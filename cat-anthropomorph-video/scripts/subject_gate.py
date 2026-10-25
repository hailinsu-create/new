#!/usr/bin/env python3
"""Subject gate G2: grayscale SSIM band vs a reference start image/frame0.

Too low  -> noise / identity collapse (cross-check G1 noise_gate).
Too high -> only a WARN (likely static; cross-check G2m motion_gate).
SSIM is a full-reference metric: both sides are scaled to 256px wide and
centre-cropped to a common height before comparison. It does NOT replace the
human identity check.

Exit codes (aligned with noise_gate/motion_gate):
  0  SSIM band OK (high-similarity warning may still be printed)
  1  usage / decode / input error
  2  at least one sampled frame below --min-ssim (or enforced centre gate)
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path

IMAGE_EXTS = {".pgm", ".ppm", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
VIDEO_EXTS = {".mp4", ".webm", ".mov", ".mkv", ".avi", ".gif"}
SCALE_WIDTH = 256
MAX_SAMPLES = 48
DEFAULT_MIN_SSIM = 0.25
DEFAULT_MAX_SSIM = 0.92
DEFAULT_CENTER_FRACTION = 0.6
C1 = (0.01 * 255) ** 2
C2 = (0.03 * 255) ** 2


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


def decode_via_ffmpeg(path: Path, max_frames: int) -> list[tuple[int, int, bytes]]:
    if not shutil.which("ffmpeg"):
        raise GateError("ffmpeg is required to decode images/videos")
    with tempfile.TemporaryDirectory(prefix="subject_gate_") as tmp:
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


def load_reference(path: Path) -> tuple[int, int, bytes]:
    if path.suffix.lower() == ".pgm":
        return read_pgm(path)
    if not path.is_file():
        raise GateError(f"start image not found: {path}")
    return decode_via_ffmpeg(path, 1)[0]


def center_crop(width: int, height: int, pixels: bytes, new_w: int, new_h: int) -> bytes:
    new_w = max(2, min(new_w, width))
    new_h = max(2, min(new_h, height))
    x0 = (width - new_w) // 2
    y0 = (height - new_h) // 2
    rows = [
        pixels[(y0 + y) * width + x0 : (y0 + y) * width + x0 + new_w] for y in range(new_h)
    ]
    return b"".join(rows)


def align_pair(
    ref: tuple[int, int, bytes], frame: tuple[int, int, bytes]
) -> tuple[tuple[int, int, bytes], tuple[int, int, bytes]]:
    rw, rh, rp = ref
    fw, fh, fp = frame
    if rw != fw:
        raise GateError(f"width mismatch after scaling: ref {rw} vs frame {fw}")
    height = min(rh, fh)
    if rh != height:
        rp = center_crop(rw, rh, rp, rw, height)
    if fh != height:
        fp = center_crop(fw, fh, fp, fw, height)
    return (rw, height, rp), (fw, height, fp)


def ssim_block(
    a: bytes,
    b: bytes,
    width: int,
    height: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
) -> float:
    total = 0
    s1 = s2 = s11 = s22 = s12 = 0
    for y in range(y0, y1):
        base = y * width
        for x in range(x0, x1):
            i = base + x
            va = a[i]
            vb = b[i]
            s1 += va
            s2 += vb
            s11 += va * va
            s22 += vb * vb
            s12 += va * vb
            total += 1
    if total == 0:
        return 0.0
    mu1 = s1 / total
    mu2 = s2 / total
    var1 = max(s11 / total - mu1 * mu1, 0.0)
    var2 = max(s22 / total - mu2 * mu2, 0.0)
    cov = s12 / total - mu1 * mu2
    numerator = (2 * mu1 * mu2 + C1) * (2 * cov + C2)
    denominator = (mu1 * mu1 + mu2 * mu2 + C1) * (var1 + var2 + C2)
    return numerator / denominator if denominator else 0.0


def ssim(a: bytes, b: bytes, width: int, height: int) -> float:
    if len(a) != len(b):
        raise GateError("frame size mismatch for SSIM")
    tiles_x = max(1, round(width / 32))
    tiles_y = max(1, round(height / 32))
    xs = [round(i * width / tiles_x) for i in range(tiles_x + 1)]
    ys = [round(i * height / tiles_y) for i in range(tiles_y + 1)]
    weighted = 0.0
    weight = 0
    for ty in range(tiles_y):
        y0, y1 = ys[ty], ys[ty + 1]
        if y1 - y0 < 2:
            continue
        for tx in range(tiles_x):
            x0, x1 = xs[tx], xs[tx + 1]
            if x1 - x0 < 2:
                continue
            count = (x1 - x0) * (y1 - y0)
            weighted += ssim_block(a, b, width, height, x0, y0, x1, y1) * count
            weight += count
    return weighted / weight if weight else 0.0


def compare(
    ref: tuple[int, int, bytes],
    frame: tuple[int, int, bytes],
    center_fraction: float,
) -> dict[str, float]:
    aligned_ref, aligned_frame = align_pair(ref, frame)
    width, height, a = aligned_ref
    _, _, b = aligned_frame
    full = ssim(a, b, width, height)
    center_w = max(2, int(width * center_fraction))
    center_h = max(2, int(height * center_fraction))
    ca = center_crop(width, height, a, center_w, center_h)
    cb = center_crop(width, height, b, center_w, center_h)
    center = ssim(ca, cb, center_w, center_h)
    return {"ssim": full, "center_ssim": center}


def summary_for_clip(
    ref: tuple[int, int, bytes],
    frames: list[tuple[int, int, bytes]],
    min_ssim: float,
    max_ssim: float,
    center_fraction: float,
    enforce_center: bool,
    center_min_ssim: float,
) -> dict:
    lows: list[int] = []
    highs: list[int] = []
    center_lows: list[int] = []
    values: list[float] = []
    centers: list[float] = []
    for idx, frame in enumerate(frames, start=1):
        metrics = compare(ref, frame, center_fraction)
        values.append(metrics["ssim"])
        centers.append(metrics["center_ssim"])
        if metrics["ssim"] < min_ssim:
            lows.append(idx)
        if metrics["ssim"] > max_ssim:
            highs.append(idx)
        if enforce_center and metrics["center_ssim"] < center_min_ssim:
            center_lows.append(idx)
    return {
        "frames": len(frames),
        "ssim_min": round(min(values), 4),
        "ssim_median": round(statistics.median(values), 4),
        "ssim_max": round(max(values), 4),
        "center_ssim_min": round(min(centers), 4),
        "low_frames": lows,
        "high_frames": highs,
        "center_low_frames": center_lows,
        "fail": bool(lows or center_lows),
        "static_warn": bool(values and min(values) > max_ssim),
        "values": [round(v, 4) for v in values],
        "centers": [round(v, 4) for v in centers],
    }


def synthetic_reference(width: int, height: int) -> bytes:
    buf = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            value = int(40 + 100 * x / (width - 1) + 20 * y / (height - 1))
            if 30 <= x < 80 and 24 <= y < 104:
                value = 225
            buf[y * width + x] = value
    return bytes(buf)


def synthetic_moved(reference: bytes, width: int, height: int, shift: int) -> bytes:
    buf = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            src_x = x - shift
            buf[y * width + x] = reference[y * width + src_x] if src_x >= 0 else 0
    return bytes(buf)


def run_self_test(
    min_ssim: float, max_ssim: float, center_fraction: float
) -> int:
    width = height = 128
    reference = synthetic_reference(width, height)
    moved = synthetic_moved(reference, width, height, 12)
    rng = random.Random(20261025)
    noise = bytes(rng.randrange(256) for _ in range(width * height))

    ref_frame = (width, height, reference)
    noise_metrics = compare(ref_frame, (width, height, noise), center_fraction)
    moved_metrics = compare(ref_frame, (width, height, moved), center_fraction)
    same_metrics = compare(ref_frame, ref_frame, center_fraction)

    print(
        f"[subject_gate][SELF-TEST] noise ssim={noise_metrics['ssim']:.4f} "
        f"center={noise_metrics['center_ssim']:.4f}"
    )
    print(
        f"[subject_gate][SELF-TEST] moved ssim={moved_metrics['ssim']:.4f} "
        f"center={moved_metrics['center_ssim']:.4f}"
    )
    print(f"[subject_gate][SELF-TEST] identical ssim={same_metrics['ssim']:.4f}")

    if noise_metrics["ssim"] >= min_ssim:
        print("[subject_gate][SELF-TEST][FAIL] noise was not below the low band", file=sys.stderr)
        return 1
    if not (min_ssim <= moved_metrics["ssim"] <= max_ssim):
        print(
            "[subject_gate][SELF-TEST][FAIL] moved subject fell outside "
            f"[{min_ssim}, {max_ssim}]",
            file=sys.stderr,
        )
        return 1
    if same_metrics["ssim"] <= max_ssim:
        print("[subject_gate][SELF-TEST][FAIL] identical frame did not trigger high warn", file=sys.stderr)
        return 1
    print(
        f"[subject_gate][SELF-TEST] PASS (noise < {min_ssim} <= moved "
        f"<= {max_ssim} < identical warn)"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "G2 subject gate: grayscale SSIM band vs start image/frame0 "
            f"(default {DEFAULT_MIN_SSIM}-{DEFAULT_MAX_SSIM})."
        )
    )
    parser.add_argument("--self-test", action="store_true", help="run synthetic noise/moved/identical self-test")
    parser.add_argument("--start-image", type=Path, help="reference start image (required for still inputs)")
    parser.add_argument("--min-ssim", type=float, default=DEFAULT_MIN_SSIM)
    parser.add_argument("--max-ssim", type=float, default=DEFAULT_MAX_SSIM)
    parser.add_argument(
        "--center-fraction",
        type=float,
        default=DEFAULT_CENTER_FRACTION,
        help="centre crop fraction used for the optional coarse subject heuristic",
    )
    parser.add_argument(
        "--center-min-ssim",
        type=float,
        default=None,
        help="centre-region minimum (only enforced with --enforce-center; default = --min-ssim)",
    )
    parser.add_argument(
        "--enforce-center",
        action="store_true",
        help="fail when centre-region SSIM is below --center-min-ssim (off by default)",
    )
    parser.add_argument("--max-frames", type=int, default=MAX_SAMPLES)
    parser.add_argument("--json", action="store_true", help="print JSON summary on stdout")
    parser.add_argument("paths", nargs="*", help="video / still / directory of frames")
    args = parser.parse_args(argv)

    if not (0.0 < args.min_ssim < args.max_ssim <= 1.0):
        parser.error("require 0 < --min-ssim < --max-ssim <= 1")
    if not (0.1 <= args.center_fraction <= 1.0):
        parser.error("--center-fraction must be within [0.1, 1.0]")
    if args.max_frames < 1:
        parser.error("--max-frames must be >= 1")
    center_min = args.min_ssim if args.center_min_ssim is None else args.center_min_ssim
    if not (0.0 <= center_min <= 1.0):
        parser.error("--center-min-ssim must be within [0, 1]")

    self_rc = run_self_test(args.min_ssim, args.max_ssim, args.center_fraction) if args.self_test else 0
    if not args.paths:
        return self_rc
    if self_rc != 0:
        return self_rc

    ref = load_reference(args.start_image) if args.start_image else None
    overall_fail = False
    summaries: list[dict] = []
    for raw in args.paths:
        path = Path(raw)
        try:
            frames = collect_frames(path, args.max_frames)
            clip_ref = ref
            if clip_ref is None:
                if path.is_file() and path.suffix.lower() not in VIDEO_EXTS:
                    raise GateError(
                        f"still input {path} needs --start-image (SSIM is full-reference)"
                    )
                if len(frames) < 2:
                    raise GateError(f"need at least 2 frames or --start-image for {path}")
                clip_ref = frames[0]
                target_frames = frames[1:]
            else:
                target_frames = frames
            summary = summary_for_clip(
                clip_ref,
                target_frames,
                args.min_ssim,
                args.max_ssim,
                args.center_fraction,
                args.enforce_center,
                center_min,
            )
            summary.update(
                {
                    "path": str(path),
                    "reference": str(args.start_image) if args.start_image else "frame0",
                    "band": [args.min_ssim, args.max_ssim],
                }
            )
            summaries.append(summary)
            if summary["fail"]:
                overall_fail = True
                if summary["low_frames"]:
                    print(
                        f"[subject_gate][FAIL] {path}: low SSIM frames "
                        f"{summary['low_frames']} min={summary['ssim_min']} "
                        f"band=[{args.min_ssim},{args.max_ssim}]",
                        file=sys.stderr,
                    )
                    print(
                        "[subject_gate][FAIL] low SSIM = noise / identity collapse; "
                        "cross-check G1 noise_gate and do not claim usable clip",
                        file=sys.stderr,
                    )
                if summary["center_low_frames"]:
                    print(
                        f"[subject_gate][FAIL] {path}: centre SSIM frames "
                        f"{summary['center_low_frames']} min={summary['center_ssim_min']} "
                        f"< {center_min} (--enforce-center)",
                        file=sys.stderr,
                    )
            else:
                status = "WARN" if summary["static_warn"] else "PASS"
                print(
                    f"[subject_gate][{status}] {path}: ssim min={summary['ssim_min']} "
                    f"median={summary['ssim_median']} max={summary['ssim_max']} "
                    f"centre_min={summary['center_ssim_min']} frames={summary['frames']}"
                )
                if summary["static_warn"]:
                    print(
                        "[subject_gate][WARN] all sampled frames are highly similar to frame0; "
                        "possible static clip — cross-check G2m motion_gate (warn only)",
                        file=sys.stderr,
                    )
        except GateError as exc:
            print(f"[subject_gate][ERROR] {exc}", file=sys.stderr)
            return 1

    if args.json:
        print(json.dumps({"results": summaries}, ensure_ascii=False, indent=2))

    if overall_fail:
        return 2
    print(f"[subject_gate] PASS: {len(summaries)} clip(s) inside SSIM band (warnings do not fail)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
