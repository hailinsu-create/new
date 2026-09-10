class_name MissionSky
extends Node2D

## Live night overlay: moon wash, sodium haze, vent stripes, beacon sweep.
## Static landmarks live in map_draw's cached layer; this node never blocks the grid.

var atmosphere_id: String = "yard"
var _t: float = 0.0


func setup(id: String) -> void:
	atmosphere_id = id
	name = "MissionSky"
	z_index = 1
	z_as_relative = true
	_t = 0.0
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and not gs.changed.is_connected(_on_settings_changed):
		gs.changed.connect(_on_settings_changed)
	_apply_process()
	queue_redraw()


func _on_settings_changed() -> void:
	_apply_process()
	queue_redraw()


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _apply_process() -> void:
	set_process(not _is_power_saving())
	if _is_power_saving():
		_t = 0.0


func _exit_tree() -> void:
	set_process(false)
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and gs.changed.is_connected(_on_settings_changed):
		gs.changed.disconnect(_on_settings_changed)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match atmosphere_id:
		"warehouse":
			_draw_warehouse()
		"pump":
			_draw_pump()
		"railcut":
			_draw_railcut()
		"depot":
			_draw_depot()
		_:
			_draw_yard()


func _map_size() -> Vector2:
	return Vector2(AmbushGrid.COLS * AmbushGrid.TILE, AmbushGrid.ROWS * AmbushGrid.TILE)


func _draw_top_haze(col: Color, rows: int = 6) -> void:
	var sz := _map_size()
	var n := mini(rows, 3) if _is_power_saving() else rows
	for i in n:
		var a := col.a * (0.55 - float(i) * 0.07)
		draw_rect(Rect2(0.0, float(i) * 18.0, sz.x, 22.0), Color(col.r, col.g, col.b, maxf(a, 0.02)))


func _draw_contrast_wash(floor_tint: Color, side_tint: Color) -> void:
	## Second gradient: deeper floor contrast + a thin side key. Overlay only.
	var sz := _map_size()
	var n := 3 if _is_power_saving() else 6
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var h := 28.0
		var y := sz.y - h * float(i + 1) + 8.0
		var a := floor_tint.a * (0.18 + 0.14 * t)
		draw_rect(Rect2(0.0, y, sz.x, h), Color(floor_tint.r, floor_tint.g, floor_tint.b, a))
	draw_rect(Rect2(0.0, 0.0, 36.0, sz.y), Color(side_tint.r, side_tint.g, side_tint.b, side_tint.a))
	draw_rect(Rect2(sz.x - 40.0, 0.0, 40.0, sz.y), Color(side_tint.r * 0.6, side_tint.g * 0.6, side_tint.b * 0.7, side_tint.a * 0.7))


func _draw_yard() -> void:
	var sz := _map_size()
	_draw_top_haze(Color(0.55, 0.68, 0.52, 0.10), 5)
	_draw_contrast_wash(Color(0.04, 0.07, 0.05, 0.22), Color(0.08, 0.10, 0.07, 0.05))
	# Open courtyard: cool moon wash from the NE, never purple.
	var moon := Vector2(sz.x * 0.82, 58.0)
	var breathe := 0.5 + 0.5 * sin(_t * 0.55)
	draw_circle(moon, 48.0 + breathe * 5.0, Color(0.82, 0.88, 0.72, 0.12 + 0.04 * breathe))
	draw_circle(moon, 22.0 + breathe * 2.0, Color(0.86, 0.92, 0.74, 0.20 + 0.05 * breathe))
	draw_circle(moon, 14.0, Color(0.92, 0.95, 0.82, 0.58 + 0.08 * breathe))
	draw_circle(moon, 7.0, Color(0.98, 0.98, 0.90, 0.88))
	# Soft ground wash toward the yard interior.
	draw_rect(Rect2(sz.x * 0.55, 0.0, sz.x * 0.45, 160.0), Color(0.72, 0.78, 0.58, 0.05 + 0.02 * breathe))
	# Window flicker — standard tier only; 省电 keeps a static warm pool.
	var win := Vector2(33.5 * AmbushGrid.TILE, 6.5 * AmbushGrid.TILE)
	var wa := 0.10 + 0.04 * (0.5 + 0.5 * sin(_t * 1.7))
	var flick := 1.0
	if not _is_power_saving():
		var n := 0.5 + 0.5 * sin(_t * 13.0) * sin(_t * 3.1)
		flick = 0.58 + 0.42 * n
		if fmod(_t * 2.4, 1.0) > 0.90:
			flick *= 0.22
	draw_circle(win, 42.0, Color(1.0, 0.72, 0.28, wa * flick))
	draw_circle(win, 18.0, Color(1.0, 0.82, 0.40, wa * 1.4 * flick))
	# Courtyard moths — tiny drifting specks under the moon wash.
	if not _is_power_saving():
		for i in 5:
			var mx := sz.x * 0.62 + sin(_t * 0.55 + float(i) * 1.3) * 90.0 + float(i) * 28.0
			var my := 70.0 + cos(_t * 0.72 + float(i) * 0.9) * 22.0 + float(i % 3) * 18.0
			draw_circle(Vector2(mx, my), 1.6, Color(0.92, 0.95, 0.78, 0.18 + 0.10 * sin(_t * 3.0 + float(i))))


