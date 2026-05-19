#!/usr/bin/env bash
# Launch per-platform chrome against a bundled or local engine tree.
# Usage: run_chrome_with_engine.sh <platform> [engine-root]
set -euo pipefail

PLATFORM="${1:?windows|macos|linux-gtk|ios|android}"
ENGINE="${2:-}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

case "$PLATFORM" in
  windows)
    ENGINE="${ENGINE:-C:/W/webkit-src/WebKitBuild/Debug}"
    export WEBKITIUM_LAUNCH_URL="${WEBKITIUM_LAUNCH_URL:-https://example.com}"
    dotnet run --project "$repo_root/chrome/windows/Webkitium/Webkitium.csproj" -c Debug -p:Platform=x64 \
      /p:WebKitSrc="${ENGINE%/WebKitBuild/*}" \
      /p:WebKitBuild="$ENGINE"
    ;;
  macos)
    ENGINE="${ENGINE:-$HOME/webkit-src/WebKitBuild/Debug}"
    export WEBKIT_FRAMEWORK_PATH="$ENGINE:$ENGINE/WebKit.framework"
    export DYLD_FRAMEWORK_PATH="${WEBKIT_FRAMEWORK_PATH}${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
    cd "$repo_root/chrome/macos"
    swift build -c debug
    exec "$(find .build -name Webkitium -type f -perm +111 | head -1)"
    ;;
  linux-gtk)
    ENGINE="${ENGINE:-$HOME/webkit-src/WebKitBuild/GTK/Debug}"
    export WEBKIT_GTK_BUILD="$ENGINE"
    export PKG_CONFIG_PATH="$ENGINE/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    cd "$repo_root/chrome/linux"
    cargo run --release
    ;;
  *)
    echo "Use platform CI bundle for $PLATFORM or see chrome/$PLATFORM/README.md" >&2
    exit 2
    ;;
esac
