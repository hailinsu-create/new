extends SceneTree

## Forced-touch HUD stills for v0.5.32 phone feel: west trio dest spread
## (span 4, (6,8)/(5,15), no west-wall hug), bodies/rings at visual floor
## (~0.16) + camera at ~0.26 clamp, south-corridor full path y=14 pulled
## into y≤13 (mid x≈21 included), settle-on-ring after ↻, bidirectional
## ↺/↻ swipe, faded yellow cone, compact 5-key, crate-cluster axis_run 0.

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
	_dump_compact(main, "scout")
	_dump_twist_swipe(main)
	await _save("01_scout_touch_simple")

	if main.operators.size() > 0 and not main.raid_stashes.is_empty():
		main._select_op(0)
		main.operators[0].global_position = main.raid_stashes[0].global_position
		if main.c2 and main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(8)
		_count_chrome(main, "scout_hotspot")
		await _save("03_scout_hotspots")

	await _walk_west_crate(main)

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
		sent.route = PackedVector2Array([sent.global_position])
		sent.route_i = 0
		sent.frozen = true
		if sent.has_method("_rebuild_cone"):
			sent._rebuild_cone()
		if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
			main.c2.prompt.refresh_now()
		await _settle(4)
		var west2 := int(main.c2.prompt.hotspot_hits_west_operable()) if main.c2.prompt and main.c2.prompt.has_method("hotspot_hits_west_operable") else -1
		print(
			"DUMP_WEST_FLANK hits=", west2,
			" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2.prompt else PackedStringArray()),
			" rects=", main.c2.prompt.visible_hotspot_rects() if main.c2.prompt else []
		)
		_dump_feel(main, "west_flank")
		await _save("05c_west_flank")
		var fired := false
		if main.has_method("simulate_hotspot"):
			fired = bool(main.simulate_hotspot("绕背"))
		if not fired and main.has_method("_start_flank_approach"):
			main._start_flank_approach(sent.global_position)
			fired = true
		await _settle(8)
		var path_hits := 0
		for pt in op.move_path:
			if main.has_method("_sentry_blocks_stealth") and bool(main._sentry_blocks_stealth(pt, op)):
				path_hits += 1
		print("DUMP_WEST_FLANK_FIRE fire=", fired, " hits=", path_hits, " pts=", op.move_path.size())
		await _save("05d_west_flank_path")
		op.stop_move()
		await _walk_flank_guide_complete(main)
		await _walk_flank_side_wrap(main)
		await _walk_west_combo_follow(main)
		await _walk_short_detour(main)
		await _walk_follow_continuity(main)
		await _walk_follow_settle(main)
		await _walk_three_follow_side_wrap(main)
		await _walk_west_rear(main)
		await _walk_facing_turn(main)
		await _walk_badge_probes(main)

	await _walk_yard_loop(main)

	await _walk_three_follow(main)

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


func _walk_west_crate(main) -> void:
	if main.operators.is_empty() or not main.has_method("west_stash"):
		return
	var st = main.west_stash()
	if st == null:
		print("DUMP_WEST_CRATE none")
		return
	if main.c2 and not main.c2.sentries.is_empty() and main.grid:
		var park: Vector2 = main.grid.cell_to_world_center(Vector2i(32, 6))
		for s in main.c2.sentries:
			if s and is_instance_valid(s):
				s.global_position = park
				s.facing_deg = 0.0
	var op = main.operators[0]
	main._select_op(0)
	op.stop_move()
	if op.has_method("cancel_search"):
		op.cancel_search()
	var crate_world: Vector2 = st.global_position
	var crate_cell: Vector2i = main.grid.world_to_cell(crate_world) if main.grid else Vector2i(-1, -1)
	if main.has_method("simulate_touch_tap"):
		main.simulate_touch_tap(crate_world)
	op.stop_move()
	op.global_position = crate_world
	if op.has_method("cancel_search"):
		op.cancel_search()
	if main.c2 and main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
		main.c2.prompt.refresh_now()
	await _settle(4)
	if op.has_method("cancel_search"):
		op.cancel_search()
	_count_chrome(main, "west_crate")
	_dump_feel(main, "west_crate")
	var fired := false
	if main.has_method("simulate_hotspot"):
		fired = bool(main.simulate_hotspot("开匣"))
	if op.has_method("cancel_search"):
		op.cancel_search()
	print(
		"DUMP_WEST_CRATE cell=", crate_cell,
		" gest=", main._last_touch_gesture,
		" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2 and main.c2.prompt else PackedStringArray()),
		" fire=", fired
	)
	await _save("07_west_crate")
	op.stop_move()
	if op.has_method("cancel_search"):
		op.cancel_search()