func _draw_warehouse() -> void:
	var sz := _map_size()
	_draw_top_haze(Color(0.62, 0.40, 0.08, 0.14), 6)
	_draw_contrast_wash(Color(0.08, 0.05, 0.02, 0.24), Color(0.18, 0.10, 0.03, 0.06))
	# Cold sodium canopy — horizontal bands, not a purple night.
	var pulse := 0.5 + 0.5 * sin(_t * 1.15)
	# flickering sodium — high-freq dip, not a smooth breathe. Standard only.
	var flicker := 1.0
	if not _is_power_saving():
		flicker = 0.72 + 0.28 * abs(sin(_t * 1.15))
		if fmod(_t * 4.7, 1.0) > 0.84:
			flicker = 0.18 + 0.22 * abs(sin(_t * 37.0))
	draw_rect(Rect2(0.0, 0.0, sz.x, 110.0), Color(0.62, 0.40, 0.08, (0.14 + 0.04 * pulse) * flicker))
	var lamps := [
		Vector2(13.5 * AmbushGrid.TILE, 5.4 * AmbushGrid.TILE),
		Vector2(24.5 * AmbushGrid.TILE, 5.4 * AmbushGrid.TILE),
		Vector2(32.5 * AmbushGrid.TILE, 8.5 * AmbushGrid.TILE),
	]
	for p in lamps:
		# Sodium pool on the floor under each lamp.
		draw_circle(p + Vector2(0, 36), 52.0, Color(0.95, 0.58, 0.10, (0.10 + 0.04 * pulse) * flicker))
		draw_circle(p, 42.0, Color(0.95, 0.62, 0.12, (0.14 + 0.05 * pulse) * flicker))
		draw_circle(p, 12.0, Color(1.0, 0.82, 0.28, (0.34 + 0.10 * pulse) * flicker))
	# Oil-sheen glints along the south lane (cached sheen is static; this is the wet flicker).
	if not _is_power_saving():
		for i in 6:
			var gx := 180.0 + float(i) * 150.0 + sin(_t * 0.7 + float(i)) * 8.0
			var gy := 17.2 * AmbushGrid.TILE + sin(_t * 1.3 + float(i) * 0.7) * 3.0
			draw_rect(Rect2(gx, gy, 48.0, 2.0), Color(0.35, 0.55, 0.48, 0.07 + 0.04 * pulse))
		# Hanging chain sway under the sodium canopy.
		for i in 3:
			var cx := 210.0 + float(i) * 220.0
			var sway := sin(_t * 1.1 + float(i)) * 6.0
			draw_line(Vector2(cx, 8.0), Vector2(cx + sway, 52.0), Color(0.22, 0.16, 0.08, 0.28), 1.4, true)


