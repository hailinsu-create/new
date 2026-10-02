# PaperRoute 方法（builtbysketch / GPT-6 Astra）

来源：[Emm Tee @builtbysketch, 2026-09-12](https://x.com/builtbysketch/status/2098773631249854478)  
游戏：[paperroute.lol](https://www.paperroute.lol/) · [完整 devlog](https://www.paperroute.lol/devlog/) · 追踪：[DevClocked](https://devclocked.com)

本仓库是 Godot 游戏 **Ambush Loop**，不是 PaperRoute。这篇笔记只把那条 run book 落到本环境的工具/MCP 上，不改游戏内容。

## 方法论

核心主张：一次性 prompt 能出 demo，出不了能玩两遍的完整游戏。顺序比模型更重要。

1. **先写自己相信的 brief**  
   概念不来自模型。用自己的话写玩法，给 1 个最接近的参考（哪怕不能克隆），再给 2–3 张粗参考图。先力学，后美术。

2. **先可玩，再定画面**  
   第一晚只做浏览器可玩切片：确定性模拟、测试跟着写、每改一条操作就提交。大段美术方向会稀释力学。

3. **两条工作流分开**  
   - **Engine stream**：操作、物理、关卡、HUD。一句 prompt → 浏览器里看 → 一次 commit。  
   - **Look stream**：Blender Python **无头**建网格、分材质、导出 GLB。先独立 art study（剪影/道具），再进可玩世界。  
   房子难看时，不要在同一条对话里吵投掷物理。PaperRoute 明确写了：**Astra 不打开 Blender GUI，也不走 MCP**，只写 Python 让 Blender `--background` 跑。

4. **角色有脸就换工具**  
   房子/树/信箱：脚本化 Blender。人脸/角色：ChatGPT 概念图 → **Meshy** 出网格（约 $8）→ 代理减面、修衣服、绑定、对齐已有载具。同一管线复制到第二个角色会便宜很多。绑定做好了，资产才可复用。

5. **审查循环才是正业**  
   3D 靠渲染图审，不靠猜网格。每个检查点：正/侧/背 + clay turnaround；运行时姿态（转向、投掷、冲刺、摔倒）。指出某一帧的具体错误就是下一条 prompt。作者称 60–70% 的改善来自「代理自审 Render1→Render2」。

6. **留一天给 flourish，实验先开分支**  
   砸窗、雨天、终点滑板场各自 worktree/分支，测完再合。网站包装（报纸落地页/成绩单/排行）和游戏本体一样算成品。

7. **记时间和 token**  
   PaperRoute 口径（2026-07-01 → 09-12）：39h 覆盖（25.2 人 + 13.8 仅代理）、15.6 亿 token（其中 15.3 亿 cached）、API 价值 $2175、90 commits / 11 个有效日。80% 会话时间花在打磨，不是「从零搭引擎」。浏览器重做 4 天可玩 + 1 天上线。

**TLDR 顺序：** brief + 参考 → 力学可玩 + 测试 → 引擎/美术分对话 → Blender Python 可复现道具 → Meshy 做人脸角色 → 每改必出审查渲染 → 留一天 flourish → 上域名。

## 规则

- 不要 one-shot 完整游戏；那是 slop。Taste 和耐心仍是护城河。
- 先力学后美术；美术 brief 用描述性参考（他们用「日式夏日微风电影 + 手绘纹理」），不要丢潮流风格词。
- Engine 和 Look 分对话；一条 prompt 只改一件可验证的事，然后 commit。
- 资产必须可复现：每个房子/树/篱笆/信箱是脚本，不是一次性手搓文件。
- 角色需要脸时，停止用语言模型硬雕；走 Meshy，再减面/绑定/贴合。
- 用渲染图审 3D；指向具体帧，不写空泛「看起来不对」。
- 不确定的功能（镜头特写、天气）先独立分支，验证再合。
- 测试跟着写，后续美术才有回归网。
- 尽早放到浏览器/真机上一直可玩；不要卡在原生 iOS 灰盒（他们 7 月因此停了两个月）。
- 记录小时和 token；对未验证的事直说（他们承认手机持续 60fps 未证死，Meshy 骑手 88550 三角）。
- Blender MCP 能操作场景，但 **不会凭空雕出好看角色**。PaperRoute 主路径是无头 Python；MCP 是附加手，不是主路径。

## 技能 / 工具

| 用途 | 他们用的 | 本环境对应 |
| --- | --- | --- |
| 写代码 / 跑 Blender 脚本 | GPT-6 Astra + Codex（T3 自定义表单） | 本会话的 Grok CLI；无头 `blender` |
| 概念图 / 情绪板 | ChatGPT 图像 | 现有图像工具；Meshy 也可出图 |
| 道具/建筑网格 | Blender Python → GLB | Blender 5.2.2 LTS `--background` |
| 有脸角色 | Meshy image-to-3D | `meshy` CLI + Meshy MCP（需 API key） |
| 减面 / 绑定 / 贴合 | Astra 写 Blender 脚本 | 无头 bpy；可选 Blender MCP |
| 运行时 | Three.js 浏览器 | 本仓库是 **Godot 4.7.2** |
| 审图循环 | 捕获脚本 + turnaround | 自己写 capture；Blender 可出 clay |
| 实验隔离 | git worktree / 分支 / 子代理 | 同样适用 |
| 工时 token | DevClocked | 需账号，未装客户端 |
| 引擎 MCP | 他们没用 Blender MCP | 仍装了官方 Blender MCP + Godot MCP |

可执行技能：`.cursor/skills/paperroute-game-build/SKILL.md`（Grok 侧符号链接 `.grok/skills/paperroute-game-build`）。

## Ambush Loop 适配（Engine vs Look）

本仓库不是 PaperRoute。落到 Godot 夜袭时：

- **Engine**：一句 prompt 只改一件可玩的事。西巷跟镜头 / 人影 / 观察环 **缩放** / **世界偏移** / **填色裁切** 是三件事——0.5.38 把 zoom/body 拉回 1.0；0.5.39 只收院内环偏移；v0.6 填色 LOS 裁切+淡化（不把人缩回 0.16，不把镜头缩成邮票，不静默改 `kit_range`）。RAID 契约、kit compress、桌面轨、冒烟网必须绿。
- **Look**：无头 `blender-headless --python ArtSource/build_<asset>.py` → GLB + clay/shaded 接触纸。本游戏是 2D Godot：同一脚本再烘一张顶视/3/4 PNG 进院子。先 art study，再进可玩院子。有脸角色才走 Meshy（需 `MESHY_API_KEY`）。
- 验收：`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`；触控静帧 `godot --path ambush_loop -s res://scripts/eval_dump_touch_hud.gd`。指向某一帧，不写「看起来好一点」。
- 大改 brief：`.cursor/docs/AMBUSH_OVERHAUL_BRIEF.md`。

## 本机安装

见同目录 `INSTALL_REPORT.md`。
