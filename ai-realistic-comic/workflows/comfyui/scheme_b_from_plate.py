"""Redraw nude turnaround plates from the clothed base plates.

Qwen undress seeds are not inputs. Front and side use InstantID for identity,
OpenPose from the clothed plate for the stance, then FaceDetailer with
IP-Adapter FaceID Plus v2. Back uses OpenPose only and does not receive a face.

Sources, adapted rather than pasted:
- FaceDetailer graph shape: https://github.com/ltdrdata/ComfyUI-Impact-Pack/blob/Main/example_workflows/1-FaceDetailer.json
- InstantID apply graph: https://github.com/cubiq/ComfyUI_InstantID
- FaceID Plus v2 preset: https://github.com/cubiq/ComfyUI_IPAdapter_plus
- DWPose / xinsir stick scaling: https://github.com/Fannovel16/comfyui_controlnet_aux
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SAMPLER_SEED = 20261006
WIDTH = 1024
HEIGHT = 1536

# SDXL CLIP is English. The clauses match the clothed-plate redo:
# full body, adult, actor look, nude result, plain background.
PROMPTS: dict[tuple[str, str], tuple[str, str]] = {
    ("lin_wantang", "front"): (
        "photorealistic full-body photo of an adult East Asian woman in her twenties, standing facing the camera, head and both feet in frame, plain gray background, black-brown hair loosely tied back, clean forehead, light makeup, natural lips, black-brown eyes, level eyes, nude, bare chest abdomen hips and legs, visible nipples, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, hair bun, hairpin, forehead ornament, heavy makeup, red lips, crooked eyes, asymmetrical eyes, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("lin_wantang", "side"): (
        "photorealistic full-body photo of an adult East Asian woman in her twenties, left side profile, standing, head and both feet in frame, plain gray background, black-brown hair loosely tied back, clean forehead, light makeup, natural lips, black-brown eyes, nude, bare chest abdomen hips and legs, visible nipples, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, hair bun, hairpin, forehead ornament, heavy makeup, red lips, front view, crooked eyes, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("lin_wantang", "back"): (
        "photorealistic full-body photo from behind of an adult East Asian woman in her twenties, standing, face not visible, head and both feet in frame, plain gray background, black-brown hair loosely tied back, nude back, bare hips and legs, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, hair bun, hairpin, face visible, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("gu_chengan", "front"): (
        "photorealistic full-body photo of an adult East Asian man in his twenties, standing facing the camera, both hands out of pockets, head and both feet in frame, plain gray background, short black-brown hair, light makeup, black-brown eyes, level eyes, nude, bare chest abdomen hips and legs, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, hair bun, wig, headband, heavy makeup, red lips, hands in pockets, crooked eyes, extra fingers, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("gu_chengan", "side"): (
        "photorealistic full-body photo of an adult East Asian man in his twenties, left side profile, standing, both hands out of pockets, head and both feet in frame, plain gray background, short black-brown hair, light makeup, black-brown eyes, nude, bare chest abdomen hips and legs, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, hair bun, wig, headband, heavy makeup, red lips, front view, hands in pockets, extra fingers, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("gu_chengan", "back"): (
        "photorealistic full-body photo from behind of an adult East Asian man in his twenties, standing, face not visible, both hands visible, head and both feet in frame, plain gray background, short black-brown hair, nude back, bare hips and legs, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, hair bun, wig, headband, face visible, hands in pockets, extra fingers, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("elena_voss", "front"): (
        "photorealistic full-body photo of an adult woman in her twenties, standing facing the camera, head and both feet in frame, plain gray background, soft brown wavy hair loosely pulled back, blue-grey eyes, human ears, no glasses, level eyes, nude, bare chest abdomen hips and legs, visible nipples, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, pointed ears, elf ears, green eyes, auburn hair, amber eyes, glasses, crooked eyes, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("elena_voss", "side"): (
        "photorealistic full-body photo of an adult woman in her twenties, left side profile, standing, head and both feet in frame, plain gray background, soft brown wavy hair loosely pulled back, blue-grey eyes, human ears, no glasses, nude, bare chest abdomen hips and legs, visible nipples, visible navel, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, pointed ears, green eyes, auburn hair, glasses, front view, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
    ("elena_voss", "back"): (
        "photorealistic full-body photo from behind of an adult woman in her twenties, standing, face not visible, head and both feet in frame, plain gray background, soft brown wavy hair loosely pulled back, human ears, nude back, bare hips and legs, realistic skin, both feet fully inside the frame, bare hips and legs with no cloth, nothing tied around the neck, no bow, no string on the skin",
        "child, teen, clothes, shirt, shorts, underwear, bodysuit, hip seam, pointed ears, glasses, face visible, extra limbs, cropped head, cropped feet, plastic skin, skirt, towel, wrap, sarong, draped cloth, halter, straps, ribbon, bow, choker, necklace, string, cord, neck strap, black strap, bikini, bra, sandals, shoes, heels, text, watermark",
    ),
}

JOBS = [
    ("lin_wantang", "front"),
    ("lin_wantang", "side"),
    ("lin_wantang", "back"),
    ("gu_chengan", "front"),
    ("gu_chengan", "side"),
    ("gu_chengan", "back"),
    ("elena_voss", "front"),
    ("elena_voss", "side"),
    ("elena_voss", "back"),
]


def _get(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def _choices(host: str, node: str, key: str) -> list:
    data = _get(f"{host}/object_info/{node}")
    info = data[node]["input"]
    spec = (info.get("required") or {}).get(key)
    if spec is None:
        spec = (info.get("optional") or {}).get(key)
    if not spec or not isinstance(spec[0], list):
        return []
    return spec[0]


def _pick(choices: list[str], needle: str) -> str:
    hits = [item for item in choices if needle in item]
    if not hits:
        raise SystemExit(f"MODEL_MISSING {needle} in {choices}")
    return hits[0]


def resolve_models(host: str) -> dict[str, str]:
    checkpoints = _choices(host, "CheckpointLoaderSimple", "ckpt_name")
    controlnets = _choices(host, "DiffControlNetLoader", "control_net_name")
    instant = _choices(host, "InstantIDModelLoader", "instantid_file")
    detectors = _choices(host, "UltralyticsDetectorProvider", "model_name")
    sams = _choices(host, "SAMLoader", "model_name")
    found = {
        "ckpt": _pick(checkpoints, "RealVisXL_V5.0_fp16"),
        "instant_cn": _pick(controlnets, "instantid/"),
        "pose_cn": _pick(controlnets, "openpose-sdxl-xinsir/"),
        "instant_ip": _pick(instant, "ip-adapter.bin"),
        "face_det": _pick(detectors, "bbox/face_yolov8m"),
    }
    eyes = [item for item in detectors if "Eyes" in item or "eye" in item.lower()]
    if eyes:
        found["eye_det"] = eyes[0]
    if sams:
        found["sam"] = sams[0]
    return found


def _detailer(image, model, positive, negative, detector, sam, denoise: float, guide: float) -> dict:
    node = {
        "class_type": "FaceDetailer",
        "inputs": {
            "image": image,
            "model": model,
            "clip": ["3", 1],
            "vae": ["3", 2],
            "guide_size": guide,
            "guide_size_for": True,
            "max_size": 1280,
            "seed": SAMPLER_SEED,
            "steps": 16,
            "cfg": 4.5,
            "sampler_name": "dpmpp_2m",
            "scheduler": "karras",
            "positive": positive,
            "negative": negative,
            "denoise": denoise,
            "feather": 5,
            "noise_mask": True,
            "force_inpaint": True,
            "bbox_threshold": 0.5,
            "bbox_dilation": 10,
            "bbox_crop_factor": 3.0,
            "sam_detection_hint": "center-1",
            "sam_dilation": 0,
            "sam_threshold": 0.93,
            "sam_bbox_expansion": 0,
            "sam_mask_hint_threshold": 0.7,
            "sam_mask_hint_use_negative": "False",
            "drop_size": 10,
            "bbox_detector": detector,
            "wildcard": "",
            "cycle": 1,
        },
    }
    if sam is not None:
        node["inputs"]["sam_model_opt"] = sam
    return node


def build(actor: str, view: str, models: dict[str, str]) -> dict:
    positive, negative = PROMPTS[(actor, view)]
    pose = f"{actor}-{view}-clothed.png"
    ref = f"{actor}-ref.png"
    prompt: dict = {
        "3": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": models["ckpt"]},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": positive, "clip": ["3", 1]},
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": negative, "clip": ["3", 1]},
        },
        "1": {"class_type": "LoadImage", "inputs": {"image": pose}},
        "11": {
            "class_type": "DiffControlNetLoader",
            "inputs": {"model": ["3", 0], "control_net_name": models["pose_cn"]},
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
        "30": {
            "class_type": "ImageScaleBy",
            "inputs": {"image": ["12", 0], "upscale_method": "nearest-exact", "scale_by": 0.86},
        },
        "31": {
            "class_type": "EmptyImage",
            "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1, "color": 0},
        },
        "32": {
            "class_type": "ImageCompositeMasked",
            "inputs": {
                "destination": ["31", 0],
                "source": ["30", 0],
                "x": 72,
                "y": 40,
                "resize_source": False,
            },
        },
        "14": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1},
        },
    }
    if view == "back":
        prompt["13"] = {
            "class_type": "ControlNetApplyAdvanced",
            "inputs": {
                "positive": ["4", 0],
                "negative": ["5", 0],
                "control_net": ["11", 0],
                "image": ["32", 0],
                "strength": 0.95,
                "start_percent": 0.0,
                "end_percent": 1.0,
            },
        }
        prompt["15"] = {
            "class_type": "KSampler",
            "inputs": {
                "model": ["3", 0],
                "seed": SAMPLER_SEED,
                "steps": 26,
                "cfg": 4.0,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["13", 0],
                "negative": ["13", 1],
                "latent_image": ["14", 0],
                "denoise": 1.0,
            },
        }
        prompt["16"] = {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["15", 0], "vae": ["3", 2]},
        }
        save_from = ["16", 0]
    else:
        prompt["2"] = {"class_type": "LoadImage", "inputs": {"image": ref}}
        prompt["6"] = {
            "class_type": "InstantIDModelLoader",
            "inputs": {"instantid_file": models["instant_ip"]},
        }
        prompt["7"] = {
            "class_type": "InstantIDFaceAnalysis",
            "inputs": {"provider": "CPU"},
        }
        prompt["8"] = {
            "class_type": "DiffControlNetLoader",
            "inputs": {"model": ["3", 0], "control_net_name": models["instant_cn"]},
        }
        prompt["9"] = {
            "class_type": "FaceKeypointsPreprocessor",
            "inputs": {"faceanalysis": ["7", 0], "image": ["1", 0]},
        }
        prompt["33"] = {
            "class_type": "ImageScaleBy",
            "inputs": {"image": ["9", 0], "upscale_method": "nearest-exact", "scale_by": 0.86},
        }
        prompt["34"] = {
            "class_type": "ImageCompositeMasked",
            "inputs": {
                "destination": ["31", 0],
                "source": ["33", 0],
                "x": 72,
                "y": 40,
                "resize_source": False,
            },
        }
        prompt["10"] = {
            "class_type": "ApplyInstantID",
            "inputs": {
                "instantid": ["6", 0],
                "insightface": ["7", 0],
                "control_net": ["8", 0],
                "image": ["2", 0],
                "model": ["3", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "weight": 0.8,
                "start_at": 0.0,
                "end_at": 1.0,
                "image_kps": ["34", 0],
            },
        }
        prompt["13"] = {
            "class_type": "ControlNetApplyAdvanced",
            "inputs": {
                "positive": ["10", 1],
                "negative": ["10", 2],
                "control_net": ["11", 0],
                "image": ["32", 0],
                "strength": 0.95,
                "start_percent": 0.0,
                "end_percent": 1.0,
            },
        }
        prompt["15"] = {
            "class_type": "KSampler",
            "inputs": {
                "model": ["10", 0],
                "seed": SAMPLER_SEED,
                "steps": 26,
                "cfg": 4.0,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["13", 0],
                "negative": ["13", 1],
                "latent_image": ["14", 0],
                "denoise": 1.0,
            },
        }
        prompt["16"] = {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["15", 0], "vae": ["3", 2]},
        }
        prompt["17"] = {
            "class_type": "IPAdapterUnifiedLoaderFaceID",
            "inputs": {
                "model": ["3", 0],
                "preset": "FACEID PLUS V2",
                "lora_strength": 0.6,
                "provider": "CPU",
            },
        }
        prompt["18"] = {
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
        }
        prompt["19"] = {
            "class_type": "UltralyticsDetectorProvider",
            "inputs": {"model_name": models["face_det"]},
        }
        sam = None
        if "sam" in models:
            prompt["20"] = {
                "class_type": "SAMLoader",
                "inputs": {"model_name": models["sam"], "device_mode": "AUTO"},
            }
            sam = ["20", 0]
        prompt["21"] = _detailer(
            ["16", 0], ["18", 0], ["4", 0], ["5", 0], ["19", 0], sam, 0.40, 768
        )
        save_from = ["21", 0]
        if "eye_det" in models:
            prompt["23"] = {
                "class_type": "UltralyticsDetectorProvider",
                "inputs": {"model_name": models["eye_det"]},
            }
            prompt["24"] = _detailer(
                ["21", 0], ["18", 0], ["4", 0], ["5", 0], ["23", 0], sam, 0.28, 512
            )
            save_from = ["24", 0]
    prompt["22"] = {
        "class_type": "SaveImage",
        "inputs": {"images": save_from, "filename_prefix": f"cast-{actor}-{view}"},
    }
    return prompt


def envelope(actor: str, view: str, prompt: dict) -> dict:
    return {
        "source": {
            "facedetailer": "https://github.com/ltdrdata/ComfyUI-Impact-Pack/blob/Main/example_workflows/1-FaceDetailer.json",
            "instantid": "https://github.com/cubiq/ComfyUI_InstantID",
            "ipadapter_faceid": "https://github.com/cubiq/ComfyUI_IPAdapter_plus",
            "openpose_pre": "https://github.com/Fannovel16/comfyui_controlnet_aux",
            "why": "Clothed plate supplies the pose. The face lock supplies identity. Nude is in the prompt and the photoreal checkpoint, not in a Qwen edit.",
            "actor": actor,
            "view": view,
            "sampler_seed": SAMPLER_SEED,
        },
        "prompt": prompt,
    }


def _post(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise SystemExit(f"PROMPT_REJECTED {exc.code} {body[:2000]}") from exc


def _wait_saved(host: str, prompt_id: str, node_id: str, dest: Path, actor: str, view: str) -> Path:
    deadline = time.time() + 1200
    while time.time() < deadline:
        history = _get(f"{host}/history/{prompt_id}")
        item = history.get(prompt_id)
        if not item:
            time.sleep(5)
            continue
        status = item.get("status") or {}
        if status.get("status_str") == "error":
            raise SystemExit(f"RUN_FAILED {actor} {view} {json.dumps(status)[:2000]}")
        images = ((item.get("outputs") or {}).get(node_id) or {}).get("images") or []
        if images and status.get("completed"):
            image = images[0]
            query = urllib.parse.urlencode(
                {
                    "filename": image["filename"],
                    "subfolder": image.get("subfolder") or "",
                    "type": image.get("type") or "output",
                }
            )
            with urllib.request.urlopen(f"{host}/view?{query}", timeout=120) as response:
                dest.write_bytes(response.read())
            print(f"SAVED {dest} {dest.stat().st_size}", flush=True)
            return dest
        time.sleep(5)
    raise SystemExit(f"RUN_TIMEOUT {actor} {view}")


def _chest_positive(actor: str) -> str:
    if actor == "gu_chengan":
        return "photorealistic bare chest of an adult man, bare skin, no clothing"
    return "photorealistic bare chest of an adult woman, natural breasts, nipples, bare skin, no clothing"


def clear_torso_cloth(host: str, actor: str, view: str, image_path: Path, input_dir: Path) -> Path:
    """RealVisXL draws a black ribbon when the figure is scaled to keep the feet.

    A solid sternum inpaint removes that ribbon. Back views are skipped so a
    ponytail is not treated as cloth. A dark pixel counts only when skin sits
    on both sides, so hair against the gray background is not a ribbon. A
    light wrap is left for the scorer. The box is capped so it cannot cover
    an arm or the hips.
    """
    if view == "back":
        print(f"CLEAN_SKIP {actor} {view} back", flush=True)
        return image_path
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    src = Image.open(image_path).convert("RGB")
    arr = np.asarray(src)
    height, width = arr.shape[:2]
    y0, y1 = int(0.155 * height), int(0.42 * height)
    x0, x1 = int(0.32 * width), int(0.68 * width)
    region = arr[y0:y1, x0:x1]
    dark = region.max(axis=2) < 48
    ys, xs = np.nonzero(dark)
    if len(xs) == 0:
        print(f"CLEAN_SKIP {actor} {view} dark=0", flush=True)
        return image_path
    abs_y = ys + y0
    abs_x = xs + x0
    left_x = abs_x - 22
    right_x = abs_x + 22
    inside = (left_x >= 0) & (right_x < width)
    left_px = arr[abs_y[inside], left_x[inside]]
    right_px = arr[abs_y[inside], right_x[inside]]

    def _skin(px: np.ndarray) -> np.ndarray:
        red = px[:, 0].astype(np.int16)
        blue = px[:, 2].astype(np.int16)
        peak = px.max(axis=1).astype(np.int16)
        return (red > 130) & (red > blue + 15) & (peak > 80)

    kept = _skin(left_px) & _skin(right_px)
    count = int(kept.sum())
    if count < 120:
        print(f"CLEAN_SKIP {actor} {view} ribbon={count}", flush=True)
        return image_path
    keep_y = abs_y[inside][kept]
    keep_x = abs_x[inside][kept]
    left = max(0, int(keep_x.min()) - 28)
    right = min(width - 1, int(keep_x.max()) + 28)
    top = max(int(0.15 * height), int(keep_y.min()) - 24)
    bottom = min(int(0.42 * height), int(keep_y.max()) + 36)
    if right - left > 340 or bottom - top > 380:
        print(f"CLEAN_SKIP {actor} {view} box={left},{top},{right},{bottom}", flush=True)
        return image_path
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((left, top, right, bottom), radius=20, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=8))
    rgba = src.convert("RGBA")
    rgba.putalpha(Image.fromarray(255 - np.asarray(mask)).convert("L"))
    name = f"{actor}-{view}-chest.png"
    input_dir.mkdir(parents=True, exist_ok=True)
    rgba.save(input_dir / name)
    print(f"CLEAN {actor} {view} dark={count} box={left},{top},{right},{bottom}", flush=True)
    prompt = {
        "3": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": "RealVisXL_V5.0_fp16.safetensors"},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": _chest_positive(actor), "clip": ["3", 1]},
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": "ribbon, bow, strap, bandeau, bra, cloth, fabric, string, necklace, jewelry, scar, veins, text, watermark",
                "clip": ["3", 1],
            },
        },
        "1": {"class_type": "LoadImage", "inputs": {"image": name}},
        "41": {"class_type": "VAEEncode", "inputs": {"pixels": ["1", 0], "vae": ["3", 2]}},
        "42": {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["41", 0], "mask": ["1", 1]}},
        "15": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["3", 0],
                "seed": SAMPLER_SEED + 3,
                "steps": 20,
                "cfg": 4.5,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["42", 0],
                "denoise": 1.0,
            },
        },
        "16": {"class_type": "VAEDecode", "inputs": {"samples": ["15", 0], "vae": ["3", 2]}},
        "22": {
            "class_type": "SaveImage",
            "inputs": {"images": ["16", 0], "filename_prefix": f"cast-{actor}-{view}-chest"},
        },
    }
    queued = _post(f"{host}/prompt", {"prompt": prompt, "client_id": f"cast-chest-{actor}-{view}"})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise SystemExit(f"PROMPT_REJECTED {queued}")
    return _wait_saved(host, prompt_id, "22", image_path, actor, view)


def run_one(
    host: str,
    actor: str,
    view: str,
    models: dict[str, str],
    out_dir: Path,
    input_dir: Path,
) -> Path:
    prompt = build(actor, view, models)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{actor}-{view}.api.json").write_text(
        json.dumps(envelope(actor, view, prompt), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    queued = _post(f"{host}/prompt", {"prompt": prompt, "client_id": f"cast-{actor}-{view}"})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise SystemExit(f"PROMPT_REJECTED {queued}")
    print(f"QUEUED {actor} {view} {prompt_id}", flush=True)
    dest = out_dir / f"{actor}-{view}.png"
    _wait_saved(host, prompt_id, "22", dest, actor, view)
    return clear_torso_cloth(host, actor, view, dest, input_dir)


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
    for actor, view in (("lin_wantang", "front"), ("lin_wantang", "back")):
        payload = envelope(actor, view, build(actor, view, models))
        name = "scheme-b-front-side.api.json" if view == "front" else "scheme-b-back.api.json"
        (directory / name).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(directory / name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/comfy-runs"))
    parser.add_argument("--input", type=Path, default=Path("/root/autodl-tmp/comfyui/input"))
    parser.add_argument("--only", nargs=2, metavar=("ACTOR", "VIEW"))
    parser.add_argument("--emit-examples", type=Path)
    args = parser.parse_args()
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return
    models = resolve_models(args.host)
    print("MODELS", json.dumps(models, ensure_ascii=False), flush=True)
    jobs = [tuple(args.only)] if args.only else JOBS
    for actor, view in jobs:
        run_one(args.host, actor, view, models, args.out, args.input)


if __name__ == "__main__":
    main()
