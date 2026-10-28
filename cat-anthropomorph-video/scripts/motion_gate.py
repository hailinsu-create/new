#!/usr/bin/env python3
"""Motion gate for Wan I2V clips: grayscale MAD max vs frame 0.

Rejects nearly-static clips. Negative calibration from looklock→I2V fp16
nearly-static smoke: baseline max MAD ≈ 3.6 → require max MAD ≥ 11.0 by default
(≈3× baseline) unless overridden.

Exit codes:
  0  enough motion (PASS)
  1  usage / decode / input error
  2  motion below threshold (FAIL)
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VIDEO_EXTS = {".mp4", ".webm", ".mov", ".mkv", ".avi", ".gif"}
IMAGE_EXTS = {".pgm", ".ppm", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
# Baseline nearly-static clip MAD≈3.6; require clear motion above that band.
DEFAULT_MIN_MAX_MAD = 11.0
BASELINE_STATIC_MAD = 3.6
SCALE_WIDTH = 256


class GateError(RuntimeError):
    pass


def read_pgm(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(b"P5"):
        raise GateError(f"not a P5 PGM file: {path}")
    parts: list[bytes] = []
    i = 2
    while len(parts) < 3 and i < len(data):
        while i < len(data) and data[i] in b" \t\r\n":
            i += 1
        if i < len(data) and data[i] == ord("#"):
            while i < len(data) and data[i] not in b"\r\n":
                i += 1
            continue
        start = i
        while i < len(data) and data[i] not in b" \t\r\n":
            i += 1
        parts.append(data[start:i])
    if len(parts) < 3:
        raise GateError(f"truncated PGM header: {path}")
    width, height, maxval = (int(x) for x in parts)
    while i < len(data) and data[i] in b" \t\r":
        i += 1
    if i < len(data) and data[i] in b"\n":
        i += 1
    body = data[i:]
    if len(body) < width * height:
        raise GateError(f"truncated PGM file: {path}")
    pixels = body[: width * height]
    if maxval != 255:
        pixels = bytes(round(v * 255 / maxval) for v in pixels)
    return width, height, pixels


def write_pgm(path: Path, width: int, height: int, pixels: bytes) -> None:
    if len(pixels) != width * height:
        raise GateError("pixel buffer does not match dimensions")
    path.write_bytes(b"P5\n%d %d\n255\n" % (width, height) + pixels)


def mean_abs_diff(a: bytes, b: bytes) -> float:
    if len(a) != len(b):
        raise GateError("frame size mismatch for MAD")
    if not a:
        return 0.0
    total = 0
    for x, y in zip(a, b):
        total += abs(x - y)
    return total / len(a)


def decode_via_ffmpeg(path: Path, max_frames: int) -> list[tuple[int, int, bytes]]:
    if not shutil.which("ffmpeg"):
        raise GateError("ffmpeg is required to decode images/videos")
    with tempfile.TemporaryDirectory(prefix="motion_gate_") as tmp:
        tmpdir = Path(tmp)
        pattern = str(tmpdir / "frame-%05d.pgm")
        suffix = path.suffix.lower()
        command = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(path)]
        if suffix in VIDEO_EXTS:
            command += ["-vf", f"scale={SCALE_WIDTH}:-2,fps=8", "-frames:v", str(max_frames)]
        else:
            command += ["-vf", f"scale={SCALE_WIDTH}:-2", "-frames:v", "1"]
        command += ["-pix_fmt", "gray", "-f", "image2", pattern]
        try:
            result = subprocess.run(command, capture_output=True, timeout=180, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise GateError(f"ffmpeg failed for {path}: {exc}") from exc
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", "replace").strip()
            raise GateError(f"ffmpeg failed for {path}: {detail}")
        frames = sorted(tmpdir.glob("frame-*.pgm"))
        if not frames:
            raise GateError(f"ffmpeg decoded zero frames from {path}")
        return [read_pgm(frame) for frame in frames]


def collect_frames(path: Path, max_frames: int) -> list[tuple[int, int, bytes]]:
    if path.is_dir():
        pgms = sorted(path.glob("*.pgm"))
        if pgms:
            return [read_pgm(p) for p in pgms[:max_frames]]
        images = sorted(
            p for p in path.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS | VIDEO_EXTS
        )
        if not images:
            raise GateError(f"no frames under {path}")
        # Prefer treating a directory of stills as an ordered sequence via ffmpeg concat-less load
        frames: list[tuple[int, int, bytes]] = []
        for img in images[:max_frames]:
            if img.suffix.lower() == ".pgm":
                frames.append(read_pgm(img))
            else:
                frames.extend(decode_via_ffmpeg(img, 1))
        return frames
    if not path.is_file():
        raise GateError(f"not a file or directory: {path}")
    if path.suffix.lower() == ".pgm":
        return [read_pgm(path)]
    if path.suffix.lower() in VIDEO_EXTS | IMAGE_EXTS:
        return decode_via_ffmpeg(path, max_frames)
    raise GateError(f"unsupported media: {path}")


def max_mad_vs_frame0(frames: list[tuple[int, int, bytes]]) -> tuple[float, int, list[float]]:
    if len(frames) < 2:
        raise GateError("need at least 2 frames to measure motion")
    w0, h0, p0 = frames[0]
    mads: list[float] = []
    for idx, (w, h, pixels) in enumerate(frames[1:], start=1):
        if (w, h) != (w0, h0):
            raise GateError(f"frame {idx} size {w}x{h} != frame0 {w0}x{h0}")
        mads.append(mean_abs_diff(p0, pixels))
    best_i = max(range(len(mads)), key=lambda i: mads[i])
    return mads[best_i], best_i + 1, mads


def run_self_test(min_max_mad: float) -> int:
    """Synthetic static (must FAIL) and moving (must PASS) sequences."""
    width = height = 64
    n = width * height
    static_base = bytes([120] * n)
    with tempfile.TemporaryDirectory(prefix="motion_gate_self_") as tmp:
        tmpdir = Path(tmp)
        static_dir = tmpdir / "static"
        moving_dir = tmpdir / "moving"
        static_dir.mkdir()
        moving_dir.mkdir()
        for i in range(5):
            write_pgm(static_dir / f"f{i:02d}.pgm", width, height, static_base)
        for i in range(5):
            buf = bytearray([40] * n)
            offset = min(i * 8, width - 16)
            for y in range(16, 48):
                for x in range(offset, offset + 16):
                    buf[y * width + x] = 220
            write_pgm(moving_dir / f"f{i:02d}.pgm", width, height, bytes(buf))

        static_max, _, static_mads = max_mad_vs_frame0(collect_frames(static_dir, 16))
        moving_max, _, moving_mads = max_mad_vs_frame0(collect_frames(moving_dir, 16))
        print(
            f"[motion_gate][SELF-TEST] static max_mad={static_max:.3f} "
            f"mads={[round(m, 3) for m in static_mads]}"
        )
        print(
            f"[motion_gate][SELF-TEST] moving max_mad={moving_max:.3f} "
            f"mads={[round(m, 3) for m in moving_mads]}"
        )
        if static_max >= min_max_mad:
            print(
                f"[motion_gate][SELF-TEST][FAIL] static sequence max_mad={static_max:.3f} "
                f">= threshold {min_max_mad}",
                file=sys.stderr,
            )
            return 1
        if moving_max < min_max_mad:
            print(
                f"[motion_gate][SELF-TEST][FAIL] moving sequence max_mad={moving_max:.3f} "
                f"< threshold {min_max_mad}",
                file=sys.stderr,
            )
            return 1
        # Negative calibration: emulate baseline≈3.6 nearly-static band must FAIL threshold
        nearly = bytes([120 + (i % 3) for i in range(n)])  # tiny flicker
        with tempfile.TemporaryDirectory(prefix="motion_gate_base_") as tmp2:
            bdir = Path(tmp2)
            for i in range(5):
                # MAD vs frame0 stays in the ~few-units band if we only flip a few pixels
                buf = bytearray(static_base)
                for j in range(i * 20, i * 20 + 40):
                    buf[j % n] = 130
                write_pgm(bdir / f"f{i:02d}.pgm", width, height, bytes(buf))
            base_max, _, _ = max_mad_vs_frame0(collect_frames(bdir, 16))
        print(
            f"[motion_gate][SELF-TEST] near-static calibration max_mad={base_max:.3f} "
            f"(documented baseline≈{BASELINE_STATIC_MAD}; must stay < {min_max_mad})"
        )
        if base_max >= min_max_mad:
            print(
                "[motion_gate][SELF-TEST][FAIL] near-static calibration incorrectly PASSed threshold",
                file=sys.stderr,
            )
            return 1
        print(
            f"[motion_gate][SELF-TEST] PASS "
            f"(static/near-static < {min_max_mad} <= moving {moving_max:.3f})"
        )
        return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Reject nearly-static I2V clips via grayscale MAD max vs frame0 "
            f"(default threshold {DEFAULT_MIN_MAX_MAD}; baseline FAIL≈{BASELINE_STATIC_MAD})."
        )
    )
    parser.add_argument(
        "--min-max-mad",
        type=float,
        default=DEFAULT_MIN_MAX_MAD,
        help=f"require max MAD vs frame0 >= this (default {DEFAULT_MIN_MAX_MAD})",
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=48,
        help="max frames to decode/sample from a video or directory",
    )
    parser.add_argument("--self-test", action="store_true", help="run synthetic static/moving self-test")
    parser.add_argument("--json", action="store_true", help="print JSON summary on stdout")
    parser.add_argument("paths", nargs="*", help="mp4/webm/… or directory of frames")
    args = parser.parse_args(argv)

    if args.min_max_mad < 0:
        parser.error("--min-max-mad must be >= 0")
    if args.max_frames < 2:
        parser.error("--max-frames must be >= 2")

    self_rc = run_self_test(args.min_max_mad) if args.self_test else 0
    if not args.paths:
        return self_rc
    if self_rc != 0:
        return self_rc

    overall_fail = False
    summaries: list[dict] = []
    for raw in args.paths:
        path = Path(raw)
        try:
            frames = collect_frames(path, args.max_frames)
            max_mad, peak_idx, mads = max_mad_vs_frame0(frames)
            passed = max_mad >= args.min_max_mad
            summary = {
                "path": str(path),
                "frames": len(frames),
                "max_mad": round(max_mad, 4),
                "peak_frame_index": peak_idx,
                "threshold": args.min_max_mad,
                "pass": passed,
                "baseline_static_mad": BASELINE_STATIC_MAD,
                "mads": [round(m, 4) for m in mads],
            }
            summaries.append(summary)
            status = "PASS" if passed else "FAIL"
            line = (
                f"[motion_gate][{status}] {path}: max_mad={max_mad:.3f} "
                f"(peak frame {peak_idx}/{len(frames) - 1}) "
                f"threshold={args.min_max_mad} frames={len(frames)}"
            )
            if passed:
                print(line)
            else:
                overall_fail = True
                print(line, file=sys.stderr)
                print(
                    "[motion_gate][FAIL] nearly-static clip "
                    f"(baseline FAIL≈{BASELINE_STATIC_MAD} MAD); "
                    "not a usable motion sample — do not claim «可用片段» without G2m PASS",
                    file=sys.stderr,
                )
        except GateError as exc:
            print(f"[motion_gate][ERROR] {exc}", file=sys.stderr)
            return 1

    if args.json:
        print(json.dumps({"results": summaries}, ensure_ascii=False, indent=2))

    if overall_fail:
        return 2
    print(f"[motion_gate] PASS: {len(summaries)} clip(s) meet motion threshold")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
