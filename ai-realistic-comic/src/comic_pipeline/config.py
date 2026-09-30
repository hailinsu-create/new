from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Explicit mock only. Default is real generation via IMAGE_PROVIDER.
    comic_mock: bool = False

    # fal (default) | comfy — swap backends without changing episode/character assets.
    image_provider: str = "fal"

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

    # ComfyUI / AutoDL (future). Same character refs + episode.yaml.
    comfy_api_url: str = "http://127.0.0.1:8188"
    comfy_workflow_path: str = ""
    comfy_client_id: str = "ai-realistic-comic"

    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    def resolved_t2i_model(self) -> str:
        return self.fal_image_model or self.fal_t2i_model

    def resolved_provider(self) -> str:
        if self.comic_mock:
            return "mock"
        return (self.image_provider or "fal").strip().lower()


def get_settings() -> Settings:
    return Settings()


def require_provider(settings: Settings) -> None:
    """Raise a clear error when the active image backend is not configured."""
    from comic_pipeline.providers import get_image_provider

    get_image_provider(settings).ready()


# Back-compat name used by older call sites / tests.
def require_fal(settings: Settings) -> None:
    if settings.comic_mock:
        return
    if settings.resolved_provider() != "fal":
        require_provider(settings)
        return
    if not settings.fal_key.strip():
        raise RuntimeError(
            "FAL_KEY is not set. Add it as a Cloud Agent / environment secret "
            "(or export FAL_KEY / put it in ai-realistic-comic/.env), then rerun. "
            "For offline smoke tests only: COMIC_MOCK=1. "
            "To prepare AutoDL later: IMAGE_PROVIDER=comfy + COMFY_API_URL."
        )
