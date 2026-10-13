"""Offline tests: no iTerm2 session or Codex account required."""
import unittest

from capacity_guard import (
    RETRY_DELAYS,
    is_capacity_waiting,
    mark_sent,
    retry_decision,
)


class ScreenDetectionTests(unittest.TestCase):
    WARNING = "Selected model is at capacity. Please try a different model."

    def test_capacity_error_and_empty_codex_composer(self):
        self.assertTrue(is_capacity_waiting([self.WARNING, "", "›"]))
        self.assertTrue(is_capacity_waiting(["■ " + self.WARNING, "›"]))

    def test_busy_or_approval_never_nudged(self):
        for status in (
            "Working (15s)", "esc to interrupt", "Press enter to confirm",
            "Approval required", "1. Yes, proceed",
        ):
            with self.subTest(status=status):
                self.assertFalse(is_capacity_waiting([self.WARNING, status, "›"]))

    def test_human_draft_never_submitted(self):
        self.assertFalse(is_capacity_waiting([self.WARNING, "› 继续"]))
        self.assertFalse(is_capacity_waiting([self.WARNING, "› user draft", "›"]))

    def test_no_matching_error(self):
        self.assertFalse(is_capacity_waiting(["All tests passed", "›"]))
        self.assertFalse(is_capacity_waiting(["Rate limit exceeded", "›"]))
        self.assertFalse(is_capacity_waiting([self.WARNING]))

    def test_not_confused_by_user_mentioning_warning(self):
        self.assertFalse(is_capacity_waiting(["› " + self.WARNING, "›"]))

    def test_stale_error_in_scrollback_is_ignored(self):
        self.assertFalse(
            is_capacity_waiting([self.WARNING] + ["Progress line"] * 12 + ["›"])
        )

    def test_nul_padded_terminal_rows(self):
        self.assertTrue(
            is_capacity_waiting(["\x00" + self.WARNING + "\x00", "\x00›\x00"])
        )


class RetryTests(unittest.TestCase):
    def test_wait_before_first_retry(self):
        state = {}
        self.assertEqual(retry_decision(state, "s1", True, 100), (False, 0))
        self.assertEqual(retry_decision(state, "s1", True, 129), (False, 0))
        self.assertEqual(retry_decision(state, "s1", True, 130), (True, 0))

    def test_backoff_and_retry_limit(self):
        state = {}
        now = 10.0
        retry_decision(state, "s1", True, now)
        now += RETRY_DELAYS[0]
        for i in range(5):
            self.assertEqual(retry_decision(state, "s1", True, now), (True, i))
            mark_sent(state, "s1", i, now)
            self.assertFalse(retry_decision(state, "s1", True, now + 1)[0])
            now += RETRY_DELAYS[min(i + 1, 4)]
        self.assertEqual(retry_decision(state, "s1", True, now + 10000), (False, 5))

    def test_reset_after_successful_period(self):
        state = {}
        retry_decision(state, "s", True, 0)
        mark_sent(state, "s", 0, 30)
        retry_decision(state, "s", False, 40)
        self.assertIn("s", state)
        retry_decision(state, "s", False, 160)
        self.assertNotIn("s", state)
        self.assertFalse(retry_decision(state, "s", True, 161)[0])

    def test_multiple_sessions_are_independent(self):
        state = {}
        retry_decision(state, "a", True, 0)
        retry_decision(state, "b", True, 50)
        self.assertTrue(retry_decision(state, "a", True, 31)[0])
        self.assertFalse(retry_decision(state, "b", True, 31)[0])

    def test_idle_sessions_create_no_state(self):
        state = {}
        self.assertEqual(retry_decision(state, "idle", False, 0), (False, 0))
        self.assertEqual(state, {})


if __name__ == "__main__":
    unittest.main()
