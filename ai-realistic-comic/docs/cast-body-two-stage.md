# 演员资产模板流水线

这条流水线给以后的出片提供可复用身体模板。它不是叙事构图，也不是艺术创作。入口和出片静帧分开：

- 出片继续走 `docs/explicit-still-two-stage.md` 和 `autodl/run_explicit_two_stage.py`。这里不改那两个文件，也不共用它们的 job 文件。
- 资产走 `autodl/run_cast_body_two_stage.py` 和 `autodl/cast_body_worker.py`。机器上的队列是 `/root/autodl-tmp/in/cast-asset-job.json`。

四人仍是林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩。一采只改衣着、发型和妆，脸锁在喂进去的穿衣底板上。不写故事场景，不换构图。

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

## 两段，求快

固定 LoRA scale `0.85`。不扫 scale。一采只改衣着、发型和妆，五官、脸型和肤色锁住这张穿衣底板，不要重画脸。输入只喂 `body-clothed` 底板，不喂定妆 ref。

林晚棠正面从 seed `34` 起；`scale 0.85 / seed 33` 那张正面一采已作废，脚本拒绝把它标成过门。identity 或 anatomy 低于 9 就换下一颗种子。同一张一次调用最多三颗种子。三颗都未过门就停，禁止二采。

1. 一采约 `448×592`（接近 448×600 的网格），16 步。过门看 identity、interaction（姿势）、anatomy、wardrobe 都 ≥ 9，硬门为空，并且发型妆眼睛自检通过。identity 低于 9 表示脸被重画，不是因为按要求改了发型或妆。
2. 二采只在一采过门之后才允许。同一 seed、同一 scale，低去噪放大到 `896×1200`。全八项均分 ≥ 9，硬门为空，自检仍要通过。掉分只重二采。二采显存不够时，VAE 已经在 CPU，接着只降步数或去噪，不改 scale，不重做一采。未过门的一采不进这一段。

8bit bitsandbytes 主干留在 GPU。文本编码器和 VAE 留在 CPU。禁止把 BF16 整模读进主机内存。

## 发型妆眼睛

林晚棠、顾承安的去衣模板去掉古装发髻、头饰、额带、花钿、浓妆、红唇。头发是自然黑褐色（林晚棠披发，顾承安短发）。眼睛是正常黑褐色。打分不再用古装发型认人。自检字段 `period_hair`、`period_makeup`、`eyes_black_brown` 缺了或不对，不得标过门。

伊莲保持赤褐发、暖琥珀棕眼、人耳。阿德里安保持深色发、浅蓝灰眼、尖耳，不要武器。

## 机器

只用 F34 `xaxna66hqt-c5c9c7fc`（西北B）。禁止开 G09 `sa4eaxgcuq-26e36fc9`，禁止新建实例。F34 上若已有出片 worker，本脚本退出，不杀那个进程。开机要用户授权；状态不是 `running` 时脚本不开机。

和出片共用同一套 F34 登录，不另要令牌。自测是 `python autodl/run_cast_body_two_stage.py --login-check`。口令读 `AUTODL_SSH_PASSWORD`，或本机 `/tmp/cast-ssh.env`。SSH 通了再核对 F34 上的 `/root/autodl-tmp/.cast-ssh.env`。口令不写入仓库。

关机保留数据盘。关机之后立刻读 AutoDL 钱包 `assets`（厘）并写进当轮报告。1000 厘 = ¥1。低于 ¥5 只警报，不充值。

```bash
# 只看机器和余额，不出图
AUTODL_TOKEN=... python autodl/run_cast_body_two_stage.py --doctor

# 林晚棠正面：一采过门后自动二采
AUTODL_TOKEN=... python autodl/run_cast_body_two_stage.py --only lin_wantang:front
```

在 `ai-realistic-comic/` 目录下运行。一采过门图写到 `/opt/cursor/artifacts/body-nude/<id>-<view>-pass1.png` 和同名 json。二采过门才写入 `library/cast/<id>/body-nude/` 和 F34 `/root/autodl-tmp/assets/body-nude/<id>/`。
