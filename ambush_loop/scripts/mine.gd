class_name Tripwire
extends Node2D

const CombatFxScript := preload("res://scripts/fx/combat_fx.gd")

## Secondary logistics tool — not the main verb. One shot.
## Trigger checks run only from Main._sim_tick (fixed step), never from _process.

signal triggered

const RADIUS := 18.0

var armed: bool = true
var spent: bool = false
var _pulse_t: float = 0.0

@onready var visual: Polygon2D = $Visual


func _process(delta: float) -> void:
	_pulse_t += delta
	if spent or not armed:
		return
	var wave := 0.5 + 0.5 * sin(_pulse_t * 4.2)
	var pulse := Color(1.0, 1.0, 1.0, 0.72 + 0.28 * wave)
	if visual:
		visual.modulate = pulse
	var wire := get_node_or_null("Wire") as Line2D
	if wire:
		wire.modulate = pulse
		wire.width = 1.2 + 0.5 * wave
	var peg_a := get_node_or_null("PegA") as Polygon2D
	var peg_b := get_node_or_null("PegB") as Polygon2D
	if peg_a:
		peg_a.modulate = Color(1.0, 1.05, 1.0).lerp(Color(1.15, 1.25, 0.95), wave * 0.5)
	if peg_b:
		peg_b.modulate = Color(1.0, 1.05, 1.0).lerp(Color(1.15, 1.25, 0.95), wave * 0.5)


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
		visual.modulate = Color.WHITE
	var wire := get_node_or_null("Wire") as Line2D
	if wire:
		wire.default_color = Color(0.32, 0.34, 0.30, 0.45)
		wire.modulate = Color.WHITE
		wire.width = 1.2
	var peg_a := get_node_or_null("PegA") as Polygon2D
	var peg_b := get_node_or_null("PegB") as Polygon2D
	if peg_a:
		peg_a.modulate = Color(0.55, 0.55, 0.52)
	if peg_b:
		peg_b.modulate = Color(0.55, 0.55, 0.52)
	CombatFxScript.trip_snap(self, global_position)
	triggered.emit()
