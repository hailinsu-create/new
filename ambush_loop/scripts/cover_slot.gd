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
		Vector2(-14, -11), Vector2(-8, -16), Vector2(8, -16), Vector2(14, -11),
		Vector2(14, 11), Vector2(8, 16), Vector2(-8, 16), Vector2(-14, 11)
	])
	pad.color = Color(0.30, 0.38, 0.24, 0.92)
	var shadow := Polygon2D.new()
	shadow.name = "CrateShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-16, 8), Vector2(16, 8), Vector2(13, 18), Vector2(-13, 18)
	])
	shadow.color = Color(0.04, 0.05, 0.04, 0.40)
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
	rebuild_protect_arc()
	match emphasis:
		2:
			protect_arc.visible = true
			protect_arc.color = Color(0.22, 0.95, 0.68, 0.38)
		1:
			protect_arc.visible = true
			protect_arc.color = Color(0.22, 0.78, 0.58, 0.20)
		_:
			protect_arc.visible = false


func protect_compass() -> String:
	var d := fposmod(protect_facing_deg, 360.0)
	if d >= 315.0 or d < 45.0:
		return "东"
	if d < 135.0:
		return "南"
	if d < 225.0:
		return "西"
	return "北"


func protects_from(attack_from: Vector2) -> bool:
	var to_atk := attack_from - global_position
	if to_atk.length() < 1.0:
		return true
	var ang := rad_to_deg(atan2(to_atk.y, to_atk.x))
	var d := fposmod(ang - protect_facing_deg + 180.0, 360.0) - 180.0
	return absf(d) <= protect_half_angle
