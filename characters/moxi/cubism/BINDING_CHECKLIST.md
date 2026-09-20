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

1. File → Open → `C:\moxi\moxi.psd`，选 Create new model from PSD。
2. FREE 没有 Automatic Mesh Generator。每个图层导入时是四顶点矩形即可，张嘴只改透明度，不用细网格。
3. 若网格被弄丢：选中 ArtMesh，Ctrl+E，Reset mesh，再 Ctrl+E 退出。
4. 没有 `ParamMouthOpenY` / `ParamEyeLOpen` 时，加默认参数模板（标准 ID）。

## 2. 张嘴

`mouth_open` 只绑 `ParamMouthOpenY`。关键形：0 → 不透明 0%，1 → 100%。默认值 0。

Editor 里绑当然最好。当前运行包用 `scripts/bind-mouth-keyforms.py` 在导出文件上补了同样的两帧，旁窗写 LipSync 参数就能张嘴。不要用 py-moc3 整文件重写。

## 3. 眨眼

`eye_left` 只绑 `ParamEyeLOpen`：0 = 0%，1 = 100%。
`eye_right` 只绑 `ParamEyeROpen`。
`body` 眼窝已填肤色。不要在嘴或眼上再绑 Angle（FREE 每层最多 2 个参数）。

## 4. 导出

1. Texture Atlas 用 2048，Auto Layout。FREE 经常导出一张全透明图，UV 是对的。
2. File → Export Embedded File → Export as MOC3（Ctrl+Alt+S）。
3. Export target 选 **For SDK 5.0 / Cubism5.0**。不要 5.2/5.3（moc3 v6）。
4. 备份到 `characters/moxi/cubism/moxi.cubism-export.moc3`，再：

```bash
python3 scripts/pack-moxi-atlas.py
python3 scripts/bind-mouth-keyforms.py
python3 scripts/merge-cubism-export.py
npm run check-model -- public/models/moxi
```

`pack-moxi-atlas.py` 按 UV 把七层 PNG 填进图集。`bind-mouth-keyforms.py` 只插入嘴的透明度关键形，画布仍是 1536×1024。不要改成 1×1，也不要用 py-moc3 `to_file()`（会丢掉 v5 尾部，网页 Core 直接 Unknown error）。

## 5. 不要做

- 不要把十种肖像网格表情画进 moc3。难过/生气先并到 talk。
- 不要精细物理、点击 hit area。
- 不要在这个仓库里给旁窗改识屏或 TTS。

## 6. 完成定义（这一版）

1. 研究台默认预设是墨汐 moc3
2. 播 Talk，嘴从图上张开
3. `public/models/moxi/character.json` 仍在，旁窗整夹复制
