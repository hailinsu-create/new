"""Two-person still: cubiq Multi-ID InstantID, then crop-and-stitch undress.

This is the Beijing ComfyUI path. CAST.md still names F34 Qwen
`autodl/run_explicit8.py` as the film-still command. Do not edit that script.

Official cubiq Multi-ID (`examples/InstantID_multi_id.json`): one KSampler,
two ApplyInstantID with complementary masks, lock face on `image`, pose on
`image_kps`, ConditioningCombine. Do not crop-paste faces for the main pass.
InsightFace takes the largest face in image_kps, so the other face is blacked
out on each keypoints image.

Undress is a later 1024 crop with InpaintModelConditioning at denoise 0.75.
FaceDetailer runs last, one face at a time, SEGS limited by the face box.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comfy_util import (  # noqa: E402
    face_detailer_node,
    queue_prompt,
    resolve_base_models,
)
from inpaint_crop import (  # noqa: E402
    INPAINT_DENOISE,
    inpaint_crop_graph,
    pixel_box,
    prepare_crop,
    save_crop_pair,
    stitch,
)

CAST_ROOT = Path(__file__).resolve().parents[2]
SAMPLER_SEED = 20261011
FACE_DENOISE = 0.70
STILL_WIDTH = 896
STILL_HEIGHT = 1200

# Fractions of the pose image. Tuned on library/cast/body-boards/p01.png.
P01_HER_FACE = (0.32, 0.16, 0.56, 0.38)
P01_HIS_FACE = (0.50, 0.17, 0.76, 0.40)
P01_BANDEAU = (0.36, 0.38, 0.55, 0.50)

LIN_POS = (
    "photoreal adult East Asian woman looking down, soft oval face, even light skin, "
    "black-brown eyes, natural brows, nude-pink lips, clean forehead, moonlit cabin"
)
GU_POS = (
    "photoreal adult East Asian man, small oval face, fair warm skin, dark brown almond eyes, "
    "straight brows, pale rose lips, clean-shaven, black topknot, no navy forehead headband, moonlit cabin"
)
NEG = (
    "child, teen, extra fingers, extra hand, extra person, gold irises, crimson lips, "
    "navy headband, forehead wrap, smear, plastic skin, fish tail, fins, her legs, her feet, "
    "text, watermark, collage, glitch"
)
BANDEAU_POS = (
    "photoreal matching skin, bare chest of an adult woman, natural breast and nipple, "
    "skin tone matches the neck, no white cloth"
)
BANDEAU_NEG = (
    "white bandeau, strap, bra, cloth, fabric, smear, blotch, blur, plastic, "
    "extra fingers, extra hand, text, watermark"
)
FACE_NEG = "child, extra fingers, gold irises, crimson lips, smear, plastic skin, headband, text, watermark"

CUBIQ_MULTI_ID = "https://github.com/cubiq/ComfyUI_InstantID/blob/main/examples/InstantID_multi_id.json"
CROP_STITCH = "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"


def exclusive_face_masks(
    size: tuple[int, int],
    her_box: tuple[int, int, int, int],
    his_box: tuple[int, int, int, int],
) -> tuple[Image.Image, Image.Image]:
    """Complementary masks. Overlap is split on x, like cubiq left/right SolidMask."""
    her = Image.new("L", size, 0)
    his = Image.new("L", size, 0)
    ImageDraw.Draw(her).ellipse(her_box, fill=255)
    ImageDraw.Draw(his).ellipse(his_box, fill=255)
    her_c = (her_box[0] + her_box[2]) / 2
    his_c = (his_box[0] + his_box[2]) / 2
    split_x = int(round((her_c + his_c) / 2))
    width, height = size

    def clip_left(mask: Image.Image) -> Image.Image:
        out = Image.new("L", size, 0)
        out.paste(mask.crop((0, 0, split_x, height)), (0, 0))
        return out

    def clip_right(mask: Image.Image) -> Image.Image:
        out = Image.new("L", size, 0)
        out.paste(mask.crop((split_x, 0, width, height)), (split_x, 0))
        return out

    her = clip_left(her).filter(ImageFilter.GaussianBlur(radius=8))
    his = clip_right(his).filter(ImageFilter.GaussianBlur(radius=8))
    return clip_left(her), clip_right(his)


def hide_face(pose: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    out = pose.convert("RGB").copy()
    ImageDraw.Draw(out).ellipse(box, fill=(8, 8, 10))
    return out


def union_mask(her: Image.Image, his: Image.Image) -> Image.Image:
    return ImageChops.lighter(her.convert("L"), his.convert("L"))


def build_multi_id_graph(
    models: dict[str, str],
    pose_name: str,
    lin_face: str,
    gu_face: str,
    lin_mask: str,
    gu_mask: str,
    lin_kps: str,
    gu_kps: str,
    union_mask_name: str,
    seed: int = SAMPLER_SEED,
) -> dict:
    """One sampler. Two ApplyInstantID. Complementary masks. Face-only inpaint."""
    return {
        "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": models["ckpt"]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": LIN_POS, "clip": ["3", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": GU_POS, "clip": ["3", 1]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["3", 1]}},
        "20": {"class_type": "LoadImage", "inputs": {"image": pose_name}},
        "21": {"class_type": "LoadImage", "inputs": {"image": lin_face}},
        "22": {"class_type": "LoadImage", "inputs": {"image": gu_face}},
        "23": {"class_type": "LoadImage", "inputs": {"image": lin_mask}},
        "24": {"class_type": "LoadImage", "inputs": {"image": gu_mask}},
        "25": {"class_type": "LoadImage", "inputs": {"image": lin_kps}},
        "26": {"class_type": "LoadImage", "inputs": {"image": gu_kps}},
        "27": {"class_type": "LoadImage", "inputs": {"image": union_mask_name}},
        "30": {"class_type": "ImageToMask", "inputs": {"image": ["23", 0], "channel": "red"}},
        "31": {"class_type": "ImageToMask", "inputs": {"image": ["24", 0], "channel": "red"}},
        "32": {"class_type": "ImageToMask", "inputs": {"image": ["27", 0], "channel": "red"}},
        "7": {"class_type": "InstantIDModelLoader", "inputs": {"instantid_file": models["instant_ip"]}},
        "8": {"class_type": "InstantIDFaceAnalysis", "inputs": {"provider": "CPU"}},
        "9": {
            "class_type": "DiffControlNetLoader",
            "inputs": {"model": ["3", 0], "control_net_name": models["instant_cn"]},
        },
        "10": {
            "class_type": "ApplyInstantID",
            "inputs": {
                "instantid": ["7", 0],
                "insightface": ["8", 0],
                "control_net": ["9", 0],
                "image": ["21", 0],
                "model": ["3", 0],
                "positive": ["4", 0],
                "negative": ["6", 0],
                "weight": 0.8,
                "start_at": 0.0,
                "end_at": 1.0,
                "image_kps": ["25", 0],
                "mask": ["30", 0],
            },
        },
        "11": {
            "class_type": "ApplyInstantID",
            "inputs": {
                "instantid": ["7", 0],
                "insightface": ["8", 0],
                "control_net": ["9", 0],
                "image": ["22", 0],
                "model": ["10", 0],
                "positive": ["5", 0],
                "negative": ["6", 0],
                "weight": 0.85,
                "start_at": 0.0,
                "end_at": 1.0,
                "image_kps": ["26", 0],
                "mask": ["31", 0],
            },
        },
        "12": {
            "class_type": "ConditioningCombine",
            "inputs": {"conditioning_1": ["10", 1], "conditioning_2": ["11", 1]},
        },
        "13": {
            "class_type": "ConditioningCombine",
            "inputs": {"conditioning_1": ["10", 2], "conditioning_2": ["11", 2]},
        },
        "40": {
            "class_type": "InpaintModelConditioning",
            "inputs": {
                "positive": ["12", 0],
                "negative": ["13", 0],
                "vae": ["3", 2],
                "pixels": ["20", 0],
                "mask": ["32", 0],
                "noise_mask": True,
            },
        },
        "15": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["11", 0],
                "seed": seed,
                "steps": 26,
                "cfg": 4.0,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["40", 0],
                "negative": ["40", 1],
                "latent_image": ["40", 2],
                "denoise": FACE_DENOISE,
            },
        },
        "16": {"class_type": "VAEDecode", "inputs": {"samples": ["15", 0], "vae": ["3", 2]}},
        "99": {"class_type": "SaveImage", "inputs": {"images": ["16", 0], "filename_prefix": "p01-multi-id"}},
    }


def build_detail_graph(
    models: dict[str, str],
    crop_name: str,
    ref_name: str,
    positive: str,
    seed: int,
    prefix: str,
) -> dict:
    """FaceDetailer last. One face in the crop. Identity from the lock, not from the still."""
    prompt = {
        "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": models["ckpt"]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": positive, "clip": ["3", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": FACE_NEG, "clip": ["3", 1]}},
        "1": {"class_type": "LoadImage", "inputs": {"image": crop_name}},
        "2": {"class_type": "LoadImage", "inputs": {"image": ref_name}},
        "17": {
            "class_type": "IPAdapterUnifiedLoaderFaceID",
            "inputs": {
                "model": ["3", 0],
                "preset": "FACEID PLUS V2",
                "lora_strength": 0.6,
                "provider": "CPU",
            },
        },
        "18": {
            "class_type": "IPAdapterFaceID",
            "inputs": {
                "model": ["17", 0],
                "ipadapter": ["17", 1],
                "image": ["2", 0],
                "weight": 0.85,
                "weight_faceidv2": 1.0,
                "weight_type": "linear",
                "combine_embeds": "average",
                "start_at": 0.0,
                "end_at": 1.0,
                "embeds_scaling": "V only",
            },
        },
        "19": {"class_type": "UltralyticsDetectorProvider", "inputs": {"model_name": models["face_det"]}},
        "22": {"class_type": "SaveImage", "inputs": {"images": ["21", 0], "filename_prefix": prefix}},
    }
    sam = None
    if "sam" in models:
        prompt["20"] = {
            "class_type": "SAMLoader",
            "inputs": {"model_name": models["sam"], "device_mode": "AUTO"},
        }
        sam = ["20", 0]
    prompt["21"] = face_detailer_node(["1", 0], ["18", 0], ["4", 0], ["5", 0], ["19", 0], sam, 0.40, seed)
    return prompt


def envelope(prompt: dict, stage: str) -> dict:
    return {
        "source": {
            "multi_id": CUBIQ_MULTI_ID,
            "inpaint": CROP_STITCH,
            "why": "Full-frame dual InstantID with complementary masks. Cloth is a later 1024 crop. No face paste.",
            "stage": stage,
            "sampler_seed": SAMPLER_SEED,
            "face_denoise": FACE_DENOISE,
            "cloth_denoise": INPAINT_DENOISE,
        },
        "prompt": prompt,
    }


def _write_mask_rgb(mask: Image.Image, path: Path) -> None:
    mask.convert("RGB").save(path)


def prepare_p01_inputs(
    pose: Image.Image,
    input_dir: Path,
    her_frac=P01_HER_FACE,
    his_frac=P01_HIS_FACE,
    band_frac=P01_BANDEAU,
) -> dict[str, tuple[int, int, int, int]]:
    pose = pose.convert("RGB")
    if pose.size != (STILL_WIDTH, STILL_HEIGHT):
        pose = pose.resize((STILL_WIDTH, STILL_HEIGHT), Image.Resampling.LANCZOS)
    input_dir.mkdir(parents=True, exist_ok=True)
    pose.save(input_dir / "p01-pose.png")
    her_box = pixel_box(pose.size, her_frac)
    his_box = pixel_box(pose.size, his_frac)
    band_box = pixel_box(pose.size, band_frac)
    her_m, his_m = exclusive_face_masks(pose.size, her_box, his_box)
    _write_mask_rgb(her_m, input_dir / "p01-lin-mask.png")
    _write_mask_rgb(his_m, input_dir / "p01-gu-mask.png")
    _write_mask_rgb(union_mask(her_m, his_m), input_dir / "p01-face-union.png")
    hide_face(pose, his_box).save(input_dir / "p01-lin-kps.png")
    hide_face(pose, her_box).save(input_dir / "p01-gu-kps.png")
    band = Image.new("L", pose.size, 0)
    ImageDraw.Draw(band).rounded_rectangle(band_box, radius=16, fill=255)
    band = band.filter(ImageFilter.GaussianBlur(radius=12))
    _write_mask_rgb(band, input_dir / "p01-bandeau-mask.png")
    print(f"PREP her={her_box} his={his_box} band={band_box}", flush=True)
    return {"her": her_box, "his": his_box, "band": band_box}


def _pad_face(src: Image.Image, box: tuple[int, int, int, int], dest: Path) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    """Return (dest_box on the still, inner box on the 1024 canvas)."""
    pad = 1024
    x0, y0, x1, y1 = box
    dest_box = (
        max(0, x0),
        max(0, y0),
        min(src.width, x1),
        min(src.height, y1),
    )
    crop = src.crop(dest_box)
    canvas = Image.new("RGB", (pad, pad), (24, 26, 32))
    width, height = crop.size
    scale = min((pad - 48) / max(width, 1), (pad - 48) / max(height, 1))
    new_w, new_h = max(8, int(width * scale)), max(8, int(height * scale))
    resized = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)
    pad_x = (pad - new_w) // 2
    pad_y = (pad - new_h) // 2
    canvas.paste(resized, (pad_x, pad_y))
    canvas.save(dest)
    return dest_box, (pad_x, pad_y, pad_x + new_w, pad_y + new_h)


def _paste_detail(
    base: Image.Image,
    detailed: Image.Image,
    inner: tuple[int, int, int, int],
    dest_box: tuple[int, int, int, int],
) -> Image.Image:
    face = detailed.convert("RGB").crop(inner)
    x0, y0, x1, y1 = dest_box
    width, height = x1 - x0, y1 - y0
    face = face.resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).ellipse((int(width * 0.06), int(height * 0.08), int(width * 0.96), int(height * 0.98)), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=10))
    out = base.copy()
    out.paste(face, (x0, y0), mask)
    return out


def emit_examples(directory: Path) -> None:
    models = {
        "ckpt": "RealVisXL_V5.0_fp16.safetensors",
        "instant_cn": "instantid/diffusion_pytorch_model.safetensors",
        "pose_cn": "openpose-sdxl-xinsir/diffusion_pytorch_model.safetensors",
        "instant_ip": "ip-adapter.bin",
        "face_det": "bbox/face_yolov8m.pt",
        "sam": "sam_vit_b_01ec64.pth",
    }
    directory.mkdir(parents=True, exist_ok=True)
    main = build_multi_id_graph(
        models,
        "p01-pose.png",
        "p01-lin-face.png",
        "p01-gu-face.png",
        "p01-lin-mask.png",
        "p01-gu-mask.png",
        "p01-lin-kps.png",
        "p01-gu-kps.png",
        "p01-face-union.png",
    )
    (directory / "scheme-still-p01.api.json").write_text(
        json.dumps(envelope(main, "multi-id"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    cloth = inpaint_crop_graph(
        ckpt=models["ckpt"],
        crop_name="p01-bandeau-crop.png",
        mask_name="p01-bandeau-crop-mask.png",
        positive=BANDEAU_POS,
        negative=BANDEAU_NEG,
        seed=SAMPLER_SEED + 3,
        prefix="p01-bandeau",
    )
    (directory / "scheme-still-p01-cloth.api.json").write_text(
        json.dumps(envelope(cloth, "cloth-crop"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(directory / "scheme-still-p01.api.json")
    print(directory / "scheme-still-p01-cloth.api.json")


def run(
    host: str,
    pose_path: Path,
    lin_face: Path,
    gu_face: Path,
    out_dir: Path,
    input_dir: Path,
) -> Path:
    from PIL import Image as PILImage

    pose = PILImage.open(pose_path)
    boxes = prepare_p01_inputs(pose, input_dir)
    for src, name in ((lin_face, "p01-lin-face.png"), (gu_face, "p01-gu-face.png")):
        if not src.is_file():
            raise SystemExit(f"missing identity {src}")
        PILImage.open(src).convert("RGB").save(input_dir / name)
    models = resolve_base_models(host)
    print("MODELS", json.dumps(models), flush=True)
    out_dir.mkdir(parents=True, exist_ok=True)
    main = build_multi_id_graph(
        models,
        "p01-pose.png",
        "p01-lin-face.png",
        "p01-gu-face.png",
        "p01-lin-mask.png",
        "p01-gu-mask.png",
        "p01-lin-kps.png",
        "p01-gu-kps.png",
        "p01-face-union.png",
    )
    (out_dir / "p01-multi-id.api.json").write_text(
        json.dumps(envelope(main, "multi-id"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    after_faces = queue_prompt(host, main, "p01-multi-id", "99", out_dir / "p01-after-faces.png", "multi-id")

    still = PILImage.open(after_faces).convert("RGB")
    band_mask = PILImage.open(input_dir / "p01-bandeau-mask.png").convert("L")
    job = prepare_crop(still, band_mask)
    crop_name, mask_name = save_crop_pair(job, input_dir, "p01-bandeau")
    cloth = inpaint_crop_graph(
        ckpt=models["ckpt"],
        crop_name=crop_name,
        mask_name=mask_name,
        positive=BANDEAU_POS,
        negative=BANDEAU_NEG,
        seed=SAMPLER_SEED + 3,
        prefix="p01-bandeau",
    )
    crop_out = queue_prompt(host, cloth, "p01-bandeau", "22", out_dir / "p01-bandeau-crop.png", "bandeau")
    undressed = stitch(still, PILImage.open(crop_out), job)
    undressed_path = out_dir / "p01-after-cloth.png"
    undressed.save(undressed_path)

    result = undressed
    for key, ref_name, positive, tag in (
        ("her", "p01-lin-face.png", LIN_POS, "lin-detail"),
        ("his", "p01-gu-face.png", GU_POS, "gu-detail"),
    ):
        crop_path = input_dir / f"p01-{tag}.png"
        dest_box, inner = _pad_face(result, boxes[key], crop_path)
        detail = build_detail_graph(models, crop_path.name, ref_name, positive, SAMPLER_SEED + 4, tag)
        detailed = queue_prompt(host, detail, tag, "22", out_dir / f"p01-{tag}.png", tag)
        result = _paste_detail(result, PILImage.open(detailed), inner, dest_box)

    dest = out_dir / "p01-nude.png"
    result.save(dest)
    print(f"FINAL {dest} {dest.stat().st_size}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/comfy-runs/p01-still"))
    parser.add_argument("--input", type=Path, default=Path("/root/autodl-tmp/comfyui/input"))
    parser.add_argument(
        "--pose",
        type=Path,
        default=CAST_ROOT / "library/cast/body-boards/p01.png",
    )
    parser.add_argument(
        "--lin-face",
        type=Path,
        default=CAST_ROOT / "library/cast/lin_wantang/ref-face.png",
    )
    parser.add_argument(
        "--gu-face",
        type=Path,
        default=CAST_ROOT / "library/cast/gu_chengan/ref-face.png",
    )
    parser.add_argument("--emit-examples", type=Path)
    args = parser.parse_args()
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return
    run(args.host, args.pose, args.lin_face, args.gu_face, args.out, args.input)


if __name__ == "__main__":
    main()
