class_name TouchHUD
extends Control

## Portrait first touch HUD.  Buttons are deliberately large enough for the
## 360x640 fallback after the 720x1280 logical viewport is scaled by 0.5.

signal card_selected(index: int)
signal facing_requested(delta_deg: float)
signal aim_requested
signal tripwire_requested
signal clear_requested
signal mode_requested
signal pack_requested
signal door_requested
signal alarm_requested
signal pause_requested
signal speed_requested
signal log_requested
signal safe_area_changed(safe_rect: Rect2, source: String)
signal safe_area_refresh_requested

const BUTTON_MIN := 96.0
const GAP := 12.0
const H_MARGIN := 8.0
const V_MARGIN := 8.0
const CARD_HEIGHT := 96.0
const ACTION_COUNT := 12


static func safe_rect_for_viewport(viewport_size: Vector2, insets: Vector4) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	if insets.x < 0.0 or insets.y < 0.0 or insets.z < 0.0 or insets.w < 0.0:
		return viewport_rect
	var left := minf(insets.x, viewport_size.x)
	var top := minf(insets.y, viewport_size.y)
	var right := minf(insets.z, maxf(viewport_size.x - left, 0.0))
	var bottom := minf(insets.w, maxf(viewport_size.y - top, 0.0))
	if left + right >= viewport_size.x or top + bottom >= viewport_size.y:
		return viewport_rect
	return Rect2(Vector2(left, top), Vector2(viewport_size.x - left - right, viewport_size.y - top - bottom))

var card_buttons: Array[Button] = []
var left_button: Button
var right_button: Button
var aim_button: Button
var tripwire_button: Button
var clear_button: Button
var mode_button: Button
var pack_button: Button
var door_button: Button
var alarm_button: Button
var pause_button: Button
var speed_button: Button
var log_button: Button
var event_log: RichTextLabel
var log_panel: PanelContainer
var log_close_button: Button
var log_prev_button: Button
var log_next_button: Button
var log_page_label: Label
var _built := false
var _active_button: Button = null
var _active_blocking := false
var _bottom_panel: PanelContainer = null
var _action_grid: GridContainer = null
var _log_lines := PackedStringArray()
var _log_page := 0
var _log_return_to_result := false
var safe_rect := Rect2()
var safe_area_source := "fallback"
var _test_safe_rect_set := false
var _test_safe_rect := Rect2()
var _safe_area_refresh_queued := false

const LOG_PAGE_SIZE := 10


static func layout_metrics(viewport_size: Vector2, safe_rect: Rect2 = Rect2()) -> Dictionary:
	var width := maxf(viewport_size.x, 1.0)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var effective_safe_rect := _normalize_safe_rect(viewport_rect, safe_rect)
	var columns := 6
	if effective_safe_rect.size.x < 324.0:
		columns = 2
	elif effective_safe_rect.size.x < 600.0:
		columns = 3
	var inner_width := maxf(effective_safe_rect.size.x - H_MARGIN * 2.0, 0.0)
	var cell_width := (inner_width - float(columns - 1) * GAP) / float(columns)
	var rows := ceili(float(ACTION_COUNT) / float(columns))
	var actions_height := float(rows) * BUTTON_MIN + float(rows - 1) * GAP
	var panel_height := V_MARGIN * 2.0 + CARD_HEIGHT + GAP + actions_height + 2.0
	var panel_rect := Rect2(
		Vector2(effective_safe_rect.position.x, effective_safe_rect.end.y - panel_height),
		Vector2(effective_safe_rect.size.x, panel_height)
	)
	var cards_rect := Rect2(Vector2(H_MARGIN, panel_rect.position.y + V_MARGIN), Vector2(inner_width, CARD_HEIGHT))
	cards_rect.position.x += effective_safe_rect.position.x
	var actions_rect := Rect2(
		Vector2(effective_safe_rect.position.x + H_MARGIN, cards_rect.end.y + GAP),
		Vector2(inner_width, actions_height)
	)
	return {
		"viewport_rect": viewport_rect,
		"safe_rect": effective_safe_rect,
		"panel_rect": panel_rect,
		"cards_rect": cards_rect,
		"actions_rect": actions_rect,
		"columns": columns,
		"rows": rows,
		"cell_width": cell_width,
		"button_min": BUTTON_MIN,
		"gap": GAP,
		"fits_horizontal": cell_width >= BUTTON_MIN and actions_rect.position.x >= effective_safe_rect.position.x - 0.01 and actions_rect.end.x <= effective_safe_rect.end.x + 0.01,
		"fits_vertical": panel_rect.position.y >= effective_safe_rect.position.y - 0.01 and panel_rect.end.y <= effective_safe_rect.end.y + 0.01,
	}


