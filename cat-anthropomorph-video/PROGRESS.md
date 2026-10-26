# 小猫拟人 · 工作进度日志

> **约定（用户）**：每完成一段工作，同步写入 **GitHub**（本文件 + 必要代码/文档 commit/PR）与 **Notion**（题材页子页或追加）。

## 2026-10-23 17:03 Asia/Shanghai · 段1：ComfyUI 管线骨架落地

- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) · 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82`
- **内容**：`README-PIPELINE.md`（P0–P3）、`workflow/`×3、`manifest.json`、`scripts/`、`prompts/`；与 `ai-realistic-comic/` 隔离；未声称租卡/充值/开机
- **Notion**：https://app.notion.com/p/402b407a692a813c95dfe8301f82573f

## 2026-10-23 17:03 Asia/Shanghai · 段2：社区方案调研 + 定妆路径结论

- **结论**：定妆主路径仍为 **Qwen-Image-Edit-2511 多图真猫参考**；Cursor 生图仅适合 mood 探索，**不能**当锁定包
- **视频**：仓库 Wan2.1 I2V+FLF2V 仍可用；社区倾向后续可试 **Wan2.2 I2V** 升级
- **文档**：见 `README-PIPELINE.md`「定妆分工」与「社区口径」小节

## 2026-10-24 Asia/Shanghai · 段3：双机实体 + 三猫定妆锁定 + 离线验收

- **双机实体**：母-Comfy定妆 **025机** `9b4c40bda6-dad38bb9` / 克隆-Wan **003机** `bb8c4f8e12-00c8bdac`（重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘）；任意时刻只开一台；余额约 ¥17.25、未充值；开机需用户授权
- **三猫定妆锁定**：A **小橘**（橘白长毛）/ B **银宝**（银虎斑折耳）/ C **墨墨**（全黑折耳）；英文固定前缀锁毛色瞳色、露耳、少持枪，见 `prompts/look_cards.md`
- **管线对齐**：`scripts/restore.sh` 默认 dry-run，支持 `--apply` / `--group looklock|i2v|flf2v`；三份 workflow 的 UNET/CLIP/VAE/LoRA 与 `manifest.json`（4090 fp8）对齐；新增 `scripts/smoke_test.sh`
- **离线验收**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**（仅 dry-run；未开机真跑 GPU）
- **Notion**：https://app.notion.com/p/402b407a692a813c95dfe8301f82573f
- **边界**：禁止 grok CLI / 设备码；未触碰 `ai-realistic-comic/` 或任何 NSFW；未声称开机/计费试跑

## 2026-10-24 Asia/Shanghai · 段4：附件入库尝试 + CHARACTER-LOCK / refs/cats 落地

- **附件入库尝试**：按用户所列 `CHARACTER-LOCK-2026-10-24_64b7.md`、三张猫图、`DUAL-CREATE-RESULT-2026-10-24_d231.md` 全盘搜索（`/workspace` 与 `find / -xdev`），均**未找到**；未伪造、生成或下载猫照片
- **权威锁定**：由 `prompts/look_cards.md` + 用户权威字段重建 [`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)：A 小橘 / B 银宝 / C 墨墨 角色表、三套固定英文前缀、`refs/cats/` 路径、双机 ID、SFW 隔离，并与 look_cards / refs / DUAL / 管线文档互链
- **参考图目录**：建立 `refs/cats/{A,B,C}/` + `README.md` + `.gitkeep`；三张 jpg **待重传**，记录于 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)
- **双机对齐**：`DUAL-CREATE-RESULT-2026-10-24.md` 对齐母 `9b4c40bda6-dad38bb9` / 克隆 `bb8c4f8e12-00c8bdac`，补链 CHARACTER-LOCK 与 refs/cats；`scripts/race_boot.md`、`README-PIPELINE.md`、`prompts/look_cards.md`、`SERIES-WW2.md`、`README.md` 引用同步
- **restore**：`mkdir` 增加 `refs/cats/{A,B,C}`；存在 `front.jpg` / `cat-*.jpg` 时**硬拷贝**到 `$INPUT_ROOT/cats/{cat}/raw/`，目标已存在则跳过；`ai-realistic-comic/` 路径仍拒绝
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**；三张 jpg 均缺失时打印 `[smoke][WARN] 参考图待重传`，文档锁定仍通过
- Notion 进度页已由本轮 Cursor 追加段5（CHARACTER-LOCK + refs/cats；jpg 待重传）。
- **边界**：未开机、未跑 GPU、未计费；禁止 grok；未触碰 `ai-realistic-comic/` 或任何 NSFW

