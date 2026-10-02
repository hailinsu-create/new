from __future__ import annotations

import base64
import io
import random
from dataclasses import dataclass

import httpx
import numpy as np
from PIL import Image

from pangchuang.config import Settings

_MOCK_BY_SCENE = {
    "feed": ["又开始无脑下拉了，手指比大脑勤快。", "深夜还在刷，明天的你会来讨债。"],
    "chat": ["置顶消息闪了三遍，你还在装没看见。", "回个表情包也能拖成史诗。"],
    "shop": ["购物车比存款诚实多了。", "凑单凑着凑着就把理智凑没了。"],
    "game": ["匹配界面都快看穿了，还不快投降。", "连跪三把还不退，这叫毅力。"],
    "note": ["备忘录写得很勤，执行力在隔壁。", "提醒设得漂亮，起床另说。"],
}

_MOCK_LINES = [line for lines in _MOCK_BY_SCENE.values() for line in lines]


@dataclass
class RoastResult:
    text: str
    source: str  # api | mock | error


class Roaster:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._last_fingerprint: np.ndarray | None = None

    def should_roast(self, frame: np.ndarray) -> bool:
        fp = _fingerprint(frame)
        if self._last_fingerprint is None:
            self._last_fingerprint = fp
            return True
        delta = float(np.mean(np.abs(fp.astype(np.float32) - self._last_fingerprint)))
        if delta >= self._settings.roast_change_threshold:
            self._last_fingerprint = fp
            return True
        return False

    def roast(self, frame: np.ndarray, scene: str | None = None) -> RoastResult:
        if self._settings.mock_api or not self._settings.vision_api_key:
            pool = _MOCK_BY_SCENE.get(scene or "", _MOCK_LINES)
            return RoastResult(text=random.choice(pool), source="mock")
        try:
            text = self._call_vision(frame)
            if not text:
                pool = _MOCK_BY_SCENE.get(scene or "", _MOCK_LINES)
                return RoastResult(text=random.choice(pool), source="mock")
            return RoastResult(text=text, source="api")
        except Exception as exc:  # noqa: BLE001 — surface as bubble copy
            return RoastResult(text=f"吐槽服务开小差了：{exc.__class__.__name__}", source="error")

    def _call_vision(self, frame: np.ndarray) -> str:
        jpeg = _frame_to_jpeg_b64(frame, max_side=768, quality=72)
        url = f"{self._settings.vision_base_url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self._settings.vision_api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self._settings.vision_model,
            "temperature": 0.8,
            "max_tokens": 80,
            "messages": [
                {"role": "system", "content": self._settings.roast_style},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "看这张手机截图，来一句短吐槽。"},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{jpeg}"},
                        },
                    ],
                },
            ],
        }
        with httpx.Client(timeout=45.0) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
        content = data["choices"][0]["message"]["content"]
        if isinstance(content, list):
            parts = []
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    parts.append(item.get("text", ""))
                elif isinstance(item, str):
                    parts.append(item)
            content = "".join(parts)
        text = str(content).strip().replace("\n", " ")
        if len(text) > 40:
            text = text[:39] + "…"
        return text


def _fingerprint(frame: np.ndarray) -> np.ndarray:
    img = Image.fromarray(frame).convert("L").resize((32, 32))
    return np.asarray(img, dtype=np.uint8)


def _frame_to_jpeg_b64(frame: np.ndarray, max_side: int, quality: int) -> str:
    img = Image.fromarray(frame)
    img.thumbnail((max_side, max_side * 2))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality, optimize=True)
    return base64.b64encode(buf.getvalue()).decode("ascii")
