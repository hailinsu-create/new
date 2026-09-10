class_name CreditsOverlay
extends CanvasLayer

signal finished

var _open: bool = false


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -180.0
	panel.offset_bottom = 180.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var word := Label.new()
	word.text = "AMBUSH LOOP"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 28)
	word.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(word)
	var tag := Label.new()
	tag.text = "战前埋伏 · 锁死计划 · 时间穿梭"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	box.add_child(tag)
	var body := Label.new()
	body.name = "Body"
	body.text = "院子 / 仓道 / 泵站 / 信号楼 / 油库 全部封锁。\n五关夜班已切断。情报已归档。计划锁死过的那些秒，就是这场胜负。\n\n感谢游玩。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	box.add_child(body)
	var btn := Button.new()
	btn.text = "返回标题"
	btn.pressed.connect(_on_done)
	box.add_child(btn)


func is_open() -> bool:
	return _open


func present() -> void:
	_open = true
	visible = true


func _on_done() -> void:
	_open = false
	visible = false
	finished.emit()
