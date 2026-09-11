extends SceneTree

## Headless PCM probe: peak/rms/duration for every cue. Writes /tmp/ambush_cues.
## Dummy never plays(); this only reads pooled AudioStreamWAV bytes.

const OUT_DIR := "/tmp/ambush_cues"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var Sfx := load("res://scripts/sfx/sfx_bus.gd") as GDScript
	var bus = Sfx.new()
	bus.name = "ProbeBus"
	root.add_child(bus)
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var n := 0
	for cue in Sfx.CUES:
		if not bus.has_cue(cue):
			push_error("PROBE_MISSING %s" % cue)
			quit(2)
			return
		var peak: float = float(bus.cue_peak(cue))
		var dur: float = float(bus.cue_duration_sec(cue))
		var st: AudioStreamWAV = bus._pooled_stream(cue)
		var rms := _rms(st)
		_write_wav(st, "%s/%s.wav" % [OUT_DIR, cue])
		print(
			"PROBE ", cue,
			" peak=", snapped(peak, 0.001),
			" rms=", snapped(rms, 0.001),
			" sec=", snapped(dur, 0.001)
		)
		n += 1
	print("PROBE_OK n=", n, " dir=", OUT_DIR)
	quit(0)


func _rms(st: AudioStreamWAV) -> float:
	if st == null or st.data.is_empty():
		return 0.0
	var acc := 0.0
	var count := 0
	var i := 0
	var data: PackedByteArray = st.data
	while i + 1 < data.size():
		var s := float(data.decode_s16(i)) / 32767.0
		acc += s * s
		count += 1
		i += 2
	if count <= 0:
		return 0.0
	return sqrt(acc / float(count))


func _write_wav(st: AudioStreamWAV, path: String) -> void:
	if st == null:
		return
	var pcm: PackedByteArray = st.data
	var rate := st.mix_rate
	var data_bytes := pcm.size()
	var hdr := PackedByteArray()
	hdr.resize(44)
	# RIFF
	hdr.encode_u8(0, "R".unicode_at(0))
	hdr.encode_u8(1, "I".unicode_at(0))
	hdr.encode_u8(2, "F".unicode_at(0))
	hdr.encode_u8(3, "F".unicode_at(0))
	hdr.encode_u32(4, 36 + data_bytes)
	hdr.encode_u8(8, "W".unicode_at(0))
	hdr.encode_u8(9, "A".unicode_at(0))
	hdr.encode_u8(10, "V".unicode_at(0))
	hdr.encode_u8(11, "E".unicode_at(0))
	hdr.encode_u8(12, "f".unicode_at(0))
	hdr.encode_u8(13, "m".unicode_at(0))
	hdr.encode_u8(14, "t".unicode_at(0))
	hdr.encode_u8(15, " ".unicode_at(0))
	hdr.encode_u32(16, 16)
	hdr.encode_u16(20, 1)
	hdr.encode_u16(22, 1)
	hdr.encode_u32(24, rate)
	hdr.encode_u32(28, rate * 2)
	hdr.encode_u16(32, 2)
	hdr.encode_u16(34, 16)
	hdr.encode_u8(36, "d".unicode_at(0))
	hdr.encode_u8(37, "a".unicode_at(0))
	hdr.encode_u8(38, "t".unicode_at(0))
	hdr.encode_u8(39, "a".unicode_at(0))
	hdr.encode_u32(40, data_bytes)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("PROBE_WRITE %s" % path)
		return
	f.store_buffer(hdr)
	f.store_buffer(pcm)
	f.close()
