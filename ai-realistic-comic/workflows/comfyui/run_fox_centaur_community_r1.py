"""Community-aligned R1 undress plan (2026-10-09). Scaffold only — no power-on / no generate.

R1: SegFormer/DINO mask + CropAndStitch (<=1024) + Fooocus denoise 0.78-0.85
+ OpenPose (on-disk) + optional InstantID/FaceDetailer. No LaMa residual loop,
no pixelfill, not the retired whole-garment scheme A.
"""

from __future__ import annotations

import argparse
import json
import sys

PLAN = {
    "name": "community_r1_sdxl_crop_fooocus_openpose",
    "status": "scaffold_only",
    "supersedes": "wholebody_garment_A_paused",
    "denoise": [0.78, 0.85],
    "crop_max": 1024,
    "use_openpose": True,
    "use_instantid_face": True,
    "forbid": ["lama_residual_loop", "hip_pixelfill", "touch_0.35_only", "whole_body_single_hole_1.0"],
    "reuse_on_disk": [
        "RealVisXL_V5.0_fp16",
        "fooocus_inpaint_v26",
        "segformer_b2_clothes",
        "grounding_dino_sam",
        "openpose-sdxl-xinsir",
        "instantid",
        "Inpaint-CropAndStitch",
    ],
    "new_download_gb": "0-0.2",
    "cost_cny": {"pilot": "0.5-0.8", "four": "1.5-2.5", "cap": "4"},
    "sources": [
        "https://lewdly.ai/blog/comfyui-nsfw-inpainting-clothing-workflow",
        "https://civitai.com/models/967161/flux-or-sdxl-auto-clothes-inpainting",
        "https://github.com/lllyasviel/Fooocus/discussions/414",
        "https://github.com/acly/comfyui-inpaint-nodes",
    ],
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--i-know-authorized", action="store_true")
    args = parser.parse_args()
    print(json.dumps(PLAN, ensure_ascii=False, indent=2))
    if not args.i_know_authorized:
        print("R1_SCAFFOLD: no generate / no autodl power-on.", flush=True)
        raise SystemExit(0)
    print("R1_NOT_IMPLEMENTED: wait for user authorization to wire graph.", flush=True)
    raise SystemExit(2)


if __name__ == "__main__":
    main()
