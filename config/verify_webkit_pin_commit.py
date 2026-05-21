#!/usr/bin/env python3
"""
Verify CI pins against config/webkit-build-matrix.json.

  --webkit-root DIR   require git HEAD == webkit.expectedCommit
  --check-vcpkg       require vcpkg-configuration.json default-registry.baseline
                      == dawn.vcpkgBaseline (Windows WebGPU / Dawn alignment)
  --check-green-json  require config/windows-webgpu-dawn-green.json source.commit
                      == webkit.expectedCommit (doc / recovery lane alignment)
  --check-upstream    require WebKit source metadata to point at official
                      WebKit/WebKit, not a personal fork
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


OFFICIAL_WEBKIT_URL = "https://github.com/WebKit/WebKit.git"
OFFICIAL_WEBKIT_PRESET = "official-webkit-main"


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


def normalize_repo_url(url: str) -> str:
    value = url.strip().rstrip("/")
    if value.endswith(".git"):
        value = value[:-4]
    return value.lower()


def verify_webkit_upstream(matrix: dict) -> None:
    upstream = (matrix.get("webkit") or {}).get("upstream") or {}
    got_url = upstream.get("url") or ""
    got_preset = upstream.get("preset") or ""
    want_url = OFFICIAL_WEBKIT_URL

    if normalize_repo_url(got_url) != normalize_repo_url(want_url):
        print(
            "::error::matrix.webkit.upstream.url must point at official WebKit — "
            f"got {got_url!r}, want {want_url!r}.",
            file=sys.stderr,
        )
        sys.exit(1)
    if got_preset != OFFICIAL_WEBKIT_PRESET:
        print(
            "::error::matrix.webkit.upstream.preset must use the official preset — "
            f"got {got_preset!r}, want {OFFICIAL_WEBKIT_PRESET!r}.",
            file=sys.stderr,
        )
        sys.exit(1)

    branch = upstream.get("defaultBranch")
    if branch and branch != "main":
        print(
            "::error::matrix.webkit.upstream.defaultBranch must be 'main' when set — "
            f"got {branch!r}.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"OK WebKit upstream is official: {got_url}")


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

    harness_path = repo_root / "changes" / "windows-webgpu-service" / "harness" / "vcpkg.json"
    if harness_path.is_file():
        harness = json.loads(harness_path.read_text(encoding="utf-8"))
        got_harness_baseline = harness.get("builtin-baseline")
        if got_harness_baseline != want:
            print(
                "::error::Windows WebGPU harness vcpkg builtin-baseline does not match "
                "webkit-build-matrix.json — "
                f"got {got_harness_baseline!r}, want {want!r}.",
                file=sys.stderr,
            )
            sys.exit(1)

        want_dawn_version = tag[1:] if tag.startswith("v") else tag
        dawn_override = next(
            (
                override
                for override in harness.get("overrides", [])
                if isinstance(override, dict) and override.get("name") == "dawn"
            ),
            None,
        )
        got_dawn_version = (dawn_override or {}).get("version")
        if got_dawn_version != want_dawn_version:
            print(
                "::error::Windows WebGPU harness Dawn override does not match "
                "webkit-build-matrix.json — "
                f"got {got_dawn_version!r}, want {want_dawn_version!r}.",
                file=sys.stderr,
            )
            sys.exit(1)
        print("OK Windows WebGPU harness Dawn manifest matches matrix")


def verify_windows_green_json(repo_root: Path, matrix: dict) -> None:
    path = repo_root / "config" / "windows-webgpu-dawn-green.json"
    if not path.is_file():
        print(f"::warning::{path} missing — skip green-json alignment check")
        return
    green = json.loads(path.read_text(encoding="utf-8"))
    source = green.get("source") or {}
    got = source.get("commit")
    want = (matrix.get("webkit") or {}).get("expectedCommit")
    if got != want:
        print(
            "::error::windows-webgpu-dawn-green.json source.commit differs from webkit-build-matrix.json — "
            f"got {got!r}, want {want!r}.",
            file=sys.stderr,
        )
        sys.exit(1)
    matrix_upstream = (matrix.get("webkit") or {}).get("upstream") or {}
    matrix_url = matrix_upstream.get("url")
    green_url = source.get("url")
    if matrix_url and green_url and normalize_repo_url(matrix_url) != normalize_repo_url(green_url):
        print(
            "::error::windows-webgpu-dawn-green.json source.url differs from webkit-build-matrix.json — "
            f"got {green_url!r}, want {matrix_url!r}.",
            file=sys.stderr,
        )
        sys.exit(1)
    matrix_preset = matrix_upstream.get("preset")
    green_preset = source.get("preset")
    if matrix_preset and green_preset and matrix_preset != green_preset:
        print(
            "::error::windows-webgpu-dawn-green.json source.preset differs from webkit-build-matrix.json — "
            f"got {green_preset!r}, want {matrix_preset!r}.",
            file=sys.stderr,
        )
        sys.exit(1)
    print("OK windows-webgpu-dawn-green.json source matches matrix")


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
    p.add_argument(
        "--check-upstream",
        action="store_true",
        help="Assert WebKit upstream metadata points at official WebKit/WebKit",
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

    if args.check_upstream:
        verify_webkit_upstream(matrix)

    if args.check_vcpkg:
        verify_vcpkg_baseline(repo_root, matrix)

    if args.check_green_json:
        verify_windows_green_json(repo_root, matrix)

    if args.webkit_root is None and not args.check_vcpkg and not args.check_green_json and not args.check_upstream:
        p.print_help()
        print("::error::Specify --webkit-root and/or --check-vcpkg and/or --check-green-json and/or --check-upstream", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
