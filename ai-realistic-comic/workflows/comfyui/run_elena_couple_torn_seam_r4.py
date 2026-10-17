#!/usr/bin/env python3
"""Elena couple torn redo v3: nude-above-seam base + add thick plate shards.

1) Build base = nude torso above seam, USER_LOCKED plate below seam.
2) Qwen-Edit adds thick broken breastplate shards + cloth strips (remove LoRA ~0).
3) Paste USER_LOCKED below seam again (narrow feather).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_community_r4 as r4  # noqa: E402
import run_fox_centaur_semantic as base  # noqa: E402

SEAM_RATIO = 0.38
FEATHER = 16
SEEDS = (20261031, 20261032, 20261033, 20261034)

PROMPT = (
    "She is already bare-chested. Add only thick jagged broken metal breastplate shards with real "
    "plate thickness and bent cut edges, plus hanging torn cloth strips on her human torso. "
    "Large patches of bare adult skin must remain visible between the heavy metal chunks. "
    "Destroyed plate armor look — NOT thin wire, NOT filigree mesh, NOT lace cage. "
    "Do not change the man, horse body, golden caparison/鸾布, face, hair, glasses, pose, or background."
)
NEGATIVE = (
    "human hips, human thighs, human legs, wire cage, thin wire, filigree cage, spider web metal, "
    "human buttocks on horse, skin patch on horse flank, intact undamaged breastplate, "
    "fully clothed seamless armor, completely bare with no metal scraps, changed man, "
    "changed horse body, extra limbs, broken pose, blurry, watermark, child"
)


def fit_resize(img: Image.Image) -> Image.Image:
    w, h = img.size
    scale = min(1536 / max(w, h), 1.0) if max(w, h) > 1536 else 1.0
    tw, th = max(64, int(w * scale) // 8 * 8), max(64, int(h * scale) // 8 * 8)
    return img.resize((tw, th), Image.Resampling.LANCZOS)


def seam_keep_edit_alpha(w: int, h: int, seam_ratio: float = SEAM_RATIO, feather: int = FEATHER) -> np.ndarray:
    """Alpha=1 keep edit (above seam), 0 use plate (below). Full width."""
    seam = int(h * seam_ratio)
    alpha = np.zeros((h, w), dtype=np.float32)
    for y in range(h):
        if y < seam - feather:
            v = 1.0
        elif y > seam + feather:
            v = 0.0
        else:
            t = (y - (seam - feather)) / max(1, 2 * feather)
            v = 0.5 * (1.0 + np.cos(np.pi * t))
        alpha[y, :] = v
    return alpha


def composite(base: Image.Image, edited: Image.Image, alpha: np.ndarray) -> Image.Image:
    b = np.asarray(base.convert("RGB"), dtype=np.float32)
    e = np.asarray(edited.convert("RGB").resize(base.size, Image.Resampling.LANCZOS), dtype=np.float32)
    if alpha.shape[:2] != b.shape[:2]:
        a_img = Image.fromarray((alpha * 255).astype(np.uint8), "L").resize(base.size, Image.Resampling.BILINEAR)
        alpha = np.asarray(a_img).astype(np.float32) / 255.0
    out = b * (1.0 - alpha[:, :, None]) + e * alpha[:, :, None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def build_nude_above_seam(locked_plate: Path, nude_raw: Path) -> Image.Image:
    plate = fit_resize(Image.open(locked_plate).convert("RGB"))
    nude = fit_resize(Image.open(nude_raw).convert("RGB")).resize(plate.size, Image.Resampling.LANCZOS)
    alpha = seam_keep_edit_alpha(*plate.size)  # keep nude above
    return composite(plate, nude, alpha)


def qwen_add_armor_graph(*, image_name: str, models: dict, prompt: str, negative: str, seed: int, use_ref: bool) -> dict:
    g = r4.qwen_edit_graph(
        image_name=image_name,
        models=models,
        prompt=prompt,
        negative=negative,
        seed=seed,
        use_ref_method=use_ref,
    )
    g["8"]["inputs"]["strength_model"] = 0.08  # almost no remove
    g["9"]["inputs"]["strength_model"] = 0.15
    return g


def run_seed(host: str, out_dir: Path, base_img: Image.Image, locked_plate: Path, seed: int, models: dict, use_ref: bool) -> Path:
    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    stem = f"elena-couple-torn-s{seed}"
    upload = work / f"base-{stem}.png"
    base_img.save(upload)
    base.upload(host, upload)
    graph = qwen_add_armor_graph(
        image_name=upload.name, models=models, prompt=PROMPT, negative=NEGATIVE, seed=seed, use_ref=use_ref
    )
    print(f"ELENA_TORN_V3_GRAPH {stem} seed={seed}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, f"elena-{stem}")
    raw = Image.open(got["raw"]).convert("RGB")
    raw_path = out_dir / f"{stem}-r4-raw.png"
    raw.save(raw_path)
    plate = fit_resize(Image.open(locked_plate).convert("RGB")).resize(raw.size, Image.Resampling.LANCZOS)
    alpha = seam_keep_edit_alpha(*raw.size)
    # keep edit above seam, plate below
    official = composite(plate, raw, alpha)
    official_path = out_dir / f"{stem}.png"
    official.save(official_path)
    Image.fromarray((alpha * 255).astype(np.uint8), "L").save(out_dir / f"{stem}-seam-mask.png")
    w, h = official.size
    official.resize((512, int(512 * h / w)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    (out_dir / f"{stem}.run.json").write_text(
        json.dumps(
            {
                "pipeline": "elena_couple_torn_seam_v3_add_armor",
                "stem": stem,
                "seed": seed,
                "seam_ratio": SEAM_RATIO,
                "prompt": PROMPT,
                "negative": NEGATIVE,
                "remove_lora": 0.08,
                "object_lora": 0.15,
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
    print(f"VISUAL_JUDGE {stem} {official_path}", flush=True)
    return official_path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:8188")
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--plate", type=Path, default=None, help="USER_LOCKED plate")
    ap.add_argument("--nude", type=Path, default=None, help="usable nude r4 raw")
    ap.add_argument("--seeds", default=",".join(str(s) for s in SEEDS))
    ap.add_argument("--i-know-authorized", action="store_true")
    ap.add_argument("--check-stack", action="store_true")
    args = ap.parse_args()
    if args.check_stack:
        r4.check_stack(args.host)
        return
    if not args.i_know_authorized:
        raise SystemExit("NEED --i-know-authorized")
    if args.out is None or args.plate is None or args.nude is None:
        raise SystemExit("NEED --out --plate --nude")
    if not args.plate.is_file() or not args.nude.is_file():
        raise SystemExit("MISSING plate/nude")
    args.out.mkdir(parents=True, exist_ok=True)
    base_img = build_nude_above_seam(args.plate, args.nude)
    base_img.save(args.out / "BASE_nude_above_seam.png")
    models = r4.resolve_r4_models(args.host)
    use_ref = r4.has_ref_method(args.host)
    seeds = [int(x) for x in args.seeds.split(",") if x.strip()]
    done = []
    for seed in seeds:
        path = run_seed(args.host, args.out, base_img, args.plate, seed, models, use_ref)
        done.append(path.name)
    (args.out / "ELENA_TORN_SEAM_SUMMARY.json").write_text(
        json.dumps({"done": done, "pipeline": "v3_add_armor", "seeds": seeds}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("ELENA_TORN_SEAM_DONE", done, flush=True)


if __name__ == "__main__":
    main()
