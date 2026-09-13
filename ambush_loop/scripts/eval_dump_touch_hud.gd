extends SceneTree

## Two HUD stills for docs/TOUCH_UX_OPTIONS.md — current v0.5 chrome stack.
## Not a campaign dump. SCOUT crowded bar + ALERT watch bar.

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const OUT := "res://docs/eval_touch_ux"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	_wipe_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("DUMP_TOUCH_HUD display=", DisplayServer.get_name(), " size=", DisplayServer.window_get_size())

	var err := change_scene_to_file("res://scenes/title.tscn")
	if err != OK:
		push_error("DUMP_NO_TITLE")
		quit(2)
		return
	await _settle(16)
	var title = current_scene
	if title == null:
		push_error("DUMP_NO_TITLE_NODE")
		quit(2)
		return
	title._on_start()
	await _settle(8)
	title._on_mission_picked(0)
	await _settle(6)
	title._enter_mission("yard")
	await _settle(18)
	var main = current_scene
	if main == null or not main.has_method("_on_alarm_pressed"):
		push_error("DUMP_NO_MAIN")
		quit(2)
		return
	_dismiss_tut(main)
	await _settle(8)

	var gs := root.get_node_or_null("GameSettings")
	if gs:
		gs.force_touch_hud = true
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(6)
	_count_chrome(main, "scout")
	await _save("01_scout_touch_crowded")

	if main.has_method("raid_prepare_ref"):
		main.raid_prepare_ref([0, 1, 2], [0.0, 0.0, 90.0], {"grenades": 2, "mines": 1})
	await _settle(6)
	main._on_alarm_pressed()
	await _settle(16)
	_count_chrome(main, "alert")
	await _save("02_alert_touch_watch")

	print("DUMP_TOUCH_HUD_OK")
	quit(0)


func _count_chrome(main, tag: String) -> void:
	var n := 0
	if main.touch_hud and main.touch_hud._row_setup and main.touch_hud._row_setup.visible:
		for c in main.touch_hud._row_setup.get_children():
			if c is Control and c.visible:
				n += 1
	var w := 0
	if main.touch_hud and main.touch_hud._row_watch and main.touch_hud._row_watch.visible:
		for c in main.touch_hud._row_watch.get_children():
			if c is Control and c.visible:
				w += 1
	var portraits_on := false
	var skills_on := false
	var mmap_on := false
	if main.get("c2") != null:
		if main.c2.get("portraits") != null:
			portraits_on = bool(main.c2.portraits.visible)
		if main.c2.get("skill_bar") != null:
			skills_on = bool(main.c2.skill_bar.visible)
		if main.c2.get("minimap") != null:
			mmap_on = bool(main.c2.minimap.visible)
	var cards := "?"
	if main.get("role_box") != null:
		cards = str(main.role_box.visible)
	print(
		"DUMP_CHROME tag=", tag,
		" phase=", (main.phase_id() if main.has_method("phase_id") else main.phase),
		" setup_btns=", n,
		" watch_btns=", w,
		" portraits=", portraits_on,
		" skillbar=", skills_on,
		" minimap=", mmap_on,
		" left_cards=", cards
	)


func _dismiss_tut(main) -> void:
	if main.tutorial_overlay and main.tutorial_overlay.is_open():
		var g := 0
		while main.tutorial_overlay.is_open() and g < 8:
			main.tutorial_overlay._on_next()
			g += 1


func _settle(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(stem: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_viewport().get_texture().get_image()
	if img == null:
		push_error("DUMP_NO_IMAGE %s" % stem)
		return
	var path := "%s/%s.png" % [OUT, stem]
	var err := img.save_png(path)
	print("DUMP_SAVE ", stem, " err=", err, " ", img.get_width(), "x", img.get_height())


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.reset_to_defaults()
		gs.seen_tutorial = false
		gs.seen_level_tutorials = {}
