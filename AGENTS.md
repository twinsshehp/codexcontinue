# AI assistant guidance for codexcontinue

This repository contains a macOS/iTerm2 tool that automatically retries a specific Codex CLI model-capacity warning.

When asked to **install, set up, check, debug, or uninstall** codexcontinue, first read **[AI_INSTALL.md](AI_INSTALL.md)** and follow it. The user-friendly Chinese setup is in README.md and the English documentation is in README.en.md.

Key constraints:
- Do not stop or restart an existing Codex/iTerm2 session unnecessarily.
- Never bypass macOS permissions, terminal approvals, or Codex safety controls.
- Install only when the user requests it. For already-running services, inspect first and avoid accidental replacement.
- Verify that the LaunchAgent is running and the guard has a startup log entry before claiming a working installation.
- A passing test or active background service does *not* prove end-to-end recovery from a real capacity error.
