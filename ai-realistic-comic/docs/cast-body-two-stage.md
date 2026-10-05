# 演员资产模板流水线

这条流水线给以后的出片提供可复用身体模板。它不是叙事构图，也不是艺术创作。入口和出片静帧分开：

- 出片第一段同样只走 Codex CLI，见 `docs/explicit-still-two-stage.md` 和 `autodl/run_explicit_two_stage.py`。资产脚本不共用出片的 job 文件。
- 资产走 `autodl/run_cast_body_two_stage.py` 和 `autodl/cast_body_worker.py`。机器上的队列是 `/root/autodl-tmp/in/cast-asset-job.json`。穿衣底板不进这个队列。

四人仍是林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩。林晚棠和伊莲的脸已换成 2026-10-06 记事正面锁脸：`library/cast/lin_wantang/ref.png`、`library/cast/elena_voss/ref.png`。旧女脸在 `archive/ref-retired-2026-10-05.png`，停用。男演员 ref 不动。侧脸和三视图还没有。`library/cast/mood/` 的五合一合成图只是气质标签板，不能当这四张 `ref.png`，也不能喂去衣。一采只改衣着、发型和妆，脸锁在**新的**穿衣底板上。一采过除分辨率外的全部要求。二采只用同一颗种子做轻放大；掉分只调 denoise 和步数，不大改内容。不写故事场景，不换构图。出片不代跑。

## 十二张穿衣底板

十二个位置仍是四人各正、侧、背。2026-10-06 已用 Codex 过门的六张女人图替换女性位。顾承安、阿德里安六张不动：均分仍是顾承安正 9.25、侧 8.75、背 8.875，阿德里安正 9.25、侧 9.125、背 9.125。本仓库没有男演员穿衣 png，这次不新增、不覆盖。

女性位都在 `library/cast/<id>/body-clothed/<view>.png`，json 的 `lock` 是 `2026-10-06-front`，`entry` 是 `codex`，八项都 ≥ 9：林晚棠正 9.4125、侧 9.4、背 9.4，伊莲正 9.4625、侧 9.475、背 9.3875。去衣输入就是这张新底板。女性视图要这份 json 里 `passed` 且均分 ≥ 9 才去衣。顾承安侧面 8.75、背面 8.875 未到 9，先补再去衣。

穿衣重做只走 Codex CLI。命令是 `/home/ubuntu/.local/bin/codex exec --skip-git-repo-check --ephemeral --color never -C <目录> -s workspace-write -i <新 ref.png> -`，提示词从标准输入送入。参考图只有该演员的新锁脸。模型用这条 CLI 自己的默认模型，脚本不另换。没有 `codex` 可执行文件就 `SystemExit`，打印 `CODEX_CLI_MISSING`。不许改走别的出图，不许锁脸直出，不许把穿衣底板交给 F34。F34 工人收到 `kind=clothed` 同样退出。不过门就在 Codex CLI 里重出。林晚棠正面穿衣种子从 `1` 起，只用于记录这次尝试，和去衣黑名单 `33`–`61` 分开。去衣种子仍从 `62` 起，而且只在穿衣过门之后。

去衣只用 F34。穿衣过门之前禁止开机去衣。

打分 = Codex CLI + 固定标准前缀 `SCORE_PREFIX`（`autodl/cast_body_template.py`）。前缀含八项、硬门和 JSON schema，同一次运行里字节不变。`score_call` 只在末尾追加定妆路径、待打分图路径和一句任务。没有 `codex` 或未登录就 `SystemExit`，禁止改走 OpenCode vision。

## 修订必推

说明文档用来固化这条工作流，防止漂移。修订 = 改脚本 + 写或更新说明文档 + 推到 GitHub。规则、入口、打分、开关机、过门档案都算修订。同一批改动必须写进说明文档，并推到 GitHub。不得只留在本机。文档与代码不一致算漂移，须立刻对齐。

## F34 开关机

F34 干活才开机。当前批次做完或暂停，`f34_shutdown_hook` 立刻 `power_off` 关机留盘，不释放实例。禁止空转，禁止为等下一步挂着机。用户当次说别关用 `--keep-on`，说先别开用 `--hold-off`。穿衣和打分不开机。不开 G09，不新建实例。

## 十张去衣模板

| 演员 | 视图 |
| --- | --- |
| lin_wantang | 正、侧、背 |
| gu_chengan | 正 |
| elena_voss | 正、侧、背 |
| adrian_kane | 正、侧、背 |

