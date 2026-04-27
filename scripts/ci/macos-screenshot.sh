#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "ERROR: Binary not found: $APP"
  exit 1
fi

# Run the binary directly -- it's now a pure AppKit app (MacOSMain.swift)
# that creates an NSWindow, so it should show up immediately
"$APP" &
PID=$!
echo "Launched PID=$PID"
sleep 10

echo "Alive: $(kill -0 $PID 2>/dev/null && echo YES || echo NO)"

# Capture
screencapture -x "$OUT"

kill $PID 2>/dev/null || true
echo "Done: $OUT ($(wc -c < "$OUT") bytes)"
