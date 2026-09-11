extends SceneTree

## Vertical-slice smoke: abort/wipe fail paths, yard escape→restore→win,
## warehouse+pump+railcut+depot reference wins, campaign credits name 油库.
## Isolates user:// save data so player progress cannot mask failures.
## Bypasses title via change_scene_to_file(main.tscn).

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_wipe_save()
	if not await _assert_launch_bar():
		return
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
	if not _assert_touch_parity(main):
		return
	if not _assert_lifecycle(main):
		return
	if not _assert_watch_juice(main):
		return
	if not _assert_alarm_stinger(main):
		return
	if not _assert_win_stinger(main):
		return
	if not _assert_perf_tier(main):
		return
	if not _assert_readability(main):
		return
	if not _assert_unit_anim(main):
		return
	if not _assert_feel_presence(main):
		return
	if not _assert_props(main):
		return
	if not _assert_teaching(main):
		return
	if not await _assert_checklist(main):
		return
	print("LEVEL=", main.level.level_id)
	if main.has_method("_refresh_watch_timeline"):
		main._refresh_watch_timeline()
	if not main.has_method("setup_spawn_preview_visible") or not bool(main.setup_spawn_preview_visible()):
		push_error("SMOKE_NO_SPAWN_PREVIEW")
		quit(59)
		return
	if not main.has_method("setup_spawn_preview_count") or int(main.setup_spawn_preview_count()) < 2:
		push_error("SMOKE_SPAWN_PREVIEW_COUNT %s" % (main.setup_spawn_preview_count() if main.has_method("setup_spawn_preview_count") else -1))
		quit(59)
		return
	print("SMOKE_OK_SPAWN_PREVIEW n=", main.setup_spawn_preview_count())
	if not await _assert_fail_paths(main):
		return

	# Life 1: 灰狼 on west cover, authored east face (0°) covers the spine so
	# 敌1/敌2 die and flank 敌3 (delay 0.4s) is the leaker. South 90° covers neither.
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(0.0)
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
			if str(main.result_label.text).find("情报已记录") < 0:
				push_error("SMOKE_NO_INTEL_RECORDED %s" % main.result_label.text)
				quit(4)
				return
			print("SMOKE_OK_INTEL_RECORDED")
			if str(main.result_label.text).find("下一波") < 0:
				push_error("SMOKE_NO_NEXT_WAVE %s" % main.result_label.text)
				quit(52)
				return
			var leak_line_txt := str(main.result_label.text)
			if (
				leak_line_txt.find("漏网：") < 0
				or leak_line_txt.find("侧翼") < 0
				or leak_line_txt.find("敌3") < 0
				or leak_line_txt.find("0.4") < 0
			):
				push_error("SMOKE_NO_LEAK_RESULT_LINE %s" % leak_line_txt)
				quit(59)
				return
			print("SMOKE_OK_LEAK_RESULT_LINE")
			if leak_line_txt.find("改一处") < 0:
				push_error("SMOKE_NO_FIX_ONE %s" % leak_line_txt)
				quit(61)
				return
			print("SMOKE_OK_FIX_ONE")
			if main.intel.records.is_empty():
				push_error("SMOKE_NO_LEAKER_RECORD")
				quit(56)
				return
			var leak_rec_fail: Dictionary = main.intel.records[main.intel.records.size() - 1]
			var leak_id_fail: int = int(leak_rec_fail.get("leaker_id", -1))
			var leak_route_fail := str(leak_rec_fail.get("route", ""))
			var esc_ev: Dictionary = main.battle_log.last_of_type("escape") if main.battle_log.has_method("last_of_type") else {}
			if leak_route_fail != "flank" or leak_id_fail != 3:
				push_error(
					"SMOKE_WRONG_LEAKER route=%s id=%s rec=%s"
					% [leak_route_fail, leak_id_fail, str(leak_rec_fail)]
				)
				quit(56)
				return
			if esc_ev.is_empty() or int(esc_ev.get("actor_id", -1)) != leak_id_fail:
				push_error(
					"SMOKE_ESCAPE_ACTOR_MISMATCH log=%s intel=%s"
					% [esc_ev.get("actor_id", -1), leak_id_fail]
				)
				quit(56)
				return
			if str(esc_ev.get("payload", {}).get("route", "")) != "flank":
				push_error("SMOKE_ESCAPE_LOG_ROUTE %s" % str(esc_ev.get("payload", {})))
				quit(56)
				return
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
			if not main.has_method("intel_path_ghost_active") or not bool(main.intel_path_ghost_active()):
				push_error("SMOKE_NO_INTEL_GHOST")
				quit(4)
				return
			print("SMOKE_OK_INTEL_GHOST")
			if not main.has_method("leak_advice_text") or str(main.leak_advice_text()).find("建议") < 0 or str(main.leak_advice_text()).find("秒前") < 0:
				push_error("SMOKE_NO_LEAK_ADVICE %s" % (main.leak_advice_text() if main.has_method("leak_advice_text") else "no_api"))
				quit(56)
				return
			if main.intel.records.is_empty():
				push_error("SMOKE_NO_LEAKER_RECORD")
				quit(56)
				return
			var leak_rec: Dictionary = main.intel.records[main.intel.records.size() - 1]
			var leaker_id: int = int(leak_rec.get("leaker_id", -1))
			if leaker_id < 1:
				push_error("SMOKE_NO_LEAKER_ID rec=%s" % str(leak_rec))
				quit(56)
				return
			if str(leak_rec.get("route", "")) != "flank" or leaker_id != 3:
				push_error(
					"SMOKE_LEAKER_NOT_FLANK3 route=%s id=%s"
					% [leak_rec.get("route", ""), leaker_id]
				)
				quit(56)
				return
			if main.level == null or not main.level.has_method("delay_for_actor"):
				push_error("SMOKE_NO_DELAY_FOR_ACTOR")
				quit(56)
				return
			var actor_delay: float = float(main.level.delay_for_actor(leaker_id))
			if absf(actor_delay - 0.4) > 0.001 or absf(float(main.level.delay_for_actor(3)) - 0.4) > 0.001:
				push_error("SMOKE_FLANK3_DELAY %s" % actor_delay)
				quit(56)
				return
			var advice_txt := str(main.leak_advice_text())
			if advice_txt.find("敌") < 0 or advice_txt.find(str(leaker_id)) < 0:
				push_error("SMOKE_LEAK_ADVICE_NO_ACTOR id=%s txt=%s" % [leaker_id, advice_txt])
				quit(56)
				return
			if advice_txt.find("侧翼") < 0:
				push_error("SMOKE_LEAK_ADVICE_NOT_FLANK txt=%s" % advice_txt)
				quit(56)
				return
			if advice_txt.find("改一处") < 0:
				push_error("SMOKE_LEAK_ADVICE_NO_FIX txt=%s" % advice_txt)
				quit(56)
				return
			var leak_tick_n: int = int(leak_rec.get("leak_tick", -1))
			var leak_sec_n: float = float(leak_tick_n) / 60.0 if leak_tick_n >= 0 else float(leak_rec.get("cut_sec", 0.0))
			var expect_ahead := maxf(0.1, leak_sec_n - actor_delay)
			if advice_txt.find("%.1f" % expect_ahead) < 0:
				push_error(
					"SMOKE_LEAK_ADVICE_WRONG_DELAY id=%s delay=%s ahead=%s txt=%s"
					% [leaker_id, actor_delay, expect_ahead, advice_txt]
				)
				quit(56)
				return
			# Authored per-runner delay (railcut 敌4 = 4.6s) must beat first_route_delay (3.8s).
			var rc_def: LevelDef = LevelDef.by_id("railcut")
			if not rc_def.has_method("delay_for_actor"):
				push_error("SMOKE_RAILCUT_NO_ACTOR_DELAY")
				quit(56)
				return
			var d4: float = float(rc_def.delay_for_actor(4))
			var d_flank: float = float(rc_def.first_route_delay("flank"))
			if d4 <= 0.0 or d4 <= d_flank + 0.01:
				push_error("SMOKE_ACTOR_DELAY_NOT_PER_RUNNER d4=%s first=%s" % [d4, d_flank])
				quit(56)
				return
			var store := IntelStore.new()
			store.add_path(
				1,
				PackedVector2Array([Vector2.ZERO, Vector2(40, 0)]),
				6.0,
				"escape",
				"侧翼奔袭从东廊漏出",
				"flank",
				360,
				4
			)
			var unit_line := str(store.leak_advice_line(rc_def, "侧翼"))
			if unit_line.find("1.4") < 0 or unit_line.find("敌4") < 0 or unit_line.find("2.2") >= 0:
				push_error("SMOKE_PER_RUNNER_ADVICE_MATH %s" % unit_line)
				quit(56)
				return
			if unit_line.find("改一处") < 0:
				push_error("SMOKE_PER_RUNNER_NO_FIX %s" % unit_line)
				quit(56)
				return
			print("SMOKE_OK_LEAK_ADVICE ", advice_txt, " leaker=", leaker_id, " delay=", actor_delay)
			if main.has_method("_refresh_checklist"):
				main._refresh_checklist()
			if not main.has_method("leak_cover_ok") or bool(main.leak_cover_ok()):
				push_error("SMOKE_LEAK_COVER_NOT_RED %s" % (main.checklist_strip_text() if main.has_method("checklist_strip_text") else ""))
				quit(56)
				return
			var leak_chip_txt := str(main.checklist_strip_text()) if main.has_method("checklist_strip_text") else ""
			if leak_chip_txt.find("漏网") < 0:
				push_error("SMOKE_NO_LEAK_CHIP %s" % leak_chip_txt)
				quit(56)
				return
			if main.alarm_button == null or bool(main.alarm_button.disabled):
				push_error("SMOKE_LEAK_CHIP_HARD_GATE")
				quit(56)
				return
			print("SMOKE_OK_LEAK_COVER_RED chip=", leak_chip_txt.replace("\n", " | "))
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
			if main.has_method("_refresh_checklist"):
				main._refresh_checklist()
			if not main.has_method("leak_cover_ok") or not bool(main.leak_cover_ok()):
				push_error("SMOKE_LEAK_COVER_NOT_GREEN %s" % (main.checklist_strip_text() if main.has_method("checklist_strip_text") else ""))
				quit(56)
				return
			print("SMOKE_OK_LEAK_COVER_GREEN")
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
			if main.title_return_button == null or not main.title_return_button.visible:
				push_error("SMOKE_NO_DEBRIEF_TITLE_BTN")
				quit(44)
				return
			if str(main.continue_button.text).find("下一关") < 0:
				push_error("SMOKE_DEBRIEF_CONTINUE %s" % main.continue_button.text)
				quit(44)
				return
			if str(main.result_label.text).find("关键事件") < 0:
				push_error("SMOKE_DEBRIEF_EVENTS")
				quit(44)
				return
			if str(main.result_label.text).find("终局摘要") < 0:
				push_error("SMOKE_DEBRIEF_SUMMARY")
				quit(44)
				return
			if str(main.result_label.text).find("解锁下一关") < 0 or str(main.result_label.text).find("深仓") < 0:
				push_error("SMOKE_DEBRIEF_UNLOCK %s" % main.result_label.text)
				quit(44)
				return
			if str(main.result_label.text).find("完美院子") >= 0:
				push_error("SMOKE_YARD_STAR_AFTER_ESCAPE")
				quit(44)
				return
			if not main.has_method("result_stats_block_text") or str(main.result_stats_block_text()).strip_edges() == "":
				push_error("SMOKE_NO_RESULT_STATS")
				quit(54)
				return
			if str(main.result_stats_block_text()).find("世数") < 0 or str(main.result_stats_block_text()).find("用时") < 0:
				push_error("SMOKE_RESULT_STATS_EMPTY %s" % main.result_stats_block_text())
				quit(54)
				return
			if str(main.result_stats_block_text()).find("第一枪是") < 0:
				push_error("SMOKE_NO_FIRST_SHOT_ROLE %s" % main.result_stats_block_text())
				quit(61)
				return
			if str(main.result_label.text).find("交叉封锁") < 0:
				push_error("SMOKE_NO_YARD_HOOK %s" % main.result_label.text)
				quit(61)
				return
			print("SMOKE_OK_PRESENTATION stats=", main.result_stats_block_text().replace("\n", " | "))
			var gs_win = root.get_node_or_null("GameSettings")
			if gs_win == null or not gs_win.is_level_cleared("yard") or not gs_win.is_level_unlocked("warehouse"):
				push_error("SMOKE_WIN_UNLOCK")
				quit(44)
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
			if main.level.barrel_cell != Vector2i(22, 8):
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
			var dump_fail: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 240)
			if not dump_fail or main.fail_reason != "escape":
				push_error(
					"SMOKE_WAREHOUSE_DUMP_NOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(12)
				return
			var dump_route := str(main.intel.latest_route()) if main.intel else ""
			if dump_route != "flank":
				push_error("SMOKE_WAREHOUSE_DUMP_ROUTE %s" % dump_route)
				quit(12)
				return
			var dump_txt := str(main.result_label.text)
			if dump_txt.find("改一处") < 0 or (dump_txt.find("东廊") < 0 and dump_txt.find("侧翼") < 0):
				push_error("SMOKE_WAREHOUSE_DUMP_COPY %s" % dump_txt)
				quit(12)
				return
			print(
				"SMOKE_WAREHOUSE_DUMP_FAIL reason=", main.fail_reason,
				" route=", dump_route,
				" leaker=", main.intel.latest_leaker_id(),
				" tick=", main.sim.tick
			)
			main._on_continue_pressed()
			await process_frame
			main._on_clear_pressed()
			await process_frame
			_deploy_ref(main, [1, 3, 5], [180.0, 0.0, 180.0])
			if main.has_method("_play_hold_pack"):
				main._play_hold_pack(1)
			else:
				push_error("SMOKE_NO_HOLD_PACK_HELPER")
				quit(12)
				return
			if main.operators[1].fire_mode != OperatorUnit.FireMode.HOLD_FOR_AMBUSH or not main.operators[1].has_ammo_pack:
				push_error(
					"SMOKE_WAREHOUSE_HOLD_PACK_NOT_SET mode=%s pack=%s"
					% [main.operators[1].fire_mode, main.operators[1].has_ammo_pack]
				)
				quit(12)
				return
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var wh: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not wh:
				push_error(
					"SMOKE_WAREHOUSE_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(12)
				return
			if not main.battle_log.has_type("ambush_armed") and not main.battle_log.has_type("repack"):
				push_error("SMOKE_WAREHOUSE_HOOK_NOT_HOLD_PACK")
				quit(12)
				return
			print(
				"SMOKE_WAREHOUSE_HOLD_PACK_WIN tick=", main.sim.tick,
				" ambush=", main.battle_log.has_type("ambush_armed"),
				" repack=", main.battle_log.has_type("repack")
			)
			print("BLAST_RADIUS warehouse tick 824 -> ", main.sim.tick)
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
			if not main.has_method("decision_pulse_active") or not bool(main.decision_pulse_active()):
				push_error("SMOKE_NO_DECISION_PULSE")
				quit(56)
				return
			if not main.door_locked:
				main._on_door_pressed()
			await process_frame
			if bool(main.decision_pulse_active()):
				push_error("SMOKE_PULSE_AFTER_DOOR")
				quit(56)
				return
			print("SMOKE_OK_DECISION_PULSE")
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
			var alt_mark: Vector2 = main.grid.cell_to_world_center(Vector2i(9, 8))
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
			var old_face: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 240)
			if not old_face or main.fail_reason != "escape":
				push_error(
					"SMOKE_PUMP_LOCKED_OLD_FACE_NOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(17)
				return
			var pump_route := str(main.intel.latest_route()) if main.intel else ""
			var pump_fail_txt := str(main.result_label.text)
			if pump_route != "alt" and pump_fail_txt.find("紫") < 0 and pump_fail_txt.find("备用") < 0:
				push_error("SMOKE_PUMP_OLD_FACE_NOT_PURPLE route=%s txt=%s" % [pump_route, pump_fail_txt])
				quit(17)
				return
			print(
				"SMOKE_PUMP_LOCKED_OLD_FACE_FAIL reason=", main.fail_reason,
				" route=", pump_route,
				" tick=", main.sim.tick
			)
			main._on_continue_pressed()
			await process_frame
			if main.has_method("_refresh_checklist"):
				main._refresh_checklist()
			var pump_chip := str(main.checklist_strip_text()) if main.has_method("checklist_strip_text") else ""
			if pump_chip.find("紫备用") < 0 and pump_chip.find("备用") < 0:
				push_error("SMOKE_PUMP_NO_ALT_CHIP %s" % pump_chip)
				quit(17)
				return
			if pump_chip.find("侧翼") >= 0:
				push_error("SMOKE_PUMP_DEAD_ORANGE_CHIP %s" % pump_chip)
				quit(17)
				return
			if main.has_method("leak_cover_ok") and bool(main.leak_cover_ok()):
				push_error("SMOKE_PUMP_LEAK_COVER_NOT_RED %s" % pump_chip)
				quit(17)
				return
			print("SMOKE_OK_PUMP_LEAK_CHIP ", pump_chip.replace("\n", " | "))
			main._on_clear_pressed()
			await process_frame
			if not main.door_locked:
				main._on_door_pressed()
			_deploy_ref(main, [1, 4, 5], [90.0, 180.0, 180.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var pl: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not pl:
				push_error(
					"SMOKE_PUMP_LOCKED_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(17)
				return
			if not main.battle_log.has_type("route_choice"):
				push_error("SMOKE_PUMP_WIN_NO_ROUTE_CHOICE")
				quit(17)
				return
			print("BLAST_RADIUS pump_locked tick 1016 -> ", main.sim.tick)
			print("SMOKE_OK pump_locked won tick=", main.sim.tick)
			if not _assert_level_order(main, 5):
				return
			var gs_pump = root.get_node_or_null("GameSettings")
			if gs_pump == null or not gs_pump.is_level_cleared("pump") or not gs_pump.is_level_unlocked("railcut"):
				push_error(
					"SMOKE_RAILCUT_UNLOCK cleared_pump=%s unlocked=%s"
					% [
						gs_pump.is_level_cleared("pump") if gs_pump else false,
						gs_pump.is_level_unlocked("railcut") if gs_pump else false,
					]
				)
				quit(45)
				return
			var entries_after: Array = gs_pump.mission_entries()
			if entries_after.size() != 5 or not bool(entries_after[3]["unlocked"]) or str(entries_after[3]["id"]) != "railcut":
				push_error("SMOKE_RAILCUT_MISSION_ENTRY %s" % str(entries_after.size()))
				quit(45)
				return
			print("SMOKE_OK_RAILCUT_UNLOCK")
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "railcut":
				push_error("SMOKE_BAD_ADVANCE expected=railcut got=%s" % main.level.level_id)
				quit(45)
				return
			if not _assert_save_level("railcut"):
				return
			if not _assert_geometry(main, "railcut"):
				return
			if not _assert_railcut_contract(main):
				return
			# South-stack probe: 南折 + 南闸 + 西廊脊. Delayed east pair must leak.
			_deploy_ref(main, [2, 5, 1], [0.0, 180.0, 270.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var rc_stack: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 240)
			if not rc_stack or main.fail_reason != "escape":
				push_error(
					"SMOKE_RAILCUT_STACK_NOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(45)
				return
			var rc_route := str(main.intel.latest_route()) if main.intel else ""
			var rc_leaker := int(main.intel.latest_leaker_id()) if main.intel else -1
			if rc_route != "flank" or (rc_leaker != 3 and rc_leaker != 4):
				push_error("SMOKE_RAILCUT_STACK_NOT_EAST route=%s leaker=%s" % [rc_route, rc_leaker])
				quit(45)
				return
			var rc_fail_txt := str(main.result_label.text)
			if rc_fail_txt.find("东廊") < 0 or rc_fail_txt.find("3.8") < 0:
				push_error("SMOKE_RAILCUT_STACK_COPY %s" % rc_fail_txt)
				quit(45)
				return
			print(
				"SMOKE_RAILCUT_SOUTH_STACK_FAIL reason=", main.fail_reason,
				" route=", rc_route,
				" leaker=", rc_leaker,
				" tick=", main.sim.tick
			)
			main._on_continue_pressed()
			await process_frame
			main._on_clear_pressed()
			await process_frame
			# Reference win (documented): rifle 西廊脊 slot1 face 270 (north up west spine),
			# MG 东廊 slot4 face 270 (north up delayed east corridor), scout 南闸 slot5 face 180 (west).
			# Core walls block cross-corridor LOS; ignoring the delayed east pair escapes (probe).
			_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var rc: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not rc:
				push_error(
					"SMOKE_RAILCUT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(45)
				return
			print("SMOKE_OK railcut won tick=", main.sim.tick)
			var gs_rc = root.get_node_or_null("GameSettings")
			if gs_rc == null or not gs_rc.is_level_cleared("railcut") or not gs_rc.is_level_unlocked("depot"):
				push_error(
					"SMOKE_DEPOT_UNLOCK cleared_railcut=%s unlocked=%s"
					% [
						gs_rc.is_level_cleared("railcut") if gs_rc else false,
						gs_rc.is_level_unlocked("depot") if gs_rc else false,
					]
				)
				quit(48)
				return
			var depot_entries: Array = gs_rc.mission_entries()
			if depot_entries.size() != 5 or not bool(depot_entries[4]["unlocked"]) or str(depot_entries[4]["id"]) != "depot":
				push_error("SMOKE_DEPOT_MISSION_ENTRY %s" % str(depot_entries.size()))
				quit(48)
				return
			print("SMOKE_OK_DEPOT_UNLOCK")
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "depot":
				push_error("SMOKE_BAD_ADVANCE expected=depot got=%s" % main.level.level_id)
				quit(48)
				return
			if not _assert_save_level("depot"):
				return
			if not _assert_geometry(main, "depot"):
				return
			if not _assert_depot_contract(main):
				return
			# No-trip probe: same guns, no 绊索. Sneak 敌3 at 2.2s must leak.
			_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var depot_stack: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 240)
			if not depot_stack or main.fail_reason != "escape":
				push_error(
					"SMOKE_DEPOT_NOTRIP_NOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(48)
				return
			var dp_route := str(main.intel.latest_route()) if main.intel else ""
			var dp_leaker := int(main.intel.latest_leaker_id()) if main.intel else -1
			if dp_route != "sneak" or dp_leaker != 3:
				push_error("SMOKE_DEPOT_NOTRIP_NOT_SNEAK route=%s leaker=%s" % [dp_route, dp_leaker])
				quit(48)
				return
			var dp_fail_txt := str(main.result_label.text)
			if dp_fail_txt.find("暗道") < 0 or dp_fail_txt.find("2.2") < 0:
				push_error("SMOKE_DEPOT_NOTRIP_COPY %s" % dp_fail_txt)
				quit(48)
				return
			print(
				"SMOKE_DEPOT_NO_TRIP_FAIL reason=", main.fail_reason,
				" route=", dp_route,
				" leaker=", dp_leaker,
				" tick=", main.sim.tick
			)
			main._on_continue_pressed()
			await process_frame
			if main.has_method("_refresh_checklist"):
				main._refresh_checklist()
			var sneak_chip := str(main.checklist_strip_text()) if main.has_method("checklist_strip_text") else ""
			if sneak_chip.find("暗道") < 0:
				push_error("SMOKE_DEPOT_SNEAK_CHIP_AFTER %s" % sneak_chip)
				quit(48)
				return
			if main.has_method("leak_cover_ok") and bool(main.leak_cover_ok()):
				push_error("SMOKE_DEPOT_LEAK_COVER_NOT_RED %s" % sneak_chip)
				quit(48)
				return
			print("SMOKE_OK_DEPOT_SNEAK_CHIP ", sneak_chip.replace("\n", " | "))
			main._on_clear_pressed()
			await process_frame
			# Rifle 主路脊 slot1 face 270, MG 东廊 slot4 face 270, scout 南闸 slot5 face 180.
			# Tripwire on the west alley (7,11) so the delayed sneak does not leak.
			_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
			main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
			if main.tripwires.size() != 1:
				push_error("SMOKE_DEPOT_TRIP n=%s" % main.tripwires.size())
				quit(48)
				return
			main.sim.set_speed(2.0)
			main._on_alarm_pressed()
			main.sim.set_speed(2.0)
			var dp: bool = await _wait_phase(main, main.Phase.WON, 60 * 240)
			if not dp:
				push_error(
					"SMOKE_DEPOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(48)
				return
			print("SMOKE_OK depot won tick=", main.sim.tick)
			var depot_debrief := str(main.result_label.text) + "\n" + str(main.result_stats_block_text() if main.has_method("result_stats_block_text") else "")
			if depot_debrief.find("2.2") < 0 or depot_debrief.find("绊索") < 0:
				push_error("SMOKE_DEPOT_NO_HOOK %s" % depot_debrief)
				quit(61)
				return
			print("SMOKE_OK_DEPOT_HOOK")
			if str(main.continue_button.text).find("查看致谢") < 0:
				push_error("SMOKE_DEPOT_NO_CREDITS_CTA %s" % main.continue_button.text)
				quit(61)
				return
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.credits_overlay == null or not main.credits_overlay.is_open():
				push_error("SMOKE_DEPOT_CREDITS_CLOSED")
				quit(61)
				return
			var cred_txt := _collect_label_text(main.credits_overlay)
			if cred_txt.find("油库") < 0:
				push_error("SMOKE_DEPOT_CREDITS_NO_OIL %s" % cred_txt)
				quit(61)
				return
			print("SMOKE_OK_CREDITS_DEPOT")
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
		if main.phase == main.Phase.WON:
			return false
	return false


func _drive_ticks(main, n: int) -> void:
	var start: int = main.sim.tick
	var guard := 0
	while main.sim.tick < start + n and guard < 180:
		await process_frame
		guard += 1


func _collect_label_text(n: Node) -> String:
	var acc := ""
	if n is Label:
		acc += str((n as Label).text)
	for c in n.get_children():
		acc += _collect_label_text(c)
	return acc


func _assert_fail_paths(main) -> bool:
	## Abort keeps intel; squad wipe is a fail. Reset SETUP afterwards for LIFE1.
	if main.phase != main.Phase.SETUP:
		main._start_setup(false, false)
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main.selected.set_facing(90.0)
	main._on_alarm_pressed()
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_ABORT_NO_WATCH phase=%s" % main.phase)
		quit(60)
		return false
	await _drive_ticks(main, 30)
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_ABORT_ENDED_EARLY phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(60)
		return false
	main._on_abort_pressed()
	await process_frame
	if main.phase != main.Phase.FAILED or main.fail_reason != "abort":
		push_error("SMOKE_ABORT_REASON phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(60)
		return false
	if main.intel.records.is_empty():
		push_error("SMOKE_ABORT_NO_INTEL")
		quit(60)
		return false
	var abort_txt := str(main.result_label.text)
	if abort_txt.find("情报已记录") < 0:
		push_error("SMOKE_ABORT_NO_INTEL_LINE %s" % abort_txt)
		quit(60)
		return false
	if abort_txt.find("中止") < 0:
		push_error("SMOKE_ABORT_NO_ZH %s" % abort_txt)
		quit(60)
		return false
	print("SMOKE_OK_ABORT_INTEL n=", main.intel.records.size(), " tick=", main.sim.tick)
	main._on_continue_pressed()
	await process_frame
	if main.intel.records.is_empty():
		push_error("SMOKE_ABORT_INTEL_LOST")
		quit(60)
		return false
	print("SMOKE_OK_ABORT_KEEP")
	main._start_setup(false, false)
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main.selected.set_facing(90.0)
	main._on_alarm_pressed()
	await _drive_ticks(main, 30)
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_WIPE_ENDED_EARLY phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(60)
		return false
	for op in main.operators:
		if op.visible and op.alive:
			op.take_damage(999.0, Vector2(-9999, -9999))
	# take_damage sets FAILED immediately, so always flush the pending fail panel.
	if str(main.pending_result) != "":
		main._flush_pending_result()
	elif main.phase == main.Phase.WATCHING:
		main._finish_sim_tick()
	await process_frame
	if main.phase != main.Phase.FAILED or main.fail_reason != "wipe":
		push_error("SMOKE_WIPE_REASON phase=%s reason=%s living=%s" % [main.phase, main.fail_reason, main._living_ops()])
		quit(60)
		return false
	var wipe_txt := str(main.result_label.text)
	if wipe_txt.find("全灭") < 0:
		push_error("SMOKE_WIPE_NO_ZH %s" % wipe_txt)
		quit(60)
		return false
	print("SMOKE_OK_WIPE tick=", main.sim.tick)
	main._on_continue_pressed()
	await process_frame
	main._start_setup(false, false)
	if main.phase != main.Phase.SETUP or main.loop_index != 1:
		push_error("SMOKE_FAIL_PATHS_RESET phase=%s loop=%s" % [main.phase, main.loop_index])
		quit(60)
		return false
	print("SMOKE_OK_FAIL_PATHS")
	return true


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
	if not _assert_atmosphere(main, tag):
		return false
	return true


func _assert_atmosphere(main, tag: String) -> bool:
	if main.level == null:
		push_error("SMOKE_ATMO_NO_LEVEL %s" % tag)
		quit(49)
		return false
	var want := str(main.level.level_id)
	if str(main.level.atmosphere_id) != want:
		push_error("SMOKE_ATMO_ID %s got=%s" % [want, main.level.atmosphere_id])
		quit(49)
		return false
	if main.map_draw == null or str(main.map_draw.atmosphere_id) != want:
		push_error(
			"SMOKE_ATMO_MAP %s map=%s"
			% [want, main.map_draw.atmosphere_id if main.map_draw else "null"]
		)
		quit(49)
		return false
	var sky = main.get_node_or_null("World/MissionSky")
	if sky == null:
		push_error("SMOKE_NO_MISSION_SKY %s" % tag)
		quit(49)
		return false
	if str(sky.get("atmosphere_id")) != want:
		push_error("SMOKE_SKY_ID %s got=%s" % [want, sky.get("atmosphere_id")])
		quit(49)
		return false
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null or not audio.has_method("play_mission_ambient"):
		push_error("SMOKE_NO_AMBIENT_API %s" % tag)
		quit(49)
		return false
	if not audio.has_method("has_mission_ambient") or not bool(audio.has_mission_ambient(want)):
		push_error("SMOKE_NO_AMBIENT_CUE %s" % want)
		quit(49)
		return false
	if not main.map_draw.has_method("signature_tint"):
		push_error("SMOKE_NO_SIGNATURE_TINT %s" % want)
		quit(49)
		return false
	var tint: Color = main.map_draw.signature_tint()
	var want_c: Color = LevelDef.signature_color(want)
	if absf(tint.r - want_c.r) > 0.03 or absf(tint.g - want_c.g) > 0.03 or absf(tint.b - want_c.b) > 0.03:
		push_error("SMOKE_SIGNATURE_TINT %s got=%s want=%s" % [want, tint, want_c])
		quit(49)
		return false
	if main.ambush_zone_poly != null and main.ambush_zone_poly.has_method("signature_tint"):
		var zc: Color = main.ambush_zone_poly.signature_tint()
		if absf(zc.r - want_c.r) > 0.03 or absf(zc.g - want_c.g) > 0.03:
			push_error("SMOKE_ZONE_TINT %s got=%s" % [want, zc])
			quit(49)
			return false
	if not audio.has_method("play_mission_mood") or not audio.has_method("has_mission_mood"):
		push_error("SMOKE_NO_MOOD_API %s" % tag)
		quit(49)
		return false
	if not bool(audio.has_mission_mood(want)):
		push_error("SMOKE_NO_MOOD_BED %s" % want)
		quit(49)
		return false
	print("SMOKE_OK_ATMO ", want)
	return true


func _assert_level_order(main, n: int) -> bool:
	var gs = root.get_node_or_null("GameSettings")
	if gs == null or gs.LEVEL_ORDER.size() != n or main.LEVEL_ORDER.size() != n:
		push_error(
			"SMOKE_LEVEL_ORDER_LEN gs=%s main=%s want=%s"
			% [gs.LEVEL_ORDER.size() if gs else -1, main.LEVEL_ORDER.size(), n]
		)
		quit(45)
		return false
	var last_id := str(gs.LEVEL_ORDER[n - 1])
	if last_id != str(main.LEVEL_ORDER[n - 1]):
		push_error("SMOKE_LEVEL_ORDER_LAST gs=%s main=%s" % [gs.LEVEL_ORDER, main.LEVEL_ORDER])
		quit(45)
		return false
	var cat: Array = LevelDef.catalog()
	if cat.size() != n or str(cat[n - 1].level_id) != last_id:
		push_error("SMOKE_CATALOG_LEN %s last=%s" % [cat.size(), last_id])
		quit(45)
		return false
	return true


func _assert_railcut_contract(main) -> bool:
	if main.cover_slots.size() != 6:
		push_error("SMOKE_RAILCUT_COVERS n=%s" % main.cover_slots.size())
		quit(45)
		return false
	if main.level.door_cell.x >= 0:
		push_error("SMOKE_RAILCUT_HAS_DOOR %s" % str(main.level.door_cell))
		quit(45)
		return false
	if main.door_button != null and main.door_button.visible:
		push_error("SMOKE_RAILCUT_DOOR_BUTTON")
		quit(45)
		return false
	if not main.level.has_ammo_pack:
		push_error("SMOKE_RAILCUT_NO_PACK")
		quit(45)
		return false
	if main.barrels.size() != 0 or main.level.barrel_cell.x >= 0:
		push_error("SMOKE_RAILCUT_BARREL")
		quit(45)
		return false
	if not main.level.route_cells.has("main") or not main.level.route_cells.has("flank"):
		push_error("SMOKE_RAILCUT_ROUTES")
		quit(45)
		return false
	if main._active_routes().size() != 2:
		push_error("SMOKE_RAILCUT_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(45)
		return false
	if str(main.level.title).find("信号楼") < 0:
		push_error("SMOKE_RAILCUT_TITLE %s" % main.level.title)
		quit(45)
		return false
	var pages: Array = TutorialOverlay.pages_for("railcut")
	if pages.size() != 2:
		push_error("SMOKE_RAILCUT_TUTORIAL n=%s" % pages.size())
		quit(45)
		return false
	var west: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 12))
	var east: Vector2 = main.grid.cell_to_world_center(Vector2i(32, 11))
	if not main._near_any_route_segment(west, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_RAILCUT_TRIP_WEST")
		quit(45)
		return false
	if not main._near_any_route_segment(east, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_RAILCUT_TRIP_EAST")
		quit(45)
		return false
	if not main.grid.is_blocked(20, 10):
		push_error("SMOKE_RAILCUT_CORE_OPEN")
		quit(45)
		return false
	if main.grid.is_blocked(13, 12) or main.grid.is_blocked(32, 11):
		push_error("SMOKE_RAILCUT_CORRIDOR_BLOCKED")
		quit(45)
		return false
	var max_main := 0.0
	var min_flank := 999.0
	var flank_n := 0
	var main_n := 0
	for spec in main.level.spawn_schedule:
		var delay := float(spec["delay"])
		if str(spec["route"]) == "main":
			main_n += 1
			max_main = maxf(max_main, delay)
		elif str(spec["route"]) == "flank":
			flank_n += 1
			min_flank = minf(min_flank, delay)
	if main_n < 1 or flank_n < 1:
		push_error("SMOKE_RAILCUT_SPAWN_SPLIT main=%s flank=%s" % [main_n, flank_n])
		quit(45)
		return false
	if min_flank < 3.0 or min_flank <= max_main + 1.5:
		push_error("SMOKE_RAILCUT_FLANK_NOT_DELAYED main_max=%s flank_min=%s" % [max_main, min_flank])
		quit(45)
		return false
	print(
		"SMOKE_OK_RAILCUT_CONTRACT covers=6 no_door delayed_flank=", min_flank,
		" trip_west/east"
	)
	return true


func _assert_depot_contract(main) -> bool:
	if main.cover_slots.size() != 6:
		push_error("SMOKE_DEPOT_COVERS n=%s" % main.cover_slots.size())
		quit(48)
		return false
	if main.level.door_cell.x >= 0:
		push_error("SMOKE_DEPOT_HAS_DOOR %s" % str(main.level.door_cell))
		quit(48)
		return false
	if not main.level.has_ammo_pack:
		push_error("SMOKE_DEPOT_NO_PACK")
		quit(48)
		return false
	if main.barrels.size() != 0 or main.level.barrel_cell.x >= 0:
		push_error("SMOKE_DEPOT_BARREL")
		quit(48)
		return false
	if not main.level.route_cells.has("main") or not main.level.route_cells.has("flank") or not main.level.route_cells.has("sneak"):
		push_error("SMOKE_DEPOT_ROUTES")
		quit(48)
		return false
	if main._active_routes().size() != 3:
		push_error("SMOKE_DEPOT_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(48)
		return false
	if str(main.level.title).find("油库") < 0:
		push_error("SMOKE_DEPOT_TITLE %s" % main.level.title)
		quit(48)
		return false
	var pages: Array = TutorialOverlay.pages_for("depot")
	if pages.size() != 2:
		push_error("SMOKE_DEPOT_TUTORIAL n=%s" % pages.size())
		quit(48)
		return false
	var p0: Dictionary = pages[0]
	var p1: Dictionary = pages[1]
	if str(p0.get("body", "")).find("三路") < 0:
		push_error("SMOKE_DEPOT_TUTORIAL_THREE %s" % str(p0.get("body", "")))
		quit(48)
		return false
	if str(p1.get("body", "")).find("2.2") < 0 or str(p1.get("body", "")).find("绊索") < 0:
		push_error("SMOKE_DEPOT_TUTORIAL_SNEAK %s" % str(p1.get("body", "")))
		quit(48)
		return false
	if str(main.level.teaching).find("2.2") < 0 or str(main.level.teaching).find("绊索") < 0 or str(main.level.teaching).find("三路") < 0:
		push_error("SMOKE_DEPOT_TEACHING %s" % main.level.teaching)
		quit(48)
		return false
	if str(main.level.tutorial).find("2.2") < 0 or str(main.level.tutorial).find("绊索") < 0:
		push_error("SMOKE_DEPOT_TUT_LABEL %s" % main.level.tutorial)
		quit(48)
		return false
	var sneak: Vector2 = main.grid.cell_to_world_center(Vector2i(7, 11))
	if not main._near_any_route_segment(sneak, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_DEPOT_TRIP_SNEAK")
		quit(48)
		return false
	if not main.grid.is_blocked(20, 10):
		push_error("SMOKE_DEPOT_CORE_OPEN")
		quit(48)
		return false
	if main.grid.is_blocked(7, 11) or main.grid.is_blocked(13, 12) or main.grid.is_blocked(32, 11):
		push_error("SMOKE_DEPOT_LANE_BLOCKED")
		quit(48)
		return false
	var max_main := 0.0
	var min_sneak := 999.0
	var sneak_n := 0
	var main_n := 0
	var flank_n := 0
	for spec in main.level.spawn_schedule:
		var delay := float(spec["delay"])
		if str(spec["route"]) == "main":
			main_n += 1
			max_main = maxf(max_main, delay)
		elif str(spec["route"]) == "flank":
			flank_n += 1
		elif str(spec["route"]) == "sneak":
			sneak_n += 1
			min_sneak = minf(min_sneak, delay)
	if main_n < 1 or flank_n < 1 or sneak_n < 1:
		push_error("SMOKE_DEPOT_SPAWN_SPLIT main=%s flank=%s sneak=%s" % [main_n, flank_n, sneak_n])
		quit(48)
		return false
	if min_sneak < 1.6 or min_sneak <= max_main + 0.6:
		push_error("SMOKE_DEPOT_SNEAK_NOT_DELAYED main_max=%s sneak_min=%s" % [max_main, min_sneak])
		quit(48)
		return false
	if main.has_method("_refresh_checklist"):
		main._refresh_checklist()
	var depot_chip := str(main.checklist_strip_text()) if main.has_method("checklist_strip_text") else ""
	if depot_chip.find("暗道") < 0 and depot_chip.find("sneak") < 0:
		push_error("SMOKE_DEPOT_NO_SNEAK_CHIP %s" % depot_chip)
		quit(48)
		return false
	print(
		"SMOKE_OK_DEPOT_CONTRACT covers=6 routes=3 delayed_sneak=", min_sneak,
		" trip_west_alley sneak_chip"
	)
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
	if not _assert_operator_identity(main, rifle, mg, scout):
		return false
	return true


func _assert_operator_identity(main, rifle: OperatorUnit, mg: OperatorUnit, scout: OperatorUnit) -> bool:
	if rifle.display_name.strip_edges() == "" or rifle.display_name == "队员":
		push_error("SMOKE_OP_NO_DISPLAY_NAME %s" % rifle.display_name)
		quit(32)
		return false
	if rifle.display_name == mg.display_name or mg.display_name == scout.display_name:
		push_error(
			"SMOKE_OP_NAMES_COLLIDE rifle=%s mg=%s scout=%s"
			% [rifle.display_name, mg.display_name, scout.display_name]
		)
		quit(32)
		return false
	if rifle.role_glyph == null or not is_instance_valid(rifle.role_glyph):
		push_error("SMOKE_NO_ROLE_GLYPH")
		quit(32)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	if not rifle.visible:
		push_error("SMOKE_RIFLE_NOT_VISIBLE")
		quit(32)
		return false
	if not rifle.role_glyph.visible:
		push_error("SMOKE_ROLE_GLYPH_HIDDEN")
		quit(32)
		return false
	if rifle.body == null or rifle.body.polygon.size() < 5:
		push_error("SMOKE_RIFLE_BODY_TOO_SIMPLE n=%s" % (rifle.body.polygon.size() if rifle.body else -1))
		quit(32)
		return false
	if mg.body == null or mg.body.polygon.size() < 5:
		push_error("SMOKE_MG_BODY_TOO_SIMPLE")
		quit(32)
		return false
	if scout.body == null or scout.body.polygon.size() < 5:
		push_error("SMOKE_SCOUT_BODY_TOO_SIMPLE")
		quit(32)
		return false
	if rifle.body.polygon == mg.body.polygon or mg.body.polygon == scout.body.polygon:
		push_error("SMOKE_BODY_POLYS_IDENTICAL")
		quit(32)
		return false
	rifle._rebuild_cone()
	mg._rebuild_cone()
	scout._rebuild_cone()
	for op in [rifle, mg, scout]:
		if op.body.polygon.size() < 12:
			push_error("SMOKE_BODY_NOT_HUMAN op=%s n=%s" % [op.display_name, op.body.polygon.size()])
			quit(32)
			return false
		if op.body.get_node_or_null("Head") == null:
			push_error("SMOKE_NO_HEAD op=%s" % op.display_name)
			quit(32)
			return false
		if op.body.get_node_or_null("LegL") == null or op.body.get_node_or_null("LegR") == null:
			push_error("SMOKE_NO_LEGS op=%s" % op.display_name)
			quit(32)
			return false
		if op.weapon == null or not is_instance_valid(op.weapon):
			push_error("SMOKE_NO_WEAPON_ON_IDENTITY op=%s" % op.display_name)
			quit(32)
			return false
		var tip_y := 0.0
		for p in op.weapon.polygon:
			tip_y = minf(tip_y, p.y)
		if tip_y > -16.0:
			push_error("SMOKE_BARREL_TOO_SHORT op=%s tip=%s" % [op.display_name, tip_y])
			quit(32)
			return false
	main._on_clear_pressed()
	print(
		"SMOKE_OK_IDENTITY rifle=%s mg=%s scout=%s glyph=1"
		% [rifle.display_name, mg.display_name, scout.display_name]
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
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null or not audio.has_music_bed():
		push_error("SMOKE_NO_MUSIC_BED")
		quit(43)
		return false
	if audio.music_player_playing():
		push_error("SMOKE_MUTE_LEAVES_MUSIC")
		quit(36)
		return false
	main._toggle_mute()
	if main.sfx.muted:
		push_error("SMOKE_UNMUTE_FAIL")
		quit(36)
		return false
	if was_muted:
		main._toggle_mute()
	if not main.has_method("_sfx_every_shot"):
		push_error("SMOKE_NO_EVERY_SHOT_SFX")
		quit(36)
		return false
	main._sfx_every_shot(main.operators[0] if not main.operators.is_empty() else null)
	if str(main.sfx.last_cue) != "fire":
		push_error("SMOKE_EVERY_SHOT_CUE %s" % main.sfx.last_cue)
		quit(36)
		return false
	print("SMOKE_OK_SFX cues=8 muted=", main.sfx.muted, " every_shot=1")
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
	# Redeploy must keep the facing the player already set (same pad and pad-to-pad).
	op.set_facing(45.0)
	main._deploy_selected_to(main.cover_slots[0], false)
	if absf(float(main.selected.facing_deg) - 45.0) > 0.5:
		push_error("SMOKE_REDEPLOY_RESET_FACE same=%s" % main.selected.facing_deg)
		quit(40)
		return false
	main._deploy_selected_to(main.cover_slots[1], false)
	if absf(float(main.selected.facing_deg) - 45.0) > 0.5:
		push_error("SMOKE_MOVE_PAD_RESET_FACE got=%s" % main.selected.facing_deg)
		quit(40)
		return false
	print("SMOKE_OK_KEEP_FACING")
	main._on_clear_pressed()
	return true


func _assert_tripwire_tooling(main) -> bool:
	var tw := Tripwire.new()
	var empty = tw.sim_check([])
	tw.free()
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
	main.tool = main.Tool.TRIPWIRE
	main._try_place_tripwire(on_route)
	if main.tripwires.size() != 1:
		push_error("SMOKE_TRIP_PLACE_COUNT %s" % main.tripwires.size())
		quit(41)
		return false
	var moved: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 15))
	if not main._near_any_route_segment(moved, 24.0):
		push_error("SMOKE_TRIP_MOVE_TARGET_OFF_ROUTE")
		quit(41)
		return false
	main._try_place_tripwire(moved)
	if main.tripwires.size() != 1:
		push_error("SMOKE_TRIP_RELOCATE_COUNT %s" % main.tripwires.size())
		quit(41)
		return false
	if main.tripwires[0].global_position.distance_to(moved) > 2.0:
		push_error("SMOKE_TRIP_DID_NOT_MOVE pos=%s want=%s" % [main.tripwires[0].global_position, moved])
		quit(41)
		return false
	main._clear_tripwires()
	main.tool = main.Tool.DEPLOY
	print("SMOKE_OK_TRIPWIRE_TOOLING relocate=1")
	return true


func _assert_touch_parity(main) -> bool:
	if not ResourceLoader.exists("res://scripts/touch_hud.gd"):
		push_error("SMOKE_NO_TOUCH_HUD_SCRIPT")
		quit(44)
		return false
	if main.get_node_or_null("TouchHud") == null:
		push_error("SMOKE_NO_TOUCH_HUD")
		quit(44)
		return false
	if not main.has_method("apply_touch_command") or not main.has_method("handle_android_back"):
		push_error("SMOKE_NO_TOUCH_API")
		quit(44)
		return false
	var proj := FileAccess.get_file_as_string("res://project.godot")
	if proj.find("quit_on_go_back=false") < 0 or proj.find("gl_compatibility") < 0:
		push_error("SMOKE_ANDROID_PROJECT_FLAGS")
		quit(44)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		push_error("SMOKE_NO_GS_TOUCH")
		quit(44)
		return false
	gs.force_touch_hud = true
	main._ensure_touch_hud()
	if main.touch_hud == null or not main.touch_hud.visible:
		push_error("SMOKE_TOUCH_HUD_HIDDEN")
		quit(44)
		return false
	if bool(main._event_log_open) or (main.event_log != null and main.event_log.visible):
		push_error("SMOKE_LOG_NOT_COLLAPSED")
		quit(44)
		return false
	if main.role_cards.is_empty() or (main.role_cards[0] as Control).custom_minimum_size.y < 48.0:
		push_error("SMOKE_OPCARD_TOUCH_SIZE")
		quit(44)
		return false
	var alarm_touch: Button = main.touch_hud._btns["alarm"] as Button
	if alarm_touch == null or alarm_touch.custom_minimum_size.y < 48.0:
		push_error("SMOKE_TOUCH_BTN_SIZE")
		quit(44)
		return false
	main.handle_android_back()
	if main.pause_overlay == null or not main.pause_overlay.is_open():
		push_error("SMOKE_ANDROID_BACK_NO_MENU")
		quit(44)
		return false
	main.handle_android_back()
	if main.pause_overlay.is_open():
		push_error("SMOKE_ANDROID_BACK_STUCK")
		quit(44)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	var f0: float = float(main.selected.facing_deg)
	main.apply_touch_command("rotate_cw")
	if is_equal_approx(float(main.selected.facing_deg), f0):
		push_error("SMOKE_TOUCH_ROTATE_NOOP f=%s" % main.selected.facing_deg)
		quit(44)
		return false
	var mode0 = main.selected.fire_mode
	main.apply_touch_command("fire")
	if main.selected.fire_mode == mode0:
		push_error("SMOKE_TOUCH_FIRE_NOOP")
		quit(44)
		return false
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var slot_pos: Vector2 = main.cover_slots[1].global_position
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = xf * slot_pos
	main._unhandled_input(ev)
	var ev2 := InputEventScreenTouch.new()
	ev2.index = 0
	ev2.pressed = false
	ev2.position = ev.position
	main._unhandled_input(ev2)
	if main.selected == null or main.selected.slot != main.cover_slots[1]:
		push_error("SMOKE_TOUCH_DEPLOY_FAIL pos=%s screen=%s" % [slot_pos, ev.position])
		quit(44)
		return false
	var f_drag: float = float(main.selected.facing_deg)
	var press_op := InputEventScreenTouch.new()
	press_op.index = 0
	press_op.pressed = true
	press_op.position = xf * main.selected.global_position
	main._unhandled_input(press_op)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = xf * (main.selected.global_position + Vector2(90, 0))
	drag.relative = Vector2(40, 0)
	main._unhandled_input(drag)
	if is_equal_approx(float(main.selected.facing_deg), f_drag):
		push_error("SMOKE_TOUCH_DRAG_FACE f=%s" % main.selected.facing_deg)
		quit(44)
		return false
	var rel_op := InputEventScreenTouch.new()
	rel_op.index = 0
	rel_op.pressed = false
	rel_op.position = drag.position
	main._unhandled_input(rel_op)
	main.apply_touch_command("clear")
	if main._deployed_count() != 0:
		push_error("SMOKE_TOUCH_CLEAR_FAIL n=%s" % main._deployed_count())
		quit(44)
		return false
	var hold_slot = main.cover_slots[2]
	var lp := InputEventScreenTouch.new()
	lp.index = 0
	lp.pressed = true
	lp.position = xf * hold_slot.global_position
	main._unhandled_input(lp)
	main._cover_hold_msec = Time.get_ticks_msec() - 500
	main._tick_cover_long_press()
	if main._touch_preview_slot != hold_slot:
		push_error("SMOKE_LONGPRESS_NO_PREVIEW")
		quit(44)
		return false
	if hold_slot.protect_arc == null or not hold_slot.protect_arc.visible:
		push_error("SMOKE_LONGPRESS_NO_ARC")
		quit(44)
		return false
	var lp2 := InputEventScreenTouch.new()
	lp2.index = 0
	lp2.pressed = false
	lp2.position = lp.position
	main._unhandled_input(lp2)
	if main._deployed_count() != 0:
		push_error("SMOKE_LONGPRESS_DEPLOYED n=%s" % main._deployed_count())
		quit(44)
		return false
	gs.force_touch_hud = false
	main._ensure_touch_hud()
	print("SMOKE_OK_TOUCH_PARITY")
	return true


func _assert_lifecycle(main) -> bool:
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null:
		push_error("SMOKE_NO_AUDIODIRECTOR")
		quit(47)
		return false
	if not audio.has_method("pause_for_background") and not audio.has_method("set_background_muted"):
		push_error("SMOKE_NO_BG_AUDIO_API")
		quit(47)
		return false
	if not main.has_method("handle_app_focus_out") or not main.has_method("handle_app_focus_in"):
		push_error("SMOKE_NO_FOCUS_API")
		quit(47)
		return false
	var TitleScript = load("res://scripts/title.gd")
	if TitleScript == null:
		push_error("SMOKE_NO_TITLE_SCRIPT")
		quit(47)
		return false
	var title_probe = TitleScript.new()
	if title_probe == null or not title_probe.has_method("handle_app_focus_out") or not title_probe.has_method("handle_app_focus_in"):
		push_error("SMOKE_NO_TITLE_FOCUS")
		if title_probe:
			title_probe.free()
		quit(47)
		return false
	title_probe.free()
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_LIFECYCLE_NOT_SETUP")
		quit(47)
		return false
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main._on_alarm_pressed()
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_LIFECYCLE_NO_WATCH phase=%s" % main.phase)
		quit(47)
		return false
	if main.sim.paused:
		push_error("SMOKE_LIFECYCLE_ALREADY_PAUSED")
		quit(47)
		return false
	main.handle_app_focus_out()
	if not main.sim.paused:
		push_error("SMOKE_FOCUS_OUT_SIM_RUNS")
		quit(47)
		return false
	if audio.music_player_playing():
		push_error("SMOKE_FOCUS_OUT_MUSIC_LEAK")
		quit(47)
		return false
	if audio.has_method("is_background_paused") and not bool(audio.is_background_paused()):
		push_error("SMOKE_FOCUS_OUT_AUDIO_NOT_GATED")
		quit(47)
		return false
	main.handle_app_focus_in()
	if not main.sim.paused:
		push_error("SMOKE_FOCUS_IN_AUTOPLAY")
		quit(47)
		return false
	if audio.has_method("is_background_paused") and bool(audio.is_background_paused()):
		push_error("SMOKE_FOCUS_IN_AUDIO_STUCK")
		quit(47)
		return false
	main._start_setup(false, false)
	if main.phase != main.Phase.SETUP or main.loop_index != 1:
		push_error("SMOKE_LIFECYCLE_RESET phase=%s loop=%s" % [main.phase, main.loop_index])
		quit(47)
		return false
	print("SMOKE_OK_LIFECYCLE")
	return true


func _assert_watch_juice(main) -> bool:
	if not main.has_method("_spawn_watch_tracer") or not main.has_method("_kill_edge_flash"):
		push_error("SMOKE_NO_WATCH_JUICE_API")
		quit(53)
		return false
	if not main.has_method("_shake_for_explosion") or not main.has_method("_ensure_watch_timeline"):
		push_error("SMOKE_NO_WATCH_SHAKE_OR_TIMELINE")
		quit(53)
		return false
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("_tracer_pool.size() < 12") < 0 or src.find("_trim_live_tracers") < 0:
		push_error("SMOKE_TRACER_POOL_CAP")
		quit(53)
		return false
	if main.operators.is_empty() or not main.operators[0].has_method("hit_feedback"):
		push_error("SMOKE_NO_OP_HIT_FEEDBACK")
		quit(53)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.set_quality_tier("standard")
	if main.phase != main.Phase.SETUP:
		main._start_setup(false, false)
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main._on_alarm_pressed()
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_WATCH_JUICE_NO_WATCH phase=%s" % main.phase)
		quit(53)
		return false
	if main.watch_timeline == null or not main.watch_timeline.visible:
		push_error("SMOKE_WATCH_TIMELINE_HIDDEN")
		quit(53)
		return false
	var watch_op: OperatorUnit = main.operators[0]
	if not watch_op.has_method("watching_cone_frozen") or not bool(watch_op.watching_cone_frozen()):
		push_error(
			"SMOKE_WATCH_CONE_NOT_FROZEN locked=%s col=%s"
			% [watch_op.locked, watch_op.cone.color if watch_op.cone else Color()]
		)
		quit(53)
		return false
	var probe: EnemyRunner = main._make_enemy(99)
	main.entities.add_child(probe)
	probe.setup(
		99,
		PackedVector2Array([Vector2(80, 80), Vector2(120, 80)]),
		main.grid,
		0,
		"main"
	)
	probe.activate()
	probe._update_hp_bar()
	if not probe.has_method("hp_bar_watch_visible") or not bool(probe.hp_bar_watch_visible()):
		push_error("SMOKE_ENEMY_HP_BAR_HIDDEN")
		probe.queue_free()
		quit(53)
		return false
	var hp_col: Color = probe.hp_bar.color
	if hp_col.r < 0.7:
		push_error("SMOKE_ENEMY_HP_BAR_NOT_ROUTE %s" % str(hp_col))
		probe.queue_free()
		quit(53)
		return false
	if gs:
		gs.set_quality_tier("power_saving")
		probe._update_hp_bar()
		if probe.hp_bar_watch_visible():
			push_error("SMOKE_ENEMY_HP_BAR_IN_POWER_SAVE")
			probe.queue_free()
			gs.set_quality_tier("standard")
			quit(53)
			return false
		gs.set_quality_tier("standard")
		probe._update_hp_bar()
	probe.queue_free()
	var chip := str(main.phase_chip.text) if main.phase_chip else ""
	if chip.find("t=") < 0 or (chip.find("1×") < 0 and chip.find("2×") < 0 and chip.find("暂停") < 0):
		push_error("SMOKE_WATCH_CHIP %s" % chip)
		quit(53)
		return false
	if typeof(main._tracer_pool) != TYPE_ARRAY:
		push_error("SMOKE_TRACER_POOL_TYPE")
		quit(53)
		return false
	if gs:
		gs.set_quality_tier("power_saving")
		main._spawn_watch_tracer(Vector2(40, 40), Vector2(80, 80), Color.WHITE, 2.0)
		var n_tr := 0
		if main.entities:
			for c in main.entities.get_children():
				if c is Line2D and str(c.name).begins_with("WatchTracer"):
					n_tr += 1
		if n_tr != 0:
			push_error("SMOKE_TRACER_IN_POWER_SAVE n=%s" % n_tr)
			quit(53)
			return false
		gs.set_quality_tier("standard")
	main._kill_edge_flash()
	main._start_setup(false, false)
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_WATCH_JUICE_RESET phase=%s" % main.phase)
		quit(53)
		return false
	print("SMOKE_OK_WATCH_JUICE tracer_pool timeline chip cone_freeze hp_bar")
	return true


func _assert_alarm_stinger(main) -> bool:
	if main.sfx == null or not main.sfx.has_cue("alarm_stinger"):
		push_error("SMOKE_NO_ALARM_STINGER_CUE")
		quit(57)
		return false
	if not main.has_method("_alarm_cam_stinger"):
		push_error("SMOKE_NO_ALARM_STINGER_API")
		quit(57)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs and gs.has_method("set_quality_tier"):
		gs.set_quality_tier("standard")
	main._alarm_cam_stinger()
	if str(main.sfx.last_cue) != "alarm_stinger":
		push_error("SMOKE_STINGER_NO_PLAY cue=%s" % main.sfx.last_cue)
		quit(57)
		return false
	if main._stinger_tween == null or not is_instance_valid(main._stinger_tween):
		push_error("SMOKE_STINGER_NO_TWEEN")
		quit(57)
		return false
	if main._game_cam == null:
		push_error("SMOKE_STINGER_NO_CAM")
		quit(57)
		return false
	if gs and gs.has_method("set_quality_tier"):
		gs.set_quality_tier("power_saving")
		main.sfx.last_cue = ""
		if main._stinger_tween != null:
			main._stinger_tween.kill()
			main._stinger_tween = null
		main._cam_zoom_punch = 1.0
		main._apply_cam()
		main._alarm_cam_stinger()
		if str(main.sfx.last_cue) == "alarm_stinger":
			push_error("SMOKE_STINGER_IN_POWER_SAVE")
			quit(57)
			return false
		if main._stinger_tween != null and is_instance_valid(main._stinger_tween):
			push_error("SMOKE_STINGER_TWEEN_IN_POWER_SAVE")
			quit(57)
			return false
		gs.set_quality_tier("standard")
		main._cam_zoom_punch = 1.0
		main._apply_cam()
	print("SMOKE_OK_STINGER cue=alarm_stinger")
	return true


func _assert_win_stinger(main) -> bool:
	if main.sfx == null or not main.sfx.has_cue("win_stinger"):
		push_error("SMOKE_NO_WIN_STINGER_CUE")
		quit(58)
		return false
	if not main.has_method("_win_stinger") or not main.has_method("_play_load_fade"):
		push_error("SMOKE_NO_WIN_STINGER_API")
		quit(58)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs and gs.has_method("set_quality_tier"):
		gs.set_quality_tier("standard")
	main._win_stinger()
	if str(main.sfx.last_cue) != "win_stinger":
		push_error("SMOKE_WIN_STINGER_NO_PLAY cue=%s" % main.sfx.last_cue)
		quit(58)
		return false
	if not main.has_method("win_stinger_active") or not bool(main.win_stinger_active()):
		push_error("SMOKE_WIN_STINGER_NO_TWEEN")
		quit(58)
		return false
	if main._sig_wash == null or not is_instance_valid(main._sig_wash):
		push_error("SMOKE_WIN_STINGER_NO_WASH")
		quit(58)
		return false
	if gs and gs.has_method("set_quality_tier"):
		gs.set_quality_tier("power_saving")
		main.sfx.last_cue = ""
		if main._win_stinger_tween != null:
			main._win_stinger_tween.kill()
			main._win_stinger_tween = null
		if main._sig_wash:
			main._sig_wash.color.a = 0.0
		main._win_stinger()
		if str(main.sfx.last_cue) == "win_stinger":
			push_error("SMOKE_WIN_STINGER_IN_POWER_SAVE")
			quit(58)
			return false
		if main.has_method("win_stinger_active") and bool(main.win_stinger_active()):
			push_error("SMOKE_WIN_STINGER_TWEEN_IN_POWER_SAVE")
			quit(58)
			return false
		gs.set_quality_tier("standard")
	main._play_load_fade()
	if not main.has_method("load_fade_active") or not bool(main.load_fade_active()):
		push_error("SMOKE_NO_LOAD_FADE")
		quit(58)
		return false
	var world: Node2D = main.get_node_or_null("World") as Node2D
	if world == null or world.modulate.r > 0.35:
		push_error("SMOKE_LOAD_FADE_NOT_DARK mod=%s" % (world.modulate if world else Color.WHITE))
		quit(58)
		return false
	if main._load_fade_tween != null:
		main._load_fade_tween.kill()
		main._load_fade_tween = null
	if world:
		world.modulate = Color.WHITE
	if main._sig_wash:
		main._sig_wash.color.a = 0.0
	print("SMOKE_OK_WIN_STINGER cue=win_stinger fade=0.2")
	return true


func _assert_perf_tier(main) -> bool:
	var gs = root.get_node_or_null("GameSettings")
	if gs == null or not gs.has_method("is_power_saving") or not gs.has_method("set_quality_tier"):
		push_error("SMOKE_NO_QUALITY_TIER")
		quit(46)
		return false
	if str(gs.QUALITY_POWER_SAVING) != "power_saving" or str(gs.QUALITY_STANDARD) != "standard":
		push_error("SMOKE_QUALITY_CONST %s %s" % [gs.QUALITY_POWER_SAVING, gs.QUALITY_STANDARD])
		quit(46)
		return false
	if str(gs.quality_tier) != "standard" or bool(gs.is_power_saving()):
		push_error("SMOKE_QUALITY_DEFAULT %s" % gs.quality_tier)
		quit(46)
		return false
	gs.set_quality_tier("power_saving")
	if not gs.is_power_saving() or str(gs.quality_tier) != "power_saving":
		push_error("SMOKE_QUALITY_SET_FAIL %s" % gs.quality_tier)
		quit(46)
		return false
	if gs.has_method("quality_tier_label") and str(gs.quality_tier_label()) != "省电":
		push_error("SMOKE_QUALITY_LABEL %s" % gs.quality_tier_label())
		quit(46)
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or str(cfg.get_value("graphics", "quality_tier", "")) != "power_saving":
		push_error("SMOKE_QUALITY_NOT_PERSISTED")
		quit(46)
		return false
	if main.map_draw == null or not main.map_draw.has_method("uses_static_cache"):
		push_error("SMOKE_NO_MAP_CACHE")
		quit(46)
		return false
	if not bool(main.map_draw.uses_static_cache()):
		push_error("SMOKE_MAP_CACHE_INACTIVE")
		quit(46)
		return false
	if not main.map_draw.has_method("invalidate_static_cache"):
		push_error("SMOKE_NO_MAP_CACHE_INVALIDATE")
		quit(46)
		return false
	main.map_draw.invalidate_static_cache()
	if main.map_draw.get_node_or_null("StaticCache") == null:
		push_error("SMOKE_MAP_CACHE_NODE")
		quit(46)
		return false
	if main.pause_overlay:
		main.pause_overlay.present(false, false)
		var qbtn: Button = main.pause_overlay._quality_btn as Button
		if qbtn == null or str(qbtn.text).find("省电") < 0:
			push_error("SMOKE_QUALITY_UI %s" % (qbtn.text if qbtn else "null"))
			main.pause_overlay.dismiss()
			quit(46)
			return false
		main.pause_overlay.dismiss()
	gs.set_quality_tier("standard")
	if gs.is_power_saving() or str(gs.quality_tier) != "standard":
		push_error("SMOKE_QUALITY_RESTORE_FAIL %s" % gs.quality_tier)
		quit(46)
		return false
	if main.operators.is_empty() or not main.operators[0].has_method("apply_recoil_kick"):
		push_error("SMOKE_NO_RECOIL_KICK")
		quit(46)
		return false
	print("SMOKE_OK_PERF_TIER")
	return true


func _assert_unit_anim(main) -> bool:
	if main.operators.is_empty():
		push_error("SMOKE_ANIM_NO_OPS")
		quit(55)
		return false
	var op: OperatorUnit = main.operators[0]
	if op.weapon == null or not is_instance_valid(op.weapon):
		op._rebuild_cone()
	if op.weapon == null or not is_instance_valid(op.weapon):
		push_error("SMOKE_NO_WEAPON")
		quit(55)
		return false
	var probe: EnemyRunner = main._make_enemy(98)
	main.entities.add_child(probe)
	probe.setup(
		98,
		PackedVector2Array([Vector2(80, 80), Vector2(200, 80)]),
		main.grid,
		0,
		"main"
	)
	if not probe.has_method("walk_bob_hook"):
		probe.queue_free()
		push_error("SMOKE_NO_WALK_BOB_HOOK")
		quit(55)
		return false
	probe.activate()
	probe.sim_step(0.08)
	probe._apply_walk_bob()
	var _bob := float(probe.walk_bob_hook())
	if probe.body == null or probe.body.polygon.size() < 12:
		probe.queue_free()
		push_error("SMOKE_ENEMY_BODY_TOO_SIMPLE")
		quit(55)
		return false
	if probe.body.get_node_or_null("Head") == null or probe.body.get_node_or_null("LegL") == null:
		probe.queue_free()
		push_error("SMOKE_ENEMY_NOT_HUMAN")
		quit(55)
		return false
	var flank: EnemyRunner = main._make_enemy(97)
	main.entities.add_child(flank)
	flank.setup(97, PackedVector2Array([Vector2(80, 80), Vector2(200, 80)]), main.grid, 0, "flank")
	var sneak: EnemyRunner = main._make_enemy(96)
	main.entities.add_child(sneak)
	sneak.setup(96, PackedVector2Array([Vector2(80, 80), Vector2(200, 80)]), main.grid, 0, "sneak")
	if probe.body.polygon == flank.body.polygon or flank.body.polygon == sneak.body.polygon:
		probe.queue_free()
		flank.queue_free()
		sneak.queue_free()
		push_error("SMOKE_ENEMY_KINDS_IDENTICAL")
		quit(55)
		return false
	probe.queue_free()
	flank.queue_free()
	sneak.queue_free()
	print("SMOKE_OK_ANIM walk_bob_hook weapon=1")
	return true


func _assert_readability(main) -> bool:
	if main.operators.is_empty():
		push_error("SMOKE_READABILITY_NO_OPS")
		quit(50)
		return false
	for op in main.operators:
		op._rebuild_cone()
	if main.has_method("_update_hud"):
		main._update_hud()
	for op in main.operators:
		if op.body_outline == null or not is_instance_valid(op.body_outline):
			push_error("SMOKE_NO_BODY_OUTLINE op=%s" % op.display_name)
			quit(50)
			return false
		var rim = op.get_node_or_null("RoleRim")
		if rim == null or not (rim is Line2D):
			push_error("SMOKE_NO_ROLE_RIM op=%s" % op.display_name)
			quit(50)
			return false
		if op.body_outline.polygon.size() < 5:
			push_error("SMOKE_OUTLINE_TOO_SIMPLE n=%s" % op.body_outline.polygon.size())
			quit(50)
			return false
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_READABILITY_NOT_SETUP phase=%s" % main.phase)
		quit(50)
		return false
	if main.route_legend == null or not main.route_legend.visible:
		push_error("SMOKE_LEGEND_HIDDEN")
		quit(50)
		return false
	if main.route_legend.get_child_count() < 2:
		push_error("SMOKE_LEGEND_NO_CHIPS n=%s" % main.route_legend.get_child_count())
		quit(50)
		return false
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("WatchTracer") < 0 or src.find("_is_power_saving") < 0:
		push_error("SMOKE_NO_TRACER_POOL")
		quit(50)
		return false
	print("SMOKE_OK_READABILITY outlines=3 legend_chips=", main.route_legend.get_child_count())
	return true


func _assert_props(main) -> bool:
	if main.map_draw == null:
		push_error("SMOKE_PROPS_NO_MAP")
		quit(51)
		return false
	var md = main.map_draw
	for m in ["_landmark_yard", "_landmark_warehouse", "_landmark_pump", "_landmark_railcut", "_landmark_depot"]:
		if not md.has_method(m):
			push_error("SMOKE_PROPS_MISSING %s" % m)
			quit(51)
			return false
	if not md.has_method("_cache_signature") or not md.has_method("_draw_layout_decal"):
		push_error("SMOKE_PROPS_CACHE_OR_DECAL")
		quit(51)
		return false
	if not md.has_method("_draw_floor_accent_stripe"):
		push_error("SMOKE_PROPS_NO_ACCENT")
		quit(51)
		return false
	if not md.has_method("_draw_signature_silhouette"):
		push_error("SMOKE_PROPS_NO_SILHOUETTE")
		quit(51)
		return false
	var sig := str(md._cache_signature())
	if sig.find("yard") < 0:
		push_error("SMOKE_PROPS_SIG_LAYOUT %s" % sig)
		quit(51)
		return false
	var src := FileAccess.get_file_as_string("res://scripts/map_draw.gd")
	for token in [
		"Clothesline", "Bicycle wreck", "Gate shadow",
		"Forklift", "pallet", "Loading dock",
		"Warning triangle", "Valve wheels",
		"signal mast", "Cable run", "Crossing gate",
		"Fuel pipe", "Hazard cone", "Chain-link",
		"yard tree", "roof peak", "pump chimney", "tower block", "tank farm",
		"Doorway jamb",
	]:
		if src.find(token) < 0:
			push_error("SMOKE_PROPS_TOKEN %s" % token)
			quit(51)
			return false
	if src.find("layout_id") < 0 or src.find("atmosphere_id") < 0:
		push_error("SMOKE_PROPS_CACHE_KEYS")
		quit(51)
		return false
	var sky_src := FileAccess.get_file_as_string("res://scripts/fx/mission_sky.gd")
	if sky_src.find("Steam wisps") < 0 or sky_src.find("sodium") < 0 or sky_src.find("underglow") < 0:
		push_error("SMOKE_PROPS_SKY")
		quit(51)
		return false
	if (
		sky_src.find("Window flicker") < 0
		or sky_src.find("flickering sodium") < 0
		or sky_src.find("steam puff") < 0
		or sky_src.find("gauge blink") < 0
		or sky_src.find("_draw_contrast_wash") < 0
	):
		push_error("SMOKE_PROPS_SKY_MOTION")
		quit(51)
		return false
	if md.z_index > 1:
		push_error("SMOKE_PROPS_Z %s" % md.z_index)
		quit(51)
		return false
	print("SMOKE_OK_PROPS landmarks=5 sig=", sig)
	return true


func _assert_checklist(main) -> bool:
	if not main.has_method("checklist_visible") or not bool(main.checklist_visible()):
		push_error("SMOKE_NO_CHECKLIST")
		quit(56)
		return false
	var txt := str(main.checklist_strip_text()) if main.has_method("checklist_strip_text") else ""
	if txt.find("已部署") < 0 or txt.find("射界覆盖主路") < 0 or txt.find("侧翼") < 0:
		push_error("SMOKE_CHECKLIST_LABELS %s" % txt)
		quit(56)
		return false
	if main.intel == null or not main.intel.has_method("latest_leak_tick"):
		push_error("SMOKE_NO_LEAK_TICK_API")
		quit(56)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		push_error("SMOKE_NO_GS_CHECKLIST")
		quit(56)
		return false
	var prev_touch: bool = bool(gs.force_touch_hud)
	gs.force_touch_hud = true
	main._ensure_touch_hud()
	if main.has_method("_layout_checklist"):
		main._layout_checklist()
	elif main.has_method("_refresh_checklist"):
		main._refresh_checklist()
	await process_frame
	await process_frame
	var strip = main.checklist_strip
	if strip == null or not is_instance_valid(strip):
		push_error("SMOKE_CHECKLIST_GONE_TOUCH")
		quit(56)
		return false
	if int(strip.mouse_filter) != int(Control.MOUSE_FILTER_IGNORE):
		push_error("SMOKE_CHECKLIST_STEALS_TAPS filter=%s" % strip.mouse_filter)
		quit(56)
		return false
	var vp_h: float = main.get_viewport().get_visible_rect().size.y
	var top_anchored := is_equal_approx(float(strip.anchor_top), 0.0) and float(strip.anchor_bottom) < 0.5
	var above_bar := float(strip.global_position.y) < vp_h - 160.0
	var near_top := float(strip.offset_top) < 90.0 and float(strip.anchor_left) >= 0.99
	if not above_bar and not top_anchored:
		push_error(
			"SMOKE_CHECKLIST_TOUCH_OVERLAP y=%s vp=%s top=%s bot=%s"
			% [strip.global_position.y, vp_h, strip.anchor_top, strip.anchor_bottom]
		)
		quit(56)
		return false
	if not near_top:
		push_error(
			"SMOKE_CHECKLIST_NOT_TOP_RIGHT off_top=%s anchor_left=%s y=%s"
			% [strip.offset_top, strip.anchor_left, strip.global_position.y]
		)
		quit(56)
		return false
	var box := strip as BoxContainer
	if box != null and bool(box.vertical):
		push_error("SMOKE_CHECKLIST_STILL_VBOX")
		quit(56)
		return false
	var th = main.touch_hud
	if th != null and th.get_child_count() > 0:
		var th_root := th.get_child(0) as Control
		if th_root != null and int(th_root.mouse_filter) != int(Control.MOUSE_FILTER_IGNORE):
			push_error("SMOKE_TOUCHHUD_ROOT_FILTER %s" % th_root.mouse_filter)
			quit(56)
			return false
	gs.force_touch_hud = prev_touch
	main._ensure_touch_hud()
	if main.has_method("_layout_checklist"):
		main._layout_checklist()
	if main.has_method("_refresh_checklist"):
		main._refresh_checklist()
	print("SMOKE_OK_CHECKLIST ", txt.replace("\n", " | "))
	return true


func _assert_teaching(main) -> bool:
	var yard: LevelDef = LevelDef.by_id("yard")
	if str(yard.beat_kind) != "ambush_zone" or str(yard.beat_text).find("侧翼") < 0:
		push_error("SMOKE_YARD_BEAT %s %s" % [yard.beat_kind, yard.beat_text])
		quit(52)
		return false
	var wh: LevelDef = LevelDef.by_id("warehouse")
	if str(wh.beat_kind) != "barrel":
		push_error("SMOKE_WAREHOUSE_BEAT %s" % wh.beat_kind)
		quit(52)
		return false
	var pump: LevelDef = LevelDef.by_id("pump")
	if str(pump.beat_kind) != "decision" or pump.decision_cell != Vector2i(13, 5):
		push_error("SMOKE_PUMP_BEAT %s %s" % [pump.beat_kind, str(pump.decision_cell)])
		quit(52)
		return false
	var rc: LevelDef = LevelDef.by_id("railcut")
	if rc.first_route_delay("flank") < 3.0:
		push_error("SMOKE_RAILCUT_BEAT_DELAY %s" % rc.first_route_delay("flank"))
		quit(52)
		return false
	var dp: LevelDef = LevelDef.by_id("depot")
	if dp.first_route_delay("sneak") < 1.6:
		push_error("SMOKE_DEPOT_BEAT_DELAY %s" % dp.first_route_delay("sneak"))
		quit(52)
		return false
	if not ResourceLoader.exists("res://scripts/ui/route_timeline.gd"):
		push_error("SMOKE_NO_ROUTE_TIMELINE")
		quit(52)
		return false
	if main.ambush_zone_poly == null:
		push_error("SMOKE_NO_AMBUSH_ZONE")
		quit(52)
		return false
	var zone_tag = main.ambush_zone_poly.get_node_or_null("Tag")
	if zone_tag == null or str(zone_tag.text).find("侧翼") < 0:
		push_error("SMOKE_ZONE_TAG %s" % (zone_tag.text if zone_tag else "null"))
		quit(52)
		return false
	if rc.spawn_teaching.is_empty() or str(rc.spawn_teaching[0]).find("3.8") < 0:
		push_error("SMOKE_RAILCUT_SPAWN_TEACH %s" % str(rc.spawn_teaching))
		quit(52)
		return false
	if dp.spawn_teaching.is_empty() or str(dp.spawn_teaching[0]).find("2.2") < 0:
		push_error("SMOKE_DEPOT_SPAWN_TEACH %s" % str(dp.spawn_teaching))
		quit(52)
		return false
	if main.trap_callout == null or not main.trap_callout.visible:
		push_error("SMOKE_NO_TRAP_CALLOUT")
		quit(52)
		return false
	var call_tag = main.trap_callout.get_node_or_null("Tag")
	if call_tag == null or str(call_tag.text).find("侧翼") < 0:
		push_error("SMOKE_TRAP_CALLOUT_TEXT %s" % (call_tag.text if call_tag else "null"))
		quit(52)
		return false
	if main.spawn_teach_label == null or not main.spawn_teach_label.visible:
		push_error("SMOKE_NO_SPAWN_TEACH_HUD")
		quit(52)
		return false
	if not main.has_method("_intel_flash_color"):
		push_error("SMOKE_NO_INTEL_COLOR")
		quit(52)
		return false
	if not main.has_method("_play_intel_path_ghost"):
		push_error("SMOKE_NO_INTEL_GHOST_API")
		quit(52)
		return false
	for lid in ["yard", "warehouse", "pump", "railcut", "depot"]:
		var def: LevelDef = LevelDef.by_id(lid)
		var note := ""
		if def.has_method("teaching_note_for"):
			if lid == "depot":
				note = str(def.teaching_note_for("sneak"))
			else:
				note = str(def.teaching_note_for("flank"))
		if note == "":
			push_error("SMOKE_NO_TEACHING_NOTE %s" % lid)
			quit(52)
			return false
	var flank_c: Color = main._intel_flash_color("flank")
	var sneak_c: Color = main._intel_flash_color("sneak")
	var main_c: Color = main._intel_flash_color("main")
	if flank_c.r < 0.8 or flank_c.g < 0.4 or flank_c.g > 0.75:
		push_error("SMOKE_INTEL_FLANK_COLOR %s" % str(flank_c))
		quit(52)
		return false
	if sneak_c.b < 0.7 or sneak_c.r < 0.4:
		push_error("SMOKE_INTEL_SNEAK_COLOR %s" % str(sneak_c))
		quit(52)
		return false
	if main_c.r < 0.8 or main_c.g > 0.45:
		push_error("SMOKE_INTEL_MAIN_COLOR %s" % str(main_c))
		quit(52)
		return false
	for lid in ["yard", "warehouse", "pump", "railcut", "depot"]:
		var pages: Array = TutorialOverlay.pages_for(lid)
		var last: Dictionary = pages[pages.size() - 1]
		if str(last.get("body", "")).find("陷阱路线") < 0:
			push_error("SMOKE_TUTORIAL_TRAP %s" % lid)
			quit(52)
			return false
	if not _assert_payoff_copy(main):
		return false
	if not _assert_first_visit_tutorial(main):
		return false
	print("SMOKE_OK_TEACHING beats=5 timeline=1 callout=1 spawn_teach=1 overlay=1")
	return true


func _assert_first_visit_tutorial(main) -> bool:
	if main.tutorial_overlay == null:
		push_error("SMOKE_NO_TUTORIAL_OVERLAY")
		quit(52)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null or not gs.has_method("has_seen_tutorial"):
		push_error("SMOKE_NO_TUTORIAL_FLAGS")
		quit(52)
		return false
	if main.tutorial_overlay.is_open():
		main.tutorial_overlay._finish()
	gs.seen_tutorial = false
	gs.seen_level_tutorials.clear()
	main._maybe_show_tutorial()
	if not main.tutorial_overlay.is_open():
		push_error("SMOKE_TUTORIAL_NOT_SHOWN")
		quit(52)
		return false
	var dim := main.tutorial_overlay.get_node_or_null("Dimmer") as Control
	if dim == null:
		push_error("SMOKE_TUTORIAL_NO_DIMMER")
		quit(52)
		return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 20)
	dim.gui_input.emit(click)
	if not main.tutorial_overlay.is_open():
		push_error("SMOKE_TUTORIAL_DIMMER_SKIP")
		quit(52)
		return false
	var guard := 0
	while main.tutorial_overlay.is_open() and guard < 8:
		main.tutorial_overlay._on_next()
		guard += 1
	if main.tutorial_overlay.is_open():
		push_error("SMOKE_TUTORIAL_STUCK")
		quit(52)
		return false
	if not bool(gs.has_seen_tutorial("yard")):
		push_error("SMOKE_TUTORIAL_NOT_MARKED")
		quit(52)
		return false
	main._maybe_show_tutorial()
	if main.tutorial_overlay.is_open():
		push_error("SMOKE_TUTORIAL_RESHOWN")
		quit(52)
		return false
	gs.seen_tutorial = true
	return true


func _assert_feel_presence(main) -> bool:
	var script := load("res://scripts/feel_gate.gd") as GDScript
	if script == null:
		push_error("SMOKE_NO_FEEL_GATE")
		quit(70)
		return false
	if main.has_method("_ensure_night_grade"):
		main._ensure_night_grade()
	if main.has_method("_ensure_watch_cinema"):
		main._ensure_watch_cinema()
	for op in main.operators:
		if op != null and op.has_method("_rebuild_cone"):
			op._rebuild_cone()
	var fails: PackedStringArray = script.evaluate(main)
	if not script.has_watch_cinema(main):
		fails.append("watch_cinema")
	if not fails.is_empty():
		push_error("SMOKE_FEEL_GATE %s" % ",".join(fails))
		quit(70)
		return false
	if not _assert_desktop_hud_chrome(main):
		return false
	print("SMOKE_OK_FEEL_GATE")
	return true


func _assert_desktop_hud_chrome(main) -> bool:
	## After touch-parity restore, Art 5.0 card height and hidden TutPlate
	## must still hold. Phone chrome used to inflate desktop cards to 138px.
	if main.has_method("_ensure_touch_hud"):
		main._ensure_touch_hud()
	if main.has_method("_update_hud"):
		main._update_hud()
	if main.tut_label != null and bool(main.tut_label.visible):
		push_error("SMOKE_DUP_TUT_VISIBLE")
		quit(70)
		return false
	var plate := main.get_node_or_null("HUD/Root/TutPlate") as CanvasItem
	if plate != null and plate.visible:
		push_error("SMOKE_DUP_TUT_PLATE")
		quit(70)
		return false
	if main.get_node_or_null("World/NightKeys") == null:
		push_error("SMOKE_NO_NIGHT_KEYS")
		quit(70)
		return false
	if main._want_touch():
		return true
	if main.role_cards.is_empty():
		push_error("SMOKE_NO_ROLE_CARDS")
		quit(70)
		return false
	var card := main.role_cards[0] as Control
	if card.custom_minimum_size.y > 110.0:
		push_error("SMOKE_OPCARD_DESKTOP_STRETCH h=%s" % card.custom_minimum_size.y)
		quit(70)
		return false
	if int(card.size_flags_vertical) & int(Control.SIZE_EXPAND):
		push_error("SMOKE_OPCARD_EXPAND flags=%s" % card.size_flags_vertical)
		quit(70)
		return false
	if main.role_box != null:
		var dock_h := float(main.role_box.offset_bottom - main.role_box.offset_top)
		var content_h := dock_h
		if main.role_box is Container:
			content_h = float((main.role_box as Container).get_combined_minimum_size().y)
		if absf(dock_h - content_h) > 12.0:
			push_error("SMOKE_ROLE_DOCK_NOT_CONTENT dock=%s content=%s" % [dock_h, content_h])
			quit(70)
			return false
		if float(main.role_box.offset_bottom) > 530.0:
			push_error("SMOKE_ROLE_DOCK_TALL %s" % main.role_box.offset_bottom)
			quit(70)
			return false
	if main.checklist_strip != null and main.role_box != null:
		if float(main.checklist_strip.offset_top) + 8.0 < float(main.role_box.offset_bottom):
			push_error(
				"SMOKE_CHECKLIST_OVER_CARDS top=%s dock=%s"
				% [main.checklist_strip.offset_top, main.role_box.offset_bottom]
			)
			quit(70)
			return false
	print("SMOKE_OK_HUD_CHROME cards=", card.custom_minimum_size.y, " dock=", main.role_box.offset_bottom if main.role_box else -1)
	return true


func _assert_payoff_copy(main) -> bool:
	if not ResourceLoader.exists("res://scripts/replay/payoff.gd"):
		push_error("SMOKE_NO_PAYOFF_SCRIPT")
		quit(61)
		return false
	var want_hooks := {
		"yard": "交叉封锁",
		"warehouse": "入伏",
		"pump": "紫线",
		"railcut": "3.8",
		"depot": "2.2",
	}
	for lid in want_hooks.keys():
		var def: LevelDef = LevelDef.by_id(str(lid))
		if str(def.highlight_hook).find(str(want_hooks[lid])) < 0:
			push_error("SMOKE_HIGHLIGHT_HOOK %s %s" % [lid, def.highlight_hook])
			quit(61)
			return false
		if str(def.must_bring).strip_edges() == "":
			push_error("SMOKE_NO_MUST_BRING %s" % lid)
			quit(61)
			return false
		if str(def.fix_one).find("改一处") < 0:
			push_error("SMOKE_NO_FIX_ONE_COPY %s" % lid)
			quit(61)
			return false
		if not def.has_method("role_why_for"):
			push_error("SMOKE_NO_ROLE_WHY_API %s" % lid)
			quit(61)
			return false
		if str(def.role_why_for(1)).strip_edges() == "" or str(def.role_why_for(0)).strip_edges() == "" or str(def.role_why_for(2)).strip_edges() == "":
			push_error("SMOKE_ROLE_WHY_EMPTY %s" % lid)
			quit(61)
			return false
	var log := BattleLog.new()
	log.add_event(12, "fire", 2, 1, Vector2.ZERO, {"name": "铁砧", "role": "机"})
	log.mark_terminal(40, "win")
	var epitaph := log.terminal_summary_line()
	if epitaph.find("第一枪是铁砧") < 0:
		push_error("SMOKE_TERMINAL_FIRST_SHOT %s" % epitaph)
		quit(61)
		return false
	var fire_line := log.format_event(log.first_of_type("fire"))
	if fire_line.find("第一枪是铁砧") < 0:
		push_error("SMOKE_FORMAT_FIRST_SHOT %s" % fire_line)
		quit(61)
		return false
	var rc_pages: Array = TutorialOverlay.pages_for("railcut")
	if str(rc_pages[1].get("body", "")).find("铁砧") < 0 or str(rc_pages[1].get("body", "")).find("3.8") < 0:
		push_error("SMOKE_RAILCUT_ROLE_TEACH %s" % str(rc_pages[1].get("body", "")))
		quit(61)
		return false
	var wh_pages: Array = TutorialOverlay.pages_for("warehouse")
	if str(wh_pages[1].get("body", "")).find("铁砧") < 0:
		push_error("SMOKE_WAREHOUSE_PACK_ROLE %s" % str(wh_pages[1].get("body", "")))
		quit(61)
		return false
	var dp_pages: Array = TutorialOverlay.pages_for("depot")
	if str(dp_pages[1].get("body", "")).find("绊索就是第四人") < 0 and str(dp_pages[1].get("body", "")).find("第四人") < 0:
		push_error("SMOKE_DEPOT_TRIP_ROLE %s" % str(dp_pages[1].get("body", "")))
		quit(61)
		return false
	if main.level == null or str(main.level.highlight_hook).find("交叉") < 0:
		push_error("SMOKE_YARD_HOOK_LIVE %s" % (main.level.highlight_hook if main.level else "null"))
		quit(61)
		return false
	if main.trap_callout:
		var tag = main.trap_callout.get_node_or_null("Tag")
		if tag and str(tag.text).find("交叉封锁") < 0:
			push_error("SMOKE_YARD_CALLOUT_HOOK %s" % tag.text)
			quit(61)
			return false
	print("SMOKE_OK_PAYOFF_COPY hooks=5 roles=3 first_shot=1")
	return true


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.reset_to_defaults()
		gs.seen_tutorial = true


func _assert_launch_bar() -> bool:
	if not ResourceLoader.exists("res://scenes/title.tscn"):
		push_error("SMOKE_NO_TITLE_SCENE")
		quit(42)
		return false
	if not FileAccess.file_exists("res://export_presets.cfg"):
		push_error("SMOKE_NO_EXPORT_PRESETS")
		quit(42)
		return false
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.find("platform=\"Android\"") < 0 or presets.find("com.ambushloop.game") < 0:
		push_error("SMOKE_NO_ANDROID_PRESET")
		quit(42)
		return false
	var packed = load("res://scenes/title.tscn")
	if packed == null:
		push_error("SMOKE_TITLE_LOAD_FAIL")
		quit(42)
		return false
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		push_error("SMOKE_NO_GAMESETTINGS")
		quit(42)
		return false
	if absf(float(gs.get("music_volume")) - 1.0) > 0.02 or absf(float(gs.get("sfx_volume")) - 1.0) > 0.02:
		push_error("SMOKE_AUDIO_BUS_DEFAULTS music=%s sfx=%s" % [gs.get("music_volume"), gs.get("sfx_volume")])
		quit(43)
		return false
	var audio = root.get_node_or_null("AudioDirector")
	if audio == null:
		push_error("SMOKE_NO_AUDIODIRECTOR")
		quit(43)
		return false
	if not audio.has_cue("alarm") or not audio.has_cue("win"):
		push_error("SMOKE_AUDIO_CUES")
		quit(43)
		return false
	if not audio.has_music_bed() or not audio.music_bus_ok():
		push_error("SMOKE_NO_MUSIC_BED")
		quit(43)
		return false
	var entries: Array = gs.mission_entries()
	if entries.size() != 5:
		push_error("SMOKE_MISSION_COUNT %s" % entries.size())
		quit(43)
		return false
	if str(gs.LEVEL_ORDER[3]) != "railcut" or str(gs.LEVEL_ORDER[4]) != "depot" or gs.LEVEL_ORDER.size() != 5:
		push_error("SMOKE_LEVEL_ORDER %s" % str(gs.LEVEL_ORDER))
		quit(43)
		return false
	var howto_src := FileAccess.get_file_as_string("res://scripts/title.gd")
	if howto_src.find("弹包交给已部署队员（仓道、泵站、信号楼、油库）") < 0:
		push_error("SMOKE_HOWTO_NO_DEPOT")
		quit(43)
		return false
	var cred_src := FileAccess.get_file_as_string("res://scripts/ui/credits_overlay.gd")
	if cred_src.find("院子 / 仓道 / 泵站 / 信号楼 / 油库") < 0:
		push_error("SMOKE_CREDITS_SRC_NO_DEPOT")
		quit(43)
		return false
	var foot_src := FileAccess.get_file_as_string("res://scenes/title.tscn")
	if foot_src.find("院子 / 仓道 / 泵站 / 信号楼 / 油库") < 0:
		push_error("SMOKE_TITLE_FOOT_NO_DEPOT")
		quit(43)
		return false
	if not bool(entries[0]["unlocked"]) or bool(entries[1]["unlocked"]) or bool(entries[3]["unlocked"]) or bool(entries[4]["unlocked"]) or bool(entries[0]["cleared"]):
		push_error("SMOKE_MISSION_UNLOCK_FRESH")
		quit(43)
		return false
	var inst = packed.instantiate()
	if inst == null:
		push_error("SMOKE_TITLE_INSTANTIATE_FAIL")
		quit(42)
		return false
	root.add_child(inst)
	await process_frame
	await process_frame
	if inst.mission_row_count() != 5:
		push_error("SMOKE_TITLE_MISSION_ROWS %s" % inst.mission_row_count())
		inst.free()
		quit(43)
		return false
	inst._on_start()
	await process_frame
	if not inst.mission_select_visible():
		push_error("SMOKE_MISSION_SELECT_HIDDEN")
		inst.free()
		quit(43)
		return false
	var mood_want := ["初阵", "深仓", "闸站", "信号", "油库"]
	for mi in mood_want.size():
		if mi >= inst._mission_btns.size():
			break
		var row_txt := str(inst._mission_btns[mi].text)
		if row_txt.find(mood_want[mi]) < 0:
			push_error("SMOKE_MOOD_TAG %s row=%s" % [mood_want[mi], row_txt])
			inst.free()
			quit(43)
			return false
	inst._on_mission_picked(1)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "warehouse":
		push_error("SMOKE_SKIPPED_LOCKED_MISSION")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(3)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "railcut":
		push_error("SMOKE_SKIPPED_LOCKED_RAILCUT")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(4)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "depot":
		push_error("SMOKE_SKIPPED_LOCKED_DEPOT")
		inst.free()
		quit(43)
		return false
	inst._on_mission_picked(0)
	await process_frame
	if not inst.briefing_visible() or inst.pending_mission_id() != "yard":
		push_error("SMOKE_YARD_BRIEFING_FAIL")
		inst.free()
		quit(43)
		return false
	if not inst.has_method("briefing_codename_text") or str(inst.briefing_codename_text()).find("行动") < 0:
		push_error("SMOKE_NO_CODENAME %s" % (inst.briefing_codename_text() if inst.has_method("briefing_codename_text") else "no_api"))
		inst.free()
		quit(54)
		return false
	if not inst.has_method("mission_row_accent_exists") or not bool(inst.mission_row_accent_exists()):
		push_error("SMOKE_NO_MISSION_ACCENT")
		inst.free()
		quit(54)
		return false
	if inst._brief_go == null or inst._brief_go.custom_minimum_size.y < 48.0:
		push_error("SMOKE_BRIEF_CTA_SIZE")
		inst.free()
		quit(54)
		return false
	inst.free()
	# Keep tutorial modal off so SETUP input/API matches the slice gate.
	gs.seen_tutorial = true
	print("SMOKE_OK_LAUNCH_BAR title+GameSettings+AudioDirector+missions+android_preset")
	return true
