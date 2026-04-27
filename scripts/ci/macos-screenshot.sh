#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "Binary not found: $APP"
  exit 1
fi

# Wrap in a .app bundle so WindowServer creates a real window
BUNDLE="$(mktemp -d)/Webkitium.app"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$APP" "$BUNDLE/Contents/MacOS/webkitium"

cat > "$BUNDLE/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>webkitium</string>
<key>CFBundleIdentifier</key><string>dev.webkitium.Browser</string>
<key>CFBundleName</key><string>Webkitium</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

echo "Launching $BUNDLE"
open -a "$BUNDLE"
sleep 5

# Bring to front
osascript -e 'tell application "Webkitium" to activate' 2>/dev/null || true
# Also try by process name
osascript -e 'tell application "System Events" to set frontmost of process "webkitium" to true' 2>/dev/null || true
sleep 5

# List visible windows for debugging
osascript -e 'tell application "System Events" to get name of every process whose visible is true' 2>/dev/null || true
osascript -e 'tell application "System Events" to get {name, position, size} of every window of process "webkitium"' 2>/dev/null || true

screencapture -x "$OUT"
pkill -f "$BUNDLE/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
