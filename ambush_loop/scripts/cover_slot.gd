class_name CoverSlot
extends Node2D

var slot_id: int = 0
var occupied_by: OperatorUnit = null
var label_text: String = ""
## Degrees: attacks from this facing get cover mitigation (blueprint P2).
var protect_facing_deg: float = 0.0
var protect_half_angle: float = 70.0

const PREVIEW_RANGE := 64.0
const PREVIEW_RAYS := 10

@onready var pad: Polygon2D = $Pad
@onready var tag: Label = $Tag

var protect_arc: Polygon2D = null
var _crate_bits: Array[Polygon2D] = []
var _lock_mark: Label = null
var _fire_lean: Vector2 = Vector2.ZERO
var _arc_edge: Line2D = null
var _arc_arrow: Polygon2D = null
var _hold_ring: Line2D = null
var _emphasis: int = 0
var _pulse_t: float = 0.0
var _hold_p: float = 0.0


func setup(id: int, text: String, protect_face: float = 0.0) -> void:
	slot_id = id
	label_text = text
	protect_facing_deg = protect_face
	if tag:
		tag.text = text
	_ensure_crate_look()
	_ensure_protect_arc()
	rebuild_protect_arc()
	set_highlight(false)
	set_process(false)


func _ensure_crate_look() -> void:
	if pad == null:
		pad = get_node_or_null("Pad") as Polygon2D
	if pad == null:
		return
	if pad.get_meta("crate_built", false):
		return
	pad.set_meta("crate_built", true)
	# Stacked sandbag / crate silhouette. Pad stays the hit-tint target.
	pad.polygon = PackedVector2Array([
		Vector2(-17, -13), Vector2(-10, -19), Vector2(10, -19), Vector2(17, -13),
		Vector2(17, 14), Vector2(10, 19), Vector2(-10, 19), Vector2(-17, 14)
	])
	pad.color = Color(0.28, 0.36, 0.22, 0.94)
	var shadow := Polygon2D.new()
	shadow.name = "CrateShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-16, 8), Vector2(20, 8), Vector2(16, 24), Vector2(-14, 24)
	])
	shadow.color = Color(0.03, 0.04, 0.03, 0.55)
	shadow.z_index = -1
	shadow.show_behind_parent = true
	add_child(shadow)
	_crate_bits.append(shadow)
	var rim := Polygon2D.new()
	rim.name = "CrateRim"
	rim.polygon = PackedVector2Array([
		Vector2(-12, -15), Vector2(12, -15), Vector2(11, -11), Vector2(-11, -11)
	])
	rim.color = Color(0.55, 0.62, 0.38, 0.85)
	rim.z_index = 1
	add_child(rim)
	_crate_bits.append(rim)
	var plank := Polygon2D.new()
	plank.name = "CratePlank"
	plank.polygon = PackedVector2Array([
		Vector2(-11, -3), Vector2(11, -3), Vector2(11, 3), Vector2(-11, 3)
	])
	plank.color = Color(0.18, 0.14, 0.08, 0.75)
	plank.z_index = 1
	add_child(plank)
	_crate_bits.append(plank)
	var bag_a := Polygon2D.new()
	bag_a.name = "SandbagA"
	bag_a.polygon = PackedVector2Array([
		Vector2(-15, 3), Vector2(-1, 1), Vector2(2, 9), Vector2(-13, 13)
	])
	bag_a.color = Color(0.44, 0.40, 0.22, 0.92)
	bag_a.z_index = 1
	add_child(bag_a)
	_crate_bits.append(bag_a)
	var bag_b := Polygon2D.new()
	bag_b.name = "SandbagB"
	bag_b.polygon = PackedVector2Array([
		Vector2(1, 1), Vector2(15, 3), Vector2(13, 13), Vector2(-1, 9)
	])
	bag_b.color = Color(0.38, 0.34, 0.18, 0.92)
	bag_b.z_index = 1
	add_child(bag_b)
	_crate_bits.append(bag_b)
	var bag_c := Polygon2D.new()
	bag_c.name = "SandbagC"
	bag_c.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -10), Vector2(9, -2), Vector2(-9, -1)
	])
	bag_c.color = Color(0.40, 0.36, 0.20, 0.90)
	bag_c.z_index = 1
	add_child(bag_c)
	_crate_bits.append(bag_c)
	var bag_d := Polygon2D.new()
	bag_d.name = "SandbagD"
	bag_d.polygon = PackedVector2Array([
		Vector2(-8, -16), Vector2(8, -17), Vector2(7, -11), Vector2(-7, -10)
	])
	bag_d.color = Color(0.46, 0.42, 0.24, 0.90)
	bag_d.z_index = 2
	add_child(bag_d)
	_crate_bits.append(bag_d)
	var strap := Polygon2D.new()
	strap.name = "BagStrap"
	strap.polygon = PackedVector2Array([
		Vector2(-2, -17), Vector2(2, -17), Vector2(2, 12), Vector2(-2, 12)
	])
	strap.color = Color(0.16, 0.12, 0.07, 0.55)
	strap.z_index = 2
	add_child(strap)
	_crate_bits.append(strap)


