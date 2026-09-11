class_name CampaignJournal
extends CanvasLayer

## Title-side campaign dossier. Fills the post-credits hole: six nights stay readable.

signal closed

var _open: bool = false
var _body: Label
var _kicker: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.020, 0.016, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -268.0
	panel.offset_bottom = 268.0
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
	var word := Label.new()
	word.text = "战役档案"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 22)
	word.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(word)
	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.add_theme_font_size_override("font_size", 13)
	_kicker.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	_kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_kicker)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(620, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", NightOps.TEXT)
	_body.custom_minimum_size = Vector2(600, 0)
	scroll.add_child(_body)
	var btn := Button.new()
	btn.text = "关闭"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_on_done)
	box.add_child(btn)


func is_open() -> bool:
	return _open


func body_text() -> String:
	if _body == null:
		return ""
	return str(_body.text)


func present() -> void:
	_refresh()
	_open = true
	visible = true


func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func _on_done() -> void:
	dismiss()


func _refresh() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	var complete := gs != null and gs.has_method("is_campaign_complete") and bool(gs.is_campaign_complete())
	if _kicker:
		if complete:
			_kicker.text = "%s\n灯塔停转。这一夜已经结束。可以再打任意一关。" % LevelDef.campaign_frame()
		else:
			_kicker.text = "%s\n%s" % [LevelDef.campaign_frame(), LevelDef.campaign_kicker()]
	var lines: PackedStringArray = PackedStringArray()
	lines.append(LevelDef.campaign_chain_names())
	var stamp := ""
	if gs and gs.has_method("latest_cleared_id"):
		var last_id := str(gs.latest_cleared_id())
		if last_id != "":
			var last_def: LevelDef = LevelDef.by_id(last_id)
			stamp = "封印邮戳 · %s 已封锁" % last_def.title
	if complete:
		stamp = "封印邮戳 · 六夜全部封锁。灯塔停转。"
	if stamp != "":
		lines.append(stamp)
	lines.append("")
	for def in LevelDef.catalog():
		var state := "锁定"
		if gs:
			if gs.has_method("is_level_cleared") and bool(gs.is_level_cleared(def.level_id)):
				state = "已封锁"
			elif gs.has_method("is_level_unlocked") and bool(gs.is_level_unlocked(def.level_id)):
				state = "可出击"
		lines.append("%s  [%s]" % [def.title, state])
		var beat := str(def.campaign_beat).strip_edges()
		if beat != "":
			lines.append("  %s" % beat)
		var sit := str(def.situation).strip_edges()
		if sit != "":
			lines.append("  %s" % sit)
		lines.append("")
	if _body:
		_body.text = "\n".join(lines)
