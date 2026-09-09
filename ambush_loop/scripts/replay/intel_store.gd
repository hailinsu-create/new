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
	leak_tick: int = -1
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


func leak_advice_line(spawn_delay_sec: float, route_zh: String) -> String:
	## Presentation math: how long the leaker walked after their authored spawn.
	if records.is_empty():
		return ""
	var rec: Dictionary = records[records.size() - 1]
	if str(rec.get("reason", "")) != "escape":
		return ""
	var tick := int(rec.get("leak_tick", -1))
	var leak_sec := float(tick) / 60.0 if tick >= 0 else float(rec.get("cut_sec", 0.0))
	var ahead := maxf(0.1, leak_sec - spawn_delay_sec)
	var wing := route_zh if route_zh != "" else "侧翼"
	return "建议在 %.1f 秒前加强%s" % [ahead, wing]
