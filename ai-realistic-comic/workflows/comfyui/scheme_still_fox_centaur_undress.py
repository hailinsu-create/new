"""Clothes-only crop-and-stitch for fox/centaur solos: nude or torn/shatter.

Community stack (not Scheme B full redraw):
- lquesada / comfyorg Crop-and-Stitch + InpaintModelConditioning
- clothing denoise 0.75–0.85; edge pass ~0.4
- small holes; downscale large crops (anti double-body)
- InstantID from plate head-shoulder (jaw-up ref-face often fails InsightFace)
- modes: nude (remove cloth/armor) | torn (shattered cloth/armor, skin shows)
- no ReActor; Beijing only; F34/G09 off

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

SAMPLER_SEED = 20261006
CLOTH_DENOISE = 0.85
TORN_DENOISE = 0.83
EDGE_DENOISE = 0.42
MASK_BLUR = 14
MAX_CONTENT_FRAC = 0.55

BJ_UUID = "359a49a1c3-4cda10df"
F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"

LIN_NUDE_POS = (
    "bare skin only, natural breasts, visible nipples, navel, skin tone matches the neck, "
    "same adult woman already in the photo, one person only, no second body, no extra arms"
)
LIN_NUDE_NEG = (
    "child, teen, extra person, second woman, extra face, extra head, clone, ghost, "
    "qipao, cheongsam, dress, clothes, embroidery, fabric pattern, ribbon, bra, panties, "
    "snake tail, extra limbs, extra arm, extra hand, smear, plastic, text, watermark"
)
ELENA_NUDE_POS = (
    "bare human torso skin only, natural breasts, visible nipples, skin tone matches the neck, "
    "brown eyes, round gold wire glasses, no metal, no armor, waist joins the bay mare body, "
    "one person only"
)
ELENA_NUDE_NEG = (
    "child, teen, extra person, extra face, armor, plate, gauntlet, gorget, pauldron, mail, "
    "clothes, bra, green eyes, blue-grey eyes, blue-gray eyes, pointed ears, stallion, "
    "extra legs, smear, plastic, text, watermark"
)

LIN_TORN_POS = (
    "heavily torn ripped qipao, jagged shredded silk edges, large irregular holes exposing "
    "bare breasts and belly skin, dangling fabric scraps, dress remnants still on hips and "
    "collar, same adult woman, one person only, fox tails untouched"
)
LIN_TORN_NEG = (
    "child, teen, extra person, fully nude, completely naked, missing dress entirely, "
    "snake tail, extra limbs, extra arm, clone, smear, plastic, text, watermark"
)
ELENA_TORN_POS = (
    "shattered cracked breastplate with jagged broken metal edges, large holes in armor, "
    "bare breasts and belly skin visible through wrecked plates, armor shards still on "
    "shoulders and waist, same adult woman, brown eyes, round gold wire glasses, "
    "waist still joins bay mare body, one person only, no extra arms"
)
ELENA_TORN_NEG = (
    "child, teen, extra person, fully nude, armor completely gone, green eyes, "
    "blue-grey eyes, blue-gray eyes, pointed ears, stallion, extra legs, smear, "
    "plastic, text, watermark"
)

EDGE_POS = "matching bare skin, seamless blend to surrounding skin, soft cloth or metal edge"
EDGE_NEG = "seam, hard edge, smear, blur, plastic, text, watermark, extra limbs"

CROP_STITCH = "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"
INSTANTID = "https://github.com/cubiq/ComfyUI_InstantID"
BASE = (1024, 1536)

LIN_HEAD = (340, 40, 600, 360)
# Face sits left-of-center on the armored plate; rightward boxes miss InsightFace.
ELENA_HEAD = (250, 20, 500, 300)
LIN_FACE_CLEAR = (300, 10, 620, 300)
ELENA_FACE_CLEAR = (240, 10, 520, 230)

OUT_STEM = {
    ("lin", "nude"): "lin-qipao-nine-tail-nude",
    ("lin", "torn"): "lin-qipao-nine-tail-torn",
    ("elena", "nude"): "elena-armor-centaur-nude",
    ("elena", "torn"): "elena-armor-centaur-torn",
}


@dataclass(frozen=True)
class RegionPass:
    stem: str
    box: tuple[int, int, int, int]
    denoise: float
    positive: str
    negative: str
    grow: int = 0
    ellipses: tuple[tuple[int, int, int, int], ...] = ()


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
    ellipses: tuple[tuple[int, int, int, int], ...] = (),
) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    if ellipses:
        for oval in ellipses:
            draw.ellipse(_scale_box(image.size, oval), fill=255)
    else:
        draw.rounded_rectangle(_scale_box(image.size, box), radius=18, fill=255)
    if clear_face is not None:
        draw.rounded_rectangle(_scale_box(image.size, clear_face), radius=20, fill=0)
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
    src = src.convert("RGB")
    canvas = Image.new("RGB", (size, size), (46, 42, 38))
    scale = min((size - 96) / max(src.width, 1), (size - 96) / max(src.height, 1))
    new_w = max(8, int(src.width * scale))
    new_h = max(8, int(src.height * scale))
    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2))
    return canvas


def lin_nude_passes() -> list[RegionPass]:
    # One torso hole + edge. Stacking InstantID chest/mid/skirt passes left sheer cloth and smear.
    return [
        RegionPass("lin-nude-torso", (330, 280, 560, 1260), CLOTH_DENOISE, LIN_NUDE_POS, LIN_NUDE_NEG),
        RegionPass("lin-nude-edge", (330, 280, 560, 1260), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=28),
    ]


def elena_nude_passes() -> list[RegionPass]:
    # Human torso + arms only; never stack four InstantID passes (spawned extra limbs).
    return [
        RegionPass("elena-nude-torso", (150, 220, 560, 720), CLOTH_DENOISE, ELENA_NUDE_POS, ELENA_NUDE_NEG),
        RegionPass("elena-nude-edge", (150, 220, 560, 720), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=24),
    ]


def lin_torn_passes() -> list[RegionPass]:
    # Few large jagged tears so Codex sees shredded cloth, not couture cutouts.
    return [
        RegionPass(
            "lin-torn-front",
            (340, 290, 560, 1100),
            TORN_DENOISE,
            LIN_TORN_POS,
            LIN_TORN_NEG,
            ellipses=(
                (350, 310, 520, 500),
                (360, 480, 540, 700),
                (350, 700, 500, 980),
            ),
        ),
        RegionPass("lin-torn-edge", (340, 290, 560, 1100), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=18),
    ]


def elena_torn_passes() -> list[RegionPass]:
    return [
        RegionPass(
            "elena-torn-front",
            (160, 220, 560, 700),
            TORN_DENOISE,
            ELENA_TORN_POS,
            ELENA_TORN_NEG,
            ellipses=(
                (300, 240, 520, 480),
                (170, 300, 310, 620),
                (320, 480, 540, 680),
            ),
        ),
        RegionPass("elena-torn-edge", (160, 220, 560, 700), EDGE_DENOISE, EDGE_POS, EDGE_NEG, grow=18),
    ]


def region_passes(actor: str, mode: str) -> list[RegionPass]:
    table = {
        ("lin", "nude"): lin_nude_passes,
        ("lin", "torn"): lin_torn_passes,
        ("elena", "nude"): elena_nude_passes,
        ("elena", "torn"): elena_torn_passes,
    }
    return table[(actor, mode)]()


# Back-compat aliases for older tests / callers.
def lin_region_passes() -> list[RegionPass]:
    return lin_nude_passes()


def elena_region_passes() -> list[RegionPass]:
    return elena_nude_passes()


def _union_masks(
    image: Image.Image,
    regions: list[RegionPass],
    clear_face: tuple[int, int, int, int],
) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    for region in regions:
        part = box_mask(image, region.box, clear_face=clear_face, ellipses=region.ellipses)
        mask = ImageChops.lighter(mask, part)
    return mask.filter(ImageFilter.GaussianBlur(radius=2))


def lin_clothes_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, [r for r in lin_nude_passes() if r.denoise >= 0.6], LIN_FACE_CLEAR)


def elena_clothes_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, [r for r in elena_nude_passes() if r.denoise >= 0.6], ELENA_FACE_CLEAR)


def lin_torn_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, [r for r in lin_torn_passes() if r.denoise >= 0.6], LIN_FACE_CLEAR)


def elena_torn_mask(image: Image.Image) -> Image.Image:
    return _union_masks(image, [r for r in elena_torn_passes() if r.denoise >= 0.6], ELENA_FACE_CLEAR)


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


def envelope(prompt: dict, stage: str, mode: str) -> dict:
    return {
        "source": {
            "inpaint": CROP_STITCH,
            "instantid": INSTANTID,
            "why": (
                "Small-hole clothes inpaint; nude or torn/shatter mode; "
                "denoise 0.75–0.85 + edge ~0.4; InstantID from plate head-shoulder."
            ),
            "stage": stage,
            "mode": mode,
            "sampler_seed": SAMPLER_SEED,
            "cloth_denoise": CLOTH_DENOISE,
            "torn_denoise": TORN_DENOISE,
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
    specs = [
        ("scheme-still-lin-qipao-undress.api.json", "lin", "nude", "lin-chest", LIN_NUDE_POS, LIN_NUDE_NEG),
        ("scheme-still-elena-armor-undress.api.json", "elena", "nude", "elena-breastplate", ELENA_NUDE_POS, ELENA_NUDE_NEG),
        ("scheme-still-lin-qipao-torn.api.json", "lin", "torn", "lin-torn-chest", LIN_TORN_POS, LIN_TORN_NEG),
        ("scheme-still-elena-armor-torn.api.json", "elena", "torn", "elena-torn-breastplate", ELENA_TORN_POS, ELENA_TORN_NEG),
    ]
    for filename, actor, mode, stage, pos, neg in specs:
        ref = f"{actor}-head-shoulder.png"
        crop = f"{stage}-crop.png"
        graph = instantid_inpaint_graph(
            models,
            crop,
            f"{stage}-crop-mask.png",
            ref,
            pos,
            neg,
            SAMPLER_SEED,
            stage,
            CLOTH_DENOISE if mode == "nude" else TORN_DENOISE,
        )
        (directory / filename).write_text(
            json.dumps(envelope(graph, stage, mode), ensure_ascii=False, indent=2),
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
    mode: str,
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
    mask = box_mask(plate, region.box, clear_face=clear, ellipses=region.ellipses)
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
        json.dumps(envelope(graph, region.stem, mode), ensure_ascii=False, indent=2),
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
                mode,
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
        f"PASS {region.stem} mode={mode} denoise={region.denoise} "
        f"opaque={prepared['opaque_ratio']:.3f} instantid={use_instantid}",
        flush=True,
    )
    return stitched


def run_actor_mode(
    host: str,
    models: dict[str, str],
    actor: str,
    mode: str,
    input_dir: Path,
    out_dir: Path,
    *,
    use_instantid: bool,
) -> Path:
    plate_path = LIN_PLATE if actor == "lin" else ELENA_PLATE
    head_box = LIN_HEAD if actor == "lin" else ELENA_HEAD
    regions = region_passes(actor, mode)
    seed_offset = {"lin": 0, "elena": 20}[actor] + {"nude": 0, "torn": 40}[mode]
    plate = Image.open(plate_path).convert("RGB")
    head = head_shoulder_from_plate(plate, head_box)
    current = plate
    for i, region in enumerate(regions):
        # Body undress: InstantID on stacked crops caused sheer cloth / extra limbs.
        # Keep InstantID off unless the caller forces it and this is a cloth pass.
        want_id = use_instantid and region.denoise >= 0.6
        current = run_region(
            host,
            models,
            actor,
            mode,
            current,
            head,
            region,
            SAMPLER_SEED + seed_offset + i,
            input_dir,
            out_dir,
            use_instantid=want_id,
        )
    dest = out_dir / f"{OUT_STEM[(actor, mode)]}.png"
    current.save(dest)
    print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
    return dest


def _write_mask_previews(actor: str, mode: str, debug: Path) -> None:
    plate_path = LIN_PLATE if actor == "lin" else ELENA_PLATE
    clear = LIN_FACE_CLEAR if actor == "lin" else ELENA_FACE_CLEAR
    head_box = LIN_HEAD if actor == "lin" else ELENA_HEAD
    plate = Image.open(plate_path).convert("RGB")
    for region in region_passes(actor, mode):
        if region.denoise < 0.6:
            continue
        m = box_mask(plate, region.box, clear_face=clear, ellipses=region.ellipses)
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
    parser.add_argument("--mode", choices=("nude", "torn", "both"), default="both")
    parser.add_argument("--no-instantid", action="store_true")
    args = parser.parse_args()
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return

    actors = args.only or ["lin", "elena"]
    modes = ["nude", "torn"] if args.mode == "both" else [args.mode]
    args.input.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    debug = Path("/tmp/fox-undress-preview/masks")
    debug.mkdir(parents=True, exist_ok=True)

    for actor in actors:
        for mode in modes:
            _write_mask_previews(actor, mode, debug)

    if args.prepare_only:
        return

    models = resolve_base_models(args.host)
    print("MODELS", json.dumps(models, ensure_ascii=False), flush=True)
    print(
        f"SCHEDULE cloth={CLOTH_DENOISE} torn={TORN_DENOISE} edge={EDGE_DENOISE} "
        f"max_content={MAX_CONTENT_FRAC} modes={modes} instantid={not args.no_instantid}",
        flush=True,
    )

    for actor in actors:
        for mode in modes:
            run_actor_mode(
                args.host,
                models,
                actor,
                mode,
                args.input,
                args.out,
                use_instantid=not args.no_instantid,
            )


if __name__ == "__main__":
    main()
