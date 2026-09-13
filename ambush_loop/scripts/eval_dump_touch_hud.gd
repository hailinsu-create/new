extends SceneTree

## Forced-touch HUD stills for v0.5.4 phone feel: crate names off,
## 绕背 clears west court, follow spacing, tighter hotspots, courtyard loop.

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
	var gs0 := root.get_node_or_null("GameSettings")
	if gs0:
		gs0.force_touch_hud = true
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
	if main.c2 and main.c2.has_method("layout_chrome"):
		main.c2.layout_chrome(true)
	main._ensure_touch_hud()
	main._update_hud()
	await _settle(8)
	_count_chrome(main, "scout")
	_dump_feel(main, "scout")
	await _save("01_scout_touch_simple")

	if main.operators.size() > 0 and not main.raid_stashes.is_empty():
		main._select_op(0)
		main.operators[0].global_position = main.raid_stashes[0].global_position
		if main.c2 and main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(8)
		_count_chrome(main, "scout_hotspot")
		await _save("03_scout_hotspots")

	if main.c2 and not main.c2.sentries.is_empty() and main.operators.size() > 0:
		var op = main.operators[0]
		var sent = main.c2.sentries[0]
		var clear := Vector2(220, 280)
		if main.grid:
			clear = main.grid.cell_to_world_center(Vector2i(6, 8))
		op.global_position = clear
		sent.global_position = clear + Vector2(16, 0)
		sent.facing_deg = 0.0
		main._select_op(0)
		if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(8)
		_count_chrome(main, "scout_knife")
		await _save("04_scout_hotspot_knife")
		sent.global_position = clear + Vector2(64, 0)
		sent.facing_deg = 0.0
		op.global_position = clear
		if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(8)
		_count_chrome(main, "scout_flank")
		_dump_feel(main, "flank")
		var west_hits := -1
		if main.c2.prompt and main.c2.prompt.has_method("hotspot_hits_west_operable"):
			west_hits = int(main.c2.prompt.hotspot_hits_west_operable())
		print("DUMP_FLANK_WEST_HITS ", west_hits, " rects=", main.c2.prompt.visible_hotspot_rects() if main.c2.prompt else [])
		await _save("05_scout_hotspot_flank")
		if main.has_method("apply_context_action"):
			main.apply_context_action("flank", sent.global_position)
		await _settle(10)
		_count_chrome(main, "scout_flank_path")
		var cone_hits := 0
		if main.operators.size() > 0:
			for pt in main.operators[0].move_path:
				if main.has_method("_sentry_blocks_stealth") and bool(main._sentry_blocks_stealth(pt, main.operators[0])):
					cone_hits += 1
		print("DUMP_FLANK_PATH hits=", cone_hits, " pts=", main.operators[0].move_path.size() if main.operators.size() > 0 else 0)
		await _save("05b_scout_flank_path")
		op.stop_move()
		var west_op := Vector2i(7, 12)
		var west_sent := Vector2i(9, 12)
		if main.grid.is_blocked(west_op.x, west_op.y):
			west_op = Vector2i(6, 13)
		if main.grid.is_blocked(west_sent.x, west_sent.y):
			west_sent = Vector2i(9, 13)
		op.global_position = main.grid.cell_to_world_center(west_op)
		sent.global_position = main.grid.cell_to_world_center(west_sent)
		sent.facing_deg = 0.0
		if sent.has_method("_rebuild_cone"):
			sent._rebuild_cone()
		if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(8)
		var west2 := int(main.c2.prompt.hotspot_hits_west_operable()) if main.c2.prompt and main.c2.prompt.has_method("hotspot_hits_west_operable") else -1
		print(
			"DUMP_WEST_FLANK hits=", west2,
			" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2.prompt else PackedStringArray()),
			" rects=", main.c2.prompt.visible_hotspot_rects() if main.c2.prompt else []
		)
		_dump_feel(main, "west_flank")
		await _save("05c_west_flank")
		op.stop_move()

	await _walk_yard_loop(main)

	if main.operators.size() >= 2:
		main._select_op(0)
		if main.c2 and not main.c2.sentries.is_empty() and main.grid:
			var park: Vector2 = main.grid.cell_to_world_center(Vector2i(32, 6))
			for s in main.c2.sentries:
				if s and is_instance_valid(s):
					s.global_position = park
					s.facing_deg = 0.0
		var spine := Vector2i(15, 13)
		if main.grid and main.grid.is_blocked(spine.x, spine.y):
			spine = Vector2i(14, 15)
		var sw: Vector2 = main.grid.cell_to_world_center(spine)
		main.operators[0].stop_move()
		main.operators[0].facing_deg = 0.0
		main.operators[0].global_position = sw
		if main.has_method("toggle_follow"):
			if not bool(main.operators[1].follow_lead):
				main.toggle_follow(1)
			if main.operators.size() >= 3 and not bool(main.operators[2].follow_lead):
				main.toggle_follow(2)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		var frames := 0
		while frames < 90:
			if main.has_method("_tick_command_moves"):
				main._tick_command_moves(0.05)
			await process_frame
			frames += 1
			var busy := false
			for opx in main.operators:
				if opx and opx.is_moving():
					busy = true
					break
			if not busy and frames > 12:
				break
		main._update_hud()
		await _settle(8)
		_dump_feel(main, "follow")
		print(
			"DUMP_FOLLOW_SPREAD dest=", snapped(float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else -1.0, 0.1),
			" live=", snapped(float(main.follow_min_spacing()) if main.has_method("follow_min_spacing") else -1.0, 0.1)
		)
		await _save("09_scout_follow")
		if bool(main.operators[1].follow_lead):
			main.toggle_follow(1)
		if main.operators.size() >= 3 and bool(main.operators[2].follow_lead):
			main.toggle_follow(2)

	if main.has_method("raid_prepare_ref"):
		main.raid_prepare_ref([0, 1, 2], [0.0, 0.0, 90.0], {"grenades": 2, "mines": 1})
	await _settle(6)
	main._on_alarm_pressed()
	await _settle(16)
	_count_chrome(main, "alert")
	_dump_feel(main, "alert")
	await _save("02_alert_touch_watch")

	print("DUMP_TOUCH_HUD_OK")
	quit(0)


