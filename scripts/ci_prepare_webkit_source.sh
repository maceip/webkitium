#!/usr/bin/env bash
# Prepare a disposable WebKit source worktree from the matrix-pinned checkout.
#
# The first run on a runner downloads/extracts the webkit-pin release into a
# SHA-specific cache. Later jobs create git worktrees from that cache instead of
# downloading and extracting the multi-GB archive again.

set -euo pipefail

DEST="${1:?usage: ci_prepare_webkit_source.sh DEST_PATH [CACHE_PATH]}"
ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${WEBKIT_MATRIX_PATH:-$ROOT/config/webkit-build-matrix.json}"
VERIFY="$ROOT/config/verify_webkit_pin_commit.py"

command -v gh >/dev/null 2>&1 || { echo "::error::gh CLI not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "::error::git not found on PATH"; exit 1; }
command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || { echo "::error::python not found"; exit 1; }
PYTHON="${PYTHON:-$(command -v python3 2>/dev/null || command -v python)}"

EXPECTED_COMMIT="$("$PYTHON" -c "import json, pathlib; print(json.load(pathlib.Path('$MATRIX').open())['webkit']['expectedCommit'])")"
CACHE="${2:-${WEBKIT_PIN_CACHE:-}}"
if [[ -z "$CACHE" ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    CACHE="$(cygpath -u "C:/W/webkit-pin-cache/$EXPECTED_COMMIT")"
  else
    CACHE="${HOME}/.cache/webkitium/webkit-pin/$EXPECTED_COMMIT"
  fi
fi

git_safe() {
  git -c "safe.directory=$1" -C "$1" "${@:2}"
}

remove_path() {
  local path="$1"
  rm -rf "$path" || {
    if command -v cygpath >/dev/null 2>&1; then
      local win_path
      win_path="$(cygpath -w "$path")"
      cmd //c "rd /s /q \"$win_path\"" 2>/dev/null || true
    fi
  }
}

verify_checkout() {
  local path="$1"
  [[ -d "$path/.git" ]] || return 1
  "$PYTHON" "$VERIFY" --matrix "$MATRIX" --webkit-root "$path" >/dev/null
}

ensure_cache() {
  if verify_checkout "$CACHE"; then
    echo "Using cached WebKit pin at $CACHE"
    return
  fi

  echo "Refreshing WebKit pin cache at $CACHE"
  remove_path "$CACHE"
  mkdir -p "$(dirname "$CACHE")"

  local temp_root archive extract_dir
  temp_root="${RUNNER_TEMP:-$(dirname "$CACHE")}/webkit-pin-download-$$"
  archive="$temp_root/webkit-pin.tar.gz"
  extract_dir="$temp_root/extract"
  remove_path "$temp_root"
  mkdir -p "$temp_root" "$extract_dir"

  gh release download "${WEBKIT_PIN_RELEASE_TAG:?WEBKIT_PIN_RELEASE_TAG missing}" \
    --repo "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY missing}" \
    --pattern "${WEBKIT_PIN_PART_GLOB:?WEBKIT_PIN_PART_GLOB missing}" \
    --dir "$temp_root"

  shopt -s nullglob
  for f in "$temp_root"/${WEBKIT_PIN_PART_GLOB}$'\r'; do
    [[ -e "$f" ]] && mv -- "$f" "${f%$'\r'}"
  done
  local parts=( "$temp_root"/${WEBKIT_PIN_PART_GLOB} )
  if (( ${#parts[@]} == 0 )); then
    echo "::error::No tarball parts found after download"
    exit 1
  fi
  cat "${parts[@]}" > "$archive"
  shopt -u nullglob
  [[ -s "$archive" ]] || { echo "::error::Stitched webkit-pin archive is empty"; exit 1; }

  tar -xzf "$archive" --strip-components=1 -C "$extract_dir" \
    --exclude='*/LayoutTests/*' \
    --exclude='*/WebKitLibraries/SDKs/*' \
    --exclude='*/Websites/*' \
    --exclude='*/JSTests/*' \
    || true

  "$PYTHON" "$VERIFY" --matrix "$MATRIX" --webkit-root "$extract_dir"
  mv "$extract_dir" "$CACHE"
  remove_path "$temp_root"
}

ensure_cache

git_safe "$CACHE" worktree prune
git_safe "$CACHE" worktree remove --force "$DEST" >/dev/null 2>&1 || true
remove_path "$DEST"
mkdir -p "$(dirname "$DEST")"
git_safe "$CACHE" worktree add --detach "$DEST" HEAD
"$PYTHON" "$VERIFY" --matrix "$MATRIX" --webkit-root "$DEST"

echo "Source ready at $DEST"