func _walk_west_combo_follow(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 == null or main.c2.sentries.is_empty():
		return
	var sent = main.c2.sentries[0]
	var i := 1
	for s in main.c2.sentries:
		if s == null or s == sent:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		i += 1
	var lead_c := Vector2i(7, 12)
	var sent_c := Vector2i(9, 12)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(9, 13)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 16)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	var frames := 0
	while frames < 80:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		var busy := false
		for opx in main.operators:
			if opx and opx.is_moving():
				busy = true
				break
		if not busy and frames > 10:
			break
	for _hold in 8:
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		await process_frame
	main._update_hud()
	await _settle(6)
	_dump_feel(main, "west_combo_follow")
	print(
		"DUMP_WEST_COMBO dest=", snapped(float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else -1.0, 0.1),
		" live=", snapped(float(main.follow_min_spacing()) if main.has_method("follow_min_spacing") else -1.0, 0.1),
		" cone=", int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else -1,
		" rim=", int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else -1,
		" detour=", int(main.follow_max_detour()) if main.has_method("follow_max_detour") else -1,
		" idle=", int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else -1,
		" cheb=", int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else -1,
		" span=", int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else -1,
		" zoom=", snapped(float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0, 0.01),
		" obs_scale=", snapped(float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0, 0.01),
		" obs_r=", snapped(float(main.follow_obs_visual_radius()) if main.has_method("follow_obs_visual_radius") else 0.0, 0.1),
		" d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" queue=", int(main.follow_west_queue_hits()) if main.has_method("follow_west_queue_hits") else -1,
		" dest_w_spread=", snapped(float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else -1.0, 0.1),
		" cluster_scale=", snapped(float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0, 0.01),
		" cone_fade=", snapped(float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0, 0.01),
		" obs_off=", snapped(float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0, 0.1),
		" obs_ring_spread=", snapped(float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0, 0.1)
	)
	await _save("08_west_combo_follow")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	main._pending_flank = null


