"""Community R3: plate as pose+face only; nude regen; horse paste-back.

Authorized path after R1/R1-fix Fooocus armor-inpaint ceiling (2026-10-09).

- OpenPose from clothed plate (stance only)
- InstantID from plate head-shoulder crop (face only; not armor latent)
- EmptyLatent + denoise 1.0 (NO Fooocus inpaint, NO plate as KSampler image)
- Paste plate pixels below horse_guard_y (mare body + junction zone)

    python run_fox_centaur_community_r3.py --emit-plan
    python run_fox_centaur_community_r3.py --only elena --mode nude --out /path --i-know-authorized
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
import scheme_still_fox_centaur_undress as legacy  # noqa: E402
import semantic_undress as sem  # noqa: E402
from comfy_util import resolve_base_models  # noqa: E402

R3_SEED = 20261009
R3_STEPS = 28
R3_CFG = 4.5
R3_OPENPOSE_STRENGTH = 0.90
R3_INSTANTID_WEIGHT = 0.80
R3_WIDTH = 1024
R3_HEIGHT = 1536
HORSE_FEATHER = 24

ELENA_POS = (
    "photorealistic full-body photo of an adult female centaur, soft brown wavy hair, thin glasses, "
    "pearl earrings, facing camera, nude human torso, bare breasts, visible nipples, bare abdomen, "
    "realistic skin, no armor, no metal, chestnut horse body below the waist, long brown horse tail, "
    "mediterranean stone terrace, lake and cypress trees, golden hour light, highly detailed"
)
ELENA_NEG = (
    "clothes, armor, breastplate, pauldron, chrome, glossy metal, specular highlight, latex, "
    "bodysuit, vacuum-formed armor, gunmetal, shiny plate, metallic skin, mirror finish, "
    "bra, bikini, choker straps covering chest, gauntlet, vambrace, child, teen, extra limbs, "
    "blurry, watermark, text"
)

PLAN = {
    "name": "community_r3_pose_face_regen_horse_paste",
    "status": "implemented",
    "supersedes": "community_r1_fooocus_armor_inpaint_ceiling",
    "forbid": [
        "fooocus_inpaint_on_armor_plate",
        "r1_denoise_retune",
        "lama_residual_loop",
        "qwen_edit",
    ],
    "openpose_strength": R3_OPENPOSE_STRENGTH,
    "instantid_weight": R3_INSTANTID_WEIGHT,
    "denoise": 1.0,
    "latent": "empty",
    "horse_paste": True,
    "horse_guard_y_base": sem.ELENA.horse_guard_y,
    "cost_cny": {"pilot": "1-2.5", "cap": "3"},
}


def head_crop(plate: Image.Image) -> Image.Image:
    """Jaw-up / head-shoulder crop for InstantID (armor plate not fed to sampler)."""
    w, h = plate.size
    # face_clear on BASE 1024x1536 ≈ (240,10)-(520,224); expand to shoulders
    box = (
        int(w * 0.20),
        int(h * 0.00),
        int(w * 0.70),
        int(h * 0.28),
    )
    return plate.crop(box).resize((512, 512), Image.Resampling.LANCZOS)


def build_r3_graph(
    *,
    plate_name: str,
    face_name: str,
    ckpt: str,
    pose_cn: str,
    instant_cn: str,
    instant_ip: str,
    seed: int,
) -> dict:
    """Empty latent nude regen; plate only via DWPose + InstantID face image."""
    return {
        "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": ELENA_POS, "clip": ["3", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": ELENA_NEG, "clip": ["3", 1]}},
        "1": {"class_type": "LoadImage", "inputs": {"image": plate_name}},
        "2": {"class_type": "LoadImage", "inputs": {"image": face_name}},
        "11": {
            "class_type": "DiffControlNetLoader",
            "inputs": {"model": ["3", 0], "control_net_name": pose_cn},
        },
        "12": {
            "class_type": "DWPreprocessor",
            "inputs": {
                "image": ["1", 0],
                "detect_hand": "enable",
                "detect_body": "enable",
                "detect_face": "disable",
                "resolution": 1024,
                "bbox_detector": "yolox_l.onnx",
                "pose_estimator": "dw-ll_ucoco_384.onnx",
                "scale_stick_for_xinsr_cn": "enable",
            },
        },
        "6": {"class_type": "InstantIDModelLoader", "inputs": {"instantid_file": instant_ip}},
        "7": {"class_type": "InstantIDFaceAnalysis", "inputs": {"provider": "CPU"}},
        "8": {
            "class_type": "DiffControlNetLoader",
            "inputs": {"model": ["3", 0], "control_net_name": instant_cn},
        },
        "9": {
            "class_type": "FaceKeypointsPreprocessor",
            "inputs": {"faceanalysis": ["7", 0], "image": ["2", 0]},
        },
        "10": {
            "class_type": "ApplyInstantID",
            "inputs": {
                "instantid": ["6", 0],
                "insightface": ["7", 0],
                "control_net": ["8", 0],
                "image": ["2", 0],
                "model": ["3", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "weight": R3_INSTANTID_WEIGHT,
                "start_at": 0.0,
                "end_at": 1.0,
                "image_kps": ["9", 0],
            },
        },
        "13": {
            "class_type": "ControlNetApplyAdvanced",
            "inputs": {
                "positive": ["10", 1],
                "negative": ["10", 2],
                "control_net": ["11", 0],
                "image": ["12", 0],
                "strength": R3_OPENPOSE_STRENGTH,
                "start_percent": 0.0,
                "end_percent": 1.0,
            },
        },
        "14": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": R3_WIDTH, "height": R3_HEIGHT, "batch_size": 1},
        },
        "15": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["10", 0],
                "seed": seed,
                "steps": R3_STEPS,
                "cfg": R3_CFG,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["13", 0],
                "negative": ["13", 1],
                "latent_image": ["14", 0],
                "denoise": 1.0,
            },
        },
        "16": {"class_type": "VAEDecode", "inputs": {"samples": ["15", 0], "vae": ["3", 2]}},
        "22": {
            "class_type": "SaveImage",
            "inputs": {"images": ["16", 0], "filename_prefix": "r3-elena-nude-raw"},
        },
    }


def paste_horse(plate: Image.Image, generated: Image.Image, horse_guard_y_base: int) -> Image.Image:
    """Keep mare (+junction band) from clothed plate; keep generated nude torso above."""
    plate_r = plate.convert("RGB").resize((R3_WIDTH, R3_HEIGHT), Image.Resampling.LANCZOS)
    gen_r = generated.convert("RGB").resize((R3_WIDTH, R3_HEIGHT), Image.Resampling.LANCZOS)
    y_cut = int(horse_guard_y_base / sem.BASE[1] * R3_HEIGHT)
    # Soft alpha: 0 above cut (use gen), 1 below (use plate)
    alpha = np.zeros((R3_HEIGHT, R3_WIDTH), dtype=np.float32)
    alpha[y_cut:, :] = 1.0
    # Feather upward into torso a bit so seam softens (still mostly plate below cut)
    for i in range(HORSE_FEATHER):
        y = y_cut - HORSE_FEATHER + i
        if 0 <= y < R3_HEIGHT:
            alpha[y, :] = (i + 1) / (HORSE_FEATHER + 1)
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8), mode="L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=HORSE_FEATHER / 3))
    out = Image.composite(plate_r, gen_r, alpha_img)
    return out


def undress_elena_r3(
    host: str,
    models: dict[str, str],
    out_dir: Path,
    input_dir: Path,
    *,
    attempt: int = 0,
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    input_dir.mkdir(parents=True, exist_ok=True)
    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)

    plate = Image.open(legacy.ELENA_PLATE).convert("RGB")
    face = head_crop(plate)
    plate_name = "r3-elena-plate.png"
    face_name = "r3-elena-face.png"
    plate.resize((R3_WIDTH, R3_HEIGHT), Image.Resampling.LANCZOS).save(input_dir / plate_name)
    face.save(input_dir / face_name)
    base.upload(host, input_dir / plate_name)
    base.upload(host, input_dir / face_name)

    seed = R3_SEED + attempt * 17
    graph = build_r3_graph(
        plate_name=plate_name,
        face_name=face_name,
        ckpt=models["ckpt"],
        pose_cn=models["pose_cn"],
        instant_cn=models["instant_cn"],
        instant_ip=models["instant_ip"],
        seed=seed,
    )
    print("R3_GRAPH empty_latent+InstantID+OpenPose (no Fooocus inpaint)", flush=True)
    got = base.run_graph(host, graph, {"raw": "22"}, work, "r3-elena-nude")
    raw_path = got["raw"]
    raw = Image.open(raw_path).convert("RGB")
    final = paste_horse(plate, raw, sem.ELENA.horse_guard_y)

    stem = legacy.OUT_STEM[("elena", "nude")]
    dest = out_dir / f"{stem}.png"
    final.save(dest)
    raw.save(out_dir / f"{stem}-r3-raw.png")
    debug = out_dir / "debug"
    debug.mkdir(parents=True, exist_ok=True)
    face.save(debug / f"{stem}-face-crop.png")

    meta = {
        "pipeline": "community_r3",
        "actor": "elena",
        "mode": "nude",
        "attempt": attempt,
        "seed": seed,
        "denoise": 1.0,
        "latent": "empty",
        "openpose_strength": R3_OPENPOSE_STRENGTH,
        "instantid_weight": R3_INSTANTID_WEIGHT,
        "horse_guard_y_base": sem.ELENA.horse_guard_y,
        "horse_feather": HORSE_FEATHER,
        "forbid": PLAN["forbid"],
        "raw": str(raw_path.name),
    }
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R3 {dest} {dest.stat().st_size}", flush=True)
    print(f"VISUAL_JUDGE elena nude {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=base.DEFAULT_OUT)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-r3-input"))
    parser.add_argument("--only", choices=("elena",), nargs="*", default=["elena"])
    parser.add_argument("--mode", choices=("nude",), default="nude")
    parser.add_argument("--attempt", type=int, default=0)
    parser.add_argument("--check-stack", action="store_true")
    parser.add_argument("--i-know-authorized", action="store_true")
    args = parser.parse_args()

    if args.emit_plan:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return

    if args.check_stack:
        base.check_host(args.host)
        models = resolve_base_models(args.host)
        need = ("ckpt", "pose_cn", "instant_cn", "instant_ip")
        missing = [k for k in need if k not in models]
        # DWPreprocessor presence
        from comfy_util import get_json

        info = get_json(f"{args.host}/object_info", timeout=120)
        if "DWPreprocessor" not in info or "ApplyInstantID" not in info:
            missing.append("DWPreprocessor|ApplyInstantID")
        print(f"STACK_OK {missing}" if not missing else f"STACK_MISS {missing}", flush=True)
        if missing:
            raise SystemExit(1)
        return

    if not args.i_know_authorized:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        print("R3_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(0)

    base.check_host(args.host)
    models = resolve_base_models(args.host)
    undress_elena_r3(args.host, models, args.out, args.input, attempt=args.attempt)


if __name__ == "__main__":
    main()
