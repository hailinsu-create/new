class_name LootPickup
extends Node2D

## Ammo scavenged from a corpse. Auto-collected by nearby living operators.

var ammo_amount: int = 5
var collected: bool = false

@onready var visual: Polygon2D = $Visual
@onready var tag: Label = $Tag


func setup(amount: int) -> void:
	ammo_amount = amount
	collected = false
	add_to_group("loot")
	if tag:
		tag.text = "+%d弹" % amount


func collect() -> int:
	if collected:
		return 0
	collected = true
	var gained := ammo_amount
	ammo_amount = 0
	visible = false
	queue_free()
	return gained
