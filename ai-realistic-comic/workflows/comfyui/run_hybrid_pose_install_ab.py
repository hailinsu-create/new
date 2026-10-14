#!/usr/bin/env python3
"""Hybrid pose install + small A/B (Route C humanoid + R4 torn prompt A/B).

Policy: 791 first, else 592; never both on; ¥5 spend_cap + watchdog; shutdown keep disk.
Docs/PR must not embed nudes — only paths under /opt/cursor/artifacts/hybrid-pose-ab/.
"""
from __future__ import annotations

import atexit
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WF = Path(__file__).resolve().parent
ART = Path("/opt/cursor/artifacts/hybrid-pose-ab")
SESSION = ART / "SPEND_CAP_SESSION.json"
CAP_YUAN = 5.0
MOTHER = "359a49a1c3-4cda10df"
CLONE = os.environ.get("BJB_CLONE_UUID", "683045898b-caaa5b8f")

sys.path.insert(0, str(WF))
from autodl_power import (  # noqa: E402
    ensure_on,
    instance_uuid,
    power_off,
    power_on_once,
    shutdown_fleet,
    web_authorization,
)
from spend_cap import SpendCap  # noqa: E402


def bal() -> float:
    out = subprocess.check_output([sys.executable, str(WF / "autodl_power.py"), "balance"], text=True)
    m = re.search(r"yuan=([0-9.]+)", out)
    if not m:
        raise SystemExit(f"BALANCE_PARSE {out!r}")
    return float(m.group(1))


def log(msg: str) -> None:
    print(msg, flush=True)
    ART.mkdir(parents=True, exist_ok=True)
    with (ART / "run.log").open("a", encoding="utf-8") as f:
        f.write(msg + "\n")


def shutdown_safe(reason: str) -> None:
    log(f"SHUTDOWN reason={reason}")
    try:
        shutdown_fleet()
    except Exception as exc:  # noqa: BLE001
        log(f"SHUTDOWN_ERR {exc}")


def main() -> int:
    ART.mkdir(parents=True, exist_ok=True)
    start = bal()
    cap = SpendCap(start_bal=start, cap_yuan=CAP_YUAN, session_path=SESSION)
    cap.save()
    refuse = cap.refuse_power_on(start)
    if refuse:
        log(refuse)
        return 3

    auth = web_authorization()
    if not auth:
        log("NEED_AUTODL_WEB_AUTHORIZATION refresh JWT in autodl-web-auth.env")
        return 4

    def _stop(*_a):
        shutdown_safe("signal")
        raise SystemExit(130)

    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGHUP, _stop)
    atexit.register(lambda: shutdown_safe("atexit"))

    # Mutex: force clone off, then mother
    log("MUTEX power-off clone first")
    power_off(CLONE, auth)
    v, reply = power_on_once(MOTHER, auth)
    log(f"MOTHER power_on_once {v} {reply.get('code')} {reply.get('msg')}")
    active = MOTHER
    if v != "success":
        if str(reply.get("code")) == "AuthorizeFailed":
            log("AUTH_BLOCKED web JWT rejected; no GPU burn")
            return 4
        log("MOTHER unavailable; ensuring clone after mother off")
        power_off(MOTHER, auth)
        code = ensure_on(CLONE, max_minutes=60)
        if code != 0:
            log(f"CLONE ensure_on failed {code}")
            shutdown_safe("no_gpu")
            return code or 5
        active = CLONE

    cap.mark_boot()
    # Start watchdog
    wd = subprocess.Popen(
        [
            sys.executable,
            str(WF / "autodl_watchdog.py"),
            "--session",
            str(SESSION),
            "--max-wall-min",
            "90",
        ]
    )
    log(f"WATCHDOG pid={wd.pid} active={active}")

    # Remaining work is SSH install — print handoff for operator scripts
    (ART / "ACTIVE_UUID.txt").write_text(active + "\n", encoding="utf-8")
    log(
        "NEXT: SSH install Qwen-Image 2.1 int8 trio + NSFW LoRAs + VNCCS; "
        "df before/after; Route C edit 1-2 clothed; R4 torn A/B; pull; shutdown."
    )
    log("Orchestrator stops after boot gate when install script not yet remote-wired.")
    # Soft stop: caller continues with remote steps; we keep process for watchdog until remote done.
    # For this commit, exit 0 after recording boot success so follow-up can SSH.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
