class_name EnemyRunner
extends Node2D

signal escaped(enemy: EnemyRunner, path: PackedVector2Array)
signal died(enemy: EnemyRunner)

const SPEED := 70.0
const RECORD_DIST := 10.0
const MAX_HP := 100.0

var route: PackedVector2Array = PackedVector2Array()
var route_index: int = 0
var alive: bool = true
var active: bool = false
var hp: float = MAX_HP
var label_id: int = 0
var recorded: PackedVector2Array = PackedVector2Array()

@onready var body: Polygon2D = $Body
@onready var tag: Label = $Tag
@onready var hp_bar: Polygon2D = $HpBar


func setup(id: int, p_route: PackedVector2Array) -> void:
	label_id = id
	route = p_route.duplicate()
	add_to_group("enemies")
	if tag:
		tag.text = "敌%d" % id
	if route.size() > 0:
		global_position = route[0]
	recorded.append(global_position)
	_update_hp_bar()


func activate() -> void:
	active = true
	route_index = 1 if route.size() > 1 else 0


func _process(delta: float) -> void:
	if not active or not alive:
		return
	if route_index >= route.size():
		mark_escaped()
		return
	var target: Vector2 = route[route_index]
	global_position = global_position.move_toward(target, SPEED * delta)
	if global_position.distance_to(target) < 2.0:
		route_index += 1
	if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
		recorded.append(global_position)


func apply_fire(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		kill()


func kill() -> void:
	if not alive:
		return
	alive = false
	active = false
	if body:
		body.color = Color(0.35, 0.35, 0.38, 0.7)
	died.emit(self)


func mark_escaped() -> void:
	if not alive:
		return
	alive = false
	active = false
	recorded.append(global_position)
	escaped.emit(self, recorded.duplicate())


func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	var w := 24.0 * clampf(hp / MAX_HP, 0.0, 1.0)
	hp_bar.polygon = PackedVector2Array([
		Vector2(-12, -18), Vector2(-12 + w, -18), Vector2(-12 + w, -15), Vector2(-12, -15)
	])
	hp_bar.color = Color(0.2, 0.85, 0.35) if hp > 40.0 else Color(0.9, 0.25, 0.2)
