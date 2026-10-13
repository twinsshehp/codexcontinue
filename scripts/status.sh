#!/usr/bin/env bash
# Read-only status check for Codex Capacity Guard.
set -u
LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$HOME/.local/state/codex-capacity-guard"
LOG="$STATE_DIR/supervisor.log"
ERR="$STATE_DIR/service.stderr.log"
DISABLED="$HOME/Library/Application Support/CodexCapacityGuard/disabled"

echo "Codex Capacity Guard — 安装状态检查"
echo "----------------------------------------"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ 仅支持 macOS"
  exit 1
fi

if [[ -f "$PLIST" ]]; then
  echo "✅ 后台启动配置存在：$PLIST"
else
  echo "❌ 没有找到后台启动配置（尚未安装，或已卸载）"
  exit 1
fi

if [[ -f "$DISABLED" ]]; then
  if launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -q 'state = running'; then
    echo "⚠️ 已设置主动停止，但后台监工进程尚未退出，请稍后重新检查！" >&2
    exit 2
  fi
  echo "⏸️ 已被用户主动停止，不会随 iTerm2 启动。"
  echo "✅ 恢复方式：bash \"$HOME/Library/Application Support/CodexCapacityGuard/scripts/start.sh\""
  echo "也可以对有本机权限的 AI 说“恢复 codexcontinue”。"
  exit 0
fi

if ! /usr/bin/pgrep -x "iTerm2" >/dev/null 2>&1; then
  echo "✅ iTerm2 已退出：监工应当处于停止状态，不需要常驻运行。"
  echo "   下次打开 iTerm2 时，它会通过启动脚本自动启动。"
  exit 0
fi

RESULT="$(launchctl print "gui/$(id -u)/$LABEL" 2>&1)" || {
  echo "❌ 后台监工服务没有加载。"
  echo "$RESULT" | head -n 6
  exit 2
}
if grep -q 'state = running' <<< "$RESULT"; then
  echo "✅ 后台监工运行中"
  grep -m1 -E 'pid = [0-9]+' <<< "$RESULT" | sed 's/^/[状态] /' || true
else
  echo "❌ 后台监工并未处于 running 状态"
  echo "$RESULT" | grep -E 'state =|last exit code' | head -n 8
  exit 3
fi

if [[ -s "$LOG" ]] && grep -qE 'Started: Codex CLI only|capacity watcher started' "$LOG"; then
  echo "✅ 监工存在成功启动的日志记录"
  tail -n 3 "$LOG" | sed 's/^/[日志] /'
else
  echo "⚠️ 尚未发现监工启动日志；服务可能仍在连接 iTerm2"
  echo "   查看 $ERR"
fi

echo
echo "最近自动发送“继续”的记录（包含最多两份轮转日志）："
RECENT_SENDS="$(grep -h 'Sent continuation' "$STATE_DIR"/supervisor.log* 2>/dev/null | sort | tail -n 5 || true)"
if [[ -n "$RECENT_SENDS" ]]; then
  printf '%s\n' "$RECENT_SENDS"
else
  echo "暂未发现自动发送记录（并不代表历史上从未发送，日志可能已轮转或清理）"
fi
echo "更多记录：grep 'Sent continuation' ~/.local/state/codex-capacity-guard/supervisor.log"

if [[ -s "$ERR" ]]; then
  echo "⚠️ 最近的错误日志（可能包含历史记录）："
  tail -n 8 "$ERR"
else
  echo "✅ 错误日志目前为空"
fi

echo
echo "提示：running 只证明进程正在运行；只有真实报错发生后才能验证自动续跑效果。"
echo "正常退出 iTerm2 后监工退出；再次打开 iTerm2 后会自动启动。无需手动执行命令。"
