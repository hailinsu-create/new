# 自建 Live2D 角色研究 · 总览

目标：搞清楚「自己画一个角色 → 做成 Live2D → 放到自己的网页/应用里跑」整条链路，以及哪一段必须用官方工具、哪一段可以自托管。

## 结论先说

Live2D 不是开源替代品能随便换的。角色制作靠 Cubism Editor，运行靠 Cubism SDK / Core。你可以自托管模型文件和自己的播放器网页，但 **Cubism Core 是专有库**，不能随便二次分发。

自建角色的可行路径是：

1. 画分层立绘（PSD）
2. 在 Cubism Editor 里网格化、做变形器、绑参数、加物理与动作
3. 导出嵌入用数据包（`moc3` + `model3.json` + 贴图等）
4. 用 Web / Unity / 原生 SDK 加载
5. 模型资源放在自己的服务器或仓库；Core 按许可本地引入

本仓库提供：

- `docs/`：流程、授权、文件结构、自托管要点
- Web 研究台：用 PixiJS + `pixi-live2d-display` 验证模型能否加载
- `npm run check-model`：检查导出包是否缺关键文件

## 技术栈选型（本项目）

| 层 | 选择 | 原因 |
| --- | --- | --- |
| 编辑器 | Cubism Editor（官方） | 几乎是行业默认；免费版可学习，商用看规模 |
| 运行时 Core | Cubism Core for Web | 解析 `moc3` 必需 |
| 渲染胶水 | pixi-live2d-display（Cubism4） | 比直接啃官方 Framework 样例更快验证 |
| 渲染器 | PixiJS 6 | 与上述库版本匹配 |
| 本地服务 | Vite | 方便挂本地 `/models` |

官方 CubismWebFramework + CubismWebSamples 更「正统」，适合产品化。研究阶段用 Pixi 插件足够。

## 仓库地图

```text
docs/                 研究笔记
models/               放你自己的导出模型（local/ 默认 gitignore）
public/               静态资源；Cubism Core 下载到这里但不提交
scripts/              fetch-core / check-model
src/                  研究台前端
```

## 授权红线（务必先读）

- Cubism Editor / SDK / Core 受 Live2D 专有软件许可约束
- 官方 Sample 模型另有《免费素材许可协议》与样例数据使用条款
- 个人或年营业额低于门槛的小规模主体，对部分官方原创样例角色可用范围更宽；中大型企业不行
- **不要把 `live2dcubismcore.min.js` 推进公开仓库当「可随便复制的依赖」**
- 自建角色的画作版权归你；若外包建模，合同里写清源文件与二次修改权

细节见 [05-license-and-compliance.md](./05-license-and-compliance.md)。

## 建议阅读顺序

1. [02-creation-pipeline.md](./02-creation-pipeline.md) 怎么从插画做出模型
2. [03-runtime-package.md](./03-runtime-package.md) 导出包里每个文件干什么
3. [04-web-selfhost.md](./04-web-selfhost.md) 网页怎么自托管
4. [06-research-log.md](./06-research-log.md) 本仓库验证过的结论与坑
