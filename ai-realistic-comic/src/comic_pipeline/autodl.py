"""AutoDL Pro API + SSH runner: rent GPU, run still smoke, pull results, power off."""
from __future__ import annotations

import json
import shlex
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

from comic_pipeline.config import Settings

API = "https://api.autodl.com"

# Defaults from AutoDL Pro API appendix (override via env).
DEFAULT_GPU = "4090D"
DEFAULT_IMAGE = "base-image-l2t43iu6uk"  # PyTorch 2.0 / CUDA 11.8
DEFAULT_CUDA_FROM = 118


class AutodlError(RuntimeError):
    pass


@dataclass
class SshInfo:
    host: str
    port: int
    password: str
    command: str = ""


class AutodlClient:
    def __init__(self, token: str, timeout: float = 60.0) -> None:
        if not token.strip():
            raise AutodlError(
                "AUTODL_TOKEN is empty. Console → 账号 → 设置 → 开发者Token, "
                "then put it in .env or Cloud Secrets."
            )
        self.token = token.strip()
        self.timeout = timeout

    def _headers(self) -> dict[str, str]:
        return {"Authorization": self.token, "Content-Type": "application/json"}

    def _request(self, method: str, path: str, body: dict | None = None) -> Any:
        url = f"{API}{path}"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.request(method, url, headers=self._headers(), json=body or {})
        try:
            data = resp.json()
        except Exception as exc:  # noqa: BLE001
            raise AutodlError(f"AutoDL {method} {path}: non-JSON ({resp.status_code}) {resp.text[:300]}") from exc
        if resp.status_code >= 400:
            raise AutodlError(f"AutoDL {method} {path}: HTTP {resp.status_code} {data}")
        code = data.get("code")
        if code not in (None, "Success", 0, "0", "success"):
            # Some endpoints return code as string Success
            if str(code).lower() != "success":
                raise AutodlError(f"AutoDL {method} {path} failed: {data}")
        return data.get("data", data)

    def balance(self) -> Any:
        return self._request("POST", "/api/v1/dev/wallet/balance")

    def create(
        self,
        *,
        gpu_spec: str,
        image_uuid: str,
        cuda_v_from: int,
        name: str,
        gpu_amount: int = 1,
        expand_gb: int = 0,
        data_centers: list[str] | None = None,
        start_command: str = "sleep 1",
    ) -> str:
        body: dict[str, Any] = {
            "req_gpu_amount": gpu_amount,
            "expand_system_disk_by_gb": expand_gb,
            "gpu_spec_uuid": gpu_spec,
            "image_uuid": image_uuid,
            "cuda_v_from": cuda_v_from,
            "instance_name": name,
            "start_command": start_command,
        }
        if data_centers:
            body["data_center_list"] = data_centers
        uuid = self._request("POST", "/api/v1/dev/instance/pro/create", body)
        if isinstance(uuid, dict):
            uuid = uuid.get("instance_uuid") or uuid.get("uuid") or uuid
        return str(uuid)

    def status(self, instance_uuid: str) -> str:
        try:
            data = self._request("GET", "/api/v1/dev/instance/pro/status", {"instance_uuid": instance_uuid})
        except AutodlError:
            data = self._request("POST", "/api/v1/dev/instance/pro/status", {"instance_uuid": instance_uuid})
        if isinstance(data, dict):
            return str(data.get("status") or data.get("sub_status") or data)
        return str(data)

    def snapshot(self, instance_uuid: str) -> dict:
        try:
            data = self._request("GET", "/api/v1/dev/instance/pro/snapshot", {"instance_uuid": instance_uuid})
        except AutodlError:
            data = self._request("POST", "/api/v1/dev/instance/pro/snapshot", {"instance_uuid": instance_uuid})
        if not isinstance(data, dict):
            raise AutodlError(f"Unexpected snapshot payload: {data!r}")
        return data

    def list_instances(self, page_index: int = 1, page_size: int = 20) -> list[dict]:
        data = self._request(
            "POST",
            "/api/v1/dev/instance/pro/list",
            {"page_index": page_index, "page_size": page_size},
        )
        if isinstance(data, dict):
            return list(data.get("list") or [])
        return list(data or [])

    def power_on(self, instance_uuid: str, start_command: str = "sleep 1") -> Any:
        return self._request(
            "POST",
            "/api/v1/dev/instance/pro/power_on",
            {"instance_uuid": instance_uuid, "payload": "gpu", "start_command": start_command},
        )

    def power_off(self, instance_uuid: str) -> Any:
        return self._request(
            "POST",
            "/api/v1/dev/instance/pro/power_off",
            {"instance_uuid": instance_uuid},
        )

    def wait_running(self, instance_uuid: str, timeout_s: int = 900, poll_s: int = 10) -> str:
        deadline = time.time() + timeout_s
        last = ""
        while time.time() < deadline:
            last = self.status(instance_uuid)
            print(f"[autodl] status={last}")
            if last in {"running", "Running", "RUNNING"}:
                return last
            if last in {"create_failed", "error", "Error"}:
                raise AutodlError(f"Instance entered bad status: {last}")
            time.sleep(poll_s)
        raise AutodlError(f"Timed out waiting for running (last={last})")

    def ssh_info(self, instance_uuid: str) -> SshInfo:
        snap = self.snapshot(instance_uuid)
        host = str(snap.get("proxy_host") or "")
        port = int(snap.get("ssh_port") or 0)
        password = str(snap.get("root_password") or "")
        command = str(snap.get("ssh_command") or "")
        if not host or not port or not password:
            # parse from ssh_command: ssh -p PORT root@HOST
            if command:
                parts = command.split()
                if "-p" in parts:
                    i = parts.index("-p")
                    port = int(parts[i + 1])
                for p in parts:
                    if "@" in p:
                        host = p.split("@", 1)[1]
            if not host or not port or not password:
                raise AutodlError(f"Snapshot missing SSH fields: keys={list(snap)}")
        return SshInfo(host=host, port=port, password=password, command=command)


