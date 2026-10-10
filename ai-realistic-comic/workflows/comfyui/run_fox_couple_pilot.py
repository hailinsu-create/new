"""Fox-couple R4 nude+torn pilot (AutoDL dual race).

2026-10-10 19:28: DO NOT boot until user locks clothed pose.
Requires library/stills/fox-couple/POSE_LOCKED.json (or --pose-locked) plus local plate.
Clothed plate must come from Cursor GenerateImage (offline); never GenerateImage on AutoDL.

User 2026-10-10 18:59 (once authorized after pose lock):
  - dual race mutex; unlimited card wait; cap ¥4
  - R4 raw-official for Lin wardrobe only; lock Gu/tails/bg
  - artifacts /opt/cursor/artifacts/fox-couple/ + Store
  - no grok.com
"""
from __future__ import annotations

import hashlib
import json
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402
import bringup_and_run as bring  # noqa: E402
import dual_collab_run as dual  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCRIPT_REL = "workflows/comfyui/run_fox_couple_r4.py"
INSTALL_REL = "workflows/comfyui/install_r4_qwen.sh"
LOCAL_SCRIPT = ROOT / SCRIPT_REL
OUT = Path("/opt/cursor/artifacts/fox-couple")
STORE = Path("/cursor/stores/self/artifacts/fox-couple")
REMOTE_SCRIPT = f"{bring.REMOTE_ROOT}/{SCRIPT_REL}"
REMOTE_OUT = "/root/autodl-tmp/fox-couple-out"
REMOTE_INPUT = "/root/autodl-tmp/fox-couple-input"
LOCAL_PLATE = ROOT / "library/stills/fox-couple/lin-gu-embrace-clothed.png"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()
CAP_YUAN = 4.0
STUCK_MIN = 15.0

POSE_LOCK = ROOT / "library/stills/fox-couple/POSE_LOCKED.json"


def require_pose_locked() -> None:
    """Refuse AutoDL boot until user picked clothed pose (2026-10-10 19:28)."""
    if "--pose-locked" in sys.argv:
        return
    if POSE_LOCK.is_file():
        data = json.loads(POSE_LOCK.read_text(encoding="utf-8"))
        if data.get("locked") is True:
            return
    raise SystemExit(
        "POSE_NOT_LOCKED: clothed pose still pending user pick. "
        "Use Cursor GenerateImage offline; write POSE_LOCKED.json or pass --pose-locked only after authorization."
    )



def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/fox-couple-pilot.log")):
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
    _status, reply = power.post(power.DEV_BALANCE, {"Authorization": token}, {})
    raw = (reply.get("data") or {}).get("assets")
    if raw is None:
        return -1.0
    return float(raw) / 1000.0


def host_idle(auth: str, uuid: str) -> tuple[int, str, str]:
    d = dual.detail(auth, uuid, soft=True)
    m = d.get("machine") or {}
    return int(m.get("gpu_idle_num") or 0), str(d.get("status") or ""), str(m.get("machine_alias") or "")


def ensure_both_off(auth: str) -> None:
    for u in (power.MOTHER_UUID, power.clone_uuid()):
        if not u:
            continue
        if dual.instance_status(auth, u) == "running":
            power.power_off_keep_disk(u, auth)


def pick_and_power(auth: str) -> tuple[str, str]:
    mother = power.MOTHER_UUID
    clone = power.clone_uuid()
    assert clone
    ensure_both_off(auth)
    started = time.time()
    attempt = 0
    while True:
        bal = balance_yuan()
        elapsed = (time.time() - started) / 60.0
        log(f"CARD_POLL {attempt} bal={bal:.2f} elapsed_min={elapsed:.1f} wait=unlimited race=dual")
        if (OUT / "AWAITING_JUDGE.json").exists():
            start_bal = float(json.loads((OUT / "AWAITING_JUDGE.json").read_text()).get("start_bal", bal))
            if bal >= 0 and start_bal - bal >= CAP_YUAN:
                raise SystemExit(f"CAP_DURING_CARD_WAIT spent>={CAP_YUAN}")
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
    raise SystemExit(f"BOOT_TIMEOUT {uuid}")


def remote_sha() -> str:
    run = bring.ssh(f"sha256sum {shlex.quote(REMOTE_SCRIPT)}", check=True)
    for line in run.stdout.splitlines():
        parts = line.strip().split()
        if parts and len(parts[0]) == 64:
            return parts[0]
    raise SystemExit("REMOTE_SHA_PARSE_FAIL")


