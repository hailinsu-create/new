from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


class MockProvider:
    name = "mock"

    def ready(self) -> None:
        return None

    def generate(
        self,
        *,
        out_path: Path,
        prompt: str,
        negative: str,
        refs: list[Path],
    ) -> str:
        img = Image.new("RGB", (768, 1024), (28, 34, 48))
        draw = ImageDraw.Draw(img)
        draw.rectangle((40, 40, 728, 984), outline=(210, 190, 140), width=3)
        draw.text((60, 80), "MOCK provider", fill=(235, 230, 220))
        draw.text((60, 130), f"refs={len(refs)}", fill=(200, 200, 210))
        draw.text((60, 900), prompt[:70] + "...", fill=(150, 160, 180))
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(out_path)
        return "mock"

    def call(self, model: str, arguments: dict, out_path: Path) -> str:
        return self.generate(
            out_path=out_path, prompt=str(arguments.get("prompt", "")), negative="", refs=[]
        )
