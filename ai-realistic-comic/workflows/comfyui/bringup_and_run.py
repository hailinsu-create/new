"""Self-service bring-up for the semantic undress run on Beijing B 791.

    python bringup_and_run.py            # power on -> ssh -> install -> check-stack -> 4 stills -> score -> shutdown

Steps, in order:
 1. ensure the instance is on (autodl_power.ensure_on: web JWT, then developer token;
    no credential -> NEED_AUTODL_TOKEN). Skipped when SSH already answers.
 2. wait for SSH (re-reads /cursor/stores/user/bjb-ssh.env every try, so a new host/port is picked up).
 3. ship the scripts, plates and lock faces; run install_undress_stack.sh install; restart ComfyUI.
 4. run_fox_centaur_semantic.py --check-stack, then nude lin, nude elena, torn lin, torn elena.
 5. pull results back, score them with Codex only (no CLI -> SCORE_FAILED, no fallback).
 6. after a clean run, shut the machine down from the inside (disk kept), then print the balance.
    After a failed step the machine is left on (and says so) unless --shutdown-on-failure,
    because a free GPU is hard to get twice.

Never clones, never uses the no-GPU mode, never touches F34/G09.
If SSH keeps answering "Permission denied (publickey)" the machine is on but the key is not
authorised: the script stops with NEED_SSH_KEY_AUTH and tells you what to add.
"""

from __future__ import annotations

import argparse
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
STILL = "library/stills/fox-centaur-embrace"
SHIP = (
    "workflows/comfyui",
    f"{STILL}/lin-qipao-nine-tail.png",
    f"{STILL}/elena-armor-centaur.png",
    f"{STILL}/score-nude.txt",
    f"{STILL}/score-torn.txt",
    "library/cast/lin_wantang/ref-face.png",
    "library/cast/elena_voss/ref-face.png",
)
REMOTE_ROOT = "/root/autodl-tmp/arc/ai-realistic-comic"
REMOTE_OUT = "/root/autodl-tmp/fox-semantic-out"
REMOTE_PY = "/root/miniconda3/bin/python"
COMFY_DIR = "/root/autodl-tmp/comfyui"
LOCAL_ARTIFACTS = Path("/opt/cursor/artifacts/fox-centaur-semantic")
SSH_ENV = Path("/cursor/stores/user/bjb-ssh.env")
KEY_COPY = Path.home() / ".ssh" / "bjb791"
DENIED_LIMIT = 3
PRUNE = ("__pycache__", "*.pyc")


class NeedSshKeyAuth(SystemExit):
    pass


def connection() -> dict[str, str]:
    env = power.read_env_file(SSH_ENV)
    return {
        "host": env.get("BJB_SSH_HOST", "connect.bjb2.seetacloud.com"),
        "port": env.get("BJB_SSH_PORT", "34711"),
        "user": env.get("BJB_SSH_USER", "root"),
        "key": env.get("BJB_SSH_KEY_PATH", "/cursor/stores/user/bjb791"),
        "uuid": env.get("BJB_INSTANCE_UUID", power.DEFAULT_UUID),
    }


def ssh_argv(extra: list[str] | None = None) -> list[str]:
    conn = connection()
    KEY_COPY.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copyfile(conn["key"], KEY_COPY)
        KEY_COPY.chmod(0o600)
    except OSError:
        pass
    argv = [
        "ssh", "-i", str(KEY_COPY), "-p", conn["port"],
        "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=30",
        f"{conn['user']}@{conn['host']}",
    ]
    return argv + (extra or [])


