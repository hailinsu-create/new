# 狐 / 马去衣：语义蒙版管线

2026-10-07。适用 `library/stills/fox-centaur-embrace/` 的四张：林晚棠旗袍九尾 nude / torn，伊莲铠甲半人马 nude / torn。不是身体板，不进 `library/cast/*/body-nude/`。机器只用北京 B `359a49a1c3-4cda10df`。F34 / G09 不开，脚本遇到它们的主机名直接 `FORBIDDEN_HOST`。

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

# 已过门的跳过
python workflows/comfyui/run_fox_centaur_semantic.py --resume

# 只打分（机器上没有 codex 时在别处补）
python workflows/comfyui/run_fox_centaur_semantic.py --score-only --out <含 png 的目录>
```

每张产物：`<stem>.png`、`<stem>.json`（打分 sidecar）、`<stem>.run.json`（种子、轮数、残留比）、`debug/<stem>-garment-overlay.png`、`work/`（各带的 api json 和中间图）。

装栈：`bash workflows/comfyui/install_undress_stack.sh inventory|install`。幂等，已有的跳过，模型走 hf-mirror，装包前去代理、用清华源。2026-10-07 上机踩出来、脚本已处理的几处：SegFormer 节点在 import 时读 `models/segformer_b2_clothes/`（不是节点目录里的 checkpoints），并且它的 `__init__` 还会 import 用不上的 b3 fashion 变体、缺权重就整包 import 失败，脚本改成只导出 b2；GroundingDINO 需要 `models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py` 和 `bert-base-uncased`，北京 B 连不上 huggingface.co，两者都走 hf-mirror，ComfyUI 启动时带 `HF_ENDPOINT=https://hf-mirror.com`；机器上的 transformers 5.x 没有 `BertModel.get_extended_attention_mask`，GroundingDINO 建模直接报 AttributeError，所以固定 `transformers==4.46.3`、`tokenizers<0.21`、`huggingface_hub<1.0`。北京 B 直连 github.com 会卡死，`git clone` 只在子 shell 里 `source /etc/network_turbo`（AutoDL 学术加速），并带 300 秒超时，失败时清掉半截目录。清单：lquesada ComfyUI-Inpaint-CropAndStitch、Acly comfyui-inpaint-nodes、storyicon comfyui_segment_anything、StartHua Comfyui_segformer_b2_clothes、ComfyUI_InstantID；`lllyasviel/fooocus_inpaint` 两个文件，`mattmdjaga/segformer_b2_clothes`。

## 打分

