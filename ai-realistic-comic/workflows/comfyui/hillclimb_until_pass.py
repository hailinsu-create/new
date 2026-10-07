#!/usr/bin/env python3
"""Hill-climb nude/torn on the live machine until Cursor sidecars pass (mean>=9, no gates).

Remote generate only (--no-score). Agent applies .cursor-score.json between attempts.
Stops when every requested stem has passed=True, or attempts are exhausted.

    python hillclimb_until_pass.py --out /opt/cursor/artifacts/fox-centaur-semantic/run13 \\
        --max-attempts 8 --actors lin elena
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_semantic as runner  # noqa: E402
import scheme_still_fox_centaur_undress as legacy  # noqa: E402

STEM = legacy.OUT_STEM


def passed(out: Path, actor: str, mode: str) -> bool:
    path = out / f"{STEM[(actor, mode)]}.json"
    if not path.exists():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    return bool(data.get("passed")) and not data.get("score_pending") and not data.get("score_failed")


def hard_blocked_nude(out: Path, actor: str) -> bool:
    path = out / f"{STEM[(actor, 'nude')]}.json"
    if not path.exists():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    gates = set(data.get("gates") or [])
    return bool(gates & {"clothes_remain", "armor_remain"})


def ssh_env() -> dict[str, str]:
    env = {}
    for path in (
        Path("/cursor/stores/user/bjb-ssh.env"),
        Path("/cursor/stores/user/bjb-clone.env"),
    ):
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def remote_run(actors: list[str], mode: str, attempt: int, remote_out: str) -> None:
    only = " ".join(actors)
    cmd = (
        f"cd /root/autodl-tmp/arc/ai-realistic-comic && "
        f"/root/miniconda3/bin/python -u workflows/comfyui/run_fox_centaur_semantic.py "
        f"--only {only} --mode {mode} --attempt {attempt} --no-score --out {remote_out}"
    )
    print(f"REMOTE {mode} attempt={attempt} actors={actors}", flush=True)
    # Reuse bringup_and_run helpers via a thin SSH from the same env the bringup uses.
    from bringup_and_run import ssh  # noqa: E402

    ssh(cmd, timeout=14_400)


def pull(local: Path, remote_out: str = "/root/autodl-tmp/fox-semantic-out") -> None:
    from bringup_and_run import pull as bringup_pull  # noqa: E402

    bringup_pull(local)


def light_ship() -> None:
    from bringup_and_run import ship  # noqa: E402

    ship(light=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--actors", nargs="+", default=["lin", "elena"])
    parser.add_argument("--max-attempts", type=int, default=8)
    parser.add_argument("--remote-out", default="/root/autodl-tmp/fox-semantic-out")
    parser.add_argument("--skip-ship", action="store_true")
    parser.add_argument("--wait-score-seconds", type=int, default=120,
                        help="After each pull, wait this long for agent .cursor-score.json apply.")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    if not args.skip_ship:
        light_ship()

    for attempt in range(args.max_attempts):
        need_nude = [a for a in args.actors if not passed(args.out, a, "nude")]
        if need_nude:
            remote_run(need_nude, "nude", attempt, args.remote_out)
            pull(args.out, args.remote_out)
            print(f"SCORE_WAIT nude attempt={attempt} seconds={args.wait_score_seconds}", flush=True)
            print("SCORE_PENDING_HINT write .cursor-score.json next to PNGs then "
                  "python workflows/comfyui/cursor_still_score.py apply ...", flush=True)
            deadline = time.monotonic() + args.wait_score_seconds
            while time.monotonic() < deadline:
                if all(passed(args.out, a, "nude") or (args.out / f"{STEM[(a,'nude')]}.cursor-score.json").exists()
                       for a in need_nude):
                    break
                time.sleep(5)
            # Auto-apply any cursor-score sidecars present.
            import cursor_still_score as scorer  # noqa: E402

            for a in need_nude:
                img = args.out / f"{STEM[(a, 'nude')]}.png"
                if img.exists():
                    scorer.score_image(a, "nude", img)

        need_torn = [
            a for a in args.actors
            if passed(args.out, a, "nude") and not passed(args.out, a, "torn") and not hard_blocked_nude(args.out, a)
        ]
        # Soft-fail nude (no clothes/armor gate) may still try torn.
        soft = [
            a for a in args.actors
            if not passed(args.out, a, "nude")
            and not hard_blocked_nude(args.out, a)
            and (args.out / f"{STEM[(a, 'nude')]}.json").exists()
            and not passed(args.out, a, "torn")
        ]
        torn_actors = list(dict.fromkeys(need_torn + soft))
        if torn_actors:
            remote_run(torn_actors, "torn", attempt, args.remote_out)
            pull(args.out, args.remote_out)
            print(f"SCORE_WAIT torn attempt={attempt} seconds={args.wait_score_seconds}", flush=True)
            deadline = time.monotonic() + args.wait_score_seconds
            while time.monotonic() < deadline:
                if all(
                    passed(args.out, a, "torn")
                    or (args.out / f"{STEM[(a, 'torn')]}.cursor-score.json").exists()
                    for a in torn_actors
                ):
                    break
                time.sleep(5)
            import cursor_still_score as scorer  # noqa: E402

            for a in torn_actors:
                img = args.out / f"{STEM[(a, 'torn')]}.png"
                if img.exists():
                    scorer.score_image(a, "torn", img)

        status = {
            f"{a}:{m}": passed(args.out, a, m)
            for a in args.actors
            for m in ("nude", "torn")
        }
        print(f"HILLCLIMB_STATUS attempt={attempt} {status}", flush=True)
        if all(status.values()):
            print("HILLCLIMB_PASS all stems passed", flush=True)
            return 0

        # If nudes still hard-blocked, continue; if all pending score, wait longer next loop.
        if any(not passed(args.out, a, "nude") and not hard_blocked_nude(args.out, a)
               and (args.out / f"{STEM[(a,'nude')]}.json").exists()
               and json.loads((args.out / f"{STEM[(a,'nude')]}.json").read_text()).get("score_pending")
               for a in args.actors):
            print("HILLCLIMB_BLOCKED awaiting cursor scores; stopping loop for agent", flush=True)
            return 3

    print("HILLCLIMB_EXHAUSTED", flush=True)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
