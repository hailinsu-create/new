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
			var shooter := str(ev.get("payload", {}).get("name", ""))
			var first := first_of_type("fire")
			var is_first := not first.is_empty() and int(first.get("seq", -2)) == int(ev.get("seq", -1))
			if is_first and shooter != "":
				return "%.1fs  ★ 第一枪是%s → 敌%d" % [t, shooter, ev["target_id"]]
			if shooter != "":
				return "%.1fs  %s 开火 → 敌%d" % [t, shooter, ev["target_id"]]
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
			var route_zh := _route_zh(str(ev.get("payload", {}).get("route", "")))
			if route_zh != "":
				return "%.1fs  敌%d 沿%s越界逃逸" % [t, ev["actor_id"], route_zh]
			return "%.1fs  敌%d 越界逃逸" % [t, ev["actor_id"]]
		"abort":
			return "%.1fs  指挥官中止尝试" % t
		"barrel":
			var hits := int(ev.get("payload", {}).get("hits", 0))
			if hits > 0:
				return "%.1fs  ★ 油桶炸到人 · %d" % [t, hits]
			return "%.1fs  油桶爆炸" % t
		"repack":
			var pack_nm := str(ev.get("payload", {}).get("name", ""))
			if pack_nm != "":
				return "%.1fs  ★ %s 弹包续上" % [t, pack_nm]
			return "%.1fs  队员%d 弹包补给" % [t, ev["actor_id"]]
		"ambush_armed":
			var amb_nm := str(ev.get("payload", {}).get("name", ""))
			if amb_nm != "":
				return "%.1fs  ★ %s 入伏许可 — 现在打" % [t, amb_nm]
			return "%.1fs  队员%d 入伏许可开启" % [t, ev["actor_id"]]
		"door":
			return "%.1fs  门状态=%s" % [t, str(ev["payload"].get("locked", "?"))]
		"no_engage":
			return "%.1fs  队员%d 无法交战 敌%d（%s）" % [
				t, ev["actor_id"], ev["target_id"], _no_engage_reason_zh(str(ev["payload"].get("reason", "?")))
			]
		"trip":
			return "%.1fs  ★ 绊索抽中 敌%d" % [t, ev["actor_id"]]
		"route_choice":
			if bool(ev.get("payload", {}).get("covered", false)):
				return "%.1fs  ★ 敌%d 改走紫色备用接近 — 被你罩住" % [t, ev["actor_id"]]
			return "%.1fs  敌%d 改走紫色备用接近" % [t, ev["actor_id"]]
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


static func reason_zh(reason: String) -> String:
	match reason:
		"escape":
			return "逃逸"
		"wipe":
			return "全灭"
		"abort":
			return "中止"
		"win":
			return "通关"
		"empty":
			return "空弹"
		"route_choice":
			return "改线"
		"trip":
			return "绊索"
		_:
			return reason


func has_type(type_name: String) -> bool:
	return not last_of_type(type_name).is_empty()


func max_kill_combo(window_ticks: int = 48) -> int:
	var best := 0
	var run := 0
	var last := -99999
	for ev in events:
		if str(ev.get("type", "")) != "kill":
			continue
		var t := int(ev.get("tick", 0))
		if t - last <= window_ticks and last >= 0:
			run += 1
		else:
			run = 1
		last = t
		best = maxi(best, run)
	return best


func _route_zh(route: String) -> String:
	match route:
		"main":
			return "主路"
		"flank":
			return "侧翼"
		"sneak":
			return "西暗道"
		"alt":
			return "备用接近"
		_:
			return ""


func first_of_type(type_name: String) -> Dictionary:
	for ev in events:
		if str(ev["type"]) == type_name:
			return ev
	return {}


func terminal_summary_line() -> String:
	## One-line 终局摘要 from terminal reason + last meaningful events.
	var bits: PackedStringArray = []
	match terminal_reason:
		"escape":
			var esc := last_of_type("escape")
			var route_zh := _route_zh(str(esc.get("payload", {}).get("route", "")))
			if route_zh != "":
				bits.append("敌军沿%s从逃逸口越界" % route_zh)
			else:
				bits.append("敌军从逃逸口越界")
		"wipe":
			bits.append("参战小队全灭")
		"abort":
			bits.append("指挥官中止尝试")
		"win":
			bits.append("零逃逸，封锁成功")
		_:
			if terminal_reason != "":
				bits.append(reason_zh(terminal_reason))
	var first_fire := first_of_type("fire")
	if not first_fire.is_empty():
		var nm := str(first_fire.get("payload", {}).get("name", ""))
		if nm != "":
			bits.append("第一枪是%s" % nm)
		else:
			bits.append("第一枪是队员%d" % int(first_fire.get("actor_id", 0)))
	if has_type("empty") and terminal_reason != "win":
		bits.append("有队员空弹")
	if has_type("trip"):
		var trip_ev := last_of_type("trip")
		bits.append("绊索抽中敌%d" % int(trip_ev.get("actor_id", 0)))
	if has_type("barrel"):
		var bar := last_of_type("barrel")
		var hits := int(bar.get("payload", {}).get("hits", 0))
		if hits > 0:
			bits.append("油桶炸到人")
	if has_type("ambush_armed"):
		bits.append("入伏后再打")
	if has_type("repack"):
		bits.append("弹包续上")
	if has_type("route_choice"):
		var rc := last_of_type("route_choice")
		if bool(rc.get("payload", {}).get("covered", false)):
			bits.append("门锁后紫线改道被你罩住")
		else:
			bits.append("门锁后敌改走备用接近")
	var combo := max_kill_combo()
	if combo >= 2:
		bits.append("连击×%d" % combo)
	if bits.is_empty():
		return "终局摘要：—"
	return "终局摘要：" + "；".join(bits) + "。"


func fingerprint() -> String:
	var parts: PackedStringArray = []
	for ev in events:
		parts.append("%s:%d" % [str(ev["type"]), int(ev["tick"])])
	return ",".join(parts)