func _ensure_protect_arc() -> void:
	if protect_arc != null and is_instance_valid(protect_arc):
		return
	protect_arc = get_node_or_null("ProtectArc") as Polygon2D
	if protect_arc == null:
		protect_arc = Polygon2D.new()
		protect_arc.name = "ProtectArc"
		# Behind the crate pad, but keep world z with the slot so the cyan
		# fan stays above MapDraw (floor grain).
		protect_arc.z_index = 0
		protect_arc.z_as_relative = true
		protect_arc.show_behind_parent = true
		add_child(protect_arc)
		move_child(protect_arc, 0)


func rebuild_protect_arc() -> void:
	_ensure_protect_arc()
	if protect_arc == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(PREVIEW_RAYS + 1):
		var t := lerpf(-protect_half_angle, protect_half_angle, float(i) / float(PREVIEW_RAYS))
		var rad := deg_to_rad(protect_facing_deg + t)
		pts.append(Vector2(cos(rad), sin(rad)) * PREVIEW_RANGE)
	protect_arc.polygon = pts
	_rebuild_arc_edge(pts)


func is_free() -> bool:
	return occupied_by == null or not is_instance_valid(occupied_by)


func set_highlight(on: bool) -> void:
	_ensure_crate_look()
	if pad:
		pad.color = Color(0.42, 0.62, 0.34, 0.95) if on else Color(0.30, 0.38, 0.24, 0.92)
	for bit in _crate_bits:
		if bit != null and is_instance_valid(bit):
			bit.modulate = Color(1.15, 1.2, 1.05) if on else Color.WHITE


func set_plan_lock(on: bool) -> void:
	if _lock_mark == null or not is_instance_valid(_lock_mark):
		_lock_mark = get_node_or_null("LockMark") as Label
	if _lock_mark == null:
		_lock_mark = Label.new()
		_lock_mark.name = "LockMark"
		_lock_mark.text = "锁"
		_lock_mark.position = Vector2(-10, -30)
		_lock_mark.add_theme_font_size_override("font_size", 13)
		_lock_mark.add_theme_color_override("font_color", Color(1.0, 0.28, 0.16))
		_lock_mark.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.02, 0.95))
		_lock_mark.add_theme_constant_override("shadow_offset_x", 1)
		_lock_mark.add_theme_constant_override("shadow_offset_y", 1)
		_lock_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_mark.z_index = 4
		add_child(_lock_mark)
	_lock_mark.visible = on
	if on:
		_lock_mark.modulate = Color(1.35, 0.55, 0.35)


## emphasis: 0 hidden, 1 idle map hint, 2 selected/hovered.
func set_protect_preview(emphasis: int) -> void:
	_ensure_protect_arc()
	if protect_arc == null:
		return
	_emphasis = emphasis
	rebuild_protect_arc()
	match emphasis:
		2:
			protect_arc.visible = true
			protect_arc.color = Color(0.22, 0.95, 0.68, 0.46)
			if _arc_edge:
				_arc_edge.visible = true
			if _arc_arrow:
				_arc_arrow.visible = true
			set_process(true)
		1:
			protect_arc.visible = true
			protect_arc.color = Color(0.22, 0.78, 0.58, 0.26)
			if _arc_edge:
				_arc_edge.visible = true
				_arc_edge.default_color = Color(0.32, 0.92, 0.68, 0.55)
			if _arc_arrow:
				_arc_arrow.visible = true
				_arc_arrow.color = Color(0.32, 0.88, 0.62, 0.62)
		_:
			protect_arc.visible = false
			if _arc_edge:
				_arc_edge.visible = false
			if _arc_arrow:
				_arc_arrow.visible = false
	_maybe_idle_process()


func protect_compass() -> String:
	var d := fposmod(protect_facing_deg, 360.0)
	if d >= 315.0 or d < 45.0:
		return "东"
	if d < 135.0:
		return "南"
	if d < 225.0:
		return "西"
	return "北"


func kick_fire_lean(facing_deg: float, heavy: bool = false) -> void:
	## Visual peek: crate shifts toward the occupant's facing on a burst. Does not move the slot.
	var dist := 2.2 if heavy else 1.35
	var rad := deg_to_rad(facing_deg)
	_fire_lean = Vector2(cos(rad), sin(rad)) * dist
	set_process(true)


