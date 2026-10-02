"""Local GPU backend (AutoDL / rented GPU) via Hugging Face Diffusers.

No fal calls. First run downloads the model weights (several GB) into HF cache —
on AutoDL put that cache on the data disk (`/root/autodl-tmp/hf`).
"""
from __future__ import annotations

from pathlib import Path

from comic_pipeline.config import Settings

# Short aliases the still workflow / CLI can use in edit_model or LOCAL_STILL_MODEL.
ALIASES = {
    "qwen-image-edit-2511": "Qwen/Qwen-Image-Edit-2511",
    "qwen2511": "Qwen/Qwen-Image-Edit-2511",
    "flux2-klein-4b": "black-forest-labs/FLUX.2-klein-4B",
    "flux2klein4b": "black-forest-labs/FLUX.2-klein-4B",
}

SIZE_HW = {
    "portrait_4_3": (1280, 960),
    "portrait_16_9": (1280, 720),
    "square_hd": (1024, 1024),
    "landscape_4_3": (960, 1280),
}


class LocalProvider:
    name = "local"

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._pipe = None
        self._pipe_id = ""

    def ready(self) -> None:
        try:
            import torch  # noqa: F401
        except ImportError as exc:
            raise RuntimeError(
                "IMAGE_PROVIDER=local needs torch + diffusers on this machine. "
                "On AutoDL run: bash autodl/bootstrap.sh"
            ) from exc
        if not self.settings.local_still_model.strip():
            raise RuntimeError("LOCAL_STILL_MODEL is empty.")

    def resolve_model(self, model: str = "") -> str:
        raw = (model or self.settings.local_still_model).strip()
        # Ignore fal endpoint ids left in still.edit_model when switching providers.
        if "fal-ai/" in raw or "nano-banana" in raw or "gpt-image" in raw or "seedream" in raw:
            raw = self.settings.local_still_model.strip()
        return ALIASES.get(raw.lower(), raw)

    def generate(
        self,
        *,
        out_path: Path,
        prompt: str,
        negative: str,
        refs: list[Path],
    ) -> str:
        return self.call(
            self.resolve_model(),
            {"prompt": prompt, "negative": negative, "images": refs},
            out_path,
        )

    def call(self, model: str, arguments: dict, out_path: Path) -> str:
        """Generate one image. arguments: prompt, negative, images (list[Path|str]), optional size/width/height."""
        self.ready()
        model_id = self.resolve_model(model)
        images = [Path(p) for p in (arguments.get("images") or arguments.get("image_urls") or [])]
        # fal-style uploaded URLs are not usable here
        images = [p for p in images if isinstance(p, Path) or (isinstance(p, str) and not str(p).startswith("http"))]
        images = [Path(p) for p in images]
        prompt = arguments.get("prompt") or ""
        negative = arguments.get("negative") or arguments.get("negative_prompt") or ""
        size = arguments.get("size") or self.settings.fal_image_size
        h, w = SIZE_HW.get(size, (self.settings.local_height, self.settings.local_width))
        h = int(arguments.get("height") or h)
        w = int(arguments.get("width") or w)

        pipe = self._load(model_id)
        from PIL import Image
        import torch

        pil = [Image.open(p).convert("RGB") for p in images]
        seed = int(arguments.get("seed") or self.settings.local_seed)
        g = torch.Generator(device="cuda" if torch.cuda.is_available() else "cpu").manual_seed(seed)
        kwargs = {
            "prompt": prompt,
            "height": h,
            "width": w,
            "generator": g,
            "num_inference_steps": int(arguments.get("steps") or self.settings.local_steps),
        }
        is_qwen = "qwen" in model_id.lower()
        is_flux_klein = "flux" in model_id.lower() and "klein" in model_id.lower()
        # Flux2KleinPipeline has no negative_prompt kwarg (only negative_prompt_embeds).
        if negative and is_qwen:
            kwargs["negative_prompt"] = negative
        if pil:
            # Qwen edit + FLUX.2 klein both take image= or image=list
            kwargs["image"] = pil if (len(pil) > 1 or is_flux_klein) else pil[0]
        if is_qwen:
            kwargs.setdefault("true_cfg_scale", 4.0)
            kwargs.setdefault("guidance_scale", 1.0)
        else:
            kwargs.setdefault("guidance_scale", float(arguments.get("guidance_scale") or 4.0))

        print(f"[local:{model_id}] {w}x{h} steps={kwargs['num_inference_steps']} refs={len(pil)} seed={seed}")
        out = pipe(**kwargs).images[0]
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out.save(out_path)
        return model_id

    def _load(self, model_id: str):
        if self._pipe is not None and self._pipe_id == model_id:
            return self._pipe
        import torch

        dtype = torch.bfloat16 if self.settings.local_dtype == "bfloat16" else torch.float16
        print(f"[local] loading {model_id} ({self.settings.local_dtype}) …")
        if "qwen" in model_id.lower():
            from diffusers import QwenImageEditPlusPipeline

            pipe = QwenImageEditPlusPipeline.from_pretrained(model_id, torch_dtype=dtype)
        elif "flux" in model_id.lower() and "klein" in model_id.lower():
            from diffusers import Flux2KleinPipeline

            pipe = Flux2KleinPipeline.from_pretrained(model_id, torch_dtype=dtype)
        else:
            raise RuntimeError(
                f"Unsupported LOCAL model {model_id!r}. "
                "Use qwen-image-edit-2511 or flux2-klein-4b (or their HF ids)."
            )
        if torch.cuda.is_available():
            offload = (self.settings.local_offload or "model").strip().lower()
            if offload in ("sequential", "seq"):
                pipe.enable_sequential_cpu_offload()
            else:
                pipe.enable_model_cpu_offload()
            # Best-effort VRAM helpers (supported ops vary by pipeline).
            for fn_name in ("enable_attention_slicing", "enable_vae_slicing", "enable_vae_tiling"):
                fn = getattr(pipe, fn_name, None)
                if callable(fn):
                    try:
                        fn()
                    except Exception:
                        pass
            vae = getattr(pipe, "vae", None)
            if vae is not None:
                for fn_name in ("enable_tiling", "enable_slicing"):
                    fn = getattr(vae, fn_name, None)
                    if callable(fn):
                        try:
                            fn()
                        except Exception:
                            pass
        else:
            pipe.to("cpu")
        self._pipe, self._pipe_id = pipe, model_id
        return pipe
