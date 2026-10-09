#!/usr/bin/env python3
"""Builds the web-sized Vibe Trio card faces from the app's masters.

The app ships the 81 card faces at 900x1153, which is 72MB — the right size for
a 13-inch iPad and far too much for a web page. This writes 512px, 256-colour
copies to `web/public/cards/`, which the browser fetches lazily, one per card
actually on the table.

512 is not a guess: the largest a card is ever drawn is on a 13-inch iPad in
portrait, where the fitted board gives four columns of 484px each (see the Trio
board layout). 512 is above that, so nothing is ever upscaled. Downscaling first
and quantising second beats either alone, because the resample smooths the
gradients until 256 colours can carry them — measured at a mean 37.3 dB against
the 512px originals across all 81 cards.

Usage:
    python3 Tools/make_web_cards.py [--force]

The masters in `cards/` are untouched; this only writes derived copies.
"""
import argparse
import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    raise SystemExit("Needs Pillow: python3 -m pip install Pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "cards"
TARGET = ROOT / "web" / "public" / "cards"
WIDTH = 512
COLOURS = 256


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true",
                        help="rebuild even if the output already exists")
    args = parser.parse_args()

    masters = sorted(SOURCE.glob("*.png"))
    if len(masters) != 81:
        raise SystemExit(f"expected 81 masters in {SOURCE}, found {len(masters)}")

    TARGET.mkdir(parents=True, exist_ok=True)
    total = 0
    skipped = 0

    for master in masters:
        out = TARGET / master.name
        if out.exists() and not args.force:
            total += out.stat().st_size
            skipped += 1
            continue

        image = Image.open(master).convert("RGBA")
        height = round(image.height * WIDTH / image.width)
        small = image.resize((WIDTH, height), Image.LANCZOS)
        small.quantize(colors=COLOURS, method=Image.FASTOCTREE).save(out, "PNG", optimize=True)
        total += out.stat().st_size

    master_bytes = sum(m.stat().st_size for m in masters)
    print(f"{len(masters)} cards -> {TARGET.relative_to(ROOT)}")
    print(f"  {master_bytes / 1e6:.1f}MB of masters -> {total / 1e6:.1f}MB at {WIDTH}px/{COLOURS} colours"
          + (f"  ({skipped} already present)" if skipped else ""))


if __name__ == "__main__":
    sys.exit(main())
