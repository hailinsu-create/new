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


func _draw_yard() -> void:
	var sz := _map_size()
	# Open courtyard: cool moon wash from the NE, never purple.
	var moon := Vector2(sz.x * 0.82, 58.0)
	var breathe := 0.5 + 0.5 * sin(_t * 0.55)
	draw_circle(moon, 38.0 + breathe * 4.0, Color(0.82, 0.88, 0.72, 0.16 + 0.04 * breathe))
	draw_circle(moon, 14.0, Color(0.92, 0.95, 0.82, 0.55 + 0.08 * breathe))
	draw_circle(moon, 7.0, Color(0.98, 0.98, 0.90, 0.85))
	# Soft ground wash toward the yard interior.
	draw_rect(Rect2(sz.x * 0.55, 0.0, sz.x * 0.45, 160.0), Color(0.72, 0.78, 0.58, 0.05 + 0.02 * breathe))
	# Warm window glow, NE interior corner (matches cached window landmark).
	var win := Vector2(33.5 * AmbushGrid.TILE, 6.5 * AmbushGrid.TILE)
	var wa := 0.10 + 0.04 * (0.5 + 0.5 * sin(_t * 1.7))
	draw_circle(win, 42.0, Color(1.0, 0.72, 0.28, wa))
	draw_circle(win, 18.0, Color(1.0, 0.82, 0.40, wa * 1.4))


func _draw_warehouse() -> void:
	var sz := _map_size()
	# Cold sodium canopy — horizontal bands, not a purple night.
	var pulse := 0.5 + 0.5 * sin(_t * 1.15)
	draw_rect(Rect2(0.0, 0.0, sz.x, 90.0), Color(0.55, 0.38, 0.08, 0.10 + 0.03 * pulse))
	var lamps := [
		Vector2(13.5 * AmbushGrid.TILE, 5.4 * AmbushGrid.TILE),
		Vector2(24.5 * AmbushGrid.TILE, 5.4 * AmbushGrid.TILE),
		Vector2(32.5 * AmbushGrid.TILE, 8.5 * AmbushGrid.TILE),
	]
	for p in lamps:
		draw_circle(p, 36.0, Color(0.95, 0.62, 0.12, 0.10 + 0.04 * pulse))
		draw_circle(p, 10.0, Color(1.0, 0.82, 0.28, 0.28 + 0.08 * pulse))
	# Oil-sheen glints along the south lane (cached sheen is static; this is the wet flicker).
	if not _is_power_saving():
		for i in 6:
			var gx := 180.0 + float(i) * 150.0 + sin(_t * 0.7 + float(i)) * 8.0
			var gy := 17.2 * AmbushGrid.TILE + sin(_t * 1.3 + float(i) * 0.7) * 3.0
			draw_rect(Rect2(gx, gy, 48.0, 2.0), Color(0.35, 0.55, 0.48, 0.07 + 0.04 * pulse))


func _draw_pump() -> void:
	var sz := _map_size()
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
	# Puddle speculars on the south approach.
	var puddle := Vector2(13.5 * AmbushGrid.TILE, 15.5 * AmbushGrid.TILE)
	var shine := 0.08 + 0.05 * (0.5 + 0.5 * sin(_t * 2.4))
	draw_circle(puddle, 22.0, Color(0.25, 0.55, 0.48, shine))
	draw_circle(puddle + Vector2(86, 8), 16.0, Color(0.22, 0.50, 0.44, shine * 0.8))


func _draw_railcut() -> void:
	# Signal tower beacon — rotating cone from the core block. Overlay only.
	var tower := Vector2(21.5 * AmbushGrid.TILE, 10.5 * AmbushGrid.TILE)
	var ang := _t * 0.85
	if _is_power_saving():
		ang = 0.35
	var reach := 260.0
	var half := 0.22
	var pts := PackedVector2Array([tower])
	var steps := 7 if _is_power_saving() else 10
	for i in steps:
		var a := ang - half + (half * 2.0) * (float(i) / float(steps - 1))
		pts.append(tower + Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(pts, Color(0.95, 0.55, 0.18, 0.10))
	var tip := tower + Vector2(cos(ang), sin(ang)) * 40.0
	draw_circle(tower, 7.0, Color(1.0, 0.72, 0.22, 0.55))
	draw_circle(tip, 5.0, Color(1.0, 0.85, 0.35, 0.35 + 0.15 * sin(_t * 6.0)))
	# Cool night rim on the split corridors.
	draw_rect(Rect2(12.0 * AmbushGrid.TILE, 0.0, 3.0 * AmbushGrid.TILE, 5.0 * AmbushGrid.TILE), Color(0.55, 0.72, 0.85, 0.04))
	draw_rect(Rect2(31.0 * AmbushGrid.TILE, 0.0, 3.0 * AmbushGrid.TILE, 5.0 * AmbushGrid.TILE), Color(0.55, 0.72, 0.85, 0.04))


func _draw_depot() -> void:
	var sz := _map_size()
	# Diesel haze along the top of the yard.
	var haze_n := 4 if _is_power_saving() else 8
	for i in haze_n:
		var a := 0.05 + float(i) * 0.012
		draw_rect(Rect2(0.0, float(i) * 16.0, sz.x, 18.0), Color(0.42, 0.22, 0.08, a))
	var pulse := 0.5 + 0.5 * sin(_t * 0.9)
	draw_rect(Rect2(0.0, 0.0, sz.x, 48.0), Color(0.55, 0.28, 0.08, 0.06 + 0.03 * pulse))
	# Warm tank glow over the mid-map silhouettes (cached tanks stay put).
	var tank := Vector2(19.0 * AmbushGrid.TILE, 11.0 * AmbushGrid.TILE)
	draw_circle(tank, 54.0, Color(0.95, 0.42, 0.10, 0.07 + 0.03 * pulse))
	draw_circle(tank + Vector2(70, -8), 40.0, Color(0.90, 0.38, 0.10, 0.05 + 0.02 * pulse))
