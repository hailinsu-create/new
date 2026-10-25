# 有声成片 / 换轨合规（短版）

> 工具：`python3 scripts/stitch_audio.py`。默认给**静音**成片，或生成**程序化 128 BPM 正弦滴答节拍床**（非歌曲、非盗版曲）。
> 15 秒不是侵权豁免；平台曲库跨平台/商用也可能侵权。参考 [`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](../reviews/COMMUNITY-OPTIMIZE-2026-10-25.md) 第 4 节。

## 1) 先出 silent 母版

```bash
# 输入静音 mp4；自动生成 128 BPM 节拍床并保留完整时长
python3 scripts/stitch_audio.py clip.mp4 --out clip_128bpm.mp4

# 纯静音（不上任何音轨）
python3 scripts/stitch_audio.py clip.mp4 --out clip_silent.mp4 --silent

# 已有授权 wav：替换音轨（视频流 copy，音频 AAC 192k，apad 不截断视频）
python3 scripts/stitch_audio.py clip.mp4 --wav licensed.wav --out clip_final.mp4

# 只看命令不落盘
python3 scripts/stitch_audio.py clip.mp4 --out /tmp/out.mp4 --dry-run
```

- 节拍床：128 BPM、1200 Hz 短滴答 + 55 Hz 低音重拍，`--gain` 默认 0.18；可用 `--bpm 128` 与 beat sheet 对齐。
- `--audio-policy auto`：有 wav → 替换；原片有音轨 → 保留；原片静音 → 生成节拍床。

## 2) 卡点

- beat sheet 固定 **128 BPM / 15s**（见 [`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`](../reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md)）。
- 先按 silent 母版卡画面，再换轨；换轨后复听，避免 `-shortest` 截断（脚本已用 `apad`）。

## 3) 换轨合规（发布前逐条打勾）

- [ ] 只使用**目标平台官方曲库**内的音乐，或已取得的**书面授权 / CC0** 录音。
- [ ] **不跨平台**导出/搬运曲库音乐；不保存、不再分发平台缓存文件。
- [ ] 免版税 ≠ 免授权；公版作品 ≠ 公版录音（录音版权可能仍在）。
- [ ] 保留授权截图/合同/CC0 来源链接，记录曲名、作者、获取日期。
- [ ] 不用“15 秒所以没事”作为理由；16 秒案例已被追责。
- [ ] 成片标注 AI 生成；音轨来源写入发布记录。

## 4) 自检

```bash
python3 scripts/stitch_audio.py --self-test   # 生成/混流/静音剥离
ffprobe -v error -show_entries stream=codec_type -of csv=p=0 clip_final.mp4
```

未做真实版权审查的曲目，一律不上片；宁可 silent 或自制节拍床。
