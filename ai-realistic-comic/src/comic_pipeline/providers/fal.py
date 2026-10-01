from __future__ import annotations

import os
from pathlib import Path

import httpx

from comic_pipeline.config import Settings


class FalProvider:
    name = "fal"

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def ready(self) -> None:
        if not self.settings.fal_key.strip():
            raise RuntimeError(
                "IMAGE_PROVIDER=fal but FAL_KEY is not set. "
                "Add FAL_KEY to Secrets / .env, or set COMIC_MOCK=1 for offline tests."
            )

    def generate(
        self,
        *,
        out_path: Path,
        prompt: str,
        negative: str,
        refs: list[Path],
    ) -> str:
        import fal_client

        self.ready()
        os.environ["FAL_KEY"] = self.settings.fal_key.strip()
        settings = self.settings

        if settings.comic_ref_mode == "edit":
            avoid = f" Avoid: {negative}." if negative else ""
            if refs:
                model = settings.fal_edit_model
                arguments = {
                    "prompt": prompt + avoid,
                    "image_urls": [fal_client.upload_file(str(r)) for r in refs],
                    "image_size": settings.fal_image_size,
                    "num_images": 1,
                    "enable_safety_checker": settings.fal_enable_safety_checker,
                }
            else:
                model = settings.fal_edit_t2i_model
                arguments = {
                    "prompt": prompt + avoid,
                    "image_size": settings.fal_image_size,
                    "num_images": 1,
                    "enable_safety_checker": settings.fal_enable_safety_checker,
                }
        elif len(refs) == 1:
            model = settings.fal_pulid_model
            ref_url = fal_client.upload_file(str(refs[0]))
            arguments = {
                "prompt": prompt,
                "reference_image_url": ref_url,
                "negative_prompt": negative,
                "image_size": settings.fal_image_size,
                "num_inference_steps": settings.fal_num_inference_steps,
                "guidance_scale": settings.fal_guidance_scale,
                "id_weight": settings.fal_id_weight,
                "enable_safety_checker": settings.fal_enable_safety_checker,
            }
        else:
            model = settings.resolved_t2i_model()
            arguments = {
                "prompt": prompt,
                "image_size": settings.fal_image_size,
                "num_inference_steps": max(settings.fal_num_inference_steps, 32),
                "guidance_scale": max(settings.fal_guidance_scale, 4.0),
                "enable_safety_checker": settings.fal_enable_safety_checker,
                "num_images": 1,
            }

        return self.call(model, arguments, out_path)

    def call(self, model: str, arguments: dict, out_path: Path) -> str:
        """Run any fal image endpoint and write the first returned image to out_path."""
        import fal_client

        self.ready()
        os.environ["FAL_KEY"] = self.settings.fal_key.strip()

        def _on_update(update) -> None:  # noqa: ANN001
            if isinstance(update, fal_client.InProgress) and update.logs:
                for log in update.logs:
                    msg = log.get("message") if isinstance(log, dict) else getattr(log, "message", None)
                    if msg:
                        print(f"[fal:{model}] {msg}")

        result = fal_client.subscribe(
            model,
            arguments=arguments,
            with_logs=True,
            on_queue_update=_on_update,
        )
        images = result.get("images") or ([result["image"]] if result.get("image") else [])
        if not images:
            raise RuntimeError(f"fal returned no images: {result}")
        url = images[0]["url"] if isinstance(images[0], dict) else images[0]
        with httpx.Client(timeout=180.0) as client:
            resp = client.get(url)
            resp.raise_for_status()
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_bytes(resp.content)
        return model
