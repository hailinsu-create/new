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
		Vector2(-10, -8), Vector2(10, -8), Vector2(9, 10), Vector2(-9, 10)
	])
	visual.color = Color(0.28, 0.20, 0.10, 0.96)
	var lid := Polygon2D.new()
	lid.name = "BoxLid"
	lid.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8), Vector2(8, -4), Vector2(-8, -4)
	])
	lid.color = Color(0.36, 0.26, 0.12, 0.94)
	add_child(lid)
	var strap := Polygon2D.new()
	strap.name = "Strap"
	strap.polygon = PackedVector2Array([
		Vector2(-7, -2), Vector2(7, -2), Vector2(7, 1.4), Vector2(-7, 1.4)
	])
	strap.color = Color(0.18, 0.12, 0.06, 0.92)
	add_child(strap)
	var stencil := Polygon2D.new()
	stencil.name = "Stencil"
	stencil.polygon = PackedVector2Array([
		Vector2(-6, 2), Vector2(6, 2), Vector2(5.4, 6.5), Vector2(-5.4, 6.5)
	])
	stencil.color = Weapons.color(kind)
	stencil.z_index = 1
	add_child(stencil)
	var brass := Polygon2D.new()
	brass.name = "Brass"
	brass.polygon = PackedVector2Array([
		Vector2(-5, 3), Vector2(-2, 3), Vector2(-2, 8), Vector2(-5, 8)
	])
	brass.color = Color(0.72, 0.56, 0.22, 0.95)
	brass.z_index = 2
	add_child(brass)
	var brass2 := Polygon2D.new()
	brass2.name = "Brass2"
	brass2.polygon = PackedVector2Array([
		Vector2(1, 3), Vector2(4, 3), Vector2(4, 8), Vector2(1, 8)
	])
	brass2.color = Color(0.68, 0.52, 0.18, 0.95)
	brass2.z_index = 2
	add_child(brass2)
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = PackedVector2Array([
		Vector2(-12, 6), Vector2(12, 6), Vector2(9, 13), Vector2(-9, 13)
	])
	glow.color = Color(0.55, 0.42, 0.16, 0.28)
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
