# Cubism 绑定清单（墨汐）

旁窗不负责网格。这里把 PSD 变成能张嘴的 moc3。

Wine 启动：`./tools/cubism/launch-editor.sh`（首次选 FREE）。本机官方 Editor 也可以，打开同一份 PSD。

## 0. 生成 PSD

```bash
python3 scripts/build-cubism-layers.py
python3 scripts/build-moxi-psd.py
```

产出：`characters/moxi/cubism/import/moxi.psd`（gitignore）。Wine 下另有 `C:\moxi\moxi.psd`。

图层（底 → 顶）：`body` `hair_lock` `eye_left` `eye_right` `mouth_open` `hair_front` `tassel`。

## 1. 导入

1. File → Open → `C:\moxi\moxi.psd`
2. 每个图层会变成 ArtMesh。若还是整块矩形，选中后 Modeling → Automatic Mesh Generator，alpha 阈值约 20%，生成。
3. 对 7 个图层都做一遍。不要合并成一个网格。
4. Modeling → Parameter → 若没有 `ParamMouthOpenY` / `ParamEyeLOpen`，加默认参数模板（标准 ID，不要自造名字）。

## 2. 张嘴（必须）

选中 `mouth_open`。只绑 **一个** 参数：`ParamMouthOpenY`。

| 关键形 | 不透明度 |
| --- | --- |
| 0 | 0% |
| 1 | 100% |

默认值保持 0。闭嘴时看到 `body` 上的原嘴；开口时这层盖上去。

## 3. 眨眼（一起做，仍是 MVP）

`eye_left` → 只绑 `ParamEyeLOpen`：0 = 0%，1 = 100%。
`eye_right` → 只绑 `ParamEyeROpen`，同样。

`body` 眼窝已填肤色，眼睛层隐掉就是闭眼。不要在同一网格上再绑 Angle。

## 4. 导出

1. Edit Texture Atlas。2048 够用。自动摆盘，确认七块都在图集里。
2. File → Export Embedded File → Export as MOC3。快捷键 Ctrl+Alt+S。
3. **Export target 选 For SDK 5.0 / Cubism5.0**。不要用 5.2/5.3（moc3 v6，网页 Core 读不了）。
4. 导出到 `public/models/moxi/`，覆盖 `moxi.moc3` 和纹理。
5. 立刻跑：

```bash
python3 scripts/merge-cubism-export.py
npm run check-model -- public/models/moxi
```

merge 会把 Cubism 抹掉的 LipSync 组、Idle/Talk、idle/talk/smile/surprise 写回 `model3.json`。

## 5. 不要做

- 不要把十种肖像网格表情画进 moc3。现在只有平静 / 浅笑 / 吃惊三个 expression 文件；难过生气先并到 talk。
- 不要精细物理、点击 hit area。
- 不要在这个仓库里给旁窗改识屏或 TTS。

## 6. 完成定义（这一版）

1. 研究台默认预设是墨汐 moc3
2. 播 Talk 或把 `ParamMouthOpenY` 拉到 1，嘴从图上张开
3. `public/models/moxi/character.json` 仍在，旁窗整夹复制
