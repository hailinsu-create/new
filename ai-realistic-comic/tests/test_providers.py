from __future__ import annotations

import pytest

from comic_pipeline.config import Settings, require_fal, require_provider
from comic_pipeline.providers import get_image_provider
from comic_pipeline.providers.comfy import ComfyProvider


def test_default_provider_is_fal() -> None:
    p = get_image_provider(Settings(comic_mock=False, fal_key="x:y"))
    assert p.name == "fal"


def test_mock_provider_when_comic_mock() -> None:
    p = get_image_provider(Settings(comic_mock=True))
    assert p.name == "mock"
    p.ready()


def test_comfy_provider_selected() -> None:
    p = get_image_provider(
        Settings(comic_mock=False, image_provider="comfy", comfy_api_url="http://127.0.0.1:8188")
    )
    assert isinstance(p, ComfyProvider)
    assert p.name == "comfy"


def test_comfy_ready_requires_url() -> None:
    with pytest.raises(RuntimeError, match="COMFY_API_URL"):
        require_provider(Settings(comic_mock=False, image_provider="comfy", comfy_api_url=""))


def test_require_fal_errors_without_key() -> None:
    with pytest.raises(RuntimeError, match="FAL_KEY"):
        require_fal(Settings(comic_mock=False, image_provider="fal", fal_key=""))


def test_unknown_provider() -> None:
    with pytest.raises(RuntimeError, match="Unknown IMAGE_PROVIDER"):
        get_image_provider(Settings(comic_mock=False, image_provider="nope"))


def test_local_provider_selected() -> None:
    from comic_pipeline.providers.local import LocalProvider

    p = get_image_provider(Settings(comic_mock=False, image_provider="local"))
    assert isinstance(p, LocalProvider)
    assert p.resolve_model("fal-ai/nano-banana-pro/edit") == "Qwen/Qwen-Image-Edit-2511"
    assert p.resolve_model("qwen2511") == "Qwen/Qwen-Image-Edit-2511"


def test_budget_local_is_free() -> None:
    from comic_pipeline.budget import BudgetLedger

    led = BudgetLedger(limit_usd=1.0)
    assert led.estimate("qwen-image-edit-2511") == 0.0
    assert led.estimate("Qwen/Qwen-Image-Edit-2511") == 0.0
