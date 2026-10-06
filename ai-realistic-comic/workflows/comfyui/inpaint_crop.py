"""Crop-and-stitch inpaint for a regular SDXL checkpoint.

Community practice (lquesada / comfyorg Crop-and-Stitch, plus InpaintModelConditioning):
work at about 1024, denoise 0.65–0.85, blur the mask 8–15px, and never VAE the
unmasked pixels. Beijing stacks RealVisXL with Acly Fooocus inpaint head/patch
(`INPAINT_LoadFooocusInpaint` + `INPAINT_ApplyFooocusInpaint`) and core
`DifferentialDiffusion` so fabric/armor priors do not stick at mid denoise.
Still uses InpaintModelConditioning + noise_mask — never SetLatentNoiseMask at
denoise 1.0 on the full frame.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

INPAINT_DENOISE = 0.75
INPAINT_STEPS = 22
INPAINT_CFG = 4.5
TARGET = 1024
CONTEXT = 72
MASK_BLUR = 12
INPAINT_NODE = "InpaintModelConditioning"
FOOOCUS_HEAD = "fooocus_inpaint_head.pth"
FOOOCUS_PATCH = "inpaint_v26.fooocus.patch"
FOOOCUS_LOAD = "INPAINT_LoadFooocusInpaint"
FOOOCUS_APPLY = "INPAINT_ApplyFooocusInpaint"
DIFF_DIFFUSION = "DifferentialDiffusion"


class CropJob:
    def __init__(
        self,
        canvas: Image.Image,
        canvas_mask: Image.Image,
        orig_box: tuple[int, int, int, int],
        inner: tuple[int, int, int, int],
        full_mask: Image.Image,
    ) -> None:
        self.canvas = canvas
        self.canvas_mask = canvas_mask
        self.orig_box = orig_box
        self.inner = inner
        self.full_mask = full_mask


def pixel_box(size: tuple[int, int], frac: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    width, height = size
    x0, y0, x1, y1 = frac
    return (
        int(round(x0 * width)),
        int(round(y0 * height)),
        int(round(x1 * width)),
        int(round(y1 * height)),
    )


def prepare_crop(image: Image.Image, mask: Image.Image, context: int = CONTEXT, target: int = TARGET) -> CropJob:
    mask_l = mask.convert("L")
    binary = mask_l.point(lambda pixel: 255 if pixel > 12 else 0)
    bbox = binary.getbbox()
    if bbox is None:
        raise ValueError("empty inpaint mask")
    left, top, right, bottom = bbox
    left = max(0, left - context)
    top = max(0, top - context)
    right = min(image.width, right + context)
    bottom = min(image.height, bottom + context)
    crop = image.crop((left, top, right, bottom))
    crop_mask = mask_l.crop((left, top, right, bottom))
    width, height = crop.size
    scale = min((target - 16) / width, (target - 16) / height)
    new_w = max(16, int(width * scale) // 8 * 8)
    new_h = max(16, int(height * scale) // 8 * 8)
    resized = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)
    resized_mask = crop_mask.resize((new_w, new_h), Image.Resampling.BILINEAR)
    canvas = Image.new("RGB", (target, target), (12, 12, 16))
    canvas_mask = Image.new("L", (target, target), 0)
    pad_x = (target - new_w) // 2
    pad_y = (target - new_h) // 2
    canvas.paste(resized, (pad_x, pad_y))
    canvas_mask.paste(resized_mask, (pad_x, pad_y))
    return CropJob(
        canvas=canvas,
        canvas_mask=canvas_mask,
        orig_box=(left, top, right, bottom),
        inner=(pad_x, pad_y, pad_x + new_w, pad_y + new_h),
        full_mask=mask_l,
    )


def stitch(original: Image.Image, inpainted: Image.Image, job: CropJob) -> Image.Image:
    inner = inpainted.convert("RGB").crop(job.inner)
    dest_w = job.orig_box[2] - job.orig_box[0]
    dest_h = job.orig_box[3] - job.orig_box[1]
    pasted = inner.resize((dest_w, dest_h), Image.Resampling.LANCZOS)
    region_mask = job.full_mask.crop(job.orig_box)
    out = original.convert("RGB").copy()
    out.paste(pasted, (job.orig_box[0], job.orig_box[1]), region_mask)
    return out


def inpaint_crop_graph(
    ckpt: str,
    crop_name: str,
    mask_name: str,
    positive: str,
    negative: str,
    seed: int,
    prefix: str,
    denoise: float = INPAINT_DENOISE,
    *,
    fooocus: bool = True,
    differential: bool = True,
    fooocus_head: str = FOOOCUS_HEAD,
    fooocus_patch: str = FOOOCUS_PATCH,
) -> dict:
    """API graph: 1024 crop + IMC (+ Fooocus patch + DifferentialDiffusion)."""
    graph: dict = {
        "3": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": positive, "clip": ["3", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["3", 1]}},
        "1": {"class_type": "LoadImage", "inputs": {"image": crop_name}},
        "2": {"class_type": "LoadImage", "inputs": {"image": mask_name}},
        "50": {"class_type": "ImageToMask", "inputs": {"image": ["2", 0], "channel": "red"}},
        "40": {
            "class_type": INPAINT_NODE,
            "inputs": {
                "positive": ["4", 0],
                "negative": ["5", 0],
                "vae": ["3", 2],
                "pixels": ["1", 0],
                "mask": ["50", 0],
                "noise_mask": True,
            },
        },
        "15": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["3", 0],
                "seed": seed,
                "steps": INPAINT_STEPS,
                "cfg": INPAINT_CFG,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["40", 0],
                "negative": ["40", 1],
                "latent_image": ["40", 2],
                "denoise": denoise,
            },
        },
        "16": {"class_type": "VAEDecode", "inputs": {"samples": ["15", 0], "vae": ["3", 2]}},
        "22": {"class_type": "SaveImage", "inputs": {"images": ["16", 0], "filename_prefix": prefix}},
    }
    model_src: list = ["3", 0]
    if fooocus:
        graph["70"] = {
            "class_type": FOOOCUS_LOAD,
            "inputs": {"head": fooocus_head, "patch": fooocus_patch},
        }
        graph["71"] = {
            "class_type": FOOOCUS_APPLY,
            "inputs": {"model": model_src, "patch": ["70", 0], "latent": ["40", 2]},
        }
        model_src = ["71", 0]
    if differential:
        graph["72"] = {
            "class_type": DIFF_DIFFUSION,
            "inputs": {"model": model_src, "strength": 1.0},
        }
        model_src = ["72", 0]
    graph["15"]["inputs"]["model"] = model_src
    return graph


def save_crop_pair(job: CropJob, input_dir: Path, stem: str) -> tuple[str, str]:
    input_dir.mkdir(parents=True, exist_ok=True)
    rgb_name = f"{stem}-crop.png"
    mask_name = f"{stem}-crop-mask.png"
    job.canvas.save(input_dir / rgb_name)
    job.canvas_mask.convert("RGB").save(input_dir / mask_name)
    return rgb_name, mask_name
