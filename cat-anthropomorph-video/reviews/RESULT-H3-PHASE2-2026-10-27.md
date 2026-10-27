# RESULT-H3-PHASE2 — 2026-10-27 Asia/Shanghai

## Verdict
**PASS** — 克隆003 本地 MiniMax H3 FL2VA 双镜（S04 boat_ramp + S10 flag）出片成功；双机 power_off 留盘。

## Instance
- winner：**克隆003** `bb8c4f8e12-00c8bdac`（重庆A cq-A1 · RTX 4090D）· ssh `root@58.144.141.28:22803`
- 母机025 `9b4c40bda6-dad38bb9`：全程 **shutdown**（已留盘；power_off 返回已关机）
- 规则：只开一台；不充值；不 release；跑完 power_off 留盘；试点**无预算软顶**（t75u/t76u）
- 授权：用户续跑第三轮（盯权重→出片→关机→RESULT/PR）

## 样片（本机，二进制不入库）
| 镜 | 路径 | 分辨率 | 帧/时长 | 体积 | prompt_id |
|---|---|---|---|---|---|
| S04 boat_ramp | `outputs/h3-phase2-2026-10-27/h3_phase2_S04_boat_ramp_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 5.6 MiB | `41ee1a62-e347-4038-8302-6dae02d2eac3` |
| S10 flag | `outputs/h3-phase2-2026-10-27/h3_phase2_S10_flag_00001_.mp4` | **768×1344** · 24fps | **124f / 5.167s** | 4.1 MiB | `af667f91-5dce-492b-8c78-b8d1be92ecfa` |

- 远端：`/root/autodl-tmp/h3-phase2/out/` + Comfy `output/`
- Comfy 执行：S04 ≈ **388s**；S10 ≈ **373s**（8-step turbo；含装载）
- node_errors / prompt_err：**无**；`ALL_DONE status=ok` 双镜

## 管线
- ComfyUI（克隆盘）· 内置 `MiniMaxH3ImageToVideo`（FL2VA 首尾帧）
- workflow：`workflow_api_fl2va_s04.json` / `…_s10.json`（turbo LoRA 8step · res_multistep · simple · length=124）
- 首尾帧：Cursor GenerateImage 静帧 → PNG `S04_start/end.png` · `S10_start/end.png`（`outputs/cursor-stills-2026-10-27/` + `phase2_stills/`）
- 编排：本机守护 `/tmp/autodl_race/h3/watch_dl_then_phase2.sh` + 远程 `remote_h3_phase2.py`

## 权重（克隆 `/root/autodl-tmp/ComfyUI/models/`）
| 组件 | 文件 | 约大小 |
|---|---|---|
| diffusion FL2VA | `diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors` | 20G |
| text encoder | `text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 15G |
| video VAE | `vae/minimax_h3_video_vae_fp16.safetensors` | 4.9G |
| audio VAE | `vae/minimax_h3_audio_vae_fp32.safetensors` | 578M |
| turbo LoRA | `loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors` | 1.9G |

- 日志：`/root/autodl-tmp/h3-dl.log` → `H3 DL done 2026-10-27 16:55:06 +0800`
- 途中修复：原 `dl_h3_weights.sh` 在 `source ~/.bashrc` + `set -u` 下秒退；video VAE 完成后父进程已死，补跑 `dl_remaining.sh`（audio+LoRA）；EXISTS 跳过半成品（`.aria2`）；静帧上传对齐 workflow 的 `S04_start.png` 等名

## 花费 / 关机
| 项 | 值 |
|---|---|
| 余额 before（phase2 标记） | **46560** 分 |
| 关机瞬间（watch） | **44330** 分 |
| 余额 final（现查） | **44000** 分 |
| 本轮消耗（before→final） | **≈2560 分（¥25.60）** |
| 克隆003 | **shutdown**（power_off Success） |
| 母025 | **shutdown**（本已关机） |
| 盘 | 双机留盘；克隆约 104G 空 |

## 边界
- 禁 grok / 禁 NSFW；未充值、未 release
- 二进制 mp4 **不入库**；文档入 PR#84
