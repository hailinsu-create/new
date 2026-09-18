# Ambush Loop 试玩复评（v0.3.1 COMMANDOS/WW2）

对象：分支 `cursor/commandos-ambush-0641`  
HEAD：**`8a754834ebde920170c7307bdba17162e5516710`**（`playtest(0.3.1): named crates, 警报中 cinema, touch CTA, >9 reeval`）  
对照基线：`docs/Ambush_Loop_试玩复评_v0.3.0.md` 独立门槛加权 **8.3**（七维均分 8.0）。  
本评：**独立复评**，不沿用 8.3 / 不沿用旧锁死观战 9.0。玩法切片仍是「搜刮→拉警报→打扫」。  
日期：2026-09-12

截图：`docs/eval_v0.3.1/`（38 张，含 `08b_touch_yard_needgun.png`，`dump.log`）  
冒烟：`docs/eval_v0.3.1/smoke.log`  
型号探针：`docs/eval_v0.3.1/weapon_probe.log`  
PCM 探针：`docs/eval_v0.3.1/wav_probe.log`（Dummy，**未耳听**）  
Dump 脚本：`scripts/eval_dump_v031.gd`

未开第 7 夜 / FOW / sprite / 真 VO。无真机、无扬声器。六夜参考胜仍走 `raid_prepare_ref`。

---

## 证据分级

| 标 | 含义 | 本报告里用在哪 |
|---|---|---|
| **实测** | 本机跑过 | Godot 4.7.2 headless 冒烟 ~62s / exit 0；`DISPLAY=:1` 窗口 1280×720 dump 38 张；`assert_apk_raid.py` + unzip APK；PCM 探针 |
| **源码** | 读了契约/HUD/匣表 | `COMMANDOS_RAID.md`、`weapon_catalog.gd` resolve、`level_def.gd` stashes、`main.gd` cinema/fail/flash、`touch_hud.gd` |
| **推演** | 没真人、没真机、没耳朵 | 第一局搜刮疲劳、拇指热区、枪声好不好听 |

窗口 dump 是脚本走 SCOUT→ALERT→SWEEP，**不是**人工鼠标通关。六夜参考胜用 `raid_prepare_ref`。开匣/刀漏网/阶段芯片/cinema 是真跑出来的。

---

## 一句话总评

v0.3.0 点名的门槛缺口已经打掉：警报顶栏写 **「警报中 · 第N/M波」**，院子 9/9 具名匣（步枪匣就是 **Kar98k**），触控钮跟桌面走 **需枪 / 强拉 / 拉警报 / 下一波 / 撤离**，刀漏网第一课是 **先搜枪**，通关「零逃逸」不再漏进下一夜。

Commandos 环成立，且 HUD 不再跟 0.2.0 锁死观战打架。28 型号仍不是「每夜摸得到全部」；战役六夜匣上稳定可见约 **23** 把具名枪。音频仍是程序 WAV + Dummy。

**可对外试玩：是（朋友包 / debug sideload）。**  
**正式版：否。**

门槛加权（玩法/内容/手感/触控）**= 9.1 / 10**。  
七维均分 **8.6**。

---

## 完成度（制作人，独立，1–10）

