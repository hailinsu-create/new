# Ambush Loop

Godot 4.7.2 vertical slice — Commandos-style ambush prep + time-loop intel.

Blueprint: `docs/Ambush_Loop_开发蓝图.md`  
Launch criteria: `docs/LAUNCH_BAR.md`  
Completeness: `docs/COMMANDOS_COMPLETE.md`  
Roadmap: `docs/开发规划.md`

## Install Godot 4.7.2

1. Download **Godot 4.7.2** (standard, not .NET) from https://godotengine.org/download
2. Unpack so `godot` is on your `PATH`, or use the full binary path below.

This repo was last run against `4.7.2.stable`.

## Run

From the repository root:

```bash
godot --path ambush_loop
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

The editor **Main Scene** is `scenes/title.tscn`. Smoke bypasses the title and loads `scenes/main.tscn` directly; it must print `SMOKE_SLICE_COMPLETE` and exit 0.

Reference wins: yard slots 1,2,5 facings 90/180/180; warehouse 1,3,5; pump 1,4,5 (open and locked door).

## Export (Linux + Windows)

Presets live in `ambush_loop/export_presets.cfg` (Linux Desktop, Windows Desktop, embed PCK, x86_64). CI does **not** build them; export locally.

1. Install Godot **export templates** matching 4.7.2: Editor → Manage Export Templates → Download.
2. Open the project: `godot --editor --path ambush_loop`
3. Project → Export.
4. **Linux Desktop** → Export Project → `build/linux/AmbushLoop.x86_64`
5. **Windows Desktop** → Export Project → `build/windows/AmbushLoop.exe`

`build/` is gitignored. You do not need export templates to *play* from the editor.

## Controls

| Key / UI | Action |
|----------|--------|
| Title | 开始行动 → 任务列表（锁定/可出击/首通）→ 简报 / 继续进度 / 操作说明（全键表） / 退出（确认） |
| Esc | 标题：退出确认（可进设置）；战场：暂停 / 设置（静音、音乐/音效、返回标题、布置期重新部署） |
| 1 / 2 / 3 or left operator cards | Select 步枪手 / 机枪手 / 侦察兵 |
| LMB cover | Deploy selected operator (cyan arc = cover protect direction) |
| Hover cover | Preview that slot's protect arc |
| A/D or RMB | Facing (fire cone is LOS-clipped by walls) |
| F | Fire mode (见敌即打 / 入伏再打) |
| G | Assign ammo pack (levels 2–3, one operator) |
| B | Toggle door lock (level 3; switches flank to authored alternate route) |
| Tab | 绊索 tool (max 1, on route segments only) |
| Space | Sound alarm (freezes plan) / pause while watching / exit replay |
| P | Pause during watch |
| + / − or speed button | 1× / 2× watch speed (viewing only) |
| X or 中止尝试 | Abort current attempt; keep intel up to now (counts as fail) |
| 时间轴复盘 | Read-only snapshot scrub (←/→ or slider). Click an event log line to seek/highlight that actor. Does not re-simulate. Space restores the last plan. |
| M or 音效 button | Mute / unmute (Music + SFX). Esc settings: separate Music / SFX sliders |
| Clear btn | Clear deploy (keep intel + tripwires) |
| R | Clear memory and restart |

Alarm locks layout, facing, fire modes, door, and tools. Pause/speed/replay only change viewing. Escape **or** squad wipe fails the loop; abort is an intentional fail that still stores intel. On escape the exit cell flashes and the result panel stays docked so the mouth stays visible. After fail continue, the last plan restores with a slot/facing summary; further edits flash a diff vs that plan. Cross-loop keeps intel ghosts + last plan only.

First visit to each mission shows a short tutorial (yard 3 pages; warehouse F/G/barrel; pump door/flank). Page 1 cannot be skipped by clicking the dimmer. The bottom `tut_label` remains as a secondary tip.

## Content

| Piece | What ships |
|-------|------------|
| Title | Wordmark, Chinese tagline, start → mission list → briefing, continue, full key table, quit confirm |
| Settings | Autoload `GameSettings`: mute, Music/SFX volumes, per-level tutorials (`user://ambush_loop_settings.cfg`) |
| Progress | `user://ambush_loop.cfg` current level + `cleared`; campaign complete → credits → title |
| Roles | 步枪手 / 机枪手 / 侦察兵 kits, left-rail HP/ammo/mode/slot cards + role glyphs on card and map |
| Levels | 院子, 仓道 (ammo pack + barrel), 泵站 (door → alternate route) |
| Toys | Tripwire (1, lime pegs), killzone preview, scout observation ring (SETUP only) |
| Loop | Alarm freezes plan; authored routes; escape/wipe fail; intel + last plan persist; win debrief before 下一关 |
| Audio | Autoload `AudioDirector`: quiet looping drone (Music) + pooled SFX beeps (SFX); M mute; Music/SFX sliders; quieter bed while watching |
| Export | Linux + Windows desktop presets (manual) |

## Roles

| Role | Kit |
|------|-----|
| 步枪手 | Balanced cone, 7 rounds — filler / sustain |
| 机枪手 | Wider cone, faster fire, shorter reach, hungrier ammo; more exposed from the flank |
| 侦察兵 | Long narrow overwatch, few heavy shots — exit / lock-line. SETUP-only faint 「观察环」 at scout range (not combat FOW) |

Cover only mitigates attacks from its protect arc (cyan fan, drawn on top of the floor). Side/back shots are full damage. Fire cones are yellow and clipped by walls.

Warehouse has an authored orange **油桶** on the east flank (cell tint + blast preview). It detonates on enemy proximity during the frozen watch — never by mid-fight click — and damages friendlies in the blast.

## Levels

1. **院子** — cover / facing / dual routes; rifle / MG / scout kits; abort / replay / mute  
2. **仓道** — ambush hold-fire + ammo pack + authored explosive barrel on the east flank (proximity during sim only; damages friendlies in blast)  
3. **泵站** — door lock switches flank to alternate route; re-cover the new approach  
