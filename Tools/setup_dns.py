#!/usr/bin/env python3
"""Points a custom domain at the Firebase Hosting sites, using Cloudflare DNS.

Two halves have to agree, and it is easy to do only one of them:

  1. Firebase must be *told* about the hostname, or it serves 404 for a domain
     it does not recognise — a CNAME alone is not enough.
  2. Cloudflare must carry the exact records Firebase asks for, so it can
     verify ownership and issue a certificate.

This does both: it registers the custom domains, reads back the records
Firebase requires, reconciles them in Cloudflare, then waits for the
certificates.

Usage:
    export CLOUDFLARE_API_TOKEN=...        # Zone:DNS:Edit + Zone:Zone:Read
    python3 Tools/setup_dns.py example.com            # dry run, shows the plan
    python3 Tools/setup_dns.py example.com --apply    # makes the changes

The token is read from the environment so it never lands in shell history or in
this repository. The Firebase side reuses the CLI's session, which is already
scoped to your account.
"""
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIREBASE_CONFIG = ROOT / ".build/fbconfig/configstore/firebase-tools.json"
FIREBASE_CLI = ROOT / ".build/fbcli/node_modules/.bin/firebase"
PROJECT = "vibe-words-party"

HOSTING_API = "https://firebasehosting.googleapis.com/v1beta1"
CLOUDFLARE_API = "https://api.cloudflare.com/client/v4"

# Which hostname serves which Firebase Hosting site.
def plan_for(domain: str) -> dict[str, str]:
    return {
        domain: "vibe-games",             # the landing page
        f"play.{domain}": "vibe-words-party",  # the web game
    }


# --------------------------------------------------------------------------- #
# credentials
# --------------------------------------------------------------------------- #

def firebase_token() -> str:
    """The CLI refreshes its own access token; poke it, then read the result."""
    env = dict(os.environ, XDG_CONFIG_HOME=str(ROOT / ".build/fbconfig"),
               NO_UPDATE_NOTIFIER="1")
    subprocess.run([str(FIREBASE_CLI), "projects:list"],
                   capture_output=True, env=env, check=False)
    tokens = json.loads(FIREBASE_CONFIG.read_text()).get("tokens", {})
    token = tokens.get("access_token")
    if not token:
        raise SystemExit("No Firebase session. Run `firebase login` first.")
    return token


def cloudflare_token() -> str:
    token = os.environ.get("CLOUDFLARE_API_TOKEN")
    if not token:
        raise SystemExit(
            "Set CLOUDFLARE_API_TOKEN first.\n"
            "Create one at: Cloudflare dashboard -> My Profile -> API Tokens\n"
            "Use the 'Edit zone DNS' template, scoped to this domain."
        )
    return token


# --------------------------------------------------------------------------- #
# transport
# --------------------------------------------------------------------------- #

