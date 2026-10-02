# Ambush Loop v0.6.0 大改报告

日期：2026-09-18。分支 `cursor/commandos-ambush-0641`。方法：PaperRoute，切片提交，Engine / Look 分开。

## 改了什么

**Engine**

- 观察环填色 LOS 裁切 + 淡化，人影/环缩放仍 1.0，侦察 `kit_range` 仍 280。院子不再被 280px 青皂泡盖住。
- 西巷三人金色队形线。落点仍 (7,12)/(6,6)/(5,16) span 6，镜头 ~1.0 平移/裁切。
- 第一局：跟芯片加大；开匣钉在头顶；绕背 88×38。需枪契约未改。

**Look（无头 Blender）**

- 院子木匣：侧板接缝 + AMMO 钢印。GLB 为源，iso 烘图进可玩院子 (19,10)。
- 第二件：橄榄 30CAL 弹药箱，放在同一岛上。

RAID 未动：`SCOUT → ALERT → SWEEP`，警报锁走位，自动开火/手雷，10 枪 kit，简配 5 键。

## 还卡哪

- 西巷 span 6 仍然散，队形线是视觉胶水，不是更紧的落点。
- 跟芯片命中仍被 gun-band 裁到约 39×20。
- 有脸角色未走 Meshy（没有 `MESHY_API_KEY`）。
- 真机拇指未证；窗口 dump 不是手机。

## 方法论对照

| 规则 | 本轮 |
| --- | --- |
| 先 brief | `.cursor/docs/AMBUSH_OVERHAUL_BRIEF.md` |
| 先可玩再画面 | Engine 0.5.40–42 先于 Look crate/can |
| 一条可验证的事 + commit | 环 / 队形线 / 第一局 / crate study / crate in yard / ammo can |
| 无头 Blender → GLB + 接触纸 | `ArtSource/build_yard_crate.py`、`build_ammo_can.py` |
| 审图指向帧 | `01_scout_touch_simple`、`08_west_combo_follow`、`07_west_crate`、`yard_crate_turnaround` |

## Engine vs Look 下一步

- Engine：若还要更抱团，单独做 dest 重写并改 leftover 0534–0539 断言；不要再缩 zoom/body。
- Look：下一件道具（步枪匣剪影）或夜间地面材质；有 key 再 Meshy 夜枭。
