#!/usr/bin/env bash
# Merge packaging/macos/Info.plist.template keys into an existing .app Info.plist.
# Usage: apply-macos-plist-to-app.sh /path/to/MiniBrowser.app
set -euo pipefail
APP="${1:?usage: $0 MiniBrowser.app}"
PLIST="$APP/Contents/Info.plist"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp)"
/usr/libexec/PlistBuddy -c 'Print' "$PLIST" &>/dev/null || { echo "::error::Missing or invalid plist: $PLIST"; exit 1; }
cp "$PLIST" "$TMP"
# Bluetooth usage strings (required if binary links Bluetooth frameworks / uses CBCentral)
/usr/libexec/PlistBuddy -c "Add :NSBluetoothAlwaysUsageDescription string 'Required for security keys and passkeys that use Bluetooth (WebAuthn).'" "$TMP" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSBluetoothAlwaysUsageDescription 'Required for security keys and passkeys that use Bluetooth (WebAuthn).'" "$TMP"
/usr/libexec/PlistBuddy -c "Add :NSBluetoothPeripheralUsageDescription string 'Required for Bluetooth security keys (WebAuthn).'" "$TMP" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSBluetoothPeripheralUsageDescription 'Required for Bluetooth security keys (WebAuthn).'" "$TMP"
cp "$TMP" "$PLIST"
rm -f "$TMP"
echo "Updated $PLIST with WebAuthn Bluetooth usage strings."