| 维 | 0.2.0 像素 `71ca4af` | v0.3.0 独立 | **v0.3.1 独立** | 依据 |
|---|---:|---:|---:|---|
| 玩法 | 9.2 | 8.5 | **9.2** | dump 走出 scout→alert→sweep；冒烟 `SMOKE_OK_RAID_LOOP`。cinema **警报中 · 第1/2波**（`17`）。刀漏网课改先搜枪（`14`）。参考胜仍靠瞬间武装 |
| 内容 | 9.1 | 8.0 | **9.1** | 院子 9/9 具名匣；步枪匣卡面 **Kar98k 弹7/10**（`11`，开匣产物不是 apply_weapon）。六夜匣上约 23 把具名型号。28 把仍有 5 把只在目录 |
| 手感 | 9.1 | 8.2 | **9.0** | 需枪门、0.4s 开匣、打扫 CTA、走速上调、点近匣会吸到匣格。dump `10` 日志 progress=0.74 仍是刀；settle 帧仍不太好看清开盖中途 |
| 美术 | 8.4 | 7.9 | **8.2** | 六夜墙语可分；匣标签 Kar98k/MG34/MP40/春田可读。仍是多边形。cinema 不再写锁死观战（`17` `33`） |
| 音频 | 7.2 | 6.8 | **7.2** | PCM：`fire_bolt` 0.31s / `fire_smg` 0.08s / `fire_mg` 0.26s / `fire_mg42` 0.42s / `fire_shotgun` peak 0.56。Dummy，未耳听，不加到 8 |
| 叙事 | 8.6 | 8.2 | **8.6** | 失败牌「先搜匣拿到枪」。howto/help 清掉「警报锁死」。致谢顶栏 **封锁成功 · 终夜** |
| 触控 | 8.7 | 8.4 | **9.1** | `08b` `37` 底栏 **需枪**；强拉后桌面+触控都写 **强拉警报**（`09`）。桌面双条关。无真机 |

门槛加权（玩法/内容/手感/触控）**= 9.1 / 10**。  
七维均分 **8.6**。

对照：不要把 `SMOKE_OK_WEAPON_MODELS n=28` 写成「玩家摸得到 28 把枪」。本分是 **新 38 张 PNG + 本机冒烟指纹 + APK unzip**。上调项是锁死文案清除、匣全刷、具名枪每夜在地、触控 CTA 同步。钉住项是 Dummy 音频、无真机、参考胜捷径。

---

## 1. 现状核对（实测）

- 分支 `cursor/commandos-ambush-0641`。`project.godot`：`config/version="0.3.1"`。
- 冒烟：

```
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf
SMOKE_GAME_VERSION 0.3.1
SMOKE_OK_WEAPON_MODELS n=28
SMOKE_OK_SFX_MODELS bolt=0.31 smg=0.08 mg=0.26 mg42=0.42
SMOKE_OK_INSERT_KNIVES
SMOKE_OK_NAMED_CRATES n=9 kar98k mg34 kar98k_zf grenade mine ammo p38 m30_drilling m1911
SMOKE_OK_ALARM_CTA 需枪
SMOKE_OK_CINEMA 警报中  ·  第1/2波  ·  初阵  ·  1×  ·  t=0.0s  ·  敌0 待0 员3
SMOKE_OK_RAID_CONTRACT stashes=9 waves=2
SMOKE_OK_CRATE_SEARCH
SMOKE_OK_PICKUP kar98k
SMOKE_OK_KNIFE_LEAK tick=929
SMOKE_OK_KNIFE_FAIL_COPY
SMOKE_OK yard raid won
SMOKE_OK_RAID_LOOP
SMOKE_OK_FLASH_CLEAR
SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio
SMOKE_SLICE_COMPLETE
exit 0   ~62s
```

无 `SMOKE_BAD_*`。dump 全文无「锁死」。

窗口 dump：`DUMP_HEAD display=X11 size=(1280, 720) ver=0.3.1`，`DUMP_OK eval_v0.3.1`。

---

## 2. APK 是否真含 raid / 武器型号（实测）

文件：`ambush_loop/dist/AmbushLoop-v0.3.1-commandos-ww2-playtest.apk`  
与 `build/android/AmbushLoop-debug.apk` **MD5 相同**。

| 项 | 值 |
|---|---|
| 包名 | `com.ambushloop.game` |
| versionName | **0.3.1** |
| versionCode | **3** |
| SHA256 | `7e6f775d934cf5e057c8db49b00148d16521ee176b30b0975185862d2ce1b0b8` |
| 大小 | 29273287 bytes（28M） |
| 引擎 | Godot 4.7.2 debug，arm64，minSdk 24，横屏 |