func _draw_pump() -> void:
	var sz := _map_size()
	_draw_top_haze(Color(0.10, 0.32, 0.28, 0.12), 5)
	_draw_contrast_wash(Color(0.02, 0.08, 0.08, 0.22), Color(0.04, 0.10, 0.09, 0.05))
	draw_rect(Rect2(0.0, 0.0, sz.x, 70.0), Color(0.10, 0.28, 0.24, 0.10))
	# Humming vent stripes over the machinery block.
	var origin := Vector2(17.5 * AmbushGrid.TILE, 11.0 * AmbushGrid.TILE)
	var phase := fmod(_t * 22.0, 14.0)
	var n := 3 if _is_power_saving() else 6
	for i in n:
		var y := origin.y - 20.0 + float(i) * 7.0 + phase * 0.15
		draw_rect(
			Rect2(origin.x - 40.0, y, 88.0, 2.5),
			Color(0.35, 0.92, 0.72, 0.08 + 0.04 * sin(_t * 4.0 + float(i)))
		)
	# Steam wisps — standard tier only; 省电 keeps static vents.
	if not _is_power_saving():
		for i in 4:
			var wx := origin.x - 18.0 + float(i) * 16.0 + sin(_t * 1.4 + float(i)) * 6.0
			var wy := origin.y - 28.0 - fmod(_t * 18.0 + float(i) * 11.0, 36.0)
			var wa := 0.10 + 0.06 * sin(_t * 2.2 + float(i))
			draw_circle(Vector2(wx, wy), 7.0 + float(i % 2) * 3.0, Color(0.72, 0.92, 0.82, wa))
		# steam puff — a slower periodic bloom off the main vent.
		var cycle := fmod(_t, 1.85)
		if cycle < 0.62:
			var puff := sin(cycle / 0.62 * PI)
			var py := origin.y - 34.0 - puff * 22.0
			draw_circle(origin + Vector2(6.0, py - origin.y), 10.0 + puff * 8.0, Color(0.78, 0.94, 0.86, 0.10 + 0.12 * puff))
			draw_circle(origin + Vector2(-8.0, py - origin.y + 8.0), 7.0 + puff * 5.0, Color(0.70, 0.90, 0.82, 0.08 + 0.08 * puff))
	# Puddle speculars on the south approach.
	var puddle := Vector2(13.5 * AmbushGrid.TILE, 15.5 * AmbushGrid.TILE)
	var shine := 0.08 + 0.05 * (0.5 + 0.5 * sin(_t * 2.4))
	draw_circle(puddle, 22.0, Color(0.25, 0.55, 0.48, shine))
	draw_circle(puddle + Vector2(86, 8), 16.0, Color(0.22, 0.50, 0.44, shine * 0.8))
	# Condensation drip off the main pipe run.
	if not _is_power_saving():
		var drip := fmod(_t * 0.85, 1.35)
		var dy := origin.y + 18.0 + drip * 36.0
		var da := 0.16 * (1.0 - drip / 1.35)
		draw_circle(Vector2(origin.x + 22.0, dy), 2.2, Color(0.55, 0.88, 0.78, da))


