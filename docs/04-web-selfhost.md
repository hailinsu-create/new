# Web 自托管

「自建」到最后一步，通常是：模型文件放在你控制的源上，网页或客户端去拉。

## 架构

```text
浏览器页面（本仓库 Vite 应用）
    │
    ├─ live2dcubismcore.min.js   ← 专有 Core（本地引入，不随公开源码分发）
    ├─ PixiJS + pixi-live2d-display
    └─ GET /models/你的角色/*.model3.json 及相对资源
```

静态托管即可。不需要专门的 Live2D 服务器。注意 CORS：模型域名和页面域名不同时，要允许跨域读 json/png。

## 本仓库怎么跑

```bash
npm install
npm run fetch-core    # 下载 Core 到 public/（已 gitignore）
npm run dev
```

浏览器打开研究台：

1. 用远程 Haru 样例验证播放器本身没坏
2. 把你的导出包放到 `models/local/`
3. 路径填 `/models/local/xxx.model3.json` 再加载

Vite 开发服务器会把项目根下的文件按约定提供；`models/` 需要能被访问。默认 Vite 只把 `public/` 映射到站点根。所以本地模型有两种放法：

**推荐 A**：放到 `public/models/你的角色/`

**推荐 B**：在 `vite.config.ts` 里加 `server.fs` + 中间件，或把 `models` 链到 `public/models`

本仓库采用 **A 的约定写在文档里**，并提供 `models/local/` 作为工作区占位；实际服务时请把模型同步到 `public/models/`，或直接在 `public/models` 开发。

为减少迷路，仓库里保留：

```text
models/README.md          说明
public/models/.gitkeep    给开发服务器用的真实挂载点
models/local/.gitkeep     你的工作副本（可 gitignore 内容）
```

研究台预设里的本地路径是 `/models/local/character.model3.json`，对应文件应位于：

`public/models/local/character.model3.json`

## 最小加载代码（概念）

```ts
import * as PIXI from "pixi.js";
import { Live2DModel } from "pixi-live2d-display/cubism4";

(window as any).PIXI = PIXI;

const app = new PIXI.Application({ view: canvas, backgroundAlpha: 0 });
const model = await Live2DModel.from("/models/local/character.model3.json");
app.stage.addChild(model);
```

页面需先加载 Cubism Core 脚本。

## 产品化时更稳的做法

1. 从 [Cubism SDK for Web](https://www.live2d.com/download/cubism-sdk/download-web/) 取得 Core 与 Framework
2. 以 CubismWebSamples 为骨架，而不是长期绑着社区 Pixi 插件
3. Core 按专有许可部署：可随你的应用分发，但别假装它是 MIT 依赖
4. 模型用自己的 CDN / 对象存储；版本号写进路径，方便回滚
5. 需要口型时，从音频 RMS/viseme 驱动 `Mouth Open` 参数（另开专题）

## 常见加载失败

| 现象 | 常因 |
| --- | --- |
| `Live2DCubismCore is not defined` | 没引入 Core，或脚本顺序错了 |
| 404 on png/moc | `model3.json` 相对路径不对，或漏传文件 |
| CORS error | 跨域没放行 |
| 模型极大/极小 | 没按画布做 scale；研究台会自动 fit |
| 有模型无动作 | 没导出 motion，或组名不匹配 |

## 和直播/桌面方案的关系

- **VTube Studio / nizima LIVE**：面向直播捕捉，模型仍是 moc3 包，只是宿主换了
- **自研网页伴侣 / 站内看板娘**：本仓库这条路
- **Unity 游戏**：换 Cubism SDK for Unity，模型包同类

自建角色的建模产物可以一套导出、多处消费，只要 SDK 版本对得上。
