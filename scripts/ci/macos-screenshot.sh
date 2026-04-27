#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "Binary not found: $APP"
  exit 1
fi

# Wrap in .app bundle
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

# Get the GUI user's UID for launching into their session
GUI_UID=$(stat -f %u /dev/console 2>/dev/null || id -u)
echo "GUI session UID: $GUI_UID, current UID: $(id -u)"

# Launch into the GUI session
sudo launchctl asuser "$GUI_UID" open -a "$BUNDLE" 2>/dev/null \
  || open -a "$BUNDLE" 2>/dev/null \
  || "$BUNDLE/Contents/MacOS/webkitium" &
sleep 10

screencapture -x "$OUT"
pkill -f "Webkitium.app/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
