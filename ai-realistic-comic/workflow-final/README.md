# workflow-final

可在**全新 AutoDL GPU 机**上重建的最终工作流包，覆盖：

1. **R4 去衣** — Qwen-Image-Edit-2511 FP8 + 去衣/Object LoRA（**贴回前原图**为准）  
2. **路线 C** — 先出图，再用 VNCCS 人偶改姿势  
3. **Qwen-Image 2.1 破衣** — int8 + 七要素长提示词 + NSFW LoRA  
4. **舰队** — 双机互斥抢卡、spend cap、watchdog、关机留盘  

新机器逐步命令（耗时/流量）→ [`RESTORE.md`](./RESTORE.md)。

## 一键从零重建

```bash
export HF_TOKEN=...
export CIVITAI_API_TOKEN=...
export AUTODL_TOKEN=...          # 普通实例填网页 JWT
bash restore.sh                  # ComfyUI pin + 节点 + ~46.6 GiB 模型 + smoke
```

Token **只从环境变量读**；清单见 `manifest.json`（URL / 文件名 / bytes / sha256）。

## 目录

```text
workflow-final/
├── RESTORE.md / restore.sh / pins.json / manifest.json / env.example
├── workflows/     r4_qwen_edit_2511.api.json · qwen21_*.api.json · VNCCS_PoseStudio_QI2.1.json
├── prompts/       r4_remove_clothes · r4_torn_edge · torn_long7_qwen21 · seven_elements_template
├── assets/refs/   lin_qipao_nine_tail · gu_chengan_ref · gu_pose_stand
├── assets/poses/  55 × local_user_poses JSON
├── lib/           autodl_power · spend_cap · autodl_watchdog · comfy_util
└── scripts/       download_models · smoke_check · run_* · race_boot
```

## 使用示例（ComfyUI 已在 8188）

### (1) R4 去衣（贴回前原图）

```bash
python3 scripts/run_r4_edit.py \
  --image assets/refs/lin_qipao_nine_tail.png \
  --prompt-file prompts/r4_remove_clothes.txt \
  --out /root/autodl-tmp/out/r4-raw-nude.png
# 破衣边缘改用：--prompt-file prompts/r4_torn_edge.txt
```

默认 LoRA 强度：Lightning 1.0 / remove 0.95 / object-remover 0.75；4 steps。

### (2) 路线 C（VNCCS 改姿）

```bash
python3 scripts/run_route_c_pose.py \
  --char assets/refs/lin_qipao_nine_tail.png
# 装好 pose + UI workflow 后：浏览器打开 ComfyUI → Load
# VNCCS_PoseStudio_QI2.1.json → 选 pose → Queue
```

### (3) Qwen 2.1 + NSFW LoRA 破衣

LoRA smoke（791）推荐权重：

| LoRA | 权重 | 观感 |
| --- | --- | --- |
| `thesealpacas-nsfw-v2.safetensors` | **0.8** | 破口更强，脸/发饰稳（默认） |
| `qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors` | **1.0** | 撕开更狠 |
| `nsfw-posture-v3.safetensors` | 0.85 | 中等偏强 |

```bash
# 默认 thesealpacas@0.8 + prompts/torn_long7_qwen21.txt
python3 scripts/run_qwen21_torn.py --out /root/autodl-tmp/out/q21-torn.png

python3 scripts/run_qwen21_torn.py \
  --lora qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors \
  --lora-strength 1.0 \
  --out /root/autodl-tmp/out/q21-torn-fv.png
```

### (4) 双机互斥抢卡 / 关机留盘

```bash
export AUTODL_TOKEN=...                 # web JWT
export BJB_INSTANCE_UUID=...            # mother
export BJB_CLONE_UUID=...               # clone（有则自动 --dual）

python3 scripts/race_boot.py --dual --cap-yuan 5 --max-minutes 0
# 用完（留盘，不 release）：
python3 scripts/race_boot.py --power-off-fleet
```

## 模型组（`manifest.json`）

| group | 内容 |
| --- | --- |
| `r4` | Edit-2511 unet/clip/vae + Lightning + remove + object-remover |
| `qwen21` | 2.1 int8 trio + VNCCS LoRA + edit LoRA |
| `nsfw_lora` | Civitai thesealpacas / femaledVaginus L22 / nsfw-posture |

合计约 **46.6 GiB**。有 sha256 的 LoRA 做哈希校验；HF 大文件校 **精确字节数**。

## 钉死版本（`pins.json`）

- ComfyUI `v0.39.0` / `b0b743566f65daafc423b4fea8a2fbda94b3384a`
- `ComfyUI_VNCCS_Utils` / `2b0f4041b368e3408cfb826f4cf09e6f8dafa164`

## 盘上有、本包未带（不开机）

| 项 | 说明 |
| --- | --- |
| 完整 ~136 pose 集 | 仓内 vendored **55**；其余靠 VNCCS `repositories/refresh` 拉社区库 |
| SDXL undress 栈 | RealVis / InstantID / Fooocus inpaint 等见 `docs/comfyui-setup.md` + `install_undress_stack.sh`，**不在**本包 46.6 GiB 清单 |
| `comfyui-inpaint-nodes` / `comfyui_segment_anything` 精确 commit | 文档只记「数据盘 git HEAD」，未写入 pins；R4/2.1/VNCCS 路径不依赖它们 |
| 791/592 实例 UUID / SSH / web JWT | 密钥，不进仓；用环境变量或本机 secret 文件 |
| HF 大文件内容 sha256 | LFS OID ≠ 内容哈希；清单里为 `null`，恢复时靠 bytes |

## 许可

脚本随本仓库。第三方模型 / LoRA / pose 归原作者；NSFW 仅限成人角色资产流程。
