#!/usr/bin/env bash
# Verify every patch in webkit/patches/windows/ applies cumulatively to the
# pinned WebKit source tree.
#
# Pin: iangrunert/WebKit@64f58084c78130b874d05dbcfb508147354095af
#      (recorded in config/windows-webgpu-dawn-green.json; matched by
#      webkit-pin.tar.gz at the repo root).
#
# Usage:
#   bash changes/windows-webgpu-service/harness/tools/verify-patches.sh [workdir]
#
# The script extracts just the files the patches touch from webkit-pin.tar.gz
# (not the whole 15GB tree), builds a throwaway git repo, and runs
# `git apply --check` against every patch in order. Exits 0 iff all pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PIN_TGZ="$REPO_ROOT/webkit-pin.tar.gz"
PATCH_DIR="$REPO_ROOT/webkit/patches/windows"
WORK="${1:-$REPO_ROOT/.tmp/pin-verify}"

if [ ! -f "$PIN_TGZ" ]; then
    echo "[verify] missing $PIN_TGZ — rebuild from the webkit-pin.tar.gz.part-* files first" >&2
    exit 2
fi
if [ ! -d "$PATCH_DIR" ]; then
    echo "[verify] missing $PATCH_DIR" >&2
    exit 2
fi

mkdir -p "$WORK"
cd "$WORK"

echo "[verify] building file list from $(ls "$PATCH_DIR"/*.patch | wc -l) patches"
grep -h '^--- a/' "$PATCH_DIR"/*.patch \
    | sed 's|^--- a/||' | awk '{print $1}' | sort -u > files.list
sed 's|^|src/webkit-pin/|' files.list > tar-paths.list

if [ ! -d extracted ]; then
    echo "[verify] extracting $(wc -l < tar-paths.list) files from $(basename "$PIN_TGZ")"
    mkdir extracted
    (cd extracted && tar xzf "$PIN_TGZ" -T "$WORK/tar-paths.list" 2>/dev/null || true)
fi

TREE="$WORK/extracted/src/webkit-pin"
cd "$TREE"
if [ ! -d .git ]; then
    git init -q
    git add -A
    git -c user.email=verify@local -c user.name=verify commit -q -m "pin baseline"
fi

PASS=0 ; FAIL=0 ; FAILS=""
BASE="$(git rev-parse HEAD)"
git reset --hard "$BASE" -q

for p in "$PATCH_DIR"/*.patch; do
    n="$(basename "$p")"
    if git apply --check -p1 "$p" 2>/dev/null; then
        printf '  pass  %s\n' "$n"
        git apply -p1 "$p" >/dev/null 2>&1
        git add -A
        git -c user.email=verify@local -c user.name=verify commit -q -m "$n" 2>/dev/null || true
        PASS=$((PASS+1))
    else
        printf '  FAIL  %s\n' "$n"
        FAILS="$FAILS $n"
        FAIL=$((FAIL+1))
    fi
done

echo
echo "[verify] pass=$PASS fail=$FAIL"
if [ $FAIL -gt 0 ]; then
    echo "[verify] failures:$FAILS"
    exit 1
fi
echo "[verify] every patch applies cleanly to the pin."
