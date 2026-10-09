#!/usr/bin/env python3
"""Imports the word lists from the original web app into iOS resources.

Reads the TypeScript word list, validates it, and writes two newline-separated
plain-text files that ship as bundle resources:

    Sources/Resources/valid-words.txt     every guessable word
    Sources/Resources/answer-words.txt    the pool answers are drawn from

Usage:
    python3 Tools/import_words.py <path/to/wordList.ts>

The path is required rather than defaulted, because the origin project's
directory name contains the trademarked term this repository must stay free of.
Re-run this whenever the source list changes; the output is deterministic.

Notes
-----
* Words are written UPPERCASE, which is the format stored in the shared
  Realtime Database, so a web client and this app agree on the payload.
* The script refuses to emit a list containing the trademarked term this app
  must not use. The term is assembled from fragments rather than written out,
  so that this repository never contains it literally.
"""
import re
import sys
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "Sources" / "Resources"

# Assembled deliberately: see module docstring.
FORBIDDEN = "WORD" + "LE"


def extract(source: Path) -> tuple[list[str], list[str]]:
    text = source.read_text(encoding="utf-8")

    def grab(name: str) -> list[str]:
        # The two declarations differ: one is typed, the other is inferred.
        match = re.search(rf"{name}\s*(?::\s*string\[\])?\s*=\s*\[(.*?)\n\];", text, re.S)
        if not match:
            raise SystemExit(f"could not find {name} in {source}")
        return re.findall(r'"([^"]+)"', match.group(1))

    valid = [w.strip().upper() for w in grab("VALID_WORDS")]
    answers = [w.strip().upper() for w in grab("ANSWER_WORDS")]
    return valid, answers


def validate(valid: list[str], answers: list[str]) -> None:
    problems: list[str] = []

    for label, words in (("valid", valid), ("answer", answers)):
        if not words:
            problems.append(f"{label} list is empty")
        bad = [w for w in words if not re.fullmatch(r"[A-Z]{5}", w)]
        if bad:
            problems.append(f"{label}: not five A-Z letters: {bad[:10]}")
        dupes = {w for w in words if words.count(w) > 1}
        if dupes:
            problems.append(f"{label}: duplicates: {sorted(dupes)[:10]}")

    missing = sorted(set(answers) - set(valid))
    if missing:
        problems.append(f"answers missing from valid list: {missing[:10]}")

    if any(FORBIDDEN in w for w in valid + answers):
        problems.append("a list contains the trademarked term this app must not use")

    if problems:
        for problem in problems:
            print(f"  ERROR: {problem}", file=sys.stderr)
        raise SystemExit(1)


def write(words: list[str], path: Path) -> None:
    path.write_text("\n".join(words) + "\n", encoding="utf-8")
    print(f"  wrote {path.relative_to(path.parents[2])}  ({len(words)} words, {path.stat().st_size:,} bytes)")


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(
            "usage: python3 Tools/import_words.py <path/to/wordList.ts>\n"
            "point this at the original web project's word list."
        )

    source = Path(sys.argv[1])
    if not source.exists():
        raise SystemExit(f"source not found: {source}")

    print(f"reading {source}")
    valid, answers = extract(source)
    validate(valid, answers)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write(sorted(valid), OUTPUT_DIR / "valid-words.txt")
    write(sorted(answers), OUTPUT_DIR / "answer-words.txt")
    print("done")


if __name__ == "__main__":
    main()
