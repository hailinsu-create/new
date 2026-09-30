from __future__ import annotations

import json
from pathlib import Path

import httpx

from comic_pipeline.config import Settings


class ComfyProvider:
    """ComfyUI / AutoDL backend stub.

    Later: POST a workflow JSON to COMFY_API_URL, upload refs to /upload/image,
    poll /history/{prompt_id}, download output. Character cards + episode.yaml
    stay unchanged — only this provider swaps in for fal.
    """

    name = "comfy"

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def ready(self) -> None:
        if not self.settings.comfy_api_url.strip():
            raise RuntimeError(
                "IMAGE_PROVIDER=comfy but COMFY_API_URL is empty. "
                "Example: COMFY_API_URL=http://127.0.0.1:8188 "
                "(AutoDL port mapping to ComfyUI). "
                "Until then keep IMAGE_PROVIDER=fal."
            )

    def generate(
        self,
        *,
        out_path: Path,
        prompt: str,
        negative: str,
        refs: list[Path],
    ) -> str:
        self.ready()
        base = self.settings.comfy_api_url.rstrip("/")
        workflow_path = self.settings.comfy_workflow_path.strip()
        if not workflow_path:
            raise RuntimeError(
                "COMFY_WORKFLOW_PATH is not set. Export an API-format workflow "
                "JSON from ComfyUI (Save (API Format)) that accepts prompt + "
                "optional reference image, then point COMFY_WORKFLOW_PATH at it."
            )
        wf_file = Path(workflow_path)
        if not wf_file.is_file():
            raise RuntimeError(f"Comfy workflow not found: {wf_file}")

        # Placeholder integration surface — full queue/poll lands when AutoDL is ready.
        # Probe the server so misconfig fails fast.
        try:
            with httpx.Client(timeout=10.0) as client:
                ping = client.get(f"{base}/system_stats")
                ping.raise_for_status()
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(
                f"Cannot reach ComfyUI at {base}. Is the instance running? ({exc})"
            ) from exc

        raise RuntimeError(
            "ComfyProvider is scaffolded but not fully wired yet. "
            f"Server reachable at {base}; workflow={wf_file.name}; "
            f"prompt_chars={len(prompt)}; negative_chars={len(negative)}; "
            f"refs={[str(r) for r in refs]}. "
            "Next step: inject prompt/refs into the workflow JSON and POST /prompt."
        )

    def describe_handoff(self) -> dict:
        """Debug helper for docs/tests."""
        return {
            "provider": self.name,
            "api_url": self.settings.comfy_api_url,
            "workflow": self.settings.comfy_workflow_path,
            "status": "stub",
        }
