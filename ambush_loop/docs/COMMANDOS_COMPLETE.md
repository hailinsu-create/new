# Ambush Loop — Commandos-prep completeness

Honest checklist against a Commandos-style ambush-prep fantasy. This is a 2D
top-down Godot vertical slice, not a Commandos clone.

## Done in this slice

- **Plan then lock:** SETUP → Space alarm freezes layout / facing / fire mode / door / tools. No mid-fight micro.
- **Specialist kits:** rifle (filler), MG (wide/fast/short), scout (long/narrow/scarce).
- **Cover protect arcs:** cyan fan; only attacks from that facing get 60% mitigation.
- **LOS-clipped fire cones:** yellow, wall-cut; authored routes only (no free pathing).
- **Scout lookout ring:** faint 「观察环」 at scout range during SETUP only. Prep readability — does **not** reveal hidden enemies in combat (no FOW rewrite).
- **Intel + last plan:** escape/wipe/abort fail the loop; ghosts + restored plan persist. Restore flashes slot/facing summary; later edits flash a diff vs last plan.
- **Abort (X):** intentional fail, keeps intel up to now.
- **Read-only replay:** snapshot scrub, click-to-focus events. Does not re-simulate.
- **Authored toys:** tripwire (1), ammo pack, door→alternate route, warehouse proximity barrel (sim-tick only).
- **Watch-only speed:** 1× / 2× must match tick + event fingerprint (smoke).
- **Procedural SFX:** short in-code WAV beeps (alarm, first fire, first return fire, empty, loot, op death, escape, win). Mute with **M**. No external audio assets.

## Deferred (not this slice)

| Item | Why it is out |
|------|----------------|
| True fog of war / enemy-hidden-until-spotted | Would rewrite combat info; scout ring is setup-only on purpose |
| Isometric / pixel Commandos art | Geometry + labels only; no art pipeline |
| Full campaign / briefing / map select | Three authored missions + local progress cfg |
| Export package (itch/Steam build) | Dev `godot --path` run; no preset/CI export |
| Human playtest pass | Smoke is the regression gate, not a player report |
| Mid-mission Commandos verbs | Climb, knife, distract, vehicles, multi-floor — explicitly out of design |
| Real audio mix / VO / music | Beeps only; Dummy driver in headless |

## Smoke gates that must stay green

`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd` prints `SMOKE_SLICE_COMPLETE` and exits 0.

Includes: yard escape → restore → 1×/2× fingerprint match → reference win; warehouse barrel present; pump open + locked alternate route; roles with distinct ranges; LOS clip.
