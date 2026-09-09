extends Control

## Title: brand, mission select, briefing, continue, how-to, quit confirm.

const HOWTO := """布置杀局，警报锁死，只能观看。失败穿梭并带回情报。

【手机】点左侧作战卡选人 → 点掩体部署 → 底栏 ↺↻ 或拖队员调射界 → 点「警报」锁死。
返回键打开菜单，不直接退出。中止 / 暂停 / 倍速 / 弹包 / 绊索 / 门锁都在底栏。清空记忆在设置里点两次。

键 / 操作              作用
1 / 2 / 3 或左侧卡片    选步枪手 / 机枪手 / 侦察兵
左键点掩体              部署选中队员（青弧=保护方向）
悬停掩体                预览该位保护弧
A / D 或右键            调整射界（黄锥被墙裁切）
F                       开火条件：见敌即打 / 入伏再打
G                       弹包交给已部署队员（仓道、泵站、信号楼）
B                       门锁（泵站；侧翼改走备用接近）
Tab                     绊索工具（路线附近，限额 1）
空格                    拉响警报并锁死计划 / 观看时暂停 / 退出复盘
P                       观看暂停
+ / −                   观看变速 1× / 2×（不改模拟结果）
X                       中止尝试，保留目前情报（算失败）
时间轴复盘 / ← →        只读回放，点击事件定位
M                       静音（音乐+音效一起关；设置里可分轨调音量）
R                       清空记忆并重新布置（手机：设置里确认）
Esc / 返回键            标题：退出确认；战场：作战设置
退出                    退出确认（进度留在本地）

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
var _mission: CanvasLayer
var _mission_box: VBoxContainer
var _mission_btns: Array[Button] = []
var _quit: CanvasLayer
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
	_build_mission_select()
	_build_quit_confirm()
	pause_ui = PauseOverlay.new()
	add_child(pause_ui)
	pause_ui.closed.connect(func() -> void: pass)
	pause_ui.return_to_title.connect(func() -> void: pause_ui.dismiss())
	_play_intro()
	_refresh_continue()
	continue_btn.custom_minimum_size = Vector2(300, 48)
	help_btn.custom_minimum_size = Vector2(300, 48)
	quit_btn.custom_minimum_size = Vector2(300, 48)


func mission_row_count() -> int:
	return _mission_btns.size()


func mission_select_visible() -> bool:
	return _mission != null and _mission.visible


func briefing_visible() -> bool:
	return _brief != null and _brief.visible


func pending_mission_id() -> String:
	return _pending_id


func _wire_menu() -> void:
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	help_btn.pressed.connect(_on_help)
	quit_btn.pressed.connect(_show_quit_confirm)


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
	start_btn.pivot_offset = Vector2(150, 24)
	var pulse := create_tween().set_loops()
	pulse.tween_property(start_btn, "modulate", Color(1.28, 1.30, 0.88), 0.72)
	pulse.parallel().tween_property(start_btn, "scale", Vector2(1.045, 1.045), 0.72)
	pulse.tween_property(start_btn, "modulate", Color.WHITE, 0.72)
	pulse.parallel().tween_property(start_btn, "scale", Vector2.ONE, 0.72)


func handle_android_back() -> void:
	_on_back()


func handle_app_focus_out() -> void:
	_gate_title_audio(true)
	_set_title_background_paused(true)


func handle_app_focus_in() -> void:
	_gate_title_audio(false)
	_set_title_background_paused(false)


func _gate_title_audio(paused: bool) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("gate_background_audio"):
		gs.gate_background_audio(paused)
		return
	var audio = get_node_or_null("/root/AudioDirector")
	if audio == null:
		return
	if paused and audio.has_method("pause_for_background"):
		audio.pause_for_background()
	elif (not paused) and audio.has_method("resume_from_background"):
		audio.resume_from_background()


func _set_title_background_paused(on: bool) -> void:
	var back := get_node_or_null("Backdrop")
	if back != null and back.has_method("set_background_paused"):
		back.set_background_paused(on)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			GameSettings.toggle_mute()
			if pause_ui and pause_ui.is_open():
				pause_ui._refresh_audio()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()


func _on_back() -> void:
	if _quit != null and _quit.visible:
		_quit.visible = false
	elif _brief != null and _brief.visible:
		_brief.visible = false
	elif _howto != null and _howto.visible:
		_howto.visible = false
	elif _mission != null and _mission.visible:
		_mission.visible = false
	elif pause_ui != null and pause_ui.is_open():
		pause_ui.dismiss()
	else:
		_show_quit_confirm()


func _on_start() -> void:
	_show_mission_select()


func _on_continue() -> void:
	if not GameSettings.has_progress():
		return
	_enter_mission(GameSettings.progress_level_id())


func _show_mission_select() -> void:
	_refresh_mission_rows()
	_reveal_modal(_mission)


func _refresh_mission_rows() -> void:
	var entries: Array = GameSettings.mission_entries()
	for i in _mission_btns.size():
		var btn := _mission_btns[i]
		if i >= entries.size():
			btn.visible = false
			continue
		var e: Dictionary = entries[i]
		btn.visible = true
		btn.disabled = not bool(e["unlocked"])
		var badge := "锁定 · 先完成上一关"
		if bool(e["unlocked"]):
			badge = "可出击"
		if bool(e["cleared"]):
			badge = "首通"
		btn.text = "%s\n%s" % [str(e["title"]), badge]
		btn.modulate = Color(0.62, 0.64, 0.58) if btn.disabled else Color.WHITE
		btn.set_meta("level_id", str(e["id"]))
		btn.set_meta("unlocked", bool(e["unlocked"]))


func _on_mission_picked(idx: int) -> void:
	if idx < 0 or idx >= _mission_btns.size():
		return
	var btn := _mission_btns[idx]
	if not bool(btn.get_meta("unlocked", false)):
		return
	var id := str(btn.get_meta("level_id", "yard"))
	_mission.visible = false
	_pending_id = id
	_show_briefing(id)


func _show_briefing(level_id: String) -> void:
	var def: LevelDef = LevelDef.by_id(level_id)
	_brief_title.text = def.title
	_brief_body.text = "%s\n\n%s" % [def.teaching, def.tutorial]
	_reveal_modal(_brief)


func _enter_mission(level_id: String) -> void:
	GameSettings.pending_level_id = level_id
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_help() -> void:
	_reveal_modal(_howto)


func _show_quit_confirm() -> void:
	if _quit:
		_reveal_modal(_quit)


func _confirm_quit() -> void:
	get_tree().quit()


func _open_settings_from_quit() -> void:
	if _quit:
		_quit.visible = false
	if pause_ui:
		pause_ui.present(false, false)


func _modal_panel(layer: int, w: float, h: float) -> Dictionary:
	var root := CanvasLayer.new()
	root.layer = layer
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	panel.theme = NightOps.theme()
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	return {"root": root, "box": box}


func _reveal_modal(layer: CanvasLayer) -> void:
	if layer == null:
		return
	layer.visible = true
	for c in layer.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(c, "modulate:a", 1.0, 0.22)


func _build_briefing() -> void:
	var ui := _modal_panel(20, 640.0, 420.0)
	_brief = ui["root"]
	var box: VBoxContainer = ui["box"]
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
	back.pressed.connect(func() -> void:
		_brief.visible = false
		_show_mission_select()
	)
	row.add_child(back)
	var go := Button.new()
	go.text = "进入战场"
	go.pressed.connect(func() -> void: _enter_mission(_pending_id))
	row.add_child(go)


func _build_howto() -> void:
	var ui := _modal_panel(20, 720.0, 520.0)
	_howto = ui["root"]
	var box: VBoxContainer = ui["box"]
	var t := Label.new()
	t.text = "操作说明"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(t)
	var body := Label.new()
	body.text = HOWTO
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.custom_minimum_size = Vector2(660, 360)
	box.add_child(body)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: _howto.visible = false)
	box.add_child(close)


func _build_mission_select() -> void:
	var ui := _modal_panel(20, 560.0, 620.0)
	_mission = ui["root"]
	_mission_box = ui["box"]
	var t := Label.new()
	t.text = "选择任务"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_mission_box.add_child(t)
	var hint := Label.new()
	hint.text = "按顺序解锁。已封锁的关卡可再打一次。"
	hint.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_box.add_child(hint)
	_mission_btns.clear()
	for i in GameSettings.LEVEL_ORDER.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(500, 68)
		btn.add_theme_font_size_override("font_size", 15)
		btn.clip_text = false
		var idx := i
		btn.pressed.connect(func() -> void: _on_mission_picked(idx))
		_mission_box.add_child(btn)
		_mission_btns.append(btn)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(func() -> void: _mission.visible = false)
	_mission_box.add_child(back)


func _build_quit_confirm() -> void:
	var ui := _modal_panel(30, 420.0, 230.0)
	_quit = ui["root"]
	var box: VBoxContainer = ui["box"]
	var t := Label.new()
	t.text = "退出游戏？"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(t)
	var body := Label.new()
	body.text = "进度留在本地。音量与静音会记住。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(90, 36)
	cancel.pressed.connect(func() -> void: _quit.visible = false)
	row.add_child(cancel)
	var settings := Button.new()
	settings.text = "设置"
	settings.custom_minimum_size = Vector2(90, 36)
	settings.pressed.connect(_open_settings_from_quit)
	row.add_child(settings)
	var yes := Button.new()
	yes.text = "退出"
	yes.custom_minimum_size = Vector2(90, 36)
	yes.pressed.connect(_confirm_quit)
	row.add_child(yes)
