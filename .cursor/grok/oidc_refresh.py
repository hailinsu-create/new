#!/usr/bin/env python3
"""Refresh grok.com OIDC access tokens in ~/.grok/auth.json.

Prints only safe metadata (email, expires_at, remaining_hours).
Never prints access tokens, refresh tokens, JWTs, or auth.json contents.

Exit codes:
  0  refreshed
  1  no refresh_token / no OIDC entry
  2  invalid_grant or HTTP/protocol error (device login required)
"""
from __future__ import annotations

import base64
import json
import os
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

DEFAULT_ISSUER = "https://auth.x.ai"
TIMEOUT = 20
AUTH_PATH = os.path.expanduser("~/.grok/auth.json")


class OIDCRefreshError(Exception):
    def __init__(self, message: str, code: int) -> None:
        super().__init__(message)
        self.code = code


def jwt_exp(token: str) -> int | None:
    if not token or token.count(".") < 2:
        return None
    payload = token.split(".")[1]
    pad = "=" * ((4 - len(payload) % 4) % 4)
    try:
        data = json.loads(base64.urlsafe_b64decode(payload + pad))
    except Exception:
        return None
    try:
        return int(data.get("exp"))
    except (TypeError, ValueError):
        return None


def format_expires_at(dt: datetime) -> str:
    utc = dt.astimezone(timezone.utc)
    return utc.strftime("%Y-%m-%dT%H:%M:%S") + f".{utc.microsecond:06d}Z"


def parse_error_field(raw: bytes) -> str:
    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception:
        return "unknown"
    if isinstance(data, dict) and data.get("error"):
        return str(data["error"])
    return "unknown"


def find_oidc_entry(data: object) -> tuple[str, dict] | None:
    if not isinstance(data, dict):
        return None
    for key, value in data.items():
        if not isinstance(value, dict):
            continue
        if value.get("refresh_token") and value.get("oidc_client_id"):
            return str(key), value
    return None


def http_json(
    urlopen,
    method: str,
    url: str,
    data: bytes | None = None,
    timeout: int = TIMEOUT,
) -> dict:
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
    req.add_header("Accept", "application/json")
    try:
        with urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        raw = b""
        try:
            raw = exc.read() if exc.fp is not None else b""
        except Exception:
            raw = b""
        err = parse_error_field(raw)
        raise OIDCRefreshError(f"HTTP {exc.code} error={err}", 2) from None
    except urllib.error.URLError as exc:
        reason = getattr(exc, "reason", exc)
        raise OIDCRefreshError(f"HTTP error: {reason}", 2) from None
    except TimeoutError:
        raise OIDCRefreshError("HTTP error: timeout", 2) from None
    try:
        parsed = json.loads(raw.decode("utf-8"))
    except Exception:
        raise OIDCRefreshError(f"HTTP {status} error=unknown", 2) from None
    if not isinstance(parsed, dict):
        raise OIDCRefreshError(f"HTTP {status} error=unknown", 2)
    if parsed.get("error") and not parsed.get("access_token"):
        raise OIDCRefreshError(
            f"HTTP {status} error={parsed.get('error')}", 2
        )
    return parsed


def discover_token_endpoint(urlopen, issuer: str, timeout: int = TIMEOUT) -> str:
    base = issuer.rstrip("/")
    url = f"{base}/.well-known/openid-configuration"
    parsed = http_json(urlopen, "GET", url, timeout=timeout)
    endpoint = parsed.get("token_endpoint")
    if not endpoint or not isinstance(endpoint, str):
        raise OIDCRefreshError("HTTP error: missing token_endpoint", 2)
    return endpoint


def expires_at_from_response(payload: dict) -> datetime:
    expires_in = payload.get("expires_in")
    if expires_in is not None and str(expires_in) != "":
        try:
            seconds = int(expires_in)
            if seconds > 0:
                return datetime.now(timezone.utc) + timedelta(seconds=seconds)
        except (TypeError, ValueError):
            pass
    exp = jwt_exp(str(payload.get("access_token") or ""))
    if exp:
        return datetime.fromtimestamp(exp, tz=timezone.utc)
    raise OIDCRefreshError("token response missing expires_in and JWT exp", 2)


def atomic_write_json(path: str, data: dict) -> None:
    directory = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".auth.json.", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def refresh_auth_file(
    path: str,
    urlopen=urllib.request.urlopen,
    timeout: int = TIMEOUT,
) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        raise OIDCRefreshError("no refresh_token", 1) from None
    except Exception:
        raise OIDCRefreshError("no refresh_token", 1) from None

    found = find_oidc_entry(data)
    if found is None:
        raise OIDCRefreshError("no refresh_token", 1)
    _key, entry = found
    refresh_token = entry.get("refresh_token")
    client_id = entry.get("oidc_client_id")
    if not refresh_token or not client_id:
        raise OIDCRefreshError("no refresh_token", 1)

    issuer = entry.get("oidc_issuer") or DEFAULT_ISSUER
    token_endpoint = discover_token_endpoint(urlopen, str(issuer), timeout=timeout)
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": client_id,
        }
    ).encode("utf-8")
    payload = http_json(urlopen, "POST", token_endpoint, data=body, timeout=timeout)
    access_token = payload.get("access_token")
    if not access_token or not isinstance(access_token, str):
        raise OIDCRefreshError("HTTP error: missing access_token", 2)

    expires_dt = expires_at_from_response(payload)
    expires_at = format_expires_at(expires_dt)
    entry["key"] = access_token
    new_refresh = payload.get("refresh_token")
    if new_refresh:
        entry["refresh_token"] = new_refresh
    entry["expires_at"] = expires_at
    atomic_write_json(path, data)

    remaining = (expires_dt - datetime.now(timezone.utc)).total_seconds()
    return {
        "email": str(entry.get("email") or ""),
        "expires_at": expires_at,
        "remaining_hours": remaining / 3600.0,
    }


def main(argv: list[str] | None = None, urlopen=urllib.request.urlopen) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    path = AUTH_PATH
    if args[:1] == ["--auth-file"] and len(args) >= 2:
        path = args[1]
        args = args[2:]
    elif args:
        print("usage: oidc_refresh.py [--auth-file PATH]", file=sys.stderr)
        return 1
    try:
        meta = refresh_auth_file(path, urlopen=urlopen)
    except OIDCRefreshError as exc:
        print(f"oidc refresh: {exc}", file=sys.stderr)
        return exc.code
    except OSError as exc:
        print(f"oidc refresh: HTTP error: {exc}", file=sys.stderr)
        return 2
    print(
        "refreshed"
        f" email={meta['email']}"
        f" expires_at={meta['expires_at']}"
        f" remaining_hours={meta['remaining_hours']:.2f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
