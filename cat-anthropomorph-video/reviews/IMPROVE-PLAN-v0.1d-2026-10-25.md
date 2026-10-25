# 提升方案 · v0.1d（2026-10-25）

> **Notion**：https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99

> **仅规划文档**。未开机、未充值、未 merge、未 stitch 正式成片。  
> 默认路径 = **Opus A**（¥0 有声 + 蒙太奇换 S06 → 盲测）。B 仅条件触发；C 与出片解耦。  
> 增量于既有：[`COMMUNITY-OPTIMIZE-2026-10-25.md`](COMMUNITY-OPTIMIZE-2026-10-25.md) / [`COMMUNITY-I2V-MOTION-2026-10-25.md`](COMMUNITY-I2V-MOTION-2026-10-25.md) / [`COMMUNITY-LOOKLOCK-2026-10-24.md`](COMMUNITY-LOOKLOCK-2026-10-24.md) / [`BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`](BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md) / 段14 Opus 6.6。

## 一句话目标

做出第一个 **有声 + 无「缺」字卡 + 成片层全段仅 HUMAN_ACCEPTED 素材** 的版本 = **v0.1d**（可盲测；发布曲库可 P2）。

## 现状锚点（已定）

| 项 | 值 |
| --- | --- |
| v0.1c | 720×1280 · ~14.9s · **无声** |
| S05 | R4 boat looklock · minSSIM 0.5663 · **HUMAN_ACCEPTED** |
| S06 | 3s 绿底「缺」字卡（共识瓶颈） |
| 有声 | 停在含坏 R4 的 **v0.1b-beatbed** → **须作废** |
| 评审 | 本岗 7.4；Opus 5.5 **6.6**（+1.0）· 瓶颈转剪辑 |

## 社区要点 → 本岗动作映射

| # | 来源（标题 + URL） | 可复用做法 | 成本 | 本岗动作 / 验收 |
| --- | --- | --- | --- | --- |
| 1 | 光影联盟《电商剪辑节奏…完播率》· <https://www.lunxiao.com/article.html?id=23309> | 15s 三段：0–3s 钩子 / 3–12s 起伏 / 末 3s 收束；BPM 定基础切频，情绪拐点局部变速；至少留 ≥1.5s「喘息镜」 | ¥0 | 重排 beat sheet 落点；钩子用真猫→looklock；S02/S03 压缩给 S05/高潮；验收：时间轴三段可标色 |
| 2 | 豆因网《二次剪辑…高完播》· <https://www.douyin766.com/182909.html> | 先打标记再精剪；鼓点卡切 **或** 卡动作完成；爆点前近静帧蓄力；舍得砍 | ¥0 | 只保留 HUMAN_ACCEPTED；坏 beatbed 整轨作废；验收：素材表无 AUTO_QC/RENDER_DONE |
| 3 | 豆因网《PR 蒙太奇…》· <https://www.douyin766.com/182234.html> | 按音乐「呼吸」剪；Speed Ramp 强调动作峰值；J/L-cut 润滑；对比蒙太奇替旁白 | ¥0 | S06 用蒙太奇配方（见下）代替绿卡；敬礼/抬头落点做短 ramp；验收：S06 无「缺」字 |
| 4 | B 站 Opus《完播率…2026》· <https://www.bilibili.com/opus/1165140042381787140> | 完播是入场券；15s 基准≈40%；有效完播>硬完播；前 3s 相关钩子勿标题党 | ¥0 | 盲测问题单含 3s 留存/有效完播/是否认出小橘；不唯完播论 |
| 5 | TrueSight《抖音…注意力工程 2026》· <https://tsight.io/articles/17999147> | 前 3s 视觉冲击+声音引导；情绪曲线控节奏；静音观看仍靠字幕（可选） | ¥0 | 开场硬切+节拍床入；字幕「Normandy 1944」仅收尾；验收：无声预览仍可读钩子 |
| 6 | Morphic《AI 蒙太奇制作器》· <https://morphic.com/zh/resources/tools/ai-montage-maker> | 缺镜用已有片拼蒙太奇或再生（本岗默认**不再生**）；卡重拍切换 | ¥0（再生=须授权） | **默认只用库存 HUMAN_ACCEPTED + 静帧运镜**；不调新模型 |
| 7 | MediaSqueeze Velocity / EchoWave Ken Burns · <https://media-squeeze.com/tools/velocity/> · <https://echowave.io/tools/ken-burns-effect/> | 静图推镜/轻 zoom；speed ramp 推重拍；闪白/闪切（社区常用，参数因片而异→**不确定精确帧数**） | ¥0 | S06/战场缺镜：boat_ramp / looklock 静帧做 1.5–3s Ken Burns；重音处闪白 ≤2 帧（剪映/ffmpeg）；验收：无绿卡、动作可读 |
| 8 | Shorty《Speed Curves…》· <https://shortyedit.com/blog/speed-curves-motion-blur-and-stabilization> | Montage/Hero/Flash-in 等曲线；慢在命中、快在过渡 | ¥0 | 对 R1/R4 峰值做 ±10–20% 局部变速对齐 128 BPM 强拍；验收：门落/抬头/敬礼落在强拍 ±1 帧可听 |
| 9 | POPCUT / ChatCut 曲库说明 · <https://popcut.io/> · <https://chatcut.io/zh/features/ai-music> | 平台向免版税/BPM 锁轨；跨平台授权仍须核对 | ¥0 临时床；发布=P2 | **临时**：`stitch_audio.py` 128 BPM 节拍床；**发布**：目标平台官方曲库或书面授权/CC0（见 AUDIO-SWAP） |
| 10 | 本仓 COMMUNITY-OPTIMIZE §4 + AUDIO-SWAP | 「15s 免责」误区；禁跨平台搬曲 | ¥0 | 成片层只叠合规轨；作废含坏 R4 的 v0.1b-beatbed |
| 11 | 本仓 CLIP-STATUS / assemble_clip | 仅 HUMAN_ACCEPTED 可称可用 | ¥0 | 成片时间线素材白名单 = HUMAN_ACCEPTED；assemble 过线后再 `--human` |

