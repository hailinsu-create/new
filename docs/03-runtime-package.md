# 运行时数据包：每个文件干什么

Cubism Editor 里的 `.cmo3` / `.can3` 是编辑源文件。真正给 SDK 用的是「嵌入用」导出包。

## 关键文件

### `*.model3.json`

入口清单。告诉运行时：moc 在哪、贴图有哪些、有哪些动作/表情/物理/姿势、HitArea 叫什么。

研究台和 `pixi-live2d-display` 都是先读这个文件，再按相对路径拉资源。

### `*.moc3`

模型本体（网格、变形、参数结构的二进制）。没有它就什么都画不出来。由 Cubism Core 解析。

### `textures/*.png`

纹理图集。导出时可能是一张或多张。`model3.json` 的 `FileReferences.Textures` 必须和真实文件对得上。

### `*.physics3.json`（可选）

物理演算。头发随角度摆动主要靠它。没有也能显示静态/纯关键帧模型。

### `*.pose3.json`（可选）

部件显隐与姿势切换，比如左右手互斥、脱外套。

### `motions/*.motion3.json`（可选）

时间轴动作。常见分组名：`Idle`、`TapBody`、`FlickHead`。播放时按「组名」点名。

### `expressions/*.exp3.json`（可选）

表情。通常是一组参数目标值，可与动作叠加。

### `*.cdi3.json`（可选）

显示辅助信息（参数/部件显示名等），对调试友好，运行时不一定需要。

## `model3.json` 里要盯的字段

```json
{
  "Version": 3,
  "FileReferences": {
    "Moc": "Hero.moc3",
    "Textures": ["textures/texture_00.png"],
    "Physics": "Hero.physics3.json",
    "Pose": "Hero.pose3.json",
    "Expressions": [{ "Name": "smile", "File": "expressions/smile.exp3.json" }],
    "Motions": {
      "Idle": [{ "File": "motions/idle.motion3.json" }]
    }
  },
  "Groups": [],
  "HitAreas": [{ "Name": "Body", "Id": "HitAreaBody" }]
}
```

检查清单：

1. 所有相对路径相对 `model3.json` 所在目录可解析
2. 贴图数组顺序与导出一致
3. 动作组名和你在应用里 `model.motion("Idle")` 用的字符串一致
4. HitArea 在 Editor/Viewer 里真正建过，不只是随便写个名字

## 用本仓库检查

```bash
npm run check-model -- models/local
```

脚本会确认：

- 有没有 `model3.json` / `moc3` / png
- `FileReferences` 指向的 moc 与贴图是否存在

它不保证「好看」或「参数齐全」，只保证「文件层面能开始加载」。

## 版本兼容

- Cubism 3/4/5 导出的 `moc3` 大体走 Cubism 4 Core 这一路（向前兼容策略以官方文档为准）
- 编辑器大版本升级后，核对目标 SDK 发行说明
- 本研究台按 Cubism4 Core + `pixi-live2d-display/cubism4` 验证

官方兼容说明入口：[Cubism SDK Manual](https://docs.live2d.com/cubism-sdk-manual/top/)
