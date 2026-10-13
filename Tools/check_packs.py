#!/usr/bin/env python3
"""Validates the Vibe Five pack files.

Checks, per pack:
  * at least MIN_PER_PACK prompts
  * no duplicates within the pack
  * no duplicates across the whole library
  * 1-6 words, no trailing punctuation, no forbidden characters

Usage: python3 Tools/check_packs.py
Exits non-zero if any check fails.
"""
import re
import sys
from pathlib import Path

PACKS_DIR = Path("Sources/Features/VibeFive/Packs")
# A floor, not a target. Packs get trimmed over time as prompts are retired, so
# demanding an exact size would mean editing this file every time a category is
# dropped — the check would be reporting the edit rather than a problem. What it
# is actually here to catch is a pack being gutted by accident: a bad merge or a
# truncated file. Keeping well clear of the smallest pack by design leaves room
# for normal trimming without the number needing to move.
MIN_PER_PACK = 40
MIN_WORDS, MAX_WORDS = 1, 6

# Types referenced by CategoryPack.prompts
EXPECTED_TYPES = [
    "EverydayPrompts", "FoodPrompts", "AnimalsPrompts", "MoviesPrompts",
    "MusicPrompts", "TVPrompts", "TravelPrompts", "SportsPrompts",
    "GamesPrompts", "PeoplePrompts", "RandomPrompts",
]

problems: list[str] = []
seen: dict[str, str] = {}
total = 0

print(f"{'pack':22s} {'count':>5s}  status")
print("-" * 48)

for type_name in EXPECTED_TYPES:
    path = PACKS_DIR / f"{type_name}.swift"
    if not path.exists():
        problems.append(f"{type_name}: file missing ({path})")
        print(f"{type_name:22s} {'--':>5s}  MISSING")
        continue

    source = path.read_text()
    body = re.search(r"static let all: \[String\] = \[(.*?)\n    \]", source, re.S)
    if not body:
        problems.append(f"{type_name}: could not find the `static let all` array")
        print(f"{type_name:22s} {'--':>5s}  UNPARSEABLE")
        continue

    items = re.findall(r'"((?:[^"\\]|\\.)*)"', body.group(1))
    total += len(items)

    local_problems: list[str] = []
    if len(items) < MIN_PER_PACK:
        local_problems.append(f"only {len(items)} prompts, fewer than {MIN_PER_PACK}")

    local_seen: set[str] = set()
    for item in items:
        if item in local_seen:
            local_problems.append(f"duplicate within pack: {item!r}")
        local_seen.add(item)

        words = item.split()
        if not (MIN_WORDS <= len(words) <= MAX_WORDS):
            local_problems.append(f"{len(words)} words: {item!r}")
        if item != item.strip() or item.endswith((".", "?", "!", ",")):
            local_problems.append(f"punctuation/whitespace: {item!r}")
        if any(ch in item for ch in '"\\'):
            local_problems.append(f"unsafe character: {item!r}")
        if len(item) > 46:
            local_problems.append(f"too long ({len(item)} chars): {item!r}")
        if item and not item[0].isupper():
            local_problems.append(f"not capitalised: {item!r}")

        if item in seen:
            local_problems.append(f"ALSO in {seen[item]}: {item!r}")
        else:
            seen[item] = type_name

    problems.extend(f"{type_name}: {p}" for p in local_problems)
    status = "ok" if not local_problems else f"{len(local_problems)} issue(s)"
    print(f"{type_name:22s} {len(items):5d}  {status}")

print("-" * 48)
print(f"{'TOTAL':22s} {total:5d}")
print(f"{'unique':22s} {len(seen):5d}")

if problems:
    print(f"\n{len(problems)} problem(s):")
    for p in problems[:80]:
        print(f"  - {p}")
    if len(problems) > 80:
        print(f"  ... and {len(problems) - 80} more")
    sys.exit(1)

print("\nAll pack files valid.")
