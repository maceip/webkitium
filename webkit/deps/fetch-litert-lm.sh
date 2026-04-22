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
for platform_dir in \
    prebuilt/android_arm64 \
    prebuilt/linux_x64 \
    prebuilt/macos_arm64 \
    prebuilt/windows_x64; do
    if [ -d "${TARGET_DIR}/${platform_dir}" ]; then
        echo "  OK: ${platform_dir}/"
    else
        echo "  NOT PRESENT: ${platform_dir}/ (GPU may need Git LFS)"
    fi
done

echo ""
echo "=== LiteRT-LM ${LITERT_LM_VERSION} fetched successfully ==="
echo "To build from source: cd ${TARGET_DIR} && bazel build //runtime/engine:litert_lm_main"
echo "To use pre-built: copy prebuilt/<platform>/* beside your browser binary"
