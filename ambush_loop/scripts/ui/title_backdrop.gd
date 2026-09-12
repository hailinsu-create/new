extends Node2D

## Asphalt night courtyard + drifting route traces for the title screen.

var t: float = 0.0
var _routes: Array[PackedVector2Array] = []
var _dust: CPUParticles2D = null
var _sparks: CPUParticles2D = null
var _focus_paused: bool = false


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
		PackedVector2Array([
			Vector2(40, 360), Vector2(180, 420), Vector2(320, 560), Vector2(520, 620)
		]),
	]
	_dust = _make_particles(28, 7.5, Color(0.42, 0.36, 0.22, 0.28), Vector2(0.15, -1.0), 10.0)
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 12.0
	_dust.gravity = Vector2(4.0, 6.0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.6
	add_child(_dust)
	_sparks = _make_particles(14, 3.2, Color(0.72, 0.52, 0.22, 0.55), Vector2(0.35, -1.0), 18.0)
	_sparks.initial_velocity_min = 12.0
	_sparks.initial_velocity_max = 28.0
	_sparks.gravity = Vector2(2.0, 14.0)
	_sparks.scale_amount_min = 0.4
	_sparks.scale_amount_max = 1.1
	add_child(_sparks)
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and not gs.changed.is_connected(_apply_quality_tier):
		gs.changed.connect(_apply_quality_tier)
	_apply_quality_tier()


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func set_background_paused(on: bool) -> void:
	_focus_paused = on
	_apply_quality_tier()


func _particles_suppressed() -> bool:
	return _focus_paused or _is_power_saving()


func _apply_quality_tier() -> void:
	var saving := _particles_suppressed()
	if _dust:
		_dust.emitting = not saving
		_dust.visible = not saving
		if not saving:
			_dust.restart()
	if _sparks:
		_sparks.emitting = not saving
		_sparks.visible = not saving
		if not saving:
			_sparks.restart()
	set_process(not saving)
	if saving:
		t = 0.0
	queue_redraw()


func _make_particles(amount: int, lifetime: float, col: Color, dir: Vector2, spread: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = 2.4
	p.emitting = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640, 360)
	p.position = Vector2(640, 360)
	p.direction = dir
	p.spread = spread
	p.color = col
	p.local_coords = false
	return p


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var sz := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.022, 0.032, 0.026))
	# Sky bands, olive not purple.
	for i in 10:
		var a := 0.035 + float(i) * 0.010
		draw_rect(Rect2(0.0, float(i) * 18.0, sz.x, 22.0), Color(0.04, 0.06, 0.04, a))
	for i in 16:
		var a := 0.050 + float(i) * 0.014
		draw_rect(
			Rect2(0.0, sz.y - float(16 - i) * 18.0, sz.x, 20.0),
			Color(0.08, 0.11, 0.06, a)
		)
	var moon := Vector2(sz.x * 0.84, 74.0)
	var breathe := 0.0 if _particles_suppressed() else (0.5 + 0.5 * sin(t * 0.55))
	draw_circle(moon, 92.0 + breathe * 6.0, Color(0.72, 0.68, 0.48, 0.07 + 0.03 * breathe))
	draw_circle(moon, 48.0, Color(0.80, 0.76, 0.56, 0.14 + 0.04 * breathe))
	draw_circle(moon, 22.0, Color(0.88, 0.84, 0.66, 0.42 + 0.08 * breathe))
	draw_circle(moon, 11.0, Color(0.94, 0.90, 0.74, 0.82))
	draw_circle(moon + Vector2(-4, 3), 3.2, Color(0.78, 0.82, 0.68, 0.35))
	draw_circle(moon + Vector2(5, -2), 2.0, Color(0.80, 0.84, 0.70, 0.28))
	# Cloud bands across the moon.
	draw_rect(Rect2(sz.x * 0.62, 48.0, sz.x * 0.34, 14.0), Color(0.04, 0.06, 0.04, 0.22))
	draw_rect(Rect2(sz.x * 0.70, 92.0, sz.x * 0.28, 10.0), Color(0.05, 0.07, 0.05, 0.18))
	_draw_courtyard(sz)
	var step := 44.0
	var drift := 0.0 if _particles_suppressed() else fmod(t * 6.0, step)
	var grid_c := Color(0.22, 0.28, 0.18, 0.10)
	var x := -step + drift * 0.25
	while x < sz.x + step:
		draw_line(Vector2(x, sz.y * 0.42), Vector2(x, sz.y), grid_c, 1.0)
		x += step
	var y := sz.y * 0.42 - step + drift * 0.12
	while y < sz.y + step:
		draw_line(Vector2(0.0, y), Vector2(sz.x, y), grid_c, 1.0)
		y += step
	var off := Vector2.ZERO if _particles_suppressed() else Vector2(sin(t * 0.32) * 14.0, cos(t * 0.21) * 9.0)
	var cols := [
		Color(0.82, 0.90, 0.42, 0.52),
		Color(0.68, 0.78, 0.38, 0.40),
		Color(0.95, 0.84, 0.42, 0.32),
		Color(0.62, 0.52, 0.28, 0.38),
	]
	for i in _routes.size():
		var shifted := PackedVector2Array()
		for p in _routes[i]:
			shifted.append(p + off * (0.65 + float(i) * 0.18))
		if shifted.size() >= 2:
			if not _particles_suppressed():
				draw_polyline(shifted, Color(cols[i % cols.size()].r, cols[i % cols.size()].g, cols[i % cols.size()].b, 0.16), 6.0, true)
			draw_polyline(shifted, cols[i % cols.size()], 3.0, true)
	_draw_ops_stamps(sz)
	if not _particles_suppressed():
		for i in 20:
			var px := fposmod(sz.x * _frac(i + 3) + t * (7.0 + float(i) * 0.35), sz.x)
			var py := fposmod(sz.y * _frac(i + 11) - t * (5.0 + float(i) * 0.18), sz.y)
			var pa := 0.12 + 0.16 * _frac(i + 19)
			draw_circle(Vector2(px, py), 1.0 + _frac(i) * 1.4, Color(0.90, 0.84, 0.42, pa))
	for i in 16:
		var inset := float(i) * 16.0
		var va := 0.055
		draw_rect(Rect2(0.0, 0.0, sz.x, inset), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(0.0, sz.y - inset, sz.x, inset), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(0.0, 0.0, inset, sz.y), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(sz.x - inset, 0.0, inset, sz.y), Color(0.01, 0.02, 0.02, va))


