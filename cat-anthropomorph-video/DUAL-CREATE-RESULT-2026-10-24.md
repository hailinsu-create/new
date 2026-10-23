# 双机创建结果 · 2026-10-24（SFW）

> 范围：仅 `cat-anthropomorph-video/` SFW 小猫拟人管线。**未触碰** `ai-realistic-comic/` 或任何 NSFW/去衣资产。  
> 本文只记录实例登记与运维口径，**不代表已开机、已跑 GPU 或已产生计费**。

## 实体结果

| 角色 | 实体 | 实例 ID | 区域 | GPU | 系统盘 / 数据盘 | 关机策略 |
| --- | --- | --- | --- | --- | --- | --- |
| 母-Comfy定妆 | 025机 | `9b4c40bda6-dad38bb9` | 重庆A | RTX 4090D | 扩盘 100G | shutdown 留盘 |
| 克隆-Wan | 003机 | `bb8c4f8e12-00c8bdac` | 重庆A | RTX 4090D | 扩盘 100G | shutdown 留盘 |

实例 ID 已与用户权威字段对齐：母 **`9b4c40bda6-dad38bb9`** / 克隆 **`bb8c4f8e12-00c8bdac`**；三猫角色与参考图见 [`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md) 与 [`refs/cats/`](refs/cats/)。

对应 `env.example`：

```dotenv
AUTODL_INSTANCE_PRIMARY=9b4c40bda6-dad38bb9
AUTODL_INSTANCE_CLONE=bb8c4f8e12-00c8bdac
AUTODL_REGION=重庆A
```

## 约束与现状

- **任意时刻只开一台**：母机与克隆互斥，开机前确认另一台已关机。
- **余额约 ¥17.25，未充值**：开机/租卡必须由用户明确授权；脚本不自动开机、不自动充值。
- **关机留盘**：停止实例但保留数据盘，不执行「释放并删盘」。
- **当前状态**：两台均未开机；本轮仅完成实体登记、文档与离线 dry-run 验收。
- **参考图**：`refs/cats/{A,B,C}/` 已建目录，三张真猫 jpg 仍**待重传**（见 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)）；不影响本文的双机登记。
- **禁止 grok CLI / 设备码流程**。

## 离线验收

在仓库根目录执行：

```bash
bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run
```

预期 `exit 0`。该验收只解析 workflow、对齐 manifest、检查定妆卡与双机文档、执行 restore dry-run，不连接 GPU。

## 关联文档

- 权威定妆锁定：[`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)
- 参考图索引：[`refs/cats/README.md`](refs/cats/README.md) · 缺失记录：[`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)
- 双机运维口径：[`scripts/race_boot.md`](scripts/race_boot.md)
- 管线 SOP：[`README-PIPELINE.md`](README-PIPELINE.md)
- 定妆卡：[`prompts/look_cards.md`](prompts/look_cards.md)
