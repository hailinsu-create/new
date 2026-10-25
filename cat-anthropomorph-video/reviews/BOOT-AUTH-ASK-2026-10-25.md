# 开机授权请示 · 2026-10-25（改写版）

> **状态：等待用户明确授权**。本文不是开机指令；未授权则保持双机关机留盘。
> **余额只以 AutoDL 控制台为准**（本文不写死金额）；**不充值、不 release**，除非用户另行书面授权。

## 0) 先做离线 v0.1b（不花 GPU）

当前 **v0.1b 只有 R1 / R2 / R4**，且 **R4 场景漂移偏弱**；先离线装配，不急着开机：

```bash
cd cat-anthropomorph-video
python3 scripts/assemble_clip.py <R1_or_R2_or_R4.mp4> --start-image <首帧> --audio bed
python3 scripts/assemble_clip.py --self-test
```

- 目标：用 `RENDER_DONE → G1/G2/G2m → AUTO_QC_PASS → candidates.jsonl` 把现有片段过一遍；人眼确认后才 `--human`。
- 离线能拼出的 15s v0.1b 先出 silent/节拍床样片；**R4 漂移不达标就不当可用成片**。
- 只有在离线装配仍缺关键镜头时，才进入下面的开机包。

## 1) 双机 race（硬约束）

| 项 | 口径 |
| --- | --- |
| 机位 | 母 **025** `9b4c40bda6-dad38bb9` · 克隆 **003** `bb8c4f8e12-00c8bdac`（重庆A · RTX 4090D · 100G） |
| 并发 | **任意时刻只开一台**；确认另一台已关机，禁止双开抢盘 |
| I2V | 优先母 025；**克隆 003 明确可代跑 I2V** |
| Looklock | 优先克隆 003（Qwen）；单机互斥不变 |
| 计费 | 以控制台余额为准；不自动充值、不 release、不删盘 |

## 2) 下次 GPU 包（授权后按序）

| 序 | 任务 | 建议机位 | 模板 | 备注 |
| --- | --- | --- | --- | --- |
| 1 | **诺曼底艇/滩场景 looklock**（A 小橘 + 艇/滩参考） | 克隆 003 优先 | `workflow/01_looklock_qwen_edit.json` | 先出场景首帧；过盲测/裁切后再喂 I2V |
| 2 | **修 R4 场景漂移**（换 start_image/seed，必要时 R3 回退） | 母 025 优先；003 可代跑 | `workflow/02_i2v_wan21_480p.json` 方案 A | v0.1b 已知弱点；只改槽位 |
| 3 或 | **R6 战场短动作**（短 motion 段） | 同上 | 同上 | 与序 2 二选一；先短样片，不量产 |

- 完成序 1 后，序 2 / 序 3 **按需二选一**，不并跑、不同时开机。
- 每段产物：先 `assemble_clip.py` 过 G1/G2/G2m；`AUTO_QC_PASS` 仍不可用，人眼确认后 `--human`。
- 方图 looklock 先 `crop_check_i2v.py`；G2m 阈值 11（R1 正例 16.27，静帧基线≈3.6）。

## 3) 明确不做（本请示范围外）

- **不**跑 FLF2V（`03_flf2v`）。
- **不**定妆银宝（B）/ 墨墨（C）；只做 A 小橘的诺曼底艇/滩场景。
- **不**自动充值、**不** release 删盘、**不** merge/发布。
- **不**碰 `ai-realistic-comic/`、NSFW 或未授权曲目。
- **不**双开、**不**在克隆与母机之间来回抢同一工作目录。

## 4) 验收

- 离线：`python3 scripts/assemble_clip.py --self-test` 与 `bash scripts/smoke_test.sh --dry-run` 均 exit 0。
- 真机每段：G1 `noise_gate` + G2 `subject_gate` + G2m `motion_gate`；人眼身份/动作/音轨。
- 有声按 [`scripts/AUDIO-SWAP.md`](../scripts/AUDIO-SWAP.md) 听检；默认 silent 或自制 128 BPM 节拍床。
- 12 秒/15 秒都不是侵权豁免；只用目标平台官方曲库或书面授权/CC0。

## 5) 待 GPU（仍未授权 / 未开机）

- 诺曼底艇/滩 looklock 首帧、R4 漂移修复、R6 短动作均未真机验证。
- `subject_gate.py` 的 0.25–0.92 带与中心区启发式需真实 I2V 样片校准（合成 fixtures 不等于真机证据），默认不改。
- `assemble_clip.py` 的真实 15s 有声样片、三态走账与 `candidates.jsonl` 需在真机产物上跑一遍。
- 以上全部等用户明确授权；不充值、不 release。

## 6) 授权回复模板（用户可复制）

```text
授权开机：只开一台；
先克隆 003 跑诺曼底艇/滩 looklock，再[母 025 / 克隆 003]跑 R4 漂移修复或 R6 战场短动作；
不 FLF2V；不定妆银宝/墨墨；不充值；不 release；关机留盘。
```
