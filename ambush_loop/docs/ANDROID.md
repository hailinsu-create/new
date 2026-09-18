# Android 安装说明（Ambush Loop）

本游戏的**目标机是安卓手机**。云端桌面只是开发预览，不能代替真机。玩法是搜刮埋伏、多波警报、打扫继承，不是锁死观战。

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
# 按版本命名的朋友包（可进仓）：
# cp build/android/AmbushLoop-debug.apk dist/AmbushLoop-v0.6.0-overhaul.apk
```

当前试玩包：`dist/AmbushLoop-v0.6.0-overhaul.apk`（`versionName` 0.6.0 / `versionCode` 49）。不要装 GitHub `ambush-loop-playtest-0.2.0` 的同名 `AmbushLoop-playtest.apk`。

## 本机导出 APK

1. 用 Godot 4.7.2 打开 `ambush_loop/`
2. **Editor → Manage Export Templates** 安装 4.7.2
3. **Project → Export → Android APK**
4. 若提示 Gradle：本预设默认 **不使用 Gradle**（`use_gradle_build=false`），用模板直接出 APK，方便侧载
5. 导出到 `build/android/AmbushLoop.apk`

命令行：

```bash
godot --headless --path ambush_loop --export-debug "Android APK" build/android/AmbushLoop-debug.apk
# 按版本命名的朋友包（可进仓）：
# cp build/android/AmbushLoop-debug.apk dist/AmbushLoop-v0.6.0-overhaul.apk
```

非 Gradle 预设不要填 `min_sdk` 覆盖，否则导出会失败。Release 需要 release keystore。

## 装进手机

1. 手机打开「安装未知来源」/ 允许该文件管理器安装
2. 把 APK 拷到手机，点安装
3. **必须横屏**；竖着会按 16:9 留边，不旋转内容
4. 标题应显示 **v0.6.0 COMMANDOS/WW2**。院子里点底栏肖像选人，点地走路（短拖拖图、长按奔跑），靠近匣/岗哨出热区（贴身/侧面绕背会绕岗身画完整虚线，至少 4 格到背后，不是 2 格残段）。未选中肖像点右上角 **跟** 跟上（领队边走跟班连续走；跟上格偏侧后会收到领队正后方，多人左右错开仍偏后；西巷跟上第一名跟班沿队形再推出到 (6,6)（不贴西墙、不叠在领队对角口袋里），第二名错开到 (5,16)（span 6，西巷跟上绕路 ≤6、不穿西墙），三人观察环约 1.0、人影约 1.0、观察环沿队形/向院内错开收小（不贴西墙、不把 280px 环再推 154px 进院子）、黄锥填色变淡，镜头在三人+黄锥聚在一起时保持约 1.0 并用平移/裁切跟住（院子不是邮票）；领队只拧射界时跟上格随连续朝向换格，点一次或按住简配底栏 **↺ / ↻**（15°，也可在两键上左右滑；窄屏匍匐/背包叠成两行，拧键靠右拇指）落点与跟班身体都绕槽位环走，不等到约 90°，松手后身体留在环上半格、不立刻弹回离散站位，圆弧绕复杂箱群贴墙段顶成弓（含剩余 1 段）、南走廊远侧弓帽约 20px、整段收在 y≤13（含中段 x≈21）、少绕东出、钳在可行走格上不穿箱；停在黄锥外、不贴锥沿；锥东领队时西巷跟班短绕 2–3 格，不傻等）。点肖像身体/名字/血条/枪印/编号选人，点角标才跟上（角标略抬高，不吃枪印和编号）。脚下无「射界」小字。点队友身体不会抢走选中。匍匐躲黄锥，点 **需枪** 拉警报（警报中自动丢雷）。匣上枪名默认隐藏。

## 触控对照

手机默认是 **简配夜袭**（`docs/TOUCH_UX_OPTIONS.md` 已落地）：常驻三肖像 + 叠起来的匍匐/背包 + ↺ + ↻ + 警报。世界动词是热区，不是 14 个底栏键。桌面键鼠仍是完整 C/Q/W/Z。按住 ↺/↻ 或在两键上左右滑连拧射界。

| 手指 | 键盘时代 |
| --- | --- |
| 点底栏肖像 | 1 / 2 / 3 |
| 点地走；短拖拖图；长按空地跑 | 左键；中键拖；双击跑 |
| 靠近匣 / 岗哨 / 尸 / 掩体上的大热区；背面出绕背 | E 开匣、Q 割喉、W 口哨、H 拖尸、点掩体 |
| 未选中肖像点「跟」跟上 | （桌面切 1/2/3，不必跟上） |
| 长按肖像 → 技能轮 | Q/W/Z 空地技能（望远镜、埋雷、诱饵、包扎） |
| 底栏 匍匐 / 背包 / ↺ / ↻ / 需枪 | C / I / A·D / 空格 |
| 警报：暂停 / 倍速 / 中止（需再点确认） | P / ± / X |
| 系统返回 | Esc 菜单 |

没有实体键盘也能打完六关（院子 / 仓道 / 泵站 / 信号楼 / 油库 / 电台）。R 重开仍在设置里，且要确认。
