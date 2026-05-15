#!/usr/bin/env python3
"""
Apply or validate the repo WebKit patch series against a pinned WebKit checkout.

The script intentionally avoids --unidiff-zero. Each patch is applied
cumulatively with git apply --3way so malformed hunks fail early, while small
upstream context drift can still be resolved by Git.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(cmd: list[str], *, cwd: Path | None = None) -> str:
    try:
        return subprocess.check_output(cmd, cwd=cwd, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.output)
        raise


def git(root: Path, *args: str) -> list[str]:
    return ["git", "-c", f"safe.directory={root}", "-C", str(root), *args]


def load_json(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"::error::missing JSON file: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def verify_webkit_head(webkit_root: Path, matrix_path: Path) -> None:
    matrix = load_json(matrix_path)
    expected = (matrix.get("webkit") or {}).get("expectedCommit")
    if not expected:
        raise SystemExit("::error::matrix.webkit.expectedCommit missing")
    if not (webkit_root / ".git").exists():
        raise SystemExit(f"::error::not a git checkout (no .git): {webkit_root}")
    head = run(git(webkit_root, "rev-parse", "HEAD")).strip()
    if head != expected:
        raise SystemExit(
            "::error::webkit checkout does not match config/webkit-build-matrix.json "
            f"(got {head}, expected {expected})"
        )
    print(f"OK webkit HEAD matches matrix: {head[:12]}...")


def enabled_change_ids(platform: str, changes_path: Path) -> list[str]:
    changes = load_json(changes_path)
    enabled: list[str] = []
    for item in changes.get("activeChanges", []):
        if not item.get("enabled"):
            continue
        platforms = item.get("platforms") or []
        if platform in platforms:
            enabled.append(item["id"])
    return enabled


def display_path(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def patch_dirs(repo_root: Path, platform: str, changes_path: Path, *, include_common: bool) -> list[Path]:
    dirs = []
    if include_common:
        dirs.append(repo_root / "webkit" / "patches" / "common")
    dirs.append(repo_root / "webkit" / "patches" / platform)
    for change_id in enabled_change_ids(platform, changes_path):
        lane = repo_root / "changes" / change_id / "patches"
        dirs.extend([lane / "common", lane / platform])
    return [path for path in dirs if path.is_dir()]


def patch_files(dirs: list[Path]) -> list[Path]:
    patches: list[Path] = []
    for directory in dirs:
        patches.extend(sorted(directory.glob("*.patch")))
    return patches


UNQUALIFIED_WEBNN_INCLUDE = re.compile(
    r'^\+#include\s+"(?:\.\./(?:ML|WebNN|LiteRT|Implementation)[^"]*|(?:ML|WebNN|LiteRT|Implementation|Navigator|Supplementable|JSDOM)[^"/]*\.h")'
)


def audit_patch_includes(repo_root: Path, patches: list[Path]) -> None:
    failures: list[str] = []
    for patch in patches:
        rel = display_path(patch, repo_root)
        if not rel.startswith("changes/webnn-service/patches/"):
            continue
        for lineno, line in enumerate(patch.read_text(encoding="utf-8").splitlines(), start=1):
            if UNQUALIFIED_WEBNN_INCLUDE.match(line):
                failures.append(f"{rel}:{lineno}: {line[1:]}")

    if failures:
        print("::error::WebNN patches must use WebCore-root include paths, not local/MSVC-only lookup", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        raise SystemExit(1)


def file_has_include(path: Path, include: str) -> bool:
    needle = f"#include {include}"
    return any(line.strip() == needle for line in path.read_text(encoding="utf-8").splitlines())


def audit_webnn_source_includes(webkit_root: Path) -> None:
    webnn_root = webkit_root / "Source" / "WebCore" / "Modules" / "WebNN"
    if not webnn_root.is_dir():
        return

    # Keep this hard audit narrowly scoped to the concrete clang-cl miss we hit:
    # WebNN-owned files using WTF utility helpers must include their WTF header.
    checks = ((("WTFMove", "makeUnique", "makeRef", "WTF::move"), "<wtf/StdLibExtras.h>"),)
    failures: list[str] = []
    for path in sorted(list(webnn_root.rglob("*.h")) + list(webnn_root.rglob("*.cpp"))):
        text = path.read_text(encoding="utf-8")
        for tokens, include in checks:
            if any(token in text for token in tokens) and not file_has_include(path, include):
                rel = display_path(path, webkit_root)
                failures.append(f"{rel}: uses {tokens[0]} but lacks #include {include}")

    if failures:
        print("::error::Patched WebNN sources are missing direct includes", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        raise SystemExit(1)


def clean_patch(src: Path, temp_dir: Path) -> Path:
    dst = temp_dir / src.name
    data = src.read_bytes().replace(b"\r\n", b"\n")
    dst.write_bytes(data)
    return dst


def apply_patch_series(
    repo_root: Path,
    webkit_root: Path,
    patches: list[Path],
    *,
    temp_dir: Path,
) -> None:
    for patch in patches:
        clean = clean_patch(patch, temp_dir)
        rel = display_path(patch, repo_root)
        print(f"Applying {rel}")
        run(
            [
                *git(webkit_root, "apply"),
                "--3way",
                "--whitespace=nowarn",
                str(clean),
            ]
        )
        run(git(webkit_root, "add", "-A"))
    audit_webnn_source_includes(webkit_root)
    run(git(webkit_root, "reset"))


def reset_worktree(webkit_root: Path) -> None:
    run(git(webkit_root, "reset", "--hard", "HEAD"))
    run(git(webkit_root, "clean", "-ffdx"))


def check_in_temporary_worktree(
    repo_root: Path,
    webkit_root: Path,
    patches: list[Path],
    *,
    temp_dir: Path,
) -> None:
    worktree = temp_dir / "webkit-patch-check"
    try:
        run(git(webkit_root, "worktree", "add", "--detach", str(worktree), "HEAD"))
        reset_worktree(worktree)
        apply_patch_series(repo_root, worktree, patches, temp_dir=temp_dir)
    finally:
        if worktree.exists():
            subprocess.run(
                git(webkit_root, "worktree", "remove", "--force", str(worktree)),
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            shutil.rmtree(worktree, ignore_errors=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--webkit-root", type=Path, required=True)
    parser.add_argument("--platform", default="windows", choices=("windows", "macos", "linux", "ios", "android"))
    parser.add_argument("--mode", choices=("apply", "check"), default="check")
    parser.add_argument(
        "--no-common-patches",
        action="store_true",
        help="Only include webkit/patches/<platform> and matching change lanes. Android patches target WPE-Android, not the pinned WebKit tree.",
    )
    parser.add_argument(
        "--matrix",
        type=Path,
        default=None,
        help="Path to config/webkit-build-matrix.json (defaults under repo root)",
    )
    parser.add_argument(
        "--changes",
        type=Path,
        default=None,
        help="Path to config/changes.json (defaults under repo root)",
    )
    parser.add_argument(
        "--skip-pin-check",
        action="store_true",
        help="Skip asserting that --webkit-root HEAD equals matrix.webkit.expectedCommit",
    )
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    webkit_root = args.webkit_root.resolve()
    matrix_path = (args.matrix or repo_root / "config" / "webkit-build-matrix.json").resolve()
    changes_path = (args.changes or repo_root / "config" / "changes.json").resolve()

    if not args.skip_pin_check:
        verify_webkit_head(webkit_root, matrix_path)

    dirs = patch_dirs(repo_root, args.platform, changes_path, include_common=not args.no_common_patches)
    patches = patch_files(dirs)
    print(f"Patch directories ({len(dirs)}):")
    for directory in dirs:
        print(f"  {display_path(directory, repo_root)}")
    print(f"Patch count: {len(patches)}")
    audit_patch_includes(repo_root, patches)

    with tempfile.TemporaryDirectory(prefix="webkit-patches-") as temp:
        temp_dir = Path(temp)
        if args.mode == "apply":
            apply_patch_series(repo_root, webkit_root, patches, temp_dir=temp_dir)
        else:
            check_in_temporary_worktree(repo_root, webkit_root, patches, temp_dir=temp_dir)

    print(f"PATCH_SERIES_OK platform={args.platform} mode={args.mode} patches={len(patches)}")


if __name__ == "__main__":
    main()
