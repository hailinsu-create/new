from __future__ import annotations

from comic_pipeline.config import Settings
from comic_pipeline.providers.base import ImageProvider
from comic_pipeline.providers.comfy import ComfyProvider
from comic_pipeline.providers.fal import FalProvider
from comic_pipeline.providers.local import LocalProvider
from comic_pipeline.providers.mock import MockProvider


def get_image_provider(settings: Settings) -> ImageProvider:
    """Resolve the active image backend from settings."""
    if settings.comic_mock:
        return MockProvider()
    name = (settings.image_provider or "fal").strip().lower()
    if name == "fal":
        return FalProvider(settings)
    if name == "local":
        return LocalProvider(settings)
    if name in {"comfy", "comfyui"}:
        return ComfyProvider(settings)
    raise RuntimeError(
        f"Unknown IMAGE_PROVIDER={settings.image_provider!r}. "
        "Use 'fal' (default), 'local' (AutoDL/Diffusers), or 'comfy'."
    )


__all__ = [
    "ImageProvider",
    "get_image_provider",
    "FalProvider",
    "LocalProvider",
    "ComfyProvider",
    "MockProvider",
]
