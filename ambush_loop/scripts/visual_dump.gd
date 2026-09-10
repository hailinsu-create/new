extends SceneTree

## Capture title + SETUP (+ WATCHING) PNGs for feel review.

const SAVE_PATH := "user://ambush_loop.cfg"
const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const OUT_A := "/opt/cursor/artifacts"
const OUT_B := "/tmp/ambush-feel/.audit"


func _init() -> void:
	print("DUMP_INIT")
	call_deferred("_run")


func _run() -> void:
	print("DUMP_RUN")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	_wipe_save()
	print("DUMP_WIPED")
	DirAccess.make_dir_recursive_absolute(OUT_A)
	DirAccess.make_dir_recursive_absolute(OUT_B)
	var err := change_scene_to_file("res://scenes/title.tscn")
	if err != OK:
		push_error("DUMP_NO_TITLE")
		quit(2)
		return
	print("DUMP_TITLE_SCENE err=", err)
	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	print("DUMP_TITLE_FRAMES")
	_save("title")
	err = change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("DUMP_NO_MAIN")
		quit(2)
		return
	for i in 16:
		await process_frame
	var main = current_scene
	_deploy_all(main)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("setup_clear")
	_save("setup")
	if main.has_method("_on_alarm_pressed"):
		main._on_alarm_pressed()
	var saw := await _wait_combat_fx(main)
	await RenderingServer.frame_post_draw
	_save("watching_shot")
	_save("watching")
	if not saw:
		push_error("DUMP_NO_SHOT")
		quit(3)
		return
	print("DUMP_OK title+setup+watching_shot")
	quit(0)


func _deploy_all(main) -> void:
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
		if ops[i] != null and ops[i].has_method("set_selected_visual") and i == 0:
			ops[i].set_selected_visual(true)


func _wait_combat_fx(main) -> bool:
	## Advance via process_frame (same as smoke _drive_ticks). Do not touch
	## Engine.time_scale or SimClock step size. Capture the first live shot.
	var guard := 0
	while guard < 720:
		await process_frame
		guard += 1
		var kind := _combat_fx_kind(main)
		if kind != "":
			var tsec := 0.0
			var tick := 0
			if main != null and main.get("sim") != null:
				tsec = float(main.sim.time_sec())
				tick = int(main.sim.tick)
			print("DUMP_SHOT kind=", kind, " t=", tsec, " tick=", tick, " frames=", guard)
			return true
		if main != null and main.get("Phase") != null:
			if main.phase == main.Phase.FAILED or main.phase == main.Phase.WON:
				print("DUMP_PHASE_LEFT phase=", main.phase, " t=", main.sim.time_sec() if main.get("sim") else -1)
				return false
	push_error("DUMP_NO_COMBAT_FX")
	return false


func _combat_fx_kind(main) -> String:
	if main == null:
		return ""
	var live = main.get("_tracer_live")
	if live is Array:
		for t in live:
			if t != null and is_instance_valid(t) and t is CanvasItem and (t as CanvasItem).visible:
				if (t as CanvasItem).modulate.a > 0.04:
					return "WatchTracer"
	var roots: Array = []
	if main.get("entities") != null:
		roots.append(main.entities)
	if main.get("operators") is Array:
		for op in main.operators:
			if op != null:
				roots.append(op)
	if main.get("enemies") is Array:
		for e in main.enemies:
			if e != null:
				roots.append(e)
	for r in roots:
		var hit := _named_fx_in(r)
		if hit != "":
			return hit
	return ""


func _named_fx_in(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	for c in n.get_children():
		if c == null or not is_instance_valid(c):
			continue
		var nam := str(c.name)
		if nam.begins_with("Cfx"):
			return nam
		if nam.begins_with("WatchTracer"):
			return nam
		var scr = c.get_script()
		if scr != null and str(scr.resource_path).find("muzzle_flash") >= 0:
			return "MuzzleFlash"
		if scr != null and str(scr.resource_path).find("combat_fx") >= 0:
			return nam
	return ""


func _save(stem: String) -> void:
	var tex := root.get_viewport().get_texture()
	if tex == null:
		push_error("DUMP_NO_TEX %s" % stem)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("DUMP_NO_IMG %s" % stem)
		return
	var a := "%s/%s.png" % [OUT_A, stem]
	var b := "%s/%s.png" % [OUT_B, stem]
	var e1 := img.save_png(a)
	var e2 := img.save_png(b)
	print("DUMP_PNG ", stem, " bytes=", img.get_width(), "x", img.get_height(), " e=", e1, ",", e2)


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var gs = root.get_node_or_null("GameSettings")
	if gs:
		gs.reset_to_defaults()
		gs.seen_tutorial = true
