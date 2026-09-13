class_name C2Sentry
extends Node2D

## Scout-phase patrol. Vision cone like Commandos. Does not pull RAID.

enum State { PATROL, SUSPICIOUS, ALERT, KO, BOUND }

const SEE_R := 128.0
const HALF_ANG := 26.0
const HEAR_R := 78.0
const SPEED := 38.0
const CONE_RAYS := 12

signal spotted(sentry: C2Sentry, op: Node)
signal knocked(sentry: C2Sentry)

var route: PackedVector2Array = PackedVector2Array()
var route_i: int = 0
var dir: int = 1
var state: int = State.PATROL
var facing_deg: float = 90.0
var suspicion: float = 0.0
var grid = null
var label_id: int = 0
var last_seen: Vector2 = Vector2.ZERO
var _look_t: float = 0.0
var _ko_t: float = 0.0
var cone: Polygon2D
var body: Polygon2D
var mark: Node2D
var _base_poly: PackedVector2Array = PackedVector2Array()


func setup(id: int, p_route: PackedVector2Array, p_grid) -> void:
	label_id = id
	route = p_route.duplicate()
	grid = p_grid
	state = State.PATROL
	suspicion = 0.0
	dir = 1
	route_i = 1 if route.size() > 1 else 0
	if route.size() > 0:
		global_position = route[0]
	z_index = 3
	_ensure_visual()
	if route.size() > 1:
		_face_to(route[1])
	_rebuild_cone()


func is_down() -> bool:
	return state == State.KO or state == State.BOUND


func knock_out() -> void:
	if is_down():
		return
	state = State.KO
	_ko_t = 0.0
	suspicion = 0.0
	if cone:
		cone.visible = false
	if mark and mark.has_method("set"):
		mark.kind = 3
	if body:
		body.rotation = deg_to_rad(90.0)
		body.color = Color(0.32, 0.30, 0.28, 0.85)
	knocked.emit(self)


func bind_gag() -> bool:
	if state != State.KO:
		return false
	state = State.BOUND
	if mark:
		mark.kind = 3
	return true


func hear_at(world: Vector2, loud: float) -> void:
	if is_down() or loud < 0.08:
		return
	var d := global_position.distance_to(world)
	var r := HEAR_R * (0.55 + loud)
	if d > r:
		return
	suspicion = minf(suspicion + 0.35 + loud * 0.4, 1.0)
	last_seen = world
	if state == State.PATROL:
		state = State.SUSPICIOUS
		_look_t = 1.4


func tick(delta: float, ops: Array, hidden_at: Callable) -> Node:
	if is_down():
		_ko_t += delta
		return null
	var seen: Node = _scan(ops, hidden_at)
	if seen != null:
		last_seen = seen.global_position
		suspicion = minf(suspicion + delta * 0.85, 1.0)
		if suspicion >= 0.55:
			state = State.ALERT
			if mark:
				mark.kind = 2
			spotted.emit(self, seen)
		else:
			state = State.SUSPICIOUS
			if mark:
				mark.kind = 1
		_face_to(seen.global_position)
		_rebuild_cone()
		return seen
	suspicion = maxf(suspicion - delta * 0.28, 0.0)
	if suspicion < 0.12 and state != State.PATROL:
		state = State.PATROL
		if mark:
			mark.kind = 0
	if state == State.SUSPICIOUS:
		_look_t = maxf(_look_t - delta, 0.0)
		if last_seen != Vector2.ZERO and _look_t > 0.0:
			_face_to(last_seen)
		_rebuild_cone()
		return null
	if state == State.ALERT:
		_step_toward(last_seen, delta * 1.35)
		_rebuild_cone()
		if global_position.distance_to(last_seen) < 10.0:
			state = State.SUSPICIOUS
			_look_t = 1.2
		return null
	_patrol(delta)
	_rebuild_cone()
	return null


func _scan(ops: Array, hidden_at: Callable) -> Node:
	for op in ops:
		if op == null or not op.visible or not bool(op.alive):
			continue
		if hidden_at.is_valid() and bool(hidden_at.call(op)):
			continue
		if _sees(op.global_position):
			return op
	return null


