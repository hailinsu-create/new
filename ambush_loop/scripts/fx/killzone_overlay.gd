extends Node2D

## SETUP kill-lane overlay. Pulses so the red route paint reads as a live fan, not a sticker.

var _t: float = 0.0


func _ready() -> void:
	z_index = 3
	set_process(true)


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _process(delta: float) -> void:
	if not visible or get_child_count() == 0:
		modulate = Color.WHITE
		return
	if _is_power_saving():
		modulate = Color(1, 1, 1, 0.85)
		return
	_t += delta
	var wave := 0.5 + 0.5 * sin(_t * 5.6)
	modulate = Color(1.08, 1.02, 0.92, 0.62 + 0.38 * wave)
