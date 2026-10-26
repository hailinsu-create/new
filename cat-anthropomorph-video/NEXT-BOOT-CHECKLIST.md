# 下次开机验证清单 · Wan2.1 I2V fp16

> **2026-10-26 t62u**：下次开机默认按 **v0.2 大改包**（见 [`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md`](reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md)），不按 v0.1h；本文旧清单仅作技术核对。
> 目的：在 fp16 已验证身份稳定的前提下，验证 **强动词 + static 负向 + length=49** 能否产出人眼可见敬礼/抬头，并通过 **G2m**。
> 前提：**需用户明确授权开机**；任意时刻只开一台；不自动充值；不碰 `ai-realistic-comic/` 或 NSFW；**勿再改 fp16 / 勿开 sage**。
> **v0.1g 主清单**：[`BOOT-v0.1g.md`](BOOT-v0.1g.md)。**t60u**：全栈对齐；抢到者本机全流程；勿再按「克隆只定妆 / 母机只 I2V」执行。

## A. 开机前（离机可做）

- [ ] `git status` 确认只改本仓库预期文件；未 pull/merge 他人分支。
- [ ] `bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → exit 0。
- [ ] 确认 `workflow/02_i2v_wan21_480p.json` 内部 id 为 `cat-anthro-i2v-wan21-480p-fp16`。
- [ ] 确认 02 的 UNETLoader widgets 为 `wan2.1_i2v_480p_14B_fp16.safetensors`。
- [ ] 确认 03 的 UNETLoader widgets 为 `wan2.1_flf2v_720p_14B_fp16.safetensors`（如本次跑高潮段）。
- [ ] 准备 looklock 过线首帧；先 `python3 scripts/crop_check_i2v.py <looklock.png>` 确认手是否在 480×832 内。
- [ ] 替换 `LoadImage` 占位；正向确认无 gentle/slightly/small/soft/subtle；负向含 static（`prompts/negative.txt`）。
- [ ] 磁盘至少预留 **35GB**（单个 fp16 UNET 约 32.8GB）；若同时装 I2V+FLF2V fp16，预留 **70GB+**。

## B. 开机与权重（需授权）

- [ ] 控制台确认另一台实例已关机；只启动一台。
- [ ] `source .env`。
- [ ] `bash cat-anthropomorph-video/scripts/restore.sh --apply --group i2v`。
- [ ] 校验 `wan2.1_i2v_480p_14B_fp16.safetensors` 字节数 **32791377504**，不是 fp8 文件。
- [ ] 如跑 FLF2V：`--group flf2v`，校验 `wan2.1_flf2v_720p_14B_fp16.safetensors` 字节数 **32792693440**。
- [ ] `fp8_e4m3fn` 仅在显存实在不够时使用；默认 **不要** 装/选 fp8。

## C. ComfyUI 启动

- [ ] 启动命令 **不得包含** `--use-sage-attention`（ComfyUI#8573）。
- [ ] **必须** `--force-upcast-attention`（ComfyUI#6987）。
- [ ] 推荐：`python main.py --listen 0.0.0.0 --port 6006 --force-upcast-attention`。
- [ ] 启动日志中确认没有 SageAttention patch / sage attention 字样。

## D. Workflow 核对（02 I2V）

- [ ] UNET = `wan2.1_i2v_480p_14B_fp16.safetensors`。
- [ ] CLIP = `umt5_xxl_fp8_e4m3fn_scaled.safetensors`，type=wan。
- [ ] VAE = `wan_2.1_vae.safetensors`。
- [ ] CLIP Vision = `clip_vision_h.safetensors`。
- [ ] `CLIPVisionEncode` crop=none。
- [ ] `ModelSamplingSD3` shift=8。
- [ ] `WanImageToVideo` 480×832，**length=49**，batch=1。
- [ ] `KSampler` steps=20，cfg=6，uni_pc，simple；`ModelSamplingSD3` shift=8。
- [ ] 正向为 **R1 敬礼强动词**（或构图无手时 R4 抬头）；无 soft 词。
- [ ] 负向含 `static, still, still picture, frozen, motionless, no motion` + 中文静帧词。
- [ ] 输出为 `CreateVideo` + `SaveVideo`，fps=16。

## E. 真跑（短样片）

- [ ] 阶梯：R1→R2（敬礼 length=49）→R4（抬头）；仅双败后再试 R3 cfg5/shift10。不做量产。
- [ ] 记录开始/结束时间、显存峰值、输出路径、耗时、seed。
- [ ] 输出先不要剪映加工，保留原始文件。
- [ ] `python3 scripts/noise_gate.py <输出视频>`（G1）必须 exit 0。
- [ ] `python3 scripts/subject_gate.py --start-image <首帧> <输出视频>`（**G2**）必须 exit 0；过低=噪点/身份崩。
- [ ] `python3 scripts/motion_gate.py <输出视频>`（**G2m**）必须 exit 0；近静帧应 FAIL。
- [ ] 人眼可见敬礼或抬头；**未过 G2/G2m 不得写「可用片段」**。
- [ ] `clip_status.py`：先 `RENDER_DONE`；三门禁全过后 `AUTO_QC_PASS`；人眼确认后 `HUMAN_ACCEPTED`。

## F. 人眼与指标验收

- [ ] 人眼可见猫拟人主体（头盔/露耳/军装至少可辨），不是纯噪点、黑屏或色块。
- [ ] 首帧与输入图构图一致，没有明显漂移。
- [ ] 可选：用 ffmpeg/PSNR 工具对首帧与输入首帧做对比，记录 PSNR；目标显著高于事故时的 ≈10 dB。
- [ ] 若仍几乎不动（G2m FAIL）：
  - [ ] 确认正向无 soft 词、负向含 static、length=49。
  - [ ] 确认 crop-check：手是否在画内；否则应跑 R4 而非敬礼。
  - [ ] 再试 R3（cfg=5/shift=10），仍失败再写 FLF2V 预算申请（需授权）。
  - [ ] **不要**回退 fp8 / 不要开 sage。
  - [ ] 保存日志与失败视频，更新 `PROGRESS.md`。

## G. Looklock（Qwen-Image-Edit-2511，可选）

- [ ] `bash cat-anthropomorph-video/scripts/restore.sh --apply --group looklock`；下载 `qwen_image_edit_2511_fp8mixed.safetensors` + `qwen_2.5_vl_7b_fp8_scaled.safetensors` + `qwen_image_vae.safetensors`。
- [ ] **Qwen 默认 fp8mixed（OK）**；Wan 的 fp16 政策不适用，**不要**对 Qwen 加 `--force-fp16`（黑图风险）。
- [ ] 启动命令仍**不得**包含 `--use-sage-attention`。
- [ ] Lightning 4steps LoRA 仅加速可选：只能搭配 fp8mixed 基础模型，不可叠加 fused lightning checkpoint；质量门禁默认 **OFF**（`Enable 4steps LoRA?` = false）。
- [ ] 打开 `workflow/01_looklock_qwen_edit.json`：确认 `LoadImage` #41 = `cats/A/raw/front.jpg`，#83 = `looklock/costume_ref_PLACEHOLDER.png`；正向为 A 小橘美军诺曼底拟人、SFW 不持枪。

## H. 收尾

- [ ] 记录本次是否通过、实际耗时、磁盘增量、PSNR。
- [ ] 将输出/日志路径写入 `PROGRESS.md`；真实通过前不写“成功”。
- [ ] **关机留盘**（不要释放并删盘）。
- [ ] 确认未充值、未 merge、未触碰 comic/NSFW。
