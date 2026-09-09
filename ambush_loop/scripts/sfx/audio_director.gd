extends "res://scripts/sfx/sfx_bus.gd"

## Autoload: pooled SFX + looping procedural bed. Music/SFX buses; mute gates both.
## Bed is a reused looping WAV (not AudioStreamGenerator) so Dummy-driver
## headless quit does not leak AudioStreamGeneratorPlayback.

var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _want_music: bool = true
var _watch_bed: bool = false
## Home-button / APPLICATION_FOCUS_OUT: stop bed + SFX without touching user mute.
var _background_paused: bool = false
var _mood: AudioStreamPlayer
var _mood_id: String = ""
var _want_mood: bool = false


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
	return (not muted) and (not _background_paused) and music_player_playing()


func is_background_paused() -> bool:
	return _background_paused


func pause_for_background() -> void:
	set_background_muted(true)


func resume_from_background() -> void:
	set_background_muted(false)


func set_background_muted(on: bool) -> void:
	_background_paused = on
	if on:
		_stop_active_sfx()
		if _music != null and is_instance_valid(_music) and _music.playing:
			_music.stop()
		if _mood != null and is_instance_valid(_mood) and _mood.playing:
			_mood.stop()
		return
	_apply_music_mute()
	_apply_mood_mute()


func play(cue: String) -> void:
	if _background_paused:
		last_cue = cue
		return
	super.play(cue)


func _stop_active_sfx() -> void:
	for k in _players:
		var p: AudioStreamPlayer = _players[k]
		if p != null and is_instance_valid(p) and p.playing:
			p.stop()


func music_player_playing() -> bool:
	return _music != null and is_instance_valid(_music) and _music.playing


func set_muted(on: bool) -> void:
	super.set_muted(on)
	_apply_music_mute()
	_apply_mood_mute()


func set_watch_bed(on: bool) -> void:
	## Quieter looping bed while WATCHING so cues and gunfire read.
	if _watch_bed == on:
		return
	_watch_bed = on
	_apply_music_gain()
	_apply_mood_params()


func _apply_music_gain() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	_music.volume_db = -18.0 if _watch_bed else -12.0


func _on_settings_changed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		set_muted(bool(gs.muted))
	_apply_music_gain()
	_apply_music_mute()
	_apply_mood_mute()


func _can_play_audio() -> bool:
	# Dummy/headless leaves AudioStreamPlaybackWAV in ObjectDB if we start the bed.
	return DisplayServer.get_name() != "headless"


func _apply_music_mute() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	if muted or _background_paused or not _want_music or not _can_play_audio():
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
	if _mood != null and is_instance_valid(_mood):
		_mood.stop()
		_mood.stream = null
	_music_stream = null
	_want_mood = false
	_mood_id = ""


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
	_apply_music_gain()
	add_child(_music)
	_mood = AudioStreamPlayer.new()
	_mood.name = "MoodBed"
	_mood.stream = _music_stream
	_mood.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_mood.volume_db = -30.0
	add_child(_mood)
	if _can_play_audio():
		_music.play()


func has_mission_mood(level_id: String) -> bool:
	return mission_mood_pitch(level_id) > 0.0


func mission_mood_pitch(level_id: String) -> float:
	match str(level_id):
		"warehouse":
			return 0.78
		"pump":
			return 0.64
		"railcut":
			return 1.14
		"depot":
			return 0.55
		"yard":
			return 0.92
		_:
			return 0.0


func mission_mood_filter_hz(level_id: String) -> float:
	## Soft cutoff encoded as pitch-adjacent filter; used for volume shading.
	match str(level_id):
		"warehouse":
			return 720.0
		"pump":
			return 380.0
		"railcut":
			return 2100.0
		"depot":
			return 260.0
		_:
			return 1400.0


func play_mission_mood(level_id: String) -> void:
	_mood_id = str(level_id)
	_want_mood = has_mission_mood(_mood_id)
	_apply_mood_params()
	_apply_mood_mute()


func _mood_off_for_tier() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _apply_mood_params() -> void:
	if _mood == null or not is_instance_valid(_mood):
		return
	if _music_stream != null and _mood.stream != _music_stream:
		_mood.stream = _music_stream
	var pitch := mission_mood_pitch(_mood_id)
	_mood.pitch_scale = pitch if pitch > 0.0 else 1.0
	# Quiet layer; 省电 is off entirely. Filter is expressed as extra attenuation
	# on darker missions so we reuse the same procedural WAV.
	var hz := mission_mood_filter_hz(_mood_id)
	var dark := clampf((1600.0 - hz) / 1600.0, 0.0, 1.0)
	_mood.volume_db = -30.0 - dark * 8.0
	if _watch_bed:
		_mood.volume_db -= 4.0


func _apply_mood_mute() -> void:
	if _mood == null or not is_instance_valid(_mood):
		return
	if (
		muted
		or _background_paused
		or not _want_mood
		or not _can_play_audio()
		or _mood_off_for_tier()
	):
		if _mood.playing:
			_mood.stop()
		return
	_apply_mood_params()
	if not _mood.playing:
		_mood.play()


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