## 2026-10-24 Asia/Shanghai · 段5：三张 jpg 重传仍未落地（uploads 路径为空）

- **用户重传声明**：消息给出 uploads 路径 `A-cat-A-ginger-white_3671.jpg` / `B-cat-B-silver-fold_c393.jpg` / `C-cat-C-black-fold_ed9a.jpg`
- **VM 实际**：Cloud Agent VM 全盘（含 `/workspace` 与 `find / -xdev`）仍未收到任何匹配二进制；`uploads` 目录仅有 9 月旧 md/json，无 jpg
- **本轮未做**：未拷贝到 `refs/cats/`、未删 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)、未伪造或生成图片
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → 仍打印三条缺图 `[smoke][WARN]`，其余检查通过
- **请用户改用**：① 本机 `git` 直接加到分支；② PR 评论附 raw 链接；③ 文件 base64/zip 放到可访问处
- **边界**：未碰 NSFW/`ai-realistic-comic`；未用 grok；未开机

## 2026-10-24 Asia/Shanghai · 段6：三猫原图已入库 + 文档收尾

- **入库确认**：仓库 tip `3abef51`，三猫原图六张 jpg 全部到位；每猫首选名与 `front.jpg` 兼容副本字节数一致
- **六路径**：
  - `cat-anthropomorph-video/refs/cats/A/cat-A-ginger-white.jpg` · 262169 B
  - `cat-anthropomorph-video/refs/cats/A/front.jpg` · 262169 B
  - `cat-anthropomorph-video/refs/cats/B/cat-B-silver-fold.jpg` · 247783 B
  - `cat-anthropomorph-video/refs/cats/B/front.jpg` · 247783 B
  - `cat-anthropomorph-video/refs/cats/C/cat-C-black-fold.jpg` · 183198 B
  - `cat-anthropomorph-video/refs/cats/C/front.jpg` · 183198 B
- **文档收尾**：`refs/cats/MISSING-UPLOADS.md` 改写为「已入库」状态页（保留文件名避免断链）；`refs/cats/README.md`、A/B/C README、`CHARACTER-LOCK-2026-10-24.md` 顶部及互链、项目 README / README-PIPELINE / DUAL / SERIES / look_cards / race_boot 同步去除待重传口径
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**；六张 jpg 非空，输出无「参考图待重传」或缺图类 WARN；完整日志 `/opt/cursor/artifacts/smoke-dry-run-cats-ok.log`
- **提交**：GitHub：本轮文档收尾 commit 即将/已 push 到 PR #84 分支。
- **边界**：未开机、未跑 GPU、未计费；禁止 grok；未触碰 `ai-realistic-comic/` 或任何 NSFW

## 约定落库

