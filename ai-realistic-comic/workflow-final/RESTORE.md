# 全新 AutoDL 机器一键恢复（到第一张图）

目标：租一台新 GPU 实例后，只配置三个环境变量，跑一条命令，装好 ComfyUI + 固定 commit 节点 + 全部模型/LoRA + 工作流资产，并出一张 smoke 图。

| 项 | 值 |
| --- | --- |
| 建议 GPU | RTX 4090 / 5090（≥24GB 显存） |
| 数据盘 | **≥80 GiB** 空闲（模型约 **46.6 GiB** + ComfyUI/缓存） |
| 镜像 | AutoDL 常见 PyTorch 2.x + CUDA 12.x（保留机上 torch，不要被 pip 换掉） |
| 本包路径 | 仓库内 `ai-realistic-comic/workflow-final/` |
| 三个密钥 | `HF_TOKEN` · `CIVITAI_API_TOKEN` · `AUTODL_TOKEN` |

`AUTODL_TOKEN`：普通容器实例开机请填 **网页 JWT**（`Authorization`）；Pro 开发者 token 只能查余额/开 Pro 机。本包 `race_boot.py` 会把 `AUTODL_TOKEN` 同时当作 web JWT 使用（若未另设 `AUTODL_WEB_AUTHORIZATION`）。

---

## 总耗时 / 流量（冷启动估算）

| 阶段 | 预计耗时 | 下载量 |
| --- | --- | --- |
| 0 租机 + SSH | 2–10 min（看卡） | — |
| 1 clone 本仓库 | 1–3 min | ~50–200 MiB（含 refs/poses） |
| 2 `restore.sh`：ComfyUI + 节点 + pip | 5–15 min | ~0.5–1.5 GiB |
| 3 `restore.sh`：模型 + LoRA | **40–120 min**（看 hf-mirror/Civitai） | **~46.6 GiB** |
| 4 smoke 第一张图（R4 破衣 4 steps） | 1–4 min | — |
| **合计** | **约 1–2.5 h** | **~47–48 GiB** |

断点续传：模型下到一半可重跑同一条 `bash restore.sh`，已完整且尺寸/sha 对的文件会 `SKIP`。

---

## 0) 租机并登录

1. AutoDL 控制台 → 租用 GPU（北京区即可）→ 数据盘 ≥80 GiB。
2. 开机后打开 JupyterLab / SSH。

SSH 示例（端口/主机以控制台为准）：

```bash
ssh -p <PORT> root@connect.<region>.seetacloud.com
```

预计：2–10 min；下载：0。

---

## 1) 拉仓库（含定妆图 / pose / workflow）

在数据盘上操作：

```bash
mkdir -p /root/autodl-tmp && cd /root/autodl-tmp
# 若 GitHub 慢，先开学术加速再 clone
[ -f /etc/network_turbo ] && source /etc/network_turbo

git clone https://github.com/hailinsu-create/new.git fox-repo
cd fox-repo
git fetch origin cursor/fox-centaur-workflow-final-dbe2
git checkout cursor/fox-centaur-workflow-final-dbe2

cd ai-realistic-comic/workflow-final
ls pins.json manifest.json restore.sh
```

预计：1–3 min；下载：仓库体积（小文件已进仓，无大模型）。

私有仓请改用带 token 的 clone URL，或先 `gh auth login`。

---

## 2) 只配三个环境变量

```bash
cd /root/autodl-tmp/fox-repo/ai-realistic-comic/workflow-final

cat > env.local <<'EOF'
export HF_TOKEN="hf_你的token"
export CIVITAI_API_TOKEN="你的civitai_api_token"
export AUTODL_TOKEN="你的_autodl_web_jwt_或_dev_token"
export HF_ENDPOINT="https://hf-mirror.com"
export COMFY_ROOT="/root/autodl-tmp/comfyui"
export COMFYUI_URL="http://127.0.0.1:8188"
EOF

set -a
source ./env.local
set +a
```

`env.local` 已在 `.gitignore` 友好区外之外：请勿提交。模板见 `env.example`。

预计：1 min；下载：0。

---

## 3) 一条命令恢复（装栈 + 下模型 + smoke）

