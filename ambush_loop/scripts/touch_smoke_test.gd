extends SceneTree

## Synthetic portrait touch smoke.
## Every user-facing interaction in this file enters through
## Input.parse_input_event(InputEventScreenTouch); direct calls are used only
## to change the test level between independent interaction cases.

const PRODUCTION_SAVE_PATH := "user://ambush_loop.cfg"
const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"

var isolated_save_path := ""
var production_save_existed := false
var production_save_bytes := PackedByteArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _prepare_isolated_storage():
		quit(30)
		return
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("TOUCH_SCENE_LOAD_FAILED %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	for _i in 4:
		await process_frame
	var main = current_scene
	if not _assert_portrait_layout(main):
		return
	if not await _test_yard_controls(main):
		return
	if not await _test_event_log_toggle_and_result_view(main):
		return
	if not await _test_watching_lock_pause_and_speed(main):
		return
	if not await _test_pump_door(main):
		return
	if not await _test_failure_result_recovery_and_touch_win(main):
		return
	if not await _test_touch_continue_chain(main):
		return
	if not _assert_production_save_untouched():
		return
	print("TOUCH_SMOKE_COMPLETE")
	quit(0)


func _test_touch_continue_chain(main) -> bool:
	main._load_level("yard", false, false)
	await _frames(4)
	var hud: TouchHUD = main.touch_hud
	if not _expect(main.level.level_id == "yard" and main.phase == main.Phase.SETUP, "CHAIN_YARD_INIT failed", 70):
		return false

	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[1].global_position)
	await _tap_button(hud.card_buttons[1])
	await _tap_world(main, main.cover_slots[3].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(18, 10)))
	await _tap_button(hud.card_buttons[2])
	await _tap_world(main, main.cover_slots[5].global_position)
	await _tap_button(hud.alarm_button)
	await _frames(2)
	await _tap_button(hud.speed_button)
	if not await _wait_for_phase(main, main.Phase.WON, 60 * 45):
		return _expect(false, "CHAIN_YARD_WON failed phase=%s reason=%s" % [main.phase, main.fail_reason], 71)
	await _tap_button(main.continue_button)
	if not _expect(main.level.level_id == "warehouse" and main.phase == main.Phase.SETUP, "CHAIN_WAREHOUSE_SETUP failed level=%s phase=%s" % [main.level.level_id, main.phase], 72):
		return false

	for i in 3:
		await _tap_button(hud.card_buttons[i])
		await _tap_world(main, main.cover_slots[[1, 3, 5][i]].global_position)
	await _tap_button(hud.pack_button)
	await _tap_button(hud.mode_button)
	await _tap_button(hud.alarm_button)
	await _frames(2)
	await _tap_button(hud.speed_button)
	if not await _wait_for_phase(main, main.Phase.WON, 60 * 45):
		return _expect(false, "CHAIN_WAREHOUSE_WON failed phase=%s reason=%s" % [main.phase, main.fail_reason], 73)
	await _tap_button(main.continue_button)
	if not _expect(main.level.level_id == "pump" and main.phase == main.Phase.SETUP, "CHAIN_PUMP_SETUP failed level=%s phase=%s" % [main.level.level_id, main.phase], 74):
		return false
	if not _expect(hud.door_button.visible and not main.door_locked and not main.grid.is_blocked(main.level.door_cell.x, main.level.door_cell.y), "CHAIN_PUMP_OPEN_DOOR_NOT_CLEAR", 75):
		return false
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[1].global_position)
	if not _expect(_angle_near(main.selected.facing_deg, 90.0), "CHAIN_PUMP_OPEN_SLOT1_FACE got=%s" % main.selected.facing_deg, 76):
		return false
	await _tap_button(hud.card_buttons[1])
	await _tap_world(main, main.cover_slots[4].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(17, 16)))
	if not _expect(_angle_near(main.selected.facing_deg, 0.0), "CHAIN_PUMP_OPEN_SLOT4_FACE got=%s" % main.selected.facing_deg, 77):
		return false
	await _tap_button(hud.card_buttons[2])
	await _tap_world(main, main.cover_slots[5].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(8, 19)))
	if not _expect(_angle_near(main.selected.facing_deg, 180.0), "CHAIN_PUMP_OPEN_SLOT5_FACE got=%s" % main.selected.facing_deg, 78):
		return false
	await _tap_button(hud.alarm_button)
	await _frames(2)
	await _tap_button(hud.speed_button)
	if not await _wait_for_phase(main, main.Phase.WON, 60 * 200):
		return _expect(false, "CHAIN_PUMP_OPEN_WON failed phase=%s reason=%s" % [main.phase, main.fail_reason], 79)
	if not _expect(main.level.level_id == "pump", "CHAIN_PUMP_OPEN_LEVEL failed level=%s" % main.level.level_id, 80):
		return false
	print("TOUCH_PUMP_OPEN_OK")

	main._load_level("pump", false, false)
	await _frames(4)
	if not _expect(main.level.level_id == "pump" and main.phase == main.Phase.SETUP, "CHAIN_PUMP_LOCKED_INIT failed level=%s phase=%s" % [main.level.level_id, main.phase], 81):
		return false
	await _tap_button(hud.door_button)
	if not _expect(main.door_locked and main.grid.is_blocked(main.level.door_cell.x, main.level.door_cell.y), "CHAIN_PUMP_LOCKED_DOOR failed", 82):
		return false
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[1].global_position)
	if not _expect(_angle_near(main.selected.facing_deg, 90.0), "CHAIN_PUMP_LOCKED_SLOT1_FACE got=%s" % main.selected.facing_deg, 83):
		return false
	await _tap_button(hud.card_buttons[1])
	await _tap_world(main, main.cover_slots[4].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(9, 16)))
	if not _expect(_angle_near(main.selected.facing_deg, 180.0), "CHAIN_PUMP_LOCKED_SLOT4_FACE got=%s" % main.selected.facing_deg, 84):
		return false
	await _tap_button(hud.card_buttons[2])
	await _tap_world(main, main.cover_slots[5].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(11, 16)))
	if not _expect(_angle_near(main.selected.facing_deg, 270.0), "CHAIN_PUMP_LOCKED_SLOT5_FACE got=%s" % main.selected.facing_deg, 85):
		return false
	await _tap_button(hud.alarm_button)
	await _frames(2)
	await _tap_button(hud.speed_button)
	var flank_enemy = null
	for _i in 300:
		await process_frame
		for e in main.enemies:
			if e.label_id == 2:
				flank_enemy = e
				break
		if flank_enemy != null:
			break
	if not _expect(flank_enemy != null, "CHAIN_PUMP_LOCKED_FLANK_SPAWN", 86):
		return false
	var alt_mark: Vector2 = main.grid.cell_to_world_center(Vector2i(2, 10))
	var used_alt := false
	for p in flank_enemy.route:
		if p.distance_to(alt_mark) < 1.0:
			used_alt = true
			break
	if not _expect(used_alt, "CHAIN_PUMP_LOCKED_ROUTE_NOT_USED door=%s route_len=%s" % [main.door_locked, flank_enemy.route.size()], 87):
		return false
	if not await _wait_for_phase(main, main.Phase.WON, 60 * 200):
		return _expect(false, "CHAIN_PUMP_LOCKED_WON failed phase=%s reason=%s" % [main.phase, main.fail_reason], 88)
	if not _expect(main.level.level_id == "pump", "CHAIN_PUMP_LOCKED_LEVEL failed level=%s" % main.level.level_id, 89):
		return false
	print("TOUCH_PUMP_LOCKED_OK")
	print("TOUCH_CONTINUE_CHAIN_OK")
	return true