func _walk_short_detour(main) -> void:
	if main.operators.size() < 3 or main.grid == null or main.c2 == null or main.c2.sentries.is_empty():
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	var sent = main.c2.sentries[0]
	var i := 1
	for s in main.c2.sentries:
		if s == null or s == sent:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		i += 1
	var lead_c := Vector2i(12, 12)
	var sent_c := Vector2i(9, 12)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
		lead_c = Vector2i(12, 13)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(9, 13)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 180.0
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 16)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	var frames := 0
	while frames < 80:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		var busy := false
		for opx in main.operators:
			if opx and opx.is_moving():
				busy = true
				break
		if not busy and frames > 10:
			break
	main._update_hud()
	await _settle(6)
	_dump_feel(main, "short_detour")
	print(
		"DUMP_SHORT_DETOUR dest=", snapped(float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else -1.0, 0.1),
		" live=", snapped(float(main.follow_min_spacing()) if main.has_method("follow_min_spacing") else -1.0, 0.1),
		" cone=", int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else -1,
		" rim=", int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else -1,
		" detour=", int(main.follow_max_detour()) if main.has_method("follow_max_detour") else -1,
		" idle=", int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else -1,
		" cheb=", int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else -1,
		" a=", a.grid_cell(), " b=", b.grid_cell(),
		" d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	)
	await _save("08b_short_detour")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	main._pending_flank = null


func _walk_three_follow(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	main._select_op(0)
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 and not main.c2.sentries.is_empty():
		var sent = main.c2.sentries[0]
		var sent_c := Vector2i(9, 12)
		var lead_c := Vector2i(7, 12)
		if main.grid.is_blocked(sent_c.x, sent_c.y):
			sent_c = Vector2i(9, 13)
		if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
			lead_c = Vector2i(7, 13)
		var i := 1
		for s in main.c2.sentries:
			if s == null or s == sent:
				continue
			s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
			s.facing_deg = 0.0
			i += 1
		sent.global_position = main.grid.cell_to_world_center(sent_c)
		sent.facing_deg = 0.0
		sent.route = PackedVector2Array([sent.global_position])
		sent.route_i = 0
		sent.frozen = true
		if sent.has_method("_rebuild_cone"):
			sent._rebuild_cone()
		lead.stop_move()
		a.stop_move()
		b.stop_move()
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
		lead.global_position = main.grid.cell_to_world_center(lead_c)
		var a_c := Vector2i(6, 14)
		var b_c := Vector2i(6, 16)
		if main.grid.is_blocked(a_c.x, a_c.y):
			a_c = Vector2i(5, 14)
		if main.grid.is_blocked(b_c.x, b_c.y):
			b_c = Vector2i(5, 16)
		a.global_position = main.grid.cell_to_world_center(a_c)
		b.global_position = main.grid.cell_to_world_center(b_c)
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	elif main.has_method("toggle_follow"):
		if not bool(a.follow_lead):
			main.toggle_follow(1)
		if not bool(b.follow_lead):
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
		" live=", snapped(float(main.follow_min_spacing()) if main.has_method("follow_min_spacing") else -1.0, 0.1),
		" cone=", int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else -1,
		" rim=", int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else -1,
		" detour=", int(main.follow_max_detour()) if main.has_method("follow_max_detour") else -1,
		" idle=", int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else -1,
		" cheb=", int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else -1,
		" operable=", int(main.follow_operable_hits()) if main.has_method("follow_operable_hits") else -1,
		" d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	)
	await _save("09_scout_follow")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)


func _walk_flank_guide_complete(main) -> void:
	if main.operators.is_empty() or main.c2 == null or main.c2.sentries.is_empty() or main.grid == null:
		return
	var op = main.operators[0]
	var sent = main.c2.sentries[0]
	var i := 1
	for s in main.c2.sentries:
		if s == null or s == sent:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		i += 1
	var op_c := Vector2i(11, 14)
	var sent_c := Vector2i(12, 12)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(12, 13)
	if main.grid.is_blocked(op_c.x, op_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(op_c))) or op_c == sent_c:
		op_c = Vector2i(10, 14)
	if main.grid.is_blocked(op_c.x, op_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(op_c))) or op_c == sent_c:
		op_c = Vector2i(11, 13)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
		main.c2.prompt.refresh_now()
	await _settle(4)
	var dump := {}
	if main.has_method("flank_guide_dump"):
		dump = main.flank_guide_dump(sent, op)
	var dash := 0
	var dash_ok := false
	if main.c2.prompt and main.c2.prompt.has_method("guide_points"):
		dash = int(main.c2.prompt.guide_points().size())
	if main.c2.prompt and main.c2.prompt.has_method("guide_complete"):
		dash_ok = bool(main.c2.prompt.guide_complete())
	print(
		"DUMP_FLANK_GUIDE pts=", dump.get("pts", -1),
		" complete=", dump.get("complete", false),
		" cone=", dump.get("cone", -1),
		" gaps=", dump.get("gaps", -1),
		" wrap=", dump.get("wrap", false),
		" side=", dump.get("side", false),
		" body=", dump.get("body", -1),
		" dest=", dump.get("dest", Vector2i(-1, -1)),
		" dash=", dash, " dash_ok=", dash_ok,
		" dash_cells=", int(main.c2.prompt.guide_cell_count()) if main.c2.prompt and main.c2.prompt.has_method("guide_cell_count") else -1,
		" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2.prompt else PackedStringArray())
	)
	await _save("05e_flank_guide_full")
	op.stop_move()
	main._pending_flank = null


