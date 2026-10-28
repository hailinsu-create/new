# 有声成片 / 换轨合规（15s 竖屏 · 短版）

> 工具：`python3 scripts/stitch_audio.py` 或一键装配 `scripts/assemble_clip.py`。
> 默认：**静音**母版，或**程序化 128 BPM 正弦滴答节拍床**（非歌曲、非盗版曲）。
> 15 秒不是侵权豁免；平台曲库跨平台/商用也可能侵权。参考 [`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](../reviews/COMMUNITY-OPTIMIZE-2026-10-25.md) 第 4 节。
> 未做真实版权审查的曲目，一律不上片；宁可 silent 或自制节拍床。

## 1) 15s 竖屏有声命令（推荐走装配）

```bash
cd cat-anthropomorph-video

# 静音母版（先卡画面；不带音轨）
python3 scripts/assemble_clip.py outputs/B0-01_15s_v0.mp4 \
  --start-image outputs/B0-01_start.png \
  --audio silent --audio-out outputs/B0-01_15s_silent.mp4

# 默认节拍床：128 BPM，与 beat sheet 对齐
python3 scripts/assemble_clip.py outputs/B0-01_15s_v0.mp4 \
  --start-image outputs/B0-01_start.png \
  --audio bed --bpm 128 --audio-out outputs/B0-01_15s_bed.mp4

# 已取得书面授权 / CC0 / 平台官方曲库导出的 wav（保留凭证）
python3 scripts/assemble_clip.py outputs/B0-01_15s_v0.mp4 \
  --start-image outputs/B0-01_start.png \
  --audio wav --wav licensed_128bpm.wav \
  --audio-out outputs/B0-01_15s_final.mp4
```

- `assemble_clip.py` 会先做音轨，再对最终 mp4 跑 G1/G2/G2m；全过才进 `candidates.jsonl`，`--human` 才是可用成片。
- 若画面已过 QC，只想换音轨：

```bash
# 保留原音轨
python3 scripts/stitch_audio.py clip.mp4 --audio-policy keep --out clip_keep.mp4
# 强制生成 128 BPM 节拍床（即使原片有音轨也替换）
python3 scripts/stitch_audio.py clip.mp4 --audio-policy bed --bpm 128 --out clip_bed.mp4
# 纯静音
python3 scripts/stitch_audio.py clip.mp4 --silent --out clip_silent.mp4
# 授权 wav；apad 不截断视频
python3 scripts/stitch_audio.py clip.mp4 --wav licensed.wav --out clip_final.mp4
# 只看命令不落盘
python3 scripts/stitch_audio.py clip.mp4 --out /tmp/out.mp4 --dry-run
```

## 2) 15s 竖屏硬检查

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,duration \
  -of default=nw=1 outputs/B0-01_15s_final.mp4
ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,channels,sample_rate,duration \
  -of default=nw=1 outputs/B0-01_15s_final.mp4
```

- 目标：**1080×1920 · 30fps · ≈15.0s**（±0.2s）；音频 AAC 192k，时长覆盖整片。
- 128 BPM / 32 拍 = 8 小节；强卡点参考 `3.75s 门落 / 7.97s 卧倒 / 10.78s 抬头`。
- 先静音母版卡画面，再换轨；换轨后复听，脚本已用 `apad` 防 `-shortest` 截断。
- 响度/削波可选用 `ffmpeg -af volumedetect` 自检；发布前保留检测日志。

## 3) 听检清单（发布前逐条打勾）

- [ ] 时长 15.0s ±0.2s；音轨没有被截断，也没有尾部静音拖长。
- [ ] 第一拍落在画面起点；3.75s / 7.97s / 10.78s 卡点可听出落点。
- [ ] 无爆音/削波/明显爆点；无人声盖过环境音（如用节拍床）。
- [ ] 左/右声道一致、无单边缺失；手机外放与耳机各听一遍。
- [ ] 音乐来源为**目标平台官方曲库**，或**书面授权 / CC0**；保留曲名、作者、获取日期、授权截图。
- [ ] **不跨平台**导出/搬运曲库音乐；不保存、不再分发平台缓存文件。
- [ ] 免版税 ≠ 免授权；公版作品 ≠ 公版录音（录音版权可能仍在）。
- [ ] 不用“15 秒所以没事”作理由；16 秒案例已被追责。
- [ ] 成片标注 AI 生成；音轨来源写入发布记录。

## 4) 自检

```bash
python3 scripts/stitch_audio.py --self-test   # 生成/混流/静音剥离
python3 scripts/assemble_clip.py --self-test  # 三态 + 候选 + 节拍床
ffprobe -v error -show_entries stream=codec_type -of csv=p=0 outputs/B0-01_15s_final.mp4
```

合规底线：**默认 silent 或自制节拍床；不塞盗版曲、不跨平台搬运**。无法证明授权的曲目直接弃用。

## v0.1d · Opus A 有声

- 临时轨：128 BPM 节拍床（`stitch_audio.py --audio-policy bed --bpm 128`），对齐 beat sheet。
- 发布曲库 / 书面授权仍为 P2；勿用含坏 R4 的旧 beatbed。
- 全流程见 [`../reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](../reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md)。