static func is_valid_safe_rect(candidate: Rect2) -> bool:
	return candidate.size.x >= 1.0 and candidate.size.y >= 1.0


static func _normalize_safe_rect(viewport_rect: Rect2, candidate: Rect2) -> Rect2:
	if not is_valid_safe_rect(candidate):
		return viewport_rect
	var clipped := candidate.intersection(viewport_rect)
	return clipped if is_valid_safe_rect(clipped) else viewport_rect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	safe_rect = Rect2(Vector2.ZERO, _viewport_size())
	safe_area_source = "initial_fallback"
	_layout_responsive()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_active_pointer()
		return
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_queue_safe_area_refresh()


func _on_viewport_size_changed() -> void:
	_queue_safe_area_refresh()


func _queue_safe_area_refresh() -> void:
	if _safe_area_refresh_queued:
		return
	_safe_area_refresh_queued = true
	call_deferred("_refresh_safe_area_deferred")


func _refresh_safe_area_deferred() -> void:
	_safe_area_refresh_queued = false
	if _test_safe_rect_set:
		refresh_safe_area()
	else:
		safe_area_refresh_requested.emit()


func set_safe_rect_for_test(candidate: Rect2) -> void:
	_test_safe_rect_set = true
	_test_safe_rect = candidate
	if is_valid_safe_rect(candidate):
		set_safe_rect(candidate, "injected")
	else:
		set_safe_rect(Rect2(Vector2.ZERO, _viewport_size()), "injected_invalid_fallback")


func clear_safe_rect_for_test() -> void:
	_test_safe_rect_set = false
	_test_safe_rect = Rect2()
	safe_area_refresh_requested.emit()


func set_safe_rect(candidate: Rect2, source: String = "provided") -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	safe_rect = _normalize_safe_rect(viewport_rect, candidate)
	safe_area_source = source
	if _built:
		_layout_responsive()
	clear_active_pointer()
	safe_area_changed.emit(safe_rect, safe_area_source)
	print("SAFE_AREA_LAYOUT source=%s safe_rect=%s viewport=%s" % [safe_area_source, safe_rect, viewport_rect])
	return safe_rect


func refresh_safe_area() -> Rect2:
	var viewport_size := _viewport_size()
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var resolved := _resolve_safe_rect(viewport_rect)
	return set_safe_rect(resolved.rect, str(resolved.source))


func clear_active_pointer() -> void:
	_active_button = null
	_active_blocking = false


func _viewport_size() -> Vector2:
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)
	return viewport_size


func _resolve_safe_rect(viewport_rect: Rect2) -> Dictionary:
	if _test_safe_rect_set:
		if is_valid_safe_rect(_test_safe_rect):
			return {"rect": _normalize_safe_rect(viewport_rect, _test_safe_rect), "source": "injected"}
		return {"rect": viewport_rect, "source": "injected_invalid_fallback"}

	var mobile := OS.get_name() == "Android" or OS.get_name() == "iOS"
	if not mobile:
		return {"rect": viewport_rect, "source": "non_mobile_fallback"}

	var display_safe_area := DisplayServer.get_display_safe_area()
	var display_rect := Rect2(Vector2(display_safe_area.position), Vector2(display_safe_area.size))
	if not is_valid_safe_rect(display_rect):
		return {"rect": viewport_rect, "source": "invalid_fallback"}
	var screen_to_local := get_screen_transform().affine_inverse()
	var local_rect := map_rect(display_rect, screen_to_local)
	var clipped := local_rect.intersection(viewport_rect)
	if not is_valid_safe_rect(clipped):
		return {"rect": viewport_rect, "source": "offscreen_fallback"}
	return {"rect": clipped, "source": "display_safe_area"}


