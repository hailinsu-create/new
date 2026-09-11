# Ambush Loop PR #4 审查报告

审查日期：2026-09-07。

审查对象：[PR #4](https://github.com/hailinsu-create/new/pull/4)，head `779fdcfb0ba442f8de733aad761d8e21d714555b`。审查结束时再次核对，head 未变化。仓库本地副本未修改。

结论：三关确有可获胜方案，但目前仍有 3 项 P1 和 3 项 P2 问题，建议修复后再合并。完整时间轴拖动、迷雾、导出包与真人平衡测试按已声明范围暂缓，没有把这些延期项当作缺陷。

## 1. [P1] 绊索必须加入同一固定步长模拟

位置：[scripts/mine.gd:16–22](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/mine.gd#L16-L22)。

`main._process()` 每渲染帧可连续执行多个 `_sim_tick()`，但绊索仍在独立 `_process()` 中每渲染帧检测一次。进入触发范围和射击之间的先后顺序因模拟步批量不同而变化，固定步长不能覆盖完整战斗。

控制场景：一个敌人第一 tick 进入绊索范围，队员第二 tick 冷却结束。同一初态，每 1 个 tick 调用一次绊索检测，结算后剩 7 发；每 2 个 tick 调用一次检测，结算后剩 6 发。终局 tick 也由 1 变为 2。另一个边界测试将活跃敌人置于绊索范围并暂停模拟，等待真实 process_frame，tick 保持 0，敌人仍被击杀。

建议：绊索检测由 `_sim_tick()` 在固定阶段统一调用，删除会改战斗状态的独立 `_process()`；暂停与终局统一阻止触发。加入按不同渲染分组推进同一计划的事件/弹药一致性断言。

## 2. [P1] 换关需要匹配阻挡网格，当前掩体和路线穿墙

位置：[scripts/main.gd:193–205](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/main.gd#L193-L205)；相关定义为 `scripts/level/level_def.gd`。

`AmbushGrid` 只在初始化构造院子阻挡布局，`_load_level()` 更换路线与掩体却没有重建关卡几何。网格实际采样确认：

- 仓道的“仓门掩体” `(10,8)`、“南口掩体” `(18,16)` 均在 blocked 格。
- 泵站的“泵房西” `(9,9)`、“管架” `(20,14)` 均在 blocked 格。
- 仓道侧翼穿过外墙 `(15,4)`、`(16,4)`、`(17,4)`。
- 泵站锁门备用路线穿过箱体 `(10,8)`、`(10,9)`、`(10,10)`。
- 院子和后两关的部分主路线也穿过阻挡格，详情见诊断日志。

敌人移动不受网格阻挡，而 LOS 受其影响，因此会出现敌人穿墙、合法部署位置陷在障碍内、射界被邻近实体格封死等不一致。可通关并不能证明地图几何合法。

建议：为每关提供匹配的阻挡定义，或先调整掩体/折线路点以适应当前网格；在构建每关时断言所有部署格可站立、路线的整条线段不穿阻挡。门的阻挡与通行状态也应采用一致的地图规则。

## 3. [P1] 越界判定必须先于下一轮射击

位置：[scripts/enemy.gd:73–81](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/enemy.gd#L73-L81)；相关顺序在 `main.gd:1026–1053`。

敌人到达最后路点时只递增 `route_index`，下一次 `sim_step()` 才调用 `mark_escaped()`。但每次 tick 都先让队员射击，再运行敌人。因此到达逃逸终点的敌人仍有一轮被射杀的机会，击杀回调还能先把结果置为 WON。

边界复现：将最后一名敌人置于真实 `escape_world`，路线终点同为该坐标、`route_index == route.size()`、剩 1 HP，并让合法射程内的队员准备开火。下一 tick 得到 `phase=WON, reason=win`，而不是 escape。

建议：移动后立即检测逃逸并提交失败，射击前拒绝继续处理已终局的一轮；统一按蓝图约定执行移动、越界、战斗、最终结算。为最后一枪与越界相邻/同 tick 建立边界回归。

## 4. [P2] 下一关存档写入了旧 level_id

位置：[scripts/main.gd:1229–1237](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/main.gd#L1229-L1237)。

`_on_continue_pressed()` 先改 `level_index`，随后在加载下一关之前 `_save_progress()`。后者从仍指向旧关的 `level.level_id` 取值，读取进度时又只使用该 ID，忽略保存的数字 index。

实测：从院子点下一关后，当前是 warehouse，但存档为 `level_id=yard, level_index=1`；重新 `_load_progress()` 得到 index 0。第三关结束选择再玩，当前为 yard，存档却仍为 pump。

建议：加载目标关并完成重置后再保存，或让保存函数明确接收目标关卡 ID；保证 ID/index 来源一致。测试应覆盖进入下一关后尚未获胜就退出，以及通关后从头再玩再退出。

## 5. [P2] 致命攻击在终局之后才记日志，结算摘要漏掉原因

位置：[scripts/main.gd:1044–1048](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/main.gd#L1044-L1048)。

`op.try_fire()` 同步触发死亡、`_check_win()` 和结算面板更新，返回之后才追加 fire/empty 事件。致命还击也在 `take_damage()` 引发全灭之后才发出 return_fired。

控制场景实际日志为 `[door, kill, terminal, fire]`，终局时没有最终快照。面板已在 terminal 时生成，因此最后一枪不在该次摘要内；全灭时也可能缺少最后一次还击。这个问题影响当前已经交付的事件链，与完整 scrub 是否延期无关。

建议：在实际应用伤害前记录确认的攻击事件，或者集中收集并按确定顺序提交战斗事件；统一在该 tick 的事件与终局快照写完后构造结果面板，且终局之后不再追加战斗事件。

## 6. [P2] 冒烟会在没有验证后两关时报告切片完成

位置：[scripts/smoke_test.gd:83–96](https://github.com/hailinsu-create/new/blob/779fdcfb0ba442f8de733aad761d8e21d714555b/ambush_loop/scripts/smoke_test.gd#L83-L96)。

测试只实际赢了院子。仓道检查的是成功加载，泵站检查的是 `LevelDef` 存在一扇门，随后就打印 `SMOKE_SLICE_COMPLETE` 并退出 0；即使院子胜利后没进入仓道，else 分支仍以完成退出。后两关无法获胜、门分支失效或换关损坏时都可能漏报。

建议：对错误换关返回非零；驱动三关参考方案到真实 WON，并验证泵站锁门前后不同路线、失败原因和计划恢复。隔离用户存档并用模拟 tick 超时，避免测试依赖玩家当前存档与渲染速度。

## 验证记录

- 引擎实际输出：`Godot Engine v4.7.2.stable.official.ed1daf0bf`。
- 在独立副本 `work/review-sandbox` 中执行，项目显示名改为 `Ambush Loop Review 779fdcf` 以隔离用户存档。游戏 GDScript 与 PR 一致；原克隆工作树保持干净。
- 先完成 headless editor 导入，再执行仓库原冒烟，退出码 0，确实输出 `SMOKE_SLICE_COMPLETE`。这项成功没有消除上述覆盖缺口。
- 另外以真实关卡配置直接推进固定 tick，验证以下方案得到 WON。slot 为脚本中 0 基索引；均不带绊索、不带弹包、见敌即打。这些是自动模拟结果，没有替代窗口操作/真人体验检查。

| 关卡 | 三名队员 slot | 朝向 | 门 | 终局 tick |
|---|---|---|---|---:|
| 院子 | 1, 2, 5 | 90°, 180°, 180° | 无 | 原冒烟中获胜 |
| 仓道 | 1, 3, 5 | 180°, 0°, 180° | 无 | 823 |
| 泵站 | 1, 4, 5 | 90°, 0°, 180° | 开 | 727 |
| 泵站 | 1, 4, 5 | 90°, 0°, 180° | 锁 | 746 |

绊索、越界和存档测试是针对边界条件的控制场景；它们不声称上述参考通关方案每次都会触发这些问题。

诊断脚本：`outputs/ambush_review_probe.gd`。

执行方式（在本次工作区根目录的 PowerShell）：

```powershell
& '.\work\review-tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path work/review-sandbox -s res://scripts/smoke_test.gd
& '.\work\review-tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path work/review-sandbox -s 'C:\Users\23170\Documents\Codex\2026-09-07\xian\outputs\ambush_review_probe.gd'
```

诊断脚本会写自己的隔离测试存档，重复运行原冒烟之前应使用新的隔离测试用户数据；不要针对玩家项目名执行诊断脚本。

本次未发布 GitHub 评论或 Review，未修改、提交、合并 PR。
