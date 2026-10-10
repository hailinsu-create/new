"""Dual couple R4 pilot: LinxGu + Elena male, four RAW shots, one boot.

2026-10-11 auth:
  - USER_LOCKED plates only
  - dual race mutex; unlimited wait; cap ¥3 (GPU projection + disk reserve)
  - independent watchdog tmux; signal/finally always shutdown_fleet
  - pull each raw ASAP; judge offline after shutdown
  - no grok.com; never power_on after cap breach
"""
from __future__ import annotations

import atexit
import hashlib
import json
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
FOX_SCRIPT_REL = "workflows/comfyui/run_fox_couple_r4.py"
ELENA_SCRIPT_REL = "workflows/comfyui/run_elena_couple_r4.py"
INSTALL_REL = "workflows/comfyui/install_r4_qwen.sh"
WATCHDOG_REL = "workflows/comfyui/autodl_watchdog.py"

OUT = Path("/opt/cursor/artifacts/dual-couple")
FOX_OUT = Path("/opt/cursor/artifacts/fox-couple")
ELENA_OUT = Path("/opt/cursor/artifacts/elena-couple")
STORE_FOX = Path("/cursor/stores/self/artifacts/fox-couple")
STORE_ELENA = Path("/cursor/stores/self/artifacts/elena-couple")
REMOTE_OUT = "/root/autodl-tmp/dual-couple-out"
REMOTE_INPUT = "/root/autodl-tmp/dual-couple-input"

FOX_PLATE = ROOT / "library/stills/fox-couple/lin-gu-embrace-clothed.png"
ELENA_PLATE = ROOT / "library/stills/elena-couple/elena-couple-clothed.png"
FOX_LOCK = ROOT / "library/stills/fox-couple/POSE_LOCKED.json"
ELENA_LOCK = ROOT / "library/stills/elena-couple/POSE_LOCKED.json"
FOX_SRC = ROOT / "library/stills/fox-couple/USER_LOCKED_lin-gu-C.jpg"
ELENA_SRC = ROOT / "library/stills/elena-couple/USER_LOCKED_elena-C.jpg"

CAP_YUAN = 3.0
STUCK_MIN = 15.0
SESSION_CAP = OUT / "SPEND_CAP_SESSION.json"
WATCHDOG_LOG = OUT / "watchdog.log"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()

_SHUTDOWN_DONE = False
_WATCHDOG_PROC: subprocess.Popen | None = None


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/dual-couple-pilot.log")):
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


def require_plates() -> None:
    from PIL import Image

    for src, plate, lock in (
        (FOX_SRC, FOX_PLATE, FOX_LOCK),
        (ELENA_SRC, ELENA_PLATE, ELENA_LOCK),
    ):
        if not src.is_file():
            raise SystemExit(f"MISSING_USER_LOCKED {src}")
        if not lock.is_file() or not json.loads(lock.read_text()).get("locked"):
            raise SystemExit(f"POSE_NOT_LOCKED {lock}")
        Image.open(src).convert("RGB").save(plate)
    log("PLATES_OK user_locked installed")


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
        "75",
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
        if mi > 0:
            order.append(("mother", mother))
        if ci > 0:
            order.append(("clone", clone))
        if not order:
            order = [("mother", mother), ("clone", clone)]
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
        "&& test -s /root/autodl-tmp/comfyui/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/vae/qwen_image_vae.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/loras/qwen-edit-remove-clothes.safetensors "
        "&& test -s /root/autodl-tmp/comfyui/models/loras/Qwen-Image-Edit-2511-Object-Remover.safetensors; "
        "then echo MODELS_PRESENT; else echo MODELS_MISSING; fi"
    )
    run = bring.ssh(cmd, check=False)
    return "MODELS_PRESENT" in run.stdout


def pull_raws() -> list[str]:
    """Pull any new *-r4-raw.png from remote into local artifact dirs."""
    got: list[str] = []
    scratch = Path("/tmp/dual-couple-pull")
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
        name = source.name
        if name.startswith("lin-gu-"):
            dest_root = FOX_OUT
        elif name.startswith("elena-couple-"):
            dest_root = ELENA_OUT
        else:
            dest_root = OUT
        dest = dest_root / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        if name.endswith("-r4-raw.png"):
            got.append(name)
    shutil.rmtree(scratch, ignore_errors=True)
    if got:
        log(f"PULLED_RAWS {got}")
    return got


