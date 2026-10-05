"""Cast-asset template pipeline. Serves later stills. Does not edit explicit-still files.

Women use the 2026-10-06 frontal lock. Their old clothed plates are donors only.
A female view rebuilds a clothed plate until the mean is at least 9, then undresses it.
Stage 2 is F34 Qwen-Image-Edit-2511, 8bit, VAE on CPU, fixed LoRA scale.
Pass 1 is the low-res gate. Pass 2 repeats the same seed and only upscales.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import cast_body_template as tpl

ROOT = Path(__file__).resolve().parents[1]
ART = Path("/opt/cursor/artifacts/body-nude")
FAIL = ART / "_fail"
CLOTHED_ART = Path("/opt/cursor/artifacts/body-clothed")
VISION_MODEL = "opencode-go/deepseek-v4-flash-vision-exp"
TOKEN_FILE = Path("/tmp/autodl_token_live.txt")
REUSE_JSON = Path("/tmp/f34-asset-reuse.json")
REUSE_ENV = Path("/tmp/f34-asset-reuse.env")
CAST_SSH_ENV = Path("/tmp/cast-ssh.env")
SHARED_CAST_SSH = Path("/cursor/stores/user/cast-ssh.env")
REMOTE_CAST_SSH = "/root/autodl-tmp/.cast-ssh.env"
YUAN_PER_LI = 1000


def _unquote(value: str) -> str:
    import shlex

    value = value.strip()
    if not value:
        return ""
    parts = shlex.split(value)
    return parts[0] if parts else ""


def parse_cast_env(text: str) -> dict:
    """Read either the film handoff names or the F34 .cast-ssh.env names."""
    env = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = _unquote(value)

    def pick(*keys: str) -> str:
        for key in keys:
            if env.get(key):
                return env[key]
        return ""

    return {
        "instance_uuid": pick("F34_INSTANCE_UUID") or tpl.F34_UUID,
        "ssh_host": pick("AUTODL_SSH_HOST", "F34_SSH_HOST"),
        "ssh_port": pick("AUTODL_SSH_PORT", "F34_SSH_PORT"),
        "ssh_user": pick("AUTODL_SSH_USER", "F34_SSH_USER") or "root",
        "ssh_password": pick("AUTODL_SSH_PASSWORD", "F34_SSH_PASSWORD"),
        "website_token": pick("AUTODL_WEBSITE_TOKEN", "F34_WEBSITE_TOKEN"),
    }


def parse_reuse_env(text: str) -> dict:
    return parse_cast_env(text)


def reuse_config() -> dict:
    """Film-agent handoff. Same F34 login. Never a second token."""
    if REUSE_JSON.is_file():
        data = json.loads(REUSE_JSON.read_text(encoding="utf-8"))
    elif REUSE_ENV.is_file():
        data = parse_cast_env(REUSE_ENV.read_text(encoding="utf-8"))
    elif CAST_SSH_ENV.is_file():
        data = parse_cast_env(CAST_SSH_ENV.read_text(encoding="utf-8"))
    elif SHARED_CAST_SSH.is_file():
        data = parse_cast_env(SHARED_CAST_SSH.read_text(encoding="utf-8"))
    else:
        return {}
    if data.get("instance_uuid") not in (None, "", tpl.F34_UUID):
        raise SystemExit("复用文件不是 F34。不连接 G09。")
    return data


def load_token() -> str:
    env = os.environ.get("AUTODL_TOKEN", "").strip()
    if env:
        return env
    reused = (reuse_config().get("website_token") or "").strip()
    if reused:
        return reused
    if TOKEN_FILE.is_file():
        return TOKEN_FILE.read_text(encoding="utf-8").strip()
    raise SystemExit(
        "缺少出片同一套登录。本机没有 /tmp/f34-asset-reuse.json。"
        "不要另要令牌，不要开 G09，不要新建实例。"
    )


def ssh_password_from_disk() -> str:
    env = os.environ.get("AUTODL_SSH_PASSWORD", "").strip()
    if env:
        return env
    reused = (reuse_config().get("ssh_password") or "").strip()
    if reused:
        return reused
    path = Path("/tmp/cast-recover/f34.ok")
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return ""


def direct_endpoint() -> dict | None:
    """Reuse the film agent's F34 SSH endpoint. Same password, no new token."""
    reused = reuse_config()
    host = (reused.get("ssh_host") or os.environ.get("AUTODL_SSH_HOST") or "connect.weste.seetacloud.com").strip()
    port = str(reused.get("ssh_port") or os.environ.get("AUTODL_SSH_PORT") or "35239").strip()
    password = ssh_password_from_disk()
    if not password:
        return None
    if host != "connect.weste.seetacloud.com":
        raise SystemExit("只连接 F34 的 weste 代理，不连接 G09。")
    return {
        "uuid": tpl.F34_UUID,
        "status": "running",
        "proxy_host": host,
        "ssh_port": int(port),
        "root_password": password,
    }


