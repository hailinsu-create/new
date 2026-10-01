from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

import typer
import yaml
from dotenv import load_dotenv

from comic_pipeline.assemble import assemble_pages
from comic_pipeline.budget import BudgetLedger
from comic_pipeline.compliance import PLATFORMS, format_report, lint_project, lint_still
from comic_pipeline.config import get_settings, require_provider
from comic_pipeline.export import export_release, export_still_release
from comic_pipeline.image import (
    ensure_character_reference,
    generate_panel_with_retries,
)
from comic_pipeline.llm import plan_episode
from comic_pipeline.qa import qa_panel, qa_reference
from comic_pipeline.refine import edit_character_reference
from comic_pipeline.library import archive_character, list_library, use_character
from comic_pipeline.still import make_library_still, make_still
from comic_pipeline.models import load_still, Character, Project, load_episode, load_project, save_episode, save_project

app = typer.Typer(add_completion=False, no_args_is_help=True, help="AI realistic comic pipeline")
ROOT = Path.cwd()


def _projects_root() -> Path:
    return ROOT / "projects"


def _output_root() -> Path:
    return ROOT / "output"


@app.callback()
def _load_env() -> None:
    load_dotenv(ROOT / ".env")


@app.command("init")
def init_project(
    slug: str = typer.Argument(..., help="Project folder name"),
    genre: str = typer.Option("xianxia", help="xianxia | fantasy | scifi"),
    title: str = typer.Option("", help="Display title"),
) -> None:
    if genre not in {"xianxia", "fantasy", "scifi"}:
        raise typer.BadParameter("genre must be xianxia, fantasy, or scifi")
    project_dir = _projects_root() / slug
    if project_dir.exists():
        typer.echo(f"Project already exists: {project_dir}")
        raise typer.Exit(code=1)
    project = Project(name=slug, genre=genre, title=title or slug)  # type: ignore[arg-type]
    save_project(project_dir, project)
    (project_dir / "story.md").write_text(
        "# Story\n\nWrite a short outline for one episode.\n",
        encoding="utf-8",
    )
    typer.echo(f"Created {project_dir}")



@app.command("still-library")
def still_library_cmd(
    still_id: str = typer.Argument(..., help="library/stills/<id>"),
    ref_crop: float = typer.Option(0.55, help="Top fraction of each look sheet to keep"),
) -> None:
    """Render an archived library still on the active IMAGE_PROVIDER (fal or local/AutoDL)."""
    settings = get_settings()
    out_dir = _output_root() / "library-stills" / still_id
    ledger = BudgetLedger.load_or_new(out_dir / "budget.json", settings.comic_still_budget_usd)
    try:
        final = make_library_still(
            root=ROOT,
            still_id=still_id,
            settings=settings,
            out_dir=out_dir,
            ledger=ledger,
            ref_crop=ref_crop,
        )
    except RuntimeError as exc:
        ledger.save(out_dir / "budget.json")
        typer.echo(f"STOP: {exc}")
        raise typer.Exit(code=1)
    except Exception:
        ledger.save(out_dir / "budget.json")
        raise
    ledger.save(out_dir / "budget.json")
    typer.echo(f"still-library -> {final} | spent ${ledger.spent_usd:.4f}/${ledger.limit_usd:.4f}")


