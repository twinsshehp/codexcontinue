#!/usr/bin/env bash
# Read-only status check for Codex Capacity Guard.
set -u
LABEL="com.peakmain.codex-capacity-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$HOME/.local/state/codex-capacity-guard"
LOG="$STATE_DIR/supervisor.log"
ERR="$STATE_DIR/service.stderr.log"

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

if [[ -s "$ERR" ]]; then
  echo "⚠️ 最近的错误日志（可能包含历史记录）："
  tail -n 8 "$ERR"
else
  echo "✅ 错误日志目前为空"
fi

echo
echo "提示：running 只证明进程正在运行；只有真实报错发生后才能验证自动续跑效果。"
echo "成功安装后，用户不需要额外运行启动命令，登录 Mac 后会自动尝试启动。"
