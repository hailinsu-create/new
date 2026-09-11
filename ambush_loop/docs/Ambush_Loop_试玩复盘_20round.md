# Ambush Loop 20 轮迭代交付

对象：分支 `cursor/ambush-loop-mvp-6a41`  
基线复盘：`docs/Ambush_Loop_试玩复盘_0de4f1d.md`（门槛加权 **8.6**，朋友包可发，不是 9.5）  
玩法代码停点之前：`94f38de` / docs HEAD `634d807`  
本轮 HEAD：`76a7f3285646c5831238bfc8c6348efc5053a557`（本文件为第 20 个 commit）  
日期：2026-09-11

未开第 7 夜 / FOW / sprite / 真 VO。未混旁窗/Live2D/墨汐。  
硬规则未改：警报锁死、作者路线、逃逸/全灭失败、情报+计划跨世、tick 指纹。

---

## 选型理由

朋友包痛点全是读图和听感，不是规则。大改优先打：

1. **失败牌 / 通关 CTA / 情报条** — 契约绿、画面红。改 HUD 层级，不改三行文案契约。
2. **电台远看仍是油库** — 机制已有第四条路；把 `grid._build_radio` 从罐区矩形改成灯塔+碟阵+报机架，覆盖格与作者路不动。
3. **仓道第二层误读** — 虚线仍走 flank（漏网真路），标签挪到黄区，文案改成 F 入伏。
4. **音频** — Dummy 不能当耳朵，但可以把枪声/漏网/回波做成有体的 PCM，并用 headless 峰值证明「不是细蜂鸣」。
5. **美术** — 继续程序多边形，但拉开夜身份：灯塔、碟、磷光廊 vs 油罐危橙。

参考通关未改：yard 1,2,5 / warehouse 1,3,5 hold+pack / pump 开锁两套 / railcut 1,4,5 / depot+radio 绊索 `(7,11)`，电台铁砧碟台朝南。

---

## 20 轮清单

| # | SHA | 轨 | 做了什么 |
|---|---|---|---|
| 1 | `092bd36` | A | 失败牌居中下缘，左卡失败/通关掉掉；ExtraBar 不压 CTA；情报改芯片 |
| 2 | `d86bd34` | B | 电台几何：灯塔塔身 + 发射厅 + 碟簇 + 加高报机架 |
| 3 | `2583488` | A/D | 时间轴 回5.2 在到达前 2.4s 大声呼吸 |
| 4 | `79dcc37` | C | 回波敌人更高磷光桅 |
| 5 | `0bdfc75` | B | 仓道第二层：等黄区 / F 入伏，不是站爆心外 |
| 6 | `954b918` | A | 简报去掉与「必须带」重复的子弹 |
| 7 | `7d52ffb` | A | 战役档案改六夜图板，4–6 夜不用滚 |
| 8 | `3740d1c` | B | 第二层标签钉在 `second_trap_cell`（仓道钉黄区） |
| 9 | `074c381` | C | 电台夜光洗碟缝；油库保持钠灯 |
| 10 | `c8998d9` | D | 枪声噪声+低频体；漏网脚步+嘶；回波尾；幕间/tension 分开 |
| 11 | `80dee94` | D | 分层循环床：电台载波+摩斯，油库柴油，泵 58Hz |
| 12 | `3dfca23` | C | 回波敌人独立瘦身+青视镜 |
| 13 | `9ff0b9c` | C | 电台掩体垫是碟+短桅 |
| 14 | `de634b1` | C | 地图灯塔/碟阵/磷光廊，远看不再是油罐换色 |
| 15 | `86f03a9` | C | 队员肩章闪与 Rim，三套 kit 一眼分 |
| 16 | `6437abb` | C | 天空从灯塔灯室扫，磷光粒子走 x=24 |
| 17 | `b337403` | D/E | headless WAV 探针，Dummy 下仍能量化枪声体 |
| 18 | `dd1199b` | E | 冒烟：失败牌不咬左卡、CTA 不被键条埋、情报不压时间轴、电台非罐区 |
| 19 | `9bf30cc` | C | 油桶 vs 碟垫、回波桅尖 |
| 20 | （本文件） | E | 交付复盘 |

纯 docs = 本 1 篇。

---

## 各轨

### A UI / 读图
- 失败三行牌：左轨隐藏，卡片锚在屏幕底中（560px 宽），逃逸口仍在东南，`result_panel_covers_escape` 绿。
- 通关/致谢：结果层 `z_index=50` + 关掉 ExtraBar/BottomBar，CTA 最小高度 44。
- 情报：TopBar 第三行关掉；漏网建议/计划恢复变成时间轴下方 ≤28 字芯片。
- 简报不再印两遍「必须带」。档案六夜一屏。

### B 关卡 / 内容
- 电台几何不再拷油库矩形。`(15,8)` 打开（油库仍堵），灯塔占 `(17–20,8–11)`，碟墙/报机架加高到 y=12。作者路、6 掩体、绊索 `(7,11)`、回波 x=24、碟台朝南 LOS **未改用途**。
- 仓道 `second_trap_route` 仍是 `flank`；文案和标签改成黄区入伏。