@app.command("still-new")
def still_new(
    project: str = typer.Argument(...),
    still_id: str = typer.Argument(..., help="New still id (file name)"),
    char_a: str = typer.Argument(..., help="First character id"),
    char_b: str = typer.Argument(..., help="Second character id"),
) -> None:
    """Create projects/<project>/stills/<id>.yaml from templates/still.template.yaml."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    cmap = proj.character_map()
    for cid in (char_a, char_b):
        if cid not in cmap:
            raise typer.BadParameter(f"unknown character '{cid}' in {project}: {', '.join(cmap)}")
    target = project_dir / "stills" / f"{still_id}.yaml"
    if target.exists():
        typer.echo(f"Already exists: {target}")
        raise typer.Exit(code=1)
    text = (Path(__file__).resolve().parents[2] / "templates" / "still.template.yaml").read_text(encoding="utf-8")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text.format(id=still_id, char_a=char_a, char_b=char_b), encoding="utf-8")
    typer.echo(f"Created {target}\nFill the <...> fields, then: comic still {project} {still_id} --platform fanvue")


@app.command("doctor")
def doctor() -> None:
    settings = get_settings()
    typer.echo(f"COMIC_MOCK={settings.comic_mock}")
    typer.echo(f"IMAGE_PROVIDER={settings.resolved_provider()}")
    typer.echo(f"FAL_KEY={'set' if settings.fal_key.strip() else 'MISSING'}")
    typer.echo(f"COMIC_BUDGET_USD={settings.comic_budget_usd}")
    typer.echo(f"COMIC_MAX_REF_TRIES={settings.comic_max_ref_tries}")
    typer.echo(f"COMIC_MAX_PANEL_TRIES={settings.comic_max_panel_tries}")
    typer.echo(f"COMIC_MAX_PAGE_REPAIR={settings.comic_max_page_repair}")
    typer.echo(f"COMIC_FORBID_MULTI_FACE={settings.comic_forbid_multi_face}")
    typer.echo(f"FAL_T2I_MODEL={settings.resolved_t2i_model()}")
    typer.echo(f"FAL_PULID_MODEL={settings.fal_pulid_model}")
    typer.echo(f"LOCAL_STILL_MODEL={settings.local_still_model}")
    typer.echo(f"LOCAL_CANDIDATES={settings.local_candidates}")
    try:
        require_provider(settings)
        typer.echo(f"{settings.resolved_provider()} mode: ready")
    except RuntimeError as exc:
        typer.echo(f"{settings.resolved_provider()} mode: NOT ready — {exc}")
        raise typer.Exit(code=1)


@app.command("cast")
def cast_character(
    project: str = typer.Argument(...),
    char_id: str = typer.Option(..., "--id"),
    name: str = typer.Option(...),
    age_look: str = typer.Option(""),
    face: str = typer.Option(""),
    hair: str = typer.Option(""),
    wardrobe: str = typer.Option(""),
    signature_props: str = typer.Option(""),
    notes: str = typer.Option(""),
    make_ref: bool = typer.Option(True, help="Generate look-sheet if missing"),
    force_ref: bool = typer.Option(False, help="Regenerate look-sheet (costs budget)"),
) -> None:
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    char = Character(
        id=char_id,
        name=name,
        age_look=age_look,
        face=face,
        hair=hair,
        wardrobe=wardrobe,
        signature_props=signature_props,
        notes=notes,
    )
    existing = {c.id: c for c in proj.characters}
    existing[char_id] = char
    proj.characters = list(existing.values())
    settings = get_settings()
    if make_ref:
        try:
            require_provider(settings)
        except RuntimeError as exc:
            typer.echo(str(exc))
            raise typer.Exit(code=1)
        ledger = BudgetLedger(limit_usd=settings.comic_budget_usd)
        ensure_character_reference(
            project_dir=project_dir,
            project=proj,
            character=char,
            settings=settings,
            ledger=ledger,
            force=force_ref,
        )
        existing[char_id] = char
        proj.characters = list(existing.values())
        ledger.save(_output_root() / project / "budget.json")
        typer.echo(f"budget spent ${ledger.spent_usd:.4f} / ${ledger.limit_usd:.4f}")
    save_project(project_dir, proj)
    typer.echo(f"Saved character {char_id} in {project}")


@app.command("refs")
def refs_cmd(
    project: str = typer.Argument(...),
    force: bool = typer.Option(False, help="Regenerate look sheets (costs budget)"),
    only: Optional[str] = typer.Option(None, help="Only this character id"),
) -> None:
    """Generate look sheets for every character card in the project."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    settings = get_settings()
    require_provider(settings)
    budget_path = _output_root() / project / "budget.json"
    ledger = BudgetLedger.load_or_new(budget_path, settings.comic_budget_usd)
    for char in proj.characters:
        if only and char.id != only:
            continue
        ensure_character_reference(
            project_dir=project_dir,
            project=proj,
            character=char,
            settings=settings,
            ledger=ledger,
            force=force,
        )
        typer.echo(f"ref {char.id}: {char.reference_images} | spent ${ledger.spent_usd:.4f}")
    ledger.save(budget_path)
    save_project(project_dir, proj)


