from __future__ import annotations

import json
import shutil
from pathlib import Path

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.image import _record_qa
from comic_pipeline.models import Character, Project
from comic_pipeline.providers import get_image_provider
from comic_pipeline.qa import QAResult, qa_reference


def _archive_previous(project_dir: Path, character: Character, ref_path: Path) -> Path | None:
    if not ref_path.is_file():
        return None
    base = project_dir / "characters"
    n = 1
    while (base / f"archive_v{n}" / ref_path.name).exists():
        n += 1
    dest = base / f"archive_v{n}"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ref_path, dest / ref_path.name)
    meta = ref_path.with_suffix(".json")
    if meta.is_file():
        shutil.copy2(meta, dest / meta.name)
    return dest


def edit_character_reference(
    *,
    project_dir: Path,
    project: Project,
    character: Character,
    base_image: Path,
    instruction: str,
    settings: Settings,
    ledger: BudgetLedger,
    max_tries: int = 2,
    keep_identity_from: Path | None = None,
) -> QAResult:
    """Edit a look sheet with the image-edit model, keeping identity, and re-run the QA gate (bounded tries)."""
    import fal_client

    provider = get_image_provider(settings)
    provider.ready()
    rel = f"characters/{character.id}_ref.png"
    out = project_dir / rel
    if out.is_file():
        _archive_previous(project_dir, character, out)
    frozen_base = out.with_suffix(".base.png")
    shutil.copy2(base_image, frozen_base)

    size = "portrait_16_9" if project.ref_framing == "full_body" else settings.fal_image_size
    sources = [frozen_base] + ([keep_identity_from] if keep_identity_from else [])
    hint = ""
    last: QAResult | None = None
    work = out.with_suffix(".work.png")
    for attempt in range(1, max_tries + 1):
        prompt = (
            "Image 1 is the current look sheet of this character: keep exactly the same person (face, makeup, "
            "hair style), the same camera distance, full-length framing and the same backdrop. "
            + (
                "Image 2 shows the base human form of the same character for identity reference. "
                if keep_identity_from
                else ""
            )
            + f"Apply ONLY these changes: {instruction}. "
            + (f"Also fix: {hint}. " if hint else "")
            + f"Character card: {character.prompt_block()}. "
            + project.tone
            + ", photorealistic, single subject, plain backdrop, no text."
        )
        ledger.ensure_can_afford(settings.fal_edit_model)
        args = {
            "prompt": prompt,
            "image_urls": [fal_client.upload_file(str(p)) for p in sources],
            "image_size": size,
            "num_images": 1,
            "enable_safety_checker": settings.fal_enable_safety_checker,
        }
        provider.call(settings.fal_edit_model, args, work)
        ledger.charge(model=settings.fal_edit_model, panel_id=f"{character.id}_refine{attempt}")
        try:
            last = qa_reference(
                settings, character, work, ledger, project.render_style, project.ref_framing == "full_body"
            )
        except Exception as exc:  # noqa: BLE001
            last = QAResult(ok=True, skipped=True, issues=[f"qa unavailable: {exc}"[:200]])
        shutil.copy2(work, out)
        meta_path = out.with_suffix(".json")
        meta_path.write_text(
            json.dumps(
                {
                    "panel_id": f"{character.id}_ref",
                    "model": settings.fal_edit_model,
                    "prompt": prompt,
                    "instruction": instruction,
                    "base": str(base_image.name),
                    "attempt": attempt,
                    "provider": provider.name,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        _record_qa(out, last)
        if last.ok:
            break
        hint = last.hint()
    work.unlink(missing_ok=True)
    frozen_base.unlink(missing_ok=True)
    character.reference_images = [rel]
    assert last is not None
    return last