func _assert_portrait_layout(main) -> bool:
	var sizes := [
		Vector2(720.0, 1280.0),
		Vector2(360.0, 640.0),
		Vector2(390.0, 844.0),
		Vector2(412.0, 915.0),
	]
	for viewport_size in sizes:
		var metrics: Dictionary = TouchHUD.layout_metrics(viewport_size)
		var viewport_rect: Rect2 = metrics["viewport_rect"]
		var panel_rect: Rect2 = metrics["panel_rect"]
		var cards_rect: Rect2 = metrics["cards_rect"]
		var actions_rect: Rect2 = metrics["actions_rect"]
		var min_button := float(metrics["button_min"])
		var cell_width := float(metrics["cell_width"])
		var gap := float(metrics["gap"])
		var fits := bool(metrics["fits_horizontal"]) and bool(metrics["fits_vertical"])
		print(
			"TOUCH_LAYOUT viewport=%s panel=%s cards=%s actions=%s columns=%s rows=%s cell=%.2f min=%.2f gap=%.2f fits=%s"
			% [
				viewport_size,
				panel_rect,
				cards_rect,
				actions_rect,
				metrics["columns"],
				metrics["rows"],
				cell_width,
				min_button,
				gap,
				fits,
			]
		)
		if not _expect(
			fits and cell_width + 0.01 >= min_button and gap >= 12.0 and viewport_rect.encloses(panel_rect),
			"PORTRAIT_LAYOUT_OVERFLOW size=%s panel=%s actions=%s cell=%.2f" % [viewport_size, panel_rect, actions_rect, cell_width],
			42
		):
			return false

	var sample_world: Vector2 = main.grid.cell_to_world_center(Vector2i(9, 3))
	var sample_screen: Vector2 = main.get_viewport().get_canvas_transform() * sample_world
	var round_trip: Vector2 = main._screen_to_world(sample_screen)
	if not _expect(round_trip.distance_to(sample_world) <= 0.01, "MAP_VIEWPORT_WORLD_ROUNDTRIP_FAILED", 43):
		return false
	print(
		"TOUCH_MAP_TRANSFORM world=%s screen=%s round_trip=%s hit_radius=%.1f"
		% [sample_world, sample_screen, round_trip, main.MAP_TOUCH_HIT_RADIUS]
	)
	return true


