extends SceneTree

## Vertical-slice smoke: yard escape→restore→win, then warehouse+pump reference wins.
## Isolates user:// save data so player progress cannot mask failures.

const SAVE_PATH := "user://ambush_loop.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_wipe_save()
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
	var empty = Tripwire.new().sim_check([])
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


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
