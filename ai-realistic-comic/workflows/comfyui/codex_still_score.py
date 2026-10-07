"""Codex-only scorer for the fox/centaur stills.

Asset-side scoring never falls back to another model. If the Codex CLI is
missing, logged out, out of quota, times out, or returns unparseable JSON, the
result is `SCORE_FAILED codex ... reason=<why>` plus a sidecar. No Grok, no
DeepSeek vision, no local guess.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STILL_DIR = ROOT / "library" / "stills" / "fox-centaur-embrace"
CODEX_HOME_BIN = Path.home() / ".local" / "bin" / "codex"
EIGHT = ("identity", "distinction", "interaction", "aesthetics", "anatomy", "wardrobe", "motif", "photoreal")
PASS_LINE = 9.0
PROMPT_FILE = {"nude": "score-nude.txt", "torn": "score-torn.txt"}
LOCK_FACE = {
    "lin": ROOT / "library" / "cast" / "lin_wantang" / "ref-face.png",
    "elena": ROOT / "library" / "cast" / "elena_voss" / "ref-face.png",
}
TIMEOUT_SECONDS = 600


def codex_binary() -> str | None:
    found = shutil.which("codex")
    if found:
        return found
    if CODEX_HOME_BIN.exists():
        return str(CODEX_HOME_BIN)
    return None


def codex_logged_in(binary: str) -> bool:
    try:
        result = subprocess.run([binary, "login", "status"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return "Logged in" in f"{result.stdout}\n{result.stderr}"


def score_failure_line(actor: str, mode: str, reason: str) -> str:
    detail = " ".join((reason or "unknown").split())
    return f"SCORE_FAILED codex {actor} {mode} reason={detail}"


def parse_score(text: str) -> dict:
    """Last JSON object in the output that carries the eight fields."""
    candidates = re.findall(r"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}", text, flags=re.DOTALL)
    for chunk in reversed(candidates):
        try:
            item = json.loads(chunk)
        except json.JSONDecodeError:
            continue
        if all(key in item for key in EIGHT):
            return item
    raise ValueError("no score JSON with the eight fields")


def normalise(item: dict) -> dict:
    scores = {key: float(item[key]) for key in EIGHT}
    mean = round(sum(scores.values()) / len(EIGHT), 4)
    gates = [str(g) for g in (item.get("gates") or [])]
    out = {**{k: (int(v) if v == int(v) else v) for k, v in scores.items()}}
    out.update(
        {
            "mean": mean,
            "gates": gates,
            "notes": str(item.get("notes") or ""),
            "scorer": "codex",
            "passed": bool(mean >= PASS_LINE and not gates),
            "below": [k for k, v in scores.items() if v < PASS_LINE],
        }
    )
    return out


def score_prompt(actor: str, mode: str, image: Path, lock: Path) -> str:
    body = (STILL_DIR / PROMPT_FILE[mode]).read_text(encoding="utf-8").strip()
    return f"{body}\n\nActor: {actor}. Mode: {mode}.\n第一张是锁脸：{lock}\n第二张是待打分图：{image}\n"


def codex_argv(binary: str, cwd: str, images: list[str]) -> list[str]:
    argv = [binary, "exec", "--skip-git-repo-check", "--ephemeral", "--color", "never", "-C", cwd, "-s", "read-only"]
    for path in images:
        argv += ["-i", path]
    argv.append("-")
    return argv


def score_image(actor: str, mode: str, image: Path, *, sidecar: Path | None = None) -> dict:
    """Return the sidecar dict. Always writes it. Never raises for scorer problems."""
    sidecar = sidecar or image.with_suffix(".json")
    result = _score(actor, mode, image)
    sidecar.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    if result.get("score_failed"):
        print(result["line"], flush=True)
        fail = image.with_suffix(".score-fail.json")
        fail.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        print(
            f"SCORE codex {actor} {mode} mean={result['mean']} gates={result['gates']} passed={result['passed']}",
            flush=True,
        )
    return result


def _score(actor: str, mode: str, image: Path) -> dict:
    binary = codex_binary()
    if binary is None:
        return _failed(actor, mode, "cli_missing")
    if not codex_logged_in(binary):
        return _failed(actor, mode, "not_logged_in")
    lock = LOCK_FACE[actor]
    prompt = score_prompt(actor, mode, image, lock)
    with tempfile.TemporaryDirectory() as tmp:
        argv = codex_argv(binary, tmp, [str(lock), str(image)])
        try:
            run = subprocess.run(argv, input=prompt, capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            return _failed(actor, mode, "timeout")
        except OSError as exc:
            return _failed(actor, mode, f"cli_error {exc}")
    text = f"{run.stdout}\n{run.stderr}"
    if run.returncode != 0 and re.search(r"usage limit|rate limit|quota", text, re.IGNORECASE):
        return _failed(actor, mode, "quota")
    try:
        return normalise(parse_score(run.stdout))
    except (ValueError, KeyError, TypeError) as exc:
        return _failed(actor, mode, f"parse_failed {exc}")


def _failed(actor: str, mode: str, reason: str) -> dict:
    return {
        "score_failed": True,
        "scorer": "codex",
        "reason": reason,
        "line": score_failure_line(actor, mode, reason),
        "passed": False,
        "mean": None,
        "gates": [],
    }
