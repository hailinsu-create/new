# Codex mobile-first-pass 合并记录（2026-09-27）

## 合并对象

- 目标：`cursor/ambush-play-r44-0641`，合并前 `8dc097e`
- 来源：`codex/mobile-first-pass`，提交 `422f48d`
- 共同基线：`8608cdd`

## 解析原则

来源分支从早期基线新增了安卓竖屏、触控、存档、音频与验证脚本；目标分支在此后已推进约 580 个提交并到达 R44 / 0.6.28。核心文件不能采用来源侧旧实现，否则会覆盖六夜战役、RAID 契约、R01-R44 玩法与当前冒烟网。

冲突文件全部保留 R44 侧实现，包括 `main.gd`、`smoke_test.gd`、`touch_hud.gd`、关卡定义、地图绘制、场景、工程与导出配置。来源侧的独立运行脚本未直接落树：它们绑定旧三关场景/API，`save_store.gd` 还把关卡索引限制在 0-2，与当前六夜战役不兼容；直接保留会制造看似可运行、实际失效的第二套存档/触控/音频系统。

保留并标记为历史资料的内容：

- `ambush_loop/docs/MOBILE_PORTRAIT_PLAN.md`
- `ambush_loop/docs/NEXT_RELEASE_PLAN_2026-09-09.md`
- `ambush_loop/docs/RELEASE_BLUEPRINT.md`
- `ambush_loop/docs/TERRA_DEVELOPMENT_BRIEF_2026-09-09.md`
- `docs/PLAY_STORE_RELEASE_CHECKLIST.md`
- `docs/PRIVACY_POLICY_DRAFT.md`
- 根 `.gitignore` 的本地 `outputs/` 排除规则

## 功能覆盖判断

R44 主线已有并继续使用自己的动态 `TouchHud`、安全区适配、长按跑、Android 返回/后台处理、`ConfigFile` 进度保存、`sfx_bus`/`audio_director`、六夜关卡与大型 `smoke_test.gd`。因此本次合并以保留 Git 历史和设计资料为主，不把早期并行实现伪装成新增可玩功能。

## 验证边界

合并后必须至少运行当前主线的 `smoke_test.gd`。旧 Codex 独立测试没有移植，不能引用它们的历史日志宣称当前通过。Android 导出、模拟器和真机验证未执行时，继续明确标记为未验证。