static func map_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var points := [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * Vector2(rect.position.x, rect.end.y),
		transform * rect.end,
	]
	var mapped := Rect2(points[0], Vector2.ZERO)
	for point in points:
		mapped = mapped.expand(point)
	return mapped


func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bottom := PanelContainer.new()
	bottom.name = "BottomPanel"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -336.0
	bottom.offset_bottom = 0.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _panel_style())
	add_child(bottom)
	_bottom_panel = bottom

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bottom.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var cards := HBoxContainer.new()
	cards.name = "OperatorCards"
	cards.custom_minimum_size = Vector2(0, 96)
	cards.add_theme_constant_override("separation", 12)
	body.add_child(cards)
	for i in 3:
		var card := _button("队员%d" % (i + 1), Vector2(0, 96))
		card.name = "OperatorCard%d" % (i + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func() -> void: card_selected.emit(i))
		cards.add_child(card)
		card_buttons.append(card)

	var actions := GridContainer.new()
	actions.name = "ActionGrid"
	actions.columns = 6
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", int(GAP))
	actions.add_theme_constant_override("v_separation", int(GAP))
	body.add_child(actions)
	_action_grid = actions

	left_button = _action("左转\n15°")
	left_button.pressed.connect(func() -> void: facing_requested.emit(-15.0))
	actions.add_child(left_button)
	right_button = _action("右转\n15°")
	right_button.pressed.connect(func() -> void: facing_requested.emit(15.0))
	actions.add_child(right_button)
	aim_button = _action("地图\n瞄准")
	aim_button.pressed.connect(func() -> void: aim_requested.emit())
	actions.add_child(aim_button)
	tripwire_button = _action("绊索")
	tripwire_button.pressed.connect(func() -> void: tripwire_requested.emit())
	actions.add_child(tripwire_button)

	mode_button = _action("开火\n模式")
	mode_button.pressed.connect(func() -> void: mode_requested.emit())
	actions.add_child(mode_button)
	pack_button = _action("弹包")
	pack_button.pressed.connect(func() -> void: pack_requested.emit())
	actions.add_child(pack_button)
	door_button = _action("门")
	door_button.pressed.connect(func() -> void: door_requested.emit())
	actions.add_child(door_button)
	clear_button = _action("收回")
	clear_button.pressed.connect(func() -> void: clear_requested.emit())
	actions.add_child(clear_button)

	pause_button = _action("暂停")
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	actions.add_child(pause_button)
	speed_button = _action("1×")
	speed_button.pressed.connect(func() -> void: speed_requested.emit())
	actions.add_child(speed_button)
	alarm_button = _action("警报")
	alarm_button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.62))
	alarm_button.pressed.connect(func() -> void: alarm_requested.emit())
	actions.add_child(alarm_button)
	log_button = _action("事件")
	log_button.pressed.connect(func() -> void: log_requested.emit())
	actions.add_child(log_button)
	mode_button.tooltip_text = "锁定前可调整"
	for b in card_buttons + [left_button, right_button, aim_button, tripwire_button, mode_button, pack_button, door_button, clear_button, pause_button, speed_button, alarm_button, log_button]:
		b.add_to_group("touch_hud_button")
	_build_log_panel()
	resized.connect(_layout_responsive)
	call_deferred("_layout_responsive")


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.085, 0.98)
	style.border_width_top = 2
	style.border_color = Color(0.25, 0.38, 0.48, 1.0)
	return style


