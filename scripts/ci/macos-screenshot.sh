#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

if [[ -z "$APP" || ! -f "$APP" ]]; then
  echo "ERROR: Binary not found: $APP"
  exit 1
fi

# Run the app directly (not via .app bundle) with env vars to force window
echo "Launching $APP directly..."
NSAppTransportSecurity=1 "$APP" &
APP_PID=$!
sleep 10

echo "PID: $APP_PID alive: $(kill -0 $APP_PID 2>/dev/null && echo YES || echo NO)"
screencapture -x "$OUT"

kill $APP_PID 2>/dev/null || true
echo "Done: $OUT"
