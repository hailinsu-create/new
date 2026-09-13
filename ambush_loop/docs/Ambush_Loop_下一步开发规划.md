# Ambush Loop 下一步开发规划

版本：制作人切片规划 · 2026-09-11  
对象：分支 `cursor/ambush-loop-mvp-6a41`，HEAD **`2003419`**（`docs(eval): 20-round playable-bar recap, layout and radio mast-hall`）  
Draft PR：[PR #4](https://github.com/hailinsu-create/new/pull/4) → `main`（`main` 仍是空壳 `6451db5`）  
本文件**只规划，不改游戏代码**。不按日历天数排期；范围用改动面、文件所有权与验收闸门描述。

对照（按时间倒序，分数口径不要混）：

| 文档 | HEAD / 停点 | 口径 | 分数 |
|---|---|---|---|
| `docs/Ambush_Loop_试玩评价_ce9dd2d.md` | `ce9dd2d` | 叠字/克隆期 | ~7.1，当时**不能**当对外包 |
| `docs/Ambush_Loop_试玩评价_playable.md` | `94f38de` | 十条门槛**契约** | 自称门槛加权 **9.2**（后被下调） |
| `docs/Ambush_Loop_试玩复盘_0de4f1d.md` | `0de4f1d`（玩法停 `94f38de`） | **窗口 31 张 PNG + 冒烟**独立复盘 | 门槛加权 **8.6**；朋友包可发，不是 9.5 |
| `docs/Ambush_Loop_试玩复盘_20round.md` | 玩法 `9bf30cc` / docs `2003419` | 20 轮 HUD/电台/仓道课/PCM **自评** | 门槛加权 **~9.0**；**未重截** 31 张 |
| `docs/LAUNCH_BAR.md` | 功能清单 | Steam 小品功能条 | 自评 7.7（功能在，不是读图分） |
| `docs/开发规划.md` | v3 · 2026-09-09 | 安卓侧载为首发 | **部分过时**（第 6 夜已进仓、触控 preset 已进仓）。**下一刀以本文件为准。** |

玩法已改为搜刮/多波警报/打扫继承。作者路线、逃逸/全灭失败仍有效。跨失败世不继承装备；跨波次继承。  
未开第 7 夜 / FOW / sprite / 真 VO。未混旁窗 / Live2D / 墨汐。

---

## 0. 一句话

**朋友包已经能发；正式版差的不是第 7 夜，是证据。**

20 轮把 `0de4f1d` 点名的读图债在**代码和冒烟矩形**里收了（失败牌居中、CTA 抬层、情报芯片、电台灯塔几何、仓道黄区文案、PCM 体、档案图板）。但同一份复盘写明：**窗口 31 张 PNG 本轮未重截**。上一份独立复盘能打脸的，正是「契约绿、画面红」。

所以下一步不是再堆一层程序粒子，也不是合 `main`。下一步是：

1. 用**新窗口 dump** 证明 20 轮读图真过了（或找出还红的那几张）；
2. 用**陌生人第一局 / 真机拇指 / 耳朵**把 ~9.0 从自评变成可对外说的分；
3. 只在六夜内部补疲劳与辨识，不扩系统。

没有这三块，再加夜、加 FOW、加 sprite，分数不该动。

---

## 1. 现状定位：朋友包 vs 正式版

### 1.1 朋友包（已达到）

给认识你、能容忍 jam 多边形、愿意读三行失败牌的人：

- 六夜可玩：`yard` → `warehouse` → `pump` → `railcut` → `depot` → `radio`（`GameSettings.LEVEL_ORDER`）。
- 核心环成立：标题 → 选关/简报 → SETUP → 警报冻结 → WATCHING → 逃逸/全灭/中止穿梭或通关 → 幕间 → 终夜致谢/档案。
- Headless 冒烟全绿：`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`，约 126s，`SMOKE_SLICE_COMPLETE` / `SMOKE_OK_LAUNCH_BAR` / `SMOKE_OK_TYPICAL_LOOPS`，exit 0。参考 tick 与 `0de4f1d` 附录 A **一致**（见 §7.5）。
- 启动壳是成品：`scenes/title.tscn`、战役档案、简报、操作说明、Esc 设置、Music/SFX、安卓 preset。
- 安卓工程底座已进仓：`export_presets.cfg` Android APK（`com.ambushloop.game`、arm64、横屏、ETC2）、`TouchHud`、返回键不杀进程、省电档、`map_draw` 静态缓存。`dist/AmbushLoop.apk`（约 28MB）在仓里，**不是真机证据**。
- 20 轮之后，朋友包比 8.6 那包更值得发——前提是发**分支包**，文案写「程序多边形 + 合成音的夜间战术小品」，不要写成正式版读图。

### 1.2 正式版 / 9.5 还差什么（按证据，不是按感觉）

| 缺口 | 为什么挡正式版 | 证据 |
|---|---|---|
| **窗口 dump 过期** | 20 轮改的正是 `10`/`13`/`22`/`26` 那种构图；旧 PNG 仍是左卡咬字、CTA 被键条压、电台像油库 | `docs/eval_0de4f1d/` 停在 `0de4f1d`；`20round.md` 明确「本轮未重截」 |
| **陌生人第一局** | 六夜「典型败→改一处→胜」全是 `_deploy_ref`，证明规则，不证明第一眼 | `0de4f1d`：没有这页就不要报 9.5 |
| **真机拇指** | 触控底栏、拖旋转、刘海、横屏安全区只在窗口 `force_touch_hud` 和冒烟里 | `31_touch_radio_bars.png` 是桌面强制触控；`docs/ANDROID.md`：云端 `adb` 为空 |
| **耳朵** | Dummy 下 `SfxBus.play()` 直接 return；`SMOKE_OK_SFX_BODY` 只证明 PCM **峰值** | `scripts/sfx/sfx_bus.gd`；`wav_probe.gd` 可写 `/tmp/ambush_cues`，**没人听过** |
| **美术身份** | 灯塔/碟/磷光 vs 油罐危橙已进代码；仍是 `_draw` 多边形，不是商店页 | `map_draw._landmark_radio`、`grid._build_radio`；sprite 管线不存在 |
| **音频身份** | 枪声有低频体、分夜循环床、回波 ping；仍是 `AudioStreamWAV` 合成，不是主题/VO | `sfx_bus.gd` `CUES` + `ambient_*`；禁止 `AudioStreamGenerator`（headless 会漏 Playback） |
| **`main` 空壳** | 可玩内容 147 文件 / +29792 行只在本切片；合进去等于把未像素验收的自评写进默认分支 | `git diff origin/main...HEAD` |

**完成度口径（制作人，不要再把契约分写成读图分）：**

| 维 | `0de4f1d` 实测 | 20 轮自评 | 正式版还要什么 |
|---|---:|---:|---|
| 玩法 | 8.9 | 9.1 | 陌生人能从三行牌改一处；非参考站位不迷路 |
| 内容 | 8.4 | 8.9 | 电台远看不再像油库（**像素**）；仓道课在黄区（**像素**） |
| 手感 | 8.5 | 8.8 | 第二世恢复计划不糊；观战等待有身体感；可跳到漏网 |
| 美术 | 7.4 | 8.3 | 六夜剪影可并排认出；仍允许多边形 |
| 音频 | 5.5 | 6.8 | 耳听枪声/漏网/回波/床不糊、不吵 |
| 叙事 | 8.1 | 8.4 | 档案图板截到；简报不再是墙 |
| 触控 | 8.6 | 8.6 | **真机**院子一圈：点卡→点掩体→拖射界→警报 |

门槛加权（玩法/内容/手感/触控）：**8.6 像素分 → 自评 ~9.0 → 正式版要 9.5 必须另开真人+真机+耳朵。**  
七维均分：7.9 → 自评 ~8.4。美术/音频按延期项，不挡朋友包，**挡商店页**。

### 1.3 代码体量（并行时的真实约束）

| 文件 | 行数 | 含义 |
|---|---:|---|
| `scripts/main.gd` | 6887 | 阶段机、HUD、输入、模拟协调、失败牌、情报芯片全在这。**多 agent 最大撞车点。** |
| `scripts/smoke_test.gd` | 4182 | 回归网；改契约必须改这里，不能只改画面 |
| `scripts/map_draw.gd` | 1270 | 六夜墙语/地标 |
| `scripts/level/level_def.gd` | 755 | 关卡仍内嵌 GDScript，无 `data/levels/*.tres` |
| `scripts/sfx/sfx_bus.gd` | 733 | 全部 PCM 合成 |

蓝图里的 `combat_sim.gd` / `data/levels/*.tres` **仍未拆**。下一刀不要借「架构正确」重写模拟；要拆就只拆 HUD 查询函数，且必须带着既有冒烟门。

---

## 2. 目标分层（技术切片，不排日历）

四层是**退出条件**，不是周次。P0 没出，不准开 P2 内容；P1 没出，不准把音频写成「已过耳」；P3 是包装，不是玩法。

### P0 · 正式试玩可读（把 ~9.0 变成像素分）

目标：不认识参考通关的人，在 **1280×720 窗口**里能完成「看见地图 → 看懂失败三行 → 改一处再警报」，且 20 轮宣称修掉的构图在新截图里成立。

切片：

1. **重跑战役路径窗口 dump**（新目录，例如 `docs/eval_2003419/`），复用 `scripts/eval_dump_0de4f1d.gd` 的战役链（不要 `_load_level("radio")` 热切，避免把院子情报条带到终夜、避免旧的 Tween `Infinite loop`）。
2. **读图锁门**（dump 红才改代码，dump 绿则冻结）：
   - 失败牌：标题「失败 · 逃逸」和「漏网：」完整可见；左轨关闭；东南逃逸口仍露。探针已有：`fail_card_bitten_by_rail()` / `result_panel_covers_escape()` / `SMOKE_OK_FAIL_CARD_CLEAR`。
   - 通关/致谢 CTA：`下一关` / `查看致谢` 不被 ExtraBar/BottomBar 咬。探针：`result_cta_buried_by_bars()` / `SMOKE_OK_WIN_CTA_CLEAR`。
   - 情报芯片：≤28 字、轴下、不与时间轴相交。探针：`intel_chip_overlaps_timeline()` / `SMOKE_OK_INTEL_CHIP`。
   - 电台远看：灯塔桅 + 碟阵，`(15,8)` 空、`(17,9)(19,10)` 堵。探针：`SMOKE_RADIO_STILL_TANK_RECT` / `SMOKE_RADIO_NO_TOWER`。并排油库 `19` vs 电台 `22` 的新图。
   - 仓道课：标签在 `second_trap_cell=(17,12)`，文案「等黄区再打（F 入伏）」；**路线仍是 `flank`**（故意不改漏网真路）。新图必须能看出黄区，而不是「站爆心外」。
   - 档案：六夜一屏图板，4–6 夜不用滚（`campaign_journal.gd` 已改 board；旧 `03`/`29` 是文章）。
3. **至少 1 次陌生人第一局**（朋友即可）：只记第几世懂、卡在哪、改的是站位/朝向/F/G/Tab 中的哪一处。没有这页，P0 不算退出。

P0 **不**包含：新关、FOW、sprite、真 VO、合 `main`。

### P1 · 听感与辨识（多边形内部把夜认出、把枪听出）

目标：闭眼能分油库/电台床；睁眼能分灰狼/铁砧/夜枭/回波敌人；枪声不是 UI 蜂鸣。仍**不**上 sprite 管线、不上真 VO。

切片：

1. **耳听闸门**：本机扬声器（或把 `godot --headless -s res://scripts/sfx/wav_probe.gd` 写出的 WAV 拷出来听）。必听：`fire` / `fire_mg` / `tension` / `echo_ping` / `leak` / `ambient_depot` / `ambient_radio`。记录：是否掩蔽、是否刺耳、是否六夜床撞车。
2. **混音只动 gain/PCM 体，不动规则**：`SfxBus._gain`、`_crack` / 分夜 `ambient_*`。Dummy 路径保持 `play()` 早退。
3. **剪影锁身份**：`operator_silhouette.gd` 肩闪已进；`enemy_silhouette` 回波青桅已进。P1 要的是 dump 里「三人 + 回波」一眼可数，不是新骨骼。
4. **电台/油库并排剪影**：`map_draw._landmark_radio` vs depot 罐圆；`night_keys.gd` 磷光洗 vs 钠灯。若新 dump 远看仍像换色罐区，只加大灯塔/碟/廊刻度，**不改** `cover_defs` / 作者路 / 绊索格。

### P2 · 内容扩展（只在六夜内部）

目标：同一套硬规则下，减少「我看懂了还要看完漏网走路」、减少第二世糊、减少非参考站位失语。**不是第 7 夜。**

切片：

1. 观战「看懂了 → 跳到漏网终局」（只读 seek / 快进到 terminal tick，不改冻结计划）。现在只有 `X` 中止（`_on_abort_pressed`），中止是失败并留情报，但**不能跳到漏网那一帧**。`0de4f1d` 点名这是观战疲劳。
2. 第二世恢复计划：空布置的干净不能在 `12`/`24` 作废。情报芯片已限 28 字；P2 看新 dump，若仍咬时间轴/清单，再收状态条、弹包绿条。
3. 非参考站位的失败牌仍能「改一处」：绊索放错廊、入伏等到没窗口、四人位组合。冒烟目前只咬参考通关与典型败。
4. 简报墙：`954b918` 已去掉重复「必须带」；`05_briefing_yard.png` 仍是 situation + 五条教学 + 底部键表。P2 可把键表留给操作说明，简报只留夜次/必须带/一条陷阱。
5. **不要**外置 `.tres`、不要拆 `combat_sim.gd`，除非 P0/P1 被 `main.gd` 撞车逼到必须抽 HUD 查询。抽文件不是玩家可感知迭代。

### P3 · 发行包装（侧载可给外人，不是商店首发）

目标：分支上的朋友包变成「拷 APK / 桌面包就能玩」的包装，**仍不必合 `main`、不必 Play AAB**。

切片：

1. 本机导出 Android debug APK + 真机冷启动（`docs/ANDROID.md` 已有命令）。云端虚机不能代替。
2. 真机：院子一局（胜或败均可）、横屏、返回键打开暂停、切出音频不泄漏（`AudioDirector.pause_for_background` 已进仓）。
3. 包体/图标：现有 `icon.svg` 占位可保留；商店截图、隐私政策、release keystore、AAB **后置**。
4. 对外文案：标明六夜、程序美术、合成音、横屏。不要用 9.5 / 正式版字样。
5. 合 `main` 只在 §6 清单全勾之后。Draft PR #4 保持 Draft，直到清单说可以。

---

## 3. 多 agent 分轨

并行原则：**模拟、路线、掩体、参考 tick 冻结。** 各轨只动表现/HUD/输入/验收脚本。`main.gd` 是共享锁：同一时刻最多一个 agent 改它；其他轨走旁路文件或先提「要 main 暴露哪个查询函数」。

冒烟命令（每轨结束必跑）：

```bash
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
```

必须：exit 0，无非预期 `SMOKE_FAIL_*`（`SMOKE_FAIL_ESCAPE` 是院子故意漏网），参考 tick 表不变（§7.5）。

### 3.1 UI / 读图

| | |
|---|---|
| **目标** | 失败三行、通关 CTA、情报芯片、简报、档案、幕间在**像素**上成立；第二世不把空布置的干净吃掉。 |
| **关键文件** | `scripts/main.gd`（`_dock_fail_result_panel` `_raise_result_overlay` `_refresh_intel_chip` `_apply_result_rail` `_sync_desktop_bars` `_hide_duplicate_tut`）；`scripts/ui/route_timeline.gd`；`scripts/ui/campaign_journal.gd`；`scripts/ui/night_handoff.gd`；`scripts/ui/credits_overlay.gd`；`scripts/ui/tutorial_overlay.gd`；`scripts/ui/op_card.gd`；`scripts/title.gd`（简报/操作说明） |
| **验收** | 新窗口 dump：失败牌不被左卡咬；CTA ≥44px 且无键条相交；情报芯片不交时间轴；档案六夜一屏；简报「必须带」不重复。冒烟门保持 `SMOKE_OK_FAIL_CARD_CLEAR` `SMOKE_OK_WIN_CTA_CLEAR` `SMOKE_OK_INTEL_CHIP` `SMOKE_OK_TEACHING_SINGLE` `SMOKE_OK_JOURNAL`。 |
| **风险** | `main.gd` 6887 行，改停靠易连带触控底栏/清单/逃逸口。失败牌 560px 底中已经给东南口让路——不要改回左下。字符串契约绿 ≠ 字可见：必须矩形相交 + PNG。 |

### 3.2 关卡 / 教学

| | |
|---|---|
| **目标** | 六夜各一课继续对齐第一败；仓道课在黄区；电台四路（红脊/橙东廊/绿暗道 3.6s/青回波 5.2s）不被油库模板吃回去。 |
| **关键文件** | `scripts/level/level_def.gd`（`second_trap_*` `make_radio()` `make_warehouse()` `fix_one` `spawn_teaching`）；`scripts/grid.gd` `_build_radio` / `_build_depot`；`scripts/fx/trap_path_fx.gd`；`scripts/fx/intel_path_ghost.gd`；`scripts/fx/spawn_ghost.gd` |
| **验收** | 电台 `routes=4`、`second_trap_route=sneak`、无绊索第一败仍是敌3 sneak tick **1502**；仓道 `second_trap_route` **仍是 `flank`**、文案/标签在 `(17,12)`；参考通关 slot/朝向/绊索格不动（见 README 与 §7.5）。冒烟：`SMOKE_OK_RADIO_CONTRACT` `SMOKE_RADIO_NO_TRIP_FAIL` `SMOKE_OK_TYPICAL_LOOPS`。 |
| **风险** | 改 `grid.blocked` 会拖 LOS/部署/绊索合法格。电台灯塔占 `(17–20,8–11)`、`(15,8)` 必须空——这是相对油库的身份差，回退就变回「罐区换色」。仓道若把 `second_trap_route` 改成别的，第一败（敌5 flank tick 1419）会对不齐。 |

### 3.3 美术 / 夜身份

| | |
|---|---|
| **目标** | 程序多边形内部拉开夜：院子橄榄、仓琥珀钠灯、泵青绿、楼混凝土双廊、库危橙罐、台灯塔+碟+磷光廊。三人 kit 一眼分；回波敌人不是换色巡卫。 |
| **关键文件** | `scripts/map_draw.gd`（`_landmark_radio` `_silhouette_radio_dish` 及各关 landmark）；`scripts/fx/mission_sky.gd`；`scripts/fx/night_keys.gd`；`scripts/fx/night_grade.gd`；`scripts/fx/operator_silhouette.gd`；`scripts/fx/enemy_silhouette.gd`；`scripts/fx/ambush_zone_fx.gd`；`scripts/fx/combat_fx.gd`；`scripts/fx/muzzle_flash.gd`；`scripts/ui/role_glyph.gd`；`scripts/ui/title_backdrop.gd` |
| **验收** | 新 dump 并排：油库罐圆+钠灯 vs 电台 118px 桅+东廊大碟+x=24 磷光刻度。SETUP 空布置仍能读路线色，不靠再叠字。省电档关掉粒子后身份还在（剪影/墙语，不是拖尾）。冒烟：`SMOKE_OK_PROPS` `SMOKE_OK_IDENTITY` `SMOKE_OK_READABILITY` `SMOKE_OK_PERF_TIER`。 |
| **风险** | 地标画进 `blocked` 格才安全；画进走格会骗玩家。不要为了「更像灯塔」去挪 `cover_defs`（碟台 `(24,6)` 朝南是终夜那一枪）。sprite 管线是明确不做。 |

### 3.4 音频

| | |
|---|---|
| **目标** | 耳听：枪声有体、漏网有脚步嘶、回波有尾、分夜床可辨、UI 比枪声矮。Headless 仍能量化、不漏 Playback。 |
| **关键文件** | `scripts/sfx/sfx_bus.gd`（PCM、`cue_peak`、`CUES`）；`scripts/sfx/audio_director.gd`（Music 床、分层 mood、后台暂停）；`scripts/sfx/wav_probe.gd`；`default_bus_layout.tres` |
| **验收** | 冒烟 `SMOKE_OK_SFX_BODY fire>ui*1.15 tension≥0.18 echo≥0.10`；探针脚本打印 peak/rms/sec。**另附一页耳听笔记**（谁听、什么设备、是否掩蔽）。WATCHING 床要让路给 `tension`/`echo_ping`（`set_watch_bed` 已有）。切出：`pause_for_background` 不改用户静音。 |
| **风险** | 禁止改回 `AudioStreamGenerator`。Dummy 下 `play()` 必须继续早退，否则 ObjectDB leak（dump 已报过 4 个泄漏）。把床加响很容易盖掉枪声。真 VO / 主题曲是明确不做。 |

### 3.5 平台 / 触控

| | |
|---|---|
| **目标** | 真机横屏用拇指走完院子：点卡 → 点掩体 → 拖或 ↺↻ 射界 → 警报 → 看见战斗 → 失败或胜利可继续。桌面键鼠冒烟通道保留。 |
| **关键文件** | `scripts/touch_hud.gd`；`scripts/main.gd` `_handle_touch_gestures`（`InputEventScreenTouch`/`ScreenDrag`、捏合缩放、拖旋转）；`scripts/game_settings.gd`（`force_touch_hud` `want_touch_controls` `quality_tier`）；`project.godot`（横屏、`quit_on_go_back=false`、mobile `gl_compatibility`）；`export_presets.cfg`；`docs/ANDROID.md` |
| **验收** | 冒烟 `SMOKE_OK_TOUCH_NO_DESKTOP_BARS` `SMOKE_OK_TOUCH_PARITY` `SMOKE_OK_LIFECYCLE` `SMOKE_OK_CHECKLIST`。真机清单见 §6.3。窗口 `force_touch_hud` **不能**代替真机。 |
| **风险** | `emulate_mouse_from_touch=true`：不要只信鼠标事件。拖旋转与点部署抢同一 `ScreenTouch`（`_facing_touch` / `_pending_setup_touch`）——真机最可能误部署。底栏约 148px，南闸/逃逸口曾被 156px 双条吃掉；触控时桌面 ExtraBar+BottomBar 必须关。刘海只在真机 `get_display_safe_area()` 上验。 |

### 3.6 QA / 证据

| | |
|---|---|
| **目标** | 冒烟继续当回归网；窗口 dump 重新成为读图网；WAV 探针当音频网；真机/陌生人当门槛网。 |
| **关键文件** | `scripts/smoke_test.gd`；`scripts/eval_dump_0de4f1d.gd`（战役链 dump，应复制/改名为新 HEAD，不要覆盖旧 31 张）；`scripts/playable_dump.gd`；`scripts/visual_dump.gd`；`scripts/feel_gate.gd`；`scripts/sfx/wav_probe.gd` |
| **验收** | 每 PR：冒烟 exit 0 + tick 指纹。P0 退出：新 dump 目录 + `DUMP_OK` + 关键 PNG 与旧 `eval_0de4f1d` 并排可对照。不要删旧 eval（那是 8.6 的物证）。 |
| **风险** | 冒烟只查 `result_label.text` 曾经放过「字在、看不见」。20 轮已加矩形门，dump 仍要人工看图。`eval_dump_0de4f1d.gd` 热切路径在更早版本打过 `Infinite loop detected`；战役链走「下一关」才是对的。Headless 无 DISPLAY 不能当读图。 |

### 3.7 建议的开工顺序（agent 编排）

```text
QA: 重跑窗口 dump + 冒烟（不改玩法）
        │
        ▼
   dump 仍红？──是──► UI 修停靠 / 关卡改标签位置 / 美术加大灯塔
        │                 （同一时刻只一个 agent 碰 main.gd）
        否
        ▼
   ┌────┴─────┬──────────┬──────────┐
   音频耳听    美术并排剪影  触控真机    陌生人第一局
   └────┬─────┴──────────┴──────────┘
        ▼
   P2 观战跳漏网 / 简报减肥   （仍冻 tick）
        ▼
   P3 包装；合 main 只看 §6
```

---

## 4. 建议的下一批可感知迭代（按影响力）

「可感知」= 玩家或试玩评价人能在画面/耳朵/手指上指出前后差。架构拆分、`.tres` 外置不算。  
**闸门型条目排在最前**：它们不增加功能，但决定后面的刀砍不砍空。

| # | 迭代 | 为什么排前面 | 主要文件 | 感知点 | 不做的事 |
|---|---|---|---|---|---|
| 1 | **战役窗口 dump 全量重跑** | 20 轮自评 ~9.0 没有像素；上一次 9.2 就是这么虚高的。没有新图，UI/美术都在盲改。 | 新 `scripts/eval_dump_*.gd` + `docs/eval_<HEAD>/` | 31 张级战役链：失败/通关/电台空布置/仓道黄区/档案图板 | 不覆盖 `eval_0de4f1d/` |
| 2 | **失败牌 / CTA / 情报芯片像素锁死** | `0de4f1d` Top1–3。代码已改停靠+矩形门，但旧 `10`/`13`/`26`/`12` 仍是打脸图。dump 红才动代码。 | `main.gd` 停靠函数 | 「失败 · 逃逸」整词可见；「下一关」能点；恢复计划不横切时间轴 | 不改三行文案契约（漏网/改一处/CTA） |
| 3 | **电台 vs 油库远看并排** | 内容维从 8.4→8.9 的全部理由。机制已有第四路；世界感仍可能掉档。 | `grid._build_radio` `map_draw._landmark_radio` `mission_sky._draw_radio` | 缩略图能分灯塔/碟 vs 罐/钠灯 | 不改 6 掩体、绊索 `(7,11)`、echo 路点 |
| 4 | **仓道黄区课落地** | 从 `ce9dd2d` 就欠：虚线走 flank，玩家以为课是「站爆心外」。20 轮只改了文案和标签格。 | `level_def.second_trap_*` `trap_path_fx.gd` | SETUP 看见「等黄区再打」钉在黄区，不是脊 `(13,14)` | 不改 `second_trap_route=flank`、不改入伏规则 |
| 5 | **陌生人第一局一页纸** | 9.5 的硬门槛。冒烟「典型败→改一处」是脚本，不是人。 | 文档即可（`docs/` 试玩记录） | 第几世懂、卡在叠字/朝向/F/Tab 哪一层 | 不按这页去加第 7 夜或改数值「好过关」 |
| 6 | **耳听 PCM（枪声/回波/分夜床）** | 音频 5.5→6.8 全是峰值。正式版听感维仍可能是 5 分。 | `sfx_bus.gd` `wav_probe.gd` `audio_director.gd` | 枪声比 UI 响；电台床能从油库柴油里听出来；Dummy 仍不播放 | 不上 VO、不上外部 wav 资源管线（可后置） |
| 7 | **真机院子拇指环** | 触控 8.6 是窗口分。正式试玩的目标机是手机（`ANDROID.md`）。 | `touch_hud.gd` `main.gd` 手势 | 点卡→点掩体→拖射界→警报，无需键盘 | 不在真机验收前改键鼠冒烟 |
| 8 | **第二世恢复计划去糊** | 空布置是切片最干净的图；失败回来那一世才是真实体验。 | `_refresh_intel_chip` 状态条 弹包绿条 | 恢复后时间轴主/侧/暗/回波点仍能数 | 不删漏网建议，只限字数/层级 |
| 9 | **观战「跳到漏网」** | 电台要等 3.6s 暗道 + 5.2s 回波；看懂后还要看完走路，爽点变疲劳。 | `main.gd` WATCHING UI；复用 `replay_player` 只读 | 按钮：跳到终局画面，计划仍冻 | 不是战斗中微操；不是预测未来 |
| 10 | **回波等待身体感（像素+耳）** | 终夜独特一枪。`2583488` 已让时间轴 回5.2 呼吸；`0de4f1d` 说截图仍弱。 | `route_timeline.gd` `echo_ping` / `tension` | t≈6.2s 截图+耳朵同时打出「灯塔回波到了」 | 不把 echo 改成第一败（第一败必须仍是暗道） |
| 11 | **触控拖旋转 vs 点部署** | 手势代码在，未在真机上证明不误触。这是手机可玩的真实 P0 里藏着的 P1。 | `_handle_touch_gestures` | 按住已部署队员拖 = 只改射界；点空掩体 = 部署 | 不恢复桌面双条 |
| 12 | **档案图板 / 简报减肥** | 叙事 8.1→8.4 的来源。旧档案滚裁第 4–6 夜；简报曾印两遍必须带。 | `campaign_journal.gd` `title.gd` | 六夜一屏；简报一屏可读完 | 不写新剧情、不加对话系统 |
| 13 | **非参考失败仍给「改一处」** | 陌生人不会站 1,2,5。参考通关 tick 再绿也教不会错廊绊索。 | `level_def.fix_one` 失败牌生成；可选一条冒烟错廊 | 绊索放在东廊时，牌不能仍写「铺 (7,11)」却不标你铺错了 | 不引入自由寻路或新工具 |
| 14 | **六夜床/墙语可盲分** | 美术 7.4 的核心不是分辨率，是克隆感。信号楼已经是「最不像复制」的一张，油库/电台要追上。 | `map_draw` `night_keys` `ambient_*` | 打乱六张空布置缩略图，能标出夜名 ≥5/6 | 不改 40×22 外壳、不改南闸逃逸口几何 |
| 15 | **侧载包装（debug APK + 桌面说明）** | P3 入场。没有它，朋友包仍是「来我这台机器上玩」。 | `export_presets.cfg` `README.md` `ANDROID.md` | 一份 APK + 一句「必须横屏」 | 不合 `main`；不上 Play；不改包名 |

第 1 条是所有轨的底板。第 5、6、7 条是 9.5 的三只脚，缺一只就继续写「朋友包」。

---

## 5. 明确不做（本阶段）

| 不做 | 理由 |
|---|---|
| **第 7 夜** | 六夜已是 20–30 分钟垂直切片，终夜课是「暗道然后回波」。再加夜会逼着复制 `railcut` 六点模板（油库/电台已经踩过这个坑），且会让冒烟/dump/参考通关全面涨价。内容维的分差在**身份**，不在夜数。蓝图阶段 D、`LAUNCH_BAR`、两份复盘、20 轮选型都写了不开。 |
| **FOW / 隐藏敌人直到发现** | 会重写战斗信息结构。侦察「观察环」是 SETUP-only，故意不是战斗迷雾（`COMMANDOS_COMPLETE.md`）。开 FOW 等于让失败牌/幽灵/第二层虚线全部改语义。 |
| **sprite / 等轴 Commandos 管线** | 没有 PNG 管线、没有 ident 表。现在身份靠程序剪影+签名色；中途换 sprite 会把 20 轮灯塔/肩闪/回波桅作废，且挡不掉「远看仍像罐区」这种几何问题。商店页不够，用灯塔体块补，不用新资产管线。 |
| **真 VO / 主题曲** | 无录音、无本地化口型、headless 不能播。P1 只把现有 PCM 听完、听开。外部 wav 可以后置，但不作为本阶段退出条件。 |
| **合进 `main`** | `main` 是空壳。现在合进去 = 把「自评 9.0、像素未重跑、无陌生人、无真机」写成默认分支。Draft PR #4 维持 Draft。朋友包从本分支出。清单见 §6。 |
| **旁窗 / Live2D / 墨汐** | 另一条产品线。20 轮写明未混。混进去会污染夜袭读图（字、立绘、第二窗口）——这正是 `ce9dd2d` 已经打过的「叠」。 |
| **战斗中微操 / 自由寻路 / 程序关 / 升级树** | 硬规则。警报后只能看。敌人只走作者路。 |
| **Play AAB / 商店页 / CI 签名产物** | 侧载都还没真机勾完。`开发规划.md` 阶段 S 后置，本文件同意。 |
| **把参考通关 tick 当平衡旋钮** | 指纹是回归锚。要改难度先开新探针，不要在院子 283 / 电台 730 上「调顺手」。 |
| **为并行而先重写 `main.gd` 成 ECS** | 6887 行是风险，不是本阶段交付。真撞车时只抽 HUD 查询（失败牌矩形、芯片、触控开关），带着冒烟走。 |

---

## 6. 合进 main / 对外发布门槛清单

三条通道分开勾。**不要用冒烟绿代替后两列。**

### 6.1 继续发朋友包（分支，已基本满足）

- [x] 六夜可玩，硬规则未拆
- [x] 冒烟 exit 0，参考 tick 咬死
- [x] 失败是三行牌（契约）；布置期教学单层（契约）
- [x] 电台四路 + 第一败对齐暗道（契约）
- [ ] **建议补**：新窗口 dump 至少覆盖失败牌/通关 CTA/电台空布置三张，再把包发给下一批朋友（避免发「自评 9.0、图还是 8.6」）
- 文案：朋友包 / jam 多边形 / 合成音。禁止「正式版」「9.5」。

### 6.2 合进 `main`（把空壳换成可玩默认分支）

全部满足才把 PR #4 从 Draft 打开、才允许 merge：

- [ ] 冒烟在合入 SHA 上 exit 0，§7.5 tick 表一致
- [ ] **新窗口 dump 目录进仓**，战役链 30+ 张，且人工确认：
  - 失败牌不被左卡咬（院子 + 电台各一张）
  - 通关 CTA 不被键条埋
  - 情报芯片不横切时间轴（恢复计划后）
  - 电台远看不是油库矩形
  - 仓道第二层标签在黄区
  - 档案六夜一屏
  - 触控底栏打开时桌面双条关闭
- [ ] 硬规则抽检：WATCHING 改不了朝向/F/G/Tab/门；逃逸立即失败；跨世不留 HP/弹药
- [ ] 无新增 `ERROR:`、无切关 `Infinite loop detected`
- [ ] README / `LAUNCH_BAR.md` 分数改成「像素分 8.6 + 20 轮契约补丁，dump 已重跑」，**删除**未经验证的 9.2
- [ ] PR 描述写明：程序美术、合成音、无真机、无陌生人则**不要**把合 main 写成正式发行
- [ ] 仍建议：至少 1 个陌生人第一局记录附在 `docs/`（可以短）

不合入的充分条件（有一条就保持 Draft）：dump 仍能看到左卡咬「漏网：」、电台缩略图仍像罐区、冒烟 tick 漂了、硬规则被顺手改了。

### 6.3 对外正式试玩 / 侧载发行（不是 Play）

在 6.2 之上再勾：

- [ ] 陌生人第一局 ≥3 人，或 2 人但记录完整（第几世、卡点、是否看懂三行牌）。目标：多数人 2 分钟内警报；第一关 2–5 次有效尝试内能指出漏点。
- [ ] 真机至少一台 arm64 Android 8+ 横屏：
  1. 冷启动到标题，不白屏
  2. 手指完成院子（部署 3 人、调射界、拉警报、看到战斗、失败或胜利可继续）
  3. 拖旋转不误部署；底栏 ≥44dp；南闸/逃逸口不被底栏吃掉
  4. 返回键 = 暂停/退出确认，不杀进程
  5. 主页键切出：模拟暂停、床/音效停；切回不自动继续；尊重静音
  6. 观战手感：中端机 ≥30fps 或省电档可玩
- [ ] 耳听一页：枪声/漏网/回波/两张床（油库 vs 电台）
- [ ] APK 由**带 Android export templates 的本机**打出；`docs/ANDROID.md` 命令可复现；包名仍 `com.ambushloop.game`
- [ ] 对外页面/README 写横屏、六夜、程序美术。不写 9.5。

Play AAB / Steam / 本地化管线：**正式试玩之后**，不在本清单。

---

## 7. 验证策略：四张网各补哪一块

现在的网是「冒烟极强、读图过期、真机空、耳朵空」。下一阶段按网补洞，不要用一张网冒充另一张。

### 7.1 冒烟（每 PR，headless）

**已经很强，保持。** 覆盖：启动壳、6 夜解锁、几何/LOS/门、1×/2× 指纹、三种失败、计划恢复、六夜参考胜、仓/泵/楼/库/台故意败、credits 文案、教学单层、失败三行字符串、**矩形相交**（失败牌/CTA/芯片/清单）、触控隐藏桌面条、朝向用词、电台四路与灯塔契约、PCM 峰值、手感节点存在。

本阶段冒烟**补**：

| 补什么 | 不要补成什么 |
|---|---|
| dump 脚本改路径后，冒烟仍走 `change_scene_to_file(main.tscn)` | 不要让冒烟依赖 DISPLAY 或 PNG |
| 若做「跳到漏网」：断言 WATCHING 计划字段不变、只改播放头/终局展示 | 不要在冒烟里「跳过」参考胜，tick 仍要跑完 |
| 若动 PCM：保住 `SMOKE_OK_SFX_BODY` 阈值 | 不要断言 `last_cue` 等于「好听」 |
| 错廊绊索若做第 13 刀：加**一条**故意败，不改原参考胜 | 不要把典型败表扩成排列组合 |

跑法：

```bash
godot --headless --path ambush_loop -s res://scripts/smoke_test.gd
# 可选音频探针（不替代耳听）
godot --headless --path ambush_loop -s res://scripts/sfx/wav_probe.gd
# 可选手感存在性
godot --headless --path ambush_loop -s res://scripts/feel_gate.gd
```

隔离 `user://`（冒烟已做）。Dummy 音频是预期。

### 7.2 窗口 dump（P0 退出的读图网）

**这是下一刀最大的洞。** `eval_0de4f1d` 是 8.6 的物证，必须留着当对照；20 轮之后要**新目录**。

必拍（旧编号便于并排，不必 31 张一张不差，但下列不能缺）：

| 必拍 | 用来证伪 |
|---|---|
| 标题 / 选关 / 院子简报 | 壳没被改坏；必须带不重复 |
| `setup_yard_empty` / `facing` | 空布置仍干净；射界 vs 保护两词 |
| `fail_yard_card` / `fail_radio_card` | 左卡是否还咬字 |
| `setup_yard_restored` / `setup_radio_ref` | 情报芯片是否还横切时间轴 |
| `win_yard` / `win_radio` | CTA 是否还被键条埋 |
| `setup_warehouse_empty` / hold | 黄区标签 vs 爆心 |
| `setup_depot_empty` vs `setup_radio_empty` | 远看是否还是同一座罐区 |
| `watch_radio_echo` t≈6.2s | 回波 callout + 铁砧朝南 |
| `journal` 空/封印 | 是否还要滚第 4–6 夜 |
| `touch_radio_bars` | 桌面双条是否关掉 |

脚本约束：走标题→简报→`下一关` 战役链（`eval_dump_0de4f1d.gd` 已这样走）。禁止 `_load_level` 热切跳夜。DISPLAY 需要真实窗口（本环境曾用 `:1` + llvmpipe）；headless 不能替代。Vulkan 不够就 OpenGL，记在 dump.log。

人工对照表（评价人只看图，不看 `result_label.text`）：

1. 「漏网：」三字是否完整出现在牌上？
2. 「下一关」是否能当按钮而不是键缝里的残片？
3. 电台缩略图能不能从油库里挑出来？
4. 仓道黄区上是否写着入伏，而不是「站外面」？

### 7.3 真机（P3 退出，P0 不做假）

窗口 `GameSettings.force_touch_hud = true` 只证明底栏互斥（`SMOKE_OK_TOUCH_NO_DESKTOP_BARS`）。补的是：

- 拇指热区、拖旋转误触、刘海/手势条、横屏 lock、返回键、焦点丢失、30fps/省电。
- 至少院子一局；电台终夜若时间不够，桌面窗口补观战，真机不强制六夜。
- 导出：本机 Godot 4.7.2 Android templates + JDK 17。云端打出的 `dist/AmbushLoop.apk` 不当证据。

### 7.4 耳听（P1 退出）

补的是 Dummy 永远测不到的「好听/好听不够/吵」。

| 听什么 | 通过 | 失败 |
|---|---|---|
| `fire` vs `ui` | 枪声有体、UI 明显更矮 | 两声一样尖 |
| `tension` 回波等待 | 5.2s 前能感到「要来了」 | 只有细蜂鸣或被床盖住 |
| `echo_ping` | 与枪声不同类 | 又一声 beep |
| `leak` | 失败有脚步/嘶，不是同一把号 | 与 `fail` 无法区分 |
| `ambient_depot` vs `ambient_radio` | 柴油 vs 载波/摩斯 | 同一床换音量 |
| 六夜进关 stinger | 不刺耳、不连响 | 叠在床上炸 |

记录设备（笔记本喇叭即可）和是否静音路径误开。WAV 探针是助手，不是耳朵。

### 7.5 冻结的参考 tick（改玩法才允许动，本规划默认不动）

来源：`smoke_test.gd` `_deploy_ref` + `0de4f1d` 附录 A + `20round.md`。tick÷60 ≈ 秒。

| 关 | 探针 | tick |
|---|---|---:|
| yard 逃 | 西掩体朝东 | 965 |
| yard 胜 | 1,2,5 · 90/180/180 | 283 |
| warehouse 不入伏 | 同站位 | 1419 |
| warehouse 入伏+弹包 | 1,3,5 hold+pack | 872 |
| pump 开 | 1,4,5 | 694 |
| pump 锁旧朝向 | 90/0/180 | 1052 |
| pump 锁新朝向 | 90/180/180 | 740 |
| railcut 南堆 | 2,5,1 | 1191 |
| railcut 胜 | 1,4,5 · 270/270/180 | 818 |
| depot 无绊索 | 1,4,5 | 1418 |
| depot 胜 | + Tab `(7,11)` | 572 |
| radio 无绊索 | sneak 3.6s，铁砧已朝南 | 1502 |
| radio 胜 | 碟台朝南 + 绊索 | 730 |

参考通关槽位（slot 0 基）见 `README.md`。电台铁砧是 **270/90/270**（碟台朝南），不是油库那套东廊朝北。

---

## 8. 文档与分支纪律

- **下一刀以本文件为准。** `docs/开发规划.md` v3 仍有用的部分：安卓导出步骤、真机勾选、硬规则。过时的部分：第 6 关「不要做码头」、安卓 M0–M3「未进仓」、冒烟只五关、评分锚 7.5 桌面。
- `docs/LAUNCH_BAR.md` 继续当功能清单，不当读图分。
- 旧 eval 目录（`eval_ce9dd2d/` `eval_playable/` `eval_0de4f1d/`）是分数审计轨迹，**不要删、不要覆盖**。
- 工作分支保持 `cursor/ambush-loop-mvp-6a41`。朋友包从这里出。`main` 空壳直到 §6.2。
- 提交纪律：玩法/表现/冒烟分 commit；纯 docs 可以单独进。本文件属于后者。
- 多 agent：先在 PR 描述写「不改 tick / 不改 cover_defs / 不改 spawn delay」。碰 `main.gd` 要声明函数名。

---

## 附录 A — 硬规则（再抄一次，防止下一批「顺手」）

1. 警报响起：位置、朝向、开火条件、工具、门冻结。暂停、变速、镜头、复盘、跳到漏网都只能改变观看。
2. 任一存活敌人越过有效逃逸边界 → 立即失败；参战小队全灭 → 立即失败；中止是故意失败，仍留截至此刻的情报。
3. 跨世只留情报与上轮计划，不留伤害、弹药、尸体、消耗、升级。
4. 路线与分支由作者定义。门只切换预写备用路。敌人不自由寻路。
5. 地图、人物、文本、造型、音效独立创作；不混旁窗产品线。

## 附录 B — 关键路径速查

| 主题 | 路径 |
|---|---|
| HUD / 失败牌 / 芯片 | `scripts/main.gd` |
| 电台几何 | `scripts/grid.gd` `_build_radio` |
| 关卡课 / 回波路 | `scripts/level/level_def.gd` |
| 第二层虚线 | `scripts/fx/trap_path_fx.gd` |
| 灯塔 / 碟 | `scripts/map_draw.gd` `_landmark_radio` |
| 夜空扫灯 | `scripts/fx/mission_sky.gd` |
| 音频 | `scripts/sfx/sfx_bus.gd` `audio_director.gd` `wav_probe.gd` |
| 触控 | `scripts/touch_hud.gd`；`main.gd` `_handle_touch_gestures` |
| 档案 / 幕间 / 致谢 | `scripts/ui/campaign_journal.gd` `night_handoff.gd` `credits_overlay.gd` |
| 冒烟 | `scripts/smoke_test.gd` |
| 旧读图物证 | `docs/eval_0de4f1d/` |
| 20 轮交割 | `docs/Ambush_Loop_试玩复盘_20round.md` |
| 8.6 独立复盘 | `docs/Ambush_Loop_试玩复盘_0de4f1d.md` |
| 安卓 | `docs/ANDROID.md` |

## 附录 C — 制作人停手条件

出现以下任一情况，停止加表现，先回到 P0：

- 新 dump 仍能用 `0de4f1d` 的同一句话描述失败牌/CTA/电台克隆；
- 为了「好看」改了参考 tick 或 `cover_defs`；
- 冒烟绿但 `ERROR:` / ObjectDB leak / 切关死循环回潮；
- 有人把 Draft PR 直接标 Ready 却没有新 dump 目录。

**可对外试玩（朋友包）：是。**  
**可写成正式版读图：否，直到 §6.3。**  
**下一刀：重跑窗口 dump，再决定是修停靠还是把 ~9.0 写成像素分。**
