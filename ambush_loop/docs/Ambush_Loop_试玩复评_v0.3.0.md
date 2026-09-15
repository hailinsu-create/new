# Ambush Loop 试玩复评（v0.3.0 COMMANDOS/WW2）

对象：分支 `cursor/commandos-ambush-0641`  
HEAD：**`9f21e44d0106f348eb3338bbd6184fbdba4f3b19`**（`build(android): ship v0.3.0 Commandos/WW2 playtest APK`）  
对照：0.2.0 锁死观战朋友包（`ambush-loop-playtest-0.2.0` / `82b91dc`）；像素复评 `71ca4af` 门槛加权 **9.0 / 8.6**；契约自评 ~**9.0**。  
本评：**独立复评**，不沿用 9.0。玩法切片已从「布置→锁死观战」换成「搜刮→拉警报→打扫」。  
日期：2026-09-12

截图：`docs/eval_v0.3.0/`（37 张，`dump.log`）  
冒烟：`docs/eval_v0.3.0/smoke.log`  
型号探针：`docs/eval_v0.3.0/weapon_probe.log`  
PCM 探针：`docs/eval_v0.3.0/wav_probe.log`（Dummy，**未耳听**）  
Dump 脚本：`scripts/eval_dump_v030.gd`

未开第 7 夜 / FOW / sprite / 真 VO。未改游戏代码。无真机、无扬声器。

---

## 证据分级

| 标 | 含义 | 本报告里用在哪 |
|---|---|---|
| **实测** | 本机跑过 | Godot 4.7.2 headless 冒烟 ~62.5s / exit 0；`DISPLAY=:1` 窗口 1280×720 dump 37 张；`assert_apk_raid.py` + unzip APK；PCM 探针 36 cue |
| **源码** | 读了契约/HUD/武器表 | `COMMANDOS_RAID.md`、`weapon_catalog.gd`、`level_def.gd` stashes/waves、`raid_director.gd`、`touch_hud.gd`、`main.gd` 阶段条 |
| **推演** | 没真人、没真机、没耳朵 | 第一局搜刮疲劳、拇指热区、枪声好不好听、非参考方案平衡 |

窗口 dump 是脚本走 SCOUT→ALERT→SWEEP，**不是**人工鼠标通关。六夜参考胜用 `raid_prepare_ref`（瞬间武装），与冒烟同一条捷径。开匣/刀漏网/阶段芯片是真跑出来的。

---

## 一句话总评

Commandos 环（刀开局 → 开匣 → 拉警报 → 清波打扫 → 下一波/撤离）和 **v0.3.0 COMMANDOS/WW2** 印章已经进 APK，冒烟与窗口 dump 都能走完院子到电台。

它还不是 9 分切片：警报 cinema 条仍写 **「锁死观战」**，28 型号大半停在目录里，院子 `m1911`/`shotgun` 匣被墙吃掉。朋友能分清这不是 0.2.0 锁死包；商店页还撑不住。

**可对外试玩：是（朋友包 / debug sideload）。**  
**正式版：否。**

---

## 完成度（制作人，独立，1–10）

| 维 | 0.2.0 像素 `71ca4af` | 契约自评 | **本切片独立** | 依据 |
|---|---:|---:|---:|---|
| 玩法 | 9.2 | 9.1 | **8.5** | dump 走出 scout→alert→sweep；冒烟 `SMOKE_OK_RAID_LOOP`。警报条仍写锁死观战，参考胜靠瞬间武装 |
| 内容 | 9.1 | 8.9 | **8.0** | 六夜波次表在；具名匣 6 把看得到。院子 9 匣只刷 7；28 型号未铺进玩家第一眼 |
| 手感 | 9.1 | 8.8 | **8.2** | 需枪门、0.4s 开匣、打扫 CTA 都在像素里。通关「零逃逸」字会漏进下一夜搜刮 |
| 美术 | 8.4 | 8.3 | **7.9** | 六夜墙语/钠灯/柴油橙可分；Kar98k 卡面印章可读。仍是多边形，型号剪影要凑近匣标签 |
| 音频 | 7.2 | 6.8 | **6.8** | PCM 表有 `fire_bolt` 0.166s / `fire_mg42` 0.26s / `fire_smg` 0.08s。Dummy，未耳听，不加到 7 |
| 叙事 | 8.6 | 8.4 | **8.2** | 简报「先搜匣」、教程 1/3「搜刮」、致谢写打扫带进下一波。失败牌刀漏网仍在教 0.2.0 东箱朝向 |
| 触控 | 8.7 | 8.6 | **8.4** | `37` 底栏有手雷/诱饵/递装，桌面双条关。触控钮写「警报」不写「需枪」。无真机 |

