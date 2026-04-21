#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 127
  }
}

require_cmd git
require_cmd python
require_cmd cmd.exe
require_cmd tar
require_cmd cygpath

BUILD_ID="${GITHUB_RUN_ID:-manual}-${GITHUB_RUN_ATTEMPT:-1}"
SHORT_ID="$(printf '%s' "$BUILD_ID" | md5sum | awk '{print substr($1,1,12)}')"

WORK_ROOT_WIN="C:/Bootstrap/gh-ci/$BUILD_ID"
SOURCE_ROOT_WIN="C:/W/gh-$SHORT_ID"
LOCK_DIR_WIN="C:/Bootstrap/gh-ci/windows-build.lock"
CACHE_ROOT_WIN="C:/Bootstrap/sccache-gh/windows-webgpu-dawn"

WORK_ROOT="$(cygpath -u "$WORK_ROOT_WIN")"
SOURCE_ROOT="$(cygpath -u "$SOURCE_ROOT_WIN")"
LOCK_DIR="$(cygpath -u "$LOCK_DIR_WIN")"
CACHE_ROOT="$(cygpath -u "$CACHE_ROOT_WIN")"

ARTIFACT_ROOT="$REPO_ROOT/.artifacts/windows-build"
PATCH_STAGE="$WORK_ROOT/patches"
PATCH_MANIFEST="$WORK_ROOT/patch-manifest.json"
BUILD_LOG_WIN="$WORK_ROOT_WIN/build-webkit.log"
BUILD_LOG="$WORK_ROOT/build-webkit.log"
BUILD_CMD_WIN="$WORK_ROOT_WIN/build.cmd"
BUILD_CMD="$WORK_ROOT/build.cmd"
SUMMARY_JSON="$ARTIFACT_ROOT/build-summary.json"
CMAKE_SUMMARY="$ARTIFACT_ROOT/cmake-cache-summary.txt"
SCCACHE_REPORT="$ARTIFACT_ROOT/sccache-report.txt"
AWS_EXE_WIN="C:/Program Files/Amazon/AWSCLIV2/aws.exe"
AWS_EXE="$(cygpath -u "$AWS_EXE_WIN")"
BASELINE_S3="s3://cory-build-artifacts-euc1-095713295645-20260407/webkit/windows-build29-20260413"
BASELINE_REGION="eu-central-1"

VS_DEV_CMD_WIN="C:/BuildTools/Common7/Tools/VsDevCmd.bat"
TOOLBIN_WIN="C:/Bootstrap/toolbin"
RUBY_WIN="C:/Ruby34-x64"
PYTHON_WIN="C:/Python314"
LLVM_WIN="C:/Program Files/LLVM"
GIT_WIN="C:/Program Files/Git/cmd"
CMAKE_WIN="C:/Program Files/CMake/bin"
NINJA_WIN="C:/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja"
PERL_WIN="C:/Strawberry/perl/bin"
VCPKG_ROOT_WIN="C:/vcpkg"
SCCACHE_EXE_WIN="$TOOLBIN_WIN/sccache.exe"
PATH_PREPEND_WIN="$TOOLBIN_WIN;$GIT_WIN;$RUBY_WIN/bin;$PYTHON_WIN;$PYTHON_WIN/Scripts;$LLVM_WIN/bin;$CMAKE_WIN;$NINJA_WIN;$PERL_WIN"

WEBKIT_URL="https://github.com/WebKit/WebKit.git"
WEBKIT_COMMIT="1f41867848acbe98dd9a7680365eecc2945de48d"
NINJA_JOBS="8"
ENABLE_SCCACHE="1"
ENABLE_WEBGPU="1"

