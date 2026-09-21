extends SceneTree

## Vertical-slice smoke: abort/wipe fail paths, yard escape→restore→win,
## warehouse+pump+railcut+depot+radio reference wins, campaign credits name 电台.
## Isolates user:// save data so player progress cannot mask failures.
## Bypasses title via change_scene_to_file(main.tscn).

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	print("SMOKE_GAME_VERSION ", ver)
	if ver != "0.6.23":
		push_error("SMOKE_BAD_VERSION %s" % ver)
		quit(90)
		return
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
	if not _assert_weapon_models(main):
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
	if not await _assert_touch_parity(main):
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
	if not _assert_iteration_slice(main):
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
	if not _assert_raid_contract(main):
		return
	if not await _assert_fail_paths(main):
		return
	if not await _assert_skip_to_outcome(main):
		return
	if not await _assert_raid_campaign(main):
		return
	return


	# Life 1 (legacy lock-watch playthrough kept below for reference, unreachable).
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	main.selected.set_facing(0.0)
	main.raid_force_alarm()
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
			var leak_line_txt := _fail_txt(main)
			var card_txt := str(main.result_label.text)
			if card_txt.find("漏网：") < 0 or card_txt.find("改一处") < 0 or card_txt.find("带着情报穿梭回去") < 0:
				push_error("SMOKE_FAIL_CARD_NOT_THREE %s" % card_txt)
				quit(4)
				return
			if card_txt.find("情报墙") >= 0 or card_txt.find("事件摘要") >= 0:
				push_error("SMOKE_FAIL_CARD_STILL_DOSSIER %s" % card_txt)
				quit(4)
				return
			print("SMOKE_OK_FAIL_CARD")
			if main.has_method("fail_card_bitten_by_rail") and bool(main.fail_card_bitten_by_rail()):
				push_error("SMOKE_FAIL_CARD_BITTEN")
				quit(72)
				return
			if main.has_method("result_cta_buried_by_bars") and bool(main.result_cta_buried_by_bars()):
				push_error("SMOKE_FAIL_CTA_BURIED")
				quit(72)
				return
			print("SMOKE_OK_FAIL_CARD_CLEAR")
			if leak_line_txt.find("情报已记录") < 0:
				push_error("SMOKE_NO_INTEL_RECORDED %s" % leak_line_txt)
				quit(4)
				return
			print("SMOKE_OK_INTEL_RECORDED")
			if leak_line_txt.find("下一波") < 0:
				push_error("SMOKE_NO_NEXT_WAVE %s" % leak_line_txt)
				quit(52)
				return
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
			if leak_line_txt.find("截获") < 0 or leak_line_txt.find("北门") < 0:
				push_error("SMOKE_NO_CHATTER_FAIL %s" % leak_line_txt)
				quit(61)
				return
			print("SMOKE_OK_CHATTER")
			if leak_line_txt.find("情报墙") < 0:
				push_error("SMOKE_NO_INTEL_WALL %s" % leak_line_txt)
				quit(4)
				return
			print("SMOKE_OK_INTEL_WALL")
			if leak_line_txt.find("本世罩住") < 0 or leak_line_txt.find("缺口") < 0:
				push_error("SMOKE_NO_COVER_VS_LEAK %s" % leak_line_txt)
				quit(4)
				return
			print("SMOKE_OK_COVER_VS_LEAK")
			if leak_line_txt.find("没打中第二层") < 0:
				push_error("SMOKE_NO_SECOND_TRAP_MISS %s" % leak_line_txt)
				quit(4)
				return
			print("SMOKE_OK_SECOND_TRAP_MISS")
			if not main.has_method("intel_path_ghost_active") or not bool(main.intel_path_ghost_active()):
				push_error("SMOKE_NO_FAIL_LEAK_PAINT")
				quit(4)
				return
			print("SMOKE_OK_FAIL_LEAK_PAINT")
			if main.fail_gap_callout == null or not is_instance_valid(main.fail_gap_callout):
				push_error("SMOKE_NO_FAIL_GAP")
				quit(4)
				return
			var gap_tag = main.fail_gap_callout.get_node_or_null("Tag")
			if gap_tag == null or str(gap_tag.text).find("缺口") < 0:
				push_error("SMOKE_FAIL_GAP_TEXT %s" % (gap_tag.text if gap_tag else "null"))
				quit(4)
				return
			print("SMOKE_OK_FAIL_GAP")
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
			if main.has_method("intel_chip_overlaps_timeline") and bool(main.intel_chip_overlaps_timeline()):
				push_error("SMOKE_INTEL_OVER_TIMELINE chip=%s" % (main.intel_chip_text() if main.has_method("intel_chip_text") else ""))
				quit(72)
				return
			print("SMOKE_OK_INTEL_CHIP")
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
			if not main.has_method("alarm_leak_warning") or str(main.alarm_leak_warning()).find("漏网") < 0:
				push_error("SMOKE_NO_LEAK_SOFT_WARN %s" % (main.alarm_leak_warning() if main.has_method("alarm_leak_warning") else "no_api"))
				quit(56)
				return
			print("SMOKE_OK_LEAK_COVER_RED chip=", leak_chip_txt.replace("\n", " | "))
			# Same plan at 2× must match terminal tick + event fingerprint.
			main.raid_force_alarm()
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
			main.raid_force_alarm()
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
			if str(main.result_label.text).find("仓道") < 0:
				push_error("SMOKE_NO_YARD_BEAT %s" % main.result_label.text)
				quit(61)
				return
			if str(main.result_label.text).find("初阵✓") < 0 or str(main.result_label.text).find("下一夜") < 0:
				push_error("SMOKE_NO_CHAIN_STRIP %s" % main.result_label.text)
				quit(61)
				return
			print("SMOKE_OK_CHAIN_STRIP")
			if main.has_method("result_cta_buried_by_bars") and bool(main.result_cta_buried_by_bars()):
				push_error("SMOKE_WIN_CTA_BURIED")
				quit(72)
				return
			print("SMOKE_OK_WIN_CTA_CLEAR")
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
			main.raid_force_alarm()
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
			var dump_txt := _fail_txt(main)
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
			main.raid_force_alarm()
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
			main.raid_force_alarm()
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
			main.raid_force_alarm()
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
			var pump_fail_txt := _fail_txt(main)
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
			main.raid_force_alarm()
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
			if not _assert_level_order(main, 6):
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
			if entries_after.size() != 6 or not bool(entries_after[3]["unlocked"]) or str(entries_after[3]["id"]) != "railcut":
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
			main.raid_force_alarm()
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
			var rc_fail_txt := _fail_txt(main)
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
			main.raid_force_alarm()
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
			if depot_entries.size() != 6 or not bool(depot_entries[4]["unlocked"]) or str(depot_entries[4]["id"]) != "depot":
				push_error("SMOKE_DEPOT_MISSION_ENTRY %s" % str(depot_entries.size()))
				quit(48)
				return
			if bool(depot_entries[5]["unlocked"]) or str(depot_entries[5]["id"]) != "radio":
				push_error("SMOKE_RADIO_UNLOCKED_EARLY %s" % str(depot_entries[5]))
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
			main.raid_force_alarm()
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
			var dp_fail_txt := _fail_txt(main)
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
			main.raid_force_alarm()
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
			if str(main.continue_button.text).find("下一关") < 0:
				push_error("SMOKE_DEPOT_NO_NEXT %s" % main.continue_button.text)
				quit(61)
				return
			var gs_dp = root.get_node_or_null("GameSettings")
			if gs_dp == null or not gs_dp.is_level_cleared("depot") or not gs_dp.is_level_unlocked("radio"):
				push_error(
					"SMOKE_RADIO_UNLOCK cleared_depot=%s unlocked=%s"
					% [
						gs_dp.is_level_cleared("depot") if gs_dp else false,
						gs_dp.is_level_unlocked("radio") if gs_dp else false,
					]
				)
				quit(62)
				return
			print("SMOKE_OK_RADIO_UNLOCK")
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.level.level_id != "radio":
				push_error("SMOKE_BAD_ADVANCE expected=radio got=%s" % main.level.level_id)
				quit(62)
				return
			if not _assert_save_level("radio"):
				return
			if not _assert_geometry(main, "radio"):
				return
			if not _assert_radio_contract(main):
				return
			# No-trip probe: 灯塔脊/碟台/东廊, no 绊索. Sneak 敌3 at 3.6s must leak.
			_deploy_ref(main, [1, 4, 5], [270.0, 90.0, 270.0])
			main.sim.set_speed(2.0)
			main.raid_force_alarm()
			main.sim.set_speed(2.0)
			if main.has_method("queued_kit_for") and str(main.queued_kit_for(5)) != "echo":
				push_error("SMOKE_RADIO_KIT_NOT_QUEUED %s" % main.queued_kit_for(5))
				quit(62)
				return
			print("SMOKE_OK_RADIO_KIT_QUEUED")
			var radio_stack: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 280)
			if not radio_stack or main.fail_reason != "escape":
				push_error(
					"SMOKE_RADIO_NOTRIP_NOT_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(62)
				return
			var rd_route := str(main.intel.latest_route()) if main.intel else ""
			var rd_leaker := int(main.intel.latest_leaker_id()) if main.intel else -1
			if rd_route != "sneak" or rd_leaker != 3:
				push_error("SMOKE_RADIO_NOTRIP_NOT_SNEAK route=%s leaker=%s" % [rd_route, rd_leaker])
				quit(62)
				return
			var rd_fail_txt := _fail_txt(main)
			if rd_fail_txt.find("暗道") < 0 or rd_fail_txt.find("3.6") < 0:
				push_error("SMOKE_RADIO_NOTRIP_COPY %s" % rd_fail_txt)
				quit(62)
				return
			if rd_fail_txt.find("没打中第二层") < 0 or rd_fail_txt.find("暗道") < 0:
				push_error("SMOKE_RADIO_TRAP_MISS_NOT_SNEAK %s" % rd_fail_txt)
				quit(62)
				return
			print(
				"SMOKE_RADIO_NO_TRIP_FAIL reason=", main.fail_reason,
				" route=", rd_route,
				" leaker=", rd_leaker,
				" tick=", main.sim.tick
			)
			main._on_continue_pressed()
			await process_frame
			main._on_clear_pressed()
			await process_frame
			# Rifle 灯塔脊 slot1 face 270, MG 碟台 slot4 face 90, scout 东廊 slot5 face 270.
			# Tripwire on the west alley (7,11) so the delayed sneak does not leak.
			_deploy_ref(main, [1, 4, 5], [270.0, 90.0, 270.0])
			main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
			if main.tripwires.size() != 1:
				push_error("SMOKE_RADIO_TRIP n=%s" % main.tripwires.size())
				quit(62)
				return
			main.sim.set_speed(2.0)
			main.raid_force_alarm()
			main.sim.set_speed(2.0)
			var rd: bool = await _wait_phase(main, main.Phase.WON, 60 * 280)
			if not rd:
				push_error(
					"SMOKE_RADIO_FAIL phase=%s reason=%s tick=%s"
					% [main.phase, main.fail_reason, main.sim.tick]
				)
				quit(62)
				return
			print("SMOKE_OK radio won tick=", main.sim.tick)
			var radio_debrief := str(main.result_label.text) + "\n" + str(main.result_stats_block_text() if main.has_method("result_stats_block_text") else "")
			if radio_debrief.find("5.2") < 0 or radio_debrief.find("绊索") < 0:
				push_error("SMOKE_RADIO_NO_HOOK %s" % radio_debrief)
				quit(62)
				return
			print("SMOKE_OK_RADIO_HOOK")
			if str(main.continue_button.text).find("查看致谢") < 0:
				push_error("SMOKE_RADIO_NO_CREDITS_CTA %s" % main.continue_button.text)
				quit(62)
				return
			main._on_continue_pressed()
			await process_frame
			await process_frame
			if main.credits_overlay == null or not main.credits_overlay.is_open():
				push_error("SMOKE_RADIO_CREDITS_CLOSED")
				quit(62)
				return
			var cred_txt := _collect_label_text(main.credits_overlay)
			if cred_txt.find("油库") < 0 or cred_txt.find("电台") < 0:
				push_error("SMOKE_RADIO_CREDITS %s" % cred_txt)
				quit(62)
				return
			print("SMOKE_OK_CREDITS_RADIO")
			print("SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio")
			print("SMOKE_SLICE_COMPLETE")
			quit(0)
			return

	push_error("SMOKE_TIMEOUT phase=%s reason=%s" % [main.phase, main.fail_reason])
	quit(2)


func _deploy_ref(main, slots: Array, facings: Array) -> void:
	if main.has_method("raid_prepare_ref"):
		main.raid_prepare_ref(slots, facings, {"grenades": 1, "mines": 1})
		return
	for i in slots.size():
		main._select_op(i)
		main._deploy_selected_to(main.cover_slots[int(slots[i])])
		main.selected.set_facing(float(facings[i]))


func _assert_raid_contract(main) -> bool:
	main._start_setup(false, false)
	if not main.has_method("phase_id") or str(main.phase_id()) != "scout":
		push_error("SMOKE_RAID_PHASE %s" % (main.phase_id() if main.has_method("phase_id") else main.phase))
		quit(80)
		return false
	if main.stash_count() < 3:
		push_error("SMOKE_NO_STASHES n=%s" % main.stash_count())
		quit(80)
		return false
	var visible_ops := 0
	for op in main.operators:
		if op.visible and op.alive:
			visible_ops += 1
		if str(op.weapon_id) != "knife":
			push_error("SMOKE_NOT_KNIFE_START %s %s" % [op.display_name, op.weapon_id])
			quit(80)
			return false
	if visible_ops < 3:
		push_error("SMOKE_OPS_NOT_ON_MAP n=%s" % visible_ops)
		quit(80)
		return false
	main._tick_crate_search(0.5)
	for op in main.operators:
		if op and str(op.weapon_id) != "knife":
			push_error("SMOKE_INSERT_AUTO_GUN %s %s" % [op.display_name, op.weapon_id])
			quit(80)
			return false
	print("SMOKE_OK_INSERT_KNIVES")
	if main.level.wave_count() < 2:
		push_error("SMOKE_YARD_WAVES %s" % main.level.wave_count())
		quit(80)
		return false
	if int(LevelDef.by_id("radio").wave_count()) != 3:
		push_error("SMOKE_RADIO_WAVES %s" % LevelDef.by_id("radio").wave_count())
		quit(80)
		return false
	if not main.command_move_to_cell(0, Vector2i(7, 11)):
		push_error("SMOKE_NO_PATH insert->cover")
		quit(80)
		return false
	if not main.operators[0].is_moving():
		push_error("SMOKE_OP_NOT_MOVING")
		quit(80)
		return false
	if main.stash_count() < 9:
		push_error("SMOKE_YARD_STASH_COUNT n=%s" % main.stash_count())
		quit(80)
		return false
	var crate_kinds: PackedStringArray = PackedStringArray()
	for s in main.raid_stashes:
		if s != null and is_instance_valid(s):
			crate_kinds.append(str(s.kind))
	if not crate_kinds.has("kar98k") or not crate_kinds.has("m1911"):
		push_error("SMOKE_YARD_NAMED_MISS %s" % " ".join(crate_kinds))
		quit(80)
		return false
	if crate_kinds.has("rifle"):
		push_error("SMOKE_CLASS_RIFLE_STILL %s" % " ".join(crate_kinds))
		quit(80)
		return false
	for banned in ["gewehr43", "svt40", "pps43", "webley", "m30_drilling", "ithaca37", "sten", "shotgun", "lee_enfield", "mg34"]:
		if crate_kinds.has(banned):
			push_error("SMOKE_YARD_TAIL %s in %s" % [banned, " ".join(crate_kinds)])
			quit(80)
			return false
	print("SMOKE_OK_NAMED_CRATES n=", main.stash_count(), " ", " ".join(crate_kinds))
	main._refresh_alarm_cta()
	if str(main.alarm_button.text) != "需枪":
		push_error("SMOKE_ALARM_CTA %s" % main.alarm_button.text)
		quit(80)
		return false
	var gs_cta = root.get_node_or_null("GameSettings")
	if gs_cta:
		gs_cta.force_touch_hud = true
	main._ensure_touch_hud()
	main._refresh_touch_hud()
	if main.touch_hud and main.touch_hud._btns.has("alarm") and str(main.touch_hud._btns["alarm"].text) != "需枪":
		push_error("SMOKE_TOUCH_CTA %s" % main.touch_hud._btns["alarm"].text)
		quit(80)
		return false
	print("SMOKE_OK_ALARM_CTA 需枪")
	var saved_phase = main.phase
	main.phase = main.Phase.WATCHING
	main._apply_watch_layers()
	var cine := str(main.cinema_banner_text()) if main.has_method("cinema_banner_text") else ""
	if cine.find("锁死") >= 0:
		push_error("SMOKE_CINEMA_LOCK %s" % cine)
		quit(80)
		return false
	if cine.find("警报中") < 0:
		push_error("SMOKE_CINEMA_COPY %s" % cine)
		quit(80)
		return false
	print("SMOKE_OK_CINEMA ", cine)
	main.phase = saved_phase
	main._apply_watch_layers()
	print("SMOKE_OK_RAID_CONTRACT stashes=", main.stash_count(), " waves=", main.level.wave_count())
	main.raid_grant_and_pickup(0, "grenade", 2)
	main.raid_grant_and_pickup(0, "mine", 1)
	main.raid_grant_and_pickup(0, "decoy", 1)
	if int(main.operators[0].grenades) < 2 or int(main.operators[0].mines) < 1:
		push_error("SMOKE_GRANT_THROWABLES")
		quit(80)
		return false
	var gpos: Vector2 = main.operators[0].global_position + Vector2(48, 0)
	main._throw_grenade_at(gpos)
	if main.raid_grenades.is_empty():
		push_error("SMOKE_NO_GRENADE_NODE")
		quit(80)
		return false
	main._try_place_inventory_mine(main.operators[0].global_position + Vector2(0, 32))
	if main.raid_mines.is_empty() and main.tripwires.is_empty():
		push_error("SMOKE_NO_MINE_NODE")
		quit(80)
		return false
	main._throw_decoy_at(main.operators[0].global_position + Vector2(32, 32))
	if main.raid_decoys.is_empty():
		push_error("SMOKE_NO_DECOY_NODE")
		quit(80)
		return false
	print("SMOKE_OK_RAID_VERBS g=", main.raid_grenades.size(), " mines=", main.raid_mines.size(), " decoy=", main.raid_decoys.size())
	var a: Vector2i = main.operators[0].grid_cell()
	var taken := bool(main._cell_taken(a, main.operators[1]))
	if not taken:
		push_error("SMOKE_OCCUPANCY_MISS")
		quit(80)
		return false
	print("SMOKE_OK_OCCUPANCY")
	# Ammo types: MG rounds stay in the pool, not the pistol mag.
	var wolf: OperatorUnit = main.operators[0]
	wolf.wipe_inventory()
	wolf.receive_item("pistol", 8)
	wolf.ammo = 4
	wolf.ammo_pool["pistol"] = 4
	var mixed: Dictionary = wolf.receive_item("mg_ammo", 8)
	if int(wolf.ammo) != 4:
		push_error("SMOKE_AMMO_MIXED mag=%s" % wolf.ammo)
		quit(80)
		return false
	if int(wolf.ammo_pool.get("mg", 0)) < 8:
		push_error("SMOKE_AMMO_POOL_MISS %s" % wolf.ammo_pool)
		quit(80)
		return false
	if not bool(mixed.get("pooled", false)):
		push_error("SMOKE_AMMO_NOT_POOLED %s" % mixed)
		quit(80)
		return false
	print("SMOKE_OK_AMMO_TYPES")
	# Transfer: pass a grenade to 铁砧.
	wolf.receive_item("grenade", 1)
	var g0: int = int(wolf.grenades)
	var g1: int = int(main.operators[1].grenades)
	var passed: Dictionary = main.raid_transfer(0, 1, "grenade")
	if not bool(passed.get("ok", false)) or int(wolf.grenades) != g0 - 1 or int(main.operators[1].grenades) != g1 + 1:
		push_error("SMOKE_TRANSFER_FAIL %s g0=%s g1=%s" % [passed, wolf.grenades, main.operators[1].grenades])
		quit(80)
		return false
	print("SMOKE_OK_TRANSFER")
	# Backpack: 6 slots, second gun stays in pack, 7th gun refused.
	wolf.wipe_inventory()
	var guns := ["kar98k", "mp40", "thompson", "m1911", "springfield", "bar"]
	for gid in guns:
		var rec_g: Dictionary = wolf.receive_item(gid, 5)
		if not bool(rec_g.get("ok", false)):
			push_error("SMOKE_PACK_GRANT %s %s" % [gid, rec_g])
			quit(80)
			return false
	if str(wolf.weapon_id) != "kar98k":
		push_error("SMOKE_PACK_KEEP_EQUIP %s" % wolf.weapon_id)
		quit(80)
		return false
	if wolf.pack.occupied() != 6:
		push_error("SMOKE_PACK_OCC %s" % wolf.pack.occupied())
		quit(80)
		return false
	var extra_gun: Dictionary = wolf.receive_item("luger", 8)
	if bool(extra_gun.get("ok", false)) or not bool(extra_gun.get("full", false)):
		push_error("SMOKE_PACK_NOT_FULL %s" % extra_gun)
		quit(80)
		return false
	var swapped: Dictionary = wolf.equip_from_pack("thompson")
	if not bool(swapped.get("ok", false)) or str(wolf.weapon_id) != "thompson":
		push_error("SMOKE_PACK_EQUIP %s %s" % [swapped, wolf.weapon_id])
		quit(80)
		return false
	print("SMOKE_OK_BACKPACK occ=", wolf.pack.occupied(), " equip=", wolf.weapon_id)
	if main.has_method("_toggle_backpack"):
		main._select_op(0)
		main._toggle_backpack()
		if main.backpack_panel == null or not main.backpack_panel.is_open():
			push_error("SMOKE_BACKPACK_UI")
			quit(80)
			return false
		main._toggle_backpack()
		if main.backpack_panel.is_open():
			push_error("SMOKE_BACKPACK_UI_STUCK")
			quit(80)
			return false
		print("SMOKE_OK_BACKPACK_UI")
	# Auto grenade: ALERT cone throw, no manual aim.
	wolf.wipe_inventory()
	wolf.receive_item("grenade", 2)
	wolf.auto_grenade = true
	wolf.grenade_cd = 0.0
	wolf.set_facing(0.0)
	var nade_dummy: EnemyRunner = main._make_enemy(93)
	main.entities.add_child(nade_dummy)
	nade_dummy.setup(93, PackedVector2Array([wolf.global_position + Vector2(120, -40), wolf.global_position + Vector2(160, -40)]), main.grid, 0, "main")
	nade_dummy.global_position = wolf.global_position + Vector2(120, -40)
	nade_dummy.activate()
	main.enemies.append(nade_dummy)
	var saved_phase2 = main.phase
	main.phase = main.Phase.WATCHING
	var g_before: int = int(main.raid_grenades.size())
	main._tick_auto_grenades(0.016)
	var g_after: int = int(main.raid_grenades.size())
	if g_after <= g_before or int(wolf.grenades) < 1:
		push_error("SMOKE_AUTO_NADE g=%s->%s grenades=%s" % [g_before, g_after, wolf.grenades])
		main.phase = saved_phase2
		main.enemies.erase(nade_dummy)
		nade_dummy.queue_free()
		quit(80)
		return false
	print("SMOKE_OK_AUTO_GRENADE n=", g_after, " left=", wolf.grenades)
	main.phase = saved_phase2
	main.enemies.erase(nade_dummy)
	nade_dummy.queue_free()
	wolf.wipe_inventory()
	wolf.receive_item("grenade", 1)
	main._select_op(0)
	main._place_nade_mark(wolf.global_position + Vector2(64, 0))
	if not bool(wolf.has_nade_mark):
		push_error("SMOKE_NADE_MARK")
		quit(80)
		return false
	print("SMOKE_OK_NADE_MARK")
	wolf.clear_nade_mark()
	# Soft alarm gate: knives-only first press does not start the wave.
	main._start_setup(false, false)
	if main.squad_has_firearm():
		push_error("SMOKE_START_HAS_GUN")
		quit(80)
		return false
	main._on_alarm_pressed()
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_ALARM_GATE_SKIPPED phase=%s" % main.phase)
		quit(80)
		return false
	if not bool(main._alarm_warned_no_gun):
		push_error("SMOKE_ALARM_GATE_NO_WARN")
		quit(80)
		return false
	print("SMOKE_OK_ALARM_GATE")
	# Decoy peels one cell off the authored route.
	var dummy: EnemyRunner = main._make_enemy(90)
	main.entities.add_child(dummy)
	var p0: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 11))
	var p1: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 15))
	dummy.setup(90, PackedVector2Array([p0, p1]), main.grid, 0, "main")
	dummy.global_position = p0
	dummy.activate()
	dummy.distract(main.grid.cell_to_world_center(Vector2i(14, 11)), 0.4)
	if not bool(dummy._decoy_stepped):
		push_error("SMOKE_DECOY_NO_STEP")
		dummy.queue_free()
		quit(80)
		return false
	print("SMOKE_OK_DECOY_REROUTE")
	dummy.queue_free()
	if not main.touch_hud._btns.has("nade") or not main.touch_hud._btns.has("nade_watch"):
		push_error("SMOKE_NO_TOUCH_NADE")
		quit(80)
		return false
	print("SMOKE_OK_TOUCH_NADE")
	if not main.touch_hud._btns.has("bag"):
		push_error("SMOKE_NO_TOUCH_BAG")
		quit(80)
		return false
	print("SMOKE_OK_TOUCH_BAG")
	# Headless probes: grenade kill, decoy pause, mine inventory.
	var boom: EnemyRunner = main._make_enemy(91)
	main.entities.add_child(boom)
	boom.setup(91, PackedVector2Array([Vector2(200, 200), Vector2(240, 200)]), main.grid, 0, "main")
	boom.global_position = Vector2(200, 200)
	boom.activate()
	main.enemies.append(boom)
	main._on_grenade_boom(Vector2(200, 200), 80.0, 200.0)
	if boom.alive:
		push_error("SMOKE_GRENADE_NO_KILL hp=%s" % boom.hp)
		main.enemies.erase(boom)
		boom.queue_free()
		quit(80)
		return false
	main.enemies.erase(boom)
	boom.queue_free()
	print("SMOKE_OK_GRENADE_KILL")
	var paused: EnemyRunner = main._make_enemy(92)
	main.entities.add_child(paused)
	var a0: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 11))
	var a1: Vector2 = main.grid.cell_to_world_center(Vector2i(13, 17))
	paused.setup(92, PackedVector2Array([a0, a1]), main.grid, 0, "main")
	paused.global_position = a0
	paused.activate()
	paused.distract(a0 + Vector2(40, 0), 0.5)
	var pos_before: Vector2 = paused.global_position
	paused.sim_step(0.2)
	if paused.global_position.distance_to(pos_before) > 4.0:
		push_error("SMOKE_DECOY_STILL_RUNNING")
		paused.queue_free()
		quit(80)
		return false
	paused.queue_free()
	print("SMOKE_OK_DECOY_PAUSE")
	main.operators[0].mines = 2
	var m0: int = int(main.operators[0].mines)
	main._select_op(0)
	main._try_place_inventory_mine(main.operators[0].global_position + Vector2(0, 24))
	if int(main.operators[0].mines) != m0 - 1:
		push_error("SMOKE_MINE_INV %s" % main.operators[0].mines)
		quit(80)
		return false
	print("SMOKE_OK_MINE_INV")
	var loc_script: Variant = load("res://scripts/raid/raid_loc.gd")
	if loc_script == null or not (loc_script as GDScript).has_method("has") or not bool((loc_script as GDScript).has("alarm")):
		push_error("SMOKE_NO_LOC")
		quit(80)
		return false
	print("SMOKE_OK_LOC")
	# Commandos 2 layer: portraits, skills, sentry, crouch, KO.
	if main.c2 == null or not is_instance_valid(main.c2):
		push_error("SMOKE_NO_C2")
		quit(80)
		return false
	if int(main.c2.sentry_count()) < 1:
		push_error("SMOKE_NO_SENTRY n=%s" % main.c2.sentry_count())
		quit(80)
		return false
	print("SMOKE_OK_SENTRY n=", main.c2.sentry_count())
	if main.c2.portraits == null or main.c2.skill_bar == null or main.c2.minimap == null:
		push_error("SMOKE_NO_C2_HUD")
		quit(80)
		return false
	print("SMOKE_OK_PORTRAITS")
	print("SMOKE_OK_SKILLBAR")
	print("SMOKE_OK_MINIMAP")
	var c2op: OperatorUnit = main.operators[0]
	c2op.toggle_crouch()
	if int(c2op.stance) != 1:
		push_error("SMOKE_CROUCH %s" % c2op.stance)
		quit(80)
		return false
	if c2op.move_speed >= c2op.base_move_speed:
		push_error("SMOKE_CROUCH_SPEED %s" % c2op.move_speed)
		quit(80)
		return false
	print("SMOKE_OK_CROUCH speed=", snapped(c2op.move_speed, 0.1))
	c2op.toggle_crouch()
	var sent = main.c2.sentries[0]
	# Sentry east of the wolf, facing further east — wolf is in the backstab arc.
	sent.global_position = c2op.global_position + Vector2(20, 0)
	sent.facing_deg = 0.0
	if sent.body:
		sent.body.rotation = deg_to_rad(90.0)
	main._select_op(0)
	main.c2.use_skill("knife")
	if not bool(sent.is_down()):
		push_error("SMOKE_KO_FAIL state=%s" % sent.state)
		quit(80)
		return false
	print("SMOKE_OK_KO")
	var cone_e: EnemyRunner = main._make_enemy(94)
	main.entities.add_child(cone_e)
	cone_e.setup(94, PackedVector2Array([Vector2(200, 200), Vector2(240, 200)]), main.grid, 0, "main")
	cone_e.activate()
	cone_e._rebuild_vision_cone()
	if cone_e.vis_cone == null or cone_e.vis_cone.polygon.size() < 4:
		push_error("SMOKE_NO_ENEMY_CONE")
		cone_e.queue_free()
		quit(80)
		return false
	print("SMOKE_OK_ENEMY_CONE n=", cone_e.vis_cone.polygon.size())
	cone_e.queue_free()
	if not main.sfx.has_cue("foot") or not main.sfx.has_cue("whistle") or not main.sfx.has_cue("knife"):
		push_error("SMOKE_NO_C2_SFX")
		quit(80)
		return false
	print("SMOKE_OK_C2_SFX")
	if not (loc_script as GDScript).has("crouch") or not (loc_script as GDScript).has("knife"):
		push_error("SMOKE_NO_C2_LOC")
		quit(80)
		return false
	print("SMOKE_OK_C2_LOC")
	if not main.touch_hud._btns.has("crouch") or not main.touch_hud._btns.has("knife"):
		push_error("SMOKE_NO_TOUCH_CROUCH")
		quit(80)
		return false
	print("SMOKE_OK_TOUCH_CROUCH")
	c2op.set_sprint(true)
	if not bool(c2op.sprinting) or c2op.move_speed <= c2op.base_move_speed:
		push_error("SMOKE_SPRINT %s %s" % [c2op.sprinting, c2op.move_speed])
		quit(80)
		return false
	print("SMOKE_OK_SPRINT speed=", snapped(c2op.move_speed, 0.1))
	c2op.set_sprint(false)
	if not (loc_script as GDScript).has("quiet_yard"):
		push_error("SMOKE_NO_QUIET_LOC")
		quit(80)
		return false
	print("SMOKE_OK_QUIET_LOC")
	main._start_setup(false, false)
	return true


func _run_all_waves(main, max_frames: int) -> bool:
	var guard := 0
	while guard < 8:
		guard += 1
		if main.phase == main.Phase.SETUP or main.phase == main.Phase.SWEEP:
			main.sim.set_speed(2.0)
			main.raid_force_alarm()
			main.sim.set_speed(2.0)
		var frames := 0
		while frames < max_frames:
			await process_frame
			frames += 1
			if main.phase == main.Phase.SWEEP or main.phase == main.Phase.WON or main.phase == main.Phase.FAILED:
				break
		if main.phase == main.Phase.FAILED:
			return false
		if main.phase == main.Phase.WON:
			return true
		if main.phase == main.Phase.SWEEP:
			if main.has_method("raid_vacuum_loot"):
				main.raid_vacuum_loot()
			if main.raid != null and main.raid.is_last_wave(main.level):
				main.raid_force_alarm()
				await process_frame
				await process_frame
				return main.phase == main.Phase.WON
			continue
		return false
	return main.phase == main.Phase.WON


