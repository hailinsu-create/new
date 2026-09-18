# ArtSource — Look stream (not playable yet)

PaperRoute / builtbysketch loop for Ambush Loop. **Engine stays in Godot scripts.** This folder is the reproducible prop pipeline.

```bash
blender-headless --python ambush_loop/ArtSource/build_yard_crate.py
gltf-transform inspect ambush_loop/ArtSource/yard_crate.glb
```

Contract: each `build_*.py` is deterministic, no GUI, writes a GLB next to the script plus a clay/shaded front-side-rear contact sheet. Do not check in a unique unscripted `.blend` as the source of truth.

`yard_crate` is an art-study WWII supply crate (mailbox-scale, wet pine + iron straps). It is **not** imported into the playable courtyard until a later Look prompt names a frame and a defect.

Review (point at `yard_crate_turnaround.png`):
- **Shaded side (bottom-middle):** no plank seams; the side is a flat pine slab.
- **Clay front (top-left):** the stencil is a raised plus, not a painted marking.

Faced characters: Meshy only after `MESHY_API_KEY` exists. Skip until then.
