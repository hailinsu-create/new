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


func setup(id: int, text: String, protect_face: float = 0.0) -> void:
	slot_id = id
	label_text = text
	protect_facing_deg = protect_face
	if tag:
		tag.text = text
	_ensure_protect_arc()
	rebuild_protect_arc()


func _ensure_protect_arc() -> void:
	if protect_arc != null and is_instance_valid(protect_arc):
		return
	protect_arc = get_node_or_null("ProtectArc") as Polygon2D
	if protect_arc == null:
		protect_arc = Polygon2D.new()
		protect_arc.name = "ProtectArc"
		protect_arc.z_index = -1
		add_child(protect_arc)


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
	if pad:
		pad.color = Color(0.35, 0.7, 0.45, 0.55) if on else Color(0.25, 0.45, 0.35, 0.35)


## emphasis: 0 hidden, 1 idle map hint, 2 selected/hovered.
func set_protect_preview(emphasis: int) -> void:
	_ensure_protect_arc()
	if protect_arc == null:
		return
	rebuild_protect_arc()
	match emphasis:
		2:
			protect_arc.visible = true
			protect_arc.color = Color(0.25, 0.95, 0.7, 0.32)
		1:
			protect_arc.visible = true
			protect_arc.color = Color(0.25, 0.7, 0.55, 0.14)
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
