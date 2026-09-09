extends SceneTree

## Injected safe-area geometry regression for the portrait HUD.
## DisplayServer safe-area values are exercised by production code; this test
## injects logical HUD rectangles so headless runs can prove layout behavior
## without pretending to be an Android device.

const MAIN_SCENE := "res://scenes/main.tscn"
const PRODUCTION_SAVE_PATH := "user://ambush_loop.cfg"
const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"
const WINDOW_SIZES := [
	Vector2i(360, 640),
	Vector2i(390, 844),
	Vector2i(412, 915),
	Vector2i(720, 1280),
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

	var case_count := 0
	for requested_size in WINDOW_SIZES:
		await _set_window_size(requested_size)
		var viewport_size: Vector2 = _main.touch_hud.size
		if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
			_fail("SAFE_AREA_VIEWPORT_INVALID size=%s" % viewport_size)
			return
		var scenarios := [
			{"name": "zero_inset", "rect": Rect2(Vector2.ZERO, viewport_size)},
			{"name": "top_bottom_inset", "rect": Rect2(Vector2(0.0, 24.0), Vector2(viewport_size.x, viewport_size.y - 48.0))},
			{"name": "asymmetric_horizontal_inset", "rect": Rect2(Vector2(24.0, 0.0), Vector2(viewport_size.x - 60.0, viewport_size.y))},
			{"name": "invalid_fallback", "rect": Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))},
		]
		for scenario in scenarios:
			_main.touch_hud.set_safe_rect_for_test(scenario.rect)
			await _frames(2)
			if not await _assert_layout_case(requested_size, str(scenario.name), scenario.rect):
				return
			case_count += 1

	_main.touch_hud.clear_safe_rect_for_test()
	await _frames(1)
	if not _assert_production_save_unchanged():
		return
	print("SAFE_AREA_LAYOUT_OK cases=%s" % case_count)
	print("SAFE_AREA_TEST_COMPLETE")
	quit(0)


func _set_window_size(requested_size: Vector2i) -> void:
	var window: Window = get_root() as Window
	window.mode = Window.MODE_WINDOWED
	window.size = requested_size
	await _frames(4)
	print("SAFE_AREA_WINDOW requested=%sx%s actual=%sx%s viewport=%sx%s logical=%s" % [
		requested_size.x,
		requested_size.y,
		window.size.x,
		window.size.y,
		_main.get_viewport().size.x,
		_main.get_viewport().size.y,
		_main.touch_hud.size,
	])
	if window.size != requested_size or _main.get_viewport().size != requested_size:
		_fail("SAFE_AREA_WINDOW_FAIL requested=%s actual=%s viewport=%s" % [requested_size, window.size, _main.get_viewport().size])


func _assert_layout_case(requested_size: Vector2i, case_name: String, requested_safe_rect: Rect2) -> bool:
	var hud: TouchHUD = _main.touch_hud
	var viewport_size: Vector2 = hud.size
	var metrics: Dictionary = TouchHUD.layout_metrics(viewport_size, requested_safe_rect)
	var expected_safe_rect: Rect2 = metrics["safe_rect"]
	var actual_safe_rect: Rect2 = hud.safe_rect
	if not _rect_close(expected_safe_rect, actual_safe_rect):
		_fail("SAFE_AREA_RECT_FAIL size=%s case=%s expected=%s actual=%s" % [requested_size, case_name, expected_safe_rect, actual_safe_rect])
		return false

	var safe_rect := actual_safe_rect
	var bottom_panel := hud.get_node_or_null("BottomPanel") as Control
	if bottom_panel == null or not _assert_control_inside(bottom_panel, safe_rect, "bottom_panel", requested_size, case_name):
		return false
	for button in _all_hud_buttons(hud):
		if not _assert_control_inside(button, safe_rect, button.name, requested_size, case_name):
			return false

	var top_bar := _main.get_node("HUD/Root/TopBar") as Control
	if not _assert_control_inside(top_bar, safe_rect, "top_bar", requested_size, case_name):
		return false
	for node in [_main.tut_label, _main.help_label]:
		if node != null and not _assert_control_inside(node as Control, safe_rect, str(node.name), requested_size, case_name):
			return false

	hud.open_event_log(false)
	await _frames(1)
	if not _assert_control_inside(hud.log_panel, safe_rect, "event_log_panel", requested_size, case_name):
		return false
	for button in [hud.log_close_button, hud.log_prev_button, hud.log_next_button]:
		if not _assert_control_inside(button, safe_rect, button.name, requested_size, case_name):
			return false
	hud.close_event_log()

	_main.result_panel.visible = true
	await _frames(1)
	for control in [_main.result_panel, _main.continue_button, _main.battlefield_button]:
		if not _assert_control_inside(control as Control, safe_rect, str(control.name), requested_size, case_name):
			return false
	_main.result_panel.visible = false

	var map_rect := Rect2(Vector2(AmbushGrid.WORLD_ORIGIN), Vector2(AmbushGrid.COLS * AmbushGrid.TILE, AmbushGrid.ROWS * AmbushGrid.TILE))
	var escape_rect := Rect2(_main.escape_world - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
	var hud_rect: Rect2 = bottom_panel.get_global_rect()
	if map_rect.intersects(hud_rect) or escape_rect.intersects(hud_rect):
		_fail("SAFE_AREA_MAP_COVERED size=%s case=%s map=%s escape=%s hud=%s" % [requested_size, case_name, map_rect, escape_rect, hud_rect])
		return false

	var screen_transform: Transform2D = hud.get_screen_transform()
	var sample := safe_rect.position + safe_rect.size * Vector2(0.37, 0.61)
	var screen_point := screen_transform * sample
	var round_trip := screen_transform.affine_inverse() * screen_point
	var round_trip_error := round_trip.distance_to(sample)
	if round_trip_error > 2.0:
		_fail("SAFE_AREA_ROUNDTRIP_FAIL size=%s case=%s error=%.3f" % [requested_size, case_name, round_trip_error])
		return false

	print("SAFE_AREA_CASE_OK size=%sx%s case=%s source=%s safe=%s roundtrip_error=%.3f" % [
		requested_size.x,
		requested_size.y,
		case_name,
		hud.safe_area_source,
		safe_rect,
		round_trip_error,
	])
	return true


func _all_hud_buttons(hud: TouchHUD) -> Array[Control]:
	var controls: Array[Control] = []
	for button in hud.card_buttons:
		controls.append(button)
	for button in [hud.left_button, hud.right_button, hud.aim_button, hud.tripwire_button, hud.mode_button, hud.pack_button, hud.door_button, hud.clear_button, hud.pause_button, hud.speed_button, hud.alarm_button, hud.log_button]:
		controls.append(button)
	return controls


func _assert_control_inside(control: Control, safe_area: Rect2, label: String, requested_size: Vector2i, case_name: String) -> bool:
	if control == null:
		_fail("SAFE_AREA_CONTROL_MISSING size=%s case=%s control=%s" % [requested_size, case_name, label])
		return false
	var rect := control.get_global_rect()
	if not _rect_inside(safe_area, rect, 2.0):
		_fail("SAFE_AREA_CONTROL_OVERFLOW size=%s case=%s control=%s rect=%s safe=%s" % [requested_size, case_name, label, rect, safe_area])
		return false
	return true


func _rect_inside(outer: Rect2, inner: Rect2, tolerance: float) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


func _rect_close(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 0.01 and a.size.distance_to(b.size) <= 0.01


func _prepare_isolated_storage() -> bool:
	var unique_id := "safe_area_%s_%s" % [str(Time.get_ticks_usec()), str(OS.get_process_id())]
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
