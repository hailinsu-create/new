#!/usr/bin/env python3
"""Tests for snapshot inject. No network, no real grok login."""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "inject-from-snapshot.sh"
ROUTER_MARKER = "grok-cli-router:lningha@gmail.com"


def git_init(path: Path) -> None:
    env = os.environ.copy()
    env["GIT_AUTHOR_NAME"] = "test"
    env["GIT_AUTHOR_EMAIL"] = "test@example.com"
    env["GIT_COMMITTER_NAME"] = "test"
    env["GIT_COMMITTER_EMAIL"] = "test@example.com"
    subprocess.run(["git", "init"], cwd=path, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=path,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "test"],
        cwd=path,
        check=True,
        capture_output=True,
    )


def write_snapshot(root: Path) -> None:
    (root / "grok").mkdir(parents=True)
    (root / "hooks").mkdir()
    (root / "rules").mkdir()
    (root / "AGENTS.md").write_text(
        f"<!-- {ROUTER_MARKER} -->\n# Always use grok.com CLI Extra High Fast\n"
        "lning's grok.com quota (lningha@gmail.com)\n",
        encoding="utf-8",
    )
    (root / "hooks.json").write_text('{"version":1,"hooks":{}}\n', encoding="utf-8")
    (root / "hooks" / "force-grok-cli.py").write_text(
        "#!/usr/bin/env python3\nprint('hook')\n", encoding="utf-8"
    )
    (root / "rules" / "always-use-grok-cli.mdc").write_text(
        "alwaysApply: true\nlningha@gmail.com\n", encoding="utf-8"
    )
    (root / "grok" / "run.sh").write_text("#!/bin/sh\necho snapshot-run\n", encoding="utf-8")
    (root / "grok" / "pin_profile.py").write_text(
        "#!/usr/bin/env python3\nprint('pinned')\n", encoding="utf-8"
    )
    (root / "grok" / "inject-from-snapshot.sh").write_text(
        "#!/bin/sh\necho snapshot-inject\n", encoding="utf-8"
    )


def run_inject(home: Path, root: Path, ws: Path) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["GROK_CURSOR_ROUTER_ROOT"] = str(root)
    env["CURSOR_WORKSPACE"] = str(ws)
    env["GROK_INJECT_SKIP_INSTALL"] = "1"
    env["GROK_INJECT_SKIP_REFRESH"] = "1"
    return subprocess.run(
        ["bash", str(SCRIPT)],
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


class InjectTests(unittest.TestCase):
    def test_empty_git_workspace_gets_router_and_agents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            home = tmp_path / "home"
            root = tmp_path / "snapshot"
            ws = tmp_path / "ws"
            home.mkdir()
            ws.mkdir()
            git_init(ws)
            write_snapshot(root)
            proc = run_inject(home, root, ws)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertTrue((ws / "AGENTS.md").is_file())
            self.assertIn(ROUTER_MARKER, (ws / "AGENTS.md").read_text(encoding="utf-8"))
            self.assertTrue((ws / ".cursor" / "grok" / "run.sh").is_file())
            self.assertTrue((ws / ".cursor" / "hooks" / "force-grok-cli.py").is_file())
            self.assertTrue((home / ".cursor" / "rules" / "always-use-grok-cli.mdc").is_file())
            self.assertTrue((home / ".cursor" / "hooks.json").is_file())
            hooks = (home / ".cursor" / "hooks.json").read_text(encoding="utf-8")
            self.assertIn("force-grok-cli.py", hooks)
            self.assertIn("sessionStart", hooks)

    def test_does_not_overwrite_existing_run_sh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            home = tmp_path / "home"
            root = tmp_path / "snapshot"
            ws = tmp_path / "ws"
            home.mkdir()
            (ws / ".cursor" / "grok").mkdir(parents=True)
            git_init(ws)
            write_snapshot(root)
            tracked = ws / ".cursor" / "grok" / "run.sh"
            tracked.write_text("#!/bin/sh\necho git-run\n", encoding="utf-8")
            proc = run_inject(home, root, ws)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertEqual(tracked.read_text(encoding="utf-8"), "#!/bin/sh\necho git-run\n")
            self.assertTrue((ws / ".cursor" / "grok" / "pin_profile.py").is_file())
            self.assertIn(ROUTER_MARKER, (ws / "AGENTS.md").read_text(encoding="utf-8"))

    def test_prepends_agents_md_when_marker_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            home = tmp_path / "home"
            root = tmp_path / "snapshot"
            ws = tmp_path / "ws"
            home.mkdir()
            ws.mkdir()
            git_init(ws)
            write_snapshot(root)
            (ws / "AGENTS.md").write_text("# Project agents\nkeep me\n", encoding="utf-8")
            proc = run_inject(home, root, ws)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            text = (ws / "AGENTS.md").read_text(encoding="utf-8")
            self.assertIn(ROUTER_MARKER, text)
            self.assertIn("keep me", text)
            self.assertLess(text.find(ROUTER_MARKER), text.find("keep me"))

    def test_leaves_agents_md_when_marker_present(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            home = tmp_path / "home"
            root = tmp_path / "snapshot"
            ws = tmp_path / "ws"
            home.mkdir()
            ws.mkdir()
            git_init(ws)
            write_snapshot(root)
            original = f"<!-- {ROUTER_MARKER} -->\n# already seeded\n"
            (ws / "AGENTS.md").write_text(original, encoding="utf-8")
            proc = run_inject(home, root, ws)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertEqual((ws / "AGENTS.md").read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
