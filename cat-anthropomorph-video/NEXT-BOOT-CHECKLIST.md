# 下次开机验证清单 · Wan2.1 I2V fp16

> 目的：验证第一只猫 I2V 的 raw noise / PSNR≈10 废片是否由 fp8 UNET + SageAttention 导致。
> 前提：**需用户明确授权开机**；任意时刻只开一台；不自动充值；不碰 `ai-realistic-comic/` 或 NSFW。

## A. 开机前（离机可做）

- [ ] `git status` 确认只改本仓库预期文件；未 pull/merge 他人分支。
- [ ] `bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → exit 0。
- [ ] 确认 `workflow/02_i2v_wan21_480p.json` 内部 id 为 `cat-anthro-i2v-wan21-480p-fp16`。
- [ ] 确认 02 的 UNETLoader widgets 为 `wan2.1_i2v_480p_14B_fp16.safetensors`。
- [ ] 确认 03 的 UNETLoader widgets 为 `wan2.1_flf2v_720p_14B_fp16.safetensors`（如本次跑高潮段）。
- [ ] 准备一张真实竖屏首帧，替换 `LoadImage` 占位文件名；负向使用 `prompts/negative.txt`。
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
- [ ] 如遇注意力精度异常，可试 `--force-upcast-attention`（ComfyUI#6987）。
- [ ] 推荐：`python main.py --listen 0.0.0.0 --port 6006`。
- [ ] 启动日志中确认没有 SageAttention patch / sage attention 字样。

## D. Workflow 核对（02 I2V）

- [ ] UNET = `wan2.1_i2v_480p_14B_fp16.safetensors`。
- [ ] CLIP = `umt5_xxl_fp8_e4m3fn_scaled.safetensors`，type=wan。
- [ ] VAE = `wan_2.1_vae.safetensors`。
- [ ] CLIP Vision = `clip_vision_h.safetensors`。
- [ ] `CLIPVisionEncode` crop=none。
- [ ] `ModelSamplingSD3` shift=8。
- [ ] `WanImageToVideo` 480×832，length=33，batch=1。
- [ ] `KSampler` steps=20，cfg=6，uni_pc，simple。
- [ ] 正向提示词已无 anime maid；为 A 小橘猫拟人前缀 + 慢转身。
- [ ] 输出为 `CreateVideo` + `SaveVideo`，fps=16。

## E. 真跑（短样片）

- [ ] 只跑一段 480×832 / length=33 的 smoke，不做量产。
- [ ] 记录开始/结束时间、显存峰值、输出路径、耗时。
- [ ] 输出先不要剪映加工，保留原始文件。
- [ ] 跑完立即 `python3 cat-anthropomorph-video/scripts/noise_gate.py <输出视频>`。
- [ ] 门禁必须 exit 0；若 exit 2，按 F 处理，**不得**把废片当成功。

## F. 人眼与指标验收

- [ ] 人眼可见猫拟人主体（头盔/露耳/军装至少可辨），不是纯噪点、黑屏或色块。
- [ ] 首帧与输入图构图一致，没有明显漂移。
- [ ] 可选：用 ffmpeg/PSNR 工具对首帧与输入首帧做对比，记录 PSNR；目标显著高于事故时的 ≈10 dB。
- [ ] 若仍噪：
  - [ ] 确认实际加载的是 fp16，而不是 fp8。
  - [ ] 确认启动参数无 `--use-sage-attention`。
  - [ ] 再试 `--force-upcast-attention`。
  - [ ] 降低分辨率/length 排查显存，但不要优先退回 fp8。
  - [ ] 保存 ComfyUI 日志与失败视频到 artifacts，更新 `PROGRESS.md`。

## G. 收尾

- [ ] 记录本次是否通过、实际耗时、磁盘增量、PSNR。
- [ ] 将输出/日志路径写入 `PROGRESS.md`；真实通过前不写“成功”。
- [ ] **关机留盘**（不要释放并删盘）。
- [ ] 确认未充值、未 merge、未触碰 comic/NSFW。
