extends SceneTree

## T0 contract checks.  Storage is isolated before loading the game scene.

const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, "user://test/t0_regression/ambush_loop.cfg")
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		_fail("T0_SCENE_LOAD_FAILED")
		return
	await process_frame
	await process_frame
	var main = current_scene
	# loop_index is history only: exact same surviving squad earns exact same score.
	for count in [1, 2, 3]:
		for loop in [1, 4, 99]:
			main.loop_index = loop
			for i in main.operators.size():
				var op = main.operators[i]
				op.visible = i < count
				op.alive = i < count
			var expected: int = count
			if main._calculate_stars() != expected:
				_fail("T0_STARS_DEPEND_ON_LOOP count=%s loop=%s got=%s" % [count, loop, main._calculate_stars()])
				return
	print("T0_STAR_CONTRACT_OK")
	var copy := main.about_panel.get_node_or_null("AboutBody/PrivacyCopy") as Label
	if copy == null:
		_fail("T0_PRIVACY_COPY_MISSING")
		return
	for forbidden in ["Data safety", "Play Console", "待填", "隐私政策草案", "依赖审计"]:
		if copy.text.contains(forbidden):
			_fail("T0_PRIVACY_PLACEHOLDER %s" % forbidden)
			return
	print("T0_PRIVACY_COPY_OK")
	for button in get_nodes_in_group("frontend_button"):
		var control := button as Button
		if control == null or control.custom_minimum_size.y < 96.0:
			_fail("T0_FRONTEND_TARGET_FAIL %s" % button.name)
			return
	print("T0_FRONTEND_TARGETS_OK")
	print("T0_REGRESSION_COMPLETE")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
