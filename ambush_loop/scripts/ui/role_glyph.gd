class_name RoleGlyph
extends Control

## Tiny role mark for cards (rifle chevron / MG block / scout diamond).

var role: int = OperatorUnit.Role.RIFLE:
	set(v):
		role = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 18)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	match role:
		OperatorUnit.Role.MG:
			var pts := PackedVector2Array([
				c + Vector2(-7, -4), c + Vector2(7, -4), c + Vector2(6, 6), c + Vector2(-6, 6)
			])
			draw_colored_polygon(pts, Color(0.62, 0.74, 0.38))
			draw_rect(Rect2(c.x - 6, c.y - 1, 12, 2.5), Color(0.18, 0.20, 0.12, 0.85))
		OperatorUnit.Role.SCOUT:
			var pts := PackedVector2Array([
				c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)
			])
			draw_colored_polygon(pts, Color(0.42, 0.78, 0.92))
		_:
			var pts := PackedVector2Array([
				c + Vector2(0, -8), c + Vector2(7, 7), c + Vector2(-7, 7)
			])
			draw_colored_polygon(pts, Color(0.42, 0.72, 0.96))
