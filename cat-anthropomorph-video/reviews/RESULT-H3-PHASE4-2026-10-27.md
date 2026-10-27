# RESULT-H3-PHASE4 — 2026-10-27 Asia/Shanghai

## Verdict
**PASS** — 克隆003 本地 MiniMax H3 FL2VA 四镜（S04 boat_ramp + S05 wade + S08 charge + S10 flag）用 **looklock-v0.3.1 新静帧** 出片；拼装 Normandy **v0.3.1** 15s 竖屏成片；双机 power_off 留盘。

## Instance
- winner：**克隆003** `bb8c4f8e12-00c8bdac`（重庆A cq-A1 · RTX 4090D）· ssh `root@58.144.141.28:22803`（已关机）
- 母机025 `9b4c40bda6-dad38bb9`：attempt1 曾短暂开机（python3 PATH 导致 remote 立刻挂）→ power_off；attempt2 竞速 GPU 不足，全程 **shutdown**
- 规则：不充值；不 release；跑完 power_off 留盘；试点**无预算软顶**（t80u）
- 授权：t80u 开机出片（looklock v0.3.1 新静帧 → H3 四镜 → 拼 v0.3.1）

## 样片（本机，二进制不入库）
| 镜 | 路径 | 分辨率 | 帧/时长 | 体积 | prompt_id |
|---|---|---|---|---|---|
| S04 boat_ramp | `outputs/h3-phase4-2026-10-27/h3_phase4_S04_boat_ramp_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 5.1 MiB | `ad428345-e2c6-424b-96c7-8af98ffa6156` |
| S05 wade | `outputs/h3-phase4-2026-10-27/h3_phase4_S05_wade_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 5.9 MiB | `be24e6da-ec8d-43d2-8f2d-b81e7dfd259d` |
| S08 charge | `outputs/h3-phase4-2026-10-27/h3_phase4_S08_charge_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 4.5 MiB | `32e3098b-78e7-4079-a6a6-ab6f8b31487f` |
| S10 flag | `outputs/h3-phase4-2026-10-27/h3_phase4_S10_flag_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 3.9 MiB | `7b14b4f0-c677-47bc-b082-7c6984336743` |
| v0.3.1 | `outputs/v0.3.1-b0-01-2026-10-27/out/B0-01-normandy-v0.3.1.mp4` | **1080×1920** · 24fps | **15.000s** · H.264+AAC | 9.3 MiB | assemble S04+S05+S08+S10 |
| v0.3.1 silent | `…/B0-01-normandy-v0.3.1.silent.mp4` | 同 | 15s | 9.0 MiB | — |

- 远端：`/root/autodl-tmp/h3-phase4/out/`；Comfy 每镜 ≈6–7min（8-step turbo）
- node_errors：**无**；`ALL_DONE_OK` 四镜 status=ok
- 静帧：`outputs/cursor-stills-looklock-v0.3.1/`（旧 `cursor-stills-2026-10-27` pack **作废**）

## 管线
- ComfyUI 0.42 · MiniMaxH3ImageToVideo FL2VA turbo 8step · length=124 · 768×1344
- workflow：`workflow_api_fl2va_phase4_s{04,05,08,10}.json`（seed 2026102791–794）
- 首尾帧：Cursor GenerateImage looklock-v0.3.1（boat_ramp/wade/charge/flag）JPG→PNG
- 拼片：`scripts/assemble_v0.3.1.sh` → 钩子真猫+日期 → master portrait → boat 静帧 → S04→S05→S08→S10 → 定格；BGM CC0 Horde War Drums
- 权重：克隆003 盘已齐（phase2 留盘），本轮未重下
- 编排：`/tmp/autodl_race/h3/pipeline_phase4.sh`（race→orch nohup remote→watch pull+power_off→assemble）；watch 用 `ALL_DONE_OK` / results.json（修 phase3 `ALL_DONE status=ok` 误匹配）

## 花费 / 关机
| 项 | 值 |
|---|---|
| 余额 before（会话起点） | **43460** 分 |
| attempt1 短启失败后 | **43270** 分（母025 python PATH 挂 → 立刻关） |
| 余额 after（结清） | **42250** 分 |
| 本轮消耗 | **≈1210 分（¥12.10）**（含 attempt1 空转 + clone 四镜） |
| 母025 | **shutdown**（留盘） |
| 克隆003 | **shutdown**（power_off Success；留盘） |

## 事故 / 修复
1. **attempt1 母025**：`nohup python3` 远端 PATH 无 python3 → remote 秒死；watch 见 DEAD → dual power_off。已改 orch 用 `/root/miniconda3/bin/python` 并校验 pid 存活。
2. **watch 远端 results.json 解析**：裸 `python3` 同样缺 PATH（噪声 `command not found`）；终态靠 `ALL_DONE_OK` 行命中 DONE_OK（已补丁 miniconda）。

## 目检（抽帧·短）
- 四镜均为 looklock-v0.3.1 新静帧驱动；768×1344 / 124f；**SFW**
- v0.3.1：15s 叙事弧（钩子→登艇→涉水→冲锋→插旗）；竖屏 1080×1920；AAC 叠 CC0 战鼓
- 详细人眼/Opus 评另开；本岗未做逐帧打分

## 边界
- 禁 grok CLI / 禁 NSFW；未充值、未 release；未碰漫监去衣资产
- 二进制 mp4 **不入库**；文档可入 PR#84
