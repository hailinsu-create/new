# 本地 MiniMax H3 主路方案 · v0.3（2026-10-27）

> **用户 t66u 拍板**：用本地 MiniMax H3；**Wan 太差了**。  
> 分支：`cursor/cat-anthropomorph-comfy-pipeline-db82` · PR [#84](https://github.com/hailinsu-create/new/pull/84)  
> 本轮：**纯文档 / 模板占位**；**未开机、未充值、未下载大模型、未 release**。  
> 双机：克隆003 `bb8c4f8e12-00c8bdac` / 母机025 `9b4c40bda6-dad38bb9` · 关机留盘 · race 谁抢到谁全干。  
> 仓内路径：`cat-anthropomorph-video/`（非 `briefs/` 镜像；以本仓为准）。

---

## A. 结论一句话

下一版（**v0.3**）图生视频主路 = **AutoDL ComfyUI + 本地 MiniMax H3-Base**（Comfy-Org 量化权重）；Wan2.1 I2V/FLF **降为遗留/对照，不再默认开机跑**。定妆仍 **Qwen looklock**。

---

## B. 为什么换（对照事实）

| 事实 | 含义 |
| --- | --- |
| 平台同类（猫拟人/萌宠卡点）流量主流是海螺/即梦等 | 开源侧要对齐「动作可读」观感，不能停在幻灯片 |
| 开源侧 2026：H3 本地 Comfy 已成熟；社区反馈二足拟人/动作比 Wan 更稳 | 本岗题材是**直立拟人 + 强动高潮**，模型代际要对口 |
| 本岗 v0.2：市面 Opus **6.0** / 本岗 **6.5**；门落 S04、插旗 S10 **高潮空**，偏幻灯片 | 见 [`SELF-REVIEW-v0.2-2026-10-27.md`](SELF-REVIEW-v0.2-2026-10-27.md) · [`RESULT-v0.2.md`](RESULT-v0.2.md) |
| 继续 Wan 微调（prompt/length/FLF）ROI 低 | 已榨干方案 A + FLF；结构性缺口在模型本身 |

**废止**：默认「下次开机继续跑 Wan I2V/FLF 全片」；Wan 权重/workflow **保留作遗留对照**，不删历史。

---

## C. 技术选型（本地，非云端 API）

### C.1 默认路径

| 项 | 钉死 |
| --- | --- |
| 运行时 | AutoDL ComfyUI **≥ 0.30.0**（内置 MiniMax H3 模板） |
| 模型 | **MiniMax H3-Base** 开源权重（本地）；**不用**海螺/即梦/可灵云端 API |
| 模板族 | T2V / **I2V = FL2VA** / **R2V = Ref2VA**（Comfy Template Library） |
| 定妆 | 仍 **Qwen-Image-Edit looklock**（`workflow/01_*`）；H3 吃 looklock 派生首帧 |
| 拒绝默认 | 8×B200 SGLang 拓扑；本岗默认 = **单卡 4090D/5090** 社区 **INT8 + offload** |

### C.2 权重（草案清单 · 须 Template Library 扫描后钉 revision）

基线示例（以 Comfy Template Library 扫描清单为准，**开机后钉死 revision / sha**）：

| 用途 | 示例文件名（Comfy-Org） | 备注 |
| --- | --- | --- |
| FL2VA（I2V/首尾帧） | `minimax_h3_fl2va_pruned_int8_convrot` | 高潮镜默认 |
| Ref2VA（R2V） | `minimax_h3_ref2va_pruned_int8_convrot` | 锁毛色可选；首轮非必须 |
| 文本/视觉塔 | `qwen3vl_32b_minimax_h3_nvfp4_awq` | 以扫描清单为准 |
| VAE | video / audio VAE（清单内） | 原生立体声相关 |
| 仓库 | https://huggingface.co/Comfy-Org/MiniMax-H3 | 量化件；**不**默认拉全精度全家桶 |

**盘预留**：权重合计估 **70–120 GB**（含缓存/中间态）；开机前确认扩盘与 `df` 余量。

### C.3 明确边界（开源 H3-Base）

| 有 | 无 / 勿越界 |
| --- | --- |
| 约 **768 short-edge** · **24 fps** · 原生立体声 | **无** Context-IR；**无**官方 2K Regenerate |
| 竖屏合法画布：**768×1344**（短边 768、边长 ×32） | 勿用越界 megapixel / 非 ×32 边长 |
| 时长落在 **`17n+5` 帧网格** | 勿随意 length 导致裁切/拉抻伪动作 |
| License：**MiniMax H3 Community License** | 商用/地域注意；本岗试点标 **「内部样片」** |

### C.4 镜头策略（相对 v0.2 高潮痛点）

| 镜 | 策略 | 说明 |
| --- | --- | --- |
| 高潮优先 | **I2V**：首帧 = 定妆派生 | 先打通竖屏 I2V |
| S04 门落 / S10 插旗 | 试 **FL2VA 首尾帧** | 对标 Opus P0；人眼可见门落/插旗 |
| 锁真猫毛色 | 可选 **Ref2VA**（参考图 ≤9） | 首轮以 FL2VA I2V 打通为主，不阻塞 |
| 其余镜 | **默认不全片重跑** | 先两镜盲测；通过再扩 |

### C.5 原生音轨 vs 卡点 MV

| 策略 | 默认？ | 说明 |
| --- | --- | --- |
| **剥离 H3 音轨** 或压低至听不见 | **是** | 成片仍以外置 **CC0 BGM + SFX** 为准（见 `scripts/AUDIO-SWAP.md`），避免与剪辑轨打架 |
| 可选保留环境音 | 否 | 另开一行实验：仅当 SFX 层需要「海浪/金属门」氛围且不抢 BGM 时 |

---

## D. 迁移管线（相对 v0.2）

| 阶段 | 做什么 | 须开机授权？ |
| --- | --- | --- |
| **Phase0 ¥0** | 本文档 + H3 模板 slots/README 占位 + 镜头单对齐 + 换曲 A-lite 可并行；模型下载清单 + 校验脚本**草案**（不执行拉取） | **否**（纯文档） |
| **Phase1 装机** | 开机一台 → 升 Comfy ≥0.30.0 → 拉 H3 权重（盘 **70–120GB** 级）→ **smoke 5s 竖屏 I2V** | **是** |
| **Phase2 高潮补镜** | 用现有 looklock 首帧只重跑 **S04 门落 + S10 插旗**（及必要联镜）H3；门禁：人眼可见位移 + 非静帧 | **是** |
| **Phase3 成片** | 超分（H3 已近 768 短边；竖屏 1080 可用现有 4× 或轻超分）+ 卡点包装 → **v0.3** | 含在开机窗 |

模板占位：[`../workflow/templates/README-H3.md`](../workflow/templates/README-H3.md) · [`../workflow/templates/h3_fl2va_i2v_slots.json`](../workflow/templates/h3_fl2va_i2v_slots.json)。

---

## E. 成本软顶（草案 · **须授权后实核余额**）

| 项 | 估 | 备注 |
| --- | --- | --- |
| 权重下载 + smoke | **¥1–3** | 视盘是否已有、卡型、下行速度 |
| S04 + S10 两镜试点 | **¥2–5** | 默认范围；触顶停机留盘 |
| 全片重跑 I2V | **另估并单列** | **默认不做**；先高潮两镜盲测 |
| 海螺等云端积分 | — | **不走**（用户点名本地 H3） |

余额以 AutoDL 控制台为准（炼丹师7717）；**未经授权不开机、不充值、不 release**。

---

## F. 验收

| 关卡 | 标准 |
| --- | --- |
| Smoke | 竖屏 MP4；主体**不像静帧**；无大面积崩坏 |
| S04 / S10 | 人眼确认**门落 / 插旗动作成立**（对标 Opus P0） |
| 成片目标 | 市面口径冲 **≥7**（不保证一次达到） |
| 不达标 | 记录 H3 参数/提示词再迭代；**不退回 Wan 默认** |

自动门禁（G1/G2/G2m）可沿用装配链作辅助；**可用成片仍须 HUMAN_ACCEPTED**。

---

## G. 明确不做

- 不默认可灵 / 即梦 / 海螺 **云端 API**（除非用户以后另授权对照）
- 不碰漫监 NSFW / 去衣资产；不碰 `ai-realistic-comic/`
- 未经授权：**不开机、不充值、不 release 实例、不下载大权重到生产机**
- 不把 Wan 全片重跑当 v0.3 默认
- 禁止 grok.com CLI / 向用户要设备码

---

## H. 下一步给调度岗（一句话）

**方案已落 LOCAL-H3-PLAN-v0.3；等用户授权开机 Phase1 装机+smoke。**

---

## 附录 · 命令草案（Phase1 · 授权后才执行）

> 下列为草案，**本轮不执行**。路径按抢到的那台 `$COMFY_ROOT` / `$MODEL_ROOT` 实填。

```bash
# 0) 确认余盘 ≥120G、Comfy ≥0.30.0
comfy --version   # 或 python -c 读 package；须 ≥0.30.0

# 1) 拉量化权重（示例；revision/sha 钉死后写入校验脚本）
# huggingface-cli download Comfy-Org/MiniMax-H3 \
#   --include 'minimax_h3_fl2va_pruned_int8_convrot*' \
#   --include 'minimax_h3_ref2va_pruned_int8_convrot*' \
#   --include 'qwen3vl_32b_minimax_h3_nvfp4_awq*' \
#   --local-dir "$MODEL_ROOT/MiniMax-H3"

# 2) Template Library：导入 H3 I2V/FL2VA 竖屏 768×1344；length ∈ 17n+5
# 3) smoke：looklock 首帧 → ~5s 竖屏 MP4 → 人眼非静帧
# 4) 成片拼装：默认去 H3 音轨；外置 CC0 BGM+SFX
```

校验脚本草案占位：未来可扩 `scripts/download_models.py` 增加 `groups.h3`；**Phase0 只登记清单，不拉文件**。

---

## 互链

- 进度：[`../PROGRESS.md`](../PROGRESS.md) 段31  
- 废止注记：[`MAJOR-LEAP-PLAN-v0.2-2026-10-26.md`](MAJOR-LEAP-PLAN-v0.2-2026-10-26.md) 顶部  
- 模板：[`../workflow/TEMPLATES.md`](../workflow/TEMPLATES.md) · [`../workflow/templates/`](../workflow/templates/)  
- 自评锚点：[`SELF-REVIEW-v0.2-2026-10-27.md`](SELF-REVIEW-v0.2-2026-10-27.md)
