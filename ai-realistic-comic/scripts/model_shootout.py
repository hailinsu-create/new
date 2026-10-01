"""Capped one-shot comparison of fal multi-reference edit models on two-character panels.

Hard cap: sum of conservative per-call estimates must stay <= CAP_USD; one image per (model, panel), no rerolls.
Usage: python scripts/model_shootout.py [--out output/shootout]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import fal_client
import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "projects" / "demo-spider-wukong"
CAP_USD = 0.30

MODELS = {
    "nano-banana": {"endpoint": "fal-ai/nano-banana/edit", "est": 0.05, "extra": {"num_images": 1}},
    "seedream4": {
        "endpoint": "fal-ai/bytedance/seedream/v4/edit",
        "est": 0.05,
        "extra": {"num_images": 1, "image_size": "portrait_4_3"},
    },
    "flux2-edit": {
        "endpoint": "fal-ai/flux-2/edit",
        "est": 0.05,
        "extra": {"image_size": "portrait_4_3", "num_images": 1},
    },
}

CAST = (
    "Image 1 is Sun Wukong the Monkey King: male, furred simian-human face, golden fillet headband, "
    "ochre tiger-skin warrior gear, golden staff. Image 2 is Zhizhu the Spider Spirit: female, "
    "glamorous human face, long black hair, black-violet sheer silk robe off one shoulder. "
    "Keep both characters' faces, outfits and species exactly as in their reference images; "
    "they must look like two clearly different people. "
)
STYLE = (
    "Photorealistic live-action cinematic still, real actors, practical costume textures, "
    "cool violet cave lighting, shallow depth of field, single frame, not a collage, no text."
)

PANELS = {
    "E1_confront": (
        CAST
        + "Both characters together in ONE frame inside a spider-silk cave: Zhizhu in the foreground "
        "smiles alluringly and extends glowing violet silk threads from her fingertips toward Wukong, "
        "who stands a few steps away in a wary defensive stance holding the golden staff across his body, "
        "eyes locked on her. "
        + STYLE
    ),
    "E2_clash": (
        CAST
        + "Both characters together in ONE frame: Wukong lunges forward swinging the golden staff, "
        "slicing through violet spider webs with sparks; Zhizhu in the mid-ground leans back, sleeves and "
        "silk threads whipping, lingering seductive smile. "
        + STYLE
    ),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "output" / "shootout"))
    args = ap.parse_args()

    load_dotenv(ROOT / ".env")
    key = os.environ.get("FAL_KEY", "").strip()
    if not key:
        print("FAL_KEY missing", file=sys.stderr)
        return 2
    os.environ["FAL_KEY"] = key

    jobs = [(m, p) for p in PANELS for m in MODELS]
    total = sum(MODELS[m]["est"] for m, _ in jobs)
    if total > CAP_USD + 1e-9:
        print(f"planned worst-case ${total:.2f} exceeds cap ${CAP_USD:.2f}", file=sys.stderr)
        return 3
    print(f"planned jobs={len(jobs)} worst-case=${total:.2f} cap=${CAP_USD:.2f}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    refs = [
        fal_client.upload_file(str(PROJECT / "characters" / "wukong_ref.png")),
        fal_client.upload_file(str(PROJECT / "characters" / "zhizhu_ref.png")),
    ]

    log: list[dict] = []
    for model_key, panel in jobs:
        spec = MODELS[model_key]
        dest = out / f"{panel}__{model_key}.png"
        entry = {"model": spec["endpoint"], "panel": panel, "file": dest.name, "est_usd": spec["est"]}
        try:
            result = fal_client.subscribe(
                spec["endpoint"],
                arguments={"prompt": PANELS[panel], "image_urls": refs, **spec["extra"]},
            )
            images = result.get("images") or []
            url = images[0]["url"] if isinstance(images[0], dict) else images[0]
            with httpx.Client(timeout=180.0) as c:
                r = c.get(url)
                r.raise_for_status()
                dest.write_bytes(r.content)
            entry.update(ok=True, bytes=len(r.content))
        except Exception as exc:  # noqa: BLE001
            entry.update(ok=False, error=str(exc)[:300])
        print(entry)
        log.append(entry)

    (out / "shootout.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    spent = sum(e["est_usd"] for e in log if e.get("ok"))
    print(f"done; estimated spend <= ${spent:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
