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

# Use Swift to launch the app and force-activate it
swift - "$BUNDLE" "$OUT" <<'SWIFT'
import Cocoa
import Foundation

let bundle = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]

let url = URL(fileURLWithPath: bundle)
let config = NSWorkspace.OpenConfiguration()
config.activates = true
config.createsNewApplicationInstance = true

let sem = DispatchSemaphore(value: 0)
var app: NSRunningApplication?

NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, error in
    if let error = error {
        print("Launch error: \(error)")
    }
    app = runningApp
    sem.signal()
}
sem.wait()
print("Launched: \(app?.localizedName ?? "nil") pid=\(app?.processIdentifier ?? 0)")

// Wait for window to appear
Thread.sleep(forTimeInterval: 8)

// Force activate
app?.activate()
NSApplication.shared.activate(ignoringOtherApps: true)
Thread.sleep(forTimeInterval: 2)

// Take screenshot using screencapture
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
task.arguments = ["-x", outPath]
try task.run()
task.waitUntilExit()
print("Screenshot: \(outPath)")

app?.terminate()
SWIFT

echo "Done: $OUT"
