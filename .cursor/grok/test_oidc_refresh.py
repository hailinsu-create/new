#!/usr/bin/env python3
"""Mocked OIDC refresh tests. Does not use real tokens or the network."""
from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
import urllib.error
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oidc_refresh  # noqa: E402

SECRET_ACCESS = "SECRET_ACCESS_TOKEN_xyz.aaa.bbb"
SECRET_REFRESH = "SECRET_REFRESH_TOKEN_xyz"
NEW_ACCESS = "SECRET_NEW_ACCESS_TOKEN_xyz.ccc.ddd"
NEW_REFRESH = "SECRET_NEW_REFRESH_TOKEN_xyz"
TOKEN_URL = "https://auth.x.ai/oauth2/token"
DISCOVERY = {
    "issuer": "https://auth.x.ai",
    "token_endpoint": TOKEN_URL,
}


def sample_auth(expires_at: str) -> dict:
    return {
        "https://auth.x.ai::client": {
            "key": SECRET_ACCESS,
            "auth_mode": "oidc",
            "email": "user@example.com",
            "refresh_token": SECRET_REFRESH,
            "expires_at": expires_at,
            "oidc_issuer": "https://auth.x.ai",
            "oidc_client_id": "client-id",
        }
    }


class FakeResponse:
    def __init__(self, payload: dict, status: int = 200) -> None:
        self._raw = json.dumps(payload).encode("utf-8")
        self.status = status

    def read(self) -> bytes:
        return self._raw

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class FakeUrlOpen:
    def __init__(self, responses: list) -> None:
        self._responses = list(responses)
        self.requests = []

    def __call__(self, req, timeout=None):
        self.requests.append(req)
        item = self._responses.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


def http_error(status: int, error: str) -> urllib.error.HTTPError:
    body = json.dumps({"error": error}).encode("utf-8")
    return urllib.error.HTTPError(
        TOKEN_URL, status, "error", hdrs=None, fp=io.BytesIO(body)
    )


def secrets_leaked(text: str) -> list[str]:
    found = []
    for secret in (SECRET_ACCESS, SECRET_REFRESH, NEW_ACCESS, NEW_REFRESH):
        if secret in text:
            found.append(secret)
    return found


class OidcRefreshTests(unittest.TestCase):
    def test_success_updates_expires_at_and_stays_quiet(self) -> None:
        past = (datetime.now(timezone.utc) - timedelta(hours=1)).strftime(
            "%Y-%m-%dT%H:%M:%S.000000Z"
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "auth.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(sample_auth(past), handle)
            fake = FakeUrlOpen(
                [
                    FakeResponse(DISCOVERY),
                    FakeResponse(
                        {
                            "access_token": NEW_ACCESS,
                            "refresh_token": NEW_REFRESH,
                            "expires_in": 21600,
                            "token_type": "Bearer",
                        }
                    ),
                ]
            )
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                rc = oidc_refresh.main(["--auth-file", path], urlopen=fake)
            out = stdout.getvalue()
            err = stderr.getvalue()
            self.assertEqual(rc, 0)
            self.assertEqual(secrets_leaked(out + err), [])
            self.assertIn("email=user@example.com", out)
            self.assertIn("expires_at=", out)
            self.assertIn("remaining_hours=", out)
            with open(path, encoding="utf-8") as handle:
                saved = json.load(handle)
            entry = next(iter(saved.values()))
            self.assertEqual(entry["key"], NEW_ACCESS)
            self.assertEqual(entry["refresh_token"], NEW_REFRESH)
            new_exp = datetime.fromisoformat(
                entry["expires_at"].replace("Z", "+00:00")
            )
            self.assertGreater(
                new_exp,
                datetime.now(timezone.utc) + timedelta(hours=5),
            )
            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
            post = fake.requests[1]
            self.assertEqual(post.get_method(), "POST")
            self.assertIsNone(post.get_header("Authorization"))
            body = post.data.decode("utf-8")
            self.assertIn("grant_type=refresh_token", body)
            self.assertIn("client_id=client-id", body)

    def test_invalid_grant_exits_2_without_printing_secrets(self) -> None:
        past = (datetime.now(timezone.utc) - timedelta(hours=1)).strftime(
            "%Y-%m-%dT%H:%M:%S.000000Z"
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "auth.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(sample_auth(past), handle)
            fake = FakeUrlOpen(
                [
                    FakeResponse(DISCOVERY),
                    http_error(400, "invalid_grant"),
                ]
            )
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                rc = oidc_refresh.main(["--auth-file", path], urlopen=fake)
            out = stdout.getvalue()
            err = stderr.getvalue()
            self.assertEqual(rc, 2)
            self.assertEqual(secrets_leaked(out + err), [])
            self.assertIn("HTTP 400 error=invalid_grant", err)
            with open(path, encoding="utf-8") as handle:
                saved = json.load(handle)
            entry = next(iter(saved.values()))
            self.assertEqual(entry["key"], SECRET_ACCESS)
            self.assertEqual(entry["refresh_token"], SECRET_REFRESH)

    def test_no_refresh_token_exits_1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "auth.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump({"x": {"key": "k", "oidc_client_id": "c"}}, handle)
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                rc = oidc_refresh.main(
                    ["--auth-file", path], urlopen=MagicMock()
                )
            self.assertEqual(rc, 1)
            self.assertEqual(secrets_leaked(stdout.getvalue() + stderr.getvalue()), [])


if __name__ == "__main__":
    unittest.main()
