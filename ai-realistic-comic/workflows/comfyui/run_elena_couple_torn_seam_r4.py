#!/usr/bin/env python3
"""Elena couple torn redo: Qwen-Edit + seam-above torso mask paste-back.

Edit keep-mask = human torso above waist/horse seam only.
Below seam (horse / 鸾布 / male / background) = USER_LOCKED plate pixels.
Narrow feather only at the seam band. Official out = composited (not pure raw).
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_community_r4 as r4  # noqa: E402
import run_fox_centaur_semantic as base  # noqa: E402
from comfy_util import choices, pick  # noqa: E402

PLAN = {
    "name": "elena_couple_torn_seam_r4",
    "status": "implemented",
    "success": "torso-above-seam edit; plate below seam; thick torn plates not wire",
    "official": "seam_composite",
}


PROMPT = (
    "Edit only the centaur woman's human torso clothing above the waist/horse seam: "
    "replace her gold scale bodice with a damaged metal breastplate that has real thickness — "
    "jagged broken armor plate shards and cloth strips hanging on the body, partial bare adult skin "
    "showing through gaps. Must look like torn plate armor with weight, not wires or filigree cage. "
    "Do not alter anything below the human-waist / horse-back seam. "
    "Keep standing courtyard kiss pose, the man exactly as in the photo, her horse body, "
    "golden caparison/鸾布, face, hair, glasses, and stone-courtyard background unchanged."
)

NEGATIVE = (
    "human hips, human thighs, human legs, wire cage, thin wire, filigree cage, spider web metal, "
    "human buttocks on horse, skin patch on horse flank, intact undamaged breastplate, "
    "fully clothed seamless armor, changed man, changed horse body, extra limbs, broken pose, "
    "blurry, watermark, child"
)

# Relative mask on the fitted edit canvas (after fit_resize / FluxKontext scale ~same ratio)
SEAM_RATIO = 0.38
FEATHER = 18
TORSO_X0 = 0.30
TORSO_X1 = 0.55
TORSO_Y0 = 0.05

SEEDS = (20261021, 20261022, 20261023, 20261024)


@dataclass(frozen=True)
class Shot:
    stem: str
    seed: int


def fit_resize(img: Image.Image) -> Image.Image:
    w, h = img.size
    scale = min(1536 / max(w, h), 1.0) if max(w, h) > 1536 else 1.0
    tw, th = max(64, int(w * scale) // 8 * 8), max(64, int(h * scale) // 8 * 8)
    return img.resize((tw, th), Image.Resampling.LANCZOS)


def torso_seam_alpha(w: int, h: int) -> np.ndarray:
    seam = int(h * SEAM_RATIO)
    xa, xb = int(w * TORSO_X0), int(w * TORSO_X1)
    ya = int(h * TORSO_Y0)
    feather = FEATHER
    mask = np.zeros((h, w), dtype=np.float32)
    for y in range(max(0, ya), h):
        if y < seam - feather:
            v = 1.0
        elif y > seam + feather:
            v = 0.0
        else:
            t = (y - (seam - feather)) / max(1, (2 * feather))
            v = 0.5 * (1.0 + np.cos(np.pi * t))
        mask[y, xa:xb] = v
    a = Image.fromarray((mask * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(6))
    alpha = np.asarray(a).astype(np.float32) / 255.0
    alpha[seam + feather + 2 :, :] = 0.0
    return alpha


def composite_plate(plate: Image.Image, edited: Image.Image) -> tuple[Image.Image, Image.Image]:
    base = plate.convert("RGB").resize(edited.size, Image.Resampling.LANCZOS)
    edit = edited.convert("RGB")
    w, h = edit.size
    alpha = torso_seam_alpha(w, h)
    out = np.asarray(base, dtype=np.float32) * (1.0 - alpha[:, :, None]) + np.asarray(
        edit, dtype=np.float32
    ) * alpha[:, :, None]
    comp = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    mask_img = Image.fromarray((alpha * 255).astype(np.uint8), "L")
    return comp, mask_img


def qwen_edit_graph_torn(
    *,
    image_name: str,
    models: dict[str, str],
    prompt: str,
    negative: str,
    seed: int,
    use_ref_method: bool,
) -> dict:
    """Like r4.qwen_edit_graph but lower remove LoRA so plates stay thick."""
    g = r4.qwen_edit_graph(
        image_name=image_name,
        models=models,
        prompt=prompt,
        negative=negative,
        seed=seed,
        use_ref_method=use_ref_method,
    )
    # node 8 = remove clothes lora; node 9 = object remover
    g["8"]["inputs"]["strength_model"] = 0.62
    g["9"]["inputs"]["strength_model"] = 0.45
    return g


def run_seed(host: str, out_dir: Path, plate: Path, seed: int, models: dict, use_ref: bool) -> Path:
    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    stem = f"elena-couple-torn-s{seed}"
    img = fit_resize(Image.open(plate).convert("RGB"))
    upload = work / f"plate-{stem}.png"
    img.save(upload)
    base.upload(host, upload)
    graph = qwen_edit_graph_torn(
        image_name=upload.name,
        models=models,
        prompt=PROMPT,
        negative=NEGATIVE,
        seed=seed,
        use_ref_method=use_ref,
    )
    print(f"ELENA_TORN_SEAM_GRAPH {stem} seed={seed}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, f"elena-{stem}")
    raw = Image.open(got["raw"]).convert("RGB")
    raw_path = out_dir / f"{stem}-r4-raw.png"
    raw.save(raw_path)
    # plate for paste must be USER_LOCKED original at edit canvas size
    plate_img = fit_resize(Image.open(plate).convert("RGB"))
    comp, mask_img = composite_plate(plate_img, raw)
    official = out_dir / f"{stem}.png"
    comp.save(official)
    mask_img.save(out_dir / f"{stem}-seam-mask.png")
    w, h = comp.size
    comp.resize((512, int(512 * h / w)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    (out_dir / f"{stem}.run.json").write_text(
        json.dumps(
            {
                "pipeline": "elena_couple_torn_seam_r4",
                "stem": stem,
                "seed": seed,
                "plate": str(plate),
                "official_is_raw": False,
                "official_is_seam_composite": True,
                "seam_ratio": SEAM_RATIO,
                "feather": FEATHER,
                "torso_box": [TORSO_X0, TORSO_Y0, TORSO_X1, SEAM_RATIO],
                "prompt": PROMPT,
                "negative": NEGATIVE,
                "remove_lora": 0.62,
                "object_lora": 0.45,
                "models": models,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"RAW_OK {stem}-r4-raw.png", flush=True)
    print(f"OFFICIAL_OK {stem}.png", flush=True)
    print(f"VISUAL_JUDGE {stem} {official}", flush=True)
    return official


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:8188")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--plate", type=Path, required=True)
    ap.add_argument("--seeds", default=",".join(str(s) for s in SEEDS))
    ap.add_argument("--i-know-authorized", action="store_true")
    ap.add_argument("--check-stack", action="store_true")
    args = ap.parse_args()
    if args.check_stack:
        r4.check_stack(args.host)
        return
    if not args.i_know_authorized:
        raise SystemExit("NEED --i-know-authorized")
    if not args.plate.is_file():
        raise SystemExit(f"MISSING_PLATE {args.plate}")
    args.out.mkdir(parents=True, exist_ok=True)
    models = r4.resolve_r4_models(args.host)
    use_ref = r4.has_ref_method(args.host)
    seeds = [int(x) for x in args.seeds.split(",") if x.strip()]
    done = []
    for seed in seeds:
        path = run_seed(args.host, args.out, args.plate, seed, models, use_ref)
        done.append(path.name)
    (args.out / "ELENA_TORN_SEAM_SUMMARY.json").write_text(
        json.dumps({"done": done, "plan": PLAN, "seeds": seeds}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("ELENA_TORN_SEAM_DONE", done, flush=True)


if __name__ == "__main__":
    main()
