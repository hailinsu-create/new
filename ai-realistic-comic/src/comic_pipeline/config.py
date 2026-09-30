from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    comic_mock: bool = False
    fal_key: str = ""
    fal_image_model: str = "fal-ai/flux/dev"
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"


def get_settings() -> Settings:
    return Settings()
