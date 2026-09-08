class_name SfxBus
extends Node

## Tiny procedural WAV beeps — no asset files. Mute with M.

const MIX_RATE := 22050
const CUES := [
	"alarm", "fire", "return_fire", "empty", "loot", "op_death", "escape", "win"
]

var muted: bool = false
var last_cue: String = ""
var _players: Dictionary = {}


func _ready() -> void:
	for cue in CUES:
		var p := AudioStreamPlayer.new()
		p.name = "Cue_%s" % cue
		p.stream = _build_stream(cue)
		p.volume_db = _gain(cue)
		p.bus = "Master"
		add_child(p)
		_players[cue] = p


func play(cue: String) -> void:
	last_cue = cue
	if muted:
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


func _gain(cue: String) -> float:
	match cue:
		"alarm":
			return -12.0
		"win":
			return -14.0
		"escape", "op_death":
			return -11.0
		"fire", "return_fire":
			return -16.0
		_:
			return -15.0


func _build_stream(cue: String) -> AudioStreamWAV:
	match cue:
		"alarm":
			return _pcm(_siren())
		"fire":
			return _pcm(_crack(1900.0, 0.055, 0.20))
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


func _crack(freq: float, sec: float, amp: float) -> PackedFloat32Array:
	return _tone(freq, sec, amp, 0.12)


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