func _test_yard_controls(main) -> bool:
	if not _expect(main.level.level_id == "yard", "START_LEVEL expected=yard got=%s" % main.level.level_id, 10):
		return false
	var hud: TouchHUD = main.touch_hud
	var setup_phase = main.phase
	var setup_deployed: int = main._deployed_count()
	await _tap_button(hud.log_button)
	if not _expect(hud.is_event_log_open(), "EVENT_LOG_SETUP_OPEN failed", 55):
		return false
	if not _expect(main.phase == setup_phase and main.phase == main.Phase.SETUP and main._deployed_count() == setup_deployed, "EVENT_LOG_SETUP_OPEN_MUTATED_STATE", 56):
		return false
	await _tap_button(hud.log_close_button)
	if not _expect(not hud.is_event_log_open(), "EVENT_LOG_SETUP_CLOSE failed", 57):
		return false
	if not _expect(main.phase == setup_phase and main.phase == main.Phase.SETUP and main._deployed_count() == setup_deployed, "EVENT_LOG_SETUP_CLOSE_MUTATED_STATE", 58):
		return false
	print("TOUCH_OK event_log_setup_toggle")

	# Card selection, map deployment, and both 15-degree controls.
	await _tap_button(hud.card_buttons[1])
	if not _expect(main.selected == main.operators[1], "CARD_SELECT failed", 11):
		return false
	await _tap_world(main, main.cover_slots[1].global_position)
	if not _expect(main.selected.visible and main.selected.slot == main.cover_slots[1], "MAP_DEPLOY failed", 12):
		return false
	var facing: float = main.selected.facing_deg
	await _tap_button(hud.left_button)
	if not _expect(_angle_near(main.selected.facing_deg, facing - 15.0), "FACING_LEFT failed", 13):
		return false
	await _tap_button(hud.right_button)
	if not _expect(_angle_near(main.selected.facing_deg, facing), "FACING_RIGHT failed", 14):
		return false

	# A canceled HUD pointer must clear its pressed target without firing it.
	var canceled_facing: float = main.selected.facing_deg
	await _touch_down(hud.left_button.global_position, 43)
	await _touch_cancel(hud.left_button.global_position, 43)
	if not _expect(_angle_near(main.selected.facing_deg, canceled_facing) and main.active_pointer_id == -1, "CANCELED_HUD_TOUCH_FIRED", 30):
		return false

	# Aim mode must consume the next map tap without moving the operator.
	await _tap_button(hud.aim_button)
	var aimed_slot = main.selected.slot
	var aim_point: Vector2 = main.grid.cell_to_world_center(Vector2i(9, 3))
	await _tap_world(main, aim_point)
	if not _expect(main.selected.slot == aimed_slot and not main.aim_mode, "MAP_AIM_MOVED_OPERATOR", 15):
		return false
	if not _expect(_angle_near(main.selected.facing_deg, -90.0), "MAP_AIM_WRONG_FACING got=%s" % main.selected.facing_deg, 16):
		return false

	# Tripwire placement and the same-button retract path.
	await _tap_button(hud.tripwire_button)
	if not _expect(main.tool == main.Tool.TRIPWIRE, "TRIPWIRE_TOOL_ON failed", 17):
		return false
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(9, 3)))
	if not _expect(main.tripwires.size() == 1, "TRIPWIRE_PLACE failed", 18):
		return false
	await _tap_button(hud.tripwire_button)
	if not _expect(main.tripwires.is_empty() and main.tool == main.Tool.DEPLOY, "TRIPWIRE_RETRACT failed", 19):
		return false

	# Only one active pointer may alter the plan.  The second down is ignored.
	await _tap_button(hud.clear_button)
	var first_slot = main.cover_slots[0]
	var second_slot = main.cover_slots[1]
	await _touch_down(first_slot.global_position, 41)
	await _touch_down(second_slot.global_position, 42)
	await _touch_up(second_slot.global_position, 42)
	await _touch_up(first_slot.global_position, 41)
	if not _expect(main._deployed_count() == 1 and main.operators[0].slot == first_slot, "MULTI_POINTER_ESCAPED active=%s deployed=%s" % [main.active_pointer_id, main._deployed_count()], 20):
		return false

	print("TOUCH_OK yard_card_map_facing_aim_tripwire_pointer")
	return true