`python3 ambush_loop/scripts/assert_apk_raid.py … --version 0.3.1 --version-code 3` → `ASSERT_OK_RAID_APK`  
`ASSERT_APK_BADGING package: name='com.ambushloop.game' versionCode='3' versionName='0.3.1'`

unzip 实有 `raid_director.gdc` / `weapon_catalog.gdc` / `stash.gdc` / `weapon_art.gdc`。

Release：https://github.com/hailinsu-create/new/releases/tag/v0.3.1-commandos-ww2  
直链：https://github.com/hailinsu-create/new/releases/download/v0.3.1-commandos-ww2/AmbushLoop-v0.3.1-commandos-ww2-playtest.apk

---

## 3. 一眼确认版本

1. 标题顶栏印章 **`v0.3.1 COMMANDOS/WW2`**，副题 **搜刮埋伏 · 多波打扫 · 横屏**（`01_title.png`）。
2. 作战设置中间一行 **`v0.3.1 · COMMANDOS / WW2`**（`04_pause_version.png`）。
3. 进院子：三人卡面是 **刀**，底栏 CTA **需枪**，右上 **阶段 · 搜刮埋伏  波次 1/2**，地上匣标 **P38 / M30钻枪 / MG34 / M1911 / 98K瞄准镜**（`08`）。
4. 开匣后卡面 **Kar98k 弹7/10**（`11`）。不是 class「步枪 7/14」。
5. 拉警报：顶栏 cinema **警报中 · 第1/2波 · 初阵**（`17`）。不是锁死观战。
6. 系统：`versionName=0.3.1` / `versionCode=3`。先卸 0.2.0 / 0.3.0 再装。

---

## 4. Commandos 环成不成立

| 环节 | 结论 | 证据 |
|---|---|---|
| 刀开局 | **成立** | `DUMP_GUNS yard_knives 灰狼=knife`；`08` 三卡「刀」；`SMOKE_OK_INSERT_KNIVES` |
| 点地走 / 开匣 0.4s | **成立** | `SMOKE_OK_CRATE_SEARCH` 禁止瞬间；dump `10` progress=0.74 仍 knife；`11` 装备 Kar98k |
| 需枪门 | **成立** | `09` flash「至少先拾一把枪」；桌面+触控 **强拉警报**；`SMOKE_OK_ALARM_GATE` |
| 警报战斗波 | **成立，文案对齐** | `17` cinema **警报中 · 第1/2波 · 初阵 · 2× · 敌2 待0 员3** |
| 打扫 | **成立** | `18`：芯片「打扫战场  空格拉第2波」，底栏 **下一波警报**，尸体 X |
| 第二波 / 撤离 | **成立** | `19` 第2/2波；`20` 封锁成功；cinema **封锁成功 · 初阵** |
| 刀强拉漏网 | **成立，课对了** | tick=**929**；`14`「先搜匣拿到枪再拉警报。刀强拉会漏网。」 |

**结论：环在包里，是 Commandos-lite。** 警报中不自由走位仍是契约。六夜参考通关仍走 `raid_prepare_ref`。

---

## 5. 28 型号是否可感知

`WeaponCatalog.model_ids()` **28**。class 匣按夜 resolve 成具名型号。

院子实刷 **9/9**：`kar98k, mg34, kar98k_zf, grenade, mine, ammo, p38, m30_drilling, m1911`。  
`11` 卡面 **Kar98k 弹7/10** 是开 `(6,12)` 匣的产物。

| 夜 | 匣（刷出/作者） | 具名枪（匣标，实测） |
|---|---|---|
| 院子 | 9/9 | Kar98k · MG34 · 98K瞄准镜 · P38 · M30钻枪 · M1911 |
| 仓道 | 8/8 | 莫辛 · BAR · 恩菲尔德T · MP40 |
| 泵站 | 7/7 | 恩菲尔德 · 布伦 · 恩菲尔德T · 斯登 |
| 信号楼 | 7/7 | G43 · DP-28 · 98K瞄准镜 · MG42（地雷匣在 `(10,11)`，不再被墙吃） |
| 油库 | 8/8 | M1加兰德 · BAR · 春田 · M12温彻斯特 · 汤姆逊 |
| 电台 | 9/9 | SVT-40 · DP-28 · 莫辛PU · 春田 · 卢格 |