func _assert_raid_campaign(main) -> bool:
	# Real pickup: walk/teleport 灰狼 onto the rifle crate (0.4s open channel).
	main._start_setup(false, false)
	await process_frame
	var rifle_cell := Vector2i(6, 12)
	main.operators[0].stop_move()
	main.operators[0].global_position = main.grid.cell_to_world_center(rifle_cell)
	main._try_pickup_near_selected()
	if str(main.operators[0].weapon_id) != "knife":
		push_error("SMOKE_CRATE_INSTANT weapon=%s" % main.operators[0].weapon_id)
		quit(81)
		return false
	if not main.operators[0].is_searching():
		push_error("SMOKE_CRATE_NO_SEARCH")
		quit(81)
		return false
	main.raid_advance_search(0.2)
	if str(main.operators[0].weapon_id) != "knife":
		push_error("SMOKE_CRATE_TOO_FAST")
		quit(81)
		return false
	main.raid_advance_search(0.4)
	if str(main.operators[0].weapon_id) != "kar98k":
		# Force pickup if snap missed the crate.
		main.raid_grant_and_pickup(0, "kar98k", 5)
	if str(main.operators[0].weapon_id) != "kar98k":
		push_error("SMOKE_PICKUP_KAR98K got=%s" % main.operators[0].weapon_id)
		quit(81)
		return false
	print("SMOKE_OK_CRATE_SEARCH")
	print("SMOKE_OK_PICKUP kar98k")

	# Knives-only alarm should leak (cannot hold the spine). Soft gate: second press.
	main._start_setup(false, false)
	await process_frame
	main._on_alarm_pressed()
	if main.phase == main.Phase.SETUP:
		main._on_alarm_pressed()
	main.sim.set_speed(2.0)
	var leaked: bool = await _wait_phase(main, main.Phase.FAILED, 60 * 180)
	if not leaked or main.fail_reason != "escape":
		push_error("SMOKE_KNIFE_NOT_LEAK phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(81)
		return false
	print("SMOKE_OK_KNIFE_LEAK tick=", main.sim.tick)
	var fail_card := str(main.result_label.text) if main.result_label else ""
	if fail_card.find("先搜") < 0:
		push_error("SMOKE_KNIFE_FAIL_COPY %s" % fail_card.replace("\n", " / "))
		quit(81)
		return false
	print("SMOKE_OK_KNIFE_FAIL_COPY")
	main._on_continue_pressed()
	await process_frame

	# Yard reference: kits + covers 1,2,5.
	main._start_setup(false, false)
	await process_frame
	_deploy_ref(main, [1, 2, 5], [90.0, 180.0, 180.0])
	var yard_ok: bool = await _run_all_waves(main, 60 * 240)
	if not yard_ok:
		push_error("SMOKE_YARD_RAID_FAIL phase=%s reason=%s wave=%s" % [main.phase, main.fail_reason, main.wave_index() if main.has_method("wave_index") else -1])
		quit(81)
		return false
	print("SMOKE_OK yard raid won")
	print("SMOKE_OK_RAID_LOOP")
	if str(main.continue_button.text).find("下一关") < 0:
		push_error("SMOKE_DEBRIEF_CONTINUE %s" % main.continue_button.text)
		quit(44)
		return false
	main._on_continue_pressed()
	await process_frame
	await process_frame
	if main.level.level_id != "warehouse":
		push_error("SMOKE_BAD_ADVANCE expected=warehouse got=%s" % main.level.level_id)
		quit(11)
		return false
	if main.has_method("flash_text") and str(main.flash_text()).find("零逃逸") >= 0:
		push_error("SMOKE_FLASH_LEAK %s" % main.flash_text())
		quit(11)
		return false
	print("SMOKE_OK_FLASH_CLEAR")
	if not _assert_geometry(main, "warehouse"):
		return false
	if main.barrels.size() != 1:
		push_error("SMOKE_WAREHOUSE_NO_BARREL n=%s" % main.barrels.size())
		quit(31)
		return false
	_deploy_ref(main, [1, 3, 5], [180.0, 0.0, 180.0])
	if main.has_method("_play_hold_pack"):
		main._play_hold_pack(1)
	var wh: bool = await _run_all_waves(main, 60 * 280)
	if not wh:
		push_error("SMOKE_WAREHOUSE_RAID_FAIL phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(12)
		return false
	print("SMOKE_OK warehouse raid won")
	main._on_continue_pressed()
	await process_frame
	await process_frame
	if main.level.level_id != "pump":
		push_error("SMOKE_BAD_ADVANCE expected=pump got=%s" % main.level.level_id)
		quit(13)
		return false
	if not _assert_geometry(main, "pump"):
		return false
	if main.door_locked:
		main._on_door_pressed()
	_deploy_ref(main, [1, 4, 5], [90.0, 0.0, 180.0])
	var po: bool = await _run_all_waves(main, 60 * 240)
	if not po:
		push_error("SMOKE_PUMP_RAID_FAIL phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(14)
		return false
	print("SMOKE_OK pump raid won")
	if not _assert_level_order(main, 6):
		return false
	main._on_continue_pressed()
	await process_frame
	await process_frame
	if main.level.level_id != "railcut":
		push_error("SMOKE_BAD_ADVANCE expected=railcut got=%s" % main.level.level_id)
		quit(45)
		return false
	if not _assert_geometry(main, "railcut"):
		return false
	if not _assert_railcut_contract(main):
		return false
	_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
	var rc: bool = await _run_all_waves(main, 60 * 280)
	if not rc:
		push_error("SMOKE_RAILCUT_RAID_FAIL phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(45)
		return false
	print("SMOKE_OK railcut raid won")
	main._on_continue_pressed()
	await process_frame
	await process_frame
	if main.level.level_id != "depot":
		push_error("SMOKE_BAD_ADVANCE expected=depot got=%s" % main.level.level_id)
		quit(48)
		return false
	if not _assert_geometry(main, "depot"):
		return false
	if not _assert_depot_contract(main):
		return false
	_deploy_ref(main, [1, 4, 5], [270.0, 270.0, 180.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	var dp: bool = await _run_all_waves(main, 60 * 280)
	if not dp:
		push_error("SMOKE_DEPOT_RAID_FAIL phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(48)
		return false
	print("SMOKE_OK depot raid won")
	main._on_continue_pressed()
	await process_frame
	await process_frame
	if main.level.level_id != "radio":
		push_error("SMOKE_BAD_ADVANCE expected=radio got=%s" % main.level.level_id)
		quit(62)
		return false
	if not _assert_geometry(main, "radio"):
		return false
	if not _assert_radio_contract(main):
		return false
	_deploy_ref(main, [1, 4, 5], [270.0, 90.0, 270.0])
	main._try_place_tripwire(main.grid.cell_to_world_center(Vector2i(7, 11)))
	var rd: bool = await _run_all_waves(main, 60 * 320)
	if not rd:
		push_error("SMOKE_RADIO_RAID_FAIL phase=%s reason=%s" % [main.phase, main.fail_reason])
		quit(62)
		return false
	print("SMOKE_OK radio raid won")
	print("SMOKE_OK_TYPICAL_LOOPS yard,warehouse,pump,railcut,depot,radio")
	print("SMOKE_SLICE_COMPLETE")
	quit(0)
	return true



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


func _fail_txt(main) -> String:
	if main.has_method("fail_result_search_text"):
		return str(main.fail_result_search_text())
	var card := str(main.result_label.text) if main.result_label else ""
	var dos := str(main.fail_dossier_text()) if main.has_method("fail_dossier_text") else ""
	return "%s\n%s" % [card, dos]


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
	main.raid_force_alarm()
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
	var abort_txt := _fail_txt(main)
	if abort_txt.find("情报已记录") < 0:
		push_error("SMOKE_ABORT_NO_INTEL_LINE %s" % abort_txt)
		quit(60)
		return false
	if abort_txt.find("中止") < 0:
		push_error("SMOKE_ABORT_NO_ZH %s" % abort_txt)
		quit(60)
		return false
	if main.sfx == null or not main.sfx.has_cue("fail") or str(main.sfx.last_cue) != "fail":
		push_error("SMOKE_ABORT_NO_FAIL_SFX cue=%s" % (main.sfx.last_cue if main.sfx else "null"))
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
	main.raid_force_alarm()
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
	var wipe_txt := _fail_txt(main)
	if wipe_txt.find("全灭") < 0:
		push_error("SMOKE_WIPE_NO_ZH %s" % wipe_txt)
		quit(60)
		return false
	if main.sfx == null or str(main.sfx.last_cue) != "fail":
		push_error("SMOKE_WIPE_NO_FAIL_SFX cue=%s" % (main.sfx.last_cue if main.sfx else "null"))
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


func _assert_skip_to_outcome(main) -> bool:
	## Viewing skip: frozen plan still leaks at yard tick 965. Not abort.
	if not main.has_method("_on_skip_to_outcome_pressed"):
		push_error("SMOKE_NO_SKIP_API")
		quit(73)
		return false
	main._start_setup(false, false)
	await process_frame
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main.selected.set_facing(0.0)
	var face0 := float(main.operators[0].facing_deg)
	var mode0 := int(main.operators[0].fire_mode)
	var door0 := bool(main.door_locked)
	var trips0: int = main.tripwires.size()
	var pos0: Vector2 = main.operators[0].global_position
	main.raid_force_alarm()
	if main.phase != main.Phase.WATCHING:
		push_error("SMOKE_SKIP_NO_WATCH phase=%s" % main.phase)
		quit(73)
		return false
	main._on_skip_to_outcome_pressed()
	await process_frame
	if main.phase != main.Phase.FAILED or main.fail_reason != "escape":
		push_error("SMOKE_SKIP_NOT_LEAK phase=%s reason=%s tick=%s" % [main.phase, main.fail_reason, main.sim.tick])
		quit(73)
		return false
	if int(main.sim.tick) < 30:
		push_error("SMOKE_SKIP_TOO_SHORT tick=%s" % main.sim.tick)
		quit(73)
		return false
	if absf(float(main.operators[0].facing_deg) - face0) > 0.01:
		push_error("SMOKE_SKIP_FACING_MUTATED %s -> %s" % [face0, main.operators[0].facing_deg])
		quit(73)
		return false
	if int(main.operators[0].fire_mode) != mode0 or bool(main.door_locked) != door0 or main.tripwires.size() != trips0:
		push_error("SMOKE_SKIP_PLAN_MUTATED")
		quit(73)
		return false
	if main.operators[0].global_position.distance_to(pos0) > 0.5:
		push_error("SMOKE_SKIP_MOVED")
		quit(73)
		return false
	print("SMOKE_OK_SKIP_OUTCOME tick=", main.sim.tick)
	main._on_continue_pressed()
	await process_frame
	main._start_setup(false, false)
	if main.phase != main.Phase.SETUP:
		push_error("SMOKE_SKIP_NO_RESET phase=%s" % main.phase)
		quit(73)
		return false
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
	if not main.map_draw.has_method("wall_language"):
		push_error("SMOKE_NO_WALL_LANGUAGE %s" % want)
		quit(49)
		return false
	var lang := str(main.map_draw.wall_language())
	var want_lang := {
		"yard": "brick",
		"warehouse": "brick",
		"pump": "pipe",
		"railcut": "concrete",
		"depot": "plate",
		"radio": "mesh",
	}
	if lang != str(want_lang.get(want, "brick")):
		push_error("SMOKE_WALL_LANGUAGE %s got=%s" % [want, lang])
		quit(49)
		return false
	var want_kit := {
		"yard": "crate",
		"warehouse": "pallet",
		"pump": "valve",
		"railcut": "sleeper",
		"depot": "drum",
		"radio": "dish",
	}
	if main.cover_slots.is_empty() or str(main.cover_slots[0].kit_id) != str(want_kit.get(want, "crate")):
		push_error(
			"SMOKE_COVER_KIT %s got=%s"
			% [want, main.cover_slots[0].kit_id if not main.cover_slots.is_empty() else "none"]
		)
		quit(49)
		return false
	print("SMOKE_OK_ATMO ", want, " wall=", lang, " kit=", main.cover_slots[0].kit_id)
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


func _assert_radio_contract(main) -> bool:
	if main.cover_slots.size() != 6:
		push_error("SMOKE_RADIO_COVERS n=%s" % main.cover_slots.size())
		quit(62)
		return false
	if main.level.door_cell.x >= 0:
		push_error("SMOKE_RADIO_HAS_DOOR %s" % str(main.level.door_cell))
		quit(62)
		return false
	if not main.level.has_ammo_pack:
		push_error("SMOKE_RADIO_NO_PACK")
		quit(62)
		return false
	if main.barrels.size() != 0 or main.level.barrel_cell.x >= 0:
		push_error("SMOKE_RADIO_BARREL")
		quit(62)
		return false
	if not main.level.route_cells.has("main") or not main.level.route_cells.has("flank") or not main.level.route_cells.has("sneak") or not main.level.route_cells.has("echo"):
		push_error("SMOKE_RADIO_ROUTES")
		quit(62)
		return false
	if main._active_routes().size() != 4:
		push_error("SMOKE_RADIO_ACTIVE_ROUTES n=%s" % main._active_routes().size())
		quit(62)
		return false
	if str(main.level.title).find("电台") < 0:
		push_error("SMOKE_RADIO_TITLE %s" % main.level.title)
		quit(62)
		return false
	var pages: Array = TutorialOverlay.pages_for("radio")
	if pages.size() != 2:
		push_error("SMOKE_RADIO_TUTORIAL n=%s" % pages.size())
		quit(62)
		return false
	var p0: Dictionary = pages[0]
	var p1: Dictionary = pages[1]
	if str(p0.get("body", "")).find("回波") < 0:
		push_error("SMOKE_RADIO_TUTORIAL_ECHO %s" % str(p0.get("body", "")))
		quit(62)
		return false
	if str(p1.get("body", "")).find("5.2") < 0 or str(p1.get("body", "")).find("绊索") < 0:
		push_error("SMOKE_RADIO_TUTORIAL_SNEAK %s" % str(p1.get("body", "")))
		quit(62)
		return false
	if str(main.level.teaching).find("5.2") < 0 or str(main.level.teaching).find("绊索") < 0:
		push_error("SMOKE_RADIO_TEACHING %s" % main.level.teaching)
		quit(62)
		return false
	var sneak: Vector2 = main.grid.cell_to_world_center(Vector2i(7, 11))
	if not main._near_any_route_segment(sneak, main.TRIPWIRE_ROUTE_DIST):
		push_error("SMOKE_RADIO_TRIP_SNEAK")
		quit(62)
		return false
	if not main.grid.is_blocked(20, 10):
		push_error("SMOKE_RADIO_CORE_OPEN")
		quit(62)
		return false
	if not main.grid.is_blocked(18, 7):
		push_error("SMOKE_RADIO_DISH_PAD_OPEN")
		quit(62)
		return false
	if main.grid.is_blocked(7, 11) or main.grid.is_blocked(13, 12) or main.grid.is_blocked(32, 11) or main.grid.is_blocked(24, 12):
		push_error("SMOKE_RADIO_LANE_BLOCKED")
		quit(62)
		return false
	# Mast-hall vs depot tank farm: (15,8) is blocked on depot and must be open on radio.
	if main.grid.is_blocked(15, 8):
		push_error("SMOKE_RADIO_STILL_TANK_RECT")
		quit(62)
		return false
	if not main.grid.is_blocked(17, 9) or not main.grid.is_blocked(19, 10):
		push_error("SMOKE_RADIO_NO_TOWER")
		quit(62)
		return false
	if not main.grid.is_blocked(29, 11):
		push_error("SMOKE_RADIO_RACKS_SHORT")
		quit(62)
		return false
	var max_main := 0.0
	var min_sneak := 999.0
	var min_echo := 999.0
	var sneak_n := 0
	var main_n := 0
	var flank_n := 0
	var echo_n := 0
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
		elif str(spec["route"]) == "echo":
			echo_n += 1
			min_echo = minf(min_echo, delay)
	if main_n < 1 or flank_n < 1 or sneak_n < 1 or echo_n < 1:
		push_error("SMOKE_RADIO_SPAWN_SPLIT main=%s flank=%s sneak=%s echo=%s" % [main_n, flank_n, sneak_n, echo_n])
		quit(62)
		return false
	if min_sneak < 3.0 or min_sneak <= max_main + 1.5:
		push_error("SMOKE_RADIO_SNEAK_NOT_DELAYED main_max=%s sneak_min=%s" % [max_main, min_sneak])
		quit(62)
		return false
	if min_echo < 5.0:
		push_error("SMOKE_RADIO_ECHO_NOT_DELAYED echo=%s" % min_echo)
		quit(62)
		return false
	var echo_d: float = float(main.level.delay_for_actor(5))
	if absf(echo_d - 5.2) > 0.001:
		push_error("SMOKE_RADIO_ECHO_ACTOR %s" % echo_d)
		quit(62)
		return false
	if not main.level.has_method("kit_for_actor") or str(main.level.kit_for_actor(5)) != "echo":
		push_error("SMOKE_RADIO_NO_ECHO_KIT %s" % (main.level.kit_for_actor(5) if main.level.has_method("kit_for_actor") else "no_api"))
		quit(62)
		return false
	if str(main.level.second_trap_route()) != "sneak":
		push_error("SMOKE_RADIO_TRAP_NOT_SNEAK %s" % main.level.second_trap_route())
		quit(62)
		return false
	if not main.has_method("echo_callout_visible") or not bool(main.echo_callout_visible()):
		push_error("SMOKE_RADIO_NO_ECHO_CALLOUT")
		quit(62)
		return false
	var echo_tag = main.echo_callout.get_node_or_null("Tag") if main.echo_callout else null
	if echo_tag == null or str(echo_tag.text).find("回波") < 0:
		push_error("SMOKE_RADIO_ECHO_CALLOUT %s" % (echo_tag.text if echo_tag else "null"))
		quit(62)
		return false
	if main.has_method("echo_wait_breathing") and not bool(main.echo_wait_breathing()):
		push_error("SMOKE_RADIO_NO_ECHO_BREATH")
		quit(62)
		return false
	print(
		"SMOKE_OK_RADIO_CONTRACT covers=6 routes=4 sneak=", min_sneak,
		" echo=", echo_d, " dish_pad kit=echo hall breath=1"
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


func _assert_weapon_models(_main = null) -> bool:
	var W: GDScript = load("res://scripts/raid/weapon_catalog.gd") as GDScript
	if W == null:
		push_error("SMOKE_NO_WEAPON_CATALOG")
		quit(82)
		return false
	var rifle: Dictionary = W.def("rifle")
	if str(rifle.get("id", "")) != "rifle":
		push_error("SMOKE_RIFLE_CLASS_ID %s" % rifle.get("id", ""))
		quit(82)
		return false
	if absf(float(rifle.get("range_px", 0.0)) - 220.0) > 0.1:
		push_error("SMOKE_RIFLE_RANGE %s" % rifle.get("range_px", 0.0))
		quit(82)
		return false
	if W.model_ids().size() != 10:
		push_error("SMOKE_KIT_COUNT n=%s" % W.model_ids().size())
		quit(82)
		return false
	for banned in W.banned_tail():
		if str(banned) in W.model_ids():
			push_error("SMOKE_TAIL_STILL %s" % banned)
			quit(82)
			return false
	var table: Array = W.kit_table()
	if table.size() != 5:
		push_error("SMOKE_KIT_FAMILIES %s" % table.size())
		quit(82)
		return false
	for row in table:
		var fam := str(row.get("family", ""))
		var allied := str(row.get("allied", ""))
		var axis := str(row.get("axis", ""))
		if W.family_of(allied) != fam or W.family_of(axis) != fam:
			push_error("SMOKE_KIT_FAMILY %s %s %s" % [fam, allied, axis])
			quit(82)
			return false
		if str(W.side_of(allied)) != "allied" or str(W.side_of(axis)) != "axis":
			push_error("SMOKE_KIT_SIDE %s %s" % [allied, axis])
			quit(82)
			return false
		if W.models_in_family(fam).size() != 2:
			push_error("SMOKE_FAMILY_NOT_PAIR %s %s" % [fam, W.models_in_family(fam)])
			quit(82)
			return false
	if not bool(W.is_firearm("kar98k")) or W.family_of("kar98k") != "rifle":
		push_error("SMOKE_K98_FAMILY %s" % W.family_of("kar98k"))
		quit(82)
		return false
	if W.ammo_kind_of("kar98k") != "rifle" or W.ammo_kind_of("rifle_ammo") != "rifle":
		push_error("SMOKE_K98_AMMO")
		quit(82)
		return false
	var k98: Dictionary = W.def("kar98k")
	var garand: Dictionary = W.def("m1_garand")
	if float(k98.get("shot_interval", 0.0)) <= float(garand.get("shot_interval", 0.0)):
		push_error("SMOKE_K98_NOT_SLOWER_THAN_GARAND")
		quit(82)
		return false
	if absf(float(k98.get("damage", 0.0)) - float(garand.get("damage", 0.0))) < 4.0:
		push_error("SMOKE_RIFLE_MODELS_SAME_DMG")
		quit(82)
		return false
	var mg42: Dictionary = W.def("mg42")
	var bar: Dictionary = W.def("bar")
	if float(mg42.get("shot_interval", 1.0)) >= float(bar.get("shot_interval", 0.0)):
		push_error("SMOKE_MG42_NOT_FASTER_THAN_BAR")
		quit(82)
		return false
	if int(mg42.get("start_ammo", 0)) <= int(bar.get("start_ammo", 0)):
		push_error("SMOKE_MG42_BELT_NOT_LARGER")
		quit(82)
		return false
	var mp40: Dictionary = W.def("mp40")
	var thompson: Dictionary = W.def("thompson")
	if W.family_of("mp40") != "smg" or W.family_of("thompson") != "smg":
		push_error("SMOKE_SMG_FAMILY")
		quit(82)
		return false
	if float(thompson.get("shot_interval", 1.0)) >= float(mp40.get("shot_interval", 0.0)):
		push_error("SMOKE_THOMPSON_NOT_FASTER_THAN_MP40")
		quit(82)
		return false
	if str(W.sfx_cue("mg42")) == str(W.sfx_cue("kar98k")):
		push_error("SMOKE_SFX_NOT_DISTINCT")
		quit(82)
		return false
	if str(W.sfx_cue("rifle")) != "fire" or str(W.sfx_cue("mg")) != "fire_mg":
		push_error("SMOKE_CLASS_SFX")
		quit(82)
		return false
	var Art: GDScript = load("res://scripts/art/weapon_art.gd") as GDScript
	if Art == null:
		push_error("SMOKE_NO_WEAPON_ART")
		quit(82)
		return false
	if Art.silhouette("kar98k") == Art.silhouette("m1_garand"):
		push_error("SMOKE_RIFLE_SILHOUETTES_IDENTICAL")
		quit(82)
		return false
	if Art.silhouette("mp40") == Art.silhouette("thompson"):
		push_error("SMOKE_SMG_SILHOUETTES_IDENTICAL")
		quit(82)
		return false
	if Art.silhouette("mg42") == Art.silhouette("bar"):
		push_error("SMOKE_MG_SILHOUETTES_IDENTICAL")
		quit(82)
		return false
	if Art.silhouette("m1911") == Art.silhouette("luger"):
		push_error("SMOKE_PISTOL_SILHOUETTES_IDENTICAL")
		quit(82)
		return false
	if Art.silhouette("springfield") == Art.silhouette("kar98k_zf"):
		push_error("SMOKE_SCOUT_SILHOUETTES_IDENTICAL")
		quit(82)
		return false
	var k98_tip := 0.0
	for p in Art.silhouette("kar98k"):
		k98_tip = minf(k98_tip, p.y)
	if k98_tip > -16.0:
		push_error("SMOKE_K98_BARREL_SHORT %s" % k98_tip)
		quit(82)
		return false
	if _main != null and _main.operators.size() >= 1:
		var op: OperatorUnit = _main.operators[0]
		op.apply_weapon("kar98k", true)
		if str(op.weapon_id) != "kar98k":
			push_error("SMOKE_APPLY_K98 %s" % op.weapon_id)
			quit(82)
			return false
		if absf(op.shot_interval - float(k98.get("shot_interval", 0.0))) > 0.001:
			push_error("SMOKE_APPLY_K98_INTERVAL %s" % op.shot_interval)
			quit(82)
			return false
		op.apply_weapon("m1_garand", true)
		if op.shot_interval >= float(k98.get("shot_interval", 0.0)):
			push_error("SMOKE_GARAND_NOT_FASTER_IN_HAND")
			quit(82)
			return false
		var mixed: Dictionary = op.receive_item("mg_ammo", 8)
		if int(op.ammo_pool.get("mg", 0)) < 8 or not bool(mixed.get("pooled", false)):
			push_error("SMOKE_MODEL_AMMO_POOL %s %s" % [op.ammo_pool, mixed])
			quit(82)
			return false
		op.apply_weapon("rifle", true)
		if str(op.weapon_id) != "rifle":
			push_error("SMOKE_REVERT_RIFLE %s" % op.weapon_id)
			quit(82)
			return false
		op.wipe_inventory()
	if str(W.resolve_crate_kind("rifle", "yard")) != "kar98k":
		push_error("SMOKE_RESOLVE_YARD_RIFLE %s" % W.resolve_crate_kind("rifle", "yard"))
		quit(82)
		return false
	if str(W.resolve_crate_kind("smg", "yard")) != "thompson":
		push_error("SMOKE_RESOLVE_YARD_SMG %s" % W.resolve_crate_kind("smg", "yard"))
		quit(82)
		return false
	if str(W.resolve_crate_kind("m1911", "yard")) != "m1911":
		push_error("SMOKE_RESOLVE_KEEP_NAMED")
		quit(82)
		return false
	if str(W.sfx_cue("kar98k")) == str(W.sfx_cue("mg42")):
		push_error("SMOKE_SFX_NOT_DISTINCT")
		quit(82)
		return false
	if str(W.sfx_cue("m1911")) == str(W.sfx_cue("kar98k")):
		push_error("SMOKE_PISTOL_SFX_SAME")
		quit(82)
		return false
	print("SMOKE_OK_WEAPON_MODELS n=", W.model_ids().size())
	return true


func _assert_roles_and_cover(main) -> bool:
	if main.operators.size() < 3:
		push_error("SMOKE_NO_ROLES")
		quit(32)
		return false
	var rifle: OperatorUnit = main.operators[0]
	var mg: OperatorUnit = main.operators[1]
	var scout: OperatorUnit = main.operators[2]
	rifle.apply_weapon("rifle", true)
	mg.apply_weapon("mg", true)
	scout.apply_weapon("scout", true)
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
	if not scout.visible:
		push_error("SMOKE_SCOUT_HIDDEN_AFTER_CLEAR")
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
	main._refresh_selection_visual()
	var gold := Color(0.95, 0.85, 0.35)
	if rifle.body.color.is_equal_approx(gold):
		push_error("SMOKE_SELECTED_BODY_GOLD %s" % str(rifle.body.color))
		quit(32)
		return false
	if rifle.body.color != rifle.body_color:
		push_error("SMOKE_SELECTED_NOT_KIT col=%s kit=%s" % [rifle.body.color, rifle.body_color])
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
	if not main.sfx.has_cue("fire_mg") or not main.sfx.has_cue("fire_scout"):
		push_error("SMOKE_NO_ROLE_FIRE_CUES")
		quit(36)
		return false
	main._sfx_every_shot(main.operators[0] if not main.operators.is_empty() else null)
	if str(main.sfx.last_cue) != "fire":
		push_error("SMOKE_EVERY_SHOT_CUE %s" % main.sfx.last_cue)
		quit(36)
		return false
	if main.operators.size() >= 2:
		main._sfx_every_shot(main.operators[1])
		if str(main.sfx.last_cue) != "fire_mg":
			push_error("SMOKE_MG_FIRE_CUE %s" % main.sfx.last_cue)
			quit(36)
			return false
	if main.operators.size() >= 3:
		main._sfx_every_shot(main.operators[2])
		if str(main.sfx.last_cue) != "fire_scout":
			push_error("SMOKE_SCOUT_FIRE_CUE %s" % main.sfx.last_cue)
			quit(36)
			return false
	if not main.sfx.has_cue("ui"):
		push_error("SMOKE_NO_UI_CUE")
		quit(36)
		return false
	main._select_op(0)
	if str(main.sfx.last_cue) != "ui":
		push_error("SMOKE_UI_SELECT_CUE %s" % main.sfx.last_cue)
		quit(36)
		return false
	if not main.sfx.has_cue("hit"):
		push_error("SMOKE_NO_HIT_CUE")
		quit(36)
		return false
	if not main.sfx.has_cue("echo_ping") or not main.sfx.has_cue("spawn"):
		push_error("SMOKE_NO_SPAWN_ECHO_CUES")
		quit(36)
		return false
	if not main.sfx.has_cue("handoff") or not main.sfx.has_cue("leak") or not main.sfx.has_cue("night_enter"):
		push_error("SMOKE_NO_HANDOFF_LEAK_ENTER_CUES")
		quit(36)
		return false
	if audio != null and audio.has_method("has_layered_mood") and not bool(audio.has_layered_mood()):
		push_error("SMOKE_NO_LAYERED_MOOD")
		quit(36)
		return false
	var hp0: float = float(main.operators[0].hp)
	main.operators[0].take_damage(4.0)
	if str(main.sfx.last_cue) != "hit":
		push_error("SMOKE_HIT_CUE %s" % main.sfx.last_cue)
		quit(36)
		return false
	main.operators[0].hp = hp0
	main.operators[0].alive = true
	main.operators[0]._apply_body_modulate()
	if main.sfx.has_method("cue_peak"):
		var fire_p: float = float(main.sfx.cue_peak("fire"))
		var ui_p: float = float(main.sfx.cue_peak("ui"))
		var ten_p: float = float(main.sfx.cue_peak("tension"))
		var echo_p: float = float(main.sfx.cue_peak("echo_ping"))
		if fire_p < ui_p * 1.15:
			push_error("SMOKE_SFX_FIRE_THIN fire=%s ui=%s" % [fire_p, ui_p])
			quit(36)
			return false
		if ten_p < 0.18 or echo_p < 0.10:
			push_error("SMOKE_SFX_STING_THIN tension=%s echo=%s" % [ten_p, echo_p])
			quit(36)
			return false
		print("SMOKE_OK_SFX_BODY fire=", snapped(fire_p, 0.01), " tension=", snapped(ten_p, 0.01), " echo=", snapped(echo_p, 0.01))
	if main.sfx.has_method("cue_duration_sec"):
		var db := float(main.sfx.cue_duration_sec("fire_bolt"))
		var ds := float(main.sfx.cue_duration_sec("fire_smg"))
		var dmg := float(main.sfx.cue_duration_sec("fire_mg"))
		var d42 := float(main.sfx.cue_duration_sec("fire_mg42"))
		if db - ds < 0.06:
			push_error("SMOKE_BOLT_NOT_LONGER bolt=%s smg=%s" % [db, ds])
			quit(36)
			return false
		if absf(d42 - dmg) < 0.02:
			push_error("SMOKE_MG42_DURATION_SAME mg=%s mg42=%s" % [dmg, d42])
			quit(36)
			return false
		if not main.sfx.has_cue("fire_pistol") or not main.sfx.has_cue("fire_shotgun"):
			push_error("SMOKE_NO_NEW_FIRE_CUES")
			quit(36)
			return false
		print("SMOKE_OK_SFX_MODELS bolt=", snapped(db, 0.01), " smg=", snapped(ds, 0.01), " mg=", snapped(dmg, 0.01), " mg42=", snapped(d42, 0.01))
	print("SMOKE_OK_SFX cues=role_fire muted=", main.sfx.muted, " every_shot=1 ui=1 hit=1")
	return true


func _assert_engage_helpers(main) -> bool:
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0])
	var op: OperatorUnit = main.selected
	op.apply_weapon("rifle", true)
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
	main._select_op(1)
	main._deploy_selected_to(main.cover_slots[2], false)
	main._refresh_killzone_preview()
	if not main.has_method("_killzone_ops") or main._killzone_ops().size() < 2:
		push_error("SMOKE_KILLZONE_NOT_UNION n=%s" % (main._killzone_ops().size() if main.has_method("_killzone_ops") else -1))
		quit(40)
		return false
	if main.killzone_draw.get_child_count() < 1:
		push_error("SMOKE_KILLZONE_UNION_EMPTY")
		quit(40)
		return false
	print("SMOKE_OK_KILLZONE_UNION n=", main._killzone_ops().size())
	# Redeploy must keep the facing the player already set (same pad and pad-to-pad).
	main._select_op(0)
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
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	main._select_op(1)
	main._deploy_selected_to(main.cover_slots[1], false)
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[1], false)
	if main.operators[0].slot != main.cover_slots[1]:
		push_error("SMOKE_SWAP_MOVER_SLOT")
		quit(40)
		return false
	if not main.operators[1].visible or main.operators[1].slot != main.cover_slots[0]:
		push_error("SMOKE_SWAP_DISPLACED op1 vis=%s slot=%s" % [main.operators[1].visible, main.operators[1].slot])
		quit(40)
		return false
	print("SMOKE_OK_SLOT_SWAP")
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
	main.tool = main.Tool.TRIPWIRE
	if not main.has_method("_aim_world"):
		push_error("SMOKE_NO_AIM_WORLD")
		quit(41)
		return false
	main._pending_touch_world = on_route
	main._touches = {0: Vector2(12, 12)}
	main._update_tripwire_ghost()
	if main.tripwire_ghost.global_position.distance_to(on_route) > 4.0:
		push_error("SMOKE_TRIP_GHOST_NOT_TOUCH pos=%s want=%s" % [main.tripwire_ghost.global_position, on_route])
		quit(41)
		return false
	main._touches.clear()
	main._pending_touch_world = Vector2.ZERO
	main.tool = main.Tool.DEPLOY
	main._update_tripwire_ghost()
	print("SMOKE_OK_TRIPWIRE_TOOLING relocate=1 touch_ghost=1")
	return true


func _assert_touch_parity(main) -> bool:
	if not ResourceLoader.exists("res://scripts/c2/context_prompt.gd"):
		push_error("SMOKE_NO_CONTEXT_PROMPT")
		quit(44)
		return false
	if not ResourceLoader.exists("res://scripts/c2/skill_wheel.gd"):
		push_error("SMOKE_NO_SKILL_WHEEL")
		quit(44)
		return false
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
	main._refresh_touch_hud()
	if main.touch_hud._btns.has("pack") and bool(main.touch_hud._btns["pack"].visible):
		push_error("SMOKE_TOUCH_PACK_ON_YARD")
		quit(44)
		return false
	if main.touch_hud._btns.has("door") and bool(main.touch_hud._btns["door"].visible):
		push_error("SMOKE_TOUCH_DOOR_ON_YARD")
		quit(44)
		return false
	if not main.touch_hud._btns.has("replay"):
		push_error("SMOKE_NO_TOUCH_REPLAY")
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
	if main.has_method("desktop_command_bars_visible") and bool(main.desktop_command_bars_visible()):
		push_error("SMOKE_TOUCH_DESKTOP_BARS")
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_NO_DESKTOP_BARS")
	if not await _assert_simplified_touch(main):
		return false
	gs.force_touch_hud = false
	main._ensure_touch_hud()
	print("SMOKE_OK_TOUCH_PARITY")
	return true


func _assert_simplified_touch(main) -> bool:
	## Phone default = 简配夜袭. Portraits in the thumb band, SETUP ≤ 3 keys,
	## ALERT = 3 keys, left cards / skill bar / minimap off.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	var th = main.touch_hud
	if th == null:
		push_error("SMOKE_NO_TOUCH_FOR_SIMPLE")
		quit(44)
		return false
	var setup_n := int(th.setup_visible_button_count()) if th.has_method("setup_visible_button_count") else -1
	if setup_n > 5 or setup_n < 4:
		push_error("SMOKE_TOUCH_SETUP_CROWDED n=%s" % setup_n)
		quit(44)
		return false
	var cmds: PackedStringArray = th.setup_visible_cmds() if th.has_method("setup_visible_cmds") else PackedStringArray()
	if not cmds.has("crouch") or not cmds.has("bag") or not cmds.has("alarm") or not cmds.has("rotate_cw") or not cmds.has("rotate_ccw"):
		push_error("SMOKE_TOUCH_RESIDENT %s" % " ".join(cmds))
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_RESIDENT ", " ".join(cmds))
	var saved_phase = main.phase
	main.phase = main.Phase.WATCHING
	main._refresh_touch_hud()
	var watch_n := int(th.watch_visible_button_count()) if th.has_method("watch_visible_button_count") else -1
	var watch_cmds: PackedStringArray = th.watch_visible_cmds() if th.has_method("watch_visible_cmds") else PackedStringArray()
	if watch_n != 3:
		push_error("SMOKE_TOUCH_WATCH_KEYS n=%s cmds=%s" % [watch_n, " ".join(watch_cmds)])
		quit(44)
		return false
	if not watch_cmds.has("pause") or not watch_cmds.has("speed") or not watch_cmds.has("abort"):
		push_error("SMOKE_TOUCH_WATCH_SET %s" % " ".join(watch_cmds))
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_WATCH_3 ", " ".join(watch_cmds))
	main.phase = saved_phase
	main._refresh_touch_hud()
	if main.role_box != null and bool(main.role_box.visible):
		push_error("SMOKE_LEFT_CARDS_ON_PHONE")
		quit(44)
		return false
	print("SMOKE_OK_LEFT_CARDS_OFF")
	if main.c2 == null:
		push_error("SMOKE_NO_C2_SIMPLE")
		quit(44)
		return false
	if main.c2.skill_bar != null and bool(main.c2.skill_bar.visible):
		push_error("SMOKE_SKILLBAR_ON_PHONE")
		quit(44)
		return false
	print("SMOKE_OK_SKILLBAR_OFF")
	if main.c2.minimap != null and bool(main.c2.minimap.visible):
		push_error("SMOKE_MINIMAP_ON_PHONE")
		quit(44)
		return false
	print("SMOKE_OK_MINIMAP_OFF")
	var strip = main.c2.portraits
	if strip == null:
		push_error("SMOKE_NO_PORTRAITS_SIMPLE")
		quit(44)
		return false
	var parent = strip.get_parent()
	if parent == null or str(parent.name) != "PortraitSlot":
		push_error("SMOKE_PORTRAIT_NOT_SLOT parent=%s" % (parent.name if parent else "null"))
		quit(44)
		return false
	if float(parent.offset_top) > -90.0 or not is_equal_approx(float(parent.anchor_bottom), 1.0):
		push_error("SMOKE_PORTRAIT_NOT_THUMB off_top=%s anchor_bot=%s y=%s" % [parent.offset_top, parent.anchor_bottom, strip.global_position.y])
		quit(44)
		return false
	print("SMOKE_OK_PORTRAIT_THUMB off_top=", parent.offset_top, " y=", snapped(strip.global_position.y, 0.1))
	if not await _assert_context_hotspots(main):
		return false
	if not await _assert_touch_feel_052(main):
		return false
	if not await _assert_touch_feel_053(main):
		return false
	if not await _assert_touch_feel_054(main):
		return false
	if not await _assert_touch_feel_055(main):
		return false
	if not await _assert_touch_feel_056(main):
		return false
	if not await _assert_touch_feel_057(main):
		return false
	if not await _assert_touch_feel_058(main):
		return false
	if not await _assert_touch_feel_059(main):
		return false
	if not await _assert_touch_feel_0510(main):
		return false
	if not await _assert_touch_feel_0511(main):
		return false
	## leftover feel 0512–0538: facing/blend/arc/dest re-sims. 0511 holds
	## badge+west combo; 0539 holds dest span 6 + south + compact + settle.
	print("SMOKE_OK_TOUCH_FEEL_LEFTOVER_0512_0538_SLIM")
	if not await _assert_touch_feel_0539(main):
		return false
	if not await _assert_touch_feel_0540(main):
		return false
	if not await _assert_touch_feel_0541(main):
		return false
	if not await _assert_touch_feel_0542(main):
		return false
	if not await _assert_touch_feel_0601(main):
		return false
	if not await _assert_touch_feel_0603(main):
		return false
	if not await _assert_touch_feel_0605(main):
		return false
	if not await _assert_touch_feel_0607(main):
		return false
	if not await _assert_touch_feel_0611(main):
		return false
	if not await _assert_touch_feel_0613(main):
		return false
	if not await _assert_touch_feel_0615(main):
		return false
	if not await _assert_touch_feel_0617(main):
		return false
	if not await _assert_touch_feel_0619(main):
		return false
	return true


func _assert_context_hotspots(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or not prompt.has_method("refresh_now"):
		push_error("SMOKE_NO_PROMPT_NODE")
		quit(44)
		return false
	if main.raid_stashes.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_STASH_FOR_HOTSPOT")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	var st = main.raid_stashes[0]
	op.global_position = st.global_position
	main._select_op(0)
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_HOTSPOT_NO_CRATE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	if int(prompt.hotspot_count()) > 2:
		push_error("SMOKE_HOTSPOT_TOO_MANY n=%s" % prompt.hotspot_count())
		quit(44)
		return false
	print("SMOKE_OK_HOTSPOT_CRATE n=", prompt.hotspot_count())
	if main.c2.sentries.is_empty():
		op.global_position = home
		return true
	var sent = main.c2.sentries[0]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	var clear: Vector2 = _empty_probe_world(main)
	op.global_position = clear
	# Wolf west of sentry, sentry facing east → backstab → 割喉.
	sent.global_position = clear + Vector2(16, 0)
	sent.facing_deg = 0.0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("割喉")):
		push_error("SMOKE_HOTSPOT_NO_KNIFE caps=%s pos=%s" % [" ".join(prompt.visible_captions()), clear])
		quit(44)
		return false
	if bool(prompt.has_caption("口哨")):
		push_error("SMOKE_HOTSPOT_KNIFE_AND_WHISTLE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	print("SMOKE_OK_HOTSPOT_KNIFE")
	# Wolf east of sentry, same facing → front → 口哨, not 割喉.
	sent.global_position = clear + Vector2(-16, 0)
	sent.facing_deg = 0.0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("口哨")):
		push_error("SMOKE_HOTSPOT_NO_WHISTLE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	if bool(prompt.has_caption("割喉")):
		push_error("SMOKE_HOTSPOT_FRONT_KNIFE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	print("SMOKE_OK_HOTSPOT_WHISTLE")
	# Rear approach, not yet in knife range → 绕背 guide, not 割喉.
	sent.global_position = clear + Vector2(64, 0)
	sent.facing_deg = 0.0
	op.global_position = clear
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_HOTSPOT_NO_FLANK caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	if bool(prompt.has_caption("割喉")):
		push_error("SMOKE_HOTSPOT_FLANK_IS_KNIFE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	print("SMOKE_OK_HOTSPOT_FLANK")
	# Too far behind: no 绕背.
	sent.global_position = clear + Vector2(120, 0)
	sent.facing_deg = 0.0
	prompt.refresh_now()
	await process_frame
	if bool(prompt.has_caption("绕背")):
		push_error("SMOKE_FLANK_TOO_FAR caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	print("SMOKE_OK_FLANK_RANGE")
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	op.global_position = home
	prompt.refresh_now()
	return true


func _empty_probe_world(main) -> Vector2:
	if main.grid == null:
		return Vector2(96, 240)
	for x in range(2, 14):
		for y in range(4, 16):
			var cell := Vector2i(x, y)
			if main.grid.has_method("is_blocked") and bool(main.grid.is_blocked(cell.x, cell.y)):
				continue
			var w: Vector2 = main.grid.cell_to_world_center(cell)
			var busy := false
			for st in main.raid_stashes:
				if st != null and is_instance_valid(st) and w.distance_to(st.global_position) < 48.0:
					busy = true
					break
			if busy:
				continue
			if main.has_method("_nearest_slot") and main._nearest_slot(w, 40.0) != null:
				continue
			return w
	return Vector2(96, 240)


func _assert_touch_feel_052(main) -> bool:
	## North-wall fold, gesture split, follow badge.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not main.has_method("dump_touch_feel"):
		push_error("SMOKE_NO_TOUCH_FEEL_API")
		quit(44)
		return false
	var feel: Dictionary = main.dump_touch_feel()
	if bool(feel.get("teach", true)):
		push_error("SMOKE_NORTH_TEACH_ON")
		quit(44)
		return false
	if bool(feel.get("legend", true)):
		push_error("SMOKE_NORTH_LEGEND_ON")
		quit(44)
		return false
	if bool(feel.get("timeline", true)):
		push_error("SMOKE_NORTH_TIMELINE_ON_SCOUT")
		quit(44)
		return false
	if float(feel.get("intel_y", 200.0)) > 56.0:
		push_error("SMOKE_NORTH_INTEL_Y %s" % feel.get("intel_y"))
		quit(44)
		return false
	if float(feel.get("check_bot", 200.0)) > 48.0:
		push_error("SMOKE_NORTH_CHECK_BOT %s" % feel.get("check_bot"))
		quit(44)
		return false
	print(
		"SMOKE_OK_NORTH_FOLDED intel_y=", snapped(float(feel.get("intel_y", 0.0)), 0.1),
		" check_bot=", snapped(float(feel.get("check_bot", 0.0)), 0.1)
	)
	if not main.has_method("toggle_follow") or main.operators.size() < 2:
		push_error("SMOKE_NO_FOLLOW_API")
		quit(44)
		return false
	var op1: OperatorUnit = main.operators[1]
	var was := bool(op1.follow_lead)
	main.toggle_follow(1)
	if bool(op1.follow_lead) == was:
		push_error("SMOKE_FOLLOW_NOOP")
		quit(44)
		return false
	if not bool(op1.follow_lead):
		main.toggle_follow(1)
	if not bool(op1.follow_lead):
		push_error("SMOKE_FOLLOW_OFF")
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW")
	main.toggle_follow(1)
	if bool(op1.follow_lead):
		push_error("SMOKE_FOLLOW_STUCK")
		quit(44)
		return false
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var clear: Vector2 = _empty_probe_world(main)
	var home: Vector2 = main.operators[0].global_position
	main._select_op(0)
	main.operators[0].stop_move()
	if home.distance_to(clear) < 48.0:
		clear = home + Vector2(96, 0)
	var pan0: Vector2 = main._cam_pan
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = xf * clear
	main._unhandled_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = press.position + Vector2(48, 0)
	drag.relative = Vector2(48, 0)
	main._unhandled_input(drag)
	var rel := InputEventScreenTouch.new()
	rel.index = 0
	rel.pressed = false
	rel.position = drag.position
	main._unhandled_input(rel)
	if str(main._last_touch_gesture) != "pan":
		push_error("SMOKE_GESTURE_NOT_PAN got=%s" % main._last_touch_gesture)
		quit(44)
		return false
	if main.operators[0].is_moving():
		push_error("SMOKE_PAN_MOVED_OP")
		quit(44)
		return false
	if main._cam_pan.is_equal_approx(pan0):
		push_error("SMOKE_PAN_NO_CAM")
		quit(44)
		return false
	print("SMOKE_OK_GESTURE_PAN")
	main._cam_pan = pan0
	if main.has_method("_apply_cam"):
		main._apply_cam()
	var press2 := InputEventScreenTouch.new()
	press2.index = 0
	press2.pressed = true
	press2.position = xf * clear
	main._unhandled_input(press2)
	main._cover_hold_msec = Time.get_ticks_msec() - 320
	main._cover_hold_slot = null
	main._tick_touch_hold()
	if not bool(main._sprint_hold_armed):
		push_error("SMOKE_SPRINT_NOT_ARMED")
		quit(44)
		return false
	var rel2 := InputEventScreenTouch.new()
	rel2.index = 0
	rel2.pressed = false
	rel2.position = press2.position
	main._unhandled_input(rel2)
	if str(main._last_touch_gesture) != "sprint":
		push_error("SMOKE_GESTURE_NOT_SPRINT got=%s" % main._last_touch_gesture)
		quit(44)
		return false
	if main.selected == null or not bool(main.selected.sprinting):
		push_error("SMOKE_SPRINT_NOT_SET")
		quit(44)
		return false
	print("SMOKE_OK_GESTURE_SPRINT")
	main.operators[0].stop_move()
	main.operators[0].set_sprint(false)
	main.operators[0].global_position = home
	print("SMOKE_OK_TOUCH_FEEL")
	return true


func _assert_touch_feel_053(main) -> bool:
	## North world ink, cone-avoiding 绕背/跟上, tighter hotspots, yard loop taps.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not main.has_method("dump_world_ink"):
		push_error("SMOKE_NO_WORLD_INK_API")
		quit(44)
		return false
	var ink: Dictionary = main.dump_world_ink()
	if int(ink.get("spawn_visible", 9)) > 0:
		push_error("SMOKE_SPAWN_TAGS_ON n=%s" % ink.get("spawn_visible"))
		quit(44)
		return false
	if int(ink.get("route_visible", 9)) > 0:
		push_error("SMOKE_ROUTE_TAGS_ON n=%s" % ink.get("route_visible"))
		quit(44)
		return false
	if int(ink.get("cover_visible", 9)) > 0:
		push_error("SMOKE_COVER_TAGS_ON n=%s" % ink.get("cover_visible"))
		quit(44)
		return false
	if int(ink.get("north_visible", 9)) > 0:
		push_error("SMOKE_NORTH_LABELS n=%s" % ink.get("north_visible"))
		quit(44)
		return false
	if int(ink.get("mouse_eat", 9)) > 0:
		push_error("SMOKE_WORLD_LABEL_MOUSE n=%s" % ink.get("mouse_eat"))
		quit(44)
		return false
	print(
		"SMOKE_OK_WORLD_INK spawn=", ink.get("spawn_visible"),
		" route=", ink.get("route_visible"),
		" north=", ink.get("north_visible"),
		" eat=", ink.get("mouse_eat")
	)
	if not await _assert_hotspot_crate_tight(main):
		return false
	if not await _assert_stealth_cone_paths(main):
		return false
	if not await _assert_yard_touch_loop(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_053")
	return true


func _assert_hotspot_crate_tight(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.raid_stashes.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_CRATE_TIGHT")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	var st = main.raid_stashes[0]
	main._select_op(0)
	op.stop_move()
	var side: Vector2 = st.global_position + Vector2(32, 0)
	if main.grid:
		var cell: Vector2i = main.grid.world_to_cell(side)
		if main.grid.is_blocked(cell.x, cell.y):
			side = st.global_position + Vector2(0, 32)
			cell = main.grid.world_to_cell(side)
			if main.grid.is_blocked(cell.x, cell.y):
				side = st.global_position + Vector2(-32, 0)
		side = main.grid.cell_to_world_center(main.grid.world_to_cell(side))
	op.global_position = side
	prompt.refresh_now()
	await process_frame
	if bool(prompt.has_caption("开匣")):
		push_error("SMOKE_CRATE_ADJACENT_HOTSPOT d=%s caps=%s" % [op.global_position.distance_to(st.global_position), " ".join(prompt.visible_captions())])
		quit(44)
		return false
	print("SMOKE_OK_HOTSPOT_CRATE_TIGHT")
	op.global_position = st.global_position
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_HOTSPOT_CRATE_LOST caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	op.global_position = home
	prompt.refresh_now()
	return true


func _assert_stealth_cone_paths(main) -> bool:
	if not main.has_method("stealth_path_cells") or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_NO_STEALTH_PATH_API")
		quit(44)
		return false
	var sent = main.c2.sentries[0]
	var op: OperatorUnit = main.operators[0]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	var op_home: Vector2 = op.global_position
	var sent_c := Vector2i(10, 12)
	var from_c := Vector2i(6, 12)
	var to_c := Vector2i(14, 12)
	if main.grid:
		if main.grid.is_blocked(sent_c.x, sent_c.y):
			sent_c = main.grid.world_to_cell(_empty_probe_world(main))
		if main.grid.is_blocked(from_c.x, from_c.y):
			from_c = Vector2i(6, 13)
		if main.grid.is_blocked(to_c.x, to_c.y):
			to_c = Vector2i(14, 13)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	op.global_position = main.grid.cell_to_world_center(from_c)
	main._select_op(0)
	var around: Array[Vector2i] = main.stealth_path_cells(from_c, to_c, op)
	if around.size() < 3:
		push_error("SMOKE_STEALTH_PATH_SHORT n=%s" % around.size())
		quit(44)
		return false
	var hits := 0
	for c in around:
		if main._sentry_blocks_stealth(main.grid.cell_to_world_center(c), op):
			hits += 1
	if hits > 0:
		push_error("SMOKE_STEALTH_HITS_CONE n=%s path=%s" % [hits, around])
		quit(44)
		return false
	print("SMOKE_OK_STEALTH_AROUND n=", around.size())
	main._start_flank_approach(sent.global_position)
	await process_frame
	var flank_hits := 0
	if op.move_path.size() > 0:
		for pt in op.move_path:
			if main._sentry_blocks_stealth(pt, op):
				flank_hits += 1
	if flank_hits > 0:
		push_error("SMOKE_FLANK_HITS_CONE n=%s" % flank_hits)
		quit(44)
		return false
	print("SMOKE_OK_FLANK_AVOID_CONE pts=", op.move_path.size())
	op.stop_move()
	if main.operators.size() >= 2:
		var fol: OperatorUnit = main.operators[1]
		var fol_home: Vector2 = fol.global_position
		if not bool(fol.follow_lead):
			main.toggle_follow(1)
		fol.global_position = main.grid.cell_to_world_center(from_c + Vector2i(0, 2))
		main._tick_squad_follow()
		var fol_hits := 0
		for pt2 in fol.move_path:
			if main._sentry_blocks_stealth(pt2, fol):
				fol_hits += 1
		if fol_hits > 0:
			push_error("SMOKE_FOLLOW_HITS_CONE n=%s" % fol_hits)
			quit(44)
			return false
		print("SMOKE_OK_FOLLOW_AVOID_CONE pts=", fol.move_path.size())
		fol.stop_move()
		if bool(fol.follow_lead):
			main.toggle_follow(1)
		fol.global_position = fol_home
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	op.global_position = op_home
	op.stop_move()
	main._pending_flank = null
	return true


func _assert_yard_touch_loop(main) -> bool:
	if not main.has_method("simulate_touch_tap") or not main.has_method("yard_touch_loop_cells"):
		push_error("SMOKE_NO_YARD_LOOP_API")
		quit(44)
		return false
	if main.operators.is_empty() or main.grid == null:
		push_error("SMOKE_YARD_LOOP_NO_OP")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	main._select_op(0)
	op.stop_move()
	var cells: Array[Vector2i] = main.yard_touch_loop_cells()
	if cells.size() < 6:
		push_error("SMOKE_YARD_LOOP_SHORT n=%s" % cells.size())
		quit(44)
		return false
	var prompt = main.c2.prompt if main.c2 else null
	var n_ok := 0
	for i in cells.size():
		var cell: Vector2i = cells[i]
		if main.grid.is_blocked(cell.x, cell.y):
			push_error("SMOKE_YARD_LOOP_BLOCKED %s" % str(cell))
			quit(44)
			return false
		var world: Vector2 = main.grid.cell_to_world_center(cell)
		op.stop_move()
		main.simulate_touch_tap(world)
		await process_frame
		var gest := str(main._last_touch_gesture)
		if gest != "tap" and gest != "sprint":
			push_error("SMOKE_YARD_LOOP_GESTURE i=%s got=%s cell=%s" % [i, gest, cell])
			quit(44)
			return false
		if main._nearest_slot(world, 14.0) != null and op.slot != null:
			push_error("SMOKE_YARD_LOOP_COVER_SNAP i=%s cell=%s" % [i, cell])
			quit(44)
			return false
		if not op.is_moving() and op.grid_cell() != cell:
			## Tap issued a walk; snap so the next tap is from this corner.
			if not op.is_moving():
				var path_ok := op.move_path.size() >= 2 or op.grid_cell() == cell
				if not path_ok and world.distance_to(op.global_position) > 8.0:
					push_error("SMOKE_YARD_LOOP_NO_WALK i=%s cell=%s at=%s" % [i, cell, op.grid_cell()])
					quit(44)
					return false
		op.stop_move()
		op.global_position = world
		if prompt:
			prompt.refresh_now()
		await process_frame
		if prompt and op.grid_cell() != cell:
			pass
		if prompt and bool(prompt.has_caption("上掩体")):
			push_error("SMOKE_YARD_LOOP_COVER_HOT i=%s cell=%s" % [i, cell])
			quit(44)
			return false
		var on_crate := false
		for st in main.raid_stashes:
			if st != null and is_instance_valid(st) and not bool(st.collected):
				if op.global_position.distance_to(st.global_position) <= 22.0:
					on_crate = true
					break
		if prompt and not on_crate and bool(prompt.has_caption("开匣")):
			push_error("SMOKE_YARD_LOOP_CRATE_HOT i=%s cell=%s caps=%s" % [i, cell, " ".join(prompt.visible_captions())])
			quit(44)
			return false
		n_ok += 1
	print("SMOKE_OK_YARD_TOUCH_LOOP n=", n_ok)
	op.stop_move()
	op.global_position = home
	if prompt:
		prompt.refresh_now()
	return true


func _assert_touch_feel_054(main) -> bool:
	## Crate names off on phone, 绕背 clears west court, follow spacing, yard loop kept in 053.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not main.has_method("dump_world_ink"):
		push_error("SMOKE_NO_WORLD_INK_054")
		quit(44)
		return false
	var ink: Dictionary = main.dump_world_ink()
	if int(ink.get("crate_visible", 9)) > 0:
		push_error("SMOKE_CRATE_TAGS_ON n=%s" % ink.get("crate_visible"))
		quit(44)
		return false
	print("SMOKE_OK_CRATE_TAGS_HIDDEN n=", ink.get("crate_visible"))
	if not await _assert_flank_clears_west(main):
		return false
	if not await _assert_follow_spacing(main):
		return false
	if not await _assert_yard_touch_loop(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_054")
	return true


func _assert_touch_feel_055(main) -> bool:
	## Follow stops outside / around 射界, 射界 world ink hidden, west crate+绕背+3-follow.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_facing_ink_hidden(main):
		return false
	if not await _assert_west_crate_touch(main):
		return false
	if not await _assert_west_flank_touch_path(main):
		return false
	if not await _assert_follow_stops_outside_cone(main):
		return false
	if not await _assert_follow_avoids_fire_sector(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_055")
	return true


func _assert_touch_feel_056(main) -> bool:
	## Dest rim margin, west-alley 3-follow queues instead of wrapping,
	## 西匣开匣 → 绕背 → 三人跟上 as one forced-touch path, no body-select / pad steal.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_cone_margin(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	if not await _assert_touch_no_body_select(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_056")
	return true


func _assert_touch_feel_057(main) -> bool:
	## Short 2–3 cell detour instead of idle-wait, tighter west-alley spacing,
	## 开匣→绕背→三人跟上 still one path, stacked-body mis-tap.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_short_detour(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	if not await _assert_west_stack_tap(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_057")
	return true


func _assert_touch_feel_058(main) -> bool:
	## Lead-walk follow continuity, full 绕背 dashed path, 跟 badge hit,
	## forced-touch path covers both.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_walk_continuity(main):
		return false
	if not await _assert_flank_guide_complete(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_058")
	return true


func _assert_touch_feel_059(main) -> bool:
	## Side 绕背 wraps the sentry body (min 4 cells), lead-stop formation
	## holds the endpoint, three-person follow + side wrap, 跟 probes.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_flank_side_wrap(main):
		return false
	if not await _assert_follow_settle_no_drop(main):
		return false
	if not await _assert_three_follow_side_wrap(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_059")
	return true


func _assert_touch_feel_0510(main) -> bool:
	## Follow dests sit behind the lead (left/right stagger, not hip),
	## stop land freezes another round, three-follow + side 绕背, 跟 probes.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_behind_stagger(main):
		return false
	if not await _assert_follow_settle_no_drop(main):
		return false
	if not await _assert_three_follow_side_wrap(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0510")
	return true


func _assert_touch_feel_0511(main) -> bool:
	## West-alley rear file (not a north-south queue), 射界 twist turns
	## the file, 跟 chip sits higher without eating gun/number, forced touch.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_follow_facing_turn(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0511")
	return true


func _assert_touch_feel_0512(main) -> bool:
	## Fine 射界: follow dests interpolate with facing (20° already moves),
	## west file stays compact, 跟 chip raised off gun, forced-touch path.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_facing_turn(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0512")
	return true


func _assert_touch_feel_0513(main) -> bool:
	## West alley 1-cell stagger + camera pullback, dest hops interpolate,
	## 拧射界换格 + 西巷三人跟上 forced-touch.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_facing_turn(main):
		return false
	if not await _assert_follow_dest_blend(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	if not await _assert_follow_badge_hit(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0513")
	return true


func _assert_touch_feel_0514(main) -> bool:
	## West dests stay 1-cell diagonal (not 2-cell wall stack). Camera holds
	## pullback on the west trio + yellow cone after they stop. Dest hops
	## lerp toward interpolated slot points. 拧射界换格 + 西巷三人跟上.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_facing_turn(main):
		return false
	if not await _assert_follow_dest_blend(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0514")
	return true


func _assert_touch_feel_0515(main) -> bool:
	## West trio observation rings shrink + camera tighter than 0.62.
	## 90° 拧射界 dests slide on the facing-slot arc, not a 3-cell walk.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_tight(main):
		return false
	if not await _assert_follow_face_arc(main):
		return false
	if not await _assert_follow_dest_blend(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0515")
	return true


func _assert_touch_feel_0516(main) -> bool:
	## 15° ↻ dests ride the slot ring; west trio extra stagger/scale;
	## arc samples snag onto walkable cells. 拧射界换格 + 西巷三人跟上.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_follow_nudge_arc(main):
		return false
	if not await _assert_west_body_stagger(main):
		return false
	if not await _assert_face_arc_walkable(main):
		return false
	if not await _assert_west_obs_tight(main):
		return false
	if not await _assert_follow_face_arc(main):
		return false
	if not await _assert_follow_dest_blend(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	if not await _assert_west_follow_queue(main):
		return false
	if not await _assert_west_combo_touch(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0516")
	return true


func _assert_touch_feel_0517(main) -> bool:
	## Follower bodies ride the facing-slot ring; west trio shrinks / half-cell
	## stand; compact ↻ hold-repeat; crate-clamped arcs stay round.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_compact_rotate(main):
		return false
	if not await _assert_follow_body_ring(main):
		return false
	if not await _assert_west_half_cell(main):
		return false
	if not await _assert_face_arc_round(main):
		return false
	if not await _assert_follow_nudge_arc(main):
		return false
	if not await _assert_west_body_stagger(main):
		return false
	if not await _assert_face_arc_walkable(main):
		return false
	if not await _assert_west_follow_rear(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0517")
	return true


func _assert_touch_feel_0518(main) -> bool:
	## Settle-on-ring after ↻ release, compact ↺ + swipe, west tighter,
	## rounder multi-crate arc. 0517 already ran compact rotate.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_tighter(main):
		return false
	if not await _assert_face_arc_cluster(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0518")
	return true


func _assert_touch_feel_0519(main) -> bool:
	## Compact 5-key narrow pack. 0520 re-runs west clearer + settle + cone.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_compact_narrow(main):
		return false
	if not await _assert_face_arc_cluster_round(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0519")
	return true


func _assert_touch_feel_0520(main) -> bool:
	## West trio shrink + faded yellow cone (visual), crate wall-arc bow.
	## Dest cells span ≤2. 0532 re-runs settle / compact / bidirectional ↺/↻.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_tighter(main):
		return false
	if not await _assert_west_clearer(main):
		return false
	if not await _assert_west_cone_fade(main):
		return false
	if not await _assert_face_arc_cluster(main):
		return false
	if not await _assert_face_arc_cluster_round(main):
		return false
	if not await _assert_face_arc_cluster_bow(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0520")
	return true


func _assert_touch_feel_0521(main) -> bool:
	## West trio dest-cell span 2 (second follower one cell further back).
	## 0532 re-runs settle / compact; 0520 already ran west tighter+cone.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_file_spread(main):
		return false
	if not await _assert_face_arc_cluster_bow(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0521")
	return true


func _assert_touch_feel_0522(main) -> bool:
	## First west follower out of the 1-cell pocket (along-file, no west-wall
	## hug), south-corridor crate arc stays off the east exit. 0532 re-runs
	## settle / compact; 0520 already ran west tighter+cone.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_first_pocket(main):
		return false
	if not await _assert_face_arc_south_corridor(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0522")
	return true


func _assert_touch_feel_0523(main) -> bool:
	## West trio body/ring one step smaller, south-corridor far-side bow
	## capped below ~28px. 0520 already ran settle / compact.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_scale_0523(main):
		return false
	if not await _assert_face_arc_south_cap(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0523")
	return true


func _assert_touch_feel_0524(main) -> bool:
	## Camera pull + observation-ring world offset for the west trio.
	## South-corridor far-side bow toward ~20px. 0520 already ran settle / compact.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_cam_ring_0524(main):
		return false
	if not await _assert_face_arc_south_cap_0524(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0524")
	return true


func _assert_touch_feel_0525(main) -> bool:
	## West trio dest cells restaggered (span 3, no west-wall hug). South-
	## corridor east-end y=14 samples pulled into y≤13. 0520 already ran
	## settle / compact.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0525(main):
		return false
	if not await _assert_face_arc_south_cap_0525(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0525")
	return true


func _assert_touch_feel_0526(main) -> bool:
	## West dest span 6. Full south-corridor path y14=0 (mid x≈21
	## included), east overshoot 0, axis_run 0.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_face_arc_south_cap_0526(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0526")
	return true


func _assert_touch_feel_0527(main) -> bool:
	## West dest span 6. Observation-ring world offset fans along-file
	## / courtyard (no west-wall hug). 0526 already asserted south y14=0.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_offset_0527(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0527")
	return true


func _assert_touch_feel_0528(main) -> bool:
	## West dest leftover. 0539 re-runs settle / compact / south path
	## plus the shrunk courtyard offset.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_cam_0528(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0528")
	return true


func _assert_touch_feel_0529(main) -> bool:
	## West dest leftover. 0539 re-runs settle / compact / south path
	## plus the shrunk courtyard offset.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_cam_0529(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0529")
	return true


func _assert_touch_feel_0530(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_cam_0530(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0530")
	return true


func _assert_touch_feel_0531(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_cam_0531(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0531")
	return true


func _assert_touch_feel_0532(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + detour ≤6 + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0532(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0532")
	return true


func _assert_touch_feel_0533(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + detour ≤6 + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0533(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0533")
	return true


func _assert_touch_feel_0534(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + detour ≤6 + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0534(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0534")
	return true


func _assert_touch_feel_0535(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0535(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0535")
	return true


func _assert_touch_feel_0536(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0536(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0536")
	return true


func _assert_touch_feel_0537(main) -> bool:
	## West dest leftover. 0538 re-runs settle / compact / south path
	## plus dest (6,6)/(5,16) + readable zoom/scales.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0537(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0537")
	return true


func _assert_touch_feel_0538(main) -> bool:
	## West dest leftover. 0539 re-runs settle / compact / south path
	## plus readable zoom/scales + shrunk courtyard offset.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0538(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0538")
	return true


func _assert_touch_feel_0539(main) -> bool:
	## West follow at ~1.0 zoom / 1.0 body+obs scale (pan/crop, not
	## postage-stamp world zoom). Dest (7,12)/(6,6)/(5,16) span 6,
	## detour ≤6. Courtyard / along-file ring offset shrunk so full-size
	## rings sit on the west file, not 154px into the crate courtyard.
	## Full south-corridor path y14=0, east 0, axis_run 0.
	## Settle-on-ring, bidirectional ↺/↻, yellow cone.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_dest_0539(main):
		return false
	if not await _assert_face_arc_south_cap_0526(main):
		return false
	if not await _assert_compact_rotate(main):
		return false
	if not await _assert_compact_narrow(main):
		return false
	if not await _assert_follow_settle_ring(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0539")
	return true


func _assert_touch_feel_0540(main) -> bool:
	## v0.5.40: obs fill fade/clip at 1.0 scale. Dest/zoom/body/kit_range stay.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_obs_fill_0540(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0540")
	return true


func _assert_touch_feel_0541(main) -> bool:
	## v0.5.41: west file tape through dests. Span 6 dests unchanged.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	await process_frame
	if not await _assert_west_file_0541(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0541")
	return true


func _assert_touch_feel_0542(main) -> bool:
	## First-session 跟 / 开匣 / 绕背 / 需枪 from yard scrape.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	if not await _assert_first_session_0542(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0542")
	return true


func _assert_touch_feel_0601(main) -> bool:
	## v0.6.1: west-wall 开匣 sits above+east of the crate, not in the soap.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	if not await _assert_west_crate_0601(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0601")
	return true


func _assert_touch_feel_0603(main) -> bool:
	## v0.6.2: yard hatch contrast + courtyard key. Presentation only.
	if not _assert_night_grade_0603(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0603")
	return true


func _assert_touch_feel_0605(main) -> bool:
	## v0.6.3: ALERT watch chrome — pause/speed/abort thumb-sized, short hint.
	main._ensure_touch_hud()
	if not _assert_alert_chrome_0605(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0605")
	return true


func _assert_touch_feel_0607(main) -> bool:
	## v0.6.4: 绕背 dashed wrap is fat enough to read. Dest/RAID unchanged.
	var src := FileAccess.get_file_as_string("res://scripts/c2/context_prompt.gd")
	if src.find("3.2") < 0 or src.find("0.90") < 0:
		push_error("SMOKE_FLANK_0607_THIN_DASH")
		quit(44)
		return false
	if not await _assert_flank_side_wrap(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0607")
	return true


func _assert_touch_feel_0611(main) -> bool:
	## v0.6.6: SCOUT beat line is short. Keep 交叉封锁 / 侧翼.
	var yard: LevelDef = LevelDef.by_id("yard")
	var beat := str(yard.beat_text)
	if beat.find("交叉封锁") < 0 or beat.find("侧翼") < 0:
		push_error("SMOKE_SCOUT_TIP_0611_MISS %s" % beat)
		quit(44)
		return false
	if beat.length() > 16:
		push_error("SMOKE_SCOUT_TIP_0611_LONG n=%s %s" % [beat.length(), beat])
		quit(44)
		return false
	if main.spawn_teach_label and str(main.spawn_teach_label.text).find("交叉封锁") < 0:
		push_error("SMOKE_SCOUT_TIP_0611_HUD %s" % main.spawn_teach_label.text)
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_FEEL_0611 beat=", beat, " n=", beat.length())
	return true


func _assert_touch_feel_0613(main) -> bool:
	## v0.6.7: west yellow cone fade is readable but still ≤0.50 leftover cap.
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("FOLLOW_WEST_CONE_FADE := 0.48") < 0:
		push_error("SMOKE_CONE_0613_CONST")
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_FEEL_0613 fade=0.48")
	return true


func _assert_touch_feel_0615(main) -> bool:
	## v0.6.8: crate take shows 拿到X in world, not only the HUD flash.
	## R36: float lasts 1.00s and rises 28px (source contract).
	if not main.has_method("_spawn_loot_chip") or not main.has_method("last_loot_chip_text"):
		push_error("SMOKE_LOOT_0615_NO_API")
		quit(44)
		return false
	main._spawn_loot_chip(Vector2(200, 200), "kar98k")
	var txt := str(main.last_loot_chip_text())
	if txt.find("拿到") < 0:
		push_error("SMOKE_LOOT_0615_TEXT %s" % txt)
		quit(44)
		return false
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if src.find("position.y - 28.0, 1.00") < 0:
		push_error("SMOKE_LOOT_R36_TWEEN")
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_FEEL_0615 chip=", txt, " r36=1.00s/28px")
	return true


func _assert_touch_feel_0617(main) -> bool:
	## v0.6.9: settle-on-ring regression net (body stays on the slot ring).
	if not await _assert_follow_settle_ring(main):
		return false
	print("SMOKE_OK_TOUCH_FEEL_0617")
	return true


func _assert_touch_feel_0619(main) -> bool:
	## v0.6.10: ALERT pause/speed spell 观战 / 倍速 so they don't read as mute.
	main._ensure_touch_hud()
	var th = main.touch_hud
	if th == null:
		push_error("SMOKE_PAUSE_0619_NO_HUD")
		quit(44)
		return false
	var prev = main.phase
	main.phase = main.Phase.WATCHING
	if th.has_method("refresh_phase"):
		th.refresh_phase("WATCHING", false, false, false, false)
	if str(th._btns["pause"].text).find("观战") < 0:
		push_error("SMOKE_PAUSE_0619_PAUSE %s" % th._btns["pause"].text)
		quit(44)
		return false
	if str(th._btns["speed"].text).find("倍速") < 0:
		push_error("SMOKE_PAUSE_0619_SPEED %s" % th._btns["speed"].text)
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_FEEL_0619 pause=", th._btns["pause"].text, " speed=", th._btns["speed"].text)
	main.phase = prev
	if th.has_method("refresh_phase"):
		th.refresh_phase("SETUP", false, false, false, false)
	return true


func _dest_is_rear(main, dest: Vector2i, lead) -> bool:
	if dest.x < 0 or lead == null:
		return false
	if main.has_method("follow_dest_rear_ok"):
		return bool(main.follow_dest_rear_ok(dest, lead))
	return false


func _assert_follow_behind_stagger(main) -> bool:
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_REAR_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(15, 14)
	var dest_c := Vector2i(24, 14)
	var a_c := Vector2i(12, 16)
	var b_c := Vector2i(12, 18)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 14)
	if main.grid.is_blocked(dest_c.x, dest_c.y) or main._cell_is_operable(dest_c):
		dest_c = Vector2i(23, 14)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(11, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 18)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow()
	main._command_move_selected(main.grid.cell_to_world_center(dest_c))
	if not lead.is_moving():
		push_error("SMOKE_REAR_LEAD_STILL at=%s dest=%s" % [lead.grid_cell(), dest_c])
		quit(44)
		return false
	var walk_d1 := Vector2i(-1, -1)
	var walk_d2 := Vector2i(-1, -1)
	for _i in 90:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
		if lead.is_moving():
			walk_d1 = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
			walk_d2 = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		else:
			break
	var stop_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var stop_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	for _j in 32:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
	var end_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var end_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var side_n := int(main.follow_side_rear_hits()) if main.has_method("follow_side_rear_hits") else 99
	if walk_d1.x < 0 or walk_d2.x < 0 or walk_d1 == walk_d2:
		push_error("SMOKE_REAR_WALK_DEST d1=%s d2=%s" % [walk_d1, walk_d2])
		quit(44)
		return false
	if not _dest_is_rear(main, walk_d1, lead) or not _dest_is_rear(main, walk_d2, lead):
		push_error("SMOKE_REAR_WALK_SIDE d1=%s d2=%s lead=%s" % [walk_d1, walk_d2, lead.grid_cell()])
		quit(44)
		return false
	if end_d1 != stop_d1 or end_d2 != stop_d2:
		push_error("SMOKE_REAR_DEST_HOP stop=%s %s end=%s %s" % [stop_d1, stop_d2, end_d1, end_d2])
		quit(44)
		return false
	if stop_d1 != walk_d1 or stop_d2 != walk_d2:
		push_error("SMOKE_REAR_DROP_ON_STOP walk=%s %s stop=%s %s" % [walk_d1, walk_d2, stop_d1, stop_d2])
		quit(44)
		return false
	if side_n > 0:
		push_error("SMOKE_REAR_SIDE_HITS n=%s d1=%s d2=%s" % [side_n, end_d1, end_d2])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_BEHIND d1=", end_d1, " d2=", end_d2, " lead=", lead.grid_cell())
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_follow_rear(main) -> bool:
	## Same west alley as the queue test, but dests must stay behind the
	## east-facing lead (left/right stagger), not file down the alley column.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_REAR_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	for _cam_i in 8:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		await process_frame
	var z_walk := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if (bool(a.is_moving()) or bool(b.is_moving())) and z_walk < 0.85:
		push_error("SMOKE_WEST_CAM_POSTAGE z=%s a=%s b=%s" % [z_walk, a.grid_cell(), b.grid_cell()])
		quit(44)
		return false
	await _tick_follow_steps(main, 16)
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_REAR_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1.x > 10 or d2.x > 10:
		push_error("SMOKE_WEST_REAR_WRAP d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1.x == lead.grid_cell().x or d2.x == lead.grid_cell().x:
		push_error("SMOKE_WEST_REAR_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_REAR_SIDE d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	if absi(d1.y - lead.grid_cell().y) > 6 or absi(d2.y - lead.grid_cell().y) > 6:
		push_error("SMOKE_WEST_REAR_STRETCH d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_REAR_SPAN n=%s d1=%s d2=%s lead=%s" % [span, d1, d2, lead.grid_cell()])
		quit(44)
		return false
	if absi(d1.x - lead.grid_cell().x) > 2 or absi(d2.x - lead.grid_cell().x) > 2:
		push_error("SMOKE_WEST_REAR_DEPTH d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 1:
		push_error("SMOKE_WEST_REAR_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	for _hold in 10:
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		await process_frame
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_CAM_HOLD z=%s walk=%s d1=%s d2=%s" % [z, z_walk, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_FOLLOW_REAR d1=", d1, " d2=", d2, " lead=", lead.grid_cell(),
		" span=", span, " cheb=", cheb, " zoom=", snapped(z_walk, 0.01), snapped(z, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_follow_facing_turn(main) -> bool:
	## Lead stands still and only twists 射界: followers re-file behind the cone.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_FACE_TURN_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(10, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 17)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow()
	await _tick_follow_steps(main, 20)
	var east_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var east_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if east_d1.x < 0 or east_d2.x < 0 or east_d1 == east_d2:
		push_error("SMOKE_FACE_TURN_EAST_DEST d1=%s d2=%s" % [east_d1, east_d2])
		quit(44)
		return false
	if not _dest_is_rear(main, east_d1, lead) or not _dest_is_rear(main, east_d2, lead):
		push_error("SMOKE_FACE_TURN_EAST_SIDE d1=%s d2=%s lead=%s" % [east_d1, east_d2, lead.grid_cell()])
		quit(44)
		return false
	if east_d1.x >= lead.grid_cell().x and east_d2.x >= lead.grid_cell().x:
		push_error("SMOKE_FACE_TURN_EAST_NOT_WEST d1=%s d2=%s lead=%s" % [east_d1, east_d2, lead.grid_cell()])
		quit(44)
		return false
	a.stop_move()
	b.stop_move()
	## 20° is well under the old 45° cardinal snap. Dest cells must already move.
	if lead.has_method("set_facing"):
		lead.set_facing(20.0)
	else:
		lead.facing_deg = 20.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._tick_squad_follow()
	await _tick_follow_steps(main, 20)
	var nudge_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var nudge_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if nudge_d1.x < 0 or nudge_d2.x < 0 or nudge_d1 == nudge_d2:
		push_error("SMOKE_FACE_NUDGE_DEST d1=%s d2=%s" % [nudge_d1, nudge_d2])
		quit(44)
		return false
	if nudge_d1 == east_d1 and nudge_d2 == east_d2:
		push_error("SMOKE_FACE_NUDGE_STUCK east=%s %s nudge=%s %s face=%s" % [
			east_d1, east_d2, nudge_d1, nudge_d2, lead.facing_deg
		])
		quit(44)
		return false
	if not _dest_is_rear(main, nudge_d1, lead) or not _dest_is_rear(main, nudge_d2, lead):
		push_error("SMOKE_FACE_NUDGE_SIDE d1=%s d2=%s lead=%s face=%s" % [
			nudge_d1, nudge_d2, lead.grid_cell(), lead.facing_deg
		])
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_FACING_NUDGE east=", east_d1, east_d2,
		" nudge=", nudge_d1, nudge_d2, " lead=", lead.grid_cell(), " face=", lead.facing_deg
	)
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(90.0)
	else:
		lead.facing_deg = 90.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._tick_squad_follow()
	await _tick_follow_steps(main, 24)
	var south_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var south_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if south_d1.x < 0 or south_d2.x < 0 or south_d1 == south_d2:
		push_error("SMOKE_FACE_TURN_SOUTH_DEST d1=%s d2=%s" % [south_d1, south_d2])
		quit(44)
		return false
	if south_d1 == east_d1 and south_d2 == east_d2:
		push_error("SMOKE_FACE_TURN_STUCK east=%s %s south=%s %s" % [east_d1, east_d2, south_d1, south_d2])
		quit(44)
		return false
	if south_d1 == nudge_d1 and south_d2 == nudge_d2:
		push_error("SMOKE_FACE_TURN_NUDGE_STUCK nudge=%s %s south=%s %s" % [
			nudge_d1, nudge_d2, south_d1, south_d2
		])
		quit(44)
		return false
	if not _dest_is_rear(main, south_d1, lead) or not _dest_is_rear(main, south_d2, lead):
		push_error("SMOKE_FACE_TURN_SOUTH_SIDE d1=%s d2=%s lead=%s face=%s" % [
			south_d1, south_d2, lead.grid_cell(), lead.facing_deg
		])
		quit(44)
		return false
	if south_d1.y >= lead.grid_cell().y and south_d2.y >= lead.grid_cell().y:
		push_error("SMOKE_FACE_TURN_SOUTH_NOT_NORTH d1=%s d2=%s lead=%s" % [south_d1, south_d2, lead.grid_cell()])
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_FACING_TURN east=", east_d1, east_d2,
		" nudge=", nudge_d1, nudge_d2,
		" south=", south_d1, south_d2, " lead=", lead.grid_cell()
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_follow_dest_blend(main) -> bool:
	## After a 1-cell dest hop (20° 射界), dest world slides — it does not snap.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_DEST_BLEND_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(10, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 17)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	var east_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var east_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if east_d1.x < 0 or east_d2.x < 0 or east_d1 == east_d2:
		push_error("SMOKE_DEST_BLEND_EAST d1=%s d2=%s" % [east_d1, east_d2])
		quit(44)
		return false
	a.stop_move()
	b.stop_move()
	a.global_position = main.grid.cell_to_world_center(east_d1)
	b.global_position = main.grid.cell_to_world_center(east_d2)
	if lead.has_method("set_facing"):
		lead.set_facing(20.0)
	else:
		lead.facing_deg = 20.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._follow_blend_hits = 0
	main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	main._tick_squad_follow(0.05)
	var hop_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var hop_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if hop_d1 == east_d1 and hop_d2 == east_d2:
		push_error("SMOKE_DEST_BLEND_NO_HOP east=%s %s hop=%s %s" % [east_d1, east_d2, hop_d1, hop_d2])
		quit(44)
		return false
	var hits := int(main.follow_dest_blend_hits()) if main.has_method("follow_dest_blend_hits") else 0
	var on := int(main.follow_dest_blend_active()) if main.has_method("follow_dest_blend_active") else 0
	if hits < 1:
		push_error("SMOKE_DEST_BLEND_HITS n=%s hop=%s %s east=%s %s" % [hits, hop_d1, hop_d2, east_d1, east_d2])
		quit(44)
		return false
	if on < 1:
		push_error("SMOKE_DEST_BLEND_DONE_EARLY n=%s frac=%s" % [
			on, main.follow_dest_blend_frac(int(a.op_id)) if main.has_method("follow_dest_blend_frac") else -1.0
		])
		quit(44)
		return false
	var old_w: Vector2 = main.grid.cell_to_world_center(east_d1)
	var new_w: Vector2 = main.grid.cell_to_world_center(hop_d1)
	var now_w: Vector2 = main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else new_w
	if a.is_moving() and a.move_path.size() > 1:
		now_w = a.move_path[a.move_path.size() - 1]
	var span := old_w.distance_to(new_w)
	if span < 8.0:
		push_error("SMOKE_DEST_BLEND_TINY span=%s east=%s hop=%s" % [span, east_d1, hop_d1])
		quit(44)
		return false
	if now_w.distance_to(new_w) < 6.0:
		push_error("SMOKE_DEST_HOP_SNAP now=%s new=%s old=%s" % [now_w, new_w, old_w])
		quit(44)
		return false
	if now_w.distance_to(old_w) < 4.0:
		push_error("SMOKE_DEST_BLEND_STUCK now=%s old=%s new=%s" % [now_w, old_w, new_w])
		quit(44)
		return false
	var along := (now_w - old_w).dot((new_w - old_w).normalized())
	if along < 3.0 or along > span - 3.0:
		push_error("SMOKE_DEST_BLEND_OFF along=%s span=%s now=%s" % [along, span, now_w])
		quit(44)
		return false
	if main.has_method("follow_slot_world_of"):
		var slot_w: Vector2 = main.follow_slot_world_of(int(a.op_id))
		if slot_w.distance_to(new_w) >= 4.0 and now_w.distance_to(new_w) < 2.0:
			push_error("SMOKE_DEST_BLEND_CELL_SNAP now=%s slot=%s new=%s" % [now_w, slot_w, new_w])
			quit(44)
			return false
	print(
		"SMOKE_OK_FOLLOW_DEST_BLEND east=", east_d1, east_d2,
		" hop=", hop_d1, hop_d2,
		" hits=", hits, " on=", on,
		" along=", snapped(along, 0.1), "/", snapped(span, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_obs_tight(main) -> bool:
	## West trio: observation ring shrinks (less overlap with the yellow cone),
	## camera pulls past 0.62, dests sit on in-cell corners.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 12:
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_OBS_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_OBS_CAM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_OBS_SCALE s=%s z=%s" % [scale, z])
		quit(44)
		return false
	var rad := float(main.follow_obs_visual_radius()) if main.has_method("follow_obs_visual_radius") else 0.0
	var kit := float(b.kit_range_px) if "kit_range_px" in b else 280.0
	if rad < kit * 0.92:
		push_error("SMOKE_WEST_OBS_RAD r=%s kit=%s scale=%s" % [rad, kit, scale])
		quit(44)
		return false
	if b.has_method("observation_ring_visible") and not bool(b.observation_ring_visible()):
		push_error("SMOKE_WEST_OBS_HIDDEN")
		quit(44)
		return false
	var slot_w: Vector2 = main.follow_slot_world_of(int(a.op_id)) if main.has_method("follow_slot_world_of") else Vector2.ZERO
	var cell_w: Vector2 = main.grid.cell_to_world_center(d1)
	var inset := slot_w.distance_to(cell_w)
	if inset < 8.0:
		push_error("SMOKE_WEST_OBS_INSET d=%s slot=%s cell=%s" % [inset, slot_w, cell_w])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_TIGHT d1=", d1, " d2=", d2,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" rad=", snapped(rad, 0.1), "/", snapped(kit, 0.1),
		" inset=", snapped(inset, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_follow_face_arc(main) -> bool:
	## 90° 拧射界: dest world bows off the chord around the lead (slot arc),
	## followers slide a curved path instead of a 3-cell grid walk.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_FACE_ARC_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(10, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 17)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	var east_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var east_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if east_d1.x < 0 or east_d2.x < 0 or east_d1 == east_d2:
		push_error("SMOKE_FACE_ARC_EAST d1=%s d2=%s" % [east_d1, east_d2])
		quit(44)
		return false
	a.stop_move()
	b.stop_move()
	a.global_position = main.grid.cell_to_world_center(east_d1)
	b.global_position = main.grid.cell_to_world_center(east_d2)
	if main.has_method("follow_slot_world_of"):
		a.global_position = main.follow_slot_world_of(int(a.op_id))
		b.global_position = main.follow_slot_world_of(int(b.op_id))
	if lead.has_method("set_facing"):
		lead.set_facing(90.0)
	else:
		lead.facing_deg = 90.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	main._follow_arc_hits = 0
	main._follow_blend_hits = 0
	main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	main._tick_squad_follow(0.05)
	var ticks := 0
	while ticks < 8:
		var frac0 := float(main.follow_dest_blend_frac(int(a.op_id))) if main.has_method("follow_dest_blend_frac") else 1.0
		if frac0 >= 0.28 and frac0 <= 0.82:
			break
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		ticks += 1
	var hop_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var hop_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if hop_d1 == east_d1 and hop_d2 == east_d2:
		push_error("SMOKE_FACE_ARC_NO_HOP east=%s %s hop=%s %s" % [east_d1, east_d2, hop_d1, hop_d2])
		quit(44)
		return false
	var arc_hits := int(main.follow_dest_arc_hits()) if main.has_method("follow_dest_arc_hits") else 0
	var arc_on := int(main.follow_dest_arc_active()) if main.has_method("follow_dest_arc_active") else 0
	if arc_hits < 1:
		push_error("SMOKE_FACE_ARC_HITS n=%s hop=%s %s east=%s %s" % [arc_hits, hop_d1, hop_d2, east_d1, east_d2])
		quit(44)
		return false
	if arc_on < 1:
		push_error("SMOKE_FACE_ARC_DONE_EARLY n=%s frac=%s" % [
			arc_on, main.follow_dest_blend_frac(int(a.op_id)) if main.has_method("follow_dest_blend_frac") else -1.0
		])
		quit(44)
		return false
	var bow := float(main.follow_dest_arc_bow(int(a.op_id))) if main.has_method("follow_dest_arc_bow") else 0.0
	if bow < 5.0:
		push_error("SMOKE_FACE_ARC_FLAT bow=%s hop=%s east=%s w=%s" % [
			bow, hop_d1, east_d1,
			main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else Vector2.ZERO
		])
		quit(44)
		return false
	var path_n := a.move_path.size() if a.is_moving() else 0
	if path_n < 3:
		push_error("SMOKE_FACE_ARC_PATH n=%s hop=%s" % [path_n, hop_d1])
		quit(44)
		return false
	var grid_hits := 0
	if path_n >= 3:
		for i in range(1, path_n - 1):
			var pw: Vector2 = a.move_path[i]
			var pc: Vector2i = main.grid.world_to_cell(pw)
			if pw.distance_to(main.grid.cell_to_world_center(pc)) < 4.0:
				grid_hits += 1
	if grid_hits >= 2:
		push_error("SMOKE_FACE_ARC_GRID_WALK hits=%s n=%s hop=%s" % [grid_hits, path_n, hop_d1])
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_FACE_ARC east=", east_d1, east_d2,
		" hop=", hop_d1, hop_d2,
		" hits=", arc_hits, " on=", arc_on,
		" bow=", snapped(bow, 0.1),
		" path=", path_n
	)
	await _tick_follow_steps(main, 20)
	var south_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var south_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if south_d1.x < 0 or south_d2.x < 0 or south_d1 == south_d2:
		push_error("SMOKE_FACE_ARC_SOUTH d1=%s d2=%s" % [south_d1, south_d2])
		quit(44)
		return false
	if not _dest_is_rear(main, south_d1, lead) or not _dest_is_rear(main, south_d2, lead):
		push_error("SMOKE_FACE_ARC_SOUTH_SIDE d1=%s d2=%s lead=%s" % [south_d1, south_d2, lead.grid_cell()])
		quit(44)
		return false
	if south_d1.y >= lead.grid_cell().y and south_d2.y >= lead.grid_cell().y:
		push_error("SMOKE_FACE_ARC_SOUTH_NOT_NORTH d1=%s d2=%s lead=%s" % [south_d1, south_d2, lead.grid_cell()])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_FACE_ARC_LAND south=", south_d1, south_d2, " lead=", lead.grid_cell())
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_follow_nudge_arc(main) -> bool:
	## 15° ↻ taps: dest world rides the facing-slot ring, not a cell-center hop.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_NUDGE_ARC_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(10, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 17)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	var east_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	if east_d1.x < 0:
		push_error("SMOKE_NUDGE_ARC_EAST d1=%s" % east_d1)
		quit(44)
		return false
	a.stop_move()
	b.stop_move()
	if main.has_method("follow_slot_world_of"):
		a.global_position = main.follow_slot_world_of(int(a.op_id))
		b.global_position = main.follow_slot_world_of(int(b.op_id))
	var lead_w: Vector2 = lead.global_position
	var prev_w: Vector2 = main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else a.global_position
	var prev_ang := atan2(prev_w.y - lead_w.y, prev_w.x - lead_w.x)
	main._follow_arc_hits = 0
	var max_step := 0.0
	var ang_steps := 0
	for step_i in 6:
		var face := float(step_i + 1) * 15.0
		if lead.has_method("set_facing"):
			lead.set_facing(face)
		else:
			lead.facing_deg = face
			if lead.has_method("_rebuild_cone"):
				lead._rebuild_cone()
		main._stealth_avoid_cache.clear()
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		var now_w: Vector2 = main.follow_dest_world_of(int(a.op_id)) if main.has_method("follow_dest_world_of") else a.global_position
		var step_d := now_w.distance_to(prev_w)
		if step_d > max_step:
			max_step = step_d
		var ang := atan2(now_w.y - lead_w.y, now_w.x - lead_w.x)
		var dang := absf(wrapf(ang - prev_ang, -PI, PI))
		if dang >= 0.04:
			ang_steps += 1
		prev_w = now_w
		prev_ang = ang
	var arc_hits := int(main.follow_dest_arc_hits()) if main.has_method("follow_dest_arc_hits") else 0
	if arc_hits < 1:
		push_error("SMOKE_NUDGE_ARC_HITS n=%s" % arc_hits)
		quit(44)
		return false
	if ang_steps < 3:
		push_error("SMOKE_NUDGE_ARC_FLAT steps=%s max=%s" % [ang_steps, snapped(max_step, 0.1)])
		quit(44)
		return false
	if max_step > 56.0:
		push_error("SMOKE_NUDGE_ARC_HOP step=%s" % snapped(max_step, 0.1))
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_NUDGE_ARC hits=", arc_hits,
		" ang_steps=", ang_steps,
		" max_step=", snapped(max_step, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_body_stagger(main) -> bool:
	## West trio dest worlds sit a half-cell further apart, bodies shrink.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_STAGGER_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 8:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		main._tick_squad_follow(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_STAGGER_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if spread < 48.0:
		push_error("SMOKE_WEST_STAGGER_TIGHT spread=%s d1=%s d2=%s" % [spread, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_STAGGER_SCALE s=%s spread=%s" % [scale, spread])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_BODY_STAGGER d1=", d1, " d2=", d2,
		" spread=", snapped(spread, 0.1),
		" scale=", snapped(scale, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_face_arc_walkable(main) -> bool:
	## Arc samples snag onto walkable cells so the path does not clip crates.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_ARC_WALK_NO_OPS")
		quit(44)
		return false
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(6, 9))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(12, 9))
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(9, 12))
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_WALK_NO_API")
		quit(44)
		return false
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 7)
	if pts.size() < 4:
		push_error("SMOKE_ARC_WALK_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var mid_bow := 0.0
	var chord: Vector2 = to_w - from_w
	var chord_n := chord.length()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		if i > 0 and i < pts.size() - 1 and chord_n > 8.0:
			var t_line := (p - from_w).dot(chord) / chord.length_squared()
			var proj: Vector2 = from_w + chord * t_line
			mid_bow = maxf(mid_bow, p.distance_to(proj))
	if blocked > 0:
		push_error("SMOKE_ARC_WALK_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if mid_bow < 4.0:
		push_error("SMOKE_ARC_WALK_FLAT bow=%s n=%s" % [mid_bow, pts.size()])
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	if lead.has_method("set_facing"):
		lead.set_facing(90.0)
	else:
		lead.facing_deg = 90.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	main._tick_squad_follow(0.05)
	var live_block := int(main.follow_arc_blocked_hits()) if main.has_method("follow_arc_blocked_hits") else 99
	if live_block > 0:
		push_error("SMOKE_ARC_WALK_LIVE n=%s" % live_block)
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_WALKABLE n=", pts.size(),
		" bow=", snapped(mid_bow, 0.1),
		" live_block=", live_block
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_compact_rotate(main) -> bool:
	## Compact night-raid bar exposes ↺ and ↻; hold-repeat and swipe both ways.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	var th = main.touch_hud
	if th == null:
		push_error("SMOKE_COMPACT_ROTATE_NO_HUD")
		quit(44)
		return false
	var cmds: PackedStringArray = th.setup_visible_cmds() if th.has_method("setup_visible_cmds") else PackedStringArray()
	if not cmds.has("rotate_cw") or not cmds.has("rotate_ccw"):
		push_error("SMOKE_COMPACT_NO_ROTATE cmds=%s" % " ".join(cmds))
		quit(44)
		return false
	for cmd in ["rotate_cw", "rotate_ccw"]:
		if not th._btns.has(cmd) or not bool(th._btns[cmd].visible):
			push_error("SMOKE_COMPACT_ROTATE_HIDDEN cmd=%s" % cmd)
			quit(44)
			return false
		if bool(th._btns[cmd].disabled):
			push_error("SMOKE_COMPACT_ROTATE_DISABLED cmd=%s" % cmd)
			quit(44)
			return false
	if main.operators.is_empty():
		push_error("SMOKE_COMPACT_ROTATE_NO_OP")
		quit(44)
		return false
	main._select_op(0)
	var f0: float = float(main.selected.facing_deg)
	main.apply_touch_command("rotate_cw")
	var f1: float = float(main.selected.facing_deg)
	if is_equal_approx(f1, f0):
		push_error("SMOKE_COMPACT_ROTATE_NOOP f=%s" % f1)
		quit(44)
		return false
	if th.has_method("simulate_hold_tick"):
		th.simulate_hold_tick("rotate_cw")
	else:
		main.apply_touch_command("rotate_cw")
	var f2: float = float(main.selected.facing_deg)
	if is_equal_approx(f2, f1):
		push_error("SMOKE_COMPACT_ROTATE_HOLD f1=%s f2=%s" % [f1, f2])
		quit(44)
		return false
	main.apply_touch_command("rotate_ccw")
	var f3: float = float(main.selected.facing_deg)
	if is_equal_approx(f3, f2):
		push_error("SMOKE_COMPACT_CCW_NOOP f=%s" % f3)
		quit(44)
		return false
	if th.has_method("simulate_hold_tick"):
		th.simulate_hold_tick("rotate_ccw")
	else:
		main.apply_touch_command("rotate_ccw")
	var f4: float = float(main.selected.facing_deg)
	if is_equal_approx(f4, f3):
		push_error("SMOKE_COMPACT_CCW_HOLD f3=%s f4=%s" % [f3, f4])
		quit(44)
		return false
	var swipe_n := 0
	if th.has_method("simulate_swipe_twist"):
		swipe_n = int(th.simulate_swipe_twist(-56.0))
	else:
		main.apply_touch_command("rotate_ccw")
		swipe_n = 1
	var f5: float = float(main.selected.facing_deg)
	if is_equal_approx(f5, f4):
		push_error("SMOKE_COMPACT_SWIPE_CCW f=%s n=%s" % [f5, swipe_n])
		quit(44)
		return false
	var swipe_n2 := 0
	if th.has_method("simulate_swipe_twist"):
		swipe_n2 = int(th.simulate_swipe_twist(56.0))
	else:
		main.apply_touch_command("rotate_cw")
		swipe_n2 = 1
	var f6: float = float(main.selected.facing_deg)
	if is_equal_approx(f6, f5):
		push_error("SMOKE_COMPACT_SWIPE_CW f=%s n=%s" % [f6, swipe_n2])
		quit(44)
		return false
	print(
		"SMOKE_OK_COMPACT_ROTATE cmds=", " ".join(cmds),
		" f=", snapped(f0, 0.1), snapped(f1, 0.1), snapped(f2, 0.1),
		snapped(f3, 0.1), snapped(f4, 0.1), snapped(f5, 0.1), snapped(f6, 0.1),
		" swipe=", swipe_n, swipe_n2
	)
	return true


func _assert_compact_narrow(main) -> bool:
	## 5-key SETUP packs on a narrow remaining strip: stacked 匍匐/背包,
	## smaller type, ↺/↻ stay hold/swipe-able.
	main._ensure_touch_hud()
	main._update_hud()
	await process_frame
	var th = main.touch_hud
	if th == null:
		push_error("SMOKE_COMPACT_NARROW_NO_HUD")
		quit(44)
		return false
	if th.has_method("simulate_narrow_layout"):
		th.simulate_narrow_layout(320.0)
	await process_frame
	var m: Dictionary = th.setup_bar_metrics() if th.has_method("setup_bar_metrics") else {}
	var font := int(m.get("font", 99))
	var stacked := bool(m.get("stacked", false))
	var need := float(m.get("need_w", 999.0))
	var avail := float(m.get("avail_w", 0.0))
	var fits := bool(m.get("fits", false))
	var twist_min := float(m.get("twist_min", 0.0))
	if not stacked:
		push_error("SMOKE_COMPACT_NARROW_FLAT stacked=0 need=%s" % snapped(need, 0.1))
		quit(44)
		return false
	if font > 13:
		push_error("SMOKE_COMPACT_NARROW_FONT n=%s" % font)
		quit(44)
		return false
	if need > 360.0:
		push_error("SMOKE_COMPACT_NARROW_WIDE need=%s avail=%s" % [snapped(need, 0.1), snapped(avail, 0.1)])
		quit(44)
		return false
	if not fits:
		push_error("SMOKE_COMPACT_NARROW_OVERFLOW need=%s avail=%s" % [snapped(need, 0.1), snapped(avail, 0.1)])
		quit(44)
		return false
	if twist_min < 56.0:
		push_error("SMOKE_COMPACT_NARROW_TWIST_SMALL n=%s" % snapped(twist_min, 0.1))
		quit(44)
		return false
	var cmds: PackedStringArray = th.setup_visible_cmds() if th.has_method("setup_visible_cmds") else PackedStringArray()
	if not cmds.has("rotate_cw") or not cmds.has("rotate_ccw") or not cmds.has("crouch") or not cmds.has("bag") or not cmds.has("alarm"):
		push_error("SMOKE_COMPACT_NARROW_CMDS %s" % " ".join(cmds))
		quit(44)
		return false
	if main.operators.is_empty():
		push_error("SMOKE_COMPACT_NARROW_NO_OP")
		quit(44)
		return false
	main._select_op(0)
	var f0: float = float(main.selected.facing_deg)
	if th.has_method("simulate_swipe_twist"):
		th.simulate_swipe_twist(-56.0)
	else:
		main.apply_touch_command("rotate_ccw")
	var f1: float = float(main.selected.facing_deg)
	if is_equal_approx(f1, f0):
		push_error("SMOKE_COMPACT_NARROW_SWIPE_CCW f=%s" % f1)
		quit(44)
		return false
	if th.has_method("simulate_swipe_twist"):
		th.simulate_swipe_twist(56.0)
	else:
		main.apply_touch_command("rotate_cw")
	var f2: float = float(main.selected.facing_deg)
	if is_equal_approx(f2, f1):
		push_error("SMOKE_COMPACT_NARROW_SWIPE_CW f=%s" % f2)
		quit(44)
		return false
	if th.has_method("simulate_hold_tick"):
		th.simulate_hold_tick("rotate_cw")
	var f3: float = float(main.selected.facing_deg)
	if is_equal_approx(f3, f2):
		push_error("SMOKE_COMPACT_NARROW_HOLD f=%s" % f3)
		quit(44)
		return false
	if th.has_method("_apply_safe_area"):
		th._apply_safe_area()
	elif th.has_method("_layout_compact"):
		th._layout_compact()
	print(
		"SMOKE_OK_COMPACT_NARROW font=", font,
		" need=", snapped(need, 0.1),
		" avail=", snapped(avail, 0.1),
		" twist=", snapped(twist_min, 0.1),
		" stacked=", 1 if stacked else 0,
		" cmds=", " ".join(cmds)
	)
	return true


func _assert_follow_body_ring(main) -> bool:
	## 15° ↻: follower bodies polar-slide on the slot ring, not a cell hop.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_BODY_RING_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(13, 13)
	var a_c := Vector2i(11, 16)
	var b_c := Vector2i(12, 17)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(14, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	if main.has_method("follow_slot_world_of"):
		a.stop_move()
		b.stop_move()
		a.global_position = main.follow_slot_world_of(int(a.op_id))
		b.global_position = main.follow_slot_world_of(int(b.op_id))
	var lead_w: Vector2 = lead.global_position
	var prev_body: Vector2 = a.global_position
	var prev_ang := atan2(prev_body.y - lead_w.y, prev_body.x - lead_w.x)
	main._follow_body_arc_hits = 0
	var max_step := 0.0
	var ang_steps := 0
	var path_n := 0
	var grid_hits := 0
	for step_i in 6:
		var face := float(step_i + 1) * 15.0
		if lead.has_method("set_facing"):
			lead.set_facing(face)
		else:
			lead.facing_deg = face
			if lead.has_method("_rebuild_cone"):
				lead._rebuild_cone()
		main._stealth_avoid_cache.clear()
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		if a.is_moving():
			path_n = maxi(path_n, a.move_path.size())
			for i in range(1, a.move_path.size() - 1):
				var pw: Vector2 = a.move_path[i]
				var pc: Vector2i = main.grid.world_to_cell(pw)
				if pw.distance_to(main.grid.cell_to_world_center(pc)) < 4.0:
					grid_hits += 1
		var now_body: Vector2 = a.global_position
		if a.is_moving() and a.move_path.size() > 1:
			now_body = a.move_path[a.move_path.size() - 1]
		var step_d := now_body.distance_to(prev_body)
		if step_d > max_step:
			max_step = step_d
		var ang := atan2(now_body.y - lead_w.y, now_body.x - lead_w.x)
		var dang := absf(wrapf(ang - prev_ang, -PI, PI))
		if dang >= 0.04:
			ang_steps += 1
		prev_body = now_body
		prev_ang = ang
	var body_hits := int(main.follow_body_arc_hits()) if main.has_method("follow_body_arc_hits") else 0
	if body_hits < 1:
		push_error("SMOKE_BODY_RING_HITS n=%s path=%s" % [body_hits, path_n])
		quit(44)
		return false
	if ang_steps < 3:
		push_error("SMOKE_BODY_RING_FLAT steps=%s max=%s" % [ang_steps, snapped(max_step, 0.1)])
		quit(44)
		return false
	if max_step > 56.0:
		push_error("SMOKE_BODY_RING_HOP step=%s" % snapped(max_step, 0.1))
		quit(44)
		return false
	if grid_hits >= 6:
		push_error("SMOKE_BODY_RING_GRID hits=%s path=%s" % [grid_hits, path_n])
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_BODY_RING hits=", body_hits,
		" ang_steps=", ang_steps,
		" max_step=", snapped(max_step, 0.1),
		" path=", path_n
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_half_cell(main) -> bool:
	## West trio: smaller silhouettes + bodies sit off dest-cell centers.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_HALF_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 8:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_HALF_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_HALF_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_HALF_SCALE s=%s" % scale)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 52.0:
		push_error("SMOKE_WEST_HALF_SPREAD dest=%s" % dest_spread)
		quit(44)
		return false
	var inset_ok := 0
	var near := 0
	for op in [a, b]:
		var oid := int(op.op_id)
		var dest: Vector2i = main._follow_dest.get(oid, Vector2i(-1, -1))
		if dest.x < 0:
			continue
		var dest_w: Vector2 = main.follow_dest_world_of(oid) if main.has_method("follow_dest_world_of") else op.global_position
		var center: Vector2 = main.grid.cell_to_world_center(dest)
		if op.global_position.distance_to(dest_w) < 22.0 or op.global_position.distance_to(center) < 40.0:
			near += 1
		if dest_w.distance_to(center) >= 10.0:
			inset_ok += 1
		elif op.global_position.distance_to(center) >= 10.0:
			inset_ok += 1
	if inset_ok < 1:
		push_error("SMOKE_WEST_HALF_CENTER d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_HALF_CELL d1=", d1, " d2=", d2,
		" span=", span, " scale=", snapped(scale, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" inset=", inset_ok, " near=", near
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_face_arc_round(main) -> bool:
	## Crate-hugging polar samples stay walkable and keep circular bow.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_ROUND_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_ROUND_NO_API")
		quit(44)
		return false
	var crate_c := Vector2i(6, 12)
	var crate_w: Vector2 = main.grid.cell_to_world_center(crate_c)
	var pivot: Vector2 = crate_w + Vector2(0, 48)
	var from_w: Vector2 = crate_w + Vector2(-48, 0)
	var to_w: Vector2 = crate_w + Vector2(48, 0)
	var raw: PackedVector2Array = PackedVector2Array()
	if main.has_method("follow_arc_sample_raw"):
		raw = main.follow_arc_sample_raw(from_w, to_w, pivot, 11)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 11)
	if pts.size() < 5:
		push_error("SMOKE_ARC_ROUND_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
	if blocked > 0:
		push_error("SMOKE_ARC_ROUND_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	var raw_bow := 0.0
	var raw_blocked := 0
	if raw.size() >= 3:
		raw_bow = float(main.follow_arc_chord_bow(raw, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
		for rp in raw:
			var rc: Vector2i = main.grid.world_to_cell(rp)
			if main.grid.is_blocked(rc.x, rc.y) or main._cell_is_operable(rc):
				raw_blocked += 1
	if snag_bow < 10.0:
		push_error("SMOKE_ARC_ROUND_FLAT bow=%s raw=%s raw_block=%s" % [snag_bow, raw_bow, raw_blocked])
		quit(44)
		return false
	if raw_bow > 12.0 and snag_bow < raw_bow * 0.40:
		push_error("SMOKE_ARC_ROUND_SQUASH snag=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	var axis_run := 0
	var max_axis := 0
	for i in range(1, pts.size()):
		var d: Vector2 = pts[i] - pts[i - 1]
		if absf(d.x) < 2.6 or absf(d.y) < 2.6:
			axis_run += 1
			max_axis = maxi(max_axis, axis_run)
		else:
			axis_run = 0
	if max_axis >= 5:
		push_error("SMOKE_ARC_ROUND_WALL run=%s n=%s bow=%s" % [max_axis, pts.size(), snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_ROUND n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" raw_bow=", snapped(raw_bow, 0.1),
		" raw_block=", raw_blocked,
		" axis_run=", max_axis
	)
	return true


func _assert_follow_settle_ring(main) -> bool:
	## After ↻ release, follower bodies stay on the ring, not dest-cell centers.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_SETTLE_RING_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	if main.has_method("follow_slot_world_of"):
		a.stop_move()
		b.stop_move()
		a.global_position = main.follow_slot_world_of(int(a.op_id))
		b.global_position = main.follow_slot_world_of(int(b.op_id))
	for step_i in 6:
		var face := float(step_i + 1) * 15.0
		if lead.has_method("set_facing"):
			lead.set_facing(face)
		else:
			lead.facing_deg = face
			if lead.has_method("_rebuild_cone"):
				lead._rebuild_cone()
		main._stealth_avoid_cache.clear()
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _catch in 24:
		lead.stop_move()
		var ring_catch: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else a.global_position
		if a.global_position.distance_to(ring_catch) <= 20.0:
			break
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		await process_frame
	var ring_a: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else a.global_position
	var dest_a: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var center_a: Vector2 = main.grid.cell_to_world_center(dest_a) if dest_a.x >= 0 else a.global_position
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if a.global_position.distance_to(ring_a) > 20.0:
		a.global_position = ring_a
	if main.has_method("follow_ring_world_of"):
		var ring_b: Vector2 = main.follow_ring_world_of(int(b.op_id))
		if b.global_position.distance_to(ring_b) > 20.0:
			b.global_position = ring_b
	## Release ↻: facing frozen, bodies must stay on the ring they landed on.
	for _hold in 16:
		lead.stop_move()
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		await process_frame
	var hold_on := bool(main.follow_ring_hold_active()) if main.has_method("follow_ring_hold_active") else false
	if not hold_on:
		push_error("SMOKE_SETTLE_RING_NO_HOLD face=%s" % lead.facing_deg)
		quit(44)
		return false
	var body_a: Vector2 = a.global_position
	var ring_now: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else ring_a
	if body_a.distance_to(ring_a) > 24.0 and body_a.distance_to(ring_now) > 24.0:
		push_error(
			"SMOKE_SETTLE_RING_SNAP body=%s ring=%s center=%s d=%s" % [
				body_a, ring_now, center_a, snapped(body_a.distance_to(ring_now), 0.1)
			]
		)
		quit(44)
		return false
	if ring_now.distance_to(center_a) < 10.0:
		push_error("SMOKE_SETTLE_RING_NO_INSET ring=%s center=%s" % [ring_now, center_a])
		quit(44)
		return false
	if body_a.distance_to(center_a) < 8.0:
		push_error(
			"SMOKE_SETTLE_RING_CENTER body=%s ring=%s center=%s" % [body_a, ring_now, center_a]
		)
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_SETTLE_RING hold=", 1 if hold_on else 0,
		" body_ring=", snapped(body_a.distance_to(ring_now), 0.1),
		" body_center=", snapped(body_a.distance_to(center_a), 0.1),
		" ring_center=", snapped(ring_now.distance_to(center_a), 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_tighter(main) -> bool:
	## West trio: smaller silhouettes + more world stagger, span still ≤1.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_TIGHT_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 8:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_TIGHT_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_TIGHT_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_TIGHT_SCALE s=%s" % scale)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 56.0:
		push_error("SMOKE_WEST_TIGHT_SPREAD dest=%s" % dest_spread)
		quit(44)
		return false
	if lead.has_method("set_facing"):
		lead.set_facing(30.0)
	else:
		lead.facing_deg = 30.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	main._tick_squad_follow(0.05)
	if main.has_method("_tick_command_moves"):
		main._tick_command_moves(0.05)
	await _tick_follow_steps(main, 10)
	for _stop in 12:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		await process_frame
	var ring_w: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else a.global_position
	var dest_c: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var cell_w: Vector2 = main.grid.cell_to_world_center(dest_c) if dest_c.x >= 0 else a.global_position
	if a.global_position.distance_to(ring_w) > 26.0:
		push_error("SMOKE_WEST_TIGHT_SNAP body=%s ring=%s" % [a.global_position, ring_w])
		quit(44)
		return false
	if ring_w.distance_to(cell_w) < 10.0:
		push_error("SMOKE_WEST_TIGHT_NO_INSET ring=%s cell=%s" % [ring_w, cell_w])
		quit(44)
		return false
	if a.global_position.distance_to(cell_w) < 8.0:
		push_error("SMOKE_WEST_TIGHT_CENTER body=%s ring=%s cell=%s" % [a.global_position, ring_w, cell_w])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_TIGHTER d1=", d1, " d2=", d2,
		" span=", span, " scale=", snapped(scale, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" body_ring=", snapped(a.global_position.distance_to(ring_w), 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_clearer(main) -> bool:
	## v0.5.19: smaller silhouettes + more pullback, dest worlds farther,
	## dest cells still span ≤1.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_CLEAR_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	for _catch in 40:
		var ring_catch: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else a.global_position
		if a.global_position.distance_to(ring_catch) <= 24.0:
			break
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_CLEAR_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_CLEAR_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_CLEAR_SCALE s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_CLEAR_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 64.0:
		push_error("SMOKE_WEST_CLEAR_SPREAD dest=%s" % dest_spread)
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_CLEAR_CAM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var ring_w: Vector2 = main.follow_ring_world_of(int(a.op_id)) if main.has_method("follow_ring_world_of") else a.global_position
	var dest_c: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var cell_w: Vector2 = main.grid.cell_to_world_center(dest_c) if dest_c.x >= 0 else a.global_position
	if a.global_position.distance_to(ring_w) > 26.0:
		push_error("SMOKE_WEST_CLEAR_SNAP body=%s ring=%s" % [a.global_position, ring_w])
		quit(44)
		return false
	if ring_w.distance_to(cell_w) < 10.0:
		push_error("SMOKE_WEST_CLEAR_NO_INSET ring=%s cell=%s" % [ring_w, cell_w])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_CLEARER d1=", d1, " d2=", d2,
		" span=", span, " scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" zoom=", snapped(z, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_face_arc_cluster(main) -> bool:
	## Multi-crate cluster: snagged polar samples stay walkable and round.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_CLUSTER_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_CLUSTER_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 14))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 12))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 12))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var raw: PackedVector2Array = PackedVector2Array()
	if main.has_method("follow_arc_sample_raw"):
		raw = main.follow_arc_sample_raw(from_w, to_w, pivot, 13)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 13)
	if pts.size() < 6:
		push_error("SMOKE_ARC_CLUSTER_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
	if blocked > 0:
		push_error("SMOKE_ARC_CLUSTER_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	var raw_bow := 0.0
	if raw.size() >= 3 and main.has_method("follow_arc_chord_bow"):
		raw_bow = float(main.follow_arc_chord_bow(raw, from_w, to_w))
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_CLUSTER_FLAT bow=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	if raw_bow > 16.0 and snag_bow < raw_bow * 0.38:
		push_error("SMOKE_ARC_CLUSTER_SQUASH snag=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 4:
		push_error("SMOKE_ARC_CLUSTER_WALL run=%s n=%s bow=%s" % [max_axis, pts.size(), snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_CLUSTER n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" raw_bow=", snapped(raw_bow, 0.1),
		" axis_run=", max_axis
	)
	return true


func _assert_face_arc_cluster_round(main) -> bool:
	## South face of the yard north-crate block: snag must go around, not slide y.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_CLUSTER_ROUND_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_CLUSTER_ROUND_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var raw: PackedVector2Array = PackedVector2Array()
	if main.has_method("follow_arc_sample_raw"):
		raw = main.follow_arc_sample_raw(from_w, to_w, pivot, 15)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_CLUSTER_ROUND_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
	if blocked > 0:
		push_error("SMOKE_ARC_CLUSTER_ROUND_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	var raw_bow := 0.0
	if raw.size() >= 3 and main.has_method("follow_arc_chord_bow"):
		raw_bow = float(main.follow_arc_chord_bow(raw, from_w, to_w))
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_CLUSTER_ROUND_FLAT bow=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	if raw_bow > 18.0 and snag_bow < raw_bow * 0.30:
		push_error("SMOKE_ARC_CLUSTER_ROUND_SQUASH snag=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 4:
		push_error("SMOKE_ARC_CLUSTER_ROUND_WALL run=%s n=%s bow=%s" % [max_axis, pts.size(), snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_CLUSTER_ROUND n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" raw_bow=", snapped(raw_bow, 0.1),
		" axis_run=", max_axis
	)
	return true


func _assert_west_cone_fade(main) -> bool:
	## v0.5.20: west trio smaller still, observation rings shrink, yellow
	## cone fill fades visually. Dest cells span ≤2 (v0.5.21 second-follower).
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_FADE_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_FADE_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_FADE_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_FADE_SCALE s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_FADE_OBS s=%s" % obs)
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_FADE_CONE s=%s" % fade)
		quit(44)
		return false
	if lead.cone == null or lead.cone.color.a > 0.20:
		push_error("SMOKE_WEST_FADE_CONE_A a=%s fade=%s" % [lead.cone.color.a if lead.cone else -1.0, fade])
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 64.0:
		push_error("SMOKE_WEST_FADE_SPREAD dest=%s" % dest_spread)
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_FADE_CAM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_CONE_FADE d1=", d1, " d2=", d2,
		" span=", span, " scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01),
		" cone_a=", snapped(lead.cone.color.a, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" zoom=", snapped(z, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_file_spread(main) -> bool:
	## v0.5.33: first west follower is 6 along-file (span ≤6). Second stays
	## staggered further back. No west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_FILE_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_FILE_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_FILE_SPAN n=%s d1=%s d2=%s lead=%s" % [span, d1, d2, lc])
		quit(44)
		return false
	var dx1 := absi(d1.x - lc.x)
	var dx2 := absi(d2.x - lc.x)
	var cd1 := maxi(dx1, absi(d1.y - lc.y))
	var cd2 := maxi(dx2, absi(d2.y - lc.y))
	if maxi(dx1, dx2) < 2:
		push_error("SMOKE_WEST_FILE_DEPTH dx=%s/%s d1=%s d2=%s lead=%s" % [dx1, dx2, d1, d2, lc])
		quit(44)
		return false
	if maxi(dx1, dx2) > 2:
		push_error("SMOKE_WEST_FILE_WALL dx=%s/%s d1=%s d2=%s lead=%s" % [dx1, dx2, d1, d2, lc])
		quit(44)
		return false
	if cd1 < 2:
		push_error("SMOKE_WEST_FILE_POCKET d1=%s d2=%s lead=%s cd=%s/%s" % [d1, d2, lc, cd1, cd2])
		quit(44)
		return false
	if dx1 >= 2:
		push_error("SMOKE_WEST_FILE_FIRST_WALL dx=%s d1=%s d2=%s lead=%s" % [dx1, d1, d2, lc])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_FILE_STACK cheb=%s d1=%s d2=%s lead=%s" % [cheb, d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_FILE_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_FILE_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	var rim := int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else 99
	if cone > 0 or rim > 0:
		push_error("SMOKE_WEST_FILE_CONE cone=%s rim=%s d1=%s d2=%s" % [cone, rim, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_FILE_FADE s=%s" % fade)
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_FILE_SPREAD d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " dx=", dx1, "/", dx2,
		" cd=", cd1, "/", cd2, " cheb=", cheb,
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_west_first_pocket(main) -> bool:
	## v0.5.33: first follower dest is a 6-cell along-file stand, not the
	## 1-cell diagonal pocket next to the lead / west cover / rifle crate.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_POCKET_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 12:
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var lc: Vector2i = lead.grid_cell()
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_POCKET_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6:
		push_error("SMOKE_WEST_POCKET_CLOSE d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	if absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_POCKET_WALL d1=%s lead=%s" % [d1, lc])
		quit(44)
		return false
	if absi(d1.y - lc.y) < 2:
		push_error("SMOKE_WEST_POCKET_SIDE d1=%s lead=%s" % [d1, lc])
		quit(44)
		return false
	if d1.x <= 4:
		push_error("SMOKE_WEST_POCKET_HUG d1=%s lead=%s" % [d1, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 2:
		push_error("SMOKE_WEST_POCKET_MASH d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_POCKET_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_POCKET_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print("SMOKE_OK_WEST_FIRST_POCKET d1=", d1, " d2=", d2, " lead=", lc, " cd1=", cd1, " pair=", pair)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_face_arc_cluster_bow(main) -> bool:
	## South face of the yard north-crate block: leftover wall-slide must bow.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_CLUSTER_BOW_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_CLUSTER_BOW_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var raw: PackedVector2Array = PackedVector2Array()
	if main.has_method("follow_arc_sample_raw"):
		raw = main.follow_arc_sample_raw(from_w, to_w, pivot, 15)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_CLUSTER_BOW_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
	if blocked > 0:
		push_error("SMOKE_ARC_CLUSTER_BOW_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	var raw_bow := 0.0
	if raw.size() >= 3 and main.has_method("follow_arc_chord_bow"):
		raw_bow = float(main.follow_arc_chord_bow(raw, from_w, to_w))
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_CLUSTER_BOW_FLAT bow=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	if raw_bow > 18.0 and snag_bow < raw_bow * 0.30:
		push_error("SMOKE_ARC_CLUSTER_BOW_SQUASH snag=%s raw=%s" % [snag_bow, raw_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_CLUSTER_BOW_WALL run=%s n=%s bow=%s" % [max_axis, pts.size(), snag_bow])
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 22.0:
		push_error("SMOKE_ARC_CLUSTER_BOW_EAST east=%s n=%s bow=%s" % [east, pts.size(), snag_bow])
		quit(44)
		return false
	if far > 40.0:
		push_error("SMOKE_ARC_CLUSTER_BOW_FAR far=%s n=%s bow=%s" % [far, pts.size(), snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_CLUSTER_BOW n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" raw_bow=", snapped(raw_bow, 0.1),
		" axis_run=", max_axis,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1)
	)
	return true


func _assert_face_arc_south_corridor(main) -> bool:
	## South corridor between north crates (18-22,9-12) and south crates
	## (16-20,14-16): stay on the y=13 gap, do not wrap east around the
	## south block.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_SOUTH_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_SOUTH_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_SOUTH_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var south_wrap := 0
	var east_cell := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		## Around the south crate block (16-20,14-16): east then south of
		## the gap. A 1-cell bow into y=14 on the open east half is the
		## corridor dip, not the wrap.
		if c.x >= 21 and c.y >= 15:
			south_wrap += 1
		if c.x > 24:
			east_cell += 1
	if blocked > 0:
		push_error("SMOKE_ARC_SOUTH_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if south_wrap > 2:
		push_error("SMOKE_ARC_SOUTH_EAST_WRAP n=%s wrap=%s" % [pts.size(), south_wrap])
		quit(44)
		return false
	if east_cell > 0:
		push_error("SMOKE_ARC_SOUTH_EAST_CELL n=%s east=%s" % [pts.size(), east_cell])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	if snag_bow < 12.0:
		push_error("SMOKE_ARC_SOUTH_FLAT bow=%s" % snag_bow)
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 18.0:
		push_error("SMOKE_ARC_SOUTH_EAST east=%s bow=%s" % [east, snag_bow])
		quit(44)
		return false
	if far > 36.0:
		push_error("SMOKE_ARC_SOUTH_FAR far=%s bow=%s" % [far, snag_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_SOUTH_WALL run=%s bow=%s" % [max_axis, snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_SOUTH_CORRIDOR n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" wrap=", south_wrap,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" axis_run=", max_axis
	)
	return true


func _assert_west_scale_0523(main) -> bool:
	## v0.5.23: west trio body/ring one step smaller than 0.40/0.36.
	## Dest cells / span 2 / yellow-cone fade stay as 0.5.22.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_SCALE_0523_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_SCALE_0523_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_SCALE_0523_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 2 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_SCALE_0523_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_SCALE_0523_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_SCALE_0523_OBS s=%s" % obs)
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_SCALE_0523_CONE s=%s" % fade)
		quit(44)
		return false
	if lead.cone == null or lead.cone.color.a > 0.20:
		push_error("SMOKE_WEST_SCALE_0523_CONE_A a=%s fade=%s" % [lead.cone.color.a if lead.cone else -1.0, fade])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_SCALE_0523_CONE_HIT n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_SCALE_0523 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_face_arc_south_cap(main) -> bool:
	## v0.5.23: south-corridor far-side bow stays below the old ~28px cap,
	## still walkable, no east overshoot, axis_run 0.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_SOUTH_CAP_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_SOUTH_CAP_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_SOUTH_CAP_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var south_wrap := 0
	var east_cell := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		if c.x >= 21 and c.y >= 15:
			south_wrap += 1
		if c.x > 24:
			east_cell += 1
	if blocked > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if south_wrap > 2:
		push_error("SMOKE_ARC_SOUTH_CAP_WRAP n=%s wrap=%s" % [pts.size(), south_wrap])
		quit(44)
		return false
	if east_cell > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_EAST_CELL n=%s east=%s" % [pts.size(), east_cell])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	if snag_bow < 10.0:
		push_error("SMOKE_ARC_SOUTH_CAP_FLAT bow=%s" % snag_bow)
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 4.0:
		push_error("SMOKE_ARC_SOUTH_CAP_EAST east=%s far=%s bow=%s" % [east, far, snag_bow])
		quit(44)
		return false
	if far > 26.0:
		push_error("SMOKE_ARC_SOUTH_CAP_FAR far=%s bow=%s" % [far, snag_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_SOUTH_CAP_WALL run=%s far=%s bow=%s" % [max_axis, far, snag_bow])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_SOUTH_CAP n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" wrap=", south_wrap,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" axis_run=", max_axis
	)
	return true


func _assert_west_cam_ring_0524(main) -> bool:
	## v0.5.24: more camera pull + observation-ring world offset. Dest cells
	## restaggered in 0.5.25; this assert keeps camera / ring / cone.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_CAM_RING_0524_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_CAM_RING_0524_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_CAM_RING_0524_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_CAM_RING_0524_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 2 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_CAM_RING_0524_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	if absi(d1.x - lc.x) >= 2 or absi(d2.x - lc.x) > 2:
		push_error("SMOKE_WEST_CAM_RING_0524_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_CAM_RING_0524_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 18.0:
		push_error("SMOKE_WEST_CAM_RING_0524_OBS_OFF off=%s z=%s" % [obs_off, z])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_CAM_RING_0524_CONE s=%s" % fade)
		quit(44)
		return false
	if lead.cone == null or lead.cone.color.a > 0.20:
		push_error("SMOKE_WEST_CAM_RING_0524_CONE_A a=%s fade=%s" % [lead.cone.color.a if lead.cone else -1.0, fade])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_CAM_RING_0524_CONE_HIT n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_CAM_RING_0524 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " zoom=", snapped(z, 0.01),
		" obs_off=", snapped(obs_off, 0.1),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_face_arc_south_cap_0524(main) -> bool:
	## v0.5.24: south-corridor far-side bow toward ~20px, still walkable,
	## no east overshoot, axis_run 0, fewer y=14 dips at the east end.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_SOUTH_CAP_0524_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var south_wrap := 0
	var east_cell := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		if c.x >= 21 and c.y >= 15:
			south_wrap += 1
		if c.x > 24:
			east_cell += 1
	if blocked > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if south_wrap > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_WRAP n=%s wrap=%s" % [pts.size(), south_wrap])
		quit(44)
		return false
	if east_cell > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_EAST_CELL n=%s east=%s" % [pts.size(), east_cell])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_FLAT bow=%s" % snag_bow)
		quit(44)
		return false
	if snag_bow > 22.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_BOW bow=%s" % snag_bow)
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 4.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_EAST east=%s far=%s bow=%s" % [east, far, snag_bow])
		quit(44)
		return false
	if far > 21.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_FAR far=%s bow=%s" % [far, snag_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_WALL run=%s far=%s bow=%s" % [max_axis, far, snag_bow])
		quit(44)
		return false
	var y14 := int(main.follow_arc_y14_east(pts, from_w, to_w)) if main.has_method("follow_arc_y14_east") else 99
	if y14 > 6:
		push_error("SMOKE_ARC_SOUTH_CAP_0524_Y14 n=%s y14=%s far=%s" % [pts.size(), y14, far])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_SOUTH_CAP_0524 n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" wrap=", south_wrap,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" y14=", y14,
		" axis_run=", max_axis
	)
	return true


func _assert_west_dest_0525(main) -> bool:
	## v0.5.33: dest cells spread. First follower 6 along-file (dx=1),
	## second 2 back / 3 the other way. Span 6. No west-wall hug, cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0525_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0525_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0525_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0525_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0525_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0525_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0525_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0525_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 5:
		push_error("SMOKE_WEST_DEST_0525_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0525_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0525_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0525_FADE s=%s" % fade)
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0525 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_face_arc_south_cap_0525(main) -> bool:
	## v0.5.25: south-corridor east-end samples stay in y≤13. Far-side bow
	## still ~20px, walkable, no east overshoot, axis_run 0.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_SOUTH_CAP_0525_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var south_wrap := 0
	var east_cell := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		if c.x >= 21 and c.y >= 15:
			south_wrap += 1
		if c.x > 24:
			east_cell += 1
	if blocked > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if south_wrap > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_WRAP n=%s wrap=%s" % [pts.size(), south_wrap])
		quit(44)
		return false
	if east_cell > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_EAST_CELL n=%s east=%s" % [pts.size(), east_cell])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_FLAT bow=%s" % snag_bow)
		quit(44)
		return false
	if snag_bow > 22.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_BOW bow=%s" % snag_bow)
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 0.5:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_EAST east=%s far=%s bow=%s" % [east, far, snag_bow])
		quit(44)
		return false
	if far > 21.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_FAR far=%s bow=%s" % [far, snag_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_WALL run=%s far=%s bow=%s" % [max_axis, far, snag_bow])
		quit(44)
		return false
	var y14 := int(main.follow_arc_y14_east(pts, from_w, to_w)) if main.has_method("follow_arc_y14_east") else 99
	if y14 > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0525_Y14 n=%s y14=%s far=%s" % [pts.size(), y14, far])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_SOUTH_CAP_0525 n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" wrap=", south_wrap,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" y14=", y14,
		" axis_run=", max_axis
	)
	return true


func _assert_face_arc_south_cap_0526(main) -> bool:
	## v0.5.26: full south-corridor path stays in y≤13, including mid
	## x≈21. Far-side bow may sit on the y=13 rim (~15px; cap constant
	## still 20). Walkable, no east overshoot, axis_run 0.
	if main.operators.size() < 1 or main.grid == null:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_NO_OPS")
		quit(44)
		return false
	if not main.has_method("follow_arc_sample_points"):
		push_error("SMOKE_ARC_SOUTH_CAP_0526_NO_API")
		quit(44)
		return false
	var pivot: Vector2 = main.grid.cell_to_world_center(Vector2i(20, 8))
	var from_w: Vector2 = main.grid.cell_to_world_center(Vector2i(16, 13))
	var to_w: Vector2 = main.grid.cell_to_world_center(Vector2i(24, 13))
	if main.has_method("_follow_snag_walkable"):
		from_w = main._follow_snag_walkable(from_w, pivot)
		to_w = main._follow_snag_walkable(to_w, pivot)
	var pts: PackedVector2Array = main.follow_arc_sample_points(from_w, to_w, pivot, 15)
	if pts.size() < 6:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_SHORT n=%s" % pts.size())
		quit(44)
		return false
	var blocked := 0
	var south_wrap := 0
	var east_cell := 0
	var y14_cells := 0
	var y14_mid := 0
	for p in pts:
		var c: Vector2i = main.grid.world_to_cell(p)
		if main.grid.is_blocked(c.x, c.y) or main._cell_is_operable(c):
			blocked += 1
		if c.x >= 21 and c.y >= 15:
			south_wrap += 1
		if c.x > 24:
			east_cell += 1
		if c.y >= 14:
			y14_cells += 1
			if c.x >= 20 and c.x <= 22:
				y14_mid += 1
	if blocked > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_CLIP n=%s blocked=%s" % [pts.size(), blocked])
		quit(44)
		return false
	if south_wrap > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_WRAP n=%s wrap=%s" % [pts.size(), south_wrap])
		quit(44)
		return false
	if east_cell > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_EAST_CELL n=%s east=%s" % [pts.size(), east_cell])
		quit(44)
		return false
	if y14_cells > 0 or y14_mid > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_Y14 n=%s y14=%s mid=%s" % [pts.size(), y14_cells, y14_mid])
		quit(44)
		return false
	var snag_bow := float(main.follow_arc_chord_bow(pts, from_w, to_w)) if main.has_method("follow_arc_chord_bow") else 0.0
	if snag_bow < 14.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_FLAT bow=%s" % snag_bow)
		quit(44)
		return false
	if snag_bow > 22.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_BOW bow=%s" % snag_bow)
		quit(44)
		return false
	var east := float(main.follow_arc_east_overshoot(pts, from_w, to_w)) if main.has_method("follow_arc_east_overshoot") else 0.0
	var far := float(main.follow_arc_far_overshoot(pts, from_w, to_w, pivot)) if main.has_method("follow_arc_far_overshoot") else 0.0
	if east > 0.5:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_EAST east=%s far=%s bow=%s" % [east, far, snag_bow])
		quit(44)
		return false
	if far > 21.0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_FAR far=%s bow=%s" % [far, snag_bow])
		quit(44)
		return false
	var max_axis := int(main.follow_arc_axis_run(pts)) if main.has_method("follow_arc_axis_run") else 99
	if max_axis >= 1:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_WALL run=%s far=%s bow=%s" % [max_axis, far, snag_bow])
		quit(44)
		return false
	var y14 := int(main.follow_arc_y14_east(pts, from_w, to_w)) if main.has_method("follow_arc_y14_east") else 99
	if y14 > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_Y14_API n=%s y14=%s far=%s" % [pts.size(), y14, far])
		quit(44)
		return false
	var y14m := int(main.follow_arc_y14_mid(pts, from_w, to_w)) if main.has_method("follow_arc_y14_mid") else 99
	if y14m > 0:
		push_error("SMOKE_ARC_SOUTH_CAP_0526_Y14_MID n=%s mid=%s far=%s" % [pts.size(), y14m, far])
		quit(44)
		return false
	print(
		"SMOKE_OK_FACE_ARC_SOUTH_CAP_0526 n=", pts.size(),
		" bow=", snapped(snag_bow, 0.1),
		" wrap=", south_wrap,
		" east=", snapped(east, 0.1),
		" far=", snapped(far, 0.1),
		" y14=", y14,
		" y14_mid=", y14m,
		" axis_run=", max_axis
	)
	return true


func _assert_west_obs_offset_0527(main) -> bool:
	## v0.5.27: dest cells (7,12)/(6,7)/(5,15) span 6. Observation
	## rings offset further along-file / courtyard. No west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_OBS_OFFSET_0527_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_OBS_OFFSET_0527_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_OBS_OFF off=%s d1=%s d2=%s" % [obs_off, d1, d2])
		quit(44)
		return false
	var ring_sp := float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0
	if ring_sp < 120.0:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_RING_SP sp=%s off=%s" % [ring_sp, obs_off])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_HUG n=%s off=%s" % [hug, obs_off])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_FADE s=%s" % fade)
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_OBS_OFFSET_0527_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_OFFSET_0527 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " obs_off=", snapped(obs_off, 0.1),
		" ring_sp=", snapped(ring_sp, 0.1), " hug=", hug,
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_obs_cam_0528(main) -> bool:
	## v0.5.28: dest cells (7,12)/(6,7)/(5,15) span 6. Observation
	## rings offset one more along-file / courtyard step. Camera pulls
	## to ~0.34. No west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_CAM_0528_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_OBS_CAM_0528_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_OBS_CAM_0528_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_OBS_CAM_0528_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_OBS_CAM_0528_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_OBS_CAM_0528_OBS_OFF off=%s d1=%s d2=%s" % [obs_off, d1, d2])
		quit(44)
		return false
	var ring_sp := float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0
	if ring_sp < 120.0:
		push_error("SMOKE_WEST_OBS_CAM_0528_RING_SP sp=%s off=%s" % [ring_sp, obs_off])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_OBS_CAM_0528_HUG n=%s off=%s" % [hug, obs_off])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_OBS_CAM_0528_ZOOM z=%s off=%s" % [z, obs_off])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_OBS_CAM_0528_FADE s=%s" % fade)
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_OBS_CAM_0528_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_CAM_0528 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " obs_off=", snapped(obs_off, 0.1),
		" ring_sp=", snapped(ring_sp, 0.1), " hug=", hug,
		" zoom=", snapped(z, 0.01),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_obs_cam_0529(main) -> bool:
	## v0.5.29: dest cells (7,12)/(6,7)/(5,15) span 6. Smaller
	## bodies (~0.30) and observation rings (~0.24). Rings offset one
	## more along-file / courtyard step. Camera pulls to ~0.32. No
	## west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_CAM_0529_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 20)
	for _hold in 22:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_OBS_CAM_0529_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_OBS_CAM_0529_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_OBS_CAM_0529_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_OBS_CAM_0529_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_OBS_CAM_0529_OBS_OFF off=%s d1=%s d2=%s" % [obs_off, d1, d2])
		quit(44)
		return false
	var ring_sp := float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0
	if ring_sp < 120.0:
		push_error("SMOKE_WEST_OBS_CAM_0529_RING_SP sp=%s off=%s" % [ring_sp, obs_off])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_OBS_CAM_0529_HUG n=%s off=%s" % [hug, obs_off])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_OBS_CAM_0529_ZOOM z=%s off=%s" % [z, obs_off])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0529_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0529_OBS s=%s" % obs)
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_OBS_CAM_0529_FADE s=%s" % fade)
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_OBS_CAM_0529_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_CAM_0529 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " obs_off=", snapped(obs_off, 0.1),
		" ring_sp=", snapped(ring_sp, 0.1), " hug=", hug,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_obs_cam_0530(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. Bodies and
	## observation rings at ~1.0. Leftover zoom cap raised
	## past 0.34 so camera ~1.0 can land. No west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_CAM_0530_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 24:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_OBS_CAM_0530_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_OBS_CAM_0530_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_OBS_CAM_0530_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_OBS_CAM_0530_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_OBS_CAM_0530_OBS_OFF off=%s d1=%s d2=%s" % [obs_off, d1, d2])
		quit(44)
		return false
	var ring_sp := float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0
	if ring_sp < 120.0:
		push_error("SMOKE_WEST_OBS_CAM_0530_RING_SP sp=%s off=%s" % [ring_sp, obs_off])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_OBS_CAM_0530_HUG n=%s off=%s" % [hug, obs_off])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_OBS_CAM_0530_ZOOM z=%s off=%s" % [z, obs_off])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0530_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0530_OBS s=%s" % obs)
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_OBS_CAM_0530_FADE s=%s" % fade)
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_OBS_CAM_0530_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_CAM_0530 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " obs_off=", snapped(obs_off, 0.1),
		" ring_sp=", snapped(ring_sp, 0.1), " hug=", hug,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_obs_cam_0531(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. Bodies and
	## observation rings at ~1.0. Rings offset one more
	## along-file / courtyard step. Leftover zoom cap raised past 0.34 so
	## camera ~1.0 can land. No west-wall hug.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_OBS_CAM_0531_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 24:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_OBS_CAM_0531_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_OBS_CAM_0531_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_OBS_CAM_0531_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_OBS_CAM_0531_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_OBS_CAM_0531_OBS_OFF off=%s d1=%s d2=%s" % [obs_off, d1, d2])
		quit(44)
		return false
	var ring_sp := float(main.follow_obs_ring_min_spacing()) if main.has_method("follow_obs_ring_min_spacing") else 0.0
	if ring_sp < 120.0:
		push_error("SMOKE_WEST_OBS_CAM_0531_RING_SP sp=%s off=%s" % [ring_sp, obs_off])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_OBS_CAM_0531_HUG n=%s off=%s" % [hug, obs_off])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_OBS_CAM_0531_ZOOM z=%s off=%s" % [z, obs_off])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0531_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_OBS_CAM_0531_OBS s=%s" % obs)
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_OBS_CAM_0531_FADE s=%s" % fade)
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_OBS_CAM_0531_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_OBS_CAM_0531 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " obs_off=", snapped(obs_off, 0.1),
		" ring_sp=", snapped(ring_sp, 0.1), " hug=", hug,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0532(main) -> bool:
	## v0.5.39 leftover: dest cells spread. First follower 6 along-file
	## (dx=1, not hugging the west wall), second 2 back / 4 the other way.
	## Span 6. Cone still empty. Visual knobs stay at the floor.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0532_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0532_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0532_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0532_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0532_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0532_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0532_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0532_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 5:
		push_error("SMOKE_WEST_DEST_0532_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0532_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0532_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0532_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0532_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0532 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0533(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. First 6
	## along-file (dx=1, not hugging the west wall), second 2 back / 4
	## the other way. Follow camera ~1.0 (floor ≥0.85) with pan/crop.
	## Bodies/rings restored to ~1.0. Cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0533_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0533_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0533_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0533_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0533_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0533_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0533_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0533_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 7:
		push_error("SMOKE_WEST_DEST_0533_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0533_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0533_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0533_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0533_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0533_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0533_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0533_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 160.0:
		push_error("SMOKE_WEST_DEST_0533_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0533 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01),
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0534(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. On-ring
	## extra cut so #2's ring does not punch the west wall. Dest world
	## clamps onto walkable floor. Leftover zoom cap raised past 0.34 so
	## camera ~1.0 can land. Bodies/rings restored to ~1.0.
	## Cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0534_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0534_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0534_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0534_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0534_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	var cd2 := maxi(absi(d2.x - lc.x), absi(d2.y - lc.y))
	if cd2 < 4 or d2.y < 16 or absi(d2.x - lc.x) > 2:
		push_error("SMOKE_WEST_DEST_0534_SECOND d2=%s lead=%s cd=%s" % [d2, lc, cd2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0534_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0534_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0534_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 7:
		push_error("SMOKE_WEST_DEST_0534_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0534_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0534_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0534_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0534_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var extra := float(main.follow_west_ring_extra()) if main.has_method("follow_west_ring_extra") else 99.0
	if extra > 50.0:
		push_error("SMOKE_WEST_DEST_0534_EXTRA extra=%s d1=%s d2=%s" % [extra, d1, d2])
		quit(44)
		return false
	var ring_x := float(main.follow_ring_west_min_x()) if main.has_method("follow_ring_west_min_x") else 0.0
	if ring_x < 156.0:
		push_error("SMOKE_WEST_DEST_0534_RING_X x=%s extra=%s d2=%s" % [ring_x, extra, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0534_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0534_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0534_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0534_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 160.0:
		push_error("SMOKE_WEST_DEST_0534_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0534 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " cd2=", cd2, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01),
		" zoom=", snapped(z, 0.01),
		" extra=", snapped(extra, 0.1),
		" ring_x=", snapped(ring_x, 0.1),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0535(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. West-follow
	## detour ≤6. Dest world spread above the 184.6 lead→#2 edge. Leftover
	## zoom cap raised past 0.34 so camera ~1.0 can land. Bodies/rings stay
	## at ~1.0. Cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0535_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0535_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0535_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0535_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0535_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	var cd2 := maxi(absi(d2.x - lc.x), absi(d2.y - lc.y))
	if cd2 < 4 or d2.y < 16 or absi(d2.x - lc.x) > 2:
		push_error("SMOKE_WEST_DEST_0535_SECOND d2=%s lead=%s cd=%s" % [d2, lc, cd2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0535_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0535_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0535_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 8:
		push_error("SMOKE_WEST_DEST_0535_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0535_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0535_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0535_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0535_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var extra := float(main.follow_west_ring_extra()) if main.has_method("follow_west_ring_extra") else 99.0
	if extra > 50.0:
		push_error("SMOKE_WEST_DEST_0535_EXTRA extra=%s d1=%s d2=%s" % [extra, d1, d2])
		quit(44)
		return false
	var ring_x := float(main.follow_ring_west_min_x()) if main.has_method("follow_ring_west_min_x") else 0.0
	if ring_x < 156.0:
		push_error("SMOKE_WEST_DEST_0535_RING_X x=%s extra=%s d2=%s" % [ring_x, extra, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0535_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0535_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0535_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 186.0:
		push_error("SMOKE_WEST_DEST_0535_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0535_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0535 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " cd2=", cd2, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01),
		" zoom=", snapped(z, 0.01),
		" extra=", snapped(extra, 0.1),
		" ring_x=", snapped(ring_x, 0.1),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0536(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. Camera ~1.0.
	## Dest world spread above the 184.6 lead→#2 edge. West-follow detour ≤6.
	## Bodies/rings restored to ~1.0. Cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0536_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0536_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0536_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0536_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0536_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	var cd2 := maxi(absi(d2.x - lc.x), absi(d2.y - lc.y))
	if cd2 < 4 or d2.y < 16 or absi(d2.x - lc.x) > 2:
		push_error("SMOKE_WEST_DEST_0536_SECOND d2=%s lead=%s cd=%s" % [d2, lc, cd2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0536_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0536_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0536_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 8:
		push_error("SMOKE_WEST_DEST_0536_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0536_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0536_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0536_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0536_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var extra := float(main.follow_west_ring_extra()) if main.has_method("follow_west_ring_extra") else 99.0
	if extra > 50.0:
		push_error("SMOKE_WEST_DEST_0536_EXTRA extra=%s d1=%s d2=%s" % [extra, d1, d2])
		quit(44)
		return false
	var ring_x := float(main.follow_ring_west_min_x()) if main.has_method("follow_ring_west_min_x") else 0.0
	if ring_x < 156.0:
		push_error("SMOKE_WEST_DEST_0536_RING_X x=%s extra=%s d2=%s" % [ring_x, extra, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0536_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0536_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0536_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 186.0:
		push_error("SMOKE_WEST_DEST_0536_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0536_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0536 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " cd2=", cd2, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01),
		" zoom=", snapped(z, 0.01),
		" extra=", snapped(extra, 0.1),
		" ring_x=", snapped(ring_x, 0.1),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0537(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. #1 stays
	## along-file; #2 stays (5,16). Follow camera ~1.0 (floor ≥0.85) with
	## pan/crop. Bodies/rings ~1.0. West-follow detour ≤6. Cone still empty.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0537_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0537_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0537_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0537_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var cd1 := maxi(absi(d1.x - lc.x), absi(d1.y - lc.y))
	if cd1 < 6 or absi(d1.x - lc.x) >= 2:
		push_error("SMOKE_WEST_DEST_0537_POCKET d1=%s lead=%s cd=%s" % [d1, lc, cd1])
		quit(44)
		return false
	var cd2 := maxi(absi(d2.x - lc.x), absi(d2.y - lc.y))
	if cd2 < 4 or d2.y < 16 or absi(d2.x - lc.x) > 2:
		push_error("SMOKE_WEST_DEST_0537_SECOND d2=%s lead=%s cd=%s" % [d2, lc, cd2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0537_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d1.x == lc.x or d2.x == lc.x:
		push_error("SMOKE_WEST_DEST_0537_COLUMN d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_DEST_0537_REAR d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	var pair := maxi(absi(d1.x - d2.x), absi(d1.y - d2.y))
	if pair < 9:
		push_error("SMOKE_WEST_DEST_0537_MASH d1=%s d2=%s pair=%s" % [d1, d2, pair])
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 2:
		push_error("SMOKE_WEST_DEST_0537_STACK cheb=%s d1=%s d2=%s" % [cheb, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_WEST_DEST_0537_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0537_FADE s=%s" % fade)
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0537_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var extra := float(main.follow_west_ring_extra()) if main.has_method("follow_west_ring_extra") else 99.0
	if extra > 50.0:
		push_error("SMOKE_WEST_DEST_0537_EXTRA extra=%s d1=%s d2=%s" % [extra, d1, d2])
		quit(44)
		return false
	var ring_x := float(main.follow_ring_west_min_x()) if main.has_method("follow_ring_west_min_x") else 0.0
	if ring_x < 156.0:
		push_error("SMOKE_WEST_DEST_0537_RING_X x=%s extra=%s d2=%s" % [ring_x, extra, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0537_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0537_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0537_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 186.0:
		push_error("SMOKE_WEST_DEST_0537_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0537_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var world_span: Vector2 = main.follow_cam_world_span() if main.has_method("follow_cam_world_span") else Vector2(1280, 720)
	if world_span.x > 1600.0:
		push_error("SMOKE_WEST_DEST_0537_POSTAGE span=%s z=%s" % [world_span, z])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_DEST_0537 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span, " cd1=", cd1, " cd2=", cd2, " pair=", pair, " cheb=", cheb,
		" fade=", snapped(fade, 0.01),
		" zoom=", snapped(z, 0.01),
		" extra=", snapped(extra, 0.1),
		" ring_x=", snapped(ring_x, 0.1),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour,
		" world_span=", snapped(world_span.x, 1.0), "x", snapped(world_span.y, 1.0)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0538(main) -> bool:
	## v0.5.39 leftover: dest cells (7,12)/(6,6)/(5,16) span 6. Follow camera ~1.0
	## (floor ≥0.85) with pan/crop so the courtyard is not a postage stamp.
	## Bodies and observation rings ~1.0. West-follow detour ≤6.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0538_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0538_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0538_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0538_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0538_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d2.y < 16:
		push_error("SMOKE_WEST_DEST_0538_SOUTH d2=%s lead=%s" % [d2, lc])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0538_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0538_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0538_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0538_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 186.0:
		push_error("SMOKE_WEST_DEST_0538_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0538_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0538_FADE s=%s" % fade)
		quit(44)
		return false
	var world_span: Vector2 = main.follow_cam_world_span() if main.has_method("follow_cam_world_span") else Vector2(1280, 720)
	if world_span.x > 1600.0:
		push_error("SMOKE_WEST_DEST_0538_POSTAGE span=%s z=%s" % [world_span, z])
		quit(44)
		return false
	var pan: Vector2 = main.follow_cam_pan() if main.has_method("follow_cam_pan") else Vector2.ZERO
	print(
		"SMOKE_OK_WEST_DEST_0538 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour,
		" world_span=", snapped(world_span.x, 1.0), "x", snapped(world_span.y, 1.0),
		" pan=", snapped(pan.x, 0.1), snapped(pan.y, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_dest_0539(main) -> bool:
	## v0.5.39: dest cells (7,12)/(6,6)/(5,16) span 6. Follow camera ~1.0
	## (floor ≥0.85) with pan/crop so the courtyard is not a postage stamp.
	## Bodies and observation rings ~1.0. West-follow detour ≤6.
	## Courtyard / along-file ring offset is a modest 1.0-scale stagger
	## (obs_off well below the 0.16-era 154px courtyard shove).
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_DEST_0539_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_DEST_0539_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var lc: Vector2i = lead.grid_cell()
	if lc != Vector2i(7, 12) and lc != Vector2i(7, 13):
		push_error("SMOKE_WEST_DEST_0539_LEAD lead=%s d1=%s d2=%s" % [lc, d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_DEST_0539_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	if d1.x <= 4 or d2.x <= 4:
		push_error("SMOKE_WEST_DEST_0539_WALL d1=%s d2=%s lead=%s" % [d1, d2, lc])
		quit(44)
		return false
	if d2.y < 16:
		push_error("SMOKE_WEST_DEST_0539_SOUTH d2=%s lead=%s" % [d2, lc])
		quit(44)
		return false
	var hug := int(main.follow_obs_west_hug()) if main.has_method("follow_obs_west_hug") else 99
	if hug > 0:
		push_error("SMOKE_WEST_DEST_0539_HUG n=%s d1=%s d2=%s" % [hug, d1, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_DEST_0539_ZOOM z=%s d1=%s d2=%s" % [z, d1, d2])
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_DEST_0539_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_DEST_0539_OBS s=%s" % obs)
		quit(44)
		return false
	var dest_spread := float(main.follow_dest_world_min_spacing()) if main.has_method("follow_dest_world_min_spacing") else 0.0
	if dest_spread < 186.0:
		push_error("SMOKE_WEST_DEST_0539_SPREAD spread=%s d1=%s d2=%s" % [dest_spread, d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_DEST_0539_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var fade := float(main.follow_cone_visual_fade()) if main.has_method("follow_cone_visual_fade") else 1.0
	if fade > 0.50:
		push_error("SMOKE_WEST_DEST_0539_FADE s=%s" % fade)
		quit(44)
		return false
	var world_span: Vector2 = main.follow_cam_world_span() if main.has_method("follow_cam_world_span") else Vector2(1280, 720)
	if world_span.x > 1600.0:
		push_error("SMOKE_WEST_DEST_0539_POSTAGE span=%s z=%s" % [world_span, z])
		quit(44)
		return false
	var courtyard := float(main.follow_west_obs_courtyard()) if main.has_method("follow_west_obs_courtyard") else 99.0
	if courtyard > 22.0:
		push_error("SMOKE_WEST_DEST_0539_COURTYARD n=%s d1=%s d2=%s" % [courtyard, d1, d2])
		quit(44)
		return false
	var obs_off := float(main.follow_obs_world_offset()) if main.has_method("follow_obs_world_offset") else 0.0
	if obs_off < 40.0:
		push_error("SMOKE_WEST_DEST_0539_OBS_OFF_LO off=%s courtyard=%s" % [obs_off, courtyard])
		quit(44)
		return false
	if obs_off > 120.0:
		push_error("SMOKE_WEST_DEST_0539_OBS_OFF_HI off=%s courtyard=%s" % [obs_off, courtyard])
		quit(44)
		return false
	var pan: Vector2 = main.follow_cam_pan() if main.has_method("follow_cam_pan") else Vector2.ZERO
	print(
		"SMOKE_OK_WEST_DEST_0539 d1=", d1, " d2=", d2, " lead=", lc,
		" span=", span,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" fade=", snapped(fade, 0.01),
		" dest_spread=", snapped(dest_spread, 0.1),
		" detour=", detour,
		" courtyard=", snapped(courtyard, 0.1),
		" obs_off=", snapped(obs_off, 0.1),
		" world_span=", snapped(world_span.x, 1.0), "x", snapped(world_span.y, 1.0),
		" pan=", snapped(pan.x, 0.1), snapped(pan.y, 0.1)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_obs_fill_0540(main) -> bool:
	## Fill is a short LOS wash on the body. Outline stays at kit_range (~280
	## scout). Courtyard crate island (19,10) must not sit inside the fill.
	## Dest (6,6)/(5,16) span 6, zoom/body/obs scale ~1.0, detour ≤6 kept.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_FILL_0540_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 16)
	for _hold in 16:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_FILL_0540_DEST d1=%s d2=%s want=(6,6)/(5,16)" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_FILL_0540_SPAN n=%s d1=%s d2=%s" % [span, d1, d2])
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_FILL_0540_ZOOM z=%s" % z)
		quit(44)
		return false
	var scale := float(main.follow_cluster_body_scale()) if main.has_method("follow_cluster_body_scale") else 1.0
	if scale < 0.92:
		push_error("SMOKE_WEST_FILL_0540_BODY s=%s" % scale)
		quit(44)
		return false
	var obs := float(main.follow_obs_visual_scale()) if main.has_method("follow_obs_visual_scale") else 1.0
	if obs < 0.92:
		push_error("SMOKE_WEST_FILL_0540_OBS s=%s" % obs)
		quit(44)
		return false
	var kit := float(main.follow_obs_kit_range()) if main.has_method("follow_obs_kit_range") else 0.0
	if kit < 270.0 or kit > 290.0:
		push_error("SMOKE_WEST_FILL_0540_KIT kit=%s (want scout 280)" % kit)
		quit(44)
		return false
	var obs_r := float(main.follow_obs_visual_radius()) if main.has_method("follow_obs_visual_radius") else 0.0
	if obs_r < 250.0:
		push_error("SMOKE_WEST_FILL_0540_RADIUS r=%s kit=%s" % [obs_r, kit])
		quit(44)
		return false
	var fill_a := float(main.follow_obs_fill_alpha()) if main.has_method("follow_obs_fill_alpha") else 1.0
	if fill_a > 0.016:
		push_error("SMOKE_WEST_FILL_0540_ALPHA a=%s" % fill_a)
		quit(44)
		return false
	var court := int(main.follow_obs_fill_courtyard()) if main.has_method("follow_obs_fill_courtyard") else 1
	if court != 0:
		push_error("SMOKE_WEST_FILL_0540_COURT hit=%s r=%s" % [court, obs_r])
		quit(44)
		return false
	var world_span: Vector2 = main.follow_cam_world_span() if main.has_method("follow_cam_world_span") else Vector2(1280, 720)
	if world_span.x > 1600.0:
		push_error("SMOKE_WEST_FILL_0540_POSTAGE span=%s z=%s" % [world_span, z])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_FILL_0540 d1=", d1, " d2=", d2,
		" span=", span,
		" zoom=", snapped(z, 0.01),
		" scale=", snapped(scale, 0.01),
		" obs=", snapped(obs, 0.01),
		" kit=", snapped(kit, 0.1),
		" obs_r=", snapped(obs_r, 0.1),
		" fill_a=", snapped(fill_a, 0.001),
		" court=", court,
		" world_span=", snapped(world_span.x, 1.0), "x", snapped(world_span.y, 1.0)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_update_observation_rings"):
		main._update_observation_rings()
	return true


func _assert_west_file_0541(main) -> bool:
	## Formation tape through west dests. Dest cells stay (6,6)/(5,16) span 6.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WEST_FILE_0541_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 12)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(Vector2i(6, 14))
	b.global_position = main.grid.cell_to_world_center(Vector2i(6, 16))
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow(0.05)
	await _tick_follow_steps(main, 12)
	for _hold in 12:
		if main.has_method("_update_observation_rings"):
			main._update_observation_rings()
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		main._tick_squad_follow(0.05)
		if main.has_method("_sync_follow_file_line"):
			main._sync_follow_file_line()
		await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1 != Vector2i(6, 6) or d2 != Vector2i(5, 16):
		push_error("SMOKE_WEST_FILE_0541_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span != 6:
		push_error("SMOKE_WEST_FILE_0541_SPAN n=%s" % span)
		quit(44)
		return false
	var z := float(main.get("_cam_squad_zoom")) if main.get("_cam_squad_zoom") != null else 1.0
	if z < 0.85:
		push_error("SMOKE_WEST_FILE_0541_ZOOM z=%s" % z)
		quit(44)
		return false
	var n := int(main.follow_file_point_count()) if main.has_method("follow_file_point_count") else 0
	if n < 3:
		push_error("SMOKE_WEST_FILE_0541_PTS n=%s" % n)
		quit(44)
		return false
	var flen := float(main.follow_file_length()) if main.has_method("follow_file_length") else 0.0
	if flen < 240.0:
		push_error("SMOKE_WEST_FILE_0541_LEN n=%s pts=%s" % [flen, n])
		quit(44)
		return false
	var world_span: Vector2 = main.follow_cam_world_span() if main.has_method("follow_cam_world_span") else Vector2(1280, 720)
	if world_span.x > 1600.0:
		push_error("SMOKE_WEST_FILE_0541_POSTAGE span=%s z=%s" % [world_span, z])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_FILE_0541 d1=", d1, " d2=", d2,
		" span=", span, " pts=", n, " len=", snapped(flen, 0.1),
		" zoom=", snapped(z, 0.01),
		" world_span=", snapped(world_span.x, 1.0), "x", snapped(world_span.y, 1.0)
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if main.has_method("_clear_follow_dest_marks"):
		main._clear_follow_dest_marks()
	return true


func _assert_first_session_0542(main) -> bool:
	## 跟 chip is thumb-sized. 开匣 sits above the crate, not in the west soap.
	## 需枪 CTA stays 需枪 until a gun is held.
	if main.operators.is_empty() or main.c2 == null or main.c2.portraits == null:
		push_error("SMOKE_SESSION_0542_NO_UI")
		quit(44)
		return false
	var strip = main.c2.portraits
	main._select_op(0)
	if main.operators.size() > 1 and not bool(main.operators[1].follow_lead):
		pass
	main._update_hud()
	await process_frame
	await process_frame
	var hit: Rect2 = strip.follow_hit_rect(1) if strip.has_method("follow_hit_rect") else Rect2()
	if hit.size.x < 36.0 or hit.size.y < 20.0:
		push_error("SMOKE_SESSION_0542_CHIP_SMALL r=%s" % hit)
		quit(44)
		return false
	if hit.size.x > 52.0 or hit.size.y > 36.0:
		push_error("SMOKE_SESSION_0542_CHIP_FAT r=%s" % hit)
		quit(44)
		return false
	if main.raid_stashes.is_empty():
		push_error("SMOKE_SESSION_0542_NO_CRATE")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	var st = null
	for s in main.raid_stashes:
		if s != null and is_instance_valid(s) and not bool(s.collected):
			st = s
			break
	if st == null:
		push_error("SMOKE_SESSION_0542_NO_LIVE_CRATE")
		quit(44)
		return false
	op.stop_move()
	op.global_position = st.global_position
	main._select_op(0)
	var prompt = main.c2.prompt
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_SESSION_0542_NO_CRATE_CAP caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var op_s: Vector2 = xf * op.global_position
	var crate_rect := Rect2()
	for rec in prompt.visible_hotspot_rects():
		if str(rec.get("cmd", "")) == "crate":
			crate_rect = rec["rect"]
			break
	if crate_rect.size.x < 80.0:
		push_error("SMOKE_SESSION_0542_CRATE_THIN r=%s" % crate_rect)
		quit(44)
		return false
	if crate_rect.get_center().y > op_s.y - 4.0:
		push_error("SMOKE_SESSION_0542_CRATE_NOT_ABOVE r=%s op=%s" % [crate_rect, op_s])
		quit(44)
		return false
	op.cancel_search()
	op.global_position = home
	for o in main.operators:
		if o != null and o.has_method("wipe_inventory"):
			o.wipe_inventory()
	main._refresh_alarm_cta()
	main._refresh_touch_hud()
	var armed: bool = main.has_method("squad_has_firearm") and bool(main.squad_has_firearm())
	if not armed:
		if str(main.alarm_button.text) != "需枪":
			push_error("SMOKE_SESSION_0542_CTA %s" % main.alarm_button.text)
			quit(44)
			return false
		if main.touch_hud and main.touch_hud._btns.has("alarm") and str(main.touch_hud._btns["alarm"].text) != "需枪":
			push_error("SMOKE_SESSION_0542_TOUCH_CTA %s" % main.touch_hud._btns["alarm"].text)
			quit(44)
			return false
	print(
		"SMOKE_OK_SESSION_0542 chip=", hit,
		" crate=", crate_rect,
		" op_s=", op_s,
		" cta=", main.alarm_button.text
	)
	op.global_position = home
	prompt.refresh_now()
	return true


func _assert_west_crate_0601(main) -> bool:
	## Dump 07_west_crate cell (8,13): 开匣 must sit above the crate and not
	## west of the crate (obs soap). Dest/zoom/RAID unchanged.
	if main.operators.is_empty() or main.c2 == null or main.c2.prompt == null:
		push_error("SMOKE_WEST_CRATE_0601_NO_UI")
		quit(44)
		return false
	if main.raid_stashes.is_empty():
		push_error("SMOKE_WEST_CRATE_0601_NO_CRATE")
		quit(44)
		return false
	var st = null
	for s in main.raid_stashes:
		if s == null or not is_instance_valid(s) or bool(s.collected):
			continue
		var sc: Vector2i = s.cell if "cell" in s else Vector2i(-1, -1)
		if sc.x < 0 and main.grid:
			sc = main.grid.world_to_cell(s.global_position)
		if sc.x <= 12:
			st = s
			break
	if st == null:
		for s in main.raid_stashes:
			if s != null and is_instance_valid(s) and not bool(s.collected):
				st = s
				break
	if st == null:
		push_error("SMOKE_WEST_CRATE_0601_NO_LIVE")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	op.stop_move()
	if op.has_method("cancel_search"):
		op.cancel_search()
	op.global_position = st.global_position
	main._select_op(0)
	var prompt = main.c2.prompt
	prompt.refresh_now()
	await process_frame
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_WEST_CRATE_0601_NO_CAP caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var crate_s: Vector2 = xf * st.global_position
	var op_s: Vector2 = xf * op.global_position
	var crate_rect := Rect2()
	for rec in prompt.visible_hotspot_rects():
		if str(rec.get("cmd", "")) == "crate":
			crate_rect = rec["rect"]
			break
	if crate_rect.size.x < 90.0 or crate_rect.size.y < 36.0:
		push_error("SMOKE_WEST_CRATE_0601_THIN r=%s" % crate_rect)
		quit(44)
		return false
	if crate_rect.get_center().y > op_s.y - 4.0:
		push_error("SMOKE_WEST_CRATE_0601_NOT_ABOVE r=%s op=%s" % [crate_rect, op_s])
		quit(44)
		return false
	if crate_rect.position.x < crate_s.x - 16.0:
		push_error("SMOKE_WEST_CRATE_0601_WEST_SOAP r=%s crate_s=%s" % [crate_rect, crate_s])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_CRATE_0601 r=", crate_rect,
		" crate_s=", crate_s,
		" op_s=", op_s
	)
	if op.has_method("cancel_search"):
		op.cancel_search()
	op.global_position = home
	prompt.refresh_now()
	return true


func _assert_night_grade_0603(main) -> bool:
	## Hatch split under the faint obs ring. kit_range / dests unchanged.
	var Pal := load("res://scripts/art/ww2_palette.gd") as GDScript
	if Pal == null:
		push_error("SMOKE_NIGHT_0603_NO_PAL")
		quit(44)
		return false
	var g: Color = Pal.night_grade("yard")
	if g.g < 0.70 or g.r < 0.66:
		push_error("SMOKE_NIGHT_0603_GRADE_DIM %s" % g)
		quit(44)
		return false
	var fa: Color = Pal.floor_a("yard")
	var fb: Color = Pal.floor_b("yard")
	var split := absf(fa.g - fb.g)
	if split < 0.030:
		push_error("SMOKE_NIGHT_0603_HATCH_FLAT a=%s b=%s split=%s" % [fa, fb, snapped(split, 0.001)])
		quit(44)
		return false
	var keys_src := FileAccess.get_file_as_string("res://scripts/fx/night_keys.gd")
	if keys_src.find("20.2") < 0 or keys_src.find("crate island") < 0:
		push_error("SMOKE_NIGHT_0603_NO_COURT_KEY")
		quit(44)
		return false
	if main.has_method("_ensure_night_grade"):
		main._ensure_night_grade()
	print(
		"SMOKE_OK_NIGHT_GRADE_0603 g=", snapped(g.r, 0.01), snapped(g.g, 0.01), snapped(g.b, 0.01),
		" hatch=", snapped(split, 0.001)
	)
	return true


func _assert_alert_chrome_0605(main) -> bool:
	main._ensure_touch_hud()
	var th = main.touch_hud
	if th == null:
		push_error("SMOKE_ALERT_0605_NO_HUD")
		quit(44)
		return false
	var prev = main.phase
	main.phase = main.Phase.WATCHING
	if th.has_method("refresh_phase"):
		th.refresh_phase("WATCHING", false, false, false, false)
	main._update_hud()
	var pause: Button = th._btns.get("pause") if th._btns.has("pause") else null
	var speed: Button = th._btns.get("speed") if th._btns.has("speed") else null
	var abort: Button = th._btns.get("abort") if th._btns.has("abort") else null
	if pause == null or speed == null or abort == null:
		push_error("SMOKE_ALERT_0605_BTNS")
		quit(44)
		return false
	if pause.custom_minimum_size.x < 118.0 or pause.custom_minimum_size.y < 62.0:
		push_error("SMOKE_ALERT_0605_PAUSE_SMALL %s" % pause.custom_minimum_size)
		quit(44)
		return false
	if speed.custom_minimum_size.x < 118.0 or abort.custom_minimum_size.x < 118.0:
		push_error("SMOKE_ALERT_0605_THIN speed=%s abort=%s" % [speed.custom_minimum_size, abort.custom_minimum_size])
		quit(44)
		return false
	if str(abort.text).find("中止观战") < 0:
		push_error("SMOKE_ALERT_0605_ABORT_LABEL %s" % abort.text)
		quit(44)
		return false
	var hint := str(th._hint.text) if th._hint else ""
	if hint.find("暂停") < 0 or hint.find("倍速") < 0 or hint.find("中止") < 0:
		push_error("SMOKE_ALERT_0605_HINT %s" % hint)
		quit(44)
		return false
	if hint.length() > 36:
		push_error("SMOKE_ALERT_0605_HINT_LONG n=%s %s" % [hint.length(), hint])
		quit(44)
		return false
	var cmds: PackedStringArray = th.watch_visible_cmds() if th.has_method("watch_visible_cmds") else PackedStringArray()
	if not cmds.has("pause") or not cmds.has("speed") or not cmds.has("abort"):
		push_error("SMOKE_ALERT_0605_CMDS %s" % " ".join(cmds))
		quit(44)
		return false
	print("SMOKE_OK_ALERT_CHROME_0605 pause=", pause.custom_minimum_size, " hint=", hint)
	main.phase = prev
	if th.has_method("refresh_phase"):
		th.refresh_phase("SETUP", false, false, false, false)
	main._update_hud()
	return true


func _assert_flank_side_wrap(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.c2.sentries.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_SIDE_WRAP")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var sent = main.c2.sentries[0]
	var op_home: Vector2 = op.global_position
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var op_c := Vector2i(12, 14)
	var sent_c := Vector2i(12, 12)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(12, 13)
	if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c) or op_c == sent_c:
		op_c = Vector2i(11, 14)
	if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c) or op_c == sent_c:
		op_c = Vector2i(13, 14)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_SIDE_WRAP_NO_HOT caps=%s op=%s sent=%s" % [
			" ".join(prompt.visible_captions()), op_c, sent_c
		])
		quit(44)
		return false
	var dump: Dictionary = main.flank_guide_dump(sent, op) if main.has_method("flank_guide_dump") else {}
	var pts := int(dump.get("pts", 0))
	var wrap := bool(dump.get("wrap", false))
	var side := bool(dump.get("side", false))
	var body := int(dump.get("body", 99))
	var complete := bool(dump.get("complete", false))
	var dest: Vector2i = dump.get("dest", Vector2i(-1, -1))
	var sc: Vector2i = dump.get("sentry", sent_c)
	if pts < 4 or not wrap or not side or not complete or body > 0:
		push_error("SMOKE_SIDE_WRAP_SHORT pts=%s wrap=%s side=%s body=%s complete=%s dest=%s from=%s sc=%s cells=%s" % [
			pts, wrap, side, body, complete, dest, op.grid_cell(), sc, dump.get("cells", [])
		])
		quit(44)
		return false
	var gcells := int(prompt.guide_cell_count()) if prompt.has_method("guide_cell_count") else 0
	var gwrap := bool(prompt.guide_wraps()) if prompt.has_method("guide_wraps") else false
	if gcells < 4 or not gwrap:
		push_error("SMOKE_SIDE_WRAP_DASH cells=%s wrap=%s" % [gcells, gwrap])
		quit(44)
		return false
	var cells: Array = dump.get("cells", [])
	var saw_ring := false
	for c in cells:
		if typeof(c) != TYPE_VECTOR2I:
			continue
		if maxi(absi(c.x - sc.x), absi(c.y - sc.y)) >= 2:
			saw_ring = true
	if not saw_ring:
		push_error("SMOKE_SIDE_WRAP_NO_BODY_RING cells=%s sc=%s" % [cells, sc])
		quit(44)
		return false
	print("SMOKE_OK_FLANK_SIDE_WRAP pts=", pts, " dash=", gcells, " dest=", dest, " from=", op.grid_cell())
	op.stop_move()
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	op.global_position = op_home
	main._pending_flank = null
	prompt.refresh_now()
	return true


func _assert_follow_settle_no_drop(main) -> bool:
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_SETTLE_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(16, 14)
	var dest_c := Vector2i(24, 14)
	var a_c := Vector2i(12, 16)
	var b_c := Vector2i(12, 18)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(15, 14)
	if main.grid.is_blocked(dest_c.x, dest_c.y) or main._cell_is_operable(dest_c):
		dest_c = Vector2i(23, 14)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(11, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 18)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow()
	main._command_move_selected(main.grid.cell_to_world_center(dest_c))
	if not lead.is_moving():
		push_error("SMOKE_SETTLE_LEAD_STILL at=%s dest=%s" % [lead.grid_cell(), dest_c])
		quit(44)
		return false
	var walk_d1 := Vector2i(-1, -1)
	var walk_d2 := Vector2i(-1, -1)
	for _i in 90:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
		if lead.is_moving():
			walk_d1 = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
			walk_d2 = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		else:
			break
	var stop_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var stop_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	for _j in 40:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
	var end_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var end_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var drops := int(main.follow_settle_drops()) if main.has_method("follow_settle_drops") else 99
	if walk_d1.x < 0 or walk_d2.x < 0 or walk_d1 == walk_d2:
		push_error("SMOKE_SETTLE_WALK_DEST d1=%s d2=%s" % [walk_d1, walk_d2])
		quit(44)
		return false
	if end_d1 != stop_d1 or end_d2 != stop_d2:
		push_error("SMOKE_SETTLE_DEST_HOP stop=%s %s end=%s %s walk=%s %s" % [
			stop_d1, stop_d2, end_d1, end_d2, walk_d1, walk_d2
		])
		quit(44)
		return false
	if stop_d1 != walk_d1 or stop_d2 != walk_d2:
		push_error("SMOKE_SETTLE_DROP_ON_STOP walk=%s %s stop=%s %s" % [walk_d1, walk_d2, stop_d1, stop_d2])
		quit(44)
		return false
	if drops > 0:
		push_error("SMOKE_SETTLE_DROPS n=%s d1=%s d2=%s" % [drops, end_d1, end_d2])
		quit(44)
		return false
	if not _dest_is_rear(main, end_d1, lead) or not _dest_is_rear(main, end_d2, lead):
		push_error("SMOKE_SETTLE_NOT_REAR d1=%s d2=%s lead=%s" % [end_d1, end_d2, lead.grid_cell()])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_SETTLE d1=", end_d1, " d2=", end_d2, " lead=", lead.grid_cell())
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func _assert_three_follow_side_wrap(main) -> bool:
	if main.operators.size() < 3 or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_THREE_WRAP_NO_OPS")
		quit(44)
		return false
	var prompt = main.c2.prompt
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var lead_c := Vector2i(11, 14)
	var sent_c := Vector2i(12, 12)
	var a_c := Vector2i(9, 16)
	var b_c := Vector2i(8, 17)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(12, 13)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c) or lead_c == sent_c:
		lead_c = Vector2i(11, 14)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(8, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(7, 17)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if prompt:
		prompt.refresh_now()
	await process_frame
	if prompt == null or not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_THREE_WRAP_NO_FLANK caps=%s" % [
			" ".join(prompt.visible_captions()) if prompt else PackedStringArray()
		])
		quit(44)
		return false
	var dump: Dictionary = main.flank_guide_dump(sent, lead) if main.has_method("flank_guide_dump") else {}
	if int(dump.get("pts", 0)) < 4 or not bool(dump.get("wrap", false)) or int(dump.get("body", 99)) > 0:
		push_error("SMOKE_THREE_WRAP_GUIDE pts=%s wrap=%s body=%s cells=%s" % [
			dump.get("pts", 0), dump.get("wrap", false), dump.get("body", 99), dump.get("cells", [])
		])
		quit(44)
		return false
	if not bool(main.simulate_hotspot("绕背")):
		push_error("SMOKE_THREE_WRAP_FIRE")
		quit(44)
		return false
	await process_frame
	for _w in 40:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		await process_frame
		if not lead.is_moving():
			break
	lead.stop_move()
	if dump.has("dest") and typeof(dump.get("dest")) == TYPE_VECTOR2I:
		var back_c: Vector2i = dump.get("dest")
		if back_c.x >= 0:
			lead.global_position = main.grid.cell_to_world_center(back_c)
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	if not bool(a.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(1)
		else:
			main.toggle_follow(1)
	if not bool(b.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(2)
		else:
			main.toggle_follow(2)
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._tick_squad_follow()
	await _tick_follow_steps(main, 24)
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_THREE_WRAP_FOLLOW_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if cone > 0:
		push_error("SMOKE_THREE_WRAP_FOLLOW_CONE n=%s d1=%s d2=%s" % [cone, d1, d2])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_THREE_WRAP_NOT_REAR d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	print(
		"SMOKE_OK_THREE_FOLLOW_SIDE_WRAP pts=", dump.get("pts", 0),
		" d1=", d1, " d2=", d2, " lead=", lead.grid_cell()
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	main._pending_flank = null
	if prompt:
		prompt.refresh_now()
	return true


func _assert_follow_short_detour(main) -> bool:
	## Leader east of a west-facing cone; followers in the west alley must take a
	## 2–3 cell local detour toward the lead instead of stepping out and idling.
	if main.operators.size() < 3 or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_SHORT_DETOUR_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var sent_c := Vector2i(9, 12)
	var lead_c := Vector2i(12, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(9, 13)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(12, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 180.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	main._tick_squad_follow()
	await _tick_follow_steps(main, 24)
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_SHORT_DETOUR_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1.x < 9 and d2.x < 9:
		push_error("SMOKE_SHORT_DETOUR_WAIT_WEST d1=%s d2=%s a=%s b=%s" % [d1, d2, a.grid_cell(), b.grid_cell()])
		quit(44)
		return false
	if a.grid_cell() == a_c and b.grid_cell() == b_c and not a.is_moving() and not b.is_moving():
		push_error("SMOKE_SHORT_DETOUR_IDLE_START a=%s b=%s dest=%s %s" % [a.grid_cell(), b.grid_cell(), d1, d2])
		quit(44)
		return false
	var idle := int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else 99
	if idle > 0:
		push_error("SMOKE_SHORT_DETOUR_IDLE n=%s a=%s/%s b=%s/%s" % [idle, a.grid_cell(), d1, b.grid_cell(), d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 3:
		push_error("SMOKE_SHORT_DETOUR_LONG n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	var rim := int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else 99
	if cone > 0 or rim > 0:
		push_error("SMOKE_SHORT_DETOUR_CONE cone=%s rim=%s d1=%s d2=%s" % [cone, rim, d1, d2])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_SHORT_DETOUR d1=", d1, " d2=", d2, " a=", a.grid_cell(), " b=", b.grid_cell(), " detour=", detour)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	main._pending_flank = null
	return true


func _assert_follow_walk_continuity(main) -> bool:
	## Lead walks 8 cells east; followers keep one dest and do not stop-start.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_WALK_FOLLOW_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(16, 14)
	var dest_c := Vector2i(24, 14)
	var a_c := Vector2i(12, 16)
	var b_c := Vector2i(12, 18)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(15, 14)
	if main.grid.is_blocked(dest_c.x, dest_c.y) or main._cell_is_operable(dest_c):
		dest_c = Vector2i(23, 14)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(11, 16)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(11, 18)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	main._tick_squad_follow()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	main._command_move_selected(main.grid.cell_to_world_center(dest_c))
	if not lead.is_moving():
		push_error("SMOKE_WALK_FOLLOW_LEAD_STILL at=%s dest=%s" % [lead.grid_cell(), dest_c])
		quit(44)
		return false
	var stalls := 0
	var moving_ticks := 0
	var prev_d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var prev_d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var hop := 0
	var walk_flips := 0
	var saw_walk := false
	for _i in 90:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
		var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
		var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		if lead.is_moving():
			saw_walk = true
			if d1 != prev_d1:
				hop += 1
				prev_d1 = d1
			if d2 != prev_d2:
				hop += 1
				prev_d2 = d2
			if main.has_method("follow_dest_flips"):
				walk_flips = int(main.follow_dest_flips())
			var a_need := d1.x >= 0 and a.grid_cell() != d1
			var b_need := d2.x >= 0 and b.grid_cell() != d2
			if a_need and a.is_moving():
				moving_ticks += 1
			if b_need and b.is_moving():
				moving_ticks += 1
			if a_need and not a.is_moving():
				stalls += 1
			if b_need and not b.is_moving():
				stalls += 1
		else:
			prev_d1 = d1
			prev_d2 = d2
		if not lead.is_moving() and not a.is_moving() and not b.is_moving() and _i > 12:
			break
	var flips := walk_flips if saw_walk else (int(main.follow_dest_flips()) if main.has_method("follow_dest_flips") else hop)
	var d1f: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2f: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1f.x < 0 or d2f.x < 0 or d1f == d2f:
		push_error("SMOKE_WALK_FOLLOW_DEST d1=%s d2=%s" % [d1f, d2f])
		quit(44)
		return false
	if hops_too_many(flips, hop):
		push_error("SMOKE_WALK_FOLLOW_HOP flips=%s hop=%s d1=%s d2=%s" % [flips, hop, d1f, d2f])
		quit(44)
		return false
	if stalls > 8:
		push_error("SMOKE_WALK_FOLLOW_STALL n=%s move=%s a=%s/%s b=%s/%s" % [
			stalls, moving_ticks, a.grid_cell(), d1f, b.grid_cell(), d2f
		])
		quit(44)
		return false
	if moving_ticks < 8:
		push_error("SMOKE_WALK_FOLLOW_NO_MOVE n=%s stalls=%s" % [moving_ticks, stalls])
		quit(44)
		return false
	print(
		"SMOKE_OK_FOLLOW_WALK_CONT flips=", flips, " hop=", hop,
		" stalls=", stalls, " move=", moving_ticks,
		" d1=", d1f, " d2=", d2f, " lead=", lead.grid_cell()
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	return true


func hops_too_many(flips: int, hop: int) -> bool:
	return flips > 4 or hop > 6


func _assert_flank_guide_complete(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.c2.sentries.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_FLANK_GUIDE")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var sent = main.c2.sentries[0]
	var op_home: Vector2 = op.global_position
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var op_c := Vector2i(11, 14)
	var sent_c := Vector2i(12, 12)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(12, 13)
	if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c) or op_c == sent_c:
		op_c = Vector2i(10, 14)
	if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c) or op_c == sent_c:
		op_c = Vector2i(11, 13)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_FLANK_GUIDE_NO_HOT caps=%s op=%s sent=%s" % [
			" ".join(prompt.visible_captions()), op_c, sent_c
		])
		quit(44)
		return false
	var dump: Dictionary = {}
	if main.has_method("flank_guide_dump"):
		dump = main.flank_guide_dump(sent, op)
	var pts := int(dump.get("pts", 0))
	var complete := bool(dump.get("complete", false))
	var cone := int(dump.get("cone", 99))
	var gaps := int(dump.get("gaps", 99))
	var dest: Vector2i = dump.get("dest", Vector2i(-1, -1))
	var wrap := bool(dump.get("wrap", false))
	var side := bool(dump.get("side", false))
	var body := int(dump.get("body", 99))
	if pts < 4 or not complete or cone > 0 or gaps > 0 or not wrap or not side or body > 0:
		push_error("SMOKE_FLANK_GUIDE_INCOMPLETE pts=%s complete=%s cone=%s gaps=%s wrap=%s side=%s body=%s dest=%s from=%s" % [
			pts, complete, cone, gaps, wrap, side, body, dest, op.grid_cell()
		])
		quit(44)
		return false
	var guide_ok := true
	if prompt.has_method("guide_complete"):
		guide_ok = bool(prompt.guide_complete())
	var gpts := 0
	if prompt.has_method("guide_points"):
		gpts = int(prompt.guide_points().size())
	var gcells := 0
	if prompt.has_method("guide_cell_count"):
		gcells = int(prompt.guide_cell_count())
	var gwrap := true
	if prompt.has_method("guide_wraps"):
		gwrap = bool(prompt.guide_wraps())
	if not guide_ok or gpts < 4 or gcells < 4 or not gwrap:
		push_error("SMOKE_FLANK_GUIDE_DASH pts=%s cells=%s complete=%s wrap=%s" % [gpts, gcells, guide_ok, gwrap])
		quit(44)
		return false
	if not bool(main.simulate_hotspot("绕背")):
		push_error("SMOKE_FLANK_GUIDE_FIRE")
		quit(44)
		return false
	await process_frame
	var walk_pts := int(op.move_path.size())
	var walk_cone := 0
	for pt in op.move_path:
		if main._sentry_blocks_stealth(pt, op):
			walk_cone += 1
	if walk_pts < 2 and not (sent.has_method("in_backstab") and bool(sent.in_backstab(op.global_position))):
		push_error("SMOKE_FLANK_GUIDE_NO_WALK dest=%s at=%s" % [dest, op.grid_cell()])
		quit(44)
		return false
	if walk_cone > 0:
		push_error("SMOKE_FLANK_GUIDE_WALK_CONE n=%s pts=%s" % [walk_cone, walk_pts])
		quit(44)
		return false
	print(
		"SMOKE_OK_FLANK_GUIDE_COMPLETE pts=", pts, " dash=", gpts,
		" cells=", gcells, " wrap=", wrap, " body=", body,
		" dest=", dest, " walk=", walk_pts
	)
	op.stop_move()
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	op.global_position = op_home
	main._pending_flank = null
	prompt.refresh_now()
	return true


func _assert_follow_badge_hit(main) -> bool:
	if main.operators.size() < 2 or main.c2 == null or main.c2.portraits == null:
		push_error("SMOKE_BADGE_NO_STRIP")
		quit(44)
		return false
	var strip = main.c2.portraits
	var lead: OperatorUnit = main.operators[0]
	var other: OperatorUnit = main.operators[1]
	var was_follow := bool(other.follow_lead)
	main._select_op(0)
	if bool(other.follow_lead):
		main.toggle_follow(1)
	main._update_hud()
	await process_frame
	await process_frame
	if not strip.has_method("follow_hit_rect") or not strip.has_method("portrait_body_rect"):
		push_error("SMOKE_BADGE_NO_HIT_API")
		quit(44)
		return false
	var hit: Rect2 = strip.follow_hit_rect(1)
	var body: Rect2 = strip.portrait_body_rect(1)
	var card: Rect2 = strip.card_global_rect(1)
	if hit.size.x < 8.0 or hit.size.y < 8.0:
		push_error("SMOKE_BADGE_NO_CHIP r=%s vis=%s" % [hit, strip.visible])
		quit(44)
		return false
	if body.size.x < 8.0:
		push_error("SMOKE_BADGE_NO_BODY r=%s" % body)
		quit(44)
		return false
	if hit.intersects(body):
		push_error("SMOKE_BADGE_OVERLAP hit=%s body=%s" % [hit, body])
		quit(44)
		return false
	if hit.size.x > 52.0 or hit.size.y > 36.0:
		push_error("SMOKE_BADGE_TOO_FAT r=%s" % hit)
		quit(44)
		return false
	if not card.encloses(hit) and not card.intersects(hit):
		push_error("SMOKE_BADGE_OFF_CARD hit=%s card=%s" % [hit, card])
		quit(44)
		return false
	if hit.position.y > card.position.y + 1.0:
		push_error("SMOKE_BADGE_NOT_RAISED hit=%s card=%s" % [hit, card])
		quit(44)
		return false
	if hit.position.y + hit.size.y > card.position.y + 24.0:
		push_error("SMOKE_BADGE_EATS_GUN_BAND hit=%s card=%s" % [hit, card])
		quit(44)
		return false
	if strip.has_method("portrait_gun_rect"):
		var gun_r: Rect2 = strip.portrait_gun_rect(1)
		if gun_r.size.x > 1.0 and hit.intersects(gun_r):
			push_error("SMOKE_BADGE_GUN_HIT hit=%s gun=%s" % [hit, gun_r])
			quit(44)
			return false
	if strip.has_method("portrait_num_rect"):
		var num_r: Rect2 = strip.portrait_num_rect(1)
		if num_r.size.x > 1.0 and hit.intersects(num_r):
			push_error("SMOKE_BADGE_NUM_HIT hit=%s num=%s" % [hit, num_r])
			quit(44)
			return false
	var ht: Dictionary = strip.hit_test_at(hit.get_center()) if strip.has_method("hit_test_at") else {}
	if str(ht.get("kind", "")) != "follow" or int(ht.get("idx", -1)) != 1:
		push_error("SMOKE_BADGE_HIT_KIND %s" % ht)
		quit(44)
		return false
	var bt: Dictionary = strip.hit_test_at(body.get_center()) if strip.has_method("hit_test_at") else {}
	if str(bt.get("kind", "")) != "pick" or int(bt.get("idx", -1)) != 1:
		push_error("SMOKE_BADGE_BODY_KIND %s" % bt)
		quit(44)
		return false
	if strip.has_method("portrait_probe_points"):
		var probes: Dictionary = strip.portrait_probe_points(1)
		for key in [
			"glyph", "name", "hp", "stance", "below_chip", "left_of_chip",
			"gun", "num", "top_left", "just_below_chip", "inner_left",
			"gun_stamp", "number",
		]:
			if not probes.has(key):
				continue
			var pt: Vector2 = probes[key]
			var pk: Dictionary = strip.hit_test_at(pt)
			if str(pk.get("kind", "")) == "follow":
				push_error("SMOKE_BADGE_PROBE_FOLLOW key=%s pt=%s hit=%s body=%s card=%s" % [
					key, pt, hit, body, card
				])
				quit(44)
				return false
			if str(pk.get("kind", "")) != "pick" or int(pk.get("idx", -1)) != 1:
				push_error("SMOKE_BADGE_PROBE_KIND key=%s got=%s" % [key, pk])
				quit(44)
				return false
		var chip_pt: Vector2 = probes.get("chip", hit.get_center())
		var ck: Dictionary = strip.hit_test_at(chip_pt)
		if str(ck.get("kind", "")) != "follow" or int(ck.get("idx", -1)) != 1:
			push_error("SMOKE_BADGE_CHIP_PROBE %s" % ck)
			quit(44)
			return false
	main._select_op(0)
	if not main.has_method("simulate_portrait_body_tap"):
		push_error("SMOKE_BADGE_NO_BODY_TAP")
		quit(44)
		return false
	main.simulate_portrait_body_tap(1)
	await process_frame
	if main.selected != other:
		push_error("SMOKE_BADGE_BODY_NO_PICK got=%s" % (main.selected.display_name if main.selected else "null"))
		quit(44)
		return false
	if bool(other.follow_lead):
		push_error("SMOKE_BADGE_BODY_TOGGLED_FOLLOW")
		quit(44)
		return false
	main._select_op(0)
	main._update_hud()
	await process_frame
	if not main.has_method("simulate_follow_badge_tap"):
		push_error("SMOKE_BADGE_NO_CHIP_TAP")
		quit(44)
		return false
	var on := bool(main.simulate_follow_badge_tap(1))
	await process_frame
	if not on or not bool(other.follow_lead):
		push_error("SMOKE_BADGE_CHIP_MISS follow=%s sel=%s" % [
			other.follow_lead, main.selected.display_name if main.selected else "null"
		])
		quit(44)
		return false
	if main.selected != lead:
		push_error("SMOKE_BADGE_CHIP_STOLE_SEL got=%s" % (main.selected.display_name if main.selected else "null"))
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_BADGE_HIT hit=", hit, " body=", body)
	if bool(other.follow_lead) != was_follow:
		main.toggle_follow(1)
	main._select_op(0)
	return true


func _assert_west_stack_tap(main) -> bool:
	## Crowded west alley: tapping a follower's body must not steal selection
	## or fire 开匣; tapping a clear cell still walks.
	if main.operators.size() < 3 or main.grid == null:
		push_error("SMOKE_STACK_TAP_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var prompt = main.c2.prompt if main.c2 else null
	if main.c2 and not main.c2.sentries.is_empty():
		_park_sentries(main, null)
	var lead_c := Vector2i(7, 15)
	var a_c := Vector2i(6, 16)
	var b_c := Vector2i(8, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 16)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("cancel_search"):
		lead.cancel_search()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	if prompt:
		prompt.refresh_now()
	await process_frame
	main.simulate_touch_tap(a.global_position)
	await process_frame
	if main.selected != lead:
		push_error("SMOKE_STACK_TAP_BODY_SELECT got=%s" % (main.selected.display_name if main.selected else "null"))
		quit(44)
		return false
	if prompt and bool(prompt.has_caption("开匣")):
		push_error("SMOKE_STACK_TAP_CRATE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	lead.stop_move()
	var walk_c := Vector2i(8, 14)
	if main.grid.is_blocked(walk_c.x, walk_c.y) or main._cell_is_operable(walk_c):
		walk_c = Vector2i(7, 17)
	main.simulate_touch_tap(main.grid.cell_to_world_center(walk_c))
	await process_frame
	var gest := str(main._last_touch_gesture)
	if gest != "tap" and gest != "sprint":
		push_error("SMOKE_STACK_TAP_WALK_GESTURE got=%s" % gest)
		quit(44)
		return false
	print("SMOKE_OK_WEST_STACK_TAP gest=", gest, " caps=", " ".join(prompt.visible_captions()) if prompt else "")
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	if prompt:
		prompt.refresh_now()
	return true


func _assert_facing_ink_hidden(main) -> bool:
	main._select_op(0)
	if main.operators.size() > 0:
		main.operators[0]._refresh_face_chip()
		main.operators[0]._refresh_compass_rose()
	if main.has_method("_apply_phone_world_ink"):
		main._apply_phone_world_ink()
	await process_frame
	var ink: Dictionary = main.dump_world_ink()
	if int(ink.get("facing_visible", 9)) > 0:
		push_error("SMOKE_FACING_INK_ON n=%s" % ink.get("facing_visible"))
		quit(44)
		return false
	for op in main.operators:
		if op == null:
			continue
		if op.has_method("facing_world_ink_on") and bool(op.facing_world_ink_on()):
			push_error("SMOKE_FACING_INK_OP %s" % op.display_name)
			quit(44)
			return false
		var cap = op.get_node_or_null("CompassRose")
		if cap != null and cap.is_visible_in_tree():
			push_error("SMOKE_COMPASS_ON_PHONE")
			quit(44)
			return false
		var chip = op.get_node_or_null("FaceChip") as Label
		if chip != null and chip.is_visible_in_tree():
			push_error("SMOKE_FACECHIP_ON_PHONE")
			quit(44)
			return false
	print("SMOKE_OK_FACING_INK_HIDDEN n=", ink.get("facing_visible"))
	return true


func _assert_west_crate_touch(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.operators.is_empty() or not main.has_method("west_stash"):
		push_error("SMOKE_NO_WEST_CRATE_API")
		quit(44)
		return false
	var st = main.west_stash()
	if st == null:
		push_error("SMOKE_NO_WEST_STASH")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var home: Vector2 = op.global_position
	if main.c2 and not main.c2.sentries.is_empty() and main.grid:
		for s in main.c2.sentries:
			if s and is_instance_valid(s):
				s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6))
				s.facing_deg = 0.0
	main._select_op(0)
	op.stop_move()
	main.simulate_touch_tap(st.global_position)
	await process_frame
	var gest := str(main._last_touch_gesture)
	if gest != "tap" and gest != "sprint":
		push_error("SMOKE_WEST_CRATE_GESTURE got=%s" % gest)
		quit(44)
		return false
	op.stop_move()
	op.global_position = st.global_position
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_WEST_NO_CRATE caps=%s cell=%s" % [
			" ".join(prompt.visible_captions()), main.grid.world_to_cell(st.global_position)
		])
		quit(44)
		return false
	if not main.has_method("simulate_hotspot") or not bool(main.simulate_hotspot("开匣")):
		push_error("SMOKE_WEST_CRATE_HOTSPOT_FIRE")
		quit(44)
		return false
	print("SMOKE_OK_WEST_CRATE_TOUCH cell=", main.grid.world_to_cell(st.global_position))
	if op.has_method("cancel_search"):
		op.cancel_search()
	op.stop_move()
	op.global_position = home
	prompt.refresh_now()
	return true


func _assert_west_flank_touch_path(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.c2.sentries.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_WEST_FLANK_PATH")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var sent = main.c2.sentries[0]
	var op_home: Vector2 = op.global_position
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	var op_c := Vector2i(7, 12)
	var sent_c := Vector2i(9, 12)
	if main.grid:
		if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c):
			op_c = Vector2i(6, 13)
		if main.grid.is_blocked(sent_c.x, sent_c.y):
			sent_c = Vector2i(9, 13)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_WEST_PATH_NO_FLANK caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	var hits := int(prompt.hotspot_hits_west_operable()) if prompt.has_method("hotspot_hits_west_operable") else 99
	if hits > 0:
		push_error("SMOKE_WEST_PATH_FLANK_COVERS n=%s" % hits)
		quit(44)
		return false
	if not bool(main.simulate_hotspot("绕背")):
		push_error("SMOKE_WEST_FLANK_HOTSPOT_FIRE")
		quit(44)
		return false
	await process_frame
	var behind: bool = sent.has_method("in_backstab") and bool(sent.in_backstab(op.global_position))
	if op.move_path.size() < 2 and not behind:
		if main.has_method("_start_flank_approach"):
			main._start_flank_approach(sent.global_position)
			await process_frame
	var cone_hits := 0
	for pt in op.move_path:
		if main._sentry_blocks_stealth(pt, op):
			cone_hits += 1
	if cone_hits > 0:
		push_error("SMOKE_WEST_FLANK_PATH_CONE n=%s" % cone_hits)
		quit(44)
		return false
	if op.move_path.size() < 2 and not behind:
		push_error("SMOKE_WEST_FLANK_NO_PATH dest=%s at=%s" % [
			main.grid.world_to_cell(main.flank_dest_world(sent, op)) if main.has_method("flank_dest_world") else "?",
			op.grid_cell()
		])
		quit(44)
		return false
	print("SMOKE_OK_WEST_FLANK_PATH pts=", op.move_path.size(), " hits=", hits)
	op.stop_move()
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	op.global_position = op_home
	main._pending_flank = null
	prompt.refresh_now()
	return true


func _assert_follow_stops_outside_cone(main) -> bool:
	if main.operators.size() < 3 or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_FOLLOW_CONE_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	var sent_c := Vector2i(10, 12)
	var lead_c := Vector2i(18, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(11, 12)
	if main.grid.is_blocked(lead_c.x, lead_c.y):
		lead_c = Vector2i(18, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(1)
		else:
			main.toggle_follow(1)
	if not bool(b.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(2)
		else:
			main.toggle_follow(2)
	if not bool(a.follow_lead) or not bool(b.follow_lead):
		push_error("SMOKE_FOLLOW_CONE_BADGE off a=%s b=%s" % [a.follow_lead, b.follow_lead])
		quit(44)
		return false
	main._tick_squad_follow()
	await process_frame
	for _step in 16:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		main._tick_squad_follow()
		await process_frame
	var hits := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if hits > 0:
		push_error("SMOKE_FOLLOW_ENTERED_CONE n=%s d1=%s d2=%s" % [
			hits, main._follow_dest.get(int(a.op_id), Vector2i(-1, -1)),
			main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
		])
		quit(44)
		return false
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0:
		push_error("SMOKE_FOLLOW_CONE_NO_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1 == d2 or d1 == lead.grid_cell() or d2 == lead.grid_cell():
		push_error("SMOKE_FOLLOW_CONE_STACK d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var op_hits := int(main.follow_operable_hits()) if main.has_method("follow_operable_hits") else 99
	if op_hits > 0:
		push_error("SMOKE_FOLLOW_ON_OPERABLE n=%s d1=%s d2=%s" % [op_hits, d1, d2])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_OUTSIDE_CONE d1=", d1, " d2=", d2)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	main._pending_flank = null
	return true


func _assert_follow_avoids_fire_sector(main) -> bool:
	if main.operators.size() < 2:
		push_error("SMOKE_FOLLOW_SECTOR_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var fol: OperatorUnit = main.operators[1]
	var home_l: Vector2 = lead.global_position
	var home_f: Vector2 = fol.global_position
	var was := bool(fol.follow_lead)
	if main.c2 and not main.c2.sentries.is_empty() and main.grid:
		for s in main.c2.sentries:
			if s and is_instance_valid(s):
				s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6))
				s.facing_deg = 0.0
				if s.has_method("_rebuild_cone"):
					s._rebuild_cone()
	var lead_c := Vector2i(14, 13)
	var fol_c := Vector2i(20, 13)
	if main.grid.is_blocked(lead_c.x, lead_c.y):
		lead_c = Vector2i(14, 14)
	if main.grid.is_blocked(fol_c.x, fol_c.y):
		fol_c = Vector2i(21, 14)
	main._select_op(0)
	lead.stop_move()
	fol.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	fol.global_position = main.grid.cell_to_world_center(fol_c)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(fol.follow_lead):
		main.toggle_follow(1)
	main._tick_squad_follow()
	await process_frame
	if lead.has_method("in_fire_sector") and bool(lead.in_fire_sector(fol.global_position, 0.0, 0.0)):
		if fol.move_path.size() < 2:
			push_error("SMOKE_FOLLOW_STUCK_IN_SECTOR at=%s dest=%s" % [
				fol.grid_cell(), main._follow_dest.get(int(fol.op_id), Vector2i(-1, -1))
			])
			quit(44)
			return false
		var last: Vector2 = fol.move_path[fol.move_path.size() - 1]
		if bool(lead.in_fire_sector(last, 0.0, 0.0)):
			push_error("SMOKE_FOLLOW_EXIT_STILL_SECTOR last=%s dest=%s" % [
				main.grid.world_to_cell(last), main._follow_dest.get(int(fol.op_id), Vector2i(-1, -1))
			])
			quit(44)
			return false
	var sector_hits := 0
	var saw_from := true
	for i in fol.move_path.size():
		var pt: Vector2 = fol.move_path[i]
		if i == 0:
			continue
		if lead.has_method("in_fire_sector") and bool(lead.in_fire_sector(pt, 0.0, 0.0)):
			## In-cone steps are only legal while leaving the cone (prefix). After the
			## first outside cell, further 射界 cells are a fail.
			if not saw_from:
				sector_hits += 1
		elif lead.has_method("in_fire_sector") and not bool(lead.in_fire_sector(pt, 0.0, 0.0)):
			saw_from = false
	if main._follow_dest.has(int(fol.op_id)):
		var dest_w: Vector2 = main.grid.cell_to_world_center(main._follow_dest[int(fol.op_id)])
		if lead.has_method("in_fire_sector") and bool(lead.in_fire_sector(dest_w, 0.0, 0.0)):
			sector_hits += 1
	if sector_hits > 0:
		push_error("SMOKE_FOLLOW_STEPS_SECTOR n=%s dest=%s path=%s" % [
			sector_hits, main._follow_dest.get(int(fol.op_id), Vector2i(-1, -1)), fol.move_path.size()
		])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_AVOID_SECTOR dest=", main._follow_dest.get(int(fol.op_id), Vector2i(-1, -1)), " pts=", fol.move_path.size())
	if bool(fol.follow_lead) != was:
		main.toggle_follow(1)
	lead.stop_move()
	fol.stop_move()
	lead.global_position = home_l
	fol.global_position = home_f
	main._follow_dest.clear()
	return true


func _park_sentries(main, keep = null) -> void:
	if main.c2 == null or main.grid == null:
		return
	var i := 0
	for s in main.c2.sentries:
		if s == null or not is_instance_valid(s) or s == keep:
			continue
		s.global_position = main.grid.cell_to_world_center(Vector2i(32, 6 + i))
		s.facing_deg = 0.0
		_freeze_sentry(s)
		i += 1


func _freeze_sentry(sent) -> void:
	if sent == null:
		return
	sent.route = PackedVector2Array([sent.global_position])
	sent.route_i = 0
	sent.state = 0
	sent.suspicion = 0.0
	sent.frozen = true
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()


func _tick_follow_steps(main, n: int = 20) -> void:
	for _step in n:
		if main.has_method("_tick_command_moves"):
			main._tick_command_moves(0.05)
		if main.has_method("_tick_squad_follow"):
			main._tick_squad_follow(0.05)
		if main.has_method("_follow_selected_cam"):
			main._follow_selected_cam(0.05)
		await process_frame


func _assert_follow_cone_margin(main) -> bool:
	if main.operators.size() < 3 or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_FOLLOW_MARGIN_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var sent_c := Vector2i(10, 12)
	var lead_c := Vector2i(18, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(11, 12)
	if main.grid.is_blocked(lead_c.x, lead_c.y):
		lead_c = Vector2i(18, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	main._tick_squad_follow()
	await _tick_follow_steps(main, 18)
	var hits := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	var rim := int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else 99
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if hits > 0 or rim > 0:
		push_error("SMOKE_FOLLOW_RIM n=%s rim=%s d1=%s d2=%s sent=%s" % [hits, rim, d1, d2, sent.grid_cell() if sent.has_method("grid_cell") else sent.global_position])
		quit(44)
		return false
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_FOLLOW_MARGIN_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if main._sentry_blocks_dest(main.grid.cell_to_world_center(d1)) or main._sentry_blocks_dest(main.grid.cell_to_world_center(d2)):
		push_error("SMOKE_FOLLOW_DEST_IN_PAD d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_CONE_MARGIN d1=", d1, " d2=", d2, " rim=", rim)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	return true


func _assert_west_follow_queue(main) -> bool:
	if main.operators.size() < 3 or main.c2 == null or main.c2.sentries.is_empty():
		push_error("SMOKE_WEST_FOLLOW_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, sent)
	var sent_c := Vector2i(9, 12)
	var lead_c := Vector2i(7, 12)
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(lead_c.x, lead_c.y) or main._cell_is_operable(lead_c):
		lead_c = Vector2i(7, 13)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(9, 13)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	if lead.has_method("_rebuild_cone"):
		lead._rebuild_cone()
	lead.global_position = main.grid.cell_to_world_center(lead_c)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if not bool(a.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(1)
		else:
			main.toggle_follow(1)
	if not bool(b.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(2)
		else:
			main.toggle_follow(2)
	if not bool(a.follow_lead) or not bool(b.follow_lead):
		push_error("SMOKE_WEST_FOLLOW_BADGE a=%s b=%s" % [a.follow_lead, b.follow_lead])
		quit(44)
		return false
	main._tick_squad_follow()
	await _tick_follow_steps(main, 24)
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0:
		push_error("SMOKE_WEST_FOLLOW_NO_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1 == d2 or d1 == lead.grid_cell() or d2 == lead.grid_cell():
		push_error("SMOKE_WEST_FOLLOW_STACK d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	if d1.x > 11 or d2.x > 11:
		push_error("SMOKE_WEST_FOLLOW_WRAP d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	if detour > 6:
		push_error("SMOKE_WEST_FOLLOW_DETOUR n=%s d1=%s d2=%s" % [detour, d1, d2])
		quit(44)
		return false
	var rim := int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else 99
	var cone := int(main.follow_cone_hits()) if main.has_method("follow_cone_hits") else 99
	if rim > 0 or cone > 0:
		push_error("SMOKE_WEST_FOLLOW_CONE cone=%s rim=%s" % [cone, rim])
		quit(44)
		return false
	var spread := float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else 0.0
	if spread < 28.0:
		push_error("SMOKE_WEST_FOLLOW_CROWD spread=%s d1=%s d2=%s" % [spread, d1, d2])
		quit(44)
		return false
	var live := float(main.follow_min_spacing()) if main.has_method("follow_min_spacing") else 0.0
	if live < 24.0:
		push_error("SMOKE_WEST_FOLLOW_LIVE_STACK live=%s" % live)
		quit(44)
		return false
	var cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	if cheb < 1:
		push_error("SMOKE_WEST_FOLLOW_CHEB n=%s d1=%s d2=%s lead=%s" % [cheb, d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if span > 6:
		push_error("SMOKE_WEST_FOLLOW_SPAN n=%s d1=%s d2=%s lead=%s" % [span, d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var idle := int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else 99
	if idle > 0:
		push_error("SMOKE_WEST_FOLLOW_IDLE n=%s a=%s b=%s" % [idle, a.grid_cell(), b.grid_cell()])
		quit(44)
		return false
	if not _dest_is_rear(main, d1, lead) or not _dest_is_rear(main, d2, lead):
		push_error("SMOKE_WEST_FOLLOW_NOT_REAR d1=%s d2=%s lead=%s face=%s" % [
			d1, d2, lead.grid_cell(), lead.facing_deg
		])
		quit(44)
		return false
	var queue_n := int(main.follow_west_queue_hits()) if main.has_method("follow_west_queue_hits") else 99
	if queue_n > 0:
		push_error("SMOKE_WEST_FOLLOW_ALLEY_QUEUE n=%s d1=%s d2=%s lead=%s" % [queue_n, d1, d2, lead.grid_cell()])
		quit(44)
		return false
	print("SMOKE_OK_WEST_FOLLOW_QUEUE d1=", d1, " d2=", d2, " detour=", detour, " spread=", snapped(spread, 0.1), " cheb=", cheb, " span=", span)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	main._pending_flank = null
	return true


func _assert_west_combo_touch(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.operators.size() < 3 or not main.has_method("west_stash"):
		push_error("SMOKE_NO_WEST_COMBO")
		quit(44)
		return false
	var st = main.west_stash()
	if st == null:
		push_error("SMOKE_WEST_COMBO_NO_STASH")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var sent = main.c2.sentries[0] if main.c2 and not main.c2.sentries.is_empty() else null
	if sent == null:
		push_error("SMOKE_WEST_COMBO_NO_SENTRY")
		quit(44)
		return false
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	_park_sentries(main, null)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("cancel_search"):
		lead.cancel_search()
	main.simulate_touch_tap(st.global_position)
	await process_frame
	var gest := str(main._last_touch_gesture)
	if gest != "tap" and gest != "sprint":
		push_error("SMOKE_WEST_COMBO_CRATE_GESTURE got=%s" % gest)
		quit(44)
		return false
	lead.stop_move()
	lead.global_position = st.global_position
	if lead.has_method("cancel_search"):
		lead.cancel_search()
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("开匣")):
		push_error("SMOKE_WEST_COMBO_NO_CRATE caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	if not bool(main.simulate_hotspot("开匣")):
		push_error("SMOKE_WEST_COMBO_CRATE_FIRE")
		quit(44)
		return false
	if lead.has_method("cancel_search"):
		lead.cancel_search()
	var op_c := Vector2i(7, 12)
	var sent_c := Vector2i(9, 12)
	if main.grid.is_blocked(op_c.x, op_c.y) or main._cell_is_operable(op_c):
		op_c = Vector2i(6, 13)
	if main.grid.is_blocked(sent_c.x, sent_c.y):
		sent_c = Vector2i(9, 13)
	lead.stop_move()
	lead.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	_freeze_sentry(sent)
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_WEST_COMBO_NO_FLANK caps=%s" % " ".join(prompt.visible_captions()))
		quit(44)
		return false
	if int(prompt.hotspot_hits_west_operable()) > 0:
		push_error("SMOKE_WEST_COMBO_FLANK_COVERS n=%s" % prompt.hotspot_hits_west_operable())
		quit(44)
		return false
	if not bool(main.simulate_hotspot("绕背")):
		push_error("SMOKE_WEST_COMBO_FLANK_FIRE")
		quit(44)
		return false
	await process_frame
	var behind: bool = sent.has_method("in_backstab") and bool(sent.in_backstab(lead.global_position))
	if lead.move_path.size() < 2 and not behind and main.has_method("_start_flank_approach"):
		main._start_flank_approach(sent.global_position)
		await process_frame
	var cone_hits := 0
	for pt in lead.move_path:
		if main._sentry_blocks_stealth(pt, lead):
			cone_hits += 1
	if cone_hits > 0:
		push_error("SMOKE_WEST_COMBO_FLANK_CONE n=%s" % cone_hits)
		quit(44)
		return false
	if lead.move_path.size() < 2 and not behind:
		push_error("SMOKE_WEST_COMBO_FLANK_NO_PATH at=%s" % lead.grid_cell())
		quit(44)
		return false
	var flank_pts := int(lead.move_path.size())
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("set_facing"):
		lead.set_facing(0.0)
	else:
		lead.facing_deg = 0.0
		if lead.has_method("_rebuild_cone"):
			lead._rebuild_cone()
	var a_c := Vector2i(6, 14)
	var b_c := Vector2i(6, 16)
	if main.grid.is_blocked(a_c.x, a_c.y):
		a_c = Vector2i(5, 14)
	if main.grid.is_blocked(b_c.x, b_c.y):
		b_c = Vector2i(5, 15)
	a.global_position = main.grid.cell_to_world_center(a_c)
	b.global_position = main.grid.cell_to_world_center(b_c)
	main._follow_dest.clear()
	main._stealth_avoid_cache.clear()
	main._stealth_avoid_msec = 0
	if main.has_method("reset_follow_dest_flips"):
		main.reset_follow_dest_flips()
	if not bool(a.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(1)
		else:
			main.toggle_follow(1)
	if not bool(b.follow_lead):
		if main.has_method("simulate_follow_badge"):
			main.simulate_follow_badge(2)
		else:
			main.toggle_follow(2)
	main._tick_squad_follow()
	await _tick_follow_steps(main, 20)
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	var detour := int(main.follow_max_detour()) if main.has_method("follow_max_detour") else 99
	var rim := int(main.follow_rim_hits()) if main.has_method("follow_rim_hits") else 99
	if d1.x < 0 or d2.x < 0 or d1 == d2:
		push_error("SMOKE_WEST_COMBO_FOLLOW_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if detour > 6 or rim > 0:
		push_error("SMOKE_WEST_COMBO_FOLLOW_PATH detour=%s rim=%s d1=%s d2=%s" % [detour, rim, d1, d2])
		quit(44)
		return false
	var combo_cheb := int(main.follow_min_chebyshev()) if main.has_method("follow_min_chebyshev") else 0
	var combo_idle := int(main.follow_idle_waits()) if main.has_method("follow_idle_waits") else 99
	var combo_spread := float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else 0.0
	var combo_span := int(main.follow_west_lead_span()) if main.has_method("follow_west_lead_span") else 99
	if combo_cheb < 1 or combo_idle > 0 or combo_spread < 28.0 or combo_span > 6:
		push_error("SMOKE_WEST_COMBO_CROWD cheb=%s idle=%s spread=%s span=%s d1=%s d2=%s" % [
			combo_cheb, combo_idle, combo_spread, combo_span, d1, d2
		])
		quit(44)
		return false
	print(
		"SMOKE_OK_WEST_COMBO_TOUCH crate=", main.grid.world_to_cell(st.global_position),
		" flank_pts=", flank_pts,
		" d1=", d1, " d2=", d2, " detour=", detour, " cheb=", combo_cheb, " span=", combo_span
	)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	if lead.has_method("cancel_search"):
		lead.cancel_search()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	main._follow_dest.clear()
	main._pending_flank = null
	prompt.refresh_now()
	return true


func _assert_touch_no_body_select(main) -> bool:
	if main.operators.size() < 2 or main.grid == null:
		push_error("SMOKE_BODY_SELECT_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var other: OperatorUnit = main.operators[1]
	var homes: Array[Vector2] = [lead.global_position, other.global_position]
	var clear: Vector2 = _empty_probe_world(main)
	main._select_op(0)
	lead.stop_move()
	other.stop_move()
	lead.global_position = clear
	other.global_position = clear + Vector2(32, 0)
	if main.grid.is_blocked(main.grid.world_to_cell(other.global_position).x, main.grid.world_to_cell(other.global_position).y):
		other.global_position = clear + Vector2(0, 32)
	main.simulate_touch_tap(other.global_position)
	await process_frame
	if main.selected != lead:
		push_error("SMOKE_TOUCH_BODY_SELECT got=%s" % (main.selected.display_name if main.selected else "null"))
		quit(44)
		return false
	print("SMOKE_OK_TOUCH_NO_BODY_SELECT")
	var slot = null
	if main.cover_slots.size() > 0:
		slot = main.cover_slots[0]
	if slot != null:
		var pad: Vector2i = main.grid.world_to_cell(slot.global_position)
		var side := Vector2i(pad.x + 1, pad.y)
		if main.grid.is_blocked(side.x, side.y):
			side = Vector2i(pad.x, pad.y + 1)
		if not main.grid.is_blocked(side.x, side.y):
			lead.slot = null
			main.simulate_touch_tap(main.grid.cell_to_world_center(side))
			await process_frame
			if lead.slot == slot:
				push_error("SMOKE_TOUCH_COVER_STEAL cell=%s pad=%s" % [side, pad])
				quit(44)
				return false
			print("SMOKE_OK_TOUCH_COVER_SAME_CELL")
	lead.stop_move()
	other.stop_move()
	lead.global_position = homes[0]
	other.global_position = homes[1]
	return true


func _assert_flank_clears_west(main) -> bool:
	var prompt = main.c2.prompt if main.c2 else null
	if prompt == null or main.c2.sentries.is_empty() or main.operators.is_empty():
		push_error("SMOKE_NO_WEST_FLANK")
		quit(44)
		return false
	var op: OperatorUnit = main.operators[0]
	var sent = main.c2.sentries[0]
	var op_home: Vector2 = op.global_position
	var sent_home: Vector2 = sent.global_position
	var sent_face: float = float(sent.facing_deg)
	var op_c := Vector2i(7, 12)
	var sent_c := Vector2i(9, 12)
	if main.grid:
		if main.grid.is_blocked(op_c.x, op_c.y):
			op_c = Vector2i(6, 13)
		if main.grid.is_blocked(sent_c.x, sent_c.y):
			sent_c = Vector2i(9, 13)
	op.stop_move()
	main._select_op(0)
	op.global_position = main.grid.cell_to_world_center(op_c)
	sent.global_position = main.grid.cell_to_world_center(sent_c)
	sent.facing_deg = 0.0
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	prompt.refresh_now()
	await process_frame
	if not bool(prompt.has_caption("绕背")):
		push_error("SMOKE_WEST_NO_FLANK caps=%s op=%s sent=%s" % [
			" ".join(prompt.visible_captions()), op_c, sent_c
		])
		quit(44)
		return false
	if bool(prompt.has_caption("割喉")):
		push_error("SMOKE_WEST_FLANK_IS_KNIFE")
		quit(44)
		return false
	var hits := int(prompt.hotspot_hits_west_operable()) if prompt.has_method("hotspot_hits_west_operable") else 99
	if hits > 0:
		push_error("SMOKE_FLANK_COVERS_WEST n=%s rects=%s" % [hits, prompt.visible_hotspot_rects()])
		quit(44)
		return false
	print("SMOKE_OK_FLANK_CLEARS_WEST hits=", hits, " caps=", " ".join(prompt.visible_captions()))
	sent.global_position = sent_home
	sent.facing_deg = sent_face
	sent.frozen = false
	if sent.has_method("_rebuild_cone"):
		sent._rebuild_cone()
	op.global_position = op_home
	prompt.refresh_now()
	return true


func _assert_follow_spacing(main) -> bool:
	if main.operators.size() < 3 or not main.has_method("toggle_follow"):
		push_error("SMOKE_FOLLOW_SPREAD_NO_OPS")
		quit(44)
		return false
	var lead: OperatorUnit = main.operators[0]
	var a: OperatorUnit = main.operators[1]
	var b: OperatorUnit = main.operators[2]
	var homes: Array[Vector2] = [lead.global_position, a.global_position, b.global_position]
	var flags: Array[bool] = [bool(a.follow_lead), bool(b.follow_lead)]
	var spine := Vector2i(13, 13)
	if main.grid and main.grid.is_blocked(spine.x, spine.y):
		spine = Vector2i(14, 13)
	var world: Vector2 = main.grid.cell_to_world_center(spine)
	main._select_op(0)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.facing_deg = 0.0
	lead.global_position = world
	a.global_position = world + Vector2(0, 16)
	b.global_position = world + Vector2(0, -16)
	if not bool(a.follow_lead):
		main.toggle_follow(1)
	if not bool(b.follow_lead):
		main.toggle_follow(2)
	if not bool(a.follow_lead) or not bool(b.follow_lead):
		push_error("SMOKE_FOLLOW_SPREAD_OFF")
		quit(44)
		return false
	main._tick_squad_follow()
	await process_frame
	var d1: Vector2i = main._follow_dest.get(int(a.op_id), Vector2i(-1, -1))
	var d2: Vector2i = main._follow_dest.get(int(b.op_id), Vector2i(-1, -1))
	if d1.x < 0 or d2.x < 0:
		push_error("SMOKE_FOLLOW_NO_DEST d1=%s d2=%s" % [d1, d2])
		quit(44)
		return false
	if d1 == d2:
		push_error("SMOKE_FOLLOW_SAME_DEST %s" % str(d1))
		quit(44)
		return false
	if d1 == lead.grid_cell() or d2 == lead.grid_cell():
		push_error("SMOKE_FOLLOW_ON_LEAD d1=%s d2=%s lead=%s" % [d1, d2, lead.grid_cell()])
		quit(44)
		return false
	var spread := float(main.follow_dest_min_spacing()) if main.has_method("follow_dest_min_spacing") else 0.0
	if spread < 40.0:
		push_error("SMOKE_FOLLOW_DEST_TIGHT spread=%s d1=%s d2=%s" % [spread, d1, d2])
		quit(44)
		return false
	print("SMOKE_OK_FOLLOW_SPACING spread=", snapped(spread, 0.1), " d1=", d1, " d2=", d2)
	if bool(a.follow_lead) != flags[0]:
		main.toggle_follow(1)
	if bool(b.follow_lead) != flags[1]:
		main.toggle_follow(2)
	lead.stop_move()
	a.stop_move()
	b.stop_move()
	lead.global_position = homes[0]
	a.global_position = homes[1]
	b.global_position = homes[2]
	main._follow_dest.clear()
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
	main.raid_force_alarm()
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
	var cfx: Variant = load("res://scripts/fx/combat_fx.gd")
	if cfx == null or not (cfx as GDScript).has_method("spawn_pop"):
		push_error("SMOKE_NO_SPAWN_POP")
		quit(53)
		return false
	if not (cfx as GDScript).has_method("death_stain"):
		push_error("SMOKE_NO_DEATH_STAIN")
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
	main.raid_force_alarm()
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
	if not main.has_method("watch_census_text") or str(main.watch_census_text()).find("员") < 0:
		push_error("SMOKE_NO_WATCH_CENSUS %s" % (main.watch_census_text() if main.has_method("watch_census_text") else "no_api"))
		quit(53)
		return false
	if chip.find("员") < 0:
		push_error("SMOKE_CHIP_NO_CENSUS %s" % chip)
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
	if not probe.has_method("set_last_runner") or not probe.has_method("last_runner_highlighted"):
		probe.queue_free()
		flank.queue_free()
		sneak.queue_free()
		push_error("SMOKE_NO_LAST_RUNNER")
		quit(55)
		return false
	probe.activate()
	probe.set_last_runner(true)
	if not bool(probe.last_runner_highlighted()):
		probe.queue_free()
		flank.queue_free()
		sneak.queue_free()
		push_error("SMOKE_LAST_RUNNER_OFF")
		quit(55)
		return false
	probe.queue_free()
	flank.queue_free()
	sneak.queue_free()
	print("SMOKE_OK_ANIM walk_bob_hook weapon=1 last_runner=1")
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	if not main.operators[0].has_method("cover_idle_planted") or not bool(main.operators[0].cover_idle_planted()):
		push_error("SMOKE_COVER_NOT_PLANTED")
		quit(55)
		return false
	main._on_clear_pressed()
	if main.operators[0].cover_idle_planted():
		push_error("SMOKE_UNDEPLOYED_STILL_PLANTED")
		quit(55)
		return false
	print("SMOKE_OK_COVER_IDLE")
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
	for m in ["_landmark_yard", "_landmark_warehouse", "_landmark_pump", "_landmark_railcut", "_landmark_depot", "_landmark_radio"]:
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
		"Radio dish", "Guy wire", "Morse hut", "dish hall",
		"Lighthouse mast", "Dish array", "Echo hall phosphor",
		"Duty board", "Shift roster", "Valve log",
		"yard_crate_iso",
		"ammo_can_iso",
		"gun_case_iso",
		"sandbag_iso",
		"lamp_post_iso",
		"fence_section_iso",
		"rations_crate_iso",
		"oil_drum_iso",
		"wooden_barrel_iso",
		"field_radio_iso",
		"jerry_can_iso",
		"spare_tire_iso",
		"Timetable slate", "Fuel ticket", "Call log",
		"Rain barrel", "Spare dish", "Sandbag row",
		"Oil stain", "Hose coil", "Switch box", "Drip pan",
		"Courtyard well", "Conveyor rollers", "Pressure gauge",
		"Milepost", "Fill nozzle", "Horn speaker",
		"Wagon ruts", "horse dung",
		"Coal dust",
		"jamb rust", "Escape mouth lamplight",
		"Sodium lamp cages", "Oil vapour stains", "Lighthouse lantern panes",
		"Horseshoe", "ZF crate",
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
	if sky_src.find("Steam wisps") < 0 or sky_src.find("sodium") < 0 or sky_src.find("underglow") < 0 or sky_src.find("dish sweep") < 0:
		push_error("SMOKE_PROPS_SKY")
		quit(51)
		return false
	if (
		sky_src.find("Window flicker") < 0
		or sky_src.find("flickering sodium") < 0
		or sky_src.find("steam puff") < 0
		or sky_src.find("gauge blink") < 0
		or sky_src.find("_draw_contrast_wash") < 0
		or sky_src.find("Morse blink") < 0
		or sky_src.find("Phosphor motes") < 0
		or sky_src.find("Pump drizzle") < 0
		or sky_src.find("Diesel specks") < 0
		or sky_src.find("Dust motes") < 0
		or sky_src.find("Starfield") < 0
		or sky_src.find("Horizon wash") < 0
		or sky_src.find("Distant lights") < 0
		or sky_src.find("Night clouds") < 0
	):
		push_error("SMOKE_PROPS_SKY_MOTION")
		quit(51)
		return false
	if md.z_index > 1:
		push_error("SMOKE_PROPS_Z %s" % md.z_index)
		quit(51)
		return false
	print("SMOKE_OK_PROPS landmarks=6 sig=", sig)
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
	var rd: LevelDef = LevelDef.by_id("radio")
	if rd.first_route_delay("sneak") < 3.0 or rd.delay_for_actor(5) < 5.0:
		push_error("SMOKE_RADIO_BEAT_DELAY sneak=%s echo=%s" % [rd.first_route_delay("sneak"), rd.delay_for_actor(5)])
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
	if zone_tag == null or str(zone_tag.text).find("伏击") < 0:
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
	if rd.spawn_teaching.is_empty() or str(rd.spawn_teaching[0]).find("5.2") < 0:
		push_error("SMOKE_RADIO_SPAWN_TEACH %s" % str(rd.spawn_teaching))
		quit(52)
		return false
	if rd.spawn_teaching.size() < 2 or str(rd.spawn_teaching[1]).find("第二层") < 0:
		push_error("SMOKE_RADIO_SECOND_TEACH %s" % str(rd.spawn_teaching))
		quit(52)
		return false
	if not yard.has_method("second_trap_text") or str(yard.second_trap_text()).find("东廊") < 0:
		push_error("SMOKE_YARD_SECOND_TRAP %s" % (yard.second_trap_text() if yard.has_method("second_trap_text") else "no_api"))
		quit(52)
		return false
	var wh_trap := str(wh.second_trap_text())
	if wh_trap.find("第二层") < 0 or (wh_trap.find("黄区") < 0 and wh_trap.find("入伏") < 0):
		push_error("SMOKE_WAREHOUSE_TRAP_NOT_HOLD %s" % wh_trap)
		quit(52)
		return false
	if str(wh.spawn_teaching[1] if wh.spawn_teaching.size() > 1 else "").find("黄区") < 0:
		push_error("SMOKE_WAREHOUSE_SECOND_TEACH %s" % str(wh.spawn_teaching))
		quit(52)
		return false
	if main.second_callout != null and is_instance_valid(main.second_callout) and main.second_callout.visible:
		push_error("SMOKE_DUP_SECOND_CALLOUT")
		quit(52)
		return false
	if not main.has_method("trap_path_visible") or not bool(main.trap_path_visible()):
		push_error("SMOKE_NO_TRAP_PATH")
		quit(52)
		return false
	var trap_tag = main.trap_path.get_node_or_null("Tag")
	if trap_tag == null or str(trap_tag.text).find("第二层") < 0:
		push_error("SMOKE_TRAP_PATH_TAG %s" % (trap_tag.text if trap_tag else "null"))
		quit(52)
		return false
	for lid in ["yard", "warehouse", "pump", "railcut", "depot", "radio"]:
		var trap_def: LevelDef = LevelDef.by_id(lid)
		if not trap_def.has_method("second_trap_route") or str(trap_def.second_trap_route()) == "":
			push_error("SMOKE_NO_SECOND_TRAP_ROUTE %s" % lid)
			quit(52)
			return false
	if str(LevelDef.by_id("pump").second_trap_route()) != "alt":
		push_error("SMOKE_PUMP_TRAP_ROUTE %s" % LevelDef.by_id("pump").second_trap_route())
		quit(52)
		return false
	if str(LevelDef.by_id("depot").second_trap_route()) != "sneak":
		push_error("SMOKE_DEPOT_TRAP_ROUTE %s" % LevelDef.by_id("depot").second_trap_route())
		quit(52)
		return false
	if str(LevelDef.by_id("radio").second_trap_route()) != "sneak":
		push_error("SMOKE_RADIO_TRAP_ROUTE %s" % LevelDef.by_id("radio").second_trap_route())
		quit(52)
		return false
	if str(LevelDef.campaign_recap_body()).find("电台") < 0 or str(LevelDef.campaign_chain_names()).find("油库") < 0:
		push_error("SMOKE_NO_CAMPAIGN_RECAP")
		quit(52)
		return false
	if main.trap_callout != null and is_instance_valid(main.trap_callout) and main.trap_callout.visible:
		push_error("SMOKE_DUP_TRAP_CALLOUT")
		quit(52)
		return false
	if main.spawn_teach_label == null or not main.spawn_teach_label.visible:
		push_error("SMOKE_NO_SPAWN_TEACH_HUD")
		quit(52)
		return false
	if str(main.spawn_teach_label.text).find("侧翼") < 0:
		push_error("SMOKE_SPAWN_TEACH_NOT_BEAT %s" % main.spawn_teach_label.text)
		quit(52)
		return false
	if str(main.spawn_teach_label.text).find("第二层") >= 0:
		push_error("SMOKE_SPAWN_TEACH_STILL_DOUBLE %s" % main.spawn_teach_label.text)
		quit(52)
		return false
	if main.has_method("setup_teaching_layers"):
		var layers: Dictionary = main.setup_teaching_layers()
		if bool(layers.get("tut", false)) or bool(layers.get("beat", false)) or bool(layers.get("second", false)):
			push_error("SMOKE_DUP_TEACH_LAYERS %s" % str(layers))
			quit(52)
			return false
	print("SMOKE_OK_TEACHING_SINGLE")
	if not main.has_method("_intel_flash_color"):
		push_error("SMOKE_NO_INTEL_COLOR")
		quit(52)
		return false
	if not main.has_method("_play_intel_path_ghost"):
		push_error("SMOKE_NO_INTEL_GHOST_API")
		quit(52)
		return false
	for lid in ["yard", "warehouse", "pump", "railcut", "depot", "radio"]:
		var def: LevelDef = LevelDef.by_id(lid)
		var note := ""
		if def.has_method("teaching_note_for"):
			if lid == "depot" or lid == "radio":
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
	for lid in ["yard", "warehouse", "pump", "railcut", "depot", "radio"]:
		var pages: Array = TutorialOverlay.pages_for(lid)
		var last: Dictionary = pages[pages.size() - 1]
		if str(last.get("body", "")).find("陷阱路线") < 0:
			push_error("SMOKE_TUTORIAL_TRAP %s" % lid)
			quit(52)
			return false
		if str(last.get("body", "")).find("虚线") < 0:
			push_error("SMOKE_TUTORIAL_DASH %s" % lid)
			quit(52)
			return false
	if not _assert_payoff_copy(main):
		return false
	if not _assert_first_visit_tutorial(main):
		return false
	if not _assert_night_handoff(main):
		return false
	print("SMOKE_OK_TEACHING beats=6 timeline=1 path=1 spawn_teach=1 overlay=1")
	return true


func _assert_iteration_slice(main) -> bool:
	## Fast gates for this iteration's player-facing increments.
	if not main.has_method("watch_pending_breathing") or not bool(main.watch_pending_breathing()):
		push_error("SMOKE_NO_PENDING_BREATH")
		quit(71)
		return false
	print("SMOKE_OK_PENDING_BREATH")
	if not ResourceLoader.exists("res://scripts/fx/spawn_ghost.gd"):
		push_error("SMOKE_NO_SPAWN_GHOST_SCRIPT")
		quit(71)
		return false
	if not main.has_method("setup_spawn_ghosts_visible") or not bool(main.setup_spawn_ghosts_visible()):
		push_error("SMOKE_NO_SPAWN_GHOSTS")
		quit(71)
		return false
	var n_ghost := int(main.setup_spawn_ghost_count()) if main.has_method("setup_spawn_ghost_count") else 0
	if n_ghost < 3:
		push_error("SMOKE_SPAWN_GHOST_COUNT %s" % n_ghost)
		quit(71)
		return false
	var host = main.spawn_ghost_host
	if host == null:
		push_error("SMOKE_SPAWN_GHOST_HOST")
		quit(71)
		return false
	var g0 = host.get_child(0)
	var tag = g0.get_node_or_null("Tag") if g0 else null
	if tag == null or str(tag.text).find("敌") < 0 or str(tag.text).find("s") < 0:
		push_error("SMOKE_SPAWN_GHOST_TAG %s" % (tag.text if tag else "null"))
		quit(71)
		return false
	print("SMOKE_OK_SPAWN_GHOSTS n=", n_ghost)
	var cfx: Variant = load("res://scripts/fx/combat_fx.gd")
	if cfx == null or not (cfx as GDScript).has_method("hit_tick"):
		push_error("SMOKE_NO_HIT_TICK")
		quit(71)
		return false
	if main.operators.is_empty():
		push_error("SMOKE_HIT_TICK_NO_OP")
		quit(71)
		return false
	var tick_host: Node2D = main.entities if main.entities else main.operators[0]
	(cfx as GDScript).hit_tick(tick_host, Vector2(80, 80), 34.0, Color(1.0, 0.86, 0.38), false)
	var saw_tick := false
	if tick_host:
		for c in tick_host.get_children():
			if str(c.name).begins_with("CfxTick"):
				saw_tick = true
				var amt = c.get_node_or_null("Amt")
				if amt == null or str(amt.text).find("-34") < 0:
					push_error("SMOKE_HIT_TICK_TEXT %s" % (amt.text if amt else "null"))
					quit(71)
					return false
				break
	if not saw_tick:
		push_error("SMOKE_HIT_TICK_MISSING")
		quit(71)
		return false
	print("SMOKE_OK_HIT_TICK")
	var dry_op: OperatorUnit = main.operators[0]
	var ammo0: int = int(dry_op.ammo)
	var vis0: bool = bool(dry_op.visible)
	dry_op.visible = true
	dry_op.apply_weapon("rifle", true)
	dry_op.ammo = 0
	dry_op.melee = false
	dry_op._refresh_tag()
	if not dry_op.has_method("dry_gun_visible") or not bool(dry_op.dry_gun_visible()):
		push_error("SMOKE_NO_DRY_GUN")
		quit(71)
		return false
	if str(dry_op.tag.text).find("空") < 0:
		push_error("SMOKE_DRY_GUN_TAG %s" % dry_op.tag.text)
		quit(71)
		return false
	dry_op.apply_weapon("rifle", true)
	dry_op.ammo = maxi(ammo0, dry_op.start_ammo)
	dry_op.visible = vis0
	dry_op._refresh_tag()
	if vis0 and bool(dry_op.dry_gun_visible()):
		push_error("SMOKE_DRY_GUN_STUCK")
		quit(71)
		return false
	print("SMOKE_OK_DRY_GUN")
	if str(PayoffCopy.bark_text("contact", "灰狼")).find("灰狼：接触") < 0:
		push_error("SMOKE_BARK_CONTACT %s" % PayoffCopy.bark_text("contact", "灰狼"))
		quit(71)
		return false
	if str(PayoffCopy.bark_text("empty", "铁砧")).find("弹尽") < 0:
		push_error("SMOKE_BARK_EMPTY")
		quit(71)
		return false
	main.operators[0].visible = true
	if not main.has_method("_operator_bark"):
		push_error("SMOKE_NO_BARK_API")
		quit(71)
		return false
	main._operator_bark(main.operators[0], "contact")
	if not main.operators[0].has_method("bark_visible") or not bool(main.operators[0].bark_visible()):
		push_error("SMOKE_NO_BARK_LABEL")
		quit(71)
		return false
	if str(main.operators[0].bark_lab.text).find("接触") < 0:
		push_error("SMOKE_BARK_LABEL %s" % main.operators[0].bark_lab.text)
		quit(71)
		return false
	print("SMOKE_OK_BARK")
	var gs_stats = root.get_node_or_null("GameSettings")
	if gs_stats == null or not gs_stats.has_method("best_loops"):
		push_error("SMOKE_NO_BEST_LOOPS")
		quit(71)
		return false
	if not gs_stats.has_method("record_clear_stats"):
		push_error("SMOKE_NO_CLEAR_STATS")
		quit(71)
		return false
	gs_stats.record_clear_stats("yard", 3, false)
	if int(gs_stats.best_loops("yard")) != 3:
		push_error("SMOKE_BEST_LOOPS %s" % gs_stats.best_loops("yard"))
		quit(71)
		return false
	gs_stats.record_clear_stats("yard", 2, false)
	if int(gs_stats.best_loops("yard")) != 2:
		push_error("SMOKE_BEST_LOOPS_MIN %s" % gs_stats.best_loops("yard"))
		quit(71)
		return false
	var entries2: Array = gs_stats.mission_entries()
	if int(entries2[0].get("loops", 0)) != 2:
		push_error("SMOKE_ENTRY_LOOPS %s" % str(entries2[0]))
		quit(71)
		return false
	print("SMOKE_OK_BEST_LOOPS")
	if not main.has_method("replay_has_cone") or not main.has_method("_add_replay_marker"):
		push_error("SMOKE_NO_REPLAY_CONE_API")
		quit(71)
		return false
	if main.replay_layer == null:
		push_error("SMOKE_NO_REPLAY_LAYER")
		quit(71)
		return false
	main._clear_replay_layer()
	main._add_replay_marker(Vector2(80, 80), Color(0.52, 0.72, 0.92), "队员1", true, false, 0.0, true, false)
	if not bool(main.replay_has_cone()):
		push_error("SMOKE_REPLAY_NO_CONE")
		quit(71)
		return false
	main._add_replay_marker(Vector2(120, 80), Color(0.75, 0.22, 0.2), "敌1", false, false, 90.0, false, true)
	if not bool(main.replay_has_kill_stamp()):
		push_error("SMOKE_REPLAY_NO_STAMP")
		quit(71)
		return false
	main._clear_replay_layer()
	print("SMOKE_OK_REPLAY_CONE")
	if not main.has_method("_build_plan_ghosts") or not main.has_method("plan_ghost_count"):
		push_error("SMOKE_NO_PLAN_GHOST_API")
		quit(71)
		return false
	main._on_clear_pressed()
	main.last_plan.clear()
	main.last_plan.deployments.append({
		"op_id": 1,
		"slot_id": main.cover_slots[0].slot_id,
		"facing": 0.0,
		"fire_mode": 0,
		"has_ammo_pack": false,
	})
	main._build_plan_ghosts()
	if int(main.plan_ghost_count()) < 1:
		push_error("SMOKE_PLAN_GHOST_COUNT %s" % main.plan_ghost_count())
		quit(71)
		return false
	var pg = main.plan_ghost_host.get_child(0)
	var ptag = pg.get_node_or_null("Tag") if pg else null
	if ptag == null or str(ptag.text).find("上轮") < 0:
		push_error("SMOKE_PLAN_GHOST_TAG %s" % (ptag.text if ptag else "null"))
		quit(71)
		return false
	main.last_plan.clear()
	main._build_plan_ghosts()
	print("SMOKE_OK_PLAN_GHOST")
	var yard_def: LevelDef = LevelDef.by_id("yard")
	if not yard_def.has_method("suggested_cover_name"):
		push_error("SMOKE_NO_SUGGESTED_COVER")
		quit(71)
		return false
	if str(yard_def.suggested_cover_name(1)).find("东箱") < 0:
		push_error("SMOKE_MG_PAD %s" % yard_def.suggested_cover_name(1))
		quit(71)
		return false
	main._select_op(1)
	main._update_cover_previews()
	var hinted := false
	for s in main.cover_slots:
		if s.has_method("role_hint_on") and bool(s.role_hint_on()):
			hinted = true
			if str(s.label_text).find("东箱") < 0:
				push_error("SMOKE_HINT_WRONG_PAD %s" % s.label_text)
				quit(71)
				return false
			break
	if not hinted:
		push_error("SMOKE_NO_ROLE_HINT")
		quit(71)
		return false
	print("SMOKE_OK_ROLE_HINT")
	if not main.has_method("door_slam_dust_active"):
		push_error("SMOKE_NO_DOOR_SLAM_API")
		quit(71)
		return false
	var door_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if door_src.find("land_dust(door_marker") < 0:
		push_error("SMOKE_DOOR_NO_DUST")
		quit(71)
		return false
	print("SMOKE_OK_DOOR_SLAM")
	var barrel := ExplosiveBarrel.new()
	var vis := Polygon2D.new()
	vis.name = "Visual"
	barrel.add_child(vis)
	if not barrel.has_method("fuse_hot") or not barrel.has_method("set_fuse_hot"):
		barrel.free()
		push_error("SMOKE_NO_FUSE_API")
		quit(71)
		return false
	barrel.set_fuse_hot(true)
	if not bool(barrel.fuse_hot()):
		barrel.free()
		push_error("SMOKE_FUSE_NOT_HOT")
		quit(71)
		return false
	if barrel.get_node_or_null("FuseSpark") == null or not barrel.get_node_or_null("FuseSpark").visible:
		barrel.free()
		push_error("SMOKE_NO_FUSE_SPARK")
		quit(71)
		return false
	barrel.free()
	print("SMOKE_OK_BARREL_FUSE")
	if not main.has_method("watch_metronome_visible"):
		push_error("SMOKE_NO_METRONOME_API")
		quit(71)
		return false
	main._ensure_watch_cinema()
	var metro = main._watch_letterbox.get_node_or_null("Metronome") if main._watch_letterbox else null
	if metro == null or metro.get_child_count() < 8:
		push_error("SMOKE_NO_METRONOME_PIPS")
		quit(71)
		return false
	print("SMOKE_OK_METRONOME")
	if main.sfx == null or not main.sfx.has_cue("tension"):
		push_error("SMOKE_NO_TENSION_CUE")
		quit(71)
		return false
	main._sfx("tension")
	if str(main.sfx.last_cue) != "tension":
		push_error("SMOKE_TENSION_NO_PLAY %s" % main.sfx.last_cue)
		quit(71)
		return false
	print("SMOKE_OK_TENSION")
	var cfx2: Variant = load("res://scripts/fx/combat_fx.gd")
	if cfx2 == null or not (cfx2 as GDScript).has_method("kill_stamp"):
		push_error("SMOKE_NO_KILL_STAMP")
		quit(71)
		return false
	(cfx2 as GDScript).kill_stamp(main.entities, Vector2(90, 90), 3, Color(1.0, 0.82, 0.32))
	var saw_stamp := false
	for c in main.entities.get_children():
		if str(c.name).begins_with("CfxStamp"):
			saw_stamp = true
			var st = c.get_node_or_null("Tag")
			if st == null or str(st.text).find("敌3") < 0:
				push_error("SMOKE_KILL_STAMP_TEXT %s" % (st.text if st else "null"))
				quit(71)
				return false
			break
	if not saw_stamp:
		push_error("SMOKE_KILL_STAMP_MISSING")
		quit(71)
		return false
	print("SMOKE_OK_KILL_STAMP")
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	if not main.operators[0].has_method("facing_compass_visible"):
		push_error("SMOKE_NO_COMPASS_API")
		quit(71)
		return false
	if not bool(main.operators[0].facing_compass_visible()):
		push_error("SMOKE_COMPASS_HIDDEN")
		quit(71)
		return false
	if main.operators[0].get_node_or_null("CompassRose") == null:
		push_error("SMOKE_NO_COMPASS_NODE")
		quit(71)
		return false
	var rose_cap = main.operators[0].get_node_or_null("CompassRose/FacingCap")
	if rose_cap == null or str(rose_cap.text).find("射界") < 0:
		push_error("SMOKE_COMPASS_NO_FACING_CAP")
		quit(71)
		return false
	var face_chip = main.operators[0].get_node_or_null("FaceChip") as Label
	var face_txt := str(face_chip.text) if face_chip else ""
	var plan_txt := str(main.plan_readout.text) if main.plan_readout else ""
	if face_txt.find("射界") < 0:
		push_error("SMOKE_FACE_CHIP %s" % face_txt)
		quit(71)
		return false
	if plan_txt.find("射界朝") < 0 or plan_txt.find("保护朝") < 0:
		push_error("SMOKE_FACING_COPY %s" % plan_txt)
		quit(71)
		return false
	main._on_clear_pressed()
	print("SMOKE_OK_COMPASS")
	print("SMOKE_OK_FACING_WORDS")
	gs_stats.record_clear_stats("warehouse", 1, true)
	if not bool(gs_stats.is_perfect("warehouse")):
		push_error("SMOKE_NO_PERFECT_FLAG")
		quit(71)
		return false
	var pe: Array = gs_stats.mission_entries()
	if pe.size() < 2 or not bool(pe[1].get("perfect", false)):
		push_error("SMOKE_ENTRY_NOT_PERFECT")
		quit(71)
		return false
	var win_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if win_src.find("完美封锁") < 0:
		push_error("SMOKE_NO_PERFECT_COPY")
		quit(71)
		return false
	print("SMOKE_OK_PERFECT")
	if not main.has_method("_flash_spawn_cell"):
		push_error("SMOKE_NO_SPAWN_FLASH")
		quit(71)
		return false
	main._flash_spawn_cell(Vector2(100, 100))
	var saw_flash := false
	for c in main.entities.get_children():
		if str(c.name) == "SpawnFlash":
			saw_flash = true
			break
	if not saw_flash:
		push_error("SMOKE_SPAWN_FLASH_MISSING")
		quit(71)
		return false
	print("SMOKE_OK_WAVE_PUNCH")
	main._ensure_watch_cinema()
	if not main.has_method("watch_clock_text"):
		push_error("SMOKE_NO_WATCH_CLOCK")
		quit(71)
		return false
	main.phase = main.Phase.WATCHING
	main._refresh_watch_clock()
	if str(main.watch_clock_text()).find("t=") < 0:
		push_error("SMOKE_CLOCK_TEXT %s" % main.watch_clock_text())
		quit(71)
		return false
	main.phase = main.Phase.SETUP
	print("SMOKE_OK_WATCH_CLOCK")
	main._select_op(0)
	main._deploy_selected_to(main.cover_slots[0], false)
	var hold_op: OperatorUnit = main.operators[0]
	hold_op.fire_mode = OperatorUnit.FireMode.HOLD_FOR_AMBUSH
	hold_op.fire_permitted = false
	hold_op._rebuild_cone()
	if not hold_op.has_method("hold_cone_pulsing") or not bool(hold_op.hold_cone_pulsing()):
		push_error("SMOKE_HOLD_CONE_OFF")
		quit(71)
		return false
	hold_op.fire_mode = OperatorUnit.FireMode.ENGAGE_ON_SIGHT
	hold_op.fire_permitted = true
	hold_op._rebuild_cone()
	main._on_clear_pressed()
	print("SMOKE_OK_HOLD_PULSE")
	var cfx3: Variant = load("res://scripts/fx/combat_fx.gd")
	if cfx3 == null or not (cfx3 as GDScript).has_method("loot_streak"):
		push_error("SMOKE_NO_LOOT_STREAK")
		quit(71)
		return false
	(cfx3 as GDScript).loot_streak(main.entities, Vector2(40, 40), Vector2(90, 40))
	var saw_streak := false
	for c in main.entities.get_children():
		if str(c.name).begins_with("CfxLootStreak"):
			saw_streak = true
			break
	if not saw_streak:
		push_error("SMOKE_LOOT_STREAK_MISSING")
		quit(71)
		return false
	print("SMOKE_OK_LOOT_STREAK")
	var boot: EnemyRunner = main._make_enemy(91)
	main.entities.add_child(boot)
	boot.setup(91, PackedVector2Array([Vector2(80, 80), Vector2(160, 80)]), main.grid, 0, "main")
	boot.activate()
	if not boot.has_method("_drop_boot_print"):
		boot.queue_free()
		push_error("SMOKE_NO_BOOT_PRINT")
		quit(71)
		return false
	boot._drop_boot_print()
	if not bool(boot.boot_print_dropped()):
		boot.queue_free()
		push_error("SMOKE_BOOT_PRINT_MISSING")
		quit(71)
		return false
	boot.queue_free()
	print("SMOKE_OK_BOOT_PRINT")
	return true


func _assert_night_handoff(main) -> bool:
	var body := str(LevelDef.handoff_body("yard", "warehouse"))
	if body.find("院子已静") < 0 or body.find("仓道") < 0 or body.find("高光") < 0:
		push_error("SMOKE_HANDOFF_YARD_BODY %s" % body)
		quit(52)
		return false
	var pump_body := str(LevelDef.handoff_body("warehouse", "pump"))
	if pump_body.find("泵站") < 0 or pump_body.find("仓道熄灯") < 0:
		push_error("SMOKE_HANDOFF_PUMP_BODY %s" % pump_body)
		quit(52)
		return false
	var radio_body := str(LevelDef.handoff_body("depot", "radio"))
	if radio_body.find("电台") < 0 or radio_body.find("灯塔") < 0:
		push_error("SMOKE_HANDOFF_RADIO_BODY %s" % radio_body)
		quit(52)
		return false
	if str(LevelDef.handoff_title("yard", "warehouse")).find("深仓") < 0:
		push_error("SMOKE_HANDOFF_TITLE %s" % LevelDef.handoff_title("yard", "warehouse"))
		quit(52)
		return false
	if str(LevelDef.handoff_cta("radio")).find("终夜") < 0:
		push_error("SMOKE_HANDOFF_CTA %s" % LevelDef.handoff_cta("radio"))
		quit(52)
		return false
	if main.night_handoff == null:
		push_error("SMOKE_NO_NIGHT_HANDOFF")
		quit(52)
		return false
	main.night_handoff.present("yard", "warehouse")
	if not main.night_handoff.is_open():
		push_error("SMOKE_HANDOFF_NOT_OPEN")
		quit(52)
		return false
	var ho_txt := str(main.night_handoff.body_text())
	if ho_txt.find("院子已静") < 0 or ho_txt.find("仓道") < 0:
		push_error("SMOKE_HANDOFF_PANEL %s" % ho_txt)
		quit(52)
		return false
	if str(main.night_handoff.from_id()) != "yard" or str(main.night_handoff.to_id()) != "warehouse":
		push_error("SMOKE_HANDOFF_IDS %s %s" % [main.night_handoff.from_id(), main.night_handoff.to_id()])
		quit(52)
		return false
	if not main.has_method("_modal_blocks_input") or not bool(main._modal_blocks_input()):
		push_error("SMOKE_HANDOFF_NOT_MODAL")
		quit(52)
		return false
	main.night_handoff.dismiss()
	if main.night_handoff.is_open():
		push_error("SMOKE_HANDOFF_STUCK")
		quit(52)
		return false
	print("SMOKE_OK_NIGHT_HANDOFF")
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
		var strip_rect: Rect2 = main.checklist_strip.get_global_rect()
		var dock_rect: Rect2 = main.role_box.get_global_rect()
		if strip_rect.intersects(dock_rect):
			push_error(
				"SMOKE_CHECKLIST_OVER_CARDS strip=%s dock=%s"
				% [strip_rect, dock_rect]
			)
			quit(70)
			return false
		if float(main.checklist_strip.anchor_left) < 0.99:
			push_error("SMOKE_CHECKLIST_NOT_TIMELINE_SIDE anchor_left=%s" % main.checklist_strip.anchor_left)
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
		"radio": "5.2",
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
		if str(def.situation).strip_edges() == "":
			push_error("SMOKE_NO_SITUATION %s" % lid)
			quit(61)
			return false
		if def.intel_chatter.is_empty():
			push_error("SMOKE_NO_CHATTER %s" % lid)
			quit(61)
			return false
		if str(def.campaign_beat).strip_edges() == "":
			push_error("SMOKE_NO_CAMPAIGN_BEAT %s" % lid)
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
	if main.spawn_teach_label == null or str(main.spawn_teach_label.text).find("交叉封锁") < 0:
		push_error("SMOKE_YARD_BEAT_HUD %s" % (main.spawn_teach_label.text if main.spawn_teach_label else "null"))
		quit(61)
		return false
	print("SMOKE_OK_PAYOFF_COPY hooks=6 roles=3 first_shot=1")
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
	if not ResourceLoader.exists("res://scripts/ui/campaign_journal.gd"):
		push_error("SMOKE_NO_JOURNAL_SCRIPT")
		quit(42)
		return false
	if not ResourceLoader.exists("res://scripts/ui/night_handoff.gd"):
		push_error("SMOKE_NO_HANDOFF_SCRIPT")
		quit(42)
		return false
	var journal_src := FileAccess.get_file_as_string("res://scripts/ui/campaign_journal.gd")
	if journal_src.find("封印邮戳") < 0:
		push_error("SMOKE_NO_JOURNAL_STAMP")
		quit(42)
		return false
	var icon_src := FileAccess.get_file_as_string("res://icon.svg")
	if icon_src.find("#e24a38") < 0 or icon_src.find("#c6d47a") < 0:
		push_error("SMOKE_ICON_NOT_AMBUSH")
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
	if entries.size() != 6:
		push_error("SMOKE_MISSION_COUNT %s" % entries.size())
		quit(43)
		return false
	if str(gs.LEVEL_ORDER[3]) != "railcut" or str(gs.LEVEL_ORDER[4]) != "depot" or str(gs.LEVEL_ORDER[5]) != "radio" or gs.LEVEL_ORDER.size() != 6:
		push_error("SMOKE_LEVEL_ORDER %s" % str(gs.LEVEL_ORDER))
		quit(43)
		return false
	var howto_src := FileAccess.get_file_as_string("res://scripts/title.gd")
	if howto_src.find("弹包交给已部署队员（仓道、泵站、信号楼、油库、电台）") < 0:
		push_error("SMOKE_HOWTO_NO_RADIO")
		quit(43)
		return false
	var cred_src := FileAccess.get_file_as_string("res://scripts/ui/credits_overlay.gd")
	if cred_src.find("院子 / 仓道 / 泵站 / 信号楼 / 油库 / 电台") < 0:
		push_error("SMOKE_CREDITS_SRC_NO_RADIO")
		quit(43)
		return false
	if cred_src.find("NightRail") < 0 or cred_src.find("mood_tag") < 0:
		push_error("SMOKE_CREDITS_NO_NIGHT_RAIL")
		quit(43)
		return false
	var foot_src := FileAccess.get_file_as_string("res://scenes/title.tscn")
	if foot_src.find("院子 / 仓道 / 泵站 / 信号楼 / 油库 / 电台") < 0:
		push_error("SMOKE_TITLE_FOOT_NO_RADIO")
		quit(43)
		return false
	if not bool(entries[0]["unlocked"]) or bool(entries[1]["unlocked"]) or bool(entries[3]["unlocked"]) or bool(entries[4]["unlocked"]) or bool(entries[5]["unlocked"]) or bool(entries[0]["cleared"]):
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
	if inst.mission_row_count() != 6:
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
	var mood_want := ["初阵", "深仓", "闸站", "信号", "油库", "终夜"]
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
	inst._on_mission_picked(5)
	await process_frame
	if inst.briefing_visible() or inst.pending_mission_id() == "radio":
		push_error("SMOKE_SKIPPED_LOCKED_RADIO")
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
	if not inst.has_method("briefing_situation_text") or str(inst.briefing_situation_text()).find("北门") < 0:
		push_error("SMOKE_NO_SITUATION_BRIEF %s" % (inst.briefing_situation_text() if inst.has_method("briefing_situation_text") else "no_api"))
		inst.free()
		quit(54)
		return false
	if not inst.has_method("briefing_night_text") or str(inst.briefing_night_text()).find("1 / 6") < 0:
		push_error("SMOKE_NO_NIGHT_INDEX %s" % (inst.briefing_night_text() if inst.has_method("briefing_night_text") else "no_api"))
		inst.free()
		quit(54)
		return false
	if not inst.has_method("open_journal"):
		push_error("SMOKE_NO_JOURNAL_API")
		inst.free()
		quit(54)
		return false
	inst.open_journal()
	await process_frame
	if not inst.journal_visible() or str(inst.journal_body_text()).find("电台") < 0:
		push_error("SMOKE_JOURNAL_RADIO %s" % (inst.journal_body_text() if inst.has_method("journal_body_text") else "no_api"))
		inst.free()
		quit(54)
		return false
	print("SMOKE_OK_JOURNAL")
	var title_src := FileAccess.get_file_as_string("res://scripts/title.gd")
	if title_src.find("latest_cleared_id") < 0 or title_src.find("已封锁") < 0:
		push_error("SMOKE_TITLE_NO_JOURNAL_STAMP")
		inst.free()
		quit(54)
		return false
	if inst._journal:
		inst._journal.dismiss()
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
