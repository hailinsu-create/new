class_name RaidStash
extends Node2D

const Weapons := preload("res://scripts/raid/weapon_catalog.gd")

## Authored map crate. Walk onto it during SCOUT/SWEEP to take the kit.

const SEARCH_SECONDS := 0.4

var kind: String = "ammo"
var amount: int = 1
var collected: bool = false
var cell: Vector2i = Vector2i.ZERO
var _t: float = 0.0
var search_progress: float = 0.0

var visual: Polygon2D = null
var tag: Label = null


func setup(p_kind: String, p_amount: int, p_cell: Vector2i = Vector2i.ZERO) -> void:
	kind = p_kind
	amount = p_amount
	cell = p_cell
	collected = false
	add_to_group("stash")
	_ensure_look()
	if tag:
		tag.text = Weapons.tag_zh(kind)
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	set_process(true)


func _ensure_look() -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		add_child(visual)
	var col := Weapons.color(kind)
	visual.polygon = _kind_poly(kind)
	visual.color = Color(0.26, 0.18, 0.10, 0.96)
	var grain := get_node_or_null("Grain") as Polygon2D
	if grain == null:
		grain = Polygon2D.new()
		grain.name = "Grain"
		grain.polygon = PackedVector2Array([
			Vector2(-8, -2), Vector2(8, -2), Vector2(7, 0.6), Vector2(-7, 0.6)
		])
		add_child(grain)
	grain.color = Color(col.r * 0.35, col.g * 0.28, col.b * 0.18, 0.88)
	if tag == null:
		tag = get_node_or_null("Tag") as Label
	if tag == null:
		tag = Label.new()
		tag.name = "Tag"
		tag.position = Vector2(-18, -22)
		tag.add_theme_font_size_override("font_size", 11)
		add_child(tag)
	tag.add_theme_color_override("font_color", col.lightened(0.25))
	var lid := get_node_or_null("Lid") as Polygon2D
	if lid == null:
		lid = Polygon2D.new()
		lid.name = "Lid"
		lid.polygon = PackedVector2Array([
			Vector2(-10, -8), Vector2(10, -8), Vector2(8, -3), Vector2(-8, -3)
		])
		lid.color = Color(0.38, 0.26, 0.12, 0.92)
		add_child(lid)


func set_search_progress(p: float) -> void:
	search_progress = clampf(p, 0.0, 1.0)
	var lid := get_node_or_null("Lid") as Polygon2D
	if lid:
		lid.rotation = -0.85 * search_progress
		lid.position.y = -6.0 * search_progress
	if tag and search_progress > 0.02:
		tag.text = "开匣 %d%%" % int(round(search_progress * 100.0))
	elif tag:
		tag.text = Weapons.tag_zh(kind)


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	var bob := sin(_t * 3.4) * 1.6
	if search_progress > 0.02:
		bob *= 0.25
	if visual:
		visual.position.y = bob
	if tag:
		tag.position.y = -22.0 + bob * 0.4


func _kind_poly(id: String) -> PackedVector2Array:
	## Colorblind-safe silhouettes (shape + tag, not hue alone).
	var fam := Weapons.family_of(id)
	match fam:
		"mine":
			return PackedVector2Array([
				Vector2(0, -11), Vector2(8, -2), Vector2(5, 10), Vector2(-5, 10), Vector2(-8, -2)
			])
		"grenade":
			return PackedVector2Array([
				Vector2(-6, -10), Vector2(6, -10), Vector2(8, 4), Vector2(0, 11), Vector2(-8, 4)
			])
		"decoy":
			return PackedVector2Array([
				Vector2(0, -11), Vector2(9, 8), Vector2(-9, 8)
			])
		"mg":
			return PackedVector2Array([
				Vector2(-12, -6), Vector2(12, -6), Vector2(12, 8), Vector2(-12, 8)
			])
		"scout":
			return PackedVector2Array([
				Vector2(-4, -11), Vector2(4, -11), Vector2(4, 11), Vector2(-4, 11)
			])
		"shotgun":
			return PackedVector2Array([
				Vector2(-11, -5), Vector2(11, -8), Vector2(11, 8), Vector2(-11, 5)
			])
		"pistol":
			return PackedVector2Array([
				Vector2(-8, -6), Vector2(6, -6), Vector2(10, 0), Vector2(6, 8), Vector2(-8, 8)
			])
		"smg":
			return PackedVector2Array([
				Vector2(-10, -5), Vector2(8, -5), Vector2(8, 4), Vector2(-4, 4),
				Vector2(-8, 10), Vector2(-12, 10)
			])
		_:
			return PackedVector2Array([
				Vector2(-10, -8), Vector2(10, -8), Vector2(9, 10), Vector2(-9, 10)
			])


func take() -> Dictionary:
	if collected:
		return {}
	collected = true
	visible = false
	var out := {"kind": kind, "amount": amount, "cell": cell}
	queue_free()
	return out
