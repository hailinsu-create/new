extends "res://scripts/sfx/sfx_bus.gd"

## Autoload: pooled SFX + looping procedural bed. Master volume/mute gate both.

var _music: AudioStreamPlayer
var _music_gen: AudioStreamGenerator
var _music_playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _want_music: bool = true


func _ready() -> void:
	_ensure_buses()
	super._ready()
	_setup_music()
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.changed.is_connected(_on_settings_changed):
		gs.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _exit_tree() -> void:
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	_music_playback = null
	_music_gen = null
	super._exit_tree()


func music_is_running() -> bool:
	return (not muted) and music_player_playing()


func music_player_playing() -> bool:
	return _music != null and is_instance_valid(_music) and _music.playing


func music_bus_ok() -> bool:
	return AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0


func set_muted(on: bool) -> void:
	super.set_muted(on)
	_apply_music_mute()


func _on_settings_changed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		set_muted(bool(gs.muted))
	else:
		_apply_music_mute()


func _apply_music_mute() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	if muted or not _want_music:
		if _music.playing:
			_music.stop()
		_music_playback = null
		return
	if not _music.playing:
		_music.play()
	_music_playback = _music.get_stream_playback() as AudioStreamGeneratorPlayback


func _ensure_buses() -> void:
	_add_bus_if_missing("Music", -6.0)
	_add_bus_if_missing("SFX", 0.0)


func _add_bus_if_missing(bus_name: String, volume_db: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus(-1)
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, volume_db)


func _setup_music() -> void:
	_music_gen = AudioStreamGenerator.new()
	_music_gen.mix_rate = 22050.0
	_music_gen.buffer_length = 0.35
	_music = AudioStreamPlayer.new()
	_music.name = "MusicBed"
	_music.stream = _music_gen
	_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_music.volume_db = -10.0
	add_child(_music)
	_music.play()
	_music_playback = _music.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if muted or _music_playback == null:
		return
	if not is_instance_valid(_music) or not _music.playing:
		return
	var n := _music_playback.get_frames_available()
	if n <= 0:
		return
	var rate := 22050.0
	for _i in n:
		_phase += 1.0
		var t := _phase / rate
		# Very quiet dual-drone + slow pulse. Headless Dummy driver still consumes frames.
		var pulse := 0.62 + 0.38 * sin(t * TAU * 0.38)
		var s := sin(t * TAU * 46.0) * 0.016 * pulse
		s += sin(t * TAU * 69.0) * 0.011 * pulse
		s += sin(t * TAU * 92.5) * 0.005
		_music_playback.push_frame(Vector2(s, s))
