class_name IntelStore
extends RefCounted

## Cross-loop memory: limited ghost paths with life index + cut-off time.

const MAX_RECORDS := 5

var records: Array = [] # {loop, path:PackedVector2Array, cut_sec:float, reason:String}


func clear() -> void:
	records.clear()


func add_path(
	loop_i: int,
	path: PackedVector2Array,
	cut_sec: float,
	reason: String,
	hint: String = "",
	route: String = "",
	leak_tick: int = -1,
	leaker_id: int = -1
) -> void:
	if path.size() < 2:
		return
	var summary := "第%d世 · %s · %.1fs" % [loop_i, BattleLog.reason_zh(reason), cut_sec]
	if hint != "":
		summary += " · " + hint
	var tick := leak_tick
	if tick < 0:
		tick = int(round(cut_sec * 60.0))
	records.append({
		"loop": loop_i,
		"path": path.duplicate(),
		"cut_sec": cut_sec,
		"reason": reason,
		"hint": hint,
		"route": route,
		"leak_tick": tick,
		"leaker_id": leaker_id,
		"summary": summary,
	})
	while records.size() > MAX_RECORDS:
		records.pop_front()


func recent(n: int = 3) -> Array:
	if records.is_empty():
		return []
	var start := maxi(records.size() - n, 0)
	return records.slice(start, records.size())


func latest_line() -> String:
	if records.is_empty():
		return ""
	return str(records[records.size() - 1].get("summary", ""))


func latest_hint() -> String:
	if records.is_empty():
		return ""
	return str(records[records.size() - 1].get("hint", ""))


func latest_route() -> String:
	if records.is_empty():
		return ""
	return str(records[records.size() - 1].get("route", ""))


func latest_leak_tick() -> int:
	if records.is_empty():
		return -1
	return int(records[records.size() - 1].get("leak_tick", -1))


func latest_leaker_id() -> int:
	if records.is_empty():
		return -1
	return int(records[records.size() - 1].get("leaker_id", -1))


func wall_text(n: int = 4) -> String:
	## Fail-panel dossier of recent loops. Presentation only.
	if records.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("—— 情报墙 ——")
	for rec in recent(n):
		var summary := str(rec.get("summary", "")).strip_edges()
		if summary == "":
			continue
		lines.append(summary)
	if lines.size() <= 1:
		return ""
	return "\n".join(lines)


func leak_advice_line(level, route_zh: String) -> String:
	## Presentation math: how long that leaker walked after their authored spawn.
	if records.is_empty():
		return ""
	var rec: Dictionary = records[records.size() - 1]
	if str(rec.get("reason", "")) != "escape":
		return ""
	var route := str(rec.get("route", ""))
	var lid := int(rec.get("leaker_id", -1))
	var spawn_d := 0.0
	if level != null and lid >= 1 and level.has_method("delay_for_actor"):
		spawn_d = float(level.delay_for_actor(lid))
	elif level != null and route != "" and level.has_method("first_route_delay"):
		spawn_d = float(level.first_route_delay(route))
	var tick := int(rec.get("leak_tick", -1))
	var leak_sec := float(tick) / 60.0 if tick >= 0 else float(rec.get("cut_sec", 0.0))
	var ahead := maxf(0.1, leak_sec - spawn_d)
	var wing := route_zh if route_zh != "" else "侧翼"
	var core := ""
	if lid >= 1:
		core = "建议在 %.1f 秒前加强%s（敌%d）" % [ahead, wing, lid]
	else:
		core = "建议在 %.1f 秒前加强%s" % [ahead, wing]
	var hint := str(rec.get("hint", "")).strip_edges()
	if hint != "":
		return "改一处就能赢：%s。%s" % [hint, core]
	return "改一处就能赢：%s" % core
