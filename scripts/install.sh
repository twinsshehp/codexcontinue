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
echo "Installed and started $LABEL"
echo "Enable iTerm2 > Settings > General > Magic > Enable Python API."
echo "Watch: tail -f '$LOGS/supervisor.log'"
