class_name CoverSlot
extends Node2D

var slot_id: int = 0
var occupied_by: OperatorUnit = null
var label_text: String = ""
## Degrees: attacks from this facing get cover mitigation (blueprint P2).
var protect_facing_deg: float = 0.0
var protect_half_angle: float = 70.0

@onready var pad: Polygon2D = $Pad
@onready var tag: Label = $Tag


func setup(id: int, text: String, protect_face: float = 0.0) -> void:
	slot_id = id
	label_text = text
	protect_facing_deg = protect_face
	if tag:
		tag.text = text


func is_free() -> bool:
	return occupied_by == null or not is_instance_valid(occupied_by)


func set_highlight(on: bool) -> void:
	if pad:
		pad.color = Color(0.35, 0.7, 0.45, 0.55) if on else Color(0.25, 0.45, 0.35, 0.35)


func protects_from(attack_from: Vector2) -> bool:
	var to_atk := attack_from - global_position
	if to_atk.length() < 1.0:
		return true
	var ang := rad_to_deg(atan2(to_atk.y, to_atk.x))
	var d := fposmod(ang - protect_facing_deg + 180.0, 360.0) - 180.0
	return absf(d) <= protect_half_angle
