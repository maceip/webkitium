#!/usr/bin/env python3
"""
Emit environment lines for GitHub Actions from config/webkit-build-matrix.json.

Usage (after checkout, before prepare):

  python3 config/ci_matrix_env.py --matrix "$GITHUB_WORKSPACE/config/webkit-build-matrix.json" >> "$GITHUB_ENV"

This keeps webkit-pin tag/glob and shared CMake toggles in one place.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def onoff(val: object) -> str:
    if val is True:
        return "ON"
    if val is False:
        return "OFF"
    if isinstance(val, str) and val.upper() in ("ON", "OFF", "TRUE", "FALSE", "1", "0"):
        v = val.upper()
        if v in ("TRUE", "1", "ON"):
            return "ON"
        return "OFF"
    return "ON" if val else "OFF"


def emit_github_env(matrix_path: Path) -> None:
    data = json.loads(matrix_path.read_text(encoding="utf-8"))
    wk = data.get("webkit") or {}
    tag = wk.get("pinReleaseTag") or "webkit-pin"
    glob_pat = wk.get("partGlob") or "webkit-pin.tar.gz.part-*"
    cm = data.get("cmake") or {}
    exp = onoff(cm.get("enableExperimentalFeatures", True))
    wxr = onoff(cm.get("enableWebxr", False))
    win = cm.get("windows") or {}
    webgpu = win.get("enableWebgpuViaBuildWebkit", True)

    lines = [
        f"WEBKIT_PIN_RELEASE_TAG={tag}",
        f"WEBKIT_PIN_PART_GLOB={glob_pat}",
        f"WEBKIT_CMAKE_ENABLE_EXPERIMENTAL_FEATURES={exp}",
        f"WEBKIT_CMAKE_ENABLE_WEBXR={wxr}",
        # cmd.exe: always set; empty value omits --webgpu from the perl argv
        f"WINDOWS_BUILD_WEBKIT_EXTRA={'--webgpu' if webgpu else ''}",
    ]

    for line in lines:
        if "\n" in line or "\r" in line:
            raise ValueError(f"invalid env line: {line!r}")
        print(line)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--matrix",
        type=Path,
        default=Path(__file__).resolve().parent / "webkit-build-matrix.json",
    )
    args = ap.parse_args()
    if not args.matrix.is_file():
        print(f"::error::Matrix file not found: {args.matrix}", file=sys.stderr)
        sys.exit(1)
    emit_github_env(args.matrix)


if __name__ == "__main__":
    main()
