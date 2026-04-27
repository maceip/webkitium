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

# Try to bring to front
osascript -e 'tell application "Webkitium" to activate' 2>&1 || true
osascript -e 'tell application "System Events" to set frontmost of process "webkitium" to true' 2>&1 || true
sleep 3

# Debug: list all windows
echo "=== Window list ==="
osascript -e 'tell application "System Events" to get name of every process whose visible is true' 2>&1 || true
echo "=== webkitium windows ==="
osascript -e 'tell application "System Events" to get properties of every window of process "webkitium"' 2>&1 || true
echo "=== all windows ==="
python3 -c "
import subprocess, json
out = subprocess.check_output(['osascript', '-e',
  'tell application \"System Events\" to get {name, position, size} of every window of every process'
], stderr=subprocess.DEVNULL, timeout=5).decode()
print(out[:500])
" 2>&1 || true

# Capture: try window-specific first via CGWindowList
python3 -c "
import Quartz, sys
opts = Quartz.kCGWindowListOptionAll
wl = Quartz.CGWindowListCopyWindowInfo(opts, Quartz.kCGNullWindowID)
for w in wl:
    name = w.get('kCGWindowOwnerName','')
    if 'webkitium' in name.lower() or 'Webkitium' in name:
        wid = w['kCGWindowNumber']
        img = Quartz.CGWindowListCreateImage(Quartz.CGRectNull, Quartz.kCGWindowListOptionIncludingWindow, wid, Quartz.kCGWindowImageDefault)
        if img:
            from Cocoa import NSBitmapImageRep, NSPNGFileType
            rep = NSBitmapImageRep.alloc().initWithCGImage_(img)
            data = rep.representationUsingType_properties_(NSPNGFileType, None)
            data.writeToFile_atomically_('$OUT', True)
            print(f'Captured window {wid} of {name}')
            sys.exit(0)
print('No webkitium window found in CGWindowList')
for w in wl[:5]:
    print(f'  {w.get(\"kCGWindowOwnerName\",\"?\")} layer={w.get(\"kCGWindowLayer\",\"?\")}')
sys.exit(1)
" 2>&1 && { echo "Window capture OK"; } || {
  echo "Window capture failed, falling back to full screen"
  screencapture -x "$OUT"
}

pkill -f "$BUNDLE/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
