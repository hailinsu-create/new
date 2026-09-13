class_name RaidDirector
extends RefCounted

## Wave index + phase labels. Main owns entities; this owns raid bookkeeping.

const PHASE_SCOUT := "scout"
const PHASE_ALERT := "alert"
const PHASE_SWEEP := "sweep"
const PHASE_FAIL := "fail"
const PHASE_WIN := "win"
const PHASE_REPLAY := "replay"

var wave_index: int = 0
var waves_cleared: int = 0
var awaiting_extract: bool = false


func reset() -> void:
	wave_index = 0
	waves_cleared = 0
	awaiting_extract = false


func wave_count(level: LevelDef) -> int:
	if level == null:
		return 1
	if level.has_method("wave_count"):
		return maxi(1, int(level.wave_count()))
	if "waves" in level and level.waves is Array and not level.waves.is_empty():
		return level.waves.size()
	return 1


func current_spawns(level: LevelDef) -> Array:
	if level == null:
		return []
	if level.has_method("spawns_for_wave"):
		return level.spawns_for_wave(wave_index)
	if "waves" in level and level.waves is Array and wave_index >= 0 and wave_index < level.waves.size():
		return level.waves[wave_index]
	return level.spawn_schedule


func is_last_wave(level: LevelDef) -> bool:
	return wave_index >= wave_count(level) - 1


func mark_wave_cleared() -> void:
	waves_cleared += 1
	awaiting_extract = false


func advance_wave() -> void:
	wave_index += 1
	awaiting_extract = false


func label_for_main_phase(phase_i: int) -> String:
	## Main.Phase ordinal: SETUP=0 WATCHING=1 SWEEP=2 FAILED=3 WON=4 REPLAY=5
	match phase_i:
		0:
			return PHASE_SCOUT
		1:
			return PHASE_ALERT
		2:
			return PHASE_SWEEP
		3:
			return PHASE_FAIL
		4:
			return PHASE_WIN
		5:
			return PHASE_REPLAY
		_:
			return ""


func hud_chip(phase_i: int, wave: int, total: int, sim_t: float, paused: bool, speed: float) -> String:
	match phase_i:
		0:
			return "阶段 · 搜刮埋伏  波次 %d/%d" % [wave + 1, total]
		1:
			var spd := "暂停" if paused else ("2×" if speed >= 1.5 else "1×")
			return "警报中  第%d/%d波  %s  t=%.1fs" % [wave + 1, total, spd, sim_t]
		2:
			if wave >= total - 1:
				return "打扫战场  最后一波 · 空格撤离"
			return "打扫战场  空格拉第%d波" % [wave + 2]
		3:
			return "阶段 · 失败"
		4:
			return "阶段 · 封锁成功"
		5:
			return "阶段 · 只读复盘"
		_:
			return ""