mkdir -p "$ARTIFACT_ROOT" "$(dirname "$WORK_ROOT")" "$(dirname "$SOURCE_ROOT")" "$CACHE_ROOT"
rm -rf "$ARTIFACT_ROOT"/*

collect_partial_artifacts() {
  mkdir -p "$ARTIFACT_ROOT"
  [[ -f "$BUILD_LOG" ]] && cp "$BUILD_LOG" "$ARTIFACT_ROOT/" || true
  [[ -f "$PATCH_MANIFEST" ]] && cp "$PATCH_MANIFEST" "$ARTIFACT_ROOT/" || true
  [[ -f "$BUILD_CMD" ]] && cp "$BUILD_CMD" "$ARTIFACT_ROOT/" || true
}

cleanup() {
  local exit_code=$?
  collect_partial_artifacts
  rm -rf "$WORK_ROOT" "$SOURCE_ROOT"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$BUILD_ID" >"$LOCK_DIR/owner"
    return 0
  fi
  echo "Windows build lock already held: $LOCK_DIR_WIN" >&2
  exit 1
}

cleanup_stale_state() {
  local root
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  for root in /c/Bootstrap/gh-ci /c/W; do
    [[ -d "$root" ]] || continue
    find "$root" -mindepth 1 -maxdepth 1 -type d \
      \( -name 'gh-*' -o -name '[0-9]*-[0-9]*' \) \
      ! -path "$WORK_ROOT" \
      ! -path "$LOCK_DIR" \
      -exec rm -rf {} + 2>/dev/null || true
  done
}

verify_dependencies() {
  local missing=0
  local path
  for path in \
    "$VS_DEV_CMD_WIN" \
    "$SCCACHE_EXE_WIN" \
    "$VCPKG_ROOT_WIN/vcpkg.exe" \
    "$VCPKG_ROOT_WIN/installed/x64-windows-webkit/include/dawn/webgpu.h" \
    "$VCPKG_ROOT_WIN/installed/x64-windows-webkit/bin/webgpu_dawn.dll" \
    "C:/Program Files/Git/cmd/git.exe" \
    "C:/Program Files/LLVM/bin/clang-cl.exe" \
    "C:/Program Files/CMake/bin/cmake.exe" \
    "C:/Ruby34-x64/bin/ruby.exe" \
    "C:/Strawberry/perl/bin/perl.exe" \
    "C:/Python314/python.exe"; do
    if [[ ! -e "$(cygpath -u "$path")" ]]; then
      echo "Missing required dependency: $path" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]]
}

repair_dependencies_if_needed() {
  local archive="$WORK_ROOT/release-vcpkg_installed.tar"
  local extract="$WORK_ROOT/vcpkg-extract"
  local target_root
  local triplet
  if verify_dependencies; then
    return 0
  fi

  [[ -f "$AWS_EXE" ]] || {
    echo "Missing AWS CLI at $AWS_EXE_WIN" >&2
    exit 2
  }

  echo "Restoring Dawn baseline payload from $BASELINE_S3"
  rm -rf "$extract" "$archive"
  mkdir -p "$extract"
  "$AWS_EXE" s3 cp "$BASELINE_S3/release-vcpkg_installed.tar" "$archive" --region "$BASELINE_REGION"
  tar -xf "$archive" -C "$extract"

  triplet="$(find "$extract" -type d -name 'x64-windows-webkit' | head -n1)"
  [[ -n "$triplet" ]] || {
    echo "Baseline archive did not contain x64-windows-webkit" >&2
    exit 2
  }

  target_root="$(cygpath -u "$VCPKG_ROOT_WIN/installed")"
  mkdir -p "$target_root"
  rm -rf "$target_root/x64-windows-webkit"
  cp -R "$triplet" "$target_root/"

  verify_dependencies || {
    echo "Windows dependency repair did not restore the required Dawn payload" >&2
    exit 2
  }
}

stage_patches() {
  mkdir -p "$PATCH_STAGE/common" "$PATCH_STAGE/windows"
  export NG_STAGE_PATCH_ROOT="$PATCH_STAGE"
  export NG_PATCH_MANIFEST_OUT="$PATCH_MANIFEST"
  python <<'PY'
import hashlib
import json
import os
import shutil
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
patch_root = Path(os.environ["NG_STAGE_PATCH_ROOT"])
manifest_out = Path(os.environ["NG_PATCH_MANIFEST_OUT"])
for bucket in ("common", "windows"):
    source_dir = root / "webkit" / "patches" / bucket
    target_dir = patch_root / bucket
    target_dir.mkdir(parents=True, exist_ok=True)
    if source_dir.is_dir():
        for patch in sorted(source_dir.iterdir()):
            if patch.suffix in (".patch", ".diff"):
                shutil.copy2(patch, target_dir / patch.name)

records = []
for bucket in ("common", "windows"):
    bucket_dir = patch_root / bucket
    for patch in sorted(bucket_dir.iterdir()) if bucket_dir.is_dir() else []:
        if patch.suffix not in (".patch", ".diff"):
            continue
        h = hashlib.sha256()
        with patch.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        records.append({
            "bucket": bucket,
            "name": patch.name,
            "sha256": h.hexdigest(),
        })

manifest = {
    "schema": 1,
    "platform": "windows",
    "patches": records,
}
with manifest_out.open("w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
PY
}

prepare_sccache() {
  local compiler_version
  local patch_sha
  local cache_key
  compiler_version="$(cmd.exe //c C:/Progra~1/LLVM/bin/clang-cl.exe --version | tr -d '\r')"
  patch_sha="$(sha256sum "$PATCH_MANIFEST" | awk '{print $1}')"
  cache_key="$(printf '%s\n' "$WEBKIT_URL" "$WEBKIT_COMMIT" "$ENABLE_WEBGPU" "$ENABLE_SCCACHE" "$NINJA_JOBS" "$patch_sha" "$compiler_version" | sha256sum | awk '{print $1}')"

  if [[ -f "$CACHE_ROOT/cache-key.txt" ]] && [[ "$(cat "$CACHE_ROOT/cache-key.txt")" != "$cache_key" ]]; then
    find "$CACHE_ROOT" -mindepth 1 -maxdepth 1 ! -name 'cache-key.txt' -exec rm -rf {} +
  fi
  printf '%s\n' "$cache_key" >"$CACHE_ROOT/cache-key.txt"
}

clone_source() {
  rm -rf "$SOURCE_ROOT"
  git config --global core.longpaths true
  git clone --filter=blob:none --no-checkout "$WEBKIT_URL" "$SOURCE_ROOT"
  git -C "$SOURCE_ROOT" sparse-checkout init --cone
  git -C "$SOURCE_ROOT" sparse-checkout set \
    Source Tools WebKitLibraries Configurations Websites PerformanceTests ManualTests JSTests WebDriverTests
  git -C "$SOURCE_ROOT" fetch origin "$WEBKIT_COMMIT"
  git -C "$SOURCE_ROOT" checkout -f "$WEBKIT_COMMIT"
}

apply_patches() {
  local patch
  for patch in "$PATCH_STAGE"/common/* "$PATCH_STAGE"/windows/*; do
    [[ -f "$patch" ]] || continue
    echo "Applying $(basename "$patch")"
    git -C "$SOURCE_ROOT" apply --check --whitespace=nowarn --unidiff-zero "$patch"
    git -C "$SOURCE_ROOT" apply --whitespace=nowarn --unidiff-zero "$patch"
  done
}

write_build_cmd() {
  local build_inner
  build_inner='perl Tools\Scripts\build-webkit --release --win --makeargs=-j'"$NINJA_JOBS"' -DCMAKE_C_COMPILER=C:/Progra~1/LLVM/bin/clang-cl.exe -DCMAKE_CXX_COMPILER=C:/Progra~1/LLVM/bin/clang-cl.exe -DCMAKE_LINKER=C:/Progra~1/LLVM/bin/lld-link.exe -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=Embedded -DCMAKE_C_FLAGS="-D_CRT_SECURE_NO_WARNINGS -flto=thin" -DCMAKE_CXX_FLAGS="-D_CRT_SECURE_NO_WARNINGS -flto=thin"'
  if [[ "$ENABLE_SCCACHE" == "1" ]]; then
    build_inner+=' -DCMAKE_C_COMPILER_LAUNCHER='"$SCCACHE_EXE_WIN"' -DCMAKE_CXX_COMPILER_LAUNCHER='"$SCCACHE_EXE_WIN"
  fi
  if [[ "$ENABLE_WEBGPU" == "1" ]]; then
    build_inner+=' --webgpu -DENABLE_EXPERIMENTAL_FEATURES=ON -DENABLE_WEBXR=OFF'
  else
    build_inner+=' --no-experimental-features'
  fi

  cat >"$BUILD_CMD" <<EOF
@echo off
setlocal
call "$VS_DEV_CMD_WIN" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
set "PATH=$PATH_PREPEND_WIN;%PATH%"
set "VCPKG_ROOT=$VCPKG_ROOT_WIN"
set "SCCACHE_DIR=$CACHE_ROOT_WIN"
set "SCCACHE_CACHE_SIZE=50G"
set "SCCACHE_IDLE_TIMEOUT=0"
"$SCCACHE_EXE_WIN" --start-server
"$SCCACHE_EXE_WIN" --zero-stats > "$BUILD_LOG_WIN" 2>&1
cd /d "$SOURCE_ROOT_WIN"
$build_inner >> "$BUILD_LOG_WIN" 2>&1
set "BUILD_EXIT=%ERRORLEVEL%"
"$SCCACHE_EXE_WIN" --show-stats >> "$BUILD_LOG_WIN" 2>&1
exit /b %BUILD_EXIT%
EOF
}

verify_outputs() {
  local release_dir="$SOURCE_ROOT/WebKitBuild/Release"
  local bin_dir="$release_dir/bin"
  local cache_file="$release_dir/CMakeCache.txt"
  local compile_requests
  local required

  [[ -d "$bin_dir" ]] || {
    echo "Missing release bin directory: $bin_dir" >&2
    exit 3
  }
  [[ -f "$cache_file" ]] || {
    echo "Missing CMakeCache.txt: $cache_file" >&2
    exit 3
  }

  for required in MiniBrowser.exe WebKit2.dll WebCore.dll JavaScriptCore.dll webgpu_dawn.dll; do
    [[ -f "$bin_dir/$required" ]] || {
      echo "Missing required artifact: $required" >&2
      exit 3
    }
  done

  grep -E '^(ENABLE_WEBGPU|CMAKE_C_COMPILER_LAUNCHER|CMAKE_CXX_COMPILER_LAUNCHER|CMAKE_MSVC_DEBUG_INFORMATION_FORMAT)' \
    "$cache_file" >"$CMAKE_SUMMARY"

  grep -q 'CMAKE_C_COMPILER_LAUNCHER' "$cache_file" || {
    echo "sccache requested but CMAKE_C_COMPILER_LAUNCHER is missing" >&2
    exit 4
  }
  grep -q 'CMAKE_CXX_COMPILER_LAUNCHER' "$cache_file" || {
    echo "sccache requested but CMAKE_CXX_COMPILER_LAUNCHER is missing" >&2
    exit 4
  }

  export NG_SUMMARY_JSON="$SUMMARY_JSON"
  export NG_RELEASE_DIR_WIN
  export BUILD_ID WEBKIT_URL WEBKIT_COMMIT SOURCE_ROOT_WIN
  NG_RELEASE_DIR_WIN="$(cygpath -m "$release_dir")"
  python <<'PY'
import json
import os

summary = {
    "buildId": os.environ["BUILD_ID"],
    "webkitUrl": os.environ["WEBKIT_URL"],
    "webkitCommit": os.environ["WEBKIT_COMMIT"],
    "sourceRoot": os.environ["SOURCE_ROOT_WIN"],
    "releaseDir": os.environ["NG_RELEASE_DIR_WIN"],
}
with open(os.environ["NG_SUMMARY_JSON"], "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)
PY

  grep -E 'Compile requests|Compile requests executed|Cache hits|Cache misses|Cache hits rate' \
    "$BUILD_LOG" >"$SCCACHE_REPORT" || true
  compile_requests="$(awk '/^Compile requests[[:space:]]+[0-9]+$/ { value=$3 } END { print value }' "$BUILD_LOG")"
  if [[ -z "$compile_requests" || "$compile_requests" == "0" ]]; then
    echo "sccache recorded zero compile requests" >&2
    exit 4
  fi

  mkdir -p "$ARTIFACT_ROOT/bin"
  cp "$BUILD_LOG" "$ARTIFACT_ROOT/"
  cp "$PATCH_MANIFEST" "$ARTIFACT_ROOT/"
  tar -C "$bin_dir" -czf "$ARTIFACT_ROOT/webkitium-windows-$BUILD_ID.tar.gz" .
}

cleanup_stale_state
acquire_lock
export REPO_ROOT
repair_dependencies_if_needed
stage_patches
prepare_sccache
clone_source
apply_patches
write_build_cmd
cmd.exe //c "$(cygpath -w "$BUILD_CMD")"
verify_outputs
