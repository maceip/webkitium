#!/usr/bin/env bash
# Package pinned WebKit build output + per-platform chrome into one tarball.
#
# Usage:
#   bundle_webkitium_platform.sh <platform> <output.tar.gz> <engine-root> [chrome-root]

set -euo pipefail

PLATFORM="${1:?platform}"
OUT_TAR="${2:?output tar}"
ENGINE_ROOT="${3:?engine root}"
CHROME_ROOT="${4:-}"

if [[ ! -d "$ENGINE_ROOT" ]]; then
  echo "::error::engine root missing: $ENGINE_ROOT" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$STAGE/engine" "$STAGE/chrome"
cp -a "$ENGINE_ROOT/." "$STAGE/engine/"

if [[ -n "$CHROME_ROOT" ]]; then
  if [[ ! -e "$CHROME_ROOT" ]]; then
    echo "::error::chrome root missing: $CHROME_ROOT" >&2
    exit 1
  fi
  cp -a "$CHROME_ROOT/." "$STAGE/chrome/"
fi

SHORT_SHA="${GITHUB_SHA:-local}"
SHORT_SHA="${SHORT_SHA:0:7}"
MATRIX="${GITHUB_WORKSPACE:-}/config/webkit-build-matrix.json"
PIN=""
if [[ -f "$MATRIX" ]]; then
  PIN="$(python3 -c "import json, pathlib; print(json.load(pathlib.Path('$MATRIX').open())['webkit']['expectedCommit'])" 2>/dev/null || true)"
fi

export BUNDLE_STAGE="$STAGE"
export BUNDLE_PLATFORM="$PLATFORM"
export BUNDLE_PIN="$PIN"
export BUNDLE_SHA="$SHORT_SHA"
export BUNDLE_HAS_CHROME="$([[ -n "$CHROME_ROOT" ]] && echo true || echo false)"
python3 <<'PY'
import json, os
from datetime import datetime, timezone

platform = os.environ["BUNDLE_PLATFORM"]
embed = {
    "windows": "chrome uses WKView (webkitium_host.dll) when built with WebKitSrc/WebKitBuild",
    "macos": "chrome launches pinned MiniBrowser (WEBKIT_MINIBROWSER); no WKWebView in chrome",
    "ios": "engine MobileMiniBrowser.app in bundle; in-process embed pending",
    "linux-gtk": "chrome links WebKitGTK from WEBKIT_GTK_BUILD (pinned GTK port)",
    "android": "chrome uses WPEView from engine wpeview AAR; engine minibrowser APKs under engine/",
}.get(platform, "see docs/ENGINE_EMBED.md")

doc = {
    "platform": platform,
    "bundledAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "webkitPinCommit": os.environ.get("BUNDLE_PIN") or None,
    "gitShortSha": os.environ.get("BUNDLE_SHA") or None,
    "engineRoot": "engine/",
    "chromeRoot": "chrome/" if os.environ.get("BUNDLE_HAS_CHROME") == "true" else None,
    "embedNote": embed,
}
path = os.path.join(os.environ["BUNDLE_STAGE"], "BUNDLE_MANIFEST.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY

mkdir -p "$(dirname "$OUT_TAR")"
tar -czf "$OUT_TAR" -C "$STAGE" .
[[ -s "$OUT_TAR" ]] || { echo "::error::bundle tarball empty: $OUT_TAR" >&2; exit 1; }
echo "BUNDLE_OK platform=$PLATFORM tar=$OUT_TAR ($(du -h "$OUT_TAR" | cut -f1))"
