extends CanvasLayer
## Phone command bar. Simplified night-raid rail: 3 portraits + crouch + bag +
## alarm CTA. World verbs live on context hotspots. ALERT is pause/speed/abort.

const SETUP_RESIDENT := ["crouch", "bag", "alarm"]
const WATCH_RESIDENT := ["abort", "pause", "speed"]
const PORTRAIT_INSET := 348

var _host: Node = null
var _hint: Label = null
var _row_setup: HBoxContainer = null
var _row_watch: HBoxContainer = null
var _safe: MarginContainer = null
var _btns: Dictionary = {}
var _wave_chip: PanelContainer = null
var _wave_lab: Label = null
var _portrait_slot: Control = null
var _abort_armed: bool = false
var _abort_msec: int = 0


func bind_host(host: Node) -> void:
	_host = host


func portrait_slot() -> Control:
	return _portrait_slot


func bar_height() -> float:
	return 132.0


func setup_visible_button_count() -> int:
	return _count_visible_buttons(_row_setup)


func watch_visible_button_count() -> int:
	return _count_visible_buttons(_row_watch)


func setup_visible_cmds() -> PackedStringArray:
	return _visible_cmds(_row_setup)


func watch_visible_cmds() -> PackedStringArray:
	return _visible_cmds(_row_watch)


func _count_visible_buttons(row: HBoxContainer) -> int:
	if row == null or not row.visible:
		return 0
	var n := 0
	for c in row.get_children():
		if c is Button and c.visible:
			n += 1
	return n