func _test_event_log_toggle_and_result_view(main) -> bool:
	var hud: TouchHUD = main.touch_hud
	var setup_phase = main.phase
	var setup_locked: bool = main.plan_locked
	var setup_deployed: int = main._deployed_count()
	await _tap_button(hud.log_button)
	if not _expect(hud.is_event_log_open(), "SETUP_EVENT_LOG_OPEN failed", 44):
		return false
	if not _expect(main.phase == setup_phase and main.plan_locked == setup_locked and main._deployed_count() == setup_deployed, "SETUP_EVENT_LOG_MUTATED_STATE", 45):
		return false
	await _tap_button(hud.log_close_button)
	if not _expect(not hud.is_event_log_open(), "SETUP_EVENT_LOG_CLOSE failed", 46):
		return false
	if not _expect(main.phase == setup_phase and main.plan_locked == setup_locked and main._deployed_count() == setup_deployed, "SETUP_EVENT_LOG_CLOSE_MUTATED_STATE", 47):
		return false

	main._load_level("yard", false, false)
	await _frames(4)
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[0].global_position)
	await _tap_button(hud.alarm_button)
	await _frames(2)
	if not _expect(main.phase == main.Phase.WATCHING, "RESULT_VIEW_ALARM failed", 48):
		return false
	await _tap_button(hud.speed_button)
	if not await _wait_for_phase(main, main.Phase.FAILED, 60 * 45):
		return _expect(false, "RESULT_VIEW_FAILURE_NOT_REACHED phase=%s reason=%s" % [main.phase, main.fail_reason], 49)
	var result_phase = main.phase
	var result_locked: bool = main.plan_locked
	var result_deployed: int = main._deployed_count()
	if not _expect(main.result_panel.visible, "RESULT_VIEW_PANEL_MISSING", 50):
		return false
	await _tap_button(main.battlefield_button)
	if not _expect(hud.is_event_log_open() and not main.result_panel.visible, "RESULT_VIEW_OPEN failed", 51):
		return false
	if not _expect(main.phase == result_phase and main.plan_locked == result_locked and main._deployed_count() == result_deployed, "RESULT_VIEW_OPEN_MUTATED_STATE", 52):
		return false
	await _tap_button(hud.log_close_button)
	if not _expect(not hud.is_event_log_open() and main.result_panel.visible, "RESULT_VIEW_RETURN failed", 53):
		return false
	if not _expect(main.phase == result_phase and main.plan_locked == result_locked and main._deployed_count() == result_deployed, "RESULT_VIEW_RETURN_MUTATED_STATE", 54):
		return false
	print("TOUCH_OK event_log_setup_toggle_result_view")
	return true