func _draw_courtyard(sz: Vector2) -> void:
	# Far wall mass.
	draw_rect(Rect2(0.0, sz.y * 0.38, sz.x, 28.0), Color(0.10, 0.08, 0.05, 0.55))
	draw_rect(Rect2(0.0, sz.y * 0.38, sz.x, 4.0), Color(0.42, 0.34, 0.16, 0.45))
	# Building blocks left / right.
	draw_rect(Rect2(0.0, sz.y * 0.22, 210.0, sz.y * 0.18), Color(0.07, 0.06, 0.04, 0.70))
	draw_rect(Rect2(sz.x - 240.0, sz.y * 0.18, 240.0, sz.y * 0.22), Color(0.08, 0.06, 0.04, 0.68))
	# Windows, warm sodium. 省电 keeps them static.
	var flick := 1.0
	if not _particles_suppressed():
		flick = 0.72 + 0.28 * abs(sin(t * 1.4))
		if fmod(t * 3.1, 1.0) > 0.88:
			flick *= 0.35
	var wins := [
		Vector2(48, sz.y * 0.28), Vector2(92, sz.y * 0.28), Vector2(136, sz.y * 0.28),
		Vector2(sz.x - 190, sz.y * 0.24), Vector2(sz.x - 140, sz.y * 0.24), Vector2(sz.x - 90, sz.y * 0.24),
	]
	for i in wins.size():
		var p: Vector2 = wins[i]
		var a := 0.38 * (0.7 if i == 2 and not _particles_suppressed() else flick)
		draw_rect(Rect2(p.x, p.y, 22.0, 14.0), Color(0.95, 0.72, 0.28, a))
		draw_rect(Rect2(p.x + 2.0, p.y + 2.0, 18.0, 10.0), Color(1.0, 0.84, 0.42, a * 0.55))
	# Gate shadow at the south.
	draw_rect(Rect2(sz.x * 0.38, sz.y * 0.78, sz.x * 0.24, 18.0), Color(0.02, 0.03, 0.02, 0.40))
	# Tree mass, west.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(70, sz.y * 0.72), Vector2(110, sz.y * 0.72),
			Vector2(98, sz.y * 0.52), Vector2(82, sz.y * 0.52)
		]),
		Color(0.08, 0.07, 0.04, 0.70)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(90, sz.y * 0.40), Vector2(150, sz.y * 0.58),
			Vector2(90, sz.y * 0.54), Vector2(30, sz.y * 0.58)
		]),
		Color(0.10, 0.16, 0.08, 0.55)
	)
	# Radio dish on the east roof — campaign finale silhouette.
	var dish := Vector2(sz.x - 150.0, sz.y * 0.20)
	draw_arc(dish, 34.0, -2.5, 0.5, 12, Color(0.58, 0.50, 0.32, 0.45), 3.2, true)
	draw_line(dish, dish + Vector2(18, -16), Color(0.70, 0.58, 0.32, 0.55), 1.8, true)
	draw_circle(dish + Vector2(18, -16), 3.4, Color(0.82, 0.70, 0.40, 0.70))
	draw_rect(Rect2(dish.x - 4.0, dish.y, 8.0, 28.0), Color(0.12, 0.10, 0.08, 0.70))


