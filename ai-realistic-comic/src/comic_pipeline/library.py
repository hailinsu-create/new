from __future__ import annotations

import hashlib
import shutil
from datetime import datetime, timezone
from pathlib import Path

import yaml

from comic_pipeline.models import Character, load_project


def _lib(root: Path) -> Path:
    return root / "library"


def _index_path(root: Path) -> Path:
    return _lib(root) / "index.yaml"


def _read_index(root: Path) -> list[dict]:
    path = _index_path(root)
    return yaml.safe_load(path.read_text(encoding="utf-8")) or [] if path.is_file() else []


def _write_index(root: Path, entries: list[dict]) -> None:
    _lib(root).mkdir(parents=True, exist_ok=True)
    _index_path(root).write_text(yaml.safe_dump(entries, allow_unicode=True, sort_keys=False), encoding="utf-8")


def list_library(root: Path) -> list[dict]:
    return _read_index(root)


def archive_character(root: Path, project_dir: Path, char_id: str, tags: list[str] | None = None) -> dict:
    """Snapshot a character card + look sheet into library/<id>/; bump version when the sheet changed."""
    project = load_project(project_dir)
    char = project.character_map()[char_id]
    ref_rel = char.reference_images[0]
    ref_src = project_dir / ref_rel
    card_dump = yaml.safe_dump(char.model_copy(update={"reference_images": []}).model_dump(), sort_keys=True)
    digest = hashlib.sha256(ref_src.read_bytes() + card_dump.encode("utf-8")).hexdigest()

    entries = _read_index(root)
    existing = next((e for e in entries if e["id"] == char_id), None)
    if existing and existing["ref_sha256"] == digest:
        return existing
    version = (existing["version"] + 1) if existing else 1

    dest = _lib(root) / "characters" / char_id
    if existing:
        shutil.copytree(dest, dest.parent / f"{char_id}.v{existing['version']}", dirs_exist_ok=True)
    dest.mkdir(parents=True, exist_ok=True)
    card = char.model_copy(update={"reference_images": ["ref.png"], "tags": tags or char.tags})
    (dest / "card.yaml").write_text(yaml.safe_dump(card.model_dump(), allow_unicode=True, sort_keys=False), encoding="utf-8")
    shutil.copy2(ref_src, dest / "ref.png")
    meta_src = ref_src.with_suffix(".json")
    if meta_src.is_file():
        shutil.copy2(meta_src, dest / "ref.json")

    entry = {
        "id": char_id,
        "name": char.name,
        "form": char.form,
        "variant_of": char.variant_of,
        "tags": card.tags,
        "version": version,
        "ref_sha256": digest,
        "source_project": project_dir.name,
        "genre": project.genre,
        "render_style": project.render_style,
        "archived_at": datetime.now(timezone.utc).isoformat(),
    }
    entries = [e for e in entries if e["id"] != char_id] + [entry]
    _write_index(root, sorted(entries, key=lambda e: e["id"]))
    return entry


def use_character(root: Path, project_dir: Path, char_id: str) -> Character:
    """Copy a library character into a project's characters/ folder (card + ref)."""
    src = _lib(root) / "characters" / char_id
    if not src.is_dir():
        raise RuntimeError(f"{char_id!r} not in library; run `comic archive` first")
    card = Character.model_validate(yaml.safe_load((src / "card.yaml").read_text(encoding="utf-8")))
    chars = project_dir / "characters"
    chars.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "ref.png", chars / f"{char_id}_ref.png")
    if (src / "ref.json").is_file():
        shutil.copy2(src / "ref.json", chars / f"{char_id}_ref.json")
    card.reference_images = [f"characters/{char_id}_ref.png"]
    (chars / f"{char_id}.yaml").write_text(
        yaml.safe_dump(card.model_dump(), allow_unicode=True, sort_keys=False), encoding="utf-8"
    )
    return card


__all__ = ["archive_character", "list_library", "use_character"]
