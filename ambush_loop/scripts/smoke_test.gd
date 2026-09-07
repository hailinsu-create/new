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
				" events=", main.battle_log.events.size()
			)
			main._on_continue_pressed()
			await process_frame
			if main._deployed_count() < 1:
				push_error("SMOKE_PLAN_NOT_RESTORED")
				quit(5)
				return
			print("LIFE2_RESTORED deployed=", main._deployed_count())
			main._on_clear_pressed()
			await process_frame
			_deploy_ref(main, [1, 2, 5], [90.0, 180.0, 180.0])
			main._on_alarm_pressed()
			print("LIFE2 deployed=", main._deployed_count())
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
			var used_alt := false
			var alt_mark: Vector2 = main.grid.cell_to_world_center(Vector2i(11, 8))
			for p in flank_enemy.route:
				if p.distance_to(alt_mark) < 1.0:
					used_alt = true
					break
			if not used_alt:
				push_error("SMOKE_LOCKED_ROUTE_NOT_USED door=%s route_len=%s" % [main.door_locked, flank_enemy.route.size()])
				quit(16)
				return
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
		main.level.cover_defs, main.level.route_cells, alt, blocked_route
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


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
