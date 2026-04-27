#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "ERROR: Binary not found: $APP"
  exit 1
fi

echo "Running $APP with WEBKITIUM_SCREENSHOT_PATH=$OUT"
# Run the binary directly with the screenshot path
# MacOSMain.swift will create an NSWindow, wait 8 seconds, capture it, and exit
WEBKITIUM_SCREENSHOT_PATH="$OUT" "$APP" &
PID=$!

# Wait for the app to finish (it exits after taking the screenshot)
for i in $(seq 1 30); do
  if ! kill -0 $PID 2>/dev/null; then
    echo "App exited after ${i}s"
    break
  fi
  sleep 1
done

# Kill if still running
kill $PID 2>/dev/null || true

if [[ -f "$OUT" ]]; then
  echo "Screenshot: $OUT ($(wc -c < "$OUT") bytes)"
else
  echo "ERROR: Screenshot not created! Falling back to screencapture..."
  screencapture -x "$OUT"
fi
