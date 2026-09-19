# 制作流程：从立绘到可驱动角色

自建 Live2D 角色，核心不是「找个开源引擎」，而是把一张（或一套）分层插画，变成参数可驱动的部件模型。

## 全流程

```text
设定 / 三视图
    ↓
分层绘制（PSD）
    ↓
导入 Cubism Editor → ArtMesh
    ↓
网格编辑 → 变形器层级 → 参数绑定
    ↓
物理 / 姿势 / 表情 / 动作
    ↓
纹理图集
    ↓
导出嵌入文件（moc3 包）
    ↓
Viewer / SDK / 本仓库研究台验证
```

## 1. 立绘拆分（决定后期痛不痛）

Cubism 导入的是 PSD。官方要求大致是：

- 格式 PSD
- 颜色模式 RGB
- 8bit/通道
- 建议 sRGB

拆分原则：

- 会独立动的东西单独一层：头发前/中/后、眉毛、上眼皮、下眼皮、眼球、高光、嘴（可再拆开合）、身体、衣领、袖子、飘带……
- 线稿和填色尽量合并成「一个部件一层」，避免带着未栅格化的剪贴蒙版/图层蒙版进 Editor
- 层名唯一且可读，后面参数绑定时会感谢自己
- 预留透视和遮挡：侧脸时头发、刘海、耳朵谁盖谁，拆分时就要想到

常见翻车：

- 整脸画在一层，后期只能「橡皮泥式」拉扯，表情脏
- 眼睛没拆高光/瞳孔，视线跟随假
- 头发块太大，物理一开就糊成一团

参考：[创建PSD的注意事项](https://docs.live2d.com/zh-CHS/cubism-editor-manual/precautions-for-psd-data/)

## 2. 建模（Cubism Editor）

导入后每层会变成 ArtMesh。默认网格很稀，要按形变需要加密。

推荐层级习惯：

1. 先做大范围 Warp Deformer（头、胸、腰）
2. 再做局部（刘海、脸颊、眉毛）
3. 旋转变形器处理眼球、小臂等绕轴运动
4. 参数从标准脸部套件开始：`Angle X/Y/Z`、`EyeL/R Open`、`EyeBall X/Y`、`Brow`、`Mouth Open/Form`、`Body Angle`……

参数不是越多越好。每个参数都要有关键形，还要处理组合（嘴张开时的形状变化）。先保证「转头 + 眨眼 + 张嘴 + 呼吸」能看，再加工装切换和特效。

## 3. 动作与表情

- **表情**：短参数快照，导出 `exp3.json`
- **动作**：Animator 时间轴，导出 `motion3.json`
- **物理**：头发、胸、饰品的摆动，导出 `physics3.json`
- **姿势**：服装/手臂切换可见性，导出 `pose3.json`

面向应用时，常用 Cubism Viewer (for OW) 整理 HitArea、表情列表，再写出完整的 `model3.json`。

## 4. 导出嵌入包

菜单路径（Cubism 现行版本措辞可能略有出入）：

`文件` → `导出嵌入文件` → `导出 moc3 文件`

勾选需要的物理、动作、表情等。一个干净目录大约长这样：

```text
MyCharacter/
  MyCharacter.model3.json
  MyCharacter.moc3
  MyCharacter.physics3.json
  MyCharacter.cdi3.json
  textures/
    texture_00.png
  motions/
    idle.motion3.json
    tap.motion3.json
  expressions/
    smile.exp3.json
```

路径尽量英文，避免某些加载器对 Unicode 路径不友好。

## 5. 自建 vs 外包 vs 买成品

| 方式 | 适合 | 代价 |
| --- | --- | --- |
| 自己学 Cubism | 要长期改、要懂结构 | 学习曲线陡，第一只角色很慢 |
| nizima / 约稿建模 | 有立绘没时间建模 | 钱；要合同锁定源文件 |
| 官方/市场成品 | 验证播放器、占位演示 | 角色不是你的；注意许可 |

「自建」在本仓库语境里优先指：立绘与模型源文件你可控，运行时你自己托管。

## 6. 最低可用目标（MVP 角色）

做研究或产品原型，第一版角色建议只保证：

- 正面半身
- 转头 XYZ 小范围
- 眨眼、视线
- 张嘴（后期可接唇形）
- 一条 idle 动作
- 一次点击反馈（hit body / head）

全身、多套服装、复杂物理留给第二轮。
