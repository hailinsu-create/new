# 片段状态与 G1/G2/G2m（短说明）

> 工具：`scripts/clip_status.py`、`scripts/noise_gate.py`、`scripts/subject_gate.py`、`scripts/motion_gate.py`。
> 口径：**渲染完成 ≠ 可用成片**。只有 `HUMAN_ACCEPTED` 才能对外写「可用成片」。

## 三态

| 状态 | 进入条件 | 可否对外称可用 |
| --- | --- | --- |
| `RENDER_DONE` | 渲染结束 | **否**（仅素材） |
| `AUTO_QC_PASS` | 已经是 RENDER_DONE，且 G1+G2+G2m **全部 PASS** | **否**（仍需人眼身份） |
| `HUMAN_ACCEPTED` | 已经是 AUTO_QC_PASS，且带 `--human` 人眼确认 | **是**（SFW 可用片段） |

状态账本写在 `<clip>.status.json`（或指定 `*.status.json`）；历史最多保留 50 条。

```bash
# 渲染结束
python3 scripts/clip_status.py set out.mp4 --state RENDER_DONE
# 三门禁全过（缺一不可）
python3 scripts/clip_status.py set out.mp4 --state AUTO_QC_PASS --g1 pass --g2 pass --g2m pass
# 人眼确认后才可用
python3 scripts/clip_status.py set out.mp4 --state HUMAN_ACCEPTED --g1 pass --g2 pass --g2m pass --human \
  --note "敬礼可见；身份/围巾/音轨已听检"
python3 scripts/clip_status.py show out.mp4
python3 scripts/clip_status.py verify out.mp4 --require HUMAN_ACCEPTED
python3 scripts/clip_status.py --self-test
```

`usable_clip=true` / `public_claim=usable_sfw_human_accepted` **只**出现在 `HUMAN_ACCEPTED`。

## 一键装配（`assemble_clip.py`）

`assemble_clip.py` 把上述三态串成一条命令：**RENDER_DONE → G1/G2/G2m →（全过）AUTO_QC_PASS → candidates.jsonl**；带 `--human` 才写 `HUMAN_ACCEPTED`。

```bash
# 自动 QC（G2 用显式首帧；不给 --start-image 时退回 frame0，较弱）
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png

# 人眼已确认身份/动作/音轨后
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --human \
  --note "身份/围巾/音轨已听检"

# 可选音轨：静音 / 程序化 128 BPM 节拍床 / 已授权 wav
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio bed
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio silent
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio wav --wav licensed.wav

# 端到端自检（fixtures + ffmpeg 合成短视频；不依赖真猫图）
python3 scripts/assemble_clip.py --self-test
```

- **三门禁全部跑完**才判；任一 FAIL：状态停在 `RENDER_DONE`，**不写** `candidates.jsonl`，exit 2。
- `candidates.jsonl` 默认放 `$OUTPUT_ROOT/candidates.jsonl`（未设则放视频同目录）；按 `clip` 绝对路径**覆盖同一行**，`--human` 后更新为 `HUMAN_ACCEPTED`，不重复追加。
- 音轨步骤先由 `stitch_audio.py` 生成目标 mp4，再对**最终文件**跑 G1/G2/G2m；状态与候选都指向最终文件。
- 详细命令/口径见 [`scripts/ASSEMBLE.md`](../scripts/ASSEMBLE.md)。

## 门禁

| 门 | 脚本 | 判据 | 失败 |
| --- | --- | --- | --- |
| **G1** 噪点 | `noise_gate.py` | 无参考熵/空间粗糙度/Laplacian；噪点/平场直方图 | exit 2 |
| **G2** 主体 | `subject_gate.py` | 相对 start_image/frame0 的灰度 SSIM 带 **0.25–0.92**；过低=噪点/身份崩，过高仅 WARN | exit 2（过低，或 `--enforce-center` 中心区过低） |
| **G2m** 动作 | `motion_gate.py` | 相对 frame0 的灰度 MAD max ≥ **11**（R1 正例 16.27；静帧基线≈3.6） | exit 2 |

G2 细节：

- 全参考指标：两侧先缩到 256 宽并按共同高度中心裁剪；错位/比例不一致会假失败。
- **SSIM 不替代人眼身份**；带宽故意放宽以降低假阳性。
- 中心区 SSIM 默认只报告；需要抓“边缘像、主体没了”时加 `--enforce-center --center-min-ssim 0.15`。
- 高相似（全部帧 > 0.92）只警告，交给 G2m 判静帧。
- PGM 参考与视频采样宽度不同时，按 256 宽最近邻缩放对齐（不改 SSIM 带宽）。
- 合成 fixtures：[`fixtures/qc/`](../fixtures/qc/)；校准记录见 [`SUBJECT-GATE-CALIBRATION.md`](SUBJECT-GATE-CALIBRATION.md)。

## 推荐顺序

```bash
python3 scripts/crop_check_i2v.py start.png
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --audio bed
# 人眼确认后
python3 scripts/assemble_clip.py out.mp4 --start-image start_480x832.png --human --note "已听检"
```

也可继续手工分步跑 G1/G2/G2m + `clip_status.py set`（三态规则不变）。未过 G2m 或 G2 明显崩身份：不得写「可用片段」。R2/R4 真机校准待开机授权。
