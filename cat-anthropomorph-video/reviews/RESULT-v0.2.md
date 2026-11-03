# RESULT-v0.2 — 2026-10-26 Asia/Shanghai

## Winner
- **克隆003** `bb8c4f8e12-00c8bdac`（Chongqing A · 4090D）
- 母机025 `9b4c40bda6-dad38bb9`：全程 **shutdown**（disk kept）
- 未重启 race；未重跑 I2V/FLF（第三次接管续跑远端 orch）

## 成片
| 项 | 值 |
|---|---|
| 路径 | `outputs/v0.2-b0-01-2026-10-26/out/B0-01-normandy-v0.2.mp4` |
| 副本 | `outputs/v0.2-b0-01-2026-10-26/B0-01-normandy-v0.2.mp4` |
| 分辨率 | **1080×1920** · 30fps · H.264 |
| 时长 | **15.100s**（453 frames） |
| 音频 | AAC stereo 44.1kHz · BGM + SFX≥4 |
| 字幕 | drawtext（NotoSansCJK）：片头「上岸前 0.5 秒」/「1944-06-06」· 片尾「Normandy 1944 #AI」 |
| 刀数 | **13**（S01+flash+S02+S03+S04–S11+S12）≥10 |

## Motion / Upscale
| shot | source | UPS method |
|---|---|---|
| S04 | FLF2V | **spandrel-UltraSharp**（真超分） |
| S05 | I2V | **spandrel-UltraSharp** |
| S06 | I2V | **spandrel-UltraSharp** |
| S07 | I2V | **spandrel-UltraSharp** |
| S08 | I2V | **spandrel-UltraSharp** |
| S09 | I2V | **spandrel-UltraSharp** |
| S10 | FLF2V | **spandrel-UltraSharp** |
| S11 | I2V | **spandrel-UltraSharp** |

- accepted：`outputs/motion-v0.2-2026-10-26/accepted/S04–S11.mp4`（8/8）
- upscaled：`outputs/motion-v0.2-2026-10-26/upscaled/*_1080p.mp4`（8/8）
- **无 FFMPEG_UPSCALE 兜底**（完整包真超分齐）
- orch 标记：`ORCH_MOTION_DONE` @ `logs/orch.log`

## Looklock
- portrait / boat_ramp / battle @ 1024×1536 → `outputs/looklock-v0.2-2026-10-26/accepted/`

## 音频
- BGM：Horde War Drums by William Hector（CC0；自 v0.1f 复用）
- SFX（lavfi）：slam / splash / boom / flagwind（≥2）
- credits：`out/audio-credits.md`

## 花费 / 余额
- before：**54030** 分（~¥54.03）
- after power_off：**49780** 分（~¥49.78）
- 本轮花费：**4250** 分（≈**¥4.250**）
- 软顶 spent≤8500 / 地板 45000：**未破**
- 未充值、**未 release**

## 关机确认
- 克隆003：power_off → **shutdown**（disk kept）
- 母机025：已是 shutdown（API：当前实例已关机）
- 双机均为 shutdown 留盘

## QC
- `qc/assemble.txt`：ASSEMBLE_OK cuts=13 dur=15.100000
- `qc/ffprobe.json`：1080×1920 · aac present
- 无 `qc/degraded.txt`（无 Ken Burns 兜底 motion）
