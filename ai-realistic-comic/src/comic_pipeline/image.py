from __future__ import annotations

import hashlib
import json
from pathlib import Path

from comic_pipeline.config import Settings, require_provider
from comic_pipeline.models import Character, Panel, Project
from comic_pipeline.prompts.genres import GENRE_STYLE, genre_negative
from comic_pipeline.providers import get_image_provider


def build_panel_prompt(project: Project, panel: Panel) -> tuple[str, str]:
    cmap = project.character_map()
    char_blocks = []
    for cid in panel.characters:
        char = cmap.get(cid)
        if char:
            char_blocks.append(char.prompt_block())
    prompt = ", ".join(
        [
            GENRE_STYLE[project.genre],
            panel.setting,
            f"{panel.shot} shot",
            panel.action,
            f"emotion: {panel.emotion}" if panel.emotion else "",
            "; ".join(char_blocks),
            "highly detailed skin texture, realistic eyes, coherent anatomy",
            "same character identity as reference, consistent face and wardrobe",
        ]
    )
    negative = panel.negative or genre_negative(project.genre)
    return prompt, negative


def reference_paths(project_dir: Path, project: Project, panel: Panel) -> list[Path]:
    paths: list[Path] = []
    cmap = project.character_map()
    for cid in panel.characters:
        char = cmap.get(cid)
        if not char:
            continue
        for rel in char.reference_images:
            p = (project_dir / rel).resolve()
            if p.is_file():
                paths.append(p)
    return paths


def generate_panel_image(
    *,
    project_dir: Path,
    project: Project,
    panel: Panel,
    out_path: Path,
    settings: Settings,
    force: bool = False,
) -> Path:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    prompt, negative = build_panel_prompt(project, panel)
    refs = reference_paths(project_dir, project, panel)
    provider = get_image_provider(settings)
    cache_key = hashlib.sha256(
        json.dumps(
            {
                "prompt": prompt,
                "negative": negative,
                "id": panel.id,
                "refs": [str(r) for r in refs],
                "provider": provider.name,
                "t2i": settings.resolved_t2i_model(),
                "pulid": settings.fal_pulid_model,
                "comfy_workflow": settings.comfy_workflow_path,
            },
            ensure_ascii=False,
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()[:16]
    meta_path = out_path.with_suffix(".json")
    if out_path.is_file() and meta_path.is_file() and not force:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("cache_key") == cache_key:
            return out_path

    require_provider(settings)
    model_used = provider.generate(
        out_path=out_path,
        prompt=prompt,
        negative=negative,
        refs=refs,
    )

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
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return out_path


def ensure_character_reference(
    *,
    project_dir: Path,
    project: Project,
    character: Character,
    settings: Settings,
) -> Path | None:
    """Generate a locked look sheet if no reference exists yet."""
    if character.reference_images:
        existing = project_dir / character.reference_images[0]
        if existing.is_file():
            return existing

    rel = f"characters/{character.id}_ref.png"
    out = project_dir / rel
    panel = Panel(
        id=f"{character.id}_ref",
        shot="portrait look-sheet",
        characters=[character.id],
        emotion="neutral calm",
        action=(
            "character lookbook portrait, front three-quarter view, "
            "plain soft neutral backdrop, identity lock sheet"
        ),
        setting="studio portrait for continuity lock",
    )
    if character.id not in project.character_map():
        project.characters.append(character)
    generate_panel_image(
        project_dir=project_dir,
        project=project,
        panel=panel,
        out_path=out,
        settings=settings,
        force=True,
    )
    character.reference_images = [rel]
    return out