门槛加权（玩法/内容/手感/触控）**= 8.3 / 10**。  
七维均分 **8.0**。

对照：不要把 `SMOKE_OK_WEAPON_MODELS n=28` 写成「玩家摸得到 28 把枪」，也不要把旧锁死观战的 9.0 像素分接到这条环上。本分是 **新 37 张 PNG + 本机冒烟指纹 + APK unzip**。下调项是锁死文案残留、匣格被墙吃、型号感知面、真机/真人空。

---

## 1. 现状核对（实测）

- 分支 `cursor/commandos-ambush-0641` 与 origin 同步。HEAD `9f21e44`。
- `project.godot`：`config/version="0.3.0"`。
- 冒烟：

```
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf
SMOKE_GAME_VERSION 0.3.0
SMOKE_OK_LAUNCH_BAR title+GameSettings+AudioDirector+missions+android_preset
SMOKE_OK_WEAPON_MODELS n=28
SMOKE_OK_RAID_CONTRACT stashes=7 waves=2
SMOKE_OK_CRATE_SEARCH
SMOKE_OK_PICKUP rifle
SMOKE_OK_ALARM_GATE
SMOKE_OK_KNIFE_LEAK tick=929
SMOKE_OK yard raid won
SMOKE_OK_RAID_LOOP
SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio
SMOKE_SLICE_COMPLETE
exit 0   ~62.5s
```

型号探针：`SMOKE_OK_WEAPON_MODELS n=28` / `ART_WEAPON_PROBE_OK`。  
无非预期 `SMOKE_BAD_*`。`SMOKE_OK_KNIFE_LEAK` 是院子故意漏网。

窗口 dump：`DUMP_HEAD display=X11 size=(1280, 720) ver=0.3.0`，`DUMP_OK eval_v0.3.0`。Dummy 退出仍报 4 个 ObjectDB leak（与旧 dump 同类，无声卡）。

---

## 2. APK 是否真含 raid / 武器型号（实测）

文件：`ambush_loop/dist/AmbushLoop-v0.3.0-commandos-ww2-playtest.apk`  
与 `build/android/AmbushLoop-debug.apk` **MD5 相同**。

| 项 | 值 |
|---|---|
| 包名 | `com.ambushloop.game` |
| versionName | **0.3.0** |
| versionCode | **2** |
| SHA256 | `44f89ecb578d8a0b730c9da99ad0b4e8716d3fdb80ee1ae3bb2e180ee2cf1866` |
| 大小 | 29232001 bytes（28M） |
| 引擎 | Godot 4.7.2 debug，arm64，minSdk 24，横屏 |

`python3 ambush_loop/scripts/assert_apk_raid.py …` → `ASSERT_OK_RAID_APK … n_raid 5`  
`ASSERT_APK_BADGING package: name='com.ambushloop.game' versionCode='2' versionName='0.3.0'`

unzip 实有（节选）：

- `assets/scripts/raid/raid_director.gdc`
- `assets/scripts/raid/weapon_catalog.gdc`
- `assets/scripts/raid/stash.gdc`
- `assets/scripts/raid/grenade.gdc` / `landmine.gdc` / `decoy.gdc` / `pathfinder.gdc`
- `assets/scripts/art/weapon_art.gdc` / `ww2_palette.gdc`
- `assets/scripts/ui/gun_stamp.gdc`

**0.2.0 锁死观战包没有这些。** 大改在包里，不是文档自称。

Release：https://github.com/hailinsu-create/new/releases/tag/v0.3.0-commandos-ww2  
直链：https://github.com/hailinsu-create/new/releases/download/v0.3.0-commandos-ww2/AmbushLoop-v0.3.0-commandos-ww2-playtest.apk

---

## 3. 一眼确认版本

不要靠「院子开匣一定写 Kar98k」——院子步枪匣 kind 是 class id `rifle`，卡面写 **步枪 弹7/14**（`11_scout_yard_rifle.png`）。Kar98k 卡面是 dump 里 `apply_weapon("kar98k")` 打出来的（`12`）。

稳妥确认：

