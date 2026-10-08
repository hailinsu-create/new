# 狐 / 马去衣：语义蒙版管线

2026-10-07 起稿；**2026-10-08 用户拍板修订**见下节。适用 `library/stills/fox-centaur-embrace/` 的四张：林晚棠旗袍九尾 nude / torn，伊莲铠甲半人马 nude / torn。不是身体板，不进 `library/cast/*/body-nude/`。机器：**北京 B 母机 791** `359a49a1c3-4cda10df` + **最多一台**同标准 payg 克隆机（见 ④）。F34 / G09 不开，脚本遇到它们的主机名直接 `FORBIDDEN_HOST`。

## 2026-10-08 用户拍板（必须遵守）

① **取消打分门禁，改 Cursor 观感判定。** 用户明确取消狐/马去衣的均分 ≥9、硬门（`clothes_remain` / `armor_remain` 等）、以及 `SCORE_PENDING` 等待循环。出图后脚本只打印 `VISUAL_JUDGE <actor> <mode> <path>`；是否可用由 Cursor **看 PNG 观感**判定，不再写 `.score-request.json`、不再用 sidecar `passed` 挡 torn / bringup。

② **本次管线参数改动（残留 / 接缝 / 髋 / 腿带）。** 写入 `run_fox_centaur_semantic.py`：
- 残留：首 pass 仍 Fooocus denoise 1.0 + LaMa 预填；之后每轮 **只** big-lama 硬擦 + `RESIDUAL_TOUCH_DENOISE=0.35` 弱贴肤。删除对残留的 mid/high Fooocus（原 0.62–0.88）。
- 伊莲接缝：`ELENA_JUNCTION_BUFFER=48`（相对 `horse_guard_y`）；残留 / 收边 / pixelfill 都不进缓冲带及以下；取消 `elena_torso_pixelfill`。
- 林髋：`HIP_PIXELFILL_MAX_PX=4000`；大于此值跳过，避免大块平涂肉糊。
- 林腿带：残留不进髋下（y≥720）；髋下 leftover 单独 `LEG_SOFT`（LaMa + `LEG_SOFT_DENOISE=0.32` + LOWER 提示）；领口 pixelfill 只填 leftover∩领口带（小 fallback 上限 12000 px）。

③ **hillclimb 已取消。** `workflows/comfyui/hillclimb_until_pass.py` 不再按 mean≥9 循环等分；调用即打印 `HILLCLIMB_CANCELLED` 并以退出码 2 结束。出图用 `bringup_and_run.py` 或 `run_fox_centaur_semantic.py`，然后 Cursor 观感判定。

④ **两台长期保有；跑完关机留盘；禁止 release（2026-10-08 13:44 更正）。**
- 母机 791 + 一台同标准克隆机（扩容 ≥100GiB、RTX 5090、北京 B）长期保留。**上限两台，不准第三台。**
- 收尾：两台都 **关机留盘**（机内 `shutdown` 和/或网页 `power_off`）。**791 与克隆机都不 `release`。**
- 旧规则「克隆停了就释放」对这两台作废（作废的是 13:42 原文里「克隆关了就释放」那一句）。`autodl_power.py release` / `refuse_release` 对保有 UUID 一律 `RELEASE_REFUSED`；`shutdown-fleet` / `power-off` 只关机留盘。克隆 UUID 写在 `/cursor/stores/user/bjb-clone.env` 的 `BJB_CLONE_UUID`（不进仓库）；**一旦写入就永久复用，禁止再下新克隆单**。
- **791→克隆同步**：模型/节点在 791（或仓库）改完后，经中转 ship + `fox-centaur-sync-manifest.json` 对齐到克隆机；`dual_collab_run` 开跑前 `verify_stack_aligned` 校验版本，不一致先同步再出图。
- **新建克隆门槛**：下单 `expand_data_disk≥100GiB`；若新实例扩容不达标，**该半成品**可 abort-release 后换机重来（未入保有舰队前）。入舰队后禁止 release。

