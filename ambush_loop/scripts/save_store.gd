class_name AmbushSaveStore
extends RefCounted

## Versioned, safe-state-only local storage. Battle ticks and live entities are
## deliberately absent: a save is valid only at menu/setup/result boundaries.

const SCHEMA_VERSION := 2
const DEFAULT_PATH := "user://ambush_loop.cfg"

var last_note := ""
var last_write_atomic := false


func default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"level_id": "yard",
		"level_index": 0,
		"loop": 1,
		"intel_paths": [],
		"last_plan": {"deployments": [], "tripwire_positions": [], "door_locked": false},
		"best_stars": {},
		"failure_counts": {},
		"tutorial_seen": false,
		"settings": {"volume": 0.75, "haptics": true, "touch_feedback": true, "language": "zh-CN"},
	}


func load_state(path: String = DEFAULT_PATH) -> Dictionary:
	last_note = ""
	last_write_atomic = false
	if not FileAccess.file_exists(path):
		last_note = "no_save"
		return default_state()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		last_note = "corrupt_load_error_%s" % err
		return default_state()
	var stored_schema := int(cfg.get_value("meta", "schema_version", 1))
	if stored_schema > SCHEMA_VERSION:
		last_note = "future_schema_%s" % stored_schema
		return default_state()
	var state := default_state()
	state["schema_version"] = SCHEMA_VERSION
	state["level_id"] = str(cfg.get_value("progress", "level_id", "yard"))
	state["level_index"] = int(cfg.get_value("progress", "level_index", 0))
	state["loop"] = maxi(1, int(cfg.get_value("progress", "loop", cfg.get_value("progress", "loop_index", 1))))
	state["intel_paths"] = _decode_paths(_decode_json_or_raw(cfg.get_value("progress", "intel_paths_json", cfg.get_value("progress", "intel_paths", []))))
	state["last_plan"] = _decode_plan(_decode_json_or_raw(cfg.get_value("progress", "last_plan_json", cfg.get_value("progress", "last_plan", {}))))
	state["best_stars"] = _sanitize_stars(_decode_json_or_raw(cfg.get_value("progress", "best_stars_json", cfg.get_value("progress", "best_stars", {}))))
	state["failure_counts"] = _sanitize_counts(_decode_json_or_raw(cfg.get_value("progress", "failure_counts_json", cfg.get_value("progress", "failure_counts", {}))))
	state["tutorial_seen"] = bool(cfg.get_value("progress", "tutorial_seen", false))
	state["settings"] = _sanitize_settings(_decode_json_or_raw(cfg.get_value("settings", "values_json", cfg.get_value("settings", "values", {}))))
	if stored_schema < SCHEMA_VERSION:
		last_note = "migrated_schema_%s_to_%s" % [stored_schema, SCHEMA_VERSION]
	else:
		last_note = "loaded_schema_%s" % stored_schema
	return _sanitize_state(state)


func save_state(state: Dictionary, path: String = DEFAULT_PATH) -> int:
	last_write_atomic = false
	var safe := _sanitize_state(state)
	var parent_path := path.get_base_dir()
	if parent_path != "user://" and parent_path.begins_with("user://"):
		var parent_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_path))
		if parent_err != OK:
			last_note = "parent_create_failed_%s" % parent_err
			return parent_err
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", SCHEMA_VERSION)
	cfg.set_value("meta", "format", "safe_state_only")
	cfg.set_value("progress", "level_id", safe["level_id"])
	cfg.set_value("progress", "level_index", safe["level_index"])
	cfg.set_value("progress", "loop", safe["loop"])
	cfg.set_value("progress", "intel_paths_json", JSON.stringify(_encode_paths(safe["intel_paths"])))
	cfg.set_value("progress", "last_plan_json", JSON.stringify(_encode_plan(safe["last_plan"])))
	cfg.set_value("progress", "best_stars_json", JSON.stringify(safe["best_stars"]))
	cfg.set_value("progress", "failure_counts_json", JSON.stringify(safe["failure_counts"]))
	cfg.set_value("progress", "tutorial_seen", safe["tutorial_seen"])
	cfg.set_value("settings", "values_json", JSON.stringify(safe["settings"]))
	# ConfigFile is used for the compatibility envelope because it is readable
	# by the existing smoke harness. Complex values are JSON strings so a
	# restricted desktop sandbox cannot reject typed arrays/dictionaries.
	# Keep the temporary file extension as .cfg: some Godot builds reject an
	# otherwise valid ConfigFile path ending in .tmp.
	var tmp_path := path + ".tmp.cfg"
	var save_err := cfg.save(tmp_path)
	if save_err != OK:
		last_note = "temp_save_failed_%s" % save_err
		return save_err
	var rename_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if rename_err == OK:
		last_write_atomic = true
		last_note = "atomic_replace"
		return OK
	# Keep the old target intact when replacement fails. The temporary file is
	# intentionally left in place for diagnostics/recovery; no direct write to
	# the live save is allowed.
	last_note = "atomic_replace_failed_%s" % rename_err
	return rename_err


