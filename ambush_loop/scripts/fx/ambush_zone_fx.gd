class_name AmbushZoneFx
extends Node2D

## Soft fill + dashed breathing edge for the authored ambush rectangle.

var zone: Rect2 = Rect2()
var _t: float = 0.0
var _tag: Label = null


func setup(r: Rect2, tag_text: String = "伏击区") -> void:
	zone = r
	z_index = 1
	if _tag == null or not is_instance_valid(_tag):
		_tag = Label.new()
		_tag.name = "Tag"
		_tag.add_theme_font_size_override("font_size", 13)
		_tag.add_theme_font_override("font", NightOps.ui_font_bold())
		_tag.add_theme_color_override("font_color", Color(0.98, 0.88, 0.35, 0.88))
		_tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
		_tag.add_theme_constant_override("shadow_offset_x", 1)
		_tag.add_theme_constant_override("shadow_offset_y", 1)
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tag)
	_tag.text = tag_text if tag_text != "" else "伏击区"
	_tag.position = r.position + Vector2(8, 4)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if zone.size == Vector2.ZERO:
		return
	var wave := 0.5 + 0.5 * sin(_t * 2.35)
	var fill_a := 0.045 + 0.035 * wave
	draw_rect(zone, Color(0.92, 0.82, 0.22, fill_a))
	var edge := Color(0.95, 0.86, 0.28, 0.28 + 0.22 * wave)
	var grown := zone.grow(1.2 * sin(_t * 2.35))
	_dashed_rect(grown, edge, 1.6, 11.0, 6.0)


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
