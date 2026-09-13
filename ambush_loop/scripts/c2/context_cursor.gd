class_name C2ContextCursor
extends CanvasLayer

## Commandos context cursor: walk / 开匣 / 搜尸 / 选中 / 趴下 / 割喉.

enum Mode { WALK, CRATE, CORPSE, OP, COVER, KNIFE, NONE }

var mode: int = Mode.WALK
var _lab: Label
var _icon: Control


func _ready() -> void:
	layer = 60
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_icon = Control.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(22, 22)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	root.add_child(_icon)
	_lab = Label.new()
	_lab.add_theme_font_size_override("font_size", 12)
	_lab.add_theme_font_override("font", NightOps.ui_font_bold())
	_lab.add_theme_color_override("font_color", Color(0.92, 0.86, 0.52))
	_lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
	_lab.add_theme_constant_override("shadow_offset_y", 1)
	_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_lab)
	set_process(true)


func set_mode(m: int, caption: String = "") -> void:
	mode = m
	if _lab:
		if caption == "":
			caption = caption_for(m)
		_lab.text = caption
		_lab.visible = caption != ""
	if _icon:
		_icon.queue_redraw()


func _process(_delta: float) -> void:
	var mp := get_viewport().get_mouse_position()
	if _icon:
		_icon.position = mp + Vector2(14, 10)
	if _lab:
		_lab.position = mp + Vector2(14, 32)


func _draw_icon() -> void:
	if _icon == null:
		return
	var p := Vector2(11, 11)
	var col := Color(0.92, 0.84, 0.42, 0.95)
	match mode:
		Mode.CRATE:
			_icon.draw_rect(Rect2(p.x - 7, p.y - 6, 14, 12), Color(0.42, 0.32, 0.16, 0.95))
			_icon.draw_rect(Rect2(p.x - 7, p.y - 8, 14, 3), Color(0.28, 0.20, 0.10, 0.95))
		Mode.CORPSE:
			_icon.draw_circle(p + Vector2(0, -3), 3.2, col)
			_icon.draw_line(p + Vector2(-6, 6), p + Vector2(6, 6), col, 2.0, true)
		Mode.OP:
			_icon.draw_arc(p, 8.0, 0.0, TAU, 16, col, 1.6, true)
			_icon.draw_circle(p, 2.0, col)
		Mode.COVER:
			_icon.draw_colored_polygon(PackedVector2Array([
				p + Vector2(-8, 6), p + Vector2(8, 6), p + Vector2(6, -2), p + Vector2(-6, -2)
			]), Color(0.38, 0.44, 0.28, 0.95))
		Mode.KNIFE:
			_icon.draw_line(p + Vector2(-7, 6), p + Vector2(7, -6), col, 2.0, true)
		Mode.NONE:
			pass
		_:
			_icon.draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), col, 1.4, true)
			_icon.draw_line(p + Vector2(0, -8), p + Vector2(0, 8), col, 1.4, true)
			_icon.draw_arc(p, 6.0, 0.0, TAU, 14, Color(col.r, col.g, col.b, 0.45), 1.0, true)


static func caption_for(m: int) -> String:
	match m:
		Mode.CRATE:
			return "开匣"
		Mode.CORPSE:
			return "搜尸"
		Mode.OP:
			return "选中"
		Mode.COVER:
			return "趴下"
		Mode.KNIFE:
			return "割喉"
		Mode.WALK:
			return ""
		_:
			return ""
