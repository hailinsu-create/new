# 旁窗

手机投屏缩成桌面小窗，用开源视觉模型在旁边吐槽你在刷什么。

## 它做什么

- **小窗投屏**：手机画面嵌在圆角手机框里，始终可置顶、可拖拽
- **旁观吐槽**：画面变化或定时触发时，把一帧发给视觉模型，冒出一句短评论
- **无手机也能玩**：默认 `auto` 模式——没连 ADB 就走演示画面 + 本地段子

```
手机 --ADB screencap--> 旁窗小预览
                         |
                         +--> JPEG 帧 --> Qwen-VL / 任意 OpenAI 兼容视觉接口
                                           |
                                           v
                                      气泡吐槽
```

## 系统依赖（Linux）

Ubuntu/Debian 需要 Qt 相关库，可参考 `apt-packages.txt`：

```bash
sudo apt-get install -y $(grep -v '^#' apt-packages.txt | tr '\n' ' ')
```

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 可先不填 key，走演示吐槽
python -m pangchuang
```

### 接真机（Android）

1. 手机打开开发者选项 → USB 调试（或无线调试）
2. `adb devices` 能看到设备
3. `.env` 里设 `MODE=adb`（或保持 `auto`）
4. 再运行 `python -m pangchuang`

预览用 `adb screencap` 拉帧（约 2–5 fps），够小窗旁观；吐槽另有间隔，不需要 60fps。

若你更想要独立 scrcpy 小窗，也可以另开：

```bash
scrcpy --window-width=280 --window-height=560 --max-size=800 --max-fps=15
```

旁窗仍负责吐槽；两者可并存。

### 接开源视觉模型

任意 **OpenAI 兼容** 多模态接口均可，例如 SiliconFlow 上的 Qwen-VL，或本地 Ollama：

```env
VISION_BASE_URL=https://api.siliconflow.cn/v1
VISION_API_KEY=sk-...
VISION_MODEL=Qwen/Qwen2.5-VL-7B-Instruct
```

本地 Ollama 示例：

```env
VISION_BASE_URL=http://127.0.0.1:11434/v1
VISION_API_KEY=ollama
VISION_MODEL=qwen2.5vl:7b
MOCK_API=0
```

不填 `VISION_API_KEY` 时自动用本地段子，方便先调 UI。

## 配置

| 变量 | 含义 | 默认 |
|------|------|------|
| `MODE` | `auto` / `mock` / `adb` | `auto` |
| `PHONE_WIDTH` | 小窗手机框宽度（px） | `240` |
| `PREVIEW_FPS` | 预览帧率 | `3` |
| `ROAST_INTERVAL_SEC` | 吐槽检查间隔 | `18` |
| `ALWAYS_ON_TOP` | 是否置顶 | `1` |
| `ADB_SERIAL` | 多设备时指定序列号 | 空 |

## 项目结构

```
pangchuang/
  config.py    # 环境配置
  stream.py    # mock / adb 投屏源
  roaster.py   # 视觉吐槽
  ui.py        # 置顶小窗
  __main__.py  # python -m pangchuang
```

## 和常见开源桌宠的关系

灵感来自 `live2dpet`、`oc-desktop-pet`、`mochi-llm-pet` 等「看屏就说话」的玩法；旁窗更窄：只做 **手机小窗 + 吐槽**，不堆 Live2D / 助手工具链。

## License

MIT
