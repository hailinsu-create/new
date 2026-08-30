# 研究日志

记录本仓库落地时验证过的判断，避免下次重踩。

## 已确认

1. **Web 验证不必一上来就啃 CubismWebFramework 全样例**  
   PixiJS 6 + `pixi-live2d-display/cubism4` 足够加载 `model3.json`、播动作、做指针跟随。产品阶段再迁官方 Framework 更稳。

2. **Core 必须单独引入**  
   没跑 `npm run fetch-core` 时，页面应明确报错，而不是 WebGL 白屏。

3. **远程样例适合测「播放器」**  
   jsDelivr 上的 Haru `model3.json` 可用来确认网络、Core、Pixi 链路。测「自建角色」必须换成本地导出包。  
   本仓库研究台已实测：Core 5.1.0 初始化成功，Haru 远程样例可渲染，视线跟随、点击 hit、动作组播放均正常。

4. **导出包完整性可脚本化**  
   `check-model` 只做文件与 JSON 引用检查。参数质量、网格穿透、物理爆炸仍要靠眼睛和 Editor。  
   对 `models/example-template` 会正确报缺 `moc3` / 贴图。

5. **第一视口的研究台把角色画布当主视觉**  
   控制台是交互容器；文档链接指向 `docs/`。避免做成参数仪表盘堆砌。

## 未决 / 下一刀

- [ ] 接麦克风或音频文件驱动口型（Mouth 参数）
- [ ] 本地 zip 一键导入（解压后写进 `public/models`）
- [ ] Cubism 5.x 新特性与当前插件的差异表
- [ ] 从官方 Samples 骨架迁一次「无 Pixi」对照实现，比性能与包体

## 工具备忘

| 工具 | 用途 |
| --- | --- |
| Cubism Editor | 建模与导出 |
| Cubism Viewer (for OW) | 整理 model3 / 表情 / HitArea |
| nizima | 素材与约稿市场 |
| VTube Studio | 直播宿主，不替代建模 |
| 本仓库研究台 | 浏览器加载验收 |

## 参考链接

- [CubismWebSamples](https://github.com/Live2D/CubismWebSamples)
- [CubismWebFramework](https://github.com/Live2D/CubismWebFramework)
- [pixi-live2d-display](https://github.com/guansss/pixi-live2d-display)
- [SDK Manual](https://docs.live2d.com/en/cubism-sdk-manual/cubism-sdk-for-web/)
- [PSD 注意事项](https://docs.live2d.com/zh-CHS/cubism-editor-manual/precautions-for-psd-data/)
