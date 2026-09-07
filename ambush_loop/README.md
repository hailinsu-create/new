# Ambush Loop

Godot 4.7 vertical slice — Commandos-style ambush prep + time-loop intel.

Blueprint: `docs/Ambush_Loop_开发蓝图.md`

## Run

```bash
godot --path ambush_loop
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

## Controls

| Key | Action |
|-----|--------|
| 1/2/3 | Select operator |
| LMB cover | Deploy |
| A/D or RMB | Facing |
| F | Fire mode (见敌即打 / 入伏再打) |
| G | Assign ammo pack (levels 2–3) |
| B | Toggle door lock (level 3) |
| Tab | 绊索 tool |
| Space | Sound alarm |
| P / buttons | Pause / 1× / 2× during watch |
| Clear btn | Clear deploy (keep intel) |
| R | Clear memory and restart |

## Levels

1. **院子** — cover / facing / dual routes  
2. **仓道** — ambush hold-fire + ammo pack  
3. **泵站** — door lock switches flank to alternate route  
