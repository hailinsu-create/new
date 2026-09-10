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
G                       弹包交给已部署队员（仓道、泵站、信号楼、油库）
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
var _sway_tween: Tween = null
var _sway_base_top: float = 118.0
var _brief: CanvasLayer
var _brief_title: Label
var _brief_body: Label
var _brief_codename: Label
var _brief_teach: VBoxContainer
var _brief_chips: HBoxContainer
var _brief_go: Button
var _howto: CanvasLayer
var _mission: CanvasLayer
var _mission_box: VBoxContainer
var _mission_btns: Array[Button] = []
var _mission_accents: Array[ColorRect] = []
var _mission_locks: Array[Label] = []
var _quit: CanvasLayer
var _pending_id: String = "yard"
var _ops_stamp: HBoxContainer
var _modal_tween: Tween = null


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
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and not gs.changed.is_connected(_on_settings_changed_title):
		gs.changed.connect(_on_settings_changed_title)
	continue_btn.custom_minimum_size = Vector2(300, 48)
	help_btn.custom_minimum_size = Vector2(300, 48)
	quit_btn.custom_minimum_size = Vector2(300, 48)
	_build_ops_stamp()


func mission_row_count() -> int:
	return _mission_btns.size()


func mission_select_visible() -> bool:
	return _mission != null and _mission.visible


func briefing_visible() -> bool:
	return _brief != null and _brief.visible


func pending_mission_id() -> String:
	return _pending_id


func briefing_codename_text() -> String:
	if _brief_codename == null:
		return ""
	return str(_brief_codename.text)


func mission_row_accent_exists() -> bool:
	if _mission_accents.is_empty():
		return false
	var a: ColorRect = _mission_accents[0]
	return a != null and is_instance_valid(a) and a.custom_minimum_size.x >= 4.0


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
	tw.chain().tween_callback(_start_wordmark_sway)


func _on_settings_changed_title() -> void:
	_start_wordmark_sway()


func _title_fx_paused() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving()):
		return true
	var back := get_node_or_null("Backdrop")
	if back != null and bool(back.get("_focus_paused")):
		return true
	return false


func _start_wordmark_sway() -> void:
	if wordmark == null:
		return
	if _sway_tween != null:
		_sway_tween.kill()
		_sway_tween = null
	wordmark.pivot_offset = Vector2(wordmark.size.x * 0.5, wordmark.size.y * 0.45)
	wordmark.rotation = 0.0
	wordmark.offset_top = _sway_base_top
	if _title_fx_paused():
		return
	_sway_tween = create_tween().set_loops()
	_sway_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sway_tween.tween_property(wordmark, "rotation", 0.028, 1.7)
	_sway_tween.parallel().tween_property(wordmark, "offset_top", _sway_base_top + 3.5, 1.7)
	_sway_tween.tween_property(wordmark, "rotation", -0.028, 1.7)
	_sway_tween.parallel().tween_property(wordmark, "offset_top", _sway_base_top - 2.5, 1.7)


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
	if on:
		if _sway_tween != null:
			_sway_tween.kill()
			_sway_tween = null
		if wordmark:
			wordmark.rotation = 0.0
			wordmark.offset_top = _sway_base_top
	else:
		_start_wordmark_sway()


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
		_dismiss_modal(_quit)
	elif _brief != null and _brief.visible:
		_dismiss_modal(_brief)
	elif _howto != null and _howto.visible:
		_dismiss_modal(_howto)
	elif _mission != null and _mission.visible:
		_dismiss_modal(_mission)
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
		var row: Control = btn.get_parent() as Control
		if i >= entries.size():
			btn.visible = false
			if row:
				row.visible = false
			continue
		var e: Dictionary = entries[i]
		if row:
			row.visible = true
		btn.visible = true
		btn.disabled = not bool(e["unlocked"])
		var unlocked := bool(e["unlocked"])
		var cleared := bool(e["cleared"])
		var badge := "锁定 · 先完成上一关"
		if unlocked:
			badge = "可出击"
		if cleared:
			badge = "首通"
		var lid := str(e["id"])
		var glyph := _mission_glyph(lid)
		var mood := LevelDef.mood_tag(lid)
		btn.text = "%s  %s  「%s」\n%s" % [glyph, str(e["title"]), mood, badge]
		if btn.disabled:
			btn.modulate = Color(0.62, 0.64, 0.58)
		else:
			btn.modulate = _mission_tint(lid)
		btn.set_meta("level_id", lid)
		btn.set_meta("unlocked", unlocked)
		if i < _mission_accents.size() and _mission_accents[i] != null:
			var acc: ColorRect = _mission_accents[i]
			var sig: Color = LevelDef.signature_color(lid)
			if not unlocked:
				sig.a = 0.38
			acc.color = sig
			acc.visible = true
			acc.custom_minimum_size = Vector2(8, 56)
		if i < _mission_locks.size() and _mission_locks[i] != null:
			var lock_lbl: Label = _mission_locks[i]
			if not unlocked:
				lock_lbl.text = "锁"
				lock_lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.58))
			elif cleared:
				lock_lbl.text = "★"
				lock_lbl.add_theme_color_override("font_color", NightOps.OLIVE_HI)
			else:
				lock_lbl.text = "开"
				lock_lbl.add_theme_color_override("font_color", NightOps.OLIVE_DIM)


