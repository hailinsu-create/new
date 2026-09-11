# Ambush Loop — Commandos raid completeness

Honest checklist against a Commandos-style night raid. 2D top-down Godot slice,
not a Commandos clone. Full contract: `docs/COMMANDOS_RAID.md`.

## Done in this slice

- **Scout then alarm:** SETUP (walk/loot/plant) → Space starts a combat wave. Not a frozen watch-only plan.
- **Sweep between waves:** clear a wave → walk/vacuum loot → next alarm or extract.
- **Kits from the map:** knife start; rifle/MG/scout/pistol/shotgun/ammo/mine/grenade/decoy crates.
- **Commandos verbs kept small:** click-to-move, cover pads, mines, grenades, decoys. No RTS box-select.
- **Plan then lock (legacy, replaced):** old SETUP lock-watch is gone as the core loop.
- **Specialist kits:** rifle (filler), MG (wide/fast/short), scout (long/narrow/scarce).
- **Cover protect arcs:** cyan fan; only attacks from that facing get 60% mitigation.
- **LOS-clipped fire cones:** yellow, wall-cut; authored routes only (no free pathing).
- **Scout lookout ring:** faint 「观察环」 at scout range during SETUP only. Prep readability — does **not** reveal hidden enemies in combat (no FOW rewrite).
- **Intel + last plan:** escape/wipe/abort fail the loop; ghosts + restored plan persist. Restore flashes slot/facing summary; later edits flash a diff vs last plan.
- **Abort (X):** intentional fail, keeps intel up to now.
- **Read-only replay:** snapshot scrub, click-to-focus events. Does not re-simulate.
- **Authored toys:** tripwire (1), ammo pack, door→alternate route, warehouse proximity barrel (sim-tick only).
- **Watch-only speed:** 1× / 2× must match tick + event fingerprint (smoke).
- **Procedural audio:** short pooled WAV beeps on the **SFX** bus; looping WAV drone on **Music**. Mute with **M** (Master, both buses). Pause overlay has Music / SFX sliders. WATCHING ducks the bed slightly. No `AudioStreamGenerator`. No external audio assets.
- **Title / settings / onboarding:** night-ops title, **mission select** (lock / 首通), briefing with night index, **战役档案** journal (封印邮戳), Esc quit confirm on title, in-game Esc settings, first-run 3-step yard tutorial, left operator cards with role glyphs, win debrief + chain strip, **night-to-night letterbox handoff**, campaign credits recap.
- **Second-layer trap path:** SETUP dashed arrow along the authored trap route; fail dossier names a miss and paints the leaked path until continue.
- **Export presets:** Linux + Windows desktop + **Android APK** (`com.ambushloop.game`, arm64, minSdk 24). Touch HUD + Android back. Sideload APK still needs local export templates (see `docs/ANDROID.md`).

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
Post-launch roadmap: `docs/开发规划.md`（v3：安卓 APK 首发）。

## Smoke gates that must stay green

`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd` prints `SMOKE_SLICE_COMPLETE`, `SMOKE_OK_RAID_LOOP`, and `SMOKE_OK_LAUNCH_BAR` and exits 0.

Includes: title + settings + audio; 6-night lock; raid contract (knife start, stashes, click-to-move); yard knife-leak + pickup + 2-wave reference extract; abort/wipe fail; warehouse/pump/railcut/depot/radio multi-wave reference raids; geometry/roles/LOS/feel gates.