func _sanitize_state(value: Dictionary) -> Dictionary:
	var state := default_state()
	state["level_id"] = str(value.get("level_id", "yard"))
	state["level_index"] = clampi(int(value.get("level_index", 0)), 0, 2)
	state["loop"] = maxi(1, int(value.get("loop", value.get("loop_index", 1))))
	state["intel_paths"] = _decode_paths(value.get("intel_paths", []))
	state["last_plan"] = _decode_plan(value.get("last_plan", {}))
	state["best_stars"] = _sanitize_stars(value.get("best_stars", {}))
	state["failure_counts"] = _sanitize_counts(value.get("failure_counts", {}))
	state["tutorial_seen"] = bool(value.get("tutorial_seen", false))
	state["settings"] = _sanitize_settings(value.get("settings", {}))
	return state


func _sanitize_settings(value: Variant) -> Dictionary:
	var defaults: Dictionary = default_state()["settings"]
	var source := value as Dictionary
	return {
		"volume": clampf(float(source.get("volume", defaults["volume"])), 0.0, 1.0),
		"haptics": bool(source.get("haptics", defaults["haptics"])),
		"touch_feedback": bool(source.get("touch_feedback", defaults["touch_feedback"])),
		"language": "zh-CN",
	}


func _decode_json_or_raw(value: Variant) -> Variant:
	if value is String:
		var parsed = JSON.parse_string(value as String)
		return parsed if parsed != null else value
	return value


func _sanitize_stars(value: Variant) -> Dictionary:
	var out := {}
	if not value is Dictionary:
		return out
	for key in (value as Dictionary).keys():
		var stars := clampi(int((value as Dictionary)[key]), 0, 3)
		if stars > 0:
			out[str(key)] = stars
	return out


func _sanitize_counts(value: Variant) -> Dictionary:
	var out := {}
	if not value is Dictionary:
		return out
	for key in (value as Dictionary).keys():
		var count := maxi(0, int((value as Dictionary)[key]))
		if count > 0:
			out[str(key)] = count
	return out


func _decode_paths(value: Variant) -> Array:
	var out: Array = []
	if not value is Array:
		return out
	for raw_path in value as Array:
		var path := PackedVector2Array()
		if raw_path is PackedVector2Array:
			path = raw_path
		elif raw_path is Array:
			for raw_point in raw_path as Array:
				if raw_point is Array and (raw_point as Array).size() >= 2:
					path.append(Vector2(float((raw_point as Array)[0]), float((raw_point as Array)[1])))
		if path.size() >= 2:
			out.append(path)
	return out


func _encode_paths(value: Variant) -> Array:
	var out: Array = []
	if not value is Array:
		return out
	for raw_path in value as Array:
		var points: Array = []
		if raw_path is PackedVector2Array:
			for point in raw_path as PackedVector2Array:
				points.append([point.x, point.y])
		elif raw_path is Array:
			for raw_point in raw_path as Array:
				if raw_point is Array and (raw_point as Array).size() >= 2:
					points.append([float((raw_point as Array)[0]), float((raw_point as Array)[1])])
		if points.size() >= 2:
			out.append(points)
	return out


func _decode_plan(value: Variant) -> Dictionary:
	var out := {"deployments": [], "tripwire_positions": [], "door_locked": false}
	if not value is Dictionary:
		return out
	var source := value as Dictionary
	for raw_entry in source.get("deployments", []) as Array:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry.duplicate(true)
			entry["op_id"] = int(entry.get("op_id", 0))
			entry["slot_id"] = int(entry.get("slot_id", -1))
			entry["facing"] = float(entry.get("facing", 0.0))
			entry["fire_mode"] = int(entry.get("fire_mode", 0))
			entry["has_ammo_pack"] = bool(entry.get("has_ammo_pack", false))
			out["deployments"].append(entry)
	out["tripwire_positions"] = []
	var raw_positions = source.get("tripwire_positions", [])
	if raw_positions is Array:
		for raw_pos in raw_positions as Array:
			if raw_pos is Array and (raw_pos as Array).size() >= 2:
				out["tripwire_positions"].append(Vector2(float((raw_pos as Array)[0]), float((raw_pos as Array)[1])))
			elif raw_pos is Vector2:
				out["tripwire_positions"].append(raw_pos)
	out["door_locked"] = bool(source.get("door_locked", false))
	return out


func _encode_plan(value: Variant) -> Dictionary:
	var out := {"deployments": [], "tripwire_positions": [], "door_locked": false}
	if not value is Dictionary:
		return out
	var source := value as Dictionary
	for raw_entry in source.get("deployments", []) as Array:
		if raw_entry is Dictionary:
			out["deployments"].append((raw_entry as Dictionary).duplicate(true))
	for raw_pos in source.get("tripwire_positions", []) as Array:
		if raw_pos is Vector2:
			out["tripwire_positions"].append([raw_pos.x, raw_pos.y])
		elif raw_pos is Array and (raw_pos as Array).size() >= 2:
			out["tripwire_positions"].append([float((raw_pos as Array)[0]), float((raw_pos as Array)[1])])
	out["door_locked"] = bool(source.get("door_locked", false))
	return out
