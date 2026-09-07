extends SceneTree

## Headless: fail by covering only west, then win by covering main + flank + exit.

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

	# Life 1: only north-west cover facing poorly — flank escapes
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0]) # 西侧掩体
	main.selected.set_facing(90.0) # face south, misses east flank
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
			print("t=", frames, " phase=", main.phase, " alive=", alive, " loop=", main.loop_index)
		if main.phase == main.Phase.FAILED and not saw_fail:
			saw_fail = true
			print("SMOKE_FAIL_ESCAPE intel=", main.intel_paths.size())
			main._on_continue_pressed()
			await process_frame
			# Life 2: cover main corridor, flank approach, and exit funnel
			main._select_op(0)
			main._deploy_selected_to(main.cover_slots[1]) # 北廊
			main.selected.set_facing(90.0)
			main._select_op(1)
			main._deploy_selected_to(main.cover_slots[2]) # 东箱 — face west into flank
			main.selected.set_facing(180.0)
			main._select_op(2)
			main._deploy_selected_to(main.cover_slots[5]) # 出口掩体
			main.selected.set_facing(180.0)
			main._on_alarm_pressed()
			print("LIFE2 deployed=", main._deployed_count())
		if main.phase == main.Phase.WON:
			print("SMOKE_OK won loop=", main.loop_index, " frames=", frames)
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s" % main.phase)
	quit(2)
