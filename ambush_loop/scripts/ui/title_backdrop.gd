extends Node2D

## Asphalt night grid + drifting route traces for the title screen.

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
	]
	_dust = _make_particles(28, 7.5, Color(0.72, 0.76, 0.58, 0.28), Vector2(0.15, -1.0), 10.0)
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 12.0
	_dust.gravity = Vector2(4.0, 6.0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.6
	add_child(_dust)
	_sparks = _make_particles(14, 3.2, Color(0.92, 0.84, 0.42, 0.55), Vector2(0.35, -1.0), 18.0)
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
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.028, 0.038, 0.032))
	# Bottom olive wash (not a purple gradient).
	for i in 14:
		var a := 0.045 + float(i) * 0.012
		draw_rect(
			Rect2(0.0, sz.y - float(14 - i) * 22.0, sz.x, 24.0),
			Color(0.10, 0.14, 0.07, a)
		)
	draw_rect(Rect2(0.0, 0.0, sz.x, 110.0), Color(0.01, 0.02, 0.02, 0.48))
	var moon := Vector2(sz.x * 0.84, 78.0)
	draw_circle(moon, 64.0, Color(0.78, 0.86, 0.64, 0.10))
	draw_circle(moon, 28.0, Color(0.88, 0.94, 0.72, 0.22))
	draw_circle(moon, 11.0, Color(0.96, 0.98, 0.86, 0.72))
	draw_rect(Rect2(sz.x * 0.55, 0.0, sz.x * 0.45, 160.0), Color(0.72, 0.80, 0.58, 0.05))
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
		Color(0.82, 0.90, 0.42, 0.52),
		Color(0.68, 0.78, 0.38, 0.40),
		Color(0.95, 0.84, 0.42, 0.32),
	]
	for i in _routes.size():
		var shifted := PackedVector2Array()
		for p in _routes[i]:
			shifted.append(p + off * (0.65 + float(i) * 0.18))
		if shifted.size() >= 2:
			if not _particles_suppressed():
				draw_polyline(shifted, Color(cols[i % cols.size()].r, cols[i % cols.size()].g, cols[i % cols.size()].b, 0.16), 6.0, true)
			draw_polyline(shifted, cols[i % cols.size()], 3.0, true)
	# Manual drifting sparks (readable even if particles are culled).
	if not _particles_suppressed():
		for i in 20:
			var px := fposmod(sz.x * _frac(i + 3) + t * (7.0 + float(i) * 0.35), sz.x)
			var py := fposmod(sz.y * _frac(i + 11) - t * (5.0 + float(i) * 0.18), sz.y)
			var pa := 0.12 + 0.16 * _frac(i + 19)
			draw_circle(Vector2(px, py), 1.0 + _frac(i) * 1.4, Color(0.90, 0.84, 0.42, pa))
	# Soft vignette — darken edges, keep the wordmark readable.
	for i in 14:
		var inset := float(i) * 18.0
		var va := 0.06
		draw_rect(Rect2(0.0, 0.0, sz.x, inset), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(0.0, sz.y - inset, sz.x, inset), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(0.0, 0.0, inset, sz.y), Color(0.01, 0.02, 0.02, va))
		draw_rect(Rect2(sz.x - inset, 0.0, inset, sz.y), Color(0.01, 0.02, 0.02, va))


func _frac(n: int) -> float:
	var s := sin(float(n) * 12.9898) * 43758.5453
	return s - floor(s)
