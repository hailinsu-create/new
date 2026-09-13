class_name CampaignJournal
extends CanvasLayer

## Title-side campaign dossier. Six-night board: color bar, beat, state.

signal closed

var _open: bool = false
var _body: Label
var _kicker: Label
var _stamp: Label
var _board: VBoxContainer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.016, 0.010, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400.0
	panel.offset_right = 400.0
	panel.offset_top = -268.0
	panel.offset_bottom = 268.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
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
	_stamp = Label.new()
	_stamp.name = "Stamp"
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_font_size_override("font_size", 13)
	_stamp.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_stamp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stamp)
	_board = VBoxContainer.new()
	_board.name = "Board"
	_board.add_theme_constant_override("separation", 4)
	box.add_child(_board)
	_body = Label.new()
	_body.name = "Body"
	_body.visible = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
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
	var stamp := ""
	if gs and gs.has_method("latest_cleared_id"):
		var last_id := str(gs.latest_cleared_id())
		if last_id != "":
			var last_def: LevelDef = LevelDef.by_id(last_id)
			stamp = "封印邮戳 · %s 已封锁" % last_def.title
	if complete:
		stamp = "封印邮戳 · 六夜全部封锁。灯塔停转。"
	if _stamp:
		_stamp.text = stamp
		_stamp.visible = stamp != ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append(LevelDef.campaign_chain_names())
	if stamp != "":
		lines.append(stamp)
	if _board:
		for c in _board.get_children():
			_board.remove_child(c)
			c.queue_free()
	for def in LevelDef.catalog():
		var state := "锁定"
		if gs:
			if gs.has_method("is_level_cleared") and bool(gs.is_level_cleared(def.level_id)):
				state = "已封锁"
			elif gs.has_method("is_level_unlocked") and bool(gs.is_level_unlocked(def.level_id)):
				state = "可出击"
		var beat := str(def.campaign_beat).strip_edges()
		var mood := LevelDef.mood_tag(def.level_id)
		var waves: int = int(def.wave_count()) if def.has_method("wave_count") else 1
		lines.append("%s  %s  [%s]  %d波" % [mood, def.title, state, waves])
		if beat != "":
			lines.append(beat)
		if _board:
			_board.add_child(_make_night_row(def, state, beat))
	if _body:
		_body.text = "\n".join(lines)


func _make_night_row(def: LevelDef, state: String, beat: String) -> Control:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(0, 50)
	var sig: Color = LevelDef.signature_color(def.level_id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.048, 0.040, 0.88)
	sb.border_color = Color(sig.r, sig.g, sig.b, 0.42)
	sb.set_border_width_all(1)
	sb.border_width_left = 0
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 0
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(8, 42)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.color = sig
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var mood := Label.new()
	mood.text = LevelDef.mood_tag(def.level_id)
	mood.add_theme_font_override("font", NightOps.ui_font_bold())
	mood.add_theme_font_size_override("font_size", 14)
	mood.add_theme_color_override("font_color", sig)
	head.add_child(mood)
	var title := Label.new()
	title.text = def.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", NightOps.TEXT)
	head.add_child(title)
	var st := Label.new()
	st.text = state
	st.add_theme_font_size_override("font_size", 13)
	match state:
		"已封锁":
			st.add_theme_color_override("font_color", NightOps.HP_OK)
		"可出击":
			st.add_theme_color_override("font_color", NightOps.OLIVE_HI)
		_:
			st.add_theme_color_override("font_color", NightOps.MUTED)
	head.add_child(st)
	var beat_lab := Label.new()
	beat_lab.text = beat
	beat_lab.clip_text = true
	beat_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	beat_lab.add_theme_font_size_override("font_size", 12)
	beat_lab.add_theme_color_override("font_color", NightOps.MUTED)
	col.add_child(beat_lab)
	return plate
