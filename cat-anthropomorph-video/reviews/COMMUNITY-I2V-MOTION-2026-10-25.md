# 社区方案 · I2V 动作加强（2026-10-25）

> 范围：仅 `cat-anthropomorph-video/` SFW。未开机改 GPU；未充值；未 merge；未触碰 `ai-realistic-comic/`。
> 根因：**soft 词 + 缺 static 负向 + length=33**，不是 fp16 精度。

## 一句话

默认零新权重：动作前置+强动词（去掉 gentle/slightly/small/soft/subtle）+ 负向补 static/still/frozen + **length 33→49** + 换 seed；仍用 `wan2.1_i2v_480p_14B_fp16`、480×832。验收 = 人眼可见敬礼或抬头 + **G2m**。

## 正向模板

### R1 / R2 · 敬礼（workflow `02` 默认）

```txt
The anthropomorphic cat soldier quickly raises her right paw to the brim of her helmet in a crisp military salute and holds the salute firmly; her chin lifts and she stares straight into the camera; her red neckerchief flutters strongly in the wind. Fixed camera, medium shot, same face, fur pattern and US Army uniform as the first frame.
```

### R4 · 抬头 + 围巾（手被竖裁切时的备胎）

```txt
The anthropomorphic cat soldier snaps her head up and turns to stare directly into the camera, ears perking forward; strong wind whips her red neckerchief and blows dust across the frame. Fixed camera, medium close-up, same face, fur pattern and US Army uniform as the first frame.
```

## 负向（追加 static + Wan 中文静帧词）

见 `prompts/negative.txt`；须含：

`static, still, still picture, frozen, motionless, no motion, barely moving, idle breathing only`

以及 Wan 风格中文：`静态` / `静止` / `静止不动的画面` 等。

## 参数

| 参数 | 旧 | 本轮默认 |
| --- | --- | --- |
| length | 33 | **49** |
| steps / cfg / shift | 20 / 6 / 8 | **20 / 6 / 8** |
| R3 回退 | — | 仅 R1/R2 未过 G2m：cfg=**5** / shift=**10** |
| UNET | fp16 | **不变**；禁 sage；禁 fp8 UNET；用 `--force-upcast-attention` |

## 门禁

- G1 `noise_gate.py`
- G2 身份（人眼）
- **G2m** `motion_gate.py`：灰度 MAD max vs frame0 ≥ ~11（上轮近静帧基线 ≈3.6 的约 3×）。未过 G2m **不得**写「可用片段」。

## 构图

方图 looklock（1024²）→ 480×832 会大幅左右裁切。开机前：

```bash
python3 scripts/crop_check_i2v.py path/to/looklock.png
```

手不在画内 → 跳过敬礼，改跑 R4。

## 参考

- Notion：社区方案 · I2V 动作加强 2026-10-25 / 审核报告 · I2V微动评估
- Comfy Wan I2V：https://docs.comfy.org/tutorials/video/wan/wan-video
