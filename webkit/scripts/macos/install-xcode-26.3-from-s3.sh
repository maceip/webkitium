#!/bin/bash
# Run on macOS builder (root or sudo). Installs CLT 26.3 dmg + Xcode 26.3 xip from S3.
set -euxo pipefail
export HOME="${HOME:-/var/root}"
WORKDIR="${WORKDIR:-/tmp/ng-xcode263-install}"
BUCKET_PREFIX="${NG_MACOS_XCODE263_S3:-s3://cory-build-artifacts-euc1-095713295645-20260407/ng-webkit/macos/toolchain-xcode26.3-20260416}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

aws s3 cp "$BUCKET_PREFIX/Xcode_26.3_Apple_silicon.xip" .
aws s3 cp "$BUCKET_PREFIX/Command_Line_Tools_for_Xcode_26.3.dmg" .

# Command Line Tools (pkg inside dmg)
MNT=$(mktemp -d /tmp/clt-mount.XXXXXX)
hdiutil attach "Command_Line_Tools_for_Xcode_26.3.dmg" -mountpoint "$MNT" -nobrowse
PKG=$(find "$MNT" -maxdepth 4 -name '*.pkg' | head -1)
if [[ -n "${PKG:-}" ]]; then
  installer -pkg "$PKG" -target /
fi
hdiutil detach "$MNT" -force || true
rmdir "$MNT" 2>/dev/null || true

# Full Xcode (Apple Silicon bundle)
if [[ -d /Applications/Xcode.app ]]; then
  mv /Applications/Xcode.app "/Applications/Xcode.app.backup-$(date +%Y%m%d%H%M%S)"
fi
# macOS xip uses --expand (double dash); -expand breaks option parsing.
(cd /Applications && xip --expand "$WORKDIR/Xcode_26.3_Apple_silicon.xip")

/usr/bin/xcode-select -s /Applications/Xcode.app/Contents/Developer
/usr/bin/xcodebuild -version
/usr/bin/sw_vers
