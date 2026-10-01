from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings, require_provider
from comic_pipeline.models import Character, Panel, Project
from comic_pipeline.prompts.genres import GENRE_STYLE, STYLIZED_ANCHOR, genre_negative
from comic_pipeline.providers import get_image_provider
from comic_pipeline.qa import QAResult, qa_panel, qa_reference


REF_STYLE_PHOTO = (
    "photorealistic studio lookbook photograph, seamless plain neutral grey backdrop, soft even key light, "
    "85mm lens, sharp focus on face and costume, NOT anime, NOT illustration"
)
REF_STYLE_STYLIZED = (
    "high-end digital painting character sheet, seamless plain neutral grey backdrop, soft even lighting, "
    "clearly stylized, not a photograph"
)


def build_panel_prompt(
    project: Project, panel: Panel, settings: Settings | None = None
) -> tuple[str, str]:
    cmap = project.character_map()
    char_blocks = []
    for cid in panel.characters:
        char = cmap.get(cid)
        if char:
            char_blocks.append(char.prompt_block())
    primary = len(panel.characters) == 1
    if settings is not None and settings.comic_ref_mode == "edit":
        identity = (
            "keep each character's face, species and wardrobe exactly as in their reference image; "
            "characters must look clearly different from each other"
            if not primary
            else "same character identity as reference, consistent face and wardrobe"
        )
    else:
        identity = (
            "same character identity as reference, consistent face and wardrobe, solo subject focus"
            if primary
            else (
                "ONE primary face only; secondary figure at most as silhouette/back/profile blur, "
                "do not give two equal clear faces"
            )
        )
    stylized = project.render_style == "stylized"
    is_ref = panel.id.endswith("_ref")
    ref_prefix = ""
    if settings is not None and settings.comic_ref_mode == "edit" and panel.characters and not is_ref:
        names = [cmap[c].name for c in panel.characters if c in cmap]
        ref_prefix = " ".join(f"Image {i} is {n}." for i, n in enumerate(names, 1))
    prompt = ", ".join(
        p
        for p in [
            ref_prefix,
            REF_STYLE_STYLIZED
            if is_ref and stylized
            else REF_STYLE_PHOTO
            if is_ref
            else STYLIZED_ANCHOR
            if stylized
            else GENRE_STYLE[project.genre],
            panel.setting,
            f"{panel.shot} shot",
            panel.action,
            f"emotion: {panel.emotion}" if panel.emotion else "",
            " | ".join(char_blocks),
            "coherent anatomy, clean hands"
            if stylized
            else "highly detailed skin texture, realistic eyes, coherent anatomy",
            "" if is_ref else identity,
            "" if is_ref else project.atmosphere,
        ]
        if p
    )
    negative = panel.negative or genre_negative(project.genre)
    if stylized:
        negative = re.sub(r"\b(anime|cartoon|illustration|manga)\b,?\s*", "", negative)
        negative = f"{negative}, photograph, photorealistic, skin pores"
    negative = (
        f"{negative}, identical twins, same face twice, merged faces, costume swap, "
        "sunny outdoor canyon, split screen, diptych, collage, modern clothes"
    )
    return prompt, negative


def reference_paths(
    project_dir: Path, project: Project, panel: Panel, edit_mode: bool = False
) -> list[Path]:
    paths: list[Path] = []
    cmap = project.character_map()
    ids = panel.characters if edit_mode else panel.characters[:1]
    for cid in ids:
        char = cmap.get(cid)
        if not char:
            continue
        for rel in char.reference_images:
            p = (project_dir / rel).resolve()
            if p.is_file():
                paths.append(p)
                break
    return paths


def _assert_panel_policy(panel: Panel, settings: Settings) -> None:
    if (
        settings.comic_ref_mode != "edit"
        and settings.comic_forbid_multi_face
        and len(panel.characters) > 1
    ):
        # Allowed only if action explicitly marks secondary as silhouette/back.
        action = (panel.action or "").lower()
        allowed_markers = ("silhouette", "back view", "back-view", "over-shoulder of", "blurred")
        if not any(m in action for m in allowed_markers):
            raise RuntimeError(
                f"Panel {panel.id} lists multiple characters {panel.characters}. "
                "Economic fal mode forbids equal two-face shots (PuLID collapses identity). "
                "Split into two single-lock panels, or mark secondary as silhouette/back view."
            )