@app.command("lint")
def lint_cmd(
    project: str = typer.Argument(...),
    platform: Optional[str] = typer.Option(None, help=f"One of: {', '.join(sorted(PLATFORMS))}"),
) -> None:
    """Check adult-age declarations, minor-coded terms, content tier and platform fit."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    ep_path = project_dir / "episode.yaml"
    episode = load_episode(ep_path) if ep_path.is_file() else None
    report = lint_project(proj, episode, get_settings(), platform)
    typer.echo(format_report(report))
    if not report.ok:
        raise typer.Exit(code=1)


@app.command("export")
def export_cmd(
    project: str = typer.Argument(...),
    platform: str = typer.Option(..., help=f"One of: {', '.join(sorted(PLATFORMS))}"),
) -> None:
    """Lint, stamp the AI disclosure on pages, and write caption + provenance manifest."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    episode = load_episode(project_dir / "episode.yaml")
    report = lint_project(proj, episode, get_settings(), platform)
    typer.echo(format_report(report))
    if not report.ok:
        raise typer.Exit(code=1)
    out_root = _output_root() / project
    pages = sorted((out_root / "pages").glob("page_*.png"))
    if not pages:
        typer.echo("No assembled pages; run `comic assemble` first.")
        raise typer.Exit(code=1)
    manifest = export_release(
        project=proj,
        episode=episode,
        pages=pages,
        panel_dir=out_root / "panels",
        platform=platform,
        out_dir=out_root / "export" / platform,
        budget_path=out_root / "budget.json",
    )
    typer.echo(f"export -> {manifest.parent}")