⑤ **两机协作模式（13:42 起；13:44 / 13:58 更正，入口 `dual_collab_run.py`）。**
- **互斥单机（13:58）**：任何时刻最多一台开机。取消「两台并行出图」。开机前 `ensure_peer_shutdown` 查对端状态，不是 `shutdown` 就先 `power_off` 或拒绝开机。优先 791；791 抢不到卡 / 克隆锁定中则开克隆机。两台都保有、只关机不释放，封顶两台。因不同时在线，同步只走中转（本机 `/cursor/stores/user/fox-centaur-sync-manifest*.json`、GitHub、或 AutoDL 网盘/文件存储），禁止依赖双机同时在线 rsync。
- **分工**：791 = 首选母机（环境 / 模型 / 权重真源）；克隆机 = 长期保有出图机，791 不可用时临时当母机。演员全部在**当前开机的那一台**跑完（不再林/伊莲分机并行）。
- **硬上限**：任何开新机 / 克隆前 `fleet-cap` / `refuse_third` 先数实例，已有 2 台直接拒绝第三台。
- **抢卡**：791 无空卡时只等卡或改开克隆机，**不另开第三台**；克隆机同理。
- **同步（双向清单，入口 `fleet_sync.py`）**：
  - 中转文件：`fox-centaur-sync-manifest.json`（合并真源）+ `.mother.json` / `.clone.json`（各机快照）。每条记录：路径、sha256、mtime、来源机 UUID/角色、recorded_at。
  - **791 开不了机**：克隆机临时当母机，模型/节点/权重改动记入克隆快照并合并进中转清单；代码/参数仍推 GitHub。
  - **791 恢复后**：必须先 `fleet_sync apply --role mother`（克隆→791 反向同步），`check` 清单与哈希一致后 **791 才允许出图**；不一致则只同步、不出图。
  - **源不写死**：按清单逐文件比 mtime（同刻再比 recorded_at），较新一方胜；禁止旧版本覆盖新版本。`plan` 决定方向（mother↔clone via intermediary）。
  - 开跑前 `dual_collab_run` 调 `fleet_sync.ensure_before_generate`；漂移则先 apply 再跑，仍不一致则 `SYNC_GATE_REFUSE`。
- **克隆复用**：UUID 固定写在 `bjb-clone.env`；以后复用，不反复克隆。新建仅当尚无保有克隆；门槛仍是扩容 ≥100GiB + 5090，半成品不达标才 abort-release。
- **判定**：不打分；脚本打 `VISUAL_JUDGE`；Cursor 看图观感判可用。管线参数按拍板 ②。
- **收尾**：`shutdown-fleet` 两台关机留盘（见 ④）；**绝不 release**。

```bash
python workflows/comfyui/dual_collab_run.py --dry-plan          # 只打印互斥计划
python workflows/comfyui/dual_collab_run.py                     # 确保克隆→互斥单机出图→回传→关机留盘→余额
python workflows/comfyui/dual_collab_run.py --skip-clone         # 仅母机
python workflows/comfyui/dual_collab_run.py --force-role clone   # 强制克隆机（仍先关 791）
python workflows/comfyui/dual_collab_run.py --wait-unlock --skip-clone --light-ship
  # ≥5min 轮询至 791 离开 shutdown_cloning → 母机互斥出图 → 关机留盘；不新建克隆
python workflows/comfyui/autodl_power.py fleet-cap

开机韧性（2026-10-08 补）：`ServerBusy` /「服务正忙」/「状态无法进行开机」按可重试处理，不直接 fatal；实例已是 `running` 时跳过再次 `power_on`；克隆 SSH 优先从实例列表取 `proxy_host`/`ssh_port`（detail 常缺这些字段）。
python workflows/comfyui/fleet_sync.py status
python workflows/comfyui/fleet_sync.py check --role mother --uuid 359a49a1c3-4cda10df
python workflows/comfyui/fleet_sync.py apply --role mother --uuid 359a49a1c3-4cda10df
```

## 为什么改

2026-10-07 早先的 Fooocus 重跑用的是手画矩形和椭圆蒙版：林 nude 6.125（`clothes_remain`）、伊莲 nude 7.375（`armor_remain`）、伊莲 torn 7.75（`intact_clothes`）、林 torn 8.75（近门）。蒙版框不住旗袍裙摆和甲片轮廓，衣服留在蒙版外，单靠抬 denoise 解决不了。这一版先找衣服在哪，再重绘；重绘后再找一遍，只补残留。

## 管线