def request(url: str, token: str, method: str = "GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw) if raw else {}
        except Exception:
            return error.code, {"raw": raw[:300].decode(errors="replace")}


# --------------------------------------------------------------------------- #
# cloudflare
# --------------------------------------------------------------------------- #

def cloudflare_zone_id(token: str, domain: str) -> str:
    status, out = request(f"{CLOUDFLARE_API}/zones?name={domain}", token)
    if status >= 400 or not out.get("success", True):
        raise SystemExit(f"Cloudflare rejected the token: {json.dumps(out)[:300]}")
    results = out.get("result") or []
    if not results:
        raise SystemExit(
            f"'{domain}' is not a zone in this Cloudflare account.\n"
            "Add the site in Cloudflare and point the registrar's nameservers at\n"
            "Cloudflare first — that step cannot be automated."
        )
    return results[0]["id"]


def cloudflare_records(token: str, zone: str, name: str) -> list[dict]:
    status, out = request(f"{CLOUDFLARE_API}/zones/{zone}/dns_records?name={name}", token)
    return out.get("result") or []


def cloudflare_apply(token: str, zone: str, record: dict, apply: bool) -> str:
    """Create or update one record. Returns a human-readable outcome."""
    name, rtype, content = record["name"], record["type"], record["content"]

    existing = [r for r in cloudflare_records(token, zone, name) if r["type"] == rtype]
    body = {
        "type": rtype,
        "name": name,
        "content": content,
        "ttl": 300,
        # Firebase validates ownership and issues its own certificate, so the
        # record must be DNS-only. Proxying breaks that handshake.
        "proxied": False,
    }

    if any(r["content"] == content for r in existing):
        return f"unchanged  {rtype:5} {name} -> {content}"

    if not apply:
        verb = "update   " if existing else "create   "
        return f"{verb}{rtype:5} {name} -> {content}"

    if existing:
        status, out = request(
            f"{CLOUDFLARE_API}/zones/{zone}/dns_records/{existing[0]['id']}",
            token, method="PUT", body=body)
        verb = "updated  "
    else:
        status, out = request(f"{CLOUDFLARE_API}/zones/{zone}/dns_records",
                              token, method="POST", body=body)
        verb = "created  "

    if status >= 400 or not out.get("success", True):
        return f"FAILED   {rtype:5} {name}: {json.dumps(out.get('errors', out))[:160]}"
    return f"{verb}{rtype:5} {name} -> {content}"


def cloudflare_remove_conflicts(token: str, zone: str, record: dict, apply: bool) -> list[str]:
    """Flag records that will stop Firebase validating this name.

    Two different problems, and they used to read the same. A record of the
    *same* type but a different value is merely stale — it gets replaced below.
    A record of a *different* type at the same name is a real blocker: a CNAME
    cannot coexist with an A or AAAA record, so Firebase will look for the type
    it asked for, find the wrong one, and never validate.

    Nothing is deleted here. The record may be serving something else, and
    silently dropping someone's DNS is worse than a loud warning, so each note
    carries enough to remove it by hand if that is what you want.
    """
    name, rtype = record["name"], record["type"]
    notes = []
    wanted = record["content"]

    for existing in cloudflare_records(token, zone, name):
        if existing["type"] == rtype:
            if existing["content"] != wanted:
                notes.append(f"stale    {existing['type']:5} {name} -> {existing['content']} "
                             f"(id {existing['id']}) — replaced with the value below")
        elif existing["type"] in {"A", "AAAA", "CNAME"}:
            notes.append(f"BLOCKS   {existing['type']:5} {name} -> {existing['content']} "
                         f"(id {existing['id']}) — Firebase needs {rtype} here and the two "
                         f"cannot coexist; remove this record if the domain fails to validate")
    return notes


# --------------------------------------------------------------------------- #
# firebase
# --------------------------------------------------------------------------- #

def firebase_ensure_domain(token: str, site: str, domain: str, apply: bool) -> dict:
    url = f"{HOSTING_API}/projects/{PROJECT}/sites/{site}/customDomains"
    status, out = request(f"{url}/{domain}", token)

    if status == 200:
        return out

    if not apply:
        return {"_wouldCreate": True}

    status, out = request(f"{url}?customDomainId={domain}", token, method="POST", body={})
    if status >= 400:
        raise SystemExit(f"Firebase refused to add {domain}: {json.dumps(out)[:300]}")

    # Provisioning is asynchronous; poll briefly for the record list.
    for _ in range(20):
        time.sleep(3)
        status, current = request(f"{url}/{domain}", token)
        if status == 200 and current.get("requiredDnsUpdates"):
            return current
    return out


def required_records(custom_domain: dict) -> list[dict]:
    """Every record Firebase is asking for.

    Two places ask for things, and both matter: `requiredDnsUpdates` proves you
    own the domain, and the certificate's DNS verification proves you control it
    well enough to be issued a cert. Each desired entry wraps its records in a
    `records` list, and the payload field is `rdata` — not the `rrdata` you might
    expect from the equivalent Firebase CLI output.
    """
    records: list[dict] = []
    seen: set[tuple[str, str, str]] = set()

    def collect(container) -> None:
        if not container:
            return
        groups = container if isinstance(container, list) else [container]
        for group in groups:
            for record in group.get("records", []):
                key = (record["domainName"].rstrip("."), record["type"], record["rdata"])
                if key in seen:
                    continue
                seen.add(key)
                records.append({"name": key[0], "type": key[1], "content": key[2]})

    collect((custom_domain.get("requiredDnsUpdates") or {}).get("desired"))

    cert = custom_domain.get("cert") or {}
    verification = (cert.get("verification") or {}).get("dns") or {}
    collect(verification.get("desired"))

    return records


def certificate_state(custom_domain: dict) -> str:
    cert = custom_domain.get("cert") or {}
    return cert.get("state", custom_domain.get("certPreference", "UNKNOWN"))


# --------------------------------------------------------------------------- #

def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    apply = "--apply" in sys.argv

    if not args:
        raise SystemExit(__doc__)
    domain = args[0].strip().lower()

    fb = firebase_token()
    cf = cloudflare_token()
    zone = cloudflare_zone_id(cf, domain)

    print(f"domain:    {domain}")
    print(f"zone id:   {zone}")
    print(f"mode:      {'APPLY' if apply else 'dry run (pass --apply to change anything)'}\n")

    for hostname, site in plan_for(domain).items():
        print(f"== {hostname}  ->  Firebase site '{site}'")

        existing = firebase_ensure_domain(fb, site, hostname, apply)
        if existing.get("_wouldCreate"):
            print("   firebase: would register this custom domain")
            print("   (re-run with --apply to see the exact DNS records)")
            print()
            continue

        print(f"   firebase: registered, certificate {certificate_state(existing)}")

        records = required_records(existing)
        if not records:
            print("   firebase: no DNS updates required — already satisfied")
            print()
            continue

        for record in records:
            for note in cloudflare_remove_conflicts(cf, zone, record, apply):
                print(f"   {note}")
            print(f"   {cloudflare_apply(cf, zone, record, apply)}")
        print()

    if apply:
        print("Records applied. Firebase issues certificates once DNS resolves,")
        print("usually within 15 minutes. Re-run to check progress.")
    else:
        print("Nothing changed. Re-run with --apply once the plan looks right.")


if __name__ == "__main__":
    main()
