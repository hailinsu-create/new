class_name C2SoundRing
extends Node2D

## Expanding hear-ring. Footsteps / whistle / crate lid.

var _r: float = 8.0
var _max_r: float = 72.0
var _a: float = 0.55
var _col: Color = Color(0.82, 0.78, 0.42, 0.45)


func boom(world: Vector2, radius: float, col: Color = Color(0.82, 0.78, 0.42, 0.45)) -> void:
	global_position = world
	_r = 6.0
	_max_r = maxf(radius, 18.0)
	_a = 0.55
	_col = col
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_r += delta * 140.0
	_a = maxf(_a - delta * 0.85, 0.0)
	if _r >= _max_r or _a <= 0.02:
		visible = false
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := _col
	c.a = _a
	draw_arc(Vector2.ZERO, _r, 0.0, TAU, 28, c, 1.6, true)
	var c2 := c
	c2.a *= 0.4
	draw_arc(Vector2.ZERO, _r * 0.72, 0.0, TAU, 22, c2, 1.1, true)
