# Ambush Loop M0 基线与验收记录

日期：2026-09-27。基线：PR #64 `cursor/ambush-play-r44-0641` 的 `c87aee4b587954e4102e1c77758178b0f79a17ad`。工程：Godot 4.7.2，`ambush_loop/project.godot` v0.6.28；Android 包 `com.ambushloop.game`、versionName 0.6.28、versionCode 77、targetSdk 36。目标仍是横屏六夜，不迁回旧 Codex 纵屏三关。

## M0 当前验收

| 门 | 结果 | 证据 / 限制 |
| --- | --- | --- |
| 远端与版本对齐 | 通过 | 本工作分支从远端 PR #64 的 `c87aee4` 创建；未覆盖主分支。 |
| 测试存储隔离 | 通过 | `run_isolated_test.ps1/.sh` 在 Godot 启动前设置独立 OS 用户目录，所有会清档的 SceneTree 入口先执行 `test_storage_guard.gd`；缺参数退出 91。Windows 模拟玩家进度和设置哨兵在正常退出、预期断言失败退出 42、强制终止三种路径中 SHA-256 不变。 |
| 工程导入/完整冒烟 | 通过 | Godot 导入退出 0；隔离主冒烟退出 0，含 `SMOKE_OK_RAID_LOOP`、`SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio`、`SMOKE_SLICE_COMPLETE`，输出 `PLAYER_DATA_UNCHANGED=1`。修复后复跑输出 `SMOKE_OK_ANDROID_BACK_DEBOUNCE` 且到达 `SMOKE_SLICE_COMPLETE`；后一次终端会话已结束，但退出码没有被会话接口保留，不能写成已核到 0。 |
| Android 导出 | 通过，工具链有警告 | Godot 4.7.2 匹配导出模板，JDK 17.0.20.1，Android SDK build-tools 34.0.0 / platform android-34。目标 SDK 36，导出时 Godot 警告回退使用 34.0.0，但已成功生成并验证调试 APK。正式发布前升级/重新验证 SDK 工具链。 |
| 真机最小输入 | 首版通过，修复包待复验 | AAP-AN00 / Android 16 / arm64-v8a：首版调试包安装成功，冷启动、标题→任务选择→院子→三页教学→触控“强拉警报”均有截图。发现系统 Back 在此设备无明显响应；Esc 能打开菜单。已针对 Godot 4.7.2/targetSdk 36 的双重通知加入 200ms 去重并补自动断言。两次 `adb install -r` 更新均使设备 ADB shell 卡住，无手机确认弹窗；不能声称修复包已上机。 |
| 陌生人首局 | 未完成 | 需要一位此前未读攻略的人按 M0 观察卡点；不能以开发者自动点击替代。 |

本次仓库改动只针对测试安全、环境入口、Android 返回键去重与证据。`build/` 下的 APK、测试日志、截图为本机证据，不作为源码提交；玩家真实存档只读哈希检查，从未清空或覆盖。

## 工具链与复现

- Godot 标准版：`4.7.2.stable.official.ed1daf0bf`。Windows 引擎压缩包 SHA-256：`731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953`。
- 官方 export templates 4.7.2 压缩包 SHA-256：`F298490B8D44D934BE425A5A65A51BF15F422428B229A06A6E11D9FFEA248011`，本机仅安装 Android debug/release 模板与 version.txt。
- JDK 17.0.20.1；ADB 1.0.41（platform-tools 37.0.1）；现有 SDK build-tools 34.0.0、platform android-34。`scripts/check_m0_env.ps1` 可重复输出这些版本和当前设备状态。
- 从仓库根运行：`pwsh -File ambush_loop/scripts/run_isolated_test.ps1 -GodotExe <Godot 控制台程序绝对路径>`；哨兵：`pwsh -File ambush_loop/scripts/verify_storage_isolation.ps1 -GodotExe <同一路径>`。不要直跑会调用 `_wipe_save` 的脚本。
- Windows 完整冒烟日志：`ambush_loop/build/ambush_test_runs/f89c09a9f5b14f168b538102b5fc64cb/run.log`；修复后复跑日志：`ambush_loop/build/ambush_test_runs/11cbf9501f5845c4a33e8fc5221a689c/run.log`。
- 本机最终调试包：`ambush_loop/build/android/AmbushLoop-M0.apk`，38,675,390 字节，SHA-256 `B4013A1B49E31D0B744602EE8CF467826C7941745DA3D48C4A06B127CD454F48`；`apksigner verify` 成功，v2/v3 签名有效。首次上机的旧包 SHA-256 为 `A921A7276401BC5616DF86C74D0F2D77D37CC3AE95DD6468C621A6FE24BA88C3`。调试签名不等同正式发布签名。

## 旧 Codex 内容差异审计

旧内容来源：`422f48d Add portrait mobile vertical slice foundation`，已在 PR #64 的合并历史中保留；能力按当前六夜横屏工程逐项判断。

| 能力 | 当前状态 / 入口 | 处理 |
| --- | --- | --- |
| 触控底栏、按钮分流、取消/拖动 | 主线已有 `scripts/touch_hud.gd`、`main.gd::_handle_touch_gestures`，主冒烟有触控边界断言。 | 主线已覆盖；继续真机验证多指与误触，不复制旧触控布局。 |
| 安全区 | `main.gd::_safe_area_pad` 与 `touch_hud.gd::_apply_safe_area` 已存在。 | 主线已有适配；旧纵屏测试不直接照搬，M2 增加横屏异形屏截图边界。 |
| Android 返回/后台 | `game_settings.gd::_notification`、`main.gd::handle_android_back/handle_app_focus_out` 已有。M0 在 Android 16 发现双返回通知使菜单抵消，并加去重。 | 待修复包真机回归；后台恢复仍需设备验证。 |
| 1×/2× 与暂停 | 当前 `main.gd`、`touch_hud.gd`、`sim` 中有切换与冒烟覆盖。 | 主线已覆盖；M2 压力与真实触控复验。 |
| 原子保存/损坏恢复 | 当前 `game_settings.gd` 和 `main.gd` 直接 `ConfigFile.save`；旧 `save_store.gd` 有临时文件重命名、版本化和异常回退，但旧状态结构针对旧三关。 | 待 M2 按六夜 schema 重设计并迁移测试；不得直接覆盖玩家进度格式。 |
| 旧前端、生命周期、持久化、性能测试 | `422f48d` 的多份独立测试依赖旧纵屏场景；当前主冒烟覆盖部分同类行为。 | 历史用例作清单，按现有六夜入口重写缺失边界，不直接执行会写默认 `user://` 的旧脚本。 |
| 旧纵屏主场景与三关进度 | 与本路线的横屏六夜定义冲突。 | 历史废弃，不整体合并。 |

流程约束：仓库 `AGENTS.md` 的 PaperRoute → ChatGPT web PLAN/REVIEW → ds4.1 WORK → Cursor 验证为目标流程；本地缺 Web 桥时按 fail-open 记录，不冒充已获 PLAN/REVIEW 批准。M0 本次只作可验证的基线与安全修复，后续 M1 按总计划逐轮推进。
本次在 Windows 本机运行网页版 GPT 桥接的 `status`，返回 `EDGE_CDP_UNAVAILABLE`，没有进入 ChatGPT 登录/授权阶段；所以 M0 的 PLAN/REVIEW 网页审核仍未完成，不能标为 approve。用户已表示愿意授权，待修复 Edge CDP 后继续。
