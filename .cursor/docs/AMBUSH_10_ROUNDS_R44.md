Approve with three small revisions: R44 的“1-frame flash”改为约 0.18s pulse，否则手机上几乎不可感知；R52 的 80ms“跑”改为约 0.18s；R50 只有已有 authored route name 时显示，禁止为此新增路线数据结构。

Round	Engine play slice	Executable acceptance	Bump
R44	首次获得 firearm 后，alarm CTA 从 需枪 立即切到 拉警报，附 0.18s 一次性 pulse。	Smoke 构造 knives-only→拾枪：拾枪前=需枪，拾枪后同帧/下一 physics frame=拉警报；pulse 自动结束；不得要求重新进范围。	0.6.28 / 77
R45	SWEEP 首次进入时显示一条 ≤16 字的动作教学，例如 搜尸 · 准备下一波。	Smoke 断言 SWEEP 文案存在且 Unicode len≤16；进入下一波/离开 SWEEP 后不残留。	0.6.29 / 78
R46	跟 portrait badge 的可点击 rect 四边各放宽约 4px，但视觉 badge 不放大。	Smoke 比较 visual rect 与 hit rect；hit rect 每边扩展；不得覆盖枪械切换/数字槽有效区。	0.6.30 / 79
R47	绕背 hotspot 增加手机容错，目标约 88×42，只扩大 hit area。	Smoke assert FLANK hit rect≥88×42；原世界触发距离/目的地算法不变；固定手机 frame 无按钮互压。	0.6.31 / 80
R48	开匣站定 0.4s 期间显示世界态 开匣中…，成功/离开/受打断立即消失。	Smoke 覆盖 enter→progress→open 和 enter→leave→cancel；不得缩短现有 0.4s stand requirement。	0.6.32 / 81
R49	knives-only 尝试 arm alarm 时先给 漏网预警，明确枪械不足风险。	Smoke：无 firearm 时 CTA action 产生 漏网预警；有 firearm 时不出现；不得改变实际 alarm gating / leak 判定。	0.6.33 / 82
R50	ALERT wave chip 增强边框，并在已有 authored route name 时附路线名。	Smoke：有 route→显示名称；无 route→安全回退原 wave chip；禁止新增 route schema 或改变波次逻辑。	0.6.34 / 83
R51	West follow-file ghost Line2D alpha +0.08，提高队列连贯感。	Smoke assert alpha 新值且≤1；固定 west-follow frame 可辨识 ghost line；destination/span/settle 算法完全不变。	0.6.35 / 84
R52	long-press run 真正触发瞬间，在 lead 附近显示约 0.18s 的 跑 mote。	Smoke：短按不出现；long-press crossing threshold 时只触发一次；释放/再次长按可再次触发；不改 run threshold/speed。	0.6.36 / 85
R53	SWEEP 内靠近可搜 corpse 时提供 搜尸 context hotspot，与 开匣交互语言一致。	Smoke：仅 SWEEP + corpse in range 显示；离开范围/已搜/离开 SWEEP 消失；触发后沿用现有 corpse loot，不新增第二套掉落逻辑。	0.6.37 / 86

执行优先级也合理：R44/R45/R48/R53 是直接降低首局卡顿的玩法收益最高项；R46/R47 是手机输入容错；R49 是失败前反馈；R50–R52 属于第二层可读性/手感。

全程继续锁死 RAID SCOUT→ALERT→SWEEP、ALERT lock-move、auto fire/nades、10-gun kit；(6,6)/(5,16) span==6 不动；body≥1.0、west zoom≥0.85；每轮只一个 Engine slice、独立 commit，并以 SMOKE_SLICE_COMPLETE 作为合入门槛。
