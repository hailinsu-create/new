class_name SfxBus
extends Node

## Procedural WAV cues — pooled, reused, SFX bus. Mute with M / Master.

const MIX_RATE := 22050
const CUES := [
	"alarm", "alarm_stinger", "fire", "fire_mg", "fire_scout", "fire_smg", "fire_bolt", "fire_garand", "fire_mg42", "fire_pistol", "fire_shotgun", "fire_ping", "return_fire", "empty", "loot", "op_death", "escape", "fail", "win",
	"win_stinger", "door", "trip", "barrel", "kill", "hit", "ui",
	"spawn", "echo_ping",
	"handoff", "leak", "night_enter", "tension",
	"ambient_yard", "ambient_warehouse", "ambient_pump", "ambient_railcut", "ambient_depot", "ambient_radio"
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


func cue_peak(cue: String) -> float:
	## Peak absolute sample in the pooled WAV. Headless-safe; does not play().
	var st := _pooled_stream(cue)
	if st == null or st.data.is_empty():
		return 0.0
	var peak := 0
	var data: PackedByteArray = st.data
	var i := 0
	while i + 1 < data.size():
		var v := absi(int(data.decode_s16(i)))
		if v > peak:
			peak = v
		i += 2
	return float(peak) / 32767.0


func cue_duration_sec(cue: String) -> float:
	var st := _pooled_stream(cue)
	if st == null or st.data.is_empty():
		return 0.0
	return float(st.data.size() / 2) / float(MIX_RATE)


func ambient_cue_id(level_id: String) -> String:
	match str(level_id):
		"warehouse", "pump", "railcut", "depot", "radio":
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
		"escape", "op_death", "fail":
			return -11.0
		"fire", "return_fire":
			return -13.0
		"fire_mg":
			return -12.0
		"fire_scout":
			return -15.0
		"fire_smg":
			return -14.0
		"fire_bolt":
			return -12.0
		"fire_garand":
			return -13.0
		"fire_mg42":
			return -11.0
		"fire_pistol":
			return -14.0
		"fire_shotgun":
			return -11.0
		"fire_ping":
			return -16.0
		"door":
			return -13.0
		"trip":
			return -12.0
		"barrel":
			return -10.0
		"kill":
			return -14.0
		"ui":
			return -20.0
		"hit":
			return -18.0
		"spawn":
			return -16.0
		"echo_ping":
			return -11.0
		"handoff":
			return -13.0
		"leak":
			return -12.0
		"night_enter":
			return -16.0
		"tension":
			return -8.0
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
		"ambient_radio":
			return -26.0
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
		"fire_smg":
			return _pcm(_crack(1650.0, 0.032, 0.22))
		"fire_bolt":
			return _pcm(_bolt_shot())
		"fire_garand":
			return _pcm(_garand_shot())
		"fire_mg42":
			return _pcm(_mg42_burst())
		"fire_pistol":
			return _pcm(_crack(1750.0, 0.038, 0.16))
		"fire_shotgun":
			return _pcm(_shotgun_boom())
		"fire_ping":
			return _pcm(_click())
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
		"fail":
			return _pcm(_fail())
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
		"ui":
			return _pcm(_ui_click())
		"hit":
			return _pcm(_hit())
		"spawn":
			return _pcm(_spawn_pop())
		"echo_ping":
			return _pcm(_echo_ping())
		"handoff":
			return _pcm(_handoff())
		"leak":
			return _pcm(_leak())
		"night_enter":
			return _pcm(_night_enter())
		"tension":
			return _pcm(_tension())
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
		"ambient_radio":
			return _pcm(_ambient_radio())
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


func _overlay(layers: Array) -> PackedFloat32Array:
	var n := 0
	for p in layers:
		n = maxi(n, (p as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in layers:
		var arr: PackedFloat32Array = p
		for i in arr.size():
			out[i] += arr[i]
	return out


func _overlay_offset(base: PackedFloat32Array, add: PackedFloat32Array, offset: int, gain: float = 1.0) -> PackedFloat32Array:
	var n := maxi(base.size(), offset + add.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in base.size():
		out[i] = base[i]
	for i in add.size():
		var j := offset + i
		if j >= 0 and j < n:
			out[j] += add[i] * gain
	return out


func _silence(sec: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	return out


func _noise_burst(sec: float, amp: float, color: float = 0.0) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	var lp := clampf(color, 0.0, 0.92)
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var env := exp(-t * 7.0)
		if t < 0.03:
			env *= t / 0.03
		var white := randf() * 2.0 - 1.0
		acc = acc * lp + white * (1.0 - lp)
		out[i] = acc * amp * env
	return out


func _body_thump(sec: float, amp: float, freq: float = 110.0) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := clampf(freq, 80.0, 180.0)
	var phase := 0.0
	var acc := 0.0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var env := exp(-t * 6.2)
		if t < 0.025:
			env *= t / 0.025
		var f := f0 * (1.0 - t * 0.32)
		phase += TAU * f / float(MIX_RATE)
		acc = acc * 0.90 + (randf() * 2.0 - 1.0) * 0.10
		out[i] = (sin(phase) * 0.78 + acc * 0.28) * amp * env
	return out


func _hiss(sec: float, amp: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var env := (1.0 - t) * (1.0 - t)
		if t < 0.06:
			env *= t / 0.06
		var white := randf() * 2.0 - 1.0
		prev = prev * 0.18 + white * 0.82
		out[i] = (white - prev * 0.62) * amp * env
	return out


func _with_reverb_tail(src: PackedFloat32Array, delay_sec: float, decay: float, copies: int) -> PackedFloat32Array:
	var delay := maxi(int(delay_sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(src.size() + delay * maxi(copies, 0))
	for i in src.size():
		out[i] = src[i]
	var gain := decay
	for _c in copies:
		var off := delay * (_c + 1)
		for i in src.size():
			out[off + i] += src[i] * gain
		gain *= decay
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
	## Click + noise burst + 80–180Hz body so shots read as guns, not beeps.
	var thin := freq >= 2000.0
	var click := _tone(freq, sec, amp * (0.40 if thin else 0.50), 0.22 if thin else 0.16)
	var burst := _noise_burst(maxf(sec * 0.90, 0.032), amp * (0.82 if thin else 0.74), 0.18 if thin else 0.40)
	var body_f := clampf(lerpf(92.0, 168.0, (freq - 700.0) / 1800.0), 80.0, 180.0)
	var body_amp := amp * (0.34 if thin else 0.64)
	var body_sec := clampf(sec * (1.35 if thin else 1.75), 0.08, 0.18)
	var body := _body_thump(body_sec, body_amp, body_f)
	return _overlay([click, burst, body])


func _mg_burst() -> PackedFloat32Array:
	return _concat([
		_crack(720.0, 0.028, 0.20),
		_silence(0.010),
		_crack(640.0, 0.026, 0.18),
		_silence(0.010),
		_crack(580.0, 0.030, 0.16),
	])


func _mg42_burst() -> PackedFloat32Array:
	return _concat([
		_crack(860.0, 0.016, 0.22),
		_silence(0.005),
		_crack(820.0, 0.015, 0.21),
		_silence(0.005),
		_crack(780.0, 0.015, 0.20),
		_silence(0.005),
		_crack(740.0, 0.015, 0.18),
		_silence(0.005),
		_crack(700.0, 0.018, 0.17),
	])


func _bolt_shot() -> PackedFloat32Array:
	return _concat([
		_crack(1550.0, 0.095, 0.18),
		_silence(0.045),
		_tone(380.0, 0.042, 0.12, 0.05),
		_tone(240.0, 0.055, 0.09, 0.04),
	])


func _garand_shot() -> PackedFloat32Array:
	return _concat([
		_crack(2100.0, 0.048, 0.18),
		_silence(0.018),
		_tone(2680.0, 0.038, 0.14, 0.01),
	])


func _shotgun_boom() -> PackedFloat32Array:
	return _overlay([
		_crack(620.0, 0.085, 0.22),
		_body_thump(0.16, 0.28, 88.0),
		_noise_burst(0.12, 0.22, 0.35),
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


func _tension() -> PackedFloat32Array:
	## Audible swell for last-runner and pending delayed waves (~35% louder).
	var swell := _concat([
		_blip(70.0, 160.0, 0.22, 0.30),
		_tone(180.0, 0.16, 0.25, 0.08),
		_blip(140.0, 280.0, 0.18, 0.22),
		_tone(90.0, 0.20, 0.16, 0.10),
	])
	return _overlay([swell, _rumble(0.76, 0.10, 55.0)])


func _escape() -> PackedFloat32Array:
	return _concat([
		_tone(740.0, 0.08, 0.16, 0.02),
		_silence(0.02),
		_tone(480.0, 0.12, 0.14, 0.03),
	])


func _fail() -> PackedFloat32Array:
	## Radio-static wash: descending pair + grit. Not the escape two-tone.
	return _concat([
		_tone(180.0, 0.08, 0.16, 0.10),
		_fall(220.0, 50.0, 0.22, 0.18),
		_tone(90.0, 0.10, 0.10, 0.08),
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


func _ui_click() -> PackedFloat32Array:
	return _concat([
		_tone(240.0, 0.018, 0.10, 0.02),
		_tone(420.0, 0.022, 0.08, 0.01),
	])


func _hit() -> PackedFloat32Array:
	return _tone(340.0, 0.018, 0.12, 0.16)


func _spawn_pop() -> PackedFloat32Array:
	return _concat([
		_tone(520.0, 0.028, 0.10, 0.04),
		_tone(780.0, 0.04, 0.08, 0.02),
	])


func _echo_ping() -> PackedFloat32Array:
	## Longer morse radio ping with a decaying copy as a short reverb tail.
	var ping := _concat([
		_tone(880.0, 0.065, 0.16, 0.04),
		_silence(0.048),
		_tone(880.0, 0.065, 0.15, 0.04),
		_silence(0.11),
		_tone(1320.0, 0.12, 0.14, 0.03),
		_silence(0.035),
		_tone(1760.0, 0.07, 0.07, 0.02),
	])
	var carrier := _tone(440.0, 0.58, 0.035, 0.02)
	return _with_reverb_tail(_overlay([ping, carrier]), 0.088, 0.36, 3)


func _handoff() -> PackedFloat32Array:
	## Page-turn rustle then a 3-note night sting. Not win_stinger's major flourish.
	return _concat([
		_noise_burst(0.055, 0.11, 0.12),
		_silence(0.018),
		_tone(277.0, 0.07, 0.14, 0.02),
		_silence(0.032),
		_tone(370.0, 0.08, 0.15, 0.015),
		_silence(0.038),
		_tone(554.0, 0.16, 0.13, 0.012),
	])


func _footstep(sec: float, amp: float) -> PackedFloat32Array:
	return _overlay([
		_body_thump(sec, amp, 90.0),
		_noise_burst(sec * 0.55, amp * 0.50, 0.62),
	])


func _leak() -> PackedFloat32Array:
	## Footsteps-out + radio hiss. Not the escape two-tone, not the fail rumble.
	var steps := _concat([
		_footstep(0.07, 0.18),
		_silence(0.055),
		_footstep(0.065, 0.16),
		_silence(0.065),
		_footstep(0.075, 0.14),
		_silence(0.075),
		_footstep(0.08, 0.11),
	])
	return _overlay_offset(steps, _hiss(0.58, 0.13), int(0.11 * MIX_RATE), 1.0)


func _night_enter() -> PackedFloat32Array:
	## Soft load sting under the ambient one-shot. Low fifth, not alarm.
	return _concat([
		_tone(196.0, 0.08, 0.08, 0.02),
		_tone(294.0, 0.12, 0.07, 0.015),
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


func _cricket_chirp(sec: float, amp: float, carrier: float) -> PackedFloat32Array:
	var n := maxi(int(sec * MIX_RATE), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var step := TAU * carrier / float(MIX_RATE)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var trill := 1.0 if sin(t * TAU * 28.0) > 0.12 else 0.0
		phase += step
		out[i] = sin(phase) * amp * _env(i, n) * trill
	return out


func _ambient_yard() -> PackedFloat32Array:
	## Cricket chirps over a mid yard drone.
	var chirps := _concat([
		_cricket_chirp(0.12, 0.075, 4300.0),
		_silence(0.08),
		_cricket_chirp(0.09, 0.058, 3920.0),
		_silence(0.15),
		_cricket_chirp(0.07, 0.046, 4550.0),
	])
	return _overlay([chirps, _tone(148.0, 0.58, 0.05, 0.025)])


func _ambient_warehouse() -> PackedFloat32Array:
	## Metal creak plus a ringing clang.
	var creak := _concat([
		_blip(280.0, 108.0, 0.30, 0.12),
		_tone(88.0, 0.16, 0.06, 0.10),
	])
	var clang := _overlay([
		_tone(1480.0, 0.22, 0.08, 0.03),
		_tone(2220.0, 0.16, 0.04, 0.02),
	])
	return _overlay_offset(creak, clang, int(0.10 * MIX_RATE), 1.0)


func _ambient_pump() -> PackedFloat32Array:
	## 58Hz electrical hum + buzz.
	return _overlay([
		_tone(58.0, 0.58, 0.09, 0.018),
		_tone(116.0, 0.58, 0.04, 0.01),
		_tone(174.0, 0.50, 0.018, 0.008),
		_hiss(0.58, 0.03),
	])


func _rail_click(sec: float, amp: float, freq: float) -> PackedFloat32Array:
	return _overlay([
		_tone(freq, sec, amp * 0.55, 0.08),
		_noise_burst(sec * 1.15, amp * 0.70, 0.22),
		_body_thump(sec * 1.35, amp * 0.32, 150.0),
	])


func _ambient_railcut() -> PackedFloat32Array:
	## Higher train-wheel clicks.
	return _concat([
		_rail_click(0.028, 0.13, 980.0),
		_silence(0.05),
		_rail_click(0.024, 0.11, 1180.0),
		_silence(0.07),
		_rail_click(0.022, 0.09, 1040.0),
		_silence(0.09),
		_rail_click(0.020, 0.07, 1320.0),
	])


func _ambient_depot() -> PackedFloat32Array:
	## Diesel idle rumble with a mechanical knock.
	return _overlay_offset(_rumble(0.64, 0.12, 36.0), _body_thump(0.14, 0.11, 82.0), int(0.24 * MIX_RATE), 1.0)


func _ambient_radio() -> PackedFloat32Array:
	## Morse on a thin carrier plus hiss.
	var morse := _concat([
		_tone(880.0, 0.05, 0.10, 0.04),
		_silence(0.05),
		_tone(880.0, 0.05, 0.10, 0.04),
		_silence(0.12),
		_tone(880.0, 0.12, 0.09, 0.04),
		_silence(0.08),
		_tone(880.0, 0.05, 0.08, 0.03),
		_silence(0.18),
	])
	return _overlay([
		_tone(1760.0, 0.72, 0.035, 0.012),
		morse,
		_hiss(0.72, 0.045),
	])
