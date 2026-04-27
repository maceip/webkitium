#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "ERROR: Binary not found: $APP"
  exit 1
fi

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

echo "Bundle: $BUNDLE"

# Launch the app
open -Fna "$BUNDLE" --stdout /tmp/wk-stdout.log --stderr /tmp/wk-stderr.log
sleep 3

PID=$(pgrep -f "Webkitium.app/Contents/MacOS/webkitium" || true)
echo "PID: ${PID:-DEAD}"

if [[ -z "$PID" ]]; then
  echo "App did not start via open, trying direct launch..."
  "$BUNDLE/Contents/MacOS/webkitium" &>/tmp/wk-direct.log &
  PID=$!
  sleep 5
fi

# Use AppleScript to force the app to front and open its window
osascript <<'AS' &
tell application "System Events"
  set frontmost of (first process whose unix id is THEPID) to true
end tell
AS
ASPID=$!
sleep 2
kill $ASPID 2>/dev/null || true

# Also try clicking on the app's dock icon via AppleScript
osascript -e 'tell application "Webkitium" to activate' &
ASPID2=$!
sleep 3
kill $ASPID2 2>/dev/null || true

echo "=== stdout ===" && head -20 /tmp/wk-stdout.log 2>/dev/null || true
echo "=== stderr ===" && head -20 /tmp/wk-stderr.log 2>/dev/null || true

# Capture the screen
screencapture -x "$OUT"

# Also try window-specific capture
screencapture -x -l"$(osascript -e 'tell application "System Events" to get id of first window of (first process whose unix id is '"$PID"')' 2>/dev/null || echo 0)" "${OUT%.png}_window.png" 2>/dev/null || true

kill "$PID" 2>/dev/null || true
echo "Done: $OUT"
