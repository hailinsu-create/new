"""Capped one-shot comparison of edit models on the same two-character still (anatomy focus).

One image per model, no rerolls; the sum of conservative estimates must stay <= CAP_USD.
Usage: python scripts/anatomy_shootout.py <project> <still-id> [--out DIR]
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import fal_client
from dotenv import load_dotenv

from comic_pipeline.config import get_settings
from comic_pipeline.models import load_project, load_still
from comic_pipeline.providers import get_image_provider
from comic_pipeline.still import build_still_prompt, still_refs

ROOT = Path(__file__).resolve().parents[1]
CAP_USD = 0.50
MODELS = {
    "seedream45": ("fal-ai/bytedance/seedream/v4.5/edit", 0.05, {"image_size": "portrait_4_3", "num_images": 1}),
    "nano-banana-pro": ("fal-ai/nano-banana-pro/edit", 0.17, {"aspect_ratio": "3:4", "resolution": "1K", "num_images": 1}),
    "flux2-pro": ("fal-ai/flux-2-pro/edit", 0.08, {"image_size": "portrait_4_3"}),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("project")
    ap.add_argument("still")
    ap.add_argument("--out", default=str(ROOT / "output" / "anatomy-shootout"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    load_dotenv(ROOT / ".env")
    os.environ["FAL_KEY"] = os.environ.get("FAL_KEY", "").strip()
    pdir = ROOT / "projects" / args.project
    proj = load_project(pdir)
    still = load_still(pdir / "stills" / f"{args.still}.yaml")
    prompt, negative = build_still_prompt(proj, still)
    refs = still_refs(pdir, proj, still)
    names = [m for m in MODELS if not args.only or m in args.only.split(",")]
    est = sum(MODELS[m][1] for m in names)
    if est > CAP_USD:
        print(f"estimate ${est:.2f} over cap ${CAP_USD:.2f}", file=sys.stderr)
        return 2
    out = Path(args.out) / args.project / args.still
    out.mkdir(parents=True, exist_ok=True)
    provider = get_image_provider(get_settings())
    urls = [fal_client.upload_file(str(p)) for p in refs]
    for m in names:
        endpoint, _, extra = MODELS[m]
        try:
            provider.call(endpoint, {"prompt": f"{prompt} Avoid: {negative}.", "image_urls": urls, **extra}, out / f"{m}.png")
            print("ok", m)
        except Exception as exc:  # noqa: BLE001
            print("FAIL", m, str(exc)[:200])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
