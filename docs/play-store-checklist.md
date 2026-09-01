# Google Play 上架清单（旁窗）

## 已完成（代码侧）

- [x] 默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`
- [x] 首次启动隐私同意（录屏 / API 发送说明）
- [x] 应用内隐私政策与开源许可页
- [x] 仓库 `docs/privacy-policy.md`（Console 填 URL 用）
- [x] 默认禁止明文 HTTP（仅 localhost / 127.0.0.1 / 模拟器 10.0.2.2）
- [x] Release 构建脚手架（签名读 `local.properties`）

## 上架前仍需人工完成

- [ ] Google Play 开发者账号
- [ ] 创建 **release** 签名 keystore，写入 `android/local.properties`：
  ```properties
  RELEASE_STORE_FILE=/path/to/pangchuang-release.jks
  RELEASE_STORE_PASSWORD=***
  RELEASE_KEY_ALIAS=pangchuang
  RELEASE_KEY_PASSWORD=***
  ```
- [ ] `./gradlew :app:bundleRelease` 生成 AAB
- [ ] Play Console → **Data safety**：声明「屏幕内容」「应用活动」发往用户配置的第三方 AI
- [ ] Play Console → **敏感权限**：MediaProjection、悬浮窗、使用情况访问说明视频/文案
- [ ] 隐私政策 URL 填：`https://github.com/hailinsu-create/new/blob/main/docs/privacy-policy.md`
- [ ] 商店截图、简短说明、内容分级问卷
- [ ] 确认 Mao 样例在您主体规模下符合 Live2D 商用条款，或替换为自有/授权角色

## 建议下一版产品

- [ ] 后端代理 API Key（避免用户手填）
- [ ] EncryptedSharedPreferences 存 Key
- [ ] 崩溃上报（Firebase Crashlytics 等）
- [ ] 多机型 QA 矩阵
