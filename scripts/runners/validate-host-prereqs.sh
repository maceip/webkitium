#!/usr/bin/env bash
# Quick sanity checks for self-hosted GitHub Actions builder images.
# Usage: ./scripts/runners/validate-host-prereqs.sh
# Env: RUNNER_MIN_DISK_GB (default 50), STRICT_SUDO=1 to fail if sudo -n is not allowed
set -euo pipefail

MIN_GB="${RUNNER_MIN_DISK_GB:-50}"
FAIL=0

warn() { echo "::warning::$*" >&2; }
err() { echo "::error::$*" >&2; FAIL=1; }

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not on PATH: $1"
  else
    echo "OK  found $1 -> $(command -v "$1")"
  fi
}

echo "== Disk (need >= ${MIN_GB} GiB free on workspace root) =="
# POSIX: df -k; avoid -P for widest macOS/Linux compatibility
_root="${GITHUB_WORKSPACE:-.}"
# Second line: 4th column is 1K-blocks free on GNU and BSD df -k
kb_avail="$(df -k "$_root" 2>/dev/null | awk 'NR==2 {print $4}')"
if ! [[ "${kb_avail:-}" =~ ^[0-9]+$ ]]; then
  kb_avail="$(df -k . | awk 'NR==2 {print $4}')"
fi
gb_free=$((kb_avail / 1024 / 1024))
echo "    Free: ~${gb_free} GiB"
if (( gb_free < MIN_GB )); then
  err "Less than ${MIN_GB} GiB free — expand volume or clean ccache/artifacts"
else
  echo "OK  disk threshold"
fi

echo "== Commands =="
need_cmd git
need_cmd gh

echo "== gh auth (optional if only Actions-injected token is used) =="
if gh auth status >/dev/null 2>&1; then
  echo "OK  gh auth status succeeds"
else
  warn "gh auth status failed — interactive login may be missing; Actions may still work if GH_TOKEN is injected per job"
fi

echo "== Non-interactive sudo (needed for Metal / GTK install-deps in CI) =="
if sudo -n true 2>/dev/null; then
  echo "OK  sudo -n succeeds"
else
  if [[ "${STRICT_SUDO:-}" == "1" ]]; then
    err "sudo -n failed — add NOPASSWD for required commands or bake deps into AMI (set STRICT_SUDO=0 to warn only)"
  else
    warn "sudo -n failed — macOS Metal / Linux GTK dependency steps may fail until sudoers or image is fixed"
  fi
fi

if (( FAIL )); then
  echo "::error::validate-host-prereqs: one or more hard checks failed"
  exit 1
fi
echo "validate-host-prereqs: all hard checks passed"
