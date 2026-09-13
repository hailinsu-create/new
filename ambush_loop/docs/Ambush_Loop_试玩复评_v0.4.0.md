# Ambush Loop 试玩复评（v0.4.0 Commandos 2 kit）

对象：分支 `cursor/commandos-ambush-0641`，机制收束到《盟军敢死队 2》枪表 / 背包 / 自动手雷。  
对照：v0.3.1 的 28 型号表 + 手动丢雷。

截图：`docs/eval_v0.4.0/`（40 张，含 `13b_backpack_open.png` / `13c_nade_mark.png`）  
冒烟：`docs/eval_v0.4.0/smoke.log`（`EXIT:0`，`SMOKE_SLICE_COMPLETE`）  
型号探针：`docs/eval_v0.4.0/weapon_probe.log`（`n=10`）

APK：`dist/AmbushLoop-v0.4.0-commandos2-kit.apk`  
`versionName` 0.4.0 / `versionCode` 4 / `com.ambushloop.game`

## 一眼确认

1. 标题戳 **v0.4.0 COMMANDOS/WW2**（`01_title.png`）。
2. 院子匣只有精简型号：Kar98k / MG42 / 98K瞄准镜 / M1911 / 汤姆逊 / 卢格（`08` `11` `DUMP_STASH`）。没有 G43、钻枪、斯登。
3. `I` 打开 6 格背包（`13b`：Kar98k·握 / 手雷×2 / 卢格）。
4. `G` 放下 **雷点**（`13c` 圈 +「雷点已设 · 警报自动丢」）。
5. 拉警报顶栏 **警报中 · 第1/2波**（`17`），不是锁死观战。

## 武器表（种类 × 同盟 × 轴心）

| 种类 | 同盟 | 轴心 |
|------|------|------|
| 手枪 | M1911 | 卢格 |
| 步枪 | M1加兰德 | Kar98k |
| 冲锋枪 | 汤姆逊 | MP40 |
| 轻机枪 | BAR | MG42 |
| 狙击 | 春田 | 98K瞄准镜 |

冒烟：`SMOKE_OK_WEAPON_MODELS n=10`。院子 class 匣 resolve：步枪=Kar98k，机枪=MG42，冲锋枪=汤姆逊，手枪=M1911。

## 背包

每人 6 格。枪 / 手雷 / 地雷 / 诱饵占格；弹药跟枪走。第一把枪自动装备，第二把入包不换手。满了捡不起来。`T` 或背包「递给队友」。

冒烟：`SMOKE_OK_BACKPACK occ=6 equip=thompson`，`SMOKE_OK_BACKPACK_UI`。

## 自动手雷

搜刮：`G` / 雷点工具放圈，不丢。警报：敌人进锥或走进雷点就自动丢，冷却 3.6s，友伤圈内不丢，消耗库存。

冒烟：`SMOKE_OK_AUTO_GRENADE n=2 left=1`，`SMOKE_OK_NADE_MARK`。

## RAID

`SCOUT → ALERT → SWEEP` 仍在。点选单人、点地走、搜刮、埋伏、多波、打扫带装。六夜参考通关全绿。

`SMOKE_OK_CINEMA 警报中 · 第1/2波`  
`SMOKE_OK_RAID_LOOP` + 仓道/泵站/信号楼/油库/电台 `raid won`  
`SMOKE_SLICE_COMPLETE`

## 直链

Release：https://github.com/hailinsu-create/new/releases/tag/v0.4.0-commandos2-kit  
APK：https://github.com/hailinsu-create/new/releases/download/v0.4.0-commandos2-kit/AmbushLoop-v0.4.0-commandos2-kit.apk

契约：`docs/COMMANDOS2_KIT.md`。
