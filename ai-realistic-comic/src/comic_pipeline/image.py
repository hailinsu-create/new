from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import httpx
from PIL import Image, ImageDraw

from comic_pipeline.config import Settings, require_fal
from comic_pipeline.models import Character, Panel, Project
from comic_pipeline.prompts.genres import GENRE_STYLE, genre_negative


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
    cache_key = hashlib.sha256(
        json.dumps(
            {
                "prompt": prompt,
                "negative": negative,
                "id": panel.id,
                "refs": [str(r) for r in refs],
                "t2i": settings.resolved_t2i_model(),
                "pulid": settings.fal_pulid_model,
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

    if settings.comic_mock:
        _write_mock_image(out_path, panel, prompt)
        provider = "mock"
        model_used = "mock"
    else:
        require_fal(settings)
        model_used = _call_fal(
            out_path=out_path,
            prompt=prompt,
            negative=negative,
            refs=refs,
            settings=settings,
        )
        provider = "fal"

    meta_path.write_text(
        json.dumps(
            {
                "panel_id": panel.id,
                "cache_key": cache_key,
                "prompt": prompt,
                "negative": negative,
                "refs": [str(r) for r in refs],
                "provider": provider,
                "model": model_used,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return out_path


def _write_mock_image(out_path: Path, panel: Panel, prompt: str) -> None:
    img = Image.new("RGB", (768, 1024), (28, 34, 48))
    draw = ImageDraw.Draw(img)
    draw.rectangle((40, 40, 728, 984), outline=(210, 190, 140), width=3)
    lines = [
        f"{panel.id} | {panel.shot}",
        panel.setting[:48],
        panel.action[:48],
        (panel.dialogue or "")[:40],
        "MOCK photoreal panel",
    ]
    y = 80
    for line in lines:
        draw.text((60, y), line, fill=(235, 230, 220))
        y += 40
    draw.text((60, 900), prompt[:70] + "...", fill=(150, 160, 180))
    img.save(out_path)


def _configure_fal(settings: Settings) -> None:
    # fal_client reads FAL_KEY from the environment.
    os.environ["FAL_KEY"] = settings.fal_key.strip()


def _upload_ref(path: Path) -> str:
    import fal_client

    return fal_client.upload_file(str(path))


def _download(url: str, out_path: Path) -> None:
    with httpx.Client(timeout=180.0) as client:
        resp = client.get(url)
        resp.raise_for_status()
        out_path.write_bytes(resp.content)


def _call_fal(
    *,
    out_path: Path,
    prompt: str,
    negative: str,
    refs: list[Path],
    settings: Settings,
) -> str:
    import fal_client

    _configure_fal(settings)

    if refs:
        model = settings.fal_pulid_model
        ref_url = _upload_ref(refs[0])
        arguments = {
            "prompt": prompt,
            "reference_image_url": ref_url,
            "negative_prompt": negative,
            "image_size": settings.fal_image_size,
            "num_inference_steps": settings.fal_num_inference_steps,
            "guidance_scale": settings.fal_guidance_scale,
            "id_weight": settings.fal_id_weight,
            "enable_safety_checker": settings.fal_enable_safety_checker,
        }
    else:
        model = settings.resolved_t2i_model()
        arguments = {
            "prompt": prompt,
            "image_size": settings.fal_image_size,
            "num_inference_steps": settings.fal_num_inference_steps,
            "guidance_scale": settings.fal_guidance_scale,
            "enable_safety_checker": settings.fal_enable_safety_checker,
            "num_images": 1,
        }
        # flux/dev accepts negative via some endpoints; keep optional.
        if "flux" in model:
            arguments["enable_safety_checker"] = settings.fal_enable_safety_checker

    def _on_update(update) -> None:  # noqa: ANN001
        if isinstance(update, fal_client.InProgress) and update.logs:
            for log in update.logs:
                msg = log.get("message") if isinstance(log, dict) else getattr(log, "message", None)
                if msg:
                    print(f"[fal:{model}] {msg}")

    result = fal_client.subscribe(
        model,
        arguments=arguments,
        with_logs=True,
        on_queue_update=_on_update,
    )
    images = result.get("images") or []
    if not images:
        raise RuntimeError(f"fal returned no images: {result}")
    url = images[0]["url"] if isinstance(images[0], dict) else images[0]
    _download(url, out_path)
    return model


def ensure_character_reference(
    *,
    project_dir: Path,
    project: Project,
    character: Character,
    settings: Settings,
) -> Path | None:
    """Generate a locked look sheet if no reference exists yet (mock or fal)."""
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
