#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 not found" >&2; exit 1; }
python3 -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10+ required"'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$HOME/Library/Application Support/CodexCapacityGuard"
PLIST="$HOME/Library/LaunchAgents/com.peakmain.codex-capacity-guard.plist"
LOGS="$HOME/.local/state/codex-capacity-guard"
LABEL="com.peakmain.codex-capacity-guard"
UID_NUM="$(id -u)"
# One startup hook belongs to iTerm2 itself; do not overwrite a user's hook.
AUTOLAUNCH="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch.scpt"
if [[ -f "$AUTOLAUNCH" ]] && ! /usr/bin/osadecompile "$AUTOLAUNCH" 2>/dev/null | grep -q 'codexcontinue-managed-autolaunch'; then
  echo "已有其他 iTerm2 AutoLaunch.scpt，不能自动覆盖。" >&2
  echo "请让 AI 帮你将 scripts/AutoLaunch.applescript 安全合并进原有脚本。" >&2
  exit 1
fi
mkdir -p "$BASE" "$(dirname "$PLIST")" "$LOGS" "$(dirname "$AUTOLAUNCH")"
echo "Creating isolated Python environment..."
python3 -m venv "$BASE/.venv"
"$BASE/.venv/bin/python" -m pip install -r "$ROOT/requirements.txt"
cp "$ROOT/capacity_guard.py" "$BASE/capacity_guard.py"
# Keep management scripts in a stable location even if the checkout is moved
# or deleted. AI assistants can always find them there.
mkdir -p "$BASE/scripts"
for name in start stop status; do
  cp "$ROOT/scripts/$name.sh" "$BASE/scripts/$name.sh"
  chmod 755 "$BASE/scripts/$name.sh"
done
BASE="$BASE" PLIST="$PLIST" LOGS="$LOGS" python3 - <<'PY'
import os
import plistlib
from pathlib import Path
base = Path(os.environ["BASE"])
logs = Path(os.environ["LOGS"])
plist = Path(os.environ["PLIST"])
plist.write_bytes(plistlib.dumps({
    "Label": "com.peakmain.codex-capacity-guard",
    "ProgramArguments": [str(base / ".venv/bin/python"), "-u", str(base / "capacity_guard.py")],
    "EnvironmentVariables": {
        "HOME": str(Path.home()),
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    },
    "RunAtLoad": True,
    "KeepAlive": False,  # exits when iTerm2 quits; will NOT be relaunched
    "ThrottleInterval": 20,
    "StandardOutPath": str(logs / "service.stdout.log"),
    "StandardErrorPath": str(logs / "service.stderr.log"),
}))
PY
# Compile iTerm2's official startup script. Next iTerm2 launch will kickstart
# the already registered LaunchAgent, even if it exited after a previous quit.
/usr/bin/osacompile -o "$AUTOLAUNCH" "$ROOT/scripts/AutoLaunch.applescript"
launchctl bootout "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "✅ 已注册并请求启动后台监工：$LABEL"
if [[ -f "$BASE/disabled" ]]; then
  echo "⏸️ 检测到用户此前主动停止监工；重新安装不会擅自恢复。"
  echo "   如需恢复，请运行 bash scripts/start.sh 或让 AI 帮你恢复。"
else
  echo "✅ 监工现在跟随 iTerm2：关闭 iTerm2 后退出，再打开 iTerm2 时自动启动。"
fi
echo "✅ 不需要单独打开监工终端，也不会在 iTerm2 已关闭时持续后台轮询。"
echo "ℹ️  请在 iTerm2 > Settings > General > Magic 勾选 Enable Python API。"
echo "正在执行只读健康检查（无须用户再次输入命令）..."
sleep 2
if ! bash "$BASE/scripts/status.sh"; then
  echo "⚠️ 后台服务状态未通过检查。请根据输出检查授权与运行日志。" >&2
  exit 1
fi
echo "✅ 安装流程结束。真实容量报错的自动续跑仍需在发生时验证。"
