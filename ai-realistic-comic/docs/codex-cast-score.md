# Codex CLI 资产打分

打分 = Codex CLI + 固定标准前缀 `SCORE_PREFIX`。

前缀在 `autodl/cast_body_template.py` 的 `SCORE_PREFIX`。它含八项、硬门和 JSON schema，同一次运行里字节不变。`score_call` 只在末尾追加定妆路径、待打分图路径和一句任务，不改写前缀正文。

出图和打分用同一套 `codex login`。没有 `codex` 打印 `CODEX_CLI_MISSING` 并退出。未登录打印 `CODEX_CLI_LOGGED_OUT` 并退出。禁止改走 OpenCode vision。

## 启动检查

1. 二进制：`/home/ubuntu/.local/bin/codex`，或 `command -v codex`。
2. `codex login status` 必须含 `Logged in`。
3. 打分命令是 `codex exec ... -i <定妆> -i <待打分图> -`，标准输入以 `SCORE_PREFIX` 开头。
4. 未登录或没有二进制就停，不换别的识图。
