class_name SimClock
extends RefCounted

## Fixed-step simulation clock (blueprint §5). Pause does not advance ticks.
## 2x runs more steps per real second; step size stays constant.

const TICK_HZ := 60.0
const TICK_DT := 1.0 / TICK_HZ

var paused: bool = false
var speed: float = 1.0 # 1.0 or 2.0
var tick: int = 0
var _accum: float = 0.0


func reset() -> void:
	tick = 0
	_accum = 0.0
	paused = false
	speed = 1.0


func set_speed(s: float) -> void:
	speed = 1.0 if s < 1.5 else 2.0


func toggle_pause() -> void:
	paused = not paused


## Returns how many sim steps to run this frame.
func steps_for_frame(real_delta: float) -> int:
	if paused:
		return 0
	_accum += real_delta * speed
	var n := 0
	while _accum >= TICK_DT:
		_accum -= TICK_DT
		n += 1
		if n >= 8: # safety cap
			_accum = 0.0
			break
	return n


func advance() -> void:
	tick += 1


func time_sec() -> float:
	return float(tick) * TICK_DT