func _test_watching_lock_pause_and_speed(main) -> bool:
	# This case deliberately uses the warehouse controls so the ammo-pack path
	# is exercised through the visible button as well.
	main._load_level("warehouse", false, false)
	await _frames(4)
	var hud: TouchHUD = main.touch_hud
	for i in 3:
		await _tap_button(hud.card_buttons[i])
		await _tap_world(main, main.cover_slots[[0, 2, 4][i]].global_position)
	var pack_rect := hud.pack_button.get_global_rect()
	var log_rect := hud.log_button.get_global_rect()
	print("PACK_DEBUG level=%s phase=%s selected=%s visible=%s disabled=%s rect=%s log_rect=%s overlap=%s log_open=%s" % [main.level.level_id, main.phase, main.selected, hud.pack_button.visible, hud.pack_button.disabled, pack_rect, log_rect, pack_rect.intersects(log_rect), hud.is_event_log_open()])
	if not _expect(not pack_rect.intersects(log_rect), "PACK_LOG_RECT_OVERLAP pack=%s log=%s" % [pack_rect, log_rect], 63):
		return false
	await _tap_button(hud.pack_button)
	if not _expect(main.selected.has_ammo_pack, "AMMO_PACK failed", 21):
		return false
	await _tap_button(hud.mode_button)
	if not _expect(main.selected.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH, "FIRE_MODE failed", 22):
		return false
	await _tap_button(hud.alarm_button)
	await _frames(2)
	if not _expect(main.phase == main.Phase.WATCHING, "ALARM failed phase=%s" % main.phase, 23):
		return false
	for op in main.operators:
		if op.visible and not _expect(op.locked, "PLAN_NOT_LOCKED op=%s" % op.op_id, 24):
			return false

	# UI card and map taps cannot change a locked plan.
	var locked_selected = main.selected
	var locked_slot = locked_selected.slot
	var locked_facing: float = locked_selected.facing_deg
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[5].global_position)
	if not _expect(main.selected == locked_selected and main.selected.slot == locked_slot and _angle_near(main.selected.facing_deg, locked_facing), "WATCHING_INPUT_MUTATED_PLAN", 25):
		return false

	# Pause must freeze the fixed-step clock, and speed remains a watching-only
	# control while paused.
	await _tap_button(hud.pause_button)
	await _frames(2)
	if not _expect(main.sim.paused, "PAUSE_BUTTON failed", 26):
		return false
	var paused_tick: int = main.sim.tick
	await _frames(12)
	if not _expect(main.sim.tick == paused_tick, "PAUSE_ADVANCED_TICK before=%s after=%s" % [paused_tick, main.sim.tick], 27):
		return false
	await _tap_button(hud.speed_button)
	if not _expect(main.sim.speed >= 1.5, "SPEED_BUTTON failed speed=%s" % main.sim.speed, 28):
		return false
	await _tap_button(hud.pause_button)
	await _frames(2)
	if not _expect(not main.sim.paused, "RESUME_BUTTON failed", 29):
		return false

	print("TOUCH_OK alarm_lock_pause_speed_pack_mode")
	return true


