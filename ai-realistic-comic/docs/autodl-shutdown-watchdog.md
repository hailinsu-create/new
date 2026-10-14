# AutoDL 关机与看门狗（2026-10-11）

在 `8f803c1` spend_cap 基础上强制：

1. **任何退出路径关机**：pilot `signal(SIGINT/TERM/HUP)` + `atexit` + `try/finally` → `shutdown_fleet`（留盘、不 release）。
2. **独立看门狗**：`autodl_watchdog.py` 另进程（建议 tmux），读 `SPEND_CAP_SESSION.json` 的 `boot_at` **墙钟**投影 GPU + 盘费 reserve + 钱包差额，超封顶或超 `max-wall-min` 则反复 `shutdown_fleet`，**不依赖主脚本存活**。
3. **raw 即拉**：远端每出一张 `*-r4-raw.png`，本地轮询拉回并 Store 同步，再关机。
4. **开机前预检**：`refuse_power_on`（钱包已超 / 余量不够 10min GPU+reserve）直接拒绝，不开机。

入口：`workflows/comfyui/run_dual_couple_pilot.py`（林+伊莲四张，默认封顶 ¥3）。
看门狗：`python workflows/comfyui/autodl_watchdog.py --session /opt/cursor/artifacts/dual-couple/SPEND_CAP_SESSION.json`。

禁止为观感判定挂机。
