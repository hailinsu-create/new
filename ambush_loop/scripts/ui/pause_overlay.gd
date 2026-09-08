class_name PauseOverlay
extends CanvasLayer

## Shared pause / settings: mute, volume, return to title, redeploy (SETUP only).

signal closed
signal return_to_title
signal redeploy_requested

var _open: bool = false
var _dim: ColorRect
var _panel: PanelContainer
var _mute_btn: Button
var _vol: HSlider
var _vol_val: Label
var _redeploy_btn: Button
var _title_btn: Button
var _close_btn: Button


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
	_panel.offset_left = -190.0
	_panel.offset_right = 190.0
	_panel.offset_top = -168.0
	_panel.offset_bottom = 168.0
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
	_mute_btn = Button.new()
	_mute_btn.pressed.connect(_on_mute)
	box.add_child(_mute_btn)
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	var vol_l := Label.new()
	vol_l.text = "音量"
	vol_l.custom_minimum_size = Vector2(48, 0)
	vol_row.add_child(vol_l)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.05
	_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol.value_changed.connect(_on_vol)
	vol_row.add_child(_vol)
	_vol_val = Label.new()
	_vol_val.custom_minimum_size = Vector2(44, 0)
	vol_row.add_child(_vol_val)
	box.add_child(vol_row)
	_redeploy_btn = Button.new()
	_redeploy_btn.text = "重新部署"
	_redeploy_btn.pressed.connect(func() -> void: redeploy_requested.emit())
	box.add_child(_redeploy_btn)
	_title_btn = Button.new()
	_title_btn.text = "返回标题"
	_title_btn.pressed.connect(func() -> void: return_to_title.emit())
	box.add_child(_title_btn)
	_close_btn = Button.new()
	_close_btn.text = "继续"
	_close_btn.pressed.connect(dismiss)
	box.add_child(_close_btn)


func is_open() -> bool:
	return _open


func present(show_redeploy: bool, show_title: bool) -> void:
	_open = true
	visible = true
	_redeploy_btn.visible = true
	_redeploy_btn.disabled = not show_redeploy
	_redeploy_btn.text = "重新部署" if show_redeploy else "重新部署（仅布置阶段）"
	_title_btn.visible = show_title
	_refresh_audio()


func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func _refresh_audio() -> void:
	var gs = _gs()
	var muted := false
	var vol := 1.0
	if gs:
		muted = bool(gs.get("muted"))
		vol = clampf(float(gs.get("master_volume")), 0.0, 1.0)
	_mute_btn.text = "静音：开（M）" if muted else "静音：关（M）"
	_vol.set_value_no_signal(vol)
	_vol_val.text = "%d%%" % int(round(vol * 100.0))


func _on_mute() -> void:
	var gs = _gs()
	if gs:
		gs.toggle_mute()
	_refresh_audio()


func _on_vol(v: float) -> void:
	var gs = _gs()
	if gs:
		gs.set_volume(v)
	_vol_val.text = "%d%%" % int(round(v * 100.0))


func _gs():
	return get_node_or_null("/root/GameSettings")
