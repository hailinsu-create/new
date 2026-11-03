# MiniMax H3 模板占位（v0.3）

> **状态**：默认 I2V 主路 = **本地 MiniMax H3**，见 [`../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md`](../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md)。  
> 本目录仅 **slots / README 占位**；不含大权重、不含可执行 API JSON 真机产物。  
> **未开机、未下载**；Phase1 授权后再填 revision / sha / 真实 Comfy 图。

## 前置

| 项 | 要求 |
| --- | --- |
| ComfyUI | **≥ 0.30.0**（内置 MiniMax H3 模板） |
| 权重根 | Comfy-Org MiniMax-H3 量化件，建议落盘 `$MODEL_ROOT/MiniMax-H3/` |
| 竖屏 | **9:16**；合法画布 **768×1344**（短边 768、边长 ×32） |
| 帧网格 | length ∈ **`17n+5`**；约 24 fps |
| 定妆 | 仍用上级目录 `01_looklock_*`（Qwen）；本目录只接视频 |

## 权重路径约定（占位 · 开机后钉死）

```
$MODEL_ROOT/MiniMax-H3/
  minimax_h3_fl2va_pruned_int8_convrot*     # I2V / 首尾帧 FL2VA
  minimax_h3_ref2va_pruned_int8_convrot*    # R2V Ref2VA（可选）
  qwen3vl_32b_minimax_h3_nvfp4_awq*         # 以 Template Library 清单为准
  <video_vae> / <audio_vae>                 # 扫描后填真名
```

上游：https://huggingface.co/Comfy-Org/MiniMax-H3  
盘预留：**70–120 GB**。

## 本目录文件

| 文件 | 用途 |
| --- | --- |
| [`h3_fl2va_i2v_slots.json`](h3_fl2va_i2v_slots.json) | FL2VA I2V / 首尾帧槽位契约（占位） |
| [`h3_ref2va_slots.json`](h3_ref2va_slots.json) | Ref2VA 参考图槽（占位；首轮可选） |
| 本 README | 约束与路径 |

## 与遗留 Wan 模板关系

| 路径 | v0.3 角色 |
| --- | --- |
| `../02_i2v_wan21_480p.json` 等 | **遗留/对照**；不默认开机跑 |
| `../03_flf2v_wan21.json` | **遗留**；S04/S10 改走 H3 FL2VA |
| 本目录 H3 slots | **默认主路** |

## 音轨

默认成片：**剥离或压低 H3 原生音轨**；外置 CC0 BGM+SFX。可选保留环境音另开实验行。
