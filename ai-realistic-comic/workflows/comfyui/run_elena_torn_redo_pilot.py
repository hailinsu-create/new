#!/usr/bin/env python3
"""Elena torn seam redo pilot: ¥2 cap, dual-race, watchdog, multi-seed, then 2K.

Generates 3–4 seam-composited candidates, pulls ASAP, waits for PICK.json from
Cursor judge (or auto-timeout), UltraSharp-upsclaes winner to long-edge 2560,
then shutdown_fleet leave-disk.
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
SCRIPT_REL = "workflows/comfyui/run_elena_couple_torn_seam_r4.py"
UPSCALE_REL = "workflows/comfyui/run_couple_2k_upscale.py"
WATCHDOG_REL = "workflows/comfyui/autodl_watchdog.py"

OUT = Path("/opt/cursor/artifacts/elena-couple-torn-redo")
ELENA_OUT = Path("/opt/cursor/artifacts/elena-couple")
STORE = Path("/cursor/stores/self/artifacts/elena-couple-torn-redo")
STORE_ELENA = Path("/cursor/stores/self/artifacts/elena-couple")
REMOTE_OUT = "/root/autodl-tmp/elena-torn-seam-out"
REMOTE_INPUT = "/root/autodl-tmp/elena-torn-seam-input"
PLATE = ROOT / "library/stills/elena-couple/USER_LOCKED_elena-C.jpg"
NUDE_RAW = Path("/opt/cursor/artifacts/elena-couple/elena-couple-nude-r4-raw.png")
NUDE_FALLBACK = ROOT / "library/stills/elena-couple/elena-couple-nude-r4-raw-usable.png"
PICK = OUT / "PICK.json"

CAP_YUAN = 2.0
STUCK_MIN = 12.0
PICK_WAIT_MIN = 12.0
SESSION_CAP = OUT / "SPEND_CAP_SESSION.json"
WATCHDOG_LOG = OUT / "watchdog.log"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
SEEDS = "20261031,20261032,20261033,20261034"

_SHUTDOWN_DONE = False
_WATCHDOG_PROC: subprocess.Popen | None = None


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/elena-torn-seam.log")):
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
    log(f"BAL_AFTER_SHUTDOWN {balance_yuan():.2f}")


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
        "50",
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
        log(f"CARD_POLL {attempt} bal={bal:.2f} elapsed_min={elapsed:.1f} race=dual")
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


def models_present() -> bool:
    cmd = (
        "if test -s /root/autodl-tmp/comfyui/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/loras/qwen-edit-remove-clothes.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/upscale_models/4x-UltraSharp.pth; "
        "then echo MODELS_PRESENT; else echo MODELS_MISSING; fi"
    )
    return "MODELS_PRESENT" in bring.ssh(cmd, check=False).stdout


def pull_outs() -> list[str]:
    got: list[str] = []
    scratch = Path("/tmp/elena-torn-seam-pull")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
    remote = subprocess.Popen(
        bring.ssh_argv([f"cd {REMOTE_OUT} && tar --exclude=work -cf - *.png *.webp *.json *.log 2>/dev/null || true"]),
        stdout=subprocess.PIPE,
    )
    subprocess.run(["tar", "-C", str(scratch), "-xf", "-"], stdin=remote.stdout, capture_output=True)
    if remote.stdout:
        remote.stdout.close()
    remote.wait()
    for source in scratch.rglob("*"):
        if not source.is_file():
            continue
        dest = OUT / source.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        if source.name.endswith(".png") and (
            source.name.startswith("elena-couple-torn-s") or source.name.endswith("-2k.png")
        ):
            got.append(source.name)
            # mirror official candidates into elena-couple artifacts too
            if source.name.endswith(".png") and "-seam-mask" not in source.name:
                shutil.copyfile(source, ELENA_OUT / source.name)
    shutil.rmtree(scratch, ignore_errors=True)
    if got:
        log(f"PULLED {sorted(set(got))}")
    return got


def sync_stores() -> None:
    for src_root, store in ((OUT, STORE), (ELENA_OUT, STORE_ELENA)):
        store.mkdir(parents=True, exist_ok=True)
        for source in src_root.rglob("*"):
            if not source.is_file():
                continue
            if src_root == ELENA_OUT and not (
                source.name.startswith("elena-couple-torn") or source.name.endswith("VISUAL_JUDGE.json")
            ):
                continue
            dest = store / source.relative_to(src_root)
            dest.parent.mkdir(parents=True, exist_ok=True)
            try:
                if dest.resolve() == source.resolve():
                    continue
            except OSError:
                pass
            shutil.copyfile(source, dest)
    log("STORE_SYNC ok")


def list_candidates() -> list[Path]:
    return sorted(OUT.glob("elena-couple-torn-s*.png"))


def remote_job(cmd: str, *, done_token: str, stuck_min: float, hard_min: float, cap: spend_cap.SpendCap) -> int:
    remote_log = f"{REMOTE_OUT}/gen.log"
    launch = (
        f"mkdir -p {REMOTE_OUT} && cd {bring.REMOTE_ROOT} && "
        f"nohup bash -lc {shlex.quote(cmd)} > {remote_log} 2>&1 & echo $!"
    )
    run = bring.ssh(launch, check=True)
    pid = next((ln.strip() for ln in reversed(run.stdout.splitlines()) if ln.strip().isdigit()), None)
    if not pid:
        raise SystemExit("NO_PID")
    log(f"REMOTE_PID {pid}")
    start = time.monotonic()
    last_size = -1
    last_progress = time.monotonic()
    while True:
        time.sleep(12)
        try:
            probe = bring.ssh(
                f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; "
                f"wc -c {remote_log} 2>/dev/null || echo 0; "
                f"tail -n 8 {remote_log} 2>/dev/null || true",
                check=False,
            )
        except SystemExit as exc:
            log(f"PROG_SSH_EXIT {exc}")
            pull_outs(); sync_stores()
            time.sleep(8)
            continue
        alive = "ALIVE" in probe.stdout
        size = 0
        for line in probe.stdout.splitlines():
            parts = line.strip().split()
            if parts and parts[0].isdigit():
                try:
                    size = int(parts[0]); break
                except ValueError:
                    pass
        tail = probe.stdout.strip().splitlines()[-1][:200] if probe.stdout.strip() else ""
        log(f"PROG size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail}")
        new = pull_outs()
        if new:
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
            pull_outs(); sync_stores()
            return 4
        if not alive:
            end = bring.ssh(f"tail -n 200 {remote_log}", check=False)
            (OUT / "gen.log").write_text(end.stdout, encoding="utf-8")
            pull_outs(); sync_stores()
            return 0 if done_token in end.stdout or list_candidates() else 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log("STUCK_KILL")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_outs(); sync_stores()
            return 2
        if time.monotonic() - start > hard_min * 60:
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_outs(); sync_stores()
            return 3


def wait_pick(cap: spend_cap.SpendCap) -> dict | None:
    (OUT / "AWAITING_JUDGE.json").write_text(
        json.dumps(
            {
                "candidates": [p.name for p in list_candidates()],
                "criteria": [
                    "no human skin/hips/thighs on horse body or 鸾布",
                    "chest looks like thick torn metal plates + cloth strips, not wire cage",
                ],
                "write_pick_to": str(PICK),
                "example": {"usable": True, "stem": "elena-couple-torn-s20261021", "reason": "..."},
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    sync_stores()
    log(f"AWAITING_PICK up to {PICK_WAIT_MIN}min -> {PICK}")
    deadline = time.monotonic() + PICK_WAIT_MIN * 60
    while time.monotonic() < deadline:
        if cap.breached(balance_yuan()):
            log("CAP_DURING_PICK_WAIT")
            return None
        if PICK.is_file():
            data = json.loads(PICK.read_text(encoding="utf-8"))
            log(f"PICK_RECEIVED {data}")
            return data
        time.sleep(5)
    log("PICK_TIMEOUT")
    return None


def upscale_winner(stem: str, cap: spend_cap.SpendCap) -> Path:
    src_remote = f"{REMOTE_OUT}/{stem}.png"
    # ensure remote has the official composite
    local = OUT / f"{stem}.png"
    if not local.is_file():
        raise SystemExit(f"MISSING_WINNER {local}")
    scp_to(local, src_remote)
    inputs = [{"src": src_remote, "stem": "elena-couple-torn"}]
    inputs_path = OUT / "upscale-inputs.json"
    inputs_path.write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    scp_to(inputs_path, f"{REMOTE_OUT}/upscale-inputs.json")
    scp_to(ROOT / UPSCALE_REL, f"{bring.REMOTE_ROOT}/{UPSCALE_REL}")
    scp_to(ROOT / "workflows/comfyui/comfy_util.py", f"{bring.REMOTE_ROOT}/workflows/comfyui/comfy_util.py")
    gen = (
        f"{bring.REMOTE_PY} -u {UPSCALE_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--inputs-json {shlex.quote(REMOTE_OUT + '/upscale-inputs.json')} --i-know-authorized "
        f"&& echo ELENA_TORN_2K_DONE"
    )
    log("UPSCALE_START winner -> 2K")
    rc = remote_job(gen, done_token="ELENA_TORN_2K_DONE", stuck_min=10.0, hard_min=25.0, cap=cap)
    pull_outs(); sync_stores()
    if rc != 0:
        raise SystemExit(f"UPSCALE_RC {rc}")
    got = OUT / "elena-couple-torn-2k.png"
    if not got.is_file():
        raise SystemExit("MISSING_2K")
    return got


def after_boot(auth: str, role: str, uuid: str, cap: spend_cap.SpendCap) -> None:
    bring.wait_ssh(12)
    bring.ship(True)
    cap.mark_boot()
    log(f"SPEND_CAP boot marked cap={CAP_YUAN}")
    bring.ssh(f"mkdir -p {REMOTE_INPUT} {REMOTE_OUT}", check=True)
    for rel in (
        SCRIPT_REL,
        UPSCALE_REL,
        "workflows/comfyui/comfy_util.py",
        "workflows/comfyui/spend_cap.py",
        "workflows/comfyui/run_fox_centaur_community_r4.py",
        "workflows/comfyui/run_fox_centaur_semantic.py",
    ):
        scp_to(ROOT / rel, f"{bring.REMOTE_ROOT}/{rel}")
    scp_to(PLATE, f"{REMOTE_INPUT}/USER_LOCKED_elena-C.jpg")
    nude_local = NUDE_RAW if NUDE_RAW.is_file() else NUDE_FALLBACK
    if not nude_local.is_file():
        raise SystemExit(f"MISSING_NUDE {nude_local}")
    scp_to(nude_local, f"{REMOTE_INPUT}/elena-couple-nude-r4-raw.png")
    if not models_present():
        raise SystemExit("MODELS_MISSING")
    log(f"MODELS_OK role={role}")
    bring.restart_comfy()
    bring.ssh(f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u {SCRIPT_REL} --check-stack", check=True)
    gen = (
        f"{bring.REMOTE_PY} -u {SCRIPT_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--plate {shlex.quote(REMOTE_INPUT + '/USER_LOCKED_elena-C.jpg')} "
        f"--nude {shlex.quote(REMOTE_INPUT + '/elena-couple-nude-r4-raw.png')} "
        f"--seeds {shlex.quote(SEEDS)} --i-know-authorized "
        f"&& echo ELENA_TORN_SEAM_DONE"
    )
    log(f"GENERATE_START seeds={SEEDS}")
    rc = remote_job(gen, done_token="ELENA_TORN_SEAM_DONE", stuck_min=STUCK_MIN, hard_min=40.0, cap=cap)
    pull_outs(); sync_stores()
    if rc != 0 and not list_candidates():
        raise SystemExit(rc)
    pick = wait_pick(cap)
    if not pick or not pick.get("usable"):
        log("NO_USABLE_PICK skip upscale")
        (OUT / "NO_USABLE.json").write_text(json.dumps({"pick": pick}, indent=2) + "\n", encoding="utf-8")
        return
    stem = str(pick["stem"]).removesuffix(".png")
    upscale_winner(stem, cap)
    # promote official names
    src2k = OUT / "elena-couple-torn-2k.png"
    shutil.copyfile(src2k, ELENA_OUT / "elena-couple-torn-2k.png")
    official = OUT / f"{stem}.png"
    shutil.copyfile(official, OUT / "elena-couple-torn.png")
    shutil.copyfile(official, ELENA_OUT / "elena-couple-torn.png")
    sync_stores()
    log("REDO_DONE")


def main() -> None:
    install_signal_handlers()
    OUT.mkdir(parents=True, exist_ok=True)
    ELENA_OUT.mkdir(parents=True, exist_ok=True)
    if PICK.exists():
        PICK.unlink()
    if not PLATE.is_file():
        raise SystemExit(f"MISSING_PLATE {PLATE}")
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    bal_now = balance_yuan()
    start_bal = float(os.environ.get("ELENA_TORN_SESSION_START_BAL", bal_now))
    log(f"START commit={COMMIT[:12]} bal_now={bal_now:.2f} session_start={start_bal:.2f} cap={CAP_YUAN}")
    cap = spend_cap.SpendCap(
        start_bal=start_bal,
        cap_yuan=CAP_YUAN,
        session_path=SESSION_CAP,
        disk_reserve_yuan=0.50,
    )
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
        (OUT / "SUMMARY.json").write_text(
            json.dumps(
                {
                    "commit": COMMIT,
                    "pipeline": "elena_couple_torn_seam_redo",
                    "session_start_bal": start_bal,
                    "end_bal": end,
                    "spent_cny_approx": max(0.0, start_bal - end),
                    "cap_yuan": CAP_YUAN,
                    "candidates": [p.name for p in list_candidates()],
                    "pick": json.loads(PICK.read_text()) if PICK.is_file() else None,
                    "has_2k": (OUT / "elena-couple-torn-2k.png").is_file(),
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        log(f"END bal={end:.2f} spent≈{max(0.0, start_bal - end):.2f}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        hard_shutdown("cli_shutdown")
    else:
        main()