- Notion Memory：[工作同步：GitHub + Notion](https://app.notion.com/p/402b407a692a81ecb2ddcd6b35b29320)

## 2026-10-24 段8 真机试跑（Asia/Shanghai）
- 双机协同抢：母 025 抢到；克隆全程 shutdown；空卡重试 29 次 ~14.6min。
- smoke --dry-run exit 0；restore --dry-run --group looklock exit 0；ComfyUI+controlnet_aux 落地；Torch CUDA smoke PASS。
- 全量权重 apply 跳过（护余额）；母+克隆已 shutdown；未充值未 release。
- 详见 `GPU-SMOKE-RESULT-2026-10-24.md` / PR#84 评论。

## 2026-10-24 22:40 Asia/Shanghai · 段12：fp16 门禁后本岗评估 + Opus 讨论

- **本岗评估**：`reviews/SELF-EVAL-FP16-GATE-2026-10-24.md` · Notion https://app.notion.com/p/403b407a692a818982c2cc71c07c0a66
- **结论**：噪点根因修通（fp8→fp16）；工程门禁过线；产品门禁（拟人军装+15s）未过；综合约 4.5/10
- **下一步默认**：looklock → fp16 I2V（人眼可见拟人军装才算 G2）
- **Opus 5.5**：[审核报告 · fp16门禁后评估](https://app.notion.com/p/9688fa70f3d74a1385f1b9e859afede5) · 3.5/10；先 ¥0 固化再单次开机
- **边界**：未开机、未充值、未 merge PR #84

## 2026-10-24 23:46 Asia/Shanghai · 段13：社区 looklock 方案

- **简报**：`reviews/COMMUNITY-LOOKLOCK-2026-10-24.md`
- **默认**：官方 `image_qwen_image_edit_2511` + `qwen_image_edit_2511_fp8mixed`（4090D）；多图真猫+军装；可选 Lightning 4-step；再 Wan I2V fp16
- **口径**：Qwen 用 fp8mixed；Wan 用 fp16；全局禁 sage
- Notion 进度段13 / [PR #84 评论](https://github.com/hailinsu-create/new/pull/84#issuecomment-6386208380)
- 未开机、未改仓库 workflow

## 2026-10-25 00:49 Asia/Shanghai · 段15：looklock 定妆试跑成功

- 成图：`outputs/looklock-debug-2026-10-24/cat_anthro_looklock_00001_.png` · RESULT.md
- 人眼过线：拟人橘白+美军装/M1/红围巾露耳 SFW
- tip b4bef3a · Qwen fp8mixed · 克隆003 · ¥2.82 · 余额¥11.90 · 关机留盘

## 2026-10-25 00:59 Asia/Shanghai · 段16：looklock→Wan I2V fp16 短片

- mp4: `outputs/looklock-i2v-2026-10-25/cat_anthro_looklock_i2v_00001_.mp4` · RESULT.md
- G2 PASS（拟人军装可见+微动；noise_gate PASS）· 母025 · fp16 · ¥0.22 · 余额¥11.68 · 关机留盘

## 2026-10-25 00:59 Asia/Shanghai · 段16：looklock→I2V G2 过线

- `outputs/looklock-i2v-2026-10-25/cat_anthro_looklock_i2v_00001_.mp4` · G2 PASS（拟人军装可见+微动）
- 母机025 · fp16 · ¥0.22 · 余额¥11.68 · 关机留盘

## 2026-10-25 01:39 Asia/Shanghai · 段17：I2V 微动自评 + 社区动作方案

- **本岗自评**：`reviews/SELF-EVAL-I2V-MOTION-2026-10-25.md` · 综合约 **6.5/10**
- **结论**：管线真猫→定妆→I2V 已通；产品卡在动作幅度；下一步加强动作，**不改 fp16**
- **社区简报**：`reviews/COMMUNITY-I2V-MOTION-2026-10-25.md`
- **默认路径**：动作句前置+强动词；负向加 static/still；length 33→49；同 looklock 首帧+现有 fp16；验收=人眼可见敬礼/抬头；预期 ~¥0.3–0.5
- **边界**：未开机、未充值、未 release；禁 NSFW/去衣；禁 grok CLI

## 2026-10-25 motion-fix I2V (executor)
- tip `6062ea7` length=49 + strong-verb R1; mother `9b4c40bda6-dad38bb9` after clone DL abort (UNET ETA over ¥1.5)
- **R1 PASS**: salute visible; motion_gate max_mad=16.27; noise_gate ok; R2/R4 skipped
- artifacts: `outputs/motion-fix-i2v-2026-10-25/`; both machines power_off keep disk; no top-up/release
- spend ¥0.47 · bal ¥11.210 · PR #84 comment posted

## 2026-10-25 11:20 Asia/Shanghai · 段21：¥0 离线包 · B0-01 v0-lite

- **范围**：不开机、不充值、不 release；只用现有真猫/looklock/R1 敬礼拼 ~15s 竖屏
- **卡点/分镜**：`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md` · `reviews/STORYBOARD-B0-01-NORMANDY-2026-10-25.md`（BPM 128；缺 S05/S06）
- **R1 证据**：`outputs/motion-fix-i2v-2026-10-25/R1/contact_evidence.png` + `CONTACT-SHEET.md`；校准 `reviews/MOTION-GATE-CALIBRATION.md`（正样本 R1 MAD16.27 + 静帧底 3.6）
- **race_boot**：`DUAL-RACE-MODE.md` + `scripts/race_boot.md` — **I2V/Wan 只开母机 025**；克隆仅 Qwen 定妆
- **成片**：`outputs/v0-lite-b0-01-2026-10-25/B0-01-normandy-v0-lite.mp4`（720×1280 · 30fps · ~14.9s）· README 同目录
- **开机清单**：`BOOT-AUTH-ASK.md`（R2+R4，可选 R6/场景 looklock；不上 FLF2V；不定妆银宝/墨墨）
- **边界**：未开机、未充值、未 merge PR #84

## 2026-10-25 Asia/Shanghai · 段21b：Comfy 模板化（¥0）

- `workflow/templates/wan_i2v_scheme_a.api.json` + `.slots.md`（自 R1 prompt.json；槽位 start_image/positive/seed/filename_prefix）
- `workflow/templates/qwen_looklock.api.json` + `.slots.md` + stub-manifest（自试跑成功 flat API + COMMUNITY-LOOKLOCK）
- `workflow/templates/TEMPLATE-README.md` · `scripts/fill_i2v_template.py`（dry-run OK）
- Notion 子页已补模板节；进度日志段21b
- **边界**：未开机、未充值、未 merge PR #84；开机仍见 `BOOT-AUTH-ASK.md`

- 2026-10-25 16:05 CST：克隆003 直接 Wan I2V 产出 R2+R4（gate PASS），母机未开，克隆已关机留盘，余额≈9840分。

## 2026-10-25 16:05 Asia/Shanghai · 段：克隆003 直出 R2+R4 I2V（不必回母机）

- **授权**：pt42u「克隆机克隆好，出片」· pt43u「不用非要回母鸡」——覆盖「I2V只母机」口径
- **克隆003** 跑 Wan2.1 I2V R2+R4；**母机025 全程 shutdown 未开机**
- **产物**：`outputs/motion-fix-i2v-2026-10-25/R2|R4/*.mp4` · motion_gate **双 PASS**（max_mad≈52.9 / 53.2）
- **收尾**：`r2r4_done.flag` · 克隆 power_off 留盘 · 余额 11210→9840 分（约 ¥13.70）
- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) 评论一句
- **Notion**：题材进度页追加本段

## 2026-10-25 16:10 Asia/Shanghai · 段：R2+R4 拉回质检 + v0.1 拼片（¥0）

- **成片**：[`outputs/v0.1-b0-01-2026-10-25/B0-01-normandy-v0.1.mp4`](outputs/v0.1-b0-01-2026-10-25/B0-01-normandy-v0.1.mp4) · 720×1280 · 14.9s
- **gate**：R2 PASS max_mad=52.860 · R4 PASS max_mad=53.190 · **人眼均为噪点 FAIL**（未入主片）
- **入片**：S04/S07 用 R1 敬礼；S05 looklock 暂代；S06 艇门 looklock 静帧（待 R6）
- **双机**：shutdown · 余额约 **¥9.84** · 本轮未开机未充值
- **文档**：`V0.1-README.md` · `reviews/SELF-EVAL-V0.1-ASSEMBLE-2026-10-25.md` · `BOOT-STATUS-NOW.md`
- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) 评论同步
- **Notion**：进度页追加（见评论链接）

## 2026-10-25 17:25 Asia/Shanghai · 段22：R2/R4 噪点根因修复 + v0.1b

- **根因**：克隆 UNET/CV size-only 伪校验 → corrupt → TV-static；motion_gate 假 PASS
- **修**：HF LFS sha 重拉 + `sha_or_die` + `subject_gate`；Opus 序：R1对照→R4→R2
- **对照 R1**：同 seed/输入 PASS + 人眼敬礼
- **R4/R2**：三闸 + 人眼 PASS → 入 v0.1b S05/S04
- **成片**：`outputs/v0.1b-b0-01-2026-10-25/B0-01-normandy-v0.1b.mp4`（720×1280 · 14.9s）
- **机**：克隆 power_off 留盘；母机全程 shutdown；余额 9840→7720 分；未充值未 release
- **PR**：[#84](https://github.com/hailinsu-create/new/pull/84) 评论同步

## 2026-10-25 20:24 Asia/Shanghai · 段23：v0.1d ¥0 有声+S06蒙太奇（Opus A）

- **授权**：pt51u「先做好提升，开机前告诉我」· 本任务 **零 GPU / ¥0**
- **成片**：[`outputs/v0.1d-b0-01-2026-10-25/B0-01-normandy-v0.1d.mp4`](outputs/v0.1d-b0-01-2026-10-25/B0-01-normandy-v0.1d.mp4)
  - 720×1280 · 30fps · **13.600s** · **有声** 128 BPM sine-tick bed
  - 无声中间件：`B0-01-normandy-v0.1d-silent.mp4`
- **S06**：新蒙太奇替绿「缺」卡（艇门 Ken Burns + s05 减速 + 尾段白闪）· `segments/s06_montage.mp4` ≈2.93s · 整片 greenish=0
- **作废**：`outputs/v0.1b-b0-01-2026-10-25/DO_NOT_USE-beatbed.md` + `B0-01-normandy-v0.1b-beatbed.mp4.DEPRECATED`（坏 R4；原文件未删）
- **段状态**：S04 HUMAN_ACCEPTED · S05 AUTO_QC_PASS · S06 DRAFT-HA/人眼待签（ledger RENDER_DONE）· 其余 RENDER_DONE
- **文档**：`V0.1d-README.md` · `BUILD.txt` · `qc/CHECKLIST.md` · `ffprobe.json` · `review-frames/`
- **边界**：未开机 · 未充值 · 未 release · 未 merge · 未碰 NSFW·ai-realistic-comic · GitHub 同步留给调度 CloudAgent
- **残缺**：非整片 HUMAN_ACCEPTED；S06 非新 GPU 战场镜头；BGM 非商用曲库

## 2026-10-25 20:48 Asia/Shanghai · 段24：S06 战场 I2V → v0.1e

- **授权**：pt53u「授权」· pt54u「补完出片」· 破 ¥8 · **只开克隆003**
- **机**：克隆003 开机跑 Wan fp16 I2V R6；母机025 全程 shutdown
- **参数**：方案 A · length49 · cfg6 · shift8 · steps20 · seed **20261120** · 首帧 boat looklock
- **门禁**：G1 PASS · G2 minSSIM **0.4036** PASS（portrait-crop）· G2m max_mad **43.929** PASS · greenish=0
- **人眼**：艇门/浪花锁住，涉水冲锋，与 S05 抬头围巾区分；无空沙滩/绿「缺」
- **成片**：[`outputs/v0.1e-b0-01-2026-10-25/B0-01-normandy-v0.1e.mp4`](outputs/v0.1e-b0-01-2026-10-25/B0-01-normandy-v0.1e.mp4) · 720×1280 · **13.700s** · 有声 128BPM
- **S06**：新 battlefield I2V 替换 v0.1d 蒙太奇；ledger **AUTO_QC_PASS**
- **花费**：7350→6990 分（Δ -360 / ≈¥0.36）；未充值未 release；克隆 power_off 留盘
- **证据**：`outputs/motion-test-i2v-2026-10-25-s06-battle/RESULT.md` · `BOOT-STATUS-NOW.md`

## 2026-10-25 21:02 Asia/Shanghai · 段25：v0.1f 有声粗剪（¥0）

- **触发**：PR#84 V0.1F-PLAN + 用户 t56u「画面不够精细 / 拟人性不好 / 主题差距」→ 先 A 路径后期叠层
- **成片**：[`outputs/v0.1f-b0-01-2026-10-25/out/B0-01-normandy-v0.1f-rough.mp4`](outputs/v0.1f-b0-01-2026-10-25/out/B0-01-normandy-v0.1f-rough.mp4) · **1080×1920** · **14.900s** · 有声
- **silent**：`out/B0-01-normandy-v0.1f-rough-silent.mp4`
- **BGM**：OpenGameArt **Horde War Drums** · William Hector · **CC0** · 130BPM · https://opengameart.org/content/horde-war-drums-loop
- **剪辑**：钩子真猫→闪白→looklock→boat；S04 敬礼慢放；S05 抬头慢放；S06 涉水；Ken Burns 补密度；片头`诺曼底 · 1944.6.6` / 片尾`Normandy 1944` `#AI生成`
- **相对 v0.1e**：换掉 sine-tick；升 1080；题材字幕+统一调色；无新 I2V
- **文档**：`RESULT-v0.1f-rough-2026-10-25.md` · `BUILD.txt` · `qc/`×8
- **未做**：剪映精踩点 / SFX 库≥2 / v0.1g 定妆（须授权）
- **边界**：未开机 · 未充值 · 未 release · 未 merge · 未碰 NSFW

## 2026-10-26 21:48 Asia/Shanghai · 段：v0.2 完整包收尾（第三次接管）

- **背景**：前两次执行器被平台中断；远端 orch 未重启，续跑至 ORCH_MOTION_DONE
- **winner**：克隆003 `bb8c4f8e12-00c8bdac`；母机025 全程 shutdown 留盘
- **accepted**：S04–S11（I2V+FLF）齐
- **upscale**：8/8 **spandrel-UltraSharp** 真超分（无 ffmpeg 兜底）
- **成片**：[`outputs/v0.2-b0-01-2026-10-26/out/B0-01-normandy-v0.2.mp4`](outputs/v0.2-b0-01-2026-10-26/out/B0-01-normandy-v0.2.mp4) · **1080×1920** · **15.1s** · 有声 · SFX≥4 · 字幕 · 13 刀
- **花费**：54030→49780 分（Δ **-4250** / ≈¥4.25）；软顶/地板未破；未充值未 release
- **关机**：克隆 power_off→shutdown；母机已 shutdown；双机留盘
- **文档**：`outputs/RESULT-v0.2.md` · `BOOT-STATUS-NOW.md`
- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82`（仅 md；大 mp4 不入库）
