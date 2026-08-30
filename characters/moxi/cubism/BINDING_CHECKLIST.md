# Cubism 绑定清单（墨汐）

目标：把 `characters/moxi/art/` 做成可在研究台加载的本地模型：

`public/models/moxi/moxi.model3.json`

本环境没有 Cubism Editor，**网格与参数必须在你本机 Editor 里完成**。

0. 准备

1. 启动本仓库已装的 Cubism Editor：`./tools/cubism/launch-editor.sh`（选 FREE；或用你自己电脑上的官方安装）
2. 用 Photoshop / CSP 打开 `art/00_master_reference.png`
3. 按下面图层表拆成 PSD（AI 自动分层只能当参考，对位不准，**以手拆主视觉为准**）

## 1. 必拆图层（MVP）

从下到上建议顺序：

| 图层名 | 内容 |
| --- | --- |
| `hair_back` | 后发 |
| `body` | 身体 + 高领衣服 |
| `shawl` | 肩上墨纹外搭（可与 body 合并，若要摆动则单拆） |
| `neck` | 脖子 |
| `face` | 脸底（含鼻子、面颊） |
| `ear_l` / `ear_r` | 耳 |
| `eye_white_l/r` | 眼白 |
| `iris_l/r` | 虹膜 |
| `highlight_l/r` | 眼高光 |
| `eyelid_up_l/r` | 上眼皮 |
| `eyelid_down_l/r` | 下眼皮 |
| `brow_l/r` | 眉 |
| `mouth` | 嘴（可再拆开合） |
| `hair_side_l/r` | 侧发 |
| `hair_front` | 刘海 |
| `bangs_lock` | 右侧长发缕（墨青渐变那缕） |
| `crane_pin` | 纸鹤胸针（可选） |

`art/layers_transparent/` 里的 PNG 是草稿参考，不要直接当最终 PSD。

## 2. Editor 内最低参数

- `ParamAngleX` / `Y` / `Z`
- `ParamEyeLOpen` / `ParamEyeROpen`
- `ParamEyeBallX` / `Y`
- `ParamBrowLY` / `RY`
- `ParamMouthOpenY`
- `ParamBreath`

先做出：转头小范围、眨眼、视线、张嘴、呼吸。

## 3. 导出

1. 纹理图集检查无漏图
2. `导出嵌入文件` → `moc3`
3. 用 Viewer (for OW) 补 HitArea、表情列表
4. 整包复制到：

```text
public/models/moxi/
  moxi.model3.json
  moxi.moc3
  textures/
  motions/          # 至少一条 Idle
  expressions/      # 可选
```

5. 仓库内验收：

```bash
npm run check-model -- public/models/moxi
npm run fetch-core
npm run dev
```

研究台选择「墨汐（本地）」加载 `/models/moxi/moxi.model3.json`。

## 4. 完成定义

墨汐算「自建 Live2D 角色完成」当且仅当：

1. 立绘与图层为项目原创（已具备主视觉）
2. `public/models/moxi/` 存在可加载 moc3 包
3. 研究台能播 idle，并有视线或点击反馈之一
