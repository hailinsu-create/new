"""Community R3b: upper-body vertical regen + mare-fur-only paste.

Fixes R3 double-head collapse (2026-10-10 offline diagnosis):
- Generate only the human upper band (not full centaur frame)
- OpenPose ≈0.50 on upper crop; InstantID ≈0.50; kps from upper crop
- Prompt: single woman upper body nude (no centaur/horse in positive)
- Paste plate below horse_guard only where mare-fur (skip fauld/metal)

    python run_fox_centaur_community_r3b.py --emit-plan
    python run_fox_centaur_community_r3b.py --only elena --mode nude --out /path --i-know-authorized
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

R3B_SEED = 20261010
R3B_STEPS = 28
R3B_CFG = 4.5
R3B_OPENPOSE_STRENGTH = 0.50
R3B_INSTANTID_WEIGHT = 0.50
R3B_FULL_W = 1024
R3B_FULL_H = 1536
# Upper band height (multiple of 64); covers head→just above horse_guard
R3B_UPPER_H = 768
HORSE_FEATHER = 28

ELENA_POS = (
    "photorealistic portrait photo of a single adult woman, one head only, upper body, "
    "soft brown wavy hair, thin glasses, pearl earrings, facing camera, "
    "nude, bare breasts, visible nipples, bare abdomen, realistic skin, "
    "mediterranean stone terrace background, golden hour light, highly detailed"
)
ELENA_NEG = (
    "multiple heads, conjoined, extra breasts, siamese, duplicate face, "
    "centaur, horse body, horse, clothes, armor, breastplate, pauldron, chrome, "
    "glossy metal, specular highlight, latex, bodysuit, gauntlet, vambrace, "
    "child, teen, extra limbs, blurry, watermark, text"
)

PLAN = {
    "name": "community_r3b_upper_body_weak_pose_fur_paste",
    "status": "implemented",
    "supersedes": "community_r3_pose_face_regen_horse_paste",
    "forbid": [
        "fooocus_inpaint_on_armor_plate",
        "r1_denoise_retune",
        "r3_fullframe_openpose_0.9",
        "qwen_edit",
    ],
    "openpose_strength": R3B_OPENPOSE_STRENGTH,
    "instantid_weight": R3B_INSTANTID_WEIGHT,
    "upper_height": R3B_UPPER_H,
    "denoise": 1.0,
    "latent": "empty",
    "paste": "mare_fur_only",
    "horse_guard_y_base": sem.ELENA.horse_guard_y,
    "cost_cny": {"pilot": "0.8-2", "cap": "3"},
}


def upper_band(plate: Image.Image) -> tuple[Image.Image, int]:
    """Crop/resize human upper band to R3B_FULL_W x R3B_UPPER_H."""
    plate_r = plate.convert("RGB").resize((R3B_FULL_W, R3B_FULL_H), Image.Resampling.LANCZOS)
    y_cut = int(sem.ELENA.horse_guard_y / sem.BASE[1] * R3B_FULL_H)
    # Take from top to y_cut (horse guard), then scale to UPPER_H
    band = plate_r.crop((0, 0, R3B_FULL_W, y_cut))
    upper = band.resize((R3B_FULL_W, R3B_UPPER_H), Image.Resampling.LANCZOS)
    return upper, y_cut


def head_crop_from_upper(upper: Image.Image) -> Image.Image:
    w, h = upper.size
    box = (int(w * 0.22), int(h * 0.00), int(w * 0.72), int(h * 0.42))
    return upper.crop(box).resize((512, 512), Image.Resampling.LANCZOS)


def build_r3b_graph(
    *,
    upper_name: str,
    face_name: str,
    ckpt: str,
    pose_cn: str,
    instant_cn: str,
    instant_ip: str,
    seed: int,
) -> dict:
    """Empty latent upper-body nude; pose+kps from upper crop only."""
    return {
        "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": ELENA_POS, "clip": ["3", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": ELENA_NEG, "clip": ["3", 1]}},
        "1": {"class_type": "LoadImage", "inputs": {"image": upper_name}},
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
                "resolution": 768,
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
        # Keypoints from upper crop (scheme_b style domain), face identity from head crop
        "9": {
            "class_type": "FaceKeypointsPreprocessor",
            "inputs": {"faceanalysis": ["7", 0], "image": ["1", 0]},
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
                "weight": R3B_INSTANTID_WEIGHT,
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
                "strength": R3B_OPENPOSE_STRENGTH,
                "start_percent": 0.0,
                "end_percent": 1.0,
            },
        },
        "14": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": R3B_FULL_W, "height": R3B_UPPER_H, "batch_size": 1},
        },
        "15": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["10", 0],
                "seed": seed,
                "steps": R3B_STEPS,
                "cfg": R3B_CFG,
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
            "inputs": {"images": ["16", 0], "filename_prefix": "r3b-elena-upper-raw"},
        },
        "23": {
            "class_type": "SaveImage",
            "inputs": {"images": ["12", 0], "filename_prefix": "r3b-elena-upper-pose"},
        },
    }


def mare_fur_mask(rgb: np.ndarray) -> np.ndarray:
    """True where plate looks like chestnut horse fur (not chrome/gold armor)."""
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    metal = (chroma < 38) & ((mean < 105) | (mean > 155))
    # gold-ish armor
    gold = (r > g) & (g > b) & ((r - b) > 40) & (mean > 90) & (mean < 200) & (chroma > 45)
    brown = (r > 55) & (g > 35) & (r > b * 1.02) & (g > b * 0.85) & (mean < 175) & (mean > 35)
    return brown & ~metal & ~gold


def paste_mare_fur_only(
    plate: Image.Image,
    upper_gen: Image.Image,
    y_cut: int,
) -> Image.Image:
    """Full canvas: generated upper on top; extend skin downward; overlay mare fur only."""
    plate_r = plate.convert("RGB").resize((R3B_FULL_W, R3B_FULL_H), Image.Resampling.LANCZOS)
    upper_fit = upper_gen.convert("RGB").resize((R3B_FULL_W, max(y_cut, 64)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (R3B_FULL_W, R3B_FULL_H))
    canvas.paste(upper_fit, (0, 0))
    # Fill below cut by repeating the last row of upper (avoids leaving plate armor)
    if y_cut < R3B_FULL_H:
        edge = upper_fit.crop((0, upper_fit.size[1] - 1, R3B_FULL_W, upper_fit.size[1]))
        fill = edge.resize((R3B_FULL_W, R3B_FULL_H - y_cut), Image.Resampling.NEAREST)
        canvas.paste(fill, (0, y_cut))

    plate_a = np.asarray(plate_r, dtype=np.float32)
    fur = mare_fur_mask(plate_a)
    alpha = np.zeros((R3B_FULL_H, R3B_FULL_W), dtype=np.float32)
    alpha[y_cut:, :] = np.where(fur[y_cut:, :], 1.0, 0.0)
    for i in range(HORSE_FEATHER):
        y = y_cut - HORSE_FEATHER // 3 + i
        if 0 <= y < R3B_FULL_H:
            t = (i + 1) / (HORSE_FEATHER + 1)
            alpha[y] = np.where(fur[y], np.maximum(alpha[y], t), alpha[y])

    alpha_img = Image.fromarray(np.clip(alpha * 255, 0, 255).astype(np.uint8), mode="L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=max(1, HORSE_FEATHER // 3)))
    return Image.composite(plate_r, canvas, alpha_img)


def save_previews(out_dir: Path, final: Image.Image, upper: Image.Image, stem: str) -> None:
    w, h = final.size
    final.resize((512, int(512 * h / w)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    final.crop((int(w * 0.22), int(h * 0.05), int(w * 0.78), int(h * 0.52))).save(
        out_dir / f"{stem}-torso.webp", "WEBP", quality=85
    )
    upper.resize((512, int(512 * upper.size[1] / upper.size[0])), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-upper-preview.webp", "WEBP", quality=85
    )


def undress_elena_r3b(
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
    debug = out_dir / "debug"
    debug.mkdir(parents=True, exist_ok=True)

    plate = Image.open(legacy.ELENA_PLATE).convert("RGB")
    upper, y_cut = upper_band(plate)
    face = head_crop_from_upper(upper)
    upper_name = "r3b-elena-upper.png"
    face_name = "r3b-elena-face.png"
    upper.save(input_dir / upper_name)
    face.save(input_dir / face_name)
    upper.save(debug / "elena-upper-band.png")
    face.save(debug / "elena-face-crop.png")
    base.upload(host, input_dir / upper_name)
    base.upload(host, input_dir / face_name)

    seed = R3B_SEED + attempt * 17
    graph = build_r3b_graph(
        upper_name=upper_name,
        face_name=face_name,
        ckpt=models["ckpt"],
        pose_cn=models["pose_cn"],
        instant_cn=models["instant_cn"],
        instant_ip=models["instant_ip"],
        seed=seed,
    )
    print(
        f"R3B_GRAPH upper={R3B_FULL_W}x{R3B_UPPER_H} openpose={R3B_OPENPOSE_STRENGTH} "
        f"instantid={R3B_INSTANTID_WEIGHT} fur_paste y_cut={y_cut}",
        flush=True,
    )
    got = base.run_graph(host, graph, {"raw": "22", "pose": "23"}, work, "r3b-elena")
    raw = Image.open(got["raw"]).convert("RGB")
    pose_path = got.get("pose")
    if pose_path and Path(pose_path).is_file():
        Image.open(pose_path).convert("RGB").save(debug / "elena-upper-pose.png")

    final = paste_mare_fur_only(plate, raw, y_cut)
    stem = legacy.OUT_STEM[("elena", "nude")]
    dest = out_dir / f"{stem}.png"
    final.save(dest)
    raw.save(out_dir / f"{stem}-r3b-upper-raw.png")
    save_previews(out_dir, final, raw, stem)

    try:
        import shutil

        art = Path("/opt/cursor/artifacts")
        if art.is_dir():
            shutil.copyfile(out_dir / f"{stem}-preview.webp", art / "r3b-elena-preview.webp")
            shutil.copyfile(out_dir / f"{stem}-torso.webp", art / "r3b-elena-torso.webp")
    except OSError as exc:
        print(f"PREVIEW_COPY_FAIL {exc}", flush=True)

    meta = {
        "pipeline": "community_r3b",
        "actor": "elena",
        "mode": "nude",
        "attempt": attempt,
        "seed": seed,
        "denoise": 1.0,
        "latent": "empty",
        "upper_size": [R3B_FULL_W, R3B_UPPER_H],
        "openpose_strength": R3B_OPENPOSE_STRENGTH,
        "instantid_weight": R3B_INSTANTID_WEIGHT,
        "y_cut": y_cut,
        "paste": "mare_fur_only",
        "forbid": PLAN["forbid"],
    }
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R3B {dest} {dest.stat().st_size}", flush=True)
    print(f"VISUAL_JUDGE elena nude {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=base.DEFAULT_OUT)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-r3b-input"))
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
        print("R3B_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(0)

    base.check_host(args.host)
    models = resolve_base_models(args.host)
    undress_elena_r3b(args.host, models, args.out, args.input, attempt=args.attempt)


if __name__ == "__main__":
    main()