1. 语义蒙版（`semantic_undress.py`）
   - SegFormer B2 clothes（StartHua）：Upper_clothes、Skirt、Pants、Dress、Belt、Scarf 的并集。这个节点只有一个 IMAGE 输出，布尔输入 True 表示「排除该类」，输出里背景加上 flag 为 False 的类是白色。所以跑两遍：A 遍只放开衣服类，B 遍全部排除（只剩背景），衣服蒙版 = A 且非 B。
   - GroundingDINO + SAM（storyicon，threshold 0.25）补件。林：qipao、cheongsam dress、silk fabric skirt、mandarin collar、shoulder strap、dress hem、white cloth、skirt panel。伊莲：breastplate、pauldron、vambrace、gauntlet、fauld、gorget、golden armor、black glove、gold bracer、black cloth、leather strap、black sleeve、arm guard、choker。SAM 选项名按 `/object_info` 取（`sam_vit_b (375MB)`），不写文件名。
   - 保护区先减掉：脸框、face、hair、glasses、fox tail、高跟鞋；伊莲再加 horse body / horse tail，但只在 y>720（1024×1536 板坐标）以下生效，而且 DINO 明确点名的甲件优先于马身保护，免得腰甲被当成马。
   - 裁到演员 ROI，丢掉过小的碎块，再外扩 10 px，外扩之后再减一次保护区。分带重绘时不再二次外扩，所以蒙版不会越过脸和狐尾的保护边。
   - 伊莲的 SegFormer 只在 DINO 甲件命中 40 px 之内才算数，防止把马背毛色当成衣服。ROI 是 (60,230,560,900)，马身保护线 y=690，对照两张成衣底板核过坐标。
2. torn：不再整块重绘（第一次上机实测：把 62% 衣服区整块交给模型重绘，模型会把完整旗袍/铠甲重新画出来，只剩零星小洞）。现在是：先有同一张的 nude 结果，在衣服蒙版里按固定种子挖锯齿多边形洞（锚点行保证胸、腹一定有洞：林 0.16/0.30/0.44，伊莲 0.14/0.34/0.58；林洞面积 50%、保留领口 7% 和下摆 40%，伊莲 55%、保留下摆 10%），洞里贴 nude 的皮肤，洞外保持原衣服，再对洞沿 16 px 环带跑一遍 denoise 0.55 的「撕裂边」重绘（DifferentialDiffusion，不预填），把边缘画成破口。没有 nude 文件时 torn 先自己跑 nude。
3. 预填：Acly `INPAINT_MaskedFill`，`fill=neutral`。不用 Telea / NS 当去衣预填。等价 Fooocus 的 Disable initial latent + Modify Content。
4. Crop and Stitch：SDXL 固定 1024。蒙版按 420 px 高度分带，每带单独裁剪重绘再贴回，不用一个大洞。内容占比封顶 `MAX_CONTENT_FRAC=0.52`，伊莲只裁人躯干、手臂、腰接缝，不进马身。
5. 重绘：RealVisXL V5.0 fp16（非蒸馏写实 SDXL）+ Fooocus inpaint v2.6 patch（`fooocus_inpaint_head.pth`、`inpaint_v26.fooocus.patch`）。nude denoise 1.0，cfg 7。衣服 pass 不开 DifferentialDiffusion。正向提示词里**不写否定句**（「no armor」「no metal」CLIP 会当成概念加进去，实测会把铠甲画回来），否定词只放负向提示词。林的下半身分带（y≥640）用单独的腿部提示词，因为通用提示词里的乳房/肚脐词在腿上没意义，而且旧提示词会让模型在腿侧重画裙片，甚至画出手提包。
6. 残留检查（nude）：对结果再跑一遍，**只信 SegFormer 加窄提示词**（林：silk cloth、shoulder strap、white cloth、mandarin collar；伊莲：glove、bracer、armor plate、choker、strap、black sleeve），再限制在原衣服蒙版外扩 24 px 内、丢掉 <2500 px 的碎块。原来的整套衣服提示词在裸身上也会命中，残留比会大于 1，是误报。残留面积 / 原衣服面积 <5% 才算净；否则只对残留区域再重绘，最多 3 轮，**保留残留最小的那一轮**，不用最后一轮。
7. 收边：蒙版边界 14 px 环带，denoise 0.42，开 DifferentialDiffusion，关预填。
8. InstantID：默认不开。脸在保护区里没被重绘，锁脸是多余的；去衣后 identity 若掉到 9 以下再手动加。头肩图和 `ApplyInstantID` 图在 `scheme_still_fox_centaur_undress.py` 的 `instantid_inpaint_graph`。

