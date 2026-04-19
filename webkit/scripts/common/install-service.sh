#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_FILE="$UNIT_DIR/webkitium-build.service"
mkdir -p "$UNIT_DIR"

cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Webkitium build service
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$NG_ROOT
Environment=NODE_ENV=production
ExecStart=$(command -v node) $NG_ROOT/orchestrator/src/server.js
Restart=on-failure
RestartSec=2
StandardOutput=append:$NG_LOG_DIR/service.log
StandardError=append:$NG_LOG_DIR/service.log

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now webkitium-build.service
systemctl --user status webkitium-build.service --no-pager
