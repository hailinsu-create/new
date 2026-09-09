extends SceneTree

## Godot-native portrait evidence across the requested window-size matrix.
## This script reports actual rendered dimensions so host constraints remain
## visible in the review packet.

const OUT_DIR := "res://../outputs/screenshots"
const ISOLATED_SAVE := "user://test/screenshot_evidence/ambush_loop.cfg"
const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"
const WINDOW_SIZES := [
	Vector2i(360, 640),
	Vector2i(390, 844),
	Vector2i(412, 915),
	Vector2i(720, 1280),
]

var main


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var save_dir := ProjectSettings.globalize_path(ISOLATED_SAVE.get_base_dir())
	DirAccess.make_dir_recursive_absolute(save_dir)
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, ISOLATED_SAVE)
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		_fail("SCREENSHOT_SCENE_LOAD_FAILED %s" % err)
		return
	await _frames(4)
	main = current_scene
	if main == null:
		_fail("SCREENSHOT_MAIN_SCENE_MISSING")
		return

	for requested_size in WINDOW_SIZES:
		await _set_window_size(requested_size)
		if not _assert_viewport_layout(requested_size):
			return
		if not await _capture_yard_setup(requested_size):
			return
		if not await _capture_warehouse_setup(requested_size):
			return
		if not await _capture_pump_locked_setup(requested_size):
			return

	print("SCREENSHOT_EVIDENCE_COMPLETE dir=%s count=%s" % [absolute_dir, WINDOW_SIZES.size() * 3])
	quit(0)


func _set_window_size(requested_size: Vector2i) -> void:
	var window: Window = get_root() as Window
	window.mode = Window.MODE_WINDOWED
	window.size = requested_size
	await _frames(4)
	var actual_window: Vector2i = window.size
	var actual_viewport: Vector2i = main.get_viewport().size
	print("SCREENSHOT_WINDOW requested=%sx%s actual_window=%sx%s viewport=%sx%s" % [
		requested_size.x,
		requested_size.y,
		actual_window.x,
		actual_window.y,
		actual_viewport.x,
		actual_viewport.y,
	])


func _assert_viewport_layout(requested_size: Vector2i) -> bool:
	var window: Window = get_root() as Window
	var actual_window: Vector2i = window.size
	var actual_viewport: Vector2i = main.get_viewport().size
	var texture_size := Vector2i(main.get_viewport().get_texture().get_size())
	var window_aspect := float(actual_window.x) / maxf(float(actual_window.y), 1.0)
	var texture_aspect := float(texture_size.x) / maxf(float(texture_size.y), 1.0)
	var viewport: Viewport = main.get_viewport()
	var canvas_transform: Transform2D = viewport.get_stretch_transform() * viewport.get_canvas_transform()
	var canvas_scale := Vector2(canvas_transform.x.x, canvas_transform.y.y)
	var logical_viewport := _logical_viewport_size(actual_viewport, canvas_scale)
	if actual_window != requested_size or actual_viewport != actual_window or absf(window_aspect - texture_aspect) > 0.01:
		_fail("VIEWPORT_LAYOUT_FAIL requested=%sx%s window=%sx%s viewport=%sx%s texture=%sx%s" % [
			requested_size.x,
			requested_size.y,
			actual_window.x,
			actual_window.y,
			actual_viewport.x,
			actual_viewport.y,
			texture_size.x,
			texture_size.y,
		])
		return false
	var bottom_panel: Control = main.touch_hud.get_node_or_null("BottomPanel") as Control
	if bottom_panel == null:
		_fail("VIEWPORT_LAYOUT_FAIL bottom TouchHUD panel missing")
		return false
	var panel_rect := bottom_panel.get_global_rect()
	var panel_viewport_rect := _map_rect_to_viewport(panel_rect, canvas_transform)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(actual_viewport))
	if panel_viewport_rect.position.x < -2.0 or panel_viewport_rect.position.y < -2.0 or panel_viewport_rect.end.x > viewport_rect.end.x + 2.0 or panel_viewport_rect.end.y > viewport_rect.end.y + 2.0:
		_fail("VIEWPORT_LAYOUT_FAIL bottom TouchHUD physical bounds rect=%s viewport=%s" % [panel_viewport_rect, viewport_rect])
		return false
	var logical_rect := Rect2(Vector2.ZERO, logical_viewport)
	if str(main.safe_area_source) != "non_mobile_fallback" or main.safe_rect.position.distance_to(Vector2.ZERO) > 2.0 or main.safe_rect.size.distance_to(logical_rect.size) > 2.0:
		_fail("VIEWPORT_SAFE_AREA_FAIL source=%s safe=%s logical=%s" % [main.safe_area_source, main.safe_rect, logical_rect])
		return false
	if absf(panel_viewport_rect.end.y - viewport_rect.end.y) > 2.0:
		_fail("VIEWPORT_HUD_BOTTOM_FAIL hud_bottom=%.2f viewport_bottom=%.2f" % [panel_viewport_rect.end.y, viewport_rect.end.y])
		return false
	if not _assert_physical_scene_geometry(viewport_rect, canvas_transform, panel_viewport_rect, "layout"):
		return false
	var texture_scale := Vector2(
		float(texture_size.x) / maxf(float(actual_window.x), 1.0),
		float(texture_size.y) / maxf(float(actual_window.y), 1.0)
	)
	print("VIEWPORT_LAYOUT_OK window=%sx%s viewport=%sx%s logical_viewport=%.1fx%.1f canvas_scale=%.3fx%.3f texture=%sx%s texture_scale=%.3fx%.3f hud_physical_bottom=%.1f hud_logical=%sx%s" % [
		actual_window.x,
		actual_window.y,
		actual_viewport.x,
		actual_viewport.y,
		logical_viewport.x,
		logical_viewport.y,
		canvas_scale.x,
		canvas_scale.y,
		texture_size.x,
		texture_size.y,
		texture_scale.x,
		texture_scale.y,
		panel_viewport_rect.end.y,
		int(main.touch_hud.size.x),
		int(main.touch_hud.size.y),
	])
	return true


