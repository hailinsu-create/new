extends Node2D

## Asphalt night grid + drifting route traces for the title screen.

var t: float = 0.0
var _routes: Array[PackedVector2Array] = []


func _ready() -> void:
	_routes = [
		PackedVector2Array([
			Vector2(60, 540), Vector2(260, 430), Vector2(520, 390),
			Vector2(820, 300), Vector2(1180, 210)
		]),
		PackedVector2Array([
			Vector2(30, 200), Vector2(280, 280), Vector2(490, 440),
			Vector2(760, 530), Vector2(1120, 640)
		]),
		PackedVector2Array([
			Vector2(180, 70), Vector2(420, 130), Vector2(740, 110), Vector2(1080, 80)
		]),
	]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var sz := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), NightOps.BG)
	# Bottom olive wash (not a purple gradient).
	for i in 10:
		var a := 0.035 + float(i) * 0.008
		draw_rect(
			Rect2(0.0, sz.y - float(10 - i) * 22.0, sz.x, 22.0),
			Color(0.12, 0.16, 0.08, a)
		)
	# Cooler top vignette.
	draw_rect(Rect2(0.0, 0.0, sz.x, 90.0), Color(0.02, 0.03, 0.03, 0.35))
	var step := 44.0
	var drift := fmod(t * 6.0, step)
	var grid_c := Color(0.22, 0.28, 0.18, 0.11)
	var x := -step + drift * 0.25
	while x < sz.x + step:
		draw_line(Vector2(x, 0.0), Vector2(x, sz.y), grid_c, 1.0)
		x += step
	var y := -step + drift * 0.12
	while y < sz.y + step:
		draw_line(Vector2(0.0, y), Vector2(sz.x, y), grid_c, 1.0)
		y += step
	var off := Vector2(sin(t * 0.32) * 14.0, cos(t * 0.21) * 9.0)
	var cols := [
		Color(0.62, 0.70, 0.36, 0.28),
		Color(0.50, 0.58, 0.32, 0.20),
		Color(0.78, 0.72, 0.38, 0.16),
	]
	for i in _routes.size():
		var shifted := PackedVector2Array()
		for p in _routes[i]:
			shifted.append(p + off * (0.65 + float(i) * 0.18))
		if shifted.size() >= 2:
			draw_polyline(shifted, cols[i % cols.size()], 2.2, true)
