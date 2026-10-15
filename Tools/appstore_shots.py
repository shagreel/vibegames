#!/usr/bin/env python3
"""Shoots the App Store screenshots, at the sizes Apple requires.

Apple asks for one iPhone set and one iPad set, at an exact pixel size, and
rejects anything with an alpha channel or a size it does not recognise. Both are
easy to get wrong silently, so this does three things rather than one: it runs
the screenshot tests on a named simulator, exports the attachments, and then
*checks the pixel dimensions of what came out* against Apple's accepted list.

    python3 Tools/appstore_shots.py "iPhone 17 Pro Max" iphone-6.9
    python3 Tools/appstore_shots.py "iPad Pro 13-inch (M5)" ipad-13

Writes `.build/appstore/<slug>/NN-name.jpg`, flattened to JPEG because PNGs from
the simulator can carry an alpha channel and App Store Connect refuses those.
`.build/` is ignored by git, so the screenshots live there until they are
uploaded, and can be re-shot at any time.

The first three in the folder are the three the listing shows in search results.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = "VibeGames.xcodeproj"
SCHEME = "VibeGames"

# Which attachment becomes which App Store screenshot, in listing order. The
# attachment names come from the tests; `site/README.md` has the same table for
# the landing page's pictures.
WANTED = [
    ("40-light-hub", "01-five-games"),
    ("09-revealed", "02-vibe-five"),
    ("21-words-typed", "03-word-vibe"),
    ("31-sudoku-solo", "04-number-vibe"),
    ("60-trio-board-light", "05-vibe-pairings"),
    ("light-blurt-word", "06-similar-vibe"),
    ("light-blurt-buzz", "07-similar-vibe-buzz"),
    ("22-words-scored", "08-word-vibe-scored"),
    ("32-sudoku-filled", "09-number-vibe-filled"),
    ("64-trio-leaderboard-light", "10-vibe-pairings-scores"),
    ("light-blurt-guessing", "11-similar-vibe-guessing"),
    ("44-dark-hub", "12-five-games-dark"),
]

# The test classes that attach them. A class per game, because the fast suite
# skips the screenshot fixtures and this needs them.
CLASSES = [
    "VibeGamesUITests/AppearanceUITests",
    "VibeGamesUITests/VibeFiveUITests",
    "VibeGamesUITests/VibeWordsUITests",
    "VibeGamesUITests/VibeSudokuUITests",
    "VibeGamesUITests/VibeTrioUITests",
    "VibeGamesUITests/VibeBlurtScreenshots",
]

# Apple's accepted portrait sizes, by display class. A file that is not exactly
# one of these is refused at upload, which is the most common way a submission
# loses an afternoon.
ACCEPTED = {
    "6.9-inch iPhone": {(1260, 2736), (1290, 2796), (1320, 2868)},
    "6.5-inch iPhone": {(1284, 2778), (1242, 2688)},
    "13-inch iPad": {(2064, 2752), (2048, 2732)},
    "12.9-inch iPad": {(2048, 2732)},
}


def run(command: list[str]) -> None:
    print(f"  $ {' '.join(command[:4])} …")
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        tail = "\n".join((result.stdout + result.stderr).splitlines()[-25:])
        raise SystemExit(f"\nFailed:\n{tail}")


def pixel_size(path: pathlib.Path) -> tuple[int, int]:
    """Width and height, straight out of sips — the same tool that made the file."""
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                         capture_output=True, text=True, check=True).stdout
    width = int(re.search(r"pixelWidth: (\d+)", out).group(1))
    height = int(re.search(r"pixelHeight: (\d+)", out).group(1))
    return width, height


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)

    device = sys.argv[1]
    slug = sys.argv[2] if len(sys.argv) > 2 else device.lower().replace(" ", "-").replace("(", "").replace(")", "")
    out_dir = ROOT / ".build" / "appstore" / slug
    result_bundle = ROOT / ".build" / "appstore" / f"{slug}.xcresult"
    attachments = ROOT / ".build" / "appstore" / f"{slug}-attachments"

    for path in (out_dir, result_bundle, attachments):
        shutil.rmtree(path, ignore_errors=True)
    out_dir.mkdir(parents=True)

    print(f"\nShooting on {device}\n")
    only_testing: list[str] = []
    for name in CLASSES:
        only_testing += ["-only-testing:" + name]

    run(["xcodebuild", "-project", PROJECT, "-scheme", SCHEME, "-sdk", "iphonesimulator",
         "-destination", f"platform=iOS Simulator,name={device}",
         "-resultBundlePath", str(result_bundle), *only_testing, "test"])

    run(["xcrun", "xcresulttool", "export", "attachments",
         "--path", str(result_bundle), "--output-path", str(attachments)])

    exported: dict[str, str] = {}
    for test in json.loads((attachments / "manifest.json").read_text()):
        for attachment in test.get("attachments", []):
            # The name carries a per-run suffix: `40-light-hub_0_5E9D…`.
            exported[attachment["suggestedHumanReadableName"].split("_0_")[0]] = attachment["exportedFileName"]

    print()
    problems: list[str] = []
    made: list[tuple[str, tuple[int, int]]] = []

    for attachment, name in WANTED:
        source = attachments / exported.get(attachment, "")
        if not source.exists():
            problems.append(f"{attachment}: not attached by any test — did a test get renamed?")
            continue
        # JPEG rather than PNG: no alpha channel, and small enough to upload.
        target = out_dir / f"{name}.jpg"
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90",
                        str(source), "--out", str(target)],
                       capture_output=True, check=True)
        size = pixel_size(target)
        made.append((f"{name}.jpg", size))
        if not any(size in sizes for sizes in ACCEPTED.values()):
            problems.append(f"{name}.jpg is {size[0]}x{size[1]}, which is not a size Apple accepts")

    width = max((len(name) for name, _ in made), default=0)
    for name, size in made:
        print(f"  {name:<{width}}  {size[0]}x{size[1]}")

    if problems:
        print("\nProblems:\n", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        sys.exit(1)

    print(f"\n{len(made)} screenshots in {out_dir.relative_to(ROOT)} — every one an accepted size.")
    print("Upload the first three first: those are the ones search results show.")


if __name__ == "__main__":
    main()
