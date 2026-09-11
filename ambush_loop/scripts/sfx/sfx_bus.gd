class_name SfxBus
extends Node

## Tiny procedural WAV beeps — pooled, reused, SFX bus. Mute with M / Master.

const MIX_RATE := 22050
const CUES := [
	"alarm", "alarm_stinger", "fire", "fire_mg", "fire_scout", "return_fire", "empty", "loot", "op_death", "escape", "win",
	"win_stinger", "door", "trip", "barrel", "kill",
	"ambient_yard", "ambient_warehouse", "ambient_pump", "ambient_railcut", "ambient_depot"
]

var muted: bool = false
var last_cue: String = ""
var _players: Dictionary = {}
var _stream_pool: Dictionary = {}


func _ready() -> void:
	_build_players()


func _exit_tree() -> void:
	# Drop WAV refs so headless ObjectDB stays quiet on quit.
	for k in _players:
		var p: AudioStreamPlayer = _players[k]
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null
	_players.clear()
	_stream_pool.clear()


func _build_players() -> void:
	var bus := _sfx_bus_name()
	for cue in CUES:
		if _players.has(cue) and _players[cue] != null and is_instance_valid(_players[cue]):
			continue
		var p := AudioStreamPlayer.new()
		p.name = "Cue_%s" % cue
		p.stream = _pooled_stream(cue)
		p.volume_db = _gain(cue)
		p.bus = bus
		add_child(p)
		_players[cue] = p


func play(cue: String) -> void:
	last_cue = cue
	if muted:
		return
	# Dummy/headless play() leaves AudioStreamPlaybackWAV in ObjectDB.
	if DisplayServer.get_name() == "headless":
		return
	var p: AudioStreamPlayer = _players.get(cue) as AudioStreamPlayer
	if p == null or p.stream == null:
		return
	if p.playing:
		p.stop()
	p.play()


func set_muted(on: bool) -> void:
	muted = on
	if muted:
		for k in _players:
			var p: AudioStreamPlayer = _players[k]
			if p != null and p.playing:
				p.stop()


func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func has_cue(cue: String) -> bool:
	return _players.has(cue) and _players[cue] != null


func ambient_cue_id(level_id: String) -> String:
	match str(level_id):
		"warehouse", "pump", "railcut", "depot":
			return "ambient_%s" % level_id
		_:
			return "ambient_yard"


func has_mission_ambient(level_id: String) -> bool:
	return has_cue(ambient_cue_id(level_id))


func play_mission_ambient(level_id: String) -> void:
	play(ambient_cue_id(level_id))


func _sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"


func _pooled_stream(cue: String) -> AudioStreamWAV:
	if _stream_pool.has(cue) and _stream_pool[cue] != null:
		return _stream_pool[cue]
	var st := _build_stream(cue)
	_stream_pool[cue] = st
	return st


func _gain(cue: String) -> float:
	match cue:
		"alarm":
			return -12.0
		"alarm_stinger":
			return -10.0
		"win":
			return -14.0
		"win_stinger":
			return -12.0
		"escape", "op_death":
			return -11.0
		"fire", "return_fire":
			return -16.0
		"fire_mg":
			return -15.0
		"fire_scout":
			return -18.0
		"door":
			return -13.0
		"trip":
			return -12.0
		"barrel":
			return -10.0
		"kill":
			return -14.0
		"ambient_yard":
			return -28.0
		"ambient_warehouse":
			return -24.0
		"ambient_pump":
			return -26.0
		"ambient_railcut":
			return -24.0
		"ambient_depot":
			return -25.0
		_:
			return -15.0


func _build_stream(cue: String) -> AudioStreamWAV:
	match cue:
		"alarm":
			return _pcm(_siren())
		"alarm_stinger":
			return _pcm(_stinger())
		"fire":
			return _pcm(_crack(1900.0, 0.055, 0.20))
		"fire_mg":
			return _pcm(_mg_burst())
		"fire_scout":
			return _pcm(_crack(2400.0, 0.080, 0.14))
		"return_fire":
			return _pcm(_crack(920.0, 0.07, 0.16))
		"empty":
			return _pcm(_click())
		"loot":
			return _pcm(_blip(1040.0, 1560.0, 0.09, 0.18))
		"op_death":
			return _pcm(_fall(220.0, 70.0, 0.22, 0.22))
		"escape":
			return _pcm(_escape())
		"win":
			return _pcm(_win())
		"win_stinger":
			return _pcm(_win_stinger())
		"door":
			return _pcm(_door())
		"trip":
			return _pcm(_trip())
		"barrel":
			return _pcm(_barrel())
		"kill":
			return _pcm(_kill())
		"ambient_yard":
			return _pcm(_ambient_yard())
		"ambient_warehouse":
			return _pcm(_ambient_warehouse())
		"ambient_pump":
			return _pcm(_ambient_pump())
		"ambient_railcut":
			return _pcm(_ambient_railcut())
		"ambient_depot":
			return _pcm(_ambient_depot())
		_:
			return _pcm(_crack(800.0, 0.04, 0.1))


