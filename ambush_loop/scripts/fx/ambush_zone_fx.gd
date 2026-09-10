class_name AmbushZoneFx
extends Node2D

## Soft fill + dashed breathing edge for the authored ambush rectangle.

var zone: Rect2 = Rect2()
var _t: float = 0.0
var _tag: Label = null
var _tint: Color = Color(0.95, 0.86, 0.28)
var hot: bool = false


func set_hot(on: bool) -> void:
	if hot == on:
		return
	hot = on
	queue_redraw()


func setup(r: Rect2, tag_text: String = "伏击区", tint: Color = Color(0.95, 0.86, 0.28)) -> void:
	zone = r
	_tint = tint
	z_index = 1
	if _tag == null or not is_instance_valid(_tag):
		_tag = Label.new()
		_tag.name = "Tag"
		_tag.add_theme_font_size_override("font_size", 13)
		_tag.add_theme_font_override("font", NightOps.ui_font_bold())
		_tag.add_theme_color_override("font_color", Color(_tint.r, _tint.g, _tint.b, 0.90))
		_tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
		_tag.add_theme_constant_override("shadow_offset_x", 1)
		_tag.add_theme_constant_override("shadow_offset_y", 1)
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tag)
	_tag.text = tag_text if tag_text != "" else "伏击区"
	_tag.position = r.position + Vector2(8, 4)
	queue_redraw()


func signature_tint() -> Color:
	return _tint


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if zone.size == Vector2.ZERO:
		return
	var rate := 4.4 if hot else 2.35
	var wave := 0.5 + 0.5 * sin(_t * rate)
	var fill_a := (0.08 + 0.06 * wave) if hot else (0.045 + 0.035 * wave)
	draw_rect(zone, Color(_tint.r, _tint.g, _tint.b, fill_a))
	if hot:
		draw_rect(zone.grow(4.0), Color(_tint.r, _tint.g, _tint.b, 0.06 + 0.05 * wave))
	var edge := Color(_tint.r, _tint.g, _tint.b, (0.48 + 0.32 * wave) if hot else (0.28 + 0.22 * wave))
	var grown := zone.grow((2.4 if hot else 1.2) * sin(_t * rate))
	_dashed_rect(grown, edge, 2.1 if hot else 1.6, 11.0, 6.0)
	# Corner ticks so the authored rectangle reads as a kill box, not a wash.
	var tick := 10.0
	var corners: Array[Vector2] = [
		zone.position,
		zone.position + Vector2(zone.size.x, 0.0),
		zone.position + zone.size,
		zone.position + Vector2(0.0, zone.size.y),
	]
	var tick_col := Color(_tint.r, _tint.g, _tint.b, 0.55 + 0.25 * wave)
	for p in corners:
		var inward: Vector2 = (zone.get_center() - p).normalized()
		draw_line(p, p + inward * tick, tick_col, 2.0, true)


func _dashed_rect(r: Rect2, col: Color, width: float, dash: float, gap: float) -> void:
	_dashed_segment(r.position, r.position + Vector2(r.size.x, 0.0), col, width, dash, gap)
	_dashed_segment(r.position + Vector2(r.size.x, 0.0), r.position + r.size, col, width, dash, gap)
	_dashed_segment(r.position + r.size, r.position + Vector2(0.0, r.size.y), col, width, dash, gap)
	_dashed_segment(r.position + Vector2(0.0, r.size.y), r.position, col, width, dash, gap)


func _dashed_segment(a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var pos := 0.0
	var draw_on := true
	while pos < length:
		var span := dash if draw_on else gap
		var npos := minf(pos + span, length)
		if draw_on:
			draw_line(a + dir * pos, a + dir * npos, col, width, true)
		pos = npos
		draw_on = not draw_on
