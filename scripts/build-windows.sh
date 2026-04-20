#!/usr/bin/env bash
# Trigger a Windows WebKit build on the GHA self-hosted runner.
# Replaces the legacy `curl -X POST http://localhost:8787/builds` orchestrator path.
#
# Usage:
#   scripts/build-windows.sh                       # build current branch, defaults
#   scripts/build-windows.sh --ref codex/fix-xyz   # build a specific ref
#   scripts/build-windows.sh --webgpu              # --webgpu + experimental features on
#   scripts/build-windows.sh --skip-patches        # upstream-only (no webkit/patches)
#   scripts/build-windows.sh --reuse               # reuse existing runner checkout (fast retry)
#   scripts/build-windows.sh --watch               # stream the run's logs after dispatch
#
# Requires: `gh` authenticated against this repo.
set -euo pipefail

ref=""
skip_patches="false"
enable_webgpu="false"
reuse_checkout="false"
watch="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)            ref="$2"; shift 2 ;;
    --skip-patches)   skip_patches="true"; shift ;;
    --webgpu)         enable_webgpu="true"; shift ;;
    --reuse)          reuse_checkout="true"; shift ;;
    --watch)          watch="1"; shift ;;
    -h|--help)
      sed -n '2,14p' "$0"; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ref" ]]; then
  ref="$(git -C "$(git rev-parse --show-toplevel)" rev-parse --abbrev-ref HEAD)"
fi

echo "Dispatching windows.yml on ref=$ref (skip_patches=$skip_patches webgpu=$enable_webgpu reuse=$reuse_checkout)"
gh workflow run windows.yml --ref "$ref" \
  -f "skip_repo_patches=$skip_patches" \
  -f "enable_webgpu=$enable_webgpu" \
  -f "reuse_checkout=$reuse_checkout"

if [[ "$watch" == "1" ]]; then
  # Give GitHub a beat to register the run, then watch the newest one for this workflow.
  sleep 3
  run_id="$(gh run list --workflow windows.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
  gh run watch "$run_id"
fi
