class_name C2AlertMark
extends Node2D

## Commandos ? / ! over a sentry. Yellow suspicious, red alert, Z when KO.

enum Kind { NONE, QUESTION, BANG, SLEEP }

var kind: int = Kind.NONE:
	set(v):
		kind = v
		visible = kind != Kind.NONE
		queue_redraw()

var _t: float = 0.0


func _ready() -> void:
	z_index = 12
	position = Vector2(0, -28)


func _process(delta: float) -> void:
	if kind == Kind.NONE:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.QUESTION:
			_balloon("?", Color(0.96, 0.86, 0.22))
		Kind.BANG:
			_balloon("!", Color(0.92, 0.22, 0.14))
			draw_circle(Vector2(0, -22), 3.0 + absf(sin(_t * 8.0)) * 2.0, Color(0.92, 0.22, 0.14, 0.25))
		Kind.SLEEP:
			_sleep_z()


func _balloon(ch: String, col: Color) -> void:
	var bob := sin(_t * 6.0) * 1.4
	var bg := Color(0.08, 0.06, 0.04, 0.88)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -12 + bob), Vector2(8, -12 + bob), Vector2(8, 4 + bob),
		Vector2(2, 4 + bob), Vector2(0, 10 + bob), Vector2(-2, 4 + bob), Vector2(-8, 4 + bob)
	]), bg)
	draw_circle(Vector2(0, -4 + bob), 1.2, col)
	var f := ThemeDB.fallback_font
	if f:
		draw_string(f, Vector2(-5, -1 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _sleep_z() -> void:
	var f := ThemeDB.fallback_font
	var col := Color(0.72, 0.78, 0.88, 0.85)
	if f:
		draw_string(f, Vector2(4, -6 - sin(_t * 2.2) * 3.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		draw_string(f, Vector2(10, -14 - sin(_t * 2.2 + 0.8) * 3.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
