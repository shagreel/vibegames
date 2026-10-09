#!/usr/bin/env python3
"""Generates the abstract "people playing" illustrations for the landing page.

I cannot produce real photographs, so rather than ship obvious broken-image
placeholders this draws deliberate geometric figures in each game's accent
colours. They are meant to be *replaced*: drop real photos into
`site/assets/people/` using the same filenames (as .jpg) and the page picks them
up with no other change — see the note in the site README.

    python3 Tools/make_illustrations.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "site" / "assets" / "people"

W, H = 900, 640

# One per game accent, plus a neutral group shot.
PALETTES = {
    "playing-together": (("#2a1a52", "#0b0a17"), "#ffffff"),
    "vibe-five-crowd": (("#3a1030", "#0b0a17"), "#ffffff"),
    "vibe-words-crowd": (("#0b2b3a", "#0b0a17"), "#ffffff"),
    "vibe-sudoku-crowd": (("#241046", "#0b0a17"), "#ffffff"),
    "vibe-trio-crowd": (("#33290a", "#0b0a17"), "#ffffff"),
}


def figure(cx: int, base: int, scale: float, opacity: float) -> str:
    """A head and shoulders, sized and placed by `scale`."""
    head_r = 46 * scale
    shoulder_w = 132 * scale
    shoulder_h = 150 * scale
    head_cy = base - shoulder_h - head_r - 10 * scale

    return (
        f'<g opacity="{opacity}">'
        f'<circle cx="{cx}" cy="{head_cy:.0f}" r="{head_r:.0f}"/>'
        f'<rect x="{cx - shoulder_w / 2:.0f}" y="{base - shoulder_h:.0f}" '
        f'width="{shoulder_w:.0f}" height="{shoulder_h:.0f}" '
        f'rx="{shoulder_w / 2:.0f}"/>'
        f"</g>"
    )


def confetti(seed: int) -> str:
    """Deterministic scatter, so re-running does not churn the output."""
    state = seed
    parts = []
    for _ in range(26):
        state = (state * 1103515245 + 12345) % (2**31)
        x = state % W
        state = (state * 1103515245 + 12345) % (2**31)
        y = state % (H - 120)
        state = (state * 1103515245 + 12345) % (2**31)
        r = 3 + state % 7
        state = (state * 1103515245 + 12345) % (2**31)
        o = 0.10 + (state % 30) / 100
        parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" opacity="{o:.2f}"/>')
    return "".join(parts)


def illustration(name: str, colours: tuple[str, str], ink: str) -> str:
    top, bottom = colours
    phone_x, phone_y, phone_w, phone_h = W / 2 - 74, 150, 148, 268

    figures = "".join([
        figure(150, 620, 1.00, 0.30),
        figure(330, 640, 1.18, 0.46),
        figure(W / 2, 620, 0.86, 0.92),   # the one holding the phone
        figure(W - 330, 640, 1.18, 0.46),
        figure(W - 150, 620, 1.00, 0.30),
    ])

    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="People playing {name.replace('-', ' ')}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{top}"/>
      <stop offset="1" stop-color="{bottom}"/>
    </linearGradient>
    <linearGradient id="screen" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#3ad0c0"/>
      <stop offset="1" stop-color="#4a86f7"/>
    </linearGradient>
  </defs>

  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <g fill="{ink}">{confetti(seed=len(name) * 7919)}</g>

  <g fill="{ink}">{figures}</g>

  <!-- the phone everyone is looking at -->
  <g>
    <rect x="{phone_x - 8}" y="{phone_y - 8}" width="{phone_w + 16}" height="{phone_h + 16}" rx="30" fill="{ink}" opacity="0.14"/>
    <rect x="{phone_x}" y="{phone_y}" width="{phone_w}" height="{phone_h}" rx="24" fill="#0b0a17"/>
    <rect x="{phone_x + 12}" y="{phone_y + 20}" width="{phone_w - 24}" height="{phone_h - 46}" rx="14" fill="url(#screen)" opacity="0.92"/>
    <rect x="{phone_x + 30}" y="{phone_y + 46}" width="{phone_w - 60}" height="16" rx="8" fill="{ink}" opacity="0.85"/>
    <rect x="{phone_x + 30}" y="{phone_y + 78}" width="{phone_w - 84}" height="16" rx="8" fill="{ink}" opacity="0.55"/>
    <rect x="{phone_x + 30}" y="{phone_y + 110}" width="{phone_w - 72}" height="16" rx="8" fill="{ink}" opacity="0.35"/>
  </g>
</svg>
"""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (colours, ink) in PALETTES.items():
        path = OUT / f"{name}.svg"
        path.write_text(illustration(name, colours, ink), encoding="utf-8")
        print(f"  wrote {path.relative_to(OUT.parents[2])}")
    print("\nThese are stand-ins — see site/README.md for swapping in real photos.")


if __name__ == "__main__":
    main()
