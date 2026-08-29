from __future__ import annotations

import io
import threading
import time
from abc import ABC, abstractmethod
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from pangchuang.config import Settings


def _pil_to_rgb_array(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("RGB"))


class PhoneStream(ABC):
    @abstractmethod
    def start(self) -> None: ...

    @abstractmethod
    def stop(self) -> None: ...

    @abstractmethod
    def get_frame(self) -> np.ndarray | None: ...

    @property
    @abstractmethod
    def label(self) -> str: ...


class MockPhoneStream(PhoneStream):
    """Cycles synthetic phone screens so the UI works without a device."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._frames: list[np.ndarray] = []
        self._idx = 0
        self._lock = threading.Lock()
        self._running = False
        self._thread: threading.Thread | None = None

    @property
    def label(self) -> str:
        return "演示模式"

    def start(self) -> None:
        self._frames = self._load_or_build_frames()
        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=1.5)

    def get_frame(self) -> np.ndarray | None:
        with self._lock:
            if not self._frames:
                return None
            return self._frames[self._idx % len(self._frames)].copy()

    def _loop(self) -> None:
        interval = max(2.5, 12.0 / max(len(self._frames), 1))
        while self._running:
            time.sleep(interval)
            with self._lock:
                if self._frames:
                    self._idx = (self._idx + 1) % len(self._frames)

    def _load_or_build_frames(self) -> list[np.ndarray]:
        mock_dir = self._settings.mock_dir
        mock_dir.mkdir(parents=True, exist_ok=True)
        paths = sorted(mock_dir.glob("*.png"))
        if len(paths) < 3:
            paths = _write_demo_screens(mock_dir)
        return [_pil_to_rgb_array(Image.open(p)) for p in paths]


def _write_demo_screens(mock_dir: Path) -> list[Path]:
    scenes = [
        ("feed", "#0f172a", "#38bdf8", "深夜刷短视频", "又一条同款舞蹈"),
        ("chat", "#111827", "#34d399", "微信置顶群", "老板：在吗？急！"),
        ("shop", "#1c1917", "#fb923c", "购物车结算", "凑单还差 ¥12.8"),
        ("game", "#0c1222", "#a78bfa", "排位赛匹配中", "你已经连跪三把"),
        ("note", "#14221b", "#86efac", "备忘录", "明天早上 7:30 开会"),
    ]
    out: list[Path] = []
    for name, bg, accent, title, body in scenes:
        img = Image.new("RGB", (720, 1280), bg)
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle((40, 80, 680, 200), radius=28, fill=accent)
        draw.rounded_rectangle((40, 260, 680, 520), radius=24, fill="#0b1020")
        draw.rounded_rectangle((40, 560, 680, 820), radius=24, fill="#0b1020")
        try:
            font_lg = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 42
            )
            font_sm = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 30
            )
        except OSError:
            font_lg = ImageFont.load_default()
            font_sm = font_lg
        draw.text((70, 115), title, fill="#0b1020", font=font_lg)
        draw.text((70, 320), body, fill="#e2e8f0", font=font_sm)
        draw.text((70, 620), "旁窗预览画面", fill="#94a3b8", font=font_sm)
        path = mock_dir / f"{name}.png"
        img.save(path)
        out.append(path)
    return out


class AdbPhoneStream(PhoneStream):
    """Pull frames with `adb exec-out screencap` — good enough for a mini preview."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._frame: np.ndarray | None = None
        self._lock = threading.Lock()
        self._running = False
        self._thread: threading.Thread | None = None
        self._device = None
        self._serial = settings.adb_serial or "device"

    @property
    def label(self) -> str:
        return f"ADB · {self._serial}"

    def start(self) -> None:
        from adbutils import adb

        devices = adb.device_list()
        if not devices:
            raise RuntimeError("没有检测到 ADB 设备，请用 USB/无线调试连接手机")
        if self._settings.adb_serial:
            match = [d for d in devices if d.serial == self._settings.adb_serial]
            if not match:
                raise RuntimeError(f"找不到设备 {self._settings.adb_serial}")
            self._device = match[0]
        else:
            self._device = devices[0]
        self._serial = self._device.serial
        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)

    def get_frame(self) -> np.ndarray | None:
        with self._lock:
            return None if self._frame is None else self._frame.copy()

    def _loop(self) -> None:
        assert self._device is not None
        interval = 1.0 / max(self._settings.preview_fps, 0.5)
        while self._running:
            started = time.time()
            try:
                raw = self._device.shell("screencap -p", encoding=None)
                if isinstance(raw, str):
                    raw = raw.encode("latin1")
                # Some devices escape CRLF in PNG; normalize.
                raw = raw.replace(b"\r\n", b"\n")
                img = Image.open(io.BytesIO(raw)).convert("RGB")
                # Shrink early for UI + API cost.
                img.thumbnail((720, 1280))
                arr = _pil_to_rgb_array(img)
                with self._lock:
                    self._frame = arr
            except Exception:
                # Keep last good frame; retry next tick.
                pass
            elapsed = time.time() - started
            time.sleep(max(0.05, interval - elapsed))


def open_stream(settings: Settings) -> PhoneStream:
    mode = settings.mode.lower().strip()
    if mode == "mock":
        return MockPhoneStream(settings)
    if mode == "adb":
        return AdbPhoneStream(settings)
    # auto: prefer adb when a device is present
    try:
        from adbutils import adb

        if adb.device_list():
            return AdbPhoneStream(settings)
    except Exception:
        pass
    return MockPhoneStream(settings)