func _walk_follow_continuity(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 and not main.c2.sentries.is_empty():
		var i := 0
		for s in main.c2.sentries:
			if s == null:
				continue
			s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
			s.facing_deg = 0.0
			i += 1
	var lead_c := Vector2i(16, 14)
	var dest_c := Vector2i(24, 14)
	var a_c := Vector2i(12, 16)
	var b_c := Vector2i(12, 18)
	if main.grid.is_blocked(lead_c.x, lead_c.y):
		lead_c = Vector2i(15, 14)
	if main.grid.is_blocked(dest_c.x, dest_c.y):
		dest_c = Vector2i(23, 14)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	if main.has_method("_command_move_selected"):
		main._command_move_selected(main.grid.cell_to_world_center(dest_c))
	var stalls := 0
	var moving := 0
	var hop := 0
	var prev_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var prev_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var frames := 0
	while frames < 90:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
		var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		if d1 != prev_d1:
			hop += 1
			prev_d1 = d1
		if d2 != prev_d2:
			hop += 1
			prev_d2 = d2
		if d1.x >= 0 and a.grid_cell() != d1 and a.is_moving():
			moving += 1
		if d2.x >= 0 and b.grid_cell() != d2 and b.is_moving():
			moving += 1
		if d1.x >= 0 and a.grid_cell() != d1 and not a.is_moving():
			stalls += 1
		if d2.x >= 0 and b.grid_cell() != d2 and not b.is_moving():
			stalls += 1
		var busy: bool = lead.is_moving() or a.is_moving() or b.is_moving()
		if not busy and frames > 12:
			break
	main._update_hud()
	await _settle(6)
	_dump_feel(main, "walk_follow")
	print(
		"DUMP_WALK_FOLLOW flips=", int(main.follow_dest_flips()) if main.has_method("follow_dest_flips") else -1,
		" hop=", hop, " stalls=", stalls, " move=", moving,
		" lead=", lead.grid_cell(),
		" d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1
	)
	await _save("08c_walk_follow")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()


func _walk_flank_side_wrap(main) -> void:
	if main.operators.is_empty() or main.c2 == null or main.c2.sentries.is_empty() or main.grid == null:
		return
	var op = main.operators[0]
	var sent = main.c2.sentries[0]
	var i := 1
	for s in main.c2.sentries:
		if s == null or s == sent:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		i += 1
	var op_c := Vector2i(12, 14)
	var sent_c := Vector2i(12, 12)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(12, 13)
	if main.grid.is_blocked(op_c.x, op_c.y) or op_c == sent_c:
		op_c = Vector2i(11, 14)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
		main.c2.prompt.refresh_now()
	await _settle(4)
	var dump := {}
	if main.has_method("flank_guide_dump"):
		dump = main.flank_guide_dump(sent, op)
	print(
		"DUMP_FLANK_SIDE_WRAP pts=", dump.get("pts", -1),
		" wrap=", dump.get("wrap", false),
		" side=", dump.get("side", false),
		" body=", dump.get("body", -1),
		" complete=", dump.get("complete", false),
		" dest=", dump.get("dest", Vector2i(-1, -1)),
		" from=", op.grid_cell(),
		" dash_cells=", int(main.c2.prompt.guide_cell_count()) if main.c2.prompt and main.c2.prompt.has_method("guide_cell_count") else -1,
		" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2.prompt else PackedStringArray())
	)
	await _save("05f_flank_side_wrap")
	op.stop_move()
	main._pending_flank = null


func _walk_follow_settle(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 and not main.c2.sentries.is_empty():
		var i := 0
		for s in main.c2.sentries:
			if s == null:
				continue
			s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
			s.facing_deg = 0.0
			i += 1
	var lead_c := Vector2i(15, 14)
	var dest_c := Vector2i(24, 14)
	var a_c := Vector2i(12, 16)
	var b_c := Vector2i(12, 18)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
		lead_c = Vector2i(14, 14)
	if main.grid.is_blocked(dest_c.x, dest_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(dest_c))):
		dest_c = Vector2i(23, 14)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(11, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 18)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	if main.has_method("_command_move_selected"):
		main._command_move_selected(main.grid.cell_to_world_center(dest_c))
	var walk_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var walk_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var frames := 0
	while frames < 90:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		if lead.is_moving():
			walk_d1 = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
			walk_d2 = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		else:
			break
	var stop_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var stop_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	for _j in 32:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
	print(
		"DUMP_FOLLOW_SETTLE walk=", walk_d1, walk_d2,
		" stop=", stop_d1, stop_d2,
		" end=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" drops=", int(main.follow_settle_drops()) if main.has_method("follow_settle_drops") else -1,
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1,
		" lead=", lead.grid_cell()
	)
	await _save("08d_follow_settle")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()


func _walk_three_follow_side_wrap(main) -> void:
	if main.operators.size() < 3 or main.grid == null or main.c2 == null or main.c2.sentries.is_empty():
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	var sent = main.c2.sentries[0]
	var i := 1
	for s in main.c2.sentries:
		if s == null or s == sent:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		i += 1
	var lead_c := Vector2i(11, 14)
	var sent_c := Vector2i(12, 12)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(Vector2i(9, 16))
	b.global_position = main.grid.cell_to_world_center(Vector2i(8, 17))
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	if main.c2.prompt and main.c2.prompt.has_method("refresh_now"):
		main.c2.prompt.refresh_now()
	await _settle(4)
	var dump := {}
	if main.has_method("flank_guide_dump"):
		dump = main.flank_guide_dump(sent, lead)
	if main.has_method("simulate_hotspot"):
		main.simulate_hotspot("绕背")
	var wait_i := 0
	while lead.is_moving() and wait_i < 40:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
		wait_i += 1
	lead.stop_move()
	if dump.has("dest") and typeof(dump.get("dest")) == TYPE_VECTOR2I:
		var back_c: Vector2i = dump.get("dest")
		if back_c.x >= 0:
			lead.global_position = main.grid.cell_to_world_center(back_c)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	var frames := 0
	while frames < 50:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 8:
			break
	print(
		"DUMP_THREE_SIDE_WRAP pts=", dump.get("pts", -1),
		" wrap=", dump.get("wrap", false),
		" body=", dump.get("body", -1),
		" d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1,
		" lead=", lead.grid_cell(),
		" caps=", " ".join(main.c2.prompt.visible_captions() if main.c2.prompt else PackedStringArray())
	)
	await _save("08e_three_side_wrap")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	main._pending_flank = null


func _walk_west_rear(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 and not main.c2.sentries.is_empty():
		var i := 0
		for s in main.c2.sentries:
			if s == null:
				continue
			s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
			s.facing_deg = 0.0
			i += 1
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 16)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	var frames := 0
	while frames < 50:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 8:
			break
	for _hold in 8:
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		await process_frame
	print(
		"DUMP_WEST_REAR d1=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		" d2=", main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" lead=", lead.grid_cell(),
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" queue=", int(main.follow_west_queue_hits()) if main.has_method("follow_west_queue_hits") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1,
		" cheb=", int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else -1,
		" span=", int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else -1,
		" zoom=", snapped(float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0, 0.01),
		" obs_scale=", snapped(float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0, 0.01),
		" obs_r=", snapped(float(main.follow_obs_visual_radius()) if main.has_method("follow_obs_visual_radius") else 0.0, 0.1),
		" cluster_scale=", snapped(float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0, 0.01),
		" cone_fade=", snapped(float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0, 0.01),
		" obs_off=", snapped(float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0, 0.1),
		" obs_ring_spread=", snapped(float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0, 0.1)
	)
	_dump_feel(main, "west_rear")
	await _save("08f_west_rear")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()


func _walk_facing_turn(main) -> void:
	if main.operators.size() < 3 or main.grid == null:
		return
	var lead = main.operators[0]
	var a = main.operators[1]
	var b = main.operators[2]
	if main.c2 and not main.c2.sentries.is_empty():
		var i := 0
		for s in main.c2.sentries:
			if s == null:
				continue
			s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
			s.facing_deg = 0.0
			i += 1
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(lead_c))):
		lead_c = Vector2i(14, 13)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._select_op(0)
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if main.has_method("simulate_follow_badge"):
		if not bool(a.follow_lead):
			main.simulate_follow_badge(1)
		if not bool(b.follow_lead):
			main.simulate_follow_badge(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow()
	var frames := 0
	while frames < 40:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 8:
			break
	var east_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var east_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(20.0)
	else:
		lead.facing_deg = 20.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._follow_blend_hits = 0
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	await process_frame
	var nudge_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var nudge_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	print(
		"DUMP_FACE_BLEND east=", east_d1, east_d2,
		" hop=", nudge_d1, nudge_d2,
		" blend=", int(main.follow_dest_blend_hits()) if main.has_method("follow_dest_blend_hits") else -1,
		" blend_on=", int(main.follow_dest_blend_active()) if main.has_method("follow_dest_blend_active") else -1,
		" frac=", snapped(float(main.follow_dest_blend_frac(int(a.op_id))) if main.has_method("follow_dest_blend_frac") else -1.0, 0.01),
		" w1=", main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else Vector2.ZERO,
		" slot=", main.follow_slot_world_of(int(a.op_id)) if main.has_method("follow_slot_world_of") else Vector2.ZERO,
		" path_end=", a.move_path[a.move_path.size() - 1] if a.is_moving() and a.move_path.size() > 1 else Vector2.ZERO
	)
	_dump_feel(main, "face_blend")
	await _save("08i_face_blend")
	frames = 0
	while frames < 40:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow(0.05)
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 8:
			break
	print(
		"DUMP_FACE_NUDGE east=", east_d1, east_d2,
		" nudge=", nudge_d1, nudge_d2,
		" lead=", lead.grid_cell(),
		" face=", lead.facing_deg,
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1,
		" blend=", int(main.follow_dest_blend_hits()) if main.has_method("follow_dest_blend_hits") else -1,
		" blend_on=", int(main.follow_dest_blend_active()) if main.has_method("follow_dest_blend_active") else -1,
		" w1=", main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else Vector2.ZERO
	)
	_dump_feel(main, "face_nudge")
	await _save("08h_face_nudge")
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	frames = 0
	while frames < 20:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow(0.05)
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 6:
			break
	a.stop_move()
	b.stop_move()
	main._follow_arc_hits = 0
	if lead.has_method("set_facing"):
		lead.set_facing(15.0)
	else:
		lead.facing_deg = 15.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	await process_frame
	print(
		"DUMP_FACE_RING east=", east_d1, east_d2,
		" hop=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" arc=", int(main.follow_dest_arc_hits()) if main.has_method("follow_dest_arc_hits") else -1,
		" arc_on=", int(main.follow_dest_arc_active()) if main.has_method("follow_dest_arc_active") else -1,
		" bow=", snapped(float(main.follow_dest_arc_bow(int(a.op_id))) if main.has_method("follow_dest_arc_bow") else -1.0, 0.1),
		" w1=", main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else Vector2.ZERO,
		" blocked=", int(main.follow_arc_blocked_hits()) if main.has_method("follow_arc_blocked_hits") else -1,
		" body_arc=", int(main.follow_body_arc_hits()) if main.has_method("follow_body_arc_hits") else -1,
		" path_n=", a.move_path.size() if a.is_moving() else 0
	)
	_dump_feel(main, "face_ring")
	await _save("08k_face_ring")
	frames = 0
	while frames < 24:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow(0.05)
		await process_frame
		frames += 1
	var settle_ring: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else Vector2.ZERO
	var settle_dest: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var settle_center: Vector2 = main.grid.cell_to_world_center(settle_dest) if settle_dest.x >= 0 else Vector2.ZERO
	print(
		"DUMP_FACE_SETTLE body=", a.global_position,
		" ring=", settle_ring,
		" center=", settle_center,
		" hold=", int(main.follow_ring_hold_active()) if main.has_method("follow_ring_hold_active") else -1,
		" d_ring=", snapped(a.global_position.distance_to(settle_ring), 0.1),
		" d_center=", snapped(a.global_position.distance_to(settle_center), 0.1)
	)
	_dump_feel(main, "face_settle")
	await _save("08l_face_settle")
	_dump_cluster_arc(main)
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(90.0)
	else:
		lead.facing_deg = 90.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._follow_arc_hits = 0
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	if main.has_method("_tick_squad_follow"):
		main._tick_squad_follow(0.05)
	await process_frame
	print(
		"DUMP_FACE_ARC east=", east_d1, east_d2,
		" hop=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" arc=", int(main.follow_dest_arc_hits()) if main.has_method("follow_dest_arc_hits") else -1,
		" arc_on=", int(main.follow_dest_arc_active()) if main.has_method("follow_dest_arc_active") else -1,
		" bow=", snapped(float(main.follow_dest_arc_bow(int(a.op_id))) if main.has_method("follow_dest_arc_bow") else -1.0, 0.1),
		" frac=", snapped(float(main.follow_dest_blend_frac(int(a.op_id))) if main.has_method("follow_dest_blend_frac") else -1.0, 0.01),
		" w1=", main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else Vector2.ZERO,
		" path_n=", a.move_path.size() if a.is_moving() else 0
	)
	_dump_feel(main, "face_arc")
	await _save("08j_face_arc")
	frames = 0
	while frames < 50:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow()
		await process_frame
		frames += 1
		if not a.is_moving() and not b.is_moving() and frames > 8:
			break
	print(
		"DUMP_FACE_TURN east=", east_d1, east_d2,
		" nudge=", nudge_d1, nudge_d2,
		" south=", main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
		main._follow_dest.get(int(b.op_id), Vector2i(-1, -1)),
		" lead=", lead.grid_cell(),
		" face=", lead.facing_deg,
		" rear=", int(main.follow_rear_ok_count()) if main.has_method("follow_rear_ok_count") else -1,
		" side=", int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else -1,
		" arc=", int(main.follow_dest_arc_hits()) if main.has_method("follow_dest_arc_hits") else -1
	)
	_dump_feel(main, "face_turn")
	await _save("08g_face_turn")
	if bool(a.follow_lead):
		main.toggle_follow(1)
	if bool(b.follow_lead):
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()


func _walk_badge_probes(main) -> void:
	if main.operators.size() < 2 or main.c2 == null or main.c2.portraits == null:
		return
	var strip = main.c2.portraits
	main._select_op(0)
	if bool(main.operators[1].follow_lead):
		main.toggle_follow(1)
	main._update_hud()
	await _settle(4)
	if not strip.has_method("portrait_probe_points"):
		print("DUMP_BADGE_PROBES no_api")
		return
	var probes: Dictionary = strip.portrait_probe_points(1)
	var bits: PackedStringArray = PackedStringArray()
	for key in probes.keys():
		var pt: Vector2 = probes[key]
		var ht: Dictionary = strip.hit_test_at(pt) if strip.has_method("hit_test_at") else {}
		bits.append("%s:%s" % [str(key), str(ht.get("kind", ""))])
	print(
		"DUMP_BADGE_PROBES ", " ".join(bits),
		" hit=", strip.follow_hit_rect(1),
		" body=", strip.portrait_body_rect(1),
		" gun=", strip.portrait_gun_rect(1) if strip.has_method("portrait_gun_rect") else Rect2(),
		" num=", strip.portrait_num_rect(1) if strip.has_method("portrait_num_rect") else Rect2(),
		" card=", strip.card_global_rect(1)
	)
	await _save("09b_badge_probes")


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
		" follow_dest_spread=", snapped(float(f.get("follow_dest_spread", -1.0)), 0.1),
		" facing_tags=", f.get("facing_tags", -1),
		" follow_cone_hits=", f.get("follow_cone_hits", -1),
		" follow_rim_hits=", f.get("follow_rim_hits", -1),
		" follow_max_detour=", f.get("follow_max_detour", -1),
		" follow_flips=", f.get("follow_flips", -1),
		" follow_settle_drops=", f.get("follow_settle_drops", -1),
		" follow_side_rear=", f.get("follow_side_rear", -1),
		" follow_rear_ok=", f.get("follow_rear_ok", -1),
		" follow_west_queue=", f.get("follow_west_queue", -1),
		" follow_cheb=", f.get("follow_cheb", -1),
		" follow_blend=", f.get("follow_blend", -1),
		" follow_blend_on=", f.get("follow_blend_on", -1),
		" follow_arc=", f.get("follow_arc", -1),
		" follow_arc_on=", f.get("follow_arc_on", -1),
		" obs_scale=", snapped(float(f.get("obs_scale", 1.0)), 0.01),
		" obs_r=", snapped(float(f.get("obs_r", 0.0)), 0.1),
		" obs_off=", snapped(float(f.get("obs_off", 0.0)), 0.1),
		" obs_ring_spread=", snapped(float(f.get("obs_ring_spread", 0.0)), 0.1),
		" cam_squad_zoom=", snapped(float(f.get("cam_squad_zoom", 1.0)), 0.01),
		" cluster_scale=", snapped(float(f.get("cluster_scale", 1.0)), 0.01),
		" cone_fade=", snapped(float(f.get("cone_fade", 1.0)), 0.01),
		" dest_world_spread=", snapped(float(f.get("dest_world_spread", -1.0)), 0.1),
		" arc_blocked=", f.get("arc_blocked", -1),
		" body_arc=", f.get("body_arc", -1),
		" body_spread=", snapped(float(f.get("body_spread", -1.0)), 0.1),
		" body_inset=", snapped(float(f.get("body_inset", -1.0)), 0.1),
		" ring_hold=", f.get("ring_hold", -1),
		" setup_cmds=", " ".join(f.get("setup_cmds", PackedStringArray())),
		" compact_font=", f.get("compact_font", -1),
		" compact_need=", snapped(float(f.get("compact_need", -1.0)), 0.1),
		" compact_stacked=", f.get("compact_stacked", -1)
	)


