# AI assistant guidance for codexcontinue

This repository contains a macOS/iTerm2 tool that automatically retries a specific Codex CLI model-capacity warning.

When asked to **install, set up, stop, pause, resume, check, debug, or uninstall** codexcontinue, first read **[AI_INSTALL.md](AI_INSTALL.md)** and follow it. The user-friendly Chinese setup is in README.md and the English documentation is in README.en.md.

This AGENTS.md is repository-local guidance for an AI reading this project. **Never install it into a user's global Codex configuration.** The user may have unrelated global AGENTS.md rules that must remain untouched. codexcontinue is a macOS LaunchAgent-backed watcher, **not necessarily a process named codexcontinue**.

Key constraints:
- Do not stop or restart an existing Codex/iTerm2 session unnecessarily.
- Never bypass macOS permissions, terminal approvals, or Codex safety controls.
- Never modify ~/.codex/AGENTS.md, ~/.codex/config.toml, or install a global Codex skill without the user's separate explicit request.
- Install only when the user requests it. For already-running services, inspect first and avoid accidental replacement.
- Verify that the LaunchAgent is running and the guard has a startup log entry before claiming a working installation.
- A passing test or active background service does *not* prove end-to-end recovery from a real capacity error.


AI command routing (requires authorized local Mac access):
**Never assume the AI is in the repository after installation.** Use the stable per-user installed path:
`$HOME/Library/Application Support/CodexCapacityGuard/scripts/`

- **Stop / 暂停**: Run `bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/stop.sh"`; verify with status.sh in the same directory. Do not stop Codex or iTerm2.
- **Resume / 恢复**: Run `bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/start.sh"`, then status.sh. Only on explicit request.
- **Status / 查看记录**: Run `bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/status.sh"` read-only.
- **Uninstall**: Run `bash "$HOME/Library/Application Support/CodexCapacityGuard/scripts/uninstall.sh"` only when the user explicitly asks. Installed control scripts are independent of the original clone.
- If installed management scripts are missing, report that the guard may not be installed. Do NOT guess the clone path or silently reinstall.
