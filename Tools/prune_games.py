#!/usr/bin/env python3
"""Deletes old games from the Realtime Database.

Nothing in the app can delete a game: the rules hand out writes to whoever gets
there first and never a delete, so that one phone cannot wipe a game out from
under everyone else. That leaves the cleanup to an administrator, which is this.

A game is judged by the timestamp it was created with — `meta/createdAt` for
Vibe Trio, `createdAt` for Vibe Words and Vibe Sudoku. Games with no timestamp
at all are listed but kept unless `--no-timestamp` says otherwise, because an
unreadable shape is more likely to be a schema change than rubbish.

Deleting is off unless `--apply` is passed, so the default run is a report.

Usage:
    python3 Tools/prune_games.py [--apply] [--hours 24] [--no-timestamp]
                                 [--project vibe-words-party]
                                 [--config-dir .build/fbconfig]
                                 [--keep CODE]...

Authentication reuses the Firebase CLI's stored credentials, which carry owner
rights and so bypass the security rules — the app's own rules would refuse the
delete. Run `firebase login` with the same XDG_CONFIG_HOME first.
"""
import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from firebase_database import access_token  # noqa: E402

DATABASE = "https://{project}-default-rtdb.firebaseio.com"

# The games, and the field each keeps its creation time in. Vibe Blurt was
# missing from this list, which is why its rooms had never been cleared by hand;
# the scheduled function in `functions/` covers the same four, so if you change
# one, change the other.
TREES = {
    "trio": ("meta/createdAt", "createdAt"),
    "blurt": ("meta/createdAt", "createdAt"),
    "games": ("createdAt",),
    "sudoku": ("createdAt",),
}


def request(token: str, url: str, method: str = "GET"):
    req = urllib.request.Request(url, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=180) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read()
        return error.code, json.loads(body) if body else None


def created_at(game: dict, fields) -> Optional[float]:
    """When the game was made, as a Unix time, or None if it cannot be told.

    Timestamps are stored in milliseconds, but a missing or unreadable value
    must not be mistaken for 1970 — that would delete every game we cannot read.
    """
    for field in fields:
        node = game
        for step in field.split("/"):
            node = node.get(step) if isinstance(node, dict) else None
        if isinstance(node, (int, float)) and not isinstance(node, bool):
            return node / 1000.0
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", default="vibe-words-party")
    parser.add_argument("--config-dir", default=".build/fbconfig")
    parser.add_argument("--hours", type=float, default=24.0,
                        help="delete games older than this many hours (default 24)")
    parser.add_argument("--apply", action="store_true",
                        help="actually delete; without this the run only reports")
    parser.add_argument("--no-timestamp", action="store_true",
                        help="also delete games whose creation time cannot be read")
    parser.add_argument("--keep", action="append", default=[],
                        help="a game code to leave alone; may be repeated")
    args = parser.parse_args()

    token = access_token(pathlib.Path(args.config_dir))
    base = DATABASE.format(project=args.project)
    cutoff = time.time() - args.hours * 3600.0
    keep = {code.lower() for code in args.keep}

    doomed: list[tuple[str, str, str]] = []
    kept = 0

    for tree, fields in TREES.items():
        status, games = request(token, f"{base}/{tree}.json")
        if status >= 400:
            raise SystemExit(f"Could not read /{tree}: HTTP {status} {games}")
        if not isinstance(games, dict):
            print(f"/{tree}: empty")
            continue

        print(f"/{tree}: {len(games)} game(s)")
        for code, game in sorted(games.items()):
            if not isinstance(game, dict):
                continue
            if code.lower() in keep:
                print(f"  keep    {code}  (asked for)")
                kept += 1
                continue

            made = created_at(game, fields)
            if made is None:
                if args.no_timestamp:
                    doomed.append((tree, code, "no creation time"))
                else:
                    print(f"  keep    {code}  (no creation time — pass --no-timestamp to drop)")
                    kept += 1
                continue

            age = (time.time() - made) / 3600.0
            if made < cutoff:
                doomed.append((tree, code, f"{age:.1f}h old"))
            else:
                print(f"  keep    {code}  ({age:.1f}h old)")
                kept += 1

    if not doomed:
        print(f"\nNothing to prune. {kept} game(s) kept.")
        return

    print(f"\n{len(doomed)} game(s) older than {args.hours:g}h:")
    for tree, code, why in doomed:
        print(f"  {tree}/{code}  {why}")

    if not args.apply:
        print("\nReport only — pass --apply to delete these.")
        return

    failures = 0
    for tree, code, _ in doomed:
        status, _ = request(token, f"{base}/{tree}/{urllib.parse.quote(code)}.json",
                            method="DELETE")
        if status >= 400:
            failures += 1
            print(f"  failed  {tree}/{code}: HTTP {status}")
    print(f"\nDeleted {len(doomed) - failures}, failed {failures}, kept {kept}.")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
