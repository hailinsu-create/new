#!/usr/bin/env python3
"""Race / boot helper with spend cap + watchdog (uses lib/ fleet helpers).

Requires AUTODL_TOKEN. For ordinary AutoDL containers, put the **web JWT** in
AUTODL_TOKEN (or also set AUTODL_WEB_AUTHORIZATION). Developer tokens only work
on Pro instances for power_on; balance still uses the developer API when available.
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


def ensure_auth_aliases() -> None:
    """Map the single AUTODL_TOKEN secret onto web JWT when needed."""
    tok = os.environ.get("AUTODL_TOKEN", "").strip()
    if tok and not os.environ.get("AUTODL_WEB_AUTHORIZATION"):
        # Ordinary containers need the web Authorization header; accept either form.
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


def main() -> int:
    ap = argparse.ArgumentParser(description="workflow-final race_boot")
    ap.add_argument("--uuid", default="", help="instance uuid (default mother / BJB_INSTANCE_UUID)")
    ap.add_argument("--cap-yuan", type=float, default=5.0)
    ap.add_argument("--max-minutes", type=float, default=0.0, help="0 = keep racing")
    ap.add_argument("--session", type=Path, default=Path("/tmp/workflow-final-spend.json"))
    ap.add_argument("--watchdog-log", type=Path, default=Path("/tmp/workflow-final-watchdog.log"))
    ap.add_argument("--power-off", action="store_true", help="shutdown keep disk and exit")
    ap.add_argument("--balance", action="store_true")
    args = ap.parse_args()
    ensure_auth_aliases()

    if args.balance:
        return power.balance()

    uuid = power.instance_uuid(args.uuid or None)
    if args.power_off:
        return power.power_off_keep_disk(uuid)

    if not os.environ.get("AUTODL_TOKEN") and not power.web_authorization() and not power.dev_token():
        print(
            "NEED_TOKEN export AUTODL_TOKEN=<web JWT or developer token>",
            flush=True,
        )
        return 4

    # seed spend session
    bal = -1.0
    try:
        # best-effort wallet read
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
        start_bal=bal if bal >= 0 else 0.0,
        cap_yuan=args.cap_yuan,
        session_path=args.session,
        boot_at=datetime.now(timezone.utc).isoformat(),
        boot_mono=time.monotonic(),
    )
    cap.save()
    wd = start_watchdog(args.session, args.watchdog_log, max_wall_min=max(args.max_minutes, 90.0))
    print(f"WATCHDOG pid={wd.pid} session={args.session}", flush=True)
    rc = power.ensure_on(uuid, max_minutes=args.max_minutes)
    print(f"RACE_BOOT uuid={uuid} rc={rc}", flush=True)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
