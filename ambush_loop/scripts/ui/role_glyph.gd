extends Control

## Tiny role mark for cards: mini human + kit (rifle / MG+bipod / scout cloak).

var role: int = 0:
	set(v):
		role = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(26, 26)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.58)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-6, 7), c + Vector2(6, 7), c + Vector2(4.5, 10.2), c + Vector2(-4.5, 10.2)
		]),
		Color(0.04, 0.05, 0.03, 0.55)
	)
	match role:
		1:
			_draw_mg(c)
		2:
			_draw_scout(c)
		_:
			_draw_rifle(c)


func _draw_rifle(c: Vector2) -> void:
	var kit := Color(0.46, 0.62, 0.48)
	var body := PackedVector2Array([
		c + Vector2(0, -10.2), c + Vector2(-3.4, -8.6), c + Vector2(-5.6, -4.0),
		c + Vector2(-4.6, 2.2), c + Vector2(-5.4, 8.6), c + Vector2(-2.4, 8.8),
		c + Vector2(-1.6, 3.0), c + Vector2(0, 1.4), c + Vector2(1.6, 3.0),
		c + Vector2(2.4, 8.8), c + Vector2(5.4, 8.6), c + Vector2(4.6, 2.2),
		c + Vector2(5.6, -4.0), c + Vector2(3.4, -8.6)
	])
	draw_colored_polygon(body, kit)
	draw_circle(c + Vector2(0, -9.4), 3.1, kit.darkened(0.22))
	draw_rect(Rect2(c.x - 2.4, c.y + 7.4, 2.6, 2.4), Color(0.10, 0.10, 0.08, 0.95))
	draw_rect(Rect2(c.x + 0.2, c.y + 7.4, 2.6, 2.4), Color(0.12, 0.12, 0.09, 0.95))
	draw_rect(Rect2(c.x + 1.0, c.y - 7.2, 2.0, 12.2), Color(0.12, 0.14, 0.12, 0.95))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.14, 0.12, 0.95), 1.15, true)


func _draw_mg(c: Vector2) -> void:
	var kit := Color(0.62, 0.72, 0.32)
	var body := PackedVector2Array([
		c + Vector2(-4.8, -8.6), c + Vector2(4.8, -8.6), c + Vector2(7.4, -3.0),
		c + Vector2(6.2, 3.0), c + Vector2(6.6, 8.6), c + Vector2(2.6, 8.8),
		c + Vector2(1.8, 3.2), c + Vector2(0, 1.8), c + Vector2(-1.8, 3.2),
		c + Vector2(-2.6, 8.8), c + Vector2(-6.6, 8.6), c + Vector2(-6.2, 3.0),
		c + Vector2(-7.4, -3.0)
	])
	draw_colored_polygon(body, kit)
	draw_rect(Rect2(c.x - 4.6, c.y - 10.8, 9.2, 3.4), kit.darkened(0.32))
	draw_rect(Rect2(c.x - 1.7, c.y - 8.0, 3.4, 9.0), Color(0.16, 0.14, 0.08, 0.95))
	draw_line(c + Vector2(-5.6, -6), c + Vector2(-7.4, -0.6), Color(0.16, 0.14, 0.08, 0.95), 1.7, true)
	draw_line(c + Vector2(5.6, -6), c + Vector2(7.4, -0.6), Color(0.16, 0.14, 0.08, 0.95), 1.7, true)
	draw_rect(Rect2(c.x - 3.2, c.y + 7.2, 2.8, 2.6), Color(0.12, 0.10, 0.06, 0.95))
	draw_rect(Rect2(c.x + 0.6, c.y + 7.2, 2.8, 2.6), Color(0.14, 0.12, 0.06, 0.95))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.10, 0.14, 0.06, 0.95), 1.15, true)


func _draw_scout(c: Vector2) -> void:
	var kit := Color(0.32, 0.58, 0.46)
	var cape := PackedVector2Array([
		c + Vector2(-3.4, -6.6), c + Vector2(3.4, -6.6),
		c + Vector2(7.6, 4.2), c + Vector2(0, 7.4), c + Vector2(-7.6, 4.2)
	])
	draw_colored_polygon(cape, Color(0.10, 0.20, 0.16, 0.88))
	var body := PackedVector2Array([
		c + Vector2(0, -10.4), c + Vector2(-2.6, -8.6), c + Vector2(-3.6, -4.0),
		c + Vector2(-3.0, 2.4), c + Vector2(-3.8, 8.2), c + Vector2(-1.5, 8.4),
		c + Vector2(-1.0, 3.0), c + Vector2(0, 1.6), c + Vector2(1.0, 3.0),
		c + Vector2(1.5, 8.4), c + Vector2(3.8, 8.2), c + Vector2(3.0, 2.4),
		c + Vector2(3.6, -4.0), c + Vector2(2.6, -8.6)
	])
	draw_colored_polygon(body, kit)
	draw_circle(c + Vector2(0, -9.6), 2.7, kit.darkened(0.28))
	draw_rect(Rect2(c.x - 2.0, c.y - 9.4, 4.0, 1.6), Color(0.42, 0.78, 0.52, 0.90))
	draw_rect(Rect2(c.x - 0.6, c.y - 8.0, 1.2, 11.2), Color(0.10, 0.14, 0.12, 0.95))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.18, 0.14, 0.95), 1.15, true)