```bash
cd /root/autodl-tmp/fox-repo/ai-realistic-comic/workflow-final
bash restore.sh
```

`restore.sh` 会依次：

1. 安装 ComfyUI 到 `$COMFY_ROOT`，钉死 `pins.json` 的 commit（v0.39.0 / `b0b74356…`）
2. 安装自定义节点 `ComfyUI_VNCCS_Utils` 钉死 commit
3. pip 装依赖（清华源；**不覆盖**机上 torch）
4. 按 `manifest.json` 用 hf-mirror + Civitai 断点续传下载全部模型/LoRA，并做 size / sha256 校验
5. 放入 workflow JSON、定妆 ref、55 个 pose JSON
6. 拉起 ComfyUI，用林晚棠定妆图跑 **R4 破衣 smoke**，写出第一张图

成功时日志末尾类似：

```text
SMOKE_OK first_image=/root/autodl-tmp/workflow-final-smoke.png
RESTORE_DONE
```

预计：45–140 min；下载：~46.6 GiB。

### 常用开关

```bash
# 只要文件校验 + Comfy 起来，不出图（无 GPU / 先验证下载时）
SKIP_SMOKE_IMAGE=1 bash restore.sh

# 只下某一组：r4 | qwen21 | nsfw_lora
RESTORE_GROUPS=r4 bash restore.sh
```

### 磁盘不够时

```bash
df -h /root/autodl-tmp
# 控制台扩容数据盘后再重跑 restore.sh（可续传）
```

---

## 4) 第一张图在哪 / 本机预览

机器上：

```bash
ls -lh /root/autodl-tmp/workflow-final-smoke.png
```

本机看 ComfyUI（隧道，勿把 8188 暴露公网）：

```bash
ssh -p <PORT> -L 8188:127.0.0.1:8188 root@connect.<region>.seetacloud.com
# 浏览器 http://127.0.0.1:8188
```

若 smoke 时 Comfy 已在跑，后续出图：

```bash
cd /root/autodl-tmp/fox-repo/ai-realistic-comic/workflow-final
# R4 去衣（贴回前原图）
python3 scripts/run_r4_edit.py \
  --image assets/refs/lin_qipao_nine_tail.png \
  --prompt-file prompts/r4_remove_clothes.txt \
  --out /root/autodl-tmp/out/r4-nude.png

# R4 破衣
python3 scripts/run_r4_edit.py \
  --prompt-file prompts/r4_torn_edge.txt \
  --out /root/autodl-tmp/out/r4-torn.png

# Qwen 2.1 + thesealpacas LoRA 破衣
python3 scripts/run_qwen21_torn.py \
  --lora thesealpacas-nsfw-v2.safetensors --lora-strength 0.8 \
  --out /root/autodl-tmp/out/q21-torn.png

# 路线 C：装 pose + UI workflow（在网页里 Load → 选 pose → Queue）
python3 scripts/run_route_c_pose.py
```

预计（单张）：R4 ~1–3 min；Qwen2.1 edit ~2–6 min。

---

## 5) （可选）双机抢卡 / 关机留盘

在**已有实例 UUID** 的控制机或本包所在环境：

```bash
export AUTODL_TOKEN="..."   # web JWT
export BJB_INSTANCE_UUID="你的实例uuid"   # 可选；默认见 lib/autodl_power.py

python3 scripts/race_boot.py --cap-yuan 5 --max-minutes 0
# 用完：
python3 scripts/race_boot.py --power-off
```

关机保留数据盘；**不要 release**。新租机若盘已空，从步骤 1 重新 `restore.sh`。

---

## 清单对照

| 内容 | 位置 |
| --- | --- |
| URL / 大小 / sha256 | `manifest.json` |
| ComfyUI / 节点 commit | `pins.json` |
| 下载器 | `scripts/download_models.py` |
| 一键恢复 | `restore.sh` |
| 定妆 ref | `assets/refs/` |
| 人偶 pose（55） | `assets/poses/local_user_poses/` |
| 提示词 | `prompts/` |
| API / UI workflow | `workflows/` |

大模型不进 Git；只靠公开 HF / Civitai 链接在恢复时拉取。
