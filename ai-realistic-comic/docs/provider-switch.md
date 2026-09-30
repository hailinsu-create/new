# Image provider switch (fal → ComfyUI / AutoDL)

Character cards, `episode.yaml`, reference PNGs, and `comic assemble` stay the same.
Only the image backend changes.

## Today

```bash
IMAGE_PROVIDER=fal
FAL_KEY=...
comic doctor
comic generate demo-spider-wukong --force
```

## Later (AutoDL + ComfyUI)

1. Rent RTX 4090, start ComfyUI with `--listen 0.0.0.0 --port 8188`.
2. Export an API-format workflow that takes prompt + optional reference image.
3. Point env at it:

```bash
IMAGE_PROVIDER=comfy
COMFY_API_URL=http://127.0.0.1:8188   # or AutoDL mapped URL
COMFY_WORKFLOW_PATH=workflows/pulid_api.json
comic doctor
comic generate demo-spider-wukong --force
```

Reuse the same `characters/*_ref.png` files as PuLID / IP-Adapter inputs.

## Status

| Provider | Status |
|----------|--------|
| `mock` | Ready (`COMIC_MOCK=1`) |
| `fal` | Ready (Flux Dev + PuLID) |
| `comfy` | Scaffolded — server probe + clear next-step error; full `/prompt` queue TBD |
