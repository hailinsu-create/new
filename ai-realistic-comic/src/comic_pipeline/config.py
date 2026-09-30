from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Explicit mock only. Default is real fal generation.
    comic_mock: bool = False

    fal_key: str = ""
    # Text-to-image for look sheets / panels without a reference.
    fal_t2i_model: str = "fal-ai/flux/dev"
    # Character-locked generation when a reference image exists.
    fal_pulid_model: str = "fal-ai/flux-pulid"
    # Optional scene-edit model (Kontext) for later; unused by default.
    fal_kontext_model: str = "fal-ai/flux-pro/kontext"
    # Back-compat alias used by older .env files.
    fal_image_model: str = ""

    fal_image_size: str = "portrait_4_3"
    fal_id_weight: float = 1.0
    fal_guidance_scale: float = 4.0
    fal_num_inference_steps: int = 28
    fal_enable_safety_checker: bool = True

    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    def resolved_t2i_model(self) -> str:
        return self.fal_image_model or self.fal_t2i_model


def get_settings() -> Settings:
    return Settings()


def require_fal(settings: Settings) -> None:
    """Raise a clear error when fal credentials are missing."""
    if settings.comic_mock:
        return
    if not settings.fal_key.strip():
        raise RuntimeError(
            "FAL_KEY is not set. Add it as a Cloud Agent / environment secret "
            "(or export FAL_KEY / put it in ai-realistic-comic/.env), then rerun. "
            "For offline smoke tests only: COMIC_MOCK=1"
        )
