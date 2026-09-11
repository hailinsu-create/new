extends SceneTree

## Window dump for the playable-bar reeval. Saves PNGs under docs/eval_playable/.

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const OUT := "res://docs/eval_playable"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	_wipe_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var err := change_scene_to_file("res://scenes/title.tscn")
	if err != OK:
		push_error("DUMP_NO_TITLE")
		quit(2)
		return
	await _settle(16)
	await _save("01_title")
	err = change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("DUMP_NO_MAIN")
		quit(2)
		return
	await _settle(16)
	var main = current_scene
	if main.tutorial_overlay and main.tutorial_overlay.is_open():
		var g := 0
		while main.tutorial_overlay.is_open() and g < 8:
			main.tutorial_overlay._on_next()
			g += 1
		await _settle(4)
	await _save("02_setup_yard_empty")
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(0.0)
	await _settle(6)
	await _save("03_setup_yard_facing")
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	var frames := 0
	while frames < 60 * 40:
		await process_frame
		frames += 1
		if main.phase == main.Phase.FAILED:
			break
	await _settle(8)
	await _save("04_fail_yard_card")
	if main.has_method("_toggle_fail_dossier"):
		main._toggle_fail_dossier()
		await _settle(6)
		await _save("05_fail_yard_dossier")
		main._toggle_fail_dossier()
	main._on_continue_pressed()
	await _settle(8)
	main._load_level("radio", false, false)
	await _settle(12)
	if main.tutorial_overlay and main.tutorial_overlay.is_open():
		var g2 := 0
		while main.tutorial_overlay.is_open() and g2 < 8:
			main.tutorial_overlay._on_next()
			g2 += 1
		await _settle(4)
	await _save("06_setup_radio_empty")
	_deploy_radio_ref(main)
	await _settle(8)
	await _save("07_setup_radio_ref")
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	var w := 0
	while w < 120:
		await process_frame
		w += 1
		if main.phase != main.Phase.WATCHING:
			break
	await _settle(10)
	await _save("08_watch_radio")
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.force_touch_hud = true
	main._start_setup(false, false)
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(8)
	await _save("09_touch_radio_bars")
	if gs:
		gs.force_touch_hud = false
	print("DUMP_OK playable-bar")
	quit(0)


func _deploy_radio_ref(main) -> void:
	var slots := [1, 4, 5]
	var faces := [270.0, 90.0, 270.0]
	for i in slots.size():
		main._select_op(i)
		main._deploy_selected_to(main.cover_slots[int(slots[i])])
		main.selected.set_facing(float(faces[i]))
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))


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
		gs.seen_tutorial = true
		if gs.has_method("mark_tutorial_seen"):
			for id in ["yard", "warehouse", "pump", "railcut", "depot", "radio"]:
				gs.mark_tutorial_seen(id)
