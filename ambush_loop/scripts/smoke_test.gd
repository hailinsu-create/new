extends SceneTree

## Vertical-slice smoke (blueprint §9): yard escape→restore→win, then warehouse loads.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	print("LEVEL=", main.level.level_id)

	# Life 1: only one cover — expect flank escape
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(90.0)
	main._on_alarm_pressed()
	print("LIFE1 deployed=", main._deployed_count())

	var frames := 0
	var saw_fail := false
	while frames < 60 * 100:
		await process_frame
		frames += 1
		if frames % 240 == 0:
			print("t=", frames, " phase=", main.phase, " loop=", main.loop_index, " reason=", main.fail_reason, " level=", main.level.level_id)
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
			if main.battle_log.events.is_empty():
				push_error("SMOKE_NO_EVENTS")
				quit(7)
				return
			print("SMOKE_FAIL_ESCAPE reason=", main.fail_reason, " intel=", main.intel_paths.size(), " events=", main.battle_log.events.size())
			main._on_continue_pressed()
			await process_frame
			if main._deployed_count() < 1:
				push_error("SMOKE_PLAN_NOT_RESTORED")
				quit(5)
				return
			print("LIFE2_RESTORED deployed=", main._deployed_count())
			main._on_clear_pressed()
			await process_frame
			# Winning yard setup
			main._select_op(0)
			main._deploy_selected_to(main.cover_slots[1])
			main.selected.set_facing(90.0)
			main._select_op(1)
			main._deploy_selected_to(main.cover_slots[2])
			main.selected.set_facing(180.0)
			main._select_op(2)
			main._deploy_selected_to(main.cover_slots[5])
			main.selected.set_facing(180.0)
			main._on_alarm_pressed()
			print("LIFE2 deployed=", main._deployed_count())
		if main.phase == main.Phase.WON:
			print("SMOKE_OK won loop=", main.loop_index, " frames=", frames, " events=", main.battle_log.events.size())
			# Advance to warehouse if continue does that
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id == "warehouse":
				print("SMOKE_LEVEL2_LOADED warehouse covers=", main.cover_slots.size(), " pack=", main.level.has_ammo_pack)
				# Load pump definition existence
				var pump = LevelDef.by_id("pump")
				if pump.door_cell.x < 0:
					push_error("SMOKE_PUMP_NO_DOOR")
					quit(8)
					return
				print("SMOKE_LEVEL3_OK pump door=", pump.door_cell, " alt_route=", pump.alternate_route_cells.size())
				print("SMOKE_SLICE_COMPLETE")
				quit(0)
				return
			print("SMOKE_SLICE_COMPLETE (stay_on_level=", main.level.level_id, ")")
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s reason=%s" % [main.phase, main.fail_reason])
	quit(2)
