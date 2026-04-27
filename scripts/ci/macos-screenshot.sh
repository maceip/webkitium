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

# Use ScreenCaptureKit (macOS 15+) via Swift to capture the screen
cat > /tmp/capture.swift << 'SWIFT'
import ScreenCaptureKit
import Cocoa

@main struct Capturer {
    static func main() async throws {
        let outPath = CommandLine.arguments[1]
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            print("No displays found")
            Foundation.exit(1)
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("PNG conversion failed")
            Foundation.exit(1)
        }
        try data.write(to: URL(fileURLWithPath: outPath))
        print("Captured \(image.width)x\(image.height) to \(outPath)")
    }
}
SWIFT

swiftc /tmp/capture.swift -o /tmp/capture -framework ScreenCaptureKit -framework Cocoa -parse-as-library 2>&1
/tmp/capture "$OUT" 2>&1 || {
  echo "ScreenCaptureKit failed, falling back to screencapture -x"
  screencapture -x "$OUT"
}

kill $PID 2>/dev/null || true
pkill -f "Webkitium.app/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
