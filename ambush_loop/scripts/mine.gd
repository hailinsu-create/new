class_name Tripwire
extends Node2D

## Secondary logistics tool — not the main verb. One shot.
## Trigger checks run only from Main._sim_tick (fixed step), never from _process.

signal triggered

const RADIUS := 18.0

var armed: bool = true
var spent: bool = false

@onready var visual: Polygon2D = $Visual


func sim_check(active_enemies: Array) -> EnemyRunner:
	if not armed or spent:
		return null
	for node in active_enemies:
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= RADIUS:
				_trip(node)
				return node
	return null


func _trip(enemy: EnemyRunner) -> void:
	spent = true
	armed = false
	enemy.kill()
	if visual:
		visual.color = Color(0.3, 0.32, 0.3, 0.45)
	triggered.emit()
