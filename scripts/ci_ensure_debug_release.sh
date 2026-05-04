#!/usr/bin/env bash
# Ensure the rolling GitHub release for CI debug artifacts exists (idempotent).
set -euo pipefail
TAG="${CI_DEBUG_RELEASE_TAG:-ci-debug-builds}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY missing}"
export GH_TOKEN="${GH_TOKEN:?GH_TOKEN missing}"
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" \
    --title "CI debug builds" \
    --notes "Automated debug artifacts from merged commits (push to default branch). Filenames include a short SHA." \
    --latest=false
fi
