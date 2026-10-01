from __future__ import annotations

from pathlib import Path

from PIL import Image

from comic_pipeline.compliance import lint_project
from comic_pipeline.config import Settings
from comic_pipeline.models import Character, Episode, Panel, Project
from comic_pipeline.qa import _parse_json, _result_from, blank_image_issue


def _project(**kw) -> Project:
    return Project(
        name="t",
        characters=[Character(id="a", name="A", age_look="adult woman, late 20s")],
        **kw,
    )


def test_adult_age_required_and_minor_terms_blocked() -> None:
    settings = Settings(comic_mock=True)
    proj = Project(name="t", characters=[Character(id="a", name="A", age_look="young woman")])
    rep = lint_project(proj, None, settings)
    assert any("explicit adult age" in e for e in rep.errors)

    bad = Project(
        name="t", characters=[Character(id="a", name="A", age_look="adult", notes="schoolgirl uniform")]
    )
    assert not lint_project(bad, None, settings).ok


def test_platform_profiles() -> None:
    settings = Settings(comic_mock=True)
    ep = Episode(title="e", genre="fantasy", panels=[Panel(id="p", shot="s", characters=["a"])])
    assert lint_project(_project(), ep, settings, "fanvue").ok
    assert not lint_project(_project(), ep, settings, "patreon_adult").ok
    assert lint_project(_project(render_style="stylized"), ep, settings, "patreon_adult").ok
    assert not lint_project(_project(), ep, settings, "gumroad").ok
    assert not lint_project(_project(), ep, settings, "fansly").ok


def test_explicit_blocked_on_fal() -> None:
    settings = Settings(comic_mock=False, image_provider="fal")
    rep = lint_project(_project(content_tier="explicit"), None, settings)
    assert any("Acceptable Use" in e for e in rep.errors)


def test_blank_image_detected(tmp_path: Path) -> None:
    black = tmp_path / "b.png"
    Image.new("RGB", (64, 64), (0, 0, 0)).save(black)
    assert blank_image_issue(black)


def test_qa_result_parsing() -> None:
    data = _parse_json('```json\n{"single_frame": false, "issues": ["collage"], "pass": true}\n```')
    res = _result_from(data, ["single_frame"], "")
    assert not res.ok
    assert "collage" in res.hint()
    assert _result_from({"single_frame": True, "issues": []}, ["single_frame"], "").ok


def test_still_lint_and_prompt(tmp_path: Path) -> None:
    from comic_pipeline.compliance import lint_still
    from comic_pipeline.models import Still
    from comic_pipeline.still import build_still_prompt

    proj = Project(
        name="t",
        characters=[
            Character(id="a", name="A", age_look="adult woman, late 20s"),
            Character(id="b", name="B", age_look="adult man, 30s"),
        ],
    )
    settings = Settings(comic_mock=False, image_provider="fal")
    ok = Still(id="s", characters=["a", "b"], motif="playful silk tension", blocking="she holds a thread")
    assert lint_still(ok, proj, settings).ok
    prompt, neg = build_still_prompt(proj, ok)
    assert "Image 1 is A." in prompt and "Image 2 is B." in prompt and "collage" in neg

    assert not lint_still(ok.model_copy(update={"motif": "non-consensual scene"}), proj, settings).ok
    assert not lint_still(ok.model_copy(update={"wardrobe_state": "completely naked"}), proj, settings).ok
    assert not lint_still(ok.model_copy(update={"characters": ["a"]}), proj, settings).ok


def test_library_archive_and_use(tmp_path: Path) -> None:
    import yaml

    from comic_pipeline.library import archive_character, list_library, use_character

    proj = tmp_path / "projects" / "p"
    (proj / "characters").mkdir(parents=True)
    (proj / "project.yaml").write_text("name: p\ngenre: fantasy\n", encoding="utf-8")
    (proj / "characters" / "a.yaml").write_text(
        yaml.safe_dump({"id": "a", "name": "A", "age_look": "adult", "reference_images": ["characters/a_ref.png"]}),
        encoding="utf-8",
    )
    Image.new("RGB", (8, 8), (10, 20, 30)).save(proj / "characters" / "a_ref.png")

    first = archive_character(tmp_path, proj, "a", ["t"])
    assert first["version"] == 1 and archive_character(tmp_path, proj, "a")["version"] == 1
    Image.new("RGB", (8, 8), (90, 20, 30)).save(proj / "characters" / "a_ref.png")
    assert archive_character(tmp_path, proj, "a")["version"] == 2
    assert [e["id"] for e in list_library(tmp_path)] == ["a"]

    other = tmp_path / "projects" / "q"
    (other / "characters").mkdir(parents=True)
    (other / "project.yaml").write_text("name: q\ngenre: fantasy\n", encoding="utf-8")
    card = use_character(tmp_path, other, "a")
    assert card.reference_images == ["characters/a_ref.png"]
    assert (other / "characters" / "a_ref.png").is_file()