def wallet_assets_li(token: str) -> int:
    import httpx

    response = httpx.post(
        "https://www.autodl.com/api/v1/dev/wallet/balance",
        headers={"Authorization": token, "Content-Type": "application/json"},
        json={},
        timeout=40,
    )
    response.raise_for_status()
    data = response.json().get("data") or {}
    assets = data.get("assets")
    if assets is None and isinstance(data.get("wallet"), dict):
        assets = data["wallet"].get("assets")
    if assets is None:
        raise SystemExit(f"wallet response missing assets keys={list(data)[:12]}")
    return int(assets)


def balance_line(assets_li: int) -> str:
    yuan = assets_li / YUAN_PER_LI
    flag = " ALERT_BELOW_5" if yuan < 5 else ""
    return f"autodl_balance_li {assets_li} yuan {yuan:.2f}{flag}"


def f34_instance(token: str) -> dict:
    import httpx

    response = httpx.post(
        "https://www.autodl.com/api/v1/instance",
        headers={"Authorization": token, "Content-Type": "application/json"},
        json={},
        timeout=60,
    )
    response.raise_for_status()
    items = (response.json().get("data") or {}).get("list") or []
    for item in items:
        if item.get("uuid") == tpl.G09_UUID:
            continue
        if item.get("uuid") == tpl.F34_UUID:
            return item
    raise SystemExit("F34 xaxna66hqt-c5c9c7fc 不在实例列表里。不要新建实例。")


def connect(item: dict):
    import paramiko

    if item.get("uuid") != tpl.F34_UUID:
        raise SystemExit("只连接 F34")
    if item.get("status") != "running":
        raise SystemExit(
            f"F34 状态是 {item.get('status')}。开机要用户授权。这条流水线不开机。"
        )
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        item["proxy_host"],
        port=int(item["ssh_port"]),
        username="root",
        password=item["root_password"],
        timeout=60,
        banner_timeout=120,
        auth_timeout=60,
        look_for_keys=False,
        allow_agent=False,
    )
    transport = client.get_transport()
    if transport is not None:
        transport.set_keepalive(30)
    return client


def ssh_exec(client, command: str, timeout: int = 60) -> str:
    _, stdout, stderr = client.exec_command(command, timeout=timeout)
    out = stdout.read().decode("utf-8", "replace")
    err = stderr.read().decode("utf-8", "replace")
    code = stdout.channel.recv_exit_status()
    if code != 0:
        raise SystemExit(f"ssh exit {code}: {(err or out)[-400:]}")
    return out


def _line_pid(line: str) -> str:
    token = line.strip().split(",", 1)[0].split()
    if token and token[0].isdigit():
        return token[0]
    return ""


def gpu_block_reason(text: str) -> str | None:
    """Refuse to start when a non-cast worker already holds the GPU.

    Judge each line. A memory reading and an unrelated python process must
    not combine into a false busy signal. nvidia-smi names the cast worker
    only as python, so a MiB line is ours when that pid is cast-asset/worker.py.
    """
    our_pids: set[str] = set()
    gpu_python_pids: set[str] = set()
    for line in text.splitlines():
        lowered = line.lower()
        if "run_explicit" in lowered or "f34_lora_worker" in lowered:
            return "F34 上还有出片 worker。资产流水线不抢同一张卡。"
        if "cast_body_worker" in lowered or "cast-asset/worker.py" in lowered:
            pid = _line_pid(line)
            if pid:
                our_pids.add(pid)
            continue
        if "mib" in lowered and "python" in lowered:
            pid = _line_pid(line)
            if pid:
                gpu_python_pids.add(pid)
            else:
                return "F34 GPU 上已有别的 python。资产流水线不抢同一张卡。"
    if gpu_python_pids - our_pids:
        return "F34 GPU 上已有别的 python。资产流水线不抢同一张卡。"
    return None


