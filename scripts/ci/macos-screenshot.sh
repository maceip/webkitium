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

# Ensure PyObjC for Quartz window capture
python3 -m pip install --quiet pyobjc-framework-Quartz pyobjc-framework-Cocoa 2>&1 || true

# Launch the app
open -a "$BUNDLE"
sleep 8

# List all windows via Quartz CGWindowList to find ours
python3 << 'PYEOF'
import sys
try:
    import Quartz
    wl = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
    print(f"Total windows: {len(wl)}")
    for w in wl:
        name = w.get('kCGWindowOwnerName', '')
        layer = w.get('kCGWindowLayer', -1)
        bounds = w.get('kCGWindowBounds', {})
        if layer == 0 and bounds.get('Width', 0) > 100:
            print(f"  [{name}] {bounds.get('Width')}x{bounds.get('Height')} layer={layer}")
except Exception as e:
    print(f"Quartz error: {e}")
PYEOF

# Try to capture the specific webkitium window via Quartz
python3 -c "
import sys
try:
    import Quartz
    from Cocoa import NSBitmapImageRep
    wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
    for w in wl:
        if 'webkitium' in w.get('kCGWindowOwnerName','').lower():
            wid = w['kCGWindowNumber']
            bounds = w.get('kCGWindowBounds', {})
            print(f'Found: wid={wid} {bounds}')
            img = Quartz.CGWindowListCreateImage(
                Quartz.CGRectNull,
                Quartz.kCGWindowListOptionIncludingWindow,
                wid,
                Quartz.kCGWindowImageBoundsIgnoreFraming)
            if img:
                rep = NSBitmapImageRep.alloc().initWithCGImage_(img)
                data = rep.representationUsingType_properties_(4, None)  # 4 = PNG
                data.writeToFile_atomically_('$OUT', True)
                print('Captured via Quartz')
                sys.exit(0)
    print('No webkitium window found, capturing full screen')
except Exception as e:
    print(f'Quartz capture failed: {e}')
sys.exit(1)
" 2>&1 || screencapture -x "$OUT"

pkill -f "Webkitium.app/Contents/MacOS/webkitium" 2>/dev/null || true
echo "Screenshot saved: $OUT"
