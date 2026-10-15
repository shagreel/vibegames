#!/usr/bin/env python3
"""Fails if the iOS app gains a way to pay that is not Apple's.

The app sells exactly one thing: a tip, as a consumable in-app purchase. Apple
takes its commission on that and, in exchange, forbids the app from pointing at
any *other* way to pay for the same thing — guideline 3.1.1 — which is why there
is no Venmo link in here, no website page that carries one, and why the line
naming the website came out when the tip went in.

So this scans `Sources/` for the names of other payment routes, and for the path
of the page that carries one. It does not object to the tip itself: "Buy us a
treat" is the product, and a rule that forbade it would be forbidding the thing
the app is supposed to do.

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
    # Note: "buy us a treat" is *not* here. It is the name of the in-app product,
    # so a rule against it would be a rule against the tip jar itself.
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
          "no way to pay in the app but Apple's own.")


if __name__ == "__main__":
    main()
