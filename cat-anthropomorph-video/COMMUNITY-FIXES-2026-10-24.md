# 社区修正落库 · Wan2.1 I2V 噪点废片（2026-10-24）

> 范围：仅 `cat-anthropomorph-video/` SFW 管线。未开机、未跑 GPU、未充值、未 merge；未触碰 `ai-realistic-comic/`。
> 官方模板：`/tmp/wan-official/image_to_video_wan_example.json`（ComfyUI 官方 Wan I2V 示例）。

## 1. 事故现象（用户报告）

- 第一只猫的 I2V 输出为 **raw noise / 噪点废片**，主体不可辨。
- 对输入首帧的 **PSNR ≈ 10 dB** 量级，远低于可用视频。
- 同一仓库旧默认使用 `wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors`。

## 2. 根因假设（按优先级）

1. **fp8_e4m3fn UNET 精度不足**：官方 I2V 示例默认 `wan2.1_i2v_480p_14B_fp16.safetensors`；fp8 最低档在 14B Wan I2V 上易出现噪声/结构崩坏。
2. **SageAttention 污染 Wan 注意力路径**：ComfyUI#8573 报告 Wan I2V 在 `--use-sage-attention` 下黑屏/废片；本项目旧文档未明确禁止。
3. **注意力精度未上浮**：ComfyUI#6987 建议必要时使用 `--force-upcast-attention` 规避部分精度问题（可选，不是默认必开）。
4. 其他次要因素：fp8 文本编码器、错误首帧/裁切、分辨率与 length 组合；当前先按 1–3 修正并加门禁，不再盲调采样器。

## 3. 已落库修正

### 3.1 Workflow

| 文件 | 修正 |
| --- | --- |
| `workflow/02_i2v_wan21_480p.json` | 内部 id → `cat-anthro-i2v-wan21-480p-fp16`；UNETLoader + `properties.models` → `wan2.1_i2v_480p_14B_fp16.safetensors`；正向去掉 anime maid，换 A 小橘猫拟人前缀；MarkdownNote 写明 fp16 默认、fp8 易噪回退、禁 SageAttention、可选 upcast |
| `workflow/03_flf2v_wan21.json` | 内部 id → `cat-anthro-flf2v-wan21-720p-fp16`；UNETLoader + `properties.models` → `wan2.1_flf2v_720p_14B_fp16.safetensors`；笔记同步 fp16/fp8 口径与启动参数 |

保留官方关键节点与参数，不改连线：

- `ModelSamplingSD3` shift=8
- `CLIPVisionEncode` crop=none
- `WanImageToVideo` / `WanFirstLastFrameToVideo`
- `KSampler` steps=20，cfg=6，`uni_pc` / `simple`
- I2V 竖屏 `480×832`，length=33

### 3.2 Manifest

- `i2v`：新增 **`wan21_i2v_480p_14b_fp16`**（默认/必下，32,791,377,504 B）；原 fp8 标 `optional: true`，注明「VRAM 回退；最低档、易噪，不推荐」。
- `flf2v`：新增 **`wan21_flf2v_720p_14b_fp16`**（默认/必下，32,792,693,440 B）；原 fp8 同样降为 optional。
- group `description` 改为 fp16 default。

### 3.3 启动参数

- **禁止** `--use-sage-attention`（ComfyUI#8573）。
- **可选** `--force-upcast-attention`（ComfyUI#6987）。
- 默认示例：`python main.py --listen 0.0.0.0 --port 6006`，不追加 sage-attention。

### 3.4 噪声门禁

新增 `scripts/noise_gate.py`：

- 对输入图像/视频抽帧（ffmpeg），下采样灰度后计算直方图熵、像素 std、空间粗糙度比、Laplacian std。
- 近随机噪声（高熵 + 高空间粗糙度，或熵接近均匀噪声）→ **exit 2 + FAIL**。
- `--self-test` 内置合成均匀噪声（期望 FAIL）与平滑渐变（期望 PASS）。
- `scripts/smoke_test.sh --dry-run` 已调用 self-test、合成噪声 FAIL、`refs/cats/A/front.jpg` PASS；噪声门禁失败不会 exit 0。

### 3.5 Smoke 门禁

- 02/03 的 required UNET 改为 **fp16**。
- 删除旧「stale fp16」反向检查；改为读取 `UNETLoader.widgets_values`，若仍是 `fp8_e4m3fn` 且没有 fp16 → FAIL。
- restore dry-run 日志必须出现 i2v/flf2v **fp16** UNET。
- dry-run PASS 明示「无真实视频、不代表生成成功」。

## 4. 与官方 I2V 模板对照

已对齐：

- 模型：UNET fp16 / `umt5_xxl_fp8_e4m3fn_scaled` + type=wan / `wan_2.1_vae` / `clip_vision_h`
- `ModelSamplingSD3` shift=8
- `CLIPVisionEncode` crop=none
- `WanImageToVideo`
- `KSampler` 20 / 6 / uni_pc / simple
- `VAEDecode`

仍有意不同（非噪声根因）：

- 竖屏 `480×832`（官方示例 512×512）
- 输出用原生 `CreateVideo` + `SaveVideo`（官方示例用 `SaveAnimatedWEBP` / `SaveWEBM`）
- 正向提示词为项目角色 A 小橘，不再用官方 anime maid 占位
- `LoadImage` 仍为占位文件名，开机后需换成真实首帧

## 5. 尚未验证

- 尚未开机、未安装 fp16 权重、未重跑 I2V、未复测 PSNR。
- 下次开机必须按 [`NEXT-BOOT-CHECKLIST.md`](NEXT-BOOT-CHECKLIST.md) 验证；在真实视频产出并通过 `noise_gate.py` 前，不得写“成功”。

## 6. 参考

- ComfyUI#8573：Wan I2V 与 SageAttention 的黑屏/废片报告  
  <https://github.com/comfyanonymous/ComfyUI/issues/8573>
- ComfyUI#6987：`--force-upcast-attention` 相关讨论  
  <https://github.com/comfyanonymous/ComfyUI/issues/6987>
- 官方模板：`/tmp/wan-official/image_to_video_wan_example.json`
- 权重仓库：<https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged>
