#!/usr/bin/env bash
# Ensure the GitHub release used for baseline asset uploads exists.
# - Rolling CI: CI_DEBUG_RELEASE_TAG=ci-debug-builds (not "latest" on GitHub).
# - Release cut: CI_DEBUG_RELEASE_TAG set to a version tag (created if missing, --latest).
set -euo pipefail
TAG="${CI_DEBUG_RELEASE_TAG:-ci-debug-builds}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY missing}"
if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  export GH_TOKEN="$GITHUB_TOKEN"
fi
export GH_TOKEN="${GH_TOKEN:?GH_TOKEN or GITHUB_TOKEN missing}"

if [[ "$TAG" == "ci-debug-builds" ]]; then
  exec bash "${GITHUB_WORKSPACE:?}/scripts/ci_ensure_debug_release.sh"
fi

if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" \
    --title "Webkitium ${TAG}" \
    --notes "Automated multi-platform build artifacts (workflow_dispatch with release_tag)." \
    --latest
fi
