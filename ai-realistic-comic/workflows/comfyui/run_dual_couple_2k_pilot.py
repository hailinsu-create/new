#!/usr/bin/env python3
"""Dual-race 2K upscale for USER_LOCKED plates + four R4 raws under same ¥3 session.

Continues DUAL_SESSION_START_BAL (default 56.15 from prior four-shot). Prefer 592.
Signal/finally + independent watchdog always shutdown_fleet; pull *-2k.png ASAP.
"""
from __future__ import annotations

import atexit
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402
import bringup_and_run as bring  # noqa: E402
import dual_collab_run as dual  # noqa: E402
import spend_cap as spend_cap  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
UPSCALE_REL = "workflows/comfyui/run_couple_2k_upscale.py"
WATCHDOG_REL = "workflows/comfyui/autodl_watchdog.py"

OUT = Path("/opt/cursor/artifacts/dual-couple-2k")
FOX_OUT = Path("/opt/cursor/artifacts/fox-couple")
ELENA_OUT = Path("/opt/cursor/artifacts/elena-couple")
STORE_FOX = Path("/cursor/stores/self/artifacts/fox-couple")
STORE_ELENA = Path("/cursor/stores/self/artifacts/elena-couple")
STORE_2K = Path("/cursor/stores/self/artifacts/dual-couple-2k")
REMOTE_OUT = "/root/autodl-tmp/dual-couple-2k-out"
REMOTE_INPUT = "/root/autodl-tmp/dual-couple-2k-input"

JOBS = [
    {
        "stem": "USER_LOCKED_lin-gu-C",
        "local": ROOT / "library/stills/fox-couple/USER_LOCKED_lin-gu-C.jpg",
        "bucket": "fox",
    },
    {
        "stem": "USER_LOCKED_elena-C",
        "local": ROOT / "library/stills/elena-couple/USER_LOCKED_elena-C.jpg",
        "bucket": "elena",
    },
    {
        "stem": "lin-gu-embrace-nude",
        "local": FOX_OUT / "lin-gu-embrace-nude-r4-raw.png",
        "bucket": "fox",
    },
    {
        "stem": "lin-gu-embrace-torn",
        "local": FOX_OUT / "lin-gu-embrace-torn-r4-raw.png",
        "bucket": "fox",
    },
    {
        "stem": "elena-couple-nude",
        "local": ELENA_OUT / "elena-couple-nude-r4-raw.png",
        "bucket": "elena",
    },
    {
        "stem": "elena-couple-torn",
        "local": ELENA_OUT / "elena-couple-torn-r4-raw.png",
        "bucket": "elena",
    },
]

CAP_YUAN = 3.0
DEFAULT_SESSION_START = 56.15
STUCK_MIN = 12.0
SESSION_CAP = OUT / "SPEND_CAP_SESSION.json"
WATCHDOG_LOG = OUT / "watchdog.log"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()

_SHUTDOWN_DONE = False
_WATCHDOG_PROC: subprocess.Popen | None = None


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/dual-couple-2k.log")):
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as fh:
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


def hard_shutdown(reason: str) -> None:
    global _SHUTDOWN_DONE
    if _SHUTDOWN_DONE:
        return
    _SHUTDOWN_DONE = True
    log(f"HARD_SHUTDOWN reason={reason}")
    try:
        power.shutdown_fleet()
    except Exception as exc:  # noqa: BLE001
        log(f"SHUTDOWN_ERR {exc}")
    bal = balance_yuan()
    log(f"BAL_AFTER_SHUTDOWN {bal:.2f}")


def _signal_handler(signum, _frame) -> None:
    hard_shutdown(f"signal:{signum}")
    raise SystemExit(128 + int(signum))


def install_signal_handlers() -> None:
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        try:
            signal.signal(sig, _signal_handler)
        except Exception:
            pass
    atexit.register(lambda: hard_shutdown("atexit"))


def start_watchdog() -> None:
    global _WATCHDOG_PROC
    cmd = [
        sys.executable,
        str(ROOT / WATCHDOG_REL),
        "--session",
        str(SESSION_CAP),
        "--log",
        str(WATCHDOG_LOG),
        "--poll-sec",
        "15",
        "--max-wall-min",
        "45",
    ]
    _WATCHDOG_PROC = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log(f"WATCHDOG_STARTED pid={_WATCHDOG_PROC.pid}")


def host_idle(auth: str, uuid: str) -> tuple[int, str, str]:
    d = dual.detail(auth, uuid, soft=True)
    m = d.get("machine") or {}
    return int(m.get("gpu_idle_num") or 0), str(d.get("status") or ""), str(m.get("machine_alias") or "")


