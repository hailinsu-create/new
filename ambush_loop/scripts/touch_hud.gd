extends CanvasLayer
## Phone command bar. Simplified night-raid rail: 3 portraits + stacked
## crouch/bag + ↺/↻ + alarm. World verbs live on context hotspots.
## ALERT is pause/speed/abort.

const SETUP_RESIDENT := ["crouch", "bag", "rotate_ccw", "rotate_cw", "alarm"]
const WATCH_RESIDENT := ["abort", "pause", "speed"]
const PORTRAIT_INSET := 348

var _host: Node = null
var _hint: Label = null
var _row_setup: HBoxContainer = null
var _row_watch: HBoxContainer = null
var _stack_secondary: VBoxContainer = null
var _twist_pair: HBoxContainer = null
var _safe: MarginContainer = null
var _btns: Dictionary = {}
var _wave_chip: PanelContainer = null
var _wave_lab: Label = null
var _portrait_slot: Control = null
var _abort_armed: bool = false
var _abort_msec: int = 0
var _hold_cmd: String = ""
var _hold_next_msec: int = 0
var _hold_forced: bool = false
var _twist_swiping: bool = false
var _twist_swipe_acc: float = 0.0
var _compact_font: int = 12
var _compact_sep: int = 4
var _compact_stacked: bool = true
var _compact_need_w: float = 0.0
var _compact_avail_w: float = 0.0
var _compact_twist_min: float = 60.0
var _compact_alarm_w: float = 96.0
const HOLD_FIRST_MS := 160
const HOLD_REPEAT_MS := 110
const TWIST_SWIPE_PX := 28.0


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


func setup_bar_metrics() -> Dictionary:
	return {
		"font": _compact_font,
		"sep": _compact_sep,
		"stacked": _compact_stacked,
		"need_w": _compact_need_w,
		"avail_w": _compact_avail_w,
		"fits": _compact_need_w <= _compact_avail_w + 0.5,
		"twist_min": _compact_twist_min,
		"alarm_w": _compact_alarm_w,
		"bar_h": bar_height(),
	}


func simulate_narrow_layout(avail_w: float = 320.0) -> void:
	## Smoke / dump: pack the 5-key bar as if the remaining strip is narrow.
	_layout_compact(avail_w)


func _count_visible_buttons(row: Node) -> int:
	if row == null or (row is CanvasItem and not row.visible):
		return 0
	var n := 0
	if row is Button:
		return 1
	for c in row.get_children():
		n += _count_visible_buttons(c)
	return n


func _visible_cmds(row: Node) -> PackedStringArray:
	var out := PackedStringArray()
	_collect_visible_cmds(row, out)
	return out


