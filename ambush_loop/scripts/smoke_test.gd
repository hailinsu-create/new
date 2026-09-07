extends SceneTree

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
	for i in 5:
		await process_frame

	# Life 1: seal west only — east runner should escape
	main._try_place_mine(Vector2(13.5 * 32.0, 5.5 * 32.0))
	main._try_place_mine(Vector2(15.5 * 32.0, 10.5 * 32.0))
	main._on_alarm_pressed()
	print("LIFE1 mines=", main.mines.size())

	var frames := 0
	var saw_fail := false
	while frames < 60 * 50:
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
			main._try_place_mine(Vector2(13.5 * 32.0, 5.5 * 32.0))
			main._try_place_mine(Vector2(29.5 * 32.0, 5.5 * 32.0))
			main._try_place_mine(Vector2(35.5 * 32.0, 16.5 * 32.0))
			main._on_alarm_pressed()
			print("LIFE2 mines=", main.mines.size())
		if main.phase == main.Phase.WON:
			print("SMOKE_OK won loop=", main.loop_index, " frames=", frames)
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s" % main.phase)
	quit(2)
