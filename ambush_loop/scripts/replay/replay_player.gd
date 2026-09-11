class_name ReplayPlayer
extends RefCounted

## Read-only scrubber over BattleLog snapshots (blueprint §4.1).
## Does not re-simulate combat — interpolates recorded presentation frames.

var log: BattleLog = null
var scrub_tick: int = 0
var playing: bool = false


func bind(p_log: BattleLog) -> void:
	log = p_log
	scrub_tick = 0
	playing = false
	if log != null and log.terminal_tick >= 0:
		scrub_tick = log.terminal_tick


func max_tick() -> int:
	if log == null:
		return 0
	if log.terminal_tick >= 0:
		return log.terminal_tick
	if not log.snapshots.is_empty():
		return int(log.snapshots[log.snapshots.size() - 1]["tick"])
	return 0


func set_tick(t: int) -> void:
	scrub_tick = clampi(t, 0, max_tick())


func seek_ratio(r: float) -> void:
	set_tick(int(round(clampf(r, 0.0, 1.0) * float(max_tick()))))


func snapshot_at_or_before(tick: int) -> Dictionary:
	if log == null or log.snapshots.is_empty():
		return {}
	var best: Dictionary = log.snapshots[0]
	for s in log.snapshots:
		if int(s["tick"]) <= tick:
			best = s
		else:
			break
	return best


func events_up_to(tick: int) -> Array:
	var out: Array = []
	if log == null:
		return out
	for ev in log.events:
		if int(ev["tick"]) <= tick:
			out.append(ev)
	return out


func summary_at_scrub(max_count: int = 10) -> PackedStringArray:
	if log == null:
		return PackedStringArray()
	var lines := PackedStringArray()
	var evs := events_up_to(scrub_tick)
	var start := maxi(evs.size() - max_count, 0)
	for i in range(start, evs.size()):
		lines.append(log.format_event(evs[i]))
	return lines
