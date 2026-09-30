from __future__ import annotations

from pathlib import Path
from typing import Optional

import typer
import yaml
from dotenv import load_dotenv

from comic_pipeline.assemble import assemble_pages
from comic_pipeline.config import get_settings
from comic_pipeline.image import ensure_character_reference, generate_panel_image
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
    """Create a new project skeleton."""
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
    make_ref: bool = typer.Option(True, help="Generate a look-sheet reference image"),
) -> None:
    """Add or update a character card; optionally bake a reference look sheet."""
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
        ensure_character_reference(
            project_dir=project_dir,
            project=proj,
            character=char,
            settings=settings,
        )
        existing[char_id] = char
        proj.characters = list(existing.values())
    save_project(project_dir, proj)
    typer.echo(f"Saved character {char_id} in {project}")


@app.command("plan")
def plan_cmd(project: str = typer.Argument(...)) -> None:
    """Turn story.md into episode.yaml storyboard."""
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
    """Generate panel images from episode.yaml."""
    project_dir = _projects_root() / project
    proj = load_project(project_dir)
    episode = load_episode(project_dir / "episode.yaml")
    settings = get_settings()
    panel_dir = _output_root() / project / "panels"
    panels = episode.panels[:limit] if limit else episode.panels
    for panel in panels:
        out = panel_dir / f"{panel.id}.png"
        generate_panel_image(
            project_dir=project_dir,
            project=proj,
            panel=panel,
            out_path=out,
            settings=settings,
            force=force,
        )
        typer.echo(f"panel {panel.id} -> {out}")


@app.command("assemble")
def assemble_cmd(project: str = typer.Argument(...)) -> None:
    """Compose pages with dialogue bars."""
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
    """plan + generate + assemble."""
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
