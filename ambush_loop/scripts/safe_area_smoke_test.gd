extends SceneTree

## Short logical-coordinate safe-area regression.
## Android insets are injected as HUD-local logical rectangles; production
## DisplayServer collection remains exercised by the game scene itself.

const MAIN_SCENE := "res://scenes/main.tscn"
const PRODUCTION_SAVE_PATH := "user://ambush_loop.cfg"
const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"
const LOGICAL_VIEWPORT := Vector2(720.0, 1280.0)
const SAFE_RECT_CASES := [
	{"name": "fullscreen", "rect": Rect2(0.0, 0.0, 720.0, 1280.0)},
	{"name": "vertical", "rect": Rect2(0.0, 24.0, 720.0, 1220.0)},
	{"name": "horizontal", "rect": Rect2(18.0, 0.0, 684.0, 1280.0)},
	{"name": "both", "rect": Rect2(18.0, 24.0, 684.0, 1220.0)},
	{"name": "invalid", "rect": Rect2(0.0, 0.0, -1.0, -1.0)},
]

var _main: Node = null
var _isolated_save_path := ""
var _production_save_existed := false
var _production_save_bytes := PackedByteArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _prepare_isolated_storage():
		quit(30)
		return
	var error := change_scene_to_file(MAIN_SCENE)
	if error != OK:
		_fail("SAFE_AREA_SCENE_LOAD_FAILED error=%s" % error)
		return
	await _frames(5)
	_main = current_scene
	if _main == null or _main.touch_hud == null:
		_fail("SAFE_AREA_MAIN_MISSING")
		return
	var window: Window = get_root() as Window
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(720, 1280)
	await _frames(4)
	if _main.touch_hud.size != LOGICAL_VIEWPORT:
		_fail("SAFE_AREA_LOGICAL_VIEWPORT_FAIL expected=%s actual=%s" % [LOGICAL_VIEWPORT, _main.touch_hud.size])
		return

	var layout_cases := 0
	for safe_case in SAFE_RECT_CASES:
		_main.touch_hud.set_safe_rect_for_test(safe_case.rect)
		await _frames(2)
		if not await _assert_case(str(safe_case.name), safe_case.rect):
			return
		layout_cases += 1
	print("SAFE_AREA_LAYOUT_OK cases=%s" % layout_cases)

	_main.touch_hud.clear_safe_rect_for_test()
	await _frames(3)
	var restored: Rect2 = _main.touch_hud.safe_rect
	if restored.position.distance_to(Vector2.ZERO) > 0.01 or restored.size.distance_to(LOGICAL_VIEWPORT) > 0.01 or _main.safe_area_source.begins_with("injected"):
		_fail("SAFE_AREA_FALLBACK_FAIL source=%s safe=%s" % [_main.safe_area_source, restored])
		return
	if _main.active_pointer_id != -1:
		_fail("SAFE_AREA_FALLBACK_POINTER_NOT_CLEARED id=%s" % _main.active_pointer_id)
		return
	print("SAFE_AREA_FALLBACK_OK source=%s safe=%s" % [_main.safe_area_source, restored])

	if not _assert_production_save_unchanged():
		return
	print("SAFE_AREA_SMOKE_COMPLETE")
	quit(0)