@app.command("export-stills")
def export_stills_cmd(
    platform: str = typer.Option(..., help=f"One of: {', '.join(sorted(PLATFORMS))}"),
    out: str = typer.Option("launch/fanvue", help="Output folder under output/"),
    items: list[str] = typer.Argument(..., help="project:still-id pairs"),
) -> None:
    """Lint and stamp finished stills (full + free preview) and merge their provenance into manifest.json."""
    settings = get_settings()
    out_dir = _output_root() / out
    entries = []
    for item in items:
        project, _, still_id = item.partition(":")
        project_dir = _projects_root() / project
        proj = load_project(project_dir)
        spec = load_still(project_dir / "stills" / f"{still_id}.yaml")
        report = lint_still(spec, proj, settings, platform)
        if not report.ok:
            typer.echo(format_report(report))
            raise typer.Exit(code=1)
        still_dir = _output_root() / project / "stills" / still_id
        info = json.loads((still_dir / "still.json").read_text(encoding="utf-8")) if (still_dir / "still.json").is_file() else {}
        entries.append(
            export_still_release(
                project=proj, still=spec, image=still_dir / "final.png", still_report=info, platform=platform, out_dir=out_dir
            )
        )
        typer.echo(f"exported {item}")
    manifest = out_dir / "manifest.json"
    old = json.loads(manifest.read_text(encoding="utf-8")).get("items", []) if manifest.is_file() else []
    merged = {e["file"]: e for e in [*old, *entries]}
    manifest.write_text(
        json.dumps({"platform": platform, "platform_label_rule": PLATFORMS[platform]["label"], "items": list(merged.values())}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    typer.echo(f"export-stills -> {out_dir}")


@app.command("qa")
def qa_cmd(project: str = typer.Argument(...)) -> None:
    """Run the vision QA gate over existing look sheets and panels (about $0.005 per image)."""
    from comic_pipeline.image import _record_qa, reference_paths

    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    episode = load_episode(project_dir / "episode.yaml")
    settings = get_settings()
    budget_path = _output_root() / project / "budget.json"
    ledger = BudgetLedger.load_or_new(budget_path, settings.comic_budget_usd)
    for char in proj.characters:
        for rel in char.reference_images[:1]:
            res = qa_reference(settings, char, project_dir / rel, ledger, proj.render_style)
            typer.echo(f"ref {char.id}: {'PASS' if res.ok else 'FAIL'} {res.hint()}")
    for panel in episode.panels:
        img = _output_root() / project / "panels" / f"{panel.id}.png"
        if not img.is_file():
            continue
        refs = reference_paths(project_dir, proj, panel, settings.comic_ref_mode == "edit")
        res = qa_panel(settings, proj, panel, img, refs, ledger)
        _record_qa(img, res)
        typer.echo(f"panel {panel.id}: {'PASS' if res.ok else 'FAIL'} {res.hint()}")
    ledger.save(budget_path)
    typer.echo(f"spent ${ledger.spent_usd:.4f} / ${ledger.limit_usd:.4f}")


@app.command("still")
def still_cmd(
    project: str = typer.Argument(...),
    still_id: str = typer.Argument(..., help="projects/<project>/stills/<id>.yaml"),
    platform: Optional[str] = typer.Option(None, help="Lint against a platform profile first"),
) -> None:
    """Make one refined two-character image: candidates, judge, targeted edit, upscale."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    spec = load_still(project_dir / "stills" / f"{still_id}.yaml")
    settings = get_settings()
    report = lint_still(spec, proj, settings, platform)
    typer.echo(format_report(report))
    if not report.ok:
        raise typer.Exit(code=1)
    out_dir = _output_root() / project / "stills" / still_id
    ledger = BudgetLedger.load_or_new(out_dir / "budget.json", settings.comic_still_budget_usd)
    try:
        final = make_still(
            project_dir=project_dir, project=proj, still=spec, settings=settings, out_dir=out_dir, ledger=ledger
        )
    except RuntimeError as exc:
        ledger.save(out_dir / "budget.json")
        typer.echo(f"STOP: {exc}")
        raise typer.Exit(code=1)
    except Exception:
        ledger.save(out_dir / "budget.json")
        raise
    ledger.save(out_dir / "budget.json")
    typer.echo(f"still -> {final} | spent ${ledger.spent_usd:.4f}/${ledger.limit_usd:.4f}")
    try:
        data = json.loads((out_dir / "still.json").read_text(encoding="utf-8"))
        if data.get("needs_review"):
            typer.echo(f"WARN  unresolved deal-breakers, review by eye: {'; '.join(data.get('final_blocking', []))}")
    except (OSError, ValueError):
        pass


@app.command("fix-ref")
def fix_ref_cmd(
    project: str = typer.Argument(...),
    char_id: str = typer.Argument(...),
    fix: str = typer.Option(..., help="What to change, in plain English"),
    tries: int = typer.Option(2, help="Max edit attempts"),
) -> None:
    """Targeted edit of an existing look sheet (previous version is archived)."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    char = proj.character_map()[char_id]
    settings = get_settings()
    budget_path = _output_root() / project / "budget.json"
    ledger = BudgetLedger.load_or_new(budget_path, settings.comic_budget_usd)
    base = project_dir / char.reference_images[0]
    res = edit_character_reference(
        project_dir=project_dir, project=proj, character=char, base_image=base,
        instruction=fix, settings=settings, ledger=ledger, max_tries=tries,
    )
    ledger.save(budget_path)
    save_project(project_dir, proj)
    typer.echo(f"{char_id}: {'PASS' if res.ok else 'ACCEPTED WITH ISSUES: ' + res.hint()} | spent ${ledger.spent_usd:.4f}")


@app.command("variant")
def variant_cmd(
    project: str = typer.Argument(...),
    base_id: str = typer.Argument(..., help="Existing character to derive from"),
    new_id: str = typer.Argument(...),
    instruction: str = typer.Option(..., help="How the form differs"),
    name: str = typer.Option(..., help="Display name of the new form"),
    form: str = typer.Option("variant"),
    wardrobe: str = typer.Option("", help="Override wardrobe text for the new card"),
    tries: int = typer.Option(3),
) -> None:
    """Derive an alternate form (e.g. serpent body) from a base look sheet, keeping the same face."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    base = proj.character_map()[base_id]
    card = base.model_copy(
        update={"id": new_id, "name": name, "variant_of": base_id, "form": form, "reference_images": [],
                "wardrobe": wardrobe or base.wardrobe}
    )
    proj.characters.append(card)
    settings = get_settings()
    budget_path = _output_root() / project / "budget.json"
    ledger = BudgetLedger.load_or_new(budget_path, settings.comic_budget_usd)
    base_img = project_dir / base.reference_images[0]
    res = edit_character_reference(
        project_dir=project_dir, project=proj, character=card, base_image=base_img,
        instruction=instruction, settings=settings, ledger=ledger, max_tries=tries,
        keep_identity_from=None,
    )
    ledger.save(budget_path)
    save_project(project_dir, proj)
    typer.echo(f"{new_id}: {'PASS' if res.ok else 'ACCEPTED WITH ISSUES: ' + res.hint()} | spent ${ledger.spent_usd:.4f}")


@app.command("archive")
def archive_cmd(
    project: str = typer.Argument(...),
    char_id: str = typer.Argument(...),
    tags: str = typer.Option("", help="Comma separated tags"),
) -> None:
    """Copy a character card + look sheet into the reusable library/."""
    entry = archive_character(ROOT, _projects_root() / project, char_id, [t for t in tags.split(",") if t])
    typer.echo(f"library/{entry['id']} v{entry['version']} sha={entry['ref_sha256'][:12]}")


@app.command("use")
def use_cmd(project: str = typer.Argument(...), char_id: str = typer.Argument(...)) -> None:
    """Import a library character into a project."""
    use_character(ROOT, _projects_root() / project, char_id)
    typer.echo(f"imported {char_id} into {project}")


@app.command("library")
def library_cmd() -> None:
    for e in list_library(ROOT):
        typer.echo(f"{e['id']}\tv{e['version']}\t{e['name']}\tform={e.get('form') or '-'}\ttags={','.join(e.get('tags', []))}")


@app.command("plan")
def plan_cmd(project: str = typer.Argument(...)) -> None:
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    settings = get_settings()
    episode = plan_episode(proj, project_dir / "story.md", settings)
    out = project_dir / "episode.yaml"
    save_episode(out, episode)
    typer.echo(f"Wrote {out} with {len(episode.panels)} panels")


@app.command("generate")
def generate_cmd(
    project: str = typer.Argument(...),
    force: bool = typer.Option(False, help="Ignore panel cache"),
    limit: Optional[int] = typer.Option(None, help="Only first N panels"),
) -> None:
    """Generate panels with budget + retry caps."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    episode = load_episode(project_dir / "episode.yaml")
    settings = get_settings()
    report = lint_project(proj, episode, settings)
    if not report.ok:
        typer.echo(format_report(report))
        raise typer.Exit(code=1)
    try:
        require_provider(settings)
    except RuntimeError as exc:
        typer.echo(str(exc))
        raise typer.Exit(code=1)

    ledger = BudgetLedger.load_or_new(
        _output_root() / project / "budget.json", settings.comic_budget_usd
    )
    panel_dir = _output_root() / project / "panels"
    panels = episode.panels[:limit] if limit else episode.panels
    for panel in panels:
        out = panel_dir / f"{panel.id}.png"
        try:
            generate_panel_with_retries(
                project_dir=project_dir,
                project=proj,
                panel=panel,
                out_path=out,
                settings=settings,
                force=force,
                ledger=ledger,
            )
            qa = json.loads(out.with_suffix(".json").read_text(encoding="utf-8")).get("qa") or {}
            if qa and not qa.get("ok"):
                typer.echo(f"  QA flagged {panel.id}: {'; '.join(qa.get('issues', []))}")
            typer.echo(
                f"panel {panel.id} -> {out} | spent ${ledger.spent_usd:.4f}/${ledger.limit_usd:.4f}"
            )
        except RuntimeError as exc:
            ledger.save(_output_root() / project / "budget.json")
            typer.echo(f"STOP on {panel.id}: {exc}")
            raise typer.Exit(code=1)
    ledger.save(_output_root() / project / "budget.json")
    typer.echo(f"budget total ${ledger.spent_usd:.4f} / ${ledger.limit_usd:.4f}")


@app.command("assemble")
def assemble_cmd(project: str = typer.Argument(...)) -> None:
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    episode = load_episode(project_dir / "episode.yaml")
    panel_dir = _output_root() / project / "panels"
    pages_dir = _output_root() / project / "pages"
    paths = assemble_pages(
        episode=episode,
        project=proj,
        panel_dir=panel_dir,
        out_dir=pages_dir,
    )
    for p in paths:
        typer.echo(f"page -> {p}")


@app.command("run")
def run_all(
    project: str = typer.Argument(...),
    force: bool = typer.Option(False),
) -> None:
    plan_cmd(project)
    generate_cmd(project, force=force, limit=None)
    assemble_cmd(project)


@app.command("list-projects")
def list_projects() -> None:
    root = _projects_root()
    if not root.is_dir():
        typer.echo("No projects/")
        return
    for path in sorted(root.iterdir()):
        if (path / "project.yaml").is_file():
            data = yaml.safe_load((path / "project.yaml").read_text(encoding="utf-8")) or {}
            typer.echo(f"{path.name}\tgenre={data.get('genre')}\ttitle={data.get('title')}")


if __name__ == "__main__":
    app()
