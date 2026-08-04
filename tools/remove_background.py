#!/usr/bin/env python3
"""
Remove solid-color background from PNG images.

Samples the corners to guess the background color, then replaces all
similar pixels with transparent pixels. Useful for cleaning up skill
icons before compression.

Usage:
    python tools/remove_background.py skills/my_skill/assets/*.png
    python tools/remove_background.py skills/my_skill/assets
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

TOLERANCE = 40


def remove_background(src: Path) -> None:
    img = Image.open(src).convert("RGBA")
    w, h = img.size

    # Sample background from corners and edges
    samples = [
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w // 2, 0),
        (w // 2, h - 1),
        (0, h // 2),
        (w - 1, h // 2),
    ]
    bg_colors = [img.getpixel((x, y)) for x, y in samples]
    bg_r = sum(c[0] for c in bg_colors) // len(bg_colors)
    bg_g = sum(c[1] for c in bg_colors) // len(bg_colors)
    bg_b = sum(c[2] for c in bg_colors) // len(bg_colors)

    pixels = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if (
                abs(r - bg_r) <= TOLERANCE
                and abs(g - bg_g) <= TOLERANCE
                and abs(b - bg_b) <= TOLERANCE
            ):
                pixels[x, y] = (0, 0, 0, 0)

    # Also remove extreme near-white/black edge pixels that often remain
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 0:
                brightness = (r + g + b) / 3
                if brightness > 250 or brightness < 10:
                    pixels[x, y] = (0, 0, 0, 0)

    img.save(src, "PNG", optimize=True)
    print(f"Processed {src}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Remove solid background from PNGs")
    parser.add_argument("paths", nargs="+", help="PNG files or directories")
    args = parser.parse_args()

    files: list[Path] = []
    for p in args.paths:
        path = Path(p)
        if path.is_dir():
            files.extend(sorted(path.rglob("*.png")))
        elif path.suffix.lower() == ".png":
            files.append(path)

    if not files:
        print("No PNG files found.")
        return 1

    for src in files:
        remove_background(src)

    return 0


if __name__ == "__main__":
    sys.exit(main())
