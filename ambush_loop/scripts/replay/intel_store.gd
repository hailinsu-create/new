class_name IntelStore
extends RefCounted

## Cross-loop memory: limited ghost paths with life index + cut-off time.

const MAX_RECORDS := 5

var records: Array = [] # {loop, path:PackedVector2Array, cut_sec:float, reason:String}


func clear() -> void:
	records.clear()


func add_path(loop_i: int, path: PackedVector2Array, cut_sec: float, reason: String) -> void:
	if path.size() < 2:
		return
	records.append({
		"loop": loop_i,
		"path": path.duplicate(),
		"cut_sec": cut_sec,
		"reason": reason,
	})
	while records.size() > MAX_RECORDS:
		records.pop_front()


func recent(n: int = 3) -> Array:
	if records.is_empty():
		return []
	var start := maxi(records.size() - n, 0)
	return records.slice(start, records.size())
