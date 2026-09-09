# Ambush Loop Android 首发清单

版本：0.1.0，version code 1，包名暂定 `com.hailinsu.ambushloop`。这份清单区分本地可以完成的项目和必须由开发者账号、Android SDK、签名密钥或设备完成的项目。

## 已落地

- 默认安卓竖屏，逻辑视口 720×1280，移动渲染器使用 Compatibility。
- 离线单机，无联网、广告和分析 SDK 的代码路径；最终 AAB 仍需做 Manifest/依赖审计。
- 主菜单、开始/继续/新游戏、设置、关于/隐私入口、新手教学、结算重试与跨关流程。
- 触控部署、射界、瞄准、绊索、弹包、开火模式、暂停、速度、门和日志。
- 版本化安全存档：关卡、轮回、幽灵情报、上轮计划、星级、失败次数和本地设置。
- `export_presets.cfg`：Android、AAB、ARM64、竖屏、API 36 目标配置草案。

## 上传前必须完成

- 安装与锁定 Godot Android export templates、JDK、Android SDK、build-tools、adb、apksigner。
- 生成 release AAB；用 Play App Signing 托管签名，上传密钥放在仓库外并单独备份。
- 用 `bundletool`/Play Console 检查 AAB、ARM64、依赖、Manifest、target API 36 和 16 KB page-size 兼容性。
- 在至少一台实体 Android 设备和一个模拟器完成冷启动、首次教学、三关、失败重试、返回键、锁屏/切后台、进程被杀、覆盖升级和全面屏安全区测试。
- 返回键需验证弹层优先关闭、观看中第一次暂停、第二次返回菜单且安全存档；切后台或布局刷新后重新点按不能被旧指针状态阻塞。
- 补齐真实支持邮箱、公开隐私政策 URL、应用图标/宣传图/截图、Data safety、广告声明、目标受众、内容分级和 Play 商店文案。
- 如果开发者账号是 2023-11-13 之后创建的个人账号，完成 Play 要求的封闭测试流程，再申请生产访问权限。

本地没有签名密钥，也不会把密钥写入仓库。当前版本不宣称已经生成 AAB、安装到 Android、完成 Play Console 审核或通过真人测试。
