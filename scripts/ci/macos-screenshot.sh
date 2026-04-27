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
<key>LSBackgroundOnly</key><false/>
</dict></plist>
EOF

echo "=== Session info ==="
who
echo "---"
stat -f '%Su' /dev/console
echo "---"
defaults read /Library/Preferences/com.apple.loginwindow 2>/dev/null | head -5 || true
echo "---"
launchctl print gui/$(stat -f %u /dev/console) 2>/dev/null | head -3 || true
echo "=== Launching ==="

open -Fna "$BUNDLE"
sleep 8

PID=$(pgrep -f "Webkitium.app/Contents/MacOS/webkitium" || true)
echo "PID: ${PID:-DEAD}"

# Try activate
osascript -e 'tell application "Webkitium" to activate' &
ASCRIPT=$!; sleep 3; kill $ASCRIPT 2>/dev/null || true

screencapture -x "$OUT"

kill $PID 2>/dev/null || true
pkill -f "Webkitium.app" 2>/dev/null || true
echo "Done: $OUT"
