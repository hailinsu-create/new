"""Deprecated shim: fox/centaur still scoring is Cursor-only.

Import ``cursor_still_score`` directly. This module re-exports for old callers.
"""

from __future__ import annotations

from cursor_still_score import *  # noqa: F403
from cursor_still_score import (  # noqa: F401
    EIGHT,
    LOCK_FACE,
    PASS_LINE,
    PROMPT_FILE,
    ROOT,
    SCORER,
    STILL_DIR,
    apply_score,
    find_agent_payload,
    is_blocking,
    normalise,
    parse_score,
    request_path,
    score_failure_line,
    score_image,
    score_pending_line,
    score_prompt,
    write_score_request,
)

# Back-compat names some tests/docs might still mention.
def codex_binary():
    return None


def codex_logged_in(_binary: str) -> bool:
    return False


def codex_argv(*_a, **_k):
    raise RuntimeError("Codex scoring removed; use cursor_still_score.apply_score")
