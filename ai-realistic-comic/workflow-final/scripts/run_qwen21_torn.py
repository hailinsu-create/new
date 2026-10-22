#!/usr/bin/env python3
"""Qwen-Image 2.1 int8 edit + NSFW LoRA torn-edge (seven-element long prompt)."""
from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_api as api  # noqa: E402

DEFAULT_LORA = "thesealpacas-nsfw-v2.safetensors"
DEFAULT_STRENGTH = 0.8


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", type=Path, default=ROOT / "assets" / "refs" / "lin_qipao_nine_tail.png")
    ap.add_argument("--prompt-file", type=Path, default=ROOT / "prompts" / "torn_long7_qwen21.txt")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--negative", default="")
    ap.add_argument("--lora", default=DEFAULT_LORA)
    ap.add_argument("--lora-strength", type=float, default=DEFAULT_STRENGTH)
    ap.add_argument("--no-lora", action="store_true")
    ap.add_argument("--seed", type=int, default=20261015)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--cfg", type=float, default=1.0)
    ap.add_argument("--resolution", type=int, default=1024)
    ap.add_argument("--host", default=os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188"))
    ap.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/out/qwen21-torn.png"))
    args = ap.parse_args()

    api.wait_up(args.host, timeout_sec=60)
    wf = copy.deepcopy(json.loads((ROOT / "workflows" / "qwen21_edit.api.json").read_text(encoding="utf-8")))
    prompt = args.prompt.strip() or args.prompt_file.read_text(encoding="utf-8").strip()
    img = api.upload_image(args.host, args.image)
    load_id = api.find_node(wf, "LoadImage")
    text_id = api.find_node(wf, "TextEncodeQwenImage21")
    ks = api.find_node(wf, "KSampler")
    save_id = api.find_node(wf, "SaveImage")
    wf[load_id]["inputs"]["image"] = img
    wf[text_id]["inputs"]["prompt"] = prompt
    wf[text_id]["inputs"]["negative_prompt"] = args.negative
    wf[text_id]["inputs"]["resolution"] = args.resolution
    wf[ks]["inputs"]["seed"] = args.seed
    wf[ks]["inputs"]["steps"] = args.steps
    wf[ks]["inputs"]["cfg"] = args.cfg
    wf[save_id]["inputs"]["filename_prefix"] = "qwen21-torn"
    if not args.no_lora:
        api.inject_lora_model_only(wf, args.lora, args.lora_strength)
    api.queue_prompt(args.host, wf, "wf-q21", save_id, args.out, "qwen21-torn")
    print(f"DONE {args.out} lora={None if args.no_lora else args.lora}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