func _visible_cmds(row: HBoxContainer) -> PackedStringArray:
	var out := PackedStringArray()
	if row == null:
		return out
	for c in row.get_children():
		if c is Button and c.visible:
			out.append(str(c.get_meta("cmd", "")))
	return out


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_safe_area()
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _abort_armed and Time.get_ticks_msec() - _abort_msec > 2200:
		_abort_armed = false
		if _btns.has("abort") and _btns["abort"]:
			_btns["abort"].text = "中止"


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
	_hint.text = "触控：点肖像选人 → 点地走 / 靠近出热区 → 匍匐 → 背包 → 拉警报"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)

	var plate := ColorRect.new()
	plate.name = "BarPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = Color(0.05, 0.045, 0.032, 0.90)
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_top = -132.0
	root.add_child(plate)
	var plate_rail := ColorRect.new()
	plate_rail.name = "BarRail"
	plate_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_rail.color = Color(0.62, 0.50, 0.24, 0.70)
	plate_rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	plate_rail.offset_bottom = 3.0
	plate.add_child(plate_rail)

	_portrait_slot = Control.new()
	_portrait_slot.name = "PortraitSlot"
	_portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_slot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait_slot.anchor_left = 0.0
	_portrait_slot.anchor_right = 0.0
	_portrait_slot.anchor_top = 1.0
	_portrait_slot.anchor_bottom = 1.0
	_portrait_slot.offset_left = 8.0
	_portrait_slot.offset_right = 8.0 + 336.0
	_portrait_slot.offset_top = -120.0
	_portrait_slot.offset_bottom = -8.0
	root.add_child(_portrait_slot)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_safe.anchor_top = 1.0
	_safe.anchor_bottom = 1.0
	_safe.offset_top = -124.0
	_safe.offset_bottom = 0.0
	_safe.offset_left = 0.0
	_safe.offset_right = 0.0
	_safe.add_theme_constant_override("margin_left", 8 + PORTRAIT_INSET)
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
	_row_setup.add_theme_constant_override("separation", 8)
	_row_setup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_setup)
	_add(_row_setup, "crouch", "匍匐", Color(0.36, 0.48, 0.32), Vector2(96, 60))
	_add(_row_setup, "bag", "背包", Color(0.48, 0.44, 0.28), Vector2(96, 60))
	_add_spacer(_row_setup)
	_add(_row_setup, "alarm", "需枪", Color(0.72, 0.22, 0.18), Vector2(132, 64))
	# Hidden: still wired so apply_touch_command / smoke keep working.
	_add(_row_setup, "fire", "开火", Color(0.55, 0.48, 0.28))
	_add(_row_setup, "pack", "弹包", Color(0.40, 0.55, 0.40))
	_add(_row_setup, "trip", "绊索", Color(0.55, 0.40, 0.28))
	_add(_row_setup, "nade", "雷点", Color(0.82, 0.42, 0.18))
	_add(_row_setup, "decoy", "诱饵", Color(0.82, 0.72, 0.28))
	_add(_row_setup, "knife", "割喉", Color(0.62, 0.28, 0.22))
	_add(_row_setup, "whistle", "口哨", Color(0.72, 0.62, 0.28))
	_add(_row_setup, "bind", "捆绑", Color(0.55, 0.48, 0.28))
	_add(_row_setup, "pass", "递装", Color(0.42, 0.62, 0.48))
	_add(_row_setup, "door", "门锁", Color(0.50, 0.42, 0.28))
	_add(_row_setup, "rotate_ccw", "↺", Color(0.42, 0.58, 0.36))
	_add(_row_setup, "rotate_cw", "↻", Color(0.42, 0.58, 0.36))
	_add(_row_setup, "clear", "收回", Color(0.38, 0.40, 0.36))

	_row_watch = HBoxContainer.new()
	_row_watch.alignment = BoxContainer.ALIGNMENT_CENTER
	_row_watch.add_theme_constant_override("separation", 10)
	_row_watch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_watch)
	_add(_row_watch, "abort", "中止", Color(0.55, 0.20, 0.20), Vector2(108, 60))
	_add(_row_watch, "pause", "暂停", Color(0.35, 0.38, 0.42), Vector2(108, 60))
	_add(_row_watch, "speed", "倍速", Color(0.35, 0.38, 0.42), Vector2(108, 60))
	_add_wave_chip(_row_watch)
	_add(_row_watch, "nade_watch", "自动雷", Color(0.82, 0.42, 0.18))
	_add(_row_watch, "skip", "终局", Color(0.42, 0.52, 0.28))
	_add(_row_watch, "replay", "复盘", Color(0.32, 0.42, 0.50))
	_add(_row_watch, "mute", "静音", Color(0.35, 0.38, 0.42))
	_add(_row_watch, "log", "日志", Color(0.32, 0.42, 0.44))
	_add(_row_watch, "settings", "菜单", Color(0.32, 0.36, 0.40))
	_hide_overflow()


func _add_spacer(row: HBoxContainer) -> void:
	var s := Control.new()
	s.name = "Spacer"
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.custom_minimum_size = Vector2(12, 8)
	row.add_child(s)


func _add_wave_chip(row: HBoxContainer) -> void:
	var p := PanelContainer.new()
	p.name = "WaveChip"
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(124, 56)
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


func _add(row: HBoxContainer, cmd: String, label: String, tint: Color, minsz: Vector2 = Vector2(78, 56)) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = minsz
	b.theme = NightOps.theme()
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("tint", tint)
	b.set_meta("cmd", cmd)
	b.set_meta("label", label)
	_apply_btn_style(b, tint, false)
	b.pressed.connect(func() -> void:
		_kick_btn(b)
		var c := str(b.get_meta("cmd", cmd))
		if c == "abort":
			if not _abort_armed:
				_abort_armed = true
				_abort_msec = Time.get_ticks_msec()
				b.text = "确认中止"
				return
			_abort_armed = false
			b.text = "中止"
		if _host != null and _host.has_method("apply_touch_command"):
			_host.call("apply_touch_command", c)
	)
	var lock := Label.new()
	lock.name = "LockMark"
	lock.text = "锁"
	lock.visible = false
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lock.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lock.add_theme_font_size_override("font_size", 11)
	lock.add_theme_color_override("font_color", Color(1.0, 0.32, 0.18, 0.95))
	lock.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.02, 0.9))
	lock.add_theme_constant_override("shadow_offset_x", 1)
	lock.add_theme_constant_override("shadow_offset_y", 1)
	lock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lock.offset_left = -22.0
	lock.offset_top = 2.0
	lock.offset_right = -4.0
	lock.offset_bottom = 16.0
	b.add_child(lock)
	row.add_child(b)
	_btns[cmd] = b


