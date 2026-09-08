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
- **Procedural audio:** short pooled WAV beeps on the **SFX** bus; looping generator drone on **Music**. Mute with **M** (Master, both buses). Volume slider is master. No external audio assets.
- **Title / settings / onboarding:** night-ops title, **mission select** (lock / 首通), briefing, Esc quit confirm on title, in-game Esc settings, first-run 3-step yard tutorial, left operator cards with role glyphs, win debrief, campaign credits.
- **Export presets:** Linux + Windows desktop in `export_presets.cfg` (manual export; see README).

## Deferred (not this slice)

| Item | Why it is out |
|------|----------------|
| True fog of war / enemy-hidden-until-spotted | Would rewrite combat info; scout ring is setup-only on purpose |
| Isometric / pixel Commandos art | Geometry + labels only; no art pipeline |
| Steam/itch store page + CI export artifacts | Presets ship; builds are local (export templates required) |
| Human playtest pass | Smoke is the regression gate, not a player report |
| Mid-mission Commandos verbs | Climb, knife, distract, vehicles, multi-floor — explicitly out of design |
| Real audio mix / VO / soundtrack | Quiet drone + beeps; Dummy driver in headless |

Launch-bar checklist: `docs/LAUNCH_BAR.md`.

## Smoke gates that must stay green

`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd` prints `SMOKE_SLICE_COMPLETE` and `SMOKE_OK_LAUNCH_BAR` and exits 0.

Includes: title scene + GameSettings + AudioDirector autoloads; mission list lock; yard escape → restore → 1×/2× fingerprint match → reference win + debrief; warehouse barrel present; pump open + locked alternate route; roles with distinct ranges; LOS clip.
