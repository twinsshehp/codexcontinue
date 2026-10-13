#!/usr/bin/env bash
# Keep the guard stopped until the user explicitly runs start.sh.
set -euo pipefail

LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BASE="$HOME/Library/Application Support/CodexCapacityGuard"
DISABLED="$BASE/disabled"
TARGET="gui/$(id -u)/$LABEL"

if [[ ! -f "$PLIST" ]]; then
  echo "ℹ️ 尚未安装 codexcontinue，无需停止。"
  exit 0
fi

mkdir -p "$BASE"
# Write opt-out BEFORE stopping, so any concurrent startup will also exit.
touch "$DISABLED"
launchctl kill SIGTERM "$TARGET" >/dev/null 2>&1 || true

for attempt in {1..20}; do
  if ! launchctl print "$TARGET" 2>/dev/null | grep -q 'state = running'; then
    echo "✅ codexcontinue 已停止。重新打开 iTerm2 也不会自动恢复。"
    echo "✅ Codex CLI 和 iTerm2 不受影响。"
    echo "如需恢复：bash scripts/start.sh（或直接告诉有本机权限的 AI“恢复 codexcontinue”）。"
    exit 0
  fi
  sleep 0.25
done

echo "⚠️ 已保存停用设置，但监工进程仍在运行，请检查系统服务状态。" >&2
exit 1
