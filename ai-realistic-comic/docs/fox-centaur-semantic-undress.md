# 狐 / 马去衣：语义蒙版管线

2026-10-07 起稿；**2026-10-08 用户拍板修订**见下节。适用 `library/stills/fox-centaur-embrace/` 的四张：林晚棠旗袍九尾 nude / torn，伊莲铠甲半人马 nude / torn。不是身体板，不进 `library/cast/*/body-nude/`。机器：**北京 B 母机 791** `359a49a1c3-4cda10df` + **最多一台**同标准 payg 克隆机（见 ④）。F34 / G09 不开，脚本遇到它们的主机名直接 `FORBIDDEN_HOST`。

## 2026-10-08 用户拍板（必须遵守）

① **取消打分门禁，改 Cursor 观感判定。** 用户明确取消狐/马去衣的均分 ≥9、硬门（`clothes_remain` / `armor_remain` 等）、以及 `SCORE_PENDING` 等待循环。出图后脚本只打印 `VISUAL_JUDGE <actor> <mode> <path>`；是否可用由 Cursor **看 PNG 观感**判定，不再写 `.score-request.json`、不再用 sidecar `passed` 挡 torn / bringup。

② **（已由 2026-10-09 前提复盘废止微调）原残留 / 接缝 / 髋 / 腿带参数改动。** 不再开机微调；改走整片衣物方案 A，见「前提复盘」。历史记录： 写入 `run_fox_centaur_semantic.py`：
- 残留：首 pass 仍 Fooocus denoise 1.0 + LaMa 预填；之后 LaMa 硬擦，**小岛** touch 0.35，**大岛** Fooocus `RESIDUAL_FOOOCUS_DENOISE=0.72`（2026-10-08 晚间部分回退：纯 0.35 去衣失败）。
- 伊莲接缝：`ELENA_JUNCTION_BUFFER=24`；残留 / 收边不进缓冲带及以下；接缝**上方**可 `elena_torso_pixelfill`（≤80k）。
- 林髋：`HIP_PIXELFILL_MAX_PX=100000`（覆盖旧 best 量级 leftover∩髋）。
- 林腿带：残留不进髋下（y≥720）；髋下 leftover 且 ≤`LEG_SOFT_MAX_PX=40000` 才 `LEG_SOFT`；领口 pixelfill 只填 leftover∩领口带（≤12000）。

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



## 社区复盘与修订推荐（2026-10-09，不开机、不出图；方案 A 暂不执行）

本轮系统重看 artifacts（`baseline` / `run2–run7` / `run9` / `run10` / `run12` / `run13` / `best` / `dual/clone`=P0P1 / `rollback-01a2f6f`）成图与 `debug/*-garment-overlay` / `*-residual-p*`，并检索 Civitai、Reddit、GitHub、HF、Comfy 文档、B 站等（**只记实际打开到的链接**）。

### 1) 失败类型归类（工具链上限 vs 参数）

| 类型 | 典型出现 | 判据 | 上限还是参数 |
| --- | --- | --- | --- |
| **衣物残留** | baseline–run10 林 nude；run9 伊莲 nude residual≈0.89；领口/臂甲/护腕 | 成图仍见旗袍花纹/甲片；debug 蒙版漏领口或甲件洞 | **两者都有**：蒙版漏是分割上限（SegFormer 对旗袍领/甲片不稳）；denoise 过低是参数（P0P1 0.35 留下整衣） |
| **大块糊死（泥巴/漆皮）** | run12 伊莲 nude；dual/clone；rollback 四张；baseline 林胸腹已偏糊 | 衣物区低频糊块、无皮肤高频；residual debug 大红块反复擦 | **工具链上限为主**：大洞 + LaMa 预填/残留把洞刷成泥；Fooocus 社区亦称一次洞不宜过大（见下） |
| **接缝/半人马结构** | run13 及以后伊莲；rollback 伊莲 leftover≈274k | 人马交界糊进马胸、冻结带下方无可画区或马色渗入人躯干 | **工具链上限**：OpenPose/人体先验不含半人马；马毛↔皮肤交界无可靠条件；冻结带只能「少画」不能「画对」 |
| **分带横缝 / 块状蒙版** | run6 residual debug 块状红罩；torn 髋横线 | debug 蒙版呈矩形块、漏岛；成图髋有硬横缝 | **工具链/实现上限**：SegFormer 低分辨率上采样 + CropAndStitch 分带接缝；不是单靠 denoise 能消 |
| **锁脸漂** | 本狐/马系列**少见主因** | 脸多在保护区外，成图脸尚可读 | **非主失败**；InstantID 未默认开也未大面积毁脸 |
| **姿势变** | 偶发腿肉糊/肢体增（run13 a48 `extra_limb`） | 高 denoise 裙带重画出多余肢 | **参数+缺姿态锁**：高 denoise 无 OpenPose 时会漂；非主型 |
| **九尾** | 多数 run 尾部完好 | 尾在保护区 | **已守住**（保护逻辑有效） |

