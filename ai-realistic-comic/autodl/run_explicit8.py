# 已停用，改用 two-stage
"""Explicit stills p01-p08 plus myth poses m01-m04. Same offline Qwen cache.

Retired. Still scores are executed by Codex CLI against docs/still-score-two-stage.md.
Hard-gate failures and means under 9 stay inside this script: the same panel is
rendered again. Callers do not start a second generation command.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_FILES = (
    ROOT / "library" / "stills" / "explicit-8" / "prompts.md",
    ROOT / "library" / "stills" / "myth-poses" / "prompts.md",
)
ANCHOR = ROOT / "library" / "stills" / "explicit-8" / "anchor-10.jpg"
RUBRIC = ROOT / "docs" / "still-score.md"
KEEP_MEAN = 9.0


def accepted(item: dict) -> bool:
    gates = item.get("gates") or []
    try:
        mean = float(item.get("mean"))
    except (TypeError, ValueError):
        return False
    return not gates and mean >= KEEP_MEAN


def parse_score(text: str) -> dict:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise SystemExit("score json missing")
    data = json.loads(text[start : end + 1])
    if isinstance(data.get("items"), list) and data["items"]:
        data = data["items"][0]
    if not isinstance(data, dict):
        raise SystemExit("score json was not an object")
    return data


def _blocks(text: str) -> list[dict]:
    out = []
    for m in re.finditer(r"<!-- ([PM]\d\d)_START -->(.*?)<!-- \1_END -->", text, re.S):
        body = m.group(2)
        gen = re.search(r"<!-- GEN_START -->(.*?)<!-- GEN_END -->", body, re.S)
        neg = re.search(r"<!-- NEG_START -->(.*?)<!-- NEG_END -->", body, re.S)
        refs = []
        width = height = 0
        for line in body.splitlines():
            line = line.strip()
            if line.startswith("- library/"):
                refs.append(ROOT / line[2:].strip())
            elif line.startswith("width:"):
                width = int(line.split(":", 1)[1])
            elif line.startswith("height:"):
                height = int(line.split(":", 1)[1])
        if not gen or not neg or len(refs) < 2 or width < 256:
            raise SystemExit(f"bad block {m.group(1)}")
        out.append(
            {
                "id": m.group(1).lower(),
                "prompt": gen.group(1).strip(),
                "negative": neg.group(1).strip(),
                "refs": refs,
                "width": width,
                "height": height,
            }
        )
    return out


def require_subset(raw: str, known: set[str]) -> set[str]:
    only = {item.strip().lower() for item in raw.split(",") if item.strip()}
    if not only:
        raise SystemExit(
            "EXPLICIT_ONLY is required. Refusing to render p01-p08 and m01-m04 together."
        )
    unknown = sorted(only - known)
    if unknown:
        raise SystemExit(f"unknown EXPLICIT_ONLY: {', '.join(unknown)}")
    return only


def _load_panels() -> list[dict]:
    out = []
    for path in PROMPT_FILES:
        if not path.is_file():
            raise SystemExit(f"missing prompts {path}")
        out.extend(_blocks(path.read_text(encoding="utf-8")))
    ids = [panel["id"] for panel in out]
    expected = [f"p{n:02d}" for n in range(1, 9)] + [f"m{n:02d}" for n in range(1, 5)]
    if ids != expected:
        raise SystemExit(f"expected {expected}, got {ids}")
    return out


def score_still(image: Path) -> dict:
    del image
    raise SystemExit("已停用。出片打分只许 Codex CLI。禁止 OpenCode Go vision。失败退出。")


def _render_until_kept(provider, panel: dict, dest: Path, seed: int) -> None:
    del provider, panel, dest, seed
    raise SystemExit(
        "已停用。锁定图必须由 Codex CLI 在 autodl/run_explicit_two_stage.py 生成。禁止这条本地 Qwen 降级。"
    )


def main() -> None:
    raise SystemExit(
        "已停用。锁定图必须由 Codex CLI 在 autodl/run_explicit_two_stage.py 生成。禁止这条本地 Qwen 降级。失败退出。"
    )


if __name__ == "__main__":
    main()
