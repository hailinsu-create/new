# ArtSource — Look stream (not playable yet)

PaperRoute / builtbysketch loop for Ambush Loop. **Engine stays in Godot scripts.** This folder is the reproducible prop pipeline.

```bash
blender-headless --python ambush_loop/ArtSource/build_yard_crate.py
gltf-transform inspect ambush_loop/ArtSource/yard_crate.glb
```

Contract: each `build_*.py` is deterministic, no GUI, writes a GLB next to the script plus a clay/shaded front-side-rear contact sheet. Do not check in a unique unscripted `.blend` as the source of truth.

`yard_crate` is an art-study WWII supply crate (mailbox-scale, wet pine + iron straps). It is **not** imported into the playable courtyard until a later Look prompt names a frame and a defect.

Review (point at `yard_crate_turnaround.png`):
- **Shaded side (bottom-middle):** vertical side slats with gaps — not a flat pine slab.
- **Clay front (top-left):** flush **AMMO** stencil bars, not a raised plus.
- Also writes `yard_crate_iso.png` / `yard_crate_top.png` for the 2D yard (Look import is a later commit).

Second prop: `build_ammo_can.py` → `ammo_can.glb` + turnaround + iso.

Third prop: `build_gun_case.py` → `gun_case.glb` + turnaround + iso. Long rifle crate; shaded **front** is flush **RIFLE** stencil. Iso is now in `art/look/gun_case_iso.png` on the courtyard island west lip.

Fourth prop (art study): `build_sandbag.py` → `sandbag.glb` + turnaround + iso. Three-bag stack. Shaded **front**: stacked canvas bricks + neck ties (sag is a later defect pass).

Fifth prop (art study): `build_lamp_post.py` → `lamp_post.glb` + turnaround + iso. Iron stem + caged sodium lamp. Iso reads; contact sheet is cramped on a tall prop (later camera pass).

Sixth prop (art study): `build_fence_section.py` → `fence_section.glb` + turnaround + iso. Two posts + three rails.

Faced characters: Meshy only after `MESHY_API_KEY` exists. Scaffold: `meshy/README.md`. Skip until then.
