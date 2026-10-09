"""Authorized R1-fix pilot: Elena nude first, then optional remaining three.

User auth 2026-10-09 14:23:
  - denoise 1.0×3, edge 0.42, OpenPose 0.40 (first pass), metal negatives
  - existing stack only; no big model install
  - prefer 791, else 592; never both powered
  - verify remote script sha256 == local commit tree blob
  - artifacts -> /opt/cursor/artifacts/fox-centaur-semantic/r1-fix/
  - cap ¥4; card wait ≤60min; generate stuck/error ≤15min then shutdown keep-disk
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
SCRIPT_REL = "workflows/comfyui/run_fox_centaur_community_r1.py"
LOCAL_SCRIPT = ROOT / SCRIPT_REL
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/r1-fix")
STORE = Path("/cursor/stores/self/artifacts/fox-centaur-semantic/r1-fix")
REMOTE_SCRIPT = f"{bring.REMOTE_ROOT}/{SCRIPT_REL}"
REMOTE_OUT = "/root/autodl-tmp/fox-semantic-out-r1fix"
COMMIT = subprocess.check_output(["git", "-C", "/workspace", "rev-parse", "HEAD"], text=True).strip()
LOCAL_SHA = hashlib.sha256(LOCAL_SCRIPT.read_bytes()).hexdigest()
CAP_YUAN = 4.0
CARD_WAIT_MIN = 60.0
GEN_STUCK_MIN = 15.0
RATE_YUAN_PER_HOUR = 2.88  # 5090 payg approx


def log(msg: str) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{now} {msg}"
    print(line, flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / "run.log").open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def balance_yuan() -> float:
    token = power.dev_token()
    if not token:
        return -1.0
    _status, reply = power.post(power.DEV_BALANCE, {"Authorization": token}, {})
    data = reply.get("data") or {}
    # assets field historically used; also assets_li as milli-yuan
    if "assets" in data:
        return float(data["assets"])
    if "assets_li" in data:
        return float(data["assets_li"]) / 1000.0
    return -1.0


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
    """791 first; if no card try 592. Never power both. Max CARD_WAIT_MIN."""
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
        # Prefer mother whenever it reports idle OR always poke mother first.
        order: list[tuple[str, str]] = [("mother", mother), ("clone", clone)]
        if mi <= 0 and ci > 0:
            # Still try mother once, then clone — but only one power_on success.
            order = [("mother", mother), ("clone", clone)]
        for name, uuid in order:
            try:
                dual.ensure_peer_shutdown(auth, uuid)
            except Exception as exc:  # noqa: BLE001
                log(f"MUTEX_ERR {exc}")
                continue
            st = dual.instance_status(auth, uuid)
            if st == "running":
                # Should not happen after ensure_both_off / peer shutdown.
                log(f"UNEXPECTED_RUNNING {name} {uuid}")
                return name, uuid
            verdict, reply = power.power_on_once(uuid, auth)
            msg = str(reply.get("msg", ""))[:120]
            log(f"POWER_TRY {name} -> {verdict} {reply.get('code')} {msg}")
            if verdict == "success":
                # Immediately ensure peer still off.
                dual.ensure_peer_shutdown(auth, uuid)
                return name, uuid
            if verdict == "fatal":
                code = str(reply.get("code") or "")
                if code in ("ServerBusy",) or any(m in msg for m in ("服务正忙", "克隆锁定", "状态无法进行开机")):
                    log(f"SOFT_RETRY {name} {code}")
                    continue
                raise SystemExit(f"POWER_FATAL {name} {reply}")
            # no_gpu / transient: try next in order, then sleep
        attempt += 1
        time.sleep(30)
    raise SystemExit("CARD_WAIT_TIMEOUT 60min — shutdown nothing powered")


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


def remote_r1(args: str, *, log_name: str, stuck_min: float = GEN_STUCK_MIN) -> int:
    """Run community_r1 in background; poll log; kill if stuck > stuck_min with no progress."""
    remote_log = f"{REMOTE_OUT}/{log_name}.log"
    py = bring.REMOTE_PY
    launch = (
        f"mkdir -p {REMOTE_OUT} && cd {bring.REMOTE_ROOT} && "
        f"nohup {py} -u workflows/comfyui/run_fox_centaur_community_r1.py {args} "
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
            f"tail -n 3 {remote_log} 2>/dev/null || true",
            check=False,
        )
        alive = "ALIVE" in probe.stdout
        size = 0
        for line in probe.stdout.splitlines():
            parts = line.strip().split()
            if parts and parts[0].isdigit() and len(parts) >= 1 and "log" in line or (parts and parts[0].isdigit()):
                try:
                    size = int(parts[0])
                    break
                except ValueError:
                    pass
        # simpler size parse
        for line in probe.stdout.splitlines():
            if line.strip().endswith(".log") or (line.strip().split() and line.strip().split()[0].isdigit()):
                try:
                    size = int(line.strip().split()[0])
                except ValueError:
                    pass
        tail = " | ".join(probe.stdout.strip().splitlines()[-4:])
        log(f"PROG {log_name} size={size} alive={'ALIVE' if alive else 'DEAD'} | {tail[:240]}")
        if size > last_size:
            last_size = size
            last_progress = time.monotonic()
        if not alive:
            # finished — check exit via log markers
            if "VISUAL_JUDGE" in probe.stdout or "STITCH_R1" in probe.stdout:
                return 0
            # fetch full log end
            end = bring.ssh(f"tail -n 40 {remote_log}", check=False)
            (OUT / f"{log_name}.log").write_text(end.stdout, encoding="utf-8")
            if "VISUAL_JUDGE" in end.stdout or "STITCH_R1" in end.stdout:
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


def pull_out() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # reuse bring.pull pattern but custom remote out
    scratch = Path("/tmp/r1fix-pull")
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
    STORE.parent.mkdir(parents=True, exist_ok=True)
    if STORE.exists() or STORE.is_symlink():
        # same-mount SameFileError possible — copy file-by-file
        pass
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
    # emit-plan sanity
    plan = subprocess.check_output(
        [sys.executable, str(LOCAL_SCRIPT), "--emit-plan"],
        text=True,
    )
    plan_j = json.loads(plan)
    assert plan_j.get("elena_denoise") == 1.0
    assert plan_j.get("elena_nude_passes") == 3
    assert abs(float(plan_j.get("elena_openpose_strength")) - 0.40) < 1e-6
    log(f"PLAN_OK {json.dumps(plan_j, ensure_ascii=False)}")

    dual.refuse_third(auth)
    power.assert_fleet_cap()

    role, uuid = pick_and_power(auth)
    log(f"WINNER {role} {uuid}")
    wait_running(auth, uuid)
    wire_ssh(role, auth, uuid)
    bring.wait_ssh(12)
    # Full ship (need plates) first time; light if plates already there
    bring.ship(False)
    rem = remote_sha()
    log(f"REMOTE_SHA {rem}")
    if rem != LOCAL_SHA:
        log(f"SHA_MISMATCH local={LOCAL_SHA} remote={rem} — re-ship scripts")
        bring.ship(True)
        rem = remote_sha()
        log(f"REMOTE_SHA_RETRY {rem}")
        if rem != LOCAL_SHA:
            power.shutdown_fleet()
            raise SystemExit(f"SHA_MISMATCH_FATAL local={LOCAL_SHA} remote={rem}")
    log("SHA_MATCH ok")

    # Skip heavy install — existing stack. Just restart Comfy and check.
    bring.restart_comfy()
    bring.ssh(
        f"cd {bring.REMOTE_ROOT} && {bring.REMOTE_PY} -u workflows/comfyui/run_fox_centaur_community_r1.py --check-stack",
        check=True,
    )

    # --- Elena nude pilot ---
    log("GENERATE_START elena nude")
    rc = remote_r1(
        f"--only elena --mode nude --out {shlex.quote(REMOTE_OUT)} "
        f"--input /tmp/fox-centaur-r1fix-input --i-know-authorized",
        log_name="gen-elena-nude",
    )
    pull_out()
    sync_store()
    if rc != 0:
        log(f"ELENA_NUDE_FAIL rc={rc} shutdown")
        power.shutdown_fleet()
        end_bal = balance_yuan()
        log(f"END fail bal={end_bal:.2f} spent≈{start_bal - end_bal:.2f}")
        raise SystemExit(rc)

    # Leave machine on briefly for visual judge by caller; write marker
    marker = {
        "commit": COMMIT,
        "sha256": LOCAL_SHA,
        "role": role,
        "uuid": uuid,
        "elena_nude": str(OUT / "elena-armor-centaur-nude.png"),
        "awaiting_visual_judge": True,
        "start_bal": start_bal,
    }
    (OUT / "AWAITING_JUDGE.json").write_text(json.dumps(marker, indent=2), encoding="utf-8")
    log("AWAITING_VISUAL_JUDGE elena nude — machine kept on for follow-up or shutdown")
    print("MACHINE_HELD_FOR_JUDGE", flush=True)


def continue_remaining() -> None:
    """After visual OK: lin nude + both torn, then shutdown."""
    auth = power.web_authorization()
    start_bal = balance_yuan()
    log(f"CONTINUE_REMAINING bal={start_bal:.2f}")
    for actor, mode in (("lin", "nude"), ("lin", "torn"), ("elena", "torn")):
        bal = balance_yuan()
        spent = (start_bal - bal) if bal >= 0 else 0
        # also load pilot start from marker if present
        if bal >= 0:
            marker_path = OUT / "AWAITING_JUDGE.json"
            if marker_path.exists():
                m = json.loads(marker_path.read_text())
                spent = m.get("start_bal", start_bal) - bal
            if spent >= CAP_YUAN:
                log(f"CAP_STOP spent={spent:.2f}")
                break
        log(f"GENERATE_START {actor} {mode}")
        rc = remote_r1(
            f"--only {actor} --mode {mode} --out {shlex.quote(REMOTE_OUT)} "
            f"--input /tmp/fox-centaur-r1fix-input --i-know-authorized",
            log_name=f"gen-{actor}-{mode}",
        )
        pull_out()
        if rc != 0:
            log(f"FAIL {actor} {mode} rc={rc}")
            break
    sync_store()
    log("SHUTDOWN_FLEET_KEEP_DISK")
    power.shutdown_fleet()
    end_bal = balance_yuan()
    log(f"END bal={end_bal:.2f}")


def shutdown_only() -> None:
    log("SHUTDOWN_ONLY keep-disk")
    power.shutdown_fleet()
    sync_store()
    end_bal = balance_yuan()
    log(f"END bal={end_bal:.2f}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "continue":
        continue_remaining()
    elif len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        shutdown_only()
    else:
        main()
