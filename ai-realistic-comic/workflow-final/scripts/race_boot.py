#!/usr/bin/env python3
"""Dual-machine mutex race + spend cap + watchdog (lib/ fleet helpers).

Requires AUTODL_TOKEN. For ordinary AutoDL containers, put the **web JWT** in
AUTODL_TOKEN (or also set AUTODL_WEB_AUTHORIZATION). Developer tokens only work
on Pro instances for power_on; balance still uses the developer API when available.

Dual race (default when BJB_CLONE_UUID is set, or --dual):
  alternate power_on_once between mother and clone; never leave both running.
  On win: print WINNER uuid and keep that machine on. Use --power-off / --power-off-fleet
  to shutdown keep-disk (never release).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
sys.path.insert(0, str(LIB))

import autodl_power as power  # noqa: E402
import spend_cap as spend_cap  # noqa: E402

BACKOFF = (15, 20, 30, 45, 60)


def ensure_auth_aliases() -> None:
    tok = os.environ.get("AUTODL_TOKEN", "").strip()
    if tok and not os.environ.get("AUTODL_WEB_AUTHORIZATION"):
        os.environ["AUTODL_WEB_AUTHORIZATION"] = tok


def start_watchdog(session: Path, log: Path, max_wall_min: float) -> subprocess.Popen:
    return subprocess.Popen(
        [
            sys.executable,
            str(LIB / "autodl_watchdog.py"),
            "--session",
            str(session),
            "--log",
            str(log),
            "--max-wall-min",
            str(max_wall_min),
        ],
        start_new_session=True,
    )


def seed_cap(session: Path, cap_yuan: float) -> spend_cap.SpendCap:
    bal = 0.0
    try:
        import re

        out = subprocess.check_output(
            [sys.executable, str(LIB / "autodl_power.py"), "balance"],
            text=True,
            stderr=subprocess.STDOUT,
        )
        m = re.search(r"yuan=([0-9.]+)", out)
        if m:
            bal = float(m.group(1))
    except Exception:  # noqa: BLE001
        bal = 0.0
    cap = spend_cap.SpendCap(
        start_bal=bal,
        cap_yuan=cap_yuan,
        session_path=session,
        boot_at=datetime.now(timezone.utc).isoformat(),
        boot_mono=time.monotonic(),
    )
    cap.save()
    return cap


def fleet_uuids(explicit: str | None, dual: bool) -> list[tuple[str, str]]:
    mother = power.instance_uuid(explicit or None)
    clone = power.clone_uuid()
    if dual and clone and clone != mother:
        # Prefer clone first (cheaper/payg) then mother — same policy as install race.
        return [(clone, "clone"), (mother, "mother")]
    return [(mother, "single")]


def race_dual(candidates: list[tuple[str, str]], *, max_minutes: float, auth: str) -> tuple[int, str | None]:
    """Mutex: try one machine at a time; power_off the other on success."""
    deadline = None if max_minutes <= 0 else time.monotonic() + max_minutes * 60
    attempt = 0
    idx = 0
    while True:
        uuid, label = candidates[idx % len(candidates)]
        idx += 1
        verdict, reply = power.power_on_once(uuid, auth)
        code, msg = reply.get("code"), str(reply.get("msg", ""))[:120]
        print(
            f"RACE attempt={attempt} target={label} uuid={uuid} verdict={verdict} code={code} msg={msg}",
            flush=True,
        )
        if verdict == "success":
            # ensure peer is off
            for other, olabel in candidates:
                if other != uuid:
                    print(f"MUTEX_OFF peer={olabel} {other}", flush=True)
                    power.power_off_keep_disk(other, auth)
            print(f"WINNER {label} uuid={uuid}", flush=True)
            return 0, uuid
        if verdict == "fatal":
            print("RACE_STOP fatal; not retrying", flush=True)
            return 2, None
        wait = BACKOFF[min(attempt, len(BACKOFF) - 1)]
        attempt += 1
        if deadline is not None and time.monotonic() + wait > deadline:
            print("RACE_GAVE_UP deadline", flush=True)
            return 3, None
        time.sleep(wait)


def main() -> int:
    ap = argparse.ArgumentParser(description="workflow-final race_boot")
    ap.add_argument("--uuid", default="", help="primary instance uuid (default mother / BJB_INSTANCE_UUID)")
    ap.add_argument("--dual", action="store_true", help="mutex race mother+clone (needs BJB_CLONE_UUID)")
    ap.add_argument("--cap-yuan", type=float, default=5.0)
    ap.add_argument("--max-minutes", type=float, default=0.0, help="0 = keep racing")
    ap.add_argument("--session", type=Path, default=Path("/tmp/workflow-final-spend.json"))
    ap.add_argument("--watchdog-log", type=Path, default=Path("/tmp/workflow-final-watchdog.log"))
    ap.add_argument("--power-off", action="store_true", help="shutdown keep disk (one uuid)")
    ap.add_argument("--power-off-fleet", action="store_true", help="shutdown mother+clone keep disk")
    ap.add_argument("--balance", action="store_true")
    args = ap.parse_args()
    ensure_auth_aliases()

    if args.balance:
        return power.balance()

    if args.power_off_fleet:
        rc = 0
        for u in sorted(power.kept_fleet_uuids()):
            r = power.power_off_keep_disk(u)
            rc = rc or r
        return rc

    uuid = power.instance_uuid(args.uuid or None)
    if args.power_off:
        return power.power_off_keep_disk(uuid)

    if not os.environ.get("AUTODL_TOKEN") and not power.web_authorization() and not power.dev_token():
        print("NEED_TOKEN export AUTODL_TOKEN=<web JWT or developer token>", flush=True)
        return 4

    seed_cap(args.session, args.cap_yuan)
    wd = start_watchdog(args.session, args.watchdog_log, max_wall_min=max(args.max_minutes, 90.0))
    print(f"WATCHDOG pid={wd.pid} session={args.session}", flush=True)

    dual = args.dual or bool(power.clone_uuid())
    candidates = fleet_uuids(args.uuid or None, dual=dual)
    auth = power.web_authorization()
    if dual and len(candidates) > 1 and auth:
        # pre-off both so we start from a clean mutex
        for u, label in candidates:
            print(f"PRE_OFF {label} {u}", flush=True)
            power.power_off_keep_disk(u, auth)
        rc, winner = race_dual(candidates, max_minutes=args.max_minutes, auth=auth)
        print(f"RACE_BOOT dual rc={rc} winner={winner}", flush=True)
        return rc

    # single-machine fallback
    rc = power.ensure_on(candidates[0][0], max_minutes=args.max_minutes)
    print(f"RACE_BOOT single uuid={candidates[0][0]} rc={rc}", flush=True)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
