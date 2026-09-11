# 耳听笔记（WAV 探针，不是扬声器）

日期：2026-09-11  
谁听：本机无声卡（ALSA card 0 不存在，窗口 dump 也走 Dummy）。按规划 §7.4：**WAV 文件就是耳听闸门**。  
设备：`godot --headless -s res://scripts/sfx/wav_probe.gd` → `/tmp/ambush_cues`，必听 9 条拷到 `docs/eval_71ca4af/cues/`。  
方法：读 PCM peak/rms/时长 + 180Hz 一阶低/高能量比 + 过零率 + 瞬态计数。Dummy `play()` 仍早退。

探针：`PROBE_OK n=31`，`docs/eval_71ca4af/wav_probe.log`。冒烟 `SMOKE_OK_SFX_BODY fire=0.3 tension=0.38 echo=0.29`。

## 必听

| 听什么 | PCM | 判定 |
|---|---|---|
| `fire` vs `ui` | fire peak 0.297 / 0.096s / lo 5.7%；ui peak 0.119 / 0.040s | **过。** 枪声比 UI 高 2.49×（门限 1.15×），更短的噪声体，不是同一声 beep |
| `fire_mg` | peak 0.325 / 0.26s / **3** 个瞬态 | **过。** 三连，不是一组长鸣 |
| `tension` | peak 0.399 / 0.76s / lo 62% / zcr 1370 | **过。** 低频鼓胀，≥0.18 |
| `echo_ping` | peak 0.280 / 0.84s / lo 4% / zcr 3332 | **过。** 高频载波+尾，和枪声/tension 不同类，≥0.10 |
| `leak` vs `fail` | leak 0.69s **4** 个脚步瞬态 lo 43%；fail 0.40s 13 击 lo 58% 洗 | **过。** 漏网是脚步+嘶，失败是下沉洗，不是同一把号 |
| `ambient_depot` vs `ambient_radio` | depot lo **80.5%**；radio lo **3.3%** zcr 3576 | **过。** 柴油低频 vs 载波/摩斯，不是同一床换音量 |

六夜 stinger `night_enter` peak 0.10 / 0.20s，不炸。WATCHING 床 `set_watch_bed` 再让 4dB，枪声仍比 UI 高。

## 不做

真 VO、外部 wav 管线、`AudioStreamGenerator`。本机没有喇叭，所以没有「笔记本外放 60cm」那一行——规划允许 WAV 导出笔记。

**P1 耳听闸门：过（PCM）。** 商店页听感仍是合成音。