def ensure_both_off(auth: str) -> None:
    for u in (power.MOTHER_UUID, power.clone_uuid()):
        if u and dual.instance_status(auth, u) == "running":
            power.power_off_keep_disk(u, auth)


def pick_and_power(auth: str, cap: spend_cap.SpendCap) -> tuple[str, str]:
    mother = power.MOTHER_UUID
    clone = power.clone_uuid()
    assert clone
    ensure_both_off(auth)
    started = time.time()
    attempt = 0
    while True:
        bal = balance_yuan()
        refuse = cap.refuse_power_on(bal)
        if refuse:
            hard_shutdown("cap_before_power")
            raise SystemExit(refuse)
        elapsed = (time.time() - started) / 60.0
        log(f"CARD_POLL {attempt} bal={bal:.2f} elapsed_min={elapsed:.1f} wait=unlimited race=dual")
        mi, ms, ma = host_idle(auth, mother)
        ci, cs, ca = host_idle(auth, clone)
        log(f"CARD_POLL {attempt} mother={ma}:{ms}:idle={mi} clone={ca}:{cs}:idle={ci}")
        order: list[tuple[str, str]] = []
        if ci > 0:
            order.append(("clone", clone))
        if mi > 0:
            order.append(("mother", mother))
        if not order:
            order = [("clone", clone), ("mother", mother)]
        for name, uuid in order:
            try:
                dual.ensure_peer_shutdown(auth, uuid)
            except Exception as exc:  # noqa: BLE001
                log(f"MUTEX_ERR {exc}")
                continue
            if dual.instance_status(auth, uuid) == "running":
                return name, uuid
            verdict, reply = power.power_on_once(uuid, auth)
            msg = str(reply.get("msg", ""))[:120]
            log(f"POWER_TRY {name} -> {verdict} {reply.get('code')} {msg}")
            if verdict == "success":
                dual.ensure_peer_shutdown(auth, uuid)
                log(f"CARD_WIN {name} after {elapsed:.1f}min")
                return name, uuid
            if verdict == "fatal":
                code = str(reply.get("code") or "")
                if code in ("ServerBusy",) or any(m in msg for m in ("服务正忙", "克隆锁定", "状态无法进行开机")):
                    continue
                hard_shutdown("power_fatal")
                raise SystemExit(f"POWER_FATAL {name} {reply}")
        attempt += 1
        time.sleep(30)


def wire_ssh(role: str, auth: str, uuid: str) -> None:
    if role == "mother":
        bring.SSH_ENV = Path("/cursor/stores/user/bjb-ssh.env")
    else:
        bring.SSH_ENV = dual.materialize_clone_ssh_env(auth, uuid)


def wait_running(auth: str, uuid: str, minutes: float = 8.0) -> None:
    deadline = time.monotonic() + minutes * 60
    n = 0
    while time.monotonic() < deadline:
        st = dual.instance_status(auth, uuid)
        log(f"BOOT {n} {st}")
        if st == "running":
            return
        n += 1
        time.sleep(10)
    hard_shutdown("boot_timeout")
    raise SystemExit(f"BOOT_TIMEOUT {uuid}")


