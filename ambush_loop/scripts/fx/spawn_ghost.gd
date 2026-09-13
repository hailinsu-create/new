extends Node2D

## SETUP ghost of an authored spawn. Presentation only — not simulated.

var actor_id: int = 0
var route: String = "main"
var delay: float = 0.0
var note: String = ""
var _t: float = 0.0
var _lab: Label


func setup(id: int, p_route: String, p_delay: float, p_note: String = "") -> void:
	actor_id = id
	route = p_route
	delay = p_delay
	note = p_note.strip_edges()
	name = "SpawnGhost%d" % id
	z_index = 6
	_t = 0.0
	_ensure_label()
	queue_redraw()


func caption() -> String:
	var t := "敌%d · %.1fs" % [actor_id, delay]
	if note != "":
		t += "  %s" % note
	return t


func route_color() -> Color:
	match route:
		"flank":
			return Color(0.95, 0.55, 0.16)
		"sneak":
			return Color(0.42, 0.48, 0.28)
		"echo":
			return Color(0.70, 0.58, 0.32)
		"alt":
			return Color(0.72, 0.55, 0.95)
		_:
			return Color(0.92, 0.28, 0.22)


func _ready() -> void:
	_ensure_label()
	set_process(not _is_power_saving())


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _ensure_label() -> void:
	if _lab != null and is_instance_valid(_lab):
		_lab.text = caption()
		return
	_lab = Label.new()
	_lab.name = "Tag"
	_lab.text = caption()
	_lab.position = Vector2(-6, -18)
	_lab.add_theme_font_size_override("font_size", 11)
	_lab.add_theme_font_override("font", NightOps.ui_font_bold())
	_lab.add_theme_color_override("font_color", route_color().lightened(0.18))
	_lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	_lab.add_theme_constant_override("shadow_offset_x", 1)
	_lab.add_theme_constant_override("shadow_offset_y", 1)
	_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lab)


func _draw() -> void:
	var col := route_color()
	var wave := 0.5 + 0.5 * sin(_t * 3.6 + float(actor_id) * 0.7)
	draw_circle(Vector2.ZERO, 9.0 + 1.6 * wave, Color(col.r, col.g, col.b, 0.14 + 0.10 * wave))
	draw_circle(Vector2.ZERO, 5.2, Color(col.r, col.g, col.b, 0.82))
	draw_circle(Vector2.ZERO, 5.2, Color(0.05, 0.04, 0.03, 0.90), false, 1.2)
	var diamond := PackedVector2Array([
		Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)
	])
	draw_colored_polygon(diamond, Color(col.r, col.g, col.b, 0.95))
	var tick := "主"
	match route:
		"flank":
			tick = "侧"
		"sneak":
			tick = "暗"
		"echo":
			tick = "回"
		"alt":
			tick = "备"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-5, 16),
		tick,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		col.lightened(0.12)
	)
