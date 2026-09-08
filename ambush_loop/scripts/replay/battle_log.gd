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
		"abort":
			return "%.1fs  指挥官中止尝试" % t
		"barrel":
			return "%.1fs  油桶爆炸" % t
		"repack":
			return "%.1fs  队员%d 弹包补给" % [t, ev["actor_id"]]
		"ambush_armed":
			return "%.1fs  队员%d 入伏许可开启" % [t, ev["actor_id"]]
		"door":
			return "%.1fs  门状态=%s" % [t, str(ev["payload"].get("locked", "?"))]
		"no_engage":
			return "%.1fs  队员%d 无法交战 敌%d（%s）" % [
				t, ev["actor_id"], ev["target_id"], _no_engage_reason_zh(str(ev["payload"].get("reason", "?")))
			]
		"trip":
			return "%.1fs  绊索击毙 敌%d" % [t, ev["actor_id"]]
		"route_choice":
			return "%.1fs  敌%d 改走备用接近" % [t, ev["actor_id"]]
		"terminal":
			return "%.1fs  终局：%s" % [t, str(ev["payload"].get("reason", "?"))]
		_:
			return "%.1fs  %s" % [t, typ]


func _no_engage_reason_zh(reason: String) -> String:
	match reason:
		"hold":
			return "入伏未许可"
		"ammo":
			return "弹药"
		"range":
			return "射程"
		"cone":
			return "射界"
		"los":
			return "视线"
		_:
			return reason


func summary_lines(max_count: int = 12) -> PackedStringArray:
	var out := PackedStringArray()
	var start := maxi(events.size() - max_count, 0)
	for i in range(start, events.size()):
		out.append(format_event(events[i]))
	return out


func last_of_type(type_name: String) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if str(events[i]["type"]) == type_name:
			return events[i]
	return {}


func fingerprint() -> String:
	var parts: PackedStringArray = []
	for ev in events:
		parts.append("%s:%d" % [str(ev["type"]), int(ev["tick"])])
	return ",".join(parts)