def _ssh_connect(info: SshInfo, retries: int = 30, delay: float = 10.0):
    try:
        import paramiko
    except ImportError as exc:
        raise AutodlError("paramiko is required for AutoDL SSH. pip install paramiko") from exc
    last: Exception | None = None
    for i in range(retries):
        try:
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            client.connect(
                info.host,
                port=info.port,
                username="root",
                password=info.password,
                timeout=30,
                banner_timeout=60,
                auth_timeout=30,
            )
            return client
        except Exception as exc:  # noqa: BLE001
            last = exc
            print(f"[autodl] SSH retry {i + 1}/{retries}: {exc}")
            time.sleep(delay)
    raise AutodlError(f"SSH connect failed: {last}")


def _ssh_run(client, command: str, timeout: int = 7200) -> tuple[int, str, str]:
    print(f"[autodl] $ {command[:200]}{'…' if len(command) > 200 else ''}")
    _, stdout, stderr = client.exec_command(command, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out:
        print(out[-4000:] if len(out) > 4000 else out)
    if err and code != 0:
        print(err[-2000:] if len(err) > 2000 else err)
    return code, out, err


def _sftp_download_dir(client, remote: str, local: Path) -> list[Path]:
    sftp = client.open_sftp()
    local.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    try:
        for name in sftp.listdir(remote):
            if name.startswith("."):
                continue
            rpath = f"{remote.rstrip('/')}/{name}"
            lpath = local / name
            try:
                sftp.get(rpath, str(lpath))
                saved.append(lpath)
                print(f"[autodl] downloaded {lpath}")
            except OSError:
                # skip directories
                continue
    finally:
        sftp.close()
    return saved


def resolve_ssh(settings: Settings, client: AutodlClient | None, instance_uuid: str = "") -> tuple[SshInfo, str]:
    """Return SSH info and instance uuid (uuid may be empty in pure-SSH mode)."""
    if settings.autodl_ssh_host.strip() and settings.autodl_ssh_password.strip():
        info = SshInfo(
            host=settings.autodl_ssh_host.strip(),
            port=int(settings.autodl_ssh_port or 22),
            password=settings.autodl_ssh_password,
        )
        return info, instance_uuid or settings.autodl_instance_uuid.strip()
    if client is None:
        raise AutodlError("Need AUTODL_TOKEN (API) or AUTODL_SSH_HOST + AUTODL_SSH_PASSWORD.")
    uuid = instance_uuid or settings.autodl_instance_uuid.strip()
    if not uuid:
        raise AutodlError("AUTODL_INSTANCE_UUID missing and no SSH host set.")
    return client.ssh_info(uuid), uuid


def ensure_instance(settings: Settings) -> tuple[AutodlClient | None, str]:
    """Create or power on an instance. Returns (api_client_or_none, uuid)."""
    token = settings.autodl_token.strip()
    uuid = settings.autodl_instance_uuid.strip()
    if settings.autodl_ssh_host.strip() and settings.autodl_ssh_password.strip() and not token:
        return None, uuid
    if not token:
        raise AutodlError("Set AUTODL_TOKEN, or set AUTODL_SSH_HOST/PORT/PASSWORD for an already-running box.")
    api = AutodlClient(token)
    if uuid:
        st = api.status(uuid)
        print(f"[autodl] existing {uuid} status={st}")
        if st not in {"running", "Running", "RUNNING"}:
            api.power_on(uuid)
            api.wait_running(uuid, timeout_s=settings.autodl_boot_timeout_s)
        return api, uuid
    print("[autodl] creating instance…")
    uuid = api.create(
        gpu_spec=settings.autodl_gpu_spec or DEFAULT_GPU,
        image_uuid=settings.autodl_image_uuid or DEFAULT_IMAGE,
        cuda_v_from=settings.autodl_cuda_v_from or DEFAULT_CUDA_FROM,
        name=settings.autodl_instance_name or "comic-still-smoke",
        expand_gb=settings.autodl_expand_gb,
    )
    print(f"[autodl] created {uuid}")
    for hint in (Path("/tmp/autodl_instance_uuid.txt"), Path("output/autodl/last_instance.txt")):
        hint.parent.mkdir(parents=True, exist_ok=True)
        hint.write_text(uuid + "\n", encoding="utf-8")
    print("[autodl] save this as AUTODL_INSTANCE_UUID to reuse the box")
    api.wait_running(uuid, timeout_s=settings.autodl_boot_timeout_s)
    return api, uuid


REMOTE_ROOT = "/root/autodl-tmp/new/ai-realistic-comic"
REMOTE_OUT = "/root/autodl-tmp/out"


def run_remote_smoke(settings: Settings, branch: str, stills: list[str]) -> Path:
    """Full automated job. Pulls results into output/autodl/<timestamp>/."""
    api, uuid = ensure_instance(settings)
    local_out = Path("output") / "autodl" / time.strftime("%Y%m%d-%H%M%S")
    local_out.mkdir(parents=True, exist_ok=True)
    meta = {"instance_uuid": uuid, "branch": branch, "stills": stills}
    (local_out / "run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    stopped = False
    try:
        info, uuid = resolve_ssh(settings, api, uuid)
        print(f"[autodl] SSH {info.host}:{info.port}")
        client = _ssh_connect(info)
        try:
            repo = shlex.quote(f"https://github.com/hailinsu-create/new.git")
            br = shlex.quote(branch)
            still_args = " ".join(shlex.quote(s) for s in stills)
            script = f"""
set -euo pipefail
export HF_HOME=/root/autodl-tmp/hf
export HUGGINGFACE_HUB_CACHE=$HF_HOME/hub
export TRANSFORMERS_CACHE=$HF_HOME/transformers
export IMAGE_PROVIDER=local
export LOCAL_STILL_MODEL={shlex.quote(settings.local_still_model)}
export LOCAL_CANDIDATES={int(settings.local_candidates)}
export COMIC_QA=0 COMIC_ANATOMY_AUDIT=0 COMIC_STRICT_AUDIT=0
mkdir -p /root/autodl-tmp
cd /root/autodl-tmp
if [ ! -d new/.git ]; then
  git clone --depth 1 --branch {br} {repo} new
else
  cd new && git fetch --depth 1 origin {br} && git checkout {br} && git reset --hard origin/{br} && cd ..
fi
cd new/ai-realistic-comic
bash autodl/bootstrap.sh
# run specific stills (or default smoke)
if [ -n "{still_args}" ]; then
  mkdir -p /root/autodl-tmp/out
  for s in {still_args}; do
    comic still-library "$s"
    cp -f "output/library-stills/$s/final.png" "/root/autodl-tmp/out/$s.png" || true
  done
else
  bash autodl/run_smoke.sh
fi
ls -la /root/autodl-tmp/out || true
"""
            code, out, err = _ssh_run(client, f"bash -lc {shlex.quote(script)}", timeout=settings.autodl_job_timeout_s)
            (local_out / "remote.log").write_text(out + "\n--- stderr ---\n" + err, encoding="utf-8")
            _ssh_run(client, "ls -la /root/autodl-tmp/out", timeout=60)
            if code != 0:
                raise AutodlError(f"Remote job failed with exit {code}. See {local_out / 'remote.log'}")
            saved = _sftp_download_dir(client, REMOTE_OUT, local_out)
            if not saved:
                raise AutodlError("No files downloaded from /root/autodl-tmp/out")
            meta["files"] = [str(p.name) for p in saved]
            (local_out / "run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        finally:
            client.close()
    finally:
        if settings.autodl_auto_stop and api is not None and uuid:
            try:
                print(f"[autodl] power_off {uuid}")
                api.power_off(uuid)
                stopped = True
            except Exception as exc:  # noqa: BLE001
                print(f"[autodl] WARN power_off failed: {exc}")
                meta["power_off_error"] = str(exc)[:200]
                (local_out / "run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        meta["powered_off"] = stopped
        (local_out / "run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    return local_out


def stop_instance(settings: Settings) -> None:
    token = settings.autodl_token.strip()
    uuid = settings.autodl_instance_uuid.strip()
    if not token or not uuid:
        raise AutodlError("AUTODL_TOKEN and AUTODL_INSTANCE_UUID required to stop.")
    AutodlClient(token).power_off(uuid)
    print(f"[autodl] power_off requested for {uuid}")
