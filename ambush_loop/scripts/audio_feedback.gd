class_name AmbushAudioFeedback
extends Node

## Small procedural tones keep the first-run feedback self-contained and avoid
## unlicensed audio assets.

var player: AudioStreamPlayer
var stream: AudioStreamGenerator
var volume := 0.75
var enabled := true
var _last_beep_msec := 0
var _last_kind := ""


func _ready() -> void:
	player = AudioStreamPlayer.new()
	stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.18
	player.stream = stream
	add_child(player)


func configure(next_volume: float) -> void:
	volume = clampf(next_volume, 0.0, 1.0)
	if player:
		player.volume_db = linear_to_db(maxf(volume, 0.0001))


func beep(kind: String) -> void:
	if not enabled or volume <= 0.001 or player == null:
		return
	var now := Time.get_ticks_msec()
	# A burst of fixed ticks at 2x must not turn procedural feedback into noise.
	if kind == _last_kind and now - _last_beep_msec < 45:
		return
	_last_beep_msec = now
	_last_kind = kind
	var frequency := 440.0
	var duration := 0.07
	var amplitude := 0.12
	match kind:
		"select":
			frequency = 560.0
			duration = 0.05
			amplitude = 0.08
		"alarm":
			frequency = 180.0
			duration = 0.16
			amplitude = 0.16
		"success":
			frequency = 760.0
			duration = 0.18
			amplitude = 0.14
		"fail":
			frequency = 220.0
			duration = 0.18
			amplitude = 0.14
		"friendly_fire":
			frequency = 720.0
			duration = 0.035
			amplitude = 0.09
		"enemy_fire":
			frequency = 310.0
			duration = 0.045
			amplitude = 0.10
		"empty":
			frequency = 130.0
			duration = 0.06
			amplitude = 0.08
		"hit":
			frequency = 880.0
			duration = 0.03
			amplitude = 0.07
		"loot":
			frequency = 980.0
			duration = 0.07
			amplitude = 0.08
		"escape":
			frequency = 150.0
			duration = 0.12
			amplitude = 0.13
	if not player.playing:
		player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_count := int(stream.mix_rate * duration)
	for i in frame_count:
		var t := float(i) / stream.mix_rate
		var envelope := 1.0 - float(i) / float(maxi(frame_count, 1))
		var value := sin(TAU * frequency * t) * amplitude * envelope
		playback.push_frame(Vector2(value, value))
