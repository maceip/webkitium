#!/usr/bin/env bash
# Build pinned WebKitGTK chrome + run harness smokes (requires Linux + AT-SPI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${WEBKIT_GTK_BUILD:-}" ]]; then
  if pkg-config --exists webkitgtk-6.0 2>/dev/null; then
    export WEBKIT_GTK_BUILD="${WEBKIT_GTK_BUILD:-/usr}"
    echo "note: WEBKIT_GTK_BUILD unset — using system webkitgtk-6.0 (/usr pkg-config)"
  else
    echo "error: WEBKIT_GTK_BUILD must point at pinned WebKitGTK Debug tree" >&2
    exit 1
  fi
fi

export PKG_CONFIG_PATH="${WEBKIT_GTK_BUILD}/lib/pkgconfig:${WEBKIT_GTK_BUILD}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

echo "==> chrome/linux release build"
(cd "$ROOT/chrome/linux" && cargo build --release)

BIN="$ROOT/chrome/linux/target/release/webkitium"
export WEBKITIUM_BIN="$BIN"

bash "$ROOT/scripts/gen_harness_linux_tests.sh"

echo "==> harness_linux (ignored smokes — need display + AT-SPI)"
RUN_HARNESS='cd "'"$ROOT"'/harness_linux" && cargo build --lib && GDK_BACKEND=wayland GTK_A11Y=atspi cargo test --test required_smokes -- --ignored --nocapture --test-threads=1'
if command -v wayland-headless-run >/dev/null 2>&1; then
  wayland-headless-run dbus-run-session -- bash -lc "$RUN_HARNESS" || {
    echo "note: harness failed under wayland-headless-run (see log)"
  }
else
  (cd "$ROOT/harness_linux" && cargo test -- --ignored --nocapture 2>&1) || {
    echo "note: harness may skip if AT-SPI/display unavailable"
  }
fi

echo "==> manual smoke hint"
echo "  GDK_BACKEND=wayland WEBKITIUM_LAUNCH_URL=https://example.com $BIN"
