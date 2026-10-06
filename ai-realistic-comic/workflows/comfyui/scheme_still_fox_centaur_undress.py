"""Clothes-only crop-and-stitch undress for the fox/centaur solos.

Community stack this follows (not Scheme B full redraw):
- lquesada / comfyorg Crop-and-Stitch + InpaintModelConditioning
- clothing denoise 0.75–0.85; edge pass ~0.4
- small holes (split garments); downscale large crops to avoid double bodies
- InstantID lock from a *detectable* head-shoulder crop of the clothed plate
  (jaw-up ref-face.png alone often fails InsightFace)
- FaceDetailer is optional post; no ReActor; Beijing only; F34/G09 off

Do not feed these stills to scheme_b_from_plate.py — OpenPose redraw wipes
fox tails and the mare body.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comfy_util import queue_prompt, resolve_base_models  # noqa: E402
from inpaint_crop import (  # noqa: E402
    CropJob,
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
# Community clothing band. Below ~0.7 keeps fabric; above ~0.9 drifts anatomy.
CLOTH_DENOISE = 0.80
EDGE_DENOISE = 0.42
MASK_BLUR = 12
# CropAndStitch: large holes spawn double bodies — keep content under this share of the 1024 canvas.
MAX_CONTENT_FRAC = 0.58

BJ_HOST = "connect.bjb2.seetacloud.com"
BJ_PORT = "34711"
BJ_KEY = Path.home() / ".ssh" / "bjb791"
BJ_UUID = "359a49a1c3-4cda10df"
F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"

LIN_POS = (
    "bare skin only, natural breasts, visible nipples, navel, skin tone matches the neck, "
    "same adult woman already in the photo, one person only, no second body"
)
LIN_NEG = (
    "child, teen, extra person, second woman, extra face, extra head, clone, ghost, "
    "qipao, cheongsam, dress, clothes, embroidery, fabric pattern, ribbon, bra, panties, "
    "snake tail, extra limbs, smear, plastic, text, watermark"
)
ELENA_POS = (
    "bare human torso skin only, natural breasts, visible nipples, skin tone matches the neck, "
    "brown eyes, round gold wire glasses, no metal, no armor, waist joins the bay mare body, "
    "one person only"
)
ELENA_NEG = (
    "child, teen, extra person, extra face, armor, plate, gauntlet, gorget, pauldron, mail, "
    "clothes, bra, green eyes, blue-grey eyes, blue-gray eyes, pointed ears, stallion, "
    "extra legs, smear, plastic, text, watermark"
)
EDGE_POS = "matching bare skin, seamless blend to surrounding skin, no cloth edge"
EDGE_NEG = "seam, hard edge, cloth fringe, metal rim, smear, blur, plastic, text, watermark"

CROP_STITCH = "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"
INSTANTID = "https://github.com/cubiq/ComfyUI_InstantID"
BASE = (1024, 1536)

# Head-shoulder boxes on the clothed plates (px at 1024×1536). InsightFace needs shoulders.
LIN_HEAD = (360, 60, 560, 340)
ELENA_HEAD = (340, 40, 540, 300)
LIN_FACE_CLEAR = (320, 20, 560, 300)
ELENA_FACE_CLEAR = (330, 20, 530, 235)


@dataclass(frozen=True)
class RegionPass:
    stem: str
    box: tuple[int, int, int, int]
    denoise: float
    positive: str
    negative: str
    grow: int = 0


def assert_not_forbidden_uuid(uuid: str) -> None:
    if uuid in {F34_UUID, G09_UUID}:
        raise SystemExit(f"FORBIDDEN_INSTANCE {uuid}")


def _scale_box(size: tuple[int, int], box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    width, height = size
    x0, y0, x1, y1 = box
    return (
        int(x0 / BASE[0] * width),
        int(y0 / BASE[1] * height),
        int(x1 / BASE[0] * width),
        int(y1 / BASE[1] * height),
    )


def box_mask(
    image: Image.Image,
    box: tuple[int, int, int, int],
    *,
    blur: int = MASK_BLUR,
    clear_face: tuple[int, int, int, int] | None = None,
) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    rect = _scale_box(image.size, box)
    ImageDraw.Draw(mask).rounded_rectangle(rect, radius=18, fill=255)
    if clear_face is not None:
        ImageDraw.Draw(mask).rounded_rectangle(_scale_box(image.size, clear_face), radius=20, fill=0)
    if blur:
        mask = mask.filter(ImageFilter.GaussianBlur(radius=blur))
    return mask


def dilate_mask(mask: Image.Image, pixels: int = 18) -> Image.Image:
    if pixels <= 0:
        return mask.convert("L")
    return mask.convert("L").filter(ImageFilter.MaxFilter(pixels | 1))


def mask_opaque_ratio(mask: Image.Image) -> float:
    hist = mask.convert("L").histogram()
    return sum(hist[41:]) / float(mask.width * mask.height)


def prepare_crop_community(
    image: Image.Image,
    mask: Image.Image,
    *,
    target: int = 1024,
    max_content_frac: float = MAX_CONTENT_FRAC,
) -> CropJob:
    """Crop-and-stitch with extra downscale when the hole is large (anti double-body)."""
    job = prepare_crop(image, mask, target=target)
    content_w = job.inner[2] - job.inner[0]
    content_h = job.inner[3] - job.inner[1]
    frac = max(content_w, content_h) / float(target)
    if frac <= max_content_frac:
        return job
    # Shrink content on the canvas; leave more gray context — community downscale for big holes.
    scale = max_content_frac / frac
    new_w = max(16, int(content_w * scale) // 8 * 8)
    new_h = max(16, int(content_h * scale) // 8 * 8)
    piece = job.canvas.crop(job.inner).resize((new_w, new_h), Image.Resampling.LANCZOS)
    piece_m = job.canvas_mask.crop(job.inner).resize((new_w, new_h), Image.Resampling.BILINEAR)
    canvas = Image.new("RGB", (target, target), (12, 12, 16))
    canvas_mask = Image.new("L", (target, target), 0)
    pad_x = (target - new_w) // 2
    pad_y = (target - new_h) // 2
    canvas.paste(piece, (pad_x, pad_y))
    canvas_mask.paste(piece_m, (pad_x, pad_y))
    return CropJob(
        canvas=canvas,
        canvas_mask=canvas_mask,
        orig_box=job.orig_box,
        inner=(pad_x, pad_y, pad_x + new_w, pad_y + new_h),
        full_mask=job.full_mask,
    )


def head_shoulder_from_plate(plate: Image.Image, box: tuple[int, int, int, int], size: int = 768) -> Image.Image:
    """InstantID reference: shoulders-in crop from the clothed plate, padded square."""
    rect = _scale_box(plate.size, box)
    crop = plate.convert("RGB").crop(rect)
    canvas = Image.new("RGB", (size, size), (48, 44, 40))
    scale = min((size - 64) / max(crop.width, 1), (size - 64) / max(crop.height, 1))
    new_w = max(8, int(crop.width * scale))
    new_h = max(8, int(crop.height * scale))
    resized = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2))
    return canvas


def pad_face_for_instantid(src: Image.Image, size: int = 768) -> Image.Image:
    """Fallback pad for a tight jaw-up lock. Prefer head_shoulder_from_plate."""
    src = src.convert("RGB")
    canvas = Image.new("RGB", (size, size), (46, 42, 38))
    scale = min((size - 96) / max(src.width, 1), (size - 96) / max(src.height, 1))
    new_w = max(8, int(src.width * scale))
    new_h = max(8, int(src.height * scale))
    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2))
    return canvas


def lin_region_passes() -> list[RegionPass]:
    """Small holes: chest / midriff / skirt, then a low-denoise edge pass."""
    return [
        RegionPass("lin-chest", (390, 300, 510, 560), CLOTH_DENOISE, LIN_POS, LIN_NEG),
        RegionPass("lin-midriff", (375, 540, 505, 780), CLOTH_DENOISE, LIN_POS, LIN_NEG),
        RegionPass("lin-skirt", (365, 760, 495, 1260), CLOTH_DENOISE, LIN_POS, LIN_NEG),
        RegionPass("lin-edge", (380, 310, 505, 1240), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=22),
    ]


def elena_region_passes() -> list[RegionPass]:
    """Small holes: breastplate / collar / arm / hip, then edge pass."""
    return [
        RegionPass("elena-breastplate", (300, 250, 540, 560), CLOTH_DENOISE, ELENA_POS, ELENA_NEG),
        RegionPass("elena-collar", (380, 230, 510, 310), CLOTH_DENOISE, ELENA_POS, ELENA_NEG),
        RegionPass("elena-arm", (160, 280, 330, 700), CLOTH_DENOISE, ELENA_POS, ELENA_NEG),
        RegionPass("elena-hip", (320, 540, 550, 700), CLOTH_DENOISE, ELENA_POS, ELENA_NEG),
        RegionPass("elena-edge", (170, 235, 545, 700), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=20),
    ]


def _union_masks(image: Image.Image, regions: list[RegionPass], clear_face: tuple[int, int, int, int]) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    for region in regions:
        part = box_mask(image, region.box, clear_face=clear_face)
        mask = ImageChops.lighter(mask, part)
    return mask.filter(ImageFilter.GaussianBlur(radius=2))


# Kept for tests / debug overlays: union of cloth regions (not used as one pass).
def lin_clothes_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, lin_region_passes()[:3], LIN_FACE_CLEAR)


def elena_clothes_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, elena_region_passes()[:4], ELENA_FACE_CLEAR)


def instantid_inpaint_graph(
    models: dict[str, str],
    crop_name: str,
    mask_name: str,
    ref_name: str,
    positive: str,
    negative: str,
    seed: int,
    prefix: str,
    denoise: float = CLOTH_DENOISE,
) -> dict:
    graph = inpaint_crop_graph(
        ckpt=models["ckpt"],
        crop_name=crop_name,
        mask_name=mask_name,
        positive=positive,
        negative=negative,
        seed=seed,
        prefix=prefix,
        denoise=denoise,
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
            "weight": 0.75,
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
            "why": (
                "Small-hole clothes inpaint at denoise 0.75–0.85, edge pass ~0.4, "
                "InstantID from plate head-shoulder. Not full OpenPose redraw."
            ),
            "stage": stage,
            "sampler_seed": SAMPLER_SEED,
            "cloth_denoise": CLOTH_DENOISE,
            "edge_denoise": EDGE_DENOISE,
            "max_content_frac": MAX_CONTENT_FRAC,
            "beijing": BJ_UUID,
        },
        "prompt": prompt,
    }


def prepare_job(name: str, plate: Image.Image | Path, mask: Image.Image, input_dir: Path) -> dict:
    image = plate.convert("RGB") if isinstance(plate, Image.Image) else Image.open(plate).convert("RGB")
    input_dir.mkdir(parents=True, exist_ok=True)
    mask_name = f"{name}-mask.png"
    mask.convert("RGB").save(input_dir / mask_name)
    job = prepare_crop_community(image, mask)
    crop_name, crop_mask = save_crop_pair(job, input_dir, name)
    return {
        "plate": image,
        "mask": mask,
        "job": job,
        "crop_name": crop_name,
        "crop_mask": crop_mask,
        "mask_name": mask_name,
        "opaque_ratio": mask_opaque_ratio(mask),
    }


def emit_examples(directory: Path) -> None:
    models = {
        "ckpt": "RealVisXL_V5.0_fp16.safetensors",
        "instant_cn": "instantid/diffusion_pytorch_model.safetensors",
        "instant_ip": "ip-adapter.bin",
    }
    directory.mkdir(parents=True, exist_ok=True)
    lin = instantid_inpaint_graph(
        models,
        "lin-chest-crop.png",
        "lin-chest-crop-mask.png",
        "lin-head-shoulder.png",
        LIN_POS,
        LIN_NEG,
        SAMPLER_SEED,
        "lin-chest",
        CLOTH_DENOISE,
    )
    elena = instantid_inpaint_graph(
        models,
        "elena-breastplate-crop.png",
        "elena-breastplate-crop-mask.png",
        "elena-head-shoulder.png",
        ELENA_POS,
        ELENA_NEG,
        SAMPLER_SEED + 1,
        "elena-breastplate",
        CLOTH_DENOISE,
    )
    (directory / "scheme-still-lin-qipao-undress.api.json").write_text(
        json.dumps(envelope(lin, "lin-chest"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (directory / "scheme-still-elena-armor-undress.api.json").write_text(
        json.dumps(envelope(elena, "elena-breastplate"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _upload(host: str, path: Path) -> None:
    subprocess.run(
        ["curl", "-sS", "-F", f"image=@{path}", "-F", "overwrite=true", f"{host.rstrip('/')}/upload/image"],
        check=True,
        capture_output=True,
        text=True,
    )


def _instantid_missed(exc: BaseException) -> bool:
    text = str(exc)
    return "No face detected" in text or "RUN_FAILED" in text


def run_region(
    host: str,
    models: dict[str, str],
    actor: str,
    plate: Image.Image,
    head_ref: Image.Image,
    region: RegionPass,
    seed: int,
    input_dir: Path,
    out_dir: Path,
    *,
    use_instantid: bool,
) -> Image.Image:
    clear = LIN_FACE_CLEAR if actor == "lin" else ELENA_FACE_CLEAR
    mask = box_mask(plate, region.box, clear_face=clear)
    if region.grow:
        mask = dilate_mask(mask, region.grow).filter(ImageFilter.GaussianBlur(radius=MASK_BLUR))
    prepared = prepare_job(region.stem, plate, mask, input_dir)
    ref_name = f"{actor}-head-shoulder.png"
    head_ref.save(input_dir / ref_name)
    for filename in (prepared["crop_name"], prepared["crop_mask"], ref_name):
        _upload(host, input_dir / filename)
    if use_instantid:
        graph = instantid_inpaint_graph(
            models,
            prepared["crop_name"],
            prepared["crop_mask"],
            ref_name,
            region.positive,
            region.negative,
            seed,
            region.stem,
            region.denoise,
        )
    else:
        graph = inpaint_crop_graph(
            ckpt=models["ckpt"],
            crop_name=prepared["crop_name"],
            mask_name=prepared["crop_mask"],
            positive=region.positive,
            negative=region.negative,
            seed=seed,
            prefix=region.stem,
            denoise=region.denoise,
        )
    (out_dir / f"{region.stem}.api.json").write_text(
        json.dumps(envelope(graph, region.stem), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    crop_out = out_dir / f"{region.stem}-crop.png"
    try:
        queue_prompt(host, graph, f"fox-{region.stem}", "22", crop_out, region.stem)
    except SystemExit as exc:
        if use_instantid and _instantid_missed(exc):
            print(f"INSTANTID_MISS {region.stem}; fallback plain inpaint", flush=True)
            return run_region(
                host,
                models,
                actor,
                plate,
                head_ref,
                region,
                seed,
                input_dir,
                out_dir,
                use_instantid=False,
            )
        raise
    stitched = stitch(prepared["plate"], Image.open(crop_out), prepared["job"])
    print(
        f"PASS {region.stem} denoise={region.denoise} opaque={prepared['opaque_ratio']:.3f} "
        f"instantid={use_instantid}",
        flush=True,
    )
    return stitched


def run_actor(
    host: str,
    models: dict[str, str],
    actor: str,
    plate_path: Path,
    head_box: tuple[int, int, int, int],
    regions: list[RegionPass],
    input_dir: Path,
    out_dir: Path,
    *,
    use_instantid: bool,
    seed_offset: int = 0,
) -> Path:
    plate = Image.open(plate_path).convert("RGB")
    head = head_shoulder_from_plate(plate, head_box)
    current = plate
    for i, region in enumerate(regions):
        # InstantID only on cloth passes; edge pass is plain low denoise.
        want_id = use_instantid and region.denoise >= 0.6
        current = run_region(
            host,
            models,
            actor,
            current,
            head,
            region,
            SAMPLER_SEED + seed_offset + i,
            input_dir,
            out_dir,
            use_instantid=want_id,
        )
    dest = out_dir / {
        "lin": "lin-qipao-nine-tail-nude.png",
        "elena": "elena-armor-centaur-nude.png",
    }[actor]
    current.save(dest)
    print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
    return dest


def _write_mask_previews(actor: str, plate: Image.Image, regions: list[RegionPass], clear: tuple[int, int, int, int], head_box: tuple[int, int, int, int], debug: Path) -> None:
    for region in regions:
        if region.denoise < 0.6:
            continue
        m = box_mask(plate, region.box, clear_face=clear)
        overlay = plate.convert("RGBA")
        tint = Image.new("RGBA", overlay.size, (220, 40, 40, 110))
        Image.composite(tint, overlay, m).save(debug / f"{region.stem}-overlay.png")
        m.convert("RGB").save(debug / f"{region.stem}-mask.png")
        print(f"MASK {region.stem} opaque={mask_opaque_ratio(m):.4f}", flush=True)
    head_shoulder_from_plate(plate, head_box).save(debug / f"{actor}-head-shoulder.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=STILL_DIR)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-undress-input"))
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--emit-examples", type=Path)
    parser.add_argument("--only", choices=("lin", "elena"), nargs="*")
    parser.add_argument("--no-instantid", action="store_true")
    args = parser.parse_args()
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return

    chosen = args.only or ["lin", "elena"]
    args.input.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    debug = Path("/tmp/fox-undress-preview/masks")
    debug.mkdir(parents=True, exist_ok=True)

    if "lin" in chosen:
        lin = Image.open(LIN_PLATE).convert("RGB")
        _write_mask_previews("lin", lin, lin_region_passes(), LIN_FACE_CLEAR, LIN_HEAD, debug)
    if "elena" in chosen:
        elena = Image.open(ELENA_PLATE).convert("RGB")
        _write_mask_previews("elena", elena, elena_region_passes(), ELENA_FACE_CLEAR, ELENA_HEAD, debug)

    if args.prepare_only:
        return

    models = resolve_base_models(args.host)
    print("MODELS", json.dumps(models, ensure_ascii=False), flush=True)
    print(
        f"SCHEDULE cloth={CLOTH_DENOISE} edge={EDGE_DENOISE} max_content={MAX_CONTENT_FRAC} "
        f"instantid={not args.no_instantid}",
        flush=True,
    )

    if "lin" in chosen:
        run_actor(
            args.host,
            models,
            "lin",
            LIN_PLATE,
            LIN_HEAD,
            lin_region_passes(),
            args.input,
            args.out,
            use_instantid=not args.no_instantid,
            seed_offset=0,
        )
    if "elena" in chosen:
        run_actor(
            args.host,
            models,
            "elena",
            ELENA_PLATE,
            ELENA_HEAD,
            elena_region_passes(),
            args.input,
            args.out,
            use_instantid=not args.no_instantid,
            seed_offset=10,
        )


if __name__ == "__main__":
    main()
