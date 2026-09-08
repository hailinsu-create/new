extends "res://scripts/sfx/sfx_bus.gd"

## Autoload: pooled SFX + looping procedural bed. Master volume/mute gate both.
## Bed is a reused looping WAV (not AudioStreamGenerator) so Dummy-driver
## headless quit does not leak AudioStreamGeneratorPlayback.

var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
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
	_stop_music_hard()
	super._exit_tree()


func has_music_bed() -> bool:
	return _music != null and is_instance_valid(_music) and _music.stream != null


func music_bus_ok() -> bool:
	return AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0


func music_is_running() -> bool:
	return (not muted) and music_player_playing()


func music_player_playing() -> bool:
	return _music != null and is_instance_valid(_music) and _music.playing


func set_muted(on: bool) -> void:
	super.set_muted(on)
	_apply_music_mute()


func _on_settings_changed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		set_muted(bool(gs.muted))
	else:
		_apply_music_mute()


func _can_play_audio() -> bool:
	# Dummy/headless leaves AudioStreamPlaybackWAV in ObjectDB if we start the bed.
	return DisplayServer.get_name() != "headless"


func _apply_music_mute() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	if muted or not _want_music or not _can_play_audio():
		if _music.playing:
			_music.stop()
		return
	if _music.stream == null and _music_stream != null:
		_music.stream = _music_stream
	if not _music.playing:
		_music.play()


func _stop_music_hard() -> void:
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	_music_stream = null


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
	_music_stream = _build_bed_wav()
	_music = AudioStreamPlayer.new()
	_music.name = "MusicBed"
	_music.stream = _music_stream
	_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_music.volume_db = -12.0
	add_child(_music)
	if _can_play_audio():
		_music.play()


func _build_bed_wav() -> AudioStreamWAV:
	## ~1.6s looping dual-drone with a slow pulse. Very quiet.
	var rate := 22050
	var sec := 1.6
	var n := int(sec * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var pulse := 0.62 + 0.38 * sin(t * TAU * 0.625)
		var s := sin(t * TAU * 46.0) * 0.016 * pulse
		s += sin(t * TAU * 69.0) * 0.011 * pulse
		s += sin(t * TAU * 92.5) * 0.005
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st