func _pcm(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = data
	return st


func _tone(freq: float, sec: float, amp: float, noise: float = 0.0) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var step := TAU * freq / float(MIX_RATE)
	for i in n:
		var env := _env(i, n)
		var s := sin(phase) * amp * env
		if noise > 0.0:
			s += (randf() * 2.0 - 1.0) * noise * env
		out[i] = s
		phase += step
	return out


func _env(i: int, n: int) -> float:
	if n <= 1:
		return 0.0
	var t := float(i) / float(n - 1)
	var a := clampf(t / 0.08, 0.0, 1.0)
	var r := clampf((1.0 - t) / 0.22, 0.0, 1.0)
	return minf(a, r)


func _concat(parts: Array) -> PackedFloat32Array:
	var total := 0
	for p in parts:
		total += (p as PackedFloat32Array).size()
	var out := PackedFloat32Array()
	out.resize(total)
	var w := 0
	for p in parts:
		var arr: PackedFloat32Array = p
		for i in arr.size():
			out[w] = arr[i]
			w += 1
	return out


func _silence(sec: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	return out


func _siren() -> PackedFloat32Array:
	return _concat([
		_tone(880.0, 0.11, 0.18, 0.01),
		_silence(0.03),
		_tone(620.0, 0.13, 0.16, 0.01),
	])


func _stinger() -> PackedFloat32Array:
	return _concat([
		_tone(1480.0, 0.045, 0.22, 0.02),
		_silence(0.015),
		_tone(990.0, 0.08, 0.16, 0.02),
	])


func _crack(freq: float, sec: float, amp: float) -> PackedFloat32Array:
	return _tone(freq, sec, amp, 0.12)


func _mg_burst() -> PackedFloat32Array:
	return _concat([
		_tone(720.0, 0.028, 0.18, 0.14),
		_silence(0.012),
		_tone(640.0, 0.026, 0.16, 0.12),
		_silence(0.012),
		_tone(580.0, 0.030, 0.15, 0.12),
	])


func _click() -> PackedFloat32Array:
	return _concat([
		_tone(240.0, 0.04, 0.12, 0.08),
		_tone(180.0, 0.05, 0.08, 0.02),
	])


func _blip(f0: float, f1: float, sec: float, amp: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n - 1)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / float(MIX_RATE)
		out[i] = sin(phase) * amp * _env(i, n)
	return out


func _fall(f0: float, f1: float, sec: float, amp: float) -> PackedFloat32Array:
	return _blip(f0, f1, sec, amp)


func _escape() -> PackedFloat32Array:
	return _concat([
		_tone(740.0, 0.08, 0.16, 0.02),
		_silence(0.02),
		_tone(480.0, 0.12, 0.14, 0.03),
	])


func _win() -> PackedFloat32Array:
	return _concat([
		_tone(523.0, 0.09, 0.14),
		_tone(784.0, 0.12, 0.15),
	])


func _win_stinger() -> PackedFloat32Array:
	## Brief major flourish — not the alarm descending pair.
	return _concat([
		_tone(392.0, 0.04, 0.11),
		_tone(523.0, 0.05, 0.13),
		_tone(659.0, 0.06, 0.15),
		_tone(784.0, 0.10, 0.16),
	])


func _door() -> PackedFloat32Array:
	return _concat([
		_tone(190.0, 0.045, 0.20, 0.10),
		_tone(420.0, 0.035, 0.10, 0.04),
		_silence(0.02),
		_tone(140.0, 0.06, 0.14, 0.06),
	])


func _trip() -> PackedFloat32Array:
	return _concat([
		_tone(2100.0, 0.018, 0.16, 0.08),
		_tone(420.0, 0.05, 0.14, 0.04),
		_tone(180.0, 0.06, 0.10, 0.03),
	])


func _barrel() -> PackedFloat32Array:
	return _concat([
		_rumble(0.12, 0.22, 48.0),
		_tone(90.0, 0.10, 0.16, 0.10),
		_tone(240.0, 0.06, 0.08, 0.06),
	])


func _kill() -> PackedFloat32Array:
	return _concat([
		_tone(520.0, 0.03, 0.12, 0.04),
		_tone(310.0, 0.05, 0.10, 0.03),
	])


func _rumble(sec: float, amp: float, freq: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	var phase := 0.0
	var step := TAU * freq / float(MIX_RATE)
	for i in n:
		acc = acc * 0.96 + (randf() * 2.0 - 1.0) * 0.04
		phase += step
		out[i] = (acc * 3.2 + sin(phase) * 0.45) * amp * _env(i, n)
	return out


func _ambient_yard() -> PackedFloat32Array:
	## Distant dog + cricket ticks. Very quiet bed sting.
	return _concat([
		_tone(4100.0, 0.028, 0.05, 0.03),
		_silence(0.09),
		_tone(3650.0, 0.022, 0.04, 0.02),
		_silence(0.16),
		_tone(150.0, 0.08, 0.06, 0.04),
		_silence(0.10),
		_tone(4300.0, 0.018, 0.035, 0.02),
	])


func _ambient_warehouse() -> PackedFloat32Array:
	## Metal creak — slow down-sweep with grit.
	return _concat([
		_blip(240.0, 128.0, 0.22, 0.10),
		_tone(90.0, 0.12, 0.05, 0.08),
	])


func _ambient_pump() -> PackedFloat32Array:
	## Low electrical hum.
	return _concat([
		_tone(58.0, 0.42, 0.07, 0.015),
		_tone(116.0, 0.28, 0.035, 0.01),
	])


func _ambient_railcut() -> PackedFloat32Array:
	## Distant train wheel click.
	return _concat([
		_tone(210.0, 0.035, 0.10, 0.06),
		_silence(0.07),
		_tone(180.0, 0.03, 0.08, 0.05),
		_silence(0.11),
		_tone(195.0, 0.028, 0.07, 0.04),
	])


func _ambient_depot() -> PackedFloat32Array:
	## Diesel idle rumble.
	return _rumble(0.48, 0.09, 36.0)