func _walk_yard_loop(main) -> void:
	if main.operators.is_empty() or main.grid == null:
		return
	main._select_op(0)
	var op = main.operators[0]
	var cells: Array = main.yard_touch_loop_cells() if main.has_method("yard_touch_loop_cells") else [
		Vector2i(6, 16), Vector2i(6, 8), Vector2i(18, 6), Vector2i(32, 8),
		Vector2i(32, 16), Vector2i(18, 17), Vector2i(6, 16),
	]
	var names: PackedStringArray = PackedStringArray([
		"loop_sw", "loop_nw", "loop_n", "loop_ne", "loop_se", "loop_s", "loop_home"
	])
	for i in cells.size():
		var cell: Vector2i = cells[i]
		if main.grid.has_method("is_blocked") and bool(main.grid.is_blocked(cell.x, cell.y)):
			cell = _open_near(main, cell)
		var world: Vector2 = main.grid.cell_to_world_center(cell)
		op.stop_move()
		if main.has_method("simulate_touch_tap"):
			main.simulate_touch_tap(world)
		elif main.has_method("_command_move_selected"):
			main._command_move_selected(world)
		var frames := 0
		while op.is_moving() and frames < 260:
			await process_frame
			frames += 1
		if not op.is_moving():
			op.global_position = world
		if main.c2 and main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		main._update_hud()
		await _settle(6)
		_count_chrome(main, str(names[i]))
		_dump_feel(main, str(names[i]))
		var slot_hit := main._nearest_slot(world, 14.0) != null and op.slot != null
		print(
			"DUMP_LOOP i=", i, " name=", names[i], " cell=", cell,
			" gest=", main._last_touch_gesture,
			" moving=", op.is_moving(),
			" cover_snap=", slot_hit,
			" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2 and main.c2.prompt else PackedStringArray())
		)
		if str(names[i]) in ["loop_nw", "loop_n", "loop_ne", "loop_se", "loop_home"]:
			await _save("06_%s" % names[i])


