#!/usr/bin/env bash
# Copy pinned WebKit + JavaScriptCore into an iOS .app for in-process embed.
# Usage: ios_embed_webkit_frameworks.sh <Webkitium.app> <WebKitBuild/Debug-or-Release>
set -euo pipefail

APP="${1:?Webkitium.app path}"
ENGINE="${2:?WebKit build output directory}"

[[ -d "$APP" ]] || { echo "::error::App bundle not found: $APP"; exit 1; }
[[ -d "$ENGINE" ]] || { echo "::error::Engine dir not found: $ENGINE"; exit 1; }

FRAMEWORKS="$APP/Frameworks"
mkdir -p "$FRAMEWORKS"

for name in WebKit JavaScriptCore; do
  src=""
  for candidate in \
    "$ENGINE/$name.framework" \
    "$ENGINE/lib/$name.framework" \
    "$ENGINE/../$name.framework"; do
    if [[ -d "$candidate" ]]; then
      src="$candidate"
      break
    fi
  done
  if [[ -z "$src" ]]; then
    found="$(find "$ENGINE" -maxdepth 4 -type d -name "$name.framework" 2>/dev/null | head -1)"
    [[ -n "$found" ]] && src="$found"
  fi
  [[ -n "$src" ]] || { echo "::error::$name.framework not found under $ENGINE"; exit 1; }
  rm -rf "$FRAMEWORKS/$(basename "$src")"
  cp -R "$src" "$FRAMEWORKS/"
  echo "Embedded $(basename "$src") from $src"
done

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --deep "$APP" 2>/dev/null || true
fi

echo "IOS_EMBED_OK app=$APP"
