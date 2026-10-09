#!/usr/bin/env python3
"""Creates the default Realtime Database instance for a Firebase project.

`firebase init database` is the CLI's only built-in way to do this, and it is
interactive, rewrites `database.rules.json`, and asks you to pick a region from
a list — a poor fit for a script, and risky given the region is permanent.

This talks to the same management API the CLI uses, with an explicit region and
without touching any files.

Usage:
    python3 Tools/firebase_database.py <project-id> <location> [config-dir]

Authentication reuses the Firebase CLI's stored credentials, so run
`firebase login` first. Credentials are read from the CLI's config directory
(the same XDG_CONFIG_HOME the setup script uses).
"""
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

SERVICE = "firebasedatabase.googleapis.com"
MGMT = "https://firebasedatabase.googleapis.com/v1beta"
SERVICEUSAGE = "https://serviceusage.googleapis.com/v1"


def access_token(config_dir: pathlib.Path) -> str:
    candidates = list(config_dir.rglob("firebase-tools.json"))
    if not candidates:
        raise SystemExit(
            f"No Firebase CLI credentials under {config_dir}.\n"
            "Run `firebase login` with XDG_CONFIG_HOME pointing there first."
        )
    tokens = json.loads(candidates[0].read_text()).get("tokens", {})
    token = tokens.get("access_token")
    if not token:
        raise SystemExit("Stored credentials have no access token; run `firebase login` again.")
    return token


def call(token: str, project: str, url: str, method: str = "GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-Goog-User-Project": project,
    })
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)

    project = sys.argv[1]
    location = sys.argv[2]
    config_dir = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else pathlib.Path(".build/fbconfig")

    token = access_token(config_dir)
    instance = f"{project}-default-rtdb"
    instances_url = f"{MGMT}/projects/{project}/locations/{location}/instances"

    status, existing = call(token, project, instances_url)
    if status < 400 and any(instance in (i.get("name") or "") for i in existing.get("instances", [])):
        url = next(i["databaseUrl"] for i in existing["instances"] if instance in i["name"])
        print(f"Database already exists: {url}")
        return

    print(f"Enabling {SERVICE}…")
    status, out = call(token, project, f"{SERVICEUSAGE}/projects/{project}/services/{SERVICE}:enable",
                       method="POST", body={})
    if status >= 400 and "already enabled" not in json.dumps(out):
        print(f"  warning: enable returned HTTP {status}: {out.get('error', {}).get('message', '')[:200]}")

    print(f"Creating {instance} in {location}…")
    create_url = f"{instances_url}?databaseId={instance}"
    for attempt in range(1, 21):
        status, out = call(token, project, create_url, method="POST",
                           body={"type": "default_database"})
        if status < 400:
            print(f"Created: {out.get('databaseUrl')}")
            print(f"Location: {location}   State: {out.get('state')}")
            return

        message = out.get("error", {}).get("message", "")
        # Enabling an API is eventually consistent, so retry while it settles.
        if "has not been used" in message or "disabled" in message:
            print(f"  attempt {attempt}: API still propagating, waiting…")
            time.sleep(10)
            continue

        raise SystemExit(f"Failed to create the database: {message or out}")

    raise SystemExit("Timed out waiting for the Realtime Database API to become available.")


if __name__ == "__main__":
    main()
