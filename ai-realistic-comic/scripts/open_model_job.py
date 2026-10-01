"""Build a model-agnostic job (prompt, negative, cropped refs) from an archived library still.

Used by colab/open_model_test.ipynb so open-weight models get exactly the same inputs the approved
nano-banana-pro recipe used. No network and no paid API calls.
Usage: python scripts/open_model_job.py <library-still-id> [--ref-crop 0.55] [--out DIR]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml
from PIL import Image

from comic_pipeline.models import Character, Project, Still
from comic_pipeline.still import build_still_prompt

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "library"


def build_job(still_id: str, ref_crop: float, out: Path) -> dict:
    still_dir = LIB / "stills" / still_id
    still = Still.model_validate(yaml.safe_load((still_dir / "still.yaml").read_text(encoding="utf-8")))
    chars, refs = [], []
    out.mkdir(parents=True, exist_ok=True)
    for cid in still.characters:
        cdir = LIB / "characters" / cid
        char = Character.model_validate(yaml.safe_load((cdir / "card.yaml").read_text(encoding="utf-8")))
        chars.append(char)
        with Image.open(cdir / char.reference_images[0]) as im:
            im = im.convert("RGB")
            if ref_crop:
                im = im.crop((0, 0, im.width, int(im.height * ref_crop)))
            target = out / f"ref_{cid}.png"
            im.save(target)
        refs.append(str(target))
    project = Project(name=still_id, genre="fantasy", characters=chars)
    prompt, negative = build_still_prompt(project, still)
    job = {
        "still_id": still_id,
        "prompt": prompt,
        "negative": negative,
        "refs": refs,
        "labels": [c.label for c in chars],
        "aspect": still.image_size,
        "approved_image": str(still_dir / "approved.jpg"),
    }
    (out / "job.json").write_text(json.dumps(job, ensure_ascii=False, indent=2), encoding="utf-8")
    return job


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("still_id")
    ap.add_argument("--ref-crop", type=float, default=0.55)
    ap.add_argument("--out", default="/tmp/open_model_job")
    args = ap.parse_args()
    job = build_job(args.still_id, args.ref_crop, Path(args.out))
    print(json.dumps(job, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
