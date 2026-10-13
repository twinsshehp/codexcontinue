# codexcontinue

A small, **unofficial** watchdog for OpenAI Codex CLI running in **iTerm2 on macOS**.

When Codex displays:

~~~text
Selected model is at capacity. Please try a different model.
~~~

...and returns to an empty input prompt, the guard waits and sends a follow-up to **the same iTerm2 session**. It uses iTerm2's supported Python API instead of synthetic keystrokes or a Codex Stop hook.

[简体中文 / Chinese README](README.md)

## The problem

When Codex CLI stops after a model-capacity error, someone has to type "continue" to get it moving again.

![Codex capacity warning in iTerm2](assets/codex-capacity-error.png)

This guard watches the specific capacity error in your active iTerm2 Codex session, then retries with a bounded delay.

## Recommended: install by chatting with an AI

**No terminal experience needed**—if your AI assistant can actually access your Mac's files and shell (for example, a local Codex session, or ChatGPT with an authorized local-computer connector), copy and send this message:

~~~text
Please install the GitHub project https://github.com/twinsshehp/codexcontinue
on my Mac. Read AI_INSTALL.md and AGENTS.md from that repository first.
With my authorization, perform the environment checks, clone the repository,
install the tool, start its background service, and verify it is running.
Do not merely send me shell commands to copy. Do not stop my current
iTerm2/Codex tasks, bypass security prompts, or claim success without proof.
Ask me only when I must approve a macOS/iTerm2 permission.
Finally, report whether installation succeeded and what remains unverified.
~~~

**After installation the watchdog starts automatically, and attempts to start again when you log in. There is no separate manual startup step.** The service and log commands below are optional checks for developers—not extra tasks every user must perform.

An ordinary web-only AI chat without local access **cannot** directly install software on your computer. The assistant must have an authorized tool to operate on your Mac.

See [AI installation instructions](AI_INSTALL.md) for the exact checklist and safe validation rules.

## First: enable the iTerm2 Python API

Open **iTerm2 → Settings → General → Magic**, then enable **Python API**:

![iTerm2 Python API setting](assets/iterm2-python-api.png)

You normally do not need to restart Codex. For the complete illustrated setup, see the [Chinese step-by-step guide](README.md).

## What it does

- Checks open iTerm2 sessions every **5 seconds**, filtering for foreground Codex jobs.
- Looks for the **specific model-capacity error** and an **empty Codex input prompt**.
- Uses an initial delay of **30 seconds**, followed by **60, 120, 240, and 300 seconds** between retries, up to **five** automated continuations per error episode.
- Re-checks the screen immediately before sending a message.
- Never intentionally approves commands, changes models, or bypasses Codex permissions.
- Persists retry counters, logs actions, and runs as a per-user macOS LaunchAgent.

> **Important:** Screen detection is heuristic. It may miss errors or mistake stale screen content for a live error in rare cases. The watchdog cannot guarantee that a task completes, and it has **not yet been end-to-end verified against a live model-capacity error**. It will not revive a terminated Codex process. Review the script before allowing it to type into your terminal.

## Requirements

- macOS with [iTerm2](https://iterm2.com/); enable **Settings → General → Magic → Enable Python API**
- Codex CLI running **inside iTerm2**, foreground program named codex
- Python **3.10+** with venv and pip
- An internet connection during installation for the iterm2 Python package

Codex Desktop, Terminal.app, tmux terminals outside iTerm2, and ChatGPT browser conversations are **not** supported.

## Manual installation (optional)

~~~bash
git clone https://github.com/twinsshehp/codexcontinue.git
cd codexcontinue
bash scripts/install.sh
~~~

**The installer already registers and starts the service—no second launch command is needed.**

The installer creates a private Python environment under
**~/Library/Application Support/CodexCapacityGuard/** and registers a user LaunchAgent.

You can keep your existing Codex CLI session running; no Codex restart is required. **Do not run multiple instances of the watchdog in parallel.**

## Check service status (optional)

~~~bash
# Service status
launchctl print gui/$(id -u)/com.peakmain.codex-capacity-guard

# Detection and retry events
tail -f ~/.local/state/codex-capacity-guard/supervisor.log

# Runtime errors
tail -f ~/.local/state/codex-capacity-guard/service.stderr.log
~~~

The guard does **not** need to display a terminal window. Startup appears in the log. It sends no message unless the error and prompt conditions are met. You can ask an AI with local Mac access to run **bash scripts/status.sh** instead of typing these commands yourself.

## Customize the continuation message

The default message is:

> Continue the previous unfinished task. Check the work already done first; do not repeat completed steps. Stop and ask the user if approval is needed.

You can add **CAPACITY_GUARD_MESSAGE** to the LaunchAgent's **EnvironmentVariables** dictionary if you prefer another one-line prompt; then reload the LaunchAgent. Don't use it to circumvent approvals.

## Pause, restart, uninstall

~~~bash
# Stop until next login or manual bootstrap
launchctl bootout gui/$(id -u)/com.peakmain.codex-capacity-guard

# Start again
launchctl bootstrap gui/$(id -u) \
  "$HOME/Library/LaunchAgents/com.peakmain.codex-capacity-guard.plist"

# Uninstall (retains diagnostic logs)
bash scripts/uninstall.sh
~~~

## Tests

~~~bash
python3 -m unittest discover -s tests -v
~~~

Tests cover prompt matching, non-capacity errors, approval/busy states, user drafts, stale scrollback, backoff, retry limits, and reset behavior. They run without iTerm2.

## How it works

~~~text
iTerm2 Python API
    |
    +-- Is foreground job Codex CLI? -- no --> ignore
    |
    +-- Inspect terminal screen
         |
         +-- Capacity error AND empty prompt --> backoff
         |                                      |
         |                                recheck and send
         |
         +-- Anything else -------------------> do nothing
~~~

Logs and retry state stay local under **~/.local/state/codex-capacity-guard/**.
The guard needs no OpenAI API key and has no separate telemetry service.

## Limitations and safety

- iTerm2 Python API permissions must be enabled locally.
- If you type at the instant the guard sends text, there is a small race condition.
- CLI UI changes may invalidate the screen heuristic.
- If the error is not on the visible terminal screen, it may not be detected.
- Five failed retries require manual attention; no automatic model switching.
- Codex Stop hooks may not fire for server overloads, so this tool observes iTerm2 directly.

**License:** MIT. **Not affiliated with or endorsed by OpenAI or iTerm2.**
