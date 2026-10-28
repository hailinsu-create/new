#!/usr/bin/env python3
"""Offline crop preview: square looklock (e.g. 1024²) → Wan I2V 480×832 cover crop.

Helps answer: will the right paw / forearm stay inside the vertical frame?
Exit 0 always after writing the preview (unless input decode fails → exit 1).
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Center/cover crop a looklock still to 480x832 and note hand visibility risk."
    )
    parser.add_argument("input", type=Path, help="looklock PNG/JPG (often 1024x1024)")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="output preview path (default: <input stem>_i2v_480x832_crop.png)",
    )
    parser.add_argument("--width", type=int, default=480)
    parser.add_argument("--height", type=int, default=832)
    args = parser.parse_args(argv)

    if not args.input.is_file():
        print(f"[crop_check][ERROR] missing input: {args.input}", file=sys.stderr)
        return 1
    if not shutil.which("ffmpeg"):
        print("[crop_check][ERROR] ffmpeg required", file=sys.stderr)
        return 1

    out = args.output or args.input.with_name(f"{args.input.stem}_i2v_{args.width}x{args.height}_crop.png")
    # cover-crop then scale (matches typical center crop into taller aspect)
    vf = (
        f"scale={args.width}:{args.height}:force_original_aspect_ratio=increase,"
        f"crop={args.width}:{args.height}"
    )
    cmd = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-y",
        "-i",
        str(args.input),
        "-vf",
        vf,
        "-frames:v",
        "1",
        str(out),
    ]
    result = subprocess.run(cmd, capture_output=True, check=False)
    if result.returncode != 0:
        print(result.stderr.decode("utf-8", "replace"), file=sys.stderr)
        return 1

    print(f"[crop_check] wrote {out} ({args.width}x{args.height} cover crop)")
    print(
        "[crop_check] 人工核对：右手/前臂/肩是否在画内？"
        "若手被裁掉 → 本轮改跑 R4 抬头+围巾，勿指望敬礼。"
    )
    print(
        "[crop_check] 说明：1024²→480×832 会裁掉左右约 40% 宽度；"
        "详见 README-PIPELINE「looklock→I2V 构图」。"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
