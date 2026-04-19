#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

PLATFORM="${1:?usage: apply-patches.sh <platform> <source-dir>}"
SOURCE_DIR="${2:?usage: apply-patches.sh <platform> <source-dir>}"

apply_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f \( -name '*.patch' -o -name '*.diff' \) | sort | while read -r patch_file; do
    echo "Applying $(basename "$patch_file") to $SOURCE_DIR"
    git -C "$SOURCE_DIR" apply --index "$patch_file" || git -C "$SOURCE_DIR" apply "$patch_file"
  done
}

git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null

# Optional lanes (changes/) first — same script as standalone apply-changes.
"$SCRIPT_DIR/apply-changes.sh" "$PLATFORM" "$SOURCE_DIR"

# Single WebKit patch tree: webkit/patches/ in-repo; bundled Android layout mirrors this under ng/.
if [[ -d "$NG_ROOT/webkit/patches" ]]; then
  PATCH_ROOT="$NG_ROOT/webkit/patches"
else
  PATCH_ROOT="$NG_ROOT/patches"
fi
apply_dir "$PATCH_ROOT/common"
apply_dir "$PATCH_ROOT/$PLATFORM"
