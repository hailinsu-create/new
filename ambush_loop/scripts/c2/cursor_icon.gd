extends Control

## Drawn glyph that sits under the hardware cursor.

var mode: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var p := Vector2(11, 11)
	var col := Color(0.92, 0.84, 0.42, 0.95)
	match mode:
		1: ## crate
			draw_rect(Rect2(p.x - 7, p.y - 6, 14, 12), Color(0.42, 0.32, 0.16, 0.95))
			draw_rect(Rect2(p.x - 7, p.y - 8, 14, 3), Color(0.28, 0.20, 0.10, 0.95))
		2: ## corpse
			draw_circle(p + Vector2(0, -3), 3.2, col)
			draw_line(p + Vector2(-6, 6), p + Vector2(6, 6), col, 2.0, true)
		3: ## op
			draw_arc(p, 8.0, 0.0, TAU, 16, col, 1.6, true)
			draw_circle(p, 2.0, col)
		4: ## cover
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-8, 6), p + Vector2(8, 6), p + Vector2(6, -2), p + Vector2(-6, -2)
			]), Color(0.38, 0.44, 0.28, 0.95))
		5: ## knife
			draw_line(p + Vector2(-7, 6), p + Vector2(7, -6), col, 2.0, true)
		_:
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), col, 1.4, true)
			draw_line(p + Vector2(0, -8), p + Vector2(0, 8), col, 1.4, true)
			draw_arc(p, 6.0, 0.0, TAU, 14, Color(col.r, col.g, col.b, 0.45), 1.0, true)