func _open_near(main, cell: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := Vector2i(cell.x + dx, cell.y + dy)
				if main.grid.in_bounds(n.x, n.y) and not bool(main.grid.is_blocked(n.x, n.y)):
					return n
	return cell


func _dump_feel(main, tag: String) -> void:
	if not main.has_method("dump_touch_feel"):
		return
	var f: Dictionary = main.dump_touch_feel()
	print(
		"DUMP_FEEL tag=", tag,
		" intel_y=", snapped(float(f.get("intel_y", -1)), 0.1),
		" check_bot=", snapped(float(f.get("check_bot", -1)), 0.1),
		" teach=", f.get("teach"),
		" legend=", f.get("legend"),
		" timeline=", f.get("timeline"),
		" caps=", " ".join(f.get("hotspots", PackedStringArray())),
		" cmds=", " ".join(f.get("cmds", PackedStringArray())),
		" gesture=", f.get("gesture"),
		" follow=", " ".join(f.get("follow", PackedStringArray())),
		" north_labels=", f.get("north_labels", -1),
		" spawn_tags=", f.get("spawn_tags", -1),
		" route_tags=", f.get("route_tags", -1),
		" mouse_eat=", f.get("mouse_eat", -1),
		" crate_tags=", f.get("crate_tags", -1),
		" west_hits=", f.get("west_hits", -1),
		" follow_dest_spread=", snapped(float(f.get("follow_dest_spread", -1.0)), 0.1)
	)


func _count_chrome(main, tag: String) -> void:
	var n := 0
	if main.touch_hud and main.touch_hud.has_method("setup_visible_button_count"):
		n = int(main.touch_hud.setup_visible_button_count())
	var w := 0
	if main.touch_hud and main.touch_hud.has_method("watch_visible_button_count"):
		w = int(main.touch_hud.watch_visible_button_count())
	var portraits_on := false
	var skills_on := false
	var mmap_on := false
	var portrait_y := -1.0
	var portrait_parent := ""
	var hotspots := 0
	var caps := ""
	if main.get("c2") != null:
		if main.c2.get("portraits") != null:
			portraits_on = bool(main.c2.portraits.visible)
			portrait_y = main.c2.portraits.global_position.y
			if main.c2.portraits.get_parent():
				portrait_parent = str(main.c2.portraits.get_parent().name)
		if main.c2.get("skill_bar") != null:
			skills_on = bool(main.c2.skill_bar.visible)
		if main.c2.get("minimap") != null:
			mmap_on = bool(main.c2.minimap.visible)
		if main.c2.get("prompt") != null and main.c2.prompt.has_method("hotspot_count"):
			hotspots = int(main.c2.prompt.hotspot_count())
			caps = " ".join(main.c2.prompt.visible_captions())
	var cards := "?"
	if main.get("role_box") != null:
		cards = str(main.role_box.visible)
	print(
		"DUMP_CHROME tag=", tag,
		" phase=", (main.phase_id() if main.has_method("phase_id") else main.phase),
		" setup_btns=", n,
		" watch_btns=", w,
		" portraits=", portraits_on,
		" portrait_y=", snapped(portrait_y, 0.1),
		" portrait_parent=", portrait_parent,
		" skillbar=", skills_on,
		" minimap=", mmap_on,
		" left_cards=", cards,
		" hotspots=", hotspots,
		" caps=", caps
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
