extends Node2D

## SETUP dashed pulse along the second-layer trap route. Overlay only.

var pts: PackedVector2Array = PackedVector2Array()
var col: Color = Color(1.0, 0.72, 0.38, 0.92)
var tag: String = ""
var tag_at: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _pip: float = 0.0
var _lab: Label


func setup(path: PackedVector2Array, tint: Color, label: String, at: Vector2 = Vector2.ZERO) -> void:
	pts = path.duplicate()
	col = tint
	tag = label
	tag_at = at
	name = "TrapPathFx"
	z_index = 7
	_t = 0.0
	_pip = 0.0
	_ensure_tag()
	_hook_settings()
	_apply_process()
	queue_redraw()


func _ready() -> void:
	_hook_settings()
	_apply_process()


func _gs():
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameSettings")


func _hook_settings() -> void:
	var gs = _gs()
	if gs and gs.has_signal("changed") and not gs.changed.is_connected(_on_settings_changed):
		gs.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	_apply_process()
	queue_redraw()


func _is_power_saving() -> bool:
	var gs = _gs()
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _apply_process() -> void:
	set_process(not _is_power_saving())


func _exit_tree() -> void:
	set_process(false)
	var gs = _gs()
	if gs and gs.has_signal("changed") and gs.changed.is_connected(_on_settings_changed):
		gs.changed.disconnect(_on_settings_changed)


func _ensure_tag() -> void:
	if _lab != null and is_instance_valid(_lab):
		_lab.text = tag
		_place_tag()
		return
	_lab = Label.new()
	_lab.name = "Tag"
	_lab.text = tag
	_lab.add_theme_font_size_override("font_size", 12)
	_lab.add_theme_font_override("font", NightOps.ui_font_bold())
	_lab.add_theme_color_override("font_color", col)
	_lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	_lab.add_theme_constant_override("shadow_offset_x", 1)
	_lab.add_theme_constant_override("shadow_offset_y", 1)
	_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lab)
	_place_tag()


func _place_tag() -> void:
	if _lab == null:
		return
	if tag_at != Vector2.ZERO:
		_lab.position = tag_at + Vector2(8, -22)
		return
	if pts.size() < 1:
		return
	var idx := mini(maxi(pts.size() - 2, 0), pts.size() - 1)
	_lab.position = pts[idx] + Vector2(8, -22)


func _process(delta: float) -> void:
	_t += delta
	_pip = fmod(_pip + delta * 0.32, 1.0)
	queue_redraw()


func _draw() -> void:
	if pts.size() < 2:
		return
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(_t * 3.2))
	var draw_col := Color(col.r, col.g, col.b, col.a * pulse)
	var dash := 12.0
	var gap := 8.0
	var phase := fmod(_t * 26.0, dash + gap)
	for i in range(pts.size() - 1):
		_dashed_segment(pts[i], pts[i + 1], dash, gap, phase, draw_col)
	var tip: Vector2 = pts[pts.size() - 1]
	var prev: Vector2 = pts[pts.size() - 2]
	var dir := (tip - prev).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	var left := dir.rotated(2.5)
	var right := dir.rotated(-2.5)
	var arrow := PackedVector2Array([
		tip + dir * 10.0,
		tip + left * 12.0,
		tip + right * 12.0,
	])
	draw_colored_polygon(arrow, Color(draw_col.r, draw_col.g, draw_col.b, 0.95))
	draw_circle(pts[0], 4.0, Color(draw_col.r, draw_col.g, draw_col.b, 0.55))
	var pip := _point_along(_pip)
	var glow := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 7.0))
	draw_circle(pip, 7.0, Color(draw_col.r, draw_col.g, draw_col.b, 0.18 + 0.10 * glow))
	draw_circle(pip, 3.4, Color(1.0, 0.94, 0.72, 0.70 + 0.25 * glow))


func _point_along(t: float) -> Vector2:
	if pts.size() < 2:
		return Vector2.ZERO
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if total < 0.5:
		return pts[0]
	var want := clampf(t, 0.0, 1.0) * total
	var acc := 0.0
	for i in range(pts.size() - 1):
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= want:
			var u := 0.0 if seg < 0.01 else (want - acc) / seg
			return pts[i].lerp(pts[i + 1], u)
		acc += seg
	return pts[pts.size() - 1]


func _dashed_segment(a: Vector2, b: Vector2, dash: float, gap: float, phase: float, draw_col: Color) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var pos := -fmod(phase, dash + gap)
	var on := true
	while pos < length:
		var span := dash if on else gap
		var npos := minf(pos + span, length)
		if on and npos > 0.0:
			draw_line(a + dir * maxf(pos, 0.0), a + dir * npos, draw_col, 3.2, true)
		pos = npos
		on = not on