1. 标题顶栏印章 **`v0.3.0 COMMANDOS/WW2`**，副题 **搜刮埋伏 · 多波打扫 · 横屏**（`01_title.png`）。
2. 作战设置中间一行 **`v0.3.0 · COMMANDOS / WW2`**（`04_pause_version.png`）。
3. 进院子：三人卡面是 **刀**，底栏 CTA **需枪**，右上 **阶段 · 搜刮埋伏  波次 1/2**（`08`）。
4. 清完第一波：右上 **打扫战场  空格拉第2波**，底栏 **下一波警报**（`18`）。不是冻在观战里。
5. 系统：`versionName=0.3.0` / `versionCode=2`。先卸 0.2.0 再装，避免同包名旧包残留。

---

## 4. Commandos 环成不成立

契约一句话：搜刮组火力 → 埋伏拉警报 → 清波打扫带战利品 → 下一波；逃逸/全灭失败。

| 环节 | 结论 | 证据 |
|---|---|---|
| 刀开局 | **成立（实测）** | `DUMP_GUNS yard_knives 灰狼=knife …`；`08` 三卡「刀」 |
| 点地走 / 开匣 0.4s | **成立（冒烟实测，dump 截到结果）** | `SMOKE_OK_CRATE_SEARCH` 禁止瞬间；dump `10`/`11` 已是「装备步枪」（settle 帧吃掉开匣过程，**没截到开盖中途**） |
| 需枪门 | **成立** | `09`：flash「至少先拾一把枪 — 再按一次才强拉警报」，CTA **强拉警报**，仍 `phase=scout`。`SMOKE_OK_ALARM_GATE` |
| 警报战斗波 | **成立，文案打架** | `17` HUD `phase=alert`「警报 第1/2波 敌2 待0 员3」。顶栏 cinema 仍印 **锁死观战 · 初阵**（`main.gd` 约 1338 行） |
| 打扫 | **成立** | `18`：`phase=sweep` tick=271 loot=2，芯片「打扫战场  空格拉第2波」，尸体 X + 地上弹药 |
| 第二波 | **成立** | `19`：`警报 第2/2波` 敌1。参考胜 tick=227 |
| 撤离 | **成立** | `20` 封锁成功 / 下一关整钮。电台 `32`/`33` 致谢 |
| 刀强拉漏网 | **成立** | `14`「第1波漏网：主路 · 敌1 · 0.0s出发 · 主路南闸」tick=**929**（与冒烟同一指纹） |

**结论：环在包里，是 Commandos-lite，不是敢死队。** 契约砍掉的爬楼/开车/真迷雾/警报中走位都还在。警报中可丢已持有手雷（源码 + 触控「手雷」）。六夜参考通关仍走 `raid_prepare_ref`，**不能当成真人搜刮通关记录**。

相对 0.2.0：核心循环从「布置锁死 → 看一遍」变成「搜刮提交 → 波次打扫」。地图走廊、作者路线、逃逸口还是那六夜。

---

## 5. 28 型号是否可感知

`WeaponCatalog.model_ids()` **28** 把，冒烟咬死：Kar98k 比 M1 加兰德慢、弹匣比恩菲尔德小、MG42 比 BAR 快、Thompson 比 Sten 密、剪影不全等。

**玩家第一眼能看见的，少得多。**

匣上刷出的具名型号（dump `DUMP_STASH` + 像素）：

| 夜 | 具名匣 | 像素 |
|---|---|---|
| 院子 | 作者写了 `m1911`，**未刷出** | `13` 格上没有 M1911 标签 |
| 仓道 | **MP40** | `22` 地面标签「MP40」 |
| 泵站 | **斯登** (`sten`) | stash 日志；空图未特写 |
| 信号楼 | **MG42** | stash 日志；`26` 狼站在匣上 |
| 油库 | **汤姆逊** | stash 日志；`28` 开匣中 |
| 电台 | **春田** + **卢格** | `37` 南折旁「春田」可读 |

院子实刷 7/9：`rifle, mg, scout, grenade, mine, ammo, pistol`。`shotgun@(18,12)`、`m1911@(20,16)` 格 `grid.is_blocked` 被跳过。信号楼地雷匣 `(7,11)` 同样没刷（6/7）。

卡面型号：class 匣写出「步枪 / 机枪 / 狙」。Kar98k 卡面（`12`）是脚本 `apply_weapon`，**不是**院子匣默认产物。弹匣差可感知：步枪 7/14 vs Kar98k 7/10。

尸体掉落表（源码，dump 未截到型号枪躺地上）：仓 Kar98k/MP40，泵恩菲尔德/斯登，信号楼 MG42/布伦，油库汤姆逊/M12，电台春田/卢格，院子 M1911/Kar98k。`loot_ammo==1` 只掉弹药。

