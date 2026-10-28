# RESULT-H3-SMOKE — 2026-10-27 Asia/Shanghai

## Verdict
**PASS** — 本地 MiniMax H3（ComfyUI 内置节点）S04 boat_ramp 一镜样片出片成功。

## Instance
- winner：**母机025** `9b4c40bda6-dad38bb9`（重庆A cq-A1 · RTX 4090D）
- 克隆003 `bb8c4f8e12-00c8bdac`：全程 **shutdown**（未开）
- SSH：`root@58.144.141.28:49669`（本机 DNS 假解析 bypass）
- 授权：用户 t68u（开机+拉 H3 权重+出片；软顶约 ¥8）

## 样片
| 项 | 值 |
|---|---|
| 本机路径 | `/workspace/briefs/cat-anthropomorph-video/outputs/h3-smoke-2026-10-27/h3_smoke_S04_boat_ramp_00001_.mp4` |
| 远端 | `/root/autodl-tmp/ComfyUI/output/h3_smoke_S04_boat_ramp_00001_.mp4` |
| 分辨率 | **768×1344** · 24fps · H.264 |
| 时长 | **5.167s**（124 frames） |
| 音频 | AAC stereo 32kHz（H3 原生 AV latent 解码） |
| 体积 | ≈4.15 MiB |
| prompt_id | `f5f74607-f4ec-46f5-bd01-6405c325320f` |
| Comfy 执行 | **359.33s**（含模型装载；8-step turbo） |
| node_errors / prompt_err | **无** |

## 管线
- ComfyUI **0.42.0**（≥0.30；内置 `MiniMaxH3ImageToVideo`，无需额外 custom_nodes）
- workflow：`h3-smoke/workflow_api_i2v_s04.json`（turbo LoRA 8step · res_multistep · simple）
- first_frame：`boat_ramp.png`（looklock 定妆）
- 采样：steps=8 · seed=20261027 · length=124

## 权重清单（`/root/autodl-tmp/ComfyUI/models/`）
| 组件 | 文件 | 约大小 |
|---|---|---|
| diffusion | `diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors` | 20G |
| text encoder | `text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 15G |
| video VAE | `vae/minimax_h3_video_vae_fp16.safetensors` | 4.9G |
| audio VAE | `vae/minimax_h3_audio_vae_fp32.safetensors` | 578M |
| turbo LoRA | `loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors` | 1.9G |
| 日志 | `/root/autodl-tmp/h3-dl.log` → `H3 DL DONE 2026-10-27 11:20:05 +0800` | |

## 花费 / 余额
- session 起点（开机前记）：**48440** 分
- power_off 后：**46560** 分
- 本轮花费：**1880** 分（≈**¥1.880**）
- 软顶 ¥8 / 软底 40440：**未破**
- 未充值、**未 release**、未开第二台

## 关机确认
- `POST /api/v1/instance/power_off` uuid=`9b4c40bda6-dad38bb9` → Success
- API 状态：**shutdown**（disk kept）
- 克隆003：仍为 shutdown

## 已知问题
1. 本机 DNS 将 `connect.cqa1.seetacloud.com` 解析为假 IP `198.18.0.1`，SSH/SCP 必须直连真实 IP。
2. smoke 脚本 `out/` 初拷未走 SaveVideo 的 videos 字段（扫 output 目录补齐）；本机已有完整 mp4 + run.log + ffprobe。
3. `comfyui_controlnet_aux` 缺 cv2 导入失败（与 H3 无关，未装 NSFW/去衣）。
4. 样片为 Phase1 smoke，未做主观 QC / 门禁；直立拟人与门落物理待人工看片。

## 边界
- 未碰漫监 NSFW / 去衣资产；未用 grok CLI / OpenCode Go；未 merge PR。
