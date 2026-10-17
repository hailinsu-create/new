"""Community R5: Flux Fill surgical holes on R4b Elena (waist girdle + gauntlets).

Authorized 2026-10-10:
- Baseline = R4b final nude PNG
- Mask = waist seam armor ∪ gauntlets only; y >= horse_guard locked out
- Models: FLUX.1-Fill-dev + T5 + CLIP-L + ae
- Prefer 592; HF gated wall → stop with URL
- Cap ¥6; no grok.com; no same-Qwen retune

    python run_fox_centaur_community_r5.py --emit-plan
    python run_fox_centaur_community_r5.py --check-stack
    python run_fox_centaur_community_r5.py --out /path --i-know-authorized
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_semantic as base  # noqa: E402
import semantic_undress as sem  # noqa: E402
from comfy_util import choices, get_json, pick  # noqa: E402

W, H = 1024, 1536
Y_CUT = int(sem.ELENA.horse_guard_y / sem.BASE[1] * H)
R5_SEED = 202610105
R5_STEPS = 20
R5_CFG = 1.0
FEATHER = 8
GATED_URL = "https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev"

POS = (
    "bare natural skin and continuous soft human–horse waist transition, "
    "realistic pores, golden-hour light, no metal armor, no gauntlet, no chrome belt"
)
NEG = (
    "metal waist belt, hip armor plates, girdle, gauntlet, chrome, "
    "specular armor, jewelry, extra limbs, blurry, watermark"
)

REQUIRED_NODES = (
    "UNETLoader",
    "DualCLIPLoader",
    "VAELoader",
    "LoadImage",
    "LoadImageMask",
    "InpaintModelConditioning",
    "FluxGuidance",
    "KSampler",
    "VAEDecode",
    "SaveImage",
)

PLAN = {
    "name": "community_r5_flux_fill_waist_gauntlet",
    "status": "implemented",
    "baseline": "r4b",
    "forbid": ["qwen_prompt_mask_retune", "r3_regen", "fooocus_armor_inpaint"],
    "steps": R5_STEPS,
    "cfg": R5_CFG,
    "y_cut": Y_CUT,
    "gated_url": GATED_URL,
    "cost_cny": {"pilot": "2.5-5", "cap": "6"},
}


def _metalish(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    low = (chroma < 48) & ((mean > 130) | ((mean < 100) & (mean > 20)))
    specular = (chroma < 38) & (mean > 145) & (mean < 220)
    gold = (r > g) & (g > b) & ((r - b) > 28) & (chroma > 35) & (mean > 70) & (mean < 210)
    return low | specular | gold


def _dilate(mask: np.ndarray, size: int = 15) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    return np.asarray(img) > 127


def waist_gauntlet_mask(rgb: np.ndarray) -> np.ndarray:
    """Only waist girdle + forearm gauntlets; never below horse guard."""
    yy, xx = np.mgrid[0:H, 0:W]
    metal = _metalish(rgb)
    waist = (
        (yy > int(H * 0.38))
        & (yy < Y_CUT)
        & (xx > int(W * 0.20))
        & (xx < int(W * 0.68))
        & metal
    )
    # viewer-left forearm (her right) + viewer-right forearm
    g_l = (
        (yy > int(H * 0.24))
        & (yy < int(H * 0.48))
        & (xx > int(W * 0.12))
        & (xx < int(W * 0.34))
        & metal
    )
    g_r = (
        (yy > int(H * 0.26))
        & (yy < int(H * 0.50))
        & (xx > int(W * 0.48))
        & (xx < int(W * 0.70))
        & metal
    )
    mask = waist | g_l | g_r
    mask = _dilate(mask, 15)
    mask[Y_CUT:, :] = False
    return mask


def resolve_r5_models(host: str) -> dict[str, str]:
    unet = pick(choices(host, "UNETLoader", "unet_name"), "flux1-fill-dev")
    # DualCLIPLoader uses clip_name1 / clip_name2
    clips = choices(host, "DualCLIPLoader", "clip_name1")
    clip_l = pick(clips, "clip_l")
    clips2 = choices(host, "DualCLIPLoader", "clip_name2")
    t5_hits = [x for x in clips2 if "t5xxl_fp16" in x] or [x for x in clips2 if "t5xxl_fp8" in x]
    if not t5_hits:
        raise SystemExit(f"MODEL_MISSING t5xxl_fp16|fp8 in {clips2}")
    t5 = t5_hits[0]
    vaes = choices(host, "VAELoader", "vae_name")
    vae_hits = [x for x in vaes if x == "ae.safetensors" or x.endswith("/ae.safetensors")] or [
        x for x in vaes if "ae.safetensors" in x or x == "ae.safetensors"
    ] or [x for x in vaes if x.endswith("ae.safetensors") or x == "ae.safetensors" or "ae" == Path(x).stem]
    if not vae_hits:
        vae_hits = [x for x in vaes if "ae" in x.lower()]
    if not vae_hits:
        raise SystemExit(f"MODEL_MISSING ae in {vaes}")
    vae = vae_hits[0]
    return {"unet": unet, "clip_l": clip_l, "t5": t5, "vae": vae}


def check_stack(host: str) -> None:
    info = get_json(f"{host}/object_info", timeout=180)
    missing = [n for n in REQUIRED_NODES if n not in info]
    if missing:
        raise SystemExit(f"R5_STACK_MISSING_NODES {missing}")
    models = resolve_r5_models(host)
    print("R5_STACK_OK", json.dumps(models), flush=True)


def fill_graph(
    *,
    image_name: str,
    mask_name: str,
    models: dict[str, str],
    prompt: str,
    negative: str,
    seed: int,
) -> dict:
    return {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {
            "class_type": "LoadImageMask",
            "inputs": {"image": mask_name, "channel": "red"},
        },
        "3": {
            "class_type": "UNETLoader",
            "inputs": {"unet_name": models["unet"], "weight_dtype": "default"},
        },
        "4": {
            "class_type": "DualCLIPLoader",
            "inputs": {
                "clip_name1": models["clip_l"],
                "clip_name2": models["t5"],
                "type": "flux",
            },
        },
        "5": {"class_type": "VAELoader", "inputs": {"vae_name": models["vae"]}},
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["4", 0], "text": prompt},
        },
        "7": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["4", 0], "text": negative},
        },
        "8": {
            "class_type": "InpaintModelConditioning",
            "inputs": {
                "positive": ["6", 0],
                "negative": ["7", 0],
                "vae": ["5", 0],
                "pixels": ["1", 0],
                "mask": ["2", 0],
                "noise_mask": True,
            },
        },
        "9": {
            "class_type": "FluxGuidance",
            "inputs": {"conditioning": ["8", 0], "guidance": 30.0},
        },
        "10": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["3", 0],
                "positive": ["9", 0],
                "negative": ["8", 1],
                "latent_image": ["8", 2],
                "seed": seed,
                "steps": R5_STEPS,
                "cfg": R5_CFG,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        },
        "11": {"class_type": "VAEDecode", "inputs": {"samples": ["10", 0], "vae": ["5", 0]}},
        "12": {
            "class_type": "SaveImage",
            "inputs": {"images": ["11", 0], "filename_prefix": "r5-fill-raw"},
        },
    }


def composite_lock(
    baseline: Image.Image,
    edited: Image.Image,
    mask: np.ndarray,
    *,
    feather: int = FEATHER,
) -> Image.Image:
    base = np.asarray(baseline.convert("RGB").resize((W, H), Image.Resampling.LANCZOS), dtype=np.float32)
    edit = np.asarray(edited.convert("RGB").resize((W, H), Image.Resampling.LANCZOS), dtype=np.float32)
    edit[Y_CUT:] = base[Y_CUT:]
    alpha = mask.astype(np.float32)
    alpha[Y_CUT:] = 0.0
    a_img = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), mode="L")
    if feather > 0:
        a_img = a_img.filter(ImageFilter.GaussianBlur(radius=feather))
    a = np.asarray(a_img).astype(np.float32) / 255.0
    a[Y_CUT:] = 0.0
    out = base * (1.0 - a[:, :, None]) + edit * a[:, :, None]
    out[Y_CUT:] = base[Y_CUT:]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def save_previews(out_dir: Path, final: Image.Image, stem: str) -> None:
    final.resize((512, int(512 * H / W)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    final.crop((int(W * 0.20), int(H * 0.06), int(W * 0.72), int(H * 0.52))).save(
        out_dir / f"{stem}-torso.webp", "WEBP", quality=85
    )


def run_elena(host: str, out_dir: Path, *, baseline_path: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    work = out_dir / "work"
    work.mkdir(exist_ok=True)
    dbg = out_dir / "debug"
    dbg.mkdir(exist_ok=True)

    base_img = Image.open(baseline_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    rgb = np.asarray(base_img, dtype=np.float32)
    mask = waist_gauntlet_mask(rgb)
    Image.fromarray((mask.astype(np.uint8) * 255), mode="L").save(dbg / "waist-gauntlet-mask.png")
    print(f"MASK_SHARE {float(mask.mean()):.4f} y_cut={Y_CUT}", flush=True)

    upload_img = work / "r4b-elena-baseline.png"
    upload_mask = work / "r5-waist-gauntlet-mask.png"
    base_img.save(upload_img)
    # RGB mask for LoadImageMask red channel
    Image.fromarray(np.stack([mask.astype(np.uint8) * 255] * 3, axis=-1)).save(upload_mask)
    base.upload(host, upload_img)
    base.upload(host, upload_mask)

    models = resolve_r5_models(host)
    graph = fill_graph(
        image_name=upload_img.name,
        mask_name=upload_mask.name,
        models=models,
        prompt=POS,
        negative=NEG,
        seed=R5_SEED,
    )
    print(f"R5_GRAPH flux_fill steps={R5_STEPS}", flush=True)
    got = base.run_graph(host, graph, {"raw": "12"}, work, "r5-elena")
    raw = Image.open(got["raw"]).convert("RGB")
    raw.save(out_dir / "elena-armor-centaur-nude-r5-raw.png")

    final = composite_lock(base_img, raw, mask)
    stem = "elena-armor-centaur-nude"
    dest = out_dir / f"{stem}.png"
    final.save(dest)
    save_previews(out_dir, final, stem)

    below = np.abs(
        np.asarray(final, dtype=np.float32)[Y_CUT:] - np.asarray(base_img, dtype=np.float32)[Y_CUT:]
    ).mean()
    meta = {
        "pipeline": "community_r5",
        "baseline": str(baseline_path),
        "y_cut": Y_CUT,
        "feather": FEATHER,
        "mask_share": round(float(mask.mean()), 6),
        "below_cut_mae_vs_baseline": round(float(below), 4),
        "steps": R5_STEPS,
        "cfg": R5_CFG,
        "seed": R5_SEED,
        "models": models,
        "gated_url": GATED_URL,
        "forbid": PLAN["forbid"],
    }
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R5 {dest} {dest.stat().st_size}", flush=True)
    print(f"BELOW_CUT_MAE_vs_baseline {below:.2f}", flush=True)
    print(f"VISUAL_JUDGE elena nude {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/fox-semantic-out-r5"))
    parser.add_argument(
        "--baseline",
        type=Path,
        default=Path("/root/autodl-tmp/fox-r5-input/elena-armor-centaur-nude-r4b.png"),
    )
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--check-stack", action="store_true")
    parser.add_argument("--i-know-authorized", action="store_true")
    args = parser.parse_args()

    if args.emit_plan:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return
    if args.check_stack:
        check_stack(args.host)
        return
    if not args.i_know_authorized:
        print("R5_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(2)
    if not args.baseline.is_file():
        raise SystemExit(f"MISSING_BASELINE {args.baseline}")
    run_elena(args.host, args.out, baseline_path=args.baseline)


if __name__ == "__main__":
    main()
