from __future__ import annotations

from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, Field

Genre = Literal["xianxia", "fantasy", "scifi"]


class Character(BaseModel):
    id: str
    name: str
    age_look: str = ""
    face: str = ""
    hair: str = ""
    wardrobe: str = ""
    signature_props: str = ""
    notes: str = ""
    reference_images: list[str] = Field(default_factory=list)

    def prompt_block(self) -> str:
        parts = [
            f"Character {self.name} (id={self.id})",
            f"age look: {self.age_look}" if self.age_look else "",
            f"face: {self.face}" if self.face else "",
            f"hair: {self.hair}" if self.hair else "",
            f"wardrobe (LOCKED unless panel says costume change): {self.wardrobe}"
            if self.wardrobe
            else "",
            f"signature props: {self.signature_props}" if self.signature_props else "",
            f"notes: {self.notes}" if self.notes else "",
        ]
        return "; ".join(p for p in parts if p)


class Panel(BaseModel):
    id: str
    page: int = 1
    shot: str
    characters: list[str] = Field(default_factory=list)
    emotion: str = ""
    dialogue: str = ""
    action: str = ""
    setting: str = ""
    negative: str = "cartoon, anime, illustration, deformed face, extra fingers"


class Still(BaseModel):
    """A single refined hero image with two characters."""

    id: str
    title: str = ""
    characters: list[str] = Field(default_factory=list)
    setting: str = ""
    camera: str = "85mm portrait lens, medium shot, shallow depth of field"
    lighting: str = ""
    blocking: str = ""  # who stands/sits where, gaze, touch
    wardrobe_state: str = ""  # what is worn and how (always covered)
    motif: str = ""  # the specific theme/dynamic this image is about
    mood: str = ""
    negative: str = ""
    image_size: str = "portrait_4_3"


class Episode(BaseModel):
    title: str
    genre: Genre
    logline: str = ""
    panels: list[Panel] = Field(default_factory=list)


class Project(BaseModel):
    name: str
    genre: Genre = "xianxia"
    title: str = ""
    layout: Literal["grid_2x3", "grid_2x4", "vertical_strip"] = "grid_2x3"
    render_style: Literal["photoreal", "stylized"] = "photoreal"
    content_tier: Literal["sfw", "suggestive", "explicit"] = "suggestive"
    atmosphere: str = ""
    characters: list[Character] = Field(default_factory=list)

    def character_map(self) -> dict[str, Character]:
        return {c.id: c for c in self.characters}


def load_project(project_dir: Path) -> Project:
    path = project_dir / "project.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    chars: list[Character] = []
    char_dir = project_dir / "characters"
    if char_dir.is_dir():
        for file in sorted(char_dir.glob("*.yaml")):
            raw = yaml.safe_load(file.read_text(encoding="utf-8")) or {}
            chars.append(Character.model_validate(raw))
    data["characters"] = chars
    if "name" not in data:
        data["name"] = project_dir.name
    return Project.model_validate(data)


def save_project(project_dir: Path, project: Project) -> None:
    project_dir.mkdir(parents=True, exist_ok=True)
    (project_dir / "characters").mkdir(parents=True, exist_ok=True)
    root = project.model_dump(exclude={"characters"})
    (project_dir / "project.yaml").write_text(
        yaml.safe_dump(root, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    for char in project.characters:
        (project_dir / "characters" / f"{char.id}.yaml").write_text(
            yaml.safe_dump(char.model_dump(), allow_unicode=True, sort_keys=False),
            encoding="utf-8",
        )


def load_episode(path: Path) -> Episode:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return Episode.model_validate(data)


def save_episode(path: Path, episode: Episode) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(episode.model_dump(), allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )


def load_still(path: Path) -> Still:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return Still.model_validate(data)
