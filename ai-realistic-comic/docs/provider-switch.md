# Image provider switch (fal ↔ AutoDL local ↔ ComfyUI)

Character cards, still yaml, reference PNGs stay the same. Only the image backend changes.

## fal (default, approved quality)

```bash
IMAGE_PROVIDER=fal
FAL_KEY=...
comic still-library hades-persephone-throne
```

## AutoDL local Diffusers (current cost-cut path)

```bash
IMAGE_PROVIDER=local
LOCAL_STILL_MODEL=qwen-image-edit-2511
COMIC_QA=0
bash autodl/bootstrap.sh
bash autodl/run_smoke.sh
```

See [autodl.md](autodl.md). One-shot from your laptop/CI: `comic autodl run` (needs `AUTODL_TOKEN`).

## ComfyUI (optional later)

```bash
IMAGE_PROVIDER=comfy
COMFY_API_URL=http://127.0.0.1:8188
COMFY_WORKFLOW_PATH=workflows/edit_api.json
```

`comfy` is still a scaffold (server probe only). Prefer `local` on AutoDL for now.

## Status

| Provider | Status |
|----------|--------|
| `mock` | Ready (`COMIC_MOCK=1`) |
| `fal` | Ready — nano-banana-pro stills approved |
| `local` | Ready — Diffusers on rented GPU (AutoDL) |
| `comfy` | Scaffolded — full `/prompt` queue TBD |
