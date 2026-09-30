from __future__ import annotations

import pytest

from comic_pipeline.config import Settings, require_fal


def test_require_fal_errors_without_key() -> None:
    with pytest.raises(RuntimeError, match="FAL_KEY"):
        require_fal(Settings(comic_mock=False, fal_key=""))


def test_require_fal_ok_in_mock() -> None:
    require_fal(Settings(comic_mock=True, fal_key=""))


def test_require_fal_ok_with_key() -> None:
    require_fal(Settings(comic_mock=False, fal_key="test:key"))
