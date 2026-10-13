#!/usr/bin/env bash
# Re-enable the guard and start it if iTerm2 is currently open.
set -euo pipefail

LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BASE="$HOME/Library/Application Support/CodexCapacityGuard"
DISABLED="$BASE/disabled"
TARGET="gui/$(id -u)/$LABEL"

if [[ ! -f "$PLIST" ]]; then
  echo "❌ 尚未安装 codexcontinue。请先使用安装脚本。" >&2
  exit 1
fi

rm -f "$DISABLED"
if ! /usr/bin/pgrep -x "iTerm2" >/dev/null 2>&1; then
  echo "✅ 已取消主动停用。iTerm2 当前未运行，下次打开时监工会自动启动。"
  exit 0
fi

if launchctl print "$TARGET" >/dev/null 2>&1; then
  if launchctl print "$TARGET" | grep -q 'state = running'; then
    echo "✅ codexcontinue 已在运行，无需重复启动。"
    exit 0
  fi
  launchctl kickstart "$TARGET"
else
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi

for attempt in {1..20}; do
  if launchctl print "$TARGET" 2>/dev/null | grep -q 'state = running'; then
    echo "✅ codexcontinue 已恢复监控；关闭 iTerm2 时自动退出，再次打开会自动启动。"
    exit 0
  fi
  sleep 0.25
done
echo "⚠️ 已取消停用，但监工没有成功进入运行状态，请检查 stderr 日志。" >&2
exit 1
