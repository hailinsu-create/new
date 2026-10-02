extends Node2D

## Tiny crouch/sprint mark over the selected commando.

var mode: String = "stand"


func _ready() -> void:
	z_index = 8
	position = Vector2(16, -22)


func set_mode(m: String) -> void:
	mode = m
	visible = mode != "stand"
	queue_redraw()


func _draw() -> void:
	match mode:
		"crouch":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6, 2), Vector2(6, 2), Vector2(4, 7), Vector2(-4, 7)
			]), Color(0.72, 0.78, 0.38, 0.9))
		"sprint":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, -6), Vector2(7, 0), Vector2(-2, 6)
			]), Color(0.92, 0.78, 0.32, 0.9))
		"hide":
			draw_circle(Vector2.ZERO, 5.0, Color(0.22, 0.32, 0.18, 0.8))