顺序：先两张 nude，再两张 torn。不开 ReActor。

## 容错

- DINO 一批提示词里有一条没检出导致整图报错时，改成逐条提示词重跑，没检出的按空蒙版处理，日志 `DINO_EMPTY`。
- DINO 节点的 MASK 输出口按 `/object_info` 找。SegFormer 节点只有 IMAGE 输出，用两遍相减，不再猜槽位。
- 一批 DINO 提示词全部逐条重跑也都报错（节点本身坏了，不是没检出）时报 `DINO_ALL_FAILED` 并停，不再把它当空蒙版继续出图。
- 衣服蒙版占整图 <0.5% 报 `MASK_EMPTY`，>35% 报 `MASK_SUSPECT`（多半是输出口取错），都不继续出图。

## 入口

在北京机上（ComfyUI 监听 127.0.0.1:8188）：

```bash
# 只检查节点是否装齐
python workflows/comfyui/run_fox_centaur_semantic.py --check-stack

# 四张批跑；输出到 library/stills/fox-centaur-embrace/semantic/
python workflows/comfyui/run_fox_centaur_semantic.py --only lin elena --mode both

# 单张重试：换种子（attempt 每加 1，所有种子 +1000）
python workflows/comfyui/run_fox_centaur_semantic.py --only elena --mode nude --attempt 1

# 已有 PNG 的跳过（不再看 passed 分）
python workflows/comfyui/run_fox_centaur_semantic.py --resume

# --score / --score-only 已废弃：只打印 SCORING_CANCELLED + VISUAL_JUDGE，不当门禁
```

每张产物：`<stem>.png`、`<stem>.run.json`（种子、轮数、残留比）、可选 `<stem>.json`（仅标记 `visual_judge` / `scoring_cancelled`，不再当门禁）、`debug/<stem>-garment-overlay.png`、`work/`（各带的 api json 和中间图）。

装栈：`bash workflows/comfyui/install_undress_stack.sh inventory|install`。幂等，已有的跳过，模型走 hf-mirror，装包前去代理、用清华源。2026-10-07 上机踩出来、脚本已处理的几处：SegFormer 节点在 import 时读 `models/segformer_b2_clothes/`（不是节点目录里的 checkpoints），并且它的 `__init__` 还会 import 用不上的 b3 fashion 变体、缺权重就整包 import 失败，脚本改成只导出 b2；GroundingDINO 需要 `models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py` 和 `bert-base-uncased`，北京 B 连不上 huggingface.co，两者都走 hf-mirror，ComfyUI 启动时带 `HF_ENDPOINT=https://hf-mirror.com`；机器上的 transformers 5.x 没有 `BertModel.get_extended_attention_mask`，GroundingDINO 建模直接报 AttributeError，所以固定 `transformers==4.46.3`、`tokenizers<0.21`、`huggingface_hub<1.0`。北京 B 直连 github.com 会卡死，`git clone` 只在子 shell 里 `source /etc/network_turbo`（AutoDL 学术加速），并带 300 秒超时，失败时清掉半截目录。清单：lquesada ComfyUI-Inpaint-CropAndStitch、Acly comfyui-inpaint-nodes、storyicon comfyui_segment_anything、StartHua Comfyui_segformer_b2_clothes、ComfyUI_InstantID；`lllyasviel/fooocus_inpaint` 两个文件，`mattmdjaga/segformer_b2_clothes`。

## 观感判定（打分已取消）

细则见文首 **2026-10-08 用户拍板** ①③。出图后 Cursor 直接看 PNG 判定是否可用（`VISUAL_JUDGE`）。`cursor_still_score.py` 与 `hillclimb_until_pass.py` 为兼容壳：前者写 `scoring_cancelled` 笔记，后者 `HILLCLIMB_CANCELLED` 退出。历史 `score-nude.txt` / `score-torn.txt` 仅作参考，不进流水线。成衣首图仍可由 Cursor GenerateImage 出（Comfy 只做去衣）。

工作流 JSON：`workflows/comfyui/scheme-semantic-*.api.json` 八个（SegFormer、两个 DINO、四个 inpaint、收边），由 `--emit-examples <目录>` 生成，测试里核对和脚本一致。MASK 输出口在机器上按 `/object_info` 取，JSON 里写的是 1。

