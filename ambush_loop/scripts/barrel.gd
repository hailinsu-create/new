class_name ExplosiveBarrel
extends Node2D

const CombatFxScript := preload("res://scripts/fx/combat_fx.gd")

## Authored one-shot explosive. Triggers only from Main._sim_tick (never _process).
## Like tripwire: proximity during the freeze-plan watch, no mid-fight click detonate.

signal detonated(barrel: ExplosiveBarrel)

const TRIGGER_RADIUS := 22.0
const BLAST_RADIUS := 52.0
const OP_DAMAGE := 70.0

var armed: bool = true
var spent: bool = false
var _shimmer_t: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var blast: Polygon2D = $BlastPreview
@onready var tag: Label = $Tag


func _process(delta: float) -> void:
	if spent or not armed:
		return
	_shimmer_t += delta
	var s := 0.90 + 0.10 * sin(_shimmer_t * 3.4)
	if visual:
		visual.modulate = Color(s, s * 0.92, 0.82, 1.0)
	var lid := get_node_or_null("Lid") as Polygon2D
	if lid:
		lid.modulate = Color(1.05, 1.0, 0.9).lerp(Color(1.2, 1.05, 0.7), 0.5 + 0.5 * sin(_shimmer_t * 3.4))


func reset_fuse() -> void:
	armed = true
	spent = false
	_shimmer_t = 0.0
	if visual:
		visual.color = Color(0.98, 0.48, 0.08, 0.98)
		visual.modulate = Color.WHITE
		visual.scale = Vector2.ONE
	if blast:
		blast.visible = true
		blast.scale = Vector2.ONE
		blast.color = Color(0.98, 0.42, 0.08, 0.18)
	if tag:
		tag.text = "油桶"


func sim_check(active_enemies: Array, ops: Array) -> void:
	if not armed or spent:
		return
	for node in active_enemies:
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= TRIGGER_RADIUS:
				_detonate(active_enemies, ops)
				return


func _detonate(active_enemies: Array, ops: Array) -> void:
	spent = true
	armed = false
	if visual:
		visual.color = Color(0.32, 0.22, 0.14, 0.75)
		visual.modulate = Color.WHITE
	if blast:
		blast.color = Color(0.98, 0.5, 0.12, 0.4)
	if tag:
		tag.text = "油桶·已爆"
	detonated.emit(self)
	for node in active_enemies:
		if node is EnemyRunner and node.alive:
			if global_position.distance_to(node.global_position) <= BLAST_RADIUS:
				node.kill()
	for node in ops:
		if node is OperatorUnit and node.visible and node.alive:
			if global_position.distance_to(node.global_position) <= BLAST_RADIUS:
				node.take_damage(OP_DAMAGE, global_position)
	_play_blast_ring()
	if blast:
		blast.visible = false


func _play_blast_ring() -> void:
	var ring := Line2D.new()
	ring.name = "BlastRing"
	ring.width = 3.2
	ring.closed = true
	ring.default_color = Color(1.0, 0.62, 0.18, 0.9)
	ring.z_index = 6
	var pts := PackedVector2Array()
	for i in 17:
		var r := deg_to_rad(float(i) * 22.5)
		pts.append(Vector2(cos(r), sin(r)) * 10.0)
	ring.points = pts
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(5.6, 5.6), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(1.0, 0.55, 0.15, 0.35)
	fill.z_index = 5
	add_child(fill)
	var tw2 := fill.create_tween()
	tw2.tween_property(fill, "scale", Vector2(4.8, 4.8), 0.22)
	tw2.parallel().tween_property(fill, "modulate:a", 0.0, 0.22)
	tw2.tween_callback(fill.queue_free)
	var ring2 := Line2D.new()
	ring2.name = "BlastRing2"
	ring2.width = 1.6
	ring2.closed = true
	ring2.default_color = Color(1.0, 0.92, 0.55, 0.7)
	ring2.z_index = 6
	ring2.points = pts
	add_child(ring2)
	var tw3 := ring2.create_tween()
	tw3.tween_property(ring2, "scale", Vector2(7.2, 7.2), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw3.parallel().tween_property(ring2, "modulate:a", 0.0, 0.34)
	tw3.tween_callback(ring2.queue_free)
	if visual:
		visual.scale = Vector2(1.18, 0.82)
		var crush := visual.create_tween()
		crush.tween_property(visual, "scale", Vector2(1.05, 0.72), 0.12)
	CombatFxScript.barrel_boom(self, global_position)
