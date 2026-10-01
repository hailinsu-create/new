from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Explicit mock only. Default is real generation via IMAGE_PROVIDER.
    comic_mock: bool = False

    # fal (default) | comfy — swap backends without changing episode/character assets.
    image_provider: str = "fal"

    fal_key: str = ""
    fal_t2i_model: str = "fal-ai/flux/dev"
    fal_pulid_model: str = "fal-ai/flux-pulid"
    fal_kontext_model: str = "fal-ai/flux-pro/kontext"
    # Multi-reference semantic edit: all panel characters' look sheets go in together.
    fal_edit_model: str = "fal-ai/bytedance/seedream/v4/edit"
    fal_edit_t2i_model: str = "fal-ai/bytedance/seedream/v4/text-to-image"
    # edit = multi-reference semantic edit (supports 2+ characters per frame);
    # pulid = legacy single-face lock with flux.
    comic_ref_mode: str = "edit"

    # Vision-LLM quality gate (cheap): validates look sheets and panels before they are accepted.
    comic_qa: bool = True
    fal_vlm_endpoint: str = "fal-ai/any-llm/vision"
    fal_vlm_model: str = "google/gemini-2.5-flash"
    fal_image_model: str = ""

    fal_image_size: str = "portrait_4_3"
    fal_id_weight: float = 1.0
    fal_guidance_scale: float = 4.0
    fal_num_inference_steps: int = 28
    fal_enable_safety_checker: bool = True

    # Economic gates — no infinite rerolls.
    comic_budget_usd: float = 0.80
    comic_max_ref_tries: int = 3
    comic_max_panel_tries: int = 2
    comic_max_page_repair: int = 2
    # Reject panels that ask for 2+ named characters with equal face time.
    comic_forbid_multi_face: bool = True

    comfy_api_url: str = "http://127.0.0.1:8188"
    comfy_workflow_path: str = ""
    comfy_client_id: str = "ai-realistic-comic"

    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    def resolved_t2i_model(self) -> str:
        return self.fal_image_model or self.fal_t2i_model

    def planned_model(self, ref_count: int) -> str:
        if self.comic_ref_mode == "edit":
            return self.fal_edit_model if ref_count else self.fal_edit_t2i_model
        return self.fal_pulid_model if ref_count == 1 else self.resolved_t2i_model()

    def resolved_provider(self) -> str:
        if self.comic_mock:
            return "mock"
        return (self.image_provider or "fal").strip().lower()


def get_settings() -> Settings:
    return Settings()


def require_provider(settings: Settings) -> None:
    from comic_pipeline.providers import get_image_provider

    get_image_provider(settings).ready()


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
            "For offline smoke tests only: COMIC_MOCK=1."
        )
