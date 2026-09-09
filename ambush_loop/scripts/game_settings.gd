extends Node

## Autoload: mute, Music/SFX volumes, per-level tutorial flags, pending mission id.

const SETTINGS_PATH := "user://ambush_loop_settings.cfg"
const PROGRESS_PATH := "user://ambush_loop.cfg"
const LEVEL_ORDER := ["yard", "warehouse", "pump"]

signal changed

var muted: bool = false
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var seen_tutorial: bool = false
var seen_level_tutorials: Dictionary = {} # level_id -> bool
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
	if cfg.has_section_key("audio", "music_volume") or cfg.has_section_key("audio", "sfx_volume"):
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", master_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", master_volume)), 0.0, 1.0)
	else:
		# Old single master slider: copy onto both buses.
		music_volume = master_volume
		sfx_volume = master_volume
	seen_tutorial = bool(cfg.get_value("onboarding", "seen_tutorial", false))
	seen_level_tutorials.clear()
	for id in LEVEL_ORDER:
		if cfg.has_section_key("onboarding", "seen_" + id):
			seen_level_tutorials[id] = bool(cfg.get_value("onboarding", "seen_" + id, false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "master_volume", clampf((music_volume + sfx_volume) * 0.5, 0.0, 1.0))
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("onboarding", "seen_tutorial", seen_tutorial)
	for id in LEVEL_ORDER:
		if seen_level_tutorials.has(id):
			cfg.set_value("onboarding", "seen_" + id, bool(seen_level_tutorials[id]))
	cfg.save(SETTINGS_PATH)


func reset_to_defaults() -> void:
	muted = false
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	seen_tutorial = false
	seen_level_tutorials.clear()
	pending_level_id = ""
	apply_audio()


func apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
		AudioServer.set_bus_volume_db(idx, 0.0)
	_set_bus_linear("Music", music_volume, -6.0)
	_set_bus_linear("SFX", sfx_volume, 0.0)
	changed.emit()


func _set_bus_linear(bus_name: String, linear: float, extra_db: float) -> void:
	var b := AudioServer.get_bus_index(bus_name)
	if b < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_volume_db(b, -80.0)
	else:
		AudioServer.set_bus_volume_db(b, linear_to_db(linear) + extra_db)


func set_muted(on: bool) -> void:
	muted = on
	save_settings()
	apply_audio()


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


func set_volume(v: float) -> void:
	## Compat: old single slider drives both buses.
	var n := clampf(v, 0.0, 1.0)
	master_volume = n
	music_volume = n
	sfx_volume = n
	save_settings()
	apply_audio()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	master_volume = clampf((music_volume + sfx_volume) * 0.5, 0.0, 1.0)
	save_settings()
	apply_audio()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	master_volume = clampf((music_volume + sfx_volume) * 0.5, 0.0, 1.0)
	save_settings()
	apply_audio()


func has_seen_tutorial(level_id: String = "yard") -> bool:
	if bool(seen_level_tutorials.get(level_id, false)):
		return true
	# Legacy / smoke: old bool with no per-level keys means skip every modal.
	if seen_level_tutorials.is_empty() and seen_tutorial:
		return true
	return false


func mark_tutorial_seen(level_id: String = "yard") -> void:
	if level_id == "":
		level_id = "yard"
	seen_level_tutorials[level_id] = true
	if level_id == "yard":
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


func _progress_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg


func _read_cleared_raw(cfg: ConfigFile) -> PackedStringArray:
	var v = cfg.get_value("progress", "cleared", PackedStringArray())
	var out := PackedStringArray()
	if v is PackedStringArray:
		out = v
	elif v is Array:
		for x in v:
			var s := str(x)
			if s != "" and not out.has(s):
				out.append(s)
	elif v is String:
		for p in str(v).split(","):
			var s := p.strip_edges()
			if s != "" and not out.has(s):
				out.append(s)
	return out


func cleared_level_ids() -> PackedStringArray:
	var cfg := _progress_cfg()
	var cleared := _read_cleared_raw(cfg)
	if bool(cfg.get_value("progress", "complete", false)):
		return PackedStringArray(LEVEL_ORDER)
	var cur := str(cfg.get_value("progress", "level_id", "yard"))
	var idx := LEVEL_ORDER.find(cur)
	if idx < 0:
		idx = 0
	# Old saves only stored the current incomplete level — everything before it is beaten.
	for i in idx:
		var id: String = LEVEL_ORDER[i]
		if not cleared.has(id):
			cleared.append(id)
	return cleared


func is_level_cleared(id: String) -> bool:
	return cleared_level_ids().has(id)


func is_level_unlocked(id: String) -> bool:
	var idx := LEVEL_ORDER.find(id)
	if idx <= 0:
		return true
	if is_campaign_complete():
		return true
	return is_level_cleared(LEVEL_ORDER[idx - 1])


func mission_entries() -> Array:
	var out: Array = []
	var cleared := cleared_level_ids()
	var complete := is_campaign_complete()
	for i in LEVEL_ORDER.size():
		var id: String = LEVEL_ORDER[i]
		var def: LevelDef = LevelDef.by_id(id)
		var unlocked := i == 0 or complete or cleared.has(LEVEL_ORDER[i - 1])
		out.append({
			"id": id,
			"title": def.title,
			"unlocked": unlocked,
			"cleared": complete or cleared.has(id),
		})
	return out


func record_win(level_id: String) -> void:
	var cfg := _progress_cfg()
	var cleared := _read_cleared_raw(cfg)
	if not cleared.has(level_id):
		cleared.append(level_id)
	# Keep inferred predecessors so lock state never regresses.
	var won_idx := LEVEL_ORDER.find(level_id)
	for i in maxi(won_idx, 0):
		var pred: String = LEVEL_ORDER[i]
		if not cleared.has(pred):
			cleared.append(pred)
	cfg.set_value("progress", "cleared", cleared)
	if won_idx >= LEVEL_ORDER.size() - 1:
		cfg.set_value("progress", "complete", true)
	elif won_idx >= 0:
		var next_id: String = LEVEL_ORDER[won_idx + 1]
		cfg.set_value("progress", "level_id", next_id)
		cfg.set_value("progress", "level_index", won_idx + 1)
		cfg.set_value("progress", "complete", false)
	cfg.save(PROGRESS_PATH)


func _migrate_mute_from_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", false))