func _logical_viewport_size(viewport_size: Vector2i, canvas_scale: Vector2) -> Vector2:
	return Vector2(
		float(viewport_size.x) / maxf(absf(canvas_scale.x), 0.0001),
		float(viewport_size.y) / maxf(absf(canvas_scale.y), 0.0001)
	)


func _map_rect_to_viewport(rect: Rect2, canvas_transform: Transform2D) -> Rect2:
	var points := [
		canvas_transform * rect.position,
		canvas_transform * Vector2(rect.end.x, rect.position.y),
		canvas_transform * Vector2(rect.position.x, rect.end.y),
		canvas_transform * rect.end,
	]
	var mapped := Rect2(points[0], Vector2.ZERO)
	for point in points:
		mapped = mapped.expand(point)
	return mapped


func _assert_physical_scene_geometry(viewport_rect: Rect2, canvas_transform: Transform2D, hud_rect: Rect2, context: String) -> bool:
	var map_rect := Rect2(Vector2(AmbushGrid.WORLD_ORIGIN), Vector2(AmbushGrid.COLS * AmbushGrid.TILE, AmbushGrid.ROWS * AmbushGrid.TILE))
	var escape_rect := Rect2(main.escape_world - Vector2(22.0, 22.0), Vector2(44.0, 44.0))
	var map_viewport_rect := _map_rect_to_viewport(map_rect, canvas_transform)
	var escape_viewport_rect := _map_rect_to_viewport(escape_rect, canvas_transform)
	if map_viewport_rect.intersects(hud_rect) or escape_viewport_rect.intersects(hud_rect):
		_fail("VIEWPORT_GEOMETRY_FAIL context=%s map=%s escape=%s hud=%s" % [context, map_viewport_rect, escape_viewport_rect, hud_rect])
		return false
	if not _rect_inside(viewport_rect, escape_viewport_rect, 2.0):
		_fail("VIEWPORT_ESCAPE_MARKER_FAIL context=%s escape=%s viewport=%s" % [context, escape_viewport_rect, viewport_rect])
		return false
	print("VIEWPORT_GEOMETRY_OK context=%s map=%s escape=%s hud=%s" % [context, map_viewport_rect, escape_viewport_rect, hud_rect])
	return true


func _rect_inside(outer: Rect2, inner: Rect2, tolerance: float) -> bool:
	return inner.position.x >= outer.position.x - tolerance and inner.position.y >= outer.position.y - tolerance and inner.end.x <= outer.end.x + tolerance and inner.end.y <= outer.end.y + tolerance


func _capture_yard_setup(requested_size: Vector2i) -> bool:
	main._load_level("yard", false, false)
	await _frames(3)
	_deploy_ref([1, 3, 5], [90.0, 0.0, 90.0])
	await _frames(3)
	return _capture(requested_size, "yard_setup")


func _capture_warehouse_setup(requested_size: Vector2i) -> bool:
	main._load_level("warehouse", false, false)
	await _frames(3)
	_deploy_ref([1, 3, 5], [90.0, 180.0, 90.0])
	await _frames(3)
	return _capture(requested_size, "warehouse_setup")


func _capture_pump_locked_setup(requested_size: Vector2i) -> bool:
	main._load_level("pump", false, false)
	await _frames(3)
	main._on_door_pressed()
	await _frames(3)
	return _capture(requested_size, "pump_locked_setup")


func _deploy_ref(slots: Array, facings: Array) -> void:
	for i in slots.size():
		main._select_op(i)
		main._deploy_selected_to(main.cover_slots[int(slots[i])])
		main.selected.set_facing(float(facings[i]))


func _capture(requested_size: Vector2i, state_name: String) -> bool:
	var window: Window = get_root() as Window
	var viewport: Viewport = main.get_viewport()
	var canvas_transform: Transform2D = viewport.get_stretch_transform() * viewport.get_canvas_transform()
	var canvas_scale := Vector2(canvas_transform.x.x, canvas_transform.y.y)
	var logical_viewport := _logical_viewport_size(viewport.size, canvas_scale)
	var bottom_panel: Control = main.touch_hud.get_node_or_null("BottomPanel") as Control
	if bottom_panel == null:
		_fail("VIEWPORT_GEOMETRY_FAIL context=%s bottom TouchHUD panel missing" % state_name)
		return false
	var panel_viewport_rect := _map_rect_to_viewport(bottom_panel.get_global_rect(), canvas_transform)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	if not _assert_physical_scene_geometry(viewport_rect, canvas_transform, panel_viewport_rect, state_name):
		return false
	var image: Image = window.get_texture().get_image()
	var file_name := "%sx%s_%s.png" % [requested_size.x, requested_size.y, state_name]
	var path := OUT_DIR + "/" + file_name
	var err: int = image.save_png(path)
	if err != OK:
		_fail("SCREENSHOT_SAVE_FAILED path=%s err=%s" % [path, err])
		return false
	var actual_window: Vector2i = (get_root() as Window).size
	print("SCREENSHOT_SAVED requested=%sx%s actual_window=%sx%s logical_viewport=%.1fx%.1f canvas_scale=%.3fx%.3f image_physical=%sx%s path=%s" % [
		requested_size.x,
		requested_size.y,
		actual_window.x,
		actual_window.y,
		logical_viewport.x,
		logical_viewport.y,
		canvas_scale.x,
		canvas_scale.y,
		image.get_width(),
		image.get_height(),
		path,
	])
	return true


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
