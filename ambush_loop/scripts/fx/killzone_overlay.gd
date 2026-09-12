extends Node2D

## SETUP kill-lane overlay. Pulses so the red route paint reads as a live fan, not a sticker.
## Optional miss_samples mark leaked-route points no living cone or trip covers.

var _t: float = 0.0
var miss_samples: PackedVector2Array = PackedVector2Array()


func set_miss_samples(pts: PackedVector2Array) -> void:
	miss_samples = pts.duplicate()
	queue_redraw()


func _ready() -> void:
	z_index = 3
	set_process(true)


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _draw() -> void:
	for p in miss_samples:
		draw_circle(p, 7.0, Color(0.72, 0.18, 0.10, 0.16))
		draw_circle(p, 3.4, Color(0.78, 0.28, 0.14, 0.92))
		draw_arc(p, 8.0, 0.0, TAU, 14, Color(0.78, 0.34, 0.16, 0.7), 1.5)


func _process(delta: float) -> void:
	if not visible or (get_child_count() == 0 and miss_samples.is_empty()):
		modulate = Color.WHITE
		return
	if _is_power_saving():
		modulate = Color(1, 1, 1, 0.85)
		return
	_t += delta
	var wave := 0.5 + 0.5 * sin(_t * 5.6)
	modulate = Color(1.08, 1.02, 0.92, 0.62 + 0.38 * wave)
