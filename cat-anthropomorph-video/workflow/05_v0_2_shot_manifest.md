# v0.2 镜头清单 · B0-01 诺曼底 · 12 刀

> 权威：`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md` §2.2（12 刀表）/ §2.5（超分交付）；时间轴：`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`（128 BPM / 15s / 32 拍）。
> 输出根：`outputs/v0.2-b0-01-2026-10-26/`。二进制 mp4 可不入库，路径按本表归档。
> 只有 **HUMAN_ACCEPTED** 可进时间线；`RENDER_DONE` / `AUTO_QC_PASS` 都不是可用成片。

## 状态图例

| 状态 | 含义 | 可否进时间线 |
| --- | --- | --- |
| `PENDING` | Phase 0 占位，尚未渲染 | 否 |
| `RENDER_DONE` | 已出片，未过门禁 | 否 |
| `AUTO_QC_PASS` | G1/G2/G2m 全过，未过人眼 | 否 |
| `HUMAN_ACCEPTED` | H1–H3（成片另加 H4）签字 | **是** |
| `DOWNGRADED` | 预算压缩降级（静帧 + Ken Burns），须在成片清单标注 | 仅限标注后 |

## 12 刀总表

| Shot | t (s) | 内容 | 首帧 / 素材来源 | 模板 | GPU | 验收 | 状态 / 路径（相对输出根） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S01 | 0.00–1.20 | 真猫正面硬切 + 钩子字 `1944·诺曼底` / `上岸前 0.5 秒` | `refs/cats/A/front.jpg` | 剪映 | 否 | 3s 内知道「要开战/变身」 | `PENDING` · `edit/S01_hook/` |
| S02 | 1.20–2.20 | 真猫 → 直立拟人 portrait looklock，2 帧闪白 | Phase 1 `portrait` 已验收 | 剪映 / 01 | 否（图已定） | 一眼拟人、小橘身份可读 | `PENDING` · `looklock/accepted/portrait.png` |
| S03 | 2.20–3.50 | LCVP 艇内，手扶门闩，门未落，浪花；轻推镜 | Phase 1 `boat_ramp` 已验收 | 剪映 / 01 | 否（图已定） | 一眼登陆艇/门；手在竖裁内 | `PENDING` · `looklock/accepted/boat_ramp.png` |
| S04 | 3.50–4.80 | **门落重音**：钢门砸入海面，水花扑面，猫向前一步 | `boat_ramp` + 门落末帧 | **03 FLF2V** | **是** | 一眼门落；动作完成帧踩 3.75s；首末帧同身份 | `PENDING` · `flf2v/S04_door_drop/` |
| S05 | 4.80–6.10 | 涉水第一步，水花溅到腰，围巾被风拉起 | S04 末帧或 `boat_ramp` 竖幅 | 02 I2V | **是** | 水花可见、身份不崩、围巾强风可读 | `PENDING` · `i2v/S05_wade/` |
| S06 | 6.10–7.30 | 远景烟柱 / 反应镜：猫中近景回头/压低身体 | `battle` looklock | 02 I2V 或静帧 + 烟层 | **是/可选** | 战场可读、非棚拍；回头/压低完成 | `PENDING` · `i2v/S06_smoke/` |
| S07 | 7.30–8.60 | **沙滩卧倒/翻滚**，尘土掠过；主卡点 7.97s | `battle` 竖幅首帧 | 02 I2V | **是** | 卧倒动作完整、不穿模、无多肢 | `PENDING` · `i2v/S07_prone/` |
| S08 | 8.60–9.70 | **爆破开路/冲锋**：身后炸点、猫低姿前冲 | `battle` 竖幅首帧 | 02 I2V | **是** | 爆破可读、主体不糊、低姿前冲完整 | `PENDING` · `i2v/S08_charge/` |
| S09 | 9.70–10.78 | 抬头盯镜 / 围巾强风；高潮起势；主卡点前最后一拍 | crop-check 过线首帧 | 02 I2V | **是** | 抬头完成、眼神可读、身份不崩 | `PENDING` · `i2v/S09_head_turn/` |
| S10 | 10.78–12.20 | **插旗剪影**：双爪握杆，旗升到顶，烟尘逆光；主卡点 10.78s | `battle` + 旗杆首/末帧 | **03 FLF2V** | **是** | 一眼插旗；剪影不糊；主体不裁手/旗 | `PENDING` · `flf2v/S10_flag/` |
| S11 | 12.20–13.50 | 敬礼/持旗定格；红围巾收束 | S09/S10 峰值帧 | 02 I2V 或 freeze | **是/可选** | 敬礼可读或定格干净 | `PENDING` · `i2v/S11_salute/` |
| S12 | 13.50–15.00 | 定妆定格 + `Normandy 1944` + `#AI生成`；淡出 | `portrait` / `battle` 峰值 | 剪映 | 否 | 字幕不挡脸、收束干净 | `PENDING` · `edit/S12_outro/` |

