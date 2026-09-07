class_name PlacedMine
extends Node2D

signal detonated(mine: PlacedMine)

const TRIGGER_RADIUS := 16.0
const BLAST_RADIUS := 36.0

var armed: bool = true
var spent: bool = false

@onready var visual: Polygon2D = $Visual
@onready var blast: Polygon2D = $Blast


func _ready() -> void:
	blast.visible = false


func _process(_delta: float) -> void:
	if not armed or spent:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= TRIGGER_RADIUS:
				_detonate()
				return


func _detonate() -> void:
	spent = true
	armed = false
	blast.visible = true
	visual.color = Color(0.2, 0.2, 0.2, 0.5)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyRunner and node.alive:
			if global_position.distance_to(node.global_position) <= BLAST_RADIUS:
				node.kill()
	detonated.emit(self)
	var tw := create_tween()
	tw.tween_property(blast, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: blast.visible = false)