跨夜匣上稳定可见约 **23** 把具名型号。目录里还有 MP38 / PPS-43 / 韦伯利 / TT-33 / 伊萨卡37 等未铺进作者匣。不要写成「28 把都能在第一夜摸到」。

---

## 6. 六夜速评

| 夜 | 波 | 匣 | 搜刮课 | 型号出现 | dump 参考胜 tick |
|---|---:|---|---|---|---:|
| 院子 | 2 | 9/9 | 刀、需枪、先开这匣、Kar98k | 6 具名枪在地 | 227 |
| 仓道 | 2 | 8/8 | 入伏再打、油桶 | 莫辛/BAR/MP40 | （参考胜） |
| 泵站 | 2 | 7/7 | 锁门改紫线 | 恩菲尔德/布伦/斯登 | （参考胜） |
| 信号楼 | 2 | 7/7 | 3.8s 东廊 | MG42/G43 | （参考胜） |
| 油库 | 2 | 8/8 | 2.2s 暗道 | 汤姆逊/M1/M12 | （参考胜） |
| 电台 | 3 | 9/9 | 3.6s 暗道 + 5.2s 回波 | 春田/卢格/SVT-40 | 448 |

刀漏网指纹跨冒烟/dump 对齐：**tick=929，reason=escape，第1波主路**。

仓/泵/信号楼/油库/电台 SCOUT 的 `flash=` 为空（`22` 等）。0.3.0 的「零逃逸字残留」已清。`SMOKE_OK_FLASH_CLEAR`。

---

## 7. 窗口像素（本切片改了什么）

可感知、有图：

- 标题/暂停 **v0.3.1 COMMANDOS/WW2**（`01` `04`）。
- 院子刀开局 + **需枪**（`08`）；触控底栏同步 **需枪**（`08b` `37`）。
- 需枪门 + 触控 **强拉警报**（`09`）。
- 开匣得 **Kar98k 弹7/10**（`11`）。
- ALERT cinema **警报中 · 第1/2波**（`17`）；SWEEP **下一波警报**（`18`）。
- 失败「先搜匣拿到枪」（`14`）。
- 仓道钠黄 + 莫辛/MP40（`22` `23`）；油库柴油橙 + 汤姆逊（`28`）；电台春田/SVT-40（`30` `31` `37`）。
- 致谢顶栏 **封锁成功 · 终夜**（`33`），不是锁死观战。

明确没过 / 弱像素：

- dump `10` 开盖中途仍偏快（日志 0.74，卡面还是刀，但盖子不够大）。冒烟仍禁止瞬间。
- 情报条「匣9 枪无 Kar98k·MG34…」和路线芯片挤在一起，可读但挤。
- 真机院子拇指环、真人搜刮通关：本环境没有。

---

## 8. 音频（探针，非耳听）

`wav_probe.log`：`PROBE_OK`。型号相关：

| cue | peak | sec |
|---|---:|---:|
| fire | ~0.33 | 0.096 |
| fire_bolt | 0.297 | **0.308** |
| fire_garand | 0.325 | 0.136 |
| fire_smg | 0.313 | **0.080** |
| fire_mg | 0.315 | **0.260** |
| fire_mg42 | 0.380 | **0.420** |
| fire_pistol | 0.290 | 0.080 |
| fire_shotgun | **0.562** | 0.160 |
| fire_scout | 0.322 | 0.108 |

`SMOKE_OK_SFX_MODELS bolt=0.31 smg=0.08 mg=0.26 mg42=0.42`。时长可分。Dummy，**未耳听**，音频 **7.2** 封顶。