func _button(label: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	return b


func _action(label: String) -> Button:
	var b := _button(label, Vector2(BUTTON_MIN, BUTTON_MIN))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return b


func _compact_label(text: String, fallback: String) -> String:
	if text.contains("入伏"):
		return "开火\n入伏打"
	if text.contains("见敌"):
		return "开火\n见敌打"
	if text.contains("绊索"):
		return "绊索"
	if text.contains("弹包"):
		return "弹包"
	if text.contains("锁闭"):
		return "门\n锁闭"
	if text.contains("畅通"):
		return "门\n畅通"
	return fallback


func _layout_responsive() -> void:
	if not _built or _bottom_panel == null or _action_grid == null:
		return
	var viewport_size := _viewport_size()
	var metrics := layout_metrics(viewport_size, safe_rect)
	_action_grid.columns = int(metrics["columns"])
	_bottom_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bottom_panel.position = metrics["panel_rect"].position
	_bottom_panel.size = metrics["panel_rect"].size
	_bottom_panel.custom_minimum_size = Vector2(0.0, float(metrics["panel_rect"].size.y))
	_layout_log_panel(metrics["safe_rect"])


func _build_log_panel() -> void:
	log_panel = PanelContainer.new()
	log_panel.name = "EventLogPanel"
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	log_panel.visible = false
	log_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(log_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	log_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	var title := Label.new()
	title.text = "战场事件"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	log_close_button = _button("关闭日志", Vector2(BUTTON_MIN, BUTTON_MIN))
	log_close_button.pressed.connect(func() -> void: log_requested.emit())
	header.add_child(log_close_button)

	var existing_log := get_node_or_null("../Root/EventLog") as RichTextLabel
	if existing_log != null:
		existing_log.reparent(body, false)
		event_log = existing_log
	else:
		event_log = RichTextLabel.new()
		event_log.name = "EventLog"
		body.add_child(event_log)
	event_log.bbcode_enabled = true
	event_log.fit_content = false
	event_log.scroll_active = true
	event_log.mouse_filter = Control.MOUSE_FILTER_STOP
	event_log.add_theme_font_size_override("normal_font_size", 15)
	event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	body.add_child(nav)
	log_prev_button = _button("上一页", Vector2(BUTTON_MIN, BUTTON_MIN))
	log_prev_button.pressed.connect(func() -> void: _change_log_page(-1))
	nav.add_child(log_prev_button)
	log_page_label = Label.new()
	log_page_label.text = "1/1"
	log_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log_page_label.add_theme_font_size_override("font_size", 16)
	nav.add_child(log_page_label)
	log_next_button = _button("下一页", Vector2(BUTTON_MIN, BUTTON_MIN))
	log_next_button.pressed.connect(func() -> void: _change_log_page(1))
	nav.add_child(log_next_button)

	for b in [log_close_button, log_prev_button, log_next_button]:
		b.add_to_group("touch_hud_button")
	if event_log != null:
		event_log.visible = false
		# The scene owns the initial styling; these properties make a fallback
		# EventLog equally readable when the node is absent.
		event_log.bbcode_enabled = true
		event_log.fit_content = false
		event_log.scroll_active = true
		event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		event_log.add_theme_font_size_override("normal_font_size", 15)
	_refresh_log_page()


func _layout_log_panel(safe_area: Rect2) -> void:
	if log_panel == null:
		return
	var panel_width := minf(maxf(safe_area.size.x - 24.0, 0.0), 672.0)
	var panel_height := minf(maxf(safe_area.size.y - 96.0, 0.0), 660.0)
	log_panel.position = safe_area.position + Vector2((safe_area.size.x - panel_width) * 0.5, (safe_area.size.y - panel_height) * 0.5)
	log_panel.size = Vector2(panel_width, panel_height)


func set_event_lines(lines: PackedStringArray) -> void:
	_log_lines = lines
	_log_page = 0
	_refresh_log_page()


func open_event_log(return_to_result: bool = false) -> void:
	print("LOG_OPEN return=%s" % return_to_result)
	_log_return_to_result = return_to_result
	log_panel.visible = true
	if event_log != null:
		event_log.visible = true
	log_close_button.text = "返回结算" if return_to_result else "关闭日志"
	log_button.text = "关日志"
	_refresh_log_page()


func close_event_log() -> void:
	print("LOG_CLOSE")
	if log_panel != null:
		log_panel.visible = false
	if event_log != null:
		event_log.visible = false
	_active_button = null
	_active_blocking = false
	_log_return_to_result = false
	if log_button != null:
		log_button.text = "事件"


func is_event_log_open() -> bool:
	return log_panel != null and log_panel.visible


func is_log_return_to_result() -> bool:
	return _log_return_to_result


func _change_log_page(delta: int) -> void:
	var page_count := maxi(1, ceili(float(_log_lines.size()) / float(LOG_PAGE_SIZE)))
	_log_page = clampi(_log_page + delta, 0, page_count - 1)
	_refresh_log_page()


func _refresh_log_page() -> void:
	if event_log == null:
		return
	var page_count := maxi(1, ceili(float(_log_lines.size()) / float(LOG_PAGE_SIZE)))
	_log_page = clampi(_log_page, 0, page_count - 1)
	var first := _log_page * LOG_PAGE_SIZE
	var last := mini(first + LOG_PAGE_SIZE, _log_lines.size())
	var visible_lines := PackedStringArray()
	for i in range(first, last):
		visible_lines.append(_log_lines[i])
	event_log.text = "[b]战场事件[/b]\n" + ("\n".join(visible_lines) if not visible_lines.is_empty() else "暂无事件")
	log_page_label.text = "%d/%d" % [_log_page + 1, page_count]
	log_prev_button.disabled = _log_page <= 0
	log_next_button.disabled = _log_page >= page_count - 1


func is_ui_point(point: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("touch_hud_button"):
		var button := node as Button
		if button != null and is_instance_valid(button) and button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true
	return false


## Route a native screen touch to the same Button.pressed signal used by the
## desktop UI. Main owns the single active pointer and calls this at press and
## release, so map taps and UI taps cannot both consume one touch.
func handle_screen_touch(point: Vector2, pressed: bool) -> bool:
	if pressed:
		_active_button = null
		_active_blocking = false
		if is_event_log_open():
			for button in [log_close_button, log_prev_button, log_next_button]:
				if button != null and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
					_active_button = button
					return true
			_active_blocking = true
			return true
		for node in get_tree().get_nodes_in_group("touch_hud_button"):
			var button := node as Button
			if button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
				print("TOUCH_HIT_CLAIM name=%s point=%s rect=%s log_open=%s" % [button.name, point, button.get_global_rect(), is_event_log_open()])
				_active_button = button
				return true
		return false
	if _active_blocking:
		_active_blocking = false
		return true
	if _active_button == null:
		return false
	var button := _active_button
	_active_button = null
	if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
		if button == pack_button or button == log_button:
			print("TOUCH_HIT_EMIT name=%s point=%s rect=%s log_open=%s" % [button.name, point, button.get_global_rect(), is_event_log_open()])
		button.emit_signal("pressed")
	return true


func cancel_screen_touch() -> void:
	# A canceled pointer must never be treated as a release.
	clear_active_pointer()


func update_display(
	card_data: Array,
	selected_index: int,
	setup: bool,
	watching: bool,
	door_visible: bool,
	door_locked: bool,
	mode_text: String,
	pack_text: String,
	tool_text: String,
	aim_active: bool,
	paused: bool,
	speed: float
) -> void:
	if not _built:
		build()
	for i in card_buttons.size():
		var b := card_buttons[i]
		if i < card_data.size():
			b.text = str(card_data[i])
		b.button_pressed = i == selected_index
		b.disabled = not setup
		b.modulate = Color(1.0, 0.86, 0.38) if i == selected_index and setup else Color.WHITE
	left_button.disabled = not setup
	right_button.disabled = not setup
	aim_button.disabled = not setup
	aim_button.text = "取消\n瞄准" if aim_active else "地图\n瞄准"
	tripwire_button.disabled = not setup
	tripwire_button.text = _compact_label(tool_text, "绊索")
	mode_button.disabled = not setup
	mode_button.text = _compact_label(mode_text, "开火\n模式")
	pack_button.disabled = not setup
	pack_button.text = _compact_label(pack_text, "弹包")
	door_button.disabled = not setup or not door_visible
	door_button.text = ("门\n锁闭" if door_locked else "门\n畅通") if door_visible else "本关\n无门"
	clear_button.disabled = not setup
	pause_button.disabled = not watching
	pause_button.text = "继续" if paused else "暂停"
	speed_button.disabled = not watching
	speed_button.text = "2×" if speed >= 1.5 else "1×"
	alarm_button.disabled = not setup
