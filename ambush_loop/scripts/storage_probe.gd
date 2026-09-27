extends SceneTree

const StorageGuard := preload("res://scripts/test_storage_guard.gd")

func _init() -> void:
	if not StorageGuard.check():
		quit(91)
		return
	call_deferred("_run")

func _run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("probe", "run_id", OS.get_environment("AMBUSH_TEST_RUN_ID"))
	var err := cfg.save("user://ambush_loop.cfg")
	if err != OK:
		push_error("PROBE_WRITE_FAILED: %s" % err)
		quit(43)
		return
	print("PROBE_WROTE_ISOLATED")
	var mode := OS.get_environment("AMBUSH_PROBE_MODE")
	if mode == "assertion_failure":
		push_error("PROBE_EXPECTED_ASSERTION_FAILURE")
		quit(42)
	elif mode == "forced_termination":
		await create_timer(30.0).timeout
		quit(44)
	else:
		quit(0)