## 开机凭据与自动开机

北京 B 791 `359a49a1c3-4cda10df` 是**普通容器实例**，不是 Pro。开发者 API 对它没用：`/api/v1/dev/instance/pro/power_on` 返回 RecordNotFoundError，`pro/list` 为空。所以两种凭据分工不同：

| 凭据 | 来源 | 只用来 |
| --- | --- | --- |
| 网页会话 JWT `AUTODL_WEB_AUTHORIZATION` | 环境变量，或 `/cursor/stores/user/autodl-web-auth.env`、`/workspace/cred-handoff/autodl-web-auth.env` | 普通实例开机：`POST https://www.autodl.com/api/v1/instance/power_on`，body `{"instance_uuid": ..., "payload": "gpu"}`。`payload` 固定 `gpu`，禁止无卡模式 |
| 开发者 Token `AUTODL_TOKEN` | 环境变量，或 `/cursor/stores/user/autodl-token.env` | 余额：`POST https://api.autodl.com/api/v1/dev/wallet/balance`。不用来开机 |

`workflows/comfyui/autodl_power.py`：

```bash
python workflows/comfyui/autodl_power.py balance          # 读余额（厘 / 元），低于 5 元只警报
python workflows/comfyui/autodl_power.py power-on         # 循环开机，空卡退避 20/30/45/60 s，默认最多 120 分钟
python workflows/comfyui/autodl_power.py power-on-once    # 单次；退出码 0 成功 5 无空卡 6 暂时失败 2 致命 4 没有网页凭据
python workflows/comfyui/autodl_power.py power-off        # 关机留盘（不 release）
python workflows/comfyui/autodl_power.py shutdown-fleet   # 791 + 克隆机都关机留盘
python workflows/comfyui/autodl_power.py release --uuid … # 对保有舰队一律 REFUSED
python workflows/comfyui/autodl_power.py fleet-cap        # 检查 ≤2 台
```

「空闲GPU不足」按空卡处理并退避重试；鉴权失败、实例不存在这类致命回复立即停止，不重试。F34 / G09 的 UUID 直接拒绝。密钥不打印、不入库。舰队规则见文首拍板 ④。

### 自助开机和整条链路

`workflows/comfyui/bringup_and_run.py` 一条命令走完整条链路，不用等人点网页：

```bash
python workflows/comfyui/bringup_and_run.py            # 开机（默认一直等到有卡，`--power-minutes 0`）→ SSH → 装栈 → 四张 → 关机 → 余额；Cursor 观感判定
python workflows/comfyui/bringup_and_run.py --no-power-on --keep-on   # 机器已开，不关机
```

1. 开机：`autodl_power.ensure_on`。凭据来源优先级：环境变量（Cursor Secrets 注入到这里）→ `/cursor/stores/user/` 下的 `autodl-web-auth.env`、`autodl-token.env`（也读 `/workspace/cred-handoff/autodl-web-auth.env`）→ 都没有就打印 `NEED_AUTODL_TOKEN` 并退出（码 4）。这些文件不进仓库。
   - 有网页 JWT：走普通实例的网页 `power_on`（`payload: gpu`），空卡按 20/30/45/60 s 退避重试。
   - 只有开发者 Token：先试 `dev/instance/pro/power_on`。这台是普通容器实例，会返回 `RecordNotFoundError`，脚本立刻停并说明要网页 JWT，不死循环。
   - 无论哪条路：不用无卡模式，F34 / G09 的 UUID 直接拒绝。克隆仅用于补齐「791 + 一台克隆」舰队（上限两台，见拍板 ④），禁止开第三台。
