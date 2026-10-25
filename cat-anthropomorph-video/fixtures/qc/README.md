# QC fixtures（合成小样）

> 全部为程序生成的 PGM，不含真实猫图、无版权素材；只用于离线自检/回归。
> 这些是**合成负样本**，不能替代真机视频校准与人眼身份确认。

| 文件 | 用途 | 预期 |
| --- | --- | --- |
| `noise_uniform_96x96.pgm` | G1 噪点负样本 | `noise_gate.py` exit **2** |
| `gradient_smooth_96x96.pgm` | G1 正常图正样本 | `noise_gate.py` exit **0** |
| `subject_ref_128x128.pgm` | G2 参考帧（渐变 + 亮块） | — |
| `subject_moved_128x128.pgm` | 主体右移 12px，带内 | `subject_gate.py` exit **0** |
| `subject_noise_128x128.pgm` | G2 噪点负样本 | `subject_gate.py` exit **2** |
| `subject_flat_128x128.pgm` | 近似平场/主体丢失；整帧 SSIM≈0.26 贴边，中心区极低 | 默认宽带宽下 PASS；加 `--enforce-center --center-min-ssim 0.15` 应 **2** |

## 命令

```bash
cd cat-anthropomorph-video
python3 scripts/noise_gate.py fixtures/qc/noise_uniform_96x96.pgm        # 2
python3 scripts/noise_gate.py fixtures/qc/gradient_smooth_96x96.pgm      # 0
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_moved_128x128.pgm                                  # 0
python3 scripts/subject_gate.py --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_noise_128x128.pgm                                  # 2
python3 scripts/subject_gate.py --self-test                              # 0
```

## 设计意图

- G2 默认带宽 **0.25–0.92**，宁宽勿严，避免把真实动作误判为身份崩；过低才 FAIL，过高仅 WARN。
- 中心区 SSIM 默认只报告；`--enforce-center` 才参与失败，用于抓“边缘像、主体没了”的伪过线。
- 门禁状态拆分见 [`reviews/CLIP-STATUS.md`](../../reviews/CLIP-STATUS.md)；`RENDER_DONE` 不等于可用。
