#!/usr/bin/env python3
"""Three-state clip status ledger for cat-anthropomorph-video.

States:
  RENDER_DONE      render finished; NOT a usable clip
  AUTO_QC_PASS     G1 noise + G2 subject + G2m motion all PASS; human still required
  HUMAN_ACCEPTED   human confirmed identity/motion/audio; only this is usable

Exit codes:
  0  success / requirement met
  1  usage / file / JSON error
  2  invalid transition or gate requirement not met
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "cat-anthro-clip-status/1"
STATES = ("RENDER_DONE", "AUTO_QC_PASS", "HUMAN_ACCEPTED")
STATE_RANK = {name: idx for idx, name in enumerate(STATES)}
REQUIRED_GATES = ("G1", "G2", "G2m")
GATE_VALUES = {"pass", "fail", "skip", "unknown"}
PUBLIC_CLAIM = {
    "RENDER_DONE": "not_usable_render_only",
    "AUTO_QC_PASS": "not_usable_human_identity_pending",
    "HUMAN_ACCEPTED": "usable_sfw_human_accepted",
}


class StatusError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def status_path(target: str | Path) -> Path:
    path = Path(target)
    if path.suffix.lower() == ".json":
        return path
    return Path(str(path) + ".status.json")


def load_status(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise StatusError(f"cannot read status file {path}: {exc}") from exc
    if data.get("schema") != SCHEMA:
        raise StatusError(f"unexpected schema in {path}: {data.get('schema')!r}")
    return data


def save_status(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalise_gates(gates: dict[str, str]) -> dict[str, str]:
    out = {}
    for name in REQUIRED_GATES:
        value = str(gates.get(name, "unknown")).lower()
        if value not in GATE_VALUES:
            raise StatusError(f"gate {name} must be one of {sorted(GATE_VALUES)}")
        out[name] = value
    return out


def apply_transition(
    current: dict | None,
    clip: str,
    state: str,
    gates: dict[str, str] | None = None,
    human: bool = False,
    note: str = "",
) -> dict:
    if state not in STATES:
        raise StatusError(f"unknown state: {state}")
    merged_gates = normalise_gates({**(current or {}).get("gates", {}), **(gates or {})})
    current_state = (current or {}).get("state")
    if current_state is not None and current_state not in STATES:
        raise StatusError(f"unknown current state: {current_state}")

    if current_state is None:
        if state != "RENDER_DONE":
            raise StatusError("a new clip must start at RENDER_DONE")
    elif state != current_state:
        if state == "AUTO_QC_PASS" and current_state != "RENDER_DONE":
            raise StatusError("AUTO_QC_PASS must follow RENDER_DONE")
        if state == "HUMAN_ACCEPTED" and current_state != "AUTO_QC_PASS":
            raise StatusError("HUMAN_ACCEPTED must follow AUTO_QC_PASS")
        if state == "RENDER_DONE":
            raise StatusError("cannot go back to RENDER_DONE")

    if state in ("AUTO_QC_PASS", "HUMAN_ACCEPTED"):
        bad = [name for name in REQUIRED_GATES if merged_gates[name] != "pass"]
        if bad:
            raise StatusError(f"{state} requires all gates pass; not pass: {bad}")
    if state == "HUMAN_ACCEPTED" and not human:
        raise StatusError("HUMAN_ACCEPTED requires explicit --human confirmation")

    history = list((current or {}).get("history", []))
    history.append({"state": state, "at": utc_now(), "note": note})
    data = {
        "schema": SCHEMA,
        "clip": clip,
        "state": state,
        "usable_clip": state == "HUMAN_ACCEPTED",
        "public_claim": PUBLIC_CLAIM[state],
        "gates": merged_gates,
        "human_reviewed": bool(human or (current or {}).get("human_reviewed")),
        "updated_at": utc_now(),
        "note": note,
        "history": history[-50:],
    }
    return data


def meets_requirement(data: dict, required: str) -> bool:
    current = data.get("state")
    if current not in STATE_RANK or required not in STATE_RANK:
        return False
    return STATE_RANK[current] >= STATE_RANK[required]


def run_self_test() -> int:
    failures: list[str] = []

    def expect_error(label: str, func) -> None:
        try:
            func()
        except StatusError:
            return
        failures.append(f"{label} should have been rejected")

    with tempfile.TemporaryDirectory(prefix="clip_status_self_") as tmp:
        path = Path(tmp) / "clip.mp4.status.json"
        expect_error(
            "new clip starting at AUTO_QC_PASS",
            lambda: apply_transition(None, "clip.mp4", "AUTO_QC_PASS", {g: "pass" for g in REQUIRED_GATES}),
        )
        first = apply_transition(None, "clip.mp4", "RENDER_DONE")
        save_status(path, first)
        if first["usable_clip"] or first["public_claim"] != "not_usable_render_only":
            failures.append("RENDER_DONE must not be usable")
        expect_error(
            "AUTO_QC_PASS with missing gates",
            lambda: apply_transition(first, "clip.mp4", "AUTO_QC_PASS", {"G1": "pass"}),
        )
        expect_error(
            "HUMAN_ACCEPTED before AUTO_QC_PASS",
            lambda: apply_transition(first, "clip.mp4", "HUMAN_ACCEPTED", human=True),
        )
        auto = apply_transition(
            first, "clip.mp4", "AUTO_QC_PASS", {g: "pass" for g in REQUIRED_GATES}
        )
        if auto["usable_clip"] or auto["public_claim"] != "not_usable_human_identity_pending":
            failures.append("AUTO_QC_PASS must still require human identity review")
        expect_error(
            "HUMAN_ACCEPTED without --human",
            lambda: apply_transition(auto, "clip.mp4", "HUMAN_ACCEPTED"),
        )
        human = apply_transition(
            auto, "clip.mp4", "HUMAN_ACCEPTED", human=True, note="self-test"
        )
        if not human["usable_clip"] or not human["human_reviewed"]:
            failures.append("HUMAN_ACCEPTED must be the only usable state")
        save_status(path, human)
        reloaded = load_status(path)
        if reloaded != human:
            failures.append("status JSON round-trip mismatch")
        if not meets_requirement(human, "AUTO_QC_PASS") or not meets_requirement(human, "HUMAN_ACCEPTED"):
            failures.append("HUMAN_ACCEPTED must satisfy lower requirements")

    if failures:
        for item in failures:
            print(f"[clip_status][SELF-TEST][FAIL] {item}", file=sys.stderr)
        return 1
    print("[clip_status][SELF-TEST] PASS (three states, strict gates, human-only usable)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Three-state clip status: RENDER_DONE / AUTO_QC_PASS / HUMAN_ACCEPTED."
    )
    sub = parser.add_subparsers(dest="command")

    schema_parser = sub.add_parser("schema", help="print the status schema/rules")
    schema_parser.add_argument("--json", action="store_true", help="JSON output (default)")

    show_parser = sub.add_parser("show", help="show the status for a clip")
    show_parser.add_argument("target", help="clip path (or *.status.json)")
    show_parser.add_argument("--json", action="store_true")

    set_parser = sub.add_parser("set", help="apply a state transition")
    set_parser.add_argument("target", help="clip path (or *.status.json)")
    set_parser.add_argument("--state", required=True, choices=STATES)
    set_parser.add_argument("--g1", default="unknown", choices=sorted(GATE_VALUES))
    set_parser.add_argument("--g2", default="unknown", choices=sorted(GATE_VALUES))
    set_parser.add_argument("--g2m", default="unknown", choices=sorted(GATE_VALUES))
    set_parser.add_argument("--human", action="store_true", help="explicit human acceptance")
    set_parser.add_argument("--note", default="")

    verify_parser = sub.add_parser("verify", help="exit 0 if the clip meets a required state")
    verify_parser.add_argument("target", help="clip path (or *.status.json)")
    verify_parser.add_argument(
        "--require", default="AUTO_QC_PASS", choices=STATES, help="minimum required state"
    )

    parser.add_argument("--self-test", action="store_true", help="run built-in transition self-test")
    args = parser.parse_args(argv)

    if args.self_test and args.command is None:
        return run_self_test()

    if args.command == "schema":
        print(
            json.dumps(
                {
                    "schema": SCHEMA,
                    "states": list(STATES),
                    "required_gates": list(REQUIRED_GATES),
                    "rules": {
                        "render_end": "RENDER_DONE only; never a usable clip",
                        "auto": "RENDER_DONE -> AUTO_QC_PASS only when G1+G2+G2m all pass",
                        "human": "AUTO_QC_PASS -> HUMAN_ACCEPTED only with --human",
                        "usable": "usable_clip=true only for HUMAN_ACCEPTED",
                    },
                    "public_claim": PUBLIC_CLAIM,
                    "exit_codes": {"0": "ok", "1": "usage/input error", "2": "rule violation"},
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    path = status_path(args.target)
    try:
        if args.command == "show":
            data = load_status(path)
            if data is None:
                print(f"[clip_status] no status file: {path}", file=sys.stderr)
                return 1
            if args.json:
                print(json.dumps(data, ensure_ascii=False, indent=2))
            else:
                gates = " ".join(f"{name}={data['gates'].get(name, 'unknown')}" for name in REQUIRED_GATES)
                print(
                    f"{data['state']} usable={data['usable_clip']} claim={data['public_claim']} "
                    f"{gates} path={data['clip']}"
                )
            return 0

        if args.command == "set":
            current = load_status(path)
            clip = current["clip"] if current else args.target
            data = apply_transition(
                current,
                clip,
                args.state,
                {"G1": args.g1, "G2": args.g2, "G2m": args.g2m},
                human=args.human,
                note=args.note,
            )
            save_status(path, data)
            print(
                f"[clip_status] {data['state']} usable={data['usable_clip']} "
                f"claim={data['public_claim']} -> {path}"
            )
            if not data["usable_clip"]:
                print("[clip_status] NOT a usable/public clip yet; do not claim «可用成片»")
            return 0

        if args.command == "verify":
            data = load_status(path)
            if data is None:
                print(f"[clip_status][FAIL] no status file: {path}", file=sys.stderr)
                return 2
            if meets_requirement(data, args.require):
                print(f"[clip_status] {data['state']} meets required {args.require}")
                return 0
            print(
                f"[clip_status][FAIL] {data['state']} does not meet {args.require}",
                file=sys.stderr,
            )
            return 2
    except StatusError as exc:
        print(f"[clip_status][ERROR] {exc}", file=sys.stderr)
        return 2

    parser.error("unknown command")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
