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

echo "Launching $BUNDLE"
# Launch directly to capture all output
"$BUNDLE/Contents/MacOS/webkitium" > /tmp/webkitium-stdout.log 2> /tmp/webkitium-stderr.log &
APP_PID=$!
sleep 8

echo "PID: $APP_PID alive: $(kill -0 $APP_PID 2>/dev/null && echo YES || echo NO)"
echo "=== STDOUT ==="
head -20 /tmp/webkitium-stdout.log 2>/dev/null || true
echo "=== STDERR ==="
head -20 /tmp/webkitium-stderr.log 2>/dev/null || true
echo "=== WINDOW LIST ==="
# List all windows with their owners
/usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null | head -10 || true

screencapture -x "$OUT"

kill $APP_PID 2>/dev/null || true
echo "Done: $OUT"
