#!/usr/bin/env bash
set -euo pipefail
LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
AUTOLAUNCH="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch.scpt"
if [[ -f "$AUTOLAUNCH" ]] && /usr/bin/osadecompile "$AUTOLAUNCH" 2>/dev/null | grep -q 'codexcontinue-managed-autolaunch'; then
  rm -f "$AUTOLAUNCH"
fi
rm -f "$PLIST"
rm -rf "$HOME/Library/Application Support/CodexCapacityGuard"
echo "Stopped and removed Codex Capacity Guard."
echo "Local logs and retry state retained at ~/.local/state/codex-capacity-guard"
