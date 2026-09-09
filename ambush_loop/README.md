# Ambush Loop

Godot 4.7 Android portrait first release candidate — Commandos-style ambush prep + time-loop intel.

Blueprint: `docs/Ambush_Loop_开发蓝图.md`

## Run

```bash
godot --path ambush_loop
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
godot --headless --path ambush_loop -s res://scripts/frontend_smoke_test.gd
godot --headless --path ambush_loop -s res://scripts/lifecycle_smoke_test.gd
```

首次启动进入主菜单。手机玩家依次使用“开始游戏”→新手教学→触控按钮完成布置；不需要键盘。设置提供音量、震动和触控反馈开关；关于页说明离线存档和隐私边界。

默认发行方向：安卓竖屏、Compatibility renderer、720×1280 逻辑视口、离线单机。首发导出清单见 `docs/PLAY_STORE_RELEASE_CHECKLIST.md`，隐私政策草案见 `docs/PRIVACY_POLICY_DRAFT.md`。

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

桌面快捷键保留用于开发与辅助验证；警报后计划锁死，观看阶段触摸地图和队员卡不会修改布置。

## Levels

1. **院子** — cover / facing / dual routes  
2. **仓道** — ambush hold-fire + ammo pack  
3. **泵站** — door lock switches flank to alternate route  
