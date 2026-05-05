#!/usr/bin/env python3
"""
Verify CI pins against config/webkit-build-matrix.json.

  --webkit-root DIR   require git HEAD == webkit.expectedCommit
  --check-vcpkg       require vcpkg-configuration.json default-registry.baseline
                      == dawn.vcpkgBaseline (Windows WebGPU / Dawn alignment)
  --check-green-json  require config/windows-webgpu-dawn-green.json source.commit
                      == webkit.expectedCommit (doc / recovery lane alignment)
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def load_matrix(path: Path) -> dict:
    if not path.is_file():
        print(f"::error::Matrix file missing: {path}", file=sys.stderr)
        sys.exit(1)
    return json.loads(path.read_text(encoding="utf-8"))


def verify_webkit_head(root: Path, expected: str) -> None:
    if not (root / ".git").exists():
        print(f"::error::Not a git checkout (no .git): {root}", file=sys.stderr)
        sys.exit(1)
    head = subprocess.check_output(
        ["git", "-c", f"safe.directory={root}", "-C", str(root), "rev-parse", "HEAD"],
        text=True,
    ).strip()
    if head != expected:
        print(
            "::error::webkit-pin contents do not match config/webkit-build-matrix.json — "
            f"git HEAD is {head}, expected {expected}. Re-cut webkit-pin or update the matrix.",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"OK webkit HEAD matches matrix: {head[:12]}…")


def verify_vcpkg_baseline(repo_root: Path, matrix: dict) -> None:
    want = matrix.get("dawn", {}).get("vcpkgBaseline")
    if not want:
        print("::error::matrix.dawn.vcpkgBaseline missing", file=sys.stderr)
        sys.exit(1)
    cfg_path = repo_root / matrix.get("dawn", {}).get("vcpkgConfigPath", "config/vcpkg-configuration.json")
    if not cfg_path.is_file():
        print(f"::error::vcpkg config missing: {cfg_path}", file=sys.stderr)
        sys.exit(1)
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    got = (cfg.get("default-registry") or {}).get("baseline")
    if got != want:
        print(
            "::error::vcpkg default-registry baseline does not match webkit-build-matrix.json — "
            f"got {got!r}, want {want!r}. Keep config/vcpkg-configuration.json in sync with the matrix.",
            file=sys.stderr,
        )
        sys.exit(1)
    tag = matrix.get("dawn", {}).get("versionTag", "")
    print(f"OK vcpkg baseline matches matrix ({tag})")


def verify_windows_green_json(repo_root: Path, matrix: dict) -> None:
    path = repo_root / "config" / "windows-webgpu-dawn-green.json"
    if not path.is_file():
        print(f"::warning::{path} missing — skip green-json alignment check")
        return
    green = json.loads(path.read_text(encoding="utf-8"))
    got = (green.get("source") or {}).get("commit")
    want = (matrix.get("webkit") or {}).get("expectedCommit")
    if got != want:
        print(
            "::error::windows-webgpu-dawn-green.json source.commit differs from webkit-build-matrix.json — "
            f"got {got!r}, want {want!r}.",
            file=sys.stderr,
        )
        sys.exit(1)
    print("OK windows-webgpu-dawn-green.json commit matches matrix")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--matrix",
        type=Path,
        default=Path(__file__).resolve().parent / "webkit-build-matrix.json",
        help="Path to webkit-build-matrix.json",
    )
    p.add_argument("--webkit-root", type=Path, default=None, help="Extracted WebKit source (git root)")
    p.add_argument(
        "--check-vcpkg",
        action="store_true",
        help="Assert vcpkg-configuration.json baseline matches matrix (Windows)",
    )
    p.add_argument(
        "--check-green-json",
        action="store_true",
        help="Assert windows-webgpu-dawn-green.json source.commit matches matrix webkit pin",
    )
    args = p.parse_args()

    matrix = load_matrix(args.matrix)
    expected = (matrix.get("webkit") or {}).get("expectedCommit")
    if not expected:
        print("::error::matrix.webkit.expectedCommit missing", file=sys.stderr)
        sys.exit(1)

    if args.webkit_root is not None:
        verify_webkit_head(args.webkit_root.resolve(), expected)

    repo_root = args.matrix.resolve().parents[1]

    if args.check_vcpkg:
        verify_vcpkg_baseline(repo_root, matrix)

    if args.check_green_json:
        verify_windows_green_json(repo_root, matrix)

    if args.webkit_root is None and not args.check_vcpkg and not args.check_green_json:
        p.print_help()
        print("::error::Specify --webkit-root and/or --check-vcpkg and/or --check-green-json", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