2. 等 SSH：每 20 秒一次，每次重读 `bjb-ssh.env`，host/port 变了自动跟。连续 3 次 `Permission denied (publickey)` 就停，报 `NEED_SSH_KEY_AUTH`：机器开着但密钥没授权，需要把 `bjb791.pub` 追加进 `/root/.ssh/authorized_keys`，或在 `bjb-ssh.env` 放 `BJB_SSH_PASSWORD`。此时机器在计费，脚本不会假装成功。
3. 装栈：把脚本、两张成衣底板、两张锁脸用 tar 传到 `/root/autodl-tmp/arc/ai-realistic-comic`，跑 `install_undress_stack.sh install`，重启 ComfyUI（按进程号），然后 `--check-stack`。缺节点就停。
4. 出图：先 nude（林、伊莲），再 torn（林、伊莲），结果在机器上的 `/root/autodl-tmp/fox-semantic-out`。无打分门禁。
5. 回传到 `/opt/cursor/artifacts/fox-centaur-semantic`，打印 `VISUAL_JUDGE`；Cursor 看图判定是否可用。过程文件之外的 png/json 拷进 `library/stills/fox-centaur-embrace/semantic/`。
6. 关机留盘：全流程干净跑完才执行——机内 `shutdown` + 网页 `power_off`（若 `bjb-clone.env` 有克隆 UUID 则两台都关）。**绝不 `release`。** 随后读余额。中途失败默认不关机（`MACHINE_STILL_ON`）；`--shutdown-on-failure` / `--keep-on` 语义不变。

踩过的坑（2026-10-07）：远端重启 ComfyUI 时 `pgrep -f 'main.py ...'` 会匹配到执行它自己的 SSH 命令行，把自己杀掉，随后旧版「失败也关机」的收尾把机器关了。现在 pattern 写成 `[m]ain.py`，并有测试守着。

2026-10-07 读到的余额是 ¥21.91（21910 厘），在任何开机之前。

## 提升（2026-10-07 规划落地 → 2026-10-08 再调）

参数与门禁以文首 **2026-10-08 用户拍板** ①②③ 为准。摘要：

1. 残留：LaMa + 0.35 touch only（禁止 0.62–0.88 Fooocus redo）。
2. 伊莲接缝冻结 48px；无躯干 pixelfill。
3. 林：髋 pixelfill ≤4000；`LEG_SOFT` 0.32；领口 leftover∩领带。
4. torn：弱 rim；洞心不重绘；接缝条带只 LaMa。
5. 打分 / hillclimb 取消；bringup 只打 `VISUAL_JUDGE`。


## P0/P1 回归诊断与修正（2026-10-08，离线，未开机）

对照 `dual/clone` 本轮产物 + debug 蒙版/残留，与 `run13`（旧 residual Fooocus 0.88）及 `PICKS.json` 旧 best。**不开机、不重跑。**

### 逐张崩因（一句话）

| 图 | 崩因 |
| --- | --- |
| 林 nude | 残留只靠 LaMa+0.35，清不掉大面积旗袍残留（ratio 0.51→0.60），髋 pixelfill 因 ≤4000 被跳过（实测 ~100k px），衣服留在身上 |
| 伊莲 nude | 大块 torso 残留反复 LaMa+弱贴肤糊死（leftover ~174k），且取消了旧版 `elena_torso_pixelfill`，接缝 48px 冻结后躯干无硬擦出口 |
| 林 torn | 建立在失败 nude 上，破口合成只能露出未去净旗袍+糊层 |
| 伊莲 torn | 建立在失败 nude 上，中心糊块随 nude 继承，rim 救不回 |

补充：初始 garment 蒙版覆盖尚可（share≈0.21，与旧轮同），**主因不是蒙版全漏**，而是 **残留清扫力度回退**。

### 与旧 best / run13 参数 diff（关键）

| 项 | 旧（run13 / 4b052e7 前） | P0/P1（4b052e7） | 本轮实测 |
| --- | --- | --- | --- |
| 残留主擦 | LaMa + Fooocus **0.88** | 仅 LaMa + touch **0.35** | 林 residual best 0.51（旧 0.34）；伊莲 0.53（旧 0.34） |
| 髋 pixelfill | 可跑大岛（run13 ~89k） | 上限 **4000** | `HIP_PIXELFILL_SKIP` 100028 |
| 伊莲躯干 pixelfill | 有（run13 ~64k） | **取消** | `ELENA_TORSO_PIXELFILL_SKIP` |
| 接缝冻结 | ~16px | **48px** | 残留/edge 更难碰接缝，但躯干糊更依赖 pixelfill |
| LEG_SOFT | 无 | LaMa+0.32 腿带 | 林跑了 ~126k px（可能加重腿糊） |
| 打分 | 有门禁 | VISUAL_JUDGE | 保留 |

### 修正方案（部分回退，先文档后代码）

