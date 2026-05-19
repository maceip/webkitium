#!/usr/bin/env python3
"""Heuristic: top chrome band of a shell screenshot should contain visible blue (HTTPS lock).

This does NOT prove TLS or pinned WebKit — only that the chrome painted the lock affordance.
Use together with engine bundle manifests and (where applicable) in-window page content checks.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _load_image(path: Path):
    try:
        from PIL import Image  # type: ignore
    except ImportError as e:
        raise SystemExit(
            "Pillow required: pip install Pillow (or apt install python3-pil)"
        ) from e
    return Image.open(path).convert("RGB")


def blue_pixel_ratio(path: Path, top_fraction: float = 0.18) -> float:
    im = _load_image(path)
    w, h = im.size
    top_h = max(1, int(h * top_fraction))
    pixels = im.crop((0, 0, w, top_h)).getdata()
    blueish = 0
    total = 0
    for r, g, b in pixels:
        total += 1
        # Glowing lock: strong blue, not gray/white background only
        if b >= 120 and b > r + 25 and b > g + 10:
            blueish += 1
    return blueish / total if total else 0.0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("screenshot", type=Path)
    p.add_argument(
        "--min-ratio",
        type=float,
        default=0.0008,
        help="Minimum fraction of top-band pixels that look blue (default: 0.08%%)",
    )
    p.add_argument(
        "--top-fraction",
        type=float,
        default=0.18,
        help="Height fraction from top to scan (default: 0.18)",
    )
    args = p.parse_args()
    if not args.screenshot.is_file():
        print(f"::error::screenshot missing: {args.screenshot}", file=sys.stderr)
        return 1
    ratio = blue_pixel_ratio(args.screenshot, args.top_fraction)
    print(f"blue_pixel_ratio={ratio:.6f} min={args.min_ratio}")
    if ratio < args.min_ratio:
        print(
            f"::error::HTTPS lock not detected in top chrome (ratio {ratio:.6f} < {args.min_ratio})",
            file=sys.stderr,
        )
        return 1
    print("HTTPS_CHROME_LOCK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
