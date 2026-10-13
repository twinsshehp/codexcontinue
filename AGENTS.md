# AI assistant guidance for codexcontinue

This repository contains a macOS/iTerm2 tool that automatically retries a specific Codex CLI model-capacity warning.

When asked to **install, set up, stop, pause, resume, check, debug, or uninstall** codexcontinue, first read **[AI_INSTALL.md](AI_INSTALL.md)** and follow it. The user-friendly Chinese setup is in README.md and the English documentation is in README.en.md.

Key constraints:
- Do not stop or restart an existing Codex/iTerm2 session unnecessarily.
- Never bypass macOS permissions, terminal approvals, or Codex safety controls.
- Install only when the user requests it. For already-running services, inspect first and avoid accidental replacement.
- Verify that the LaunchAgent is running and the guard has a startup log entry before claiming a working installation.
- A passing test or active background service does *not* prove end-to-end recovery from a real capacity error.


AI command routing (requires authorized local Mac access):
- **Stop / 暂停监工**: Run **bash scripts/stop.sh**, then **bash scripts/status.sh**. Do not stop iTerm2 or Codex. This stop persists until explicitly resumed.
- **Resume / 恢复监工**: Run **bash scripts/start.sh**, then **bash scripts/status.sh**. Never do this in response to a mere status question.
- **Status / 查看自动续跑记录**: Run **bash scripts/status.sh** read-only.
- **Uninstall**: Only run **bash scripts/uninstall.sh** when the user explicitly requests removal.


The installer copies management scripts to the stable local path
**~/Library/Application Support/CodexCapacityGuard/scripts/**.
If the checkout cannot be found, run the scripts from that installed location.
Do not silently reinstall merely to satisfy a stop/status request.
