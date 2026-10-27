# 音乐 + 节拍 · B0-01 诺曼底 · v0.3.2 · 2026-10-28

- **弃用**：Horde War Drums by William Hector（匀速、无 build/drop）— 仍留 v0.3.1 edit 作历史，**勿再作主床**  
- **授权**：t84u · 仅内部

## 主选曲（已锁 · 已下载）

| 项 | 值 |
| --- | --- |
| **曲名** | Determined Pursuit (epic orchestra loop) |
| **作者** | Emma_MA |
| **许可** | **CC0**（Public Domain；OGA 页声明无需署名，建议仍写 credits） |
| **URL** | https://opengameart.org/content/determined-pursuit-epic-orchestra-loop |
| **直链 wav** | https://opengameart.org/sites/default/files/determined_pursuit_loop.wav |
| **本机全长** | `outputs/v0.3.2-b0-01-2026-10-28/edit/determined_pursuit_loop_emma_ma_cc0.wav`（≈108s · 19.1MB） |
| **本机 15s 床** | `outputs/v0.3.2-b0-01-2026-10-28/edit/bgm_primary_15s.wav`（从全长 **ss=14.4** 起切 15s） |
| **结构** | 0–≈18s 中段铺垫 → **≈18s 起高段**（相对本床 = 视频 **≈3.6s** 进入 drop/高能量） |
| **工作 BPM** | 目测细分 ≈172；**四分 ≈86 BPM**（以实测 hit 为准，勿死跟 128） |

### 节拍表（对齐画面）

| 视频 time | 角色 | 音乐事件（相对 15s 床） | 画面 |
| ---: | --- | --- | --- |
| **3.60** | **DROP / 主落点** | 高段突入后首个强峰（床内 ≈3.65） | 门落触滩 |
| **9.20** | **第二重拍** | 高段持续强峰（床内 ≈9.25） | 爆破闪白 |
| **12.80** | **尾落点** | 高段强峰（床内 ≈12.85） | 插旗到位 |
| 0.00–3.50 | build | 床前段相对低/中能量爬升 | 钩子→蓄势 |
| 13.25–15.00 | 收 | 延音/持续织体 | 定格字幕 |

> 微调窗：**±0.10s**；若换备用曲，只改 MUSIC 与 assemble 的 `BGM_SS`，SCRIPT/分镜锁点尽量不动。

## 备用曲

| 项 | 值 |
| --- | --- |
| **曲名** | Adventure Intro Title [Cinematic, Epic] |
| **作者** | nene |
| **许可** | **CC0** |
| **URL** | https://opengameart.org/content/adventure-intro-title-cinematic-epic |
| **本机** | `…/edit/adventure_theme_intro_nene_cc0.wav` + `bgm_backup_15s.wav`（全长约 ss=10.5 起 15s） |
| **特点** | 更典型的 cinematic **单峰 build→drop**（约全长 23–25s）；三锁点贴合弱于主选，作替换床时优先保 **3.60 drop** |

## credits 建议文案

```text
BGM: "Determined Pursuit" by Emma_MA — OpenGameArt — CC0
https://opengameart.org/content/determined-pursuit-epic-orchestra-loop
```

## 二进制入库策略

- 全长 19MB wav / 成片 mp4：**默认可不入库**；本机 `outputs/v0.3.2-…/edit/` 保留。  
- 文档（本文件 + 三件套 + assemble 草案）入 PR#84。

ALIGN_OK v0.3.2 3.6/9.2/12.8
