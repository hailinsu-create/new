extends Node

## Autoload: mute, master volume, tutorial flag, pending mission id.

const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const PROGRESS_PATH := "user://ambush_loop.cfg"

signal changed

var muted: bool = false
var master_volume: float = 1.0
var seen_tutorial: bool = false
var pending_level_id: String = ""


func _ready() -> void:
	load_settings()
	apply_audio()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_migrate_mute_from_progress()
		return
	muted = bool(cfg.get_value("audio", "muted", false))
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	seen_tutorial = bool(cfg.get_value("onboarding", "seen_tutorial", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("onboarding", "seen_tutorial", seen_tutorial)
	cfg.save(SETTINGS_PATH)


func reset_to_defaults() -> void:
	muted = false
	master_volume = 1.0
	seen_tutorial = false
	pending_level_id = ""
	apply_audio()


func apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)
	if master_volume <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
	changed.emit()


func set_muted(on: bool) -> void:
	muted = on
	save_settings()
	apply_audio()


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	save_settings()
	apply_audio()


func mark_tutorial_seen() -> void:
	seen_tutorial = true
	save_settings()


func has_progress() -> bool:
	if is_campaign_complete():
		return false
	if not FileAccess.file_exists(PROGRESS_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return false
	return str(cfg.get_value("progress", "level_id", "")) != ""


func progress_level_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return "yard"
	var id := str(cfg.get_value("progress", "level_id", "yard"))
	if id == "":
		return "yard"
	return id


func is_campaign_complete() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return false
	return bool(cfg.get_value("progress", "complete", false))


func current_or_first_level() -> String:
	if not has_progress() or is_campaign_complete():
		return "yard"
	return progress_level_id()


func _migrate_mute_from_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", false))
