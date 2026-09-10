extends Control

## Tiny role mark for cards: mini human + kit (rifle / MG+bipod / scout cloak).

var role: int = 0:
	set(v):
		role = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.55)
	match role:
		1:
			_draw_mg(c)
		2:
			_draw_scout(c)
		_:
			_draw_rifle(c)


func _draw_rifle(c: Vector2) -> void:
	var kit := Color(0.52, 0.72, 0.92)
	var body := PackedVector2Array([
		c + Vector2(0, -10), c + Vector2(-3.2, -8.4), c + Vector2(-5.4, -4.2),
		c + Vector2(-4.4, 2.0), c + Vector2(-5.2, 9.2), c + Vector2(-2.2, 9.2),
		c + Vector2(-1.6, 3.2), c + Vector2(0, 1.6), c + Vector2(1.6, 3.2),
		c + Vector2(2.2, 9.2), c + Vector2(5.2, 9.2), c + Vector2(4.4, 2.0),
		c + Vector2(5.4, -4.2), c + Vector2(3.2, -8.4)
	])
	draw_colored_polygon(body, kit)
	draw_circle(c + Vector2(0, -9.2), 3.0, kit.darkened(0.25))
	draw_rect(Rect2(c.x + 1.2, c.y - 7.0, 2.0, 12.0), Color(0.12, 0.14, 0.16, 0.95))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.14, 0.24, 0.95), 1.2, true)


func _draw_mg(c: Vector2) -> void:
	var kit := Color(0.68, 0.78, 0.36)
	var body := PackedVector2Array([
		c + Vector2(-4.6, -8.4), c + Vector2(4.6, -8.4), c + Vector2(7.2, -3.2),
		c + Vector2(6.0, 3.0), c + Vector2(6.4, 9.0), c + Vector2(2.6, 9.0),
		c + Vector2(1.8, 3.4), c + Vector2(0, 2.0), c + Vector2(-1.8, 3.4),
		c + Vector2(-2.6, 9.0), c + Vector2(-6.4, 9.0), c + Vector2(-6.0, 3.0),
		c + Vector2(-7.2, -3.2)
	])
	draw_colored_polygon(body, kit)
	draw_rect(Rect2(c.x - 4.4, c.y - 10.6, 8.8, 3.2), kit.darkened(0.35))
	draw_rect(Rect2(c.x - 1.6, c.y - 8.0, 3.2, 9.0), Color(0.16, 0.14, 0.08, 0.95))
	draw_line(c + Vector2(-5.5, -6), c + Vector2(-7.2, -1), Color(0.18, 0.16, 0.08, 0.95), 1.6, true)
	draw_line(c + Vector2(5.5, -6), c + Vector2(7.2, -1), Color(0.18, 0.16, 0.08, 0.95), 1.6, true)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.10, 0.14, 0.06, 0.95), 1.2, true)


func _draw_scout(c: Vector2) -> void:
	var kit := Color(0.38, 0.82, 0.92)
	var cape := PackedVector2Array([
		c + Vector2(-3.2, -6.5), c + Vector2(3.2, -6.5),
		c + Vector2(7.4, 4.0), c + Vector2(0, 7.2), c + Vector2(-7.4, 4.0)
	])
	draw_colored_polygon(cape, Color(0.12, 0.28, 0.32, 0.85))
	var body := PackedVector2Array([
		c + Vector2(0, -10.2), c + Vector2(-2.4, -8.4), c + Vector2(-3.4, -4.0),
		c + Vector2(-2.8, 2.4), c + Vector2(-3.6, 8.6), c + Vector2(-1.4, 8.6),
		c + Vector2(-1.0, 3.2), c + Vector2(0, 1.8), c + Vector2(1.0, 3.2),
		c + Vector2(1.4, 8.6), c + Vector2(3.6, 8.6), c + Vector2(2.8, 2.4),
		c + Vector2(3.4, -4.0), c + Vector2(2.4, -8.4)
	])
	draw_colored_polygon(body, kit)
	draw_circle(c + Vector2(0, -9.4), 2.6, kit.darkened(0.30))
	draw_circle(c + Vector2(-1.6, -8.8), 1.4, Color(0.12, 0.22, 0.28, 0.9))
	draw_circle(c + Vector2(1.6, -8.8), 1.4, Color(0.12, 0.22, 0.28, 0.9))
	draw_rect(Rect2(c.x - 0.6, c.y - 8.0, 1.2, 11.0), Color(0.10, 0.14, 0.18, 0.95))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.20, 0.26, 0.95), 1.2, true)
