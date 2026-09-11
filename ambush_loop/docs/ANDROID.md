# Android 安装说明（Ambush Loop）

本游戏的**目标机是安卓手机**。云端桌面只是开发预览，不能代替真机。

非 Gradle 导出不能改 `min_sdk` 字段（模板自带 24）。侧载用 **debug 签名 APK** 即可；release 还要单独的 release keystore。

## 现在仓库里有什么

- `export_presets.cfg` 预设 **Android APK**
- 包名 `com.ambushloop.game`
- 横屏锁定、ETC2/ASTC、`custom_features=mobile`
- 触控 HUD（Android / 触摸屏自动出现；桌面可在设置里打开「触控底栏」）
- 手机渲染走 **GL Compatibility**；系统返回键打开菜单而不是杀进程

## 现在还没有什么

云端虚机**看不到插在你电脑上的手机 USB**（`adb devices` 为空），所以不能替你点安装。可以在这台机器打出 APK，你拷到手机上点安装。

Release 导出需要 release keystore；日常侧载用 debug 签名：

```bash
godot --headless --path ambush_loop --export-debug "Android APK" build/android/AmbushLoop-debug.apk
# 朋友包副本（可进仓）：
# cp build/android/AmbushLoop-debug.apk dist/AmbushLoop-playtest.apk
```

## 本机导出 APK

1. 用 Godot 4.7.2 打开 `ambush_loop/`
2. **Editor → Manage Export Templates** 安装 4.7.2
3. **Project → Export → Android APK**
4. 若提示 Gradle：本预设默认 **不使用 Gradle**（`use_gradle_build=false`），用模板直接出 APK，方便侧载
5. 导出到 `build/android/AmbushLoop.apk`

命令行：

```bash
godot --headless --path ambush_loop --export-debug "Android APK" build/android/AmbushLoop-debug.apk
# 朋友包副本（可进仓）：
# cp build/android/AmbushLoop-debug.apk dist/AmbushLoop-playtest.apk
```

非 Gradle 预设不要填 `min_sdk` 覆盖，否则导出会失败。Release 需要 release keystore。

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

没有实体键盘也能打完六关（院子 / 仓道 / 泵站 / 信号楼 / 油库 / 电台）。R 重开仍在设置里，且要确认。
