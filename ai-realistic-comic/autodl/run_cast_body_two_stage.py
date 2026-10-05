"""Cast-asset template pipeline. Serves later stills. Does not edit explicit-still files.

Women use the 2026-10-06 frontal lock. The six passing Codex clothed plates
are the female slots of the twelve-plate archive. Male clothed means stay.
A female view undresses only from that archived plate.
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
from datetime import datetime, timezone
from pathlib import Path

import cast_body_template as tpl

ROOT = Path(__file__).resolve().parents[1]
ART = Path("/opt/cursor/artifacts/body-nude")
FAIL = ART / "_fail"
CLOTHED_ART = Path("/opt/cursor/artifacts/body-clothed")
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
            f"F34 状态是 {item.get('status')}。未在跑，不连接。去衣才开机，穿衣和打分不开机。"
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


def eye_crop(plate: Path, lock: Path) -> tuple[Path, Path, int]:
    """Native head crop. The lock stays at its own resolution. Do not enlarge the plate."""
    from PIL import Image

    src = Image.open(plate).convert("RGB")
    width, height = src.size
    # Head sits in the top quarter of these full-body plates.
    box = (
        int(width * 0.28),
        int(height * 0.01),
        int(width * 0.72),
        max(2, int(height * 0.24)),
    )
    crop = src.crop(box)
    dest_dir = Path("/tmp/cast-eye-crops")
    dest_dir.mkdir(parents=True, exist_ok=True)
    crop_path = dest_dir / f"{plate.stem}.jpg"
    crop.save(crop_path, quality=95)
    short_side = min(crop.size)
    return lock, crop_path, short_side


def grok_binary() -> str | None:
    found = shutil.which("opencode")
    if found:
        return found
    local = Path.home() / ".opencode" / "bin" / "opencode"
    if local.is_file():
        return str(local)
    return None


def texts_from_opencode(raw: str) -> str:
    chunks: list[str] = []
    for line in raw.splitlines():
        piece = line.strip()
        if not piece.startswith("{"):
            continue
        try:
            event = json.loads(piece)
        except json.JSONDecodeError:
            continue
        part = event.get("part") if isinstance(event.get("part"), dict) else {}
        text = part.get("text") or event.get("text") or ""
        if text:
            chunks.append(str(text))
    return "\n".join(chunks)


def finish_score(parsed: dict, short_side: int, scorer: str) -> dict:
    resolved = tpl.resolve_eyes(parsed, short_side)
    resolved["scorer"] = scorer
    return resolved


def score_image(image: Path, actor: str, view: str, stage: str) -> dict:
    """Codex CLI first. Quota, logout, or a CLI error falls back to grok 4.7 xhigh."""
    face = ROOT / tpl.ref_face_rel(actor)
    makeup = face if face.is_file() else ROOT / "library" / "cast" / actor / "ref.png"
    if not makeup.is_file():
        raise SystemExit(f"missing makeup ref {makeup}")
    lock_view, cropped, short_side = eye_crop(image, makeup)
    images = [str(lock_view), str(cropped), str(image)]
    prompt = tpl.score_call(actor, view, stage, images, short_side=short_side)
    if not prompt.startswith(tpl.SCORE_PREFIX):
        raise SystemExit("SCORE_PREFIX_DRIFT 打分前缀被改写。禁止换路。")
    binary = codex_binary()
    logged = bool(binary) and codex_logged_in(binary)
    codex_detail = ""
    if binary and logged:
        cmd = tpl.score_exec_argv(binary, logged_in=True, cwd=str(image.parent), images=images)
        result = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=900,
        )
        codex_detail = (result.stderr or result.stdout or "").strip()
        parsed = None
        if result.returncode == 0:
            try:
                parsed = tpl.parse_score(f"{result.stdout}\n{result.stderr}")
            except ValueError as exc:
                codex_detail = f"{codex_detail}\n{exc}"
        if parsed is not None:
            print(f"SCORER {tpl.CODEX_SCORER}", flush=True)
            return finish_score(parsed, short_side, tpl.CODEX_SCORER)
        if not tpl.codex_should_fallback(result.returncode, codex_detail) and result.returncode == 0:
            codex_detail = f"{codex_detail}\nscore json missing"
    else:
        codex_detail = "codex missing or logged out"
    fallback = grok_binary()
    if not fallback:
        raise SystemExit(
            f"CODEX_CLI_FAILED score {actor} {view} {stage} {codex_detail[-300:]} "
            "GROK_FALLBACK_MISSING"
        )
    Path("/tmp/cast-score").mkdir(parents=True, exist_ok=True)
    grok_cmd = tpl.grok_score_argv(fallback, images)
    print(f"SCORER_FALLBACK {tpl.GROK_SCORER}", flush=True)
    grok = subprocess.run(
        grok_cmd + [prompt],
        capture_output=True,
        text=True,
        timeout=900,
    )
    grok_text = f"{grok.stdout or ''}\n{texts_from_opencode(grok.stdout or '')}\n{grok.stderr or ''}"
    if grok.returncode != 0:
        detail = (grok.stderr or grok.stdout or "grok score missing").strip()
        raise SystemExit(
            f"SCORE_FAILED codex {codex_detail[-200:]} grok {detail[-300:]}"
        )
    try:
        parsed = tpl.parse_score(grok_text)
    except ValueError as exc:
        raise SystemExit(f"SCORE_FAILED grok json {actor} {view} {stage} {exc}") from exc
    print(f"SCORER {tpl.GROK_SCORER}", flush=True)
    return finish_score(parsed, short_side, tpl.GROK_SCORER)


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
        "nohup /root/miniconda3/bin/python -u /root/autodl-tmp/cast-asset/worker.py "
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
    scale: float | None = None,
    **record_extra,
) -> dict:
    look = tpl.look_gates(actor, view, score)
    record = tpl.attempt_record(
        actor,
        view,
        stage_label.lower(),
        tpl.FIXED_SCALE if scale is None else scale,
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


def codex_binary() -> str | None:
    found = shutil.which("codex")
    if found:
        return found
    local = Path.home() / ".local" / "bin" / "codex"
    if local.is_file():
        return str(local)
    return None


def codex_logged_in(binary: str) -> bool:
    result = subprocess.run(
        [binary, "login", "status"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    text = f"{result.stdout or ''}{result.stderr or ''}"
    return result.returncode == 0 and "Logged in" in text


def run_clothed_rebuild(client, remote: Remote, actor: str, view: str) -> Path:
    """Codex CLI only. A missing or logged-out binary exits. F34 is not a clothed generator."""
    del remote
    binary = codex_binary()
    binary = tpl.require_codex_cli(binary, logged_in=bool(binary) and codex_logged_in(binary))
    print(f"NODE 启动 {actor}:{view} 重做穿衣底板 lock={tpl.LOCK_ID} entry=codex", flush=True)
    face_local = ROOT / "library" / "cast" / actor / "ref.png"
    if not face_local.is_file():
        raise SystemExit(f"missing lock ref {face_local}")
    attempt = 0
    while True:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。穿衣底板未过门，禁止去衣。")
        seed = tpl.clothed_seed_for(actor, view, attempt)
        attempt += 1
        print(
            f"CLOTHED_TRY {actor} {view} scale={tpl.CLOTHED_SCALE} seed={seed} entry=codex",
            flush=True,
        )
        CLOTHED_ART.mkdir(parents=True, exist_ok=True)
        local = CLOTHED_ART / "_fail" / f"{actor}-{view}-clothed-seed{seed}.png"
        if local.is_file():
            local.unlink()
        prompt = (
            tpl.clothed_prompt(actor, view)
            + f"用图像工具只出这一张，保存到 {local}。"
            + "附上的图是新锁脸。不要改 git，不要开机，不要画第二张。"
        )
        cmd = tpl.codex_exec_argv(binary, str(local.parent), [str(face_local)])
        result = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=900,
        )
        if result.returncode != 0 or not local.is_file():
            detail = (result.stderr or result.stdout or "codex image missing").strip()
            raise SystemExit(f"CODEX_CLI_FAILED {actor} {view} seed={seed} {detail[-500:]}")
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
            f"scale={tpl.CLOTHED_SCALE} seed={seed} entry=codex",
            scale=tpl.CLOTHED_SCALE,
            seconds=None,
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
            seconds=None,
        )
        path = store_clothed(actor, view, local, record)
        print(
            f"NODE 穿衣 {actor} {view} path={path} seed={seed} "
            f"mean={score.get('mean')} eight={tpl.format_eight(score)}",
            flush=True,
        )
        print(f"CLOTHED_KEEP {path}", flush=True)
        return path


def run_pass2(client, remote: Remote, actor: str, view: str, seed: int, src_remote: str) -> dict:
    """Same seed, larger frame. A miss changes denoise and steps only."""
    if not tpl.pass2_allowed(True):
        raise SystemExit(
            f"{actor} {view} 一采未过门，禁止二采。没有改 scale。作废对 0.85/33 仍不收。"
        )
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
                    "src": src_remote,
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
        if tpl.torso_eaten_by_background(str(local2)):
            print(f"LOCAL_FAIL {actor} {view} seed={seed} 二采头胸被背景吃掉，不送打分", flush=True)
            continue
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
        return {"pass1": {"seed": seed}, "pass2": record, "path": str(final)}
    raise SystemExit(
        f"{actor} {view} 二采未过门。只调了 denoise 和步数，没有改内容，也没有重做一采。"
    )


def run_view(
    client,
    remote: Remote,
    actor: str,
    view: str,
    specified_seed: int,
    *,
    steps: int | None = None,
    scale: float | None = None,
    on_miss: str = "exit",
    enter_pass2: bool = True,
    src_local: Path | None = None,
    plate_tag: str = "",
) -> dict:
    if actor in tpl.FEMALE_ACTORS and not view_clothed_ok(actor, view):
        run_clothed_rebuild(client, remote, actor, view)
    if not view_clothed_ok(actor, view):
        mean = fresh_clothed_mean(actor, view)
        if mean is None and actor not in tpl.FEMALE_ACTORS:
            mean = tpl.CLOTHED_MEAN.get((actor, view))
        raise SystemExit(
            f"{actor} {view} 穿衣底板均分 {mean}，未到 9。先补底板，不去衣。"
        )
    if src_local is None:
        src = resolve_clothed(client, actor, view)
    else:
        src = f"/root/autodl-tmp/in/cast-{actor}-{view}-{plate_tag or 'next'}.png"
        upload = client.open_sftp()
        upload.put(str(src_local), src)
        upload.close()
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
    pass1_steps = tpl.PASS1_STEPS if steps is None else int(steps)
    use_scale = tpl.FIXED_SCALE if scale is None else float(scale)
    # One specified seed. A miss does not step to the next seed.
    # Front and side send the jaw-up crop. Back does not.
    if user_stop_requested(client):
        raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
    seed = tpl.require_specified_seed(specified_seed, actor, view)
    tag = plate_tag or ("" if pass1_steps == tpl.PASS1_STEPS else f"steps{pass1_steps}")
    suffix = f"-{tag}" if tag else ""
    print(
        f"PASS1_TRY {actor} {view} scale={use_scale} seed={seed} steps={pass1_steps}",
        flush=True,
    )
    remote_dest = f"/root/autodl-tmp/out/cast-{actor}-{view}-pass1-seed{seed}{suffix}.png"
    job = {
        "kind": "pass1",
        "scale": use_scale,
        "seed": seed,
        "width": width,
        "height": height,
        "steps": pass1_steps,
        "true_cfg_scale": tpl.ASSET_TRUE_CFG,
        "src": src,
        "prompt": f"/root/autodl-tmp/in/cast-{actor}-{view}-pass1.txt",
        "negative": tpl.negative_for(actor),
        "dest": remote_dest,
    }
    if tpl.feeds_face(view):
        face_local = ROOT / tpl.ref_face_rel(actor)
        if not face_local.is_file():
            raise SystemExit(f"missing face crop {face_local}")
        face_remote = f"/root/autodl-tmp/in/cast-{actor}-ref-face.png"
        face_up = client.open_sftp()
        face_up.put(str(face_local), face_remote)
        face_up.close()
        job["face"] = face_remote
        print(f"PASS1_FACE {face_local}", flush=True)
    else:
        print(f"PASS1_FACE back 不喂锁脸", flush=True)
    done = remote.render(job)
    FAIL.mkdir(parents=True, exist_ok=True)
    local = FAIL / f"{actor}-{view}-pass1-seed{seed}{suffix}.png"
    remote.fetch(done["dest"], local)
    if tpl.torso_eaten_by_background(str(local)):
        print(f"LOCAL_FAIL {actor} {view} seed={seed} 头胸被背景吃掉，不送打分", flush=True)
        score = tpl.local_background_score()
        passed = False
        emit_score(
            local,
            "PASS1",
            actor,
            view,
            score,
            passed,
            seed,
            f"scale={use_scale} seed={seed} steps={pass1_steps}",
            scale=use_scale,
            seconds=done.get("seconds"),
        )
        missed = {
            "passed": False,
            "seed": seed,
            "score": score,
            "path": str(local),
            "steps": pass1_steps,
            "wardrobe": score.get("wardrobe"),
            "pass1_dest": remote_dest,
        }
        if on_miss == "return":
            return missed
        raise SystemExit(f"{actor} {view} seed={seed} 头胸被背景吃掉。禁止二采。")
    score = score_image(local, actor, view, "pass1")
    passed = tpl.accept_pass1(score, actor, view, use_scale, seed)
    emit_score(
        local,
        "PASS1",
        actor,
        view,
        score,
        passed,
        seed,
        f"scale={use_scale} seed={seed} steps={pass1_steps}",
        scale=use_scale,
        seconds=done.get("seconds"),
    )
    if not passed:
        message = (
            f"{actor} {view} seed={seed} 未过门。"
            f"below={tpl.below_nine(score)}。指定籽不递增，禁止二采。"
        )
        print(message, flush=True)
        missed = {
            "passed": False,
            "seed": seed,
            "score": score,
            "path": str(local),
            "steps": pass1_steps,
            "wardrobe": score.get("wardrobe"),
            "pass1_dest": remote_dest,
        }
        if on_miss == "return":
            return missed
        raise SystemExit(message)
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
    row = {
        "passed": True,
        "seed": seed,
        "score": score,
        "path": str(path),
        "steps": pass1_steps,
        "wardrobe": score.get("wardrobe"),
        "pass1_dest": done["dest"],
    }
    if not enter_pass2:
        return row
    return run_pass2(client, remote, actor, view, seed, done["dest"])


def expand_passed(client, remote: Remote, actor: str, view: str, rows: list[dict]) -> None:
    """Pass 2 only for plates that already cleared pass 1."""
    for row in rows:
        if not row.get("passed"):
            continue
        run_pass2(client, remote, actor, view, int(row["seed"]), str(row["pass1_dest"]))


def run_named_batch(client, remote: Remote, actor: str, view: str, seeds: list[int]) -> None:
    """Named pass-1 plates. The Lin front check may enter scheme B. No new seed."""
    rows = []
    for seed in seeds:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        rows.append(
            run_view(
                client,
                remote,
                actor,
                view,
                seed,
                on_miss="return",
                enter_pass2=False,
            )
        )
    chained = (actor, view) == ("lin_wantang", "front") and tuple(seeds) == tpl.LIN_FRONT_A_CHECK
    if not chained:
        expand_passed(client, remote, actor, view, rows)
        return
    decision = tpl.scheme_after_named_pass1(rows)
    print(f"SCHEME_AFTER_A {decision} seeds={list(seeds)}", flush=True)
    if decision == "stop_or_expand":
        expand_passed(client, remote, actor, view, rows)
        return
    if decision != "scheme_b":
        print("SCHEME_STOP 不进 B，不换籽，不跳 C。", flush=True)
        return
    print("SCHEME_B 同一指定籽先 16 步。", flush=True)
    rows16 = []
    for seed in seeds:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        rows16.append(
            run_view(
                client,
                remote,
                actor,
                view,
                seed,
                steps=tpl.B_PASS1_STEPS,
                on_miss="return",
                enter_pass2=False,
            )
        )
    decision16 = tpl.scheme_after_named_pass1(rows16)
    print(f"SCHEME_AFTER_B16 {decision16}", flush=True)
    if decision16 == "stop_or_expand":
        expand_passed(client, remote, actor, view, rows16)
        return
    if decision16 != "scheme_b":
        print("SCHEME_STOP 16 步后不两段，不换籽，不跳 C。", flush=True)
        return
    print("SCHEME_B 两段去衣。第二段用 16 步结果，同一提示，同一籽。", flush=True)
    rows2 = []
    for row in rows16:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        rows2.append(
            run_view(
                client,
                remote,
                actor,
                view,
                int(row["seed"]),
                steps=tpl.PASS1_STEPS,
                on_miss="return",
                enter_pass2=False,
                src_local=Path(row["path"]),
                plate_tag="stage2",
            )
        )
    decision2 = tpl.scheme_after_named_pass1(rows2)
    print(f"SCHEME_AFTER_STAGE2 {decision2}", flush=True)
    if decision2 == "stop_or_expand":
        expand_passed(client, remote, actor, view, rows2)
        return
    print("SCHEME_STOP 两段后仍不换籽，不跳 C。", flush=True)


def run_research(
    client,
    remote: Remote,
    actor: str,
    view: str,
    seeds: list[int],
    steps: int,
    probe_scale: float | None,
) -> None:
    """Pass 1 only. One optional scale probe, then the named seeds at 0.85. No pass 2."""
    print(f"RESEARCH_PROMPT {tpl.pass1_prompt(actor, view)}", flush=True)
    if probe_scale is not None:
        probe_seed = tpl.C_PROBE_SEED
        print(
            f"PROBE_ONCE scale={probe_scale} seed={probe_seed} steps={steps} 不扫 scale",
            flush=True,
        )
        run_view(
            client,
            remote,
            actor,
            view,
            probe_seed,
            steps=steps,
            scale=probe_scale,
            on_miss="return",
            enter_pass2=False,
            plate_tag=f"c-probe-scale{probe_scale:g}",
        )
        print("PROBE_DONE 默认批次回到 0.85。", flush=True)
    for seed in seeds:
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        try:
            run_view(
                client,
                remote,
                actor,
                view,
                seed,
                steps=steps,
                scale=tpl.FIXED_SCALE,
                on_miss="return",
                enter_pass2=False,
                plate_tag=f"noface-steps{steps}",
            )
        except SystemExit as exc:
            text = str(exc)
            if "CODEX_CLI_FAILED" not in text:
                raise
            print(
                f"SCORE_DEFERRED seed={seed} 图已留下，打分失败不中断后面的籽。{text[-180:]}",
                flush=True,
            )
    print("RESEARCH_DONE 一采研究批结束。禁止二采。", flush=True)


def deadline_hit(deadline: datetime | None) -> bool:
    if deadline is None:
        return False
    return datetime.now(timezone.utc) >= deadline


def run_until_pass2(client, remote: Remote, actor: str, view: str, steps: int, deadline: datetime | None) -> dict:
    """Pass 1, then the same seed at pass 2. A miss takes the next unspent seed."""
    used: set[int] = set()
    while True:
        if deadline_hit(deadline):
            raise SystemExit("DEADLINE 到点。关机留盘。")
        if user_stop_requested(client):
            raise SystemExit(f"{actor} {view} 用户叫停。一采未过门，禁止二采。")
        seed = tpl.seed_for(actor, view, 0)
        while seed in used or seed in tpl.spent_seeds(actor, view):
            seed += 1
        used.add(seed)
        print(f"UNTIL_PASS2 {actor} {view} seed={seed} steps={steps}", flush=True)
        try:
            row = run_view(
                client,
                remote,
                actor,
                view,
                seed,
                steps=steps,
                on_miss="return",
                enter_pass2=True,
                plate_tag=f"face-steps{steps}",
            )
        except SystemExit as exc:
            text = str(exc)
            if "二采未过门" in text:
                print(f"PASS2_RESPIN {actor} {view} seed={seed} {text[-160:]}", flush=True)
                continue
            raise
        if isinstance(row, dict) and row.get("pass2"):
            return row
        print(f"PASS1_RESPIN {actor} {view} seed={seed}", flush=True)


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


def post_f34(token: str, action: str) -> dict:
    """power_on or power_off for F34 only. Keep the data disk. Never touch G09."""
    import httpx

    if action not in ("power_on", "power_off"):
        raise SystemExit("F34 只允许 power_on 或 power_off。不释放数据盘，不新建实例。")
    response = httpx.post(
        f"https://www.autodl.com/api/v1/instance/{action}",
        headers={"Authorization": token, "Content-Type": "application/json"},
        json={"instance_uuid": tpl.F34_UUID},
        timeout=60,
    )
    try:
        body = response.json()
    except ValueError as exc:
        raise SystemExit(f"F34 {action} 非 JSON HTTP {response.status_code}") from exc
    if not isinstance(body, dict):
        raise SystemExit(f"F34 {action} 响应不是对象")
    return body


def f34_power_for_work(token: str, status: str, *, has_work: bool, hold_off: bool) -> str:
    """Boot F34 only for a real undress batch. hold_off means the user said 先别开."""
    if not tpl.f34_should_power_on(has_work=has_work, hold_off=hold_off):
        print("F34_HOLD 不开机", flush=True)
        return "hold"
    if status == "running":
        print("F34_ALREADY_ON", flush=True)
        return "running"
    if not token:
        raise SystemExit("F34 有去衣任务要开机，但没有令牌。不开 G09，不新建实例。")
    body = post_f34(token, "power_on")
    print(
        f"F34_POWER_ON {tpl.F34_UUID} code={body.get('code')} msg={body.get('msg')}",
        flush=True,
    )
    return "on"


def wait_f34_running(token: str, timeout_s: int = 600) -> dict:
    """Poll only after this batch powered F34 on. Give up and let the hook shut it down."""
    deadline = time.time() + timeout_s
    last = None
    while time.time() < deadline:
        last = f34_instance(token)
        if last.get("status") == "running":
            return last
        time.sleep(15)
    status = None if last is None else last.get("status")
    raise SystemExit(f"F34 开机后状态仍是 {status}。关机留盘，不空转。")


def f34_shutdown_hook(token: str, *, finished: bool, paused: bool, keep_on: bool) -> str:
    """Power off and keep the disk when the batch finishes or pauses."""
    if not tpl.f34_should_power_off(finished=finished, paused=paused, keep_on=keep_on):
        print("F34_KEEP_ON 用户当次说别关", flush=True)
        return "keep"
    if not token:
        raise SystemExit("F34 要关机留盘，但没有令牌。禁止空转。")
    body = post_f34(token, "power_off")
    print(
        f"F34_POWER_OFF {tpl.F34_UUID} 关机留盘 code={body.get('code')} msg={body.get('msg')}",
        flush=True,
    )
    return "off"


def main() -> None:
    parser = argparse.ArgumentParser(description="Cast body template pipeline on F34")
    parser.add_argument("--only", default="lin_wantang:front", help="actor:view comma list")
    parser.add_argument("--doctor", action="store_true", help="Check F34 and balance, do not render")
    parser.add_argument("--login-check", action="store_true", help="SSH once with the shared password and stop")
    parser.add_argument("--shutdown", action="store_true", help="Power off F34 after the run and print balance")
    parser.add_argument("--keep-on", action="store_true", help="用户当次明确说别关")
    parser.add_argument("--hold-off", action="store_true", help="用户当次明确说先别开")
    parser.add_argument("--seed", default=None, help="指定一采籽，逗号分隔。未指定不跑")
    parser.add_argument("--research", action="store_true", help="一采研究批。禁止二采。")
    parser.add_argument("--steps", type=int, default=None, help="当次一采步数。研究批默认 16。")
    parser.add_argument("--until-pass2", action="store_true", help="一采过门才二采，不过门换下一颗未花籽")
    parser.add_argument("--deadline", default=None, help="ISO 时间，到点关机留盘")
    parser.add_argument("--probe-scale", type=float, default=None, help="只对籽 62 试一次这个 scale")
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
    if not token:
        try:
            token = load_token()
        except SystemExit:
            token = ""
    if token:
        item = f34_instance(token)
    print(
        f"f34 status={item.get('status')} port={item.get('ssh_port')} host={item.get('proxy_host')}",
        flush=True,
    )
    print(tpl.F34_POWER_RULE, flush=True)
    used_f34 = False
    paused = Path(tpl.STOP_LOCAL).is_file()
    try:
        if args.doctor:
            if item.get("status") == "running":
                used_f34 = True
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
            if item.get("status") == "running":
                used_f34 = True
            client = connect(item)
            try:
                mode = ssh_exec(client, f"stat -c '%a %U %s' {REMOTE_CAST_SSH}").strip()
                print(f"cast_ssh_env {mode}", flush=True)
                print("资产登录已通", flush=True)
                print(tpl.self_run_line(), flush=True)
            finally:
                client.close()
            return
        deadline = None
        if args.deadline:
            deadline = datetime.fromisoformat(args.deadline)
            if deadline.tzinfo is None:
                deadline = deadline.replace(tzinfo=timezone.utc)
        if args.until_pass2:
            seeds = []
        else:
            seeds = tpl.parse_specified_seeds(args.seed)
            for actor, view in parse_only(args.only):
                for seed in seeds:
                    tpl.require_specified_seed(seed, actor, view)
        boot = f34_power_for_work(
            token,
            str(item.get("status") or ""),
            has_work=True,
            hold_off=args.hold_off,
        )
        if boot == "hold":
            print("F34_HOLD_OFF 先别开。不去衣，不开机。", flush=True)
            return
        used_f34 = True
        if boot == "on":
            item = wait_f34_running(token)
        print(tpl.self_run_line(), flush=True)
        client = connect(item)
        try:
            ensure_worker(client)
            print("NODE 工作流做好 女锁脸=2026-10-06-front 男演员不动 出片不代跑", flush=True)
            remote = Remote(client)
            for actor, view in parse_only(args.only):
                if user_stop_requested(client):
                    paused = True
                    raise SystemExit(f"{actor} {view} 用户叫停。关机留盘，不去衣。")
                if args.until_pass2:
                    steps = tpl.C_PASS1_STEPS if args.steps is None else int(args.steps)
                    run_until_pass2(client, remote, actor, view, steps, deadline)
                elif args.research:
                    steps = tpl.C_PASS1_STEPS if args.steps is None else int(args.steps)
                    run_research(client, remote, actor, view, seeds, steps, args.probe_scale)
                else:
                    run_named_batch(client, remote, actor, view, seeds)
        finally:
            client.close()
    finally:
        paused = paused or Path(tpl.STOP_LOCAL).is_file()
        if used_f34 or args.shutdown:
            f34_shutdown_hook(
                token,
                finished=not paused,
                paused=paused,
                keep_on=args.keep_on and not args.shutdown,
            )


if __name__ == "__main__":
    main()
