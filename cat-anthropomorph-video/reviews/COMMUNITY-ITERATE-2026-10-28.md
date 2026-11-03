# 社区 · 提升与迭代方案 · 2026-10-28

> 来源：[Notion · 社区 · 提升与迭代方案 · 2026-10-28](https://app.notion.com/p/63a904f7936f419badd70819d6a45068)  
> 范围：仅 `cat-anthropomorph-video/` SFW。本轮 **docs-only / ¥0 / 未开机 / 未跑 Comfy / 未充值 / 未 release**；禁 grok CLI / NSFW。  
> 结构：来源链接 / 可复用做法 / 与本仓冲突 / 推荐默认（沿用 [`COMMUNITY-OPTIMIZE-2026-10-25.md`](COMMUNITY-OPTIMIZE-2026-10-25.md) / [`COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md`](COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md)）。  
> 对照：v0.3.2 双评、[`SELF-REVIEW-v0.3.2-2026-10-28.md`](SELF-REVIEW-v0.3.2-2026-10-28.md)、H3 Phase2/3/4 RESULT。下文根因均为**待 A/B 验证的假设**（Notion AI 社区检索；未看 MP4）。

## §0 结论先行

评审估计 ¥0 精剪上限约 6.5，过 7 必须修动作镜。社区证据显示，v0.3.2 三处动作硬伤（门落无过程、S10 旗从沙里长出、S08 道具瞬消）**更像设置自伤，不一定是 H3 上限**：

1. **英雄镜全用了 8 步 turbo**：官方 FL2VA 默认 20 步；8 步 turbo 会减少运动；要动作可到约 25 步，16 步后收益递减；带参考帧需要更多步（[ComfyUI H3](https://docs.comfy.org/tutorials/video/minimax/minimax-h3-native) · [MiniMax 部署](https://platform.minimax.io/docs/guides/local-deploy-h3) · [Reddit 测速](https://www.reddit.com/r/comfyui/comments/1vrxppw/minimax_h3_speedup_test_turbo_lora_vs_kitchen)）。
2. **大状态变化只给了首尾两帧**：首尾差太大时，模型会用溶解、形变或跳变补中间（[Wan FLF #301](https://github.com/kijai/ComfyUI-WanVideoWrapper/issues/301) · [Veo 3.1 指南](https://www.atlascloud.ai/blog/ai-updates/veo-3.1-prompt-guide)），正对应「门直接落好」「旗长出来」。
3. **Wan 时代的负向词、静帧词可能带进了 H3**：H3 用 **BasicGuider**（无 CFG / 负向不生效）；把禁用词写进正向反而会「加概念」。应只写该出现什么：英文、按时间码写动作，并用动作填满时长（[H3 提示指南](https://docs.comfy.org/tutorials/video/minimax/minimax-h3-prompt-guide) · [社区长文 Rule 18](https://huggingface.co/datasets/malcolmrey/various/raw/main/h3-center/docs/MINIMAX_H3_PROMPTING_GUIDE.md)）。本仓 `prompts/negative.txt`（含 still / rifle）与画风锚点 `photoreal cinematic still`（`prompts/look_cards.md`）需核对是否进了 H3 正向。

**默认今天**：照评审默认 **C** 做 ¥0 盲测，同时把 ¥0 包装项修成 **v0.3.3** 一起比。**D6 授权后**再跑一次 S04 定向 A/B（约 1h / ≈¥2），验证上面三条。通过就写进 SOP 用于 B0-02；不通过就止损，按 C 走。

**S08**：推荐改成**扛旗冲锋**（系列默认少拿枪），与 S10 插旗连成一条道具线。

**成本对账（已核实并改 RESULT）**：smoke 记账 **Δ1880 分 = ¥1.88**（[`RESULT-H3-SMOKE`](RESULT-H3-SMOKE-2026-10-27.md) 单位正确）。同一「分→¥」换算（100 分 = ¥1）下：

| 轮次 | 分 Δ | 旧 ¥（错） | 更正 ¥ |
| --- | ---: | ---: | ---: |
| smoke | 1880 | ¥1.88 | ¥1.88（不变） |
| Phase2 | 2560 | ¥25.60 | **≈¥2.56** |
| Phase3 | 540 | ¥5.40 | **≈¥0.54** |
| Phase4 | 1210 | ¥12.10 | **≈¥1.21** |

B 方案「约 ¥10 换不到 0.5 分」的成本被高估了约 **10 倍**；D6 S04 A/B ≈¥2 更合理。

## §1 问题 → 社区解法

| 问题（v0.3.2） | 疑似根因 | 解法（¥0 → GPU） | 来源 / 可复用 | 与本仓冲突 | 推荐默认 |
| --- | --- | --- | --- | --- | --- |
| 门/跳板没有下落过程（跳切 ≈3/10） | 首尾帧状态差过大 + 8 步 | ¥0：遮挡切 + 拍水音效 + 水花/震屏。GPU：20–25 步；或 Multiframe 钉「门半落」；或只给首帧 + 因果句填满 5s | [cut-hide](https://invideo.io/faq/what-is-the-cut-hide-technique-in-ai-filmmaking-and-how) · [Multiframe](https://docs.comfy.org/tutorials/video/minimax/minimax-h3-multiframe) · [关键帧教程](https://www.youtube.com/watch?v=6BcIgZj1-I0) | 现 Phase2/4 英雄镜 = 8 步 turbo + 首尾硬跨 | **今天 ¥0 包装**；D6 跑 V1–V3 |
| S08 道具瞬消（裁剪 + 闪白遮，冲锋只剩 1.55s） | 首帧双手近胸、无稳定持枪；禁用词表有 rifle | 系列「少拿枪」→ **扛旗冲锋**，接 S10 插旗。坚持用枪则首尾都持枪 + keeps holding … throughout | [排障指南](https://unboundai.net/blog/posts/ai-video-artifact-troubleshooting-guide) · 系列镜头规则 | v0.3.2 精剪靠裁切盖枪消 | **推荐改扛旗**（待拍板） |
| S10 旗从沙里长出 | 疑似首帧爪中无旗、尾帧旗已立 | 首帧旗已在爪中；或中间帧钉「旗杆举过头顶」；坏帧可用 Fun ControlNet 遮罩重绘 | [Multiframe](https://docs.comfy.org/tutorials/video/minimax/minimax-h3-multiframe) · [Fun ControlNet](https://docs.comfy.org/tutorials/video/minimax/minimax-h3-fun-controlnet) | 现 FL2VA 首尾硬跨 | 第二轮（仅 A/B 通过后） |
| 涉水/冲锋滑步 | 全身入画 + 低步数 | ¥0：裁到膝上 / 水面遮脚。GPU：写清脚与地面接触因果；姿态用 Q 版骨架 | [动作提示](https://www.atlascloud.ai/blog/tips/mastering-kling-3.0-10-advanced-ai-video-prompts-for-realistic-human-motion) · [动作参考](https://runware.ai/docs/models/minimax-h3/guides/motion-camera-performance) | 真人 Mixamo 会拉细高条 | v0.3.3 膝上裁；禁成人骨架默认 |
| 爪子糊、768→1080 发软 | ffmpeg 直接拉伸 | SeedVR2 / FlashVSR / H3 latent upscaler；先修复再插帧 | [Comfy 超分](https://docs.comfy.org/tutorials/utility/video-upscale) · [官方博客](https://blog.comfy.org/p/upscaling-in-comfyui) | 现 assemble 走 ffmpeg | 第二轮 |
| 镜间色温跳 | 无统一调色 | 英雄镜基准逐镜匹配 + LUT；「做旧新闻片」去饱和 | [调色](https://invideo.io/blog/davinci-color-grading-ai) · [跨模型配色](https://hackernoon.com/how-to-color-match-ai-video-clips-when-every-model-grades-differently) | Phase3 已记色温跳 | v0.3.3 ¥0 包装 |
| drop 落在最弱镜 | 卡点只绑时间 | drop 对最强镜；门落作 build 重音；抽空 0.2–0.5s；切点提前 1–2 帧；补 CC0 音效；可先试 H3 原生音轨（现被 `-an` 丢掉） | [卡点](https://bitcut.app/blog/beat-sync-video-editing) · [drop](https://blog.faderpro.com/techniques/3-tips-for-better-edm-drops) · [变速](https://capcutguide.com/capcut-velocity-edit) | assemble 现丢原生音 | v0.3.3 |
| 脸少、萌感弱 | 战场镜挤占脸部 | 加 1–2 个脸部反应特写（甩水、竖耳、眨眼） | [36氪](https://m.36kr.com/p/3889005328333318) · [钛媒体](https://www.tmtpost.com/7819882.html) · [人人都是产品经理](https://www.woshipm.com/share/6220246.html) | 无 | 系列化后续 |

## §2 workflow 核对（S04 / S05 / S08 / S10）

### 2.1 文件落点

| RESULT 记载名 | 仓库实况 |
| --- | --- |
| Phase2：`workflow_api_fl2va_s04.json` / `…_s10.json` | **未入库**（仅远端 AutoDL 跑过；RESULT 有参数摘要） |
| Phase3：`workflow_api_fl2va_s05.json` / `…_s08.json` | **未入库** |
| Phase4：`workflow_api_fl2va_phase4_s{04,05,08,10}.json` | **未入库** |
| 本仓可对照 | [`workflow/templates/h3_fl2va_i2v_slots.json`](../workflow/templates/h3_fl2va_i2v_slots.json)（占位契约）· 官方 FL2VA 子图 / 社区 API 样例 · [`prompts/negative.txt`](../prompts/negative.txt) · [`prompts/look_cards.md`](../prompts/look_cards.md) |

> 无法对「已跑过的」API JSON 做字节级 diff；结论来自 RESULT 参数摘要 + 官方/社区 FL2VA 图结构 + 本仓 prompt 契约。本轮新写的 A/B 见 [`../workflow/h3_ab_s04_v1.json`](../workflow/h3_ab_s04_v1.json) 等（**只写不跑**）。

### 2.2 核对表

| 项 | 证据 | 结论 |
| --- | --- | --- |
| **guider 类型** | 官方 I2V/FL2VA 子图与社区 API 样例均为 `BasicGuider`；无 `CFGGuider` | **BasicGuider**（guidance-distilled；无 CFG 旋钮） |
| **cfg** | BasicGuider 不吃 negative；社区口径 cfg≈1 / 「no CFG」 | **负向采样侧不生效** |
| **负向是否接入** | `MiniMaxH3ImageToVideo` 只出 `positive` → BasicGuider；图上无 negative 接线 | **未接入**（与 Wan `CLIPTextEncode` 负向不同） |
| **正向是否含 still / static / slideshow / rifle** | 槽位契约 `h3_fl2va_i2v_slots.json` 仍写 negative must_include `static/still/frozen/slideshow`（Wan 遗留）；`look_cards.md` 正向锚含 **`photoreal cinematic still`** 与 **`no rifle`**；`negative.txt` 含 still/rifle | **风险：静帧词/枪禁用词若被抄进 H3 正向会「加概念」**。远端 Phase2–4 正向原文未入库，**不能断言**已跑片一定含这些词；契约与 looklock 前缀**确实携带**这些词，须在 A/B V2 正向清掉 |
| **采样** | RESULT：turbo 8step · **res_multistep** · simple · length=124 · 768×1344 · 首尾帧 | 与官方默认 euler+8step turbo 略有 sampler 名差；本仓 Phase2 口径以 RESULT 为准 |
| **S08 rifle** | v0.3.2 自评：步枪/旗交互爪糊、步枪瞬消靠裁切盖 | 与「负向/系列禁枪 + 首帧未定义道具」假设一致；**推荐改扛旗冲锋** |

### 2.3 推荐默认（本仓 H3）

- 英雄镜：**20 步、去 turbo**；草稿/选 seed 才用 turbo（强度约 0.6–0.8）。
- **不写负向**；正向英文、按 `[Shot N]` / 时间码写动作并填满时长；**禁止** still / static / slideshow 进正向。
- 大状态变化：中间关键帧或只给首帧 + 因果句；不靠首尾两帧硬跨。
- 系列默认**无枪**；S08→S10 用旗做道具线。

## §3 D6 S04 定向 A/B（待授权 · 约 1h / ≈¥2）

共用：S04 首帧、seed **2026102791**、length **124**、**768×1344**。每档只比上一档多改一项。

| 档 | 文件 | 改动 | 验证什么 |
| --- | --- | --- | --- |
| V0 | 远端既有 Phase4 S04（不重跑） | 8 步 turbo + 首尾帧 | 基线 |
| V1 | [`workflow/h3_ab_s04_v1.json`](../workflow/h3_ab_s04_v1.json) | 去 turbo LoRA，**steps 20**，其余同 Phase2 | turbo 是否削了动作 |
| V2 | [`workflow/h3_ab_s04_v2.json`](../workflow/h3_ab_s04_v2.json) | V1 + 新正向（英文时间码因果；**无负向/静帧词**） | 提示词是否自伤 |
| V3 | [`workflow/h3_ab_s04_v3.json`](../workflow/h3_ab_s04_v3.json) | V2，**去掉尾帧**，只给首帧 | 首尾硬约束是否导致跳切 |

- **通过线**：门板连续可见下落 ≥8 帧（≈0.33s），无溶解/跳变；3 人盲看，≥2 人认为「门是落下来的」。
- **止损**：V1–V3 都不过 → 判本地 H3 上限，按 C 走，不再追加。
- 可选提速：Kitchen Attention ≈快 30%（未验证，不作默认）。

V2 正向要点（写入 JSON）：`hinge releases → ramp slams into the surf → spray bursts → cat flinches, then steps forward`；动作填满 5s。

## §4 SOP 增补（B0-02 起默认）

1. H3 不写负向；正向用英文，按时间码写动作并填满时长；still / static / slideshow 不进正向。
2. turbo 只用于草稿和选 seed；英雄镜 20 步，大动作 25 步（[Turbo 说明](https://huggingface.co/larryvrh/MiniMax-H3-Turbo-Lora) · [强度建议](https://comfyui-wiki.com/en/news/2026-08-08-minimax-h3-turbo-v4) · [FL2VA v1.1](https://www.reddit.com/r/comfyui/comments/1vu7bkw/turbo_lora_v11_for_fl2va_released_minimax_h3)）。
3. 任何状态变化（门落、插旗、道具出现/消失）都必须有中间关键帧或结构引导。
4. 每镜写清道具连续性；系列默认无枪。
5. 英雄镜出 2–3 个 take 再挑；QA 记「第一坏帧」。
6. 出片日志记 steps / LoRA + 强度 / seed / 关键帧时间点 / **实付 ¥（统一：100 分 = ¥1）**。

## §5 迭代路线（摘要）

### ① 今天 ¥0（D5）：v0.3.3 包装 + 盲测

- v0.3.3：重排 drop、抽空、切点提前；CC0 音效（可试 H3 原生音）；调色 + LUT；滑步膝上裁；门落遮挡切。
- 盲测 C：v0.3.2 vs v0.3.3（门是落下来的吗？记得这只猫吗？会看完吗？）。
- 本轮已完成：成本单位更正 + workflow 核对 + A/B JSON 备好。

### ② D6 定向 A/B（需授权）

见 §3。

### ③ 第二轮（仅 ② 通过后）

- 道具线：S08 扛旗 → S10 插旗；looklock 补静帧。
- Fun ControlNet（depth 0.3 + pose 0.7 起步；guidance 1.0）；Blender 灰模；**不用**影视/新闻原片做动作参考。
- 超分：SeedVR2 / FlashVSR 替换 ffmpeg 拉伸。

## §6 合规

网信办「清朗·整治 AI 应用乱象」第二阶段（2026-09）点名 AI「魔改」经典、虚构猎奇剧情（[网信办](https://www.cac.gov.cn/2026-09/02/c_1790099041364574.htm)）；历史题材服装/兵器失实风险（[RFI](https://www.rfi.fr/cn/%E4%B8%93%E6%A0%8F%E6%A3%80%E7%B4%A2/%E5%BE%AE%E8%A8%80%E5%BE%AE%E8%AF%AD/20261010-%E4%B8%AD%E5%9B%BD%E6%8E%80%E8%B5%B7ai-%E5%8E%86%E5%8F%B2%E5%89%A7%E7%83%AD%E6%BD%AE%E5%8D%B4%E5%BC%95%E5%8F%91%E5%8E%86%E5%8F%B2%E5%8F%99%E4%BA%8B%E6%9D%83%E4%B8%8Eai%E5%88%9B%E4%BD%9C%E8%BE%B9%E7%95%8C%E7%9A%84%E4%BA%89%E8%AE%AE)）。继续：AI 标识、片尾「AI 生成 · 致敬历史 · 非真实影像」、旗徽中远景；枪改旗也降低风险。

## §7 待拍板

1. D6 是否授权 S04 定向 A/B（约 1h / ≈¥2）？不授权就纯走 C。
2. S08 改成「扛旗冲锋」（推荐），还是保留步枪？

## §8 相关

- Notion 本页：https://app.notion.com/p/63a904f7936f419badd70819d6a45068
- Opus v0.3.2 审 / 本岗自评 / 切刀与拼装文档（见 PROGRESS 段 39–双评）
- A/B 工作流：`workflow/h3_ab_s04_v{1,2,3}.json`（只写不跑）
