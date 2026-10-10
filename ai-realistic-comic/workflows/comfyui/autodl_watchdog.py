#!/usr/bin/env python3
"""Independent AutoDL spend watchdog (separate process / tmux).

Does NOT depend on the pilot surviving. Reads SPEND_CAP_SESSION.json, polls wallet
and projected GPU from boot_at wall clock, and force shutdown_fleet on breach or
max wall minutes. Never power_on.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402
import spend_cap as spend_cap  # noqa: E402


def log(msg: str, log_path: Path) -> None:
    line = f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')} WATCHDOG {msg}"
    print(line, flush=True)
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def balance_yuan() -> float:
    token = power.dev_token()
    if not token:
        return -1.0
    _st, reply = power.post(power.DEV_BALANCE, {"Authorization": token}, {})
    raw = (reply.get("data") or {}).get("assets")
    if raw is None:
        return -1.0
    return float(raw) / 1000.0


def projected_from_boot_at(boot_at: str | None, payg_li: int) -> float:
    if not boot_at:
        return 0.0
    try:
        boot = datetime.fromisoformat(boot_at.replace("Z", "+00:00"))
    except ValueError:
        return 0.0
    hours = max(0.0, (datetime.now(timezone.utc) - boot.astimezone(timezone.utc)).total_seconds() / 3600.0)
    return hours * (payg_li / 1000.0)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", type=Path, required=True)
    ap.add_argument("--log", type=Path, default=Path("/tmp/autodl-watchdog.log"))
    ap.add_argument("--poll-sec", type=float, default=20.0)
    ap.add_argument("--max-wall-min", type=float, default=90.0, help="Hard wall clock since boot_at")
    args = ap.parse_args()
    log(f"START session={args.session} max_wall_min={args.max_wall_min}", args.log)
    while True:
        if not args.session.is_file():
            log("WAIT_SESSION", args.log)
            time.sleep(args.poll_sec)
            continue
        cap = spend_cap.SpendCap.load(args.session)
        if cap is None:
            time.sleep(args.poll_sec)
            continue
        bal = balance_yuan()
        # Watchdog uses wall-clock boot_at (survives pilot death / monotonic reset)
        proj = projected_from_boot_at(cap.boot_at, cap.payg_li_per_hour)
        disk = cap.disk_reserve_yuan if cap.boot_at else 0.0
        wallet = cap.wallet_spent(bal) if bal >= 0 else 0.0
        eff = max(wallet, proj + disk)
        wall_min = 0.0
        if cap.boot_at:
            try:
                boot = datetime.fromisoformat(cap.boot_at.replace("Z", "+00:00"))
                wall_min = (datetime.now(timezone.utc) - boot.astimezone(timezone.utc)).total_seconds() / 60.0
            except ValueError:
                wall_min = 0.0
        log(
            f"tick bal={bal:.2f} wallet={wallet:.2f} proj={proj:.2f} disk={disk:.2f} "
            f"eff={eff:.2f} cap={cap.cap_yuan:.2f} wall_min={wall_min:.1f}",
            args.log,
        )
        breach = eff >= cap.cap_yuan
        wall_breach = bool(cap.boot_at) and wall_min >= args.max_wall_min
        if breach or wall_breach:
            reason = "CAP" if breach else "WALL"
            log(f"HARD_STOP_{reason} shutdown_fleet", args.log)
            try:
                power.shutdown_fleet()
            except Exception as exc:  # noqa: BLE001
                log(f"SHUTDOWN_ERR {exc}", args.log)
            # keep looping a few times to ensure off
            for _ in range(6):
                time.sleep(10)
                try:
                    power.shutdown_fleet()
                except Exception:
                    pass
            log("EXIT_AFTER_STOP", args.log)
            raise SystemExit(0)
        time.sleep(args.poll_sec)


if __name__ == "__main__":
    main()
