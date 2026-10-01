# AutoDL 租卡出图（替代 Colab / 降低 fal 花费）

Colab 路径已放弃（账号拿不到付费 GPU）。出图改为：在 AutoDL 租一张卡，用开源编辑模型跑**同一套**存档双人图配方，再和 `library/stills/*/approved.jpg`（nano-banana-pro 成品）对比。

## 你要租什么

| 项目 | 建议 |
|------|------|
| GPU | **RTX 4090 24GB**（优先）或 3090 24GB；测 Qwen-Image-Edit-2511 |
| 计费 | 按量，测完立刻关机 |
| 镜像 | 控制台选 **PyTorch**，CUDA ≥ 11.8，Python 3.10+（如 torch 2.3 / 2.5 / 2.7） |
| 数据 | 模型缓存和出图写到 `/root/autodl-tmp`（数据盘，关机不丢） |
| 预算 | 50 元：4090 大约能跑十余小时量级（以控制台现价为准）；首次下模型会占时间和磁盘 |

50 元够做**冒烟对比**（两组双人图各 1 张）。不够再充。

## 创建实例（网页点）

1. 控制台 → **容器实例** → **租用新实例**
2. 地区：有卡即可（价格低的区优先）
3. GPU：RTX 4090 × 1
4. 镜像：PyTorch（带 CUDA）
5. 创建并开机 → 复制 **SSH** 命令，或点 **JupyterLab**

## 首次进入机器后（复制整段）

```bash
# 建议用数据盘放代码，避免系统盘满
cd /root/autodl-tmp
git clone --depth 1 --branch cursor/ai-realistic-comic-e63b https://github.com/hailinsu-create/new.git
cd new/ai-realistic-comic
bash autodl/bootstrap.sh
bash autodl/run_smoke.sh
```

跑完后：

- 成品：`/root/autodl-tmp/out/*.png`
- 对比条：`/root/autodl-tmp/out/compare_*.jpg`（左 = 已批准的 nano-banana-pro，右 = 本地开源）
- **立刻关机**，停止计费

用 JupyterLab 的话：打开 Terminal，粘贴上面命令即可。下载可用左侧文件树，或实例页的「自定义服务」/ scp。

## 环境变量（已写进脚本，一般不用改）

```bash
IMAGE_PROVIDER=local
LOCAL_STILL_MODEL=qwen-image-edit-2511   # 或 flux2-klein-4b
LOCAL_CANDIDATES=1
COMIC_QA=0                               # 本地不走 fal 读图裁判
```

单张补跑：

```bash
export IMAGE_PROVIDER=local COMIC_QA=0
comic still-library hades-persephone-throne
comic still-library baisuzhen-xuxian-coil
```

## 和 fal 工作流的关系

| | fal（默认） | AutoDL local |
|--|-------------|--------------|
| 模型 | nano-banana-pro | Qwen-Image-Edit-2511（或 FLUX.2 klein 4B） |
| 角色卡 / still yaml / 构图裁切 | 共用 | 共用 |
| 费用 | 约 $0.15/张起 | 租卡按小时 |
| 质量 | 已批准 | **待你目视对比**；不够再混合「开源底图 + fal 精修」 |

## 若 Qwen 显存不够

```bash
LOCAL_STILL_MODEL=flux2-klein-4b LOCAL_STEPS=4 bash autodl/run_smoke.sh
```

## 安全提醒

- 只在 AutoDL 官网充值。
- 角色与成品为虚构成人向；勿上传真人照片做一致性。
- 测完关机；模型缓存在数据盘可留着下次用，免重复下载。