> 不确定项：闪白精确时长、各平台「15s 完播基准」是否仍为 ~40%——标为社区口径，盲测后校准。

## 默认路径 = Opus A · 逐步 checklist

> 全部 ¥0、不开机。工具：剪映/达芬奇/ffmpeg + 本仓 `stitch_audio.py` / `assemble_clip.py`。

1. **作废 beatbed**  
   - [ ] 标记 `outputs/**/v0.1b*beatbed*` 为 **DO_NOT_USE**（含坏 R4）  
   - [ ] 新工作目录：`outputs/v0.1d-b0-01-2026-10-25/`（本机；mp4 可不入库）

2. **锁曲节拍**  
   - [ ] 确认 **128 BPM**（[`BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`](BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md)）  
   - [ ] 临时轨：`python3 scripts/stitch_audio.py … --audio-policy bed --bpm 128`  
   - [ ] 在时间线标强拍（每小节拍 1）；门落 / 卧倒 / 抬头 / 敬礼对齐

3. **S06 蒙太奇配方（替绿底「缺」）** · 目标时长 ≈3s  
   - [ ] 镜 A（~1.0s）：boat_ramp / 诺曼底场景 looklock **静帧** + 轻 Ken Burns（推近或右移）  
   - [ ] 镜 B（~1.0s）：R1/R4 围巾或尘土峰值 **减速 0.7–0.85×** 卡到下一强拍  
   - [ ] 镜 C（~1.0s）：S05 抬头前后各 trim，闪白/硬切入收尾  
   - [ ] **禁止**「缺」字、绿底、未过 HUMAN 的 AUTO_QC 片

4. **S02 / S03 压缩**  
   - [ ] 艇内/起势静帧合计压到 ≤2.5s（把时长让给 S05 + S06 蒙太奇）  
   - [ ] 保留 ≥1 个 ≥1.5s 喘息镜（社区：防碎闪）

5. **落点变速**  
   - [ ] 全局勿匀速碎切；基础镜 1.2–2.0s，拐点 0.6–1.0s  
   - [ ] 动作完成帧落在重鼓（非仅鼓点空切）

6. **成片层门禁**  
   - [ ] 时间线片段表只列 **HUMAN_ACCEPTED**（S05 已过；S06 源片须已是 HA 或静帧+运镜且人眼签 HA）  
   - [ ] 导出后：`assemble_clip.py`（G1/G2/G2m）→ `AUTO_QC_PASS` → 人眼 `--human` → **HUMAN_ACCEPTED**  
   - [ ] 任一段混入坏 R4 / 绿卡 → 整版 FAIL