本批从林晚棠正面起跑。均分不到 9 的位置不进这张表：顾承安侧面、顾承安背面。有穿衣底图就复用 `library/cast/<id>/body-clothed/<view>.png`。没有穿衣底图就停，不用定妆全身图代替，避免古装发型和妆留在去衣结果里。

## 资产参数

三向图只用 `autodl/cast_body_template.py` 里的 `ASSET_SCHEDULE`。这张表不读出片的 `EXPLICIT_CFG`，也不写出片的身体接触或情节强度。

| | 一采 | 二采 |
| --- | --- | --- |
| 尺寸 | 448×592 | 896×1200 |
| 步数 | 8 | 12。掉分再降到 8。显存不够先降到 8，再降到 6 |
| denoise | 无 | 0.20。掉分降到 0.15，再降到 0.12 |
| true_cfg_scale | 4 | 4 |
| LoRA scale | 0.85 | 0.85，同一颗种子 |
| 提示 | 构图一句，含 `full body, head and both feet in frame, no bust/head crop`。锁脸一句。去衣一句并写两遍。三句并列，互不替换 | 只放大。头和双脚仍留在画面内 |

## 两段，求快

去衣固定 LoRA scale `0.85`。不扫 scale。一采只改衣着、发型和妆。输入只喂已经过门的新 `body-clothed` 底板。构图、锁脸、去衣分成三句，互不替换。构图只写全身入画：中文「头和双脚都留在画面内，不要裁成头肩」，加上独立硬句 `full body, head and both feet in frame, no bust/head crop`。锁脸只写脸型、五官、身体和允许改的发型妆。去衣加强就是同一句写两遍。不要把去衣句再加长。不另加接触或情节。

林晚棠正面下一颗从 seed `62` 起。`scale 0.85 / seed 33` 作废。已失败黑名单是 seed `33`–`61`，这些籽不再重跑。诊断见下一节。identity、anatomy 或 wardrobe 低于 9 立刻换下一颗种子。任一内容项低于 9 都不过门。一采没有过门就自动下一颗，直到过门，或用户放下停止文件 `/tmp/cast-asset-stop`（本机）或 `/root/autodl-tmp/in/cast-asset-stop`（F34）。没有「三颗就停」。用户叫停时一采未过门，禁止二采。

## 越跑越坏

结论：不是 worker 越跑越坏，也不是 8 步突然不够。同一条提示下分数在抖动。看起来变差，是因为锁脸写硬之后，去衣在 8 步里输掉了。

对照：

- seed `34`：全身、双脚入画、衣着分 10、身份 6。8 步、当时的短提示就能脱衣，脸被改圆。
- seed `51`：全身、头脚都在，身份 9、衣着 2。构图句已经加上，衣服换成肤色背心和短裤，红唇还在。
- seed `53`：漂浮头，硬门 FEET，解剖 3，衣着 9。没有身体可穿，衣着分不能和全身图比。
- seed `55`–`61`：全身，身份多在 9，衣着停在 1–4。均分 7.6、7.13、7.75、7.0、7.4、7.63、6.75，没有一路向下。

根因按这个顺序：

1. 提示换挡，不是种子累进。早期「锁脸、锁身体。只改衣着」脱得掉衣服，身份在 6–7。拆成独立锁脸句之后，身份升到 9，衣着掉到 1–4。去衣句写两遍没有把衣服赢回来。
2. 构图失败是种子方差。letterbox 用整图缩小贴入，不中心裁切。同一条路径上 seed `34` 和 seed `55` 都是全身。diffusers 0.40 会把 `448×592` 收成 `448×576`，那是重采样，不是把头裁掉。`53`–`54` 的 FEET 是模型自己收成头。
3. 打分只在「半身」上不稳。全身仍穿衣时，衣着分稳定在 1–4。漂浮头也可以拿到衣着 9，因为没有躯干。

立刻做：LoRA 表是 `0.85`，但 `set_adapters(0.85)` 再 `fuse_lora(0.85)` 实际烘焙成 `0.7225`，而且每张都拆开重熔。改成权重只写一次，同一 scale 不再重熔。这不是新提示。这个双乘从第一张起就在，所以它解释不了衣着后来才崩；它只是让参数表和实际不一致。

先试验：不要同时加长去衣句、加英文衣服词、加 FEET 负向、加素颜。下一次只许改一个变量。步数和 true_cfg 先不动。