func _apply_btn_style(b: Button, tint: Color, locked: bool) -> void:
	var bg := Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.18, 0.96)
	var border := Color(tint.r, tint.g, tint.b, 0.85).lightened(0.12)
	if locked:
		bg = Color(0.10, 0.10, 0.09, 0.88)
		border = Color(0.28, 0.22, 0.18, 0.7)
	var normal := NightOps.flat(bg, border, 1, 10, 6)
	var hover := NightOps.flat(bg.lightened(0.18), border.lightened(0.2), 2, 10, 6)
	var pressed := NightOps.flat(bg.darkened(0.18), border, 2, 10, 6)
	var disabled := NightOps.flat(Color(0.09, 0.09, 0.08, 0.82), Color(0.22, 0.20, 0.18), 1, 10, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color(0.94, 0.92, 0.78) if not locked else Color(0.42, 0.40, 0.38))
	b.modulate = Color.WHITE if not locked else Color(0.62, 0.60, 0.58)


func _kick_btn(b: Button) -> void:
	if b == null or b.disabled:
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_safe_area() -> void:
	var sa := DisplayServer.get_display_safe_area()
	var wsz := DisplayServer.window_get_size()
	if wsz.x <= 0 or wsz.y <= 0 or _safe == null:
		return
	var vis := get_viewport().get_visible_rect().size
	var left := sa.position.x * vis.x / float(wsz.x)
	var right := (float(wsz.x) - sa.end.x) * vis.x / float(wsz.x)
	var bottom := (float(wsz.y) - sa.end.y) * vis.y / float(wsz.y)
	_safe.add_theme_constant_override("margin_left", int(maxi(8, int(round(left)))) + PORTRAIT_INSET)
	_safe.add_theme_constant_override("margin_right", int(maxi(8, int(round(right)))))
	_safe.add_theme_constant_override("margin_bottom", int(maxi(8, int(round(bottom)))))
	if _portrait_slot:
		_portrait_slot.offset_left = 8.0 + left
		_portrait_slot.offset_right = 8.0 + left + 336.0
	if _hint:
		_hint.position = Vector2(12.0 + left, 6.0)


func set_hint(text: String) -> void:
	if _hint:
		_hint.text = text


func set_alarm_cta(text: String) -> void:
	if not _btns.has("alarm"):
		return
	var b: Button = _btns["alarm"]
	if b == null:
		return
	var lab := text.strip_edges()
	if lab == "":
		lab = "警报"
	b.text = lab
	b.set_meta("label", lab)
	b.custom_minimum_size = Vector2(132 if lab.length() >= 4 else 118, 64)


