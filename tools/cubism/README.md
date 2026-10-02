# Cubism Editor（本机 Wine 非官方安装）

官方只提供 Windows / macOS。本仓库在 Linux 云环境用 Wine 装了 **Cubism Editor 5.3.03**，路径：

```text
tools/cubism/wineprefix/drive_c/Live2D_Cubism/
```

## 启动

```bash
./tools/cubism/launch-editor.sh
```

重新安装：

```bash
./tools/cubism/install-cubism.sh
```

## 限制

- **非官方**：Live2D 不保证 Linux/Wine 可用；变形时可能卡顿
- **许可证**：首次启动要联网激活（免费版 / 试用 / PRO）
- **GPU**：需要 OpenGL 3.3+；云虚拟机可能只有软渲染，界面能开但建模体验差
- **大文件**：`wineprefix/` 与安装包不进 git（见 `.gitignore`）

## 和墨汐的关系

装好 Editor 后，按 `characters/moxi/cubism/BINDING_CHECKLIST.md` 拆 PSD、绑参数、导出到 `public/models/moxi/`。

## 本环境状态（已验证）

- Wine 9 + Cubism Editor **5.3.03** 已安装到 `wineprefix`
- 可启动，窗口标题含 `[ Unregistered ]`，需按许可选择免费版/试用
- 安装包与 wineprefix **不进 git**；仓库只保留启动脚本与说明