**贯穿结论**：从 baseline 到 rollback，**主失败始终是「大面积衣物洞的皮肤重建」**（残留↔糊死摇摆）；LaMa/pixelfill/弱 touch 把糊死变成默认态。参数微调无法跨过「大洞无结构条件」上限。半人马接缝是第二硬上限。

**对上轮方案 A 的检验**：A 主张「整片衣物一次 denoise≈0.95–1.0 + InstantID + OpenPose」。社区与 Fooocus 作者讨论指出：**单次 inpaint 区域不宜大于约 1024×1024**（[Fooocus Discussion #414](https://github.com/lllyasviel/Fooocus/discussions/414)）；换装类 NSFW 常用 denoise **0.75–0.85**，>0.9 易漂比例（[lewdly.ai 工作流文](https://lewdly.ai/blog/comfyui-nsfw-inpainting-clothing-workflow)）。因此「整片高 denoise 一洞」**假设过强，暂不执行**；OpenPose/InstantID 锁姿锁脸仍有价值，但必须与 **CropAndStitch 限洞** 和 **中高 denoise** 同用，且**废除 LaMa 残留环**。

### 2) 社区主流做法（实测检索到的条目）

1. **DINO+SAM 自动衣物蒙版 → mask blur 8–15 → Flux Fill 或 SDXL inpaint，denoise 换装 0.75–0.85，Face Detailer 收脸**  
   来源：[lewdly.ai ComfyUI NSFW clothing inpaint](https://lewdly.ai/blog/comfyui-nsfw-inpainting-clothing-workflow)（[中文版](https://lewdly.ai/zh/blog/comfyui-nsfw-inpainting-clothing-workflow)）；显存文内约 **12–16GB**。5090(sm_120) 跑 SDXL/Flux 需匹配 cu128/cu130 的 PyTorch（[ComfyUI Discussion #6643](https://github.com/Comfy-Org/ComfyUI/discussions/6643)）；791 已是 `2.8.0+cu128` + 能力 `(12,0)`（见 `docs/comfyui-setup.md`），SDXL 路径已验证。

2. **SegFormer 衣物分割 + ControlNet 锁结构 + Fooocus inpaint + CropAndStitch**（与我们栈高度同构）  
   来源：Civitai workflow [`[FLUX|SDXL] Auto clothes inpainting`](https://civitai.com/models/967161/flux-or-sdxl-auto-clothes-inpainting)；资源 [segformer_b2_clothes](https://huggingface.co/mattmdjaga/segformer_b2_clothes)、[fooocus_inpaint](https://huggingface.co/lllyasviel/fooocus_inpaint)。SDXL 版强调 ControlNet；Flux Fill 版作者称可不靠 ControlNet。

3. **Fooocus inpaint 补丁用法 + LaMa 预填定位**  
   来源：[Acly/comfyui-inpaint-nodes](https://github.com/acly/comfyui-inpaint-nodes)（Fooocus patch、LaMa/MAT 预填、Differential Diffusion 蒙版强度）；B 站教程 [BV1xC411L7RJ Fooocus Inpaint](https://www.bilibili.com/video/BV1xC411L7RJ/)。作者讨论：**高质量时一次洞不要超过 ~1024**（[#414](https://github.com/lllyasviel/Fooocus/discussions/414)）。

4. **Qwen-Image-Edit + 去衣/撕衣 LoRA（指令编辑，保构图主张）**  
   来源：[starsfriday/Qwen-Image-Edit-Remove-Clothes](https://huggingface.co/starsfriday/Qwen-Image-Edit-Remove-Clothes)（触发句 `remove all the clothes of the figure in the picture`，`true_cfg_scale=4`，50 steps；检索时页面标 Access disabled，卡片正文仍可读）；[nappa114514/Qwen-Image-Edit-2511-torn-clothes](https://huggingface.co/nappa114514/Qwen-Image-Edit-2511-torn-clothes)（白区撕衣 + 可选参考图）；官方 [Qwen-Image-Edit-2511](https://huggingface.co/Qwen/Qwen-Image-Edit-2511) / [Comfy 教程](https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit-2511)。VRAM/盘：社区写 5090 上 Qwen-Image FP8 约需 **~30GB 盘**（[smeltcore 5090 笔记](https://smeltcore.com/recipes/qwen-image-on-rtx-5090-20b-text-to-image-via-comfyui-fp8-blackwell-native-path/)）。本仓库既有结论：Qwen 全身去衣与锁脸难同时过门（`docs/cast-identity-rebuild.md`）。

5. **Flux Fill / Kontext 换装与去衣**  
   来源：[9elements Flux Redux+Fill 换装](https://9elements.com/blog/ai-clothes-swaps-with-flux-redux-and-flux-fill/)（分割 + Fill + CropAndStitch）；Reddit [Flux Fill+LoRA 去衣可用、Kontext 常不行](https://www.reddit.com/r/StableDiffusion/comments/1qgsbz3/is_flux_klein_better_for_editing_than_flux_kontext/)；[Kontext NSFW 受限讨论](https://www.reddit.com/r/StableDiffusion/comments/1llpsk1/flux_kontext_dev_can_not_do_nfw/)；HF `tensorbanana/Clothes-on-off-Flux-fill-LoRa` 检索时 **Access disabled**。盘与权重远大于当前余额舒适区。

6. **BrushNet / PowerPaint（SD1.5 物体移除）**  
   来源：[nullquant/ComfyUI-BrushNet](https://github.com/nullquant/ComfyUI-BrushNet)（PowerPaint `object removal`，prompt `empty scene blur`）。**偏 SD1.5**，与 RealVisXL 主栈不合，仅作旁证。

7. **姿势锁**  
   来源：[aiarty SD 去衣/换装指南](https://www.aiarty.com/stable-diffusion-guide/how-to-use-stable-diffusion-to-remove-clothes.htm)（OpenPose ControlNet，weight≈1）。半人马无社区可靠先例。

**非常规体型**：公开检索**几乎没有**半人马/九尾专项去衣案例；九尾靠保护区可守，半人马接缝仍属未解。

### 3) 结合 791/592 已装栈的修订推荐（排序）

**盘上已有（`docs/comfyui-setup.md` + `install_undress_stack.sh`）**：RealVisXL V5.0 fp16、Fooocus inpaint v2.6、big-lama、SegFormer b2 clothes、GroundingDINO+SAM、InstantID + InstantID CN、**OpenPose SDXL (xinsir)**、Inpaint-CropAndStitch、ComfyUI `2.8.0+cu128` on RTX 5090。数据盘扩容 **100GiB**。Qwen **不在** 791 默认栈（历史在 F34；`docs/autodl.md` 记 HF 缓存 ≥50GB）。

#### R1（首选，低成本）— 社区对齐的 SDXL 衣物 inpaint（**修订版，非原方案 A**）

- **做法**：保留 SegFormer/DINO 蒙版与 CropAndStitch（单带 ≤1024）；**删除** LaMa 残留环 / pixelfill / 0.35 touch；主擦 **Fooocus denoise 0.78–0.85** + **OpenPose**（已有权重）锁人体上半；可选 InstantID/FaceDetailer 只修脸；伊莲马身保护区照旧；torn 继续 run7/9 贴洞+rim 0.55。
- **新装**：尽量 **0～0.2GB**（若缺 FaceDetailer/`face_yolov8m.pt` 再下）；OpenPose 已在 `models/controlnet/openpose-sdxl-xinsir/`。
- **显存**：约 12–20GB；5090 已跑通 SDXL。
- **开机花费（≈¥2.88/时，余额 ¥26.72）**：试点林 nude **≈10–15 min → ¥0.5–0.8**；四张 **≈¥1.5–2.5**。建议硬顶 **≤¥4**。
- **预期改善**：衣物残留（中高 denoise）、大块糊死（去掉 LaMa 环）、姿势小漂（OpenPose）。**不承诺**半人马接缝完美。

#### R2（备选，贵）— Qwen-Image-Edit-2511 + torn/remove LoRA

- **做法**：指令/蒙版编辑去衣或撕衣（HF nappa torn-clothes；starsfriday remove 下前复核 Access）；再可选 SDXL FaceDetailer。
- **新装**：Qwen Edit FP8/GGUF + LoRA，盘 **约 20–50GB+**；可能要升 Comfy/依赖。
- **开机**：首次下载 **0.5–2 h**（¥1.5–6）+ 出图；总成本易 **¥4–8+**，对 ¥26.72 不友好。
- **预期**：普通人像去衣残影可能好于 SDXL；**身份/半人马**按本仓库既往 Qwen 经验仍高风险。

**不推荐此刻**：Flux Fill/Kontext 全家桶；PowerPaint 主路径（SD1.5）；再调 `RESIDUAL_*`；原方案 A 整片 denoise≈1.0。

### 4) 实施状态

- 方案 A：**暂不执行**。`run_fox_centaur_wholebody.py` 仅草稿。
- R1 **已实现**：`workflows/comfyui/run_fox_centaur_community_r1.py`（默认 denoise 0.82 + CropAndStitch + OpenPose；无 LaMa 残留/pixelfill）。需 `--i-know-authorized`。
- **R1 伊莲 nude 试点（592，commit `4a752aa`）不可用** → 见下节离线诊断；代码已定点修正为 **R1-fix**（仍现有栈，未装大模型）。**未再开机出图。**
- 下次开机须用户点名授权「R1-fix 伊莲 nude 复测」或「R2」。AI 漫画工作流内 **grok 一律走 Cursor 本机**，禁止 grok.com / 其他渠道 CLI。


## R1 伊莲 nude 试点离线诊断（2026-10-09，不开机、不出图）

产物：`/opt/cursor/artifacts/fox-centaur-semantic/r1/`（`elena-armor-centaur-nude.png`、`debug/*-garment-mask.png`、`*-garment-overlay.png`、`elena-armor-centaur-nude.run.json`、`VISUAL_JUDGE.json`）。对照历史较好 **run6** 同名图。

### 1) 蒙版是否罩住铠甲？为何 denoise 0.82 仍留甲壳？

| 检查 | 结果 |
| --- | --- |
| garment_share | R1 **0.208**（run.json）；run6 **0.150** — R1 蒙版并不更小 |
| 躯干框内蒙版覆盖 | ≈**0.50–0.56**（中段胸腹 ROI） |
| 成衣板躯干「金属像」像素被 mask 罩住 | ≈**0.71**（miss ≈0.29：臂/缝隙边缘有漏，但**不是**整片漏蒙） |
| 成图 VISUAL_JUDGE | **不可用**：躯干仍是整片高光金属甲/贴身甲壳 |

**结论**：蒙版大体罩住胸甲主面；崩因主要在 **重绘参数**，不是「蒙版完全没罩」。

**为何 0.82×1 留甲壳（现有栈内因）**：

1. **Denoise 过低**：Fooocus 换装常用 0.75–0.85 适合「换布料」；伊莲高光金属甲是强结构性纹理，**&lt;1.0 单次**会把镜面高光当可保留细节留在 latent 里。run6 能出相对真裸靠的是 **1.0×3**。
2. **OpenPose 过强（0.75）**：姿态锁把「胸廓壳体」轮廓钉死，中等 denoise 更容易把甲壳当身体表面重画成真空贴身金属皮，而不是换成皮肤。
3. **只 1 pass + edge 0.32**：无 run6 式多轮同洞硬擦；收边 denoise 也低于 run6 的 0.42。
4. **提示词/负向**：试点未加金属镜面专项负向；正向仍走通用 nude（正确：否定句不进正向）。
5. **参考图 = 成衣板**：inpaint 以甲壳板为 image；denoise&lt;1 时板面高光是直接泄漏源。
6. **ControlNet / CropAndStitch / 模型**：OpenPose SDXL + CropAndStitch≤1024 + RealVisXL+Fooocus v2.6 — 与计划一致；**不是**模型装错或裁块把甲裁掉。裁块在蒙版内正常工作，只是洞内擦不穿。

同洞近似对比（用 R1 mask 套在两张成图上）：R1 mask 内 residual_metalish≈**0.28** / skinish≈**0.37**；run6 ≈**0.16** / **0.59**。说明即使罩住的区域，0.82 也清不掉甲光。

### 2) 与 run6（相对较好伊莲 nude）参数/蒙版差异

| 项 | R1 试点（失败） | run6（较好） | R1-fix（已改代码，未跑） |
| --- | --- | --- | --- |
| 管线 | community_r1，无 LaMa | 旧 semantic，无 LaMa 残留环 | 同 R1 栈，仍无 LaMa |
| nude denoise × passes | **0.82 × 1** | **1.0 × 3** | **1.0 × 3** |
| edge denoise | 0.32 | **0.42** | **0.42** |
| OpenPose | on，strength **0.75** | 无（当时未锁姿） | on，仅首 pass，**0.40** |
| garment_share | 0.208 | 0.150 | 同 R1 蒙版逻辑 |
| 金属负向 | 无 | 无专项 | `ELENA_METAL_NEG_EXTRA`（chrome/specular/plate…） |
| seed | 20261209 | 20261208 | 沿用 runner 默认 |

### 3) 下一步：R1-fix（推荐）vs R2

**推荐 R1-fix**（定点修正、现有栈、不装大模型）。不推荐此刻切 R2（Qwen Edit 下载贵、身份/半人马风险高）。

| | R1-fix | R2 |
| --- | --- | --- |
| 改动点 | `run_fox_centaur_community_r1.py`：伊莲 `denoise=1.0`、`nude_passes=3`、`edge=0.42`、`openpose_strength=0.40`（仅首 pass）、金属负向；林仍 0.82×1 | 新装 Qwen-Image-Edit + LoRA，新工作流 |
| 新装 | **0** | 20–50GB+ |
| 是否开机 | **要**（用户点名授权后）单张伊莲 nude 复测 | 要，且首次下载更久 |
| 预计花费 | 复测 ≈**¥0.5–0.8**；过关再三张 → 合计硬顶 **≤¥4**（互斥单机、关机留盘） | 易 **¥4–8+** |

授权口令建议：「R1-fix 伊莲 nude 复测」。失败再评估 R2。


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

### 修正方案（部分回退 — 已落地代码，跑图待授权）

1. **残留**：恢复「小岛 touch / 大岛 Fooocus」双路径——`ratio` 与像素超阈时用 `RESIDUAL_FOOOCUS_DENOISE=0.72`（略低于旧 0.88，减 smear），否则仍 LaMa+0.35。
2. **林髋**：`HIP_PIXELFILL_MAX_PX` 提到 **100000**（覆盖旧 best 量级），仍只填 leftover∩髋带。
3. **伊莲**：恢复 **接缝上方** torso pixelfill（`y < horse_guard_y - 16`），保留冻结带不进马身；冻结缓冲改回 **24px**（介于 16 与 48）。
4. **LEG_SOFT**：仅当腿带 leftover ≤ **40000** 才跑，避免整裙 LaMa。
5. **VISUAL_JUDGE / 不打分** 不变。跑图仍需另行授权开机。



## 前提复盘：局部擦衣路线停用（2026-10-09，不开机）

两轮调参（P0/P1 `4b052e7`、部分回退 `01a2f6f`）与此前 hillclimb 同属一类失败：**大面积衣物区局部 inpaint / LaMa / pixelfill 后糊死**。停止微调 denoise / 冻结带 / pixelfill 上限。

### 1) 历史 run 中最接近可用的版本

对照本机 artifacts `fox-centaur-semantic/{baseline,run2–run7,run9,run10,run12,run13,best,dual/clone,rollback-01a2f6f}` 与 `best/PICKS.json`（Codex/Cursor 历史挑选，不以本轮糊图覆盖为准）：

| 图 | 最接近可用 | 关键参数 / 管线特征 | 备注 |
| --- | --- | --- | --- |
| 林 torn | **run9** `lin-qipao-nine-tail-torn` | nude 底板 + 锯齿洞 composite（tear 0.5）+ rim **denoise 0.55** | Codex 均分 **8.75**，硬门空 — **全库最接近可用** |
| 伊莲 torn | **run7** `elena-armor-centaur-torn` | 同上，tear 0.55 + rim 0.55 | Codex **8.56**，硬门空 |
| 伊莲 nude | **run6** `elena-armor-centaur-nude` | 连续 **nude denoise 1.0**×3 + edge **0.42**；**无** LaMa 残留 / pixelfill | 躯干相对真裸、接缝可读；仍 `armor_remain`（臂甲）≈8.0 |
| 林 nude | **run13 a35-collarfix** | LaMa + Fooocus residual **0.88** + collar pixelfill；edge 0.32 | 领口硬门清；腿仍肉糊 ≈7.1 |

早期 **baseline–run5**：手画/粗语义 + denoise 1.0 分带，残留高、衣服常留。  
**run10–run12**：开始加 LaMa residual / touch，观感抖动。  
**run13 / dual(P0P1) / rollback(01a2f6f)**：残留 LaMa↔Fooocus↔pixelfill 越调，**糊死越稳**（伊莲 rollback residual≈0.84；双机 P0P1 四张全不可用）。

**结论性挑选**：全库观感天花板在 **run7/run9 torn**（破口合成路线）与 **run6 伊莲 nude**（朴素多轮高 denoise、无 LaMa 补洞）；之后所有「残留擦补」迭代未超过这条线。

### 2) 前提判断（一句）

**在成衣大面积旗袍/铠甲上做分带局部擦衣补皮，对这套底板根本不可行**——洞太大时边界织物纹理泄漏、LaMa/弱贴肤只能糊泥，而抬 denoise / 多轮残留只是在「留衣」与「糊死/肉缝」之间摇摆，无法稳定出可用皮肤。

### 3) 替代方案（≤2；**2026-10-09 复盘后方案 A 暂不执行，见下节「社区复盘」**）

共用约束：互斥单机、关机留盘、不开第三台、余额 ≈¥26.72 → **先单张试点再四张**；5090 payg ≈ **¥2.88/时**（2880 厘）。

#### 方案 A（推荐）— 整片衣物蒙版一次高 denoise inpaint + 锁脸 InstantID + 姿势 OpenPose

- **做法**：语义衣物蒙版（已有 SegFormer/DINO）合成**单块**身体衣物洞（林：躯干+裙；伊莲：人躯干甲，马身保护区外）；**一次** Fooocus denoise ≈0.9–1.0 + neutral/MaskedFill；**不开**分带残留 LaMa / pixelfill 循环。脸：已装 **InstantID**（`scheme_still_fox_centaur_undress.instantid_inpaint_graph` / `scheme_b_from_plate.py`）。姿势：成衣板提 OpenPose/DWPose，SDXL OpenPose ControlNet（`openpose-sdxl-xinsir`，scheme_b 已引用）。九尾/马身进保护区不重绘。torn 仍用「可用 nude + 锯齿贴洞 + rim」（run7/9 路径）。
- **显存**：InstantID + OpenPose CN + SDXL inpaint ≈ **16–22 GiB**（5090 32G 富余）。
- **耗时**：装/核权重 5–15 min（多数已在盘）；每张 nude ≈3–6 min；四张 + torn ≈ **25–40 min** 墙上时间。
- **新模型**：优先复用盘上 InstantID + openpose-sdxl；若缺 openpose 权重再下 ≈1–2.5 GiB（hf-mirror）。**不新开节点全家桶**。
- **开机花费（估）**：试点 1 张林 nude ≈开机+跑 **8–12 min → ¥0.4–0.6**；通过后再四张全套 ≈ **¥1.5–2.5**；单日硬顶建议 **≤¥5**。

#### 方案 B — 成衣板作脸/姿势参考，裸体整图重生成再合成背景

- **做法**：OpenPose + InstantID/IP-Adapter FaceID 从成衣板取条件，txt2img/img2img 整图重画裸体，再把背景/九尾/马身从原板蒙版贴回（或 high denoise 全图）。
- **显存**：同类或略高（+IP-Adapter FaceID ≈再 +2–4 GiB）。
- **耗时**：每张 4–8 min；半人马/九尾结构易漂，重试次数↑ → **40–70 min** 四张。
- **新模型**：可能要 IP-Adapter FaceID Plus（scheme_b 已列）；半人马无可靠姿态先验，**伊莲风险高于 A**。
- **花费**：估 **¥2.5–4**（含重试），更费余额。

**原推荐 A 已搁置（2026-10-09）**：社区指出 Fooocus 大洞易糊、denoise>0.9 易漂体；整片高 denoise 假设需修正。见「社区复盘与修订推荐」。

### 4) 实施状态

- 文档本节已落盘；入口骨架见 `workflows/comfyui/run_fox_centaur_wholebody.py`（**未上机、默认拒绝无授权开机**）。
- **禁止**再改 `RESIDUAL_*` / `HIP_PIXELFILL_*` / `ELENA_JUNCTION_*` 微调后开机。
- **方案 A 暂不执行**；下次开机须用户明确授权「跑修订推荐 R1/R2」。


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
