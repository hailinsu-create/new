class_name LootPickup
extends Node2D

const Weapons := preload("res://scripts/raid/weapon_catalog.gd")

## Ammo scavenged from a corpse. Auto-collected by nearby living operators.

var ammo_amount: int = 5
var kind: String = "ammo"
var collected: bool = false
var _t: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var tag: Label = $Tag


func setup(amount: int, p_kind: String = "ammo") -> void:
	ammo_amount = amount
	kind = p_kind if p_kind != "" else "ammo"
	collected = false
	add_to_group("loot")
	if tag:
		if kind == "ammo":
			tag.text = "+%d弹" % amount
		else:
			tag.text = Weapons.tag_zh(kind)
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
		Vector2(-9, -7), Vector2(9, -7), Vector2(8, 9), Vector2(-8, 9)
	])
	visual.color = Weapons.color(kind)
	var strap := Polygon2D.new()
	strap.name = "Strap"
	strap.polygon = PackedVector2Array([
		Vector2(-7, -2), Vector2(7, -2), Vector2(7, 1.4), Vector2(-7, 1.4)
	])
	strap.color = Color(0.20, 0.14, 0.07, 0.92)
	add_child(strap)
	var brass := Polygon2D.new()
	brass.name = "Brass"
	brass.polygon = PackedVector2Array([
		Vector2(-5, 2), Vector2(-2, 2), Vector2(-2, 7), Vector2(-5, 7)
	])
	brass.color = Color(0.92, 0.74, 0.28, 0.95)
	brass.z_index = 1
	add_child(brass)
	var brass2 := Polygon2D.new()
	brass2.name = "Brass2"
	brass2.polygon = PackedVector2Array([
		Vector2(1, 2), Vector2(4, 2), Vector2(4, 7), Vector2(1, 7)
	])
	brass2.color = Color(0.86, 0.68, 0.22, 0.95)
	brass2.z_index = 1
	add_child(brass2)
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = PackedVector2Array([
		Vector2(-12, 6), Vector2(12, 6), Vector2(9, 13), Vector2(-9, 13)
	])
	glow.color = Color(0.95, 0.82, 0.28, 0.32)
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


func collect_item() -> Dictionary:
	if collected:
		return {}
	var out := {"kind": kind, "amount": ammo_amount}
	collect()
	return out