def generate_panel_image(
    *,
    project_dir: Path,
    project: Project,
    panel: Panel,
    out_path: Path,
    settings: Settings,
    force: bool = False,
    ledger: BudgetLedger | None = None,
    attempt: int = 1,
    hint: str = "",
) -> Path:
    _assert_panel_policy(panel, settings)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    prompt, negative = build_panel_prompt(project, panel, settings)
    # Simplify composition on retry instead of burning more random rolls.
    if attempt > 1:
        prompt = (
            prompt
            + ", simpler composition, single clear subject, medium shot, fewer props, "
            "identity lock priority over cinematic complexity"
        )
    edit_mode = settings.comic_ref_mode == "edit"
    if hint:
        prompt = f"{prompt}. Fix these problems from the previous attempt: {hint}"
    refs = reference_paths(project_dir, project, panel, edit_mode)
    if not edit_mode:
        refs = refs[:1] if len(panel.characters) == 1 else []
    planned_model = settings.planned_model(len(refs))

    provider = get_image_provider(settings)
    cache_key = hashlib.sha256(
        json.dumps(
            {
                "prompt": prompt,
                "negative": negative,
                "id": panel.id,
                "refs": [str(r) for r in refs],
                "provider": provider.name,
                "attempt": 1,  # cache ignores retry noise; force controls reruns
                "t2i": settings.resolved_t2i_model(),
                "pulid": settings.fal_pulid_model,
                "mode": settings.comic_ref_mode if refs else "t2i",
                "edit": settings.fal_edit_model,
            },
            ensure_ascii=False,
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()[:16]
    meta_path = out_path.with_suffix(".json")
    if out_path.is_file() and meta_path.is_file() and not force:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("cache_key") == cache_key:
            if ledger is not None:
                ledger.charge(model=meta.get("model", planned_model), panel_id=panel.id, cached=True)
            return out_path

    require_provider(settings)
    if ledger is not None:
        ledger.ensure_can_afford(planned_model)

    model_used = provider.generate(
        out_path=out_path,
        prompt=prompt,
        negative=negative,
        refs=refs,
    )
    if ledger is not None:
        ledger.charge(model=model_used, panel_id=panel.id, cached=False)

    meta_path.write_text(
        json.dumps(
            {
                "panel_id": panel.id,
                "cache_key": cache_key,
                "prompt": prompt,
                "negative": negative,
                "refs": [str(r) for r in refs],
                "provider": provider.name,
                "model": model_used,
                "attempt": attempt,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return out_path


def _record_qa(out_path: Path, qa: QAResult) -> None:
    meta_path = out_path.with_suffix(".json")
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.is_file() else {}
    meta["qa"] = qa.as_dict()
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def _existing_qa(out_path: Path) -> dict | None:
    meta_path = out_path.with_suffix(".json")
    if not meta_path.is_file():
        return None
    return json.loads(meta_path.read_text(encoding="utf-8")).get("qa")


def generate_panel_with_retries(
    *,
    project_dir: Path,
    project: Project,
    panel: Panel,
    out_path: Path,
    settings: Settings,
    force: bool = False,
    ledger: BudgetLedger | None = None,
) -> Path:
    """Generate a panel with at most comic_max_panel_tries attempts; QA failures feed the retry."""
    last_err: Exception | None = None
    hint = ""
    for attempt in range(1, settings.comic_max_panel_tries + 1):
        try:
            generate_panel_image(
                project_dir=project_dir,
                project=project,
                panel=panel,
                out_path=out_path,
                settings=settings,
                force=force or attempt > 1,
                ledger=ledger,
                attempt=attempt,
                hint=hint,
            )
            if _existing_qa(out_path) is not None and attempt == 1 and not force:
                return out_path
            refs = reference_paths(project_dir, project, panel, settings.comic_ref_mode == "edit")
            try:
                qa = qa_panel(settings, project, panel, out_path, refs, ledger)
            except Exception as qa_exc:  # noqa: BLE001
                qa = QAResult(ok=True, skipped=True, issues=[f"qa unavailable: {qa_exc}"[:200]])
            _record_qa(out_path, qa)
            if qa.ok or attempt >= settings.comic_max_panel_tries:
                return out_path
            hint = qa.hint()
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            if attempt >= settings.comic_max_panel_tries:
                break
    assert last_err is not None
    raise last_err


def ensure_character_reference(
    *,
    project_dir: Path,
    project: Project,
    character: Character,
    settings: Settings,
    ledger: BudgetLedger | None = None,
    force: bool = False,
) -> Path | None:
    """Generate a look sheet and only accept it once QA passes (bounded by comic_max_ref_tries)."""
    if character.reference_images and not force:
        existing = project_dir / character.reference_images[0]
        if existing.is_file():
            return existing

    rel = f"characters/{character.id}_ref.png"
    out = project_dir / rel
    if out.is_file() and not force:
        character.reference_images = [rel]
        return out

    previous_refs = character.reference_images
    character.reference_images = []
    if character.id not in project.character_map():
        project.characters.append(character)

    hint = ""
    last_path: Path | None = None
    final_qa: QAResult | None = None
    for attempt in range(1, settings.comic_max_ref_tries + 1):
        panel = Panel(
            id=f"{character.id}_ref",
            shot="portrait look-sheet",
            characters=[character.id],
            emotion="neutral calm",
            action=(
                f"solo lookbook portrait of ONLY {character.name}, "
                "three-quarter view from head to thighs so the full wardrobe is visible, "
                "plain soft neutral grey studio backdrop, identity lock sheet, "
                "single subject, no other characters, no scenery"
            ),
            setting="neutral studio portrait for continuity lock",
            negative=(
                "second person, crowd, twins, wrong gender, anime, cartoon, scenery, cave, "
                "extra cape or armor not in the card, deformed face, watermark, text overlay"
            ),
        )
        generate_panel_image(
            project_dir=project_dir,
            project=project,
            panel=panel,
            out_path=out,
            settings=settings,
            force=True,
            ledger=ledger,
            attempt=attempt,
            hint=hint,
        )
        last_path = out
        try:
            final_qa = qa_reference(settings, character, out, ledger, project.render_style)
        except Exception as qa_exc:  # noqa: BLE001
            final_qa = QAResult(ok=True, skipped=True, issues=[f"qa unavailable: {qa_exc}"[:200]])
        _record_qa(out, final_qa)
        if final_qa.ok:
            break
        hint = final_qa.hint()
    character.reference_images = [rel] if last_path else previous_refs
    if final_qa is not None and not final_qa.ok:
        print(f"[qa] {character.id} look sheet accepted after max tries with issues: {final_qa.hint()}")
    return last_path