def score_image(image: Path, actor: str, view: str, stage: str) -> dict:
    makeup = ROOT / "library" / "cast" / actor / "ref.png"
    if not makeup.is_file():
        raise SystemExit(f"missing makeup ref {makeup}")
    if shutil.which("opencode") is None:
        raise SystemExit("opencode is required to score a cast template")
    cmd = [
        "opencode",
        "run",
        "--pure",
        "--auto",
        "-m",
        VISION_MODEL,
        "--variant",
        "max",
        "--dir",
        "/tmp",
        tpl.score_prompt(actor, view, stage),
        "-f",
        str(makeup),
        "-f",
        str(image),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    if result.returncode != 0:
        raise SystemExit(f"vision score failed: {(result.stderr or result.stdout)[-500:]}")
    return tpl.parse_score(f"{result.stdout}\n{result.stderr}")


def clothed_candidates(actor: str, view: str) -> list[str]:
    local = ROOT / "library" / "cast" / actor / "body-clothed" / f"{view}.png"
    remote = [
        f"/root/autodl-tmp/in/{actor}-{view}-clothed.png",
        f"/root/autodl-tmp/assets/body-clothed/{actor}/{view}.png",
        f"/root/autodl-tmp/assets/{actor}/body-clothed/{view}.png",
    ]
    found = []
    if local.is_file():
        found.append(str(local))
    found.extend(remote)
    return found


class Remote:
    def __init__(self, client):
        self.client = client
        self.job_id = 0

    def sftp(self):
        return self.client.open_sftp()

    def render(self, job: dict) -> dict:
        self.job_id += 1
        job = {**job, "id": self.job_id}
        sftp = self.sftp()
        try:
            sftp.remove(tpl.DONE_REMOTE)
        except OSError:
            pass
        with sftp.open(tpl.JOB_REMOTE, "w") as handle:
            handle.write(json.dumps(job))
        sftp.close()
        deadline = time.time() + 900
        while time.time() < deadline:
            time.sleep(5)
            sftp = self.sftp()
            try:
                with sftp.open(tpl.DONE_REMOTE) as handle:
                    done = json.loads(handle.read().decode())
            except OSError:
                done = None
            sftp.close()
            if done and done.get("id") == self.job_id:
                if done.get("error"):
                    raise RuntimeError(done["error"])
                return done
        raise RuntimeError("render timeout")

    def fetch(self, remote: str, local: Path) -> None:
        local.parent.mkdir(parents=True, exist_ok=True)
        sftp = self.sftp()
        sftp.get(remote, str(local))
        sftp.close()


def ensure_worker(client) -> None:
    probe = ssh_exec(
        client,
        "nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader; "
        "ps -eo pid,args | awk '/python/ && !/awk/ {print}'",
        timeout=40,
    )
    reason = gpu_block_reason(probe)
    if reason:
        raise SystemExit(reason + "\n" + probe[-500:])
    local_worker = Path(__file__).with_name("cast_body_worker.py")
    import hashlib

    local_hash = hashlib.sha256(local_worker.read_bytes()).hexdigest()
    remote_listed = ssh_exec(
        client, f"sha256sum {tpl.WORKER_REMOTE} 2>/dev/null || true"
    ).strip().split()
    remote_hash = remote_listed[0] if remote_listed else ""
    running = "cast-asset/worker.py" in probe or "cast_body_worker.py" in probe
    if running and remote_hash == local_hash:
        print("worker_reuse", flush=True)
        return
    if running:
        busy = ssh_exec(
            client,
            f"if [ -f {tpl.JOB_REMOTE} ]; then echo busy; else echo idle; fi",
        )
        if "busy" in busy:
            raise SystemExit("资产 worker 要换代码，但队列里还有任务。")
        for line in probe.splitlines():
            if "cast-asset/worker.py" not in line and "cast_body_worker.py" not in line:
                continue
            parts = line.split()
            if parts and parts[0].isdigit():
                ssh_exec(client, f"kill {parts[0]} || true")
        print("worker_reload", flush=True)
        for _ in range(20):
            time.sleep(1)
            still = ssh_exec(
                client,
                "ps -eo args | awk '/cast-asset\\/worker.py/ && !/awk/ {print}'",
            )
            if "cast-asset/worker.py" not in still:
                break
        else:
            raise SystemExit("旧的资产 worker 没有退出，不启动第二个。")
    local_worker = Path(__file__).with_name("cast_body_worker.py")
    ssh_exec(
        client,
        "mkdir -p /root/autodl-tmp/cast-asset /root/autodl-tmp/in /root/autodl-tmp/out "
        "/root/autodl-tmp/assets/body-nude && rm -f /root/autodl-tmp/in/cast-asset-stop",
    )
    sftp = client.open_sftp()
    sftp.put(str(local_worker), tpl.WORKER_REMOTE)
    sftp.close()
    ssh_exec(
        client,
        "nohup python -u /root/autodl-tmp/cast-asset/worker.py "
        "> /root/autodl-tmp/cast-asset/worker.log 2>&1 < /dev/null & echo $!",
    )
    deadline = time.time() + 600
    while time.time() < deadline:
        time.sleep(5)
        log = ssh_exec(client, "tail -n 40 /root/autodl-tmp/cast-asset/worker.log || true")
        if "ready pass2_shape_ok" in log:
            print("worker_ready", flush=True)
            return
        if "Traceback" in log or "refused full BF16" in log or "SystemExit" in log:
            raise SystemExit(log[-800:])
    raise SystemExit("cast worker did not become ready")


def resolve_clothed(client, actor: str, view: str) -> str:
    remote_src = f"/root/autodl-tmp/in/cast-{actor}-{view}-clothed.png"
    local = ROOT / "library" / "cast" / actor / "body-clothed" / f"{view}.png"
    if local.is_file():
        sftp = client.open_sftp()
        sftp.put(str(local), remote_src)
        sftp.close()
        print(f"clothed_local {local}", flush=True)
        return remote_src
    for candidate in clothed_candidates(actor, view):
        if candidate.startswith("/root/"):
            check = ssh_exec(client, f"if [ -f {candidate} ]; then echo YES; else echo NO; fi")
            if "YES" in check:
                ssh_exec(client, f"cp {candidate} {remote_src}")
                print(f"clothed_remote {candidate}", flush=True)
                return remote_src
    raise SystemExit(
        f"没有 {actor} {view} 的穿衣底图。不拿定妆全身去改，避免古装发型和妆留在去衣图上。"
    )


def write_attempt_json(png: Path, record: dict) -> Path:
    """Write the eight scores beside the attempt image. Failures keep this file."""
    dest = png.with_suffix(".json")
    dest.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return dest


def user_stop_requested(client) -> bool:
    """True when the user dropped the local or the F34 stop file."""
    if Path(tpl.STOP_LOCAL).is_file():
        return True
    out = ssh_exec(
        client,
        f"if [ -f {tpl.STOP_REMOTE} ]; then echo yes; else echo no; fi",
    )
    return out.strip().endswith("yes")


def emit_score(
    png: Path,
    stage_label: str,
    actor: str,
    view: str,
    score: dict,
    passed: bool,
    seed: int,
    extra: str,
    **record_extra,
) -> dict:
    look = tpl.look_gates(actor, view, score)
    record = tpl.attempt_record(
        actor,
        view,
        stage_label.lower(),
        tpl.FIXED_SCALE,
        seed,
        score,
        look,
        passed,
        **record_extra,
    )
    write_attempt_json(png, record)
    print(tpl.score_log_line(stage_label, actor, view, score, look, passed, extra), flush=True)
    return record


def store_pass1(actor: str, view: str, png: Path, record: dict) -> Path:
    ART.mkdir(parents=True, exist_ok=True)
    dest = ART / f"{actor}-{view}-pass1.png"
    shutil.copyfile(png, dest)
    (ART / f"{actor}-{view}-pass1.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return dest


def store_pass2(client, actor: str, view: str, png: Path, record: dict) -> Path:
    dest_dir = ROOT / "library" / "cast" / actor / "body-nude"
    dest_dir.mkdir(parents=True, exist_ok=True)
    final = dest_dir / f"{view}.png"
    shutil.copyfile(png, final)
    scores_path = dest_dir / "scores.json"
    scores = {}
    if scores_path.is_file():
        scores = json.loads(scores_path.read_text(encoding="utf-8"))
    scores[view] = record
    scores_path.write_text(json.dumps(scores, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ART.mkdir(parents=True, exist_ok=True)
    art = ART / f"{actor}-{view}.png"
    shutil.copyfile(png, art)
    (art.with_suffix(".json")).write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    remote_dir = f"/root/autodl-tmp/assets/body-nude/{actor}"
    ssh_exec(client, f"mkdir -p {remote_dir}")
    sftp = client.open_sftp()
    sftp.put(str(final), f"{remote_dir}/{view}.png")
    sftp.put(str(scores_path), f"{remote_dir}/scores.json")
    sftp.close()
    return final


def clothed_plate_paths(actor: str, view: str) -> tuple[Path, Path]:
    folder = ROOT / "library" / "cast" / actor / "body-clothed"
    return folder / f"{view}.png", folder / f"{view}.json"


def fresh_clothed_mean(actor: str, view: str):
    """Mean of a new-lock clothed plate. Retired faces and missing files do not count."""
    if actor not in tpl.FEMALE_ACTORS:
        return None
    png, meta = clothed_plate_paths(actor, view)
    if not png.is_file() or not meta.is_file():
        return None
    data = json.loads(meta.read_text(encoding="utf-8"))
    if data.get("lock") != tpl.LOCK_ID or not data.get("passed"):
        return None
    return data.get("mean")


def view_clothed_ok(actor: str, view: str) -> bool:
    if actor in tpl.FEMALE_ACTORS:
        return tpl.clothed_passed(actor, view, fresh_clothed_mean(actor, view))
    return tpl.clothed_passed(actor, view)


def resolve_donor(client, actor: str, view: str) -> str:
    """Old clothed file supplies the body only. It is not the undress source."""
    remote = f"/root/autodl-tmp/in/{actor}-{view}-clothed.png"
    check = ssh_exec(client, f"if [ -f {remote} ]; then echo YES; else echo NO; fi")
    if "YES" in check:
        print(f"donor_remote {remote}", flush=True)
        return remote
    raise SystemExit(
        f"没有 {actor} {view} 的旧穿衣供体。不拿定妆全身去改，避免古装发型和妆留在去衣图上。"
    )


def store_clothed(actor: str, view: str, png: Path, record: dict) -> Path:
    dest, meta = clothed_plate_paths(actor, view)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(png, dest)
    record = {**record, "lock": tpl.LOCK_ID}
    meta.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CLOTHED_ART.mkdir(parents=True, exist_ok=True)
    art = CLOTHED_ART / f"{actor}-{view}.png"
    shutil.copyfile(png, art)
    (art.with_suffix(".json")).write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return dest


def run_clothed_rebuild(client, remote: Remote, actor: str, view: str) -> Path:
    """Walk seeds until the new-face clothed plate clears every content score."""
    print(f"NODE 启动 {actor}:{view} 重做穿衣底板 lock={tpl.LOCK_ID}", flush=True)
    face_local = ROOT / "library" / "cast" / actor / "ref.png"
    if not face_local.is_file():
        raise SystemExit(f"missing lock ref {face_local}")
    face_remote = f"/root/autodl-tmp/in/cast-{actor}-face.png"
    donor = resolve_donor(client, actor, view)
    prompt = Path(f"/tmp/cast-clothed-{actor}-{view}.txt")
    prompt.write_text(tpl.clothed_prompt(actor, view), encoding="utf-8")
    sftp = client.open_sftp()
    sftp.put(str(face_local), face_remote)
    sftp.put(str(prompt), f"/root/autodl-tmp/in/cast-{actor}-{view}-clothed.txt")
    sftp.close()
    width, height = tpl.PASS1_SIZE
    attempt = 0
    while True:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。穿衣底板未过门，禁止去衣。")
        seed = tpl.clothed_seed_for(actor, view, attempt)
        attempt += 1
        print(
            f"CLOTHED_TRY {actor} {view} scale={tpl.CLOTHED_SCALE} seed={seed}",
            flush=True,
        )
        done = remote.render(
            {
                "kind": "clothed",
                "scale": tpl.CLOTHED_SCALE,
                "seed": seed,
                "width": width,
                "height": height,
                "steps": tpl.PASS1_STEPS,
                "true_cfg_scale": tpl.ASSET_TRUE_CFG,
                "src": donor,
                "face": face_remote,
                "prompt": f"/root/autodl-tmp/in/cast-{actor}-{view}-clothed.txt",
                "negative": tpl.negative_for(actor, "clothed"),
                "dest": f"/root/autodl-tmp/out/cast-{actor}-{view}-clothed-new.png",
            }
        )
        CLOTHED_ART.mkdir(parents=True, exist_ok=True)
        local = CLOTHED_ART / "_fail" / f"{actor}-{view}-clothed-seed{seed}.png"
        remote.fetch(done["dest"], local)
        score = score_image(local, actor, view, "clothed")
        passed = tpl.accept_clothed(score, actor, view, tpl.CLOTHED_SCALE, seed)
        emit_score(
            local,
            "CLOTHED",
            actor,
            view,
            score,
            passed,
            seed,
            f"scale={tpl.CLOTHED_SCALE} seed={seed}",
            seconds=done.get("seconds"),
        )
        if not passed:
            if tpl.identity_anatomy_or_wardrobe_below(score):
                print(
                    f"CLOTHED_NEW_SEED {actor} {view} seed={seed} "
                    f"identity={score.get('identity')} anatomy={score.get('anatomy')} "
                    f"wardrobe={score.get('wardrobe')} "
                    f"below={tpl.keys_below(score, tpl.RESEED_KEYS)}",
                    flush=True,
                )
            continue
        record = tpl.attempt_record(
            actor,
            view,
            "clothed",
            tpl.CLOTHED_SCALE,
            seed,
            score,
            tpl.look_gates(actor, view, score),
            True,
            seconds=done.get("seconds"),
        )
        path = store_clothed(actor, view, local, record)
        print(
            f"NODE 穿衣 {actor} {view} path={path} seed={seed} "
            f"mean={score.get('mean')} eight={tpl.format_eight(score)}",
            flush=True,
        )
        print(f"CLOTHED_KEEP {path}", flush=True)
        return path


def run_view(client, remote: Remote, actor: str, view: str) -> dict:
    if actor in tpl.FEMALE_ACTORS and not view_clothed_ok(actor, view):
        run_clothed_rebuild(client, remote, actor, view)
    if not view_clothed_ok(actor, view):
        mean = fresh_clothed_mean(actor, view)
        if mean is None and actor not in tpl.FEMALE_ACTORS:
            mean = tpl.CLOTHED_MEAN.get((actor, view))
        raise SystemExit(
            f"{actor} {view} 穿衣底板均分 {mean}，未到 9。先补底板，不去衣。"
        )
    src = resolve_clothed(client, actor, view)
    print(f"NODE 去衣启动 {actor}:{view} src={src}", flush=True)
    prompt1 = Path(f"/tmp/cast-pass1-{actor}-{view}.txt")
    prompt2 = Path(f"/tmp/cast-pass2-{actor}.txt")
    prompt1.write_text(tpl.pass1_prompt(actor, view), encoding="utf-8")
    prompt2.write_text(tpl.pass2_prompt(actor), encoding="utf-8")
    sftp = client.open_sftp()
    sftp.put(str(prompt1), f"/root/autodl-tmp/in/cast-{actor}-{view}-pass1.txt")
    sftp.put(str(prompt2), f"/root/autodl-tmp/in/cast-{actor}-pass2.txt")
    sftp.close()
    width, height = tpl.PASS1_SIZE
    kept = None
    # Pass 1 keeps the next unspent seed until the gate clears or the user drops a stop file.
    attempt = 0
    while True:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        seed = tpl.seed_for(actor, view, attempt)
        attempt += 1
        print(f"PASS1_TRY {actor} {view} scale={tpl.FIXED_SCALE} seed={seed}", flush=True)
        done = remote.render(
            {
                "kind": "pass1",
                "scale": tpl.FIXED_SCALE,
                "seed": seed,
                "width": width,
                "height": height,
                "steps": tpl.PASS1_STEPS,
                "true_cfg_scale": tpl.ASSET_TRUE_CFG,
                "src": src,
                "prompt": f"/root/autodl-tmp/in/cast-{actor}-{view}-pass1.txt",
                "negative": tpl.negative_for(actor),
                "dest": f"/root/autodl-tmp/out/cast-{actor}-{view}-pass1.png",
            }
        )
        FAIL.mkdir(parents=True, exist_ok=True)
        local = FAIL / f"{actor}-{view}-pass1-seed{seed}.png"
        remote.fetch(done["dest"], local)
        score = score_image(local, actor, view, "pass1")
        passed = tpl.accept_pass1(score, actor, view, tpl.FIXED_SCALE, seed)
        emit_score(
            local,
            "PASS1",
            actor,
            view,
            score,
            passed,
            seed,
            f"scale={tpl.FIXED_SCALE} seed={seed}",
            seconds=done.get("seconds"),
        )
        if not passed:
            if tpl.identity_anatomy_or_wardrobe_below(score):
                print(
                    f"PASS1_NEW_SEED {actor} {view} seed={seed} "
                    f"identity={score.get('identity')} anatomy={score.get('anatomy')} "
                    f"wardrobe={score.get('wardrobe')} "
                    f"below={tpl.keys_below(score, tpl.RESEED_KEYS)}",
                    flush=True,
                )
            continue
        record = {
            "actor": actor,
            "view": view,
            "stage": "pass1",
            "scale": tpl.FIXED_SCALE,
            "seed": seed,
            "seconds": done.get("seconds"),
            "score": score,
            "look": tpl.look_gates(actor, view, score),
            "eight": {key: score.get(key) for key in tpl.EIGHT},
            "below": tpl.below_nine(score),
            "void_rejected": False,
        }
        path = store_pass1(actor, view, local, record)
        print(
            f"NODE 一采 {actor} {view} path={path} seed={seed} "
            f"mean={score.get('mean')} eight={tpl.format_eight(score)}",
            flush=True,
        )
        print(f"PASS1_KEEP {path}", flush=True)
        kept = {"seed": seed, "pass1": done, "score": score, "path": str(path)}
        break
    if not tpl.pass2_allowed(kept is not None):
        raise SystemExit(
            f"{actor} {view} 一采未过门，禁止二采。没有改 scale。作废对 0.85/33 仍不收。"
        )
    seed = kept["seed"]
    # Light upscale of the kept plate. A miss changes denoise and steps only.
    plans = list(tpl.PASS2_SCORE_TRIES)
    oom_left = list(tpl.PASS2_OOM_TRIES)
    while plans:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采已过门，二采未完成。")
        denoise, steps = plans.pop(0)
        print(
            f"PASS2_TRY {actor} {view} scale={tpl.FIXED_SCALE} seed={seed} "
            f"denoise={denoise} steps={steps} content=locked",
            flush=True,
        )
        try:
            done2 = remote.render(
                {
                    "kind": "pass2",
                    "scale": tpl.FIXED_SCALE,
                    "seed": seed,
                    "denoise": denoise,
                    "width": tpl.PASS2_SIZE[0],
                    "height": tpl.PASS2_SIZE[1],
                    "steps": steps,
                    "true_cfg_scale": tpl.ASSET_TRUE_CFG,
                    "src": kept["pass1"]["dest"],
                    "prompt": f"/root/autodl-tmp/in/cast-{actor}-pass2.txt",
                    "negative": tpl.negative_for(actor),
                    "dest": f"/root/autodl-tmp/out/cast-{actor}-{view}-pass2.png",
                }
            )
        except RuntimeError as exc:
            if "OOM" not in str(exc) and "out of memory" not in str(exc).lower():
                raise
            print(f"PASS2_OOM {exc}", flush=True)
            if oom_left:
                plans = [oom_left.pop(0)] + plans
            continue
        local2 = FAIL / f"{actor}-{view}-pass2-seed{seed}-d{denoise}.png"
        remote.fetch(done2["dest"], local2)
        score2 = score_image(local2, actor, view, "pass2")
        passed = tpl.accept_pass2(score2, actor, view, tpl.FIXED_SCALE, seed)
        emit_score(
            local2,
            "PASS2",
            actor,
            view,
            score2,
            passed,
            seed,
            f"scale={tpl.FIXED_SCALE} seed={seed} denoise={denoise} steps={steps}",
            denoise=denoise,
            steps=steps,
        )
        if not passed:
            continue
        record = {
            "actor": actor,
            "view": view,
            "stage": "pass2",
            "scale": tpl.FIXED_SCALE,
            "seed": seed,
            "denoise": denoise,
            "steps": steps,
            "pass2_seconds": done2.get("seconds"),
            "score": score2,
        }
        final = store_pass2(client, actor, view, local2, record)
        print(
            f"NODE 二采 {actor} {view} path={final} seed={seed} "
            f"mean={score2.get('mean')} eight={tpl.format_eight(score2)}",
            flush=True,
        )
        print(f"PASS2_KEEP {final}", flush=True)
        return {"pass1": kept, "pass2": record, "path": str(final)}
    raise SystemExit(
        f"{actor} {view} 二采未过门。只调了 denoise 和步数，没有改内容，也没有重做一采。"
    )


def parse_only(raw: str) -> list[tuple[str, str]]:
    if not raw:
        return list(tpl.NUDE_VIEWS)
    out = []
    for part in raw.split(","):
        actor, _, view = part.strip().partition(":")
        pair = (actor, view)
        if pair not in tpl.NUDE_VIEWS:
            raise SystemExit(f"未知视图 {part}")
        out.append(pair)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Cast body template pipeline on F34")
    parser.add_argument("--only", default="lin_wantang:front", help="actor:view comma list")
    parser.add_argument("--doctor", action="store_true", help="Check F34 and balance, do not render")
    parser.add_argument("--login-check", action="store_true", help="SSH once with the shared password and stop")
    parser.add_argument("--shutdown", action="store_true", help="Power off F34 after the run and print balance")
    args = parser.parse_args()
    if os.environ.get("CAST_ASK_FILM_PROXY") or tpl.film_proxy_allowed():
        raise SystemExit(tpl.self_run_line())
    item = direct_endpoint()
    token = ""
    if item is None:
        if args.login_check:
            raise SystemExit(
                "共享口令还没到本机。自测只读 AUTODL_SSH_PASSWORD，或本机 /tmp/cast-ssh.env，"
                "或 /cursor/stores/user/cast-ssh.env。"
                "环境变量里的旧口令会挡住文件。F34 上的 /root/autodl-tmp/.cast-ssh.env 要等这条 SSH 通了再读。不要另要令牌。"
            )
        token = load_token()
        item = f34_instance(token)
    print(
        f"f34 status={item.get('status')} port={item.get('ssh_port')} host={item.get('proxy_host')}",
        flush=True,
    )
    if args.doctor:
        if item.get("status") == "running":
            client = connect(item)
            try:
                print(ssh_exec(client, "nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader; ps -eo args | awk '/python/ && !/awk/ {print}'"), flush=True)
            finally:
                client.close()
        if token:
            print(balance_line(wallet_assets_li(token)), flush=True)
        else:
            print("autodl_balance_li unread no_token", flush=True)
        return
    if args.login_check:
        client = connect(item)
        try:
            mode = ssh_exec(client, f"stat -c '%a %U %s' {REMOTE_CAST_SSH}").strip()
            print(f"cast_ssh_env {mode}", flush=True)
            print("资产登录已通", flush=True)
            print(tpl.self_run_line(), flush=True)
        finally:
            client.close()
        return
    print(tpl.self_run_line(), flush=True)
    client = connect(item)
    try:
        ensure_worker(client)
        print("NODE 工作流做好 女锁脸=2026-10-06-front 男演员不动 出片不代跑", flush=True)
        remote = Remote(client)
        for actor, view in parse_only(args.only):
            run_view(client, remote, actor, view)
    finally:
        client.close()
    if args.shutdown:
        if not token:
            raise SystemExit("关机需要 AUTODL_TOKEN。没有令牌就不要关机。")
        import httpx

        httpx.post(
            "https://www.autodl.com/api/v1/instance/power_off",
            headers={"Authorization": token, "Content-Type": "application/json"},
            json={"instance_uuid": tpl.F34_UUID},
            timeout=60,
        )
        print(balance_line(wallet_assets_li(token)), flush=True)


if __name__ == "__main__":
    main()
