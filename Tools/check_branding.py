#!/usr/bin/env python3
"""Fails if the trademarked term this project must not use appears anywhere.

The term is assembled from fragments rather than written literally, so this
guard does not itself introduce the string it is checking for.

Scanned: Swift sources, tests, tooling, project config, Firebase rules and docs.
Ignored: build output, and the vendored Firebase package cache.

Usage: python3 Tools/check_branding.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Deliberately split so this file never contains the whole word.
FORBIDDEN = ("word" + "le").lower()

# `archive/` holds an export of the retired project, whose own project id
# contains the term. It is git-ignored, so it can never reach the repository,
# and it is data rather than code, configuration or UI.
SKIP_DIRS = {".build", ".git", "node_modules", "DerivedData", "SourcePackages", "archive"}
# Files larger than this are almost certainly generated or binary.
MAX_SCAN_BYTES = 4_000_000

# Extensionless dotfiles like .firebaserc are exactly where a stray reference
# hides, so everything readable is scanned rather than a suffix allowlist.
SCAN_SUFFIXES = {
    ".swift", ".md", ".py", ".yml", ".yaml", ".json", ".plist",
    ".txt", ".sh", ".html", ".js", ".ts", ".tsx",
}
# Extensionless files worth scanning even though they are not in the list above.
SCAN_NAMES = {".firebaserc", ".gitignore", ".env", ".env.local", ".env.example"}


def main() -> None:
    offenders: list[str] = []
    scanned = 0

    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue

        # A file *name* is as visible as its contents.
        if FORBIDDEN in path.name.lower():
            offenders.append(f"{path.relative_to(ROOT)}  (filename)")

        if path.stat().st_size > MAX_SCAN_BYTES:
            continue

        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue

        scanned += 1
        for number, line in enumerate(text.splitlines(), start=1):
            if FORBIDDEN in line.lower():
                offenders.append(f"{path.relative_to(ROOT)}:{number}  {line.strip()[:100]}")

    if offenders:
        print(f"Found {len(offenders)} occurrence(s) of the prohibited term:\n", file=sys.stderr)
        for offender in offenders:
            print(f"  {offender}", file=sys.stderr)
        print("\nThis term must not appear in code, configuration, filenames or UI.",
              file=sys.stderr)
        sys.exit(1)

    print(f"Branding check passed — scanned {scanned} files, no prohibited term found.")


if __name__ == "__main__":
    main()
