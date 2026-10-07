"""Power on / balance helper for the Beijing B ordinary container instance.

Two different credentials, two different APIs:

- Web session JWT (`AUTODL_WEB_AUTHORIZATION`): ordinary container instances such as
  Beijing B 791 `359a49a1c3-4cda10df` have no developer API. Power on goes through
  the web endpoint `POST https://www.autodl.com/api/v1/instance/power_on` with body
  `{"instance_uuid": ..., "payload": "gpu"}`. `payload` is always `gpu`; the no-card
  mode is forbidden.
- Developer token (`AUTODL_TOKEN`): Pro-only developer APIs. Here it is used only for
  the wallet balance (`POST https://api.autodl.com/api/v1/dev/wallet/balance`).
  `/api/v1/dev/instance/pro/power_on` returns RecordNotFoundError for this instance.

Secrets are read from the environment or the shared env files and never printed.
F34 and G09 UUIDs are refused. A "no idle GPU" answer is retried with backoff; any
other failure (auth, unknown instance) stops at once so nothing burns money.

    python autodl_power.py balance
    python autodl_power.py power-on [--max-minutes 120]
    python autodl_power.py ensure-on [--max-minutes 120]   # web JWT, then developer token, else NEED_AUTODL_TOKEN
    python autodl_power.py power-on-once      # exit 0 ok, 5 no GPU, 6 transient, 2 fatal, 4 no web auth
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

WEB_POWER_ON = "https://www.autodl.com/api/v1/instance/power_on"
DEV_BALANCE = "https://api.autodl.com/api/v1/dev/wallet/balance"
DEV_POWER_ON = "https://api.autodl.com/api/v1/dev/instance/pro/power_on"
DEFAULT_UUID = "359a49a1c3-4cda10df"
FORBIDDEN = {"xaxna66hqt-c5c9c7fc", "sa4eaxgcuq-26e36fc9"}
WEB_AUTH_FILES = (
    Path("/cursor/stores/user/autodl-web-auth.env"),
    Path("/workspace/cred-handoff/autodl-web-auth.env"),
)
TOKEN_FILES = (Path("/cursor/stores/user/autodl-token.env"),)
SSH_ENV = Path("/cursor/stores/user/bjb-ssh.env")
NO_GPU_MARKERS = ("GPU不足", "空闲GPU", "gpu不足", "no idle gpu", "InsufficientGpu")
BACKOFF = (20, 30, 45, 60)


def read_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return out
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip().strip('"').strip("'")
    return out


def find_secret(name: str, files: tuple[Path, ...]) -> str | None:
    value = os.environ.get(name)
    if value:
        return value
    for path in files:
        value = read_env_file(path).get(name)
        if value:
            return value
    return None


def web_authorization() -> str | None:
    return find_secret("AUTODL_WEB_AUTHORIZATION", WEB_AUTH_FILES)


def dev_token() -> str | None:
    return find_secret("AUTODL_TOKEN", TOKEN_FILES)


def instance_uuid(explicit: str | None = None) -> str:
    uuid = explicit or os.environ.get("BJB_INSTANCE_UUID") or read_env_file(SSH_ENV).get("BJB_INSTANCE_UUID") or DEFAULT_UUID
    if uuid in FORBIDDEN:
        raise SystemExit(f"FORBIDDEN_INSTANCE {uuid}")
    return uuid


def post(url: str, headers: dict[str, str], body: dict | None, timeout: int = 30) -> tuple[int, dict]:
    data = json.dumps(body if body is not None else {}).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", **headers}, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8", "replace")
            status = response.status
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        status = exc.code
    except (urllib.error.URLError, TimeoutError) as exc:
        return 0, {"code": "NetworkError", "msg": str(exc)}
    try:
        return status, json.loads(raw)
    except json.JSONDecodeError:
        return status, {"code": "BadResponse", "msg": raw[:200]}


def classify(status: int, reply: dict) -> str:
    """success | no_gpu | retry | fatal"""
    code = str(reply.get("code", ""))
    msg = str(reply.get("msg", ""))
    if code == "Success":
        return "success"
    if any(marker.lower() in msg.lower() or marker.lower() in code.lower() for marker in NO_GPU_MARKERS):
        return "no_gpu"
    if code == "NetworkError" or status >= 500 or status == 429:
        return "retry"
    return "fatal"


def power_on_once(uuid: str, authorization: str) -> tuple[str, dict]:
    status, reply = post(WEB_POWER_ON, {"Authorization": authorization}, {"instance_uuid": uuid, "payload": "gpu"})
    return classify(status, reply), reply


NEED_TOKEN_MESSAGE = (
    "NEED_AUTODL_TOKEN no AUTODL_WEB_AUTHORIZATION and no AUTODL_TOKEN. Looked in the environment "
    "(Cursor Secrets are injected there), then /cursor/stores/user/autodl-web-auth.env and "
    "/cursor/stores/user/autodl-token.env (also /workspace/cred-handoff/autodl-web-auth.env). "
    "Never commit them. Note: the developer token only works for Pro instances; Beijing B 791 is an "
    "ordinary container instance and needs the web JWT."
)


def dev_power_on_once(uuid: str, token: str) -> tuple[str, dict]:
    """Developer API. Pro instances only; an ordinary instance answers RecordNotFoundError."""
    status, reply = post(DEV_POWER_ON, {"Authorization": token}, {"instance_uuid": uuid, "payload": "gpu"})
    code = str(reply.get("code", ""))
    if code == "RecordNotFoundError":
        return "not_pro", reply
    return classify(status, reply), reply


def ensure_on(uuid: str, *, max_minutes: float, sleep=time.sleep, now=time.monotonic) -> int:
    """Web JWT first (works for ordinary instances), developer token second. Exit 4 when neither exists."""
    authorization = web_authorization()
    token = dev_token()
    if not authorization and not token:
        print(NEED_TOKEN_MESSAGE, flush=True)
        return 4
    if authorization:
        return power_on_loop(uuid, authorization, max_minutes=max_minutes, sleep=sleep, now=now)
    verdict, reply = dev_power_on_once(uuid, token or "")
    print(f"POWER_ON_DEV verdict={verdict} code={reply.get('code')} msg={str(reply.get('msg', ''))[:120]}", flush=True)
    if verdict == "not_pro":
        print(
            "POWER_ON_STOP the developer token cannot power on an ordinary container instance "
            "(RecordNotFoundError). Provide AUTODL_WEB_AUTHORIZATION. No clone, no no-GPU mode.",
            flush=True,
        )
        return 2
    if verdict == "success":
        return 0
    return power_on_loop_dev(uuid, token or "", verdict, max_minutes=max_minutes, sleep=sleep, now=now)


def power_on_loop_dev(uuid: str, token: str, first: str, *, max_minutes: float, sleep, now) -> int:
    deadline = now() + max_minutes * 60
    verdict = first
    attempt = 0
    while verdict in ("no_gpu", "retry"):
        wait = BACKOFF[min(attempt, len(BACKOFF) - 1)]
        attempt += 1
        if now() + wait > deadline:
            print("POWER_ON_GAVE_UP deadline reached; still no GPU.", flush=True)
            return 3
        sleep(wait)
        verdict, reply = dev_power_on_once(uuid, token)
        print(f"POWER_ON_DEV attempt={attempt} verdict={verdict} code={reply.get('code')}", flush=True)
    return 0 if verdict == "success" else 2


def power_on_loop(uuid: str, authorization: str, *, max_minutes: float, sleep=time.sleep, now=time.monotonic) -> int:
    deadline = now() + max_minutes * 60
    attempt = 0
    while True:
        verdict, reply = power_on_once(uuid, authorization)
        code, msg = reply.get("code"), str(reply.get("msg", ""))[:120]
        print(f"POWER_ON attempt={attempt} verdict={verdict} code={code} msg={msg}", flush=True)
        if verdict == "success":
            return 0
        if verdict == "fatal":
            print("POWER_ON_STOP fatal reply; not retrying (auth expired or wrong instance).", flush=True)
            return 2
        wait = BACKOFF[min(attempt, len(BACKOFF) - 1)]
        attempt += 1
        if now() + wait > deadline:
            print("POWER_ON_GAVE_UP deadline reached; still no GPU.", flush=True)
            return 3
        sleep(wait)


def balance() -> int:
    token = dev_token()
    if not token:
        print("BALANCE_PENDING no AUTODL_TOKEN; read the balance on the web console.")
        return 1
    status, reply = post(DEV_BALANCE, {"Authorization": token}, None)
    if str(reply.get("code")) != "Success":
        print(f"BALANCE_FAILED code={reply.get('code')} msg={str(reply.get('msg', ''))[:120]}")
        return 1
    data = reply.get("data") or {}
    assets = data.get("assets")
    if assets is None:
        print(f"BALANCE_UNKNOWN_SHAPE keys={sorted(data)}")
        return 1
    print(f"BALANCE assets_li={assets} yuan={assets / 1000:.2f}")
    if assets < 5000:
        print("BALANCE_WARNING below 5 yuan; alert only, do not top up.")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("balance")
    ensure = sub.add_parser("ensure-on")
    ensure.add_argument("--uuid")
    ensure.add_argument("--max-minutes", type=float, default=120)
    once = sub.add_parser("power-on-once")
    once.add_argument("--uuid")
    on = sub.add_parser("power-on")
    on.add_argument("--uuid")
    on.add_argument("--max-minutes", type=float, default=120)
    args = parser.parse_args()
    if args.cmd == "balance":
        raise SystemExit(balance())
    if args.cmd == "ensure-on":
        raise SystemExit(ensure_on(instance_uuid(args.uuid), max_minutes=args.max_minutes))
    authorization = web_authorization()
    if not authorization:
        print("WEB_AUTH_MISSING set AUTODL_WEB_AUTHORIZATION or autodl-web-auth.env; the developer token cannot power on this instance.")
        raise SystemExit(4)
    if args.cmd == "power-on-once":
        verdict, reply = power_on_once(instance_uuid(args.uuid), authorization)
        print(f"POWER_ON_ONCE verdict={verdict} code={reply.get('code')} msg={str(reply.get('msg', ''))[:120]}")
        raise SystemExit({"success": 0, "no_gpu": 5, "retry": 6}.get(verdict, 2))
    raise SystemExit(power_on_loop(instance_uuid(args.uuid), authorization, max_minutes=args.max_minutes))


if __name__ == "__main__":
    main()
