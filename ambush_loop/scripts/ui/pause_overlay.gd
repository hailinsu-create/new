class_name PauseOverlay
extends CanvasLayer

## Shared pause / settings: mute, Music/SFX volumes, return to title, redeploy (SETUP only).

signal closed
signal return_to_title
signal redeploy_requested
signal memory_wipe_requested
signal touch_hud_toggled

var _open: bool = false
var _dim: ColorRect
var _panel: PanelContainer
var _mute_btn: Button
var _music: HSlider
var _music_val: Label
var _sfx: HSlider
var _sfx_val: Label
var _redeploy_btn: Button
var _title_btn: Button
var _touch_btn: Button
var _wipe_btn: Button
var _close_btn: Button
var _wipe_armed: bool = false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.02, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.theme = NightOps.theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -210.0
	_panel.offset_right = 210.0
	_panel.offset_top = -268.0
	_panel.offset_bottom = 268.0
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "作战设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(title)
	_mute_btn = _fat_btn()
	_mute_btn.pressed.connect(_on_mute)
	box.add_child(_mute_btn)
	box.add_child(_make_vol_row("音乐", true))
	box.add_child(_make_vol_row("音效", false))
	_touch_btn = _fat_btn()
	_touch_btn.pressed.connect(_on_touch_toggle)
	box.add_child(_touch_btn)
	_redeploy_btn = _fat_btn()
	_redeploy_btn.text = "重新部署"
	_redeploy_btn.pressed.connect(func() -> void: redeploy_requested.emit())
	box.add_child(_redeploy_btn)
	_wipe_btn = _fat_btn()
	_wipe_btn.pressed.connect(_on_wipe)
	box.add_child(_wipe_btn)
	_title_btn = _fat_btn()
	_title_btn.text = "返回标题"
	_title_btn.pressed.connect(func() -> void: return_to_title.emit())
	box.add_child(_title_btn)
	_close_btn = _fat_btn()
	_close_btn.text = "继续"
	_close_btn.pressed.connect(dismiss)
	box.add_child(_close_btn)


func _fat_btn() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 44)
	return b


func _make_vol_row(caption: String, is_music: bool) -> HBoxContainer:
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	var vol_l := Label.new()
	vol_l.text = caption
	vol_l.custom_minimum_size = Vector2(48, 0)
	vol_row.add_child(vol_l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.custom_minimum_size = Vector2(44, 0)
	if is_music:
		_music = sl
		_music_val = val
		sl.value_changed.connect(_on_music)
	else:
		_sfx = sl
		_sfx_val = val
		sl.value_changed.connect(_on_sfx)
	vol_row.add_child(sl)
	vol_row.add_child(val)
	return vol_row


func is_open() -> bool:
	return _open


func present(show_redeploy: bool, show_title: bool) -> void:
	_open = true
	visible = true
	_wipe_armed = false
	_redeploy_btn.visible = true
	_redeploy_btn.disabled = not show_redeploy
	_redeploy_btn.text = "重新部署" if show_redeploy else "重新部署（仅布置阶段）"
	_title_btn.visible = show_title
	if _wipe_btn:
		_wipe_btn.visible = show_title
	_refresh_audio()


func dismiss() -> void:
	if not _open:
		return
	_open = false
	_wipe_armed = false
	visible = false
	closed.emit()


func _refresh_audio() -> void:
	var gs = _gs()
	var muted := false
	var mv := 1.0
	var sv := 1.0
	if gs:
		muted = bool(gs.get("muted"))
		mv = clampf(float(gs.get("music_volume")), 0.0, 1.0)
		sv = clampf(float(gs.get("sfx_volume")), 0.0, 1.0)
	_mute_btn.text = "静音：开" if muted else "静音：关"
	if _touch_btn:
		var touch_on := false
		if gs and gs.has_method("want_touch_controls"):
			touch_on = bool(gs.want_touch_controls())
		_touch_btn.text = "触控底栏：开" if touch_on else "触控底栏：关"
	if _wipe_btn:
		_wipe_btn.text = "再点确认：清空记忆" if _wipe_armed else "清空记忆（需确认）"
	if _music:
		_music.set_value_no_signal(mv)
	if _music_val:
		_music_val.text = "%d%%" % int(round(mv * 100.0))
	if _sfx:
		_sfx.set_value_no_signal(sv)
	if _sfx_val:
		_sfx_val.text = "%d%%" % int(round(sv * 100.0))


func _on_mute() -> void:
	var gs = _gs()
	if gs:
		gs.toggle_mute()
	_refresh_audio()


func _on_music(v: float) -> void:
	var gs = _gs()
	if gs:
		if gs.has_method("set_music_volume"):
			gs.set_music_volume(v)
		else:
			gs.set_volume(v)
	if _music_val:
		_music_val.text = "%d%%" % int(round(v * 100.0))


func _on_sfx(v: float) -> void:
	var gs = _gs()
	if gs:
		if gs.has_method("set_sfx_volume"):
			gs.set_sfx_volume(v)
		else:
			gs.set_volume(v)
	if _sfx_val:
		_sfx_val.text = "%d%%" % int(round(v * 100.0))


func _on_touch_toggle() -> void:
	var gs = _gs()
	if gs and gs.has_method("set_force_touch_hud"):
		gs.set_force_touch_hud(not bool(gs.force_touch_hud))
	touch_hud_toggled.emit()
	_refresh_audio()


func _on_wipe() -> void:
	if not _wipe_armed:
		_wipe_armed = true
		_refresh_audio()
		return
	_wipe_armed = false
	memory_wipe_requested.emit()


func _gs():
	return get_node_or_null("/root/GameSettings")