func _mission_glyph(id: String) -> String:
	match id:
		"warehouse":
			return "灯"
		"pump":
			return "泵"
		"railcut":
			return "塔"
		"depot":
			return "罐"
		_:
			return "月"


func _mission_tint(id: String) -> Color:
	match id:
		"warehouse":
			return Color(1.08, 0.95, 0.62)
		"pump":
			return Color(0.72, 1.10, 0.96)
		"railcut":
			return Color(0.95, 1.02, 0.78)
		"depot":
			return Color(1.14, 0.82, 0.48)
		_:
			return Color(0.92, 1.04, 0.88)


func _on_mission_picked(idx: int) -> void:
	if idx < 0 or idx >= _mission_btns.size():
		return
	var btn := _mission_btns[idx]
	if not bool(btn.get_meta("unlocked", false)):
		return
	var id := str(btn.get_meta("level_id", "yard"))
	if _mission:
		_mission.visible = false
	_pending_id = id
	_show_briefing(id)


func _show_briefing(level_id: String) -> void:
	var def: LevelDef = LevelDef.by_id(level_id)
	if _brief_codename:
		_brief_codename.text = LevelDef.operation_codename(level_id)
		_brief_codename.add_theme_color_override("font_color", LevelDef.signature_color(level_id))
	_brief_title.text = def.title
	_fill_teach_bullets(def.teaching)
	_brief_body.text = def.tutorial
	_fill_route_chips(def)
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
	# 0.15s fade; keep mouse filters so buttons stay live during the tween.
	if _modal_tween != null:
		_modal_tween.kill()
	_modal_tween = create_tween()
	_modal_tween.set_parallel(true)
	for c in layer.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = 0.0
			_modal_tween.tween_property(c, "modulate:a", 1.0, 0.15)


func _dismiss_modal(layer: CanvasLayer) -> void:
	if layer == null or not layer.visible:
		return
	if _modal_tween != null:
		_modal_tween.kill()
	_modal_tween = create_tween()
	_modal_tween.set_parallel(true)
	for c in layer.get_children():
		if c is CanvasItem:
			_modal_tween.tween_property(c, "modulate:a", 0.0, 0.15)
	_modal_tween.chain().tween_callback(func() -> void:
		layer.visible = false
	)


func _build_briefing() -> void:
	var ui := _modal_panel(20, 720.0, 540.0)
	_brief = ui["root"]
	var box: VBoxContainer = ui["box"]
	var kicker := Label.new()
	kicker.text = "任务档案"
	kicker.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	kicker.add_theme_font_size_override("font_size", 13)
	box.add_child(kicker)
	_brief_codename = Label.new()
	_brief_codename.name = "Codename"
	_brief_codename.add_theme_font_override("font", NightOps.display_font())
	_brief_codename.add_theme_font_size_override("font_size", 28)
	_brief_codename.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_brief_codename.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_brief_codename)
	_brief_title = Label.new()
	_brief_title.add_theme_font_size_override("font_size", 16)
	_brief_title.add_theme_color_override("font_color", NightOps.MUTED)
	_brief_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_brief_title)
	_brief_teach = VBoxContainer.new()
	_brief_teach.name = "TeachBullets"
	_brief_teach.add_theme_constant_override("separation", 4)
	box.add_child(_brief_teach)
	_brief_chips = HBoxContainer.new()
	_brief_chips.name = "RouteChips"
	_brief_chips.add_theme_constant_override("separation", 8)
	box.add_child(_brief_chips)
	_brief_body = Label.new()
	_brief_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_body.custom_minimum_size = Vector2(640, 96)
	_brief_body.add_theme_font_size_override("font_size", 13)
	_brief_body.add_theme_color_override("font_color", NightOps.MUTED)
	box.add_child(_brief_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(120, 48)
	back.pressed.connect(func() -> void:
		if _brief:
			_brief.visible = false
		_show_mission_select()
	)
	row.add_child(back)
	_brief_go = Button.new()
	_brief_go.name = "AcceptCta"
	_brief_go.text = "接受任务"
	_brief_go.custom_minimum_size = Vector2(220, 48)
	_brief_go.add_theme_font_size_override("font_size", 18)
	_brief_go.pressed.connect(func() -> void: _enter_mission(_pending_id))
	row.add_child(_brief_go)


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
	close.custom_minimum_size = Vector2(120, 48)
	close.pressed.connect(func() -> void: _dismiss_modal(_howto))
	box.add_child(close)


func _build_mission_select() -> void:
	var ui := _modal_panel(20, 580.0, 640.0)
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
	_mission_accents.clear()
	_mission_locks.clear()
	for i in GameSettings.LEVEL_ORDER.size():
		var row := HBoxContainer.new()
		row.name = "MissionRow%d" % i
		row.custom_minimum_size = Vector2(520, 68)
		row.add_theme_constant_override("separation", 8)
		var accent := ColorRect.new()
		accent.name = "Accent"
		accent.custom_minimum_size = Vector2(8, 56)
		accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(accent)
		_mission_accents.append(accent)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(420, 68)
		btn.add_theme_font_size_override("font_size", 15)
		btn.clip_text = false
		var idx := i
		btn.pressed.connect(func() -> void: _on_mission_picked(idx))
		row.add_child(btn)
		_mission_btns.append(btn)
		var lock_lbl := Label.new()
		lock_lbl.name = "LockIcon"
		lock_lbl.custom_minimum_size = Vector2(36, 56)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 22)
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock_lbl)
		_mission_locks.append(lock_lbl)
		_mission_box.add_child(row)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(120, 48)
	back.pressed.connect(func() -> void: _dismiss_modal(_mission))
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
	cancel.pressed.connect(func() -> void: _dismiss_modal(_quit))
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


