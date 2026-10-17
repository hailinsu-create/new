"""Authorized R5 pilot: Flux Fill waist+gauntlet holes on R4b Elena (1 shot).

User auth 2026-10-10:
  - report disk first (done offline); prefer 592; never both
  - download Fill ~33–35GB; HF gated login wall → stop + report URL
  - baseline R4b; mask waist+gauntlets; y>=690 lock
  - artifacts → …/r5/ + Agent Store; cap ¥6
  - stuck ≤15min; card wait ≤60min; unusable → shutdown keep-disk
  - no grok.com
"""
from __future__ import annotations

import hashlib
import json
import os
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
SCRIPT_REL = "workflows/comfyui/run_fox_centaur_community_r5.py"
INSTALL_REL = "workflows/comfyui/install_r5_flux_fill.sh"
LOCAL_SCRIPT = ROOT / SCRIPT_REL
LOCAL_INSTALL = ROOT / INSTALL_REL
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/r5")
STORE = Path("/cursor/stores/self/artifacts/fox-centaur-semantic/r5")
REMOTE_SCRIPT = f"{bring.REMOTE_ROOT}/{SCRIPT_REL}"
REMOTE_OUT = "/root/autodl-tmp/fox-semantic-out-r5"
REMOTE_INPUT = "/root/autodl-tmp/fox-r5-input"
LOCAL_BASELINE = Path("/opt/cursor/artifacts/fox-centaur-semantic/r4b/elena-armor-centaur-nude.png")
GATED_URL = "https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev"
TOKEN_CANDIDATES = (
    Path("/cursor/stores/self/secrets/HF_TOKEN"),
    Path("/cursor/stores/bc-ce2a871f-6243-545d-b7e1-efe5cb17dbe2/secrets/HF_TOKEN"),
)
REMOTE_TOKEN_PATHS = (
    "/root/.cache/huggingface/token",
    "/root/.huggingface/token",
    "/tmp/.r5_hf_token",
)
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()
CAP_YUAN = 6.0
CARD_WAIT_MIN = 60.0
STUCK_MIN = 15.0


def _redact(text: str) -> str:
    """Strip HF token-like strings from log tails (never echo secrets)."""
    import re

    text = re.sub(r"hf_[A-Za-z0-9]+", "hf_[REDACTED]", text)
    text = re.sub(r"Bearer\s+\S+", "Bearer [REDACTED]", text)
    return text


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {_redact(msg)}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/r5-pilot-console.log")):
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except OSError as exc:
            print(f"LOG_WRITE_FAIL {path}: {exc}", flush=True)


def resolve_token_path() -> Path:
    for p in TOKEN_CANDIDATES:
        if p.is_file() and p.stat().st_size > 10:
            return p
    raise SystemExit("HF_TOKEN_FILE_MISSING under Agent Store secrets/")


def load_token_into_env() -> None:
    """Set HF_TOKEN / HUGGING_FACE_HUB_TOKEN from Agent Store; never print value."""
    path = resolve_token_path()
    raw = path.read_text(encoding="utf-8").strip().splitlines()
    token = ""
    for line in raw:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("HF_TOKEN="):
            token = line.split("=", 1)[1].strip().strip('"').strip("'")
        else:
            token = line
        break
    if len(token) < 10:
        raise SystemExit("HF_TOKEN_EMPTY_OR_SHORT")
    os.environ["HF_TOKEN"] = token
    os.environ["HUGGING_FACE_HUB_TOKEN"] = token
    log(f"HF_TOKEN_LOADED from_store bytes={len(token)} path_kind=agent_store")


def balance_yuan() -> float:
    token = power.dev_token()
    if not token:
        return -1.0
    _status, reply = power.post(power.DEV_BALANCE, {"Authorization": token}, {})
    data = reply.get("data") or {}
    raw = data.get("assets_li", data.get("assets"))
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
        st = dual.instance_status(auth, u)
        if st == "running":
            log(f"PRE_OFF {u} was {st}")
            power.power_off_keep_disk(u, auth)


