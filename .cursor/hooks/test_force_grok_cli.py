#!/usr/bin/env python3
"""Tests for Cursor deny-hooks. No network."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent / "force-grok-cli.py"


def run_hook(payload: dict, env: dict | None = None) -> dict:
    merged = os.environ.copy()
    merged.pop("GROK_AGENT", None)
    if env:
        merged.update(env)
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        env=merged,
        check=False,
    )
    self_ok = proc.returncode == 0
    if not self_ok:
        raise AssertionError(proc.stderr or proc.stdout or "hook failed")
    return json.loads(proc.stdout)


class ForceGrokCliTests(unittest.TestCase):
    def test_session_start_injects_lning_account(self) -> None:
        out = run_hook({"hook_event_name": "sessionStart"})
        ctx = out.get("additional_context", "")
        self.assertEqual(out.get("permission"), "allow")
        self.assertIn("lningha@gmail.com", ctx)
        self.assertIn("run.sh", ctx)
        self.assertIn("hailinsu@gmail.com", ctx)

    def test_write_denied_for_cursor(self) -> None:
        out = run_hook({"hook_event_name": "preToolUse", "tool_name": "Write"})
        self.assertEqual(out.get("permission"), "deny")
        self.assertIn("lningha@gmail.com", out.get("agent_message", ""))

    def test_git_shell_allowed(self) -> None:
        out = run_hook(
            {
                "hook_event_name": "beforeShellExecution",
                "command": "git status",
            }
        )
        self.assertEqual(out.get("permission"), "allow")

    def test_run_sh_shell_allowed(self) -> None:
        out = run_hook(
            {
                "hook_event_name": "beforeShellExecution",
                "command": "bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt",
            }
        )
        self.assertEqual(out.get("permission"), "allow")

    def test_random_shell_denied(self) -> None:
        out = run_hook(
            {
                "hook_event_name": "beforeShellExecution",
                "command": "python3 setup.py install",
            }
        )
        self.assertEqual(out.get("permission"), "deny")

    def test_subagent_denied(self) -> None:
        out = run_hook({"hook_event_name": "subagentStart", "tool_name": "Task"})
        self.assertEqual(out.get("permission"), "deny")

    def test_grok_agent_noop_allows_write(self) -> None:
        out = run_hook(
            {"hook_event_name": "preToolUse", "tool_name": "Write"},
            env={"GROK_AGENT": "1"},
        )
        self.assertEqual(out.get("permission"), "allow")


if __name__ == "__main__":
    unittest.main()
