#!/usr/bin/env bash
# Fetch LiteRT-LM at the pinned version for WebNN backend integration.
#
# This script clones the LiteRT-LM repo at the pinned tag and verifies
# the commit hash. It does NOT build — building is handled by the WebKit
# CMake superbuild via ExternalProject or by pre-building with Bazel.
#
# Usage:
#   ./webkit/deps/fetch-litert-lm.sh [target-dir]
#
# Default target: webkit/deps/litert-lm-src/

set -euo pipefail

LITERT_LM_VERSION="v0.10.2"
LITERT_LM_COMMIT="7aee34c5d0b7c97e813707f1d5e677f4749cdcd1"
LITERT_LM_REPO="https://github.com/google-ai-edge/LiteRT-LM.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TARGET="${SCRIPT_DIR}/litert-lm-src"
TARGET_DIR="${1:-$DEFAULT_TARGET}"

echo "=== LiteRT-LM dependency fetch ==="
echo "Version:    ${LITERT_LM_VERSION}"
echo "Commit:     ${LITERT_LM_COMMIT}"
echo "Target dir: ${TARGET_DIR}"

if [ -d "${TARGET_DIR}/.git" ]; then
    echo "Directory exists, checking version..."
    CURRENT_COMMIT="$(cd "${TARGET_DIR}" && git rev-parse HEAD)"
    if [ "${CURRENT_COMMIT}" = "${LITERT_LM_COMMIT}" ]; then
        echo "Already at pinned commit. Nothing to do."
        exit 0
    fi
    echo "Wrong commit (${CURRENT_COMMIT}), re-fetching..."
    rm -rf "${TARGET_DIR}"
fi

echo "Cloning LiteRT-LM at ${LITERT_LM_VERSION}..."
git clone --depth 1 --branch "${LITERT_LM_VERSION}" "${LITERT_LM_REPO}" "${TARGET_DIR}"

ACTUAL_COMMIT="$(cd "${TARGET_DIR}" && git rev-parse HEAD)"
if [ "${ACTUAL_COMMIT}" != "${LITERT_LM_COMMIT}" ]; then
    echo "WARNING: Commit mismatch!"
    echo "  Expected: ${LITERT_LM_COMMIT}"
    echo "  Got:      ${ACTUAL_COMMIT}"
    echo "  The tag may have moved. Proceeding with actual commit."
fi

echo ""
echo "Checking key headers..."
for header in \
    runtime/engine/engine.h \
    runtime/engine/engine_settings.h \
    runtime/engine/io_types.h \
    runtime/conversation/conversation.h \
    runtime/conversation/io_types.h \
    runtime/executor/executor_settings_base.h; do
    if [ -f "${TARGET_DIR}/${header}" ]; then
        echo "  OK: ${header}"
    else
        echo "  MISSING: ${header}"
        exit 1
    fi
done

echo ""
echo "Checking prebuilt GPU libraries..."
PREBUILT_PLATFORMS=(
    "android_arm64:libLiteRtGpuAccelerator.so:libLiteRtOpenClAccelerator.so"
    "android_x86_64:libLiteRtGpuAccelerator.so:libLiteRtOpenClAccelerator.so"
    "linux_x86_64:libLiteRt.so"
    "linux_arm64:libLiteRt.so"
    "macos_arm64:libLiteRtMetalAccelerator.dylib:libLiteRt.dylib"
    "windows_x86_64:libLiteRt.dll"
)

# Git LFS is needed for the prebuilt binaries
if command -v git-lfs >/dev/null 2>&1 || git lfs version >/dev/null 2>&1; then
    echo "  Git LFS available, pulling prebuilt binaries..."
    (cd "${TARGET_DIR}" && git lfs pull) || echo "  WARNING: git lfs pull failed (binaries may be LFS pointers)"
else
    echo "  WARNING: Git LFS not installed. Prebuilt binaries will be LFS pointers."
    echo "  Install Git LFS: https://git-lfs.com/"
fi

echo ""
for entry in "${PREBUILT_PLATFORMS[@]}"; do
    IFS=: read -r platform libs <<< "${entry}"
    dir="${TARGET_DIR}/prebuilt/${platform}"
    if [ -d "${dir}" ]; then
        echo "  ${platform}/:"
        IFS=: read -ra LIB_ARRAY <<< "${libs}"
        for lib in "${LIB_ARRAY[@]}"; do
            if [ -f "${dir}/${lib}" ]; then
                size=$(stat -f%z "${dir}/${lib}" 2>/dev/null || stat -c%s "${dir}/${lib}" 2>/dev/null || echo "?")
                if [ "${size}" -lt 1000 ] 2>/dev/null; then
                    echo "    LFS POINTER: ${lib} (${size} bytes — run 'git lfs pull')"
                else
                    echo "    OK: ${lib} (${size} bytes)"
                fi
            else
                echo "    MISSING: ${lib}"
            fi
        done
    else
        echo "  NOT PRESENT: prebuilt/${platform}/"
    fi
done

echo ""
echo "=== LiteRT-LM ${LITERT_LM_VERSION} fetched successfully ==="
echo ""
echo "Prebuilt libraries to copy beside your browser binary:"
echo "  Android: prebuilt/android_arm64/libLiteRtGpuAccelerator.so + libLiteRtOpenClAccelerator.so"
echo "  macOS:   prebuilt/macos_arm64/libLiteRtMetalAccelerator.dylib + libLiteRt.dylib"
echo "  Windows: prebuilt/windows_x86_64/libLiteRt.dll"
echo "  Linux:   prebuilt/linux_x86_64/libLiteRt.so"
echo ""
echo "To build from source: cd ${TARGET_DIR} && bazel build //runtime/engine:litert_lm_main"
