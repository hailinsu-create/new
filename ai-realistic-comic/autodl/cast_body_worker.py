"""F34 cast-asset worker. 8bit transformer stays on GPU. VAE stays on CPU.

Independent of the explicit-still job files. Do not load a full BF16 copy.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

os.environ.setdefault("HF_HOME", "/root/autodl-tmp/hf")
os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
os.environ.setdefault("DIFFUSERS_OFFLINE", "1")
os.environ.setdefault("HF_HUB_DISABLE_XET", "1")

import numpy as np
import torch
from PIL import Image

JOB = Path("/root/autodl-tmp/in/cast-asset-job.json")
STOP = Path("/root/autodl-tmp/in/cast-asset-stop")
DONE = Path("/root/autodl-tmp/out/cast-asset-done.json")
LORA = Path("/root/autodl-tmp/loras/qwen-image-edit-plus-nsfw-lora.safetensors")

_fused_scale = None


def mem_line() -> str:
    info = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, _, rest = line.partition(":")
            if key in {"MemTotal", "MemAvailable", "MemFree", "SwapTotal", "SwapFree"}:
                info[key] = int(rest.strip().split()[0])
    except OSError:
        pass
    hwm = ""
    try:
        for line in Path("/proc/self/status").read_text().splitlines():
            if line.startswith("VmHWM:"):
                hwm = line.split()[1]
    except OSError:
        pass
    gpu = "n/a"
    try:
        import subprocess

        gpu = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=memory.used,memory.total,utilization.gpu",
                "--format=csv,noheader",
            ],
            text=True,
            timeout=15,
        ).strip()
    except Exception:
        gpu = "n/a"
    return (
        f"avail_kb={info.get('MemAvailable')} total_kb={info.get('MemTotal')} "
        f"swap_free_kb={info.get('SwapFree')} swap_total_kb={info.get('SwapTotal')} "
        f"hwm_kb={hwm} gpu={gpu}"
    )


def fuse_scale(pipe, scale: float) -> None:
    """Bake the table scale once. Do not multiply it, and do not re-fuse every image.

    set_adapters writes the weight. Fusing again at that same scale multiplies
    it, so 0.85 was baked as 0.7225. Unfusing and refusing on every
    seed does not make later seeds better. The same double scale was already
    in effect when seeds 34-36 undressed, so this fix is not a new prompt.
    """
    global _fused_scale
    scale = float(scale)
    if _fused_scale == scale:
        return
    if _fused_scale is not None:
        pipe.unfuse_lora()
    pipe.set_adapters(["mcnl"], adapter_weights=[scale])
    pipe.fuse_lora(lora_scale=1.0)
    _fused_scale = scale


def letterbox(image: Image.Image, width: int, height: int) -> Image.Image:
    """Fit the whole plate inside the frame. Do not center-crop the head or the feet."""
    image = image.convert("RGB")
    scale = min(width / image.width, height / image.height)
    resized = image.resize(
        (max(1, int(round(image.width * scale))), max(1, int(round(image.height * scale)))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGB", (width, height), image.getpixel((0, 0)))
    canvas.paste(resized, ((width - resized.width) // 2, (height - resized.height) // 2))
    return canvas


def pack_image(pipe, image: Image.Image, width: int, height: int, generator):
    processed = pipe.image_processor.preprocess(image, height, width).unsqueeze(2)
    device = pipe._execution_device
    processed = processed.to(device=device, dtype=pipe.vae.dtype)
    encoded = pipe._encode_vae_image(image=processed, generator=generator)
    num_channels = pipe.transformer.config.in_channels // 4
    spatial_h, spatial_w = encoded.shape[-2], encoded.shape[-1]
    return pipe._pack_latents(encoded, encoded.shape[0], num_channels, spatial_h, spatial_w)


def generation_seq(pipe, width: int, height: int) -> int:
    factor = pipe.vae_scale_factor * 2
    latent_h = 2 * (height // factor)
    latent_w = 2 * (width // factor)
    return (latent_h // 2) * (latent_w // 2)


def noise_at_denoise(pipe, clean, width: int, height: int, steps: int, denoise: float, generator):
    del width, height
    seq = clean.shape[1]
    module = __import__(type(pipe).__module__, fromlist=["calculate_shift"])
    mu = module.calculate_shift(
        seq,
        pipe.scheduler.config.get("base_image_seq_len", 256),
        pipe.scheduler.config.get("max_image_seq_len", 4096),
        pipe.scheduler.config.get("base_shift", 0.5),
        pipe.scheduler.config.get("max_shift", 1.15),
    )
    raw = np.linspace(1.0, 1.0 / steps, steps)
    pipe.scheduler.begin_index = None
    pipe.scheduler.step_index = None
    pipe.scheduler.set_timesteps(num_inference_steps=steps, device="cpu", sigmas=raw, mu=mu)
    keep = max(1, int(round(steps * denoise)))
    start = steps - keep
    timestep = pipe.scheduler.timesteps[start]
    noise = torch.randn(clean.shape, generator=generator, dtype=clean.dtype, device=clean.device)
    pipe.scheduler.begin_index = None
    pipe.scheduler.step_index = None
    noised = pipe.scheduler.scale_noise(clean, timestep.reshape(1), noise)
    return noised, raw[start:].tolist()


def render(pipe, job: dict) -> dict:
    kind = job["kind"]
    if kind == "clothed":
        raise SystemExit(
            "CODEX_CLI_ONLY 穿衣底板禁止 F34。缺 Codex CLI 就退出，不在这台机器上画穿衣底板。"
        )
    scale = float(job["scale"])
    seed = int(job["seed"])
    width = int(job["width"])
    height = int(job["height"])
    steps = int(job["steps"])
    prompt = Path(job["prompt"]).read_text(encoding="utf-8").strip()
    negative = job.get("negative") or ""
    images = []
    face_path = job.get("face")
    if face_path:
        # Native lock face. Do not letterbox the headshot onto the body canvas.
        images.append(Image.open(face_path).convert("RGB"))
    src = Image.open(job["src"]).convert("RGB")
    if kind == "pass1":
        src = letterbox(src, width, height)
    else:
        src = src.resize((width, height), Image.Resampling.LANCZOS)
    images.append(src)
    fuse_scale(pipe, scale)
    generator = torch.Generator(device="cpu").manual_seed(seed)
    kwargs = {
        "prompt": prompt,
        "image": images,
        "height": height,
        "width": width,
        "generator": generator,
        "true_cfg_scale": float(job.get("true_cfg_scale") or 4.0),
        "guidance_scale": 1.0,
    }
    if negative:
        kwargs["negative_prompt"] = negative
    if kind == "pass2":
        denoise = float(job["denoise"])
        clean = pack_image(pipe, src, width, height, generator)
        expected = generation_seq(pipe, width, height)
        if clean.shape[1] != expected:
            raise RuntimeError(f"latent seq {clean.shape[1]} != {expected}")
        noised, raw_tail = noise_at_denoise(pipe, clean, width, height, steps, denoise, generator)
        kwargs["latents"] = noised
        kwargs["sigmas"] = raw_tail
        kwargs["num_inference_steps"] = len(raw_tail)
    else:
        kwargs["num_inference_steps"] = steps
    import diffusers.pipelines.qwenimage.pipeline_qwenimage_edit_plus as qpipe

    old_area = qpipe.VAE_IMAGE_SIZE
    qpipe.VAE_IMAGE_SIZE = width * height
    print(
        "render",
        kind,
        "scale",
        scale,
        "seed",
        seed,
        "frame",
        width,
        height,
        "vae_area",
        qpipe.VAE_IMAGE_SIZE,
        "fused",
        _fused_scale,
        flush=True,
    )
    started = time.perf_counter()
    try:
        out = pipe(**kwargs).images[0]
    except torch.cuda.OutOfMemoryError as exc:
        torch.cuda.empty_cache()
        raise RuntimeError(f"OOM {exc}") from exc
    finally:
        qpipe.VAE_IMAGE_SIZE = old_area
    seconds = round(time.perf_counter() - started, 2)
    per_step = round(seconds / max(1, kwargs["num_inference_steps"]), 2)
    print("mem_after_render", mem_line(), "step_seconds", per_step, flush=True)
    dest = Path(job["dest"])
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    return {
        "id": job["id"],
        "kind": kind,
        "scale": scale,
        "seed": seed,
        "denoise": job.get("denoise"),
        "seconds": seconds,
        "step_seconds": per_step,
        "steps": kwargs["num_inference_steps"],
        "dest": str(dest),
        "bytes": dest.stat().st_size,
        "size": list(out.size),
    }


def load_pipe():
    """8bit transformer on GPU. VAE and text encoder on CPU. Never a full BF16 load."""
    print("mem_before", mem_line(), flush=True)
    try:
        import bitsandbytes
        from diffusers import BitsAndBytesConfig, QwenImageEditPlusPipeline, QwenImageTransformer2DModel
    except Exception as exc:
        raise SystemExit(f"bitsandbytes import failed: {type(exc).__name__}: {exc}") from exc

    quant = BitsAndBytesConfig(load_in_8bit=True)
    print("quant bitsandbytes-8bit", bitsandbytes.__version__, flush=True)
    try:
        transformer = QwenImageTransformer2DModel.from_pretrained(
            "Qwen/Qwen-Image-Edit-2511",
            subfolder="transformer",
            quantization_config=quant,
            torch_dtype=torch.bfloat16,
            local_files_only=True,
            low_cpu_mem_usage=True,
        )
    except Exception as exc:
        raise SystemExit(f"no 8bit transformer load; refused full BF16: {type(exc).__name__}: {exc}") from exc
    print("mem_after_transformer", mem_line(), flush=True)
    pipe = QwenImageEditPlusPipeline.from_pretrained(
        "Qwen/Qwen-Image-Edit-2511",
        transformer=transformer,
        torch_dtype=torch.bfloat16,
        local_files_only=True,
        low_cpu_mem_usage=True,
    )
    pipe.vae.to("cpu")
    if hasattr(pipe.vae, "enable_tiling"):
        pipe.vae.enable_tiling()
    pipe.text_encoder.to("cpu")
    original_embed = pipe._get_qwen_prompt_embeds

    def embed_on_cpu(prompt=None, image=None, device=None, dtype=None):
        embeds, mask = original_embed(prompt, image, pipe.text_encoder.device, dtype)
        target = device or pipe._execution_device
        embeds = embeds.to(device=target)
        if mask is not None:
            mask = mask.to(device=target)
        return embeds, mask

    pipe._get_qwen_prompt_embeds = embed_on_cpu
    encode_vae = pipe._encode_vae_image
    vae_decode = pipe.vae.decode

    def _cpu_tensor(value):
        if torch.is_tensor(value):
            return value.detach().to(device="cpu", dtype=pipe.vae.dtype)
        return value

    def _to_exec(value):
        if torch.is_tensor(value):
            return value.to(device=pipe._execution_device)
        if isinstance(value, tuple):
            return tuple(_to_exec(item) for item in value)
        if isinstance(value, list):
            return [_to_exec(item) for item in value]
        sample = getattr(value, "sample", None)
        if torch.is_tensor(sample):
            value.sample = sample.to(device=pipe._execution_device)
        return value

    def encode_on_cpu(image, generator):
        print("vae_encode_cpu", tuple(image.shape), mem_line(), flush=True)
        latents = encode_vae(image=_cpu_tensor(image), generator=generator)
        print("vae_encode_done", tuple(latents.shape), mem_line(), flush=True)
        return latents.to(device=pipe._execution_device)

    def decode_on_cpu(*args, **kwargs):
        args = tuple(_cpu_tensor(arg) for arg in args)
        kwargs = {key: _cpu_tensor(value) for key, value in kwargs.items()}
        print("vae_decode_cpu", mem_line(), flush=True)
        decoded = vae_decode(*args, **kwargs)
        print("vae_decode_done", mem_line(), flush=True)
        return _to_exec(decoded)

    pipe._encode_vae_image = encode_on_cpu
    pipe.vae.decode = decode_on_cpu
    print("placement bitsandbytes-8bit vae=cpu", mem_line(), flush=True)
    pipe.load_lora_weights(str(LORA), adapter_name="mcnl")
    try:
        pipe.fuse_lora(lora_scale=1.0)
        pipe.unfuse_lora()
        print("fuse_ok", flush=True)
    except Exception as exc:
        print("fuse_later", type(exc).__name__, str(exc)[:240], flush=True)
    print("mem_after_lora", mem_line(), flush=True)
    return pipe


def main() -> None:
    print("loading", flush=True)
    pipe = load_pipe()
    expected = generation_seq(pipe, 896, 1200)
    print("ready pass2_shape_ok", expected, flush=True)
    while True:
        if STOP.exists() and not JOB.exists():
            print("stop", flush=True)
            break
        if not JOB.exists():
            time.sleep(1)
            continue
        raw = JOB.read_text(encoding="utf-8").strip()
        if not raw:
            time.sleep(0.2)
            continue
        try:
            job = json.loads(raw)
        except json.JSONDecodeError:
            time.sleep(0.2)
            continue
        JOB.unlink(missing_ok=True)
        try:
            payload = render(pipe, job)
        except Exception as exc:
            payload = {"id": job.get("id"), "error": f"{type(exc).__name__}: {exc}"}
            print("error", payload["error"], flush=True)
        DONE.write_text(json.dumps(payload), encoding="utf-8")
        print("wrote", payload.get("dest") or payload.get("error"), flush=True)


if __name__ == "__main__":
    main()
