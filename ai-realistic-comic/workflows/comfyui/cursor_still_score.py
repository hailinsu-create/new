"""Cursor-only scorer for the fox/centaur stills.

Asset-side scoring is done by the Cursor agent (Read lock face + result, emit
JSON). This module normalises / writes sidecars and score-request files for the
agent. No Codex CLI, no Grok, no DeepSeek vision, no local guess.

Flow:
  1. ``score_image`` looks for an agent payload (``.cursor-score.json`` next to
     the PNG, or ``CURSOR_STILL_SCORE_JSON`` env pointing at a JSON object /
     map). If found, write the sidecar and return.
  2. Otherwise write a ``.score-request.json`` and return SCORE_PENDING so
     bringup can leave the machine on for the agent to score.
  3. Agent applies scores with ``apply`` (CLI) or by writing
     ``.cursor-score.json`` and re-running ``score_image`` / ``--score-only``.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STILL_DIR = ROOT / "library" / "stills" / "fox-centaur-embrace"
EIGHT = ("identity", "distinction", "interaction", "aesthetics", "anatomy", "wardrobe", "motif", "photoreal")
PASS_LINE = 9.0
PROMPT_FILE = {"nude": "score-nude.txt", "torn": "score-torn.txt"}
LOCK_FACE = {
    "lin": ROOT / "library" / "cast" / "lin_wantang" / "ref-face.png",
    "elena": ROOT / "library" / "cast" / "elena_voss" / "ref-face.png",
}
SCORER = "cursor"


def score_failure_line(actor: str, mode: str, reason: str) -> str:
    detail = " ".join((reason or "unknown").split())
    return f"SCORE_FAILED {SCORER} {actor} {mode} reason={detail}"


def score_pending_line(actor: str, mode: str) -> str:
    return f"SCORE_PENDING {SCORER} {actor} {mode}"


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
            "scorer": SCORER,
            "passed": bool(mean >= PASS_LINE and not gates),
            "below": [k for k, v in scores.items() if v < PASS_LINE],
        }
    )
    if "tail_count" in item:
        out["tail_count"] = item["tail_count"]
    return out


def score_prompt(actor: str, mode: str, image: Path, lock: Path) -> str:
    body = (STILL_DIR / PROMPT_FILE[mode]).read_text(encoding="utf-8").strip()
    return f"{body}\n\nActor: {actor}. Mode: {mode}.\n第一张是锁脸：{lock}\n第二张是待打分图：{image}\n"


def request_path(image: Path) -> Path:
    return image.with_suffix(".score-request.json")


def agent_payload_path(image: Path) -> Path:
    return image.with_suffix(".cursor-score.json")


def write_score_request(actor: str, mode: str, image: Path) -> Path:
    lock = LOCK_FACE[actor]
    payload = {
        "scorer": SCORER,
        "actor": actor,
        "mode": mode,
        "image": str(image),
        "lock_face": str(lock),
        "prompt": score_prompt(actor, mode, image, lock),
        "pass_line": PASS_LINE,
        "eight": list(EIGHT),
    }
    path = request_path(image)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _payload_from_env(actor: str, mode: str, image: Path) -> dict | None:
    raw = os.environ.get("CURSOR_STILL_SCORE_JSON", "").strip()
    if not raw:
        return None
    path = Path(raw)
    if path.is_file():
        data = _load_json(path)
    else:
        data = json.loads(raw)
    if all(key in data for key in EIGHT):
        return data
    key = f"{actor}:{mode}"
    stem = image.stem
    for candidate in (key, stem, f"{actor}-{mode}"):
        if isinstance(data, dict) and candidate in data and all(k in data[candidate] for k in EIGHT):
            return data[candidate]
    return None


def find_agent_payload(actor: str, mode: str, image: Path) -> dict | None:
    side = agent_payload_path(image)
    if side.is_file():
        data = _load_json(side)
        if all(key in data for key in EIGHT):
            return data
    return _payload_from_env(actor, mode, image)


def apply_score(actor: str, mode: str, image: Path, payload: dict, *, sidecar: Path | None = None) -> dict:
    """Normalise an agent score payload and write the sidecar."""
    sidecar = sidecar or image.with_suffix(".json")
    if all(k in payload for k in EIGHT):
        result = normalise(payload)
    else:
        result = normalise(parse_score(json.dumps(payload)))
    sidecar.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    fail = image.with_suffix(".score-fail.json")
    if fail.exists():
        fail.unlink()
    req = request_path(image)
    if req.exists():
        req.unlink()
    print(
        f"SCORE {SCORER} {actor} {mode} mean={result['mean']} gates={result['gates']} passed={result['passed']}",
        flush=True,
    )
    return result


def score_image(actor: str, mode: str, image: Path, *, sidecar: Path | None = None) -> dict:
    """Return the sidecar dict. Always writes it. Never raises for scorer problems."""
    sidecar = sidecar or image.with_suffix(".json")
    payload = find_agent_payload(actor, mode, image)
    if payload is not None:
        try:
            return apply_score(actor, mode, image, payload, sidecar=sidecar)
        except (ValueError, KeyError, TypeError) as exc:
            result = _failed(actor, mode, f"parse_failed {exc}")
            sidecar.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(result["line"], flush=True)
            image.with_suffix(".score-fail.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            return result

    write_score_request(actor, mode, image)
    result = _pending(actor, mode)
    sidecar.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(result["line"], flush=True)
    print(f"SCORE_REQUEST {request_path(image)}", flush=True)
    return result


def is_blocking(result: dict) -> bool:
    """True when torn / keep must wait — pending, failed, or hard clothes gates."""
    if result.get("score_failed") or result.get("score_pending"):
        return True
    gates = set(result.get("gates") or [])
    return bool(gates & {"clothes_remain", "armor_remain"})


def _pending(actor: str, mode: str) -> dict:
    return {
        "score_pending": True,
        "scorer": SCORER,
        "reason": "awaiting_cursor_agent",
        "line": score_pending_line(actor, mode),
        "passed": False,
        "mean": None,
        "gates": [],
    }


def _failed(actor: str, mode: str, reason: str) -> dict:
    return {
        "score_failed": True,
        "scorer": SCORER,
        "reason": reason,
        "line": score_failure_line(actor, mode, reason),
        "passed": False,
        "mean": None,
        "gates": [],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    apply_p = sub.add_parser("apply", help="Write a Cursor score sidecar from JSON.")
    apply_p.add_argument("--actor", choices=("lin", "elena"), required=True)
    apply_p.add_argument("--mode", choices=("nude", "torn"), required=True)
    apply_p.add_argument("--image", type=Path, required=True)
    apply_p.add_argument("--json", dest="json_text", help="Score JSON object or path to one.")
    apply_p.add_argument("--json-file", type=Path, help="Path to score JSON (alternative to --json).")

    req_p = sub.add_parser("request", help="Emit a score-request file for an image.")
    req_p.add_argument("--actor", choices=("lin", "elena"), required=True)
    req_p.add_argument("--mode", choices=("nude", "torn"), required=True)
    req_p.add_argument("--image", type=Path, required=True)

    args = parser.parse_args(argv)
    if args.cmd == "request":
        path = write_score_request(args.actor, args.mode, args.image)
        print(path)
        return 0

    raw = None
    if args.json_file:
        raw = args.json_file.read_text(encoding="utf-8")
    elif args.json_text:
        candidate = Path(args.json_text)
        raw = candidate.read_text(encoding="utf-8") if candidate.is_file() else args.json_text
    else:
        raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        payload = parse_score(raw)
    if not all(k in payload for k in EIGHT):
        payload = parse_score(raw)
    apply_score(args.actor, args.mode, args.image, payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
