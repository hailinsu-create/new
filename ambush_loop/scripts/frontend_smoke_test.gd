extends SceneTree

## Player-facing first-run smoke: menu, settings, privacy, tutorial and entry.

const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_dir := "user://test/frontend_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, save_dir + "/ambush_loop.cfg")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("FRONTEND_SCENE_LOAD_FAILED error=%s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	var main = current_scene
	# Test storage skips the player menu by design; this suite explicitly tests it.
	main._show_main_menu()
	await process_frame
	if main.app_screen != main.AppScreen.MENU or not main.menu_panel.visible:
		push_error("FRONTEND_MENU_NOT_VISIBLE")
		quit(2)
		return
	if not _assert_frontend_button_targets(main):
		return
	if not _assert_about_copy(main):
		return
	print("FRONTEND_MENU_OK")
	main._show_settings()
	if not main.settings_panel.visible or not main.settings_volume_button.visible:
		push_error("FRONTEND_SETTINGS_NOT_VISIBLE")
		quit(3)
		return
	print("FRONTEND_SETTINGS_OK")
	main._show_about()
	if not main.about_panel.visible:
		push_error("FRONTEND_ABOUT_NOT_VISIBLE")
		quit(4)
		return
	print("FRONTEND_PRIVACY_OK")
	main._close_overlay_to_return()
	await _send_touch(main.menu_start_button)
	await process_frame
	if main.app_screen != main.AppScreen.GAME or not main.guide_layer.visible:
		print("FRONTEND_TOUCH_STATE screen=%s guide=%s menu=%s rect=%s active=%s" % [main.app_screen, main.guide_layer.visible, main.menu_panel.visible, main.menu_start_button.get_global_rect(), main.frontend_active_button])
		push_error("FRONTEND_GUIDE_NOT_VISIBLE")
		quit(5)
		return
	print("FRONTEND_GUIDE_OK")
	await _send_touch_button(main.touch_hud.card_buttons[0])
	await _send_touch_position(main.cover_slots[1].global_position)
	if main.tutorial_step < 1 or main._deployed_count() != 1:
		push_error("FRONTEND_TUTORIAL_DEPLOY_NOT_ADVANCED")
		quit(6)
		return
	await _send_touch_button(main.touch_hud.left_button)
	if main.tutorial_step < 2:
		push_error("FRONTEND_TUTORIAL_FACING_NOT_ADVANCED")
		quit(7)
		return
	await _send_touch_button(main.touch_hud.tripwire_button)
	var routes: Array = main._all_routes()
	if routes.is_empty():
		push_error("FRONTEND_TUTORIAL_ROUTE_MISSING")
		quit(8)
		return
	var route: PackedVector2Array = routes[0]
	await _send_touch_position(route[mini(1, route.size() - 1)])
	if main.tutorial_step < 3:
		push_error("FRONTEND_TUTORIAL_TOOL_NOT_ADVANCED")
		quit(9)
		return
	await _send_touch_button(main.touch_hud.alarm_button)
	if main.frontend_overlay.visible or not main.get_node("World").visible:
		push_error("FRONTEND_GAME_ENTRY_FAILED")
		quit(10)
		return
	print("FRONTEND_GAME_ENTRY_OK")
	print("FRONTEND_SMOKE_COMPLETE")
	quit(0)


func _assert_frontend_button_targets(main) -> bool:
	# All menu, settings, confirmation, and tutorial actions share the portrait
	# 96 logical-unit target. Device scaling is validated by the safe-area suite.
	for node in get_nodes_in_group("frontend_button"):
		var button := node as Button
		if button == null or button.custom_minimum_size.y + 0.01 < 96.0:
			push_error("FRONTEND_BUTTON_TARGET_FAIL button=%s size=%s" % [node.name, node.custom_minimum_size])
			quit(11)
			return false
	print("FRONTEND_BUTTON_TARGETS_OK count=%s" % get_nodes_in_group("frontend_button").size())
	return true


func _assert_about_copy(main) -> bool:
	var copy := main.about_panel.get_node_or_null("AboutBody/PrivacyCopy") as Label
	if copy == null:
		push_error("FRONTEND_ABOUT_COPY_MISSING")
		quit(12)
		return false
	for forbidden in ["Data safety", "Play Console", "待填", "隐私政策草案", "依赖审计"]:
		if copy.text.contains(forbidden):
			push_error("FRONTEND_ABOUT_COPY_PLACEHOLDER text=%s" % forbidden)
			quit(13)
			return false
	return true


func _send_touch(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	print("FRONTEND_TOUCH_TARGET point=%s screen=%s buttons=%s visible=%s" % [point, button.get_global_rect(), get_nodes_in_group("frontend_button").size(), button.is_visible_in_tree()])
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = current_scene.get_viewport().get_screen_transform() * point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = current_scene.get_viewport().get_screen_transform() * point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _send_touch_button(button: Button) -> void:
	await _send_touch(button)


func _send_touch_position(world_position: Vector2) -> void:
	var point := current_scene.get_viewport().get_screen_transform() * world_position
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
