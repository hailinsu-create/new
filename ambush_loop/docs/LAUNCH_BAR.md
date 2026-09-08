# Ambush Loop — launch bar vs deferred

Target: **indie Commandos-lite / Into-the-Breach-adjacent Steam early access average** — shippable loop, readable UI, onboarding, settings, menu, exportable project. Not an AAA Commandos remake.

Hard rules that must stay true: alarm freezes plan; no mid-fight micro; authored routes; escape/wipe fail; intel+plan across loops.

## Launch bar (this cut)

| # | Criterion | Status |
|---|-----------|--------|
| A1 | `scenes/title.tscn` + `scripts/title.gd` is `run/main_scene` | Done |
| A2 | Brand-first title: **AMBUSH LOOP**, tagline 战前埋伏 · 锁死计划 · 时间穿梭, CTAs 开始行动 / 继续进度 / 操作说明 / 退出 | Done |
| A3 | Night-ops asphalt/olive (no purple gradient, no cream+serif terracotta); grid + wordmark fade, CTA pulse, route-line drift | Done |
| A4 | 继续进度 loads `user://ambush_loop.cfg` if present; else disabled | Done |
| A5 | 开始行动 → briefing for current/first incomplete level → `main.tscn` via `GameSettings.pending_level_id` | Done |
| B6 | Autoload `GameSettings`: mute, master volume 0–1, seen_tutorial; `user://ambush_loop_settings.cfg` | Done |
| B7 | Title + in-game Esc pause/settings (mute, volume, 返回标题, 重新部署 SETUP-only). M toggles mute | Done |
| B8 | Progress save + settings; campaign complete → credits → title | Done |
| C9 | First yard SETUP: 3-step modal; page 1 cannot be skipped via dimmer; auto-mark seen on dismiss | Done |
| C10 | Existing `tut_label` kept as secondary tip | Done |
| D11 | Left operator cards: name/role, ammo, HP, fire mode, slot or 未部署; click select; highlight | Done |
| D12 | Cooler night floor, warmer walls, escape mouth glow; route labels kept | Done |
| D13 | Result panels stay docked off the escape mouth; campaign win → credits | Done |
| E14 | `export_presets.cfg` Linux + Windows Desktop (Godot 4.7), embed PCK | Done |
| E15 | README: Godot 4.7.2, run, export, controls, content | Done |
| F17 | Smoke still `change_scene_to_file(main.tscn)`, `SMOKE_SLICE_COMPLETE` exit 0 | Done |
| F18 | Smoke asserts title scene + GameSettings autoload | Done |

## Still below Steam-average (deferred)

These are the honest blockers to a *true* similar-game store page, not this launch bar:

| Item | Why it is out |
|------|----------------|
| Art / animation / isometric Commandos read | Geometry + labels; no sprite pipeline, no character anim |
| Music / mix / VO | Procedural beeps only; Dummy driver in headless |
| Fog of war / hidden enemies | Scout ring is SETUP-only on purpose |
| Human playtest + balance pass | Smoke is the regression gate |
| Steam page, achievements, cloud saves, controller | Export presets exist; no store integration |
| Localization beyond ZH UI + EN README | Copy is Chinese-first, not a loc pipeline |
| Mid-mission Commandos verbs | Climb, knife, distract, vehicles, multi-floor — out of design |
| CI export artifacts | Templates + signing not in this environment |
| More than 3 authored missions | Yard / warehouse / pump only |

## Smoke

```bash
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

Must print `SMOKE_SLICE_COMPLETE` and `SMOKE_OK_LAUNCH_BAR` and exit 0.