7. **回归集**  
   - [ ] 静音预览：钩子 0–3s、无「缺」、小橘身份可读  
   - [ ] 有声预览：128 BPM 落点与动作峰值对齐（听检清单见 AUDIO-SWAP）  
   - [ ] 对照：v0.1c（无声+缺卡）不得再当对外样片

8. **导出 v0.1d-audio**  
   - [ ] 规格：竖屏 9:16（720×1280 可接受；有余力升 1080×1920）· ~15s · 有声  
   - [ ] 路径记 PROGRESS / briefs；**二进制可不入库**

9. **盲测问题单（发出前填）**  
   - [ ] 3s 内能否感到「要开战/变身」？  
   - [ ] 能否认出同一只小橘（非噪点、非换脸）？  
   - [ ] S06 是否仍像「缺镜」？  
   - [ ] 节拍是否「踩上」敬礼/抬头？  
   - [ ] 愿否划完（有效完播直觉，不唯数字）

## B 护栏（条件触发 · 本轮不执行）

仅当：**盲测后仍判 S06 蒙太奇不可接受**，且用户**书面授权突破约 ¥8**（余额约 **¥7.35**，以控制台为准）：

| 护栏 | 值 |
| --- | --- |
| 预算上限 | **¥0.6** 档试跑（或用户另批的明确上限） |
| 机位 | **只开克隆 003**；母机关机；禁双开 |
| 内容 | **场景锁首帧**已有 boat_ramp/looklock → 短 I2V 补 S06；方案 A；禁 FLF2V |
| 角色 | **不定妆银宝/墨墨** |
| 计费 | **不充值、不 release**；跑完关机留盘 |
| 门禁 | 新片须 G1+G2+G2m → AUTO_QC → **HUMAN_ACCEPTED** 才进时间线 |

## C · merge 与出片解耦

- **出片（A）不依赖 merge**：本机剪 v0.1d 即可盲测。  
- **merge PR#84**：可并行准备，但 **须用户审 diff 后再合**；合入 ≠ 授权开机/充值。  
- 合入范围预期：门禁/装配/文档；**不含** NSFW、不含强制开机脚本。

## 明确不要做

- [ ] FLF2V / 默认 Lightning  
- [ ] 扩定妆银宝、墨墨  
- [ ] 充值、release 删盘、盲测前开机  
- [ ] 把 AUTO_QC_PASS / RENDER_DONE / 坏 R4 beatbed 当可用成片  
- [ ] 跨平台搬运平台曲库；「15s 所以不侵权」  
- [ ] 碰 `ai-realistic-comic/` / 去衣 / NSFW 社区帖  
- [ ] 向用户再要 A/B/C 选择（**默认已锁 A**）

## 72h 时间表（对齐 Opus · 日历天示意）

| 窗 | 动作 | 产出 |
| --- | --- | --- |
| 0–4h | 作废 beatbed；建 v0.1d 目录；锁 128 BPM 标记 | 时间线空壳 + 强拍点 |
| 4–24h | S06 蒙太奇配方；压 S02/S03；落点变速 | 无声粗剪 v0.1d-silent |
| 24–48h | 叠节拍床；成片层门禁 + `--human`；回归集 | **v0.1d-audio** |
| 48–72h | 盲测问题单；记 PROGRESS；若 FAIL 再议是否触发 B（须授权） | 盲测结论；B 仅条件触发 |

> 本 CloudAgent 回合只交付本文档；上表供本岗后续执行。

## 成功标准（可勾选）

- [ ] 成片 **有声**（至少 128 BPM 合规节拍床）  
- [ ] **无**绿底「缺」字卡  
- [ ] 时间线视频源 **全部 HUMAN_ACCEPTED**（或人眼签 HA 的静帧运镜段）  
- [ ] 已作废含坏 R4 的 v0.1b-beatbed  
- [ ] 通过盲测问题单（或记录明确 FAIL 项）  
- [ ] 未开机 / 未充值 / 未 merge（除非用户另审 C）  
- [ ] 规格约 15s 竖屏；身份可读；SFW  

## 默认下一步（执行句）

**立刻执行 A 的第 1 步：把含坏 R4 的 v0.1b-beatbed 标为 DO_NOT_USE，并新建 `outputs/v0.1d-b0-01-2026-10-25/` 空时间线，按 128 BPM 打强拍标记。**
