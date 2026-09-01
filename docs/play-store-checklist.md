# Google Play 上架清单（旁窗）

## 已完成（代码侧）

- [x] 默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`
- [x] 首次启动隐私同意（录屏 / API 发送说明）
- [x] 应用内隐私政策与开源许可页
- [x] 仓库 `docs/privacy-policy.md`（Console 填 URL 用）
- [x] 默认禁止明文 HTTP（仅 localhost / 127.0.0.1 / 模拟器 10.0.2.2）
- [x] Release 构建脚手架（签名读 `local.properties`）
- [x] **Google Play Billing**：一次性内购 `full_unlock`（约 $0.99），演示模式免费
- [x] 商店文案模板：`docs/play-store-listing.md`

## Play Console 配置（上架必做）

### 1. 应用定价

- **应用本身设为免费**（便于试用演示模式）
- **Monetize → Products → In-app products** 创建：
  - Product ID：`full_unlock`（必须与代码一致）
  - 类型：Managed product（一次性）
  - 价格：**$0.99 USD**（或按地区等价定价）
  - 状态：Active

### 2. 签名与 AAB

- [ ] Google Play 开发者账号（$25 一次性）
- [ ] 创建 **release** 签名 keystore，写入 `android/local.properties`：
  ```properties
  RELEASE_STORE_FILE=/path/to/pangchuang-release.jks
  RELEASE_STORE_PASSWORD=***
  RELEASE_KEY_ALIAS=pangchuang
  RELEASE_KEY_PASSWORD=***
  ```
- [ ] `./gradlew :app:bundleRelease` 生成 AAB
- [ ] Play Console → **App signing**：启用 Google Play App Signing

### 3. 测试轨道

- [ ] 内部测试轨道上传 AAB
- [ ] **License testers** 添加你的 Gmail（测试购买不扣费）
- [ ] 真机验证：演示免费 → 购买解锁 → 恢复购买

### 4. 政策与披露

- [ ] **Data safety**：声明「屏幕内容」「应用活动」发往用户配置的第三方 AI
- [ ] **敏感权限**：MediaProjection、悬浮窗、使用情况访问说明视频/文案
- [ ] 隐私政策 URL：`https://github.com/hailinsu-create/new/blob/main/docs/privacy-policy.md`
- [ ] **Financial features**：声明应用内购买（一次性解锁）
- [ ] 商店截图、简短说明（见 `docs/play-store-listing.md`）、内容分级问卷
- [ ] 确认 Mao 样例在您主体规模下符合 Live2D 商用条款，或替换为自有/授权角色

## 版本说明

| 版本 | 说明 |
|------|------|
| 0.6.0 | 加入 $0.99 一次性内购解锁真屏陪伴；Debug 包自动解锁便于侧载测试 |

## 建议下一版产品

- [ ] 后端代理 API Key（避免用户手填）
- [ ] EncryptedSharedPreferences 存 Key
- [ ] 崩溃上报（Firebase Crashlytics 等）
- [ ] 多机型 QA 矩阵
