# RESULT v0.4 ASSEMBLE — 2026-10-28 (Asia/Shanghai)

**RESULT:** **PASS** — H3 Phase6 五镜 GATE PASS → ¥0 本机拼装 v0.4 成片。**未开机** / 未充值 / 未 release；禁 NSFW / grok。

| 项 | 值 |
|---|---|
| Phase6 GATE | **PASS**（旗连续 / 无幻肢 / 群戏≥2 / M09 非白场）· `outputs/h3-phase6-2026-10-28/GATE.md` |
| watch | WATCH_PASS 2026-10-28 18:22:07 +0800（前期出片；本轮仅包装） |
| 成片路径 | `/workspace/briefs/cat-anthropomorph-video/outputs/v0.4-b0-01-2026-10-28/out/B0-01-normandy-v0.4.mp4` |
| 时长 | **15.000 s** |
| 分辨率 | **1080×1920** @ 24fps，竖屏 |
| 编码 | h264 + **AAC stereo 44.1kHz**（有声） |
| 体积 | 9844799 bytes (~9.4 MiB) |
| 脚本 | `scripts/assemble_v0.4.sh` → `ASSEMBLE_V04_DONE` |
| 锁点 | DROP **3.600** · 炮火 **9.200** · 插旗 **12.800**（均 Δ0.000 ≤±0.15） |
| BGM | Determined Pursuit（Emma_MA · CC0）复用 v0.3.2 bed |
| SFX | v0.2 slam/splash/whoosh/hit/boom/flagwind + Phase6 原生床 duck |

## Phase6 五镜源

| 镜 | 路径 | 用途 |
|---|---|---|
| M04 | `h3_phase6_M04_door_crowd_00001_.mp4` | 门开见海+群影 · DROP |
| M05 | `h3_phase6_M05_wade_flag_00001_.mp4` | 持旗涉水 |
| M08 | `h3_phase6_M08_mass_charge_00001_.mp4` | 集群冲锋 |
| M09 | `h3_phase6_M09_artillery_00001_.mp4` | 可见炮火 |
| M10 | `h3_phase6_M10_flag_plant_00001_.mp4` | 沙丘插旗 |

源规格：768×1344 · ~5.17s · 24fps（各镜）。

## 刀表（实际）

| 段 | 计划 | 实际起–止 | 源 |
|---|---:|---|---|
| K01 | 0.0–0.9 | 0.000–0.917 | 真猫 +「1944·诺曼底」 |
| K02 | 0.9–1.7 | 0.917–1.708 | 定妆持旗静帧（M04 start） |
| M04 | 1.7–4.2 | 1.708–4.208 | Phase6 M04；DROP=3.600 |
| M05 | 4.2–6.6 | 4.208–6.625 | Phase6 M05 |
| M08 | 6.6–8.7 | 6.625–8.708 | Phase6 M08 |
| M09 | 8.7–9.8 | 8.708–9.792 | Phase6 M09；炮火=9.200 |
| M10 | 9.8–13.2 | 9.792–13.208 | Phase6 M10；插旗=12.800 |
| KEND | 13.2–15.0 | 13.208–15.000 | 定格 + Normandy 1944 · AI生成 |

## 相对 v0.3.4 一句

**同道具旗全程 + 群戏（M04/M05/M08）+ 可见炮火（M09 非白场）均已进成片**（v0.3.4 缺集群与真炮火卡点）。

## ffprobe

```
codec=h264 1080×1920 + aac stereo 44100
duration=15.000000
size=9844799
```

## 验收

- [x] Phase6 GATE PASS 后拼装  
- [x] ≈15s · 1080×1920 · AAC  
- [x] 锁点 DROP/炮火/插旗 ±0.15s  
- [x] **未开机** / 未充值 / 未 release  
- [x] RESULT + CUTLIST + assemble 脚本  

## 边界

大 mp4 本机保留、默认可不入库。文档推 PR#84。

## Notion

短交付页：https://app.notion.com/p/407b407a692a8190bc57f9d522db11b7
