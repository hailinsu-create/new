# Codex CLI 资产打分

打分只走 Codex CLI + 固定标准前缀 `SCORE_PREFIX`。2026-10-07 起 Codex CLI 不可用就失败并记录原因，不换模型。

前缀在 `autodl/cast_body_template.py` 的 `SCORE_PREFIX`。它含八项、硬门和 JSON schema，同一次运行里字节不变。`score_call` 只在末尾追加定妆路径、待打分图路径、`eye_crop_short_side` 和一句任务，不改写前缀正文。pass1 的 motif 定义在这前缀里：无情节的成年全身站姿模板。胸腹髋腿还有布则这一项低于 9。九分线不放宽。`eyes_black_brown` 只表虹膜颜色。眼睛裁切短边低于 200 时，`eyes_geometry` 只认大小眼、眼角高低和视线分开，高光和眼睑不清不压 identity。短边达到 200 时，高光或眼睑失败也使 `eyes_geometry` 为假，identity 最高 7。正面肉色连体（无乳点、无肚脐、髋部有衣缝）wardrobe 最高 6。打分用头肩裁切比眼睛，用全身图判衣着、姿势和脚。

出图仍只用 Codex CLI。打分也只用 Codex CLI。先走 `codex exec`。没有二进制、未登录、额度用完、CLI 报错、分数 JSON 解析失败或超时，都停在这一步：打印 `SCORE_FAILED`，同一行写 `reason=`，并在待打分图旁边写 `.score-fail.json`。不调用别的模型。成功的分数 JSON 写 `scorer`，值为 `codex` 或 `local`。头胸被背景吃掉时 `scorer` 为 `local`，不调用模型。禁止改用 DeepSeek vision。

## 启动检查

1. 二进制：`/home/ubuntu/.local/bin/codex`，或 `command -v codex`。
2. `codex login status` 必须含 `Logged in`。
3. 打分先走 `codex exec ... -i <定妆> -i <头肩裁切> -i <全身> -`，标准输入以 `SCORE_PREFIX` 开头。
4. 上一步不可用就失败并记录原因。不改 rubric，不改九分线，不换模型。未登录的原因码是 `CODEX_CLI_LOGGED_OUT`。没有二进制的原因码是 `CODEX_CLI_MISSING`。
5. 修订 = 改脚本 + 写或更新说明文档 + 推到 GitHub。说明文档用来固化，防止漂移。文档与代码不一致算漂移，须立刻对齐。不得只留在本机。
