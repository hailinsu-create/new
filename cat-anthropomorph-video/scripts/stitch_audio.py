#!/usr/bin/env python3
"""Mux a silent clip with an audio file, or synthesize a simple 128 BPM beat bed.

The generated bed is a plain sine tick + low thump, not a song and not copied
from any platform/library. For commercial release use only the target
platform's official library or a written permission / CC0 recording.

Examples:
  python3 scripts/stitch_audio.py clip.mp4 --out clip_audio.mp4
  python3 scripts/stitch_audio.py clip.mp4 --wav licensed.wav --out clip_audio.mp4
  python3 scripts/stitch_audio.py clip.mp4 --out clip_silent.mp4 --silent
  python3 scripts/stitch_audio.py --self-test

Exit codes: 0 ok / 1 usage/decode / 2 input or licensing-policy refusal.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from array import array
from pathlib import Path

DEFAULT_BPM = 128
DEFAULT_SAMPLE_RATE = 44100
DEFAULT_GAIN = 0.18


class AudioError(RuntimeError):
    pass


def require_tools() -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            raise AudioError(f"{tool} is required")


def probe(path: Path) -> dict:
    require_tools()
    command = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-show_entries",
        "stream=codec_type,duration",
        "-of",
        "json",
        str(path),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60, check=False)
    if result.returncode != 0:
        raise AudioError(f"ffprobe failed for {path}: {result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise AudioError(f"ffprobe JSON error for {path}: {exc}") from exc
    streams = payload.get("streams") or []
    has_audio = any(stream.get("codec_type") == "audio" for stream in streams)
    duration = 0.0
    for stream in streams:
        if stream.get("codec_type") != "video":
            continue
        try:
            duration = max(duration, float(stream.get("duration") or 0.0))
        except (TypeError, ValueError):
            pass
    if not duration:
        try:
            duration = float((payload.get("format") or {}).get("duration") or 0.0)
        except (TypeError, ValueError):
            duration = 0.0
    return {"duration": duration, "has_audio": has_audio}


def _envelope(phase: float, decay: float) -> float:
    if phase < 0:
        return 0.0
    return math.exp(-phase / decay)


def generate_beat_wav_python(
    path: Path, duration: float, bpm: int, sample_rate: int, gain: float
) -> None:
    interval = 60.0 / bpm
    total = max(1, int(round(duration * sample_rate)))
    samples = array("h")
    fade_in = max(1, int(sample_rate * 0.01))
    fade_out = max(1, int(sample_rate * 0.15))
    for n in range(total):
        t = n / sample_rate
        beat = int(t / interval)
        phase = t - beat * interval
        accent = 1.0 if beat % 4 == 0 else 0.65
        tick = math.sin(2 * math.pi * 1200 * phase) * _envelope(phase, 0.045) * accent
        thump = 0.0
        if beat % 4 == 0:
            thump = math.sin(2 * math.pi * 55 * phase) * _envelope(phase, 0.10) * 0.8
        value = (tick + thump) * gain
        if n < fade_in:
            value *= n / fade_in
        remaining = total - n
        if remaining < fade_out:
            value *= remaining / fade_out
        value = max(-1.0, min(1.0, value))
        samples.append(int(value * 32767))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(samples.tobytes())


def generate_beat_wav_numpy(
    path: Path, duration: float, bpm: int, sample_rate: int, gain: float
) -> None:
    import numpy as np

    interval = 60.0 / bpm
    total = max(1, int(round(duration * sample_rate)))
    t = np.arange(total, dtype=np.float64) / sample_rate
    beat = np.floor(t / interval).astype(np.int64)
    phase = t - beat * interval
    accent = np.where(beat % 4 == 0, 1.0, 0.65)
    tick = np.sin(2 * np.pi * 1200 * phase) * np.exp(-phase / 0.045) * accent
    thump = np.sin(2 * np.pi * 55 * phase) * np.exp(-phase / 0.10) * np.where(beat % 4 == 0, 0.8, 0.0)
    mono = (tick + thump) * gain
    fade_in = max(1, int(sample_rate * 0.01))
    fade_out = max(1, int(sample_rate * 0.15))
    ramp_in = np.linspace(0.0, 1.0, fade_in, endpoint=False)
    ramp_out = np.linspace(1.0, 0.0, fade_out, endpoint=False)
    mono[:fade_in] *= ramp_in
    mono[-fade_out:] *= ramp_out
    mono = np.clip(mono, -1.0, 1.0)
    pcm = (mono * 32767.0).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(pcm)


def generate_beat_wav(
    path: Path, duration: float, bpm: int, sample_rate: int, gain: float
) -> None:
    if duration <= 0:
        raise AudioError("duration must be > 0 to generate a beat bed")
    try:
        generate_beat_wav_numpy(path, duration, bpm, sample_rate, gain)
    except ImportError:
        generate_beat_wav_python(path, duration, bpm, sample_rate, gain)


def run_ffmpeg(command: list[str], dry_run: bool) -> None:
    if dry_run:
        print("[dry-run] " + " ".join(command))
        return
    result = subprocess.run(command, capture_output=True, text=True, timeout=1800, check=False)
    if result.returncode != 0:
        raise AudioError(f"ffmpeg failed: {result.stderr.strip()}")


def mux(
    video: Path,
    out: Path,
    audio: Path | None,
    policy: str,
    silent: bool,
    bpm: int,
    sample_rate: int,
    gain: float,
    overwrite: bool,
    dry_run: bool,
) -> dict:
    if not video.is_file():
        raise AudioError(f"video not found: {video}")
    if out.resolve() == video.resolve():
        raise AudioError("--out must differ from the input video")
    if out.exists() and not overwrite and not dry_run:
        raise AudioError(f"output exists (pass --overwrite): {out}")
    if audio is not None and not audio.is_file():
        raise AudioError(f"audio not found: {audio}")
    info = probe(video)
    expected_audio = bool(audio)

    if silent:
        action = "silent"
    elif audio is not None:
        action = "replace"
    elif policy == "strip":
        action = "silent"
    elif policy == "keep" or (policy == "auto" and info["has_audio"]):
        action = "keep"
    else:
        action = "bed"

    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="stitch_audio_") as tmp:
        tmpdir = Path(tmp)
        if action == "keep":
            command = [
                "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(video),
                "-map", "0", "-c", "copy", "-movflags", "+faststart", str(out),
            ]
            run_ffmpeg(command, dry_run)
        elif action == "silent":
            command = [
                "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(video),
                "-map", "0:v:0", "-c:v", "copy", "-an", "-movflags", "+faststart", str(out),
            ]
            run_ffmpeg(command, dry_run)
        else:
            source = audio
            if source is None:
                if info["duration"] <= 0:
                    raise AudioError(f"cannot determine video duration for {video}")
                source = tmpdir / "beat_bed.wav"
                generate_beat_wav(source, info["duration"], bpm, sample_rate, gain)
                print(
                    f"[stitch_audio] generated {bpm} BPM sine-tick bed "
                    f"({info['duration']:.2f}s) -> {source.name}"
                )
            expected_audio = True
            command = [
                "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(video), "-i", str(source),
                "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
                "-c:a", "aac", "-b:a", "192k", "-af", "apad",
                "-shortest", "-movflags", "+faststart", str(out),
            ]
            run_ffmpeg(command, dry_run)

    return {
        "video": str(video),
        "out": str(out),
        "action": action,
        "audio": str(audio) if audio else ("generated" if action == "bed" else ""),
        "expected_audio": expected_audio,
        "duration": round(info["duration"], 3),
        "bpm": bpm if action == "bed" else None,
    }


def run_self_test() -> int:
    require_tools()
    with tempfile.TemporaryDirectory(prefix="stitch_audio_self_") as tmp:
        tmpdir = Path(tmp)
        silent = tmpdir / "silent.mp4"
        beat = tmpdir / "beat.mp4"
        stripped = tmpdir / "stripped.mp4"
        make_silent = [
            "ffmpeg", "-nostdin", "-v", "error", "-y",
            "-f", "lavfi", "-i", "color=c=black:s=160x288:r=16:d=1.5",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", str(silent),
        ]
        result = subprocess.run(make_silent, capture_output=True, text=True, timeout=120, check=False)
        if result.returncode != 0:
            print(f"[stitch_audio][SELF-TEST][FAIL] cannot create sample: {result.stderr}", file=sys.stderr)
            return 1
        summary = mux(silent, beat, None, "auto", False, DEFAULT_BPM, DEFAULT_SAMPLE_RATE, DEFAULT_GAIN, False, False)
        info = probe(beat)
        if not info["has_audio"]:
            print("[stitch_audio][SELF-TEST][FAIL] generated bed has no audio stream", file=sys.stderr)
            return 1
        if info["duration"] < 1.4:
            print("[stitch_audio][SELF-TEST][FAIL] apad/shortest truncated the video", file=sys.stderr)
            return 1
        mux(beat, stripped, None, "auto", True, DEFAULT_BPM, DEFAULT_SAMPLE_RATE, DEFAULT_GAIN, False, False)
        if probe(stripped)["has_audio"]:
            print("[stitch_audio][SELF-TEST][FAIL] --silent left an audio stream", file=sys.stderr)
            return 1
        print(
            f"[stitch_audio][SELF-TEST] PASS (bed audio={summary['action']}, "
            f"duration={info['duration']:.2f}s, silent strip ok)"
        )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Mux a clip with audio or a generated 128 BPM sine-tick beat bed."
    )
    parser.add_argument("video", nargs="?", help="input mp4/webm/mov")
    parser.add_argument("--out", help="output mp4 (required unless --self-test)")
    parser.add_argument("--wav", type=Path, help="optional licensed audio file")
    parser.add_argument("--silent", action="store_true", help="strip audio from the output")
    parser.add_argument(
        "--audio-policy",
        choices=["auto", "keep", "replace", "strip"],
        default="auto",
        help="auto: wav->replace, existing audio->keep, silent->beat bed",
    )
    parser.add_argument("--bpm", type=int, default=DEFAULT_BPM)
    parser.add_argument("--sample-rate", type=int, default=DEFAULT_SAMPLE_RATE)
    parser.add_argument("--gain", type=float, default=DEFAULT_GAIN)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()
    if not args.video or not args.out:
        parser.error("video and --out are required")
    if not (30 <= args.bpm <= 300):
        parser.error("--bpm must be within [30, 300]")
    if not (0.0 < args.gain <= 1.0):
        parser.error("--gain must be within (0, 1]")

    try:
        summary = mux(
            Path(args.video),
            Path(args.out),
            args.wav,
            args.audio_policy,
            args.silent,
            args.bpm,
            args.sample_rate,
            args.gain,
            args.overwrite,
            args.dry_run,
        )
    except AudioError as exc:
        print(f"[stitch_audio][ERROR] {exc}", file=sys.stderr)
        return 2
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if summary["action"] != "keep":
        print(
            "[stitch_audio] audio source must be target-platform official library, "
            "written permission, or CC0; keep proof. No pirated/cross-platform rips."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
