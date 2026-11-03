# v0.2 人眼验收单 · H1–H4

> 权威：`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md` §2.7。
> 本单 **不替代 AUTO_QC**。G1/G2/G2m 仍是入场券；H1–H4 是 v0.2 必过人眼项。
> 状态严格三态：`RENDER_DONE` → `AUTO_QC_PASS` → `HUMAN_ACCEPTED`。只有 **HUMAN_ACCEPTED** 可进时间线。

## 门禁定义

| 门 | 内容 | 通过标准 | 失败处理 |
| --- | --- | --- | --- |
| G1 | `scripts/noise_gate.py` | exit 0 | 不进候选 |
| G2 | `scripts/subject_gate.py` 相对首帧 SSIM 0.25–0.92 | exit 0；过高仅 WARN | 修首帧 / 换 seed |
| G2m | `scripts/motion_gate.py` max MAD ≥ 11 | exit 0 | 改 prompt / 换 FLF2V |
| **H1 身份** | 同一只小橘；直立；耳/钢盔/红围巾可读；非四足；无换脸/多肢 | 人眼 80% 认出 | 回 Phase 1 修定妆 |
| **H2 运动** | 不读 prompt 也能看出动作；无静帧感；动作在镜内完成；无瞬移 | 6/8 主镜过；S04/S10 必过 | 换策略，不重抽 |
| **H3 构图** | 主体不裁手/旗；枪/旗可读；无文字伪影；无多余角色 | 逐镜过 | 重定首帧 / 裁切 |
| **H4 成片** | 切点踩拍；SFX 同步；字幕不挡脸；色感统一；无绿卡 | 全片过 | 回 Phase 3 |

## 状态字段（写死）

Phase 2 起在每条 `status.json` 增加三个布尔字段，**禁止只用一个 `--human` 概括**：

| 字段 | 覆盖 | 何时可为 true |
| --- | --- | --- |
| `human_subject` | H1 身份 + H3 构图（该镜） | 该镜 H1/H3 均过 |
| `human_motion` | H2 运动（该镜） | 该镜 H2 过 |
| `human_edit` | H4 成片（时间线级） | 全片 H4 过；源片段阶段保持 false |

`HUMAN_ACCEPTED` 条件：`g1 && g2 && g2m && human_subject && human_motion`。成片级另加 `human_edit`。
脚本扩展前，先在本单逐镜签字；不得以 `AUTO_QC_PASS` 代替。

## 逐镜签字 · 主镜（S04–S11）

> 由验收人逐条填写 `Y` / `N`；`Y` 才可把 `status.json` 置 `HUMAN_ACCEPTED`。备注写失败原因或降级策略。

| Shot | 内容 | H1 身份 | H2 运动 | H3 构图 | human_subject | human_motion | 结论 | 备注 / 降级 | 验收人 / 日期 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S04 | 门落 FLF2V |  |  |  |  |  |  |  |  |
| S05 | 涉水 I2V |  |  |  |  |  |  |  |  |
| S06 | 烟/反应 I2V |  |  |  |  |  |  |  |  |
| S07 | 卧倒 I2V |  |  |  |  |  |  |  |  |
| S08 | 爆破冲锋 I2V |  |  |  |  |  |  |  |  |
| S09 | 抬头 I2V |  |  |  |  |  |  |  |  |
| S10 | 插旗 FLF2V |  |  |  |  |  |  |  |  |
| S11 | 敬礼 I2V |  |  |  |  |  |  |  |  |

**主镜通过线**：至少 **6/8** 条 `HUMAN_ACCEPTED`，且 **S04、S10 必须过**。未过镜若降级为静帧 + Ken Burns，在 `05_v0_2_shot_manifest.md` 标 `DOWNGRADED`，成片不得叫完整 v0.2。

## 逐镜签字 · 非 GPU 刀（S01–S03 / S12）

| Shot | 内容 | H1 身份 | H3 构图 | 备注 | 验收人 / 日期 |
| --- | --- | --- | --- | --- | --- |
| S01 | 真猫硬切 + 钩子字 |  |  |  |  |
| S02 | 变身闪白 |  |  |  |  |
| S03 | 艇内起势 |  |  |  |  |
| S12 | 片尾定格 + 字幕 |  |  |  |  |

## 成片 H4 签字

| 项 | 通过标准 | 结果 | 备注 |
| --- | --- | --- | --- |
| 切点踩拍 | 主卡点 3.75 / 7.97 / 10.78s；12 刀（10–14） |  |  |
| SFX 同步 | ≥2（目标 3–5）：门落 / 水花 / 爆破 / 旗风 / riser |  |  |
| 字幕 | 钩子、`1944-06-06` 日期条、片尾 `Normandy 1944 #AI`；不挡脸/眼 |  |  |
| 调色 | 全片一个 LUT/grade；无每镜换滤镜 |  |  |
| 技术 | 1080×1920 · 30fps · 14.4–15.0s；无绿卡/糊段 |  |  |
| 响度 | -14 LUFS integrated；true peak ≤ -1 dBTP |  |  |
| `human_edit` | 以上全过后置 true |  |  |

**成片验收人 / 日期**：____________________

## 失败回退

- H1 不过：回 Phase 1 修 `portrait` / `boat_ramp` / `battle`；先保证首末帧同身份，不得直接跑 FLF2V。
- H2 不过：该镜两次失败后换 FLF2V（关键镜）或静帧 + Ken Burns（非关键镜）；禁止同参重抽。
- H3 不过：重定首帧或裁切，确认手/旗/钢盔在竖裁内。
- H4 不过：回 Phase 3 修切点/SFX/字幕/调色；包装未完成只能叫 `v0.2-draft` / `v0.2-limited`。
- 指标假阳性：AUTO_QC 过但人眼不过，以人眼为准，记 FAIL。

## 关联

- 12 刀路径与状态：[`05_v0_2_shot_manifest.md`](05_v0_2_shot_manifest.md)
- 8 条主镜 prompt：[`../prompts/v0_2_shot_prompts.md`](../prompts/v0_2_shot_prompts.md)
- FLF2V 槽：[`03_flf2v_api_slots.json`](03_flf2v_api_slots.json)
- 状态脚本：[`../scripts/clip_status.py`](../scripts/clip_status.py) · [`../reviews/CLIP-STATUS.md`](../reviews/CLIP-STATUS.md)
