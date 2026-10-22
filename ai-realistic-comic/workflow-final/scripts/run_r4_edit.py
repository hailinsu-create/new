#!/usr/bin/env python3
"""R4: Qwen-Image-Edit-2511 FP8 + Lightning + remove/object LoRAs (raw before paste-back)."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_api as api  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", type=Path, default=ROOT / "assets" / "refs" / "lin_qipao_nine_tail.png")
    ap.add_argument(
        "--prompt-file",
        type=Path,
        default=ROOT / "prompts" / "r4_remove_clothes.txt",
        help="use prompts/r4_torn_edge.txt for torn-edge instead of full remove",
    )
    ap.add_argument("--prompt", default="", help="override prompt text")
    ap.add_argument("--negative", default="chrome armor, metal film, blurry, watermark, extra limbs")
    ap.add_argument("--seed", type=int, default=20261010)
    ap.add_argument("--host", default=os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188"))
    ap.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/out/r4-edit.png"))
    ap.add_argument("--remove-strength", type=float, default=0.95)
    ap.add_argument("--object-strength", type=float, default=0.75)
    args = ap.parse_args()

    api.wait_up(args.host, timeout_sec=60)
    wf = json.loads((ROOT / "workflows" / "r4_qwen_edit_2511.api.json").read_text(encoding="utf-8"))
    prompt = args.prompt.strip() or args.prompt_file.read_text(encoding="utf-8").strip()
    img = api.upload_image(args.host, args.image)
    load_id = api.find_node(wf, "LoadImage")
    save_id = api.find_node(wf, "SaveImage")
    ks = api.find_node(wf, "KSampler")
    wf[load_id]["inputs"]["image"] = img
    wf["11"]["inputs"]["prompt"] = prompt
    wf["12"]["inputs"]["prompt"] = args.negative
    wf["8"]["inputs"]["strength_model"] = args.remove_strength
    wf["9"]["inputs"]["strength_model"] = args.object_strength
    wf[ks]["inputs"]["seed"] = args.seed
    wf[save_id]["inputs"]["filename_prefix"] = "r4-edit"
    api.queue_prompt(args.host, wf, "wf-r4", save_id, args.out, "r4-edit")
    print(f"DONE {args.out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