### C 美术
- 灯塔桅 118px、东廊三只大碟、磷光廊 11 格刻度。
- 油库夜光仍是危橙钠灯+罐圆，和电台青磷光对打。
- 灰狼/铁砧/夜枭肩闪；回波敌人青桅。

### D 音频
- 仍是 `AudioStreamWAV` PCM，**不是** `AudioStreamGenerator`（headless 不泄漏 Playback）。
- Dummy：`play()` 在 headless 直接 return，只写 `last_cue`。
- 耳听：本机无扬声器。用 `godot --headless -s res://scripts/sfx/wav_probe.gd` 量化：

```
fire peak=0.30  ui=0.12  tension=0.41  echo_ping=0.28 sec=0.84
leak sec=0.69  handoff=0.45  ambient_radio=0.72
```

冒烟 `SMOKE_OK_SFX_BODY fire=0.34 tension=0.42 echo=0.28`。

### E QA
- headless 冒烟 **exit 0**，~126.6s。
- 新门：`SMOKE_OK_FAIL_CARD_CLEAR` `SMOKE_OK_WIN_CTA_CLEAR` `SMOKE_OK_INTEL_CHIP` `SMOKE_RADIO_CONTRACT … breath=1` `SMOKE_OK_SFX_BODY`。
- 参考 tick **未变**（指纹仍咬死）：

| 关 | 探针 | tick |
|---|---|---:|
| yard 逃 | 西掩体朝东 | 965 |
| yard 胜 | 1,2,5 90/180/180 | 283 |
| warehouse 不入伏 | | 1419 |
| warehouse 入伏+弹包 | | 872 |
| pump 开 | | 694 |
| pump 锁旧朝向 | | 1052 |
| pump 锁新朝向 | | 740 |
| railcut 南堆 | | 1191 |
| railcut 胜 | | 818 |
| depot 无绊索 | | 1418 |
| depot 胜 | | 572 |
| radio 无绊索 | sneak 3.6s | 1502 |
| radio 胜 | 碟台朝南+绊索 | 730 |

窗口 31 张 PNG 本轮未重截（DISPLAY=:1 在，时间给了冒烟契约）。失败/通关/情报改用矩形相交断言代替「字符串在、字不在」。

---

## 破坏性大改与契约

硬规则未动。同步了的契约：

| 项 | 旧 | 新 |
|---|---|---|
| 电台 blocked 轮廓 | 油库矩形 + 两块附加 | 灯塔/发射厅/碟簇/加高架。冒烟加 `(15,8)` 必须空、`(17,9)(19,10)` 必须堵 |
| 仓道第二层文案 | 「过早开火会打空」钉在脊 `(13,14)` | 「等黄区再打（F 入伏）」钉在 `(17,12)`。路线仍 flank |
| 失败牌停靠 | 左下，被左卡咬 | 底中，左卡隐藏 |
| ExtraBar | 通关时压 CTA | 失败/通关隐藏 |
| 情报条 | TopBar 长句横切时间轴 | 轴下芯片 |

参考通关 **没有** 改 slot/朝向/绊索格。

---

## 相对 8.6 的预期

不是真人局，是读图契约 + PCM 体。对照复盘虚高项：

| 维 | 0de4f1d | 本轮预期 | 依据 |
|---|---:|---:|---|
| 玩法 | 8.9 | **9.1** | 失败牌可读；仓道课对齐黄区 |
| 内容 | 8.4 | **8.9** | 电台骨架不再是同一座罐区 |
| 手感 | 8.5 | **8.8** | 恢复计划不糊时间轴；回波等待有呼吸 |
| 美术 | 7.4 | **8.3** | 灯塔/碟/磷光 vs 油罐；仍是多边形 |
| 音频 | 5.5 | **6.8** | PCM 有体；Dummy 仍不能打「好听」 |
| 叙事 | 8.1 | **8.4** | 六夜图板 |
| 触控 | 8.6 | **8.6** | 真机未摸 |

门槛加权（玩法/内容/手感/触控）**8.6 → ~9.0**。  
七维均分 **7.9 → ~8.4**。  
**不是 9.5**：没有陌生人第一局记录，没有真机拇指，没有耳朵。

**可对外试玩：是（朋友包）。** 比 8.6 那包更值得发；仍不要写成正式版读图。

---

## 关键路径

- HUD：`scripts/main.gd` `_dock_fail_result_panel` `_raise_result_overlay` `_refresh_intel_chip`
- 电台几何：`scripts/grid.gd` `_build_radio`
- 仓道课：`scripts/level/level_def.gd` `second_trap_*`；`scripts/fx/trap_path_fx.gd`
- 灯塔：`scripts/map_draw.gd` `_landmark_radio` / `_silhouette_radio_dish`；`scripts/fx/mission_sky.gd` `_draw_radio`
- 音频：`scripts/sfx/sfx_bus.gd` `scripts/sfx/audio_director.gd` `scripts/sfx/wav_probe.gd`
- 冒烟：`scripts/smoke_test.gd`

HEAD 以本 commit 为准。