def ssh(command: str, *, timeout: int = 7200, check: bool = True) -> subprocess.CompletedProcess:
    """Run a remote command and stream its output line by line so a long install is visible."""
    print(f"$ ssh {command[:200]}", flush=True)
    proc = subprocess.Popen(ssh_argv([command]), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines: list[str] = []
    start = time.monotonic()
    assert proc.stdout is not None
    for line in proc.stdout:
        if "setlocale" in line:
            continue
        lines.append(line)
        print(line, end="", flush=True)
        if time.monotonic() - start > timeout:
            proc.kill()
            raise SystemExit(f"REMOTE_TIMEOUT {command[:120]}")
    proc.wait()
    result = subprocess.CompletedProcess(proc.args, proc.returncode, "".join(lines), "")
    if check and proc.returncode != 0:
        raise SystemExit(f"REMOTE_FAILED rc={proc.returncode} {command[:120]}")
    return result


def ssh_state() -> str:
    """up | denied | down"""
    try:
        run = subprocess.run(ssh_argv(["echo UP"]), capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return "down"
    if run.returncode == 0 and "UP" in run.stdout:
        return "up"
    if "Permission denied" in run.stderr:
        return "denied"
    return "down"


def wait_ssh(minutes: float, *, sleep=time.sleep, state=ssh_state) -> None:
    deadline = time.monotonic() + minutes * 60
    denied = 0
    while time.monotonic() < deadline:
        current = state()
        if current == "up":
            print("SSH_UP", flush=True)
            return
        denied = denied + 1 if current == "denied" else 0
        if denied >= DENIED_LIMIT:
            pub = Path(connection()["key"] + ".pub")
            raise NeedSshKeyAuth(
                "NEED_SSH_KEY_AUTH the machine is on but refuses this key (Permission denied (publickey)). "
                f"Append the contents of {pub} to /root/.ssh/authorized_keys from the web JupyterLab terminal, "
                "or put BJB_SSH_PASSWORD in bjb-ssh.env. The machine is billing until it is reachable and shut down."
            )
        sleep(20)
    raise SystemExit("SSH_TIMEOUT machine never became reachable")


def ship(light: bool = False) -> None:
    """light: only the scripts. The plates and lock faces are megabytes and the link is slow."""
    wanted = [m for m in SHIP if m.startswith("workflows/")] if light else list(SHIP)
    members = [m for m in wanted if (ROOT / m).exists()]
    missing = sorted(set(wanted) - set(members))
    if missing:
        raise SystemExit(f"SHIP_MISSING {missing}")
    tar = ["tar", "-C", str(ROOT), "-cf", "-"]
    for pattern in PRUNE:
        tar += ["--exclude", pattern]
    tar += members
    print(f"SHIP {len(members)} paths -> {REMOTE_ROOT}", flush=True)
    sender = subprocess.Popen(tar, stdout=subprocess.PIPE)
    receiver = subprocess.run(
        ssh_argv([f"mkdir -p {REMOTE_ROOT} && tar -C {REMOTE_ROOT} -xf -"]), stdin=sender.stdout, capture_output=True, text=True
    )
    sender.stdout.close()
    sender.wait()
    if sender.returncode != 0 or receiver.returncode != 0:
        raise SystemExit(f"SHIP_FAILED {receiver.stderr[:300]}")


def restart_comfy() -> None:
    # Two calls on purpose: a single command line that both kills by pattern and starts
    # "main.py --listen ..." would match its own pattern and kill the ssh session.
    ssh("for pid in $(pgrep -f '[m]ain.py --listen 127.0.0.1 --port 8188'); do kill $pid; done; sleep 3; echo OLD_COMFY_STOPPED", check=False)
    ssh(
        f"cd {COMFY_DIR}; setsid nohup {REMOTE_PY} main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch "
        "< /dev/null > /root/autodl-tmp/comfyui.log 2>&1 & sleep 1; echo COMFY_STARTED"
    )
    ssh(
        "for i in $(seq 1 60); do curl -sf http://127.0.0.1:8188/system_stats >/dev/null && echo COMFY_UP && exit 0; sleep 5; done; "
        "tail -20 /root/autodl-tmp/comfyui.log; exit 1"
    )


def remote_run(args: str, *, check: bool = True) -> subprocess.CompletedProcess:
    return ssh(f"cd {REMOTE_ROOT} && {REMOTE_PY} workflows/comfyui/run_fox_centaur_semantic.py {args}", check=check)


def pull(local: Path) -> None:
    local.mkdir(parents=True, exist_ok=True)
    remote = subprocess.Popen(ssh_argv([f"tar -C {REMOTE_OUT} -cf - ."]), stdout=subprocess.PIPE)
    unpack = subprocess.run(["tar", "-C", str(local), "-xf", "-"], stdin=remote.stdout, capture_output=True)
    remote.stdout.close()
    remote.wait()
    if remote.returncode != 0 or unpack.returncode != 0:
        raise SystemExit(f"PULL_FAILED {unpack.stderr[:200]!r}")
    print(f"PULLED -> {local}", flush=True)


def score_local(local: Path) -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import run_fox_centaur_semantic as runner  # noqa: E402
    import codex_still_score as scorer  # noqa: E402

    for mode in ("nude", "torn"):
        for actor in ("lin", "elena"):
            image = local / f"{runner.STEM[(actor, mode)]}.png"
            if image.exists():
                scorer.score_image(actor, mode, image)


def keep_in_repo(local: Path) -> None:
    dest = ROOT / STILL / "semantic"
    dest.mkdir(parents=True, exist_ok=True)
    for path in local.glob("*"):
        if path.is_file() and path.suffix in (".png", ".json"):
            shutil.copyfile(path, dest / path.name)


def shutdown_machine() -> None:
    print("SHUTDOWN from inside the machine; the data disk stays.", flush=True)
    ssh('nohup sh -c "sleep 3; shutdown" >/dev/null 2>&1 &', check=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-power-on", action="store_true", help="Machine is already on.")
    parser.add_argument("--skip-install", action="store_true")
    parser.add_argument("--light-ship", action="store_true", help="Only re-send the scripts, not the plates.")
    parser.add_argument("--keep-on", action="store_true", help="Do not shut down at the end.")
    parser.add_argument(
        "--shutdown-on-failure",
        action="store_true",
        help="Also shut down when a step failed. Default: stay on so the fix can be retried without waiting for a GPU again.",
    )
    parser.add_argument("--power-minutes", type=float, default=120)
    parser.add_argument("--ssh-minutes", type=float, default=15)
    parser.add_argument("--out", type=Path, default=LOCAL_ARTIFACTS)
    args = parser.parse_args()

    conn = connection()
    power.instance_uuid(conn["uuid"])
    if not args.no_power_on and ssh_state() == "down":
        code = power.ensure_on(conn["uuid"], max_minutes=args.power_minutes)
        if code != 0:
            raise SystemExit(code)
    wait_ssh(args.ssh_minutes)

    failure: BaseException | None = None
    try:
        ship(args.light_ship)
        if not args.skip_install:
            ssh(f"bash {REMOTE_ROOT}/workflows/comfyui/install_undress_stack.sh install", timeout=7200)
        restart_comfy()
        remote_run("--check-stack")
        ssh(f"mkdir -p {REMOTE_OUT}")
        remote_run(f"--only lin elena --mode both --no-score --out {shlex.quote(REMOTE_OUT)}", check=False)
        pull(args.out)
        score_local(args.out)
        keep_in_repo(args.out)
    except BaseException as exc:  # noqa: BLE001
        failure = exc
        print(f"BRINGUP_FAILED {exc}", flush=True)
    finally:
        if args.keep_on or (failure is not None and not args.shutdown_on_failure):
            if failure is not None:
                print("MACHINE_STILL_ON a step failed; not shutting down. It is billing. Fix and rerun with --no-power-on, or shut it down.", flush=True)
        else:
            shutdown_machine()
        power.balance()
    if failure is not None:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
