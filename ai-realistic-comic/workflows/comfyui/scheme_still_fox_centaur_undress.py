"""Clothes-only crop-and-stitch undress for the fox/centaur solos.

Do not run scheme_b_from_plate.py on these stills: the full-frame OpenPose
redraw would wipe the nine tails and the mare body. Cloth is a 1024 crop with
InpaintModelConditioning at denoise 0.75. Faces, tails, and the horse stay
unmasked. InstantID reads board-center ref-face.png. No ReActor. No F34/G09.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comfy_util import queue_prompt, resolve_base_models  # noqa: E402
from inpaint_crop import (  # noqa: E402
    INPAINT_DENOISE,
    inpaint_crop_graph,
    prepare_crop,
    save_crop_pair,
    stitch,
)

CAST_ROOT = Path(__file__).resolve().parents[2]
STILL_DIR = CAST_ROOT / "library" / "stills" / "fox-centaur-embrace"
LIN_PLATE = STILL_DIR / "lin-qipao-nine-tail.png"
ELENA_PLATE = STILL_DIR / "elena-armor-centaur.png"
LIN_FACE = CAST_ROOT / "library" / "cast" / "lin_wantang" / "ref-face.png"
ELENA_FACE = CAST_ROOT / "library" / "cast" / "elena_voss" / "ref-face.png"

SAMPLER_SEED = 20261006
BJ_HOST = "connect.bjb2.seetacloud.com"
BJ_PORT = "34711"
BJ_KEY = Path.home() / ".ssh" / "bjb791"
BJ_UUID = "359a49a1c3-4cda10df"
F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"
REMOTE_INPUT = "/root/autodl-tmp/comfyui/input"
REMOTE_OUT = "/root/autodl-tmp/comfy-runs/fox-centaur-undress"
SSH = [
    "ssh",
    "-i",
    str(BJ_KEY),
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-p",
    BJ_PORT,
    "root@" + BJ_HOST,
]

LIN_POS = (
    "bare skin only, natural breasts, visible nipples, navel, skin tone matches the neck, "
    "same body under the dress, no second person"
)
LIN_NEG = (
    "child, teen, extra person, second woman, extra face, extra head, clone, ghost, "
    "qipao, cheongsam, dress, clothes, embroidery, fabric pattern, ribbon, bra, "
    "snake tail, extra limbs, smear, plastic, text, watermark"
)
ELENA_POS = (
    "bare human torso skin only, natural breasts, visible nipples, skin tone matches the neck, "
    "no metal, no armor, same waist joining the horse body"
)
ELENA_NEG = (
    "child, teen, extra person, extra face, extra hair on chest, armor, plate, gauntlet, "
    "gorget, pauldron, mail, clothes, bra, green eyes, blue-grey eyes, pointed ears, "
    "stallion, extra legs, smear, plastic, text, watermark"
)
LIN_DENOISE = 0.72
ELENA_DENOISE = 0.78
CROP_STITCH = "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"
INSTANTID = "https://github.com/cubiq/ComfyUI_InstantID"


def assert_not_forbidden_uuid(uuid: str) -> None:
    if uuid in {F34_UUID, G09_UUID}:
        raise SystemExit(f"FORBIDDEN_INSTANCE {uuid}")


BASE = (1024, 1536)


def _scale_xy(size: tuple[int, int], points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    width, height = size
    return [(int(x / BASE[0] * width), int(y / BASE[1] * height)) for x, y in points]


def _fill_px(size: tuple[int, int], points: list[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(_scale_xy(size, points), fill=255)
    return mask


def _clear_px(mask: Image.Image, box: tuple[int, int, int, int], radius: int = 16) -> None:
    corners = _scale_xy(mask.size, [(box[0], box[1]), (box[2], box[3])])
    ImageDraw.Draw(mask).rounded_rectangle(
        (corners[0][0], corners[0][1], corners[1][0], corners[1][1]),
        radius=radius,
        fill=0,
    )


def _unmask_color(image: Image.Image, mask: Image.Image, pred) -> Image.Image:
    out = mask.copy()
    pix = out.load()
    src = image.convert("RGB")
    for y in range(image.height):
        for x in range(image.width):
            if pix[x, y] < 12:
                continue
            if pred(src.getpixel((x, y)), x, y):
                pix[x, y] = 0
    return out


def lin_clothes_mask(image: Image.Image) -> Image.Image:
    """Qipao only. Keep face, arms, tails, garden, heels."""
    size = image.size
    mask = _fill_px(
        size,
        [
            (410, 298),
            (470, 296),
            (512, 348),
            (518, 430),
            (510, 540),
            (528, 640),
            (500, 740),
            (488, 900),
            (498, 1276),
            (368, 1278),
            (354, 980),
            (352, 780),
            (360, 600),
            (354, 450),
            (362, 348),
        ],
    )
    _clear_px(mask, (320, 20, 560, 286), radius=24)
    _clear_px(mask, (0, 180, 340, 980), radius=6)
    _clear_px(mask, (560, 140, 1023, 1180), radius=6)
    _clear_px(mask, (380, 1348, 640, 1535), radius=8)
    _clear_px(mask, (280, 620, 348, 800), radius=8)
    return mask.filter(ImageFilter.GaussianBlur(radius=12))


def elena_clothes_mask(image: Image.Image) -> Image.Image:
    """Armor and gauntlets only. Keep face, glasses, hair, horse, terrace."""
    size = image.size
    mask = _fill_px(
        size,
        [
            (370, 245),
            (480, 242),
            (540, 300),
            (555, 400),
            (548, 530),
            (510, 600),
            (430, 655),
            (330, 660),
            (240, 700),
            (175, 650),
            (185, 520),
            (210, 380),
            (255, 290),
            (330, 250),
        ],
    )
    _clear_px(mask, (330, 20, 530, 238), radius=18)

    def horse(rgb: tuple[int, int, int], x: int, y: int) -> bool:
        red, green, blue = rgb
        sx = int(x / size[0] * BASE[0])
        sy = int(y / size[1] * BASE[1])
        brown = red > 55 and red > green + 12 and green >= blue - 8
        return bool(brown and sy > 650 and sx > 320)

    mask = _unmask_color(image, mask, pred=horse)
    return mask.filter(ImageFilter.GaussianBlur(radius=12))


def lin_chest_mask(image: Image.Image) -> Image.Image:
    """Upper qipao only, to avoid spawning a second figure in a full-dress hole."""
    size = image.size
    mask = _fill_px(
        size,
        [
            (400, 300),
            (490, 298),
            (518, 360),
            (515, 500),
            (505, 700),
            (368, 700),
            (358, 500),
            (365, 360),
        ],
    )
    _clear_px(mask, (320, 20, 560, 286), radius=20)
    return mask.filter(ImageFilter.GaussianBlur(radius=10))


def lin_skirt_mask(image: Image.Image) -> Image.Image:
    size = image.size
    mask = _fill_px(
        size,
        [
            (360, 690),
            (500, 690),
            (492, 1274),
            (368, 1276),
        ],
    )
    _clear_px(mask, (478, 760, 560, 1320), radius=8)
    return mask.filter(ImageFilter.GaussianBlur(radius=10))


def elena_remain_mask(image: Image.Image) -> Image.Image:
    """Leftover pauldron, gauntlet, hip plate, collar on a first-pass nude."""
    size = image.size
    arm = _fill_px(
        size,
        [
            (175, 255),
            (330, 250),
            (340, 420),
            (320, 700),
            (175, 710),
            (160, 500),
        ],
    )
    hip = _fill_px(
        size,
        [
            (330, 555),
            (545, 545),
            (540, 680),
            (330, 690),
        ],
    )
    collar = _fill_px(
        size,
        [
            (390, 236),
            (505, 236),
            (500, 300),
            (385, 300),
        ],
    )
    mask = Image.composite(arm, Image.new("L", size, 0), arm)
    mask = Image.composite(hip, mask, hip)
    mask = Image.composite(collar, mask, collar)
    _clear_px(mask, (330, 20, 530, 238), radius=16)

    def horse(rgb: tuple[int, int, int], x: int, y: int) -> bool:
        red, green, blue = rgb
        sx = int(x / size[0] * BASE[0])
        sy = int(y / size[1] * BASE[1])
        brown = red > 55 and red > green + 12 and green >= blue - 8
        return bool(brown and sy > 620 and sx > 300)

    mask = _unmask_color(image, mask, pred=horse)
    return mask.filter(ImageFilter.GaussianBlur(radius=10))


def pad_face_for_instantid(src: Image.Image, size: int = 768) -> Image.Image:
    """InsightFace misses a jaw-up lock if the canvas is too tight."""
    src = src.convert("RGB")
    canvas = Image.new("RGB", (size, size), (46, 42, 38))
    scale = min((size - 96) / max(src.width, 1), (size - 96) / max(src.height, 1))
    new_w = max(8, int(src.width * scale))
    new_h = max(8, int(src.height * scale))
    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2))
    return canvas


def instantid_inpaint_graph(
    models: dict[str, str],
    crop_name: str,
    mask_name: str,
    ref_name: str,
    positive: str,
    negative: str,
    seed: int,
    prefix: str,
) -> dict:
    graph = inpaint_crop_graph(
        ckpt=models["ckpt"],
        crop_name=crop_name,
        mask_name=mask_name,
        positive=positive,
        negative=negative,
        seed=seed,
        prefix=prefix,
        denoise=INPAINT_DENOISE,
    )
    graph["60"] = {"class_type": "LoadImage", "inputs": {"image": ref_name}}
    graph["6"] = {
        "class_type": "InstantIDModelLoader",
        "inputs": {"instantid_file": models["instant_ip"]},
    }
    graph["7"] = {"class_type": "InstantIDFaceAnalysis", "inputs": {"provider": "CPU"}}
    graph["8"] = {
        "class_type": "DiffControlNetLoader",
        "inputs": {"model": ["3", 0], "control_net_name": models["instant_cn"]},
    }
    graph["9"] = {
        "class_type": "FaceKeypointsPreprocessor",
        "inputs": {"faceanalysis": ["7", 0], "image": ["1", 0]},
    }
    graph["10"] = {
        "class_type": "ApplyInstantID",
        "inputs": {
            "instantid": ["6", 0],
            "insightface": ["7", 0],
            "control_net": ["8", 0],
            "image": ["60", 0],
            "model": ["3", 0],
            "positive": ["4", 0],
            "negative": ["5", 0],
            "weight": 0.8,
            "start_at": 0.0,
            "end_at": 1.0,
            "image_kps": ["9", 0],
        },
    }
    graph["40"]["inputs"]["positive"] = ["10", 1]
    graph["40"]["inputs"]["negative"] = ["10", 2]
    graph["15"]["inputs"]["model"] = ["10", 0]
    return graph


def envelope(prompt: dict, stage: str) -> dict:
    return {
        "source": {
            "inpaint": CROP_STITCH,
            "instantid": INSTANTID,
            "why": "Clothes-only 1024 crop. Tails and horse stay unmasked. Not a full OpenPose redraw.",
            "stage": stage,
            "sampler_seed": SAMPLER_SEED,
            "cloth_denoise": INPAINT_DENOISE,
            "beijing": BJ_UUID,
        },
        "prompt": prompt,
    }


def prepare_job(name: str, plate: Path, mask: Image.Image, input_dir: Path) -> dict:
    image = Image.open(plate).convert("RGB")
    input_dir.mkdir(parents=True, exist_ok=True)
    mask_name = f"{name}-mask.png"
    mask.convert("RGB").save(input_dir / mask_name)
    job = prepare_crop(image, mask)
    crop_name, crop_mask = save_crop_pair(job, input_dir, name)
    image.save(input_dir / f"{name}-plate.png")
    return {
        "plate": image,
        "mask": mask,
        "job": job,
        "crop_name": crop_name,
        "crop_mask": crop_mask,
        "mask_name": mask_name,
    }


def emit_examples(directory: Path) -> None:
    models = {
        "ckpt": "RealVisXL_V5.0_fp16.safetensors",
        "instant_cn": "instantid/diffusion_pytorch_model.safetensors",
        "instant_ip": "ip-adapter.bin",
    }
    directory.mkdir(parents=True, exist_ok=True)
    lin = instantid_inpaint_graph(
        models, "lin-crop.png", "lin-crop-mask.png", "lin-ref-face.png", LIN_POS, LIN_NEG, SAMPLER_SEED, "lin-nude"
    )
    elena = instantid_inpaint_graph(
        models,
        "elena-crop.png",
        "elena-crop-mask.png",
        "elena-ref-face.png",
        ELENA_POS,
        ELENA_NEG,
        SAMPLER_SEED + 1,
        "elena-nude",
    )
    (directory / "scheme-still-lin-qipao-undress.api.json").write_text(
        json.dumps(envelope(lin, "lin-cloth"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (directory / "scheme-still-elena-armor-undress.api.json").write_text(
        json.dumps(envelope(elena, "elena-cloth"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _ssh(command: str) -> None:
    subprocess.run(SSH + [command], check=True)


def sync_inputs(local_dir: Path) -> None:
    _ssh(f"mkdir -p {REMOTE_INPUT} {REMOTE_OUT}")
    files = sorted(local_dir.glob("*"))
    cmd = [
        "scp",
        "-i",
        str(BJ_KEY),
        "-o",
        "BatchMode=yes",
        "-P",
        BJ_PORT,
        *[str(path) for path in files],
        f"root@{BJ_HOST}:{REMOTE_INPUT}/",
    ]
    subprocess.run(cmd, check=True)


def _upload(host: str, path: Path) -> None:
    subprocess.run(
        ["curl", "-sS", "-F", f"image=@{path}", "-F", "overwrite=true", f"{host.rstrip('/')}/upload/image"],
        check=True,
        capture_output=True,
        text=True,
    )


def run_one(
    host: str,
    models: dict[str, str],
    name: str,
    plate: Path,
    face: Path,
    mask: Image.Image,
    positive: str,
    negative: str,
    seed: int,
    input_dir: Path,
    out_dir: Path,
    denoise: float,
    stem: str | None = None,
) -> Path:
    stem = stem or name
    prepared = prepare_job(stem, plate, mask, input_dir)
    padded = pad_face_for_instantid(Image.open(face))
    padded.save(input_dir / f"{name}-ref-face.png")
    for filename in (prepared["crop_name"], prepared["crop_mask"]):
        _upload(host, input_dir / filename)
    graph = inpaint_crop_graph(
        ckpt=models["ckpt"],
        crop_name=prepared["crop_name"],
        mask_name=prepared["crop_mask"],
        positive=positive,
        negative=negative,
        seed=seed,
        prefix=f"{name}-nude-crop",
        denoise=denoise,
    )
    (out_dir / f"{name}-undress.api.json").write_text(
        json.dumps(envelope(graph, name), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    crop_out = out_dir / f"{name}-crop-inpaint.png"
    queue_prompt(host, graph, f"fox-centaur-{name}", "22", crop_out, name)
    stitched = stitch(prepared["plate"], Image.open(crop_out), prepared["job"])
    dest = out_dir / {
        "lin": "lin-qipao-nine-tail-nude.png",
        "elena": "elena-armor-centaur-nude.png",
    }.get(name, f"{name}-nude.png")
    stitched.save(dest)
    print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=STILL_DIR)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-undress-input"))
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--emit-examples", type=Path)
    parser.add_argument("--only", choices=("lin", "elena"), nargs="*")
    args = parser.parse_args()
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return
    lin_img = Image.open(LIN_PLATE).convert("RGB")
    elena_img = Image.open(ELENA_PLATE).convert("RGB")
    jobs = {
        "lin": (LIN_PLATE, LIN_FACE, lin_clothes_mask(lin_img), LIN_POS, LIN_NEG, SAMPLER_SEED, LIN_DENOISE),
        "elena": (ELENA_PLATE, ELENA_FACE, elena_clothes_mask(elena_img), ELENA_POS, ELENA_NEG, SAMPLER_SEED + 1, ELENA_DENOISE),
    }
    chosen = args.only or ["lin", "elena"]
    args.input.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    debug = Path("/tmp/fox-undress-preview/masks")
    debug.mkdir(parents=True, exist_ok=True)
    for name in chosen:
        plate, _face, mask, _p, _n, _s, _d = jobs[name]
        overlay = Image.open(plate).convert("RGBA")
        tint = Image.new("RGBA", overlay.size, (220, 40, 40, 110))
        overlay = Image.composite(tint, overlay, mask)
        mask.convert("RGB").save(debug / f"{name}-mask.png")
        overlay.save(debug / f"{name}-mask-overlay.png")
        hist = mask.histogram()
        print(f"MASK {name} opaque={sum(hist[41:])}", flush=True)
    if args.prepare_only:
        return
    models = resolve_base_models(args.host)
    print("MODELS", json.dumps(models, ensure_ascii=False), flush=True)
    if "lin" in chosen:
        chest = lin_chest_mask(lin_img)
        lin_dest = run_one(
            args.host, models, "lin", LIN_PLATE, LIN_FACE, chest, LIN_POS, LIN_NEG,
            SAMPLER_SEED, args.input, args.out, 0.70, stem="lin-chest",
        )
        after = Image.open(lin_dest).convert("RGB")
        skirt = lin_skirt_mask(after)
        run_one(
            args.host, models, "lin", lin_dest, LIN_FACE, skirt, LIN_POS, LIN_NEG,
            SAMPLER_SEED + 2, args.input, args.out, 0.70, stem="lin-skirt",
        )
    if "elena" in chosen:
        current = args.out / "elena-armor-centaur-nude.png"
        plate = current if current.is_file() else ELENA_PLATE
        remain = elena_remain_mask(Image.open(plate).convert("RGB"))
        run_one(
            args.host, models, "elena", plate, ELENA_FACE, remain, ELENA_POS, ELENA_NEG,
            SAMPLER_SEED + 3, args.input, args.out, 0.80, stem="elena-remain",
        )


if __name__ == "__main__":
    main()