## 硬约束

- **12 刀**（成片允许 10–14 刀）；主卡点 **3.75s 门落 / 7.97s 卧倒 / 10.78s 插旗/抬头**，可 ±0.15s 对齐实际曲目强拍。
- **S04/S10 必须 FLF2V**，首末帧均来自已验收同身份 looklock；其余主镜默认 I2V。
- 8 条 GPU 主镜（6 I2V + 2 FLF2V）至少 **6/8 HUMAN_ACCEPTED**，且 S04/S10 必须过。
- 预算压缩时优先保 **S04/S05/S07/S08/S10**；S06/S11 可降级为静帧 + Ken Burns，但必须在成片清单标 `DOWNGRADED`，不得把降级版叫完整 v0.2。
- 每镜 **最多 2 seed**；两次失败换策略，禁止同参重抽。
- SFW；不碰 `ai-realistic-comic/`；不发布、不投流。

## 路径占位（相对 `outputs/v0.2-b0-01-2026-10-26/`）

```text
looklock/
  portrait/    cat_anthro_v02_portrait_<seed>.png
  boat_ramp/   cat_anthro_v02_boat_ramp_<seed>.png
  battle/      cat_anthro_v02_battle_<seed>.png
  accepted/    portrait.png / boat_ramp.png / battle.png
i2v/
  S05_wade/         raw.mp4 + start_480x832.png + gates.json + status.json
  S06_smoke/        raw.mp4 + start_480x832.png + gates.json + status.json
  S07_prone/        raw.mp4 + start_480x832.png + gates.json + status.json
  S08_charge/       raw.mp4 + start_480x832.png + gates.json + status.json
  S09_head_turn/    raw.mp4 + start_480x832.png + gates.json + status.json
  S11_salute/       raw.mp4 + start_480x832.png + gates.json + status.json
flf2v/
  S04_door_drop/    raw.mp4 + first.png + last.png + gates.json + status.json
  S10_flag/         raw.mp4 + first.png + last.png + gates.json + status.json
accepted/           <shot_id>.mp4   # 只放 HUMAN_ACCEPTED
upscaled/           <shot_id>_1080p.mp4
edit/v0.2-timeline/ 剪映工程或 ffmpeg 中间件
out/                B0-01-normandy-v0.2.mp4 / .silent.mp4 / .cover.jpg / audio-credits.md
```

## 超分与交付口径

- I2V 480×832 → **4×**（1920×3328）→ 时间一致性抽帧/目检 → 降采样 **1080×1920**。
- FLF2V 720×1280 → **4×**（2880×5120）；显存/时间不够可 2× 后进 1080 时间线，但必须在清单标注。
- 成片锁 **1080×1920 · 30fps · 14.4–15.0s**；H.264 high profile；AAC 192–320kbps；AI 标识。
- 4× 模型 **UltraSharp | ClearRealityV1 二选一后冻结**；超分闪烁才 A/B SeedVR2/FlashVSR。
- 命名：包装/授权/音效任一未完成 → `v0.2-draft` 或 `v0.2-limited`，不得对外盲测。

## 关联

- 提示词：[`../prompts/v0_2_shot_prompts.md`](../prompts/v0_2_shot_prompts.md)
- 人眼验收：[`06_v0_2_human_acceptance.md`](06_v0_2_human_acceptance.md)
- FLF2V 槽：[`03_flf2v_api_slots.json`](03_flf2v_api_slots.json)
- I2V 槽：[`02_i2v_api_prompt_r1_r4.json`](02_i2v_api_prompt_r1_r4.json)
- 定妆槽：[`01_looklock_api_slots.json`](01_looklock_api_slots.json)
- 超分槽：[`04_upscale_4x_api_slots.json`](04_upscale_4x_api_slots.json)
