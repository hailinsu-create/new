from __future__ import annotations

from pathlib import Path

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.still import _still_edit, make_library_still, still_refs, build_still_prompt
from comic_pipeline.models import load_project, load_still


def test_make_library_still_mock(tmp_path: Path) -> None:
    root = Path(__file__).resolve().parents[1]
    out = tmp_path / "out"
    led = BudgetLedger(limit_usd=1.0)
    final = make_library_still(
        root=root,
        still_id="hades-persephone-throne",
        settings=Settings(comic_mock=True),
        out_dir=out,
        ledger=led,
        ref_crop=0.55,
    )
    assert final.is_file()
    assert (out / "still.json").is_file()
    work = out / "_project"
    proj = load_project(work)
    assert set(proj.character_map()) == {"persephone", "hades"}
    still = load_still(root / "library" / "stills" / "hades-persephone-throne" / "still.yaml")
    refs = still_refs(work, proj, still)
    assert len(refs) == 2
    prompt, negative = build_still_prompt(proj, still)
    assert "pomegranate" in prompt.lower() or "throne" in prompt.lower() or "obsidian" in prompt.lower()
    assert "high fantasy" in prompt
    assert "Avoid:" not in prompt
    assert "blue skin" in negative
    assert "breasts bare" in prompt
    assert "overrides look-sheet coverage" in prompt
    assert "fully covered" not in prompt


def test_library_coil_uses_xianxia_anchor(tmp_path: Path) -> None:
    root = Path(__file__).resolve().parents[1]
    out = tmp_path / "coil"
    final = make_library_still(
        root=root,
        still_id="baisuzhen-xuxian-coil",
        settings=Settings(comic_mock=True),
        out_dir=out,
        ledger=BudgetLedger(limit_usd=1.0),
        ref_crop=0.55,
    )
    assert final.is_file()
    proj = load_project(out / "_project")
    assert proj.genre == "xianxia"
    still = load_still(root / "library" / "stills" / "baisuzhen-xuxian-coil" / "still.yaml")
    prompt, negative = build_still_prompt(proj, still)
    assert "xianxia" in prompt
    assert "weathered armor" not in prompt
    assert "West Lake" in prompt
    assert "pearl-white" in prompt
    assert "snake tail" in prompt
    assert "no legs" in prompt
    assert "each person has exactly two arms" not in prompt
    assert "caudal fin" in negative
    assert "mermaid" in negative
    assert "minor" in negative and "child" in negative


def test_local_prompt_appends_avoid(tmp_path: Path) -> None:
    captured: dict = {}

    class Provider:
        def call(self, model: str, arguments: dict, out_path: Path) -> str:
            captured.update(arguments)
            out_path.write_bytes(b"x")
            return model

    out = tmp_path / "out.png"
    _still_edit(
        Settings(comic_mock=False, image_provider="local"),
        Provider(),
        prompt="SCENE",
        negative="anime, extra fingers",
        images=[],
        size="portrait_4_3",
        model="qwen-image-edit-2511",
        out_path=out,
    )
    assert captured["prompt"] == "SCENE Avoid: anime, extra fingers."
    assert captured["negative"] == "anime, extra fingers"
