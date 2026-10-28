# 内容切刀 · B0-01 诺曼底 · v0.3.3 · 2026-10-28

- **可执行目标**：`outputs/v0.3.3-b0-01-2026-10-28/out/B0-01-normandy-v0.3.3.mp4`
- **对齐声明**：主 **DROP = 涉水首帧 3.583**；门落降为 **build**；DROP 前 **黑场 0.375s**
- **本轮不开机**；成片 RESULT 见 [`../RESULT-v0.3.3-ASSEMBLE-2026-10-28.md`](../RESULT-v0.3.3-ASSEMBLE-2026-10-28.md)
- 脚本 stub：[`../scripts/assemble_v0.3.3.sh`](../scripts/assemble_v0.3.3.sh)

## 路径约定

```text
ROOT=cat-anthropomorph-video
P4=$ROOT/outputs/h3-phase4-2026-10-27
ST=$ROOT/outputs/cursor-stills-looklock-v0.3.1
OUT=$ROOT/outputs/v0.3.3-b0-01-2026-10-28
EDIT=$OUT/edit
W=1080; H=1920; FPS=24
```

## 成片时间线（目检锁点）

| 成片时间 | 事件 |
| ---: | --- |
| 0.00 | 真猫钩子起 |
| ≈2.40 | 门落 build 段起（非主 drop） |
| **3.208–3.583** | **黑场 0.375s**（DROP 前抽空） |
| **3.583** | **主 DROP → S05 涉水首帧** |
| 中后段 | S08 冲锋（膝上裁）→ 爆破闪白 → S10 旗（ss=2.00）→ 定格署名 |
| 14.958 | 片尾 |

## 逐刀切刀

| # | out clip | 操作要点 | timeline |
| ---: | --- | --- | --- |
| 1 | `k_cat.mp4` | loop 真猫 front · 轻 Ken Burns · drawtext `1944·诺曼底` | 0.00–1.00 |
| 2 | `k_portrait.mp4` | loop looklock portrait · 轻推 | 1.00–2.00 |
| 3 | `k_boat.mp4` | loop `S04_boat_ramp_start` 静帧 | 2.00–2.40 |
| 4 | `s04_build.mp4` | S04 门落 **短窗作 build**（非主 drop）；可轻闪/震，勿抢 3.583 | 2.40–3.208 |
| 5 | `fx_black.mp4` | `color=black:s=1080x1920:d=0.375` | **3.208–3.583** |
| 6 | `s05.mp4` | S05 **从源片首帧起**入成片；`crop` **膝上**（藏滑步）；对齐 **DROP 3.583** | 3.583–… |
| 7 | `s08.mp4` | S08 冲锋；**膝上裁**；仍避开步枪瞬消坏帧（盖切/闪白） | 中段 |
| 8 | `fx_blast.mp4` | 白闪 + 微震（爆破重音） | 爆破锁点附近 |
| 9 | `s10.mp4` | S10 **`-ss 2.00`** 成形切入（旗已在画面可读）→ scale/crop | 后段 · 插旗 |
| 10 | `k_end.mp4` | 末帧 Ken Burns + 署名 `AI生成 · 致敬历史 · 非真实影像` | → 14.958 |

### concat 顺序

`k_cat → k_portrait → k_boat → s04_build → fx_black → s05 → s08 → fx_blast → s10 → k_end`

### 音频

```bash
# BGM: Determined Pursuit (Emma_MA, CC0, OGA)
# bed 可复用 v0.3.2 edit 床，或同参重切 ≈15s
ffmpeg -i silent.mp4 -i bgm_primary_15s.wav -c:v copy -c:a aac -b:a 160k -shortest out.mp4
```

## 相对 v0.3.2 的包装债

| 项 | v0.3.2 | v0.3.3 |
| --- | --- | --- |
| 主 drop | 门落 3.60 | **涉水 3.583** |
| 门落 | drop | **build** |
| 抽空 | 无 | **黑场 0.375s** |
| 滑步 | 全身 | **膝上裁** |
| 旗 | ss≈0.80 | **ss=2.00** |

## 验收清单

- [x] 成片时长 **14.958s**（±0.05 可接受）
- [x] 主 DROP 目检对齐 **涉水首帧 ~3.583**
- [x] DROP 前黑场 **0.375s**
- [x] S05/S08 膝上裁
- [x] S10 从 **ss=2.00** 切入
- [ ] 步枪瞬消 — **仍在**（仅内部；真修须开机/改道具线）
- [x] 大 mp4 / wav **不入库**

ALIGN_OK v0.3.3 DROP@3.583 wade · door=build · black=0.375 · flag ss=2.00
