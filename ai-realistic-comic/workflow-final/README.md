# workflow-final

可在**全新 AutoDL GPU 机**上重建的最终工作流包：R4 去衣、Qwen-Image 2.1 破衣、路线 C（VNCCS 人偶改姿）、以及抢卡/花费帽辅助。

**新机器请先读 → [`RESTORE.md`](./RESTORE.md)**（从租机到第一张图的逐步命令）。

## 一条命令

```bash
export HF_TOKEN=...
export CIVITAI_API_TOKEN=...
export AUTODL_TOKEN=...          # 普通实例用网页 JWT
bash restore.sh                  # ~46.6 GiB 模型 + smoke 出图
```

## 目录

```text
workflow-final/
├── RESTORE.md          # 租新机恢复手册（耗时/流量）
├── restore.sh          # 一键：ComfyUI pin + 节点 + 模型 + smoke
├── pins.json           # ComfyUI / 自定义节点 commit
├── manifest.json       # 全部模型/LoRA URL·bytes·sha256
├── env.example
├── workflows/          # R4 / Qwen2.1 API JSON + VNCCS UI JSON
├── prompts/            # 去衣 / 破衣 / 七要素模板
├── assets/refs/        # 定妆参考图
├── assets/poses/       # 55 个人偶 pose JSON
├── lib/                # autodl_power / spend_cap / watchdog
└── scripts/
    ├── download_models.py
    ├── smoke_check.py
    ├── run_r4_edit.py
    ├── run_qwen21_torn.py
    ├── run_route_c_pose.py
    └── race_boot.py
```

## 入口脚本

| 脚本 | 用途 |
| --- | --- |
| `run_r4_edit.py` | Edit-2511 FP8 + Lightning + remove/object LoRA（贴回前原图） |
| `run_qwen21_torn.py` | 2.1 int8 + NSFW LoRA（默认 thesealpacas@0.8） |
| `run_route_c_pose.py` | 安装 pose / VNCCS workflow，网页里 Queue |
| `race_boot.py` | 抢卡开机 + spend cap + watchdog；`--power-off` 关机留盘 |
| `smoke_check.py` | 校验 pin/manifest；可选出第一张图 |

## 模型组（`manifest.json`）

- `r4` — Edit-2511 unet/clip/vae + Lightning + remove + object-remover  
- `qwen21` — 2.1 int8 trio + VNCCS LoRA + edit LoRA  
- `nsfw_lora` — Civitai：thesealpacas / femaledVaginus L22 / nsfw-posture  

合计约 **46.6 GiB**。已知 sha256 的 LoRA 做哈希校验；HF 大文件以 **精确字节数** 校验（LFS OID ≠ 内容 sha256）。

## 许可与内容

工作流脚本随本仓库许可。第三方模型 / LoRA / pose 归原作者；NSFW 内容仅限成人角色资产流程。
