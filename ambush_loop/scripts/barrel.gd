class_name ExplosiveBarrel
extends Node2D

## Authored one-shot explosive. Triggers only from Main._sim_tick (never _process).
## Like tripwire: proximity during the freeze-plan watch, no mid-fight click detonate.

signal detonated(barrel: ExplosiveBarrel)

const TRIGGER_RADIUS := 22.0
const BLAST_RADIUS := 52.0
const OP_DAMAGE := 70.0

var armed: bool = true
var spent: bool = false

@onready var visual: Polygon2D = $Visual
@onready var blast: Polygon2D = $BlastPreview
@onready var tag: Label = $Tag


func reset_fuse() -> void:
	armed = true
	spent = false
	if visual:
		visual.color = Color(0.98, 0.48, 0.08, 0.98)
	if blast:
		blast.visible = true
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
	if blast:
		blast.visible = false
