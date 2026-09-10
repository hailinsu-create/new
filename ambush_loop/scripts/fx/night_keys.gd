extends Node2D

## Floor light pools under moon / sodium / vent / beacon / tanks.

var atmosphere_id: String = "yard"


func setup(id: String) -> void:
	atmosphere_id = id if id != "" else "yard"
	name = "NightKeys"
	z_index = 1
	z_as_relative = true
	queue_redraw()


func _draw() -> void:
	var t := float(AmbushGrid.TILE)
	var saving := _is_power_saving()
	match atmosphere_id:
		"warehouse":
			_pool(Vector2(13.5 * t, 8.2 * t), 58.0, Color(0.95, 0.62, 0.14, 0.11 if saving else 0.18))
			_pool(Vector2(24.5 * t, 8.2 * t), 58.0, Color(0.95, 0.62, 0.14, 0.11 if saving else 0.18))
			_pool(Vector2(32.5 * t, 10.4 * t), 46.0, Color(0.92, 0.55, 0.10, 0.09 if saving else 0.14))
		"pump":
			_pool(Vector2(17.5 * t, 12.2 * t), 52.0, Color(0.28, 0.82, 0.62, 0.11 if saving else 0.17))
			_pool(Vector2(13.5 * t, 15.4 * t), 38.0, Color(0.22, 0.70, 0.58, 0.09 if saving else 0.13))
			_pool(Vector2(10.4 * t, 14.2 * t), 28.0, Color(0.32, 0.82, 0.62, 0.07 if saving else 0.11))
		"railcut":
			_pool(Vector2(21.5 * t, 11.0 * t), 54.0, Color(0.55, 0.72, 0.92, 0.09 if saving else 0.14))
			_pool(Vector2(13.5 * t, 7.5 * t), 34.0, Color(0.70, 0.80, 0.95, 0.07 if saving else 0.11))
			_pool(Vector2(32.5 * t, 7.5 * t), 34.0, Color(0.70, 0.80, 0.95, 0.07 if saving else 0.11))
		"depot":
			_pool(Vector2(19.0 * t, 12.0 * t), 60.0, Color(0.95, 0.42, 0.10, 0.11 if saving else 0.18))
			_pool(Vector2(26.0 * t, 14.2 * t), 42.0, Color(0.90, 0.38, 0.10, 0.09 if saving else 0.13))
			_pool(Vector2(12.0 * t, 8.0 * t), 38.0, Color(0.55, 0.70, 0.82, 0.07 if saving else 0.11))
		_:
			_pool(Vector2(30.5 * t, 6.4 * t), 76.0, Color(0.82, 0.90, 0.68, 0.11 if saving else 0.18))
			_pool(Vector2(18.5 * t, 11.0 * t), 44.0, Color(0.70, 0.80, 0.58, 0.07 if saving else 0.12))
			_pool(Vector2(33.5 * t, 7.2 * t), 30.0, Color(1.0, 0.78, 0.32, 0.09 if saving else 0.14))
			_pool(Vector2(10.6 * t, 8.4 * t), 32.0, Color(0.82, 0.90, 0.62, 0.06 if saving else 0.10))


func _pool(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r, col)
	draw_circle(p, r * 0.58, Color(col.r, col.g, col.b, col.a * 1.15))
	draw_circle(p, r * 0.28, Color(col.r, col.g, col.b, col.a * 1.55))


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())
