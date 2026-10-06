# Codex CLI 资产打分

打分默认是 Codex CLI + 固定标准前缀 `SCORE_PREFIX`。只有 Codex CLI 不可用才回退 Cursor 的 grok-4.7-xhigh。

前缀在 `autodl/cast_body_template.py` 的 `SCORE_PREFIX`。它含八项、硬门和 JSON schema，同一次运行里字节不变。`score_call` 只在末尾追加定妆路径、待打分图路径、`eye_crop_short_side` 和一句任务，不改写前缀正文。pass1 的 motif 定义在这前缀里：无情节的成年全身站姿模板。胸腹髋腿还有布则这一项低于 9。九分线不放宽。`eyes_black_brown` 只表虹膜颜色。眼睛裁切短边低于 200 时，`eyes_geometry` 只认大小眼、眼角高低和视线分开，高光和眼睑不清不压 identity。短边达到 200 时，高光或眼睑失败也使 `eyes_geometry` 为假，identity 最高 7。正面肉色连体（无乳点、无肚脐、髋部有衣缝）wardrobe 最高 6。打分用头肩裁切比眼睛，用全身图判衣着、姿势和脚。

出图仍只用 Codex CLI。打分默认也仍是 Codex CLI，这一顺序不变。先走 `codex exec`。没有二进制、未登录、额度用完、CLI 报错或超时，才用同一前缀回退。回退入口是 Cursor 的 `cursor-agent -p --mode ask --model grok-4.7-xhigh`，每张图用 `--image` 附上。不走 grok.com CLI，不走 xAI 直连 API，不走 OpenCode。每张分数 JSON 写 `scorer`，值为 `codex`、`grok-4.7-xhigh` 或 `local`。头胸被背景吃掉时 `scorer` 为 `local`，不调用模型。禁止改用 DeepSeek vision。

## 启动检查

1. 二进制：`/home/ubuntu/.local/bin/codex`，或 `command -v codex`。
2. `codex login status` 必须含 `Logged in`。
3. 打分先走 `codex exec ... -i <定妆> -i <头肩裁切> -i <全身> -`，标准输入以 `SCORE_PREFIX` 开头。
4. 只有上一步不可用，才改走 Cursor 的 `cursor-agent --model grok-4.7-xhigh`。不改 rubric，不改九分线。禁止改走 grok.com CLI、xAI 直连 API 或 OpenCode。
5. 修订 = 改脚本 + 写或更新说明文档 + 推到 GitHub。说明文档用来固化，防止漂移。文档与代码不一致算漂移，须立刻对齐。不得只留在本机。
