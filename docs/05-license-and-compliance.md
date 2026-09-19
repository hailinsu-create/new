# 授权与合规（研究摘要）

本文不是法律意见。上线前用官方文本核对，必要时问律师或 Live2D 商务。

## 你要分清的三坨东西

1. **编辑器与 SDK / Core**  
   Cubism Editor、Cubism Core 等：专有软件许可。个人开发通常可免费试，发布与营收规模可能触发付费或 Publication License。以 Live2D 现行条款为准。

2. **官方 Sample 模型**  
   Haru、Hiyori 等：另有 Free Material License + Sample Data Terms。个人/小规模主体对部分原创样例角色有商业创作空间；中大型企业不行。协作角色、外部授权角色条款更严。

3. **你自己的角色**  
   画作与模型源文件的版权由你的创作/合同决定。把模型放进自己的产品时，仍要满足 SDK 发布条件。

## 对本仓库的具体约束

- `npm run fetch-core` 拉下来的 `public/live2dcubismcore.min.js` **默认不提交**
- 远程 Haru 样例只用于验证播放器；不要把它当「你的品牌角色」上线
- 文档与代码是研究笔记；引用官方文档时保留出处
- 若你对外再分发本仓库，附上 Live2D 相关许可链接，并确保不含 Core 二进制

## 官方入口

- [Cubism SDK for Web](https://www.live2d.com/download/cubism-sdk/download-web/)
- [Free Material License Agreement](https://www.live2d.com/eula/live2d-free-material-license-agreement_en.html)
- [Sample Data Terms](https://www.live2d.com/en/learn/sample/model-terms/)
- [Proprietary Software License](https://www.live2d.com/eula/live2d-proprietary-software-license-agreement_en.html)
- [Open Software License](https://www.live2d.com/eula/live2d-open-software-license-agreement_en.html)

## 实操建议

- 研究、课设、内部原型：官方样例 + 本研究台够用
- 要上线自己的形象：自己的立绘 + 自己的 moc3 + 按营收情况处理 SDK 授权
- 外包建模：交付物写明 `.cmo3` 源文件、贴图 PSD、嵌入包、商用授权范围
