#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/webkit/scripts/common/run-build.sh" "$@"
