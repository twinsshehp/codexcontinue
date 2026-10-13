#!/usr/bin/env python3
"""Watch Codex CLI in iTerm2 and retry one specific model-capacity error.

The iTerm2 API is imported only when the watchdog actually starts, allowing
pure unit tests to run on Linux and in CI without a running terminal.
"""
from __future__ import annotations

import asyncio
import fcntl
import json
import logging
import os
import re
import subprocess
import sys
import time
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any

STATE_DIR = Path.home() / ".local" / "state" / "codex-capacity-guard"
STATE_FILE = STATE_DIR / "state.json"
LOG_FILE = STATE_DIR / "supervisor.log"
# Persist explicit user choice across iTerm2 restarts and Mac logins.
DISABLED_FILE = (
    Path.home() / "Library" / "Application Support"
    / "CodexCapacityGuard" / "disabled"
)
POLL_SECONDS = 5
RETRY_DELAYS = (30, 60, 120, 240, 300)
CLEAR_SECONDS = 120
DEFAULT_MESSAGE = (
    "Continue the previous unfinished task. Check the work already done first; "
    "do not repeat completed steps. Stop and ask the user if approval is needed."
)

# Match the rendered capacity warning, not arbitrary mentions in the conversation.
CAPACITY_WARNING = re.compile(
    r"^(?:[■▪●]\s*)?selected model is at capacity\."
    r"(?:\s*please try a different model\.)?$",
    re.IGNORECASE,
)
# Codex CLI also renders a placeholder on an EMPTY composer. This is not
# user-entered text: observed in the actual iTerm2 Python API screen contents.
EMPTY_COMPOSER = re.compile(
    r"^[›❯>]\s*(?:Ask Codex to do anything)?\s*$", re.IGNORECASE
)
COMPOSER = re.compile(r"^[›❯>]")
BUSY_OR_APPROVAL = re.compile(
    r"working \(|esc to interrupt|running\s+[\d.]+[km]?\s+tokens|"
    r"press enter to confirm|esc to cancel|approval required|"
    r"do you want to run|yes, proceed",
    re.IGNORECASE,
)
CODEX_JOBS = {"codex", "codex-cli"}


