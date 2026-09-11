extends Node2D

## Presentation-only dashed snapshot of a leaked intel path. Not simulated.
## Marching ants + a scout pip so the leak reads as motion, not a sticker.

var pts: PackedVector2Array = PackedVector2Array()
var col: Color = Color(0.95, 0.28, 0.22, 0.92)
var _t: float = 0.0
var _pip: float = 0.0


func setup(path: PackedVector2Array, tint: Color) -> void:
	pts = path.duplicate()
	col = tint
	z_index = 5
	_t = 0.0
	_pip = 0.0
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


func _process(delta: float) -> void:
	_t += delta
	_pip = fmod(_pip + delta * 0.38, 1.0)
	queue_redraw()


func _draw() -> void:
	if pts.size() < 2:
		return
	var dash := 11.0
	var gap := 7.0
	var phase := fmod(_t * 28.0, dash + gap)
	for i in range(pts.size() - 1):
		_dashed_segment(pts[i], pts[i + 1], dash, gap, phase)
	draw_circle(pts[pts.size() - 1], 5.5, Color(col.r, col.g, col.b, 0.95))
	draw_circle(pts[0], 3.5, Color(col.r, col.g, col.b, 0.55))
	var pip_pos := _point_along(_pip)
	var glow := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 8.0))
	draw_circle(pip_pos, 7.0, Color(col.r, col.g, col.b, 0.22 + 0.12 * glow))
	draw_circle(pip_pos, 4.0, Color(1.0, 0.92, 0.72, 0.55 + 0.35 * glow))
	draw_circle(pip_pos, 2.0, Color(1.0, 1.0, 0.92, 0.95))


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


func _dashed_segment(a: Vector2, b: Vector2, dash: float, gap: float, phase: float) -> void:
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
			draw_line(a + dir * maxf(pos, 0.0), a + dir * npos, col, 2.6, true)
		pos = npos
		on = not on
