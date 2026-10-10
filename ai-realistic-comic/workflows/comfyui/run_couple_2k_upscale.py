#!/usr/bin/env python3
"""Upscale couple stills to ~2K long-edge via 4x-UltraSharp + ImageScale.

Content-preserving only: no edit / no denoise redraw. Official outs are *-2k.png.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comfy_util import choices, pick, queue_prompt  # noqa: E402

HOST = "http://127.0.0.1:8188"
TARGET_LONG = 2560
UPSCALE_NEEDLE = "4x-UltraSharp"


def target_size(w: int, h: int, long_edge: int = TARGET_LONG) -> tuple[int, int]:
    if w <= 0 or h <= 0:
        raise SystemExit(f"BAD_SIZE {w}x{h}")
    if max(w, h) == long_edge:
        return w, h
    if w >= h:
        return long_edge, max(1, int(round(h * (long_edge / w))))
    return max(1, int(round(w * (long_edge / h)))), long_edge


def build_graph(filename: str, model_name: str, width: int, height: int) -> dict:
    return {
        "1": {
            "class_type": "LoadImage",
            "inputs": {"image": filename},
        },
        "2": {
            "class_type": "UpscaleModelLoader",
            "inputs": {"model_name": model_name},
        },
        "3": {
            "class_type": "ImageUpscaleWithModel",
            "inputs": {"upscale_model": ["2", 0], "image": ["1", 0]},
        },
        "4": {
            "class_type": "ImageScale",
            "inputs": {
                "image": ["3", 0],
                "upscale_method": "lanczos",
                "width": width,
                "height": height,
                "crop": "disabled",
            },
        },
        "5": {
            "class_type": "SaveImage",
            "inputs": {"images": ["4", 0], "filename_prefix": "couple2k"},
        },
    }


def upload(path: Path) -> str:
    import subprocess

    proc = subprocess.run(
        [
            "curl",
            "-sS",
            "-F",
            f"image=@{path}",
            "-F",
            "overwrite=true",
            f"{HOST}/upload/image",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(f"UPLOAD_FAIL {path.name} {proc.stderr[:300]!r}")
    data = json.loads(proc.stdout)
    name = data.get("name") or path.name
    print(f"UPLOAD_OK {path.name} -> {name}", flush=True)
    return name


def upscale_one(src: Path, dest: Path, model_name: str) -> dict:
    im = Image.open(src)
    w, h = im.size
    tw, th = target_size(w, h)
    remote_name = upload(src)
    graph = build_graph(remote_name, model_name, tw, th)
    tmp = dest.with_suffix(".tmp.png")
    queue_prompt(HOST, graph, f"2k-{src.stem}", "5", tmp, src.stem)
    shutil.move(str(tmp), str(dest))
    out = Image.open(dest)
    meta = {
        "src": str(src),
        "dest": str(dest),
        "src_size": [w, h],
        "out_size": list(out.size),
        "target": [tw, th],
        "model": model_name,
        "bytes": dest.stat().st_size,
    }
    dest.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"UPSCALE_OK {src.name} {w}x{h} -> {out.size[0]}x{out.size[1]}", flush=True)
    return meta


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--inputs-json", type=Path, required=True, help="JSON list of {src, stem}")
    ap.add_argument("--i-know-authorized", action="store_true")
    args = ap.parse_args()
    if not args.i_know_authorized:
        raise SystemExit("NEED --i-know-authorized")
    args.out.mkdir(parents=True, exist_ok=True)
    items = json.loads(args.inputs_json.read_text(encoding="utf-8"))
    models = choices(HOST, "UpscaleModelLoader", "model_name")
    model_name = pick(models, UPSCALE_NEEDLE)
    print(f"UPSCALE_MODEL {model_name}", flush=True)
    results = []
    for item in items:
        src = Path(item["src"])
        stem = item["stem"]
        dest = args.out / f"{stem}-2k.png"
        if not src.is_file():
            raise SystemExit(f"MISSING {src}")
        meta = upscale_one(src, dest, model_name)
        results.append(meta)
        print(f"RAW_OK {dest.name}", flush=True)
    (args.out / "UPSCALE_2K_SUMMARY.json").write_text(
        json.dumps({"done": results, "target_long": TARGET_LONG}, indent=2) + "\n",
        encoding="utf-8",
    )
    print("COUPLE_2K_UPSCALE_DONE", flush=True)


if __name__ == "__main__":
    main()
