# 演员锁定 / CAST LOCK

四位固定演员（standing actors）从四张 F34 Qwen makeup sheets 锁定，sheet 优先于任何旧的 makeup_prompt.md 或 card.yaml。未在 sheet 上看见的特征不发明；看不清的写 uncertain。

**中文：** 今后镜头里出现的任何亚洲女性都是林晚棠（lin_wantang），任何亚洲男性都是顾承安（gu_chengan），任何西方女性都是伊莲·沃斯（elena_voss），任何西方男性都是阿德里安·凯恩（adrian_kane）。身份不得漂移。
**English:** Any future Asian woman on camera is 林晚棠 Lin Wantang (lin_wantang); any future Asian man is 顾承安 Gu Cheng'an (gu_chengan); any future Western woman is 伊莲·沃斯 Elena Voss (elena_voss); any future Western man is 阿德里安·凯恩 Adrian Kane (adrian_kane). Identity must not drift.

神话名字（白素贞、许仙、珀耳塞福涅、哈迪斯）只是这四位演员饰演的角色，不是第四张、第五张脸；换项目、换剧情、换服装都不换脸和身体。Myth names (白素贞, 许仙, 珀耳塞福涅, 哈迪斯) are roles these actors play, not separate faces.

`library/samples/approved/` 里的五个文件（01-grid、02-rain-bridge、03-standing-forehead、04-pavilion-coil、05-throne）仍然并且只是剧情样张 canon；这四张 sheet 是 CAST LOOKS（定妆）。Fal crops、`qwen_poselock_*`、`qwen_fishtail_*`、`library_pose_dingzhuang` 都不是定妆，不作为身份依据。

## 四位演员 / The four standing actors

| id | 中文名 | English | standing slot | 当前饰演角色 maps-to role | ref (F34 Qwen makeup sheet) | actor.md |
|---|---|---|---|---|---|---|
| lin_wantang | 林晚棠 | Lin Wantang | 亚洲女性 Asian woman | 白素贞 Bai Suzhen (baisuzhen_snake) | `cast/lin_wantang/ref.png` (1792×1200, two panels) | `cast/lin_wantang/actor.md` |
| gu_chengan | 顾承安 | Gu Cheng'an | 亚洲男性 Asian man | 许仙 Xu Xian (xuxian) | `cast/gu_chengan/ref.png` (896×1200) | `cast/gu_chengan/actor.md` |
| elena_voss | 伊莲·沃斯 | Elena Voss | 西方女性 Western woman | 珀耳塞福涅 Persephone (persephone) | `cast/elena_voss/ref.png` (896×1200) | `cast/elena_voss/actor.md` |
| adrian_kane | 阿德里安·凯恩 | Adrian Kane | 西方男性 Western man | 哈迪斯 Hades (hades) | `cast/adrian_kane/ref.png` (896×1200) | `cast/adrian_kane/actor.md` |

## 使用顺序 / Order of use

1. 先生成/编辑前读本文件 + 对应 `actor.md`，再把 `ref.png` 作为身份参考。Read this file and the matching `actor.md` before any generation; then use `ref.png` as the identity reference.
2. 角色名只用于场景和服装叙述，不产生新脸。Role names describe scene and wardrobe only; they never create a new face.
3. 生成后的身份检查：脸、瞳色、发型、耳朵（阿德里安尖耳，其余人耳）、林晚棠的人腿/蛇尾两种身体都必须与对应 `actor.md` 一致。Check identity after generation: face, iris color, hair, ears (Adrian pointed, everyone else human), and Lin Wantang's two bodies (human legs / snake tail) must match the actor.md.
