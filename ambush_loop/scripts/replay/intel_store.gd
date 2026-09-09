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
	route: String = ""
) -> void:
	if path.size() < 2:
		return
	var summary := "第%d世 · %s · %.1fs" % [loop_i, BattleLog.reason_zh(reason), cut_sec]
	if hint != "":
		summary += " · " + hint
	records.append({
		"loop": loop_i,
		"path": path.duplicate(),
		"cut_sec": cut_sec,
		"reason": reason,
		"hint": hint,
		"route": route,
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
