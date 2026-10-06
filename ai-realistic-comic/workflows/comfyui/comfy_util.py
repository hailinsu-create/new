"""Shared ComfyUI API helpers for the Beijing graphs."""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def post_json(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise SystemExit(f"PROMPT_REJECTED {exc.code} {body[:2000]}") from exc


def choices(host: str, node: str, key: str) -> list:
    data = get_json(f"{host}/object_info/{node}")
    info = data[node]["input"]
    spec = (info.get("required") or {}).get(key)
    if spec is None:
        spec = (info.get("optional") or {}).get(key)
    if not spec or not isinstance(spec[0], list):
        return []
    return spec[0]


def pick(items: list[str], needle: str) -> str:
    hits = [item for item in items if needle in item]
    if not hits:
        raise SystemExit(f"MODEL_MISSING {needle} in {items}")
    return hits[0]


def resolve_base_models(host: str) -> dict[str, str]:
    found = {
        "ckpt": pick(choices(host, "CheckpointLoaderSimple", "ckpt_name"), "RealVisXL_V5.0_fp16"),
        "instant_cn": pick(choices(host, "DiffControlNetLoader", "control_net_name"), "instantid/"),
        "pose_cn": pick(choices(host, "DiffControlNetLoader", "control_net_name"), "openpose-sdxl-xinsir/"),
        "instant_ip": pick(choices(host, "InstantIDModelLoader", "instantid_file"), "ip-adapter.bin"),
        "face_det": pick(choices(host, "UltralyticsDetectorProvider", "model_name"), "bbox/face_yolov8m"),
    }
    sams = choices(host, "SAMLoader", "model_name")
    if sams:
        found["sam"] = sams[0]
    return found


def wait_saved(host: str, prompt_id: str, node_id: str, dest: Path, tag: str) -> Path:
    deadline = time.time() + 1200
    while time.time() < deadline:
        history = get_json(f"{host}/history/{prompt_id}")
        item = history.get(prompt_id)
        if not item:
            time.sleep(5)
            continue
        status = item.get("status") or {}
        if status.get("status_str") == "error":
            raise SystemExit(f"RUN_FAILED {tag} {json.dumps(status)[:2000]}")
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
            dest.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(f"{host}/view?{query}", timeout=120) as response:
                dest.write_bytes(response.read())
            print(f"SAVED {tag} {dest} {dest.stat().st_size}", flush=True)
            return dest
        time.sleep(5)
    raise SystemExit(f"RUN_TIMEOUT {tag}")


def queue_prompt(host: str, prompt: dict, client_id: str, node_id: str, dest: Path, tag: str) -> Path:
    queued = post_json(f"{host}/prompt", {"prompt": prompt, "client_id": client_id})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise SystemExit(f"PROMPT_REJECTED {tag} {queued}")
    print(f"QUEUED {tag} {prompt_id}", flush=True)
    return wait_saved(host, prompt_id, node_id, dest, tag)


def face_detailer_node(
    image,
    model,
    positive,
    negative,
    detector,
    sam,
    denoise: float,
    seed: int,
    guide: float = 768,
) -> dict:
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
            "seed": seed,
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
