#!/usr/bin/env bash
# Baseline installable artifacts per CI platform. Invoked from GitHub Actions
# after a successful WebKit (or WPE-Android) build. Extend this script as
# product shells replace MiniBrowser and real installers (MSI/DMG/pkgbuild) land.
set -euo pipefail

PLATFORM="${1:?usage: baseline-package.sh <windows|macos|linux-gtk|ios|android>}"
RUN_ID="${GITHUB_RUN_ID:-local}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
OUT_ROOT="${NG_BASELINE_OUT:-${RUNNER_TEMP:-/tmp}/baseline-packages}"
mkdir -p "$OUT_ROOT"

stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

case "$PLATFORM" in
  windows)
    ROOT="${NG_BASELINE_WEBKIT_BUILD:?set NG_BASELINE_WEBKIT_BUILD (e.g. C:/W/webkit-src/WebKitBuild/Release)}"
    BIN="$ROOT/bin"
    [[ -d "$BIN" ]] || { echo "::error::Windows bin dir missing: $BIN" >&2; exit 1; }
    MSI="$OUT_ROOT/webkit-minibrowser-baseline-${RUN_ID}-${RUN_ATTEMPT}.msi"
    ZIP="$OUT_ROOT/webkit-minibrowser-baseline-${RUN_ID}-${RUN_ATTEMPT}.zip"
    (
      cd "$BIN"
      zip -qr "$ZIP" MiniBrowser.exe WebKit*.dll JavaScriptCore*.dll 2>/dev/null || zip -qr "$ZIP" .
    )
    printf '%s\n' "WiX/MSI not generated on runner yet; portable ZIP is the baseline payload." >"$MSI"
    cat >"$OUT_ROOT/baseline-${PLATFORM}-${RUN_ID}.json" <<EOF
{"platform":"windows","created":"$(stamp)","runId":"$RUN_ID","attempt":"$RUN_ATTEMPT","zip":"$(basename "$ZIP")","msi":"$(basename "$MSI")","note":"ZIP is the portable baseline; .msi is a placeholder text file until WiX is wired."}
EOF
    echo "BASELINE_OK platform=$PLATFORM zip=$ZIP"
    ;;
  macos|linux-gtk)
    ROOT="${NG_BASELINE_WEBKIT_BUILD:?set NG_BASELINE_WEBKIT_BUILD to WebKitBuild/Release}"
    [[ -d "$ROOT" ]] || { echo "::error::Build output dir missing: $ROOT" >&2; exit 1; }
    TAR="$OUT_ROOT/webkit-minibrowser-baseline-${RUN_ID}-${RUN_ATTEMPT}.tar.gz"
    if [[ -d "$ROOT/bin" ]]; then
      tar -czf "$TAR" -C "$ROOT" bin
    else
      tar -czf "$TAR" -C "$ROOT" .
    fi
    DMG="$OUT_ROOT/webkit-minibrowser-baseline-${RUN_ID}-${RUN_ATTEMPT}.dmg"
    PKG="$OUT_ROOT/webkit-minibrowser-baseline-${RUN_ID}-${RUN_ATTEMPT}.pkg"
    if [[ "$PLATFORM" == macos ]] && command -v hdiutil >/dev/null 2>&1; then
      STAGING="$OUT_ROOT/.dmg-staging-$RUN_ID"
      rm -rf "$STAGING"
      mkdir -p "$STAGING"
      if [[ -d "$ROOT/bin/MiniBrowser.app" ]]; then
        cp -a "$ROOT/bin/MiniBrowser.app" "$STAGING/"
      elif compgen -G "$ROOT/bin/"*.app >/dev/null; then
        cp -a "$ROOT/bin/"*.app "$STAGING/" 2>/dev/null || true
      else
        cp -a "$ROOT/bin" "$STAGING/" 2>/dev/null || cp -a "$ROOT" "$STAGING/out"
      fi
      hdiutil create -volname "WebKitMiniBrowser-baseline" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
      rm -rf "$STAGING"
    else
      ln -sf "$(basename "$TAR")" "$DMG" 2>/dev/null || cp "$TAR" "$DMG"
    fi
    printf '%s\n' "Placeholder PKG: use productbuild --root once signing/bundle layout is fixed." >"$PKG"
    cat >"$OUT_ROOT/baseline-${PLATFORM}-${RUN_ID}.json" <<EOF
{"platform":"$PLATFORM","created":"$(stamp)","runId":"$RUN_ID","attempt":"$RUN_ATTEMPT","tarball":"$(basename "$TAR")","dmgOrArchive":"$(basename "$DMG")","pkg":"$(basename "$PKG")","note":"linux-gtk: DMG symlink points at tarball; macOS uses hdiutil when MiniBrowser.app exists."}
EOF
    echo "BASELINE_OK platform=$PLATFORM tar=$TAR"
    ;;
  ios)
    ROOT="${NG_BASELINE_WEBKIT_BUILD:?set NG_BASELINE_WEBKIT_BUILD to WebKitBuild (parent of Release/Debug)}"
    ZIP="$OUT_ROOT/webkit-ios-simulator-baseline-${RUN_ID}-${RUN_ATTEMPT}.zip"
    (
      cd "$ROOT"
      FIRST="$(find . -name 'MiniBrowser.app' -type d 2>/dev/null | head -1)"
      if [[ -n "$FIRST" ]]; then
        tar -czf "$ZIP" -C "$(dirname "$FIRST")" "$(basename "$FIRST")"
      else
        tar -czf "$ZIP" --files-from /dev/null
        echo "::error::No MiniBrowser.app under $ROOT" >&2
        exit 1
      fi
    )
    cat >"$OUT_ROOT/baseline-ios-${RUN_ID}.json" <<EOF
{"platform":"ios","created":"$(stamp)","runId":"$RUN_ID","attempt":"$RUN_ATTEMPT","zip":"$(basename "$ZIP")","ipaNote":"App Store IPA requires signing/exportArchive; simulator/product zip is the baseline deliverable here."}
EOF
    echo "BASELINE_OK platform=ios zip=$ZIP"
    ;;
  android)
    SRC="${NG_ANDROID_SOURCE:-$HOME/webkit/wpe-android}"
    APK_DIR="$OUT_ROOT/apk"
    mkdir -p "$APK_DIR"
    count=0
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      cp -f "$f" "$APK_DIR/"
      count=$((count + 1))
    done < <(find "$SRC" -type f -name '*.apk' 2>/dev/null | head -20)
    if [[ "$count" -eq 0 ]]; then
      echo "::error::No APK files found under $SRC" >&2
      exit 1
    fi
    MANIFEST="$OUT_ROOT/baseline-android-${RUN_ID}.json"
    python3 - "$MANIFEST" "$RUN_ID" "$RUN_ATTEMPT" "$APK_DIR" <<'PY'
import json, os, sys, time
out_path, run_id, attempt, apk_dir = sys.argv[1:5]
rows = []
for name in sorted(os.listdir(apk_dir)):
    if name.endswith(".apk"):
        p = os.path.join(apk_dir, name)
        rows.append({"name": name, "bytes": os.path.getsize(p)})
with open(out_path, "w") as f:
    json.dump({"platform": "android", "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "runId": run_id, "attempt": attempt, "apks": rows}, f, indent=2)
PY
    echo "BASELINE_OK platform=android apks=$count"
    ;;
  *)
    echo "::error::Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac
