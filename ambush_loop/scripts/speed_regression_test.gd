extends SceneTree

## Direct API speed regression for the ambush loop.
##
## This runner deliberately keeps the production save path away from the
## process under test.  It is a behavior test: the trials drive the actual
## scene and loop, then compare the resulting event streams.

const MAIN_SCENE := "res://scenes/main.tscn"
const PRODUCTION_SAVE_PATH := "user://ambush_loop.cfg"
var _test_save_path := ""

var _exit_code := 1
var _app: Node
var _production_save_exists := false
var _production_save_bytes := PackedByteArray()


func _initialize() -> void:
	_exit_code = 1
	_test_save_path = "user://test/speed_%s.cfg" % [str(Time.get_unix_time_from_system())]
	_capture_production_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test"))
	ProjectSettings.set_setting("application/config/ambush_progress_path", _test_save_path)
	call_deferred("_run")


func _run() -> void:
	await _load_main_scene()
	_app = _find_loop_root()
	if _app == null:
		_fail("could not find ambush loop root after loading main.tscn")
		return

	var speed_result := await _run_speed_trials()
	if speed_result.is_empty():
		return

	var escape_result := await _run_escape_trial()
	if escape_result.is_empty():
		return

	if not await _run_plan_lock_guard():
		return

	if not _assert_production_save_unchanged():
		return

	print("SPEED_REGRESSION_OK speed1_tick=%s speed2_tick=%s events=%s" % [
		speed_result.speed1_tick,
		speed_result.speed2_tick,
		speed_result.events,
	])
	print("SPEED_ESCAPE_ORDER_OK tick=%s" % escape_result.tick)
	print("PLAN_LOCK_GUARD_OK")
	_exit_code = 0
	quit(_exit_code)


func _load_main_scene() -> void:
	var error := change_scene_to_file(MAIN_SCENE)
	if error != OK:
		_fail("change_scene_to_file failed: %s" % error)
		return
	await process_frame
	await process_frame


func _run_speed_trials() -> Dictionary:
	var first := await _run_win_trial(1.0)
	if first.is_empty():
		return {}
	var second := await _run_win_trial(2.0)
	if second.is_empty():
		return {}

	if first.terminal_reason != "win" or second.terminal_reason != "win":
		_fail("speed trials did not finish with terminal_reason=win")
		return {}
	if first.terminal_tick != second.terminal_tick:
		_fail("terminal ticks differ: speed1=%s speed2=%s" % [first.terminal_tick, second.terminal_tick])
		return {}
	if first.events != second.events:
		_fail("normalized event sequences differ between speed trials")
		return {}

	return {
		"speed1_tick": first.terminal_tick,
		"speed2_tick": second.terminal_tick,
		"events": first.events.size(),
	}


func _run_win_trial(speed: float) -> Dictionary:
	await _reset_loop_for_trial()
	if not _deploy_reference_plan():
		_fail("reference plan deployment failed for speed=%s" % speed)
		return {}
	_trigger_alarm()
	_set_simulation_speed(speed)
	var terminal := await _wait_for_terminal()
	if terminal.is_empty():
		return {}
	return {
		"terminal_reason": str(terminal.get("payload", {}).get("reason", "")),
		"terminal_tick": int(terminal.get("tick", -1)),
		"events": _normalized_events(_events()),
	}


func _run_escape_trial() -> Dictionary:
	await _reset_loop_for_trial()
	if not _deploy_escape_plan():
		_fail("escape plan deployment failed")
		return {}
	_trigger_alarm()
	var terminal := await _wait_for_terminal()
	if terminal.is_empty():
		return {}
	var events := _normalized_events(_events())
	var escape_index := -1
	var terminal_index := -1
	for index in events.size():
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == "escape":
			escape_index = index
		if str(event.get("type", "")) == "terminal":
			terminal_index = index
	if escape_index < 0 or terminal_index < 0:
		_fail("escape trial is missing escape or terminal event")
		return {}
	if int(events[escape_index].get("tick", -1)) != int(events[terminal_index].get("tick", -2)):
		_fail("escape and terminal events have different ticks")
		return {}
	if terminal_index != events.size() - 1:
		_fail("terminal event is not the last event")
		return {}
	if str(terminal.get("payload", {}).get("reason", "")) != "escape":
		_fail("escape trial did not finish with terminal_reason=escape")
		return {}

	return {"tick": int(terminal.get("tick", -1))}


func _run_plan_lock_guard() -> bool:
	await _reset_loop_for_trial()
	if not _deploy_reference_plan():
		_fail("reference plan deployment failed for plan lock guard")
		return false
	_trigger_alarm()
	await process_frame
	var before := _guard_snapshot()
	if int(before.get("phase", -1)) != int(_app.Phase.WATCHING):
		_fail("plan lock guard did not reach watching phase")
		return false

	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_R
	key_event.keycode = KEY_R
	key_event.pressed = true
	key_event.echo = false
	_app.call("_unhandled_input", key_event)
	var after_key := _guard_snapshot()
	if not _same_guard_state(before, after_key):
		_fail("KEY_R changed watching plan state")
		return false

	var selected_before := _deployment_snapshot()
	if _app.has_method("_deploy_selected_to"):
		_app.call("_deploy_selected_to", _app.cover_slots[0])
	else:
		_fail("loop root has no _deploy_selected_to method")
		return false
	var selected_after := _deployment_snapshot()
	if not _same_deployment_state(selected_before, selected_after):
		_fail("_deploy_selected_to changed locked deployment or facing state")
		return false
	return true


func _deploy_reference_plan() -> bool:
	return _deploy_plan([1, 3, 5], [90, 0, 90])


func _deploy_escape_plan() -> bool:
	return _deploy_plan([0], [90])


func _deploy_plan(slots: Array, facings: Array) -> bool:
	if _app.has_method("_deploy_selected_to"):
		for index in slots.size():
			_app.call("_select_op", index)
			_app.call("_deploy_selected_to", _app.cover_slots[int(slots[index])])
			_set_selected_facing(int(facings[index]))
		return true
	return false


func _set_selected_facing(facing: int) -> void:
	if _app.selected != null:
		_app.selected.set_facing(float(facing))


func _trigger_alarm() -> void:
	for method_name in ["_on_alarm_pressed", "_trigger_alarm", "trigger_alarm", "start_alarm"]:
		if _app.has_method(method_name):
			_app.call(method_name)
			return
	_fail("could not find alarm trigger method")


func _set_simulation_speed(speed: float) -> void:
	_app.sim.set_speed(speed)


func _wait_for_terminal() -> Dictionary:
	for _frame in 6000:
		var terminal := _last_terminal(_events())
		if not terminal.is_empty():
			return terminal
		await process_frame
	_fail("trial did not reach a terminal event")
	return {}


func _reset_loop_for_trial() -> void:
	var error := change_scene_to_file(MAIN_SCENE)
	if error != OK:
		_fail("could not reload main.tscn between trials: %s" % error)
		return
	await process_frame
	await process_frame
	await process_frame
	_app = _find_loop_root()
	if _app == null:
		_fail("could not find ambush loop root after trial reload")
		return
	# Production startup restores the last safe plan. Each trial must begin
	# from a clean setup so only the reference plan is under test.
	if _app.has_method("_start_setup"):
		_app.call("_start_setup", false, false)
		await process_frame


func _events() -> Array:
	if _app.battle_log != null and _app.battle_log.events is Array:
		return _app.battle_log.events
	return []


func _normalized_events(raw_events: Array) -> Array:
	var normalized := []
	for raw_event in raw_events:
		if not raw_event is Dictionary:
			continue
		var payload: Dictionary = raw_event.get("payload", {})
		normalized.append({
			"tick": int(raw_event.get("tick", -1)),
			"type": str(raw_event.get("type", "")),
			"actor_id": int(raw_event.get("actor_id", -1)),
			"target_id": int(raw_event.get("target_id", -1)),
			"payload": {"reason": str(payload.get("reason", ""))},
		})
	return normalized


func _last_terminal(raw_events: Array) -> Dictionary:
	for index in range(raw_events.size() - 1, -1, -1):
		if raw_events[index] is Dictionary and str(raw_events[index].get("type", "")) == "terminal":
			return raw_events[index]
	return {}


func _guard_snapshot() -> Dictionary:
	return {
		"phase": int(_app.phase),
		"loop": int(_app.loop_index),
		"intel": _app.intel_paths.duplicate(true),
		"last_plan": {
			"deployments": _app.last_plan.deployments.duplicate(true),
			"tripwire_positions": _app.last_plan.tripwire_positions.duplicate(true),
			"door_locked": _app.last_plan.door_locked,
		},
		"plan_locked": bool(_app.plan_locked),
	}


func _deployment_snapshot() -> Dictionary:
	var deployments := []
	var facings := []
	for op in _app.operators:
		deployments.append(op.slot.slot_id if op.slot != null else -1)
		facings.append(float(op.facing_deg))
	return {
		"deployments": deployments,
		"facings": facings,
	}


func _read_value(property_names: Array):
	for property_name in property_names:
		var value = _app.get(property_name)
		if value != null:
			return value
	return null


func _same_guard_state(before: Dictionary, after: Dictionary) -> bool:
	return _deep_equal(before, after)


func _same_deployment_state(before: Dictionary, after: Dictionary) -> bool:
	return _deep_equal(before, after)


func _deep_equal(left, right) -> bool:
	return var_to_bytes(left) == var_to_bytes(right)


func _find_loop_root() -> Node:
	var current := current_scene
	if current == null:
		return null
	for candidate in [current, current.get_node_or_null("AmbushLoop"), current.get_node_or_null("Game"), current.get_node_or_null("Main")]:
		if candidate != null and _looks_like_loop(candidate):
			return candidate
	return _find_loop_descendant(current)


func _find_loop_descendant(node: Node) -> Node:
	if node == null:
		return null
	for child in node.get_children():
		if _looks_like_loop(child):
			return child
		var nested := _find_loop_descendant(child)
		if nested != null:
			return nested
	return null


func _looks_like_loop(node: Node) -> bool:
	return node.has_method("_unhandled_input") and (node.has_method("_deploy_selected_to") or node.has_method("_deploy_plan") or node.has_method("deploy_plan"))


func _capture_production_save() -> void:
	var path := ProjectSettings.globalize_path(PRODUCTION_SAVE_PATH)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_production_save_exists = false
		return
	_production_save_exists = true
	_production_save_bytes = file.get_buffer(file.get_length())


func _assert_production_save_unchanged() -> bool:
	var path := ProjectSettings.globalize_path(PRODUCTION_SAVE_PATH)
	var file := FileAccess.open(path, FileAccess.READ)
	if not _production_save_exists:
		if file != null:
			_fail("production save was created during speed regression")
			return false
		return true
	if file == null:
		_fail("production save disappeared during speed regression")
		return false
	var current_bytes := file.get_buffer(file.get_length())
	if current_bytes != _production_save_bytes:
		_fail("production save bytes changed during speed regression")
		return false
	return true


func _fail(message: String) -> void:
	push_error("SPEED_REGRESSION_FAIL: %s" % message)
	_exit_code = 1
	quit(_exit_code)