func _dump_compact(main, tag: String) -> void:
	var th = main.touch_hud
	if th == null or not th.has_method("setup_bar_metrics"):
		print("DUMP_COMPACT_BAR tag=", tag, " none")
		return
	var m: Dictionary = th.setup_bar_metrics()
	print(
		"DUMP_COMPACT_BAR tag=", tag,
		" font=", int(m.get("font", -1)),
		" sep=", int(m.get("sep", -1)),
		" stacked=", 1 if bool(m.get("stacked", false)) else 0,
		" need=", snapped(float(m.get("need_w", -1.0)), 0.1),
		" avail=", snapped(float(m.get("avail_w", -1.0)), 0.1),
		" fits=", 1 if bool(m.get("fits", false)) else 0,
		" twist=", snapped(float(m.get("twist_min", -1.0)), 0.1),
		" cmds=", " ".join(th.setup_visible_cmds() if th.has_method("setup_visible_cmds") else PackedStringArray())
	)
	if th.has_method("simulate_narrow_layout"):
		th.simulate_narrow_layout(320.0)
		var n: Dictionary = th.setup_bar_metrics()
		print(
			"DUMP_COMPACT_NARROW font=", int(n.get("font", -1)),
			" need=", snapped(float(n.get("need_w", -1.0)), 0.1),
			" avail=", snapped(float(n.get("avail_w", -1.0)), 0.1),
			" fits=", 1 if bool(n.get("fits", false)) else 0,
			" stacked=", 1 if bool(n.get("stacked", false)) else 0
		)
		if th.has_method("_apply_safe_area"):
			th._apply_safe_area()


