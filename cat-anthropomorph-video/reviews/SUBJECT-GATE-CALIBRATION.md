# G2 主体门禁校准登记 · `subject_gate.py`

> 口径（2026-10-25）：灰度 SSIM 带宽 **0.25–0.92**，默认不变。
> **未授权真机校准前，不因合成小样改默认阈值**；本页只登记证据与读法。
> 相关：[`CLIP-STATUS.md`](CLIP-STATUS.md) · [`COMMUNITY-OPTIMIZE-2026-10-25.md`](COMMUNITY-OPTIMIZE-2026-10-25.md) · [`MOTION-GATE-CALIBRATION.md`](MOTION-GATE-CALIBRATION.md) · [`fixtures/qc/README.md`](../fixtures/qc/README.md)

## 一句话

- **低带 <0.25 = FAIL**：噪点/身份崩（与 G1 联判）；低于下沿不是“动作大”，是主体没了。
- **中带 ≈0.45 为工作参考**：真实动作/表情变化常见落点；中带内仍须人眼确认身份。
- **高带 >0.92 = 只 WARN**：可能近静帧，交给 G2m `motion_gate` 判。
- SSIM **不替代人眼身份**；带宽宁宽勿严，降低假阳性。

## 合成 fixtures 对照（可复跑）

| fixture | 用途 | 实测 SSIM | 中心区 SSIM | 默认结果 |
| --- | --- | --- | --- | --- |
| `subject_ref_128x128.pgm` | 参考帧（渐变 + 亮块） | 1.0000 | 1.0000 | **WARN**（高相似，exit 0） |
| `subject_moved_128x128.pgm` | 主体右移 12px | **0.5588** | 0.4081 | **PASS**（中带） |
| `subject_noise_128x128.pgm` | 噪点负样本 | **0.0057** | 0.0138 | **FAIL**（exit 2） |
| `subject_flat_128x128.pgm` | 近似平场/主体丢失 | **0.2562** | **0.0213** | 默认 **PASS 贴下沿**；加中心门禁 **FAIL** |

读法：

- `moved=0.5588` 是“中带偏上”的正样本；`flat=0.2562` 仅比下沿高 0.0062，说明 **0.25 附近不能当身份通过证**，只是 FAIL 护栏。
- 中带工作点按 **≈0.45** 理解（动作片预期区间约 0.35–0.65）；真机 R1/R2/R4 的逐帧中位数待授权后登记，**当前不写实测真机值**。

## 命令

```bash
cd cat-anthropomorph-video
python3 scripts/subject_gate.py --self-test
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_moved_128x128.pgm        # PASS 0.5588
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_noise_128x128.pgm        # FAIL 0.0057 -> exit 2
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_flat_128x128.pgm         # PASS 贴下沿
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  --enforce-center --center-min-ssim 0.15 fixtures/qc/subject_flat_128x128.pgm  # FAIL 中心区
```

## 中心区启发式

- 默认 `--center-fraction 0.6`，只**报告** `center_ssim`，不参与失败。
- 需要抓“边缘像、主体没了”的伪过线时：`--enforce-center --center-min-ssim 0.15`。
- `flat` 整帧 0.2562 但中心区仅 0.0213，说明整帧带宽会被边角结构“抬过线”；中心门禁是**可选补刀**，不设默认。
- 中心区阈值 **0.15** 是当前建议，不是已校准真机阈值；改默认需真机证据。

## 对齐与缩放

- 全参考比较：两侧按共同宽度缩放（上限 256），再按共同高度中心裁剪。
- PGM 参考与视频采样宽度不同（如 128 vs 256）时，现按 256 宽最近邻缩放参考帧，避免假 `width mismatch`；**不改 SSIM 带宽**。
- 错位/比例不一致仍会假失败；发布前必须保持首帧与视频构图一致。

## 与装配/动作门禁

- `assemble_clip.py` 用本门禁作 G2；全过才写 `AUTO_QC_PASS` 与 `candidates.jsonl`。
- 高相似只 WARN，不能单独判静帧；静帧仍由 G2m 阈值 **11**（R1 正例 16.27，静帧基线≈3.6）拦截。
- 低 SSIM 与 G1 噪点同时出现时，优先判废片，不得写「可用片段」。

## 默认值冻结

**0.25 / 0.92 / center 0.6 / center-min 0.15（仅 enforce 时）默认不动**。只有同时具备以下证据才讨论调整：

1. 真机 I2V 样片（含 R1 正例、R4 漂移例、至少一条噪点废片）；
2. 逐帧 SSIM 分布与中心区分布；
3. 人眼身份结论与 G2m 结果对照；
4. 调整前后假阳性/假阴性统计。

在此之前只加 fixture 与文档，不改默认。

## 真机短记（v0.1c R4）

- 2026-10-25：boat_ramp looklock → R4（seed 20261114，克隆 003）多帧 **minSSIM=0.5663 PASS**；详见 [`RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md`](RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md)。默认带宽 **未改**。
