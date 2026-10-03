# 破限静帧模式 / Explicit still mode

这是同一套演员上的一种出图模式，不是新演员，也不是第二套身体板。演员锁仍以 `library/cast/CAST.md` 为准。以后同类静帧必须按本文件，不能改走 `docs/still-mode.md` 里的 fal nano-banana 配方。

新神话姿势锁（尚未出图）见 `library/stills/myth-poses/POSE.md`。

## 资产锁

- 姿势和表情只锁 `library/cast/body-boards/p01.png`–`p08.png`（八格样张裁图）。
- 脸是同一批人的定妆：p01–p04 林晚棠 `lin_wantang` + 顾承安 `gu_chengan`；p05–p08 伊莲·沃斯 `elena_voss` + 阿德里安·凯恩 `adrian_kane`。参考图 `library/cast/<id>/ref.png`。神话名只是角色，不另起一张脸。
- 可以比身体板更露、衣服更开、身体贴得更近。姿势、构图、表情、身份不变。不要多余的人、文字、水印，不要未成年人。

## 蛇尾锁

林晚棠的水下和蛇身格（p01、p02，以及神话蛇身格 m01）只有一条珍珠白蛇尾，没有鱼鳍、没有尾鳍、没有鱼尾、没有第二截尾巴。p02 的青色只是水光，尾巴本身仍是珍珠白钝尾。蛇形画面里不能同时有人腿或人脚。人腿只出现在明确的人身格（p03、p04，以及神话人身格 m02）。同一格里不能又有人腿又有蛇尾。m02 不要蛇尾。m03、m04 不要蛇尾。

尾巴是不断的同一条。鳞片从尾根铺到圆钝尾尖。末段光滑、没有鳞、看起来切断，都算不合格。尾尖不能长成蛇头：没有眼、没有绿眼、没有嘴、没有第二张脸。正向提示词不写 stump；stump 只放负向。

## 脸、姿势、眼睛

脸和衣服锁四位定妆：林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩，参考图 `library/cast/<id>/ref.png`。不要另起一张脸。p01–p08 的姿势和表情锁身体板。m01–m04 的姿势和表情锁 `library/stills/myth-poses/POSE.md`，不要抄定妆全身站姿，也不要抄成另一格身体板。伊莲眼睛是琥珀褐，不是绿。阿德里安尖耳留着，不要武器。

## 哪张图不能当样例

`library/stills/explicit-8/` 里这次跑出来的文件不要整夹当标准：

- `p02.png` 不合格。同一画面里既有人腿又有蛇尾。副本：`archive/p02-human-leg.png`。不要复制，不要当批准样例。
- `p01.png` 当前文件不合格。钝尖前面有一截光滑无鳞。副本：`archive/p01-unscaled-tip.png`。该格正在重跑，重跑结果替换 `p01.png` 之前，不要把这张当尾巴样例。
- `p03.png`–`p08.png` 是这次用户看过、可以沿用的破限静帧。它们不证明蛇尾合格。

## 出图

- 只在 AutoDL F34 实例 `xaxna66hqt-c5c9c7fc` 上跑本地 Qwen。不要开旧的 G09 `sa4eaxgcuq-26e36fc9`。
- 模型 `qwen-image-edit-2511`，权重用机上缓存、离线加载。896×1200，40 步，seed 1。
- 入口 `autodl/run_explicit8.py`。同一套 Qwen 缓存，不另下权重。脚本会连读 `library/stills/explicit-8/prompts.md` 和 `library/stills/myth-poses/prompts.md`。
- p01–p08 参考顺序仍是该格身体板在前，再跟两位演员的定妆。m01–m04 没有新身体板，参考图只有两位演员的定妆，姿势写在提示词里。
- 只跑 p01、p02：`EXPLICIT_ONLY=p01,p02 python autodl/run_explicit8.py`
- 只跑 m01–m04：`EXPLICIT_ONLY=m01,m02,m03,m04 EXPLICIT_OUT=/root/autodl-tmp/out/myth-poses python autodl/run_explicit8.py`
- 跑完关机，数据盘留下，权重缓存不删。不要空开着 GPU 计费。

再出同类静帧时照这个锁，包括一条钝尾、没有人腿、鳞到尖。fal 静帧模式不能代替这一条。