func _collect_visible_cmds(row: Node, out: PackedStringArray) -> void:
	if row == null or (row is CanvasItem and not row.visible):
		return
	if row is Button:
		out.append(str(row.get_meta("cmd", "")))
		return
	for c in row.get_children():
		_collect_visible_cmds(c, out)


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
	if _hold_cmd != "":
		var b: Button = _btns.get(_hold_cmd)
		if b == null or b.disabled or (not b.is_pressed() and not _hold_forced):
			_hold_cmd = ""
		else:
			var now := Time.get_ticks_msec()
			if now >= _hold_next_msec:
				if _host != null and _host.has_method("apply_touch_command"):
					_host.call("apply_touch_command", _hold_cmd)
				_hold_next_msec = now + HOLD_REPEAT_MS


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
	_hint.text = "触控：点地走 · 短拖拖图 · 长按跑 · 近背面绕背 · 肖像角标跟上 · 按住↺/↻或左右滑拧射界"
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
	_row_setup.add_theme_constant_override("separation", 6)
	_row_setup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_setup)
	_stack_secondary = VBoxContainer.new()
	_stack_secondary.name = "SecondaryStack"
	_stack_secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack_secondary.add_theme_constant_override("separation", 3)
	_stack_secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_secondary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row_setup.add_child(_stack_secondary)
	_add(_stack_secondary, "crouch", "匍匐", Color(0.36, 0.48, 0.32), Vector2(60, 26))
	_add(_stack_secondary, "bag", "背包", Color(0.48, 0.44, 0.28), Vector2(60, 26))
	_add_spacer(_row_setup)
	_twist_pair = HBoxContainer.new()
	_twist_pair.name = "TwistPair"
	_twist_pair.alignment = BoxContainer.ALIGNMENT_CENTER
	_twist_pair.add_theme_constant_override("separation", 4)
	_twist_pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_twist_pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row_setup.add_child(_twist_pair)
	_add(_twist_pair, "rotate_ccw", "↺", Color(0.42, 0.58, 0.36), Vector2(60, 62))
	_add(_twist_pair, "rotate_cw", "↻", Color(0.42, 0.58, 0.36), Vector2(60, 62))
	_add(_row_setup, "alarm", "需枪", Color(0.72, 0.22, 0.18), Vector2(96, 56))
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
	_add(_row_setup, "clear", "收回", Color(0.38, 0.40, 0.36))

	_row_watch = HBoxContainer.new()
	_row_watch.alignment = BoxContainer.ALIGNMENT_CENTER
	_row_watch.add_theme_constant_override("separation", 10)
	_row_watch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row_watch)
	_add(_row_watch, "abort", "中止", Color(0.58, 0.20, 0.18), Vector2(120, 64))
	_add(_row_watch, "pause", "暂停", Color(0.40, 0.44, 0.38), Vector2(120, 64))
	_add(_row_watch, "speed", "倍速", Color(0.42, 0.46, 0.32), Vector2(120, 64))
	_add_wave_chip(_row_watch)
	_add(_row_watch, "nade_watch", "自动雷", Color(0.82, 0.42, 0.18))
	_add(_row_watch, "skip", "终局", Color(0.42, 0.52, 0.28))
	_add(_row_watch, "replay", "复盘", Color(0.32, 0.42, 0.50))
	_add(_row_watch, "mute", "静音", Color(0.35, 0.38, 0.42))
	_add(_row_watch, "log", "日志", Color(0.32, 0.42, 0.44))
	_add(_row_watch, "settings", "菜单", Color(0.32, 0.36, 0.40))
	_layout_compact()
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
	p.custom_minimum_size = Vector2(140, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.08, 0.94)
	sb.border_color = Color(0.90, 0.82, 0.36, 0.95)
	sb.set_border_width_all(2)
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
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(0.96, 0.90, 0.48))
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


func _add(parent: Control, cmd: String, label: String, tint: Color, minsz: Vector2 = Vector2(78, 56)) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = minsz
	b.theme = NightOps.theme()
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("tint", tint)
	b.set_meta("cmd", cmd)
	b.set_meta("label", label)
	_apply_btn_style(b, tint, false)
	if cmd == "rotate_cw" or cmd == "rotate_ccw":
		b.button_down.connect(func() -> void:
			_kick_btn(b)
			var c := str(b.get_meta("cmd", cmd))
			_hold_cmd = c
			_hold_next_msec = Time.get_ticks_msec() + HOLD_FIRST_MS
			_twist_swiping = true
			_twist_swipe_acc = 0.0
			if _host != null and _host.has_method("apply_touch_command"):
				_host.call("apply_touch_command", c)
		)
		b.button_up.connect(func() -> void:
			if _hold_cmd == str(b.get_meta("cmd", cmd)):
				_hold_cmd = ""
			_twist_swiping = false
		)
		b.gui_input.connect(func(ev: InputEvent) -> void:
			_on_twist_gui(ev)
		)
	else:
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
	parent.add_child(b)
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
		_layout_compact()
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
	_layout_compact()


