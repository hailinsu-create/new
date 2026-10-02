extends SceneTree

## Window dump for Ambush Loop v0.4.0 Commandos 2 kit.
## Title v0.4.0 → SCOUT knives → Kar98k crate → backpack UI → 雷点 →
## ALERT cinema 警报中 (no 锁死) → auto grenade → SWEEP → extract.
## Named crates from the 10-gun kit only. Script-driven.

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const OUT := "res://docs/eval_v0.4.0"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	_wipe_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("DUMP_HEAD display=", DisplayServer.get_name(), " size=", DisplayServer.window_get_size(), " ver=", ProjectSettings.get_setting("application/config/version", ""))

	var err := change_scene_to_file("res://scenes/title.tscn")
	if err != OK:
		push_error("DUMP_NO_TITLE")
		quit(2)
		return
	await _settle(20)
	var title = current_scene
	print("DUMP_TITLE tagline=", title.tagline.text if title.get("tagline") else "")
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
	if title.pause_ui and title.pause_ui.has_method("present"):
		title.pause_ui.present(false, false)
		await _settle(8)
		await _save("04_pause_version")
		if title.pause_ui.has_method("dismiss"):
			title.pause_ui.dismiss()
			await _settle(4)
	title._on_start()
	await _settle(8)
	await _save("05_mission_select")
	title._on_mission_picked(0)
	await _settle(8)
	await _save("06_briefing_yard")
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
	await _save("07_tut_yard")
	_dismiss_tut(main)
	await _settle(8)
	_hud(main, "yard_scout_knives")
	_guns(main, "yard_knives")
	_stashes(main, "yard")
	await _save("08_scout_yard_knives")
	var gs_need := root.get_node_or_null("GameSettings")
	if gs_need:
		gs_need.force_touch_hud = true
	main._ensure_touch_hud()
	main._update_hud()
	print(
		"DUMP_TOUCH_ALARM ",
		main.touch_hud._btns["alarm"].text if main.touch_hud and main.touch_hud._btns.has("alarm") else "?"
	)
	await _save("08b_touch_yard_needgun")
	if gs_need:
		gs_need.force_touch_hud = false
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(4)

	# Soft alarm gate while knives-only.
	main._on_alarm_pressed()
	await _settle(6)
	_hud(main, "yard_alarm_gate")
	print("DUMP_ALARM_CTA ", main.alarm_button.text if main.alarm_button else "", " warned=", main._alarm_warned_no_gun, " phase=", main.phase_id() if main.has_method("phase_id") else main.phase)
	await _save("09_scout_alarm_gate")

	# 0.4s crate search on the authored rifle box (6,12).
	var rifle_cell := Vector2i(6, 12)
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(rifle_cell)
	main._select_op(0)
	main._try_pickup_near_selected()
	await _settle(4)
	main.raid_advance_search(0.14)
	_hud(main, "yard_crate_search")
	print("DUMP_SEARCH weapon=", main.operators[0].weapon_id, " searching=", main.operators[0].is_searching() if main.operators[0].has_method("is_searching") else "?", " progress=", main.operators[0].search_stash.search_progress if main.operators[0].search_stash else -1)
	await _save("10_scout_crate_search")
	main.raid_advance_search(0.5)
	await _settle(8)
	_guns(main, "yard_after_rifle")
	_hud(main, "yard_after_rifle")
	await _save("11_scout_yard_kar98k")

	# MG42 class-resolved crate (26,12).
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(26, 12))
	main._select_op(0)
	await _settle(8)
	_hud(main, "yard_mg42_cell")
	await _save("12_scout_yard_mg42")

	# Named crate on the floor (luger @ 21,17 — walkable).
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(21, 17))
	main._select_op(0)
	await _settle(8)
	_hud(main, "yard_luger_cell")
	await _save("13_scout_yard_luger_cell")

	# Backpack UI + 雷点 (Commandos 2 kit).
	main.operators[0].receive_item("grenade", 2)
	main._select_op(0)
	if main.has_method("_toggle_backpack"):
		main._toggle_backpack()
		await _settle(8)
		print("DUMP_BACKPACK open=", main.backpack_panel.is_open() if main.backpack_panel else false, " occ=", main.operators[0].pack.occupied() if main.operators[0].pack else -1)
		await _save("13b_backpack_open")
		main._toggle_backpack()
		await _settle(4)
	main._place_nade_mark(main.operators[0].global_position + Vector2(72, 0))
	await _settle(6)
	print("DUMP_NADE_MARK ", main.operators[0].has_nade_mark)
	await _save("13c_nade_mark")

	# Knife leak fail (second press). Restore knives first.
	main._start_setup(false, false)
	_dismiss_tut(main)
	await _settle(6)
	main._on_alarm_pressed()
	if main.phase == main.Phase.SETUP:
		main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	var fail_ok := await _wait_phase(main, main.Phase.FAILED, 60 * 50)
	print("DUMP_KNIFE_LEAK ok=", fail_ok, " reason=", main.fail_reason, " tick=", main.sim.tick, " wave=", main.wave_index() if main.has_method("wave_index") else -1)
	await _settle(8)
	_hud(main, "yard_fail_knife")
	await _save("14_fail_yard_knife")
	if main.has_method("_toggle_fail_dossier"):
		main._toggle_fail_dossier()
		await _settle(6)
		await _save("15_fail_yard_dossier")
		main._toggle_fail_dossier()
	main._on_continue_pressed()
	await _settle(10)
	_dismiss_tut(main)

	# Reference SCOUT→ALERT→SWEEP→WON (instant kits, same as smoke).
	main._start_setup(false, false)
	_dismiss_tut(main)
	await _settle(6)
	main.raid_prepare_ref([1, 2, 5], [90.0, 180.0, 180.0])
	await _settle(8)
	_guns(main, "yard_ref")
	_hud(main, "yard_ref_scout")
	await _save("16_scout_yard_ref")
	main.sim.set_speed(2.0)
	main.raid_force_alarm()
	main.sim.set_speed(2.0)
	await _wait_t(main, 1.1, 60 * 10)
	await _settle(6)
	_hud(main, "yard_alert_w1")
	await _save("17_alert_yard_w1")
	var sweep_ok := await _wait_phase(main, main.Phase.SWEEP, 60 * 40)
	print("DUMP_SWEEP_W1 ok=", sweep_ok, " phase=", main.phase_id() if main.has_method("phase_id") else main.phase, " tick=", main.sim.tick, " loot=", main.living_loot_count() if main.has_method("living_loot_count") else -1)
	await _settle(8)
	_hud(main, "yard_sweep_w1")
	await _save("18_sweep_yard_w1")
	if main.has_method("raid_vacuum_loot"):
		print("DUMP_VACUUM n=", main.raid_vacuum_loot())
	main.sim.set_speed(2.0)
	main.raid_force_alarm()
	main.sim.set_speed(2.0)
	await _wait_t(main, 0.8, 60 * 8)
	await _settle(4)
	_hud(main, "yard_alert_w2")
	await _save("19_alert_yard_w2")
	var win_ok := await _wait_win_or_sweep_extract(main, 60 * 40)
	print("DUMP_YARD_WIN ok=", win_ok, " phase=", main.phase_id() if main.has_method("phase_id") else main.phase, " tick=", main.sim.tick)
	await _settle(8)
	_hud(main, "yard_win")
	await _save("20_win_yard")
	main._on_continue_pressed()
	await _settle(10)
	if main.night_handoff and main.night_handoff.is_open():
		print("DUMP_HANDOFF from=", main.night_handoff.from_id(), " to=", main.night_handoff.to_id())
		await _save("21_handoff_yard_warehouse")
		main.night_handoff.dismiss()
		await _settle(8)
	else:
		print("DUMP_NO_HANDOFF")
		await _save("21_handoff_yard_warehouse")

	_dismiss_tut(main)
	await _settle(6)
	_stashes(main, "warehouse")
	_hud(main, "warehouse_empty")
	await _save("22_scout_warehouse_empty")
	# MP40 crate (27? 14,16)
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(14, 16))
	await _settle(8)
	await _save("23_scout_warehouse_mp40")
	main.raid_prepare_ref([1, 3, 5], [180.0, 0.0, 180.0])
	if main.has_method("_play_hold_pack"):
		main._play_hold_pack(1)
	win_ok = await _run_all_waves(main, 60 * 50)
	print("DUMP_WAREHOUSE_WIN ok=", win_ok, " tick=", main.sim.tick)
	main._on_continue_pressed()
	await _settle(8)
	_dismiss_handoff(main)

	_dismiss_tut(main)
	_stashes(main, "pump")
	_hud(main, "pump_empty")
	await _save("24_scout_pump_empty")
	if not main.door_locked:
		main._on_door_pressed()
	main.raid_prepare_ref([1, 4, 5], [90.0, 180.0, 180.0])
	win_ok = await _run_all_waves(main, 60 * 50)
	print("DUMP_PUMP_WIN ok=", win_ok, " tick=", main.sim.tick)
	main._on_continue_pressed()
	await _settle(8)
	_dismiss_handoff(main)

	_dismiss_tut(main)
	_stashes(main, "railcut")
	_hud(main, "railcut_empty")
	await _save("25_scout_railcut_empty")
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(18, 16))
	await _settle(8)
	await _save("26_scout_railcut_mg42")
	main.raid_prepare_ref([1, 4, 5], [270.0, 270.0, 180.0])
	win_ok = await _run_all_waves(main, 60 * 50)
	print("DUMP_RAILCUT_WIN ok=", win_ok, " tick=", main.sim.tick)
	main._on_continue_pressed()
	await _settle(8)
	_dismiss_handoff(main)

	_dismiss_tut(main)
	_stashes(main, "depot")
	_hud(main, "depot_empty")
	await _save("27_scout_depot_empty")
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(16, 16))
	await _settle(8)
	await _save("28_scout_depot_thompson")
	main.raid_prepare_ref([1, 4, 5], [270.0, 270.0, 180.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	win_ok = await _run_all_waves(main, 60 * 50)
	print("DUMP_DEPOT_WIN ok=", win_ok, " tick=", main.sim.tick)
	main._on_continue_pressed()
	await _settle(10)
	if main.night_handoff and main.night_handoff.is_open():
		await _save("29_handoff_depot_radio")
		main.night_handoff.dismiss()
		await _settle(8)
	else:
		await _save("29_handoff_depot_radio")

	_dismiss_tut(main)
	_stashes(main, "radio")
	_hud(main, "radio_empty")
	await _save("30_scout_radio_empty")
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(Vector2i(18, 16))
	await _settle(8)
	await _save("31_scout_radio_springfield")
	main.raid_prepare_ref([1, 4, 5], [270.0, 90.0, 270.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	win_ok = await _run_all_waves(main, 60 * 60)
	print("DUMP_RADIO_WIN ok=", win_ok, " tick=", main.sim.tick)
	await _settle(8)
	_hud(main, "radio_win")
	await _save("32_win_radio")
	main._on_continue_pressed()
	await _settle(10)
	if main.credits_overlay and main.credits_overlay.is_open():
		print("DUMP_CREDITS_OPEN")
		await _save("33_credits")
		main.credits_overlay._on_done()
		await _settle(16)
	else:
		print("DUMP_NO_CREDITS")
		await _save("33_credits")

	title = current_scene
	if title == null or not title.has_method("open_journal"):
		push_error("DUMP_NO_TITLE_RETURN")
		quit(3)
		return
	await _settle(12)
	print("DUMP_TITLE_AFTER tagline=", title.tagline.text if title.get("tagline") else "")
	await _save("34_title_after")
	title.open_journal()
	await _settle(10)
	await _save("35_journal_stamped")
	if title._journal:
		title._journal.dismiss()
		await _settle(4)
	title._on_start()
	await _settle(8)
	await _save("36_mission_select_cleared")
	if title.has_method("_on_back"):
		title._on_back()
		await _settle(4)

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
	main.raid_prepare_ref([1, 4, 5], [270.0, 90.0, 270.0])
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.force_touch_hud = true
	main._start_setup(false, false)
	_dismiss_tut(main)
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(10)
	await _save("37_touch_radio_bars")
	if gs:
		gs.force_touch_hud = false
	print("DUMP_OK eval_v0.4.0")
	quit(0)


func _run_all_waves(main, max_frames: int) -> bool:
	var guard := 0
	while guard < 8:
		guard += 1
		if main.phase == main.Phase.SETUP or main.phase == main.Phase.SWEEP:
			main.sim.set_speed(2.0)
			main.raid_force_alarm()
			main.sim.set_speed(2.0)
		var frames := 0
		while frames < max_frames:
			await process_frame
			frames += 1
			if main.phase == main.Phase.SWEEP or main.phase == main.Phase.WON or main.phase == main.Phase.FAILED:
				break
		if main.phase == main.Phase.FAILED:
			return false
		if main.phase == main.Phase.WON:
			return true
		if main.phase == main.Phase.SWEEP:
			if main.has_method("raid_vacuum_loot"):
				main.raid_vacuum_loot()
			if main.raid != null and main.raid.is_last_wave(main.level):
				main.raid_force_alarm()
				await process_frame
				await process_frame
				return main.phase == main.Phase.WON
			continue
		return false
	return main.phase == main.Phase.WON


func _wait_win_or_sweep_extract(main, max_frames: int) -> bool:
	var frames := 0
	while frames < max_frames:
		await process_frame
		frames += 1
		if main.phase == main.Phase.WON:
			return true
		if main.phase == main.Phase.FAILED:
			return false
		if main.phase == main.Phase.SWEEP:
			if main.has_method("raid_vacuum_loot"):
				main.raid_vacuum_loot()
			main.raid_force_alarm()
	return main.phase == main.Phase.WON


func _dismiss_handoff(main) -> void:
	if main.night_handoff and main.night_handoff.is_open():
		main.night_handoff.dismiss()


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
		if main.phase == main.Phase.FAILED or main.phase == main.Phase.WON or main.phase == main.Phase.SWEEP:
			return


func _guns(main, tag: String) -> void:
	var bits: PackedStringArray = PackedStringArray()
	for op in main.operators:
		if op == null:
			continue
		bits.append("%s=%s ammo=%s" % [op.display_name, op.weapon_id, op.ammo])
	print("DUMP_GUNS tag=", tag, " ", " | ".join(bits))


func _stashes(main, tag: String) -> void:
	var bits: PackedStringArray = PackedStringArray()
	for s in main.raid_stashes:
		if s == null or not is_instance_valid(s) or bool(s.collected):
			continue
		var lab := ""
		if s.tag:
			lab = str(s.tag.text)
		bits.append("%s@%s[%s]" % [s.kind, s.cell, lab])
	print("DUMP_STASH tag=", tag, " n=", bits.size(), " ", " ".join(bits))


func _hud(main, tag: String) -> void:
	var beat := ""
	if main.spawn_teach_label:
		beat = str(main.spawn_teach_label.text).replace("\n", " / ")
	var status := str(main.status_label.text).replace("\n", " / ") if main.status_label else ""
	var intel := str(main.intel_label.text).replace("\n", " / ") if main.intel_label else ""
	var card := str(main.result_label.text).replace("\n", " / ") if main.result_label and main.result_panel and main.result_panel.visible else ""
	var chip := str(main.checklist_strip_text()).replace("\n", " | ") if main.has_method("checklist_strip_text") else ""
	var phase_txt := str(main.phase_chip.text) if main.phase_chip else ""
	var tsec := 0.0
	if main.get("sim") != null:
		tsec = float(main.sim.time_sec())
	var cinema := str(main.cinema_banner_text()) if main.has_method("cinema_banner_text") else ""
	var flash := str(main.flash_text()) if main.has_method("flash_text") else ""
	var board := str(main.stash_board.text) if main.get("stash_board") else ""
	print(
		"DUMP_HUD tag=", tag,
		" level=", (main.level.level_id if main.level else "?"),
		" phase=", (main.phase_id() if main.has_method("phase_id") else main.phase),
		" t=", snapped(tsec, 0.1),
		" tick=", (main.sim.tick if main.get("sim") else -1),
		" chip=", phase_txt,
		" cinema=", cinema,
		" flash=", flash,
		" board=", board,
		" beat=", beat,
		" status=", status,
		" intel=", intel,
		" list=", chip,
		" card=", card,
		" alarm=", (main.alarm_button.text if main.alarm_button else "")
	)


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
