#!/usr/bin/env bash
# scripts/build.sh — trigger a Webkitium build on its GHA runner.
#
# Runs on macOS or Linux dev machines. Windows devs: use scripts/build.ps1.
#
# Usage:
#   scripts/build.sh -p windows                        # current branch, defaults
#   scripts/build.sh -p windows --ref codex/fix-xyz    # specific ref
#   scripts/build.sh -p windows --webgpu               # WebGPU + experimental features
#   scripts/build.sh -p windows --skip-patches         # upstream WebKit only
#   scripts/build.sh -p windows --reuse                # reuse runner checkout (fast retry)
#   scripts/build.sh -p windows --watch                # stream logs after dispatch
#
# Requires: `gh` CLI, authenticated against this repo.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

usage() {
  sed -n '2,15p' "$0"
  echo
  echo "Available platforms (from .github/workflows/):"
  for f in "$repo_root"/.github/workflows/*.yml; do
    [ -f "$f" ] || continue
    echo "  - $(basename "$f" .yml)"
  done
}

platform=""
ref=""
skip_patches="false"
enable_webgpu="false"
reuse_checkout="false"
watch="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--platform)  platform="$2"; shift 2 ;;
    --ref)          ref="$2"; shift 2 ;;
    --skip-patches) skip_patches="true"; shift ;;
    --webgpu)       enable_webgpu="true"; shift ;;
    --reuse)        reuse_checkout="true"; shift ;;
    --watch)        watch="1"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$platform" ]]; then
  echo "Missing required -p/--platform" >&2
  usage >&2
  exit 2
fi

wf="$repo_root/.github/workflows/$platform.yml"
if [[ ! -f "$wf" ]]; then
  echo "No workflow for platform '$platform' (expected $wf)." >&2
  echo "Available platforms:" >&2
  for f in "$repo_root"/.github/workflows/*.yml; do
    [ -f "$f" ] || continue
    echo "  - $(basename "$f" .yml)" >&2
  done
  exit 3
fi

if [[ -z "$ref" ]]; then
  ref="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
fi

# Per-platform inputs. Extend as new workflows land.
inputs=()
case "$platform" in
  windows)
    inputs=(
      -f "skip_repo_patches=$skip_patches"
      -f "enable_webgpu=$enable_webgpu"
      -f "reuse_checkout=$reuse_checkout"
    )
    ;;
  android|linux|macos)
    # No inputs defined yet; workflow will use its defaults.
    ;;
esac

echo "Dispatching $platform.yml on ref=$ref"
gh workflow run "$platform.yml" --ref "$ref" "${inputs[@]}"

if [[ "$watch" == "1" ]]; then
  # Let GitHub register the run, then watch the newest one for this workflow.
  sleep 3
  run_id="$(gh run list --workflow "$platform.yml" --limit 1 --json databaseId --jq '.[0].databaseId')"
  if [[ -n "$run_id" ]]; then
    gh run watch "$run_id"
  else
    echo "Dispatched, but could not resolve run id to watch. Check: gh run list --workflow $platform.yml" >&2
  fi
fi
