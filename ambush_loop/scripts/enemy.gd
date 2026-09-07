class_name EnemyRunner
extends Node2D

signal escaped(enemy: EnemyRunner, path: PackedVector2Array)
signal died(enemy: EnemyRunner)
signal return_fired(from: EnemyRunner, to: OperatorUnit)

const SPEED := 70.0
const ALERT_SPEED := 32.0
const RECORD_DIST := 10.0
const MAX_HP := 100.0
const RETURN_RANGE := 200.0
const RETURN_DAMAGE := 14.0
const RETURN_INTERVAL := 0.28

var route: PackedVector2Array = PackedVector2Array()
var route_index: int = 0
var alive: bool = true
var active: bool = false
var alerted: bool = false
var hp: float = MAX_HP
var label_id: int = 0
var recorded: PackedVector2Array = PackedVector2Array()
var focus_target: OperatorUnit = null
var loot_ammo: int = 2
var grid: AmbushGrid = null
var return_cd: float = 0.0
var returning_fire: bool = false

@onready var body: Polygon2D = $Body
@onready var tag: Label = $Tag
@onready var hp_bar: Polygon2D = $HpBar


func setup(id: int, p_route: PackedVector2Array, p_grid: AmbushGrid = null, p_loot: int = 2) -> void:
	label_id = id
	route = p_route.duplicate()
	grid = p_grid
	loot_ammo = p_loot
	alive = true
	active = false
	alerted = false
	returning_fire = false
	hp = MAX_HP
	focus_target = null
	return_cd = 0.0
	add_to_group("enemies")
	if tag:
		tag.text = "敌%d" % id
	if route.size() > 0:
		global_position = route[0]
	recorded.clear()
	recorded.append(global_position)
	_update_hp_bar()


func activate() -> void:
	active = true
	route_index = 1 if route.size() > 1 else 0


func sim_step(delta: float) -> void:
	if not active or not alive:
		return

	return_cd = maxf(return_cd - delta, 0.0)
	returning_fire = false
	_try_return_fire()

	if body:
		body.color = Color(0.95, 0.45, 0.15) if returning_fire else Color(0.75, 0.22, 0.2)

	if route_index >= route.size():
		mark_escaped()
		return

	var speed := ALERT_SPEED if alerted else SPEED
	var target: Vector2 = route[route_index]
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_to(target) < 2.0:
		route_index += 1
	if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
		recorded.append(global_position)


func _try_return_fire() -> void:
	if not alerted:
		return
	if focus_target == null or not is_instance_valid(focus_target) or not focus_target.alive:
		focus_target = null
		return
	var dist := global_position.distance_to(focus_target.global_position)
	if dist > RETURN_RANGE:
		return
	if grid != null and not grid.has_los(global_position, focus_target.global_position):
		return
	if return_cd > 0.0:
		returning_fire = true # still aiming / in contact
		return
	return_cd = RETURN_INTERVAL
	returning_fire = true
	focus_target.take_damage(RETURN_DAMAGE, global_position)
	return_fired.emit(self, focus_target)


func apply_fire(amount: float, from: OperatorUnit = null) -> void:
	if not alive:
		return
	hp -= amount
	alerted = true
	if from != null:
		focus_target = from
	_update_hp_bar()
	if tag:
		tag.text = "敌%d!" % label_id
	if hp <= 0.0:
		kill()


func kill() -> void:
	if not alive:
		return
	alive = false
	active = false
	alerted = false
	returning_fire = false
	if body:
		body.color = Color(0.35, 0.35, 0.38, 0.7)
	if tag:
		tag.text = "敌%d 尸体" % label_id
	died.emit(self)


func mark_escaped() -> void:
	if not alive:
		return
	alive = false
	active = false
	returning_fire = false
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