def pick_and_power(auth: str) -> tuple[str, str]:
    mother = power.MOTHER_UUID
    clone = power.clone_uuid()
    assert clone
    ensure_both_off(auth)
    deadline = time.monotonic() + CARD_WAIT_MIN * 60
    attempt = 0
    order = (("clone", clone), ("mother", mother))
    while time.monotonic() < deadline:
        bal = balance_yuan()
        log(f"CARD_POLL {attempt} bal={bal:.2f}")
        mi, ms, ma = host_idle(auth, mother)
        ci, cs, ca = host_idle(auth, clone)
        log(f"CARD_POLL {attempt} mother={ma}:{ms}:idle={mi} clone={ca}:{cs}:idle={ci}")
        for name, uuid in order:
            try:
                dual.ensure_peer_shutdown(auth, uuid)
            except Exception as exc:  # noqa: BLE001
                log(f"MUTEX_ERR {exc}")
                continue
            st = dual.instance_status(auth, uuid)
            if st == "running":
                log(f"UNEXPECTED_RUNNING {name} {uuid}")
                return name, uuid
            verdict, reply = power.power_on_once(uuid, auth)
            msg = str(reply.get("msg", ""))[:120]
            log(f"POWER_TRY {name} -> {verdict} {reply.get('code')} {msg}")
            if verdict == "success":
                dual.ensure_peer_shutdown(auth, uuid)
                return name, uuid
            if verdict == "fatal":
                code = str(reply.get("code") or "")
                if code in ("ServerBusy",) or any(
                    m in msg for m in ("服务正忙", "克隆锁定", "状态无法进行开机")
                ):
                    log(f"SOFT_RETRY {name} {code}")
                    continue
                raise SystemExit(f"POWER_FATAL {name} {reply}")
        attempt += 1
        time.sleep(30)
    raise SystemExit("CARD_WAIT_TIMEOUT 60min")


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
    raise SystemExit(f"REMOTE_SHA_PARSE_FAIL {run.stdout[-200:]!r}")


def ship_baseline() -> None:
    if not LOCAL_BASELINE.is_file():
        raise SystemExit(f"LOCAL_BASELINE_MISSING {LOCAL_BASELINE}")
    bring.ssh(f"mkdir -p {REMOTE_INPUT}", check=True)
    remote = f"{REMOTE_INPUT}/elena-armor-centaur-nude-r4b.png"
    conn = bring.connection()
    scp = [
        "scp",
        "-i",
        str(bring.KEY_COPY),
        "-P",
        conn["port"],
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=20",
        str(LOCAL_BASELINE),
        f"{conn['user']}@{conn['host']}:{remote}",
    ]
    proc = subprocess.run(scp, capture_output=True, text=True, timeout=180)
    if proc.returncode != 0:
        raise SystemExit(f"SHIP_BASELINE_FAIL {proc.stderr[:300]!r}")
    log(f"SHIP_BASELINE -> {remote} bytes={LOCAL_BASELINE.stat().st_size}")


def ship_hf_token() -> None:
    """SCP token to remote HF cache paths only; never put token in ssh argv/log."""
    src = resolve_token_path()
    # Normalize to a single-line temp file (no KEY= prefix) for HF cache format
    tmp = Path("/tmp/.r5_hf_token_ship")
    raw = src.read_text(encoding="utf-8").strip()
    token = raw
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        token = line.split("=", 1)[1].strip().strip('"').strip("'") if line.startswith("HF_TOKEN=") else line
        break
    tmp.write_text(token + "\n", encoding="utf-8")
    tmp.chmod(0o600)
    bring.ssh("mkdir -p /root/.cache/huggingface /root/.huggingface", check=True)
    conn = bring.connection()
    for remote in REMOTE_TOKEN_PATHS:
        scp = [
            "scp",
            "-i",
            str(bring.KEY_COPY),
            "-P",
            conn["port"],
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=20",
            str(tmp),
            f"{conn['user']}@{conn['host']}:{remote}",
        ]
        proc = subprocess.run(scp, capture_output=True, text=True, timeout=60)
        if proc.returncode != 0:
            tmp.unlink(missing_ok=True)
            raise SystemExit(f"SHIP_HF_TOKEN_FAIL remote={remote} rc={proc.returncode}")
    bring.ssh(
        "chmod 600 /root/.cache/huggingface/token /root/.huggingface/token /tmp/.r5_hf_token 2>/dev/null || true",
        check=False,
    )
    tmp.unlink(missing_ok=True)
    log("SHIP_HF_TOKEN ok (remote cache files only; value not logged)")


