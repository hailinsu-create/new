#!/usr/bin/env python3
"""Tests for Extra High Fast pin merge. No network, no real auth."""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pin_profile  # noqa: E402


class PinProfileTests(unittest.TestCase):
    def test_overlay_pins_empty_env(self) -> None:
        overlay = pin_profile.grok_config_overlay("")
        self.assertEqual(overlay["models"]["default"], "grok-4.6")
        self.assertEqual(overlay["models"]["default_reasoning_effort"], "xhigh")
        self.assertEqual(
            overlay["models"]["extra_headers"]["x-grok-service-tier"],
            "priority",
        )

    def test_overlay_wins_over_weaker_existing_config(self) -> None:
        raw = json.dumps(
            {
                "models": {
                    "default": "grok-4.5",
                    "default_reasoning_effort": "low",
                    "extra_headers": {"x-grok-service-tier": "default"},
                },
                "keep": True,
            }
        )
        overlay = pin_profile.grok_config_overlay(raw)
        self.assertTrue(overlay["keep"])
        self.assertEqual(overlay["models"]["default"], "grok-4.6")
        self.assertEqual(overlay["models"]["default_reasoning_effort"], "xhigh")
        self.assertEqual(
            overlay["models"]["extra_headers"]["x-grok-service-tier"],
            "priority",
        )

    def test_overlay_ignores_malformed_json(self) -> None:
        overlay = pin_profile.grok_config_overlay("{not json")
        self.assertEqual(overlay["models"]["default"], "grok-4.6")
        self.assertEqual(overlay["models"]["default_reasoning_effort"], "xhigh")

    def test_user_config_appends_models(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.toml"
            path.write_text("[cli]\ninstaller = \"internal\"\n", encoding="utf-8")
            pin_profile.write_user_config(path)
            text = path.read_text(encoding="utf-8")
            self.assertIn("[cli]", text)
            self.assertIn("[models]", text)
            self.assertIn('default = "grok-4.6"', text)
            self.assertIn('default_reasoning_effort = "xhigh"', text)
            self.assertIn('x-grok-service-tier" = "priority"', text)

    def test_user_config_updates_existing_models_without_duplicate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.toml"
            path.write_text(
                "[models]\n"
                'default = "grok-4.5"\n'
                'default_reasoning_effort = "high"\n'
                'session_summary = "grok-4.6"\n',
                encoding="utf-8",
            )
            pin_profile.write_user_config(path)
            text = path.read_text(encoding="utf-8")
            self.assertEqual(text.count("[models]"), 1)
            self.assertIn('default = "grok-4.6"', text)
            self.assertNotIn('default = "grok-4.5"', text)
            self.assertIn('default_reasoning_effort = "xhigh"', text)
            self.assertIn('session_summary = "grok-4.6"', text)
            self.assertIn("x-grok-service-tier", text)


if __name__ == "__main__":
    unittest.main()
