class_name CoverSlot
extends Node2D

var slot_id: int = 0
var occupied_by: OperatorUnit = null
var label_text: String = ""

@onready var pad: Polygon2D = $Pad
@onready var tag: Label = $Tag


func setup(id: int, text: String) -> void:
	slot_id = id
	label_text = text
	if tag:
		tag.text = text


func is_free() -> bool:
	return occupied_by == null or not is_instance_valid(occupied_by)


func set_highlight(on: bool) -> void:
	if pad:
		pad.color = Color(0.35, 0.7, 0.45, 0.55) if on else Color(0.25, 0.45, 0.35, 0.35)