def scp_to(local: Path, remote: str, timeout: int = 900) -> None:
    conn = bring.connection()
    scp = [
        "scp", "-i", str(bring.KEY_COPY), "-P", conn["port"],
        "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=30", str(local), f"{conn['user']}@{conn['host']}:{remote}",
    ]
    proc = subprocess.run(scp, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise SystemExit(f"SCP_FAIL {local.name} {proc.stderr[:200]!r}")
    log(f"SCP_OK {local.name}")


def upscale_model_present() -> bool:
    cmd = (
        "if test -s /root/autodl-tmp/comfyui/models/upscale_models/4x-UltraSharp.pth; "
        "then echo UPSCALE_PRESENT; else echo UPSCALE_MISSING; fi"
    )
    run = bring.ssh(cmd, check=False)
    return "UPSCALE_PRESENT" in run.stdout


def pull_2k() -> list[str]:
    got: list[str] = []
    scratch = Path("/tmp/dual-couple-2k-pull")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
    remote = subprocess.Popen(
        bring.ssh_argv([f"cd {REMOTE_OUT} && tar --exclude=work -cf - *.png *.json *.log 2>/dev/null || true"]),
        stdout=subprocess.PIPE,
    )
    subprocess.run(["tar", "-C", str(scratch), "-xf", "-"], stdin=remote.stdout, capture_output=True)
    if remote.stdout:
        remote.stdout.close()
    remote.wait()
    for source in scratch.rglob("*"):
        if not source.is_file():
            continue
        name = source.name
        if name.startswith("USER_LOCKED_lin") or name.startswith("lin-gu-"):
            dest_root = FOX_OUT
        elif name.startswith("USER_LOCKED_elena") or name.startswith("elena-couple-"):
            dest_root = ELENA_OUT
        else:
            dest_root = OUT
        dest = dest_root / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        # also mirror into OUT for the six-pack
        if name.endswith("-2k.png") or name.endswith("-2k.json") or name in ("UPSCALE_2K_SUMMARY.json", "gen-2k.log"):
            shutil.copyfile(source, OUT / name)
        if name.endswith("-2k.png"):
            got.append(name)
    shutil.rmtree(scratch, ignore_errors=True)
    if got:
        log(f"PULLED_2K {sorted(set(got))}")
    return got


def sync_stores() -> None:
    for src_root, store in (
        (FOX_OUT, STORE_FOX),
        (ELENA_OUT, STORE_ELENA),
        (OUT, STORE_2K),
    ):
        store.mkdir(parents=True, exist_ok=True)
        for source in src_root.rglob("*"):
            if not source.is_file():
                continue
            # only sync 2k-related + judge/meta for this pass from fox/elena
            rel = source.relative_to(src_root)
            if src_root in (FOX_OUT, ELENA_OUT) and "-2k" not in source.name and source.name not in (
                "VISUAL_JUDGE.json",
            ):
                if not source.name.endswith("-2k.png") and not source.name.endswith("-2k.json"):
                    continue
            dest = store / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            try:
                if dest.resolve() == source.resolve():
                    continue
            except OSError:
                pass
            shutil.copyfile(source, dest)
    log("STORE_SYNC ok")


def expected_names() -> list[str]:
    return [f"{j['stem']}-2k.png" for j in JOBS]


def remote_job_pulling(cmd: str, *, stuck_min: float, hard_min: float, cap: spend_cap.SpendCap) -> int:
    remote_log = f"{REMOTE_OUT}/gen-2k.log"
    launch = (
        f"mkdir -p {REMOTE_OUT} && cd {bring.REMOTE_ROOT} && "
        f"nohup bash -lc {shlex.quote(cmd)} > {remote_log} 2>&1 & echo $!"
    )
    run = bring.ssh(launch, check=True)
    pid = None
    for line in reversed(run.stdout.splitlines()):
        if line.strip().isdigit():
            pid = line.strip()
            break
    if not pid:
        raise SystemExit("NO_PID")
    log(f"REMOTE_PID gen-2k={pid}")
    start = time.monotonic()
    last_size = -1
    last_progress = time.monotonic()
    seen: set[str] = set()
    want = set(expected_names())
    while True:
        time.sleep(12)
        try:
            probe = bring.ssh(
                f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; "
                f"wc -c {remote_log} 2>/dev/null || echo 0; "
                f"tail -n 12 {remote_log} 2>/dev/null || true",
                check=False,
            )
        except SystemExit as exc:
            log(f"PROG_SSH_EXIT {exc}")
            pull_2k()
            time.sleep(8)
            continue
        alive = "ALIVE" in probe.stdout
        size = 0
        for line in probe.stdout.splitlines():
            parts = line.strip().split()
            if parts and parts[0].isdigit():
                try:
                    size = int(parts[0])
                    break
                except ValueError:
                    pass
        tail = probe.stdout.strip().splitlines()[-1][:200] if probe.stdout.strip() else ""
        log(f"PROG gen-2k size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail}")
        new = pull_2k()
        for name in new:
            if name not in seen:
                seen.add(name)
                sync_stores()
        if size > last_size or new:
            last_size = max(last_size, size)
            last_progress = time.monotonic()
        bal = balance_yuan()
        if cap.boot_at and cap.boot_mono is None:
            cap.boot_mono = time.monotonic()
        if cap.breached(bal):
            log(f"CAP_HARD_KILL eff={cap.effective_spent(bal):.2f}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_2k()
            sync_stores()
            return 4
        have = {p.name for p in OUT.glob("*-2k.png")} | {p.name for p in FOX_OUT.glob("*-2k.png")} | {
            p.name for p in ELENA_OUT.glob("*-2k.png")
        }
        if want.issubset(have):
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_2k()
            sync_stores()
            return 0
        if not alive:
            end = bring.ssh(f"tail -n 200 {remote_log}", check=False)
            (OUT / "gen-2k.log").write_text(end.stdout, encoding="utf-8")
            pull_2k()
            sync_stores()
            if "COUPLE_2K_UPSCALE_DONE" in end.stdout or want.issubset(
                {p.name for p in OUT.glob("*-2k.png")}
                | {p.name for p in FOX_OUT.glob("*-2k.png")}
                | {p.name for p in ELENA_OUT.glob("*-2k.png")}
            ):
                return 0
            return 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log("STUCK_KILL")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_2k()
            sync_stores()
            return 2
        if time.monotonic() - start > hard_min * 60:
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_2k()
            sync_stores()
            return 3


def after_boot(auth: str, role: str, uuid: str, cap: spend_cap.SpendCap) -> None:
    bring.wait_ssh(12)
    bring.ship(True)
    cap.mark_boot()
    log(f"SPEND_CAP boot marked cap={CAP_YUAN} session_start={cap.start_bal}")
    bring.ssh(f"mkdir -p {REMOTE_INPUT} {REMOTE_OUT}", check=True)
    for rel in (UPSCALE_REL, "workflows/comfyui/comfy_util.py", "workflows/comfyui/spend_cap.py"):
        scp_to(ROOT / rel, f"{bring.REMOTE_ROOT}/{rel}")
    inputs = []
    for job in JOBS:
        local = job["local"]
        if not local.is_file():
            raise SystemExit(f"MISSING_LOCAL {local}")
        remote_name = f"{job['stem']}{local.suffix.lower()}"
        scp_to(local, f"{REMOTE_INPUT}/{remote_name}")
        inputs.append({"src": f"{REMOTE_INPUT}/{remote_name}", "stem": job["stem"]})
    inputs_path = OUT / "inputs.json"
    inputs_path.write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    scp_to(inputs_path, f"{REMOTE_OUT}/inputs.json")
    if upscale_model_present():
        log(f"UPSCALE_MODEL_SKIP role={role}")
    else:
        raise SystemExit("UPSCALE_MODEL_MISSING 4x-UltraSharp.pth")
    bring.restart_comfy()
    gen = (
        f"{bring.REMOTE_PY} -u {UPSCALE_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--inputs-json {shlex.quote(REMOTE_OUT + '/inputs.json')} --i-know-authorized "
        f"&& echo COUPLE_2K_UPSCALE_DONE"
    )
    log("UPSCALE_START six images to 2K")
    rc = remote_job_pulling(gen, stuck_min=STUCK_MIN, hard_min=40.0, cap=cap)
    pull_2k()
    sync_stores()
    if rc != 0:
        raise SystemExit(rc)
    log("UPSCALE_DONE")


def main() -> None:
    install_signal_handlers()
    OUT.mkdir(parents=True, exist_ok=True)
    FOX_OUT.mkdir(parents=True, exist_ok=True)
    ELENA_OUT.mkdir(parents=True, exist_ok=True)
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    bal_now = balance_yuan()
    start_bal = float(os.environ.get("DUAL_SESSION_START_BAL", str(DEFAULT_SESSION_START)))
    log(f"START commit={COMMIT[:12]} bal_now={bal_now:.2f} session_start={start_bal:.2f} cap={CAP_YUAN}")
    cap = spend_cap.SpendCap(
        start_bal=start_bal,
        cap_yuan=CAP_YUAN,
        session_path=SESSION_CAP,
        disk_reserve_yuan=0.50,
    )
    # Explicitly clear prior boot_at so watchdog wall clock resets on mark_boot.
    cap.boot_at = None
    cap.boot_mono = None
    cap.save()
    refuse = cap.refuse_power_on(bal_now)
    if refuse:
        raise SystemExit(refuse)
    start_watchdog()
    dual.refuse_third(auth)
    power.assert_fleet_cap()
    try:
        role, uuid = pick_and_power(auth, cap)
        log(f"WINNER {role} {uuid}")
        wait_running(auth, uuid)
        wire_ssh(role, auth, uuid)
        after_boot(auth, role, uuid, cap)
    finally:
        hard_shutdown("main_finally")
        sync_stores()
        end = balance_yuan()
        summary = {
            "commit": COMMIT,
            "pipeline": "dual_couple_2k_upscale",
            "session_start_bal": start_bal,
            "end_bal": end,
            "spent_cny_approx": max(0.0, start_bal - end),
            "cap_yuan": CAP_YUAN,
            "files": expected_names(),
            "have": sorted(
                {p.name for p in OUT.glob("*-2k.png")}
                | {p.name for p in FOX_OUT.glob("*-2k.png")}
                | {p.name for p in ELENA_OUT.glob("*-2k.png")}
            ),
        }
        (OUT / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        log(f"END bal={end:.2f} spent≈{summary['spent_cny_approx']:.2f} have={summary['have']}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        hard_shutdown("cli_shutdown")
    else:
        main()
