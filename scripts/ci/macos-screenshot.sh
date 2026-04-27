#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "ERROR: Binary not found: $APP"
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

echo "Launching $BUNDLE ..."
open -a "$BUNDLE"
sleep 3

# Check if process is alive
PID=$(pgrep -f "Webkitium.app/Contents/MacOS/webkitium" || true)
echo "PID: ${PID:-DEAD}"

if [[ -z "$PID" ]]; then
  echo "App crashed on launch. Trying direct execution with log..."
  "$BUNDLE/Contents/MacOS/webkitium" &> /tmp/webkitium-launch.log &
  PID=$!
  sleep 8
  echo "=== Launch log ==="
  cat /tmp/webkitium-launch.log 2>/dev/null || true
  echo "=== end log ==="
  echo "Process alive after direct launch: $(kill -0 $PID 2>/dev/null && echo YES || echo NO)"
fi

sleep 5

# Write a Swift helper to capture screen using CGWindowListCreateImage
cat > /tmp/capture.swift << 'SWIFT'
import Cocoa
let img = CGWindowListCreateImage(
    CGRect.null,
    .optionOnScreenOnly,
    kCGNullWindowID,
    .bestResolution)
guard let img = img else {
    print("CGWindowListCreateImage returned nil")
    exit(1)
}
let rep = NSBitmapImageRep(cgImage: img)
guard let data = rep.representation(using: .png, properties: [:]) else {
    print("PNG conversion failed")
    exit(1)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try data.write(to: url)
print("Captured \(img.width)x\(img.height) to \(url.path)")
SWIFT

swiftc /tmp/capture.swift -o /tmp/capture -framework Cocoa 2>&1
/tmp/capture "$OUT" 2>&1 || {
  echo "Swift capture failed, falling back to screencapture"
  screencapture -x "$OUT"
}

kill $PID 2>/dev/null || true
pkill -f "Webkitium.app/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
