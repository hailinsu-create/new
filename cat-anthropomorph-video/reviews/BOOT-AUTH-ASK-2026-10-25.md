# 开机授权请示 · 2026-10-25

> **状态：等待用户明确授权**。本文不是开机指令；未授权则保持双机关机留盘。  
> 余额约 ¥11.21（以控制台为准）；**不充值**，除非用户另行授权。

## 请求开机做什么（母机 only）

| 序 | 任务 | 实例 | 模板 | 槽位变更 |
| --- | --- | --- | --- | --- |
| 1 | **R2 敬礼复验**（同 R1 正向，换 seed） | **025 母** `9b4c40bda6-dad38bb9` | `workflow/02_i2v_wan21_480p.json` 方案 A | start_image + seed（positive 可同 R1） |
| 2 | **R4 抬头+围巾** | 同上母机 | 同上 | start_image + R4 positive + seed |
| 3 可选 | 诺曼底**场景** looklock（艇/滩气氛静帧） | **003 克隆** `bb8c4f8e12-00c8bdac`（Qwen only） | `workflow/01_looklock_qwen_edit.json` | 真猫 + 军装/场景参考槽 |

互斥：任意时刻只开一台。Wan/I2V **只许母 025**；克隆 **只许** Qwen looklock（见 `scripts/race_boot.md`）。

## 明确不做（本请示范围外）

- **不**跑 FLF2V（`03_flf2v`）
- **不**定妆 / I2V **银宝、墨墨**
- **不**自动充值、不 release 删盘
- **不**碰 `ai-realistic-comic/` / NSFW

## 验收

- 每段：G1 `noise_gate` + G2 人眼身份 + **G2m** `motion_gate`（阈值 11；对照 R1 max_mad=16.27 / 静帧基线≈3.6）
- 方图首帧先 `crop_check_i2v.py`
- 复用说明：`workflow/TEMPLATES.md`

## 授权回复模板（用户可复制）

```text
授权开机：母机 025 跑 R2+R4；[可选：克隆 003 仅 Normandy looklock]；
不充值；不 FLF2V；不定妆银宝墨墨；关机留盘。
```
