#!/usr/bin/env python3
"""Fails if the iOS app gains a way to pay.

Apple rejects an app that points at a way to pay for something it does not sell,
and this app sells nothing. The website is allowed to carry the Venmo link — a
website is not an app — so this scans `Sources/` and nothing else.

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
    # The page that carries the Venmo link. The app names the website in plain
    # text and opens nothing — a marker rather than a rule about links, because a
    # `Link` to it and a hard-coded URL in a button are the same mistake.
    "ways-to-help",
    "venmo",
    "chill-gelato",
    "chill gelato",
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
        print("\nThe app must sell nothing and point at nothing purchasable, "
              "including the website page that carries the payment link: it names "
              "the site in plain text instead. `APP_STORE.md` has the reasoning.",
              file=sys.stderr)
        sys.exit(1)

    print(f"App payment check passed — scanned {scanned} Swift files, "
          "no way to pay in the app.")


if __name__ == "__main__":
    main()