func _test_pump_door(main) -> bool:
	main._load_level("pump", false, false)
	await _frames(4)
	var hud: TouchHUD = main.touch_hud
	if not _expect(hud.door_button.visible, "PUMP_DOOR_HIDDEN", 31):
		return false
	await _tap_button(hud.door_button)
	if not _expect(main.door_locked and main.grid.is_blocked(main.level.door_cell.x, main.level.door_cell.y), "DOOR_LOCK failed", 32):
		return false
	await _tap_button(hud.door_button)
	if not _expect(not main.door_locked and not main.grid.is_blocked(main.level.door_cell.x, main.level.door_cell.y), "DOOR_UNLOCK failed", 33):
		return false
	await _tap_button(hud.door_button)
	if not _expect(main.door_locked, "DOOR_RELOCK failed", 34):
		return false
	print("TOUCH_OK pump_door_toggle")
	return true


func _test_failure_result_recovery_and_touch_win(main) -> bool:
	# First produce a real escape with the one-operator plan, then tap the
	# result panel's recovery button.  The restored plan is expanded through
	# touch input and completed as a real touch-driven yard win.
	main._load_level("yard", false, false)
	await _frames(4)
	var hud: TouchHUD = main.touch_hud
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[0].global_position)
	await _tap_button(hud.alarm_button)
	await _frames(2)
	if not _expect(main.phase == main.Phase.WATCHING, "FAILURE_SETUP_ALARM failed", 35):
		return false
	await _tap_button(hud.speed_button)
	var failed := await _wait_for_phase(main, main.Phase.FAILED, 60 * 45)
	if not _expect(failed, "FAILURE_NOT_REACHED phase=%s reason=%s" % [main.phase, main.fail_reason], 36):
		return false
	if not _expect(main.result_panel.visible and not main.intel_paths.is_empty(), "FAILURE_PANEL_OR_INTEL_MISSING", 37):
		return false
	var result_phase = main.phase
	var result_locked: bool = main.plan_locked
	var result_deployed: int = main._deployed_count()
	await _tap_button(main.battlefield_button)
	if not _expect(not main.result_panel.visible and hud.is_event_log_open(), "RESULT_BATTLEFIELD_OPEN failed", 59):
		return false
	if not _expect(main.phase == result_phase and main.plan_locked == result_locked and main._deployed_count() == result_deployed, "RESULT_BATTLEFIELD_OPEN_MUTATED_STATE", 60):
		return false
	await _tap_button(hud.log_close_button)
	if not _expect(main.result_panel.visible and not hud.is_event_log_open(), "RESULT_BATTLEFIELD_RETURN failed", 61):
		return false
	if not _expect(main.phase == result_phase and main.plan_locked == result_locked and main._deployed_count() == result_deployed, "RESULT_BATTLEFIELD_RETURN_MUTATED_STATE", 62):
		return false
	print("TOUCH_OK result_battlefield_view_return")
	var old_loop: int = main.loop_index
	await _tap_button(main.continue_button)
	if not _expect(main.phase == main.Phase.SETUP and main.loop_index == old_loop + 1 and main._deployed_count() >= 1, "FAILURE_RECOVERY_TOUCH failed", 38):
		return false

	# Clear restored deployment through the HUD, then build the known yard
	# solution entirely through card and map taps.
	await _tap_button(hud.clear_button)
	await _tap_button(hud.card_buttons[0])
	await _tap_world(main, main.cover_slots[1].global_position)
	await _tap_button(hud.card_buttons[1])
	await _tap_world(main, main.cover_slots[3].global_position)
	await _tap_button(hud.aim_button)
	await _tap_world(main, main.grid.cell_to_world_center(Vector2i(18, 10)))
	await _tap_button(hud.card_buttons[2])
	await _tap_world(main, main.cover_slots[5].global_position)
	if not _expect(main._deployed_count() == 3, "TOUCH_WIN_PLAN_DEPLOY failed count=%s" % main._deployed_count(), 39):
		return false
	await _tap_button(hud.alarm_button)
	await _frames(2)
	await _tap_button(hud.speed_button)
	var won := await _wait_for_phase(main, main.Phase.WON, 60 * 45)
	if not _expect(won, "TOUCH_WIN_NOT_REACHED phase=%s reason=%s" % [main.phase, main.fail_reason], 40):
		return false
	if not _expect(main.result_panel.visible, "TOUCH_WIN_PANEL_MISSING", 41):
		return false
	print("TOUCH_OK failure_panel_recovery_and_yard_win")
	return true


func _tap_button(button: Button) -> void:
	if button == null:
		return
	await _tap_position(button.get_global_rect().get_center())


func _tap_world(main, world_pos: Vector2) -> void:
	await _tap_position(world_pos)


func _tap_position(pos: Vector2) -> void:
	await _touch_down(pos, 0)
	await _touch_up(pos, 0)
	await process_frame


func _touch_down(pos: Vector2, pointer_id: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = pointer_id
	event.position = current_scene.get_viewport().get_screen_transform() * pos
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _touch_up(pos: Vector2, pointer_id: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = pointer_id
	event.position = current_scene.get_viewport().get_screen_transform() * pos
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _touch_cancel(pos: Vector2, pointer_id: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = pointer_id
	event.position = current_scene.get_viewport().get_screen_transform() * pos
	event.pressed = false
	event.canceled = true
	Input.parse_input_event(event)
	await process_frame


func _wait_for_phase(main, wanted, max_frames: int) -> bool:
	for _i in max_frames:
		await process_frame
		if main.phase == wanted:
			return true
		if wanted == main.Phase.FAILED and main.phase == main.Phase.WON:
			return false
		if wanted == main.Phase.WON and main.phase == main.Phase.FAILED:
			return false
	return false


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _angle_near(a: float, b: float, tolerance: float = 0.5) -> bool:
	var d := fposmod(a - b + 180.0, 360.0) - 180.0
	return absf(d) <= tolerance


func _expect(condition: bool, message: String, code: int) -> bool:
	if condition:
		return true
	push_error("TOUCH_FAIL[%d] %s" % [code, message])
	quit(code)
	return false


func _prepare_isolated_storage() -> bool:
	var unique_id := "touch_%s_%s" % [str(Time.get_ticks_usec()), str(OS.get_process_id())]
	isolated_save_path = "user://test/" + unique_id + "/ambush_loop.cfg"
	if isolated_save_path == PRODUCTION_SAVE_PATH or not isolated_save_path.begins_with("user://test/"):
		push_error("TOUCH_STORAGE_NOT_ISOLATED path=%s" % isolated_save_path)
		return false
	var absolute_dir := ProjectSettings.globalize_path(isolated_save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		push_error("TOUCH_STORAGE_DIR_FAILED path=%s" % absolute_dir)
		return false
	production_save_existed = FileAccess.file_exists(PRODUCTION_SAVE_PATH)
	if production_save_existed:
		var file := FileAccess.open(PRODUCTION_SAVE_PATH, FileAccess.READ)
		if file == null:
			push_error("TOUCH_PRODUCTION_SENTINEL_READ_FAILED")
			return false
		production_save_bytes = file.get_buffer(file.get_length())
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, isolated_save_path)
	if str(ProjectSettings.get_setting(PROGRESS_PATH_SETTING, "")) != isolated_save_path:
		push_error("TOUCH_STORAGE_INJECTION_FAILED path=%s" % isolated_save_path)
		return false
	print("TOUCH_STORAGE_ISOLATED path=", isolated_save_path)
	return true


func _assert_production_save_untouched() -> bool:
	var exists_now := FileAccess.file_exists(PRODUCTION_SAVE_PATH)
	if exists_now != production_save_existed:
		push_error("TOUCH_PRODUCTION_SAVE_CHANGED")
		quit(31)
		return false
	if not exists_now:
		return true
	var file := FileAccess.open(PRODUCTION_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("TOUCH_PRODUCTION_SENTINEL_READ_FAILED_AFTER")
		quit(31)
		return false
	var after := file.get_buffer(file.get_length())
	if after != production_save_bytes:
		push_error("TOUCH_PRODUCTION_SAVE_BYTES_CHANGED")
		quit(31)
		return false
	return true