只走 Codex CLI，沿用 `score-nude.txt` / `score-torn.txt`，第一张是各自的 `ref-face.png`，第二张是结果。八项加硬门，收留线均分 ≥ 9 且硬门空。Codex 不可用（没有二进制、未登录、额度用完、超时、JSON 解析失败）就打印 `SCORE_FAILED codex <actor> <mode> reason=<原因>`，写 sidecar 和 `.score-fail.json`，**不回退 Grok，不换别的视觉模型，也不本地估分**。出图不因此中断。

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
```

「空闲GPU不足」按空卡处理并退避重试；鉴权失败、实例不存在这类致命回复立即停止，不重试。F34 / G09 的 UUID 直接拒绝。密钥不打印、不入库。

### 自助开机和整条链路

`workflows/comfyui/bringup_and_run.py` 一条命令走完整条链路，不用等人点网页：

```bash
python workflows/comfyui/bringup_and_run.py            # 开机 → SSH → 装栈 → check-stack → 四张 → 打分 → 关机 → 余额
python workflows/comfyui/bringup_and_run.py --no-power-on --keep-on   # 机器已开，不关机
```

1. 开机：`autodl_power.ensure_on`。凭据来源优先级：环境变量（Cursor Secrets 注入到这里）→ `/cursor/stores/user/` 下的 `autodl-web-auth.env`、`autodl-token.env`（也读 `/workspace/cred-handoff/autodl-web-auth.env`）→ 都没有就打印 `NEED_AUTODL_TOKEN` 并退出（码 4）。这些文件不进仓库。
   - 有网页 JWT：走普通实例的网页 `power_on`（`payload: gpu`），空卡按 20/30/45/60 s 退避重试。
   - 只有开发者 Token：先试 `dev/instance/pro/power_on`。这台是普通容器实例，会返回 `RecordNotFoundError`，脚本立刻停并说明要网页 JWT，不死循环。
   - 无论哪条路：不克隆，不用无卡模式，F34 / G09 的 UUID 直接拒绝。
2. 等 SSH：每 20 秒一次，每次重读 `bjb-ssh.env`，host/port 变了自动跟。连续 3 次 `Permission denied (publickey)` 就停，报 `NEED_SSH_KEY_AUTH`：机器开着但密钥没授权，需要把 `bjb791.pub` 追加进 `/root/.ssh/authorized_keys`，或在 `bjb-ssh.env` 放 `BJB_SSH_PASSWORD`。此时机器在计费，脚本不会假装成功。
3. 装栈：把脚本、两张成衣底板、打分提示、两张锁脸用 tar 传到 `/root/autodl-tmp/arc/ai-realistic-comic`，跑 `install_undress_stack.sh install`，重启 ComfyUI（按进程号），然后 `--check-stack`。缺节点就停。
4. 出图：先 nude（林、伊莲），再 torn（林、伊莲），`--no-score`，结果在机器上的 `/root/autodl-tmp/fox-semantic-out`。
5. 回传到 `/opt/cursor/artifacts/fox-centaur-semantic`，本机 Codex 打分，过程文件之外的 png/json 拷进 `library/stills/fox-centaur-embrace/semantic/`。Codex 不可用：`SCORE_FAILED codex ... reason=cli_missing`，不回退。
6. 关机：全流程干净跑完才执行，机器内部 `shutdown`，数据盘保留；随后读余额（无 Token 打印 `BALANCE_PENDING`）。中途有步骤失败时默认**不关机**并打印 `MACHINE_STILL_ON`，因为拿到空卡不容易，修好后用 `--no-power-on` 接着跑；要失败也关机加 `--shutdown-on-failure`，要干净跑完也不关加 `--keep-on`。

踩过的坑（2026-10-07）：远端重启 ComfyUI 时 `pgrep -f 'main.py ...'` 会匹配到执行它自己的 SSH 命令行，把自己杀掉，随后旧版「失败也关机」的收尾把机器关了。现在 pattern 写成 `[m]ain.py`，并有测试守着。

2026-10-07 读到的余额是 ¥21.91（21910 厘），在任何开机之前。

## 提升（2026-10-07 规划落地）

P0/P1 已写入脚本：

1. **残留岛**：首 pass 仍 Fooocus denoise 1.0（LaMa 预填）；之后每轮先  硬擦，再 denoise 0.35 贴肤。不再对残留跑 denoise 1.0。
2. **伊莲甲件**：（颈/左右臂/腰）+  对甲件 DINO 命中外扩 32 px，避免半截护腕留在洞外。
3. **林领口/左侧裙片**： + 领口分带提示（y≤380 用 COLLAR_*）；胯下仍用 LOWER_*。
4. **torn**：rim denoise 0.40；洞心不重绘；伊莲  以下不做 rim，接缝条带只 LaMa。
5. **门禁**： 先 nude→Codex；有 / 的演员跳过 torn。

## 状态（2026-10-07）

上机结果（北京 B，RTX 5090，`--check-stack` 返回 `STACK_OK`，四张都出了图）。Codex CLI 已装到 VM 的 `~/.local/bin/codex` 并登录，下面是 Codex 真实打分（过线 ≥9 且硬门空）。**四张都没过门。**

| 静帧 | 取用的轮次 | Codex 均分 | 硬门 |
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
