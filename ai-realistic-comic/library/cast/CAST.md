# 演员锁定 / CAST LOCK

这一套是唯一的演员资产，不是两套系统。body-boards/p01..p08（八格样张的裁图）锁姿势和身体；演员目录 lin_wantang、gu_chengan、elena_voss、adrian_kane 各自保留今天的定妆 ref.png 和 actor.md（名字、脸、身体、衣柜），作为同一批人的脸和衣柜锁。p01–p04 是林晚棠 + 顾承安，p05–p08 是伊莲·沃斯 + 阿德里安·凯恩。没有第二套演员。

破限静帧（更露、贴得更近，姿势表情不动）只能走 `docs/explicit-still-two-stage.md` 和 `autodl/run_explicit_two_stage.py`。监督 bot 不得另开生成指令。收留按 `docs/still-score-two-stage.md`。打分默认仍是 Codex CLI。只有 Codex CLI 不可用才回退 Cursor 提供的 grok 4.7，标准和阈值相同。禁止 grok.com CLI。禁止 OpenCode vision。满分基准是亭中盘蛇 `library/stills/explicit-8/anchor-10.jpg`，硬门不过或八项均分低于 9 就在该脚本里重出这一张。蛇身是一条珍珠白鳞尾，尾尖圆钝且连在同一条尾巴上，不是蛇头，不是鱼尾。白蛇自己的人腿或人脚才算不合格；顾承安自己的脚不扣。人身格的人腿是对的。只有阿德里安有尖耳；伊莲是人耳，眼睛是琥珀褐不是绿。阿德里安不要武器。

它同时包含三样东西，缺一不可：

1. **姿势 / 身体板** `library/cast/body-boards/p01.png` … `p08.png`。从唯一样张八格 `library/samples/approved/01-grid.jpg`（与用户附件同一文件）按 2×4、从左到右、先上后下裁出。每张只锁那一格的姿势、表情和身体关系。没有第二套身体板。
2. **今天的 F34 定妆** `lin_wantang/ref.png`、`gu_chengan/ref.png`、`elena_voss/ref.png`、`adrian_kane/ref.png`。这是同一批人的脸和衣柜锁，不是另一套身体板，也不是 `library_pose_dingzhuang`。
3. **演员名和面容身体细则** 各自的 `actor.md`。名字保留：林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩。

八格里的人就是这四位演员。上排（p01–p04）是林晚棠与顾承安；下排（p05–p08）是伊莲·沃斯与阿德里安·凯恩。神话名（白素贞、许仙、珀耳塞福涅、哈迪斯）只是他们正在演的角色，不是另一张脸。

**中文：** 今后镜头里出现的任何亚洲女性都是林晚棠（lin_wantang），任何亚洲男性都是顾承安（gu_chengan），任何西方女性都是伊莲·沃斯（elena_voss），任何西方男性都是阿德里安·凯恩（adrian_kane）。身份不得漂移。
**English:** Any future Asian woman on camera is 林晚棠 Lin Wantang (lin_wantang); any future Asian man is 顾承安 Gu Cheng'an (gu_chengan); any future Western woman is 伊莲·沃斯 Elena Voss (elena_voss); any future Western man is 阿德里安·凯恩 Adrian Kane (adrian_kane). Identity must not drift.

`library/samples/approved/` 里用户最初那五张是唯一的样张。p01–p08 的姿势、表情和蛇尾按它们复刻。身体板是八格样张的裁图，锁姿势和表情；定妆 ref 锁同一批人的脸和衣着。不要拆成两套。Fal crops、`qwen_poselock_*`、`qwen_fishtail_*`、`library_pose_dingzhuang`，以及还没目检通过的静帧，都不是样张。

## 四位演员 / The four standing actors

| id | 中文名 | English | standing slot | 当前饰演角色 | 脸和衣柜锁（F34 定妆） | 细则 |
|---|---|---|---|---|---|---|
| lin_wantang | 林晚棠 | Lin Wantang | 亚洲女性 | 白素贞 | `cast/lin_wantang/ref.png` | `cast/lin_wantang/actor.md` |
| gu_chengan | 顾承安 | Gu Cheng'an | 亚洲男性 | 许仙 | `cast/gu_chengan/ref.png` | `cast/gu_chengan/actor.md` |
| elena_voss | 伊莲·沃斯 | Elena Voss | 西方女性 | 珀耳塞福涅 | `cast/elena_voss/ref.png` | `cast/elena_voss/actor.md` |
| adrian_kane | 阿德里安·凯恩 | Adrian Kane | 西方男性 | 哈迪斯 | `cast/adrian_kane/ref.png` | `cast/adrian_kane/actor.md` |

## 八格身体板 / The only body boards

| file | 格子 | 谁 | 姿势锁 |
|---|---|---|---|
| `cast/body-boards/p01.png` | 上排左一 | 林晚棠（蛇身）+ 顾承安 | 月下木屋，她盘在地上，脸贴近，手在他胸口 |
| `cast/body-boards/p02.png` | 上排左二 | 林晚棠（蛇身）+ 顾承安 | 夜湖，她在水中仰视，他跪在码头提灯 |
| `cast/body-boards/p03.png` | 上排左三 | 林晚棠（人身）+ 顾承安 | 帐内，她站着靠向坐着的他，手在腰肩 |
| `cast/body-boards/p04.png` | 上排左四 | 林晚棠（人身）+ 顾承安 | 雨桥，他举伞、竹药桶，湿衣，脸贴近 |
| `cast/body-boards/p05.png` | 下排左一 | 伊莲·沃斯 + 阿德里安·凯恩 | 冥府站立相拥，皮毛斗篷，石榴，火把 |
| `cast/body-boards/p06.png` | 下排左二 | 伊莲·沃斯 + 阿德里安·凯恩 | 她躺着，他俯身，脸贴近，百合与红籽 |
| `cast/body-boards/p07.png` | 下排左三 | 伊莲·沃斯 + 阿德里安·凯恩 | 烛光站立相拥，她的手在他脸或颈 |
| `cast/body-boards/p08.png` | 下排左四 | 伊莲·沃斯 + 阿德里安·凯恩 | 王座，她侧坐他腿上，一腿抬起，喂他 |

## 使用顺序 / Order of use

1. 出图时两张参考一起用：该格的 `body-boards/p0N.png` 锁姿势和表情；对应演员的 `ref.png` 锁脸和衣柜。Read the panel body board for pose and expression, and that actor's makeup `ref.png` for face and wardrobe. Both belong to this one cast.
2. 角色名只用于场景叙述，不产生新脸。Role names never create a new face.
3. 林晚棠的蛇身是她自己的身体变体（珍珠白钝尾，不是鱼尾）。p02 的青色是水光，尾巴本身仍是珍珠白钝尾。
4. 不要另建身体板目录，不要把定妆照或 `library_pose_dingzhuang` 当成第二套身体板。
