from __future__ import annotations

from pathlib import Path
from typing import Optional

import typer
import yaml
from dotenv import load_dotenv

from comic_pipeline.assemble import assemble_pages
from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import get_settings, require_provider
from comic_pipeline.image import (
    ensure_character_reference,
    generate_panel_with_retries,
)
from comic_pipeline.llm import plan_episode
from comic_pipeline.models import Character, Project, load_episode, load_project, save_episode, save_project

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
    try:
        require_provider(settings)
    except RuntimeError as exc:
        typer.echo(str(exc))
        raise typer.Exit(code=1)

    ledger = BudgetLedger(limit_usd=settings.comic_budget_usd)
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
