# Ambush Loop v0.6.x — 20 轮 PaperRoute 切片

Date: 2026-09-18  
Branch: `cursor/commandos-ambush-0641`  
HEAD at plan: `6aff4b6` **v0.6.0** overhaul (`versionCode` 49)  
Method: one Engine **or** Look slice → smoke/dump → commit. RAID 契约不动。

## Dump 证据（`docs/eval_touch_ux/dump.log`）

- 西巷 dest `(7,12)/(6,6)/(5,16)` span **6**，`dest_world_spread=190.9`，`file_pts=3` `file_len=434.5`，zoom/body/obs **1.0**，`postage=0`。
- 观察填色 `obs_fill_a=0.01` `obs_fill_court=0`（0.5.40 已绿）。
- 西墙匣 `DUMP_WEST_CRATE cell=(8,13)` caps=开匣。0542 把热区钉在人头顶；西墙仍可能滑进环皂。
- 绕背：`DUMP_FLANK_PATH hits=0 pts=0`，完整引导 `DUMP_FLANK_GUIDE pts=5`。部分静帧虚线空。
- ALERT `watch_btns=3`（中止/暂停/倍速），hint 偏长。
- 简配窄条 `need=259` / `avail=320` `twist=54`，能塞下，拇指键仍偏瘦。
- 黄锥 `cone_fade=0.38`（0539 上限 0.50）。
- 院子岛已有 Blender 匣 + 30CAL 弹药罐。

## 明确不做

- **西巷 dest 格重算**（建议里的 west dest rethink）：0532–0541 leftover 把 dest 锁死在 `(6,6)/(5,16)`、`span==6`、`dest_spread>=186`。改格必须一次性改十多条 leftover。本 20 轮用队形线做 cohesion，**不**把 zoom 压到 0.85 下、**不** body 0.16。
- Meshy 人脸：本机 **无** `MESHY_API_KEY`。
- 不混 Engine 物理和 Look 网格进同一 commit。
- RAID：`SCOUT→ALERT→SWEEP`、ALERT 锁走位、自动火力/手雷、10 枪 kit。

## R01–R20

| 轮 | 轨 | 切片 | 验收 | 版本 / 包 |
|---|---|---|---|---|
| R01 | Engine | 西墙 **开匣** 钉在匣上方偏东，不进西皂 | smoke `SMOKE_OK_WEST_CRATE_0601`；dump `07_west_crate` | 0.6.1 |
| R02 | Look | 步枪匣 / gun-case GLB + 接触纸（art study） | `gun_case_turnaround.png` 侧缝 + 正面 RIFLE 字模 | — |
| R03 | Engine | 夜分级：院子格纹在淡环下仍可读 | smoke 夜分级区间；dump `01_scout` | 0.6.2 |
| R04 | Look | 沙袋堆 GLB + 接触纸 | `sandbag_turnaround.png` 袋缝剪影 | — |
| R05 | Engine | ALERT 观战条：暂停/倍速/中止读得清 | dump `02_alert_touch_watch` | **0.6.3 APK** |
| R06 | Look | 灯柱 GLB + 接触纸 | `lamp_post_turnaround.png` 灯笼+杆 | — |
| R07 | Engine | 绕背虚线：有 绕背 就画完整引导 | smoke 侧绕；dump `05b`/`05e` pts≥4 | 0.6.4 |
| R08 | Look | 一段篱笆 GLB + 接触纸 | `fence_section_turnaround.png` 柱+横档 | — |
| R09 | Engine | 简配 ↺/↻ 拇指加宽，窄屏仍 fits | `SMOKE_OK_COMPACT_NARROW` twist≥52 need≤360 | 0.6.5 |
| R10 | Look | 步枪匣 iso 进可玩院子（西匣/岛旁） | dump `01`/`07` 能指到新剪影 | **0.6.5 APK** |
| R11 | Engine | SCOUT 教学一行缩短（保留 交叉封锁/侧翼） | `SMOKE_SPAWN_TEACH_*` | 0.6.6 |
| R12 | Look | 沙袋 iso 进西墙 | dump 西巷静帧 | — |
| R13 | Engine | 黄锥 fade 收到 0.44–0.48（仍 ≤0.50） | leftover 0539 fade；新 assert | 0.6.7 |
| R14 | Look | 灯柱 iso 换院子程序灯 | dump `01_scout` 灯剪影 | — |
| R15 | Engine | 开匣拿到反馈（世界字，不只 status） | smoke 拾取后有 flash chip | **0.6.8 APK** |
| R16 | Look | 篱笆 iso 进西巷 | dump `08f` 西巷边 | — |
| R17 | Engine | settle-on-ring 回归网（独立 0617） | `SMOKE_OK_SETTLE_0617` d_ring 小 | 0.6.9 |
| R18 | Look | 步枪匣接触纸缺陷：侧板缝 + 字模加粗 | 新 sheet 再指一帧 | — |
| R19 | Engine | 暂停/倍速用词：暂停观战 / 1×·2× | dump ALERT 三键 | 0.6.10 |
| R20 | Look | 第二匣变体（口粮箱）进岛 + 导入抛光 | dump 岛上两匣剪影不同 | **0.6.11 APK** |

APK 最少打在 R05 / R10 / R15 / R20。Engine 里程碑顺手 bump `versionName`。

## 每轮合同

1. 只改一件可玩或可看的事。
2. Engine：`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`。关键轮再跑 force-touch dump。
3. Look：`blender-headless --python ambush_loop/ArtSource/build_<asset>.py` → GLB + clay/shaded 接触纸。进院子另开一轮。
4. 指向一帧，不写「看起来好一点」。
