extends Control

## Title: brand, briefing, continue, how-to, settings.

const HOWTO := """布置：1/2/3 或左侧卡片选队员，左键点掩体部署。A/D 或右键调射界。F 开火条件，G 弹包（仓道），B 门锁（泵站），Tab 绊索。
空格：拉响警报并锁死计划。之后只能观看（P 暂停，+/- 变速）。X 中止并保留情报。
失败（逃逸/全灭/中止）穿梭回去，恢复上轮计划。M 静音。Esc 设置。R 清空记忆。
硬规则：警报后不能微操；敌人走作者路线；逃逸或全灭都算失败。"""

@onready var wordmark: Label = $UI/Wordmark
@onready var tagline: Label = $UI/Tagline
@onready var start_btn: Button = $UI/Menu/StartButton
@onready var continue_btn: Button = $UI/Menu/ContinueButton
@onready var help_btn: Button = $UI/Menu/HelpButton
@onready var quit_btn: Button = $UI/Menu/QuitButton

var pause_ui: PauseOverlay
var _brief: CanvasLayer
var _brief_title: Label
var _brief_body: Label
var _howto: CanvasLayer
var _pending_id: String = "yard"


func _ready() -> void:
	theme = NightOps.theme()
	wordmark.add_theme_font_override("font", NightOps.display_font())
	wordmark.add_theme_font_size_override("font_size", 72)
	wordmark.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	tagline.add_theme_font_override("font", NightOps.ui_font())
	tagline.add_theme_font_size_override("font_size", 18)
	tagline.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	start_btn.add_theme_font_size_override("font_size", 20)
	_wire_menu()
	_build_briefing()
	_build_howto()
	pause_ui = PauseOverlay.new()
	add_child(pause_ui)
	pause_ui.closed.connect(func() -> void: pass)
	pause_ui.return_to_title.connect(func() -> void: pause_ui.dismiss())
	_play_intro()
	_refresh_continue()


func _wire_menu() -> void:
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	help_btn.pressed.connect(_on_help)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())


func _refresh_continue() -> void:
	var ok := GameSettings.has_progress()
	continue_btn.disabled = not ok
	continue_btn.modulate = Color(0.55, 0.56, 0.52) if not ok else Color.WHITE


func _play_intro() -> void:
	wordmark.modulate.a = 0.0
	tagline.modulate.a = 0.0
	$UI/Menu.modulate.a = 0.0
	wordmark.offset_top = 96.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wordmark, "modulate:a", 1.0, 0.55)
	tw.tween_property(wordmark, "offset_top", 118.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tagline, "modulate:a", 1.0, 0.7).set_delay(0.15)
	tw.tween_property($UI/Menu, "modulate:a", 1.0, 0.5).set_delay(0.28)
	var pulse := create_tween().set_loops()
	pulse.tween_property(start_btn, "modulate", Color(1.12, 1.14, 0.92), 0.85)
	pulse.tween_property(start_btn, "modulate", Color.WHITE, 0.85)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			GameSettings.toggle_mute()
			if pause_ui and pause_ui.is_open():
				pause_ui._refresh_audio()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if _brief.visible:
				_brief.visible = false
			elif _howto.visible:
				_howto.visible = false
			elif pause_ui.is_open():
				pause_ui.dismiss()
			else:
				pause_ui.present(false, false)
			get_viewport().set_input_as_handled()


func _on_start() -> void:
	_pending_id = GameSettings.current_or_first_level()
	_show_briefing(_pending_id)


func _on_continue() -> void:
	if not GameSettings.has_progress():
		return
	_enter_mission(GameSettings.progress_level_id())


func _show_briefing(level_id: String) -> void:
	var def: LevelDef = LevelDef.by_id(level_id)
	_brief_title.text = def.title
	_brief_body.text = "%s\n\n%s" % [def.teaching, def.tutorial]
	_brief.visible = true


func _enter_mission(level_id: String) -> void:
	GameSettings.pending_level_id = level_id
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_help() -> void:
	_howto.visible = true


func _build_briefing() -> void:
	_brief = CanvasLayer.new()
	_brief.layer = 20
	_brief.visible = false
	add_child(_brief)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_brief.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320.0
	panel.offset_right = 320.0
	panel.offset_top = -210.0
	panel.offset_bottom = 210.0
	panel.theme = NightOps.theme()
	_brief.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var kicker := Label.new()
	kicker.text = "任务简报"
	kicker.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	box.add_child(kicker)
	_brief_title = Label.new()
	_brief_title.add_theme_font_size_override("font_size", 22)
	_brief_title.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_brief_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_brief_title)
	_brief_body = Label.new()
	_brief_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_body.custom_minimum_size = Vector2(580, 180)
	box.add_child(_brief_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func() -> void: _brief.visible = false)
	row.add_child(back)
	var go := Button.new()
	go.text = "进入战场"
	go.pressed.connect(func() -> void: _enter_mission(_pending_id))
	row.add_child(go)


func _build_howto() -> void:
	_howto = CanvasLayer.new()
	_howto.layer = 20
	_howto.visible = false
	add_child(_howto)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_howto.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = -200.0
	panel.offset_bottom = 200.0
	panel.theme = NightOps.theme()
	_howto.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var t := Label.new()
	t.text = "操作说明"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(t)
	var body := Label.new()
	body.text = HOWTO
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 220)
	box.add_child(body)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: _howto.visible = false)
	box.add_child(close)
