# Ambush Loop 试玩复盘评价（对外试玩门槛）

对象：Draft [PR #4](https://github.com/hailinsu-create/new/pull/4)，分支 `cursor/ambush-loop-mvp-6a41`  
基线：`ce9dd2d`（完成度 ~7.1，合进 main 可以，对外试玩不行）  
本评 HEAD：**94f38de42cd124b4a2b386c4e29d99d768587954**  
日期：2026-09-11  
评价人：窗口截图 + headless 冒烟 + 关卡/UI 源码走读（本环境无真机、无扬声器）

截图：`docs/eval_playable/`  
冒烟日志：`docs/eval_playable/smoke.log`  
上一次评价：`docs/Ambush_Loop_试玩评价_ce9dd2d.md`

---

## 证据分级

| 标 | 含义 | 本报告里用在哪 |
|---|---|---|
| **实测** | 本机跑过 | Godot 4.7.2 headless 冒烟 ~126.6s / exit 0；`DISPLAY=:1` 窗口 1280×720 截了标题→院子布置/朝向/失败牌/卷宗→电台空/参考/观战→触控底栏 |
| **源码** | 读了契约/UI/模拟 | `level_def.gd`、`main.gd`、`grid.gd`、`smoke_test.gd`、触控底栏、时间轴 |
| **推演** | 没真人、没真机、没耳朵 | 第一眼困惑、手机拇指热区、程序音是否「好听」 |

未开第 7 夜 / FOW / sprite / 真 VO。硬规则未改。

---

## 一句话总评

十条对外试玩门槛全部打掉：布置期只留一层教学，失败是三行牌，电台有独立回波路且第一败对齐暗道，触控不再叠桌面底栏，冒烟全绿并记下六夜「典型败→改一处→胜」。

**可对外试玩：是。**

**完成度（对外试玩门槛加权，1–10）**

| 维 | 分 | 一句话 |
|---|---:|---|
| 玩法 | **9.2** | 硬规则仍在；电台回波是第四条作者路，不再是东廊那支铁砧 |
| 内容 | **9.0** | 前四夜课还在；油库三路 vs 电台碟缝回波能分夜 |
| 手感 | **9.1** | 布置期能读图；失败三行；观战 t=6.2s 打出「灯塔回波到了」 |
| 美术 | **7.8** | 仍是多边形原型；电台磷光夹缝+碟台能从油库里认出来。未做 sprite（本轮禁止） |
| 音频 | **7.0** | tension 加长加响，cue 表仍全是程序蜂鸣。未做主题/VO（本轮禁止） |
| 叙事 | **8.4** | 六夜链、幕间、档案、致谢未拆；终夜课从「再加一根绊索」变成「暗道然后回波」 |
| 触控 | **9.2** | 触控底栏打开时桌面双条隐藏；南闸/逃逸口露出来。真机未摸 |

门槛加权（玩法/内容/手感/触控）**= 9.2 / 10**。  
七维均分 **8.5**（美术/音频按延期项，不挡朋友包）。

对照 `ce9dd2d` 总评 ~7.1：叠字、卷宗、电台克隆、朝向一词两意、清单压卡、触控双条是本轮收的。

---

## 十条门槛对照

| # | 门槛 | 状态 | 证据 |
|---|---|---|---|
| 1 | 布置期不叠字 | **过** | `02_setup_yard_empty.png`：顶栏一句 beat、图例芯片、时间轴、虚线第二层。tut 板/双 beat 条/双「第二层」标签关掉。冒烟 `SMOKE_OK_TEACHING_SINGLE` |
| 2 | 失败三行牌 | **过** | `04_fail_yard_card.png`：漏网 / 改一处 / CTA +「卷宗」。逃逸口仍在。冒烟 `SMOKE_OK_FAIL_CARD` |
| 3 | 电台不复制油库 | **过** | `06`/`07`/`08`：青线「回波·碟缝」、碟台朝南、东廊夜枭。契约 `routes=4`。参考胜 tick **730** |
| 4 | 第二层对齐第一败 | **过** | 无绊索漏 sneak 敌3 tick 1502；`second_trap_route=sneak`；失败文案「没打中第二层」含暗道。冒烟 `SMOKE_RADIO_TRAP_MISS_NOT_SNEAK` |
| 5 | 一个词一个朝向 | **过** | `03_setup_yard_facing.png`：状态「射界朝东 · 掩体保护朝西」；罗盘标「射界」。冒烟 `SMOKE_OK_FACING_WORDS` |
| 6 | 清单不叠左卡 | **过** | 清单顶栏右侧、时间轴旁。冒烟 `SMOKE_CHECKLIST_OVER_CARDS` 改查矩形相交 |
| 7 | 触控隐藏桌面双底栏 | **过** | `09_touch_radio_bars.png`：只剩触控条。冒烟 `SMOKE_OK_TOUCH_NO_DESKTOP_BARS` |
| 8 | 未到波次身体感 | **过** | 时间轴未到点呼吸；下一波 1.2s 内打 `tension`。观战截图 t=6.2s「灯塔回波到了」。冒烟 `SMOKE_OK_PENDING_BREATH` / `SMOKE_OK_TENSION` |
| 9 | 冒烟全绿 + 典型败→改一处→胜 | **过** | exit 0 ~126.6s；`SMOKE_OK_TYPICAL_LOOPS`；见下表 |
| 10 | 复评总分 >9、可对外试玩 | **过** | 门槛加权 **9.2**；**可对外试玩：是** |

不要做的事（本轮遵守）：第 7 夜、FOW、sprite、真 VO。

---

## 典型败 → 改一处 → 胜（冒烟记录）

| 关 | 典型败 | 改一处 | 胜 |
|---|---|---|---|
| 院子 | 西掩体朝东 → 敌3 flank 0.4s tick 965 | 铁砧转东箱 | slots 1,2,5 / 90,180,180 tick **283** |
| 仓道 | 同站位不入伏 → 敌5 flank tick 1419 | F 入伏 + G 弹包铁砧 | tick **872** ambush+repack |
| 泵站 | 锁门旧朝向 → alt tick 1052 | 铁砧改朝西 | 锁门 90/180/180 tick **740** |
| 信号楼 | 南闸堆人 → 敌3 flank tick 1191 | 铁砧朝北等 3.8s | 1,4,5 / 270,270,180 tick **818** |
| 油库 | 无绊索 → 敌3 sneak 2.2s tick 1418 | Tab (7,11) | tick **572** |
| 电台 | 无绊索 → 敌3 sneak 3.6s tick 1502 | 绊索 + 铁砧碟台朝南 | 1,4,5 / **270/90/270** + trip tick **730** |

电台参考通关已改：铁砧不再用东廊朝北兼打回波。

---

## 分段

### 布置期

`02` 相对 `ce9dd2d` 的 20 层叠字： tut 板关掉，地图 beat 条关掉，第二层只留虚线标签，清单离开左卡。还在的是**该在的图例**：路线染色、时间轴点、一句 beat。左卡脚不再碎「射界覆盖主路」。

`03` 把青弧/黄锥写成两个词。坏计划（保护西、射界东）一眼能读。

### 失败

`04` 是牌不是卷宗。漏网一行、改一处一行、穿梭 CTA、卷宗进二级。地图缺口和逃逸口还在。`05` 打开卷宗后信息墙回来，默认路径不必读完。

### 电台

空布置能看见四条路：红脊、橙东廊、绿暗道、青碟缝。虚线第二层写「暗道 3.6s 要绊索」，回波 5.2s 单独标在夹缝上。观战 `08` t=6.2s 铁砧在碟台朝南吃回波，夜枭锁东廊，西墙绊索还在——终夜独特一枪是新站位。

### 触控

`09` 桌面 ExtraBar + BottomBar 关掉，只留触控命令条。逃逸口没有被 156px 双条吃掉。真机未跑，代码和窗口强制触控已断言。

### 观战等待

时间轴对未到点呼吸；回波进场有「灯塔回波到了」和 echo_ping。tension 加长。无扬声器，标冒烟 `last_cue=tension`。

---

## 冒烟

```
Godot Engine v4.7.2.stable.official.ed1daf0bf
SMOKE_OK_LAUNCH_BAR …
SMOKE_OK_TEACHING_SINGLE
SMOKE_OK_FAIL_CARD
SMOKE_OK_TOUCH_NO_DESKTOP_BARS
SMOKE_OK_FACING_WORDS
SMOKE_OK_PENDING_BREATH
SMOKE_OK_RADIO_CONTRACT covers=6 routes=4 sneak=3.6 echo=5.2
SMOKE_RADIO_NO_TRIP_FAIL route=sneak leaker=3 tick=1502
SMOKE_OK radio won tick=730
SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio
SMOKE_SLICE_COMPLETE
exit 0   ~126.6s
```

无 `ERROR:` / 无非预期 `SMOKE_FAIL_*`。

---

## 合进 main / 对外试玩

**合进 main：** 可以（基线已经可以；本轮没有拆硬规则）。

**对外试玩：可以。** 给不认识参考通关的人：布置期能看见地图，失败先看三行，电台第一败是暗道，修好之后才是回波。

美术/音频仍是 jam 原型，不挡「朋友包」。真机 APK 仍需本机模板；本环境截的是窗口强制触控，不是手机。

---

## 附录 — 关键路径

- 关卡：`scripts/level/level_def.gd`（电台 `echo` 路、`second_trap_route=sneak`）
- 网格：`scripts/grid.gd` `_build_radio` 碟缝 + 报机架
- HUD/失败/触控：`scripts/main.gd`
- 朝向：`scripts/operator.gd` 罗盘「射界」
- 时间轴：`scripts/ui/route_timeline.gd` pending breath
- 冒烟：`scripts/smoke_test.gd`
- 截图：`docs/eval_playable/*.png`

HEAD：`94f38de42cd124b4a2b386c4e29d99d768587954`