func _assert_case(case_name: String, requested_safe_rect: Rect2) -> bool:
	var hud: TouchHUD = _main.touch_hud
	var metrics: Dictionary = TouchHUD.layout_metrics(LOGICAL_VIEWPORT, requested_safe_rect)
	var safe_rect: Rect2 = metrics["safe_rect"]
	if not _rect_inside(safe_rect, metrics["panel_rect"]) or not _rect_inside(safe_rect, metrics["cards_rect"]) or not _rect_inside(safe_rect, metrics["actions_rect"]):
		_fail("SAFE_AREA_METRICS_FAIL case=%s safe=%s metrics=%s" % [case_name, safe_rect, metrics])
		return false
	if not bool(metrics["fits_horizontal"]) or not bool(metrics["fits_vertical"]):
		_fail("SAFE_AREA_METRICS_FIT_FAIL case=%s safe=%s" % [case_name, safe_rect])
		return false
	if float(metrics["cell_width"]) + 0.01 < float(metrics["button_min"]) or float(metrics["gap"]) + 0.01 < 12.0:
		_fail("SAFE_AREA_BUTTON_METRICS_FAIL case=%s cell=%s min=%s gap=%s" % [case_name, metrics["cell_width"], metrics["button_min"], metrics["gap"]])
		return false

	var bottom_panel := hud.get_node_or_null("BottomPanel") as Control
	if not _assert_control_inside(bottom_panel, safe_rect, "BottomPanel", case_name):
		return false
	for button in _all_hud_buttons(hud):
		if button.size.x + 0.01 < TouchHUD.BUTTON_MIN or button.size.y + 0.01 < TouchHUD.BUTTON_MIN:
			_fail("SAFE_AREA_BUTTON_SIZE_FAIL case=%s button=%s size=%s" % [case_name, button.name, button.size])
			return false
		if not _assert_control_inside(button, safe_rect, button.name, case_name):
			return false

	var top_bar := _main.get_node("HUD/Root/TopBar") as Control
	if not _assert_control_inside(top_bar, safe_rect, "TopBar", case_name):
		return false
	for control in [_main.tut_label, _main.help_label]:
		if control != null and not _assert_control_inside(control as Control, safe_rect, str(control.name), case_name):
			return false

	hud.open_event_log(false)
	await _frames(1)
	if not _assert_control_inside(hud.log_panel, safe_rect, "EventLogPanel", case_name):
		return false
	hud.close_event_log()

	_main.result_panel.visible = true
	await _frames(1)
	for control in [_main.result_panel, _main.continue_button, _main.battlefield_button]:
		if not _assert_control_inside(control as Control, safe_rect, str(control.name), case_name):
			return false
	_main.result_panel.visible = false

	var pointer_button: Button = hud.card_buttons[0]
	_main.active_pointer_id = 17
	_main.active_touch_target = 1
	_main.active_result_button = _main.continue_button
	if not hud.handle_screen_touch(pointer_button.global_position, true):
		_fail("SAFE_AREA_POINTER_SETUP_FAIL case=%s" % case_name)
		return false
	_main.call("_notification", Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames(1)
	if _main.active_pointer_id != -1 or _main.active_touch_target != 0 or _main.active_result_button != null:
		_fail("SAFE_AREA_FOCUS_OUT_POINTER_NOT_CLEARED case=%s id=%s target=%s result=%s" % [case_name, _main.active_pointer_id, _main.active_touch_target, _main.active_result_button])
		return false
	if hud.handle_screen_touch(pointer_button.global_position, false):
		_fail("SAFE_AREA_FOCUS_OUT_STALE_BUTTON_POINTER case=%s" % case_name)
		return false

	print("SAFE_AREA_CASE_OK case=%s source=%s safe=%s columns=%s cell=%.2f" % [case_name, hud.safe_area_source, safe_rect, metrics["columns"], metrics["cell_width"]])
	return true


func _all_hud_buttons(hud: TouchHUD) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.append_array(hud.card_buttons)
	buttons.append_array([
		hud.left_button,
		hud.right_button,
		hud.aim_button,
		hud.tripwire_button,
		hud.mode_button,
		hud.pack_button,
		hud.door_button,
		hud.clear_button,
		hud.pause_button,
		hud.speed_button,
		hud.alarm_button,
		hud.log_button,
	])
	return buttons


func _assert_control_inside(control: Control, safe_area: Rect2, label: String, case_name: String) -> bool:
	if control == null:
		_fail("SAFE_AREA_CONTROL_MISSING case=%s control=%s" % [case_name, label])
		return false
	if not _rect_inside(safe_area, control.get_global_rect()):
		_fail("SAFE_AREA_CONTROL_OVERFLOW case=%s control=%s rect=%s safe=%s" % [case_name, label, control.get_global_rect(), safe_area])
		return false
	return true


func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.01 and inner.position.y >= outer.position.y - 0.01 and inner.end.x <= outer.end.x + 0.01 and inner.end.y <= outer.end.y + 0.01


func _prepare_isolated_storage() -> bool:
	var unique_id := "safe_area_smoke_%s_%s" % [str(Time.get_ticks_usec()), str(OS.get_process_id())]
	_isolated_save_path = "user://test/%s/ambush_loop.cfg" % unique_id
	if not _isolated_save_path.begins_with("user://test/") or _isolated_save_path == PRODUCTION_SAVE_PATH:
		push_error("SAFE_AREA_STORAGE_NOT_ISOLATED path=%s" % _isolated_save_path)
		return false
	var absolute_dir := ProjectSettings.globalize_path(_isolated_save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		push_error("SAFE_AREA_STORAGE_DIR_FAILED path=%s" % absolute_dir)
		return false
	_production_save_existed = FileAccess.file_exists(PRODUCTION_SAVE_PATH)
	if _production_save_existed:
		var file := FileAccess.open(PRODUCTION_SAVE_PATH, FileAccess.READ)
		if file == null:
			push_error("SAFE_AREA_PRODUCTION_SENTINEL_READ_FAILED")
			return false
		_production_save_bytes = file.get_buffer(file.get_length())
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, _isolated_save_path)
	if str(ProjectSettings.get_setting(PROGRESS_PATH_SETTING, "")) != _isolated_save_path:
		push_error("SAFE_AREA_STORAGE_INJECTION_FAILED path=%s" % _isolated_save_path)
		return false
	print("SAFE_AREA_STORAGE_ISOLATED path=%s" % _isolated_save_path)
	return true


func _assert_production_save_unchanged() -> bool:
	var exists_now := FileAccess.file_exists(PRODUCTION_SAVE_PATH)
	if exists_now != _production_save_existed:
		_fail("SAFE_AREA_PRODUCTION_SAVE_CHANGED existed_before=%s existed_after=%s" % [_production_save_existed, exists_now])
		return false
	if not exists_now:
		return true
	var file := FileAccess.open(PRODUCTION_SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("SAFE_AREA_PRODUCTION_SENTINEL_READ_FAILED_AFTER")
		return false
	var after := file.get_buffer(file.get_length())
	if after != _production_save_bytes:
		_fail("SAFE_AREA_PRODUCTION_SAVE_BYTES_CHANGED")
		return false
	return true


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
