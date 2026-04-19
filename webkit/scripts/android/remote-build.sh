#!/usr/bin/env bash
# Android Gradle build on the remote Linux builder. Reads build-config.json next to this script.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/build-config.json"
[[ -f "$CONFIG" ]] || { echo "build-config.json not found: $CONFIG" >&2; exit 1; }

cfg() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])"; }

BUILD_ID="$(cfg buildId)"
WORKDIR="$(cfg workdir)"
SOURCE="$(cfg sourceRoot)"
REPO="$(cfg androidRepo)"
ARCH="$(cfg arch)"
BUILD_DEPS="$(cfg buildDeps)"
INSTALL_NDK="$(cfg installNdk)"
export ANDROID_HOME="$(cfg androidHome)"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:${PATH:-}"
export NG_ROOT="$HERE/ng"
export NG_CHANGES_FILE="$NG_ROOT/config/changes.json"

ARTDIR="$WORKDIR/artifacts"
mkdir -p "$ARTDIR"
touch "$ARTDIR/.build-start"

log_line() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# --- Source checkout ---
if [[ ! -d "$SOURCE/.git" ]]; then
  mkdir -p "$(dirname "$SOURCE")"
  git clone "$REPO" "$SOURCE"
fi

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 127; }; }
require_cmd git
require_cmd python3
require_cmd java
require_cmd jq

cd "$SOURCE"
git fetch --all --tags || true
# Remote builders reuse the same checkout across runs. Always remove prior
# patch state before applying this run's staged patch set.
git reset --hard HEAD
git clean -fd -- \
  tools/minibrowser/src/main/res/drawable/webkitium_chrome_gradient.xml \
  tools/minibrowser/src/main/res/drawable/webkitium_menu_popup_bg.xml

if [[ "$INSTALL_NDK" == "1" ]]; then
  "$SOURCE/tools/scripts/install-android-ndk.sh"
fi

if [[ "$BUILD_DEPS" == "1" ]]; then
  "$SOURCE/tools/scripts/bootstrap.py" --build --arch="$ARCH" ${NG_ANDROID_DEBUG:+--debug}
else
  "$SOURCE/tools/scripts/bootstrap.py" --arch="$ARCH"
fi

# bootstrap.py may touch local.properties — force sdk.dir for this builder.
printf 'sdk.dir=%s\n' "$ANDROID_HOME" >"$SOURCE/local.properties"

# Android Gradle Plugin otherwise downloads Maven's Linux aapt2 binary. On our
# arm64 Android runner that x86_64 binary needs the SDK wrapper, which sets the
# qemu loader prefix before execing aapt2.real.
AAPT2_OVERRIDE="$ANDROID_HOME/build-tools/35.0.0/aapt2"
if [[ -x "$AAPT2_OVERRIDE" ]]; then
  printf '\nandroid.aapt2FromMavenOverride=%s\n' "$AAPT2_OVERRIDE" >>"$SOURCE/gradle.properties"
fi

# --- Apply ng patches + enabled changes (same as local apply-patches.sh) ---
chmod +x "$NG_ROOT/webkit/scripts/common/apply-patches.sh" "$NG_ROOT/webkit/scripts/common/apply-changes.sh" "$NG_ROOT/webkit/scripts/common/common.sh" 2>/dev/null || true
bash "$NG_ROOT/webkit/scripts/common/apply-patches.sh" android "$SOURCE"

printf 'sdk.dir=%s\n' "$ANDROID_HOME" >"$SOURCE/local.properties"
if [[ -x "$AAPT2_OVERRIDE" ]] && ! grep -q '^android\.aapt2FromMavenOverride=' "$SOURCE/gradle.properties" 2>/dev/null; then
  printf '\nandroid.aapt2FromMavenOverride=%s\n' "$AAPT2_OVERRIDE" >>"$SOURCE/gradle.properties"
fi

# --- Build ---
cd "$SOURCE"
[[ -f ./gradlew ]] && chmod +x ./gradlew
set +e
./gradlew ":tools:minibrowser:assembleDebug" ":wpeview:assembleDebug" 2>&1 | tee "$ARTDIR/gradle-android.log"
GRADLE_EXIT=${PIPESTATUS[0]}
set -e
if [[ "$GRADLE_EXIT" -ne 0 ]]; then
  log_line "gradlew failed with exit $GRADLE_EXIT"
  exit "$GRADLE_EXIT"
fi

# Collect deliverables (same globs as watch-artifacts.sh)
while IFS= read -r -d '' f; do
  cp -a "$f" "$ARTDIR/"
done < <(find "$SOURCE" -type f \( -name '*.apk' -o -name '*.aar' -o -name '*.tar.xz' \) -print0 2>/dev/null)

log_line "remote android build finished buildId=$BUILD_ID"
exit 0