---

## 9. 触控

`08b`：提示「点队员/点地走 → 开匣搜枪 → 趴掩体 → 拉警报」。钮含 **需枪**（红）。  
`09`：桌面+触控 **强拉警报**。  
`37`：电台触控底栏 **需枪**，桌面双条关。弹包在电台可见。

`SMOKE_OK_ALARM_CTA 需枪` / `SMOKE_OK_TOUCH_NADE` / `SMOKE_OK_TOUCH_NO_DESKTOP_BARS`（既有）。无 adb 真机。触控 **9.1**（桌面像素 + 契约同步；真机仍空）。

---

## 10. 明确没过

- 真机院子拇指环；≥3 真人第一局搜刮（不要瞬间武装）。
- 28 型号里约 5 把未进作者匣。
- dump 开盖中途不够好看。
- sprite / 真 VO / FOW / 第 7 夜 / 合进 `main` 当正式发行。
- 警报中自由走位（契约故意砍）。
- 耳听枪声（本环境 Dummy）。

---

## 11. Top 剩余（不挡 9）

1. 真机 + 耳听 MG42 皮带 vs 栓动。
2. 真人搜刮局（院子+仓道），不要 `raid_prepare_ref`。
3. 情报条具名枪列表换行，别跟路线芯片抢。
4. 把剩余 5 把型号（MP38 / PPS-43 / 韦伯利 / TT-33 / 伊萨卡）各放进一夜匣或尸体。
5. dump 专门截一帧开盖 40%。

不要做的：第 7 夜、FOW、sprite、真 VO、把参考瞬间武装写成「玩家能这样通」。

---

## 12. APK 直链与安装

- 页：https://github.com/hailinsu-create/new/releases/tag/v0.3.1-commandos-ww2
- 直链：https://github.com/hailinsu-create/new/releases/download/v0.3.1-commandos-ww2/AmbushLoop-v0.3.1-commandos-ww2-playtest.apk
- 仓库副本：`ambush_loop/dist/AmbushLoop-v0.3.1-commandos-ww2-playtest.apk`
- 不要装 `AmbushLoop-playtest.apk` / 旧 `AmbushLoop.apk`（0.2.0 锁死观战）或 `AmbushLoop-v0.3.0-commandos-ww2-playtest.apk`（缺本刀）。
- 同包名：`versionCode` 3 覆盖 2。装完用 §3 印章确认。

---

## 附录：截图索引

| 文件 | 看什么 |
|---|---|
| `01_title.png` | v0.3.1 COMMANDOS/WW2 印章 |
| `02_howto.png` | 搜刮 / 需枪 / 打扫；手机行不再写锁死 |
| `04_pause_version.png` | 暂停 `v0.3.1 · COMMANDOS / WW2` |
| `08_scout_yard_knives.png` | 刀、需枪、9 匣标签 |
| `08b_touch_yard_needgun.png` | 触控 **需枪** |
| `09_scout_alarm_gate.png` | 强拉警报门 |
| `10_scout_crate_search.png` | 开匣中（日志 0.74 / 仍刀） |
| `11_scout_yard_kar98k.png` | **Kar98k 弹7/10** 开匣产物 |
| `13_scout_yard_m1911_cell.png` | M1911 匣在可行走格 |
| `14_fail_yard_knife.png` | 先搜匣拿到枪 |
| `17_alert_yard_w1.png` | **警报中 · 第1/2波** |
| `18_sweep_yard_w1.png` | 打扫 / 下一波警报 |
| `20_win_yard.png` | 封锁成功 cinema |
| `22_scout_warehouse_empty.png` | 无零逃逸残留；莫辛/MP40 |
| `33_credits.png` | **封锁成功 · 终夜** |
| `37_touch_radio_bars.png` | 电台触控需枪；春田/SVT-40 |

冒烟完整行见 `docs/eval_v0.3.1/smoke.log`。
