from __future__ import annotations

from pathlib import Path

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.still import make_library_still, still_refs, build_still_prompt
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
    prompt, _ = build_still_prompt(proj, still)
    assert "pomegranate" in prompt.lower() or "throne" in prompt.lower() or "obsidian" in prompt.lower()