def sync_stores() -> None:
    for src_root, store in ((FOX_OUT, STORE_FOX), (ELENA_OUT, STORE_ELENA), (OUT, Path("/cursor/stores/self/artifacts/dual-couple"))):
        store.mkdir(parents=True, exist_ok=True)
        for source in src_root.rglob("*"):
            if not source.is_file():
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


def remote_job_pulling(cmd: str, *, expected_raws: list[str], stuck_min: float, hard_min: float, cap: spend_cap.SpendCap) -> int:
    remote_log = f"{REMOTE_OUT}/gen-dual.log"
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
    log(f"REMOTE_PID gen-dual={pid}")
    start = time.monotonic()
    last_size = -1
    last_progress = time.monotonic()
    seen: set[str] = set()
    while True:
        time.sleep(15)
        try:
            probe = bring.ssh(
                f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; "
                f"wc -c {remote_log} 2>/dev/null || echo 0; "
                f"tail -n 12 {remote_log} 2>/dev/null || true",
                check=False,
            )
        except SystemExit as exc:
            log(f"PROG_SSH_EXIT {exc}")
            pull_raws()
            time.sleep(10)
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
        log(f"PROG gen-dual size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail}")
        # incremental pull whenever a new RAW_OK appears
        new = pull_raws()
        for name in new:
            if name not in seen:
                seen.add(name)
                sync_stores()
        if size > last_size or new:
            last_size = max(last_size, size)
            last_progress = time.monotonic()
        bal = balance_yuan()
        # wall projection via boot_at
        if cap.boot_at and cap.boot_mono is None:
            cap.boot_mono = time.monotonic()  # best effort if restarted
        if cap.breached(bal):
            log(f"CAP_HARD_KILL eff={cap.effective_spent(bal):.2f}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_raws(); sync_stores()
            return 4
        if not alive:
            end = bring.ssh(f"tail -n 200 {remote_log}", check=False)
            (OUT / "gen-dual.log").write_text(end.stdout, encoding="utf-8")
            pull_raws(); sync_stores()
            if "DUAL_COUPLE_R4_DONE" in end.stdout or all(
                (FOX_OUT / f"{s}-r4-raw.png").is_file() or (ELENA_OUT / f"{s}-r4-raw.png").is_file()
                for s in expected_raws
            ):
                return 0
            # also accept if all four files present locally
            have = [p.name for p in list(FOX_OUT.glob("*-r4-raw.png")) + list(ELENA_OUT.glob("*-r4-raw.png"))]
            if len([h for h in have if any(h.startswith(s) for s in ("lin-gu-embrace-nude", "lin-gu-embrace-torn", "elena-couple-nude", "elena-couple-torn"))]) >= 4:
                return 0
            return 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log("STUCK_KILL")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_raws(); sync_stores()
            return 2
        if time.monotonic() - start > hard_min * 60:
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            pull_raws(); sync_stores()
            return 3


def after_boot(auth: str, role: str, uuid: str, cap: spend_cap.SpendCap) -> None:
    bring.wait_ssh(12)
    bring.ship(True)
    cap.mark_boot()
    log(f"SPEND_CAP boot marked cap={CAP_YUAN}")
    bring.ssh(f"mkdir -p {REMOTE_INPUT} {REMOTE_OUT}", check=True)
    scp_to(FOX_PLATE, f"{REMOTE_INPUT}/lin-gu-embrace-clothed.png")
    scp_to(ELENA_PLATE, f"{REMOTE_INPUT}/elena-couple-clothed.png")
    # ship scripts explicitly
    for rel in (FOX_SCRIPT_REL, ELENA_SCRIPT_REL, "workflows/comfyui/spend_cap.py"):
        local = ROOT / rel
        scp_to(local, f"{bring.REMOTE_ROOT}/{rel}")
    if models_present():
        log(f"MODELS_SKIP role={role}")
    else:
        log("DOWNLOAD_START")
        alias = host_idle(auth, uuid)[2]
        dl = (
            f"export HF_ENDPOINT=https://hf-mirror.com COMFY={bring.COMFY_DIR} "
            f"OUT_JSON={REMOTE_OUT}/MODEL_HOST.json STUCK_SEC=900 "
            f"AUTODL_MACHINE_ALIAS={shlex.quote(alias)} AUTODL_INSTANCE_UUID={uuid}; "
            f"bash {bring.REMOTE_ROOT}/{INSTALL_REL}"
        )
        # reuse remote_job_pulling style simple wait
        launch = f"mkdir -p {REMOTE_OUT} && cd {bring.REMOTE_ROOT} && nohup bash -lc {shlex.quote(dl)} > {REMOTE_OUT}/download.log 2>&1 & echo $!"
        run = bring.ssh(launch, check=True)
        pid = next((ln.strip() for ln in reversed(run.stdout.splitlines()) if ln.strip().isdigit()), None)
        if not pid:
            raise SystemExit("NO_DL_PID")
        t0 = time.monotonic()
        while time.monotonic() - t0 < 150 * 60:
            time.sleep(20)
            pr = bring.ssh(f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; tail -n 3 {REMOTE_OUT}/download.log", check=False)
            log(f"PROG download | {pr.stdout.strip().splitlines()[-1][:160] if pr.stdout.strip() else ''}")
            if cap.breached(balance_yuan()):
                bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
                raise SystemExit("CAP_DURING_DOWNLOAD")
            if "DEAD" in pr.stdout:
                break
        if not models_present():
            raise SystemExit("MODELS_STILL_MISSING")
    bring.restart_comfy()
    bring.ssh(f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u {FOX_SCRIPT_REL} --check-stack", check=True)
    # one remote bash that runs fox then elena
    gen = (
        f"{bring.REMOTE_PY} -u {FOX_SCRIPT_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--plate {shlex.quote(REMOTE_INPUT + '/lin-gu-embrace-clothed.png')} --i-know-authorized "
        f"&& {bring.REMOTE_PY} -u {ELENA_SCRIPT_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--plate {shlex.quote(REMOTE_INPUT + '/elena-couple-clothed.png')} --i-know-authorized "
        f"&& echo DUAL_COUPLE_R4_DONE"
    )
    log("GENERATE_START lin+elena nude+torn")
    expected = ["lin-gu-embrace-nude", "lin-gu-embrace-torn", "elena-couple-nude", "elena-couple-torn"]
    rc = remote_job_pulling(gen, expected_raws=expected, stuck_min=STUCK_MIN, hard_min=70.0, cap=cap)
    pull_raws(); sync_stores()
    if rc != 0:
        raise SystemExit(rc)
    log("GENERATE_DONE awaiting offline visual judge")


def main() -> None:
    install_signal_handlers()
    OUT.mkdir(parents=True, exist_ok=True)
    FOX_OUT.mkdir(parents=True, exist_ok=True)
    ELENA_OUT.mkdir(parents=True, exist_ok=True)
    require_plates()
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    start_bal = balance_yuan()
    log(f"START commit={COMMIT[:12]} bal={start_bal:.2f} cap={CAP_YUAN}")
    cap = spend_cap.SpendCap(
        start_bal=start_bal,
        cap_yuan=CAP_YUAN,
        session_path=SESSION_CAP,
        disk_reserve_yuan=0.50,  # one machine for ~hours; dual-day settle not charged mid-run
    )
    cap.save()
    refuse = cap.refuse_power_on(start_bal)
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
        (OUT / "AWAITING_JUDGE.json").write_text(
            json.dumps(
                {
                    "commit": COMMIT,
                    "start_bal": start_bal,
                    "end_bal": end,
                    "cap_yuan": CAP_YUAN,
                    "note": "offline visual judge; machine shut down",
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        log(f"END bal={end:.2f} spent≈{max(0.0, start_bal - end):.2f}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        hard_shutdown("cli_shutdown")
    else:
        main()