func _dump_cluster_arc(main) -> void:
	if main.grid == null or not main.has_method("follow_arc_sample_points"):
		print("DUMP_ARC_CLUSTER none")
		return
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var raw: PackedVector2Array = PackedVector2Array()
	if main.has_method("follow_arc_sample_raw"):
		raw = main.follow_arc_sample_raw(from_w, to_w, pivot, 15)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	var blocked := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or (main.has_method("_cell_is_operable") and bool(main._cell_is_operable(c))):
			blocked += 1
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	var raw_bow := float(main.follow_arc_chord_bow(raw, from_w, to_w)) if raw.size() >= 3 and main.has_method("follow_arc_chord_bow") else 0.0
	var axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else -1
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else -1.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else -1.0
	var y14 := int(main.follow_arc_y14_east(pts, from_w, to_w)) if main.has_method("follow_arc_y14_east") else -1
	var y14_mid := int(main.follow_arc_y14_mid(pts, from_w, to_w)) if main.has_method("follow_arc_y14_mid") else -1
	var cells: Array[Vector2i] = []
	for p in pts:
		cells.append(main.grid.world_to_cell(p))
	print(
		"DUMP_ARC_CLUSTER n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" raw_bow=", snapped(raw_bow, 0.1),
		" blocked=", blocked,
		" axis_run=", axis,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" y14=", y14,
		" y14_mid=", y14_mid,
		" cells=", cells
	)


