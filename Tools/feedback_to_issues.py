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

Crashes — reports the browser sent on its own, with `kind` of `crash` — arrive
here too, labelled and titled differently so they are not mistaken for something
a person wrote. Notes from the UI test start with `[test]` and are skipped
outright, so a test run can never open an issue.

Usage:
    GH_TOKEN=... python3 Tools/feedback_to_issues.py [--repo owner/name]
                                                     [--database URL]
                                                     [--limit N] [--dry-run]
"""
import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from typing import Optional

DEFAULT_REPO = "shagreel/vibegames"
DEFAULT_DATABASE = "https://vibe-words-party-default-rtdb.firebaseio.com"
LABELS = {"feedback": "feedback", "crash": "crash"}

MARKER = "feedback-id"

# The marker exactly as it is written into a body: `<!-- feedback-id: KEY -->`.
#
# A regex rather than splitting on the marker and stripping the punctuation off,
# which is what this did and was wrong in a way that took a while to see:
# `str.strip` removes *characters*, not a prefix, and every key Firebase hands
# out begins with "-". So `strip(" :->")` ate the first character of every key,
# nothing ever matched, and every entry was filed again on every run.
MARKER_PATTERN = re.compile(r"<!--\s*feedback-id:\s*([^\s]+)\s*-->")

# The prefix the UI test puts on the note it sends, so that a test run never
# turns into a public issue.
TEST_MARKER = "[test]"

# How long to wait before looking for existing issues a second time. See the
# note in `main`: GitHub's issue list can lag a moment behind an issue that was
# just created.
RE_LIST_DELAY_SECONDS = 5


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


def marker_keys(text: str) -> set[str]:
    """The feedback key an issue body claims to be about.

    Only the last non-empty line counts, and only if it is the marker on its
    own. Reading every marker anywhere in the body let a note about somebody
    else's key — and the inbox is public, so the keys are readable — suppress
    that person's real report for good: the drain would think it had already
    been filed.
    """
    lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
    if not lines:
        return set()
    match = MARKER_PATTERN.fullmatch(lines[-1])
    return {match.group(1)} if match else set()


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
            seen |= marker_keys(issue.get("body"))
        page += 1
    return seen


def ensure_label(repo: str, token: str, label: str, colour: str, description: str) -> None:
    status, _ = call(f"https://api.github.com/repos/{repo}/labels/{label}", token)
    if status == 404:
        call(
            f"https://api.github.com/repos/{repo}/labels",
            token,
            method="POST",
            body={"name": label, "color": colour, "description": description},
        )


def is_crash(entry: dict) -> bool:
    return entry.get("kind") == "crash"


def is_test_entry(entry: dict) -> bool:
    """True for a note the UI test sent down the real path.

    The test deliberately posts to the live inbox, because a form that only ever
    works against a stub proves nothing. It cannot delete what it wrote — the
    rules refuse a delete from any client — so it marks the note instead and the
    drain leaves it alone.
    """
    return str(entry.get("text", "")).lstrip().startswith(TEST_MARKER)


def title_for(entry: dict) -> str:
    """A short, single-line title. GitHub caps these at 256 characters."""
    # A crash report's first line is the exception, which makes a better title
    # than the top of its stack.
    text = " ".join(str(entry.get("text", "")).splitlines()[0:1]).strip()
    text = re.sub(r"<!--|-->|@", "", text)
    if len(text) > 70:
        text = text[:67].rstrip() + "…"
    prefix = "Crash: " if is_crash(entry) else "Feedback: "
    text = INVISIBLE.sub("", text)
    return prefix + text if text else ("Crash" if is_crash(entry) else "Feedback")


# Characters a note may not carry: C0/C1 controls, the invisible zero-width
# characters and the bidi overrides. The rules let a name or a note carry them,
# and they reach a terminal and a browser as something nobody wrote.
INVISIBLE = re.compile(
    "[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2066-\u2069]"
)


def clean_text(raw) -> str:
    """A note as it should appear in an issue: no invisibles, no HTML comments,
    and no live `@mention`."""
    text = INVISIBLE.sub("", str(raw or ""))
    # An HTML comment can hide the rest of the body — including the marker and
    # the line that says where the note came from — from anybody reading it.
    text = text.replace("<!--", "<! --").replace("-->", "-- >")
    # A mention notifies a stranger; the zero-width space keeps the text
    # readable and the notification dead.
    text = text.replace("@", "@\u200b")
    return text.strip()[:2000]


def body_for(key: str, entry: dict) -> str:
    stamped = entry.get("createdAt")
    try:
        milliseconds = float(stamped) / 1000
        # A note claiming to be from the year 100,000,000 is not a note with a
        # bad timestamp, it is a note trying to sort first forever — and
        # `fromtimestamp` raises `OverflowError` for it, which is not a
        # `ValueError`. One of those took the whole drain down: the entry sorted
        # first, could not be deleted, and every run died on it.
        now = datetime.datetime.now(datetime.timezone.utc).timestamp()
        if not (0 <= milliseconds <= now + 86400):
            raise ValueError("timestamp out of range")
        when = datetime.datetime.fromtimestamp(
            milliseconds, datetime.timezone.utc
        ).strftime("%d %b %Y, %H:%M UTC")
    except (TypeError, ValueError, OSError, OverflowError, ArithmeticError):
        when = "unknown"

    phone = entry.get("source") == "ios"
    where = "an iPhone or iPad" if phone else "a browser"
    if entry.get("game"):
        where += f", in {entry['game']}"

    # Two separate sentences on purpose: the first says what kind of report this
    # is, the second says which of the two apps it came from.
    if is_crash(entry):
        lead = (
            "The app hit this on its own — nobody typed it in."
            if phone
            else "The browser hit this on its own — nobody typed it in."
        )
    else:
        lead = "Someone typed this in and sent it."

    return (
        f"{clean_text(entry.get('text'))}\n\n"
        "---\n\n"
        f"{lead}\n\n"
        f"Came from {where}. Received {when}.\n\n"
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

    # A dry run keeps the token so it can still *read*. Throwing it away, which
    # this used to do, also threw away the list of existing issues — so the one
    # mode whose whole job is to say what would happen reported that nothing had
    # been filed yet, every time, even when everything had.

    inbox = fetch_inbox(args.database)
    if not inbox:
        print("The inbox is empty. Nothing to do.")
        return

    # The UI test walks the real path on purpose — a form that only works
    # against a stub is not evidence of anything — so its note lands in the live
    # inbox. It is marked, and marked notes never become issues.
    skipped = [
        key for key, entry in inbox.items()
        if isinstance(entry, dict) and is_test_entry(entry)
    ]
    if skipped:
        print(f"{len(skipped)} test note(s) in the inbox, left alone.")

    synced = already_synced(args.repo, token) if token else set()

    # Oldest first, so a backlog arrives in the order it was sent.
    pending = [
        (key, entry)
        for key, entry in sorted(inbox.items(), key=lambda item: item[1].get("createdAt", 0))
        if isinstance(entry, dict)
        and key not in synced
        and not is_test_entry(entry)
    ]

    print(f"{len(inbox)} in the inbox, {len(synced)} already turned into issues, "
          f"{len(pending)} to do.")

    if not pending:
        return

    # Look again before filing anything.
    #
    # GitHub serves the issue list from a read replica, so an issue created a
    # second ago may not be in it yet. Two runs close together therefore both
    # treat an entry as unfiled and both file it — which is exactly how a cleanup
    # run managed to create five duplicates immediately after filing the five
    # originals. On the usual run there is nothing pending and this costs
    # nothing; when there is, a few seconds is far cheaper than a duplicate.
    if token:
        time.sleep(RE_LIST_DELAY_SECONDS)
        synced |= already_synced(args.repo, token)
        pending = [(key, entry) for key, entry in pending if key not in synced]
        if not pending:
            print("Everything pending turned out to be filed already; nothing to do.")
            return

    if len(pending) > args.limit:
        print(f"Only doing the first {args.limit} this run; the rest wait for the next.")
        pending = pending[: args.limit]

    if token and not args.dry_run:
        # Creating a label is a write, so it waits for the real run.
        ensure_label(args.repo, token, LABELS["feedback"], "ff6b85",
                     "Sent from inside the app")
        ensure_label(args.repo, token, LABELS["crash"], "b60205",
                     "Something the app hit on its own")

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
            body={
                "title": title,
                "body": body,
                "labels": [LABELS["crash"] if is_crash(entry) else LABELS["feedback"]],
            },
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
