#!/usr/bin/env bash
# Fast local guard for WebKit patch edits. Point WEBKIT_ROOT at a clean checkout
# of matrix.webkit.expectedCommit, or pass the checkout path as argv[1].

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBKIT_ROOT="${1:-${WEBKIT_ROOT:-${NG_WEBKIT_ROOT:-}}}"
PLATFORM="${PLATFORM:-windows}"

if [[ -z "$WEBKIT_ROOT" ]]; then
  echo "usage: WEBKIT_ROOT=/path/to/WebKit $0 [webkit-root]" >&2
  echo "The checkout must match config/webkit-build-matrix.json." >&2
  exit 2
fi

python3 "$ROOT/config/apply_webkit_patches.py" \
  --repo-root "$ROOT" \
  --webkit-root "$WEBKIT_ROOT" \
  --platform "$PLATFORM" \
  --mode check
