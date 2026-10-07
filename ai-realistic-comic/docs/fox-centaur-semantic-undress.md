# 狐 / 马去衣：语义蒙版管线

2026-10-07。适用 `library/stills/fox-centaur-embrace/` 的四张：林晚棠旗袍九尾 nude / torn，伊莲铠甲半人马 nude / torn。不是身体板，不进 `library/cast/*/body-nude/`。机器只用北京 B `359a49a1c3-4cda10df`。F34 / G09 不开，脚本遇到它们的主机名直接 `FORBIDDEN_HOST`。

## 为什么改

2026-10-07 早先的 Fooocus 重跑用的是手画矩形和椭圆蒙版：林 nude 6.125（`clothes_remain`）、伊莲 nude 7.375（`armor_remain`）、伊莲 torn 7.75（`intact_clothes`）、林 torn 8.75（近门）。蒙版框不住旗袍裙摆和甲片轮廓，衣服留在蒙版外，单靠抬 denoise 解决不了。这一版先找衣服在哪，再重绘；重绘后再找一遍，只补残留。

## 管线

1. 语义蒙版（`semantic_undress.py`）
   - SegFormer B2 clothes（StartHua）：Upper-clothes、Skirt、Pants、Dress、Belt、Scarf 的并集。
   - GroundingDINO + SAM（storyicon）补件。林：qipao、cheongsam dress、silk fabric skirt、mandarin collar、shoulder strap、dress hem。伊莲：breastplate、pauldron、vambrace、gauntlet、fauld、gorget、golden armor。
   - 保护区先减掉：脸框、face、hair、glasses、fox tail、高跟鞋；伊莲再加 horse body / horse tail，但只在 y>720（1024×1536 板坐标）以下生效，而且 DINO 明确点名的甲件优先于马身保护，免得腰甲被当成马。
   - 裁到演员 ROI，丢掉过小的碎块，再外扩 10 px，外扩之后再减一次保护区。分带重绘时不再二次外扩，所以蒙版不会越过脸和狐尾的保护边。
   - 伊莲的 SegFormer 只在 DINO 甲件命中 40 px 之内才算数，防止把马背毛色当成衣服。ROI 是 (60,230,560,900)，马身保护线 y=690，对照两张成衣底板核过坐标。
2. torn：在 nude 蒙版里用固定种子的锯齿多边形挖洞（林 62%，伊莲 68%），林保留领口 7% 和下摆 18%，伊莲保留下摆 10%，所以残骸留在身上，不会全裸。
3. 预填：Acly `INPAINT_MaskedFill`，`fill=neutral`。不用 Telea / NS 当去衣预填。等价 Fooocus 的 Disable initial latent + Modify Content。
4. Crop and Stitch：SDXL 固定 1024。蒙版按 420 px 高度分带，每带单独裁剪重绘再贴回，不用一个大洞。内容占比封顶 `MAX_CONTENT_FRAC=0.52`，伊莲只裁人躯干、手臂、腰接缝，不进马身。
5. 重绘：RealVisXL V5.0 fp16（非蒸馏写实 SDXL）+ Fooocus inpaint v2.6 patch（`fooocus_inpaint_head.pth`、`inpaint_v26.fooocus.patch`）。nude denoise 1.0，torn 0.96。衣服 pass 不开 DifferentialDiffusion。
6. 残留检查（nude）：对结果再跑一遍 1 的蒙版，残留面积占原衣服面积的比例 <5% 才算净；否则只对残留区域再重绘，最多 3 轮。这是代替抬 denoise 的手段。
7. 收边：蒙版边界 14 px 环带，denoise 0.42，开 DifferentialDiffusion，关预填。
8. InstantID：默认不开。脸在保护区里没被重绘，锁脸是多余的；去衣后 identity 若掉到 9 以下再手动加。头肩图和 `ApplyInstantID` 图在 `scheme_still_fox_centaur_undress.py` 的 `instantid_inpaint_graph`。

顺序：先两张 nude，再两张 torn。不开 ReActor。

## 容错

- DINO 一批提示词里有一条没检出导致整图报错时，改成逐条提示词重跑，没检出的按空蒙版处理，日志 `DINO_EMPTY`。
- SegFormer 节点的蒙版输出口按 `/object_info` 找：先 MASK，再 IMAGE。不再写死槽位。
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

装栈：`bash workflows/comfyui/install_undress_stack.sh inventory|install`。幂等，已有的跳过，模型走 hf-mirror，装包前去代理、用清华源。清单：lquesada ComfyUI-Inpaint-CropAndStitch、Acly comfyui-inpaint-nodes、storyicon comfyui_segment_anything、StartHua Comfyui_segformer_b2_clothes、ComfyUI_InstantID；`lllyasviel/fooocus_inpaint` 两个文件，`mattmdjaga/segformer_b2_clothes`。

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
6. 关机：到过机器之后无论前面哪一步失败都会执行，机器内部 `shutdown`，数据盘保留；随后读余额（无 Token 打印 `BALANCE_PENDING`）。`--keep-on` 才跳过关机。

2026-10-07 读到的余额是 ¥21.91（21910 厘），在任何开机之前。

## 状态（2026-10-07）

- 离线完成：蒙版逻辑、torn 挖洞、残留检查、Codex-only 打分、安装脚本、八个 API 图、说明文档。25 个测试通过（`tests/test_semantic_undress.py`、`tests/test_fox_centaur_undress.py`），其中两个是用假 ComfyUI 后端在真实成衣底板上跑完整个 `undress_one`：脸区像素不变，衣服区被换成肤色，残留循环、收边、sidecar 落盘都走到；torn 保留残骸。假后端不画图，所以这只证明流程和拼接对，不证明画面质量。
- **没在机器上跑过。** 节点类名（`segformer_b2_clothes` 的输出口、DINO+SAM 的节点名）和权重路径按公开仓库写，装完后以 `--check-stack` 和 `/object_info` 为准，不符就改常量。
- 阻塞：北京 B `359a49a1c3-4cda10df` 已关机，开机弹窗「该主机空闲GPU不足…主机GPU空闲数量：0 卡」。需要用户给「克隆到有空卡主机」或其它开机授权。F34 不动。
- 开机后顺序：`install_undress_stack.sh inventory` → `install` → `--check-stack` → 先两张 nude，再两张 torn → Codex 打分（VM 无 codex 则 `SCORE_FAILED codex ... reason=cli_missing`）→ 机内关机留盘 → 回传四张和 json。
- AutoDL 余额：无开发者 Token，待读。
