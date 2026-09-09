extends SceneTree

## Vertical-slice smoke: yard escape→restore→win, warehouse+pump reference wins, then railcut.
## Isolates user:// save data so player progress cannot mask failures.
## Bypasses title via change_scene_to_file(main.tscn).

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_wipe_save()
	if not await _assert_launch_bar():
		return
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("Failed to load main scene: %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	var main = current_scene
	for i in 10:
		await process_frame

	if main.level == null or main.level.level_id != "yard":
		push_error("SMOKE_BAD_LEVEL start=%s" % (main.level.level_id if main.level else "null"))
		quit(10)
		return
	if not _assert_geometry(main, "yard_start"):
		return
	if not _assert_sim_clock():
		return
	if not _assert_roles_and_cover(main):
		return
	if not _assert_los_cone(main):
		return
	if not _assert_sfx(main):
		return
	if not _assert_engage_helpers(main):
		return
	if not _assert_tripwire_tooling(main):
		return
	if not _assert_touch_parity(main):
		return
	if not _assert_lifecycle(main):
		return
	if not _assert_perf_tier(main):
		return
	print("LEVEL=", main.level.level_id)

	# Life 1: only one cover — expect flank escape
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(90.0)
	main._on_alarm_pressed()
	print("LIFE1 deployed=", main._deployed_count())

	var frames := 0
	var saw_fail := false
	while frames < 60 * 180:
		await process_frame
		frames += 1
		if frames % 300 == 0:
			print(
				"t=", frames,
				" phase=", main.phase,
				" loop=", main.loop_index,
				" reason=", main.fail_reason,
				" level=", main.level.level_id,
				" tick=", main.sim.tick
			)
		if main.phase == main.Phase.FAILED and not saw_fail:
			saw_fail = true
			if main.fail_reason != "escape":
				push_error("SMOKE_BAD_REASON expected=escape got=%s" % main.fail_reason)
				quit(3)
				return
			if main.intel_paths.is_empty():
				push_error("SMOKE_NO_INTEL")
				quit(4)
				return
			print(
				"SMOKE_FAIL_ESCAPE reason=", main.fail_reason,
				" intel=", main.intel_paths.size(),
				" events=", main.battle_log.events.size(),
				" tick=", main.sim.tick
			)
			if not main.map_draw.escape_flash:
				push_error("SMOKE_NO_ESCAPE_FLASH")
				quit(27)
				return
			if not main.focus_latest_of_type("escape"):
				push_error("SMOKE_FOCUS_ESCAPE_FAIL")
				quit(28)
				return
			if main.focus_ring == null or not is_instance_valid(main.focus_ring):
				push_error("SMOKE_NO_FOCUS_RING")
				quit(28)
				return
			await process_frame
			if main.result_panel_covers_escape():
				push_error("SMOKE_RESULT_COVERS_ESCAPE")
				quit(39)
				return
			print("SMOKE_OK_ESCAPE_PANEL_CLEAR")
			var fp_1x: String = main.battle_log.fingerprint()
			var tick_1x: int = main.sim.tick
			print("SMOKE_1X_FP tick=", tick_1x, " fp=", fp_1x)
			main._on_continue_pressed()
			await process_frame
			if main._deployed_count() < 1:
				push_error("SMOKE_PLAN_NOT_RESTORED")
				quit(5)
				return
			print("LIFE2_RESTORED deployed=", main._deployed_count())
			if str(main.plan_restore_hint).find("已恢复上轮计划") < 0:
				push_error("SMOKE_NO_PLAN_RESTORE_HINT got=%s" % main.plan_restore_hint)
				quit(35)
				return
			print("SMOKE_OK_PLAN_RESTORE ", main.plan_restore_hint)
			# Same plan at 2× must match terminal tick + event fingerprint.
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var speed_ok: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 180)
			if not speed_ok or main.fail_reason != "escape":
				push_error(
					"SMOKE_2X_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(29)
				return
			var fp_2x: String = main.battle_log.fingerprint()
			if main.sim.tick != tick_1x or fp_2x != fp_1x:
				push_error(
					"SMOKE_SPEED_MISMATCH 1x_tick=%s 2x_tick=%s\n1x=%s\n2x=%s"
					% [tick_1x, main.sim.tick, fp_1x, fp_2x]
				)
				quit(30)
				return
			print("SMOKE_OK_SPEED_CONSISTENT tick=", tick_1x)
			main._on_continue_pressed()
			await process_frame
			main._on_clear_pressed()
			await process_frame
			_deploy_ref(main, [1, 2, 5], [90.0, 180.0, 180.0])
			if not main.operators[2].observation_ring_visible():
				push_error("SMOKE_SCOUT_OBS_MISSING_SETUP")
				quit(37)
				return
			main._on_alarm_pressed()
			if main.operators[2].observation_ring_visible():
				push_error("SMOKE_SCOUT_OBS_DURING_WATCH")
				quit(37)
				return
			print("LIFE3 deployed=", main._deployed_count())
		if main.phase == main.Phase.WON and main.level.level_id == "yard":
			print(
				"SMOKE_OK yard won loop=", main.loop_index,
				" tick=", main.sim.tick,
				" events=", main.battle_log.events.size()
			)
			if not _assert_fire_before_terminal(main):
				return
			if main.title_return_button == null or not main.title_return_button.visible:
				push_error("SMOKE_NO_DEBRIEF_TITLE_BTN")
				quit(44)
				return
			if str(main.continue_button.text).find("下一关") < 0:
				push_error("SMOKE_DEBRIEF_CONTINUE %s" % main.continue_button.text)
				quit(44)
				return
			if str(main.result_label.text).find("关键事件") < 0:
				push_error("SMOKE_DEBRIEF_EVENTS")
				quit(44)
				return
			if str(main.result_label.text).find("终局摘要") < 0:
				push_error("SMOKE_DEBRIEF_SUMMARY")
				quit(44)
				return
			var gs_win = root.get_node_or_null("GameSettings")
			if gs_win == null or not gs_win.is_level_cleared("yard") or not gs_win.is_level_unlocked("warehouse"):
				push_error("SMOKE_WIN_UNLOCK")
				quit(44)
				return
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "warehouse":
				push_error("SMOKE_BAD_ADVANCE expected=warehouse got=%s" % main.level.level_id)
				quit(11)
				return
			if not _assert_save_level("warehouse"):
				return
			if not _assert_geometry(main, "warehouse"):
				return
			print("SMOKE_LEVEL2_LOADED warehouse covers=", main.cover_slots.size())
			if main.barrels.size() != 1:
				push_error("SMOKE_WAREHOUSE_NO_BARREL n=%s" % main.barrels.size())
				quit(31)
				return
			if main.level.barrel_cell != Vector2i(32, 10):
				push_error("SMOKE_BARREL_CELL %s" % str(main.level.barrel_cell))
				quit(31)
				return
			if main.grid.is_blocked(main.level.barrel_cell.x, main.level.barrel_cell.y):
				push_error("SMOKE_BARREL_BLOCKED")
				quit(31)
				return

			_deploy_ref(main, [1, 3, 5], [180.0, 0.0, 180.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var wh: bool = await _wait_phase(main, main.Phase.WON, 60 * 200)
			if not wh:
				push_error(
					"SMOKE_WAREHOUSE_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(12)
				return
			print("SMOKE_OK warehouse won tick=", main.sim.tick)
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "pump":
				push_error("SMOKE_BAD_ADVANCE expected=pump got=%s" % main.level.level_id)
				quit(13)
				return
			if not _assert_save_level("pump"):
				return
			if not _assert_geometry(main, "pump"):
				return

			if main.door_locked:
				main._on_door_pressed()
			_deploy_ref(main, [1, 4, 5], [90.0, 0.0, 180.0])
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var po: bool = await _wait_phase(main, main.Phase.WON, 60 * 200)
			if not po:
				push_error(
					"SMOKE_PUMP_OPEN_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(14)
				return
			print("SMOKE_OK pump_open won tick=", main.sim.tick)

			main.level_index = 2
			main._load_level("pump", false, false)
			await process_frame
			if not main.door_locked:
				main._on_door_pressed()
			if not main.door_locked:
				push_error("SMOKE_DOOR_NOT_LOCKED")
				quit(15)
				return
			if not _assert_geometry(main, "pump_locked"):
				return
			if main.level.decision_cell != Vector2i(13, 5):
				push_error("SMOKE_DECISION_CELL %s" % str(main.level.decision_cell))
				quit(38)
				return
			if main._active_routes().size() != 2:
				push_error("SMOKE_LOCKED_ACTIVE_ROUTES n=%s" % main._active_routes().size())
				quit(38)
				return
			_deploy_ref(main, [1, 4, 5], [90.0, 0.0, 180.0])
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var flank_enemy = null
			var guard := 0
			while flank_enemy == null and guard < 300:
				await process_frame
				guard += 1
				for e in main.enemies:
					if e.label_id == 2:
						flank_enemy = e
						break
			if flank_enemy == null:
				push_error("SMOKE_NO_FLANK_SPAWN")
				quit(16)
				return
			var alt_mark: Vector2 = main.grid.cell_to_world_center(Vector2i(11, 8))
			var spawn_has_alt := false
			for p in flank_enemy.route:
				if p.distance_to(alt_mark) < 1.0:
					spawn_has_alt = true
					break
			if spawn_has_alt:
				push_error("SMOKE_ALT_AT_SPAWN route_len=%s" % flank_enemy.route.size())
				quit(16)
				return
			print("SMOKE_OK_SPAWN_PRIMARY_ROUTE")
			var used_alt := false
			var saw_choice := false
			var wait_branch := 0
			while wait_branch < 60 * 200:
				await process_frame
				wait_branch += 1
				if flank_enemy.did_branch:
					for p in flank_enemy.route:
						if p.distance_to(alt_mark) < 1.0:
							used_alt = true
							break
				for ev in main.battle_log.events:
					if str(ev["type"]) == "route_choice" and int(ev["actor_id"]) == 2:
						saw_choice = true
				if used_alt and saw_choice:
					break
				if main.phase == main.Phase.FAILED or main.phase == main.Phase.WON:
					break
			if not used_alt:
				push_error(
					"SMOKE_LOCKED_ROUTE_NOT_USED door=%s branched=%s route_len=%s"
					% [main.door_locked, flank_enemy.did_branch, flank_enemy.route.size()]
				)
				quit(16)
				return
			if not saw_choice:
				push_error("SMOKE_NO_ROUTE_CHOICE")
				quit(16)
				return
			print("SMOKE_OK_BRANCH_AFTER_DECISION")
			var pl: bool = await _wait_phase(main, main.Phase.WON, 60 * 200)
			if not pl:
				push_error(
					"SMOKE_PUMP_LOCKED_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(17)
				return
			print("SMOKE_OK pump_locked won tick=", main.sim.tick)
			if not _assert_level_order(main, 5):
				return
			var gs_pump = root.get_node_or_null("GameSettings")
			if gs_pump == null or not gs_pump.is_level_cleared("pump") or not gs_pump.is_level_unlocked("railcut"):
				push_error(
					"SMOKE_RAILCUT_UNLOCK cleared_pump=%s unlocked=%s"
					% [
						gs_pump.is_level_cleared("pump") if gs_pump else false,
						gs_pump.is_level_unlocked("railcut") if gs_pump else false,
					]
				)
				quit(45)
				return
			var entries_after: Array = gs_pump.mission_entries()
			if entries_after.size() != 5 or not bool(entries_after[3]["unlocked"]) or str(entries_after[3]["id"]) != "railcut":
				push_error("SMOKE_RAILCUT_MISSION_ENTRY %s" % str(entries_after.size()))
				quit(45)
				return
			print("SMOKE_OK_RAILCUT_UNLOCK")
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "railcut":
				push_error("SMOKE_BAD_ADVANCE expected=railcut got=%s" % main.level.level_id)
				quit(45)
				return
			if not _assert_save_level("railcut"):
				return
			if not _assert_geometry(main, "railcut"):
				return
			if not _assert_railcut_contract(main):
				return
			# Reference win (documented): rifle 西廊脊 slot1 face 270 (north up west spine),
			# MG 东廊 slot4 face 270 (north up delayed east corridor), scout 南闸 slot5 face 180 (west).
			# Core walls block cross-corridor LOS; ignoring the delayed east pair escapes (probe).
			_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var rc: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not rc:
				push_error(
					"SMOKE_RAILCUT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(45)
				return
			print("SMOKE_OK railcut won tick=", main.sim.tick)
			var gs_rc = root.get_node_or_null("GameSettings")
			if gs_rc == null or not gs_rc.is_level_cleared("railcut") or not gs_rc.is_level_unlocked("depot"):
				push_error(
					"SMOKE_DEPOT_UNLOCK cleared_railcut=%s unlocked=%s"
					% [
						gs_rc.is_level_cleared("railcut") if gs_rc else false,
						gs_rc.is_level_unlocked("depot") if gs_rc else false,
					]
				)
				quit(48)
				return
			var depot_entries: Array = gs_rc.mission_entries()
			if depot_entries.size() != 5 or not bool(depot_entries[4]["unlocked"]) or str(depot_entries[4]["id"]) != "depot":
				push_error("SMOKE_DEPOT_MISSION_ENTRY %s" % str(depot_entries.size()))
				quit(48)
				return
			print("SMOKE_OK_DEPOT_UNLOCK")
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "depot":
				push_error("SMOKE_BAD_ADVANCE expected=depot got=%s" % main.level.level_id)
				quit(48)
				return
			if not _assert_save_level("depot"):
				return
			if not _assert_geometry(main, "depot"):
				return
			if not _assert_depot_contract(main):
				return
			# Rifle 主路脊 slot1 face 270, MG 东廊 slot4 face 270, scout 南闸 slot5 face 180.
			# Tripwire on the west alley (7,11) so the delayed sneak does not leak.
			_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
			main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
			if main.tripwires.size() != 1:
				push_error("SMOKE_DEPOT_TRIP n=%s" % main.tripwires.size())
				quit(48)
				return
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var dp: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not dp:
				push_error(
					"SMOKE_DEPOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(48)
				return
			print("SMOKE_OK depot won tick=", main.sim.tick)
			print("SMOKE_SLICE_COMPLETE")
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s reason=%s" % [main.phase, main.fail_reason])
	quit(2)


func _deploy_ref(main, slots: Array, facings: Array) -> void:
	for i in slots.size():
		main._select_op(i)
		main._deploy_selected_to(main.cover_slots[int(slots[i])])
		main.selected.set_facing(float(facings[i]))


func _wait_phase(main, want, max_frames: int) -> bool:
	var frames := 0
	while frames < max_frames:
		await process_frame
		frames += 1
		if main.phase == want:
			return true
		if main.phase == main.Phase.FAILED:
			return false
	return false


func _drive_ticks(main, n: int) -> void:
	var start: int = main.sim.tick
	var guard := 0
	while main.sim.tick < start + n and guard < 180:
		await process_frame
		guard += 1


func _assert_geometry(main, tag: String) -> bool:
	var blocked_route := ""
	var alt: Array = main.level.alternate_route_cells
	if main.door_locked and main.level.door_blocks_route != "":
		blocked_route = main.level.door_blocks_route
	var errs: PackedStringArray = main.grid.validate_level_geometry(
		main.level.cover_defs, main.level.route_cells, alt, blocked_route, main.level.barrel_cell
	)
	if not errs.is_empty():
		for e in errs:
			push_error("SMOKE_GEO_%s %s" % [tag, e])
		quit(20)
		return false
	return true


func _assert_level_order(main, n: int) -> bool:
	var gs = root.get_node_or_null("GameSettings")
	if gs == null or gs.LEVEL_ORDER.size() != n or main.LEVEL_ORDER.size() != n:
		push_error(
			"SMOKE_LEVEL_ORDER_LEN gs=%s main=%s want=%s"
			% [gs.LEVEL_ORDER.size() if gs else -1, main.LEVEL_ORDER.size(), n]
		)
		quit(45)
		return false
	var last_id := str(gs.LEVEL_ORDER[n - 1])
	if last_id != str(main.LEVEL_ORDER[n - 1]):
		push_error("SMOKE_LEVEL_ORDER_LAST gs=%s main=%s" % [gs.LEVEL_ORDER, main.LEVEL_ORDER])
		quit(45)
		return false
	var cat: Array = LevelDef.catalog()
	if cat.size() != n or str(cat[n - 1].level_id) != last_id:
		push_error("SMOKE_CATALOG_LEN %s last=%s" % [cat.size(), last_id])
		quit(45)
		return false
	return true


func _assert_railcut_contract(main) -> bool:
	if main.cover_slots.size() != 6:
		push_error("SMOKE_RAILCUT_COVERS n=%s" % main.cover_slots.size())
		quit(45)
		return false
	if main.level.door_cell.x >= 0:
		push_error("SMOKE_RAILCUT_HAS_DOOR %s" % str(main.level.door_cell))
		quit(45)
		return false
	if main.door_button != null and main.door_button.visible:
		push_error("SMOKE_RAILCUT_DOOR_BUTTON")
		quit(45)
		return false
	if not main.level.has_ammo_pack:
		push_error("SMOKE_RAILCUT_NO_PACK")
		quit(45)
		return false
	if main.barrels.size() != 0 or main.level.barrel_cell.x >= 0:
		push_error("SMOKE_RAILCUT_BARREL")
		quit(45)
		return false
	if not main.level.route_cells.has("main") or not main.level.route_cells.has("flank"):
		push_error("SMOKE_RAILCUT_ROUTES")
		quit(45)
		return false
	if main._active_routes().size() != 2:
		push_error("SMOKE_RAILCUT_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(45)
		return false
	if str(main.level.title).find("信号楼") < 0:
		push_error("SMOKE_RAILCUT_TITLE %s" % main.level.title)
		quit(45)
		return false
	var pages: Array = TutorialOverlay.pages_for("railcut")
	if pages.size() != 2:
		push_error("SMOKE_RAILCUT_TUTORIAL n=%s" % pages.size())
		quit(45)
		return false
	var west: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 12))
	var east: Vector2 = main.grid.cell_to_world_center(Vector2i(32, 11))
	if not main._near_any_route_segment(west, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_RAILCUT_TRIP_WEST")
		quit(45)
		return false
	if not main._near_any_route_segment(east, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_RAILCUT_TRIP_EAST")
		quit(45)
		return false
	if not main.grid.is_blocked(20, 10):
		push_error("SMOKE_RAILCUT_CORE_OPEN")
		quit(45)
		return false
	if main.grid.is_blocked(13, 12) or main.grid.is_blocked(32, 11):
		push_error("SMOKE_RAILCUT_CORRIDOR_BLOCKED")
		quit(45)
		return false
	var max_main := 0.0
	var min_flank := 999.0
	var flank_n := 0
	var main_n := 0
	for spec in main.level.spawn_schedule:
		var delay := float(spec["delay"])
		if str(spec["route"]) == "main":
			main_n += 1
			max_main = maxf(max_main, delay)
		elif str(spec["route"]) == "flank":
			flank_n += 1
			min_flank = minf(min_flank, delay)
	if main_n < 1 or flank_n < 1:
		push_error("SMOKE_RAILCUT_SPAWN_SPLIT main=%s flank=%s" % [main_n, flank_n])
		quit(45)
		return false
	if min_flank < 3.0 or min_flank <= max_main + 1.5:
		push_error("SMOKE_RAILCUT_FLANK_NOT_DELAYED main_max=%s flank_min=%s" % [max_main, min_flank])
		quit(45)
		return false
	print(
		"SMOKE_OK_RAILCUT_CONTRACT covers=6 no_door delayed_flank=", min_flank,
		" trip_west/east"
	)
	return true


func _assert_depot_contract(main) -> bool:
	if main.cover_slots.size() != 6:
		push_error("SMOKE_DEPOT_COVERS n=%s" % main.cover_slots.size())
		quit(48)
		return false
	if main.level.door_cell.x >= 0:
		push_error("SMOKE_DEPOT_HAS_DOOR %s" % str(main.level.door_cell))
		quit(48)
		return false
	if not main.level.has_ammo_pack:
		push_error("SMOKE_DEPOT_NO_PACK")
		quit(48)
		return false
	if main.barrels.size() != 0 or main.level.barrel_cell.x >= 0:
		push_error("SMOKE_DEPOT_BARREL")
		quit(48)
		return false
	if not main.level.route_cells.has("main") or not main.level.route_cells.has("flank") or not main.level.route_cells.has("sneak"):
		push_error("SMOKE_DEPOT_ROUTES")
		quit(48)
		return false
	if main._active_routes().size() != 3:
		push_error("SMOKE_DEPOT_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(48)
		return false
	if str(main.level.title).find("油库") < 0:
		push_error("SMOKE_DEPOT_TITLE %s" % main.level.title)
		quit(48)
		return false
	var pages: Array = TutorialOverlay.pages_for("depot")
	if pages.size() != 2:
		push_error("SMOKE_DEPOT_TUTORIAL n=%s" % pages.size())
		quit(48)
		return false
	var sneak: Vector2 = main.grid.cell_to_world_center(Vector2i(7, 11))
	if not main._near_any_route_segment(sneak, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_DEPOT_TRIP_SNEAK")
		quit(48)
		return false
	if not main.grid.is_blocked(20, 10):
		push_error("SMOKE_DEPOT_CORE_OPEN")
		quit(48)
		return false
	if main.grid.is_blocked(7, 11) or main.grid.is_blocked(13, 12) or main.grid.is_blocked(32, 11):
		push_error("SMOKE_DEPOT_LANE_BLOCKED")
		quit(48)
		return false
	var max_main := 0.0
	var min_sneak := 999.0
	var sneak_n := 0
	var main_n := 0
	var flank_n := 0
	for spec in main.level.spawn_schedule:
		var delay := float(spec["delay"])
		if str(spec["route"]) == "main":
			main_n += 1
			max_main = maxf(max_main, delay)
		elif str(spec["route"]) == "flank":
			flank_n += 1
		elif str(spec["route"]) == "sneak":
			sneak_n += 1
			min_sneak = minf(min_sneak, delay)
	if main_n < 1 or flank_n < 1 or sneak_n < 1:
		push_error("SMOKE_DEPOT_SPAWN_SPLIT main=%s flank=%s sneak=%s" % [main_n, flank_n, sneak_n])
		quit(48)
		return false
	if min_sneak < 1.6 or min_sneak <= max_main + 0.6:
		push_error("SMOKE_DEPOT_SNEAK_NOT_DELAYED main_max=%s sneak_min=%s" % [max_main, min_sneak])
		quit(48)
		return false
	print(
		"SMOKE_OK_DEPOT_CONTRACT covers=6 routes=3 delayed_sneak=", min_sneak,
		" trip_west_alley"
	)
	return true


func _assert_save_level(expected: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		push_error("SMOKE_SAVE_MISSING")
		quit(21)
		return false
	var id := str(cfg.get_value("progress", "level_id", ""))
	if id != expected:
		push_error("SMOKE_SAVE_BAD expected=%s got=%s" % [expected, id])
		quit(22)
		return false
	return true


func _assert_fire_before_terminal(main) -> bool:
	var events: Array = main.battle_log.events
	var term_i := -1
	for i in range(events.size() - 1, -1, -1):
		if str(events[i]["type"]) == "terminal":
			term_i = i
			break
	if term_i < 0:
		push_error("SMOKE_NO_TERMINAL")
		quit(23)
		return false
	var term_tick: int = int(events[term_i]["tick"])
	var saw_fire := false
	for i in term_i:
		var ev: Dictionary = events[i]
		if int(ev["tick"]) != term_tick:
			continue
		var typ := str(ev["type"])
		if typ == "fire":
			saw_fire = true
		if typ == "kill" and not saw_fire:
			# Same-tick kill without a preceding fire log (the P2 ordering bug).
			push_error("SMOKE_KILL_BEFORE_FIRE_SAME_TICK tick=%s" % term_tick)
			quit(25)
			return false
	if main.battle_log.terminal_reason == "win" and not saw_fire:
		# Winning terminal tick should include the confirming fire event.
		push_error("SMOKE_WIN_TERMINAL_WITHOUT_FIRE tick=%s" % term_tick)
		quit(24)
		return false
	return true


func _assert_sim_clock() -> bool:
	var a := SimClock.new()
	var b := SimClock.new()
	a.set_speed(1.0)
	b.set_speed(2.0)
	var sa := 0
	var sb := 0
	for i in 60:
		sa += a.steps_for_frame(1.0 / 60.0)
		sb += b.steps_for_frame(1.0 / 60.0)
	if sa != 60 or sb != 120:
		push_error("SMOKE_CLOCK_STEPS 1x=%s 2x=%s" % [sa, sb])
		quit(26)
		return false
	# Hitch must not drop leftover accum (1× vs 2× consistency).
	var c := SimClock.new()
	c.set_speed(2.0)
	var total := c.steps_for_frame(0.2)
	for i in 40:
		total += c.steps_for_frame(1.0 / 60.0)
	var real_t := 0.2 + 40.0 * (1.0 / 60.0)
	var expected := int(floor(real_t * 2.0 * 60.0 + 0.0001))
	if total != expected:
		push_error("SMOKE_CLOCK_HITCH got=%s expected=%s" % [total, expected])
		quit(26)
		return false
	print("SMOKE_OK_CLOCK 1x=60 2x=120 hitch=", total)
	return true


func _assert_roles_and_cover(main) -> bool:
	if main.operators.size() < 3:
		push_error("SMOKE_NO_ROLES")
		quit(32)
		return false
	var rifle: OperatorUnit = main.operators[0]
	var mg: OperatorUnit = main.operators[1]
	var scout: OperatorUnit = main.operators[2]
	if mg.half_angle_deg <= rifle.half_angle_deg:
		push_error("SMOKE_MG_CONE_NOT_WIDER")
		quit(32)
		return false
	if scout.range_px <= rifle.range_px:
		push_error("SMOKE_SCOUT_RANGE_NOT_LONGER")
		quit(32)
		return false
	if scout.half_angle_deg >= rifle.half_angle_deg:
		push_error("SMOKE_SCOUT_CONE_NOT_NARROWER")
		quit(32)
		return false
	if rifle.start_ammo == mg.start_ammo and rifle.shot_interval == mg.shot_interval:
		push_error("SMOKE_ROLES_IDENTICAL")
		quit(32)
		return false
	if absf(rifle.range_px - mg.range_px) < 1.0 or absf(rifle.range_px - scout.range_px) < 1.0:
		push_error(
			"SMOKE_RANGES_NOT_DISTINCT rifle=%s mg=%s scout=%s"
			% [rifle.range_px, mg.range_px, scout.range_px]
		)
		quit(32)
		return false
	main._select_op(2)
	main._deploy_selected_to(main.cover_slots[0], false)
	if not scout.observation_ring_visible():
		push_error("SMOKE_SCOUT_OBS_NOT_SHOWN")
		quit(37)
		return false
	if scout.cone != null and scout.obs_ring != null:
		# Ring is a full circle at range; cone is a filled fan — they must be distinct nodes.
		if scout.obs_ring == scout.cone:
			push_error("SMOKE_OBS_RING_IS_CONE")
			quit(37)
			return false
	main._on_clear_pressed()
	if scout.observation_ring_visible():
		push_error("SMOKE_SCOUT_OBS_AFTER_CLEAR")
		quit(37)
		return false
	if main.cover_slots.is_empty():
		push_error("SMOKE_NO_COVER")
		quit(32)
		return false
	var slot: CoverSlot = main.cover_slots[0]
	# Yard 西侧 protect 180° (west): attacks from west mitigated, east exposed.
	var west: Vector2 = slot.global_position + Vector2(-48, 0)
	var east: Vector2 = slot.global_position + Vector2(48, 0)
	if not slot.protects_from(west):
		push_error("SMOKE_PROTECT_ARC_WEST_MISS face=%s" % slot.protect_facing_deg)
		quit(33)
		return false
	if slot.protects_from(east):
		push_error("SMOKE_PROTECT_ARC_EAST_FALSE_COVER face=%s" % slot.protect_facing_deg)
		quit(33)
		return false
	if slot.protect_compass() != "西":
		push_error("SMOKE_PROTECT_COMPASS %s" % slot.protect_compass())
		quit(33)
		return false
	print(
		"SMOKE_OK_ROLES mg_cone=", mg.half_angle_deg,
		" scout_range=", scout.range_px,
		" protect=", slot.protect_compass()
	)
	if not _assert_operator_identity(main, rifle, mg, scout):
		return false
	return true


func _assert_operator_identity(main, rifle: OperatorUnit, mg: OperatorUnit, scout: OperatorUnit) -> bool:
	if rifle.display_name.strip_edges() == "" or rifle.display_name == "队员":
		push_error("SMOKE_OP_NO_DISPLAY_NAME %s" % rifle.display_name)
		quit(32)
		return false
	if rifle.display_name == mg.display_name or mg.display_name == scout.display_name:
		push_error(
			"SMOKE_OP_NAMES_COLLIDE rifle=%s mg=%s scout=%s"
			% [rifle.display_name, mg.display_name, scout.display_name]
		)
		quit(32)
		return false
	if rifle.role_glyph == null or not is_instance_valid(rifle.role_glyph):
		push_error("SMOKE_NO_ROLE_GLYPH")
		quit(32)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	if not rifle.visible:
		push_error("SMOKE_RIFLE_NOT_VISIBLE")
		quit(32)
		return false
	if not rifle.role_glyph.visible:
		push_error("SMOKE_ROLE_GLYPH_HIDDEN")
		quit(32)
		return false
	if rifle.body == null or rifle.body.polygon.size() < 5:
		push_error("SMOKE_RIFLE_BODY_TOO_SIMPLE n=%s" % (rifle.body.polygon.size() if rifle.body else -1))
		quit(32)
		return false
	if mg.body == null or mg.body.polygon.size() < 5:
		push_error("SMOKE_MG_BODY_TOO_SIMPLE")
		quit(32)
		return false
	if scout.body == null or scout.body.polygon.size() < 5:
		push_error("SMOKE_SCOUT_BODY_TOO_SIMPLE")
		quit(32)
		return false
	if rifle.body.polygon == mg.body.polygon or mg.body.polygon == scout.body.polygon:
		push_error("SMOKE_BODY_POLYS_IDENTICAL")
		quit(32)
		return false
	main._on_clear_pressed()
	print(
		"SMOKE_OK_IDENTITY rifle=%s mg=%s scout=%s glyph=1"
		% [rifle.display_name, mg.display_name, scout.display_name]
	)
	return true


func _assert_los_cone(main) -> bool:
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(180.0)  # west into yard wall
	var into_wall: float = main.selected._los_clip_distance(Vector2(-1, 0))
	main.selected.set_facing(0.0)
	var open_lane: float = main.selected._los_clip_distance(Vector2(1, 0))
	main._on_clear_pressed()
	if into_wall >= main.operators[0].range_px - 1.0:
		push_error("SMOKE_LOS_NOT_CLIPPED wall=%s range=%s" % [into_wall, main.operators[0].range_px])
		quit(34)
		return false
	if open_lane <= into_wall + 8.0:
		push_error("SMOKE_LOS_OPEN_NOT_LONGER wall=%s open=%s" % [into_wall, open_lane])
		quit(34)
		return false
	print("SMOKE_OK_LOS wall=", into_wall, " open=", open_lane)
	return true


func _assert_sfx(main) -> bool:
	if main.sfx == null:
		push_error("SMOKE_NO_SFX")
		quit(36)
		return false
	for cue in ["alarm", "fire", "return_fire", "empty", "loot", "op_death", "escape", "win"]:
		if not main.sfx.has_cue(cue):
			push_error("SMOKE_SFX_MISSING %s" % cue)
			quit(36)
			return false
	var was_muted: bool = bool(main.sfx_muted)
	if was_muted:
		main._toggle_mute()
	main._sfx("alarm")
	if str(main.sfx.last_cue) != "alarm":
		push_error("SMOKE_SFX_NO_PLAY cue=%s" % main.sfx.last_cue)
		quit(36)
		return false
	main._toggle_mute()
	if not main.sfx.muted:
		push_error("SMOKE_MUTE_FAIL")
		quit(36)
		return false
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null or not audio.has_music_bed():
		push_error("SMOKE_NO_MUSIC_BED")
		quit(43)
		return false
	if audio.music_player_playing():
		push_error("SMOKE_MUTE_LEAVES_MUSIC")
		quit(36)
		return false
	main._toggle_mute()
	if main.sfx.muted:
		push_error("SMOKE_UNMUTE_FAIL")
		quit(36)
		return false
	if was_muted:
		main._toggle_mute()
	print("SMOKE_OK_SFX cues=8 muted=", main.sfx.muted)
	return true


func _assert_engage_helpers(main) -> bool:
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	var op: OperatorUnit = main.selected
	op.set_facing(0.0)
	op.fire_permitted = true
	op.ammo = op.start_ammo
	var ahead: Vector2 = op.global_position + Vector2(80, 0)
	if not op.in_fire_geometry(ahead, main.grid):
		push_error("SMOKE_IN_FIRE_GEO_AHEAD")
		quit(40)
		return false
	if op.engage_block_reason(ahead, main.grid) != "":
		push_error("SMOKE_ENGAGE_REASON_CLEAR %s" % op.engage_block_reason(ahead, main.grid))
		quit(40)
		return false
	if not op.can_engage(ahead, main.grid):
		push_error("SMOKE_CAN_ENGAGE_AHEAD")
		quit(40)
		return false
	op.fire_permitted = false
	if op.engage_block_reason(ahead, main.grid) != "hold":
		push_error("SMOKE_ENGAGE_HOLD %s" % op.engage_block_reason(ahead, main.grid))
		quit(40)
		return false
	if op.can_engage(ahead, main.grid):
		push_error("SMOKE_CAN_ENGAGE_WHILE_HOLD")
		quit(40)
		return false
	if not op.in_fire_geometry(ahead, main.grid):
		push_error("SMOKE_HOLD_SHOULD_STILL_BE_GEO")
		quit(40)
		return false
	op.fire_permitted = true
	op.ammo = 0
	if op.engage_block_reason(ahead, main.grid) != "ammo":
		push_error("SMOKE_ENGAGE_AMMO %s" % op.engage_block_reason(ahead, main.grid))
		quit(40)
		return false
	op.ammo = op.start_ammo
	var behind: Vector2 = op.global_position + Vector2(-80, 0)
	if op.in_fire_geometry(behind, main.grid):
		push_error("SMOKE_IN_FIRE_GEO_BEHIND")
		quit(40)
		return false
	if op.engage_block_reason(behind, main.grid) != "cone":
		push_error("SMOKE_ENGAGE_CONE %s" % op.engage_block_reason(behind, main.grid))
		quit(40)
		return false
	var far: Vector2 = op.global_position + Vector2(op.range_px + 40.0, 0)
	if op.engage_block_reason(far, main.grid) != "range":
		push_error("SMOKE_ENGAGE_RANGE %s" % op.engage_block_reason(far, main.grid))
		quit(40)
		return false
	# Wall west of yard west-cover: facing into wall should be los.
	op.set_facing(180.0)
	var into_wall: Vector2 = op.global_position + Vector2(-48, 0)
	var wall_reason := op.engage_block_reason(into_wall, main.grid)
	if wall_reason != "los" and wall_reason != "range":
		# Close point may still be range if clipped; los is the intended deny.
		if not main.grid.has_los(op.global_position, into_wall) and wall_reason != "los":
			push_error("SMOKE_ENGAGE_LOS %s" % wall_reason)
			quit(40)
			return false
	op.set_facing(0.0)
	main._refresh_killzone_preview()
	if main.killzone_draw == null or main.killzone_draw.get_child_count() < 1:
		push_error("SMOKE_NO_KILLZONE")
		quit(40)
		return false
	if main._active_routes().size() != 2:
		push_error("SMOKE_YARD_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(40)
		return false
	var blog := BattleLog.new()
	var ne := {
		"tick": 60,
		"type": "no_engage",
		"actor_id": 1,
		"target_id": 3,
		"payload": {"reason": "los"},
	}
	var formatted: String = blog.format_event(ne)
	if formatted.find("无法交战") < 0 or formatted.find("视线") < 0:
		push_error("SMOKE_NO_ENGAGE_FORMAT %s" % formatted)
		quit(40)
		return false
	print("SMOKE_OK_ENGAGE_HELPERS killzone=", main.killzone_draw.get_child_count())
	main._on_clear_pressed()
	return true


func _assert_tripwire_tooling(main) -> bool:
	var tw := Tripwire.new()
	var empty = tw.sim_check([])
	tw.free()
	if empty != null:
		push_error("SMOKE_TRIP_EMPTY_NOT_NULL")
		quit(41)
		return false
	var on_route: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 11))
	if not main._near_any_route_segment(on_route, 24.0):
		push_error("SMOKE_ROUTE_SEGMENT_MISS")
		quit(41)
		return false
	main.tool = main.Tool.TRIPWIRE
	main._update_tripwire_ghost()
	if main.tripwire_ghost == null or not main.tripwire_ghost.visible:
		push_error("SMOKE_TRIP_GHOST_HIDDEN")
		quit(41)
		return false
	main.tripwire_ghost.global_position = on_route
	var vis: Polygon2D = main.tripwire_ghost.get_node_or_null("Visual")
	if vis:
		# Force color check via the same rule the ghost uses.
		var ok: bool = main._near_any_route_segment(on_route, main.TRIPWIRE_ROUTE_DIST)
		if not ok:
			push_error("SMOKE_TRIP_GHOST_NOT_GREEN_POS")
			quit(41)
			return false
	main.tool = main.Tool.DEPLOY
	main._update_tripwire_ghost()
	if main.tripwire_ghost.visible:
		push_error("SMOKE_TRIP_GHOST_STILL_VISIBLE")
		quit(41)
		return false
	print("SMOKE_OK_TRIPWIRE_TOOLING")
	return true


func _assert_touch_parity(main) -> bool:
	if not ResourceLoader.exists("res://scripts/touch_hud.gd"):
		push_error("SMOKE_NO_TOUCH_HUD_SCRIPT")
		quit(44)
		return false
	if main.get_node_or_null("TouchHud") == null:
		push_error("SMOKE_NO_TOUCH_HUD")
		quit(44)
		return false
	if not main.has_method("apply_touch_command") or not main.has_method("handle_android_back"):
		push_error("SMOKE_NO_TOUCH_API")
		quit(44)
		return false
	var proj := FileAccess.get_file_as_string("res://project.godot")
	if proj.find("quit_on_go_back=false") < 0 or proj.find("gl_compatibility") < 0:
		push_error("SMOKE_ANDROID_PROJECT_FLAGS")
		quit(44)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		push_error("SMOKE_NO_GS_TOUCH")
		quit(44)
		return false
	gs.force_touch_hud = true
	main._ensure_touch_hud()
	if main.touch_hud == null or not main.touch_hud.visible:
		push_error("SMOKE_TOUCH_HUD_HIDDEN")
		quit(44)
		return false
	if bool(main._event_log_open) or (main.event_log != null and main.event_log.visible):
		push_error("SMOKE_LOG_NOT_COLLAPSED")
		quit(44)
		return false
	if main.role_cards.is_empty() or (main.role_cards[0] as Control).custom_minimum_size.y < 48.0:
		push_error("SMOKE_OPCARD_TOUCH_SIZE")
		quit(44)
		return false
	var alarm_touch: Button = main.touch_hud._btns["alarm"] as Button
	if alarm_touch == null or alarm_touch.custom_minimum_size.y < 48.0:
		push_error("SMOKE_TOUCH_BTN_SIZE")
		quit(44)
		return false
	main.handle_android_back()
	if main.pause_overlay == null or not main.pause_overlay.is_open():
		push_error("SMOKE_ANDROID_BACK_NO_MENU")
		quit(44)
		return false
	main.handle_android_back()
	if main.pause_overlay.is_open():
		push_error("SMOKE_ANDROID_BACK_STUCK")
		quit(44)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	var f0: float = float(main.selected.facing_deg)
	main.apply_touch_command("rotate_cw")
	if is_equal_approx(float(main.selected.facing_deg), f0):
		push_error("SMOKE_TOUCH_ROTATE_NOOP f=%s" % main.selected.facing_deg)
		quit(44)
		return false
	var mode0 = main.selected.fire_mode
	main.apply_touch_command("fire")
	if main.selected.fire_mode == mode0:
		push_error("SMOKE_TOUCH_FIRE_NOOP")
		quit(44)
		return false
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var slot_pos: Vector2 = main.cover_slots[1].global_position
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = xf * slot_pos
	main._unhandled_input(ev)
	var ev2 := InputEventScreenTouch.new()
	ev2.index = 0
	ev2.pressed = false
	ev2.position = ev.position
	main._unhandled_input(ev2)
	if main.selected == null or main.selected.slot != main.cover_slots[1]:
		push_error("SMOKE_TOUCH_DEPLOY_FAIL pos=%s screen=%s" % [slot_pos, ev.position])
		quit(44)
		return false
	var f_drag: float = float(main.selected.facing_deg)
	var press_op := InputEventScreenTouch.new()
	press_op.index = 0
	press_op.pressed = true
	press_op.position = xf * main.selected.global_position
	main._unhandled_input(press_op)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = xf * (main.selected.global_position + Vector2(90, 0))
	drag.relative = Vector2(40, 0)
	main._unhandled_input(drag)
	if is_equal_approx(float(main.selected.facing_deg), f_drag):
		push_error("SMOKE_TOUCH_DRAG_FACE f=%s" % main.selected.facing_deg)
		quit(44)
		return false
	var rel_op := InputEventScreenTouch.new()
	rel_op.index = 0
	rel_op.pressed = false
	rel_op.position = drag.position
	main._unhandled_input(rel_op)
	main.apply_touch_command("clear")
	if main._deployed_count() != 0:
		push_error("SMOKE_TOUCH_CLEAR_FAIL n=%s" % main._deployed_count())
		quit(44)
		return false
	var hold_slot = main.cover_slots[2]
	var lp := InputEventScreenTouch.new()
	lp.index = 0
	lp.pressed = true
	lp.position = xf * hold_slot.global_position
	main._unhandled_input(lp)
	main._cover_hold_msec = Time.get_ticks_msec() - 500
	main._tick_cover_long_press()
	if main._touch_preview_slot != hold_slot:
		push_error("SMOKE_LONGPRESS_NO_PREVIEW")
		quit(44)
		return false
	if hold_slot.protect_arc == null or not hold_slot.protect_arc.visible:
		push_error("SMOKE_LONGPRESS_NO_ARC")
		quit(44)
		return false
	var lp2 := InputEventScreenTouch.new()
	lp2.index = 0
	lp2.pressed = false
	lp2.position = lp.position
	main._unhandled_input(lp2)
	if main._deployed_count() != 0:
		push_error("SMOKE_LONGPRESS_DEPLOYED n=%s" % main._deployed_count())
		quit(44)
		return false
	gs.force_touch_hud = false
	main._ensure_touch_hud()
	print("SMOKE_OK_TOUCH_PARITY")
	return true


func _assert_lifecycle(main) -> bool:
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null:
		push_error("SMOKE_NO_AUDIODIRECTOR")
		quit(47)
		return false
	if not audio.has_method("pause_for_background") and not audio.has_method("set_background_muted"):
		push_error("SMOKE_NO_BG_AUDIO_API")
		quit(47)
		return false
	if not main.has_method("handle_app_focus_out") or not main.has_method("handle_app_focus_in"):
		push_error("SMOKE_NO_FOCUS_API")
		quit(47)
		return false
	var TitleScript = load("res://scripts/title.gd")
	if TitleScript == null:
		push_error("SMOKE_NO_TITLE_SCRIPT")
		quit(47)
		return false
	var title_probe = TitleScript.new()
	if title_probe == null or not title_probe.has_method("handle_app_focus_out") or not title_probe.has_method("handle_app_focus_in"):
		push_error("SMOKE_NO_TITLE_FOCUS")
		if title_probe:
			title_probe.free()
		quit(47)
		return false
	title_probe.free()
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_LIFECYCLE_NOT_SETUP")
		quit(47)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main._on_alarm_pressed()
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_LIFECYCLE_NO_WATCH phase=%s" % main.phase)
		quit(47)
		return false
	if main.sim.paused:
		push_error("SMOKE_LIFECYCLE_ALREADY_PAUSED")
		quit(47)
		return false
	main.handle_app_focus_out()
	if not main.sim.paused:
		push_error("SMOKE_FOCUS_OUT_SIM_RUNS")
		quit(47)
		return false
	if audio.music_player_playing():
		push_error("SMOKE_FOCUS_OUT_MUSIC_LEAK")
		quit(47)
		return false
	if audio.has_method("is_background_paused") and not bool(audio.is_background_paused()):
		push_error("SMOKE_FOCUS_OUT_AUDIO_NOT_GATED")
		quit(47)
		return false
	main.handle_app_focus_in()
	if not main.sim.paused:
		push_error("SMOKE_FOCUS_IN_AUTOPLAY")
		quit(47)
		return false
	if audio.has_method("is_background_paused") and bool(audio.is_background_paused()):
		push_error("SMOKE_FOCUS_IN_AUDIO_STUCK")
		quit(47)
		return false
	main._start_setup(false, false)
	if main.phase != main.Phase.SETUP or main.loop_index != 1:
		push_error("SMOKE_LIFECYCLE_RESET phase=%s loop=%s" % [main.phase, main.loop_index])
		quit(47)
		return false
	print("SMOKE_OK_LIFECYCLE")
	return true


func _assert_perf_tier(main) -> bool:
	var gs = root.get_node_or_null("GameSettings")
	if gs == null or not gs.has_method("is_power_saving") or not gs.has_method("set_quality_tier"):
		push_error("SMOKE_NO_QUALITY_TIER")
		quit(46)
		return false
	if str(gs.QUALITY_POWER_SAVING) != "power_saving" or str(gs.QUALITY_STANDARD) != "standard":
		push_error("SMOKE_QUALITY_CONST %s %s" % [gs.QUALITY_POWER_SAVING, gs.QUALITY_STANDARD])
		quit(46)
		return false
	if str(gs.quality_tier) != "standard" or bool(gs.is_power_saving()):
		push_error("SMOKE_QUALITY_DEFAULT %s" % gs.quality_tier)
		quit(46)
		return false
	gs.set_quality_tier("power_saving")
	if not gs.is_power_saving() or str(gs.quality_tier) != "power_saving":
		push_error("SMOKE_QUALITY_SET_FAIL %s" % gs.quality_tier)
		quit(46)
		return false
	if gs.has_method("quality_tier_label") and str(gs.quality_tier_label()) != "省电":
		push_error("SMOKE_QUALITY_LABEL %s" % gs.quality_tier_label())
		quit(46)
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or str(cfg.get_value("graphics", "quality_tier", "")) != "power_saving":
		push_error("SMOKE_QUALITY_NOT_PERSISTED")
		quit(46)
		return false
	if main.map_draw == null or not main.map_draw.has_method("uses_static_cache"):
		push_error("SMOKE_NO_MAP_CACHE")
		quit(46)
		return false
	if not bool(main.map_draw.uses_static_cache()):
		push_error("SMOKE_MAP_CACHE_INACTIVE")
		quit(46)
		return false
	if not main.map_draw.has_method("invalidate_static_cache"):
		push_error("SMOKE_NO_MAP_CACHE_INVALIDATE")
		quit(46)
		return false
	main.map_draw.invalidate_static_cache()
	if main.map_draw.get_node_or_null("StaticCache") == null:
		push_error("SMOKE_MAP_CACHE_NODE")
		quit(46)
		return false
	if main.pause_overlay:
		main.pause_overlay.present(false, false)
		var qbtn: Button = main.pause_overlay._quality_btn as Button
		if qbtn == null or str(qbtn.text).find("省电") < 0:
			push_error("SMOKE_QUALITY_UI %s" % (qbtn.text if qbtn else "null"))
			main.pause_overlay.dismiss()
			quit(46)
			return false
		main.pause_overlay.dismiss()
	gs.set_quality_tier("standard")
	if gs.is_power_saving() or str(gs.quality_tier) != "standard":
		push_error("SMOKE_QUALITY_RESTORE_FAIL %s" % gs.quality_tier)
		quit(46)
		return false
	print("SMOKE_OK_PERF_TIER")
	return true


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.reset_to_defaults()
		gs.seen_tutorial = true


func _assert_launch_bar() -> bool:
	if not ResourceLoader.exists("res://scenes/title.tscn"):
		push_error("SMOKE_NO_TITLE_SCENE")
		quit(42)
		return false
	if not FileAccess.file_exists("res://export_presets.cfg"):
		push_error("SMOKE_NO_EXPORT_PRESETS")
		quit(42)
		return false
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.find("platform=\"Android\"") < 0 or presets.find("com.ambushloop.game") < 0:
		push_error("SMOKE_NO_ANDROID_PRESET")
		quit(42)
		return false
	var packed = load("res://scenes/title.tscn")
	if packed == null:
		push_error("SMOKE_TITLE_LOAD_FAIL")
		quit(42)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		push_error("SMOKE_NO_GAMESETTINGS")
		quit(42)
		return false
	if absf(float(gs.get("music_volume")) - 1.0) > 0.02 or absf(float(gs.get("sfx_volume")) - 1.0) > 0.02:
		push_error("SMOKE_AUDIO_BUS_DEFAULTS music=%s sfx=%s" % [gs.get("music_volume"), gs.get("sfx_volume")])
		quit(43)
		return false
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null:
		push_error("SMOKE_NO_AUDIODIRECTOR")
		quit(43)
		return false
	if not audio.has_cue("alarm") or not audio.has_cue("win"):
		push_error("SMOKE_AUDIO_CUES")
		quit(43)
		return false
	if not audio.has_music_bed() or not audio.music_bus_ok():
		push_error("SMOKE_NO_MUSIC_BED")
		quit(43)
		return false
	var entries: Array = gs.mission_entries()
	if entries.size() != 5:
		push_error("SMOKE_MISSION_COUNT %s" % entries.size())
		quit(43)
		return false
	if str(gs.LEVEL_ORDER[3]) != "railcut" or str(gs.LEVEL_ORDER[4]) != "depot" or gs.LEVEL_ORDER.size() != 5:
		push_error("SMOKE_LEVEL_ORDER %s" % str(gs.LEVEL_ORDER))
		quit(43)
		return false
	if not bool(entries[0]["unlocked"]) or bool(entries[1]["unlocked"]) or bool(entries[3]["unlocked"]) or bool(entries[4]["unlocked"]) or bool(entries[0]["cleared"]):
		push_error("SMOKE_MISSION_UNLOCK_FRESH")
		quit(43)
		return false
	var inst = packed.instantiate()
	if inst == null:
		push_error("SMOKE_TITLE_INSTANTIATE_FAIL")
		quit(42)
		return false
	root.add_child(inst)
	await process_frame
	await process_frame
	if inst.mission_row_count() != 5:
		push_error("SMOKE_TITLE_MISSION_ROWS %s" % inst.mission_row_count())
		inst.free()
		quit(43)
		return false
	inst._on_start()
	await process_frame
	if not inst.mission_select_visible():
		push_error("SMOKE_MISSION_SELECT_HIDDEN")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(1)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "warehouse":
		push_error("SMOKE_SKIPPED_LOCKED_MISSION")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(3)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "railcut":
		push_error("SMOKE_SKIPPED_LOCKED_RAILCUT")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(4)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "depot":
		push_error("SMOKE_SKIPPED_LOCKED_DEPOT")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(0)
	await process_frame
	if not inst.briefing_visible() or inst.pending_mission_id() != "yard":
		push_error("SMOKE_YARD_BRIEFING_FAIL")
		inst.free()
		quit(43)
		return false
	inst.free()
	# Keep tutorial modal off so SETUP input/API matches the slice gate.
	gs.seen_tutorial = true
	print("SMOKE_OK_LAUNCH_BAR title+GameSettings+AudioDirector+missions+android_preset")
	return true
