"""Local Qwen makeup sheets for four characters. Does not render dual stills."""
from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARS = ("baisuzhen_snake", "xuxian", "persephone", "hades")


def _block(text: str, name: str) -> str:
    match = re.search(rf"<!-- {name}_START -->\s*(.*?)\s*<!-- {name}_END -->", text, re.S)
    if not match:
        raise SystemExit(f"missing {name} block")
    return match.group(1).strip()


def _refs(text: str) -> list[Path]:
    rels = []
    for line in text.splitlines():
        if line.startswith("- library/"):
            rels.append(ROOT / line[2:].strip())
    if len(rels) < 1:
        raise SystemExit("no refs")
    return rels


def _wh(text: str) -> tuple[int, int]:
    width = height = 0
    for line in text.splitlines():
        if line.startswith("width:"):
            width = int(line.split(":", 1)[1])
        elif line.startswith("height:"):
            height = int(line.split(":", 1)[1])
    if width < 256 or height < 256:
        raise SystemExit(f"bad size {width}x{height}")
    return width, height


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
    out_root = Path(os.environ.get("MAKEUP_OUT", "/root/autodl-tmp/out/makeup"))
    out_root.mkdir(parents=True, exist_ok=True)
    for cid in CHARS:
        md = (ROOT / "library" / "characters" / cid / "makeup_prompt.md").read_text(encoding="utf-8")
        prompt = _block(md, "GEN_PROMPT")
        negative = _block(md, "NEG")
        refs = _refs(md)
        width, height = _wh(md)
        for ref in refs:
            if not ref.is_file():
                raise SystemExit(f"missing ref {ref}")
        out = out_root / f"{cid}.png"
        print(f"==== SHEET {cid} {width}x{height} steps=40 refs={len(refs)} ====", flush=True)
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": f"{prompt} Avoid: {negative}.",
                "negative": negative,
                "images": refs,
                "width": width,
                "height": height,
                "steps": 40,
                "seed": 1,
            },
            out,
        )
        print(f"copied {cid} {out.stat().st_size}", flush=True)
    print("ALL_OK", flush=True)


if __name__ == "__main__":
    main()
