extends SceneTree

## P0 smoke: assert escape reason, intel, plan restore, then win.

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
	for i in 8:
		await process_frame

	# Life 1: only west cover — expect flank escape
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(90.0)
	main._on_alarm_pressed()
	print("LIFE1 deployed=", main._deployed_count())

	var frames := 0
	var saw_fail := false
	while frames < 60 * 90:
		await process_frame
		frames += 1
		if frames % 180 == 0:
			var alive := 0
			for e in main.enemies:
				if e.alive:
					alive += 1
			print("t=", frames, " phase=", main.phase, " alive=", alive, " loop=", main.loop_index, " reason=", main.fail_reason)
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
			print("SMOKE_FAIL_ESCAPE reason=", main.fail_reason, " intel=", main.intel_paths.size(), " pts=", main.intel_paths[0].size())
			main._on_continue_pressed()
			await process_frame
			# Plan should be restored
			if main._deployed_count() < 1:
				push_error("SMOKE_PLAN_NOT_RESTORED")
				quit(5)
				return
			print("LIFE2_RESTORED deployed=", main._deployed_count())
			# Redeploy winning setup
			main._on_clear_pressed()
			await process_frame
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
			if main.loop_index < 2:
				push_error("SMOKE_BAD_LOOP won_at=%d" % main.loop_index)
				quit(6)
				return
			print("SMOKE_OK won loop=", main.loop_index, " frames=", frames, " intel=", main.intel_paths.size())
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s reason=%s" % [main.phase, main.fail_reason])
	quit(2)
