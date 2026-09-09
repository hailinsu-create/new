# Android 安装说明（Ambush Loop）

本游戏的**目标机是安卓手机**。云端桌面只是开发预览，不能代替真机。

## 现在仓库里有什么

- `export_presets.cfg` 预设 **Android APK**
- 包名 `com.ambushloop.game`
- 横屏锁定、ETC2/ASTC、`custom_features=mobile`
- 触控 HUD（Android / 触摸屏自动出现；桌面可在设置里打开「触控底栏」）
- 手机渲染走 **GL Compatibility**；系统返回键打开菜单而不是杀进程

## 现在还没有什么

云端代理虚机**通常编不出可安装的 APK**：需要本机安装

1. Godot 4.7.2 **Android export templates**
2. JDK 17
3. Android SDK（API 与 `min_sdk=24` 对齐）
4. 调试/发布 keystore（预设已指向用户目录下的 debug keystore；首次导出可让编辑器生成）

没有上述工具时，在编辑器点 Export 会失败。这不是玩法缺关，是工具链缺件。

## 本机导出 APK

1. 用 Godot 4.7.2 打开 `ambush_loop/`
2. **Editor → Manage Export Templates** 安装 4.7.2
3. **Project → Export → Android APK**
4. 若提示 Gradle：本预设默认 **不使用 Gradle**（`use_gradle_build=false`），用模板直接出 APK，方便侧载
5. 导出到 `build/android/AmbushLoop.apk`

命令行：

```bash
godot --headless --path ambush_loop --export-release "Android APK" build/android/AmbushLoop.apk
```

## 装进手机

1. 手机打开「安装未知来源」/ 允许该文件管理器安装
2. 把 APK 拷到手机，点安装
3. **必须横屏**；竖着会按 16:9 留边，不旋转内容
4. 首次进入看教程：点选位 → 点兵种牌 → 拖或点 ↺↻ 设朝向 → 点 **警报**

## 触控对照

| 手指 | 键盘时代 |
| --- | --- |
| 点掩体格 | 左键 |
| 点兵种牌 | 1 / 2 / 3 |
| 点 ↺↻ 或拖选中格 | 右键 / A D |
| 底栏 警报 | 空格 |
| 底栏 中止 | X |
| 底栏 开火 / 弹包 / 绊索 / 门锁 | F / G / Tab / B |
| 底栏 暂停 / 倍速 / 静音 / 菜单 / 日志 | P / ± / M / Esc / 事件表 |

没有实体键盘也能打完四关。R 重开仍在设置里，且要确认。