def scrub_hf_token_remote() -> None:
    """Delete token files and unset env leftovers on the GPU box after download."""
    script = (
        "set +x; "
        "rm -f /root/.cache/huggingface/token /root/.huggingface/token /tmp/.r5_hf_token "
        "/root/autodl-tmp/.r5_hf_token /tmp/r5-fill-probe.body /tmp/r5-fill-probe.hdr 2>/dev/null; "
        "unset HF_TOKEN HUGGING_FACE_HUB_TOKEN huggingface_hub_token; "
        "sed -i '/HF_TOKEN/d;/HUGGING_FACE_HUB_TOKEN/d' /root/.bashrc /root/.profile 2>/dev/null || true; "
        "echo SCRUB_HF_TOKEN_DONE"
    )
    run = bring.ssh(script, check=False)
    log(_redact((run.stdout or "").strip()[-80:] or "SCRUB_attempted"))
    # also drop from this process
    os.environ.pop("HF_TOKEN", None)
    os.environ.pop("HUGGING_FACE_HUB_TOKEN", None)
    Path("/tmp/.r5_hf_token_ship").unlink(missing_ok=True)
    log("SCRUB_HF_TOKEN local+remote done")


def record_live_df(role: str) -> None:
    run = bring.ssh("df -h /root/autodl-tmp | tail -1", check=False)
    line = (run.stdout or "").strip().splitlines()[-1] if run.stdout else ""
    log(f"LIVE_DF {role} {line}")
    disk_path = Path("/opt/cursor/artifacts/fox-centaur-semantic/r5-disk-check.json")
    data = {}
    if disk_path.exists():
        try:
            data = json.loads(disk_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}
    data.setdefault(role if role != "clone" else "592", {})
    key = "592" if role == "clone" else "791"
    data[key] = data.get(key) or {}
    data[key]["live_df_now"] = line
    data[key]["status"] = "running"
    # parse df -h columns: Filesystem Size Used Avail Use% Mount
    parts = line.split()
    if len(parts) >= 5 and parts[1].endswith("G"):
        try:
            total = float(parts[1][:-1])
            used = float(parts[2][:-1])
            avail = float(parts[3][:-1])
            data[key]["live_parsed_G"] = {"total": total, "used": used, "avail": avail}
            data[key]["after_r5_fill_33to35GB"] = {
                "need_GB": "33-35",
                "avail_now_G": avail,
                "remain_after_33G": round(avail - 33, 1),
                "remain_after_35G": round(avail - 35, 1),
                "fits": avail >= 35,
            }
        except ValueError:
            pass
    disk_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "LIVE_DF.txt").write_text(line + "\n", encoding="utf-8")