func _draw_railcut() -> void:
	_draw_top_haze(Color(0.42, 0.52, 0.62, 0.10), 5)
	_draw_contrast_wash(Color(0.04, 0.05, 0.06, 0.22), Color(0.08, 0.10, 0.12, 0.05))
	# Signal tower beacon — rotating cone from the core block. Overlay only.
	var tower := Vector2(21.5 * AmbushGrid.TILE, 10.5 * AmbushGrid.TILE)
	var ang := _t * 0.85
	if _is_power_saving():
		ang = 0.35
	var reach := 280.0 if not _is_power_saving() else 260.0
	var half := 0.18 if not _is_power_saving() else 0.22
	var pts := PackedVector2Array([tower])
	var steps := 7 if _is_power_saving() else 12
	for i in steps:
		var a := ang - half + (half * 2.0) * (float(i) / float(steps - 1))
		pts.append(tower + Vector2(cos(a), sin(a)) * reach)
	var cone_a := 0.13 if not _is_power_saving() else 0.10
	draw_colored_polygon(pts, Color(0.95, 0.55, 0.18, cone_a))
	var tip := tower + Vector2(cos(ang), sin(ang)) * 40.0
	var blink := 0.55 + 0.45 * sin(_t * 8.4)
	if _is_power_saving():
		blink = 0.7
	draw_circle(tower, 8.0, Color(1.0, 0.38, 0.14, 0.35 + 0.40 * blink))
	draw_circle(tower, 7.0, Color(1.0, 0.72, 0.22, 0.55))
	draw_circle(tip, 5.0, Color(1.0, 0.85, 0.35, 0.35 + 0.15 * sin(_t * 6.0)))
	# Cool night rim on the split corridors.
	draw_rect(Rect2(12.0 * AmbushGrid.TILE, 0.0, 3.0 * AmbushGrid.TILE, 5.0 * AmbushGrid.TILE), Color(0.55, 0.72, 0.85, 0.04))
	draw_rect(Rect2(31.0 * AmbushGrid.TILE, 0.0, 3.0 * AmbushGrid.TILE, 5.0 * AmbushGrid.TILE), Color(0.55, 0.72, 0.85, 0.04))
	# Rail glint — a traveling specular on the west corridor steel.
	if not _is_power_saving():
		var gx := 12.2 * AmbushGrid.TILE + fmod(_t * 42.0, 3.0 * AmbushGrid.TILE)
		draw_rect(Rect2(gx, 5.2 * AmbushGrid.TILE, 18.0, 3.0), Color(0.82, 0.88, 0.95, 0.10 + 0.06 * sin(_t * 6.0)))


func _draw_depot() -> void:
	var sz := _map_size()
	_draw_top_haze(Color(0.55, 0.24, 0.06, 0.16), 7)
	_draw_contrast_wash(Color(0.10, 0.04, 0.01, 0.26), Color(0.16, 0.06, 0.02, 0.06))
	# Diesel haze along the top of the yard.
	var haze_n := 4 if _is_power_saving() else 8
	for i in haze_n:
		var a := 0.06 + float(i) * 0.014
		draw_rect(Rect2(0.0, float(i) * 16.0, sz.x, 18.0), Color(0.48, 0.22, 0.06, a))
	var pulse := 0.5 + 0.5 * sin(_t * 0.9)
	draw_rect(Rect2(0.0, 0.0, sz.x, 56.0), Color(0.62, 0.28, 0.06, 0.08 + 0.04 * pulse))
	# Orange underglow along the south tanks / hazard row.
	draw_rect(Rect2(14.0 * AmbushGrid.TILE, 13.5 * AmbushGrid.TILE, 12.0 * AmbushGrid.TILE, 70.0), Color(0.95, 0.38, 0.08, 0.07 + 0.03 * pulse))
	# Warm tank glow over the mid-map silhouettes (cached tanks stay put).
	var tank := Vector2(19.0 * AmbushGrid.TILE, 11.0 * AmbushGrid.TILE)
	draw_circle(tank, 62.0, Color(0.95, 0.42, 0.10, 0.10 + 0.04 * pulse))
	draw_circle(tank + Vector2(70, -8), 48.0, Color(0.90, 0.38, 0.10, 0.07 + 0.03 * pulse))
	# Tank gauge blink — standard tier only.
	if not _is_power_saving():
		var gauge := tank + Vector2(10.0, -30.0)
		var on := fmod(_t, 1.15) < 0.58
		var gcol := Color(0.98, 0.32, 0.10, 0.88) if on else Color(0.32, 0.12, 0.06, 0.45)
		draw_rect(Rect2(gauge.x, gauge.y, 11.0, 7.0), gcol)
		draw_rect(Rect2(gauge.x - 1.0, gauge.y - 1.0, 13.0, 9.0), Color(0.12, 0.06, 0.03, 0.7), false, 1.2)
		# Heat shimmer bars over the south tanks.
		for i in 4:
			var hx := 15.5 * AmbushGrid.TILE + float(i) * 28.0 + sin(_t * 2.2 + float(i)) * 3.0
			var hy := 13.8 * AmbushGrid.TILE + sin(_t * 3.1 + float(i) * 0.7) * 4.0
			draw_rect(Rect2(hx, hy, 16.0, 2.0), Color(0.95, 0.48, 0.12, 0.08 + 0.05 * pulse))
