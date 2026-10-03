# 破限静帧模式 / Explicit still mode

这是同一套演员上的一种出图模式，不是新演员，也不是第二套身体板。演员锁仍以 `library/cast/CAST.md` 为准。以后同类静帧必须按本文件，不能改走 `docs/still-mode.md` 里的 fal nano-banana 配方。

## 资产锁

- 姿势和表情只锁 `library/cast/body-boards/p01.png`–`p08.png`（八格样张裁图）。
- 脸是同一批人的定妆：p01–p04 林晚棠 `lin_wantang` + 顾承安 `gu_chengan`；p05–p08 伊莲·沃斯 `elena_voss` + 阿德里安·凯恩 `adrian_kane`。参考图 `library/cast/<id>/ref.png`。神话名只是角色，不另起一张脸。
- 可以比身体板更露、衣服更开、身体贴得更近。姿势、构图、表情、身份不变。不要多余的人、文字、水印，不要未成年人。

## 蛇尾锁

林晚棠的水下和蛇身格（p01、p02）只有一条珍珠白钝尾，没有人腿，没有鱼鳍、鱼尾、第二截尾巴。p02 的青色只是水光，尾巴本身仍是珍珠白钝尾。人腿只出现在 p03（帐内）和 p04（雨桥）。同一格里不能又有人腿又有蛇尾。

鳞片必须一直铺到钝尖。末段光滑、没有鳞，算不合格。

## 哪张图不能当样例

`library/stills/explicit-8/` 里这次跑出来的文件不要整夹当标准：

- `p02.png` 不合格。同一画面里既有人腿又有蛇尾。副本：`archive/p02-human-leg.png`。不要复制，不要当批准样例。
- `p01.png` 当前文件不合格。钝尖前面有一截光滑无鳞。副本：`archive/p01-unscaled-tip.png`。该格正在重跑，重跑结果替换 `p01.png` 之前，不要把这张当尾巴样例。
- `p03.png`–`p08.png` 是这次用户看过、可以沿用的破限静帧。它们不证明蛇尾合格。

## 出图

- 只在 AutoDL F34 实例 `xaxna66hqt-c5c9c7fc` 上跑本地 Qwen。不要开旧的 G09 `sa4eaxgcuq-26e36fc9`。
- 模型 `qwen-image-edit-2511`，权重用机上缓存、离线加载。896×1200，40 步，seed 1。
- 入口 `autodl/run_explicit8.py`，提示词 `library/stills/explicit-8/prompts.md`。参考顺序是该格身体板在前，再跟两位演员的定妆。
- 跑完关机，数据盘留下，权重缓存不删。不要空开着 GPU 计费。

再出同类静帧时照这个锁，包括一条钝尾、没有人腿、鳞到尖。fal 静帧模式不能代替这一条。
