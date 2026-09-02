from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PySide6.QtCore import QEasingCurve, QPoint, QPropertyAnimation, QRect, QSize, Qt, QTimer, Signal
from PySide6.QtGui import (
    QColor,
    QFont,
    QFontDatabase,
    QImage,
    QMouseEvent,
    QPainter,
    QPainterPath,
    QPixmap,
)
from PySide6.QtWidgets import (
    QApplication,
    QGraphicsOpacityEffect,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from pangchuang.config import Settings, get_settings
from pangchuang.roaster import Roaster
from pangchuang.stream import PhoneStream, open_stream


def _pick_font(families: list[str], point_size: int, bold: bool = False) -> QFont:
    available = set(QFontDatabase.families())
    for name in families:
        if name in available:
            font = QFont(name, point_size)
            font.setBold(bold)
            return font
    font = QFont()
    font.setPointSize(point_size)
    font.setBold(bold)
    return font


def _array_to_pixmap(frame: np.ndarray) -> QPixmap:
    h, w, _ = frame.shape
    contiguous = np.ascontiguousarray(frame)
    image = QImage(contiguous.data, w, h, 3 * w, QImage.Format.Format_RGB888).copy()
    return QPixmap.fromImage(image)


class PhoneBezel(QWidget):
    def __init__(self, width: int, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._pixmap: QPixmap | None = None
        self._phone_w = width
        self._phone_h = int(width * 19.5 / 9)
        self.setFixedSize(self._phone_w + 18, self._phone_h + 18)

    def set_frame(self, frame: np.ndarray) -> None:
        self._pixmap = _array_to_pixmap(frame)
        self.update()

    def paintEvent(self, _event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        outer = QRect(1, 1, self.width() - 2, self.height() - 2)
        path = QPainterPath()
        path.addRoundedRect(outer, 28, 28)
        painter.fillPath(path, QColor("#0b1220"))
        painter.setPen(QColor(255, 255, 255, 28))
        painter.drawPath(path)

        inner = outer.adjusted(8, 8, -8, -8)
        clip = QPainterPath()
        clip.addRoundedRect(inner, 22, 22)
        painter.setClipPath(clip)
        if self._pixmap is not None:
            scaled = self._pixmap.scaled(
                inner.size(),
                Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                Qt.TransformationMode.SmoothTransformation,
            )
            x = inner.x() + (inner.width() - scaled.width()) // 2
            y = inner.y() + (inner.height() - scaled.height()) // 2
            painter.drawPixmap(x, y, scaled)
        else:
            painter.fillRect(inner, QColor("#152033"))

        painter.setClipping(False)
        # notch
        notch = QRect(self.width() // 2 - 34, 14, 68, 10)
        painter.setBrush(QColor("#05070d"))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawRoundedRect(notch, 6, 6)


class Bubble(QLabel):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWordWrap(True)
        self.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        self.setMinimumHeight(64)
        self.setFont(_pick_font(["ZCOOL XiaoWei", "Noto Sans CJK SC", "Source Han Sans SC", "Segoe UI"], 12))
        self.setStyleSheet(
            """
            QLabel {
                color: #f8fafc;
                background: rgba(15, 23, 42, 0.92);
                border: 1px solid rgba(148, 163, 184, 0.35);
                border-radius: 16px;
                padding: 12px 14px;
            }
            """
        )
        self._opacity = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self._opacity)
        self._fade = QPropertyAnimation(self._opacity, b"opacity", self)
        self._fade.setDuration(420)
        self._fade.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.hide()

    def show_text(self, text: str) -> None:
        self.setText(text)
        if self.parentWidget() is not None:
            self.setFixedWidth(max(180, self.parentWidget().width() - 28))
        self.adjustSize()
        self.setMinimumHeight(max(64, self.sizeHint().height()))
        self.show()
        self._opacity.setOpacity(0.0)
        self._fade.stop()
        self._fade.setStartValue(0.0)
        self._fade.setEndValue(1.0)
        self._fade.start()


class Root(QWidget):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.setObjectName("root")
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(10)

        header = QHBoxLayout()
        brand = QLabel(settings.brand_name)
        brand.setFont(_pick_font(["ZCOOL KuaiLe", "ZCOOL XiaoWei", "Noto Sans CJK SC", "Segoe UI"], 18, bold=True))
        brand.setStyleSheet("color: #f8fafc; background: transparent;")
        self.status = QLabel("启动中…")
        self.status.setFont(_pick_font(["IBM Plex Sans", "Noto Sans", "Segoe UI"], 10))
        self.status.setStyleSheet("color: #94a3b8; background: transparent;")
        header.addWidget(brand)
        header.addStretch(1)
        header.addWidget(self.status)
        layout.addLayout(header)

        self.bubble = Bubble()
        layout.addWidget(self.bubble)

        self.phone = PhoneBezel(settings.phone_width)
        phone_row = QHBoxLayout()
        phone_row.addStretch(1)
        phone_row.addWidget(self.phone)
        phone_row.addStretch(1)
        layout.addLayout(phone_row)

        controls = QHBoxLayout()
        self.roast_btn = QPushButton("立刻吐槽")
        self.roast_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.roast_btn.setStyleSheet(
            """
            QPushButton {
                color: #0b1220;
                background: #fbbf24;
                border: none;
                border-radius: 14px;
                padding: 8px 14px;
                font-weight: 600;
            }
            QPushButton:hover { background: #f59e0b; }
            QPushButton:disabled { background: #64748b; color: #e2e8f0; }
            """
        )
        self.pin_btn = QPushButton("置顶")
        self.pin_btn.setCheckable(True)
        self.pin_btn.setChecked(settings.always_on_top)
        self.pin_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.pin_btn.setStyleSheet(
            """
            QPushButton {
                color: #e2e8f0;
                background: rgba(30, 41, 59, 0.9);
                border: 1px solid rgba(148, 163, 184, 0.25);
                border-radius: 14px;
                padding: 8px 12px;
            }
            QPushButton:checked { background: rgba(56, 189, 248, 0.2); border-color: #38bdf8; }
            """
        )
        controls.addWidget(self.roast_btn)
        controls.addWidget(self.pin_btn)
        controls.addStretch(1)
        layout.addLayout(controls)

    def paintEvent(self, _event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = self.rect().adjusted(4, 4, -4, -4)
        path = QPainterPath()
        path.addRoundedRect(rect, 24, 24)
        # layered atmosphere instead of flat fill
        painter.fillPath(path, QColor(8, 15, 28, 230))
        painter.setPen(QColor(56, 189, 248, 40))
        painter.drawPath(path)
        glow = QPainterPath()
        glow.addEllipse(rect.x() - 20, rect.y() - 30, rect.width() * 0.7, 120)
        painter.fillPath(glow, QColor(14, 116, 144, 45))


class MainWindow(QMainWindow):
    roast_ready = Signal(str, str)

    def __init__(self, settings: Settings, stream: PhoneStream, roaster: Roaster) -> None:
        super().__init__()
        self._settings = settings
        self._stream = stream
        self._roaster = roaster
        self._drag_pos: QPoint | None = None
        self._last_frame: np.ndarray | None = None
        self._roast_busy = False

        self.setWindowTitle(settings.brand_name)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.Tool
            | (Qt.WindowType.WindowStaysOnTopHint if settings.always_on_top else Qt.WindowType.Widget)
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        self.root = Root(settings)
        self.setCentralWidget(self.root)
        self.root.status.setText(stream.label)
        self.root.roast_btn.clicked.connect(self._force_roast)
        self.root.pin_btn.toggled.connect(self._toggle_pin)
        self.roast_ready.connect(self._on_roast_ready)

        self._preview_timer = QTimer(self)
        self._preview_timer.timeout.connect(self._tick_preview)
        self._preview_timer.start(int(1000 / max(settings.preview_fps, 1)))

        self._roast_timer = QTimer(self)
        self._roast_timer.timeout.connect(self._maybe_roast)
        self._roast_timer.start(int(settings.roast_interval_sec * 1000))

        # First impression
        QTimer.singleShot(700, self._force_roast)

    def sizeHint(self) -> QSize:  # noqa: N802
        return QSize(self._settings.phone_width + 80, int(self._settings.phone_width * 2.5) + 160)

    def mousePressEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_pos = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if self._drag_pos is not None and event.buttons() & Qt.MouseButton.LeftButton:
            self.move(event.globalPosition().toPoint() - self._drag_pos)
            event.accept()

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        self._drag_pos = None
        event.accept()

    def closeEvent(self, event) -> None:  # noqa: N802
        self._preview_timer.stop()
        self._roast_timer.stop()
        self._stream.stop()
        super().closeEvent(event)

    def _toggle_pin(self, pinned: bool) -> None:
        flags = self.windowFlags()
        if pinned:
            flags |= Qt.WindowType.WindowStaysOnTopHint
        else:
            flags &= ~Qt.WindowType.WindowStaysOnTopHint
        self.setWindowFlags(flags)
        self.show()

    def _tick_preview(self) -> None:
        frame = self._stream.get_frame()
        if frame is None:
            return
        self._last_frame = frame
        self.root.phone.set_frame(frame)

    def _force_roast(self) -> None:
        if self._last_frame is None:
            self.root.bubble.show_text("还在等画面…把手机连上，或先看演示。")
            return
        self._run_roast(self._last_frame, force=True)

    def _maybe_roast(self) -> None:
        if self._last_frame is None or self._roast_busy:
            return
        if self._roaster.should_roast(self._last_frame):
            self._run_roast(self._last_frame, force=False)

    def _run_roast(self, frame: np.ndarray, force: bool) -> None:
        if self._roast_busy:
            return
        self._roast_busy = True
        self.root.roast_btn.setEnabled(False)
        self.root.status.setText("正在吐槽…")

        def work() -> None:
            scene = getattr(self._stream, "scene_name", None)
            result = self._roaster.roast(frame, scene=scene)
            self.roast_ready.emit(result.text, result.source)

        import threading

        threading.Thread(target=work, daemon=True).start()
        if force:
            # keep lint happy / explicit intent
            pass

    def _on_roast_ready(self, text: str, source: str) -> None:
        self._roast_busy = False
        self.root.roast_btn.setEnabled(True)
        tag = {"api": "视觉模型", "mock": "本地段子", "error": "出错"}.get(source, source)
        self.root.status.setText(f"{self._stream.label} · {tag}")
        self.root.bubble.show_text(text)


def run_app() -> int:
    settings = get_settings()
    # Ensure package root is importable when launched as script.
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    app = QApplication(sys.argv)
    app.setApplicationName(settings.brand_name)
    stream = open_stream(settings)
    stream.start()
    roaster = Roaster(settings)
    window = MainWindow(settings, stream, roaster)
    window.resize(window.sizeHint())
    window.show()
    return app.exec()
