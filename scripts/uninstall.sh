#!/usr/bin/env bash
set -euo pipefail
LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
rm -f "$PLIST"
rm -rf "$HOME/Library/Application Support/CodexCapacityGuard"
echo "Stopped and removed Codex Capacity Guard."
echo "Local logs and retry state retained at ~/.local/state/codex-capacity-guard"