func set_hold_progress(p: float) -> void:
	_hold_p = clampf(p, 0.0, 1.0)
	_ensure_hold_ring()
	if _hold_ring == null:
		return
	if _hold_p <= 0.02:
		_hold_ring.visible = false
		_maybe_idle_process()
		return
	_hold_ring.visible = true
	var pts := PackedVector2Array()
	var rays := 18
	var span := TAU * _hold_p
	for i in range(rays + 1):
		var a := -PI * 0.5 + span * (float(i) / float(rays))
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	_hold_ring.points = pts
	_hold_ring.default_color = Color(0.95, 0.86, 0.38, 0.45 + 0.50 * _hold_p)
	set_process(true)


func _ensure_hold_ring() -> void:
	if _hold_ring != null and is_instance_valid(_hold_ring):
		return
	_hold_ring = Line2D.new()
	_hold_ring.name = "HoldRing"
	_hold_ring.width = 3.2
	_hold_ring.closed = false
	_hold_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_hold_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	_hold_ring.z_index = 5
	_hold_ring.visible = false
	add_child(_hold_ring)


func _rebuild_arc_edge(fan: PackedVector2Array) -> void:
	if fan.size() < 3:
		return
	if _arc_edge == null or not is_instance_valid(_arc_edge):
		_arc_edge = Line2D.new()
		_arc_edge.name = "ProtectEdge"
		_arc_edge.width = 2.6
		_arc_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_arc_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		_arc_edge.joint_mode = Line2D.LINE_JOINT_ROUND
		_arc_edge.z_index = 0
		_arc_edge.z_as_relative = true
		_arc_edge.show_behind_parent = true
		add_child(_arc_edge)
		move_child(_arc_edge, 0)
	var loop := PackedVector2Array()
	loop.append(Vector2.ZERO)
	for i in range(1, fan.size()):
		loop.append(fan[i])
	loop.append(Vector2.ZERO)
	_arc_edge.points = loop
	_arc_edge.default_color = Color(0.28, 0.95, 0.72, 0.78 if _emphasis >= 2 else 0.50)
	_arc_edge.visible = _emphasis > 0
	if _arc_arrow == null or not is_instance_valid(_arc_arrow):
		_arc_arrow = Polygon2D.new()
		_arc_arrow.name = "ProtectArrow"
		_arc_arrow.z_index = 1
		_arc_arrow.show_behind_parent = true
		add_child(_arc_arrow)
	var rad := deg_to_rad(protect_facing_deg)
	var tip := Vector2(cos(rad), sin(rad)) * (PREVIEW_RANGE + 6.0)
	var back := Vector2(cos(rad), sin(rad)) * (PREVIEW_RANGE - 10.0)
	var perp := Vector2(-sin(rad), cos(rad)) * 7.0
	_arc_arrow.polygon = PackedVector2Array([tip, back + perp, back - perp])
	_arc_arrow.color = Color(0.35, 0.98, 0.72, 0.75 if _emphasis >= 2 else 0.42)
	_arc_arrow.visible = _emphasis > 0


func _maybe_idle_process() -> void:
	if _fire_lean.length_squared() > 0.04 or _emphasis >= 2 or _hold_p > 0.02:
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_fire_lean = _fire_lean.lerp(Vector2.ZERO, 1.0 - exp(-delta * 10.0))
	if pad:
		pad.position = _fire_lean
	if _emphasis >= 2:
		_pulse_t += delta
		var wave := 0.5 + 0.5 * sin(_pulse_t * 4.8)
		if protect_arc:
			protect_arc.color = Color(0.22, 0.95, 0.68, 0.28 + 0.18 * wave)
		if _arc_edge:
			_arc_edge.default_color = Color(0.40, 1.0, 0.78, 0.50 + 0.32 * wave)
		if _arc_arrow:
			_arc_arrow.color = Color(0.45, 1.0, 0.78, 0.62 + 0.28 * wave)
	if _fire_lean.length_squared() < 0.04:
		_fire_lean = Vector2.ZERO
		if pad:
			pad.position = Vector2.ZERO
	_maybe_idle_process()


func protects_from(attack_from: Vector2) -> bool:
	var to_atk := attack_from - global_position
	if to_atk.length() < 1.0:
		return true
	var ang := rad_to_deg(atan2(to_atk.y, to_atk.x))
	var d := fposmod(ang - protect_facing_deg + 180.0, 360.0) - 180.0
	return absf(d) <= protect_half_angle
