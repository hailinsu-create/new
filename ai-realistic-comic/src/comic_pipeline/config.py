from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Explicit mock only. Default is real generation via IMAGE_PROVIDER.
    comic_mock: bool = False

    # fal (default) | local (AutoDL/Diffusers) | comfy — swap backends without changing assets.
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

    # Single refined still: candidates -> judge -> targeted edit pass -> upscale.
    comic_strict_audit: bool = False  # about $0.03/still; missed real defects, so off by default
    comic_anatomy_audit: bool = False  # about $0.015/candidate; same weakness, off by default (judge still runs)
    comic_strict_blocking: bool = False  # advisory by default: it missed real defects and flagged fine images
    fal_strict_model: str = "google/gemini-2.5-pro"
    comic_still_candidates: int = 2
    fal_still_model: str = "fal-ai/nano-banana-pro/edit"  # approved for two-person stills (best anatomy/composition in our shootout)
    fal_still_resolution: str = "2K"
    comic_upscale_min_width: int = 1600  # skip aura-sr when the model already outputs this wide
    comic_still_max_candidates: int = 3  # extra candidates only while none passes the anatomy/blocking gate
    comic_still_min_score: float = 7.5
    comic_still_budget_usd: float = 0.80
    fal_upscale_model: str = "fal-ai/aura-sr"

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

    # Local GPU (AutoDL): IMAGE_PROVIDER=local
    local_still_model: str = "qwen-image-edit-2511"
    local_dtype: str = "bfloat16"
    local_steps: int = 40
    local_height: int = 1280
    local_width: int = 960
    local_seed: int = 1
    local_candidates: int = 1  # keep low on rented GPU to save clock time
    # model = enable_model_cpu_offload; sequential = enable_sequential_cpu_offload (lower VRAM)
    local_offload: str = "model"

    # AutoDL automation (Pro API + SSH). Token: 控制台 → 账号 → 设置 → 开发者Token
    autodl_token: str = ""
    autodl_instance_uuid: str = ""  # reuse a stopped instance; empty = create new
    autodl_gpu_spec: str = "4090D"
    autodl_image_uuid: str = "base-image-l2t43iu6uk"
    autodl_cuda_v_from: int = 118
    autodl_instance_name: str = "comic-still-smoke"
    autodl_expand_gb: int = 0
    autodl_auto_stop: bool = True
    autodl_boot_timeout_s: int = 900
    autodl_job_timeout_s: int = 7200
    autodl_ssh_host: str = ""  # optional: skip API create, SSH into an already-running box
    autodl_ssh_port: int = 22
    autodl_ssh_password: str = ""
    autodl_git_branch: str = "cursor/ai-realistic-comic-e63b"

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
