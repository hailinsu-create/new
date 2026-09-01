# 你必须亲自办理的事项

我无法代替你登录 Google、付款或点「发布」。下面按顺序做即可。预计在开发者账号开通后，填表+上传大约一两个小时。

## 1. 注册 Google Play 开发者账号

1. 打开 https://play.google.com/console/signup
2. 支付 **$25 一次性** 注册费（个人账号即可）
3. 完成身份验证（可能要几天）

没有这一步，后面所有 Console 操作都做不了。

## 2. 启用 GitHub Pages（隐私政策 URL）

Play 必须填一个**不登录也能打开**的隐私政策网页。

仓库 Settings → Pages：

- Source: **Deploy from a branch**
- Branch: **`main`**（或当前发布分支）
- Folder: **`/docs`**

保存后打开：

- 隐私政策：`https://hailinsu-create.github.io/new/privacy.html`
- 使用条款：`https://hailinsu-create.github.io/new/terms.html`

若暂时不启用 Pages，可用过渡 URL（公开仓库即可）：

`https://github.com/hailinsu-create/new/blob/cursor/phone-roast-small-window-b0b5/docs/privacy.html`

合并到 `main` 后把 Console 里的 URL 改成 GitHub Pages 地址。

## 3. 保管上传签名密钥

构建 AAB 用的上传密钥在 Cursor 产物里（**不要提交到 GitHub**）：

- `pangchuang-upload.jks`
- `pangchuang-upload-keystore.txt`（密码）

请立刻下载到你自己的密码管理器 / 加密盘。丢失后除非已开通 Play App Signing，否则无法更新应用。

若你更想自己生成密钥：

```bash
cd android
./scripts/generate-upload-keystore.sh
./gradlew :app:bundleRelease
```

## 4. 在 Play Console 创建应用

1. 创建应用
   - 默认语言：**中文（简体）**
   - 名称：**旁窗**
   - 类型：**应用**
   - 免费/付费：**免费**（内购置 $0.99，应用本身必须免费）
2. 勾选隐私政策、美国出口法规等声明

## 5. 创建内购商品

Monetize → In-app products → Create product

| 字段 | 填这个 |
|------|--------|
| Product ID | `full_unlock` |
| Name | 完整陪伴解锁 |
| Description | 永久解锁真屏陪伴。演示模式始终免费。视觉 API 费用需自行承担。 |
| Default price | **USD 0.99** |
| Status | Active |

License testing：Settings → License testing，把你的 Gmail 加进去，内部测试购买不扣费。

## 6. 上传 AAB 到内部测试

1. 打开 **App signing**：第一次上传时选择由 Google 管理应用签名密钥（推荐）
2. Testing → Internal testing → 创建版本
3. 上传 `pangchuang-0.7.0.aab`（见 Cursor 产物或本地 `bundleRelease` 输出）
4. 把你的 Google 账号加为测试员，用测试轨道链接安装（**不要用 GitHub debug APK 测购买**）

## 7. 按填表包复制粘贴

全部现成答案在：

- 商店文案：`docs/play/listing.md`
- Data safety：`docs/play/data-safety.md`
- 内容分级：`docs/play/content-rating.md`
- 权限声明：`docs/play/permission-declarations.md`
- 商店图标 / 宣传图：`docs/play/assets/`

最少上传：

- 高清图标 `play_icon_512.png`
- 特色图片 `feature_graphic_1024x500.png`
- 至少 2 张手机截图（`docs/play/assets/screenshot_*.png`，真机更佳）

## 8. 你必须拍的两段短视频（真机）

Play 对悬浮窗 + 录屏几乎一定会要视频：

1. **屏幕录制用途**：从打开旁窗 → 同意披露 → 系统录屏授权 → 小旁出现在别的 App 上 → 锁屏暂停。
2. **悬浮窗用途**：小旁浮在微信/浏览器上说话，点通知回到设置。

镜头脚本见 `docs/play/permission-declarations.md`。用手机自带录屏即可，上传到 Console 的权限声明处。

## 9. 你必须自己确认的法律项

- **Live2D 虹色 Mao 样例**：确认你的主体规模符合 [Live2D 免费素材许可](https://www.live2d.com/eula/live2d-free-material-license-agreement_en.html)。若你是较大商业主体，需要换成自有/授权模型后再上架。
- 商店「目标年龄」建议选 **18+**（可能截取任意屏幕内容）。

## 10. 提交审核

内部测试通过购买/恢复之后：

1. 把内部测试版本提升到 **封闭测试** 或直接 **生产**（新个人开发者可能被要求先封闭测试 14 天）
2. Dashboard 里把所有红色错误消掉
3. 点 **Send for review**

---

做完第 1、2 步（账号 + Pages）后把结果发我，我可以继续帮你对 Console 报错逐条改代码或文案。
