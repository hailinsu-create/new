from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.models import Project, Still
from comic_pipeline.prompts.genres import GENRE_STYLE, STYLIZED_ANCHOR
from comic_pipeline.providers import get_image_provider
from comic_pipeline.qa import StillJudgement, judge_still

PHOTO_FINISH = (
    "photorealistic live-action cinematic still, natural skin micro-texture, fine fur detail, "
    "realistic fabric weave, subtle film grain, accurate hands, expressive believable eyes"
)
IDENTITY_RULE = (
    "keep each character's face, species and outfit exactly as in their reference image; the two characters "
    "must look clearly different from each other; one single frame, not a collage"
)


def still_refs(project_dir: Path, project: Project, still: Still) -> list[Path]:
    cmap = project.character_map()
    refs: list[Path] = []
    for cid in still.characters:
        char = cmap[cid]
        for rel in char.reference_images:
            path = (project_dir / rel).resolve()
            if path.is_file():
                refs.append(path)
                break
    return refs


def build_still_prompt(project: Project, still: Still) -> tuple[str, str]:
    cmap = project.character_map()
    chars = [cmap[c] for c in still.characters]
    labels = " ".join(f"Image {i} is {c.label}." for i, c in enumerate(chars, 1))
    style = STYLIZED_ANCHOR if project.render_style == "stylized" else f"{GENRE_STYLE[project.genre]}; {PHOTO_FINISH}"
    parts = [
        labels,
        style,
        f"camera: {still.camera}",
        f"setting: {still.setting}" if still.setting else "",
        f"lighting: {still.lighting}" if still.lighting else "",
        f"blocking: {still.blocking}" if still.blocking else "",
        f"wardrobe state (always covered): {still.wardrobe_state}" if still.wardrobe_state else "",
        f"motif: {still.motif}" if still.motif else "",
        f"mood: {still.mood}" if still.mood else "",
        " | ".join(c.prompt_block(neutral=True) for c in chars),
        IDENTITY_RULE,
    ]
    negative = still.negative or (
        "anime, cartoon, collage, split screen, twins, merged faces, extra fingers, deformed hands, "
        "text, watermark, minor, child"
        + (
            ""
            if project.render_style == "stylized"
            else ", illustration, painting, 3D render, CGI, concept art, differently colored skin, "
            "hair or eye color different from the references, props not in the references"
        )
    )
    return ", ".join(p for p in parts if p), negative


def _edit_args(settings: Settings, provider, prompt: str, negative: str, images: list[Path], size: str) -> dict:
    import fal_client

    if settings.comic_mock:
        return {"prompt": prompt}
    return {
        "prompt": f"{prompt} Avoid: {negative}.",
        "image_urls": [fal_client.upload_file(str(p)) for p in images],
        "image_size": size,
        "num_images": 1,
        "enable_safety_checker": settings.fal_enable_safety_checker,
    }


def make_still(
    *,
    project_dir: Path,
    project: Project,
    still: Still,
    settings: Settings,
    out_dir: Path,
    ledger: BudgetLedger,
) -> Path:
    """candidates -> judge -> one targeted edit pass (only if needed) -> upscale. Every step is budgeted."""
    out_dir.mkdir(parents=True, exist_ok=True)
    provider = get_image_provider(settings)
    provider.ready()
    refs = still_refs(project_dir, project, still)
    if len(refs) != 2:
        raise RuntimeError(f"still {still.id}: both characters need look sheets (run `comic refs`)")
    prompt, negative = build_still_prompt(project, still)
    edit_model = settings.fal_edit_model

    report: dict = {"still": still.id, "candidates": [], "prompt": prompt}
    best_path: Path | None = None
    best: StillJudgement | None = None

    for i in range(1, settings.comic_still_candidates + 1):
        cand = out_dir / f"candidate_{i}.png"
        ledger.ensure_can_afford(edit_model)
        provider.call(edit_model, _edit_args(settings, provider, prompt, negative, refs, still.image_size), cand)
        ledger.charge(model=edit_model, panel_id=f"{still.id}_cand{i}")
        judged = judge_still(settings, project, still, cand, refs, ledger)
        report["candidates"].append(
            {"file": cand.name, "total": judged.total, "scores": judged.scores, "blocking": judged.blocking}
        )
        if best is None or (judged.ok and not best.ok) or (judged.ok == best.ok and judged.total > best.total):
            best_path, best = cand, judged

    assert best_path is not None and best is not None

    needs_refine = (not best.ok) or best.total < settings.comic_still_min_score
    if needs_refine and best.fixes:
        ledger.ensure_can_afford(edit_model)
        refined = out_dir / "refined.png"
        fix_prompt = (
            "Image 1 is the base image: keep its composition, pose, lighting and both characters' identities. "
            f"Image 2 is {project.character_map()[still.characters[0]].label}, Image 3 is "
            f"{project.character_map()[still.characters[1]].label}. "
            f"Apply these improvements only: {'; '.join(best.fixes)}. {IDENTITY_RULE}."
        )
        provider.call(
            edit_model,
            _edit_args(settings, provider, fix_prompt, negative, [best_path, *refs], still.image_size),
            refined,
        )
        ledger.charge(model=edit_model, panel_id=f"{still.id}_refine")
        rj = judge_still(settings, project, still, refined, refs, ledger)
        report["refine"] = {"fixes": best.fixes, "total": rj.total, "scores": rj.scores, "blocking": rj.blocking}
        if (rj.ok and not best.ok) or (rj.ok == best.ok and rj.total >= best.total):
            best_path, best = refined, rj

    final = out_dir / "final.png"
    upscaled = False
    if not settings.comic_mock and best.ok:
        try:
            import fal_client

            ledger.ensure_can_afford(settings.fal_upscale_model)
            tmp = out_dir / "_upscaled_raw.png"
            provider.call(
                settings.fal_upscale_model,
                {"image_url": fal_client.upload_file(str(best_path)), "upscaling_factor": 2},
                tmp,
            )
            ledger.charge(model=settings.fal_upscale_model, panel_id=f"{still.id}_upscale")
            with Image.open(best_path) as src, Image.open(tmp) as big:
                target = (src.width * 2, src.height * 2)
                big.convert("RGB").resize(target, Image.LANCZOS).save(final)
            tmp.unlink()
            upscaled = True
        except RuntimeError:
            raise
        except Exception as exc:  # noqa: BLE001
            report["upscale_error"] = str(exc)[:200]
    if not upscaled:
        Image.open(best_path).convert("RGB").save(final)

    report.update(
        winner=best_path.name,
        final_total=best.total,
        final_blocking=best.blocking,
        upscaled=upscaled,
        spent_usd=round(ledger.spent_usd, 4),
    )
    (out_dir / "still.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return final
