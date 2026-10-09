"""Authorized R3b pilot: Elena nude via upper-body regen + mare-fur-only paste.

User auth 2026-10-09 19:41:
  - upper-band EmptyLatent; OpenPose 0.50; InstantID 0.50; single-woman prompt; mare-fur paste
  - existing stack; no big model; NO R1/Fooocus armor inpaint
  - prefer 791, else 592; never both
  - verify remote sha of run_fox_centaur_community_r3b.py
  - artifacts -> /opt/cursor/artifacts/fox-centaur-semantic/r3b/
  - cap ¥3; card wait ≤60min; gen stuck ≤15min → shutdown keep-disk
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
SCRIPT_REL = "workflows/comfyui/run_fox_centaur_community_r3b.py"
LOCAL_SCRIPT = ROOT / SCRIPT_REL
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/r3b")
STORE = Path("/cursor/stores/self/artifacts/fox-centaur-semantic/r3b")
REMOTE_SCRIPT = f"{bring.REMOTE_ROOT}/{SCRIPT_REL}"
REMOTE_OUT = "/root/autodl-tmp/fox-semantic-out-r3b"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()
CAP_YUAN = 3.0
CARD_WAIT_MIN = 60.0
GEN_STUCK_MIN = 15.0


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    for path in (OUT / "run.log", Path("/tmp/r3b-pilot-run.log")):
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
    mother = power.MOTHER_UUID
    clone = power.clone_uuid()
    assert clone
    ensure_both_off(auth)
    deadline = time.monotonic() + CARD_WAIT_MIN * 60
    attempt = 0
    while time.monotonic() < deadline:
        bal = balance_yuan()
        mi, ms, ma = host_idle(auth, mother)
        ci, cs, ca = host_idle(auth, clone)
        log(f"CARD_POLL {attempt} mother={ma}:{ms}:idle={mi} clone={ca}:{cs}:idle={ci} bal={bal:.2f}")
        for name, uuid in (("mother", mother), ("clone", clone)):
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
                if code in ("ServerBusy",) or any(m in msg for m in ("服务正忙", "克隆锁定", "状态无法进行开机")):
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


def remote_r3(args: str, *, log_name: str, stuck_min: float = GEN_STUCK_MIN) -> int:
    remote_log = f"{REMOTE_OUT}/{log_name}.log"
    py = bring.REMOTE_PY
    launch = (
        f"mkdir -p {REMOTE_OUT} && cd {bring.REMOTE_ROOT} && "
        f"nohup {py} -u workflows/comfyui/run_fox_centaur_community_r3b.py {args} "
        f"> {remote_log} 2>&1 & echo $!"
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
    while True:
        time.sleep(20)
        probe = bring.ssh(
            f"if kill -0 {pid} 2>/dev/null; then echo ALIVE; else echo DEAD; fi; "
            f"wc -c {remote_log} 2>/dev/null || echo 0; "
            f"tail -n 5 {remote_log} 2>/dev/null || true",
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
        tail = " | ".join(probe.stdout.strip().splitlines()[-5:])
        log(f"PROG {log_name} size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail[:280]}")
        if size > last_size:
            last_size = size
            last_progress = time.monotonic()
        if not alive:
            end = bring.ssh(f"tail -n 60 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(end.stdout, encoding="utf-8")
            if "VISUAL_JUDGE" in end.stdout or "STITCH_R3B" in end.stdout:
                return 0
            log(f"GEN_FAIL {log_name}")
            return 1
        if time.monotonic() - last_progress > stuck_min * 60:
            log(f"STUCK_KILL {log_name} no progress >{stuck_min}min")
            bring.ssh(f"kill {pid} 2>/dev/null; sleep 1; kill -9 {pid} 2>/dev/null || true", check=False)
            return 2
        if time.monotonic() - start > 45 * 60:
            log(f"GEN_HARD_TIMEOUT {log_name}")
            bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
            return 3
        # Cap spend while generating
        bal = balance_yuan()
        marker = OUT / "AWAITING_JUDGE.json"
        if bal >= 0 and marker.exists():
            start_bal = json.loads(marker.read_text()).get("start_bal", bal)
            if start_bal - bal >= CAP_YUAN:
                log(f"CAP_KILL spent>={CAP_YUAN}")
                bring.ssh(f"kill {pid} 2>/dev/null || true", check=False)
                return 4


def pull_out() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = Path("/tmp/r3-pull")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
    remote = subprocess.Popen(
        bring.ssh_argv([f"cd {REMOTE_OUT} && tar --exclude=work -cf - * 2>/dev/null || true"]),
        stdout=subprocess.PIPE,
    )
    unpack = subprocess.run(["tar", "-C", str(scratch), "-xf", "-"], stdin=remote.stdout, capture_output=True)
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


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    auth = power.web_authorization()
    if not auth:
        raise SystemExit("WEB_AUTH_MISSING")
    start_bal = balance_yuan()
    log(f"START commit={COMMIT[:12]} sha={LOCAL_SHA} bal={start_bal:.2f} cap={CAP_YUAN}")
    if not LOCAL_SCRIPT.is_file():
        raise SystemExit("LOCAL_SCRIPT_MISSING")
    src = LOCAL_SCRIPT.read_text(encoding="utf-8")
    for needle in (
        "EmptyLatentImage",
        "ApplyInstantID",
        "DWPreprocessor",
        "mare_fur_only",
        "fooocus_inpaint_on_armor_plate",
        "community_r3b_upper_body_weak_pose_fur_paste",
    ):
        if needle not in src:
            raise SystemExit(f"PLAN_GATE_FAIL missing {needle!r}")
    if "inpaint_crop" in src or "fooocus_inpaint_head" in src:
        raise SystemExit("PLAN_GATE_FAIL R3b must not call Fooocus inpaint")
    log("PLAN_OK R3b upper 0.5/0.5 fur_paste")

    dual.refuse_third(auth)
    power.assert_fleet_cap()

    role, uuid = pick_and_power(auth)
    log(f"WINNER {role} {uuid}")
    wait_running(auth, uuid)
    wire_ssh(role, auth, uuid)
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
    log("SHA_MATCH ok")

    bring.restart_comfy()
    bring.ssh(
        f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u workflows/comfyui/run_fox_centaur_community_r3b.py --check-stack",
        check=True,
    )

    (OUT / "AWAITING_JUDGE.json").write_text(
        json.dumps(
            {
                "commit": COMMIT,
                "sha256": LOCAL_SHA,
                "role": role,
                "uuid": uuid,
                "start_bal": start_bal,
                "awaiting_visual_judge": True,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    log("GENERATE_START elena nude R3b")
    rc = remote_r3(
        f"--only elena --mode nude --out {shlex.quote(REMOTE_OUT)} "
        f"--input /tmp/fox-centaur-r3b-input --i-know-authorized",
        log_name="gen-elena-nude",
    )
    pull_out()
    sync_store()
    if rc != 0:
        log(f"ELENA_NUDE_FAIL rc={rc} shutdown")
        power.shutdown_fleet()
        end_bal = balance_yuan()
        log(f"END fail bal={end_bal:.2f} spent≈{max(0.0, start_bal - end_bal):.2f}")
        raise SystemExit(rc)

    log("AWAITING_VISUAL_JUDGE elena nude R3b — machine held")
    print("MACHINE_HELD_FOR_JUDGE", flush=True)


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