def iterm2_is_running() -> bool:
    """Only monitor while the actual iTerm2 application process exists.

    This is intentionally different from checking for an open Codex session:
    iTerm2 may stay open between Codex tasks.
    """
    try:
        return subprocess.run(
            ["/usr/bin/pgrep", "-x", "iTerm2"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
    except OSError:
        return False


def is_explicitly_stopped() -> bool:
    """Persist user opt-out independently of iTerm2 and Codex sessions."""
    return DISABLED_FILE.is_file()


def is_capacity_waiting(lines: list[str]) -> bool:
    """Conservative screen heuristic: capacity error followed by empty input.

    Cannot distinguish every possible stale screen; see README limitations.
    """
    rows = [str(line).replace("\x00", "").strip() for line in lines]
    rows = [row for row in rows if row]
    tail = rows[-24:]
    hits = [i for i, row in enumerate(tail) if CAPACITY_WARNING.fullmatch(row)]
    if not hits:
        return False
    after = tail[hits[-1] + 1:]
    # The warning must still be near the active prompt, not old scrollback.
    if not after or len(after) > 8:
        return False
    if any(BUSY_OR_APPROVAL.search(row) for row in after):
        return False
    prompts = [(i, row) for i, row in enumerate(after) if COMPOSER.match(row)]
    if not prompts or not EMPTY_COMPOSER.fullmatch(prompts[-1][1]):
        return False
    # Don't submit while the user has typed anything into any newer composer.
    return not any(not EMPTY_COMPOSER.fullmatch(row) for _, row in prompts)


def retry_decision(
    state: dict[str, dict[str, Any]], session_id: str, waiting: bool, now: float
) -> tuple[bool, int]:
    """Return (send_now, previous_attempts), mutating only retry bookkeeping."""
    data = state.get(session_id)
    if not waiting:
        if data is not None:
            data.setdefault("clear_since", now)
            if now - float(data["clear_since"]) >= CLEAR_SECONDS:
                state.pop(session_id, None)
        return False, 0

    if data is None:
        state[session_id] = {"attempts": 0, "next_at": now + RETRY_DELAYS[0]}
        return False, 0

    data.pop("clear_since", None)
    attempts = max(0, min(len(RETRY_DELAYS), int(data.get("attempts", 0))))
    if attempts >= len(RETRY_DELAYS):
        return False, attempts
    return now >= float(data.get("next_at", now + RETRY_DELAYS[0])), attempts


def mark_sent(
    state: dict[str, dict[str, Any]], session_id: str, attempts: int, now: float
) -> None:
    state[session_id]["attempts"] = attempts + 1
    next_delay = RETRY_DELAYS[min(attempts + 1, len(RETRY_DELAYS) - 1)]
    state[session_id]["next_at"] = now + next_delay


def load_state() -> dict[str, dict[str, Any]]:
    try:
        parsed = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return parsed if isinstance(parsed, dict) else {}
    except (OSError, ValueError):
        return {}


def save_state(state: dict[str, dict[str, Any]]) -> None:
    temp = STATE_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(STATE_FILE)


def make_logger() -> logging.Logger:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    log = logging.getLogger("codex-capacity-guard")
    log.setLevel(logging.INFO)
    if not log.handlers:
        handler = RotatingFileHandler(
            LOG_FILE, maxBytes=1_000_000, backupCount=2, encoding="utf-8"
        )
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        log.addHandler(handler)
    return log


async def submit_continuation(session: Any, message: str) -> None:
    """Enter Codex prompt text and submit with a distinct Return keystroke.

    Sending message + "\\n" in one iTerm2 API call is treated as pasted
    composer text by Codex CLI; it does NOT necessarily press Enter.
    """
    await session.async_send_text(message, suppress_broadcast=True)
    # Let the TUI process the pasted text before sending the actual Enter key.
    await asyncio.sleep(0.25)
    await session.async_send_text("\r", suppress_broadcast=True)


async def supervise(connection: Any) -> None:
    import iterm2

    state = load_state()
    logger = make_logger()
    message = os.environ.get("CAPACITY_GUARD_MESSAGE", DEFAULT_MESSAGE).strip()
    if not message or "\n" in message or "\r" in message:
        raise ValueError("CAPACITY_GUARD_MESSAGE must be a single nonempty line")

    logger.info("Started: Codex CLI only; capacity errors only; maximum 5 retries")
    while True:
        if is_explicitly_stopped():
            logger.info("User requested stop; watcher stopping")
            return
        if not iterm2_is_running():
            logger.info("iTerm2 has exited; watcher stopping")
            return
        try:
            app = await iterm2.async_get_app(connection)
            sessions = [s for w in app.windows for tab in w.tabs for s in tab.sessions]
            dirty = False
            for session in sessions:
                job_name = (await session.async_get_variable("jobName") or "").lower()
                if job_name not in CODEX_JOBS:
                    continue
                screen = await session.async_get_screen_contents()
                lines = [screen.line(i).string for i in range(screen.number_of_lines)]
                sid = session.session_id
                now = time.time()
                waiting = is_capacity_waiting(lines)
                first_seen = waiting and sid not in state
                existed = sid in state
                should_send, attempts = retry_decision(state, sid, waiting, now)
                if first_seen:
                    logger.info("Capacity error on session %s; retry after 30s", sid[:12])
                if should_send:
                    # Recheck right before sending to avoid touching active user input.
                    latest = await session.async_get_screen_contents()
                    new_lines = [
                        latest.line(i).string for i in range(latest.number_of_lines)
                    ]
                    if (
                        is_capacity_waiting(new_lines)
                        and not is_explicitly_stopped()
                        and iterm2_is_running()
                    ):
                        await submit_continuation(session, message)
                        mark_sent(state, sid, attempts, time.time())
                        logger.warning(
                            "Sent continuation (text + Enter): session %s, attempt %d/5",
                            sid[:12], attempts + 1,
                        )
                        if attempts + 1 >= len(RETRY_DELAYS):
                            logger.error("Maximum retries reached for %s", sid[:12])
                if first_seen or waiting or existed:
                    dirty = True
            if dirty:
                save_state(state)
        except Exception:
            logger.exception("Check failed; no input sent for failed check")
        await asyncio.sleep(POLL_SECONDS)


def main() -> None:
    if len(sys.argv) > 1:
        if sys.argv[1:] == ["--check"]:
            print("Codex Capacity Guard script and dependencies must be checked at runtime.")
            return
        raise SystemExit("Usage: python capacity_guard.py [--check]")
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "watcher.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit("Another Codex Capacity Guard is already running")
        if is_explicitly_stopped():
            make_logger().info("User opted out; watchdog exits without starting")
            return
        if not iterm2_is_running():
            make_logger().info("iTerm2 is not running; watchdog exits without waiting")
            return
        import iterm2

        iterm2.run_until_complete(supervise)


if __name__ == "__main__":
    main()
