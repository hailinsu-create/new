# Ambush Loop v0.6.x overhaul brief

Date: 2026-09-18  
Branch: `cursor/commandos-ambush-0641`  
From: v0.5.39 (west obs-ring courtyard offset shrink) + Look art-study crate  
Method: PaperRoute — brief → playable Engine slices → separate Look (headless Blender → GLB) → review frames, not vibes.

This is not a one-shot rewrite. 「全面」means sequenced, verifiable commits. RAID stays.

## Product north star

A first-session player on a phone can run a **Commandos 2 night raid** in the yard: pick one soldier, walk the west file, open a crate, wrap a sentry, form the trio, pull the alarm, watch the auto ambush. The courtyard must stay readable. The squad must read as a file, not three stamps on a postage-stamp map.

**Closest reference (one):** Commandos 2 — *Night Raid / Silent Assassin* courtyard: small soldiers, true-range observation, crates you can name from silhouette, yellow sentry cones, no RTS after the alarm.

**Rough reference frames (already in-repo, point at these):**

1. `ambush_loop/docs/eval_touch_ux/01_scout_touch_simple.png` — first SCOUT. Cyan obs disc soaps the hatched courtyard. Bodies readable at 1.0. Compact 5-key holds.
2. `ambush_loop/docs/eval_touch_ux/08_west_combo_follow.png` / `08f_west_rear.png` — west trio dest (7,12)/(6,6)/(5,16) span 6. File is a line of people, not a clump; the 280px disc still paints the court.
3. `ambush_loop/ArtSource/yard_crate_turnaround.png` — Look study. Shaded **side** is a flat pine slab (no plank seams). Clay **front** stencil is a raised plus, not stamped lettering.

## What stays (RAID contract — do not touch)

- `SCOUT → ALERT → SWEEP`
- ALERT lock-move (no free RTS during watch)
- Auto fire + auto grenades
- 10-gun kit (do not restore 28-weapon kit)
- Desktop rail + mobile compact 5-key (`匍匐`/`背包` stacked, `↺`/`↻`, `需枪`)
- West-follow dest world clamps onto walkable floor (detour ≤ 6)
- Follow camera floor ≥ 0.85; keep ~1.0 pan/crop (no postage-stamp west zoom)
- Body / obs **scale** ~1.0 (no body 0.16)
- No GPT / Meshy without a real `MESHY_API_KEY` (scaffold only)

## What changes (v0.6.x)

| Stream | Change | Why |
| --- | --- | --- |
| Engine | Obs **fill** fades and clips at 1.0 scale. `kit_range` gameplay stays 280/220/205. | Courtyard readable; soap is fill, not scale. |
| Engine | West trio **cohesion feel** without zooming out. Dest span 6 is the contract until a dest rethink ships with new smoke. | File reads as one squad on `08f`. |
| Engine | First-session verbs 跟 / 绕背 / 开匣 / 需枪 from yard scrape. | Thumb hits the chip/crate/CTA, not the soap. |
| Look | Headless Blender crate: real board seams + stamped lettering → GLB + contact sheet. | Frame defects on `yard_crate_turnaround.png`. |
| Look | At least one Blender prop in the **playable** yard (not ArtSource-only). | Look is in-game. |
| Look | Optional second prop (ammo box / rifle case), own commit. | Silhouette next to the crate. |

## Engine pillars vs Look pillars

**Engine (Godot scripts, one mechanic per commit):**

- Observation ring **visual** ≠ kit range. Scale stays 1.0. Fill may fade/clip; detection does not shrink.
- West follow: dest cells, detour ≤ 6, pan/crop ~1.0. Cohesion is file/ghost/slot extra, or a dest rethink **with** smoke.
- Touch verbs are hotspots + compact bar. Do not rebuild RAID as lock-watch RTS.
- Smoke + force-touch dump are the net. Point at a frame.

**Look (Blender Python, never mixed with Engine physics in the same commit):**

- `blender-headless --python ambush_loop/ArtSource/build_<asset>.py`
- Deterministic GLB next to the script + clay/shaded front/side/rear sheet.
- Ambush Loop is **2D Godot**. GLB is the source of truth; the playable yard gets a bake (top / 3/4 sprite) from that same script. Do not hand-edit a unique `.blend`.
- Art study first; then import. Do not merge an ugly sheet into the yard.
- Faced characters: Meshy only after `MESHY_API_KEY`. Until then, keep polygon silhouettes.

## First 3 Engine slices (ranked)

1. **Obs ring fill fade/clip at 1.0** — LOS-clip fill + ring against blocked cells; inner fill shorter/fainter than the true-range outline; fill does not inherit the courtyard offset. Body 1.0, zoom 1.0, `kit_range_px` unchanged. Prove: dump `08_west_combo_follow` courtyard floor reads; smoke fill does not cover cell (19,10); scout `kit_range` still 280.
2. **West trio cohesion feel** — formation file through dests; tighten on-ring extra if smoke allows; **do not** drop zoom below 0.85; dest (6,6)/(5,16) span 6 stays until a dest commit rewrites leftover 0534–0539 asserts.
3. **First-session pits (跟 / 绕背 / 开匣 / 需枪)** — larger 跟 chip hit; 开匣 sits above the crate, not in the soap to the left; 绕背 thumb target; `需枪` CTA contract stays (smoke `SMOKE_OK_ALARM_CTA`).

Optional Engine: night-grade contrast so the hatched court still reads under a faint ring. Presentation only.

## First 3 Look slices (ranked)

1. **Yard crate defect pass** — plank seams visible in **shaded side**; stencil is painted/stamped letters, not a raised plus. Same `build_yard_crate.py`. Contact sheet before yard import.
2. **Wire crate into playable yard** — GLB imported; 2D sprite bake from the same script on the courtyard crate island (~19,10). Dump shows the prop, not only ArtSource.
3. **Second prop** — ammo box or rifle-case silhouette, own script / own commit.

## Review gate

After every Engine slice: slim smoke + force-touch dump. Name the frame.

After every Look mesh change: clay + shaded turnaround. Name the panel.

Do not mix throw-physics (follow dest / cone) with house-silhouette (crate boards) in one commit.

## Version

Ship **v0.6.0** when this brief + Engine ring/cohesion + Look pipeline (crate in the yard) are green. Intermediate Engine-only slices may be 0.5.40+.