def remote_job(cmd: str, *, log_name: str, stuck_min: float = STUCK_MIN, hard_min: float = 120.0) -> int:
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
        raise SystemExit(f"NO_PID {run.stdout[-200:]!r}")
    log(f"REMOTE_PID {log_name}={pid}")
    start = time.monotonic()
    last_size = -1
    last_progress = time.monotonic()
    start_bal = -1.0
    marker = OUT / "AWAITING_JUDGE.json"
    if marker.exists():
        start_bal = float(json.loads(marker.read_text()).get("start_bal", -1))
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
        tail = _redact(" | ".join(probe.stdout.strip().splitlines()[-8:]))
        log(f"PROG {log_name} size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail[:350]}")
        if "HF_GATED_LOGIN_WALL" in probe.stdout or "GATED_URL" in probe.stdout:
            log(f"GATED_DETECTED during {log_name}")
            bring.ssh(f"kill {pid} 2>/dev/null; sleep 1; kill -9 {pid} 2>/dev/null || true", check=False)
            end = bring.ssh(f"tail -n 100 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(_redact(end.stdout or ""), encoding="utf-8")
            return 41
        if size > last_size:
            last_size = size
            last_progress = time.monotonic()
        if not alive:
            end = bring.ssh(f"tail -n 120 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(_redact(end.stdout or ""), encoding="utf-8")
            if "HF_GATED_LOGIN_WALL" in end.stdout or "GATED_URL" in end.stdout:
                return 41
            if any(
                tok in end.stdout
                for tok in ("R5_MODELS_OK", "R5_MODELS_DONE", "VISUAL_JUDGE", "STITCH_R5", "R5_STACK_OK")
            ):
                return 0
            if "R5_MODELS_FAIL" in end.stdout or "STUCK_DOWNLOAD" in end.stdout:
                return 2
            log(f"JOB_FAIL {log_name}")
            return 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log(f"STUCK_KILL {log_name} no progress >{stuck_min}min")
            bring.ssh(f"kill {pid} 2>/dev/null; sleep 1; kill -9 {pid} 2>/dev/null || true", check=False)
            return 2
        if time.monotonic() - start > hard_min * 60:
            log(f"HARD_TIMEOUT {log_name}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            return 3
        bal = balance_yuan()
        if start_bal >= 0 and bal >= 0 and start_bal - bal >= CAP_YUAN:
            log(f"CAP_KILL spent>={CAP_YUAN}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            return 4


def pull_out() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = Path("/tmp/r5-pull")
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
    for src_name, dst_name in (
        ("elena-armor-centaur-nude-preview.webp", "r5-elena-preview.webp"),
        ("elena-armor-centaur-nude-torso.webp", "r5-elena-torso.webp"),
        ("elena-armor-centaur-nude-r5-raw.png", "r5-elena-raw.png"),
    ):
        src = OUT / src_name
        if src.is_file():
            try:
                shutil.copyfile(src, Path("/cursor/stores/self/artifacts") / dst_name)
            except OSError:
                pass
    log(f"STORE_SYNC -> {STORE}")


def handle_gated(start_bal: float) -> None:
    log(f"STOP_HF_GATED {GATED_URL}")
    try:
        scrub_hf_token_remote()
    except Exception as exc:  # noqa: BLE001
        log(f"SCRUB_ON_GATED_ERR {type(exc).__name__}")
    (OUT / "HF_GATED.json").write_text(
        json.dumps(
            {
                "status": "HF_GATED_LOGIN_WALL",
                "gated_url": GATED_URL,
                "need": "Accept FLUX.1-Fill-dev license on HF + provide HF_TOKEN to agent/machine",
                "commit": COMMIT,
                "sha256": LOCAL_SHA,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    pull_out()
    sync_store()
    power.shutdown_fleet()
    end_bal = balance_yuan()
    log(f"END gated bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
    print(f"HF_GATED_LOGIN_WALL\nGATED_URL {GATED_URL}", flush=True)
    raise SystemExit(41)


def after_boot(auth: str, role: str, uuid: str, start_bal: float) -> None:
    bring.wait_ssh(12)
    bring.ship(False)
    rem = remote_sha()
    log(f"REMOTE_SHA {rem}")
    if rem != LOCAL_SHA:
        log(f"SHA_MISMATCH local={LOCAL_SHA} remote={rem} — re-ship")
        bring.ship(True)
        rem = remote_sha()
        if rem != LOCAL_SHA:
            power.shutdown_fleet()
            raise SystemExit(f"SHA_MISMATCH_FATAL local={LOCAL_SHA} remote={rem}")
    log(f"SHA_MATCH ok local={LOCAL_SHA}")

    record_live_df(role)
    ship_baseline()
    ship_hf_token()

    alias = host_idle(auth, uuid)[2]
    (OUT / "MACHINE.json").write_text(
        json.dumps(
            {
                "role": role,
                "uuid": uuid,
                "alias": alias,
                "commit": COMMIT,
                "sha256_r5": LOCAL_SHA,
                "gated_url": GATED_URL,
                "hf_token_shipped": True,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    log(f"MODEL_TARGET role={role} alias={alias} uuid={uuid}")

    # Prefer official HF for gated Fill (mirror often breaks auth).
    # Token is read from remote cache files by install script — NOT in argv.
    dl_cmd = (
        f"export HF_ENDPOINT=https://huggingface.co COMFY={bring.COMFY_DIR} "
        f"OUT_JSON={REMOTE_OUT}/MODEL_HOST.json STUCK_SEC=900 "
        f"AUTODL_MACHINE_ALIAS={shlex.quote(alias)} AUTODL_INSTANCE_UUID={uuid}; "
        f"bash {bring.REMOTE_ROOT}/{INSTALL_REL}; ec=$?; "
        f"rm -f /root/.cache/huggingface/token /root/.huggingface/token /tmp/.r5_hf_token; "
        f"unset HF_TOKEN HUGGING_FACE_HUB_TOKEN; exit $ec"
    )
    log("DOWNLOAD_START R5 Fill (token via remote cache file; scrub after)")
    rc = remote_job(dl_cmd, log_name="download-r5", stuck_min=STUCK_MIN, hard_min=120.0)
    # Always scrub after download attempt (success, gate, or fail)
    try:
        scrub_hf_token_remote()
    except Exception as exc:  # noqa: BLE001
        log(f"SCRUB_AFTER_DL_ERR {type(exc).__name__}")
    if rc == 41:
        handle_gated(start_bal)
    pull_out()
    sync_store()
    # Redact any pulled download logs
    dl_log = OUT / "download-r5.log"
    if dl_log.is_file():
        dl_log.write_text(_redact(dl_log.read_text(encoding="utf-8", errors="replace")), encoding="utf-8")
    if rc != 0:
        log(f"DOWNLOAD_FAIL rc={rc} shutdown")
        power.shutdown_fleet()
        end_bal = balance_yuan()
        log(f"END fail bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
        raise SystemExit(rc)

    bring.restart_comfy()
    bring.ssh(
        f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u {SCRIPT_REL} --check-stack",
        check=True,
    )

    gen = (
        f"{bring.REMOTE_PY} -u {SCRIPT_REL} "
        f"--out {shlex.quote(REMOTE_OUT)} "
        f"--baseline {shlex.quote(REMOTE_INPUT + '/elena-armor-centaur-nude-r4b.png')} "
        f"--i-know-authorized"
    )
    log("GENERATE_START elena nude R5")
    rc = remote_job(gen, log_name="gen-elena-nude", stuck_min=STUCK_MIN, hard_min=45.0)
    pull_out()
    sync_store()
    if rc != 0:
        log(f"ELENA_NUDE_FAIL rc={rc} shutdown")
        power.shutdown_fleet()
        end_bal = balance_yuan()
        log(f"END fail bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
        raise SystemExit(rc)

    log("AWAITING_VISUAL_JUDGE elena nude R5 — machine held until Cursor judges")
    print("MACHINE_HELD_FOR_JUDGE", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    global COMMIT, LOCAL_SHA
    COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
    LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()

    load_token_into_env()

    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    start_bal = balance_yuan()
    log(f"START commit={COMMIT[:12]} sha={LOCAL_SHA} bal={start_bal:.2f} cap={CAP_YUAN}")
    if not LOCAL_SCRIPT.is_file() or not LOCAL_INSTALL.is_file():
        raise SystemExit("LOCAL_SCRIPTS_MISSING")
    src = LOCAL_SCRIPT.read_text(encoding="utf-8")
    for needle in (
        "community_r5_flux_fill_waist_gauntlet",
        "waist_gauntlet_mask",
        "InpaintModelConditioning",
        "flux1-fill-dev",
        GATED_URL,
    ):
        if needle not in src:
            raise SystemExit(f"PLAN_GATE_FAIL missing {needle!r}")
    log("PLAN_OK R5 flux fill waist+gauntlet")

    # echo disk snapshot at start
    disk = Path("/opt/cursor/artifacts/fox-centaur-semantic/r5-disk-check.json")
    if disk.exists():
        log(f"DISK_SNAPSHOT {disk.read_text(encoding='utf-8')[:500].replace(chr(10), ' ')}")

    (OUT / "AWAITING_JUDGE.json").write_text(
        json.dumps(
            {
                "commit": COMMIT,
                "sha256": LOCAL_SHA,
                "start_bal": start_bal,
                "awaiting_visual_judge": True,
                "cap_yuan": CAP_YUAN,
                "prefer": "592/clone",
                "gated_url": GATED_URL,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    dual.refuse_third(auth)
    power.assert_fleet_cap()

    role, uuid = pick_and_power(auth)
    log(f"WINNER {role} {uuid}")
    wait_running(auth, uuid)
    wire_ssh(role, auth, uuid)
    after_boot(auth, role, uuid, start_bal)


def shutdown_only() -> None:
    log("SHUTDOWN_ONLY keep-disk")
    power.shutdown_fleet()
    sync_store()
    end_bal = balance_yuan()
    log(f"END bal={end_bal:.2f}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        shutdown_only()
    else:
        main()
