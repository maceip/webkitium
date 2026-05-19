#!/usr/bin/env python3
"""Heuristic: content band below chrome should not be a flat empty/placeholder surface."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _load_image(path: Path):
    try:
        from PIL import Image  # type: ignore
    except ImportError as e:
        raise SystemExit("Pillow required") from e
    return Image.open(path).convert("RGB")


def content_variance_ratio(path: Path, top_skip: float = 0.22, bottom_skip: float = 0.05) -> float:
    im = _load_image(path)
    w, h = im.size
    y0 = int(h * top_skip)
    y1 = int(h * (1.0 - bottom_skip))
    if y1 <= y0:
        return 0.0
    pixels = im.crop((0, y0, w, y1)).getdata()
    if not pixels:
        return 0.0
    # Count pixels that are not near-uniform gray (placeholder background)
    interesting = 0
    for r, g, b in pixels:
        spread = max(r, g, b) - min(r, g, b)
        if spread > 18 or max(r, g, b) < 240:
            interesting += 1
    return interesting / len(pixels)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("screenshot", type=Path)
    p.add_argument("--min-ratio", type=float, default=0.04)
    p.add_argument("--top-skip", type=float, default=0.22)
    args = p.parse_args()
    if not args.screenshot.is_file():
        print(f"::error::missing {args.screenshot}", file=sys.stderr)
        return 1
    ratio = content_variance_ratio(args.screenshot, top_skip=args.top_skip)
    print(f"content_interesting_ratio={ratio:.6f} min={args.min_ratio}")
    if ratio < args.min_ratio:
        print(
            f"::error::Engine content area looks empty/placeholder (ratio {ratio:.6f})",
            file=sys.stderr,
        )
        return 1
    print("ENGINE_CONTENT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
