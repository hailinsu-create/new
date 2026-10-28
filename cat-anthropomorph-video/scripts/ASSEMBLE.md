# 一键装配 · `assemble_clip.py`（短说明）

> 一条命令串起 **RENDER_DONE → G1/G2/G2m → AUTO_QC_PASS → candidates.jsonl**。
> **AUTO_QC_PASS 仍不是可用成片**；只有带 `--human` 的 `HUMAN_ACCEPTED` 才可对外。
> 无 GPU、无联网；门禁失败不写候选。

## 命令

```bash
cd cat-anthropomorph-video

# 自动 QC；G2 参考首帧建议显式给
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png

# 人眼确认后才可对外
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --human \
  --note "身份/围巾/动作/音轨已听检"

# 可选音轨：静音 / 生成 128 BPM 节拍床 / 已授权 wav
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio silent
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio bed --bpm 128
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio wav --wav licensed.wav

# 端到端自检（fixtures/qc + ffmpeg 合成短视频）
python3 scripts/assemble_clip.py --self-test
```

## 行为

| 项 | 规则 |
| --- | --- |
| 状态入口 | 无账本 → 先写 `RENDER_DONE`；已有账本沿用，禁止回退 |
| 门禁 | G1 `noise_gate`、G2 `subject_gate`、G2m `motion_gate` 全部执行 |
| AUTO | 仅三门禁 **全 PASS** 才写 `AUTO_QC_PASS`；否则停在 `RENDER_DONE`，exit 2 |
| 候选 | 全过后写 `candidates.jsonl`；同一 `clip` 只保留一行，`--human` 后更新状态 |
| HUMAN | 只认 `--human`；写 `HUMAN_ACCEPTED` 后 `usable_clip=true` |
| G2 参考 | `--start-image` 优先；省略则用视频 frame0（较弱，不建议发布前省略） |
| 音频 | `stitch_audio.py` 先生成目标 mp4，再对最终文件跑三门禁；状态/候选指向最终文件 |
| 默认候选路径 | `$OUTPUT_ROOT/candidates.jsonl`，未设则视频同目录 `candidates.jsonl` |
| exit | `0` 成功；`1` 输入/音频/解码错误；`2` 门禁失败或状态规则冲突 |

`candidates.jsonl` 每行含：`clip`、`source_render`、`state`、`usable_clip`、`public_claim`、`gates`、`gate_exit_codes`、`g2_reference`、`audio`、`status_file`、`note`、时间戳。由 `assemble_clip.py` 维护，勿手工改成「可用」。

## 相关

- 三态与门禁：[`reviews/CLIP-STATUS.md`](../reviews/CLIP-STATUS.md)
- G2 校准：[`reviews/SUBJECT-GATE-CALIBRATION.md`](../reviews/SUBJECT-GATE-CALIBRATION.md)
- 有声/换轨：[`scripts/AUDIO-SWAP.md`](AUDIO-SWAP.md)
- 模板与机位：[`workflow/TEMPLATES.md`](../workflow/TEMPLATES.md)

## v0.1d · Opus A（¥0）

- 目标目录：本机 `outputs/v0.1d-b0-01-2026-10-25/`（二进制可不入库）。
- 成片层只收 **HUMAN_ACCEPTED**；作废含坏 R4 的 v0.1b-beatbed。
- 步骤与蒙太奇配方见 [`../reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](../reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md)；占位 [`../reviews/RESULT-v0.1d-2026-10-25.md`](../reviews/RESULT-v0.1d-2026-10-25.md)。
- **不开机**；B 须用户授权后再议。
