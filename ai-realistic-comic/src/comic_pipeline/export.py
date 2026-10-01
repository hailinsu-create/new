from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from comic_pipeline.compliance import PLATFORMS
from comic_pipeline.models import Episode, Project

FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
)


def _font(size: int) -> ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def stamp_disclosure(src: Path, dest: Path, text: str) -> None:
    with Image.open(src) as im:
        img = im.convert("RGB")
    draw = ImageDraw.Draw(img)
    font = _font(max(22, img.width // 40))
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    pad = 10
    x, y = img.width - w - pad * 2 - 12, img.height - h - pad * 2 - 12
    draw.rectangle((x, y, x + w + pad * 2, y + h + pad * 2), fill=(0, 0, 0))
    draw.text((x + pad, y + pad - box[1]), text, fill=(255, 255, 255), font=font)
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest, quality=92)


def export_release(
    *,
    project: Project,
    episode: Episode,
    pages: list[Path],
    panel_dir: Path,
    platform: str,
    out_dir: Path,
    budget_path: Path,
) -> Path:
    prof = PLATFORMS[platform]
    out_dir.mkdir(parents=True, exist_ok=True)
    disclosure = "AI-Generated"
    exported = []
    for page in pages:
        dest = out_dir / f"{page.stem}.jpg"
        stamp_disclosure(page, dest, disclosure)
        exported.append(dest.name)

    caption = f"#AIGenerated #ai  {project.title or project.name} - fictional adult characters, AI-generated artwork.\n"
    (out_dir / "caption.txt").write_text(caption, encoding="utf-8")

    panels = []
    for panel in episode.panels:
        meta_path = panel_dir / f"{panel.id}.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.is_file() else {}
        panels.append(
            {
                "panel_id": panel.id,
                "model": meta.get("model"),
                "prompt_sha256": hashlib.sha256(meta.get("prompt", "").encode("utf-8")).hexdigest(),
                "qa": meta.get("qa"),
            }
        )
    budget = json.loads(budget_path.read_text(encoding="utf-8")) if budget_path.is_file() else {}
    manifest = {
        "project": project.name,
        "platform": platform,
        "platform_label_rule": prof["label"],
        "platform_policy_source": prof["source"],
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "render_style": project.render_style,
        "content_tier": project.content_tier,
        "characters": [
            {"id": c.id, "name": c.name, "declared_age_look": c.age_look, "fictional": True}
            for c in project.characters
        ],
        "pages": exported,
        "panels": panels,
        "spent_usd": budget.get("spent_usd"),
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return manifest_path


def export_still_release(
    *,
    project: Project,
    still,
    image: Path,
    still_report: dict,
    platform: str,
    out_dir: Path,
) -> dict:
    """Stamp a finished still with the AI disclosure, write a full-size file and a free-preview file, and
    return its provenance entry. The manifest is merged by the caller."""
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{project.name}__{still.id}"
    full = out_dir / f"{stem}.jpg"
    stamp_disclosure(image, full, "AI-Generated")
    with Image.open(image) as im:
        prev = im.convert("RGB")
        prev.thumbnail((1080, 1440))
        tmp = out_dir / f"_{stem}_prev.png"
        prev.save(tmp)
    preview = out_dir / f"{stem}_preview.jpg"
    stamp_disclosure(tmp, preview, "AI-Generated")
    tmp.unlink()
    cmap = project.character_map()
    return {
        "file": full.name,
        "preview": preview.name,
        "project": project.name,
        "still": still.id,
        "platform": platform,
        "sha256": hashlib.sha256(full.read_bytes()).hexdigest(),
        "characters": [
            {"id": c, "name": cmap[c].name, "declared_age_look": cmap[c].age_look, "fictional": True}
            for c in still.characters
        ],
        "score": still_report.get("final_total"),
        "needs_review": still_report.get("needs_review"),
        "prompt_sha256": hashlib.sha256(str(still_report.get("prompt", "")).encode("utf-8")).hexdigest(),
        "spent_usd": still_report.get("spent_usd"),
    }
