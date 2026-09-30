from __future__ import annotations

import pytest

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.image import _assert_panel_policy
from comic_pipeline.models import Panel


def test_budget_blocks_overspend() -> None:
    ledger = BudgetLedger(limit_usd=0.05)
    ledger.charge(model="fal-ai/flux/dev", panel_id="a")
    with pytest.raises(RuntimeError, match="Budget exceeded"):
        ledger.ensure_can_afford("fal-ai/flux-pulid")


def test_forbid_multi_face() -> None:
    settings = Settings(comic_forbid_multi_face=True, comic_mock=True, comic_ref_mode="pulid")
    with pytest.raises(RuntimeError, match="multiple characters"):
        _assert_panel_policy(
            Panel(id="x", shot="two", characters=["a", "b"], action="face each other"),
            settings,
        )


def test_allow_silhouette_secondary() -> None:
    settings = Settings(comic_forbid_multi_face=True, comic_mock=True, comic_ref_mode="pulid")
    _assert_panel_policy(
        Panel(
            id="x",
            shot="ots",
            characters=["zhizhu", "wukong"],
            action="primary woman; blurred silhouette back-view of warrior",
        ),
        settings,
    )


def test_seedream_cost_and_edit_planning() -> None:
    assert BudgetLedger(limit_usd=1).estimate("fal-ai/bytedance/seedream/v4/edit") == 0.03
    settings = Settings(comic_mock=True)
    assert settings.planned_model(2) == settings.fal_edit_model
    assert settings.planned_model(0) == settings.fal_edit_t2i_model
    _assert_panel_policy(
        Panel(id="x", shot="two", characters=["a", "b"], action="face each other"), settings
    )
