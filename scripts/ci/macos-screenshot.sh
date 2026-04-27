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

# Launch
open -Fna "$BUNDLE" --stdout /tmp/wk-out.log --stderr /tmp/wk-err.log
sleep 12

PID=$(pgrep -f "Webkitium.app/Contents/MacOS/webkitium" || true)
echo "PID: ${PID:-DEAD}"

echo "=== stdout ===" && cat /tmp/wk-out.log 2>/dev/null | head -10 || true
echo "=== stderr ===" && cat /tmp/wk-err.log 2>/dev/null | head -10 || true

# Check system log for our ForceWindow / activate messages
echo "=== System log ==="
log show --predicate "processIdentifier == $PID" --last 15s --style compact 2>/dev/null | head -20 || true

# Check if any windows exist via osascript
echo "=== Window check ==="
osascript -e 'tell application "System Events" to get name of every window of every process whose unix id is '"$PID" 2>&1 | head -5 || true

# Capture
screencapture -x "$OUT"

kill "$PID" 2>/dev/null || true
echo "Done: $OUT"
