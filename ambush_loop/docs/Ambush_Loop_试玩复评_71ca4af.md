# Ambush Loop 试玩复评（像素，71ca4af 切片）

对象：分支 `cursor/ambush-loop-mvp-6a41`  
基线：`docs/Ambush_Loop_试玩复盘_0de4f1d.md` 门槛加权 **8.6**；20 轮自评 ~9.0 **当时未重截**。  
本切片玩法停点：本文件提交 HEAD（窗口 dump3 + 冒烟 exit 0）。  
日期：2026-09-11

未开第 7 夜 / FOW / sprite / 真 VO。未混旁窗。硬规则未改。参考 tick 与 §7.5 **一致**。

截图：`docs/eval_71ca4af/`（31 张，`dump.log` = dump3）  
冒烟：`docs/eval_71ca4af/smoke.log`  
耳听：`docs/eval_71ca4af/EAR_LISTEN.md` + `cues/*.wav`  
陌生人页：`docs/eval_71ca4af/STRANGER_FIRST.md`  
读图第一刀：`PIXEL_VERDICT.md`；修后：`PIXEL_AFTER.md`

---

## 一句话

20 轮宣称修掉的构图，**新窗口 dump 证明过了**：失败牌居中、「漏网：」完整、通关 CTA 是整钮、电台远看是灯塔+碟不是油罐、仓道课钉在黄区、档案六夜一屏。第二世长句横切时间轴在 dump3 收掉。观战有「跳到终局 (J)」。

**可对外试玩：是（朋友包，程序多边形 + 合成音 + 横屏）。**  
**不是 9.5，也不是正式版。** 真机拇指空；真人陌生人只有 dump 协议一页。

## 完成度（制作人，像素，1–10）

| 维 | 0de4f1d | 20 轮自评 | **本切片像素** | 依据 |
|---|---:|---:|---:|---|
| 玩法 | 8.9 | 9.1 | **9.2** | 三行牌像素可读；第 2 世按牌改一处能赢（`10`→`13`） |
| 内容 | 8.4 | 8.9 | **9.1** | `19` vs `22` 罐/灯塔可分；黄区课在 `(17,12)` 文案 |
| 手感 | 8.5 | 8.8 | **9.1** | dump3 第二世时间轴可读；`09`/`25` 跳到终局钮；冒烟 skip tick=965 |
| 美术 | 7.4 | 8.3 | **8.4** | 六夜剪影+签名色可并排认；仍是多边形 |
| 音频 | 5.5 | 6.8 | **7.2** | WAV 耳门过（枪声/UI 2.49×，柴油 vs 载波）；仍是 PCM |
| 叙事 | 8.1 | 8.4 | **8.6** | 简报一屏（夜/必须带/一条陷阱）；档案图板 |
| 触控 | 8.6 | 8.6 | **8.7** | `31` 桌面双条关；无真机，不加到 9 |

门槛加权（玩法/内容/手感/触控）**= 9.025 / 10**。  
七维均分 **8.61**。美术/音频仍挡商店页，**不挡朋友包**。

对照：不要把契约绿写成 9.5。本分是 **新 31 张 PNG + 冒烟 tick 指纹 + WAV 探针**，下调项是真机和真人。

## 冒烟（headless）

`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`  
`SMOKE_SLICE_COMPLETE` / `SMOKE_OK_TYPICAL_LOOPS` / `SMOKE_OK_SKIP_OUTCOME tick=965` / `SMOKE_OK_INTEL_CHIP` / `SMOKE_OK_FAIL_CARD_CLEAR` / `SMOKE_OK_WIN_CTA_CLEAR` / `SMOKE_OK_SFX_BODY fire=0.3 tension=0.38 echo=0.29`  
exit 0。`SMOKE_FAIL_ESCAPE` 是院子故意漏网。

| 关 | 探针 | tick |
|---|---|---:|
| yard 逃 / skip | 西掩体朝东 | 965 |
| yard 胜 | 1,2,5 | 283 |
| warehouse 不入伏 / 入伏 | | 1419 / 872 |
| pump 开 / 锁新 | | 694 / 740 |
| railcut 南堆 / 胜 | | 1191 / 818 |
| depot 无绊索 / 胜 | | 1418 / 572 |
| radio 无绊索 / 胜 | sneak 3.6s / 碟台朝南+绊索 | 1502 / 730 |

## 本切片改了什么（可感知）

- 失败/通关构图：**像素证明** 20 轮停靠，不再靠矩形门自称。
- 第二世：flash 限 28 字并挪到轴下；状态条缩短；TopBar 不再通栏咬时间轴。
- 观战「跳到终局 (J)」：只循环 `_sim_tick`，计划冻，冒烟咬 965。
- 简报减肥：键表回操作说明。
- 标题副题标明朋友包。
- 耳听 WAV 进仓。

## 明确没过

- 真机院子拇指环（云端 `adb` 空）。
- ≥3 真人第一局。
- 回波 callout 仍双印（`25`）。
- Dummy 窗口 dump 仍报 4 个 ObjectDB leak（无声卡）。
- 第 7 夜 / FOW / sprite / 真 VO / 合进 `main` 写成正式发行。

## APK

`ambush_loop/dist/AmbushLoop-playtest.apk`  
包名 `com.ambushloop.game`，Godot 4.7.2 debug，arm64，横屏，朋友包。
