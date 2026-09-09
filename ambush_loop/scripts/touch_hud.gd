extends CanvasLayer
## Phone command bar: every keyboard command is a fat button. Hidden on desktop
## unless GameSettings.force_touch_hud / want_touch_controls().

var _host: Node = null
var _hint: Label = null
var _row_setup: HBoxContainer = null
var _row_watch: HBoxContainer = null
var _safe: MarginContainer = null
var _btns: Dictionary = {}
var _wave_chip: PanelContainer = null
var _wave_lab: Label = null


func bind_host(host: Node) -> void:
	_host = host


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_safe_area()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hint = Label.new()
	_hint.theme = NightOps.theme()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_hint.position = Vector2(12, 6)
	_hint.text = "触控：点掩体部署 → ↺↻ 射界 → 警报锁死"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_safe.anchor_top = 1.0
	_safe.anchor_bottom = 1.0
	_safe.offset_top = -148.0
	_safe.offset_bottom = 0.0
	_safe.offset_left = 0.0
	_safe.offset_right = 0.0
	_safe.add_theme_constant_override("margin_left", 8)
	_safe.add_theme_constant_override("margin_right", 8)
	_safe.add_theme_constant_override("margin_bottom", 8)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_safe)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(col)

	_row_setup = HBoxContainer.new()
	_row_setup.alignment = BoxContainer.ALIGNMENT_CENTER
	_row_setup.add_theme_constant_override("separation", 6)
	_row_setup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_setup)
	_add(_row_setup, "fire", "开火", Color(0.55, 0.48, 0.28))
	_add(_row_setup, "pack", "弹包", Color(0.40, 0.55, 0.40))
	_add(_row_setup, "trip", "绊索", Color(0.55, 0.40, 0.28))
	_add(_row_setup, "door", "门锁", Color(0.50, 0.42, 0.28))
	_add(_row_setup, "rotate_ccw", "↺", Color(0.42, 0.58, 0.36))
	_add(_row_setup, "rotate_cw", "↻", Color(0.42, 0.58, 0.36))
	_add(_row_setup, "clear", "收回", Color(0.38, 0.40, 0.36))
	_add(_row_setup, "alarm", "警报", Color(0.72, 0.22, 0.18))

	_row_watch = HBoxContainer.new()
	_row_watch.alignment = BoxContainer.ALIGNMENT_CENTER
	_row_watch.add_theme_constant_override("separation", 6)
	_row_watch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_watch)
	_add(_row_watch, "abort", "中止", Color(0.55, 0.20, 0.20))
	_add(_row_watch, "pause", "暂停", Color(0.35, 0.38, 0.42))
	_add(_row_watch, "speed", "倍速", Color(0.35, 0.38, 0.42))
	_add_wave_chip(_row_watch)
	_add(_row_watch, "mute", "静音", Color(0.35, 0.38, 0.42))
	_add(_row_watch, "log", "日志", Color(0.32, 0.42, 0.44))
	_add(_row_watch, "settings", "菜单", Color(0.32, 0.36, 0.40))


func _add_wave_chip(row: HBoxContainer) -> void:
	var p := PanelContainer.new()
	p.name = "WaveChip"
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(108, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.08, 0.92)
	sb.border_color = Color(0.82, 0.78, 0.38, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.name = "Lab"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.92, 0.88, 0.52))
	lab.text = "下一波 —"
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lab)
	row.add_child(p)
	_wave_chip = p
	_wave_lab = lab


func set_next_wave(text: String, show: bool) -> void:
	if _wave_chip == null:
		return
	_wave_chip.visible = show and text != ""
	if _wave_lab:
		_wave_lab.text = text


func _add(row: HBoxContainer, cmd: String, label: String, tint: Color) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(78, 56)
	b.theme = NightOps.theme()
	b.add_theme_font_size_override("font_size", 15)
	b.modulate = tint.lightened(0.22)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		if _host != null and _host.has_method("apply_touch_command"):
			_host.call("apply_touch_command", cmd)
	)
	row.add_child(b)
	_btns[cmd] = b


func _apply_safe_area() -> void:
	var sa := DisplayServer.get_display_safe_area()
	var wsz := DisplayServer.window_get_size()
	if wsz.x <= 0 or wsz.y <= 0 or _safe == null:
		return
	var vis := get_viewport().get_visible_rect().size
	var left := sa.position.x * vis.x / float(wsz.x)
	var right := (float(wsz.x) - sa.end.x) * vis.x / float(wsz.x)
	var bottom := (float(wsz.y) - sa.end.y) * vis.y / float(wsz.y)
	_safe.add_theme_constant_override("margin_left", int(maxi(8, int(round(left)))))
	_safe.add_theme_constant_override("margin_right", int(maxi(8, int(round(right)))))
	_safe.add_theme_constant_override("margin_bottom", int(maxi(8, int(round(bottom)))))
	if _hint:
		_hint.position = Vector2(12.0 + left, 6.0)


func set_hint(text: String) -> void:
	if _hint:
		_hint.text = text


func refresh_phase(phase_name: String, watching_paused: bool, speed_hi: bool, muted: bool, log_open: bool) -> void:
	_apply_safe_area()
	match phase_name:
		"SETUP":
			set_hint("触控：点掩体部署 → ↺↻ 射界 → 警报锁死")
		"WATCHING":
			set_hint("计划已锁死 — 只能暂停 / 倍速 / 中止，不能改部署")
		"REPLAY":
			set_hint("复盘只读 — 拖时间轴；警报钮返回布置")
		_:
			set_hint("点继续。菜单可清空记忆或回标题")
	if _btns.has("pause"):
		_btns["pause"].text = "继续" if watching_paused else "暂停"
	if _btns.has("speed"):
		_btns["speed"].text = "2×" if speed_hi else "1×"
	if _btns.has("mute"):
		_btns["mute"].text = "静音中" if muted else "静音"
	if _btns.has("log"):
		_btns["log"].text = "收日志" if log_open else "日志"
	if _btns.has("alarm"):
		_btns["alarm"].disabled = phase_name != "SETUP" and phase_name != "REPLAY"
	if _btns.has("clear"):
		_btns["clear"].disabled = phase_name != "SETUP"
	if _btns.has("fire"):
		_btns["fire"].disabled = phase_name != "SETUP"
	if _btns.has("pack"):
		_btns["pack"].disabled = phase_name != "SETUP"
	if _btns.has("trip"):
		_btns["trip"].disabled = phase_name != "SETUP"
	if _btns.has("door"):
		_btns["door"].disabled = phase_name != "SETUP"
	if _btns.has("rotate_cw"):
		_btns["rotate_cw"].disabled = phase_name != "SETUP"
	if _btns.has("rotate_ccw"):
		_btns["rotate_ccw"].disabled = phase_name != "SETUP"
	if _btns.has("abort"):
		_btns["abort"].disabled = phase_name != "WATCHING"
	if phase_name != "WATCHING" and _wave_chip:
		_wave_chip.visible = false
