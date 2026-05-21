#!/usr/bin/env bash
# Check whether the current Webkitium patch stack applies to official WebKit.
#
# This does not update config/webkit-build-matrix.json and does not re-cut the
# webkit-pin release. It creates a disposable worktree from official WebKit and
# runs config/apply_webkit_patches.py with --skip-pin-check.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${WEBKIT_MATRIX_PATH:-$ROOT/config/webkit-build-matrix.json}"
REF="main"
KEEP_WORKTREE=0
BASE_ONLY=0
PLATFORMS=()

usage() {
  cat <<'USAGE'
usage: scripts/evaluate_webkit_head_patch_stack.sh [options]

Options:
  --ref REF             Official WebKit ref to test (default: main)
  --platform NAME       Platform patch stack to test. Repeatable.
                        Defaults to windows macos ios linux.
  --base-only           Test only webkit/patches and skip enabled changes/* lanes.
  --keep-worktree       Leave the evaluated WebKit worktree on disk.
  -h, --help            Show this help.

Environment:
  WEBKIT_UPSTREAM_CACHE      Bare cache path for official WebKit.
  WEBKIT_HEAD_WORKTREE       Worktree path to use for the selected ref.
  WEBKIT_MATRIX_PATH         Matrix path, defaults to config/webkit-build-matrix.json.
USAGE
}

while (($#)); do
  case "$1" in
    --ref)
      REF="${2:?--ref requires a value}"
      shift 2
      ;;
    --platform)
      PLATFORMS+=("${2:?--platform requires a value}")
      shift 2
      ;;
    --keep-worktree)
      KEEP_WORKTREE=1
      shift
      ;;
    --base-only)
      BASE_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ((${#PLATFORMS[@]} == 0)); then
  PLATFORMS=(windows macos ios linux)
fi

PYTHON="${PYTHON:-$(command -v python3 2>/dev/null || command -v python)}"
[[ -n "$PYTHON" ]] || { echo "error: python not found" >&2; exit 1; }

read_matrix_field() {
  "$PYTHON" - "$MATRIX" "$1" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value = data
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

UPSTREAM_URL="$(read_matrix_field "webkit.upstream.url")"
OFFICIAL_URL="https://github.com/WebKit/WebKit.git"
if [[ "${UPSTREAM_URL%.git}" != "${OFFICIAL_URL%.git}" ]]; then
  echo "error: matrix WebKit upstream is not official: $UPSTREAM_URL" >&2
  exit 1
fi

CACHE="${WEBKIT_UPSTREAM_CACHE:-$HOME/.cache/webkitium/upstream/WebKit.git}"
mkdir -p "$(dirname "$CACHE")"

if [[ ! -d "$CACHE" ]]; then
  git clone --filter=blob:none --bare "$UPSTREAM_URL" "$CACHE"
else
  git -C "$CACHE" remote set-url origin "$UPSTREAM_URL"
fi

git -C "$CACHE" fetch --filter=blob:none origin "$REF"
COMMIT="$(git -C "$CACHE" rev-parse FETCH_HEAD)"

WORKTREE="${WEBKIT_HEAD_WORKTREE:-${TMPDIR:-/tmp}/webkitium-webkit-${COMMIT:0:12}}"
git -C "$CACHE" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
rm -rf "$WORKTREE"
git -C "$CACHE" worktree add --detach --no-checkout "$WORKTREE" "$COMMIT"
git -C "$WORKTREE" config core.autocrlf false
git -C "$WORKTREE" config core.eol lf
git -C "$WORKTREE" sparse-checkout init --no-cone
git -C "$WORKTREE" sparse-checkout set Source Tools vcpkg.json
git -C "$WORKTREE" reset --hard HEAD >/dev/null

CHANGES_FILE="$ROOT/config/changes.json"
TEMP_CHANGES=""
if [[ "$BASE_ONLY" == "1" ]]; then
  TEMP_CHANGES="$(mktemp "${TMPDIR:-/tmp}/webkitium-empty-changes.XXXXXX.json")"
  printf '{"activeChanges":[]}\n' > "$TEMP_CHANGES"
  CHANGES_FILE="$TEMP_CHANGES"
fi

cleanup() {
  [[ -n "$TEMP_CHANGES" ]] && rm -f "$TEMP_CHANGES"
  if [[ "$KEEP_WORKTREE" != "1" ]]; then
    git -C "$CACHE" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    rm -rf "$WORKTREE"
  else
    echo "Kept WebKit worktree: $WORKTREE"
  fi
}
trap cleanup EXIT

echo "Official WebKit ref: $REF"
echo "Official WebKit commit: $COMMIT"
echo "Patch platforms: ${PLATFORMS[*]}"
if [[ "$BASE_ONLY" == "1" ]]; then
  echo "Change lanes: disabled"
fi

for platform in "${PLATFORMS[@]}"; do
  "$PYTHON" "$ROOT/config/apply_webkit_patches.py" \
    --repo-root "$ROOT" \
    --matrix "$MATRIX" \
    --changes "$CHANGES_FILE" \
    --webkit-root "$WORKTREE" \
    --platform "$platform" \
    --skip-pin-check \
    --mode apply
done
