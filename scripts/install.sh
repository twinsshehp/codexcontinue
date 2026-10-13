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
mkdir -p "$BASE" "$(dirname "$PLIST")" "$LOGS"
echo "Creating isolated Python environment..."
python3 -m venv "$BASE/.venv"
"$BASE/.venv/bin/python" -m pip install -r "$ROOT/requirements.txt"
cp "$ROOT/capacity_guard.py" "$BASE/capacity_guard.py"
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
    "KeepAlive": True,
    "ThrottleInterval": 20,
    "StandardOutPath": str(logs / "service.stdout.log"),
    "StandardErrorPath": str(logs / "service.stderr.log"),
}))
PY
launchctl bootout "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "✅ 已注册并请求启动后台监工：$LABEL"
echo "✅ 安装后不需要额外执行启动命令；下次登录 Mac 时将自动尝试运行。"
echo "ℹ️  请在 iTerm2 > Settings > General > Magic 勾选 Enable Python API。"
echo "正在执行只读健康检查（无须用户再次输入命令）..."
sleep 2
if ! bash "$ROOT/scripts/status.sh"; then
  echo "⚠️ 后台服务状态未通过检查。请根据输出检查授权与运行日志。" >&2
  exit 1
fi
echo "✅ 安装流程结束。真实容量报错的自动续跑仍需在发生时验证。"
