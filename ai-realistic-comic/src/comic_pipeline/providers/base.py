from __future__ import annotations

from pathlib import Path
from typing import Protocol


class ImageProvider(Protocol):
    """Backend that turns a panel prompt (+ optional refs) into an image file."""

    name: str

    def generate(
        self,
        *,
        out_path: Path,
        prompt: str,
        negative: str,
        refs: list[Path],
    ) -> str:
        """Write image bytes to out_path. Return model/workflow id used."""
        ...

    def ready(self) -> None:
        """Raise RuntimeError if credentials/endpoint are missing."""
        ...
