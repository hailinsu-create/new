# 演员资产模板流水线

这条流水线给以后的出片提供可复用身体模板。它不是叙事构图，也不是艺术创作。入口和出片静帧分开：

- 出片继续走 `docs/explicit-still-two-stage.md` 和 `autodl/run_explicit_two_stage.py`。这里不改那两个文件，也不共用它们的 job 文件。
- 资产走 `autodl/run_cast_body_two_stage.py` 和 `autodl/cast_body_worker.py`。机器上的队列是 `/root/autodl-tmp/in/cast-asset-job.json`。

四人仍是林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩。一采只改衣着、发型和妆，脸锁在喂进去的穿衣底板上。一采过除分辨率外的全部要求。二采只用同一颗种子做轻放大；掉分只调 denoise 和步数，不大改内容。不写故事场景，不换构图。

## 十二张穿衣底板

四人各正、侧、背，共 12 张，都是底板。去衣只在这一张穿衣均分已经 ≥ 9 之后。定妆 ref 重打后，未到 9 的是顾承安侧面 8.75、顾承安背面 8.875、伊莲侧面 8.875。这三张先补到 ≥ 9，再去衣。其余九张穿衣已过门，可以进两段去衣。林晚棠正面去衣仍优先。

## 九张去衣模板

| 演员 | 视图 |
| --- | --- |
| lin_wantang | 正、侧、背 |
| gu_chengan | 正 |
| elena_voss | 正、背 |
| adrian_kane | 正、侧、背 |

穿衣侧背如果还没有均分 ≥ 9 的记录，记为未过门，不在这条去衣流水线里重画。有穿衣底图就复用 `library/cast/<id>/body-clothed/<view>.png`，或 F34 上已经传过的同一张。没有穿衣底图就停，不用定妆全身图代替，避免古装发型和妆留在去衣结果里。

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

固定 LoRA scale `0.85`。不扫 scale。一采只改衣着、发型和妆。输入只喂 `body-clothed` 底板，不喂定妆 ref。构图、锁脸、去衣分成三句，互不替换。构图只写全身入画：中文「头和双脚都留在画面内，不要裁成头肩」，加上独立硬句 `full body, head and both feet in frame, no bust/head crop`。锁脸只写脸型、五官、身体和允许改的发型妆。去衣只写脱掉的衣服，同一句写两遍。不另加接触或情节。

林晚棠正面下一颗从 seed `57` 起。`scale 0.85 / seed 33` 作废。已失败黑名单是 seed `33`–`56`，这些籽不再重跑。seed `34`–`46` 因身份或衣着低于 9 失败。seed `47`–`49` 收成头肩，硬门 `FEET`，根因是当时提示没有「头脚都留在画面」的构图句。seed `50` 构图已是全身，mean `9.0`、硬门空、look 空，但仍 `passed=False`：至少一项内容分低于 9，旧日志没有留下八项，所以不能猜是哪一项。seed `51` 衣着分为 2。seed `52` mean `8.75`，硬门空、look 空，同样没有八项记录。新规则下 seed `53` mean 5.0、FEET、MAKEUP（漂浮头）；seed `54` mean 4.4、FEET（只有头）；seed `55` mean 7.6、硬门空、wardrobe 2（全身但衣服还在）；seed `56` mean 7.13、MAKEUP、wardrobe 1（全身，红唇和衣服还在）。八项写在每张失败图旁边的 json。identity、anatomy 或 wardrobe 低于 9 立刻换下一颗种子。任一内容项低于 9 都不过门。一采没有过门就自动下一颗，直到过门，或用户放下停止文件 `/tmp/cast-asset-stop`（本机）或 `/root/autodl-tmp/in/cast-asset-stop`（F34）。没有「三颗就停」。用户叫停时一采未过门，禁止二采。

一采和二采无论过不过门，日志都打出八项、`period_hair`、`period_makeup`、`eyes_black_brown`、硬门、look 和 `below`。每张尝试图旁边写同名 `.json`，里面有八项。mean 为 9 仍失败时，`below` 列出低于 9 的项。

1. 一采 `448×592`，8 步，`true_cfg_scale` 4。除分辨率外，全部要求都要过：identity、distinction、interaction（姿势）、aesthetics、anatomy、wardrobe、motif、photoreal 都 ≥ 9，硬门为空，发型妆眼睛自检通过。像素停在这一档，不因为图小单独判负，也不因为图小把内容分放行。identity 低于 9 表示脸被重画，不是因为按要求改了发型或妆。
2. 二采只在一采过门之后才允许。同一 seed、同一 scale、同一段「只放大」提示词，把过门的一采放大到 `896×1200`。从 denoise `0.20`、12 步起。全八项均分 ≥ 9，硬门为空，自检仍要通过。掉分只改 denoise 和步数，不改提示词，不改内容，不改 scale，不换种子。显存不够时，VAE 已经在 CPU，接着同样只降步数或去噪。未过门的一采不进这一段。

8bit bitsandbytes 主干留在 GPU。文本编码器和 VAE 留在 CPU。禁止把 BF16 整模读进主机内存。

## 发型妆眼睛

林晚棠、顾承安的去衣模板去掉古装发髻、头饰、额带、花钿、浓妆、红唇。头发是自然黑褐色（林晚棠披发，顾承安短发）。眼睛是正常黑褐色。打分不再用古装发型认人。自检字段 `period_hair`、`period_makeup`、`eyes_black_brown` 缺了或不对，不得标过门。

伊莲保持赤褐发、暖琥珀棕眼、人耳。阿德里安保持深色发、浅蓝灰眼、尖耳，不要武器。

## 机器

只用 F34 `xaxna66hqt-c5c9c7fc`（西北B）。禁止开 G09 `sa4eaxgcuq-26e36fc9`，禁止新建实例。F34 上若已有出片 worker，本脚本退出，不杀那个进程。开机要用户授权；状态不是 `running` 时脚本不开机。

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