func _dump_twist_swipe(main) -> void:
	var th = main.touch_hud
	if th == null or main.operators.is_empty():
		print("DUMP_TWIST_SWIPE none")
		return
	main._select_op(0)
	var op = main.selected
	var f0: float = float(op.facing_deg)
	var n_ccw := 0
	var n_cw := 0
	if th.has_method("simulate_swipe_twist"):
		n_ccw = int(th.simulate_swipe_twist(-56.0))
	var f1: float = float(op.facing_deg)
	if th.has_method("simulate_swipe_twist"):
		n_cw = int(th.simulate_swipe_twist(56.0))
	var f2: float = float(op.facing_deg)
	print(
		"DUMP_TWIST_SWIPE f0=", snapped(f0, 0.1),
		" ccw=", n_ccw, snapped(f1, 0.1),
		" cw=", n_cw, snapped(f2, 0.1)
	)
	if op.has_method("set_facing"):
		op.set_facing(f0)
	else:
		op.facing_deg = f0
		if op.has_method("_rebuild_cone"):
			op._rebuild_cone()


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
	var setup_cmds := ""
	if main.touch_hud and main.touch_hud.has_method("setup_visible_cmds"):
		setup_cmds = " ".join(main.touch_hud.setup_visible_cmds())
	print(
		"DUMP_CHROME tag=", tag,
		" phase=", (main.phase_id() if main.has_method("phase_id") else main.phase),
		" setup_btns=", n,
		" setup_cmds=", setup_cmds,
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
