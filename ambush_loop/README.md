# Ambush Loop

Godot 4.7 vertical slice — Commandos-style ambush prep + time-loop intel.

Blueprint: `docs/Ambush_Loop_开发蓝图.md`

## Run

```bash
godot --path ambush_loop
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

Smoke must print `SMOKE_SLICE_COMPLETE` and exit 0. Reference wins: yard slots 1,2,5 facings 90/180/180; warehouse 1,3,5; pump 1,4,5 (open and locked door).

## Controls

| Key / UI | Action |
|----------|--------|
| 1 / 2 / 3 or role cards | Select 步枪手 / 机枪手 / 侦察兵 |
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
| Clear btn | Clear deploy (keep intel + tripwires) |
| R | Clear memory and restart |

Alarm locks layout, facing, fire modes, door, and tools. Pause/speed/replay only change viewing. Escape **or** squad wipe fails the loop; abort is an intentional fail that still stores intel. On escape the exit cell flashes and the result panel shifts so the mouth stays visible. Cross-loop keeps intel ghosts + last plan only.

## Roles

| Role | Kit |
|------|-----|
| 步枪手 | Balanced cone, 7 rounds — filler / sustain |
| 机枪手 | Wider cone, faster fire, shorter reach, hungrier ammo; more exposed from the flank |
| 侦察兵 | Long narrow overwatch, few heavy shots — exit / lock-line |

Cover only mitigates attacks from its protect arc (cyan fan, drawn on top of the floor). Side/back shots are full damage. Fire cones are yellow and clipped by walls.

Warehouse has an authored orange **油桶** on the east flank (cell tint + blast preview). It detonates on enemy proximity during the frozen watch — never by mid-fight click — and damages friendlies in the blast.

## Levels

1. **院子** — cover / facing / dual routes; rifle / MG / scout kits  
2. **仓道** — ambush hold-fire + ammo pack + authored explosive barrel on the east flank (proximity during sim only; damages friendlies in blast)  
3. **泵站** — door lock switches flank to alternate route; re-cover the new approach  
