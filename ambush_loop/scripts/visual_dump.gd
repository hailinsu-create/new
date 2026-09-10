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
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("watching")
	print("DUMP_OK title+setup+watching")
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
