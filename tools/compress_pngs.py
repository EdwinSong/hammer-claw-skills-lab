#!/usr/bin/env python3
"""
Compress PNG assets for Hammer Claw skills.

Ensures every PNG is no larger than MAX_SIZE x MAX_SIZE pixels and is
saved with an optimized palette (PNG-8) when possible. Files that are
already small enough are re-compressed in place.

Usage:
    python tools/compress_pngs.py skills/my_skill/assets/*.png
    python tools/compress_pngs.py skills/my_skill/preview.png
    python tools/compress_pngs.py skills/my_skill/assets
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

MAX_SIZE = 64


def _compress_with_pngquant(src: Path, dst: Path) -> bool:
    pngquant = shutil.which("pngquant")
    if not pngquant:
        return False
    try:
        subprocess.run(
            [pngquant, "--force", "--quality=60-95", "--output", str(dst), str(src)],
            check=True,
            capture_output=True,
        )
        return dst.exists() and dst.stat().st_size > 0
    except Exception:
        return False


def _compress_with_pil(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGBA")

    # Resize if larger than MAX_SIZE while keeping aspect ratio
    w, h = img.size
    if w > MAX_SIZE or h > MAX_SIZE:
        ratio = min(MAX_SIZE / w, MAX_SIZE / h)
        new_size = (int(w * ratio), int(h * ratio))
        img = img.resize(new_size, Image.Resampling.LANCZOS)

    # For small icons with limited colors, use PNG-8 palette with alpha
    pixels = w * h
    if pixels <= MAX_SIZE * MAX_SIZE * 4:
        try:
            alpha = img.split()[3]
            palette = img.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=256)
            mask = alpha.point(lambda a: 0 if a > 128 else 255, mode="1")
            palette.paste(255, mask)
            palette.info["transparency"] = 255
            palette.save(dst, "PNG", optimize=True)
            return
        except Exception:
            pass

    img.save(dst, "PNG", optimize=True)


def compress_file(src: Path) -> tuple[int, int]:
    src = Path(src)
    if not src.is_file():
        raise FileNotFoundError(src)

    before = src.stat().st_size
    tmp = src.with_suffix(".tmp.png")

    if not _compress_with_pngquant(src, tmp):
        _compress_with_pil(src, tmp)

    after = tmp.stat().st_size
    if after < before:
        tmp.replace(src)
    else:
        tmp.unlink()
        after = before

    return before, after


def main() -> int:
    parser = argparse.ArgumentParser(description="Compress PNG skill assets")
    parser.add_argument("paths", nargs="+", help="PNG files or directories to compress")
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

    total_before = 0
    total_after = 0
    for src in files:
        before, after = compress_file(src)
        total_before += before
        total_after += after
        print(f"{src}: {before} -> {after} bytes")

    print(f"Total: {total_before} -> {total_after} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
