# RESULT-H3-PHASE3 — 2026-10-27 Asia/Shanghai

## Verdict
**PASS** — 母机025 本地 MiniMax H3 FL2VA 双镜（S05 wade + S08 charge/blast）出片；拼装 Normandy **v0.3** 15s 竖屏成片；双机 power_off 留盘。

## Instance
- winner：**母机025** `9b4c40bda6-dad38bb9`（重庆A cq-A1 · RTX 4090D）· ssh `root@58.144.141.28:49669`（已关机）
- 克隆003 `bb8c4f8e12-00c8bdac`：开机竞速失败/全程 **shutdown**（只开一台）
- 规则：不充值；不 release；跑完 power_off 留盘；试点**无预算软顶**（t77u）
- 授权：t77u 按最早剧本推进 S05 涉水 + S08 冲锋/爆破 → 拼 v0.3

## 样片（本机，二进制不入库）
| 镜 | 路径 | 分辨率 | 帧/时长 | 体积 | prompt_id |
|---|---|---|---|---|---|
| S05 wade | `outputs/h3-phase3-2026-10-27/h3_phase3_S05_wade_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 7.0 MiB | `0bbc0478-a31b-4700-b58f-64b13a79543c` |
| S08 charge | `outputs/h3-phase3-2026-10-27/h3_phase3_S08_charge_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 5.4 MiB | `f08c4cf9-3072-4951-a822-e097592c6785` |
| v0.3 | `outputs/v0.3-b0-01-2026-10-27/out/B0-01-normandy-v0.3.mp4` | **1080×1920** · 24fps | **15.000s** · H.264+AAC | 10.1 MiB | assemble S04+S05+S08+S10 |
| v0.3 silent | `…/B0-01-normandy-v0.3.silent.mp4` | 同 | 15s | 9.8 MiB | — |

- 远端：`/root/autodl-tmp/h3-phase3/out/`；Comfy 执行 S05≈390s / S08≈370s（8-step turbo）
- node_errors：**无**；`ALL_DONE` 双镜 status=ok
- 编排备注：本机 `watch_phase3.sh` 因匹配串写成 `ALL_DONE status=ok` 而日志为 `ALL_DONE {dict}` → 误报 WATCH_FAIL 并先关机；随后短启母机 scp 双 mp4 → 再 dual power_off；拼片由本岗在 `phase3_pull.done` 后手动 `assemble_v0.3.sh`（exit 0）

## 管线
- ComfyUI 0.42 · MiniMaxH3ImageToVideo FL2VA turbo 8step · length=124 · 768×1344
- workflow：`workflow_api_fl2va_s05.json` / `…_s08.json`（seed 202610275 / 202610278）
- 首尾帧：Cursor GenerateImage 静帧（wade/charge pack）
- 拼片：`scripts/assemble_v0.3.sh` → 钩子真猫+日期 → portrait → boat 静帧 → S04 → S05 → S08 → S10 → 定格；BGM CC0 Horde War Drums
- 权重：母机盘已齐（smoke/phase2 留盘），本轮未重下

## 花费 / 关机
| 项 | 值 |
|---|---|
| 余额 before | **44000** 分 |
| 余额 after | **43460** 分 |
| 本轮消耗 | **≈540 分（≈¥0.54；按 smoke 同单位 100分=¥1；旧记 ¥5.40 为笔误）** |
| 母025 | **shutdown**（power_off Success；含误报后二次拉片再关） |
| 克隆003 | **shutdown**（power_off BadRequest=已关） |
| 盘 | 双机留盘 |

## 目检（抽帧）
- **S05**：Higgins 门落→浅滩涉水成立；半 Q 版比例可读；头盔/红巾/星章一致；浪花与烟柱背景；**SFW**；无崩脸/多肢
- **S08**：滩头冲锋+身后爆破可读；铁蒺藜/烟火；光色偏暖日落（相对 S05 阴天略跳）；姿态前倾成立；**SFW**
- **v0.3**：15s 叙事弧（钩子→登艇→涉水→冲锋→插旗）连贯；竖屏 1080×1920；音轨 AAC 叠 CC0 战鼓
- **一句话**：涉水/爆破高潮已补上；H3 镜间色温略跳，整体可爱度与题材可读性明显好于 Wan v0.2

## 边界
- 禁 grok CLI / 禁 NSFW；未充值、未 release
- 二进制 mp4 **不入库**；文档入 PR#84