**28 把在目录和剪影探针里；战役里稳定看见的是 6 个具名匣 + 一堆 class 匣。** 发布说明用「院子开匣读 Kar98k」当版本指纹，**过满**。

---

## 6. 六夜速评（搜刮 / 波次 / 打扫 / 型号）

波次与匣数是 dump 实测；参考胜 tick 是 dump 的 `raid_prepare_ref` 捷径，不是真人搜刮。

| 夜 | 波 | 匣（刷出/作者） | 搜刮课 | 波次是否合理 | 型号出现 | dump 参考胜 tick |
|---|---:|---|---|---|---|---:|
| 院子 | 2 | 7/9 | 刀、需枪、先开这匣 | 第1波主路 2 人，打扫后再打东廊 1 人。合理 | class 步枪为主；m1911/散弹匣没了 | 227（第2波钟） |
| 仓道 | 2 | 8/8 | 入伏再打、油桶、弹包 | 主路 → 东廊。合理 | **MP40 匣可见** | 876 |
| 泵站 | 2 | 7/7 | 锁门改紫线 | 主路 → 侧翼。合理 | 斯登匣在日志 | 722 |
| 信号楼 | 2 | 6/7 | 3.8s 东廊、别堆南闸 | 西廊先、东廊后。合理 | MG42 匣；地雷匣被墙吃 | 602 |
| 油库 | 2 | 8/8 | 2.2s 暗道绊索 | 主+东 → 西暗道。合理 | 汤姆逊匣；散弹 class | 391 |
| 电台 | 3 | 9/9 | 3.6s 暗道 + 5.2s 回波 | 三波阶梯清楚，芯片 1/3 | 春田、卢格 | 448 |

刀漏网指纹跨冒烟/dump 对齐：**tick=929，reason=escape，第1波主路**。  
失败牌仍写「把铁砧转到东箱」——那是 0.2.0 锁死课。刀强拉的第一课其实是 **先搜枪**。

通关后幕间（`21`）文案已是「先搜机枪和弹包 / 打扫后再打东廊」，叙事层环是圆的。

---

## 7. 窗口像素（本切片改了什么）

可感知、有图：

- 标题/暂停版本印章（`01` `04`）。
- 教程 1/3「搜刮」：开局只有刀、0.4 秒开匣、步枪弹不能塞机枪（`07`）。
- 简报必须带「先搜匣」（`06`）。
- 操作说明空格：需枪 / 打扫下一波或撤离（`02`）。
- SCOUT 右上阶段芯片 + 底栏需枪（`08`）。
- 警报门（`09`）。
- 开匣得步枪（`11`）与 Kar98k 卡面差（`12`）。
- ALERT 第1波（`17`）/ SWEEP（`18`）/ 第2波（`19`）。
- 失败「第1波漏网」（`14`）。
- 仓道钠黄 + MP40 标签（`22`）；油库柴油橙（`28`）；电台网墙 + 春田（`30` `37`）。
- 触控底栏手雷/诱饵/递装，桌面双条关（`37`）。
- 六夜档案邮戳（`35`）；致谢点名搜刮/埋伏/打扫（`33`）。

明确没过 / 像素打脸：

- 警报顶栏 **锁死观战**（`17` `19` `20` `33`）。阶段芯片藏在 cinema 后面。
- 「零逃逸 · 撤离封锁」flash 漏进仓/信号楼/油库/电台搜刮（`22` `26` `28` `31`）。
- 院子 m1911、散弹匣，信号楼地雷匣，作者表有、运行没有。
- dump 没截到 0.4s 开盖中途（脚本 settle 太慢，不是冒烟红灯）。

---

## 8. 音频（探针，非耳听）

`wav_probe.log`：`PROBE_OK n=36`。型号相关时长：

| cue | peak | sec |
|---|---:|---:|
| fire | 0.321 | 0.096 |
| fire_bolt | 0.277 | 0.166 |
| fire_garand | 0.289 | 0.080 |
| fire_smg | 0.389 | 0.080 |
| fire_mg / fire_mg42 | 0.335 / 0.307 | 0.260 |
| fire_scout | 0.305 | 0.108 |

冒烟 `SMOKE_OK_SFX_BODY fire=0.28 tension=0.38 echo=0.27`。仍是程序 WAV，Dummy 驱动。**未耳听，音频维持 6.8。**

---

## 9. 触控

`37_touch_radio_bars.png`：提示「点队员/点地走 → 拾取匣 → 趴掩体 → 拉警报 → 打扫下一波」。钮：开火 / 弹包 / 绊索 / 手雷 / 诱饵 / 递装 / ↺↻ / 收回 / 警报。桌面双底栏隐藏。`SMOKE_OK_TOUCH_NADE` / `SMOKE_OK_TOUCH_NO_DESKTOP_BARS`。

