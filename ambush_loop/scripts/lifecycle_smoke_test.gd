extends SceneTree

## Mobile lifecycle smoke. It uses the real menu touch route and ui_cancel
## route, while keeping the save path isolated from the player's save.

const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep the path separate from the production save while allowing the real
	# menu startup path (the game's test_mode intentionally skips the menu).
	var save_path := "user://lifecycle_smoke/%s/ambush_loop.cfg" % str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, save_path)
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("LIFECYCLE_SCENE_LOAD_FAILED error=%s" % err)
		quit(1)
		return
	await _frames(3)
	var main = current_scene
	if main.app_screen != main.AppScreen.MENU or not main.menu_panel.visible:
		push_error("LIFECYCLE_MENU_NOT_READY")
		quit(2)
		return
	print("LIFECYCLE_MENU_OK")

	var settings := main.frontend_overlay.find_child("Settings", true, false) as Button
	if settings == null:
		push_error("LIFECYCLE_SETTINGS_BUTTON_MISSING")
		quit(3)
		return
	await _tap_button(settings)
	if not main.settings_panel.visible:
		push_error("LIFECYCLE_SETTINGS_TOUCH_FAILED")
		quit(4)
		return
	main._notification(main.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not main.menu_panel.visible or main.settings_panel.visible:
		push_error("LIFECYCLE_NATIVE_BACK_CLOSE_FAILED")
		quit(5)
		return
	print("LIFECYCLE_NATIVE_BACK_ENTRY_OK")
	await _tap_button(settings)
	if not main.settings_panel.visible:
		push_error("LIFECYCLE_SETTINGS_REOPEN_FAILED")
		quit(6)
		return
	await _send_ui_cancel()
	if not main.menu_panel.visible or main.settings_panel.visible:
		push_error("LIFECYCLE_UI_CANCEL_CLOSE_FAILED")
		quit(7)
		return
	print("LIFECYCLE_UI_CANCEL_OK")

	# Verify that a layout/lifecycle reset releases a held front-end pointer.
	main.frontend_active_button = main.menu_start_button
	main._reset_active_pointer_for_layout()
	if main.frontend_active_button != null:
		push_error("LIFECYCLE_POINTER_RESET_FAILED")
		quit(8)
		return
	await _tap_button(main.menu_start_button)
	if main.app_screen != main.AppScreen.GAME or not main.guide_layer.visible:
		push_error("LIFECYCLE_START_TOUCH_AFTER_RESET_FAILED")
		quit(9)
		return
	print("LIFECYCLE_POINTER_RESET_OK")

	main._guide_skip()
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main._on_alarm_pressed()
	await _frames(2)
	if main.phase != main.Phase.WATCHING:
		push_error("LIFECYCLE_WATCHING_NOT_REACHED")
		quit(10)
		return
	await _send_ui_cancel()
	if not main.sim.paused:
		push_error("LIFECYCLE_BACK_DID_NOT_PAUSE")
		quit(11)
		return
	print("LIFECYCLE_WATCH_PAUSE_OK")
	await _send_ui_cancel()
	if main.app_screen != main.AppScreen.MENU or not main.menu_panel.visible:
		push_error("LIFECYCLE_BACK_TO_MENU_FAILED")
		quit(12)
		return
	print("LIFECYCLE_BACK_TO_MENU_OK")
	if main.menu_continue_button.disabled:
		push_error("LIFECYCLE_CONTINUE_DISABLED_AFTER_SAVE")
		quit(13)
		return
	await _tap_button(main.menu_continue_button)
	if main.app_screen != main.AppScreen.GAME or main.phase != main.Phase.SETUP or main._deployed_count() != 1:
		push_error("LIFECYCLE_SAVE_RESTORE_FAILED level=%s phase=%s deployed=%s" % [main.level.level_id, main.phase, main._deployed_count()])
		quit(14)
		return
	print("LIFECYCLE_SAVE_RESTORE_OK")

	print("LIFECYCLE_SMOKE_COMPLETE")
	quit(0)


func _tap_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
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


func _send_ui_cancel() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = false
	Input.parse_input_event(event)
	await process_frame


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
