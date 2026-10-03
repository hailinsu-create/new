"""Explicit stills p01-p08 plus myth poses m01-m04. Same offline Qwen cache."""
from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_FILES = (
    ROOT / "library" / "stills" / "explicit-8" / "prompts.md",
    ROOT / "library" / "stills" / "myth-poses" / "prompts.md",
)


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


def main() -> None:
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
    os.environ.setdefault("DIFFUSERS_OFFLINE", "1")
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    from comic_pipeline.config import Settings
    from comic_pipeline.providers.local import LocalProvider

    settings = Settings(
        image_provider="local",
        local_still_model="qwen-image-edit-2511",
        local_steps=40,
        local_offload="sequential",
        local_seed=1,
    )
    provider = LocalProvider(settings)
    out_root = Path(os.environ.get("EXPLICIT_OUT", "/root/autodl-tmp/out/explicit-8"))
    out_root.mkdir(parents=True, exist_ok=True)
    only = {x.strip() for x in os.environ.get("EXPLICIT_ONLY", "").split(",") if x.strip()}
    for panel in _load_panels():
        if only and panel["id"] not in only:
            continue
        for ref in panel["refs"]:
            if not ref.is_file():
                raise SystemExit(f"missing ref {ref}")
        dest = out_root / f"{panel['id']}.png"
        print(
            f"==== STILL {panel['id']} {panel['width']}x{panel['height']} refs={len(panel['refs'])} ====",
            flush=True,
        )
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": f"{panel['prompt']} Avoid: {panel['negative']}.",
                "negative": panel["negative"],
                "images": panel["refs"],
                "width": panel["width"],
                "height": panel["height"],
                "steps": 40,
                "seed": int(os.environ.get("EXPLICIT_SEED", "1")),
                "true_cfg_scale": float(os.environ.get("EXPLICIT_CFG", "4")),
            },
            dest,
        )
        print(f"wrote {dest} {dest.stat().st_size}", flush=True)
    print("ALL_OK", flush=True)


if __name__ == "__main__":
    main()
