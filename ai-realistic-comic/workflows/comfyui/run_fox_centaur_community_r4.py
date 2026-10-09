"""Community R4: Qwen-Image-Edit-2511 metal-film cleanup on R1-fix baseline.

Authorized 2026-10-10 01:38:
- Input = R1-fix Elena nude (not clothed plate)
- Mask = translucent metal film + residual black edges on torso only
- Horse body / background locked (y >= horse_guard + mask_region composite)
- Models: Qwen Edit 2511 FP8 + VL + VAE + Lightning + remove/object LoRAs
- No Flux Fill; no R3 regen

    python run_fox_centaur_community_r4.py --emit-plan
    python run_fox_centaur_community_r4.py --check-stack
    python run_fox_centaur_community_r4.py --out /path --i-know-authorized
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
R4_SEED = 20261010
R4_STEPS = 4
R4_CFG = 1.0
FEATHER = 12

POS = (
    "Remove the translucent chrome metal film, glossy armor remnants, black strap lines, "
    "and metallic residue from the woman's chest, abdomen, neck, and arms. "
    "Reveal natural bare skin with realistic pores and soft golden-hour light. "
    "Keep her face, glasses, hair, pose, horse body, and stone terrace background unchanged."
)
NEG = (
    "chrome armor, glossy metal film, specular breastplate, black straps, "
    "metallic skin, mirror finish, extra limbs, blurry, watermark"
)

REQUIRED_NODES = (
    "UNETLoader",
    "CLIPLoader",
    "VAELoader",
    "LoraLoaderModelOnly",
    "TextEncodeQwenImageEditPlus",
    "ModelSamplingAuraFlow",
    "CFGNorm",
    "FluxKontextImageScale",
    "KSampler",
    "VAEEncode",
    "VAEDecode",
    "SaveImage",
    "LoadImage",
)

PLAN = {
    "name": "community_r4_qwen_edit_metal_film_mask",
    "status": "implemented",
    "baseline": "r1-fix",
    "supersedes": ["community_r3", "community_r3b", "r3c_offline"],
    "forbid": ["flux_fill", "r3_regen", "r3b_paste", "fooocus_armor_inpaint"],
    "steps": R4_STEPS,
    "cfg": R4_CFG,
    "y_cut": Y_CUT,
    "cost_cny": {"pilot": "3.5-7", "cap": "8"},
}


def metal_film_mask(r1fix: np.ndarray, plate: np.ndarray) -> np.ndarray:
    """Torso metal film + dark residual edges; never below horse guard."""
    r, g, b = r1fix[:, :, 0], r1fix[:, :, 1], r1fix[:, :, 2]
    mean = r1fix.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    pr, pg, pb = plate[:, :, 0], plate[:, :, 1], plate[:, :, 2]
    pmean = plate.mean(axis=2)
    pchroma = np.abs(pr - pg) + np.abs(pg - pb)

    plate_chrome = (pchroma < 48) & (pmean > 110)
    film = plate_chrome & (chroma < 58) & (mean > 105) & (mean < 210)
    # warm-grey specular film not covered by plate_chrome
    specular = (chroma < 35) & (mean > 140) & (mean < 205) & (r > 120)
    dark_edge = (mean < 55) & (chroma < 40) & (mean > 8)
    # torso ROI (human upper)
    yy, xx = np.mgrid[0:H, 0:W]
    torso = (yy < Y_CUT) & (yy > int(H * 0.05)) & (xx > int(W * 0.16)) & (xx < int(W * 0.68))
    mask = torso & (film | specular | dark_edge)
    # dilate then feather later
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(9))
    img = img.filter(ImageFilter.MinFilter(3))
    out = np.asarray(img) > 127
    out[Y_CUT:, :] = False
    return out


def composite_mask_region(
    baseline: Image.Image,
    edited: Image.Image,
    mask: np.ndarray,
    *,
    feather: int = FEATHER,
) -> Image.Image:
    base = np.asarray(baseline.convert("RGB").resize((W, H), Image.Resampling.LANCZOS), dtype=np.float32)
    edit = np.asarray(edited.convert("RGB").resize((W, H), Image.Resampling.LANCZOS), dtype=np.float32)
    # force horse/bg from baseline
    edit[Y_CUT:] = base[Y_CUT:]
    alpha = mask.astype(np.float32)
    alpha[Y_CUT:] = 0.0
    a_img = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), mode="L")
    if feather > 0:
        a_img = a_img.filter(ImageFilter.GaussianBlur(radius=feather))
    a = np.asarray(a_img).astype(np.float32) / 255.0
    a[Y_CUT:] = 0.0
    out = base * (1.0 - a[:, :, None]) + edit * a[:, :, None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def resolve_r4_models(host: str) -> dict[str, str]:
    return {
        "unet": pick(choices(host, "UNETLoader", "unet_name"), "qwen_image_edit_2511_fp8mixed"),
        "clip": pick(choices(host, "CLIPLoader", "clip_name"), "qwen_2.5_vl_7b_fp8_scaled"),
        "vae": pick(choices(host, "VAELoader", "vae_name"), "qwen_image_vae"),
        "lightning": pick(
            choices(host, "LoraLoaderModelOnly", "lora_name"),
            "Qwen-Image-Edit-2511-Lightning-4steps",
        ),
        "remove": pick(choices(host, "LoraLoaderModelOnly", "lora_name"), "qwen-edit-remove-clothes"),
        "object": pick(
            choices(host, "LoraLoaderModelOnly", "lora_name"),
            "Qwen-Image-Edit-2511-Object-Remover",
        ),
    }


def check_stack(host: str) -> None:
    info = get_json(f"{host}/object_info", timeout=180)
    missing = [n for n in REQUIRED_NODES if n not in info]
    # FluxKontextMultiReferenceLatentMethod optional (Comfy files often skip)
    if missing:
        raise SystemExit(f"R4_STACK_MISSING_NODES {missing}")
    models = resolve_r4_models(host)
    print("R4_STACK_OK", json.dumps(models), flush=True)


def has_ref_method(host: str) -> bool:
    info = get_json(f"{host}/object_info", timeout=120)
    return "FluxKontextMultiReferenceLatentMethod" in info


def qwen_edit_graph(
    *,
    image_name: str,
    models: dict[str, str],
    prompt: str,
    negative: str,
    seed: int,
    use_ref_method: bool,
) -> dict:
    """API prompt for single-image Qwen Edit 2511 + Lightning + remove + object LoRAs."""
    g: dict = {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {
            "class_type": "UNETLoader",
            "inputs": {"unet_name": models["unet"], "weight_dtype": "default"},
        },
        "3": {
            "class_type": "CLIPLoader",
            "inputs": {"clip_name": models["clip"], "type": "qwen_image", "device": "default"},
        },
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": models["vae"]}},
        "5": {
            "class_type": "ModelSamplingAuraFlow",
            "inputs": {"model": ["2", 0], "shift": 3.1},
        },
        "6": {
            "class_type": "CFGNorm",
            "inputs": {"model": ["5", 0], "strength": 1.0},
        },
        "7": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {"model": ["6", 0], "lora_name": models["lightning"], "strength_model": 1.0},
        },
        "8": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {"model": ["7", 0], "lora_name": models["remove"], "strength_model": 0.95},
        },
        "9": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {"model": ["8", 0], "lora_name": models["object"], "strength_model": 0.75},
        },
        "10": {"class_type": "FluxKontextImageScale", "inputs": {"image": ["1", 0]}},
        "11": {
            "class_type": "TextEncodeQwenImageEditPlus",
            "inputs": {
                "clip": ["3", 0],
                "prompt": prompt,
                "vae": ["4", 0],
                "image1": ["10", 0],
            },
        },
        "12": {
            "class_type": "TextEncodeQwenImageEditPlus",
            "inputs": {
                "clip": ["3", 0],
                "prompt": negative,
                "vae": ["4", 0],
                "image1": ["10", 0],
            },
        },
        "13": {"class_type": "VAEEncode", "inputs": {"pixels": ["10", 0], "vae": ["4", 0]}},
        "14": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["9", 0],
                "positive": ["11", 0],
                "negative": ["12", 0],
                "latent_image": ["13", 0],
                "seed": seed,
                "steps": R4_STEPS,
                "cfg": R4_CFG,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        },
        "15": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["4", 0]}},
        "16": {
            "class_type": "SaveImage",
            "inputs": {"images": ["15", 0], "filename_prefix": "r4-qwen-raw"},
        },
    }
    if use_ref_method:
        g["17"] = {
            "class_type": "FluxKontextMultiReferenceLatentMethod",
            "inputs": {"conditioning": ["11", 0], "reference_latents_method": "index_timestep_zero"},
        }
        g["18"] = {
            "class_type": "FluxKontextMultiReferenceLatentMethod",
            "inputs": {"conditioning": ["12", 0], "reference_latents_method": "index_timestep_zero"},
        }
        g["14"]["inputs"]["positive"] = ["17", 0]
        g["14"]["inputs"]["negative"] = ["18", 0]
    return g


def save_previews(out_dir: Path, final: Image.Image, stem: str) -> None:
    final.resize((512, int(512 * H / W)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    final.crop((int(W * 0.20), int(H * 0.06), int(W * 0.72), int(H * 0.52))).save(
        out_dir / f"{stem}-torso.webp", "WEBP", quality=85
    )


def run_elena(
    host: str,
    out_dir: Path,
    *,
    r1fix_path: Path,
    plate_path: Path,
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    work = out_dir / "work"
    work.mkdir(exist_ok=True)
    dbg = out_dir / "debug"
    dbg.mkdir(exist_ok=True)

    r1 = Image.open(r1fix_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    plate = Image.open(plate_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    mask = metal_film_mask(np.asarray(r1, dtype=np.float32), np.asarray(plate, dtype=np.float32))
    Image.fromarray((mask.astype(np.uint8) * 255), mode="L").save(dbg / "metal-film-mask.png")
    print(f"MASK_SHARE {float(mask.mean()):.4f} y_cut={Y_CUT}", flush=True)

    upload_path = work / "r1fix-elena.png"
    r1.save(upload_path)
    base.upload(host, upload_path)

    models = resolve_r4_models(host)
    use_ref = has_ref_method(host)
    graph = qwen_edit_graph(
        image_name=upload_path.name,
        models=models,
        prompt=POS,
        negative=NEG,
        seed=R4_SEED,
        use_ref_method=use_ref,
    )
    print(f"R4_GRAPH qwen_edit lightning={R4_STEPS} ref_method={use_ref}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, "r4-elena")
    raw = Image.open(got["raw"]).convert("RGB")
    raw.save(out_dir / "elena-armor-centaur-nude-r4-raw.png")

    final = composite_mask_region(r1, raw, mask)
    stem = "elena-armor-centaur-nude"
    dest = out_dir / f"{stem}.png"
    final.save(dest)
    save_previews(out_dir, final, stem)

    below = np.abs(
        np.asarray(final, dtype=np.float32)[Y_CUT:] - np.asarray(r1, dtype=np.float32)[Y_CUT:]
    ).mean()
    meta = {
        "pipeline": "community_r4",
        "baseline": str(r1fix_path),
        "plate": str(plate_path),
        "y_cut": Y_CUT,
        "mask_share": round(float(mask.mean()), 6),
        "below_cut_mae_vs_r1fix": round(float(below), 4),
        "steps": R4_STEPS,
        "cfg": R4_CFG,
        "seed": R4_SEED,
        "models": models,
        "forbid": PLAN["forbid"],
    }
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R4 {dest} {dest.stat().st_size}", flush=True)
    print(f"BELOW_CUT_MAE_vs_r1fix {below:.2f}", flush=True)
    print(f"VISUAL_JUDGE elena nude {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/fox-semantic-out-r4"))
    parser.add_argument(
        "--r1fix",
        type=Path,
        default=Path("/root/autodl-tmp/fox-r4-input/elena-armor-centaur-nude-r1fix.png"),
    )
    parser.add_argument(
        "--plate",
        type=Path,
        default=Path("/root/autodl-tmp/arc/ai-realistic-comic/library/stills/fox-centaur-embrace/elena-armor-centaur.png"),
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
        print("R4_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(2)
    if not args.r1fix.is_file():
        raise SystemExit(f"MISSING_R1FIX {args.r1fix}")
    if not args.plate.is_file():
        raise SystemExit(f"MISSING_PLATE {args.plate}")
    run_elena(args.host, args.out, r1fix_path=args.r1fix, plate_path=args.plate)


if __name__ == "__main__":
    main()
