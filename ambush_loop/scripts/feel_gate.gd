extends SceneTree

## Runtime presence gate. Fails if night grade, watch cinema, or contact
## shadows are missing. Smoke preloads this and calls evaluate(main).

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	_wipe_save()
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("FEEL_NO_MAIN")
		print("FEEL_GATE_FAIL n=1")
		quit(2)
		return
	await process_frame
	await process_frame
	var main = current_scene
	for i in 8:
		await process_frame
	_prep_units(main)
	var fails := evaluate(main)
	var watch_fail := await _evaluate_watch_cinema(main)
	if watch_fail != "":
		fails.append(watch_fail)
	for f in fails:
		push_error("FEEL_FAIL %s" % f)
		print("FEEL_FAIL ", f)
	if fails.is_empty():
		print("FEEL_GATE_OK")
		quit(0)
		return
	print("FEEL_GATE_FAIL n=", fails.size())
	quit(2)


static func evaluate(main) -> PackedStringArray:
	var fails := PackedStringArray()
	if main == null:
		fails.append("no_main")
		return fails
	var hook := ""
	if main.level != null:
		hook = str(main.level.highlight_hook)
	if hook.find("交叉") < 0:
		fails.append("yard_hook")
	else:
		print("FEEL_OK_YARD_HOOK ", hook)
	var ops: Array = main.operators if main.get("operators") != null else []
	if ops.is_empty():
		fails.append("no_operators")
	var need := ["Head", "ShoulderL", "LegL", "Weapon"]
	for op in ops:
		if op == null or not is_instance_valid(op):
			continue
		if op.has_method("_rebuild_cone"):
			op._rebuild_cone()
		if op.body == null:
			fails.append("op_no_body")
			continue
		for nam in need:
			if op.body.get_node_or_null(nam) == null:
				fails.append("op_part_%s" % nam)
	if not fails.has("op_part_Head") and not ops.is_empty():
		print("FEEL_OK_OP_PARTS Head,ShoulderL,LegL,Weapon")
	var saw_shadow := false
	for op in ops:
		if op != null and is_instance_valid(op) and op.get_node_or_null("ContactShadow") != null:
			saw_shadow = true
			break
	if not saw_shadow:
		fails.append("contact_shadow")
	else:
		print("FEEL_OK_CONTACT_SHADOW")
	var kinds := _probe_enemy_kinds(main)
	if kinds.size() < 3:
		fails.append("enemy_kinds")
	elif kinds[0] == kinds[1] or kinds[1] == kinds[2]:
		fails.append("enemy_kinds_identical")
	else:
		print("FEEL_OK_ENEMY_KINDS ", ",".join(kinds))
	if not _has_night_grade(main):
		fails.append("night_grade")
	else:
		print("FEEL_OK_NIGHT_GRADE")
	if main.get_node_or_null("World/NightKeys") == null:
		fails.append("night_keys")
	else:
		print("FEEL_OK_NIGHT_KEYS")
	if main.get_node_or_null("World/MissionSky") == null:
		fails.append("mission_sky")
	else:
		print("FEEL_OK_MISSION_SKY")
	var fx: Variant = load("res://scripts/fx/combat_fx.gd")
	if fx == null or not (fx as GDScript).has_method("kill_burst"):
		fails.append("kill_burst")
	else:
		print("FEEL_OK_KILL_BURST")
	return fails


static func has_watch_cinema(main) -> bool:
	if main == null:
		return false
	if _named(main, "WatchLetterbox") != null:
		return true
	if _named(main, "LetterboxTop") != null:
		return true
	if _named(main, "WatchVignette") != null:
		return true
	return false


func _evaluate_watch_cinema(main) -> String:
	if main == null:
		return "watch_cinema"
	if main.cover_slots.size() > 0 and main.operators.size() > 0:
		if main.has_method("_select_op"):
			main._select_op(0)
		if main.has_method("_deploy_selected_to"):
			main._deploy_selected_to(main.cover_slots[0], false)
	if main.has_method("_on_alarm_pressed"):
		main._on_alarm_pressed()
	for i in 4:
		await process_frame
	if not has_watch_cinema(main):
		if main.has_method("_on_abort_pressed"):
			main._on_abort_pressed()
		return "watch_cinema"
	var used := false
	var n: Node = _named(main, "WatchLetterbox")
	if n == null:
		n = _named(main, "LetterboxTop")
	if n == null:
		n = _named(main, "WatchVignette")
	if n is CanvasItem:
		used = (n as CanvasItem).visible and (n as CanvasItem).modulate.a > 0.02
		if n is ColorRect:
			used = used or (n as ColorRect).color.a > 0.02
	if n != null and n.get("visible") != null:
		used = used or bool(n.visible)
	if main.has_method("_on_abort_pressed"):
		main._on_abort_pressed()
	if not used:
		return "watch_cinema_unused"
	print("FEEL_OK_WATCH_CINEMA")
	return ""


static func _has_night_grade(main) -> bool:
	var n: Node = main.get_node_or_null("World/NightGrade")
	if n == null:
		n = main.get_node_or_null("NightGrade")
	if n == null:
		n = _named(main, "NightGrade")
	if n != null:
		return true
	if main is Node:
		for c in main.get_children():
			if c is CanvasModulate:
				return true
		var world: Node = main.get_node_or_null("World")
		if world:
			for c in world.get_children():
				if c is CanvasModulate:
					return true
	return false


static func _named(root: Node, nam: String) -> Node:
	if root == null:
		return null
	var direct := root.get_node_or_null(nam)
	if direct:
		return direct
	var hud := root.get_node_or_null("HUD/Root/" + nam)
	if hud:
		return hud
	return root.find_child(nam, true, false)


static func _probe_enemy_kinds(main) -> PackedStringArray:
	var out := PackedStringArray()
	if main == null or not main.has_method("_make_enemy"):
		return out
	var host: Node = main.entities if main.get("entities") != null else main
	var specs := [
		{"id": 91, "route": "main"},
		{"id": 92, "route": "flank"},
		{"id": 93, "route": "sneak"},
	]
	var spawned: Array = []
	for spec in specs:
		var e = main._make_enemy(int(spec["id"]))
		host.add_child(e)
		e.setup(
			int(spec["id"]),
			PackedVector2Array([Vector2(80, 80), Vector2(160, 80)]),
			main.grid,
			0,
			str(spec["route"])
		)
		spawned.append(e)
		var sig := ""
		if e.body:
			sig = "%s:%d" % [e.kind_id(), e.body.polygon.size()]
		out.append(sig)
	for e in spawned:
		if e != null and is_instance_valid(e):
			e.queue_free()
	return out


static func _prep_units(main) -> void:
	if main == null:
		return
	var slots: Array = main.cover_slots if main.get("cover_slots") != null else []
	var ops: Array = main.operators if main.get("operators") != null else []
	var n := mini(ops.size(), slots.size())
	for i in n:
		if main.has_method("_select_op"):
			main._select_op(i)
		if main.has_method("_deploy_selected_to"):
			main._deploy_selected_to(slots[i], false)
		if ops[i] != null and ops[i].has_method("_rebuild_cone"):
			ops[i]._rebuild_cone()


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.reset_to_defaults()
		gs.seen_tutorial = true