func _layout_compact(avail_override: float = -1.0) -> void:
	## Stack 匍匐/背包, shrink type, park ↺/↻ + 需枪 in the right thumb cluster.
	var vis := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var left := 8 + PORTRAIT_INSET
	var right := 8
	if _safe:
		left = _safe.get_theme_constant("margin_left")
		right = _safe.get_theme_constant("margin_right")
	var avail := vis.x - float(left) - float(right)
	if avail_override > 0.0:
		avail = avail_override
	_compact_avail_w = avail
	_compact_stacked = true
	var tight := avail < 520.0
	_compact_font = 11 if tight else 12
	_compact_sep = 3 if tight else 4
	var stack_w := 52.0 if tight else 60.0
	var stack_h := 24.0 if tight else 26.0
	var twist := 52.0 if tight else 60.0
	var twist_h := 56.0 if tight else 62.0
	var alarm_w := 88.0 if tight else 96.0
	var alarm_h := 52.0 if tight else 56.0
	_compact_twist_min = twist
	_compact_alarm_w = alarm_w
	if _stack_secondary:
		_stack_secondary.add_theme_constant_override("separation", _compact_sep)
	if _twist_pair:
		_twist_pair.add_theme_constant_override("separation", _compact_sep)
	if _row_setup:
		_row_setup.add_theme_constant_override("separation", _compact_sep + 2)
	_size_btn("crouch", Vector2(stack_w, stack_h), _compact_font)
	_size_btn("bag", Vector2(stack_w, stack_h), _compact_font)
	_size_btn("rotate_ccw", Vector2(twist, twist_h), 16 if not tight else 15)
	_size_btn("rotate_cw", Vector2(twist, twist_h), 16 if not tight else 15)
	_size_btn("alarm", Vector2(alarm_w, alarm_h), 13 if not tight else 12)
	_compact_need_w = stack_w + twist * 2.0 + alarm_w + float(_compact_sep) * 5.0 + 8.0


func _size_btn(cmd: String, sz: Vector2, font: int) -> void:
	if not _btns.has(cmd):
		return
	var b: Button = _btns[cmd]
	if b == null:
		return
	b.custom_minimum_size = sz
	b.add_theme_font_size_override("font_size", font)


func simulate_hold_tick(cmd: String) -> void:
	## Smoke / dump: one hold-repeat without a live pointer.
	if not _btns.has(cmd):
		return
	_hold_cmd = cmd
	_hold_forced = true
	_hold_next_msec = Time.get_ticks_msec() - 1
	_process(0.0)
	_hold_forced = false
	_hold_cmd = ""


func simulate_swipe_twist(dx: float) -> int:
	## Smoke / dump: left/right swipe-to-twist on the compact bar.
	var cmd := "rotate_cw" if dx > 0.0 else "rotate_ccw"
	var steps := maxi(1, int(round(absf(dx) / TWIST_SWIPE_PX)))
	var n := 0
	for _i in steps:
		if _host != null and _host.has_method("apply_touch_command"):
			_host.call("apply_touch_command", cmd)
			n += 1
	return n


func _on_twist_gui(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_twist_swiping = st.pressed
		if st.pressed:
			_twist_swipe_acc = 0.0
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_twist_swiping = event.pressed
		if event.pressed:
			_twist_swipe_acc = 0.0
		return
	var rel_x := 0.0
	if event is InputEventScreenDrag:
		rel_x = (event as InputEventScreenDrag).relative.x
	elif event is InputEventMouseMotion and _twist_swiping:
		rel_x = (event as InputEventMouseMotion).relative.x
	else:
		return
	_twist_swipe_acc += rel_x
	while absf(_twist_swipe_acc) >= TWIST_SWIPE_PX:
		var swipe_cmd := "rotate_cw" if _twist_swipe_acc > 0.0 else "rotate_ccw"
		if _hold_cmd != "" and _hold_cmd != swipe_cmd:
			_hold_cmd = ""
		if _host != null and _host.has_method("apply_touch_command"):
			_host.call("apply_touch_command", swipe_cmd)
		_twist_swipe_acc -= TWIST_SWIPE_PX * signf(_twist_swipe_acc)


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
	var w := maxf(_compact_alarm_w, 88.0)
	if lab.length() >= 4:
		w = maxf(w, 96.0)
	b.custom_minimum_size = Vector2(w, maxf(52.0, b.custom_minimum_size.y))


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
			set_hint("点地走 · 短拖拖图 · 长按跑 · 近背面绕背/割喉 · 角标跟上 · 匍匐 · 按住↺/↻或左右滑拧射界 · 拉警报")
		"SWEEP":
			set_hint("打扫：走近尸体热区搜刮/拖尸 → 背包换枪 → 下一波或撤离")
		"WATCHING":
			set_hint("警报中 — 暂停 / 倍速 / 中止。自动火力与手雷。")
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
