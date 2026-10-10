#!/usr/bin/env python3
"""Turns feedback left in the app into GitHub issues.

Nobody using the app has a GitHub account, and asking them to get one to report a
bug would mean the bug never gets reported. So the apps post to an inbox in the
Realtime Database — a write-only node anyone can add to — and this drains it.

    app  →  feedback/{key} in the database  →  this  →  a GitHub issue

Run by `.github/workflows/feedback.yml` on a schedule. There is no token in the
app and none stored anywhere: the database inbox is publicly readable precisely
because everything in it is about to become a public issue, and the workflow uses
the `GITHUB_TOKEN` it is handed for free.

An entry is never turned into two issues: the issue body carries a
`feedback-id` marker, and anything already carrying that marker is skipped. That
also means re-running after a failure is safe.

Usage:
    GH_TOKEN=... python3 Tools/feedback_to_issues.py [--repo owner/name]
                                                     [--database URL]
                                                     [--limit N] [--dry-run]
"""
import argparse
import datetime
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Optional

DEFAULT_REPO = "shagreel/vibegames"
DEFAULT_DATABASE = "https://vibe-words-party-default-rtdb.firebaseio.com"
LABEL = "feedback"

MARKER = "feedback-id"


def call(url: str, token: Optional[str], method: str = "GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Accept": "application/vnd.github+json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as error:
        raw = error.read()
        return error.code, (json.loads(raw) if raw else None)


def fetch_inbox(database: str) -> dict:
    status, payload = call(f"{database}/feedback.json", None)
    if status >= 400:
        raise SystemExit(f"could not read the feedback inbox: HTTP {status} {payload}")
    return payload or {}


def already_synced(repo: str, token: str) -> set[str]:
    """The keys that already have an issue, open or closed."""
    seen: set[str] = set()
    page = 1
    while page <= 10:  # 1,000 issues is far past anything this will ever hold
        status, issues = call(
            f"https://api.github.com/repos/{repo}/issues"
            f"?state=all&per_page=100&page={page}",
            token,
        )
        if status >= 400:
            raise SystemExit(f"could not list issues: HTTP {status} {issues}")
        if not issues:
            break
        for issue in issues:
            # Pull requests come back from this endpoint too.
            if "pull_request" in issue:
                continue
            for line in (issue.get("body") or "").splitlines():
                if MARKER in line:
                    seen.add(line.split(MARKER, 1)[1].strip(" :->"))
        page += 1
    return seen


def ensure_label(repo: str, token: str) -> None:
    status, _ = call(f"https://api.github.com/repos/{repo}/labels/{LABEL}", token)
    if status == 404:
        call(
            f"https://api.github.com/repos/{repo}/labels",
            token,
            method="POST",
            body={"name": LABEL, "color": "ff6b85",
                  "description": "Sent from inside the app"},
        )


def title_for(entry: dict) -> str:
    """A short, single-line title. GitHub caps these at 256 characters."""
    text = " ".join(str(entry.get("text", "")).split())
    if len(text) > 70:
        text = text[:67].rstrip() + "…"
    return f"Feedback: {text}" if text else "Feedback"


def body_for(key: str, entry: dict) -> str:
    stamped = entry.get("createdAt")
    try:
        when = datetime.datetime.fromtimestamp(
            float(stamped) / 1000, datetime.timezone.utc
        ).strftime("%d %b %Y, %H:%M UTC")
    except (TypeError, ValueError, OSError):
        when = "unknown"

    where = "iPhone or iPad" if entry.get("source") == "ios" else "a browser"
    if entry.get("game"):
        where += f" · {entry['game']}"

    return (
        f"{entry.get('text', '').strip()}\n\n"
        "---\n\n"
        f"Sent from the app, on {where}. Received {when}.\n\n"
        f"<!-- {MARKER}: {key} -->\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO))
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--limit", type=int, default=10,
                        help="most issues to open in one run (default 10)")
    parser.add_argument("--dry-run", action="store_true",
                        help="say what would happen without touching GitHub")
    args = parser.parse_args()

    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token and not args.dry_run:
        raise SystemExit("No GH_TOKEN or GITHUB_TOKEN in the environment.")
    if args.dry_run:
        token = None

    inbox = fetch_inbox(args.database)
    if not inbox:
        print("The inbox is empty. Nothing to do.")
        return

    synced = already_synced(args.repo, token) if token else set()

    # Oldest first, so a backlog arrives in the order it was sent.
    pending = [
        (key, entry)
        for key, entry in sorted(inbox.items(), key=lambda item: item[1].get("createdAt", 0))
        if isinstance(entry, dict) and key not in synced
    ]

    print(f"{len(inbox)} in the inbox, {len(synced)} already turned into issues, "
          f"{len(pending)} to do.")

    if not pending:
        return

    if len(pending) > args.limit:
        print(f"Only doing the first {args.limit} this run; the rest wait for the next.")
        pending = pending[: args.limit]

    if token:
        ensure_label(args.repo, token)

    opened = 0
    for key, entry in pending:
        title = title_for(entry)
        body = body_for(key, entry)
        if args.dry_run:
            print(f"  would open: {title}")
            continue

        status, issue = call(
            f"https://api.github.com/repos/{args.repo}/issues",
            token,
            method="POST",
            body={"title": title, "body": body, "labels": [LABEL]},
        )
        if status >= 400:
            # Leave the entry alone so the next run tries again.
            print(f"  failed ({status}): {title} — {issue}")
            continue
        print(f"  opened #{issue['number']}: {title}")
        opened += 1

    print(f"Opened {opened} issue(s).")


if __name__ == "__main__":
    sys.exit(main())
