from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from comic_pipeline.autodl import AutodlClient, AutodlError, SshInfo
from comic_pipeline.config import Settings


def test_client_requires_token() -> None:
    with pytest.raises(AutodlError, match="AUTODL_TOKEN"):
        AutodlClient("")


def test_client_create_and_status() -> None:
    client = AutodlClient("tok")
    with patch("comic_pipeline.autodl.httpx.Client") as C:
        inst = C.return_value.__enter__.return_value
        inst.request.return_value.status_code = 200
        inst.request.return_value.json.return_value = {"code": "Success", "data": "pro-abc"}
        assert client.create(
            gpu_spec="4090D",
            image_uuid="base-image-l2t43iu6uk",
            cuda_v_from=118,
            name="t",
        ) == "pro-abc"
        inst.request.return_value.json.return_value = {"code": "Success", "data": "running"}
        assert client.status("pro-abc") == "running"


def test_ssh_info_from_snapshot() -> None:
    client = AutodlClient("tok")
    with patch.object(
        client,
        "snapshot",
        return_value={
            "proxy_host": "connect.example.autodl.com",
            "ssh_port": 12345,
            "root_password": "secret",
            "ssh_command": "ssh -p 12345 root@connect.example.autodl.com",
        },
    ):
        info = client.ssh_info("pro-x")
    assert info.host == "connect.example.autodl.com"
    assert info.port == 12345
    assert info.password == "secret"


def test_settings_autodl_defaults() -> None:
    s = Settings()
    assert s.autodl_auto_stop is True
    assert s.autodl_gpu_spec
