extends SceneTree

## Recreate the scene after a safe save to prove menu/continue restores memory.

const PROGRESS_PATH_SETTING := "application/config/ambush_progress_path"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_dir := "user://test/persistence_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	ProjectSettings.set_setting(PROGRESS_PATH_SETTING, save_dir + "/ambush_loop.cfg")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("PERSISTENCE_SCENE_LOAD_FAILED")
		quit(1)
		return
	await process_frame
	await process_frame
	var first = current_scene
	first.loop_index = 4
	first.intel_paths.append(PackedVector2Array([Vector2(10, 10), Vector2(20, 20)]))
	first._select_op(0)
	first._deploy_selected_to(first.cover_slots[0])
	first._capture_plan()
	if first._save_progress() != OK:
		push_error("PERSISTENCE_SAVE_FAILED")
		quit(2)
		return
	print("PERSISTENCE_SAVE_OK")
	var reload_err := change_scene_to_file("res://scenes/main.tscn")
	if reload_err != OK:
		push_error("PERSISTENCE_RELOAD_SCENE_FAILED")
		quit(4)
		return
	await process_frame
	await process_frame
	var second = current_scene
	if second.loop_index != 4 or second.intel_paths.size() != 1 or second._deployed_count() != 1:
		push_error("PERSISTENCE_RESTORE_FAILED loop=%s intel=%s deployed=%s" % [second.loop_index, second.intel_paths.size(), second._deployed_count()])
		quit(3)
		return
	print("PERSISTENCE_RESTORE_OK loop=%s intel=%s deployed=%s" % [second.loop_index, second.intel_paths.size(), second._deployed_count()])
	print("PERSISTENCE_SMOKE_COMPLETE")
	quit(0)
