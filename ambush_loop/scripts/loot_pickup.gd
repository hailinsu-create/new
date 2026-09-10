class_name LootPickup
extends Node2D

## Ammo scavenged from a corpse. Auto-collected by nearby living operators.

var ammo_amount: int = 5
var collected: bool = false
var _t: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var tag: Label = $Tag


func setup(amount: int) -> void:
	ammo_amount = amount
	collected = false
	add_to_group("loot")
	if tag:
		tag.text = "+%d弹" % amount
	_ensure_pack_look()
	scale = Vector2(0.22, 0.22)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	set_process(true)


func _ensure_pack_look() -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	if visual.get_meta("pack_built", false):
		return
	visual.set_meta("pack_built", true)
	visual.polygon = PackedVector2Array([
		Vector2(-8, -6), Vector2(8, -6), Vector2(7, 8), Vector2(-7, 8)
	])
	visual.color = Color(0.78, 0.62, 0.18, 0.96)
	var strap := Polygon2D.new()
	strap.name = "Strap"
	strap.polygon = PackedVector2Array([
		Vector2(-6, -2), Vector2(6, -2), Vector2(6, 1), Vector2(-6, 1)
	])
	strap.color = Color(0.22, 0.16, 0.08, 0.9)
	add_child(strap)
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = PackedVector2Array([
		Vector2(-11, 6), Vector2(11, 6), Vector2(8, 12), Vector2(-8, 12)
	])
	glow.color = Color(0.95, 0.82, 0.28, 0.28)
	glow.z_index = -1
	glow.show_behind_parent = true
	add_child(glow)


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	var bob := sin(_t * 4.2) * 2.2
	if visual:
		visual.position.y = bob
	if tag:
		tag.position.y = -22.0 + bob * 0.4
	rotation = sin(_t * 1.6) * 0.08


func collect() -> int:
	if collected:
		return 0
	collected = true
	var gained := ammo_amount
	ammo_amount = 0
	visible = false
	queue_free()
	return gained
