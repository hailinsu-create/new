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
			_pool(Vector2(26.4 * t, 11.4 * t), 28.0, Color(0.90, 0.50, 0.10, 0.07 if saving else 0.11))
		"pump":
			_pool(Vector2(17.5 * t, 12.2 * t), 52.0, Color(0.42, 0.48, 0.28, 0.11 if saving else 0.17))
			_pool(Vector2(13.5 * t, 15.4 * t), 38.0, Color(0.28, 0.36, 0.24, 0.09 if saving else 0.13))
			_pool(Vector2(10.4 * t, 14.2 * t), 28.0, Color(0.36, 0.42, 0.26, 0.07 if saving else 0.11))
			_pool(Vector2(26.4 * t, 13.4 * t), 22.0, Color(0.40, 0.46, 0.28, 0.06 if saving else 0.10))
		"railcut":
			_pool(Vector2(21.5 * t, 11.0 * t), 54.0, Color(0.48, 0.46, 0.38, 0.09 if saving else 0.14))
			_pool(Vector2(13.5 * t, 7.5 * t), 34.0, Color(0.62, 0.60, 0.48, 0.07 if saving else 0.11))
			_pool(Vector2(32.5 * t, 7.5 * t), 34.0, Color(0.62, 0.60, 0.48, 0.07 if saving else 0.11))
			_pool(Vector2(11.4 * t, 10.4 * t), 20.0, Color(0.85, 0.32, 0.16, 0.06 if saving else 0.10))
		"depot":
			_pool(Vector2(19.0 * t, 12.0 * t), 60.0, Color(0.95, 0.42, 0.10, 0.11 if saving else 0.18))
			_pool(Vector2(26.0 * t, 14.2 * t), 42.0, Color(0.90, 0.38, 0.10, 0.09 if saving else 0.13))
			_pool(Vector2(12.0 * t, 8.0 * t), 38.0, Color(0.55, 0.70, 0.82, 0.07 if saving else 0.11))
			_pool(Vector2(28.6 * t, 11.4 * t), 22.0, Color(0.92, 0.40, 0.10, 0.06 if saving else 0.10))
		"radio":
			# Lighthouse wash on the tower, phosphor strip down the echo hall (x=24).
			_pool(Vector2(18.6 * t, 10.2 * t), 62.0, Color(0.62, 0.68, 0.52, 0.10 if saving else 0.16))
			_pool(Vector2(26.8 * t, 9.6 * t), 40.0, Color(0.70, 0.72, 0.54, 0.08 if saving else 0.13))
			_pool(Vector2(13.6 * t, 8.4 * t), 32.0, Color(0.58, 0.62, 0.48, 0.07 if saving else 0.11))
			_pool(Vector2(27.6 * t, 8.2 * t), 20.0, Color(0.66, 0.68, 0.50, 0.06 if saving else 0.10))
			var echo_a := 0.07 if saving else 0.12
			for i in 5:
				_pool(Vector2(24.5 * t, (7.2 + float(i) * 2.0) * t), 16.0, Color(0.58, 0.62, 0.46, echo_a))
		_:
			_pool(Vector2(30.5 * t, 6.4 * t), 76.0, Color(0.78, 0.76, 0.62, 0.12 if saving else 0.20))
			_pool(Vector2(18.5 * t, 11.0 * t), 44.0, Color(0.52, 0.46, 0.28, 0.07 if saving else 0.12))
			_pool(Vector2(33.5 * t, 7.2 * t), 30.0, Color(0.86, 0.58, 0.22, 0.09 if saving else 0.14))
			_pool(Vector2(10.6 * t, 8.4 * t), 32.0, Color(0.58, 0.52, 0.32, 0.06 if saving else 0.10))
			_pool(Vector2(10.6 * t, 16.6 * t), 26.0, Color(0.36, 0.32, 0.18, 0.05 if saving else 0.09))
			_pool(Vector2(7.6 * t, 16.4 * t), 20.0, Color(0.22, 0.16, 0.08, 0.05 if saving else 0.09))
			_pool(Vector2(24.2 * t, 8.6 * t), 28.0, Color(0.70, 0.66, 0.48, 0.05 if saving else 0.09))


func _pool(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r, col)
	draw_circle(p, r * 0.58, Color(col.r, col.g, col.b, col.a * 1.15))
	draw_circle(p, r * 0.28, Color(col.r, col.g, col.b, col.a * 1.55))


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())