func refresh_phase(
	phase_name: String,
	watching_paused: bool,
	speed_hi: bool,
	muted: bool,
	log_open: bool,
	has_pack: bool = true,
	has_door: bool = true
) -> void:
	_apply_safe_area()
	if _row_setup:
		_row_setup.visible = phase_name == "SETUP" or phase_name == "SWEEP"
	if _row_watch:
		_row_watch.visible = phase_name != "SETUP" and phase_name != "SWEEP"
	match phase_name:
		"SETUP":
			set_hint("触控：点肖像选人 → 点地走 / 靠近热区 → 匍匐躲岗 → 开匣 → 背包 → 拉警报")
		"SWEEP":
			set_hint("打扫：走近尸体热区搜刮/拖尸 → 背包换枪 → 下一波或撤离")
		"WATCHING":
			set_hint("警报中 — 自动火力 / 自动手雷。暂停 / 倍速 / 中止。走位等打扫")
		"REPLAY":
			set_hint("复盘只读 — 拖时间轴；警报钮返回搜刮")
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
		_btns["alarm"].disabled = phase_name != "SETUP" and phase_name != "SWEEP" and phase_name != "REPLAY"
	if _btns.has("clear"):
		_btns["clear"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("fire"):
		_btns["fire"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("pack"):
		_btns["pack"].visible = false
		_btns["pack"].disabled = (phase_name != "SETUP" and phase_name != "SWEEP") or not has_pack
	if _btns.has("trip"):
		_btns["trip"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("nade"):
		_btns["nade"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("bag"):
		_btns["bag"].disabled = false
	if _btns.has("decoy"):
		_btns["decoy"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("crouch"):
		_btns["crouch"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("knife"):
		_btns["knife"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("whistle"):
		_btns["whistle"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("bind"):
		_btns["bind"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("pass"):
		_btns["pass"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("nade_watch"):
		_btns["nade_watch"].disabled = phase_name != "WATCHING"
	if _btns.has("door"):
		_btns["door"].visible = false
		_btns["door"].disabled = (phase_name != "SETUP" and phase_name != "SWEEP") or not has_door
	if _btns.has("replay"):
		_btns["replay"].disabled = phase_name != "FAILED" and phase_name != "WON"
	if _btns.has("rotate_cw"):
		_btns["rotate_cw"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("rotate_ccw"):
		_btns["rotate_ccw"].disabled = phase_name != "SETUP" and phase_name != "SWEEP"
	if _btns.has("abort"):
		_btns["abort"].disabled = phase_name != "WATCHING"
	if _btns.has("skip"):
		_btns["skip"].disabled = phase_name != "WATCHING"
	if phase_name != "WATCHING":
		_abort_armed = false
		if _btns.has("abort"):
			_btns["abort"].text = "中止"
		if _wave_chip:
			_wave_chip.visible = false
	_paint_crouch_sticky()
	_hide_overflow()
	_paint_lock_states(phase_name)


func _hide_overflow() -> void:
	for cmd in _btns.keys():
		var b: Button = _btns[cmd]
		if b == null:
			continue
		var c := str(cmd)
		if SETUP_RESIDENT.has(c) or WATCH_RESIDENT.has(c):
			b.visible = true
			continue
		b.visible = false


func _paint_crouch_sticky() -> void:
	if not _btns.has("crouch"):
		return
	var b: Button = _btns["crouch"]
	var crouched := false
	if _host != null and _host.get("selected") != null:
		var op = _host.selected
		crouched = op.get("stance") != null and int(op.stance) == 1
	b.text = "匍中" if crouched else "匍匐"
	var tint: Color = b.get_meta("tint", Color(0.36, 0.48, 0.32))
	_apply_btn_style(b, tint, false)
	if crouched:
		b.modulate = Color(1.16, 1.12, 0.82)


func _paint_lock_states(phase_name: String) -> void:
	var setup_cmds := ["fire", "pack", "trip", "nade", "decoy", "crouch", "knife", "whistle", "bind", "pass", "door", "rotate_cw", "rotate_ccw", "clear", "alarm"]
	for cmd in _btns.keys():
		var b: Button = _btns[cmd]
		if b == null:
			continue
		var tint: Color = b.get_meta("tint", Color(0.4, 0.4, 0.36))
		var locked := b.disabled and setup_cmds.has(str(cmd)) and phase_name == "WATCHING"
		if str(cmd) != "crouch":
			_apply_btn_style(b, tint, locked)
		var lock := b.get_node_or_null("LockMark") as Label
		if lock:
			lock.visible = locked
		if str(cmd) == "alarm" and (phase_name == "SETUP" or phase_name == "SWEEP") and not b.disabled:
			b.modulate = Color(1.18, 0.92, 0.88)
		if str(cmd) == "abort" and phase_name == "WATCHING" and not b.disabled and not _abort_armed:
			b.modulate = Color(1.12, 0.85, 0.82)
		if str(cmd) == "skip" and phase_name == "WATCHING" and not b.disabled:
			b.modulate = Color(1.05, 1.12, 0.88)
