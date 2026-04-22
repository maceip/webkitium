#!/usr/bin/env bash
# Verify every patch applies cumulatively to the pinned WebKit source tree.
#
# Extracts just the files the patches touch (not the whole tree), builds a
# throwaway git repo, and runs git apply against every patch in order.
# Exits 0 iff all pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PIN_TGZ="$REPO_ROOT/webkit-pin.tar.gz"
WORK="${1:-$REPO_ROOT/.tmp/pin-verify}"

if [ ! -f "$PIN_TGZ" ]; then
    echo "[verify] missing $PIN_TGZ" >&2
    exit 2
fi

# Tarball layout: src/webkit-pin/<files> — 2 prefix components
STRIP=2
PREFIX="src/webkit-pin/"
echo "[verify] tarball prefix: $PREFIX (strip-components=$STRIP)"

# Collect all patch directories in apply order, matching the build workflow
PATCH_DIRS=("$REPO_ROOT/webkit/patches/common" "$REPO_ROOT/webkit/patches/windows")

# Add enabled change lanes — scan changes/*/patches/ directories that exist
for lane_dir in "$REPO_ROOT"/changes/*/patches; do
    [ -d "$lane_dir" ] || continue
    lane="$(basename "$(dirname "$lane_dir")")"
    [ -d "$lane_dir/common" ] && PATCH_DIRS+=("$lane_dir/common")
    [ -d "$lane_dir/windows" ] && PATCH_DIRS+=("$lane_dir/windows")
done

# Build list of all patches
ALL_PATCHES=()
for dir in "${PATCH_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r -d '' p; do
        ALL_PATCHES+=("$p")
    done < <(find "$dir" -maxdepth 1 -type f -name '*.patch' -print0 | sort -z)
done

echo "[verify] ${#ALL_PATCHES[@]} patches from ${#PATCH_DIRS[@]} directories"

# Build file list from all patches (skip new-file entries: --- /dev/null)
mkdir -p "$WORK"
for p in "${ALL_PATCHES[@]}"; do
    grep -h '^--- a/' "$p" 2>/dev/null || true
done | sed 's|^--- a/||' | awk '{print $1}' | sort -u > "$WORK/files.list"

if [ ! -s "$WORK/files.list" ]; then
    echo "[verify] warning: no existing files to extract (all patches create new files?)"
fi

# Prefix for tar extraction
sed "s|^|${PREFIX}|" "$WORK/files.list" > "$WORK/tar-paths.list"

# Extract only the files patches touch
TREE="$WORK/tree"
rm -rf "$TREE"
mkdir -p "$TREE"
tar xzf "$PIN_TGZ" --strip-components="$STRIP" -C "$TREE" \
    -T "$WORK/tar-paths.list" 2>/dev/null || true

# Also extract new files that patches create (they won't be in the tarball)
# — that's fine, git apply handles new files without needing them on disk.

cd "$TREE"
git init -q
git add -A
git -c user.email=verify@local -c user.name=verify commit -q -m "pin baseline" --allow-empty

PASS=0; FAIL=0; FAILS=""

for p in "${ALL_PATCHES[@]}"; do
    n="$(basename "$p")"
    # Strip CRLF from patches (same as build workflow)
    clean="$WORK/clean-$n"
    sed 's/\r$//' "$p" > "$clean"
    if git apply --check --whitespace=nowarn --unidiff-zero "$clean" 2>/dev/null; then
        printf '  pass  %s\n' "$n"
        git apply --whitespace=nowarn --unidiff-zero "$clean" >/dev/null 2>&1
        git add -A
        git -c user.email=verify@local -c user.name=verify commit -q -m "$n" 2>/dev/null || true
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %s\n' "$n"
        FAILS="$FAILS $n"
        FAIL=$((FAIL + 1))
    fi
done

echo
echo "[verify] pass=$PASS fail=$FAIL total=${#ALL_PATCHES[@]}"
if [ $FAIL -gt 0 ]; then
    echo "[verify] failures:$FAILS"
    exit 1
fi
echo "[verify] every patch applies cleanly to the pin."
