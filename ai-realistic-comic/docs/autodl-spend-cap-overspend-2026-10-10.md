# AutoDL 超支核查（2026-10-10，¥11.63→¥6.15）

**只读核查；本文件对应修复：`workflows/comfyui/spend_cap.py` + `run_fox_couple_pilot.py` 硬停。禁止在未授权时 `power_on`。**

## 结论（短）

| 项 | 事实 |
| --- | --- |
| 差额 | ¥11.63 → ¥6.15 = **¥5.48**（> ¥4 封顶） |
| 重复下载 | **无**（`MODELS_SKIP`，账单无镜像/下载项） |
| 正式 USER_LOCKED 出图 | **无**（当次跑的是 GenerateImage 顶替底板；且本地 SSH 监控死后未拉回） |
| 远端是否算过 | **有**：592 上 `COUPLE_R4_DONE` nude+torn raw 已生成，但底板错误且本地进程已死 |

## 按时间花费明细（账单 `POST /api/v1/bill/list`，+08）

会话锚点：首轮情侣关机结算后余额 **¥11.63**（`charge_shutdown` 2026-10-10 23:32:48+08）。

| 时间 (+08) | 机器 | 类型 | 金额 | 余额→ | 计费段 |
| --- | --- | --- | --- | --- | --- |
| 10 23:59:59 | 791 | `data_disk_settle` 100GiB | ¥0.67 | 10.96 | 10日 00:03→11日 00:00（关机仍收盘） |
| 10 23:59:59 | 592 | `data_disk_settle` 100GiB | ¥0.67 | 10.29 | 同上 |
| 11 00:59:59 | 592 | `charge_settle` GPU | ¥2.68 | 7.61 | **00:04:12→01:00:00**（开机后第 1 小时） |
| 11 01:30:38 | 592 | `charge_shutdown` GPU | ¥1.46 | **6.15** | 01:00:00→01:30:31（关机结算） |
| **合计** | | | **¥5.48** | | |

GPU 合计 ¥4.14 ≈ 86.3 min × ¥2.88/h（`payg_price=2880` 厘）。无镜像费。

## 开关机时间线（UTC / 对照 +08）

| UTC | +08 | 事件 |
| --- | --- | --- |
| 15:41:17 | 23:41 | 第二轮 pilot `START bal=11.63 cap=4`（顶替底板） |
| 15:41–16:04 | 23:41–00:04 | 双机抢卡；钱包仍 11.63（未开机不计 GPU） |
| 16:04:10 | **00:04:10** | **592 `POWER_TRY success` / CARD_WIN**（账单 charge_from 00:04:12） |
| 16:04–16:12 | 00:04–00:12 | SSH/ship、`MODELS_SKIP`、Comfy 起来 |
| 16:12:30 | 00:12 | `GENERATE_START`；远端 nohup 出图 |
| ≈16:12+ | | 本地 SSH `REMOTE_FAILED rc=255` → **pilot 进程死，未 `shutdown_fleet`** |
| ≈17:13 | 01:13 | 远端 `COUPLE_R4_DONE`（raw 已在盘） |
| 17:30:38 | **01:30:38** | 人工拉图后 `POWER_OFF`（账单 charge_shutdown） |

791 全程 shutdown；只收数据盘日结。

## 根因

1. **封顶看钱包差额，AutoDL GPU 约整点才 `charge_settle`**  
   开机后近 1h 内 `balance` 几乎不动 → `CAP_KILL` / `CAP_DURING_CARD_WAIT` **根本看不到超支**。
2. **SSH 监控死亡无 finally 关机**  
   `bring.ssh` → `SystemExit(REMOTE_FAILED)` 直接退出；GPU 空转到人工处理。
3. **「未出图」表象**  
   远端其实出了顶替底板的 raw；本地已死且未拉回；随后 USER_LOCKED 才到 → 用户侧等于白烧。
4. **数据盘日结计入钱包但不在封顶模型里**  
   两台 100GiB ≈ ¥1.34/天，即使完全不开机会吃掉封顶余量。
5. （首轮）`MACHINE_HELD_FOR_JUDGE` 出图后仍挂 GPU 等观感，放大浪费（发生在落到 11.63 之前）。

## 修复（已落地）

1. `workflows/comfyui/spend_cap.py`：**钱包差额 vs 开机投影 GPU** 取大；另留数据盘 reserve；`refuse_power_on` 硬拒。
2. `run_fox_couple_pilot.py`：抢卡前硬拒；`mark_boot` 后按投影 `CAP_HARD_KILL`；**`finally: shutdown_fleet`**；观感离线，不再 `MACHINE_HELD_FOR_JUDGE`。
3. 标准文档写明：封顶=投影硬停；禁止为判定挂机；盘费单独认知。

原始账单摘录：`/opt/cursor/artifacts/fox-couple/overspend-audit/`。
