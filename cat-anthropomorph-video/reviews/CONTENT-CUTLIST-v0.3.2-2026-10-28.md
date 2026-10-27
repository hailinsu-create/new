# 内容切刀 · B0-01 诺曼底 · v0.3.2 · 2026-10-28

- **可执行**：按序产出 `outputs/v0.3.2-b0-01-2026-10-28/edit/` 片段后 concat → 叠 BGM  
- **对齐声明**：时间码与 `SCRIPT` / `STORYBOARD` / `MUSIC-BEAT` 一致（3.60 / 9.20 / 12.80）  
- **本轮不开机**；草案脚本见 `scripts/assemble_v0.3.2.sh`

## 路径约定

```text
ROOT=briefs/cat-anthropomorph-video
P4=$ROOT/outputs/h3-phase4-2026-10-27
ST=$ROOT/outputs/cursor-stills-looklock-v0.3.1
OUT=$ROOT/outputs/v0.3.2-b0-01-2026-10-28
EDIT=$OUT/edit
W=1080; H=1920; FPS=24
```

## 逐刀切刀

| # | out clip | 操作（ffmpeg 要点） | timeline |
| ---: | --- | --- | --- |
| 1 | `k_cat.mp4` | loop `refs/cats/A/front.jpg` · zoompan 1→1.08 · 24f · drawtext `1944·诺曼底` | 0.00–1.00 |
| 2 | `k_portrait.mp4` | loop portrait JPG · zoompan 轻推 · 24f | 1.00–2.00 |
| 3 | `k_boat.mp4` | loop `boat_ramp/S04_boat_ramp_start.jpg` · z=1 · 12f | 2.00–2.50 |
| 4 | `s04.mp4` | `-ss 0.90 -t 2.30` S04 → scale/crop 1080×1920；末 0.30s 链 `eq=brightness='min(0.35,0.35*(1-mod(t,0.30)/0.15))':saturation=1.1,rotate=0.01*sin(10*2*PI*t):fillcolor=white@0`（或分两段 concat：主段 2.00s + flash 段 0.30s） | 2.50–4.80 · **hit 3.60** |
| 5 | `s05.mp4` | `-ss 1.00 -t 2.30` S05 → scale/crop | 4.80–7.10 |
| 6 | `s08.mp4` | `-ss 0.35 -t 1.55` S08 → scale/crop · **勿加长** | 7.10–8.65 |
| 7 | `fx_blast.mp4` | `color=white:s=1080x1920:d=0.60` + 轻 `noise` + 可选 `rotate` 微震；或从黑 0.05→白 0.25→白持 0.20→淡出 0.10 | 8.65–9.25 · **hit 9.20** |
| 8 | `s10.mp4` | `-ss 0.80 -t 4.00` S10 → scale/crop · 确认 12.80 附近旗高点在窗内 | 9.25–13.25 · **hit 12.80** |
| 9 | `k_end.mp4` | S10 `sseof` 抽末帧 → Ken Burns 1.75s + drawtext 署名 | 13.25–15.00 |

### concat 顺序

`k_cat → k_portrait → k_boat → s04 → s05 → s08 → fx_blast → s10 → k_end`

### 音频

```bash
# 主床已切好：
# $EDIT/bgm_primary_15s.wav  (= Determined Pursuit ss=14.4 t=15)
ffmpeg -i silent.mp4 -i $EDIT/bgm_primary_15s.wav -c:v copy -c:a aac -b:a 160k -shortest out.mp4
```

## P0 对照（Opus 主债 → ¥0 解法）

| P0 | 现象（v0.3.1） | v0.3.2 ¥0 解法 | 须开机？ |
| --- | --- | --- | --- |
| 门落跳切 | 门运动偏切镜跳、高潮不踩点 | 重定位 ss + 闪白/震屏强调触滩；对齐 drop 3.60 | 否（真修运动才须） |
| S08 步枪瞬消 | 冲锋段道具/持握异常 | **裁到异常前** + 爆破闪白盖切；不露出问题帧 | 否（真修持枪须开机） |
| BGM 无 build/drop | Horde War Drums 匀速 | 换 **Determined Pursuit** CC0；三锁点踩鼓 | 否 |

## 验收清单

- [ ] 成片时长 15.00±0.05s  
- [ ] 3.60 / 9.20 / 12.80 目检与鼓点对齐（±0.1s）  
- [ ] S08 出点无持枪瞬消/残肢帧  
- [ ] 闪白盖住 S08→S10 切点  
- [ ] 音频 credits 写 Emma_MA / CC0 / OGA URL  
- [ ] 大 mp4 / 大 wav **不入库**（可只文档）

ALIGN_OK v0.3.2 3.6/9.2/12.8