func _sees(world: Vector2) -> bool:
	var v := world - global_position
	var dist := v.length()
	if dist < 8.0:
		return true
	if dist > SEE_R:
		return false
	var ang := rad_to_deg(atan2(v.y, v.x))
	if absf(_ang_diff(facing_deg, ang)) > HALF_ANG:
		return false
	if grid != null and grid.has_method("has_los") and not bool(grid.has_los(global_position, world)):
		return false
	return true


func in_backstab(world: Vector2) -> bool:
	var v := world - global_position
	if v.length() > 30.0:
		return false
	var ang := rad_to_deg(atan2(v.y, v.x))
	return absf(_ang_diff(facing_deg, ang)) > 95.0


func _patrol(delta: float) -> void:
	if route.size() < 2:
		return
	var target: Vector2 = route[clampi(route_i, 0, route.size() - 1)]
	_step_toward(target, delta)
	if global_position.distance_to(target) <= 3.0:
		route_i += dir
		if route_i >= route.size() or route_i < 0:
			dir *= -1
			route_i = clampi(route_i, 0, route.size() - 1)


func _step_toward(target: Vector2, delta: float) -> void:
	var nxt := global_position.move_toward(target, SPEED * delta)
	global_position = nxt
	_face_to(target)


func _face_to(target: Vector2) -> void:
	var aim := target - global_position
	if aim.length_squared() < 0.2:
		return
	facing_deg = rad_to_deg(aim.angle())
	if body:
		body.rotation = aim.angle() + PI * 0.5


func _ensure_visual() -> void:
	if body != null:
		return
	body = Polygon2D.new()
	body.name = "Body"
	_base_poly = PackedVector2Array([
		Vector2(0, -11), Vector2(-5, -8), Vector2(-6, -2), Vector2(-4, 8),
		Vector2(-2, 11), Vector2(2, 11), Vector2(4, 8), Vector2(6, -2), Vector2(5, -8)
	])
	body.polygon = _base_poly
	body.color = Color(0.62, 0.22, 0.16)
	add_child(body)
	var helm := Polygon2D.new()
	helm.name = "Helm"
	helm.polygon = PackedVector2Array([Vector2(-4, -12), Vector2(4, -12), Vector2(3.4, -8), Vector2(-3.4, -8)])
	helm.color = Color(0.28, 0.30, 0.18)
	body.add_child(helm)
	cone = Polygon2D.new()
	cone.name = "Cone"
	cone.z_index = -1
	add_child(cone)
	var sh := Polygon2D.new()
	sh.name = "ContactShadow"
	sh.z_index = -4
	sh.show_behind_parent = true
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 4.2 + 10.0))
	sh.polygon = pts
	sh.color = Color(0.03, 0.02, 0.02, 0.45)
	add_child(sh)
	move_child(sh, 0)
	var AlertMarkScript := load("res://scripts/c2/alert_mark.gd")
	mark = AlertMarkScript.new()
	mark.name = "Mark"
	add_child(mark)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "岗"
	tag.position = Vector2(-10, 12)
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.82, 0.32, 0.22))
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
	add_child(tag)


func _rebuild_cone() -> void:
	if cone == null:
		return
	if is_down():
		cone.visible = false
		return
	cone.visible = true
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(CONE_RAYS + 1):
		var t := lerpf(-HALF_ANG, HALF_ANG, float(i) / float(CONE_RAYS))
		var rad := deg_to_rad(facing_deg + t)
		var dirv := Vector2(cos(rad), sin(rad))
		var dist := _clip(dirv)
		pts.append(dirv * dist)
	cone.polygon = pts
	match state:
		State.ALERT:
			cone.color = Color(0.92, 0.22, 0.14, 0.28)
		State.SUSPICIOUS:
			cone.color = Color(0.92, 0.78, 0.18, 0.24)
		_:
			cone.color = Color(0.72, 0.82, 0.28, 0.18)


func _clip(dirv: Vector2) -> float:
	if grid == null:
		return SEE_R
	var step := 16.0
	var traveled := step
	var last_ok := step
	while traveled <= SEE_R:
		var sample: Vector2 = global_position + dirv * traveled
		if grid.has_method("has_los") and not bool(grid.has_los(global_position, sample)):
			return last_ok
		last_ok = traveled
		traveled += step
	return SEE_R


func _ang_diff(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
