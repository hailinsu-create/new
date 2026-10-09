"""Scoring CANCELLED for fox/centaur stills.

Usability is decided by Cursor looking at the result PNGs (visual judgment).
Numeric mean / hard-gate sidecars, SCORE_PENDING loops, and pass lines are retired.

This module remains importable so old scripts and tests do not hard-crash. Calls
print ``SCORING_CANCELLED`` / ``VISUAL_JUDGE`` and write a tiny note sidecar; they
never block bringup or hillclimb.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STILL_DIR = ROOT / "library" / "stills" / "fox-centaur-embrace"
EIGHT = ("identity", "distinction", "interaction", "aesthetics", "anatomy", "wardrobe", "motif", "photoreal")
PASS_LINE = 9.0  # kept for normalise() legacy helpers only; not used as a gate
PROMPT_FILE = {"nude": "score-nude.txt", "torn": "score-torn.txt"}
LOCK_FACE = {
    "lin": ROOT / "library" / "cast" / "lin_wantang" / "ref-face.png",
    "elena": ROOT / "library" / "cast" / "elena_voss" / "ref-face.png",
}
SCORER = "cursor"
SCORING_CANCELLED = True


def score_failure_line(actor: str, mode: str, reason: str) -> str:
    detail = " ".join((reason or "unknown").split())
    return f"SCORE_FAILED {SCORER} {actor} {mode} reason={detail}"


def score_pending_line(actor: str, mode: str) -> str:
    return f"VISUAL_JUDGE {SCORER} {actor} {mode}"


def parse_score(text: str) -> dict:
    """Legacy helper: last JSON object carrying the eight fields."""
    import re

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
    """Legacy helper for old payloads. Does not gate bringup."""
    scores = {key: float(item[key]) for key in EIGHT}
    mean = round(sum(scores.values()) / len(EIGHT), 4)
    gates = [str(g) for g in (item.get("gates") or [])]
    out = {**{k: (int(v) if v == int(v) else v) for k, v in scores.items()}}
    out.update(
        {
            "mean": mean,
            "gates": gates,
            "notes": str(item.get("notes") or ""),
            "scorer": SCORER,
            "passed": bool(mean >= PASS_LINE and not gates),
            "below": [k for k, v in scores.items() if v < PASS_LINE],
            "scoring_cancelled": True,
        }
    )
    if "tail_count" in item:
        out["tail_count"] = item["tail_count"]
    return out


def score_prompt(actor: str, mode: str, image: Path, lock: Path) -> str:
    return (
        f"Scoring cancelled. Judge by eye.\nActor: {actor}. Mode: {mode}.\n"
        f"Lock face: {lock}\nImage: {image}\n"
    )


def request_path(image: Path) -> Path:
    return image.with_suffix(".score-request.json")


def agent_payload_path(image: Path) -> Path:
    return image.with_suffix(".cursor-score.json")


def write_score_request(actor: str, mode: str, image: Path) -> Path:
    """No longer writes SCORE_PENDING requests."""
    path = request_path(image)
    if path.exists():
        path.unlink()
    return path


def is_blocking(payload: dict | None) -> bool:
    """Scoring cancelled — never block torn / bringup on score state."""
    return False


def score_image(actor: str, mode: str, image: Path) -> dict:
    """Record a visual-judge note. Never pending, never a pass/fail gate."""
    lock = LOCK_FACE[actor]
    result = {
        "scorer": SCORER,
        "scoring_cancelled": True,
        "visual_judge": True,
        "actor": actor,
        "mode": mode,
        "image": str(image),
        "lock_face": str(lock),
        "passed": None,
        "mean": None,
        "gates": [],
        "score_pending": False,
        "notes": "Scoring cancelled. Cursor judges the PNG by eye.",
        "line": f"VISUAL_JUDGE {SCORER} {actor} {mode}",
    }
    sidecar = image.with_suffix(".json")
    sidecar.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    req = request_path(image)
    if req.exists():
        req.unlink()
    print(f"SCORING_CANCELLED {actor} {mode}", flush=True)
    print(result["line"] + f" {image}", flush=True)
    return result


def apply_cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("actor", choices=("lin", "elena"))
    parser.add_argument("mode", choices=("nude", "torn"))
    parser.add_argument("image", type=Path)
    args = parser.parse_args(argv)
    score_image(args.actor, args.mode, args.image)
    return 0


if __name__ == "__main__":
    raise SystemExit(apply_cli())
