# 林晚棠 × 顾承安 — 九尾狐旗袍情侣拥吻

一次性成衣双人静帧 + R4 去衣/破衣变体。不是身体板，不改 CAST 常驻身体。林晚棠常驻仍是白素贞蛇身；本张戏服为旗袍 + 九尾。顾承安饰演伴侣，脸锁 `gu_chengan/ref.png`。

## 脸

- 林晚棠：`library/cast/lin_wantang/ref-face.png`（黑发、黑褐眼、清冷东方脸）
- 顾承安：`library/cast/gu_chengan/ref.png`
- 正好两人。**均为成年人**。原创脸，非真人。

## 这一张

- 林：装饰旗袍，人身，**九条白狐尾**（白狐，不是蛇）。
- 顾：成年亚洲男性；**形象/衣服不锁**，按林画面配合（本板：现代短发、无发髻头饰）。
- 姿势锁定：床上**林半压顾**拥吻（姿势 C 修订）。
- 同一构图三张：**穿衣 / 去衣 / 破衣**——仅林的衣物变化；姿势、白九尾、顾（底板内）、背景在 R4 编辑时锁死。

## 出图

**2026-10-10**：成衣底板已锁定为 `USER_LOCKED_lin-gu-C.jpg`（commit `8d30232`）。顾形象/衣服以后不锁，按林画面配合。

1. 成衣候选：Cursor GenerateImage（锁脸参考）；不开 AutoDL。
2. 用户挑定姿势 → 写入 `lin-gu-embrace-clothed.png` + `POSE_LOCKED.json`。
3. 去衣 / 破衣：R4（`docs/fox-undress-r4-standard.md`），只编辑林的衣物；正式=贴回前 raw；需明确授权开机。
4. 产物：`/opt/cursor/artifacts/fox-couple/` + `library/stills/fox-couple/`。