1. **残留**：恢复「小岛 touch / 大岛 Fooocus」双路径——`ratio` 与像素超阈时用 `RESIDUAL_FOOOCUS_DENOISE=0.72`（略低于旧 0.88，减 smear），否则仍 LaMa+0.35。
2. **林髋**：`HIP_PIXELFILL_MAX_PX` 提到 **100000**（覆盖旧 best 量级），仍只填 leftover∩髋带。
3. **伊莲**：恢复 **接缝上方** torso pixelfill（`y < horse_guard_y - 16`），保留冻结带不进马身；冻结缓冲改回 **24px**（介于 16 与 48）。
4. **LEG_SOFT**：仅当腿带 leftover ≤ **40000** 才跑，避免整裙 LaMa。
5. **VISUAL_JUDGE / 不打分** 不变。跑图仍需另行授权开机。


## 审核补丁（同日代码审）

落地后又审了一遍，修了三处会直接影响出图的问题：

1. 领口分带：420px 分带几乎从不整段落在 y≤380，原来的 `y1 <= COLLAR_TO_Y` 条件形同虚设；改为首 pass 把蒙版在 380 切开，领口带单独跑 COLLAR 提示。
2. `MASK_SUSPECT` 从 0.35 提到 0.48——伊莲 force_boxes 单算约 11.5% 面积，叠上语义蒙版容易误触旧阈值。
3. LaMa 安装源：HF `fashn-ai/LaMa` 会被 spandrel 拒；安装脚本改走 Sanster GitHub release（`network_turbo`）。伊莲 force_boxes 下沿裁到 `horse_guard_y` 以上，避免和马身保护打架。

## 状态（2026-10-07）

上机结果（北京 B，RTX 5090，`--check-stack` 返回 `STACK_OK`，四张都出了图）。下面是迁 Cursor 打分前的历史 Codex 分数（过线 ≥9 且硬门空）。**四张都没过门。** 自本改起打分改 Cursor。

| 静帧 | 取用的轮次 | 均分（历史 Codex） | 硬门 |
| --- | --- | --- | --- |
| 林 nude | run9 | 7.75 | clothes_remain |
| 伊莲 nude | run6 | 8.0 | armor_remain |
| 林 torn | run9（run7、run10 同为 8.75） | 8.75 | 空 |
| 伊莲 torn | run7 | 8.5625 | 空 |

其余轮次：run7 林 nude 7.06（clothes_remain、extra_limb）、伊莲 nude 7.125；run9 伊莲 nude 7.25、伊莲 torn 7.0（intact_clothes）；run10（attempt 1）林 nude 7.625、伊莲 nude 6.625、林 torn 8.75、伊莲 torn 7.625。结果在 `library/stills/fox-centaur-embrace/semantic/`，各轮完整输出在 `/opt/cursor/artifacts/fox-centaur-semantic/run*`。

下面是我对各轮画面的目测记录：

| 轮次 | 目测 |
| --- | --- |
| 基线（第一次通栈） | nude 两张胸腹腿已无衣，但林留裙片，伊莲留手套/护腕/腰带；torn 两张几乎是完整衣服（整块重绘把衣服画回来了）→ 改成「nude 合成 + 洞沿重绘」 |
| run6（nude） | 伊莲胸肩裸，右臂残留护甲袖；林上身裸，领口、胯布、左侧裙片残留 |
| run7（both） | 林 torn：胸腹露出，领口和下摆保留，是目前最像「破衣」的；伊莲 nude 变差（棕色长袖） |
| run9（LaMa 残留 + 手臂分区） | 伊莲手臂分区把铠甲又画回来了（臂框盖到胸），已撤回；LaMa 预填对林有小改善，没有决定性变化 |

已知残留问题：林的领口、胯部布片、左侧裙片；伊莲的右臂/手套/腰带。残留检查本身能框出这些位置（`debug/*-residual-p*.png`），但重绘会把同类物体再画回来。下一步候选：残留区域专用 LaMa 擦除（已接，`big-lama.pt` 必须是 Sanster 的 `add_big_lama` 发布版，fashn-ai 那份 spandrel 不认）加更小的分区、换种子重试（`--attempt`）。

- 北京 B 机器已在机内 `shutdown`，数据盘保留；读到的余额 ¥16.02（关机时的读数）。再出图用 `bringup_and_run.py`（会自己开机）。
- 流程里踩过的坑都已写进脚本和上面的各节：SegFormer 目录和 `__init__`、GroundingDINO 的 cfg/bert/transformers 版本、SAM 选项名、object_info URL 转义、tar 解包权限。