func _draw_ops_stamps(sz: Vector2) -> void:
	var base_y := sz.y * 0.86
	_stamp_figure(Vector2(sz.x * 0.18, base_y), Color(0.42, 0.38, 0.24), 0)
	_stamp_figure(Vector2(sz.x * 0.50, base_y), Color(0.48, 0.42, 0.22), 1)
	_stamp_figure(Vector2(sz.x * 0.82, base_y), Color(0.26, 0.44, 0.38), 2)


func _stamp_figure(c: Vector2, kit: Color, kind: int) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-18, 10), c + Vector2(18, 10), c + Vector2(12, 18), c + Vector2(-12, 18)
		]),
		Color(0.02, 0.03, 0.02, 0.50)
	)
	if kind == 2:
		draw_colored_polygon(
			PackedVector2Array([
				c + Vector2(-10, -18), c + Vector2(10, -18),
				c + Vector2(22, 8), c + Vector2(0, 14), c + Vector2(-22, 8)
			]),
			Color(0.08, 0.16, 0.14, 0.80)
		)
	var w := 14.0 if kind == 1 else (9.0 if kind == 2 else 11.0)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(0, -28), c + Vector2(-w * 0.45, -24), c + Vector2(-w, -12),
			c + Vector2(-w * 0.85, 2), c + Vector2(-w * 0.7, 16), c + Vector2(-5, 16),
			c + Vector2(-3, 4), c + Vector2(0, 1), c + Vector2(3, 4),
			c + Vector2(5, 16), c + Vector2(w * 0.7, 16), c + Vector2(w * 0.85, 2),
			c + Vector2(w, -12), c + Vector2(w * 0.45, -24)
		]),
		kit
	)
	draw_circle(c + Vector2(0, -26), 5.2 if kind == 1 else 4.2, kit.darkened(0.28))
	if kind == 1:
		draw_rect(Rect2(c.x - 8, c.y - 32, 16, 5), kit.darkened(0.35))
		draw_rect(Rect2(c.x - 2.2, c.y - 22, 4.4, 18), Color(0.14, 0.12, 0.08, 0.95))
	elif kind == 2:
		draw_rect(Rect2(c.x - 3.2, c.y - 28, 6.4, 2.2), Color(0.42, 0.78, 0.52, 0.90))
		draw_rect(Rect2(c.x - 0.8, c.y - 22, 1.6, 20), Color(0.10, 0.14, 0.12, 0.95))
	else:
		draw_rect(Rect2(c.x + 1.0, c.y - 20, 2.4, 22), Color(0.12, 0.14, 0.12, 0.95))


func _frac(n: int) -> float:
	var s := sin(float(n) * 12.9898) * 43758.5453
	return s - floor(s)
