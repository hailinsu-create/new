"""旁窗 — phone cast in a small always-on-top window, with vision-model roasts."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")


@dataclass(frozen=True)
class Settings:
    # UI
    phone_width: int = int(os.getenv("PHONE_WIDTH", "240"))
    always_on_top: bool = os.getenv("ALWAYS_ON_TOP", "1") != "0"
    brand_name: str = os.getenv("BRAND_NAME", "旁窗")

    # Stream
    mode: str = os.getenv("MODE", "auto")  # auto | mock | adb
    preview_fps: float = float(os.getenv("PREVIEW_FPS", "3"))
    adb_serial: str | None = os.getenv("ADB_SERIAL") or None

    # Roast loop
    roast_interval_sec: float = float(os.getenv("ROAST_INTERVAL_SEC", "18"))
    roast_change_threshold: float = float(os.getenv("ROAST_CHANGE_THRESHOLD", "8.0"))
    mock_api: bool = os.getenv("MOCK_API", "0") == "1"

    # Vision (OpenAI-compatible)
    vision_base_url: str = os.getenv(
        "VISION_BASE_URL", "https://api.siliconflow.cn/v1"
    ).rstrip("/")
    vision_api_key: str = os.getenv("VISION_API_KEY", "")
    vision_model: str = os.getenv(
        "VISION_MODEL", "Qwen/Qwen2.5-VL-7B-Instruct"
    )
    roast_style: str = os.getenv(
        "ROAST_STYLE",
        "你是贴在手机边上看热闹的损友。用一句中文短吐槽（不超过28字），"
        "俏皮、具体、不刻薄伤人，不要建议也不要提问，只评论眼前画面。",
    )

    assets_dir: Path = ROOT / "assets"
    mock_dir: Path = ROOT / "assets" / "mock"


def get_settings() -> Settings:
    return Settings()
