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


def _bai_sheet(provider, md: str, out: Path) -> None:
    from PIL import Image

    width, height = _wh(md)
    human_refs = _refs_after(md, "human_ref:")
    snake_refs = _refs_after(md, "snake_ref:")
    for ref in human_refs + snake_refs:
        if not ref.is_file():
            raise SystemExit(f"missing ref {ref}")
    human_path = out.with_name("baisuzhen_human.png")
    snake_path = out.with_name("baisuzhen_serpent.png")
    part = os.environ.get("MAKEUP_PART", "").strip()
    if part != "serpent":
        _one(provider, _block(md, "GEN_HUMAN"), _block(md, "NEG_HUMAN"), human_refs, width, height, human_path, "bai-human")
    elif not human_path.is_file():
        raise SystemExit(f"missing human panel {human_path}")
    if part != "human":
        _one(provider, _block(md, "GEN_SNAKE"), _block(md, "NEG_SNAKE"), snake_refs, width, height, snake_path, "bai-serpent")
    elif not snake_path.is_file():
        raise SystemExit(f"missing serpent panel {snake_path}")
    human = Image.open(human_path).convert("RGB")
    snake = Image.open(snake_path).convert("RGB")
    if human.size != (width, height) or snake.size != (width, height):
        raise SystemExit(f"unexpected panel size {human.size} {snake.size}")
    sheet = Image.new("RGB", (width * 2, height), (128, 128, 128))
    sheet.paste(human, (0, 0))
    sheet.paste(snake, (width, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"composited {out} {out.stat().st_size} {sheet.size}", flush=True)


def _refs_after(text: str, heading: str) -> list[Path]:
    rels = []
    seen = False
    for line in text.splitlines():
        if line.startswith(heading):
            seen = True
            continue
        if seen and line.startswith("- library/"):
            rels.append(ROOT / line[2:].strip())
            continue
        if seen and line.strip() and not line.startswith("- "):
            break
    if not rels:
        raise SystemExit(f"no refs after {heading}")
    return rels


def _one(provider, prompt: str, negative: str, refs: list[Path], width: int, height: int, out: Path, label: str) -> None:
    print(f"==== SHEET {label} {width}x{height} steps=40 refs={len(refs)} ====", flush=True)
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
    only = os.environ.get("MAKEUP_ONLY", "").strip()
    chars = tuple(c for c in CHARS if not only or c == only)
    if not chars:
        raise SystemExit(f"MAKEUP_ONLY matched nothing: {only}")
    for cid in chars:
        md = (ROOT / "library" / "characters" / cid / "makeup_prompt.md").read_text(encoding="utf-8")
        out = out_root / f"{cid}.png"
        if cid == "baisuzhen_snake" and "GEN_HUMAN_START" in md:
            _bai_sheet(provider, md, out)
        else:
            prompt = _block(md, "GEN_PROMPT")
            negative = _block(md, "NEG")
            refs = _refs(md)
            width, height = _wh(md)
            for ref in refs:
                if not ref.is_file():
                    raise SystemExit(f"missing ref {ref}")
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
