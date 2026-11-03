#!/usr/bin/env python3
"""Heuristic noise gate for generated images/videos.

Exit codes:
  0  samples look like normal imagery
  1  usage / decode / input error
  2  near-noise or degenerate frame detected
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

IMAGE_EXTS = {".pgm", ".ppm", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
VIDEO_EXTS = {".mp4", ".webm", ".mov", ".mkv", ".avi", ".gif"}
MAX_SAMPLES = 8
SCALE_WIDTH = 256


class GateError(RuntimeError):
    pass


def write_pgm(path: Path, width: int, height: int, pixels: bytes) -> None:
    if len(pixels) != width * height:
        raise GateError("pixel buffer does not match dimensions")
    path.write_bytes(b"P5\n%d %d\n255\n" % (width, height) + pixels)


def read_pgm(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    match = re.match(rb"P5\s+(\d+)\s+(\d+)\s+(\d+)\s", data)
    if not match:
        raise GateError(f"not a P5 PGM file: {path}")
    width, height, maxval = (int(x) for x in match.groups())
    body = data[match.end():]
    if len(body) < width * height:
        raise GateError(f"truncated PGM file: {path}")
    pixels = body[: width * height]
    if maxval != 255:
        pixels = bytes(round(v * 255 / maxval) for v in pixels)
    return width, height, pixels


def probe_media(path: Path) -> dict:
    if not shutil.which("ffprobe"):
        return {}
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_type,duration,nb_frames,avg_frame_rate",
        "-of",
        "json",
        str(path),
    ]
    try:
        result = subprocess.run(command, capture_output=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    if result.returncode != 0:
        return {}
    try:
        payload = json.loads(result.stdout.decode("utf-8", "replace"))
    except json.JSONDecodeError:
        return {}
    streams = payload.get("streams") or []
    return streams[0] if streams else {}


def parse_rate(value: str | None) -> float:
    if not value or value in {"N/A", "0/0"}:
        return 0.0
    if "/" in value:
        numerator, denominator = value.split("/", 1)
        try:
            return float(numerator) / max(float(denominator), 1e-9)
        except ValueError:
            return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def decode_frames(path: Path, max_frames: int) -> list[tuple[int, int, bytes]]:
    if path.suffix.lower() == ".pgm":
        return [read_pgm(path)]
    if not shutil.which("ffmpeg"):
        raise GateError("ffmpeg is required to decode images/videos")

    info = probe_media(path)
    duration = 0.0
    try:
        duration = float(info.get("duration") or 0.0)
    except (TypeError, ValueError):
        duration = 0.0
    nb_frames = 0
    try:
        nb_frames = int(info.get("nb_frames") or 0)
    except (TypeError, ValueError):
        nb_frames = 0
    fps = parse_rate(info.get("avg_frame_rate"))
    is_video = path.suffix.lower() in VIDEO_EXTS or nb_frames > 1 or duration > 0

    with tempfile.TemporaryDirectory(prefix="noise_gate_") as tmp:
        tmpdir = Path(tmp)
        output_pattern = str(tmpdir / "frame-%03d.pgm")
        command = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(path)]
        if is_video:
            total = nb_frames or (round(duration * fps) if duration and fps else 0)
            step = max(1, total // max_frames) if total else 24
            vf = f"select='not(mod(n\\,{step}))',scale={SCALE_WIDTH}:-2"
            command += ["-vf", vf, "-frames:v", str(max_frames)]
        else:
            command += ["-vf", f"scale={SCALE_WIDTH}:-2", "-frames:v", "1"]
        command += ["-pix_fmt", "gray", "-f", "image2", output_pattern]
        try:
            result = subprocess.run(command, capture_output=True, timeout=120, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise GateError(f"ffmpeg failed for {path}: {exc}") from exc
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", "replace").strip()
            raise GateError(f"ffmpeg failed for {path}: {detail}")
        frames = sorted(tmpdir.glob("frame-*.pgm"))
        if not frames:
            raise GateError(f"ffmpeg decoded zero frames from {path}")
        return [read_pgm(frame) for frame in frames]


def collect_files(path: Path, limit: int) -> list[Path]:
    if path.is_file():
        return [path]
    if not path.is_dir():
        raise GateError(f"not a file or directory: {path}")
    files = sorted(p for p in path.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTS | VIDEO_EXTS)
    if not files:
        raise GateError(f"no image/video files under {path}")
    if len(files) <= limit:
        return files
    if limit == 1:
        return [files[0]]
    indexes = sorted({round(i * (len(files) - 1) / (limit - 1)) for i in range(limit)})
    return [files[i] for i in indexes]


def frame_metrics(width: int, height: int, pixels: bytes) -> dict[str, float]:
    total = width * height
    histogram = [0] * 256
    for value in pixels:
        histogram[value] += 1
    entropy = -sum((count / total) * math.log2(count / total) for count in histogram if count) / 8.0
    mean = sum(pixels) / total
    variance = sum((value - mean) ** 2 for value in pixels) / total
    std = math.sqrt(max(variance, 0.0))

    rough_sum = 0
    rough_count = 0
    for y in range(height):
        base = y * width
        for x in range(1, width):
            rough_sum += abs(pixels[base + x] - pixels[base + x - 1])
            rough_count += 1
    for y in range(1, height):
        base = y * width
        previous = base - width
        for x in range(width):
            rough_sum += abs(pixels[base + x] - pixels[previous + x])
            rough_count += 1
    roughness = rough_sum / max(rough_count, 1)
    roughness_ratio = roughness / max(std, 1e-9)

    lap_sum = 0.0
    lap_sq_sum = 0.0
    lap_count = 0
    for y in range(1, height - 1):
        base = y * width
        for x in range(1, width - 1):
            index = base + x
            value = (
                4 * pixels[index]
                - pixels[index - 1]
                - pixels[index + 1]
                - pixels[index - width]
                - pixels[index + width]
            )
            lap_sum += value
            lap_sq_sum += value * value
            lap_count += 1
    lap_mean = lap_sum / max(lap_count, 1)
    lap_variance = max(lap_sq_sum / max(lap_count, 1) - lap_mean * lap_mean, 0.0)

    return {
        "entropy": entropy,
        "std": std,
        "roughness": roughness,
        "roughness_ratio": roughness_ratio,
        "lap_std": math.sqrt(lap_variance) / 255.0,
        "max_bin_fraction": max(histogram) / total,
    }


def noise_reason(metrics: dict[str, float]) -> str:
    if (
        metrics["entropy"] >= 0.90
        and metrics["roughness_ratio"] >= 0.70
        and metrics["std"] >= 2.5
    ):
        return "high entropy + high spatial roughness (random-noise-like)"
    if (
        metrics["entropy"] >= 0.985
        and metrics["max_bin_fraction"] <= 0.02
        and metrics["std"] >= 8.0
    ):
        return "entropy close to uniform noise"
    if (
        metrics["lap_std"] <= 0.0015
        and metrics["entropy"] >= 0.985
        and metrics["max_bin_fraction"] <= 0.02
    ):
        return "flat histogram + extremely low Laplacian variance"
    return ""


def format_metrics(metrics: dict[str, float]) -> str:
    return (
        f"entropy={metrics['entropy']:.4f} rough_ratio={metrics['roughness_ratio']:.4f} "
        f"std={metrics['std']:.1f} lap_std={metrics['lap_std']:.4f} "
        f"max_bin={metrics['max_bin_fraction']:.4f}"
    )


def run_self_test() -> int:
    rng = random.Random(20261024)
    width = height = 256
    noise = bytes(rng.randrange(256) for _ in range(width * height))
    smooth = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            smooth[y * width + x] = int(60 + 120 * x / (width - 1))
    noise_metrics = frame_metrics(width, height, noise)
    smooth_metrics = frame_metrics(width, height, bytes(smooth))
    noise_verdict = noise_reason(noise_metrics)
    smooth_verdict = noise_reason(smooth_metrics)
    print(f"[noise_gate][SELF-TEST] synthetic noise: {format_metrics(noise_metrics)}")
    print(f"[noise_gate][SELF-TEST] smooth pattern: {format_metrics(smooth_metrics)}")
    if not noise_verdict:
        print("[noise_gate][SELF-TEST][FAIL] synthetic noise was not rejected", file=sys.stderr)
        return 1
    if smooth_verdict:
        print(f"[noise_gate][SELF-TEST][FAIL] smooth pattern was rejected: {smooth_verdict}", file=sys.stderr)
        return 1
    print("[noise_gate][SELF-TEST] PASS (noise rejected, smooth pattern accepted)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Reject near-noise/degenerate generated images or videos (exit 2 on FAIL)."
    )
    parser.add_argument("--self-test", action="store_true", help="run synthetic noise/smooth self-test")
    parser.add_argument("--max-frames", type=int, default=MAX_SAMPLES, help="max frames sampled per video/directory")
    parser.add_argument("paths", nargs="*", help="image, video, or directory of frames")
    args = parser.parse_args(argv)

    if args.max_frames < 1:
        parser.error("--max-frames must be >= 1")

    self_test_rc = run_self_test() if args.self_test else 0
    if not args.paths:
        return self_test_rc
    if self_test_rc != 0:
        return self_test_rc

    failures = 0
    checked = 0
    for raw_path in args.paths:
        path = Path(raw_path)
        try:
            sources = collect_files(path, args.max_frames)
            for source in sources:
                frames = decode_frames(source, args.max_frames)
                for index, (width, height, pixels) in enumerate(frames, start=1):
                    metrics = frame_metrics(width, height, pixels)
                    reason = noise_reason(metrics)
                    checked += 1
                    label = f"{source} frame {index}/{len(frames)}"
                    if reason:
                        failures += 1
                        print(f"[noise_gate][FAIL] {label}: {reason} ({format_metrics(metrics)})", file=sys.stderr)
                    else:
                        print(f"[noise_gate] ok {label}: {format_metrics(metrics)}")
        except GateError as exc:
            print(f"[noise_gate][ERROR] {exc}", file=sys.stderr)
            return 1

    if failures:
        print(f"[noise_gate][FAIL] {failures}/{checked} sampled frames look like noise; output is not usable", file=sys.stderr)
        return 2
    print(f"[noise_gate] PASS: {checked} sampled frames look like normal imagery")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
