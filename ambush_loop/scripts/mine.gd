class_name Tripwire
extends Node2D

## Secondary logistics tool — not the main verb. One shot.

signal triggered

const RADIUS := 18.0

var armed: bool = true
var spent: bool = false

@onready var visual: Polygon2D = $Visual


func _process(_delta: float) -> void:
	if not armed or spent:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= RADIUS:
				_trip(node)
				return


func _trip(enemy: EnemyRunner) -> void:
	spent = true
	armed = false
	enemy.kill()
	if visual:
		visual.color = Color(0.3, 0.3, 0.3, 0.5)
	triggered.emit()