func _build_ops_stamp() -> void:
	if _ops_stamp != null and is_instance_valid(_ops_stamp):
		return
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	var row := HBoxContainer.new()
	row.name = "OpsStamp"
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.offset_left = 20.0
	row.offset_right = -20.0
	row.offset_top = 10.0
	row.offset_bottom = 44.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(row)
	_ops_stamp = row
	row.add_child(_stamp_chip("StampDate", _ops_stamp_text(), NightOps.MUTED, Vector2(210, 28)))
	row.add_child(_stamp_chip("NightOpsBadge", "NIGHT OPS / 夜袭", NightOps.OLIVE_HI, Vector2(180, 28)))
	row.add_child(_stamp_chip("VersionChip", "4.7.2", NightOps.OLIVE_DIM, Vector2(64, 28)))


func _ops_stamp_text() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d  %02d:%02d UTC" % [
		int(d.get("year", 2026)),
		int(d.get("month", 1)),
		int(d.get("day", 1)),
		int(d.get("hour", 0)),
		int(d.get("minute", 0)),
	]


func _stamp_chip(p_name: String, text: String, col: Color, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = p_name
	panel.custom_minimum_size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.07, 0.82)
	sb.border_color = Color(col.r, col.g, col.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", col)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lab)
	return panel


func _fill_teach_bullets(teaching: String) -> void:
	if _brief_teach == null:
		return
	for c in _brief_teach.get_children():
		_brief_teach.remove_child(c)
		c.queue_free()
	var raw := teaching.strip_edges()
	var parts: PackedStringArray = PackedStringArray()
	for chunk in raw.split("。"):
		var bit := chunk.strip_edges()
		if bit != "":
			parts.append(bit)
	if parts.is_empty() and raw != "":
		parts.append(raw)
	for line in parts:
		var lab := Label.new()
		lab.text = "·  %s" % line
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 15)
		lab.add_theme_color_override("font_color", NightOps.TEXT)
		lab.custom_minimum_size = Vector2(640, 0)
		_brief_teach.add_child(lab)


func _fill_route_chips(def: LevelDef) -> void:
	if _brief_chips == null or def == null:
		return
	for c in _brief_chips.get_children():
		_brief_chips.remove_child(c)
		c.queue_free()
	var keys: Array = def.route_cells.keys()
	keys.sort()
	for key in keys:
		var id := str(key)
		var label := "主路"
		var col := Color(0.92, 0.28, 0.22)
		match id:
			"flank":
				label = "侧翼"
				col = Color(0.95, 0.62, 0.22)
			"sneak":
				label = "暗道"
				col = Color(0.42, 0.78, 0.62)
			"main":
				label = "主路"
				col = Color(0.92, 0.28, 0.22)
			_:
				label = id
		var chip := _stamp_chip("Chip_%s" % id, label, col, Vector2(72, 28))
		_brief_chips.add_child(chip)
	if def.door_cell.x >= 0:
		_brief_chips.add_child(_stamp_chip("Chip_door", "门锁", Color(0.78, 0.52, 0.28), Vector2(72, 28)))
