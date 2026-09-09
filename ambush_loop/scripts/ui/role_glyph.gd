extends Control

## Tiny role mark for cards (rifle chevron / MG block+bipod / scout diamond+binocs).

var role: int = 0:
	set(v):
		role = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var pts: PackedVector2Array
	match role:
		1:
			# 铁砧 — wide block + bipod feet.
			pts = PackedVector2Array([
				c + Vector2(-8, -5), c + Vector2(8, -5), c + Vector2(7, 6), c + Vector2(-7, 6)
			])
			draw_colored_polygon(pts, Color(0.68, 0.78, 0.36))
			draw_rect(Rect2(c.x - 7, c.y - 1.2, 14, 2.6), Color(0.16, 0.18, 0.10, 0.9))
			draw_line(c + Vector2(-6, 6), c + Vector2(-8, 10), Color(0.18, 0.16, 0.08, 0.95), 1.6, true)
			draw_line(c + Vector2(6, 6), c + Vector2(8, 10), Color(0.18, 0.16, 0.08, 0.95), 1.6, true)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.10, 0.14, 0.06, 0.95), 1.3, true)
		2:
			# 夜枭 — diamond + binocular tubes.
			pts = PackedVector2Array([
				c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)
			])
			draw_colored_polygon(pts, Color(0.38, 0.82, 0.92))
			draw_circle(c + Vector2(-2.4, -1), 2.1, Color(0.12, 0.22, 0.28, 0.9))
			draw_circle(c + Vector2(2.4, -1), 2.1, Color(0.12, 0.22, 0.28, 0.9))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.08, 0.20, 0.26, 0.95), 1.3, true)
		_:
			# 灰狼 — lean chevron + long barrel tick.
			pts = PackedVector2Array([
				c + Vector2(0, -8), c + Vector2(7, 7), c + Vector2(-7, 7)
			])
			draw_colored_polygon(pts, Color(0.52, 0.72, 0.92))
			draw_line(c + Vector2(0, -8), c + Vector2(0, -11), Color(0.12, 0.16, 0.22, 0.95), 1.8, true)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.08, 0.14, 0.24, 0.95), 1.3, true)
