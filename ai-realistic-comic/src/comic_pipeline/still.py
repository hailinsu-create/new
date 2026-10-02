from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.models import Project, Still
from comic_pipeline.prompts.genres import GENRE_STYLE, STYLIZED_ANCHOR
from comic_pipeline.providers import get_image_provider
from comic_pipeline.qa import AnatomyAudit, StillJudgement, audit_anatomy, judge_still, strict_limb_check

PHOTO_FINISH = (
    "photorealistic live-action cinematic still, natural skin micro-texture, fine fur detail, "
    "realistic fabric weave, subtle film grain, accurate hands, expressive believable eyes"
)
ANATOMY_RULE = (
    "anatomy: each person has exactly two arms and two hands with five fingers per hand, two legs, one head; "
    "every hand and arm clearly belongs to one body; natural relaxed hands, no extra or fused fingers"
)
ANATOMY_NEGATIVE = (
    "extra fingers, extra hands, extra arms, extra legs, fused fingers, missing fingers, malformed hands, "
    "disconnected limbs, duplicated body parts"
)
IDENTITY_RULE = (
    "keep each character's face and species exactly as in their reference image; the two characters "
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
        f"motif: {still.motif}" if still.motif else "",
        f"mood: {still.mood}" if still.mood else "",
        " | ".join(c.prompt_block(neutral=True) for c in chars),
        (
            "wardrobe state (this frame overrides look-sheet coverage, opaque linings, and any 'covered' line above): "
            f"{still.wardrobe_state}"
            if still.wardrobe_state
            else "keep each character's outfit exactly as in their reference image"
        ),
        ANATOMY_RULE,
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
    if ANATOMY_NEGATIVE.split(",")[0] not in negative:
        negative = f"{negative}, {ANATOMY_NEGATIVE}"
    return ", ".join(p for p in parts if p), negative


def nonhuman_note(project: Project, still: Still) -> str:
    cmap = project.character_map()
    notes = [
        f"{cmap[c].label} is in {cmap[c].form} form (its lower body may be non-human, as in its reference)"
        for c in still.characters
        if cmap[c].form and cmap[c].form.lower() != "human"
    ]
    return "; ".join(notes)


def _repair_fixes(audit_issues: list[str], warnings: list[str]) -> list[str]:
    fixes = []
    for text in [*audit_issues, *warnings]:
        fixes.append("Repair: " + text.removeprefix("anatomy: ") + "; each person must have exactly two arms and two hands with five fingers each")
    return fixes


NANO_ASPECT = {"portrait_4_3": "3:4", "portrait_16_9": "9:16", "square_hd": "1:1", "landscape_4_3": "4:3"}


def crop_refs(refs: list[Path], still: Still, out_dir: Path) -> list[Path]:
    if not still.ref_crop:
        return refs
    dest = out_dir / "refs_cropped"
    dest.mkdir(parents=True, exist_ok=True)
    out = []
    for i, ref in enumerate(refs, 1):
        with Image.open(ref) as im:
            im = im.convert("RGB")
            target = dest / f"ref{i}_{ref.stem}.png"
            im.crop((0, 0, im.width, int(im.height * still.ref_crop))).save(target)
        out.append(target)
    return out


def apply_crop(path: Path, still: Still) -> None:
    if not (still.crop_top or still.crop_bottom):
        return
    with Image.open(path) as im:
        im = im.convert("RGB")
        w, h = im.size
        im.crop((0, int(h * still.crop_top), w, int(h * (1 - still.crop_bottom)))).save(path)


def _edit_args(settings: Settings, provider, prompt: str, negative: str, images: list[Path], size: str, model: str = "") -> dict:
    import fal_client

    if settings.comic_mock:
        return {"prompt": prompt}
    if "nano-banana-pro" in model:
        return {
            "prompt": f"{prompt} Avoid: {negative}.",
            "image_urls": [fal_client.upload_file(str(p)) for p in images],
            "aspect_ratio": NANO_ASPECT.get(size, "3:4"),
            "resolution": settings.fal_still_resolution,
            "num_images": 1,
            "output_format": "png",
        }
    if "gpt-image" in model:
        return {
            "prompt": f"{prompt} Avoid: {negative}.",
            "image_urls": [fal_client.upload_file(str(p)) for p in images],
            "image_size": "1024x1536",
            "quality": "medium",
            "input_fidelity": "high",
            "num_images": 1,
            "output_format": "png",
        }
    return {
        "prompt": f"{prompt} Avoid: {negative}.",
        "image_urls": [fal_client.upload_file(str(p)) for p in images],
        "image_size": size,
        "num_images": 1,
        "enable_safety_checker": settings.fal_enable_safety_checker,
    }


def _still_edit(
    settings: Settings,
    provider,
    *,
    prompt: str,
    negative: str,
    images: list[Path],
    size: str,
    model: str,
    out_path: Path,
    seed: int | None = None,
) -> str:
    """Route a still edit to fal or local GPU without changing prompt/ref assets."""
    backend = settings.resolved_provider()
    if backend == "local":
        # Match the fal still call, which appends the negative list into the prompt text.
        sent = f"{prompt} Avoid: {negative}." if negative else prompt
        args = {
            "prompt": sent,
            "negative": negative,
            "images": images,
            "size": size,
            "height": settings.local_height,
            "width": settings.local_width,
            "steps": settings.local_steps,
        }
        if seed is not None:
            args["seed"] = seed
        return provider.call(model, args, out_path)
    return provider.call(model, _edit_args(settings, provider, prompt, negative, images, size, model), out_path)


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
    refs = crop_refs(refs, still, out_dir)
    prompt, negative = build_still_prompt(project, still)
    backend = settings.resolved_provider()
    if backend == "local":
        edit_model = settings.local_still_model
        n_candidates = max(1, settings.local_candidates)
        max_candidates = n_candidates
    else:
        edit_model = still.edit_model or settings.fal_still_model
        n_candidates = settings.comic_still_candidates
        max_candidates = settings.comic_still_max_candidates

    report: dict = {"still": still.id, "candidates": [], "prompt": prompt}
    best_path: Path | None = None
    best: StillJudgement | None = None

    nonhuman = nonhuman_note(project, still)

    def evaluate(path: Path, tag: str) -> StillJudgement:
        judged = judge_still(settings, project, still, path, refs, ledger)
        if settings.comic_anatomy_audit:
            audit = audit_anatomy(settings, path, len(still.characters), ledger, tag=tag, nonhuman=nonhuman)
        else:
            audit = AnatomyAudit(True, skipped=True)
        blocking = [*judged.blocking, *audit.issues]
        if judged.scores.get("anatomy", 10.0) < 6:
            blocking.append("anatomy score below 6")
        judged.blocking = list(dict.fromkeys(blocking))
        judged.fixes = [*_repair_fixes(audit.issues, audit.warnings), *judged.fixes][:6]
        judged.anatomy_warnings = audit.warnings
        judged.anatomy_counts = audit.counts
        return judged

    for i in range(1, max_candidates + 1):
        if i > n_candidates and best is not None and best.ok:
            break
        cand = out_dir / f"candidate_{i}.png"
        try:
            ledger.ensure_can_afford(edit_model)
        except RuntimeError:
            if best is None:
                raise
            report["stopped"] = "budget exhausted before another candidate"
            break
        _still_edit(
            settings,
            provider,
            prompt=prompt,
            negative=negative,
            images=refs,
            size=still.image_size,
            model=edit_model,
            out_path=cand,
            seed=settings.local_seed + i - 1 if backend == "local" else None,
        )
        apply_crop(cand, still)
        ledger.charge(model=edit_model, panel_id=f"{still.id}_cand{i}")
        judged = evaluate(cand, f"{still.id}_c{i}")
        report["candidates"].append(
            {
                "file": cand.name,
                "total": judged.total,
                "scores": judged.scores,
                "blocking": judged.blocking,
                "anatomy_counts": judged.anatomy_counts,
                "anatomy_warnings": judged.anatomy_warnings,
            }
        )
        if best is None or (judged.ok and not best.ok) or (judged.ok == best.ok and judged.total > best.total):
            best_path, best = cand, judged

    assert best_path is not None and best is not None

    def refine(base_path: Path, base: StillJudgement) -> tuple[Path, StillJudgement] | None:
        if not base.fixes:
            return None
        ledger.ensure_can_afford(edit_model)
        refined = out_dir / "refined.png"
        fix_prompt = (
            "Image 1 is the base image: keep its composition, pose, lighting and both characters' identities. "
            f"Image 2 is {project.character_map()[still.characters[0]].label}, Image 3 is "
            f"{project.character_map()[still.characters[1]].label}. "
            f"Apply these improvements only: {'; '.join(base.fixes)}. {ANATOMY_RULE}. {IDENTITY_RULE}."
        )
        _still_edit(
            settings,
            provider,
            prompt=fix_prompt,
            negative=negative,
            images=[base_path, *refs],
            size=still.image_size,
            model=edit_model,
            out_path=refined,
            seed=settings.local_seed + 99 if backend == "local" else None,
        )
        apply_crop(refined, still)
        ledger.charge(model=edit_model, panel_id=f"{still.id}_refine")
        rj = evaluate(refined, f"{still.id}_r")
        report["refine"] = {
            "fixes": base.fixes,
            "total": rj.total,
            "scores": rj.scores,
            "blocking": rj.blocking,
            "anatomy_counts": rj.anatomy_counts,
        }
        return refined, rj

    def pick(cur: tuple[Path, StillJudgement], new: tuple[Path, StillJudgement]) -> tuple[Path, StillJudgement]:
        (_, a), (_, b) = cur, new
        return new if (b.ok and not a.ok) or (b.ok == a.ok and b.total >= a.total) else cur

    refined_done = False
    if (not best.ok) or best.total < settings.comic_still_min_score:
        out = refine(best_path, best)
        if out:
            refined_done = True
            best_path, best = pick((best_path, best), out)

    def strict(path: Path, judged: StillJudgement, tag: str) -> None:
        audit = strict_limb_check(settings, path, len(still.characters), ledger, tag=tag, nonhuman=nonhuman)
        report.setdefault("strict", {})[path.name] = {"ok": audit.ok, "issues": audit.issues, **audit.counts}
        if not audit.ok and not settings.comic_strict_blocking:
            report.setdefault("strict_warnings", []).extend(audit.issues)
        elif not audit.ok:
            judged.blocking = list(dict.fromkeys([*judged.blocking, *audit.issues]))
            judged.fixes = [*_repair_fixes(audit.issues, []), *judged.fixes][:6]

    if best.ok:
        try:
            strict(best_path, best, f"{still.id}_final")
        except RuntimeError as exc:
            report["strict_skipped"] = str(exc)[:120]
        if not best.ok and not refined_done:
            try:
                out = refine(best_path, best)
            except RuntimeError as exc:
                out, report["refine_skipped"] = None, str(exc)[:120]
            if out:
                refined_done = True
                if out[1].ok:
                    try:
                        strict(out[0], out[1], f"{still.id}_refined")
                    except RuntimeError as exc:
                        report["strict_skipped"] = str(exc)[:120]
                best_path, best = pick((best_path, best), out)

    final = out_dir / "final.png"
    upscaled = False
    with Image.open(best_path) as probe:
        wide_enough = probe.width >= settings.comic_upscale_min_width
    if not settings.comic_mock and backend == "fal" and best.ok and not wide_enough:
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
        needs_review=not best.ok,
        upscaled=upscaled,
        spent_usd=round(ledger.spent_usd, 4),
    )
    (out_dir / "still.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return final


def make_library_still(
    *,
    root: Path,
    still_id: str,
    settings: Settings,
    out_dir: Path,
    ledger: BudgetLedger,
    ref_crop: float = 0.55,
) -> Path:
    """Run the still pipeline from an archived library still (no project folder required)."""
    import shutil

    import yaml

    from comic_pipeline.models import Character, Still

    still_dir = root / "library" / "stills" / still_id
    still = Still.model_validate(yaml.safe_load((still_dir / "still.yaml").read_text(encoding="utf-8")))
    if ref_crop and not still.ref_crop:
        still = still.model_copy(update={"ref_crop": ref_crop})
    work = out_dir / "_project"
    chars_dir = work / "characters"
    chars_dir.mkdir(parents=True, exist_ok=True)
    chars: list[Character] = []
    for cid in still.characters:
        cdir = root / "library" / "characters" / cid
        char = Character.model_validate(yaml.safe_load((cdir / "card.yaml").read_text(encoding="utf-8")))
        char = char.model_copy(update={"reference_images": [f"characters/{cid}_ref.png"]})
        shutil.copy2(cdir / "ref.png", chars_dir / f"{cid}_ref.png")
        (chars_dir / f"{cid}.yaml").write_text(
            yaml.safe_dump(char.model_dump(), allow_unicode=True, sort_keys=False), encoding="utf-8"
        )
        chars.append(char)
    genre = still.genre if still.genre in {"xianxia", "fantasy", "scifi"} else "fantasy"
    project = Project(name=still_id, genre=genre, characters=chars, render_style="photoreal")
    (work / "project.yaml").write_text(
        yaml.safe_dump({"name": still_id, "genre": genre, "render_style": "photoreal"}, allow_unicode=True),
        encoding="utf-8",
    )
    return make_still(
        project_dir=work,
        project=project,
        still=still,
        settings=settings,
        out_dir=out_dir,
        ledger=ledger,
    )
