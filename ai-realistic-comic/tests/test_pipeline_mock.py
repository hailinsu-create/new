from __future__ import annotations

import os
from pathlib import Path

import pytest

# Ensure mock mode before importing settings-backed modules in CLI flows.
os.environ["COMIC_MOCK"] = "1"

from comic_pipeline.assemble import assemble_pages
from comic_pipeline.config import Settings
from comic_pipeline.image import generate_panel_image
from comic_pipeline.llm import plan_episode
from comic_pipeline.models import load_project


ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / "projects" / "demo-xianxia"


@pytest.fixture()
def settings() -> Settings:
    return Settings(comic_mock=True)


def test_plan_generate_assemble_mock(tmp_path: Path, settings: Settings) -> None:
    project = load_project(DEMO)
    episode = plan_episode(project, DEMO / "story.md", settings)
    assert len(episode.panels) >= 6

    panel_dir = tmp_path / "panels"
    for panel in episode.panels:
        generate_panel_image(
            project_dir=DEMO,
            project=project,
            panel=panel,
            out_path=panel_dir / f"{panel.id}.png",
            settings=settings,
            force=True,
        )
        assert (panel_dir / f"{panel.id}.png").is_file()

    pages = assemble_pages(
        episode=episode,
        project=project,
        panel_dir=panel_dir,
        out_dir=tmp_path / "pages",
    )
    assert pages
    assert pages[0].is_file()
    assert pages[0].stat().st_size > 1000
