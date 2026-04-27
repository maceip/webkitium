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

# Test: can we create a visible AppKit window at all?
cat > /tmp/test_window.swift <<'SWIFT'
import Cocoa
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
let w = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
                 styleMask: [.titled, .closable, .resizable],
                 backing: .buffered, defer: false)
w.title = "Webkitium Display Test"
w.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1)
w.isReleasedWhenClosed = false
w.makeKeyAndOrderFront(nil)
let label = NSTextField(labelWithString: "If you see this, the display works")
label.font = NSFont.systemFont(ofSize: 20, weight: .medium)
label.textColor = .white
label.backgroundColor = .clear
label.isBezeled = false
label.isEditable = false
label.frame = NSRect(x: 50, y: 280, width: 700, height: 30)
w.contentView?.addSubview(label)
print("Window created: \(w.isVisible) frame=\(w.frame)")
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    t.arguments = ["-x", "/tmp/display_test.png"]
    try? t.run()
    t.waitUntilExit()
    print("Test screenshot taken")
    app.terminate(nil)
}
app.run()
SWIFT
echo "Compiling test window..."
swiftc /tmp/test_window.swift -o /tmp/test_window -framework Cocoa 2>&1
echo "Running test window..."
/tmp/test_window 2>&1 || echo "Test window failed"

if [ -f /tmp/display_test.png ]; then
  echo "Display test succeeded, launching real app..."
  open -Fna "$BUNDLE"
  sleep 10
  screencapture -x "$OUT"
  pkill -f "Webkitium.app" 2>/dev/null || true
else
  echo "Display test failed, using screencapture only..."
  open -Fna "$BUNDLE"
  sleep 8
  screencapture -x "$OUT"
  pkill -f "Webkitium.app" 2>/dev/null || true
fi

echo "Done: $OUT"
