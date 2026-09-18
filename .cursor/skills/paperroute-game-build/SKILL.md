---
name: paperroute-game-build
description: Build a playable game the PaperRoute / builtbysketch way — mechanics first, then separate engine vs look streams, headless Blender Python for reproducible props, Meshy for faced characters, review renders every change. Use when the user mentions PaperRoute, builtbysketch, Astra game pipeline, one-shot vs full game, Blender Python GLB, Meshy characters, or asks to polish a game beyond a demo.
---

# PaperRoute game-build loop

Source method: Emm Tee (@builtbysketch) PaperRoute run book. This repo is Godot (Ambush Loop), not Three.js. Prefer Godot runtime; keep the asset loop.

## Order (do not skip)

1. Rewrite the brief in the user's words. One closest reference + 2–3 rough images. Mechanics only.
2. Ship a playable slice with tests. One prompt → play/look → one commit.
3. Split streams. Never mix throw-physics and house-silhouette in the same conversation.
4. Props: headless Blender Python that builds mesh, splits materials, exports GLB. Art-study board before it touches the playable world.
5. Faced characters: concept image → Meshy → Blender reduce/rig/fit. Stop sculpting faces in the LLM.
6. Review renders every checkpoint: front/side/rear + clay; runtime poses. Point at a frame.
7. Flourishes (weather, smash cam, end-of-route toy) on their own branch/worktree; merge after they play.

## Engine stream

- One mechanic per prompt. Play it in Godot (or the live URL) before the next prompt.
- Write tests or a smoke dump as you go so art changes have a net.
- Mobile/touch is a first-class checkpoint, not a later port.

## Look stream (Blender, not MCP)

PaperRoute did **not** drive Blender through MCP. Default:

```bash
blender-headless --python ArtSource/build_<asset>.py
```

Script contract: deterministic, no GUI, write GLB next to the script, also write a contact-sheet PNG (front/side/rear, clay + shaded). Import GLB into Godot; do not leave unique unscripted `.blend` as the source of truth.

MCP `blender` is optional for inspecting a live session on `localhost:9876`. If Blender is not running, do not wait on MCP — write Python and run headless.

## Characters

1. Generate / pick concept images (no trendy style-word dump; describe materials, era, silhouette).
2. `meshy make ./concept.png -o ArtSource/meshy/<name>/` **after** `MESHY_API_KEY` is set. Dry-run first: `meshy make ... --dry-run`.
3. Blender: decimate to game budget, keep face/hair/seams, fix garment poke-through, fit to existing rig/prop, export GLB.
4. Same pipeline for character two; it should cost a fraction of character one.

## Review loop

After every mesh or material change, save:

- clay turnaround
- shaded turnaround
- in-engine screenshot of the actual pose (steer/throw/idle/damage)

The next prompt names the frame and the defect ("cap does not cover hair in rear clay"). Do not accept "looks better" without images.

## Tools on this machine

- `blender`, `blender-headless` — Blender 5.2.2 LTS
- `blender-mcp-official` — official Lab MCP (needs Blender + addon on :9876)
- `meshy` / `meshy-mcp-stdio` — needs `MESHY_API_KEY` or `~/.config/meshy/api_key`
- `gltf-transform` — inspect/optimize GLB
- `godot` / `godot-mcp-stdio` — Godot 4.7.2 at `/usr/local/bin/godot`

Config: `.cursor/mcp.json`, `.grok/config.toml`. Method notes: `.cursor/docs/SKETCH_PAPERROUTE.md`.

## Ambush Loop adaptations (Godot 2D, not Three.js)

Overhaul brief: `.cursor/docs/AMBUSH_OVERHAUL_BRIEF.md`. RAID contract (`SCOUT → ALERT → SWEEP`, ALERT lock-move, auto fire/nades, 10-gun kit, compact 5-key) is Engine law — do not one-shot rewrite it.

- **Engine vs Look:** west zoom / body scale / obs **fill** are three different knobs. Never shrink body below ~1.0 or west zoom below 0.85 to hide a soapy disc. `kit_range_px` is gameplay; obs fill may fade/clip.
- **Look into a 2D yard:** `blender-headless --python ArtSource/build_<asset>.py` still writes GLB + turnaround. The playable scene is Node2D — also bake a top/3/4 PNG from the same script and sprite it in. GLB stays the source of truth. Do not wait on Blender MCP.
- **No Meshy** until `MESHY_API_KEY` exists. Keep polygon operator silhouettes.
- **Net:** `godot --headless --path ambush_loop -s res://scripts/smoke_test.gd` and `godot --path ambush_loop -s res://scripts/eval_dump_touch_hud.gd`. Point at `docs/eval_touch_ux/*.png` or `ArtSource/*_turnaround.png`.