def models_present() -> bool:
    files = [
        f"{bring.COMFY_DIR}/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors",
        f"{bring.COMFY_DIR}/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
        f"{bring.COMFY_DIR}/models/vae/qwen_image_vae.safetensors",
    ]
    checks = " && ".join(f"test -s {shlex.quote(f)}" for f in files)
    probe = bring.ssh(f"if {checks}; then echo MODELS_PRESENT; else echo MODELS_MISSING; fi", check=False)
    log(f"MODEL_PROBE {probe.stdout.strip()[:200]}")
    return "MODELS_PRESENT" in probe.stdout


def scp_to(local: Path, remote: str, timeout: int = 900, retries: int = 3) -> None:
    conn = bring.connection()
    scp = [
        "scp", "-i", str(bring.KEY_COPY), "-P", conn["port"],
        "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=30", str(local), f"{conn['user']}@{conn['host']}:{remote}",
    ]
    last = ""
    for attempt in range(1, retries + 1):
        try:
            proc = subprocess.run(scp, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            last = "timeout"
            log(f"SCP_RETRY {local.name} {attempt}/{retries} timeout")
            continue
        if proc.returncode == 0:
            log(f"SCP_OK {local.name}")
            return
        last = proc.stderr[:200]
        log(f"SCP_RETRY {local.name} {attempt} {last!r}")
        time.sleep(5)
    raise SystemExit(f"SCP_FAIL {local.name} {last!r}")


def remote_job(cmd: str, *, log_name: str, stuck_min: float = STUCK_MIN, hard_min: float = 90.0) -> int:
    remote_log = f"{REMOTE_OUT}/{log_name}.log"
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
    log(f"REMOTE_PID {log_name}={pid}")
    start = time.monotonic()
    last_size = -1
    last_progress = time.monotonic()
    start_bal = float(json.loads((OUT / "AWAITING_JUDGE.json").read_text()).get("start_bal", -1)) if (OUT / "AWAITING_JUDGE.json").exists() else -1.0
    while True:
        time.sleep(20)
        probe = bring.ssh(
            f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; "
            f"wc -c {remote_log} 2>/dev/null || echo 0; "
            f"tail -n 8 {remote_log} 2>/dev/null || true",
            check=False,
        )
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
        log(f"PROG {log_name} size={size} alive={'ALIVE' if alive else 'DEAD'} | {probe.stdout.strip().splitlines()[-1][:200] if probe.stdout.strip() else ''}")
        if size > last_size:
            last_size = size
            last_progress = time.monotonic()
        if not alive:
            end = bring.ssh(f"tail -n 120 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(end.stdout, encoding="utf-8")
            if any(tok in end.stdout for tok in ("COUPLE_R4_DONE", "RAW_OK", "R4_STACK_OK", "R4_MODELS_OK", "R4_MODELS_DONE")):
                return 0
            return 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log(f"STUCK_KILL {log_name}")
            bring.ssh(f"kill {pid} 2>/dev/null; sleep 1; kill -9 {pid} 2>/dev/null || true", check=False)
            return 2
        if time.monotonic() - start > hard_min * 60:
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            return 3
        bal = balance_yuan()
        if start_bal >= 0 and bal >= 0 and start_bal - bal >= CAP_YUAN:
            log(f"CAP_KILL spent>={CAP_YUAN}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            return 4


def pull_out() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = Path("/tmp/fox-couple-pull")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
    remote = subprocess.Popen(
        bring.ssh_argv([f"cd {REMOTE_OUT} && tar --exclude=work -cf - * 2>/dev/null || true"]),
        stdout=subprocess.PIPE,
    )
    subprocess.run(["tar", "-C", str(scratch), "-xf", "-"], stdin=remote.stdout, capture_output=True)
    remote.stdout.close()
    remote.wait()
    for source in scratch.rglob("*"):
        if source.is_file():
            target = OUT / source.relative_to(scratch)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    shutil.rmtree(scratch, ignore_errors=True)
    log(f"PULLED -> {OUT}")


def sync_store() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    for source in OUT.rglob("*"):
        if source.is_file():
            dest = STORE / source.relative_to(OUT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            try:
                if dest.resolve() == source.resolve():
                    continue
            except OSError:
                pass
            shutil.copyfile(source, dest)
    log(f"STORE_SYNC -> {STORE}")


def after_boot(auth: str, role: str, uuid: str, start_bal: float) -> None:
    bring.wait_ssh(12)
    bring.ship(False)
    rem = remote_sha()
    if rem != LOCAL_SHA:
        bring.ship(True)
        rem = remote_sha()
        if rem != LOCAL_SHA:
            power.shutdown_fleet()
            raise SystemExit(f"SHA_MISMATCH {rem} != {LOCAL_SHA}")
    log(f"SHA_MATCH {LOCAL_SHA}")
    bring.ssh(f"mkdir -p {REMOTE_INPUT}", check=True)
    scp_to(LOCAL_PLATE, f"{REMOTE_INPUT}/lin-gu-embrace-clothed.png")
    alias = host_idle(auth, uuid)[2]
    (OUT / "MACHINE.json").write_text(json.dumps({"role": role, "uuid": uuid, "alias": alias, "commit": COMMIT}, indent=2), encoding="utf-8")
    if models_present():
        log(f"MODELS_SKIP role={role}")
    else:
        log(f"DOWNLOAD_START role={role}")
        dl = (
            f"export HF_ENDPOINT=https://hf-mirror.com COMFY={bring.COMFY_DIR} "
            f"OUT_JSON={REMOTE_OUT}/MODEL_HOST.json STUCK_SEC=900 "
            f"AUTODL_MACHINE_ALIAS={shlex.quote(alias)} AUTODL_INSTANCE_UUID={uuid}; "
            f"bash {bring.REMOTE_ROOT}/{INSTALL_REL}"
        )
        rc = remote_job(dl, log_name="download-r4", stuck_min=STUCK_MIN, hard_min=150.0)
        pull_out(); sync_store()
        if rc != 0:
            power.shutdown_fleet()
            raise SystemExit(rc)
    bring.restart_comfy()
    bring.ssh(f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u {SCRIPT_REL} --check-stack", check=True)
    gen = (
        f"{bring.REMOTE_PY} -u {SCRIPT_REL} --out {shlex.quote(REMOTE_OUT)} "
        f"--plate {shlex.quote(REMOTE_INPUT + '/lin-gu-embrace-clothed.png')} --i-know-authorized"
    )
    log("GENERATE_START couple nude+torn")
    try:
        rc = remote_job(gen, log_name="gen-couple", stuck_min=STUCK_MIN, hard_min=60.0)
    except SystemExit:
        pull_out(); sync_store()
        summary = OUT / "COUPLE_SUMMARY.json"
        if summary.is_file() and "lin-gu-embrace-nude" in summary.read_text(encoding="utf-8"):
            log("RECOVERED_AFTER_SSH_FAIL couple outputs present")
            rc = 0
        else:
            power.shutdown_fleet()
            raise
    pull_out(); sync_store()
    if rc != 0:
        power.shutdown_fleet()
        end = balance_yuan()
        log(f"END fail bal={end:.2f} spent≈{max(0.0, start_bal - end):.2f}")
        raise SystemExit(rc)
    log("AWAITING_VISUAL_JUDGE fox-couple")
    print("MACHINE_HELD_FOR_JUDGE", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    require_pose_locked()
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    if not LOCAL_PLATE.is_file():
        raise SystemExit(f"CLOTHED_MISSING {LOCAL_PLATE}")
    start_bal = balance_yuan()
    log(f"START commit={COMMIT[:12]} sha={LOCAL_SHA} bal={start_bal:.2f} cap={CAP_YUAN}")
    src = LOCAL_SCRIPT.read_text(encoding="utf-8")
    for needle in ("fox_couple_r4_lin_wardrobe_only", "official_is_raw", "qwen_edit_graph"):
        if needle not in src:
            raise SystemExit(f"PLAN_GATE_FAIL {needle}")
    (OUT / "AWAITING_JUDGE.json").write_text(
        json.dumps({"commit": COMMIT, "sha256": LOCAL_SHA, "start_bal": start_bal, "cap_yuan": CAP_YUAN, "card_wait": "unlimited"}, indent=2),
        encoding="utf-8",
    )
    dual.refuse_third(auth)
    power.assert_fleet_cap()
    role, uuid = pick_and_power(auth)
    log(f"WINNER {role} {uuid}")
    wait_running(auth, uuid)
    wire_ssh(role, auth, uuid)
    after_boot(auth, role, uuid, start_bal)


def continue_on_running() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    auth = power.web_authorization()
    start_bal = balance_yuan()
    if (OUT / "AWAITING_JUDGE.json").exists():
        start_bal = float(json.loads((OUT / "AWAITING_JUDGE.json").read_text()).get("start_bal", start_bal))
    role = uuid = None
    for name, u in (("clone", power.clone_uuid()), ("mother", power.MOTHER_UUID)):
        if u and dual.instance_status(auth, u) == "running":
            role, uuid = name, u
            break
    if not role:
        raise SystemExit("CONTINUE_NO_RUNNING")
    dual.ensure_peer_shutdown(auth, uuid)
    log(f"CONTINUE {role} {uuid}")
    wire_ssh(role, auth, uuid)
    bring.ship(True)
    after_boot(auth, role, uuid, start_bal)


def shutdown_only() -> None:
    power.shutdown_fleet()
    sync_store()
    log(f"END bal={balance_yuan():.2f}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        shutdown_only()
    elif len(sys.argv) > 1 and sys.argv[1] == "continue":
        continue_on_running()
    else:
        main()