缺口：桌面 SCOUT 写「需枪」，触控始终「警报」（`touch_hud.gd` 标签写死）。无 adb 真机。触控不到 9。

---

## 10. 明确没过

- 真机院子拇指环；≥3 真人第一局搜刮（不要瞬间武装）。
- 警报 cinema「锁死观战」与环矛盾。
- 28 型号的战役可见度。
- 被墙吃掉的匣。
- 通关字残留到下一夜。
- sprite / 真 VO / FOW / 第 7 夜 / 合进 `main` 当正式发行。
- 警报中自由走位（契约故意砍，不要当漏做）。

---

## 11. Top 8 下一刀（按影响力）

1. **警报 cinema 条改掉「锁死观战」** → 「警报中 · 第N/M波」。朋友否则会以为还是 0.2.0。像素：`17` `19`。
2. **class 匣按夜 roll 型号**（院子步枪匣出 Kar98k，不要只出「步枪」）。否则 28 型号是目录成就。
3. **匣格改到可行走格**：院子 `m1911@(20,16)`、`shotgun@(18,12)`，信号楼 `mine@(7,11)`。作者表有、运行 0。
4. **通关 letterbox / 「零逃逸」flash 进下一夜必须清**。`22` `26` `28` `31`。
5. **触控「警报」与桌面「需枪 / 强拉 / 下一波 / 撤离」同步。** `37` vs `08`。
6. **刀漏网失败牌改第一课「先搜枪」**，东箱朝向留给有枪之后。`14`。
7. **真人搜刮局**（至少院子+仓道）：开匣、递装、弹种、打扫捡尸，不要 `raid_prepare_ref`。
8. **真机 + 耳听** MG42 皮带 vs 栓动差。本环境 Dummy，音频分被它钉住。

不要做的：第 7 夜、FOW、sprite、真 VO、把参考瞬间武装写成「玩家能这样通」。

---

## 12. APK 直链与安装

- 页：https://github.com/hailinsu-create/new/releases/tag/v0.3.0-commandos-ww2
- 直链：https://github.com/hailinsu-create/new/releases/download/v0.3.0-commandos-ww2/AmbushLoop-v0.3.0-commandos-ww2-playtest.apk
- 仓库副本：`ambush_loop/dist/AmbushLoop-v0.3.0-commandos-ww2-playtest.apk`
- 不要装 `AmbushLoop-playtest.apk` / 旧 `AmbushLoop.apk`（那是 0.2.0 锁死观战）。
- 同包名：先卸 0.2.0，或靠 versionCode 2 覆盖。装完用 §3 印章确认。

---

## 附录：截图索引

| 文件 | 看什么 |
|---|---|
| `01_title.png` | v0.3.0 COMMANDOS/WW2 印章 + 搜刮埋伏副题 |
| `02_howto.png` | 搜刮 / 需枪 / 打扫键表 |
| `04_pause_version.png` | 暂停 `v0.3.0 · COMMANDOS / WW2` |
| `06_briefing_yard.png` | 先搜匣 |
| `07_tut_yard.png` | 1/3 搜刮 |
| `08_scout_yard_knives.png` | 刀、需枪、搜刮埋伏 1/2 |
| `09_scout_alarm_gate.png` | 强拉警报门 |
| `11_scout_yard_rifle.png` | class 步枪 7/14 |
| `12_scout_yard_kar98k.png` | Kar98k 卡面 7/10（apply_weapon） |
| `14_fail_yard_knife.png` | 第1波漏网 tick 929 |
| `17_alert_yard_w1.png` | 第1波；顶栏仍锁死观战 |
| `18_sweep_yard_w1.png` | 打扫战场 / 下一波警报 |
| `19_alert_yard_w2.png` | 第2波 |
| `20_win_yard.png` | 封锁成功 |
| `21_handoff_yard_warehouse.png` | 幕间深仓 |
| `22_scout_warehouse_empty.png` | MP40 匣 |
| `26_scout_railcut_mg42.png` | 信号楼；零逃逸字残留 |
| `28_scout_depot_thompson.png` | 油库柴油橙 |
| `31`/`37` | 电台春田；触控底栏 |
| `33_credits.png` | 六夜 + 搜刮环文案 |
| `35_journal_stamped.png` | 六夜已封锁 |

冒烟完整行见 `docs/eval_v0.3.0/smoke.log`。
