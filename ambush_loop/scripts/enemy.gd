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
var spawn_route: String = ""
var did_branch: bool = false
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
var _hit_flash: float = 0.0
var body_outline: Polygon2D = null

@onready var body: Polygon2D = $Body
@onready var tag: Label = $Tag
@onready var hp_bar: Polygon2D = $HpBar


func setup(id: int, p_route: PackedVector2Array, p_grid: AmbushGrid = null, p_loot: int = 2, p_route_name: String = "") -> void:
	label_id = id
	route = p_route.duplicate()
	spawn_route = p_route_name
	did_branch = false
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
	_hit_flash = 0.0
	_apply_hostile_silhouette()
	if route.size() > 0:
		global_position = route[0]
	recorded.clear()
	recorded.append(global_position)
	if route.size() > 1:
		_face_move(route[1])
	_update_hp_bar()
	_apply_body_modulate()


func activate() -> void:
	active = true
	route_index = 1 if route.size() > 1 else 0


func maybe_branch(door_locked: bool, decision_world: Vector2, alt_world: PackedVector2Array, blocked_route: String) -> bool:
	## At the authored decision cell, splice remaining polyline to the alt suffix once.
	if did_branch or not active or not alive:
		return false
	if not door_locked or blocked_route == "" or spawn_route != blocked_route:
		return false
	if alt_world.is_empty():
		return false
	if global_position.distance_to(decision_world) > 18.0:
		return false
	var suffix := PackedVector2Array()
	var seen_decision := false
	for p in alt_world:
		if not seen_decision:
			if p.distance_to(decision_world) < 1.5:
				seen_decision = true
			continue
		suffix.append(p)
	if suffix.is_empty():
		return false
	var next := PackedVector2Array()
	next.append(global_position)
	next.append_array(suffix)
	route = next
	route_index = 1 if route.size() > 1 else 0
	did_branch = true
	return true


func sim_step(delta: float) -> void:
	if not active or not alive:
		return

	return_cd = maxf(return_cd - delta, 0.0)
	returning_fire = false

	if route_index >= route.size():
		mark_escaped()
		return

	var speed := ALERT_SPEED if alerted else SPEED
	var target: Vector2 = route[route_index]
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_to(target) < 2.0:
		route_index += 1
		# Escape commits on the same tick the last waypoint is reached.
		if route_index >= route.size():
			if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
				recorded.append(global_position)
			mark_escaped()
			return
	if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
		recorded.append(global_position)
	_face_move(target)


func _face_move(target: Vector2) -> void:
	if body == null:
		return
	var aim := target - global_position
	if aim.length_squared() < 0.25 and route_index > 0 and route_index <= route.size():
		aim = route[mini(route_index, route.size() - 1)] - route[route_index - 1]
	if aim.length_squared() < 0.04:
		return
	# Diamond/chevron tip is local -Y; rotate so the tip points along travel.
	body.rotation = aim.angle() + PI * 0.5
	if body_outline:
		body_outline.rotation = body.rotation


func resolve_return_fire() -> void:
	if not active or not alive:
		return
	returning_fire = false
	_try_return_fire()
	if body:
		if returning_fire:
			body.color = Color(0.98, 0.48, 0.12)
		elif alive:
			body.color = Color(0.82, 0.16, 0.14)
		_apply_body_modulate()


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
	# Log/FX signal before damage so terminal UI can include the attack.
	return_fired.emit(self, focus_target)
	focus_target.take_damage(RETURN_DAMAGE, global_position)


func apply_fire(amount: float, from: OperatorUnit = null) -> void:
	if not alive:
		return
	hp -= amount
	alerted = true
	_hit_flash = 1.0
	if from != null:
		focus_target = from
	_update_hp_bar()
	_apply_body_modulate()
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
	_hit_flash = 0.0
	if body:
		body.color = Color(0.35, 0.35, 0.38, 0.7)
	_apply_body_modulate()
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


## Remaining polyline distance to escape (blueprint target priority).
func remaining_path_to_escape() -> float:
	if route.is_empty():
		return INF
	if route_index >= route.size():
		return 0.0
	var dist := global_position.distance_to(route[route_index])
	for i in range(route_index, route.size() - 1):
		dist += route[i].distance_to(route[i + 1])
	return dist


func _process(delta: float) -> void:
	if _hit_flash <= 0.0:
		return
	_hit_flash = maxf(_hit_flash - delta * 5.5, 0.0)
	_apply_body_modulate()


func _hostile_diamond() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -13), Vector2(9, 0), Vector2(0, 11), Vector2(-9, 0)
	])


func _apply_hostile_silhouette() -> void:
	if body == null:
		return
	body.polygon = _hostile_diamond()
	body.color = Color(0.82, 0.16, 0.14)
	if body_outline == null or not is_instance_valid(body_outline):
		body_outline = get_node_or_null("BodyOutline") as Polygon2D
	if body_outline == null:
		body_outline = Polygon2D.new()
		body_outline.name = "BodyOutline"
		add_child(body_outline)
		move_child(body_outline, body.get_index())
	var outline := PackedVector2Array()
	for p in body.polygon:
		var n := p
		if n.length_squared() > 0.01:
			n = n.normalized() * (p.length() + 2.6)
		outline.append(n)
	body_outline.polygon = outline
	body_outline.color = Color(0.18, 0.04, 0.04, 0.95)
	body_outline.rotation = body.rotation


func _apply_body_modulate() -> void:
	if body == null:
		return
	if not alive:
		body.modulate = Color(0.7, 0.7, 0.7, 0.8)
		if body_outline:
			body_outline.modulate = Color(0.55, 0.55, 0.55, 0.7)
		return
	var flash := Color(1, 1, 1, 1).lerp(Color(1.9, 1.7, 1.15), _hit_flash)
	body.modulate = flash
	if body_outline:
		body_outline.modulate = Color(1, 1, 1, 1).lerp(Color(1.5, 1.2, 0.5), _hit_flash)


func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	var w := 24.0 * clampf(hp / MAX_HP, 0.0, 1.0)
	hp_bar.polygon = PackedVector2Array([
		Vector2(-12, -18), Vector2(-12 + w, -18), Vector2(-12 + w, -15), Vector2(-12, -15)
	])
	hp_bar.color = Color(0.2, 0.85, 0.35) if hp > 40.0 else Color(0.9, 0.25, 0.2)
