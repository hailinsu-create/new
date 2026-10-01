# AutoDL 自动化（和 comic 工作流对接）

目标：你只提供一次 **开发者 Token**，之后一条命令完成：

**开卡 → 拉代码 → 出两组双人图 → 下载结果 → 关机停计费**

Colab 已放弃。手点网页开卡也可以，但推荐走 API。

## 一次性准备（只要做一次）

1. 已注册、实名、充值（你已完成）。
2. 打开 AutoDL 控制台 → **账号 → 设置 → 开发者 Token** → 复制。
3. 把 Token 放进本机或 Cursor Secrets：

```bash
# ai-realistic-comic/.env
AUTODL_TOKEN=你的token
AUTODL_GPU_SPEC=4090D
AUTODL_AUTO_STOP=1
IMAGE_PROVIDER=local
LOCAL_STILL_MODEL=qwen-image-edit-2511
```

> 说明：自动化走的是 **容器实例 Pro API**。规格名以控制台/附录为准（默认 `4090D`）。  
> 若创建失败，把控制台里能租到的 GPU「算力规格 ID」填进 `AUTODL_GPU_SPEC`。  
> 镜像默认 `base-image-l2t43iu6uk`（PyTorch 2.0 / CUDA 11.8），可用 `AUTODL_IMAGE_UUID` 覆盖。

4. 安装依赖：

```bash
cd ai-realistic-comic
pip install -e .
comic autodl doctor
```

`doctor` 能打出钱包余额即表示 Token 可用。

## 一键跑冒烟（推荐）

```bash
comic autodl run
```

默认会：
- 创建（或开机）一张 GPU
- 在机器上 `git clone` 当前分支并 `bootstrap` + 跑  
  `hades-persephone-throne`、`baisuzhen-xuxian-coil`
- 把 `/root/autodl-tmp/out/*` 拉到本机 `output/autodl/<时间戳>/`
- **自动关机**（`AUTODL_AUTO_STOP=1`）

只跑一张 / 不关机：

```bash
comic autodl run --still hades-persephone-throne --no-stop
comic autodl stop          # 记得关机
```

## 已经手动开了一台机器时

从控制台复制 SSH（主机、端口、密码）到 `.env`：

```bash
AUTODL_SSH_HOST=connect.xxx.autodl.com
AUTODL_SSH_PORT=34222
AUTODL_SSH_PASSWORD=...
# 可选：有 Token + UUID 时，跑完仍可自动关机
AUTODL_TOKEN=...
AUTODL_INSTANCE_UUID=pro-xxxx
```

然后同样：

```bash
comic autodl run
```

## 复用同一台实例（省创建时间）

第一次 `run` 创建后会把 UUID 打在日志里，也可看 `/tmp/autodl_instance_uuid.txt`。写入：

```bash
AUTODL_INSTANCE_UUID=pro-xxxx
```

之后 `run` 只会 **开机 → 干活 → 关机**，不再新建。

## 和本地脚本的关系

| 方式 | 谁操作 | 命令 |
|------|--------|------|
| 全自动 | 本机/`comic` | `comic autodl run` |
| 半自动 | 你在 Jupyter 终端粘贴 | `bash autodl/bootstrap.sh && bash autodl/run_smoke.sh` |

两种用同一套 `IMAGE_PROVIDER=local` 出图逻辑。

## 费用注意

- 计费从实例 **running** 开始，到 **关机** 结束；脚本默认会关机。
- 首次下模型很占时间，缓存落在数据盘 `/root/autodl-tmp/hf`，复用同一实例更省。
- 若 `power_off` 失败，日志会警告——请立刻去控制台手动关机。

## 命令一览

```bash
comic autodl doctor   # Token / 余额
comic autodl run      # 全流程
comic autodl stop     # 仅关机
```
