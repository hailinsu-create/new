# Ambush Loop — launch bar vs deferred

Target: **indie Commandos-lite / Into-the-Breach-adjacent Steam early access average (~7/10)**. Shippable loop, readable UI, onboarding, settings, mission list, quiet bed + SFX, exportable project. Not an AAA Commandos remake.

Hard rules that must stay true: alarm freezes plan; no mid-fight micro; authored routes; escape/wipe fail; intel+plan across loops.

## Score (this cut): **7.5 / 10**

Phase A presentation work is in (night floor grain, distinct friend/foe silhouettes, SETUP vs WATCHING route dim, Music/SFX sliders, per-level tutorials, 终局摘要). Score is **not 8** yet: no human playtest log of “typical fail → fix” on all three yards, and the art is still geometry-plus-labels. Treat 7.5 as honest progress toward the 8/10 presentation bar.

Average similar-game launch: title that lists missions, keyboard legend, quit confirm, debrief after a win, specialist silhouettes you can read at a glance, and *some* music bed even if it is a quiet drone. That is the bar this cut aims at.

| Band | Why |
|------|-----|
| **7** | Mission select + lock/clear from save, looping bed + SFX bus, win debrief, role glyphs, facing chevrons, full key table, quit confirm. Matches a small tactics Steam page that is honest about scope. |
| **7.5** | Phase A code in: warmer walls / grainy night floor, enemy diamond vs friend triangle + hit flash, WATCHING route dim, Music/SFX mix, warehouse/pump tutorial pages, Chinese 终局摘要. Not playtested as a set. |
| Not 8+ | No FOW, no human balance record, still no sprite pipeline or VO. Fourth authored yard (`railcut`) is in; 8+ still wants playtest + stronger art. |

## Launch bar (this cut)

| # | Criterion | Status |
|---|-----------|--------|
| A1 | `scenes/title.tscn` + `scripts/title.gd` is `run/main_scene` | Done |
| A2 | Brand-first title: **AMBUSH LOOP**, tagline 战前埋伏 · 锁死计划 · 时间穿梭, CTAs 开始行动 / 继续进度 / 操作说明 / 退出 | Done |
| A3 | Night-ops asphalt/olive (no purple gradient, no cream+serif terracotta); grid + wordmark fade, CTA pulse, route-line drift | Done |
| A4 | 继续进度 loads `user://ambush_loop.cfg` if present; else disabled | Done |
| A5 | 开始行动 → **mission list** (4 levels, lock / 可出击 / 首通 from `ambush_loop.cfg`) → briefing → `main.tscn`. Sequential unlock; cannot skip locked | Done |
| B6 | Autoload `GameSettings`: mute, **music_volume / sfx_volume** 0–1 (migrates old master), per-level `seen_*` tutorials with legacy `seen_tutorial` bool | Done |
| B7 | In-game Esc pause/settings (mute, Music/SFX sliders, 返回标题, 重新部署 SETUP-only). M toggles mute. Title Esc / 退出 → quit confirm (设置 still reachable) | Done |
| B8 | Progress save + settings; campaign complete → credits → title. Win records `cleared` and unlocks the next id | Done |
| C9 | First visit per level: yard 3-step; warehouse F/G/barrel; pump B/flank; railcut dual-corridor delay. Page 1 cannot be skipped via dimmer; auto-mark seen on dismiss | Done |
| C10 | Existing `tut_label` kept as secondary tip | Done |
| D11 | Left operator cards: name/role **glyph**, ammo, HP, fire mode, slot or 未部署; click select; highlight; matching glyph on the map | Done |
| D12 | Cooler night floor with grain/grid, heavier umber walls, lime-gold escape mouth (not purple); friend triangle vs enemy diamond; crate/sandbag pads; protect arcs above floor | Done |
| D13 | Fail panels stay docked off the escape mouth; **win debrief** (loops used, 终局摘要, last 5 events, 下一关 / 返回标题) before advance; campaign win → credits | Done |
| E14 | `export_presets.cfg` Linux + Windows Desktop (Godot 4.7), embed PCK | Done |
| E15 | README: Godot 4.7.2, run, export, controls, content | Done |
| F17 | Smoke still `change_scene_to_file(main.tscn)`, `SMOKE_SLICE_COMPLETE` exit 0 | Done |
| F18 | Smoke asserts title scene + GameSettings autoload | Done |
| G19 | Autoload `AudioDirector`: looping WAV bed on **Music**, pooled WAV SFX on **SFX**; Music/SFX sliders; mute kills both; quieter bed in WATCHING; streams reused / nulled on exit | Done |
| G20 | Enemy diamond rotates to move direction; 1–2px camera punch on escape/win; hit-flash modulate on shot | Done |
| G21 | SETUP keeps full authored routes + killzone; WATCHING dims route ink; ghosts label `第N世 · Xs · reason` | Done |

## Still below 8+ (deferred)

These are the honest blockers to a *strong* similar-game store page:

| Item | Why it is out |
|------|----------------|
| Art / animation / isometric Commandos read | Geometry + labels + tiny glyphs; no sprite pipeline |
| Real music mix / VO | Quiet procedural drone + beeps; Dummy driver in headless |
| Fog of war / hidden enemies | Scout ring is SETUP-only on purpose |
| Human playtest + balance pass | Smoke is the regression gate; Phase A teaching copy only |
| Steam page, achievements, cloud saves, controller | Export presets exist; no store integration |
| Localization beyond ZH UI + EN README | Copy is Chinese-first, not a loc pipeline |
| Mid-mission Commandos verbs | Climb, knife, distract, vehicles, multi-floor — out of design |
| CI export artifacts | Templates + signing not in this environment |
| Fifth authored mission / `.tres` validator | Four yards: yard / warehouse / pump / **railcut** (信号楼：双走廊延迟). B2/B4 still open |

## Smoke

```bash
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

Must print `SMOKE_SLICE_COMPLETE` and `SMOKE_OK_LAUNCH_BAR` and exit 0.

Content note: mission list is **4** authored yards. `railcut` (信号楼：双走廊延迟) unlocks after pump clear; smoke runs a documented reference win (slots 1,4,5 facings 270/270/180) after the pump locked branch.
