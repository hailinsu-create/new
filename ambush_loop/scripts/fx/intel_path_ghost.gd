extends Node2D

## Presentation-only dashed snapshot of a leaked intel path. Not simulated.

var pts: PackedVector2Array = PackedVector2Array()
var col: Color = Color(0.95, 0.28, 0.22, 0.92)


func setup(path: PackedVector2Array, tint: Color) -> void:
	pts = path.duplicate()
	col = tint
	z_index = 5
	queue_redraw()


func _draw() -> void:
	if pts.size() < 2:
		return
	var dash := 11.0
	var gap := 7.0
	for i in range(pts.size() - 1):
		_dashed_segment(pts[i], pts[i + 1], dash, gap)
	draw_circle(pts[pts.size() - 1], 5.5, Color(col.r, col.g, col.b, 0.95))
	draw_circle(pts[0], 3.5, Color(col.r, col.g, col.b, 0.55))


func _dashed_segment(a: Vector2, b: Vector2, dash: float, gap: float) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var pos := 0.0
	var on := true
	while pos < length:
		var span := dash if on else gap
		var npos := minf(pos + span, length)
		if on:
			draw_line(a + dir * pos, a + dir * npos, col, 2.6, true)
		pos = npos
		on = not on
