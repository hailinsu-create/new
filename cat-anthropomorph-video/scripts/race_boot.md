# 双机互斥同抢（race boot）· 小猫拟人专用说明

> 本文是 **运维口径文档 + 薄封装约定**，服务 `cat-anthropomorph-video` SFW 管线。  
> **不要**从 `ai-realistic-comic/` 拷贝 NSFW 开机脚本；若需自动化，在本目录另写新文件名实现。

## 任务分工（2026-10-25 强制）

| 任务 | 只许哪台 | 实例 ID |
| --- | --- | --- |
| **Wan / I2V**（方案 A 模板 `02`；R1/R2/R4/场景动作） | **母机 025 only** | `9b4c40bda6-dad38bb9` |
| **Qwen looklock**（定妆模板 `01`） | **克隆 003 only** | `bb8c4f8e12-00c8bdac` |
| FLF2V / 银宝 / 墨墨 / 未授权充值 | **本轮不做** | 见 `reviews/BOOT-AUTH-ASK-2026-10-25.md` |

历史曾写「母=定妆 / 克隆=Wan」——**以本表为准**（I2V 在母盘；looklock 派克隆）。复用槽位见 `workflow/TEMPLATES.md`。

## 实体台账（2026-10-24 Asia/Shanghai）

| 角色 | 实体 | 实例 ID | 区域 / 卡 / 盘 | 状态口径 |
| --- | --- | --- | --- | --- |
| 母 · Wan/I2V only | 025机 | `9b4c40bda6-dad38bb9` | 重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘 | 未开机；开机需用户授权 |
| 克隆 · Qwen looklock only | 003机 | `bb8c4f8e12-00c8bdac` | 重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘 | 未开机；开机需用户授权 |

对应环境变量已写入 `env.example`：`AUTODL_INSTANCE_PRIMARY` / `AUTODL_INSTANCE_CLONE` / `AUTODL_REGION=重庆A`。

角色与参考图：权威锁定见 [`../CHARACTER-LOCK-2026-10-24.md`](../CHARACTER-LOCK-2026-10-24.md)，仓库图像位在 [`../refs/cats/`](../refs/cats/)（三张 jpg 已入库，见 [`../refs/cats/MISSING-UPLOADS.md`](../refs/cats/MISSING-UPLOADS.md)）。

## 口径（互斥 + 分工）

1. **两台实例**：同一镜像/数据盘策略下的「母机」与「克隆」，抢同一区域空闲 4090。
2. **任意时刻只开一台**：同时双开会双倍计费且易抢同一份工作目录；开机前确认另一台为 **已关机**。
3. **Wan/I2V 禁止上克隆**；looklock 派克隆，勿占用母机 I2V 队列跑长定妆。
4. **关机留盘**：停止实例但 **保留数据盘**（权重、定妆、中间视频都在盘上）；不要「释放并删盘」。
5. **未宣称**：本仓库 **不** 声称已开机、已跑 GPU 或已产生计费；实例已创建只代表实体登记。
6. **余额**：以控制台为准；**未授权不充值**；任何开机/租卡动作均需用户明确授权。

## ComfyUI 启动参数（2026-10-24 强制口径）

- **禁止** `--use-sage-attention`：Wan2.1 I2V 易出黑屏/噪点废片（ComfyUI#8573）。
- **可选** `--force-upcast-attention`：规避部分注意力精度问题（ComfyUI#6987），代价是略慢/略耗显存。
- P1 默认 UNET 已切 **fp16**（`wan2.1_i2v_480p_14B_fp16.safetensors`）；`fp8_e4m3fn` 只是 VRAM 最低档回退，易噪，不推荐。
- 启动示例：`python main.py --listen 0.0.0.0 --port 6006`（不要追加 sage-attention）。

## 推荐人工流程（AutoDL）

1. 控制台确认另一台实例状态为关机。
2. 经用户授权后启动对应任务机（I2V→母 025；looklock→克隆 003）；**不要两台一起 Running**。
3. `source .env` → I2V 用 `--group i2v`，looklock 用 `--group looklock`（首次可 `--apply`）。`restore.sh` 同步 `refs/cats/` 到 `$INPUT_ROOT`。
4. 启动 ComfyUI 前核对本页启动参数；I2V 只改方案 A 槽位（见 `workflow/TEMPLATES.md`）；跑完过 noise_gate + motion_gate。
5. 跑完目标后 **关机留盘**。
6. 母机无卡时：**不要**把 Wan/I2V 改派克隆；克隆仅 looklock。

## 花费帽

- `.env` 中 `SPEND_CAP_CNY`（默认建议与系列约定单条 ≈¥6 对齐）仅为提醒。
- 当前余额约 ¥17.25，未充值；超时/超额：**人工停机**；脚本不自动充值、不自动开机。

## 可选薄封装（自行实现，勿抄 comic）

可在本目录新增例如 `scripts/race_status.sh`（只读列实例状态）——**本 PR 不强制提供可执行 API 封装**，因 AutoDL API/令牌因人而异。保持文档口径一致即可。

## 与漫画栈隔离

| 允许 | 禁止 |
| --- | --- |
| 复用「互斥双机 / 关机留盘 / spend_cap」**思路** | 复制 comic 目录脚本、工作流、LoRA、角色资产、提示词 |
| 本目录新建 `restore.sh` / `download_models.py` | symlink 到 `ai-realistic-comic/` |
| 使用 `refs/cats/` 的 SFW 真猫参考图 | 把猫图或工作流复制进 `ai-realistic-comic/` / NSFW 树 |