不要动：不要把去衣句再加长。不要提高 true_cfg。不要把一采步数从 8 改掉。不要改二采。不要扫 scale。不要为了 FEET 去改 letterbox。

一采和二采无论过不过门，日志都打出八项、`period_hair`、`period_makeup`、`eyes_black_brown`、硬门、look 和 `below`。每张尝试图旁边写同名 `.json`，里面有八项。mean 为 9 仍失败时，`below` 列出低于 9 的项。

1. 一采 `448×592`，8 步，`true_cfg_scale` 4。除分辨率外，全部要求都要过：identity、distinction、interaction（姿势）、aesthetics、anatomy、wardrobe、motif、photoreal 都 ≥ 9，硬门为空，发型妆眼睛自检通过。像素停在这一档，不因为图小单独判负，也不因为图小把内容分放行。identity 低于 9 表示脸被重画，不是因为按要求改了发型或妆。
2. 二采只在一采过门之后才允许。同一 seed、同一 scale、同一段「只放大」提示词，把过门的一采放大到 `896×1200`。从 denoise `0.20`、12 步起。全八项均分 ≥ 9，硬门为空，自检仍要通过。掉分只改 denoise 和步数，不改提示词，不改内容，不改 scale，不换种子。显存不够时，VAE 已经在 CPU，接着同样只降步数或去噪。未过门的一采不进这一段。

8bit bitsandbytes 主干留在 GPU。文本编码器和 VAE 留在 CPU。禁止把 BF16 整模读进主机内存。

## 发型妆眼睛

林晚棠、顾承安的去衣模板去掉古装发髻、头饰、额带、花钿、浓妆、红唇。头发是自然黑褐色（林晚棠松松束在脑后、额前干净，顾承安短发）。眼睛是正常黑褐色。林晚棠的嘴唇是自然色。打分不再用古装发型或旧金瞳认人。自检字段 `period_hair`、`period_makeup`、`eyes_black_brown` 缺了或不对，不得标过门。

伊莲保持棕波浪发松松束起、蓝灰眼、人耳，不要眼镜。不再用赤褐发和暖琥珀棕眼认人。阿德里安保持深色发、浅蓝灰眼、尖耳，不要武器。

## 机器

只用 F34 `xaxna66hqt-c5c9c7fc`（西北B）。禁止开 G09 `sa4eaxgcuq-26e36fc9`，禁止新建实例。F34 上若已有出片 worker，本脚本退出，不杀那个进程。干活才开机；批次做完或暂停立刻关机留盘。用户当次说别关或先别开才例外。

和出片共用同一套 F34 登录，不另要令牌。自测是 `python autodl/run_cast_body_two_stage.py --login-check`。口令读 `AUTODL_SSH_PASSWORD`，或本机 `/tmp/cast-ssh.env`，或两边都能挂到的 `/cursor/stores/user/cast-ssh.env`。出片机的 `/tmp/cast-ssh.env` 资产机读不到。环境变量里的旧口令会挡住文件，先取消再读。SSH 通了再核对 F34 上的 `/root/autodl-tmp/.cast-ssh.env`。口令不写入仓库。

出片代跑只这一次。共享登录到位后，资产用这个入口自己跑。`FILM_PROXY_REMAINING` 为 0。再设 `CAST_ASK_FILM_PROXY` 或再把队列交给出片，脚本退出并打印「资产自己跑。禁止再让出片代跑。」

关机保留数据盘。关机之后立刻读 AutoDL 钱包 `assets`（厘）并写进当轮报告。1000 厘 = ¥1。低于 ¥5 只警报，不充值。

```bash
# 只看机器和余额，不出图
AUTODL_TOKEN=... python autodl/run_cast_body_two_stage.py --doctor

# 林晚棠正面：一采过门后自动二采
AUTODL_TOKEN=... python autodl/run_cast_body_two_stage.py --only lin_wantang:front
```

在 `ai-realistic-comic/` 目录下运行。一采过门图写到 `/opt/cursor/artifacts/body-nude/<id>-<view>-pass1.png` 和同名 json。没过门的图留在 `/opt/cursor/artifacts/body-nude/_fail/`，旁边同名 json 含八项。二采过门才写入 `library/cast/<id>/body-nude/` 和 F34 `/root/autodl-tmp/assets/body-nude/<id>/`。二采没过门的图同样在 `_fail/` 留同名 json。
