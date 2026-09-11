class_name NightHandoff
extends CanvasLayer

## Letterbox night-to-night handoff. Copy only — does not change the sim.

signal finished

var _open: bool = false
var _from_id: String = ""
var _to_id: String = ""
var _kicker: Label
var _title: Label
var _body: Label
var _cta: Button
var _from_bar: ColorRect
var _to_bar: ColorRect
var _from_tag: Label
var _to_tag: Label
var _letter_top: ColorRect
var _letter_bot: ColorRect


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.name = "Dimmer"
	dim.color = Color(0.010, 0.016, 0.014, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_letter_top = ColorRect.new()
	_letter_top.name = "LetterTop"
	_letter_top.color = Color(0.012, 0.018, 0.014, 0.96)
	_letter_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letter_top.offset_bottom = 54.0
	_letter_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter_top)
	_letter_bot = ColorRect.new()
	_letter_bot.name = "LetterBot"
	_letter_bot.color = Color(0.012, 0.018, 0.014, 0.96)
	_letter_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letter_bot.offset_top = -54.0
	_letter_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter_bot)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -228.0
	panel.offset_bottom = 228.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.add_theme_font_size_override("font_size", 13)
	_kicker.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	box.add_child(_kicker)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", NightOps.ui_font_bold())
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(_title)
	var rail := HBoxContainer.new()
	rail.name = "NightRail"
	rail.add_theme_constant_override("separation", 10)
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rail)
	_from_bar = ColorRect.new()
	_from_bar.name = "FromBar"
	_from_bar.custom_minimum_size = Vector2(8, 44)
	rail.add_child(_from_bar)
	_from_tag = Label.new()
	_from_tag.name = "FromTag"
	_from_tag.add_theme_font_size_override("font_size", 14)
	rail.add_child(_from_tag)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	rail.add_child(arrow)
	_to_bar = ColorRect.new()
	_to_bar.name = "ToBar"
	_to_bar.custom_minimum_size = Vector2(8, 44)
	rail.add_child(_to_bar)
	_to_tag = Label.new()
	_to_tag.name = "ToTag"
	_to_tag.add_theme_font_size_override("font_size", 14)
	rail.add_child(_to_tag)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", NightOps.TEXT)
	_body.custom_minimum_size = Vector2(620, 160)
	box.add_child(_body)
	_cta = Button.new()
	_cta.name = "EnterNight"
	_cta.custom_minimum_size = Vector2(0, 48)
	_cta.pressed.connect(_on_done)
	box.add_child(_cta)


func is_open() -> bool:
	return _open


func from_id() -> String:
	return _from_id


func to_id() -> String:
	return _to_id


func body_text() -> String:
	if _body == null:
		return ""
	return str(_body.text)


func present(from_id: String, to_id: String) -> void:
	_from_id = str(from_id)
	_to_id = str(to_id)
	_refresh()
	_open = true
	visible = true


func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	finished.emit()


func _on_done() -> void:
	dismiss()


func _refresh() -> void:
	var from_col := LevelDef.signature_color(_from_id)
	var to_col := LevelDef.signature_color(_to_id)
	if _kicker:
		_kicker.text = LevelDef.campaign_frame()
	if _title:
		_title.text = LevelDef.handoff_title(_from_id, _to_id)
		_title.add_theme_color_override("font_color", to_col)
	if _from_bar:
		_from_bar.color = from_col
	if _to_bar:
		_to_bar.color = to_col
	if _from_tag:
		_from_tag.text = LevelDef.mood_tag(_from_id)
		_from_tag.add_theme_color_override("font_color", from_col)
	if _to_tag:
		_to_tag.text = LevelDef.mood_tag(_to_id)
		_to_tag.add_theme_color_override("font_color", to_col)
	if _body:
		_body.text = LevelDef.handoff_body(_from_id, _to_id)
	if _cta:
		_cta.text = LevelDef.handoff_cta(_to_id)
