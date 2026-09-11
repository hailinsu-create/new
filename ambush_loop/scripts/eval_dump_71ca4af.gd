extends SceneTree

## Window dump for 71ca4af playtest recap (campaign chain, no hot-load until touch frame 31). Saves PNGs under docs/eval_71ca4af/.
## Walks title → setup → alarm → watch → fail → restore → win → handoff
## → later nights empty → radio fail/watch/win → credits → journal.
## Script-driven, not a human mouse. Prints HUD text for the report.

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const OUT := "res://docs/eval_71ca4af"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	_wipe_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("DUMP_HEAD display=", DisplayServer.get_name(), " size=", DisplayServer.window_get_size())

	var err := change_scene_to_file("res://scenes/title.tscn")
	if err != OK:
		push_error("DUMP_NO_TITLE")
		quit(2)
		return
	await _settle(20)
	var title = current_scene
	await _save("01_title")
	if title.has_method("_on_help"):
		title._on_help()
		await _settle(8)
		await _save("02_howto")
		if title.has_method("_on_back"):
			title._on_back()
			await _settle(4)
	if title.has_method("open_journal"):
		title.open_journal()
		await _settle(8)
		await _save("03_journal_empty")
		if title._journal:
			title._journal.dismiss()
			await _settle(4)
	title._on_start()
	await _settle(8)
	await _save("04_mission_select")
	title._on_mission_picked(0)
	await _settle(8)
	await _save("05_briefing_yard")
	print(
		"DUMP_BRIEF night=", title.briefing_night_text() if title.has_method("briefing_night_text") else "",
		" code=", title.briefing_codename_text() if title.has_method("briefing_codename_text") else ""
	)
	title._enter_mission("yard")
	await _settle(18)
	var main = current_scene
	if main == null or not main.has_method("_on_alarm_pressed"):
		push_error("DUMP_NO_MAIN")
		quit(2)
		return
	await _save("06_tut_yard")
	_dismiss_tut(main)
	await _settle(8)
	_hud(main, "yard_empty")
	await _save("07_setup_yard_empty")

	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(0.0)
	await _settle(8)
	_hud(main, "yard_facing")
	await _save("08_setup_yard_facing")

	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	await _wait_t(main, 1.2, 60 * 8)
	await _settle(6)
	_hud(main, "yard_watch")
	await _save("09_watch_yard")
	var fail_ok := await _wait_phase(main, main.Phase.FAILED, 60 * 40)
	print("DUMP_YARD_FAIL ok=", fail_ok, " reason=", main.fail_reason, " tick=", main.sim.tick)
	await _settle(8)
	_hud(main, "yard_fail_card")
	await _save("10_fail_yard_card")
	if main.has_method("_toggle_fail_dossier"):
		main._toggle_fail_dossier()
		await _settle(6)
		await _save("11_fail_yard_dossier")
		main._toggle_fail_dossier()
	main._on_continue_pressed()
	await _settle(10)
	_hud(main, "yard_restored")
	await _save("12_setup_yard_restored")
	main._on_clear_pressed()
	await process_frame
	_deploy(main, [1, 2, 5], [90.0, 180.0, 180.0])
	await _settle(6)
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	var win_ok := await _wait_phase(main, main.Phase.WON, 60 * 20)
	print("DUMP_YARD_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(8)
	_hud(main, "yard_win")
	await _save("13_win_yard")
	main._on_continue_pressed()
	await _settle(10)
	if main.night_handoff and main.night_handoff.is_open():
		print("DUMP_HANDOFF from=", main.night_handoff.from_id(), " to=", main.night_handoff.to_id())
		print("DUMP_HANDOFF_BODY ", main.night_handoff.body_text().replace("\n", " | "))
		await _save("14_handoff_yard_warehouse")
		main.night_handoff.dismiss()
		await _settle(8)
	else:
		print("DUMP_NO_HANDOFF")
		await _save("14_handoff_yard_warehouse")

	_dismiss_tut(main)
	await _settle(6)
	_hud(main, "warehouse_empty")
	await _save("15_setup_warehouse_empty")
	_deploy(main, [1, 3, 5], [180.0, 0.0, 180.0])
	if main.has_method("_play_hold_pack"):
		main._play_hold_pack(1)
	await _settle(6)
	await _save("16_setup_warehouse_hold")
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	win_ok = await _wait_phase(main, main.Phase.WON, 60 * 30)
	print("DUMP_WAREHOUSE_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(4)
	main._on_continue_pressed()
	await _settle(8)
	if main.night_handoff and main.night_handoff.is_open():
		main.night_handoff.dismiss()
		await _settle(6)

	_dismiss_tut(main)
	if not main.door_locked:
		main._on_door_pressed()
	await _settle(8)
	_hud(main, "pump_locked")
	await _save("17_setup_pump_locked")
	_deploy(main, [1, 4, 5], [90.0, 180.0, 180.0])
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	win_ok = await _wait_phase(main, main.Phase.WON, 60 * 30)
	print("DUMP_PUMP_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(4)
	main._on_continue_pressed()
	await _settle(8)
	if main.night_handoff and main.night_handoff.is_open():
		main.night_handoff.dismiss()
		await _settle(6)

	_dismiss_tut(main)
	await _settle(6)
	_hud(main, "railcut_empty")
	await _save("18_setup_railcut_empty")
	_deploy(main, [1, 4, 5], [270.0, 270.0, 180.0])
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	win_ok = await _wait_phase(main, main.Phase.WON, 60 * 30)
	print("DUMP_RAILCUT_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(4)
	main._on_continue_pressed()
	await _settle(8)
	if main.night_handoff and main.night_handoff.is_open():
		main.night_handoff.dismiss()
		await _settle(6)

	_dismiss_tut(main)
	await _settle(6)
	_hud(main, "depot_empty")
	await _save("19_setup_depot_empty")
	_deploy(main, [1, 4, 5], [270.0, 270.0, 180.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	await _settle(6)
	await _save("20_setup_depot_ref")
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	win_ok = await _wait_phase(main, main.Phase.WON, 60 * 30)
	print("DUMP_DEPOT_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(4)
	main._on_continue_pressed()
	await _settle(10)
	if main.night_handoff and main.night_handoff.is_open():
		print("DUMP_HANDOFF_RADIO ", main.night_handoff.body_text().replace("\n", " | "))
		await _save("21_handoff_depot_radio")
		main.night_handoff.dismiss()
		await _settle(8)
	else:
		await _save("21_handoff_depot_radio")

	_dismiss_tut(main)
	await _settle(8)
	_hud(main, "radio_empty")
	await _save("22_setup_radio_empty")
	_deploy(main, [1, 4, 5], [270.0, 90.0, 270.0])
	await _settle(6)
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	fail_ok = await _wait_phase(main, main.Phase.FAILED, 60 * 40)
	print(
		"DUMP_RADIO_FAIL ok=", fail_ok,
		" reason=", main.fail_reason,
		" route=", (main.intel.latest_route() if main.intel else ""),
		" leaker=", (main.intel.latest_leaker_id() if main.intel else -1),
		" tick=", main.sim.tick
	)
	await _settle(8)
	_hud(main, "radio_fail")
	await _save("23_fail_radio_card")
	main._on_continue_pressed()
	await _settle(8)
	main._on_clear_pressed()
	await process_frame
	_deploy(main, [1, 4, 5], [270.0, 90.0, 270.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	await _settle(8)
	_hud(main, "radio_ref")
	await _save("24_setup_radio_ref")
	main.sim.set_speed(2.0)
	main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	await _wait_t(main, 6.2, 60 * 20)
	await _settle(8)
	_hud(main, "radio_watch")
	await _save("25_watch_radio_echo")
	win_ok = await _wait_phase(main, main.Phase.WON, 60 * 30)
	print("DUMP_RADIO_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(8)
	_hud(main, "radio_win")
	await _save("26_win_radio")
	main._on_continue_pressed()
	await _settle(10)
	if main.credits_overlay and main.credits_overlay.is_open():
		print("DUMP_CREDITS_OPEN")
		await _save("27_credits")
		main.credits_overlay._on_done()
		await _settle(16)
	else:
		print("DUMP_NO_CREDITS")
		await _save("27_credits")

	title = current_scene
	if title == null or not title.has_method("open_journal"):
		push_error("DUMP_NO_TITLE_RETURN")
		quit(3)
		return
	await _settle(12)
	await _save("28_title_after")
	title.open_journal()
	await _settle(10)
	await _save("29_journal_stamped")
	if title._journal:
		title._journal.dismiss()
		await _settle(4)
	title._on_start()
	await _settle(8)
	await _save("30_mission_select_cleared")
	if title.has_method("_on_back"):
		title._on_back()
		await _settle(4)

	# Touch HUD on radio via a fresh main load (campaign save already complete).
	err = change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("DUMP_NO_MAIN_TOUCH")
		quit(2)
		return
	await _settle(16)
	main = current_scene
	_dismiss_tut(main)
	if main.has_method("_load_level"):
		main._load_level("radio", false, false)
		await _settle(12)
		_dismiss_tut(main)
	_deploy(main, [1, 4, 5], [270.0, 90.0, 270.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.force_touch_hud = true
	main._start_setup(false, false)
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(10)
	await _save("31_touch_radio_bars")
	if gs:
		gs.force_touch_hud = false
	print("DUMP_OK eval_71ca4af")
	quit(0)


func _deploy(main, slots: Array, faces: Array) -> void:
	for i in slots.size():
		main._select_op(i)
		main._deploy_selected_to(main.cover_slots[int(slots[i])])
		main.selected.set_facing(float(faces[i]))


func _dismiss_tut(main) -> void:
	if main.tutorial_overlay and main.tutorial_overlay.is_open():
		var g := 0
		while main.tutorial_overlay.is_open() and g < 8:
			main.tutorial_overlay._on_next()
			g += 1


func _wait_phase(main, want, max_frames: int) -> bool:
	var frames := 0
	while frames < max_frames:
		await process_frame
		frames += 1
		if main.phase == want:
			return true
		if want != main.Phase.FAILED and main.phase == main.Phase.FAILED:
			return false
		if want != main.Phase.WON and main.phase == main.Phase.WON:
			return false
	return false


func _wait_t(main, sec: float, max_frames: int) -> void:
	var frames := 0
	while frames < max_frames:
		await process_frame
		frames += 1
		if main.get("sim") != null and float(main.sim.time_sec()) >= sec:
			return
		if main.phase == main.Phase.FAILED or main.phase == main.Phase.WON:
			return


func _hud(main, tag: String) -> void:
	var beat := ""
	if main.spawn_teach_label:
		beat = str(main.spawn_teach_label.text).replace("\n", " / ")
	var status := str(main.status_label.text).replace("\n", " / ") if main.status_label else ""
	var intel := str(main.intel_label.text).replace("\n", " / ") if main.intel_label else ""
	var card := str(main.result_label.text).replace("\n", " / ") if main.result_label and main.result_panel and main.result_panel.visible else ""
	var chip := str(main.checklist_strip_text()).replace("\n", " | ") if main.has_method("checklist_strip_text") else ""
	var tsec := 0.0
	if main.get("sim") != null:
		tsec = float(main.sim.time_sec())
	print(
		"DUMP_HUD tag=", tag,
		" level=", (main.level.level_id if main.level else "?"),
		" phase=", main.phase,
		" t=", snapped(tsec, 0.1),
		" tick=", (main.sim.tick if main.get("sim") else -1),
		" beat=", beat,
		" status=", status,
		" intel=", intel,
		" chip=", chip,
		" card=", card
	)
	if main.has_method("setup_teaching_layers"):
		print("DUMP_LAYERS ", main.setup_teaching_layers())


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
		# Keep first-visit tutorial so we can capture the yard overlay, then dismiss.
		gs.seen_tutorial = false
