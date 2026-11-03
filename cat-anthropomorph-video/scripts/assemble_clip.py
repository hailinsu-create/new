#!/usr/bin/env python3
"""Assemble orchestration: RENDER_DONE -> G1/G2/G2m -> AUTO_QC_PASS -> candidates.jsonl.

HUMAN_ACCEPTED is written only when --human is passed. Optional audio can be a
silent track, a generated 128 BPM beat bed, or a licensed wav (via stitch_audio).

Exit codes:
  0  gates passed and the requested state was recorded
  1  usage / decode / audio / input error
  2  gate failure or status rule violation
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(SCRIPT_DIR))

from clip_status import (  # noqa: E402
    PUBLIC_CLAIM,
    REQUIRED_GATES,
    StatusError,
    apply_transition,
    load_status,
    save_status,
    status_path as default_status_path,
    utc_now,
)
from subject_gate import read_pgm, write_pgm  # noqa: E402

ROOT = SCRIPT_DIR.parent
CANDIDATE_SCHEMA = "cat-anthro-candidates/1"
GATE_SCRIPTS = {
    "G1": SCRIPT_DIR / "noise_gate.py",
    "G2": SCRIPT_DIR / "subject_gate.py",
    "G2m": SCRIPT_DIR / "motion_gate.py",
}
AUDIO_MODES = ("none", "silent", "bed", "wav")


class AssembleError(RuntimeError):
    pass


def run_process(command: list[str], timeout: int = 1800) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise AssembleError(f"command failed to run: {' '.join(command)}: {exc}") from exc


def emit_process(result: subprocess.CompletedProcess) -> None:
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)


def default_candidates_path(clip: Path) -> Path:
    output_root = os.environ.get("OUTPUT_ROOT")
    if output_root:
        return Path(output_root).expanduser() / "candidates.jsonl"
    return clip.parent / "candidates.jsonl"


def audio_output_path(source: Path, mode: str, explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    return source.with_name(f"{source.stem}_{mode}{source.suffix or '.mp4'}")


def prepare_audio(
    source: Path,
    mode: str,
    wav_path: Path | None,
    audio_out: Path | None,
    overwrite: bool,
    bpm: int,
    gain: float,
) -> tuple[Path, dict | None]:
    if mode == "none":
        if audio_out is not None:
            raise AssembleError("--audio-out requires --audio silent|bed|wav")
        return source, None
    if mode == "wav":
        if wav_path is None:
            raise AssembleError("--audio wav requires --wav licensed.wav")
        if not wav_path.is_file():
            raise AssembleError(f"licensed wav not found: {wav_path}")
    destination = audio_out or audio_output_path(source, mode, None)
    if destination.resolve() == source.resolve():
        raise AssembleError("audio output must differ from the input clip")
    command = [
        sys.executable,
        str(SCRIPT_DIR / "stitch_audio.py"),
        str(source),
        "--out",
        str(destination),
    ]
    if mode == "silent":
        command.append("--silent")
    elif mode == "bed":
        command.extend(["--audio-policy", "bed", "--bpm", str(bpm), "--gain", str(gain)])
    else:
        command.extend(["--wav", str(wav_path)])
    if overwrite:
        command.append("--overwrite")
    result = run_process(command)
    emit_process(result)
    if result.returncode != 0:
        raise AssembleError(f"stitch_audio failed with exit {result.returncode}")
    if not destination.is_file():
        raise AssembleError(f"stitch_audio did not create {destination}")
    info = {"mode": mode, "out": str(destination.resolve())}
    if wav_path is not None:
        info["wav"] = str(wav_path.resolve())
    if mode == "bed":
        info["bpm"] = bpm
        info["gain"] = gain
    return destination, info


def gate_command(name: str, clip: Path, start_image: Path | None) -> list[str]:
    script = GATE_SCRIPTS[name]
    command = [sys.executable, str(script)]
    if name == "G2" and start_image is not None:
        command.extend(["--start-image", str(start_image)])
    command.append(str(clip))
    return command


def run_gates(clip: Path, start_image: Path | None) -> list[dict]:
    results: list[dict] = []
    for name in REQUIRED_GATES:
        command = gate_command(name, clip, start_image)
        print(f"[assemble] {name}: {' '.join(command)}")
        result = run_process(command, timeout=900)
        emit_process(result)
        results.append(
            {
                "gate": name,
                "ok": result.returncode == 0,
                "exit_code": result.returncode,
                "command": command,
            }
        )
    return results


def advance_status(
    current: dict, clip: Path, target_state: str, note: str
) -> dict:
    data = apply_transition(
        current,
        str(clip),
        target_state,
        {name: "pass" for name in REQUIRED_GATES},
        human=target_state == "HUMAN_ACCEPTED",
        note=note,
    )
    return data


def update_candidate(path: Path, record: dict) -> None:
    records: list[dict] = []
    if path.exists():
        for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError as exc:
                raise AssembleError(f"invalid candidates JSONL line {index} in {path}: {exc}") from exc
            if not isinstance(item, dict):
                raise AssembleError(f"invalid candidates JSONL line {index} in {path}: not an object")
            records.append(item)
    clip_key = record["clip"]
    for index, item in enumerate(records):
        if item.get("clip") == clip_key:
            record["created_at"] = item.get("created_at") or record["created_at"]
            records[index] = record
            break
    else:
        records.append(record)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(
        "".join(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n" for item in records),
        encoding="utf-8",
    )
    temporary.replace(path)


def candidate_record(
    clip: Path,
    source: Path,
    status_file: Path,
    data: dict,
    results: list[dict],
    start_image: Path | None,
    audio: dict | None,
    note: str,
) -> dict:
    now = utc_now()
    return {
        "schema": CANDIDATE_SCHEMA,
        "clip": str(clip.resolve()),
        "source_render": str(source.resolve()),
        "state": data["state"],
        "usable_clip": bool(data["usable_clip"]),
        "public_claim": PUBLIC_CLAIM.get(data["state"]),
        "gates": data["gates"],
        "gate_exit_codes": {item["gate"]: item["exit_code"] for item in results},
        "g2_reference": str(start_image.resolve()) if start_image else "frame0",
        "audio": audio or {"mode": "none"},
        "status_file": str(status_file.resolve()),
        "note": note,
        "created_at": now,
        "updated_at": now,
    }


def assemble(args: argparse.Namespace) -> int:
    source = Path(args.clip).expanduser().resolve()
    if not source.is_file():
        print(f"[assemble][ERROR] clip not found: {source}", file=sys.stderr)
        return 1
    start_image = Path(args.start_image).expanduser().resolve() if args.start_image else None
    if start_image is not None and not start_image.is_file():
        print(f"[assemble][ERROR] start image not found: {start_image}", file=sys.stderr)
        return 1
    mode = args.audio or ("wav" if args.wav else "none")
    if mode not in AUDIO_MODES:
        print(f"[assemble][ERROR] unknown audio mode: {mode}", file=sys.stderr)
        return 1
    wav_path = Path(args.wav).expanduser().resolve() if args.wav else None
    audio_out = Path(args.audio_out).expanduser() if args.audio_out else None
    try:
        target, audio = prepare_audio(
            source, mode, wav_path, audio_out, args.overwrite, args.bpm, args.gain
        )
    except AssembleError as exc:
        print(f"[assemble][ERROR] {exc}", file=sys.stderr)
        return 1

    status_file = (
        Path(args.status).expanduser()
        if args.status
        else default_status_path(target)
    )
    try:
        current = load_status(status_file)
        if current is None:
            current = apply_transition(None, str(target), "RENDER_DONE", note="assemble_clip")
            save_status(status_file, current)
            print(f"[assemble] RENDER_DONE -> {status_file}")
        else:
            print(f"[assemble] existing state {current['state']} -> {status_file}")
    except StatusError as exc:
        print(f"[assemble][ERROR] {exc}", file=sys.stderr)
        return 2

    results = run_gates(target, start_image)
    failed = [item for item in results if not item["ok"]]
    if failed:
        for item in failed:
            print(
                f"[assemble][FAIL] {item['gate']} exit={item['exit_code']} "
                f"for {target}",
                file=sys.stderr,
            )
        print(
            "[assemble][FAIL] AUTO_QC_PASS not written; clip stays "
            f"{current['state']} and is NOT a usable clip",
            file=sys.stderr,
        )
        return 1 if any(item["exit_code"] not in (0, 2) for item in failed) else 2

    note = args.note or "assemble_clip: G1+G2+G2m pass"
    try:
        if current["state"] != "HUMAN_ACCEPTED":
            if current["state"] == "RENDER_DONE":
                current = advance_status(current, target, "AUTO_QC_PASS", note)
                save_status(status_file, current)
            elif current["state"] == "AUTO_QC_PASS":
                current = advance_status(current, target, "AUTO_QC_PASS", note)
                save_status(status_file, current)
        if args.human:
            current = advance_status(
                current,
                target,
                "HUMAN_ACCEPTED",
                args.note or "assemble_clip: human accepted",
            )
            save_status(status_file, current)
    except StatusError as exc:
        print(f"[assemble][ERROR] {exc}", file=sys.stderr)
        return 2

    candidates = (
        Path(args.candidates).expanduser()
        if args.candidates
        else default_candidates_path(target)
    )
    record = candidate_record(
        target, source, status_file, current, results, start_image, audio, args.note
    )
    try:
        update_candidate(candidates, record)
    except AssembleError as exc:
        print(f"[assemble][ERROR] {exc}", file=sys.stderr)
        return 1

    print(
        f"[assemble] state={current['state']} usable={current['usable_clip']} "
        f"claim={current['public_claim']}"
    )
    print(f"[assemble] candidate -> {candidates}")
    if not current["usable_clip"]:
        print("[assemble] NOT a usable/public clip yet; HUMAN_ACCEPTED requires --human")
    summary = {
        "clip": record["clip"],
        "source_render": record["source_render"],
        "status_file": record["status_file"],
        "state": record["state"],
        "usable_clip": record["usable_clip"],
        "public_claim": record["public_claim"],
        "gates": record["gates"],
        "gate_exit_codes": record["gate_exit_codes"],
        "audio": record["audio"],
        "candidates": str(candidates.resolve()),
    }
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def write_synthetic_clip(directory: Path, reference: tuple[int, int, bytes], moving: bool) -> Path:
    width, height, pixels = reference
    frames = directory / ("moving" if moving else "static")
    frames.mkdir(parents=True, exist_ok=True)
    for index in range(24):
        buffer = bytearray(pixels)
        if moving:
            offset = (index * 8) % 96
            for y in range(16, 112):
                row = y * width
                for x in range(offset, min(offset + 40, width)):
                    buffer[row + x] = 20 if ((x // 8 + y // 8) % 2 == 0) else 240
        write_pgm(frames / f"f{index:03d}.pgm", width, height, bytes(buffer))
    output = directory / ("moving.mp4" if moving else "static.mp4")
    command = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-y",
        "-framerate",
        "16",
        "-i",
        str(frames / "f%03d.pgm"),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(output),
    ]
    result = run_process(command, timeout=180)
    if result.returncode != 0:
        raise AssembleError(f"ffmpeg encode failed: {result.stderr.strip()}")
    return output


def audio_streams(path: Path) -> int:
    result = run_process(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a",
            "-show_entries",
            "stream=index",
            "-of",
            "csv=p=0",
            str(path),
        ],
        timeout=60,
    )
    if result.returncode != 0:
        raise AssembleError(f"ffprobe failed for {path}: {result.stderr.strip()}")
    return len([line for line in result.stdout.splitlines() if line.strip()])


def read_candidates(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def run_self_test() -> int:
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("[assemble][SELF-TEST][FAIL] ffmpeg/ffprobe required", file=sys.stderr)
        return 1
    fixture = ROOT / "fixtures" / "qc" / "subject_ref_128x128.pgm"
    if not fixture.is_file():
        print(f"[assemble][SELF-TEST][FAIL] missing fixture: {fixture}", file=sys.stderr)
        return 1
    failures: list[str] = []

    def check(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    def invoke(extra: list[str]) -> subprocess.CompletedProcess:
        return run_process([sys.executable, str(Path(__file__).resolve()), *extra])

    with tempfile.TemporaryDirectory(prefix="assemble_self_") as tmp:
        tmpdir = Path(tmp)
        reference = read_pgm(fixture)
        start_image = tmpdir / "start.pgm"
        write_pgm(start_image, *reference)
        try:
            moving = write_synthetic_clip(tmpdir, reference, moving=True)
            static = write_synthetic_clip(tmpdir, reference, moving=False)
        except AssembleError as exc:
            print(f"[assemble][SELF-TEST][FAIL] {exc}", file=sys.stderr)
            return 1

        candidates = tmpdir / "candidates.jsonl"
        result = invoke(
            [str(moving), "--start-image", str(start_image), "--candidates", str(candidates)]
        )
        if result.returncode != 0:
            emit_process(result)
            failures.append("AUTO_QC_PASS run failed")
        else:
            status = load_status(default_status_path(moving))
            check(status is not None and status["state"] == "AUTO_QC_PASS", "expected AUTO_QC_PASS")
            check(status is not None and not status["usable_clip"], "AUTO_QC_PASS must not be usable")
            records = read_candidates(candidates)
            check(len(records) == 1, "candidates.jsonl should contain one AUTO record")
            if records:
                check(records[0]["state"] == "AUTO_QC_PASS", "candidate should be AUTO_QC_PASS")
                check(not records[0]["usable_clip"], "AUTO candidate must not be usable")

        result = invoke(
            [
                str(moving),
                "--start-image",
                str(start_image),
                "--candidates",
                str(candidates),
                "--human",
            ]
        )
        if result.returncode != 0:
            emit_process(result)
            failures.append("HUMAN_ACCEPTED run failed")
        else:
            status = load_status(default_status_path(moving))
            check(status is not None and status["state"] == "HUMAN_ACCEPTED", "expected HUMAN_ACCEPTED")
            check(status is not None and bool(status["usable_clip"]), "HUMAN_ACCEPTED must be usable")
            records = read_candidates(candidates)
            check(len(records) == 1, "human accept should update, not duplicate, the candidate")
            if records:
                check(records[0]["state"] == "HUMAN_ACCEPTED", "candidate should be HUMAN_ACCEPTED")
                check(bool(records[0]["usable_clip"]), "HUMAN candidate should be usable")

        failed_candidates = tmpdir / "failed-candidates.jsonl"
        result = invoke(
            [
                str(static),
                "--start-image",
                str(start_image),
                "--candidates",
                str(failed_candidates),
            ]
        )
        check(result.returncode == 2, "static clip should fail G2m with exit 2")
        status = load_status(default_status_path(static))
        check(status is not None and status["state"] == "RENDER_DONE", "failed clip must stay RENDER_DONE")
        check(not read_candidates(failed_candidates), "failed clip must not enter candidates.jsonl")

        audio_out = tmpdir / "moving_bed.mp4"
        result = invoke(
            [
                str(moving),
                "--start-image",
                str(start_image),
                "--audio",
                "bed",
                "--audio-out",
                str(audio_out),
                "--candidates",
                str(tmpdir / "audio-candidates.jsonl"),
            ]
        )
        if result.returncode != 0:
            emit_process(result)
            failures.append("audio bed run failed")
        else:
            check(audio_out.is_file(), "audio bed output missing")
            if audio_out.is_file():
                check(audio_streams(audio_out) == 1, "audio bed should add exactly one audio stream")

    if failures:
        for message in failures:
            print(f"[assemble][SELF-TEST][FAIL] {message}", file=sys.stderr)
        return 1
    print(
        "[assemble][SELF-TEST] PASS (RENDER_DONE -> G1/G2/G2m -> AUTO_QC_PASS -> candidates; "
        "--human -> HUMAN_ACCEPTED; static G2m FAIL; audio bed)"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "One-shot clip assembly: RENDER_DONE, G1+G2+G2m, AUTO_QC_PASS, candidates.jsonl; "
            "HUMAN_ACCEPTED only with --human."
        )
    )
    parser.add_argument("clip", nargs="?", help="rendered mp4/webm/mov to assemble")
    parser.add_argument("--start-image", help="G2 reference start image; default = frame0")
    parser.add_argument("--candidates", help="candidates.jsonl path (default: OUTPUT_ROOT or clip dir)")
    parser.add_argument("--status", help="explicit status JSON path")
    parser.add_argument(
        "--audio",
        choices=AUDIO_MODES,
        default=None,
        help="none (default) | silent | generated bed | licensed wav",
    )
    parser.add_argument("--wav", help="licensed wav for --audio wav")
    parser.add_argument("--audio-out", help="audio target path (default: <clip>_<mode>.mp4)")
    parser.add_argument("--bpm", type=int, default=128, help="generated bed BPM (default 128)")
    parser.add_argument("--gain", type=float, default=0.18, help="generated bed gain (default 0.18)")
    parser.add_argument("--human", action="store_true", help="record human acceptance")
    parser.add_argument("--note", default="", help="note stored in status and candidates")
    parser.add_argument("--overwrite", action="store_true", help="overwrite audio output")
    parser.add_argument("--json", action="store_true", help="print final JSON summary")
    parser.add_argument("--self-test", action="store_true", help="run synthetic end-to-end self-test")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()
    if not args.clip:
        parser.error("clip is required unless --self-test")
    if not (30 <= args.bpm <= 300):
        parser.error("--bpm must be within [30, 300]")
    if not (0.0 < args.gain <= 1.0):
        parser.error("--gain must be within (0, 1]")
    return assemble(args)


if __name__ == "__main__":
    raise SystemExit(main())
