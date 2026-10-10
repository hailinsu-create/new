"""Authorized R4 batch3 pilot: Lin nude/torn + Elena torn (Qwen-Edit RAW).

User auth 2026-10-10 13:58 + 17:13:
  - dual collaborative card race; mutex: only one box on at a time
  - whoever wins opens; if both have idle cards same poll → prefer 791
  - 592 has ~31.55GB models → preferred for gen; if 791 wins, confirm models or download via hf-mirror
  - card wait UNLIMITED until three shots done; cap ¥4 (gen billing); stuck ≤15min → shutdown keep-disk
  - success = Qwen-Edit RAW (no paste overwrite); do NOT re-run Elena nude
  - artifacts -> …/r4-batch3/ + Agent Store
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
SCRIPT_REL = "workflows/comfyui/run_fox_centaur_community_r4_batch3.py"
INSTALL_REL = "workflows/comfyui/install_r4_qwen.sh"
LOCAL_SCRIPT = ROOT / SCRIPT_REL
LOCAL_INSTALL = ROOT / INSTALL_REL
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/r4-batch3")
STORE = Path("/cursor/stores/self/artifacts/fox-centaur-semantic/r4-batch3")
REMOTE_SCRIPT = f"{bring.REMOTE_ROOT}/{SCRIPT_REL}"
REMOTE_OUT = "/root/autodl-tmp/fox-semantic-out-r4-batch3"
REMOTE_INPUT = "/root/autodl-tmp/fox-r4-batch3-input"
PLATE_DIR = ROOT / "library/stills/fox-centaur-embrace"
PLATES = (
    "lin-qipao-nine-tail.png",
    "elena-armor-centaur.png",
)
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()
CAP_YUAN = 4.0
CARD_WAIT_MIN = None  # unlimited — idle wait does not burn GPU fee
STUCK_MIN = 15.0


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/r4-batch3-pilot-run.log")):
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except OSError as exc:
            print(f"LOG_WRITE_FAIL {path}: {exc}", flush=True)


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
    """Dual collaborative race; mutex one-on; simultaneous idle → 791 first. Wait forever."""
    mother = power.MOTHER_UUID
    clone = power.clone_uuid()
    assert clone
    ensure_both_off(auth)
    started = time.time()
    attempt = 0
    while True:
        bal = balance_yuan()
        elapsed_min = (time.time() - started) / 60.0
        log(f"CARD_POLL {attempt} bal={bal:.2f} elapsed_min={elapsed_min:.1f} wait=unlimited race=dual")
        if (OUT / "AWAITING_JUDGE.json").exists():
            start_bal = float(json.loads((OUT / "AWAITING_JUDGE.json").read_text()).get("start_bal", bal))
            if bal >= 0 and start_bal >= 0 and start_bal - bal >= CAP_YUAN:
                raise SystemExit(f"CAP_DURING_CARD_WAIT spent>={CAP_YUAN}")
        mi, ms, ma = host_idle(auth, mother)
        ci, cs, ca = host_idle(auth, clone)
        log(f"CARD_POLL {attempt} mother={ma}:{ms}:idle={mi} clone={ca}:{cs}:idle={ci}")
        # Simultaneous idle → 791 (mother) first; else whoever has idle; else poke both mother-first.
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
            st = dual.instance_status(auth, uuid)
            if st == "running":
                log(f"UNEXPECTED_RUNNING {name} {uuid}")
                return name, uuid
            verdict, reply = power.power_on_once(uuid, auth)
            msg = str(reply.get("msg", ""))[:120]
            log(f"POWER_TRY {name} -> {verdict} {reply.get('code')} {msg}")
            if verdict == "success":
                dual.ensure_peer_shutdown(auth, uuid)
                log(f"CARD_WIN {name} after {elapsed_min:.1f}min order={[n for n,_ in order]}")
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


def scp_to(local: Path, remote: str) -> None:
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
        str(local),
        f"{conn['user']}@{conn['host']}:{remote}",
    ]
    proc = subprocess.run(scp, capture_output=True, text=True, timeout=300)
    if proc.returncode != 0:
        raise SystemExit(f"SCP_FAIL {local.name} {proc.stderr[:300]!r}")
    log(f"SCP_OK {local.name} -> {remote} bytes={local.stat().st_size}")


def ship_plates() -> None:
    bring.ssh(f"mkdir -p {REMOTE_INPUT}", check=True)
    for name in PLATES:
        local = PLATE_DIR / name
        if not local.is_file():
            raise SystemExit(f"LOCAL_PLATE_MISSING {local}")
        scp_to(local, f"{REMOTE_INPUT}/{name}")


def models_present() -> bool:
    """True if all R4 weights already on the active host."""
    probe = bring.ssh(
        f"python3 - <<'PY'\n"
        f"from pathlib import Path\n"
        f"root = Path('{bring.COMFY_DIR}') / 'models'\n"
        f"need = [\n"
        f"  root/'diffusion_models'/'qwen_image_edit_2511_fp8mixed.safetensors',\n"
        f"  root/'text_encoders'/'qwen_2.5_vl_7b_fp8_scaled.safetensors',\n"
        f"  root/'vae'/'qwen_image_vae.safetensors',\n"
        f"]\n"
        f"ok = all(p.is_file() and p.stat().st_size > 1_000_000 for p in need)\n"
        f"print('MODELS_PRESENT' if ok else 'MODELS_MISSING')\n"
        f"for p in need:\n"
        f"  print(p.name, p.is_file(), p.stat().st_size if p.is_file() else 0)\n"
        f"PY",
        check=False,
    )
    log(f"MODEL_PROBE {probe.stdout.strip()[:400]}")
    return "MODELS_PRESENT" in probe.stdout


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
        tail = " | ".join(probe.stdout.strip().splitlines()[-8:])
        log(f"PROG {log_name} size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail[:350]}")
        if size > last_size:
            last_size = size
            last_progress = time.monotonic()
        if not alive:
            end = bring.ssh(f"tail -n 120 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(end.stdout, encoding="utf-8")
            if any(
                tok in end.stdout
                for tok in (
                    "BATCH3_DONE",
                    "RAW_OK",
                    "VISUAL_JUDGE",
                    "R4_STACK_OK",
                    "R4_MODELS_OK",
                    "R4_MODELS_DONE",
                )
            ):
                return 0
            if "R4_MODELS_FAIL" in end.stdout or "STUCK_DOWNLOAD" in end.stdout:
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
    scratch = Path("/tmp/r4-batch3-pull")
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
    flat = Path("/cursor/stores/self/artifacts")
    for stem in (
        "lin-qipao-nine-tail-nude",
        "lin-qipao-nine-tail-torn",
        "elena-armor-centaur-torn",
    ):
        for suffix, dst in (
            ("-preview.webp", f"r4-batch3-{stem}-preview.webp"),
            ("-torso.webp", f"r4-batch3-{stem}-torso.webp"),
            ("-r4-raw.png", f"r4-batch3-{stem}-raw.png"),
        ):
            src = OUT / f"{stem}{suffix}"
            if src.is_file():
                try:
                    shutil.copyfile(src, flat / dst)
                except OSError:
                    pass
    log(f"STORE_SYNC -> {STORE}")


def after_boot(auth: str, role: str, uuid: str, start_bal: float) -> None:
    bring.wait_ssh(12)
    bring.ship(False)
    rem = remote_sha()
    log(f"REMOTE_SHA {rem}")
    if rem != LOCAL_SHA:
        log(f"SHA_MISMATCH local={LOCAL_SHA} remote={rem} — re-ship")
        bring.ship(True)
        rem = remote_sha()
        log(f"REMOTE_SHA_RETRY {rem}")
        if rem != LOCAL_SHA:
            power.shutdown_fleet()
            raise SystemExit(f"SHA_MISMATCH_FATAL local={LOCAL_SHA} remote={rem}")
    log(f"SHA_MATCH ok local={LOCAL_SHA}")

    ship_plates()
    alias = host_idle(auth, uuid)[2]
    (OUT / "MACHINE.json").write_text(
        json.dumps(
            {
                "role": role,
                "uuid": uuid,
                "alias": alias,
                "commit": COMMIT,
                "sha256_batch3": LOCAL_SHA,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    log(f"MODEL_TARGET role={role} alias={alias} uuid={uuid}")

    if models_present():
        log(f"MODELS_SKIP already on disk role={role} alias={alias}")
        (OUT / "MODEL_HOST.json").write_text(
            json.dumps({"skipped_download": True, "role": role, "alias": alias, "uuid": uuid}, indent=2),
            encoding="utf-8",
        )
    else:
        # Mutex: no box-to-box rsync. 791 (or unexpected 592 miss) pulls via hf-mirror install.
        log(f"DOWNLOAD_START R4 models role={role} alias={alias} via hf-mirror")
        dl_cmd = (
            f"export HF_ENDPOINT=https://hf-mirror.com COMFY={bring.COMFY_DIR} "
            f"OUT_JSON={REMOTE_OUT}/MODEL_HOST.json STUCK_SEC=900 "
            f"AUTODL_MACHINE_ALIAS={shlex.quote(alias)} AUTODL_INSTANCE_UUID={uuid}; "
            f"bash {bring.REMOTE_ROOT}/{INSTALL_REL}"
        )
        rc = remote_job(dl_cmd, log_name="download-r4", stuck_min=STUCK_MIN, hard_min=150.0)
        pull_out()
        sync_store()
        if rc != 0:
            log(f"DOWNLOAD_FAIL rc={rc} shutdown")
            power.shutdown_fleet()
            end_bal = balance_yuan()
            log(f"END fail bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
            raise SystemExit(rc)
        if not models_present():
            power.shutdown_fleet()
            raise SystemExit(f"MODELS_STILL_MISSING after download role={role}")

    bring.restart_comfy()
    bring.ssh(
        f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u {SCRIPT_REL} --check-stack",
        check=True,
    )

    gen = (
        f"{bring.REMOTE_PY} -u {SCRIPT_REL} "
        f"--out {shlex.quote(REMOTE_OUT)} "
        f"--plate-dir {shlex.quote(REMOTE_INPUT)} "
        f"--i-know-authorized"
    )
    log("GENERATE_START batch3 lin-nude lin-torn elena-torn")
    rc = remote_job(gen, log_name="gen-batch3", stuck_min=STUCK_MIN, hard_min=60.0)
    pull_out()
    sync_store()
    if rc != 0:
        log(f"BATCH3_FAIL rc={rc} shutdown")
        power.shutdown_fleet()
        end_bal = balance_yuan()
        log(f"END fail bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
        raise SystemExit(rc)

    log("AWAITING_VISUAL_JUDGE batch3 — machine held until Cursor judges then shutdown")
    print("MACHINE_HELD_FOR_JUDGE", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    start_bal = balance_yuan()
    log(f"START commit={COMMIT[:12]} sha={LOCAL_SHA} bal={start_bal:.2f} cap={CAP_YUAN}")
    if not LOCAL_SCRIPT.is_file() or not LOCAL_INSTALL.is_file():
        raise SystemExit("LOCAL_SCRIPTS_MISSING")
    src = LOCAL_SCRIPT.read_text(encoding="utf-8")
    for needle in (
        "community_r4_batch3_lin_nude_torn_elena_torn",
        "official_is_raw",
        "FORBID_ELENA_NUDE_RERUN",
        "qwen_edit_graph",
        "paste_overwrite",
    ):
        if needle not in src:
            raise SystemExit(f"PLAN_GATE_FAIL missing {needle!r}")
    log("PLAN_OK R4 batch3 raw-official")

    (OUT / "AWAITING_JUDGE.json").write_text(
        json.dumps(
            {
                "commit": COMMIT,
                "sha256": LOCAL_SHA,
                "start_bal": start_bal,
                "awaiting_visual_judge": True,
                "cap_yuan": CAP_YUAN,
                "card_wait": "unlimited",
                "targets": [
                    "lin-qipao-nine-tail-nude",
                    "lin-qipao-nine-tail-torn",
                    "elena-armor-centaur-torn",
                ],
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
