from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from comic_pipeline.models import Episode, Project


def assemble_pages(
    *,
    episode: Episode,
    project: Project,
    panel_dir: Path,
    out_dir: Path,
) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    by_page: dict[int, list] = {}
    for panel in episode.panels:
        by_page.setdefault(panel.page, []).append(panel)

    outputs: list[Path] = []
    for page_no in sorted(by_page):
        panels = by_page[page_no]
        if project.layout == "vertical_strip":
            page_path = _assemble_vertical(panels, panel_dir, out_dir / f"page_{page_no:02d}.png")
        elif project.layout == "grid_2x4":
            page_path = _assemble_grid(
                panels, panel_dir, out_dir / f"page_{page_no:02d}.png", cols=2, rows=4
            )
        else:
            page_path = _assemble_grid(panels, panel_dir, out_dir / f"page_{page_no:02d}.png")
        outputs.append(page_path)
    return outputs


def _load_panel(panel_dir: Path, panel_id: str) -> Image.Image:
    path = panel_dir / f"{panel_id}.png"
    if not path.is_file():
        img = Image.new("RGB", (768, 1024), (40, 40, 40))
        ImageDraw.Draw(img).text((40, 40), f"missing {panel_id}", fill=(255, 80, 80))
        return img
    return Image.open(path).convert("RGB")


def _draw_dialogue(img: Image.Image, text: str) -> Image.Image:
    if not text:
        return img
    img = img.copy()
    draw = ImageDraw.Draw(img)
    w, h = img.size
    box_h = max(80, h // 8)
    draw.rectangle((0, h - box_h, w, h), fill=(0, 0, 0, 180) if img.mode == "RGBA" else (10, 10, 12))
    font = None
    size = max(28, w // 22)
    for candidate, index in (
        ("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc", 0),
        ("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", 0),
        ("DejaVuSans.ttf", 0),
    ):
        try:
            font = ImageFont.truetype(candidate, size=size, index=index)
            break
        except OSError:
            continue
    if font is None:
        font = ImageFont.load_default()
    draw.text((24, h - box_h + 20), text[:80], fill=(245, 240, 230), font=font)
    return img


def _assemble_grid(
    panels,
    panel_dir: Path,
    out_path: Path,
    cols: int = 2,
    rows: int = 3,
) -> Path:
    cell_w, cell_h = 768, 1024
    page = Image.new("RGB", (cols * cell_w, rows * cell_h), (12, 12, 14))
    for idx, panel in enumerate(panels[: cols * rows]):
        row, col = divmod(idx, cols)
        tile = _load_panel(panel_dir, panel.id).resize((cell_w, cell_h))
        tile = _draw_dialogue(tile, panel.dialogue)
        page.paste(tile, (col * cell_w, row * cell_h))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    page.save(out_path)
    return out_path


def _assemble_vertical(panels, panel_dir: Path, out_path: Path) -> Path:
    tiles = []
    width = 768
    for panel in panels:
        tile = _load_panel(panel_dir, panel.id)
        tile = tile.resize((width, int(tile.height * width / tile.width)))
        tile = _draw_dialogue(tile, panel.dialogue)
        tiles.append(tile)
    height = sum(t.height for t in tiles) + 8 * max(0, len(tiles) - 1)
    page = Image.new("RGB", (width, height), (12, 12, 14))
    y = 0
    for tile in tiles:
        page.paste(tile, (0, y))
        y += tile.height + 8
    out_path.parent.mkdir(parents=True, exist_ok=True)
    page.save(out_path)
    return out_path
