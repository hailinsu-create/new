# Motion gate 校准登记 · G2m

> 工具：`scripts/motion_gate.py`（灰度 MAD max vs frame0）  
> 默认阈值：`min_max_mad=11.0`（manifest `groups.i2v.motion_policy.gates`）  
> 口径：**未过 G2m 不得写「可用片段」**。本页只登记标定，不代替真机重跑。

## 正例（R1 敬礼 · 方案 A）

| 项 | 值 |
| --- | --- |
| 标签 | **R1 positive** |
| 日期 | 2026-10-25 |
| tip | `6062ea7` |
| 机位 | 母 025 `9b4c40bda6-dad38bb9` |
| UNET | `wan2.1_i2v_480p_14B_fp16` · length=49 · cfg=6 · shift=8 |
| 启动 | `--force-upcast-attention`；无 sage |
| **max_mad** | **16.27** |
| 阈值 | 11.0 |
| G2m | **PASS** |
| 人眼 | 敬礼可见（臂→爪至帽檐） |
| 产物路径（briefs，mp4 可不入库） | `outputs/motion-fix-i2v-2026-10-25/` |

## 负例 / 静帧基线

| 项 | 值 |
| --- | --- |
| 标签 | **static baseline** |
| 来源 | looklock→I2V 近静帧事故（soft 词 / length=33 时代） |
| **max_mad** | **≈3.6** |
| 相对阈值 | 应 **FAIL**（3.6 ≪ 11） |
| 用途 | 校准「几乎不动」下界；motion_gate self-test 近静帧带必须 < 阈值 |

## 判读

- 过线带：max_mad ≥ 11（R1=16.27 已落在过线带）。
- 近静帧带：≈3.6 → 废片（动作），即使 G1/G2 身份过线。
- 复跑 R2：同正向、换 seed；目标仍 ≥11，并人眼可读敬礼。
- R4 抬头：同模板换 positive；同样过 G2m。

## 命令

```bash
python3 cat-anthropomorph-video/scripts/motion_gate.py path/to/clip.mp4
python3 cat-anthropomorph-video/scripts/motion_gate.py --self-test
```
