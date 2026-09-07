class_name BattleLog
extends RefCounted

## Event log + lightweight presentation snapshots (blueprint §4.1).

var events: Array = [] # Dictionaries
var snapshots: Array = [] # every ~0.1s
var terminal_tick: int = -1
var terminal_reason: String = ""


func clear() -> void:
	events.clear()
	snapshots.clear()
	terminal_tick = -1
	terminal_reason = ""


func add_event(tick: int, type: String, actor_id: int = -1, target_id: int = -1, pos: Vector2 = Vector2.ZERO, payload: Dictionary = {}) -> void:
	events.append({
		"tick": tick,
		"seq": events.size(),
		"type": type,
		"actor_id": actor_id,
		"target_id": target_id,
		"position": pos,
		"payload": payload,
	})


func add_snapshot(tick: int, data: Dictionary) -> void:
	snapshots.append({"tick": tick, "data": data})


func mark_terminal(tick: int, reason: String) -> void:
	if terminal_tick >= 0:
		return
	terminal_tick = tick
	terminal_reason = reason
	add_event(tick, "terminal", -1, -1, Vector2.ZERO, {"reason": reason})


func format_event(ev: Dictionary) -> String:
	var t: float = float(ev["tick"]) / 60.0
	var typ: String = str(ev["type"])
	match typ:
		"spawn":
			return "%.1fs  敌%d 进入战场" % [t, ev["actor_id"]]
		"fire":
			return "%.1fs  队员%d 开火 → 敌%d" % [t, ev["actor_id"], ev["target_id"]]
		"return_fire":
			return "%.1fs  敌%d 还击 → 队员%d" % [t, ev["actor_id"], ev["target_id"]]
		"kill":
			return "%.1fs  敌%d 被击毙" % [t, ev["actor_id"]]
		"loot":
			return "%.1fs  队员%d 拾取 +%s弹" % [t, ev["actor_id"], str(ev["payload"].get("amount", "?"))]
		"empty":
			return "%.1fs  队员%d 弹药耗尽" % [t, ev["actor_id"]]
		"op_down":
			return "%.1fs  队员%d 阵亡" % [t, ev["actor_id"]]
		"escape":
			return "%.1fs  敌%d 越界逃逸" % [t, ev["actor_id"]]
		"ambush_armed":
			return "%.1fs  队员%d 入伏许可开启" % [t, ev["actor_id"]]
		"door":
			return "%.1fs  门状态=%s" % [t, str(ev["payload"].get("locked", "?"))]
		"terminal":
			return "%.1fs  终局：%s" % [t, str(ev["payload"].get("reason", "?"))]
		_:
			return "%.1fs  %s" % [t, typ]


func summary_lines(max_count: int = 12) -> PackedStringArray:
	var out := PackedStringArray()
	var start := maxi(events.size() - max_count, 0)
	for i in range(start, events.size()):
		out.append(format_event(events[i]))
	return out
