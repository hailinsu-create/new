class_name RaidLoc
extends RefCounted

## Chinese copy keys for raid HUD. One table so later locales can swap.

const KEYS := {
	"alarm": "拉警报",
	"alarm_need_gun": "至少先拾一把枪 — 再按一次才强拉警报",
	"sweep": "打扫战场",
	"extract": "撤离封锁",
	"next_wave": "下一波警报",
	"search": "开匣中…",
	"pass": "走近队友再递装（T）",
	"haul": "走近尸体再拖（H）",
	"crate_ping": "先开这匣",
	"restore_facing": "朝向已恢复，枪要重搜",
	"wave_leak": "第%d波漏网",
	"no_hp_star": "无人受伤",
	"loot_then_hold": "先搜匣再埋伏",
}


static func t(key: String) -> String:
	return str(KEYS.get(key, key))


static func has(key: String) -> bool:
	return KEYS.has(key)
