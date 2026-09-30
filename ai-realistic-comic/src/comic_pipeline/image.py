from __future__ import annotations

import hashlib
import json
from pathlib import Path

import httpx
from PIL import Image, ImageDraw

from comic_pipeline.config import Settings
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
            panel.shot + " shot",
            panel.action,
            panel.emotion and f"emotion: {panel.emotion}",
            "; ".join(char_blocks),
            "highly detailed skin texture, realistic eyes, coherent anatomy",
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
    cache_key = hashlib.sha256(
        json.dumps(
            {"prompt": prompt, "negative": negative, "id": panel.id},
            ensure_ascii=False,
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()[:16]
    meta_path = out_path.with_suffix(".json")
    if out_path.is_file() and meta_path.is_file() and not force:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("cache_key") == cache_key:
            return out_path

    refs = reference_paths(project_dir, project, panel)
    if settings.comic_mock or not settings.fal_key:
        _write_mock_image(out_path, panel, prompt)
    else:
        _call_fal(
            out_path=out_path,
            prompt=prompt,
            negative=negative,
            refs=refs,
            settings=settings,
        )

    meta_path.write_text(
        json.dumps(
            {
                "panel_id": panel.id,
                "cache_key": cache_key,
                "prompt": prompt,
                "negative": negative,
                "refs": [str(r) for r in refs],
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


def _call_fal(
    *,
    out_path: Path,
    prompt: str,
    negative: str,
    refs: list[Path],
    settings: Settings,
) -> None:
    # fal queue API (synchronous wait via /requests endpoint pattern)
    model = settings.fal_image_model
    headers = {
        "Authorization": f"Key {settings.fal_key}",
        "Content-Type": "application/json",
    }
    body: dict = {
        "prompt": prompt,
        "num_images": 1,
        "image_size": "portrait_4_3",
        "enable_safety_checker": True,
    }
    # If reference provided, prefer image-to-image strength for consistency.
    if refs:
        import base64

        raw = refs[0].read_bytes()
        b64 = base64.b64encode(raw).decode("ascii")
        body["image_url"] = f"data:image/png;base64,{b64}"
        body["strength"] = 0.55
        # Many fal flux endpoints accept image_url for img2img variants.
        if not model.endswith("/image-to-image"):
            model = model.rstrip("/") + "/image-to-image"

    submit_url = f"https://queue.fal.run/{model}"
    with httpx.Client(timeout=180.0) as client:
        submit = client.post(submit_url, headers=headers, json=body)
        submit.raise_for_status()
        submitted = submit.json()
        status_url = submitted.get("status_url") or submitted.get("response_url")
        result = submitted
        # Poll if queued
        for _ in range(60):
            if "images" in result or (isinstance(result.get("data"), dict) and "images" in result["data"]):
                break
            if not status_url:
                break
            poll = client.get(status_url, headers=headers)
            poll.raise_for_status()
            result = poll.json()
            if result.get("status") in {"COMPLETED", "OK"} and result.get("response_url"):
                done = client.get(result["response_url"], headers=headers)
                done.raise_for_status()
                result = done.json()
                break
            if result.get("status") == "FAILED":
                raise RuntimeError(f"fal generation failed: {result}")
        images = result.get("images") or result.get("data", {}).get("images") or []
        if not images:
            raise RuntimeError(f"fal returned no images: {result}")
        url = images[0]["url"] if isinstance(images[0], dict) else images[0]
        img_bytes = client.get(url).content
        out_path.write_bytes(img_bytes)


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
        action="character lookbook portrait, front three-quarter view, plain soft backdrop",
        setting="studio portrait for continuity lock",
    )
    # Temporarily inject character into project context
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
