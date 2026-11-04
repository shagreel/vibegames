#!/usr/bin/env python3
"""Fails if the iOS app gains any way to pay at all.

The app sells nothing: no in-app purchase, no tip jar, no link to a website page
that carries a way to pay. A link to Venmo, or to the page that carries one, is
the guideline 3.1.1 mistake; so is bringing the tip back without deciding to sell
it through Apple again.

So this scans `Sources/` for the names of payment routes, the path of the page
that carries one, and the name of the tip the app used to sell.

Comments are exempt on purpose. The app's own comments explain *why* there is no
payment link, and that explanation has to be able to name the thing it is
explaining the absence of; what must stay clean is the code and the copy.

Usage: python3 Tools/check_app_no_payments.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"

# Written out rather than imported from the app, because the point is to catch a
# new one appearing anywhere, including in a file that knows nothing about this.
MARKERS = (
    # The page on the website that carries the Venmo link. A marker rather than a
    # rule about links, because a `Link` to it and a hard-coded URL in a button
    # are the same mistake.
    "ways-to-help",
    "venmo",
    "chill-gelato",
    "chill gelato",
    # The tip the app used to sell. It is gone, and a guard that lets the name
    # come back would let the feature come back with it.
    "buy us a treat",
    "paypal",
    "cash.app",
    "cashapp",
    "ko-fi",
    "buymeacoffee",
    "patreon",
    "tip jar",
)

# A line that is a comment may name these; a line of code or copy may not.
COMMENT_PREFIXES = ("//", "///", "*", "/*")


def main() -> None:
    offenders: list[str] = []
    scanned = 0

    for path in sorted(SOURCES.rglob("*.swift")):
        scanned += 1
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith(COMMENT_PREFIXES):
                continue
            lowered = line.lower()
            for marker in MARKERS:
                if marker in lowered:
                    offenders.append(
                        f"{path.relative_to(ROOT)}:{number}  {marker!r} in  {stripped[:90]}"
                    )

    if offenders:
        print(f"Found {len(offenders)} way(s) to pay in the app:\n", file=sys.stderr)
        for offender in offenders:
            print(f"  {offender}", file=sys.stderr)
        print("\nThe only way to pay in the app is Apple's. A link to any other "
              "route — including the website page that has one — is what guideline "
              "3.1.1 is about. `APP_STORE.md` has the reasoning.", file=sys.stderr)
        sys.exit(1)

    print(f"App payment check passed — scanned {scanned} Swift files, "
          "no way to pay in the app.")


if __name__ == "__main__":
    main()
