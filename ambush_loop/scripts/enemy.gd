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
const MuzzleFlashScript := preload("res://scripts/fx/muzzle_flash.gd")
const CombatFxScript := preload("res://scripts/fx/combat_fx.gd")
const Silhouette := preload("res://scripts/fx/enemy_silhouette.gd")

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
var _return_flash: float = 0.0
var _present_t: float = 0.0
var _trail_acc: float = 0.0
var _trail_world: PackedVector2Array = PackedVector2Array()
var body_outline: Polygon2D = null
var kind_rim: Line2D = null
var moon_rim: Line2D = null
var chevron: Polygon2D = null
var weapon: Polygon2D = null
var kit_helm: Polygon2D = null
var trail: Line2D = null
var death_mark: Node2D = null
var _death_tween: Tween = null
var facing_deg: float = 90.0
var _recoil_off: Vector2 = Vector2.ZERO
var _weapon_snap: float = 0.0
var _hit_punch: float = 0.0
var _kind_color: Color = Color(0.82, 0.16, 0.14)
var _foot_dust: CPUParticles2D = null
var _dust_acc: float = 0.0
var hp_track: Polygon2D = null
var _walk_phase: float = 0.0
var _walk_bob: float = 0.0
var _base_poly: PackedVector2Array = PackedVector2Array()
var _last_move_dir: Vector2 = Vector2(0, 1)
var _outline_boost: bool = false
var _fade_corpse: bool = false
var _last_runner: bool = false
var echo_kit: bool = false
var _distract_t: float = 0.0
var _distract_pos: Vector2 = Vector2.ZERO
var _decoy_stepped: bool = false

@onready var body: Polygon2D = $Body
@onready var tag: Label = $Tag
@onready var hp_bar: Polygon2D = $HpBar


func setup(id: int, p_route: PackedVector2Array, p_grid: AmbushGrid = null, p_loot: int = 2, p_route_name: String = "") -> void:
	label_id = id
	route = p_route.duplicate()
	spawn_route = p_route_name
	did_branch = false
	_decoy_stepped = false
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
	_hit_flash = 0.0
	_return_flash = 0.0
	_present_t = 0.0
	_trail_world = PackedVector2Array()
	_reset_present_fx()
	_apply_hostile_silhouette()
	_refresh_tag()
	if route.size() > 0:
		global_position = route[0]
	recorded.clear()
	recorded.append(global_position)
	if route.size() > 1:
		_face_move(route[1])
	_update_hp_bar()
	_apply_body_modulate()


func mark_echo_kit(on: bool = true) -> void:
	## Presentation only — radio call-in runner keeps flank combat stats.
	echo_kit = on
	if body != null:
		_ensure_echo_mast()


func activate() -> void:
	active = true
	route_index = 1 if route.size() > 1 else 0
	_hit_punch = 0.7


func play_spawn_pop() -> void:
	_hit_punch = 0.85
	var tint := _kind_rim_color()
	CombatFxScript.spawn_pop(self, global_position, tint)


func set_last_runner(on: bool) -> void:
	_last_runner = on and alive and active
	_outline_boost = _last_runner


func last_runner_highlighted() -> bool:
	return _last_runner


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


func distract(pos: Vector2, seconds: float = 0.35) -> void:
	if not alive or not active:
		return
	_distract_pos = pos
	_distract_t = maxf(_distract_t, seconds)
	if not _decoy_stepped:
		_decoy_stepped = true
		_decoy_step_one_cell(pos)


func _decoy_step_one_cell(pos: Vector2) -> void:
	## Commandos pebble: peel one cell toward the noise, then resume the authored route.
	if grid == null:
		return
	var cell: Vector2i = grid.world_to_cell(global_position)
	var want: Vector2i = grid.world_to_cell(pos)
	var dx := clampi(want.x - cell.x, -1, 1)
	var dy := clampi(want.y - cell.y, -1, 1)
	if dx == 0 and dy == 0:
		return
	if absi(want.x - cell.x) >= absi(want.y - cell.y):
		dy = 0
	else:
		dx = 0
	var next := Vector2i(cell.x + dx, cell.y + dy)
	if not grid.in_bounds(next.x, next.y) or grid.is_blocked(next.x, next.y):
		return
	var world: Vector2 = grid.cell_to_world_center(next)
	var rebuilt := PackedVector2Array()
	rebuilt.append(global_position)
	rebuilt.append(world)
	if route_index < route.size():
		for i in range(maxi(route_index, 0), route.size()):
			rebuilt.append(route[i])
	elif route.size() > 0:
		rebuilt.append(route[route.size() - 1])
	route = rebuilt
	route_index = 1


func sim_step(delta: float) -> void:
	if not active or not alive:
		return

	return_cd = maxf(return_cd - delta, 0.0)
	returning_fire = false
	if _distract_t > 0.0:
		_distract_t = maxf(_distract_t - delta, 0.0)
		if _distract_pos != Vector2.ZERO:
			_face_move(_distract_pos)
		return

	if route_index >= route.size():
		# Standing on the last waypoint. Main resolves mouth escape after all movers
		# so a dead runner (or a later spawn) cannot steal the leaker slot.
		return

	var speed := ALERT_SPEED if alerted else SPEED
	var target: Vector2 = route[route_index]
	var prev := global_position
	global_position = global_position.move_toward(target, speed * delta)
	var moved: Vector2 = global_position - prev
	if moved.length_squared() > 0.0001:
		_last_move_dir = moved.normalized()
		_walk_phase += moved.length() * (0.28 if alerted else 0.18)
	if global_position.distance_to(target) < 2.0:
		route_index += 1
		if route_index >= route.size():
			if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
				recorded.append(global_position)
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
	# Kit tip is local -Y; rotate so the silhouette points along travel.
	facing_deg = rad_to_deg(aim.angle())
	body.rotation = aim.angle() + PI * 0.5
	if body_outline:
		body_outline.rotation = body.rotation
	if kind_rim:
		kind_rim.rotation = body.rotation
	if weapon and is_instance_valid(weapon):
		weapon.rotation = _weapon_snap


func resolve_return_fire() -> void:
	if not active or not alive:
		return
	returning_fire = false
	_try_return_fire()
	if returning_fire:
		_return_flash = 1.0
		_spawn_return_muzzle()
	if body:
		if returning_fire:
			body.color = Color(0.98, 0.48, 0.12)
		elif alive:
			body.color = _kind_color
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
	_hit_punch = 1.0
	if from != null:
		focus_target = from
	_update_hp_bar()
	_apply_body_modulate()
	_refresh_tag()
	CombatFxScript.hit_tick(self, global_position, amount, _kind_color.lightened(0.35), false)
	if hp <= 0.0:
		kill()
	else:
		CombatFxScript.impact(self, global_position, _kind_color.lightened(0.25), false)
		_play_hit_sfx()


func kill() -> void:
	if not alive:
		return
	alive = false
	active = false
	alerted = false
	returning_fire = false
	_hit_flash = 0.0
	_return_flash = 0.0
	if body:
		body.color = Color(0.35, 0.35, 0.38, 0.7)
	_apply_body_modulate()
	_play_death_fx()
	_refresh_tag()
	CombatFxScript.kill_burst(self, global_position, _kind_rim_color())
	died.emit(self)


func at_escape_mouth(mouth: Vector2, slop: float = 24.0) -> bool:
	## Alive runner who finished the authored polyline and is actually at the mouth.
	if not alive or not active:
		return false
	if route_index < route.size():
		return false
	return global_position.distance_to(mouth) <= slop


func mark_escaped() -> void:
	if not alive:
		return
	alive = false
	active = false
	returning_fire = false
	if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= 0.5:
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
	_present_t += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta * 5.5, 0.0)
	if _return_flash > 0.0:
		_return_flash = maxf(_return_flash - delta * 8.0, 0.0)
	if _hit_punch > 0.0:
		_hit_punch = maxf(_hit_punch - delta * 7.0, 0.0)
	_recoil_off = _recoil_off.lerp(Vector2.ZERO, 1.0 - exp(-delta * 16.0))
	if _recoil_off.length_squared() < 0.04:
		_recoil_off = Vector2.ZERO
	_weapon_snap = move_toward(_weapon_snap, 0.0, delta * 8.0)
	_apply_walk_bob()
	_tick_outline_boost()
	_tick_trail(delta)
	_tick_foot_dust(delta)
	_apply_body_modulate()
	_update_hp_bar()
	_tick_chevron_pulse()
	_tick_echo_mast()


func _ensure_contact_shadow() -> void:
	var sh := get_node_or_null("ContactShadow") as Polygon2D
	if sh == null:
		sh = Polygon2D.new()
		sh.name = "ContactShadow"
		sh.z_index = -4
		sh.show_behind_parent = true
		add_child(sh)
		move_child(sh, 0)
	var rx := 10.4
	var ry := 4.8
	match kind_id():
		"flank":
			rx = 11.2
			ry = 5.0
		"sneak":
			rx = 8.2
			ry = 3.8
		_:
			rx = 10.6
			ry = 5.0
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry + 11.0))
	sh.polygon = pts
	sh.rotation = 0.0
	sh.position = Vector2(2.4, 1.8)
	var a0 := 0.48 if alive else 0.18
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving()):
		a0 *= 0.65
	sh.color = Color(0.03, 0.02, 0.02, a0)
	sh.visible = visible
	var core := get_node_or_null("ContactShadowCore") as Polygon2D
	if core == null:
		core = Polygon2D.new()
		core.name = "ContactShadowCore"
		core.z_index = -3
		core.show_behind_parent = true
		add_child(core)
		move_child(core, mini(1, get_child_count() - 1))
	var cpts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		cpts.append(Vector2(cos(a) * rx * 0.52, sin(a) * ry * 0.52 + 10.6))
	core.polygon = cpts
	core.position = Vector2(1.1, 0.8)
	core.color = Color(0.02, 0.01, 0.01, a0 * 1.2)
	core.visible = visible and not (gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving()))


func _play_hit_sfx() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio = tree.root.get_node_or_null("/root/AudioDirector")
	if audio and audio.has_method("play"):
		audio.play("hit")


func kind_id() -> String:
	if echo_kit:
		return "echo"
	match spawn_route:
		"flank":
			return "flank"
		"sneak":
			return "sneak"
		_:
			return "main"


func kind_short() -> String:
	if echo_kit:
		return "回"
	match kind_id():
		"flank":
			return "奔"
		"sneak":
			return "影"
		_:
			return "巡"


func _hostile_body_poly() -> PackedVector2Array:
	return Silhouette.body_poly(kind_id())


func _kind_body_color() -> Color:
	match kind_id():
		"flank":
			return Color(0.48, 0.30, 0.16)
		"sneak":
			return Color(0.16, 0.18, 0.14)
		"echo":
			return Color(0.28, 0.32, 0.30)
		_:
			return Color(0.38, 0.32, 0.24)


func _kind_outline_color() -> Color:
	var kit := _kind_rim_color()
	return Color(
		clampf(kit.r * 0.38 + 0.10, 0.0, 1.0),
		clampf(kit.g * 0.32 + 0.06, 0.0, 1.0),
		clampf(kit.b * 0.28 + 0.05, 0.0, 1.0),
		1.0
	)


func _kind_rim_color() -> Color:
	if echo_kit:
		return Color(0.82, 0.70, 0.32, 0.95)
	match kind_id():
		"flank":
			return Color(1.0, 0.62, 0.18, 0.95)
		"sneak":
			return Color(0.62, 0.72, 0.48, 0.92)
		_:
			return Color(1.0, 0.32, 0.22, 0.95)


func _outline_pad() -> float:
	var h := 720.0
	var vp := get_viewport()
	if vp:
		h = maxf(vp.get_visible_rect().size.y, 360.0)
	var pad := 5.2 * clampf(720.0 / h, 0.9, 1.35)
	if _outline_boost:
		pad += 1.0
	return pad


func _ensure_chevron() -> void:
	if body == null:
		return
	if chevron == null or not is_instance_valid(chevron):
		chevron = get_node_or_null("Chevron") as Polygon2D
	if chevron == null:
		chevron = Polygon2D.new()
		chevron.name = "Chevron"
		chevron.z_index = 1
		body.add_child(chevron)
	match kind_id():
		"flank":
			chevron.polygon = PackedVector2Array([
				Vector2(0, -13), Vector2(5.5, -2), Vector2(0, 1), Vector2(-5.5, -2)
			])
			chevron.color = Color(1.0, 0.72, 0.22, 0.95)
		"sneak":
			chevron.polygon = PackedVector2Array([
				Vector2(0, -6), Vector2(3.2, 0), Vector2(0, 2), Vector2(-3.2, 0)
			])
			chevron.color = Color(0.42, 0.72, 0.62, 0.85)
		_:
			chevron.polygon = PackedVector2Array([
				Vector2(0, -12), Vector2(4.8, -1), Vector2(0, 2), Vector2(-4.8, -1)
			])
			chevron.color = Color(0.95, 0.28, 0.18, 0.95)


func _ensure_weapon() -> void:
	if body == null:
		return
	Silhouette.mount(body, kind_id())
	if weapon == null or not is_instance_valid(weapon):
		weapon = body.get_node_or_null("Weapon") as Polygon2D
	if weapon:
		weapon.rotation = _weapon_snap
		weapon.visible = true


func _ensure_helm() -> void:
	if body == null:
		return
	Silhouette.mount(body, kind_id())
	if kit_helm == null or not is_instance_valid(kit_helm):
		kit_helm = body.get_node_or_null("KitHelm") as Polygon2D


func _apply_hostile_silhouette() -> void:
	if body == null:
		return
	_kind_color = _kind_body_color()
	_base_poly = _hostile_body_poly()
	body.polygon = _base_poly
	body.color = _kind_color
	_ensure_chevron()
	_ensure_weapon()
	_ensure_helm()
	_ensure_trail()
	_ensure_contact_shadow()
	if body_outline == null or not is_instance_valid(body_outline):
		body_outline = get_node_or_null("BodyOutline") as Polygon2D
	if body_outline == null:
		body_outline = Polygon2D.new()
		body_outline.name = "BodyOutline"
		add_child(body_outline)
		move_child(body_outline, body.get_index())
	var pad := _outline_pad()
	var outline := PackedVector2Array()
	for p in body.polygon:
		var n := p
		if n.length_squared() > 0.01:
			n = n.normalized() * (p.length() + pad)
		outline.append(n)
	body_outline.polygon = outline
	body_outline.color = _kind_outline_color()
	body_outline.rotation = body.rotation
	_refresh_kind_rim()
	_refresh_tag()
	if echo_kit:
		_ensure_echo_mast()


func _ensure_echo_mast() -> void:
	if body == null:
		return
	var mast := body.get_node_or_null("EchoMast") as Polygon2D
	if mast == null:
		mast = Polygon2D.new()
		mast.name = "EchoMast"
		mast.polygon = PackedVector2Array([
			Vector2(-1.4, -16), Vector2(1.4, -16), Vector2(1.1, -38), Vector2(-1.1, -38)
		])
		mast.color = Color(0.55, 0.88, 0.98, 0.95)
		mast.z_index = 4
		body.add_child(mast)
	mast.visible = echo_kit
	var tip := body.get_node_or_null("EchoTip") as Polygon2D
	if tip == null:
		tip = Polygon2D.new()
		tip.name = "EchoTip"
		tip.polygon = PackedVector2Array([
			Vector2(-4.2, -36), Vector2(4.2, -36), Vector2(2.6, -44), Vector2(-2.6, -44)
		])
		tip.color = Color(0.78, 0.96, 1.0, 0.95)
		tip.z_index = 5
		body.add_child(tip)
	tip.visible = echo_kit


func _tick_echo_mast() -> void:
	if not echo_kit or body == null:
		return
	var tip := body.get_node_or_null("EchoTip") as Polygon2D
	var mast := body.get_node_or_null("EchoMast") as Polygon2D
	if tip == null and mast == null:
		return
	var pulse := 0.55 + 0.45 * sin(_present_t * 6.2)
	if tip:
		tip.color = Color(0.62 + 0.30 * pulse, 0.92, 1.0, 0.70 + 0.28 * pulse)
		tip.visible = alive
	if mast:
		mast.color = Color(0.40, 0.82, 0.96, 0.70 + 0.25 * pulse)
		mast.visible = alive


func _refresh_kind_rim() -> void:
	if body == null:
		return
	if kind_rim == null or not is_instance_valid(kind_rim):
		kind_rim = get_node_or_null("KindRim") as Line2D
	if kind_rim == null:
		kind_rim = Line2D.new()
		kind_rim.name = "KindRim"
		kind_rim.closed = true
		kind_rim.joint_mode = Line2D.LINE_JOINT_ROUND
		kind_rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
		kind_rim.end_cap_mode = Line2D.LINE_CAP_ROUND
		kind_rim.z_index = 0
		add_child(kind_rim)
		if body_outline != null and is_instance_valid(body_outline):
			move_child(kind_rim, body_outline.get_index() + 1)
	var pad := _outline_pad() + 1.4
	var pts := PackedVector2Array()
	for p in body.polygon:
		var n := p
		if n.length_squared() > 0.01:
			n = n.normalized() * (p.length() + pad)
		pts.append(n)
	if pts.size() > 0:
		var loop := pts.duplicate()
		loop.append(loop[0])
		kind_rim.points = loop
	kind_rim.width = (3.6 if _last_runner else 2.2) if _is_power_saving() else (4.2 if _last_runner else 2.8)
	var rim_c := _kind_rim_color()
	if _last_runner:
		var pulse := 0.55 + 0.45 * sin(_present_t * 8.0)
		rim_c = Color(1.0, 0.92, 0.42, pulse).lerp(rim_c, 0.25)
	kind_rim.default_color = rim_c
	kind_rim.visible = true
	kind_rim.rotation = body.rotation
	if moon_rim == null or not is_instance_valid(moon_rim):
		moon_rim = get_node_or_null("MoonRim") as Line2D
	if moon_rim == null:
		moon_rim = Line2D.new()
		moon_rim.name = "MoonRim"
		moon_rim.closed = false
		moon_rim.joint_mode = Line2D.LINE_JOINT_ROUND
		moon_rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
		moon_rim.end_cap_mode = Line2D.LINE_CAP_ROUND
		moon_rim.z_index = 1
		add_child(moon_rim)
	var lit := PackedVector2Array()
	for p in pts:
		if p.x + p.y < 2.0:
			lit.append(p)
	if lit.size() < 3:
		lit = pts
	moon_rim.points = lit
	moon_rim.width = 1.4 if _is_power_saving() else 2.0
	moon_rim.default_color = Color(0.94, 0.82, 0.62, 0.82 if alive else 0.22)
	moon_rim.visible = alive
	moon_rim.rotation = body.rotation
	moon_rim.position = Vector2(1.2, -1.5)


func _spawn_death_puff() -> void:
	## Route-colored collapse puff. Standard tier only — 省电 keeps the X mark.
	if _is_power_saving():
		return
	var puff := CPUParticles2D.new()
	puff.name = "DeathPuff"
	puff.emitting = false
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 10
	puff.lifetime = 0.28
	puff.local_coords = false
	puff.direction = Vector2(0, -1)
	puff.spread = 80.0
	puff.initial_velocity_min = 18.0
	puff.initial_velocity_max = 46.0
	puff.gravity = Vector2(0, 70)
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.6
	var rc := _kind_rim_color()
	puff.color = Color(rc.r, rc.g, rc.b, 0.72)
	puff.z_index = 3
	add_child(puff)
	puff.emitting = true
	puff.restart()
	var tw := puff.create_tween()
	tw.tween_interval(0.36)
	tw.tween_callback(puff.queue_free)


func _refresh_tag() -> void:
	if tag == null:
		return
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	if not alive:
		tag.text = "%s%d 尸体" % [kind_short(), label_id]
		tag.add_theme_color_override("font_color", Color(0.58, 0.56, 0.54))
		return
	var bang := "!" if alerted else ""
	if echo_kit:
		tag.text = "回波%d%s" % [label_id, bang]
	else:
		tag.text = "%s%d%s" % [kind_short(), label_id, bang]
	var col := _kind_color.lightened(0.25)
	if echo_kit:
		col = Color(0.55, 0.92, 1.0)
	elif kind_id() == "sneak":
		col = Color(0.62, 0.78, 0.72)
	tag.add_theme_color_override("font_color", col)


func _apply_body_modulate() -> void:
	if body == null:
		return
	if not alive:
		if _death_tween != null and is_instance_valid(_death_tween) and _death_tween.is_running():
			return
		if _fade_corpse:
			body.modulate = Color(0.62, 0.62, 0.64, 0.0)
			if body_outline:
				body_outline.modulate = Color(0.55, 0.55, 0.55, 0.0)
			if kind_rim:
				kind_rim.modulate = Color(0.55, 0.55, 0.55, 0.0)
			if chevron:
				chevron.modulate = Color(0.55, 0.55, 0.55, 0.0)
			if weapon:
				weapon.modulate = Color(0.5, 0.5, 0.52, 0.0)
			if kit_helm:
				kit_helm.modulate = Color(0.5, 0.5, 0.52, 0.0)
			_tint_figure_parts(Color(0.62, 0.62, 0.64, 0.0))
			return
		body.modulate = Color(0.62, 0.62, 0.64, 0.72)
		if body_outline:
			body_outline.modulate = Color(0.55, 0.55, 0.55, 0.7)
		if kind_rim:
			kind_rim.modulate = Color(0.55, 0.55, 0.55, 0.5)
		if chevron:
			chevron.modulate = Color(0.55, 0.55, 0.55, 0.65)
		if weapon:
			weapon.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_helm:
			kit_helm.modulate = Color(0.5, 0.5, 0.52, 0.7)
		_tint_figure_parts(Color(0.62, 0.62, 0.64, 0.72))
		return
	var flash := Color(1.55, 1.55, 1.55, 1).lerp(Color(1.9, 0.22, 0.16), _hit_flash)
	if _return_flash > 0.0:
		flash = flash.lerp(Color(1.6, 0.7, 0.25), _return_flash)
	elif alerted:
		var pulse := 0.5 + 0.5 * sin(_present_t * 7.5)
		flash = flash.lerp(Color(1.35, 0.45, 0.22), 0.22 + 0.28 * pulse)
	body.modulate = flash
	if body_outline:
		body_outline.modulate = Color(1, 1, 1, 1).lerp(Color(1.5, 1.2, 0.5), _hit_flash)
	if kind_rim:
		kind_rim.modulate = Color(1, 1, 1, 1).lerp(Color(1.6, 1.2, 0.4), _hit_flash)
	if chevron:
		chevron.modulate = flash
	if weapon:
		weapon.modulate = flash
	if kit_helm:
		kit_helm.modulate = flash
	_tint_figure_parts(flash)


func _tint_figure_parts(flash: Color) -> void:
	if body == null:
		return
	for nam in ["Head", "Visor", "LegL", "LegR", "ShoulderL", "ShoulderR", "TorsoShade", "Cape", "FrontSight", "Sight", "BootL", "BootR", "MoonFill", "KitHelm"]:
		var n := body.get_node_or_null(nam)
		if n is CanvasItem:
			(n as CanvasItem).modulate = flash


func walk_bob_hook() -> float:
	## Smoke / presentation hook: last applied walk-cycle bob (px).
	return _walk_bob


func _apply_walk_bob() -> void:
	var bob := 0.0
	if alive and active:
		var amp := 0.55 if _is_power_saving() else 1.45
		if alerted:
			amp *= 1.25
		var kind_rate := 1.15 if kind_id() == "sneak" else (1.45 if kind_id() == "flank" else 1.25)
		if alerted:
			kind_rate *= 1.55
		bob = sin(_walk_phase * kind_rate + float(label_id)) * amp
	_walk_bob = bob
	if body:
		body.position = Vector2(0.0, bob) + _recoil_off
		if alive and (_death_tween == null or not is_instance_valid(_death_tween)):
			var punch := 1.0 + _hit_punch * 0.18
			body.scale = Vector2(punch, punch)
		if alive and active and not _is_power_saving() and _base_poly.size() >= 4:
			var stride_amp := 1.35 if alerted else 0.85
			body.polygon = _offset_walk_poly(_base_poly, _walk_phase, stride_amp)
	if body_outline:
		body_outline.position = Vector2(0.0, bob) + _recoil_off
		if body:
			body_outline.scale = body.scale
	if kind_rim:
		kind_rim.position = Vector2(0.0, bob) + _recoil_off
		if body:
			kind_rim.scale = body.scale
		kind_rim.rotation = body.rotation if body else kind_rim.rotation
	if weapon and is_instance_valid(weapon):
		weapon.rotation = _weapon_snap
	if body:
		Silhouette.pose_parts(body, kind_id(), {
			"phase": _walk_phase,
			"alive": alive,
			"active": active,
			"alerted": alerted,
			"saving": _is_power_saving(),
			"recoil": _weapon_snap,
		})
	if hp_bar:
		hp_bar.position = Vector2(0.0, bob * 0.25)
	if hp_track:
		hp_track.position = Vector2(0.0, bob * 0.25)


func _offset_walk_poly(src: PackedVector2Array, phase: float, amp: float) -> PackedVector2Array:
	## Opposite-leg vertex offset so the silhouette reads as a stride at distance.
	var out := PackedVector2Array()
	var stride := sin(phase)
	var sway := cos(phase)
	for p in src:
		var q := p
		if p.y > 1.5:
			var side := 1.0 if p.x >= 0.0 else -1.0
			q.y += stride * amp * side
			q.x += sway * amp * 0.4 * side
		out.append(q)
	return out


func _ensure_trail() -> void:
	if trail != null and is_instance_valid(trail):
		return
	trail = Line2D.new()
	trail.name = "Trail"
	trail.width = 2.0
	trail.default_color = _trail_color(0.22)
	trail.z_index = -1
	trail.show_behind_parent = true
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	move_child(trail, 0)


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _tick_trail(delta: float) -> void:
	_ensure_trail()
	if trail == null:
		return
	var saving := _is_power_saving()
	trail.width = 1.0 if saving else 2.0
	if not alive or not active:
		if _trail_world.size() > 0:
			_trail_world = PackedVector2Array()
			trail.points = PackedVector2Array()
		return
	var interval := 0.12 if saving else 0.05
	var limit := 3 if saving else 9
	_trail_acc += delta
	if _trail_acc >= interval:
		_trail_acc = 0.0
		_trail_world.append(global_position)
		while _trail_world.size() > limit:
			_trail_world.remove_at(0)
	var local_pts := PackedVector2Array()
	for p in _trail_world:
		local_pts.append(p - global_position)
	local_pts.append(Vector2.ZERO)
	trail.points = local_pts
	var a := 0.10 if saving else (0.18 if alerted else 0.12)
	trail.default_color = _trail_color(a)


func _trail_color(a: float) -> Color:
	match kind_id():
		"flank":
			return Color(0.95, 0.48, 0.14, a)
		"sneak":
			return Color(0.32, 0.48, 0.42, a * 0.7)
		_:
			return Color(0.82, 0.18, 0.14, a)


func _spawn_return_muzzle() -> void:
	if focus_target == null or not is_instance_valid(focus_target):
		return
	var aim := focus_target.global_position - global_position
	if aim.length_squared() < 0.01:
		return
	var rad := aim.angle()
	var style := "rifle"
	var intensity := 0.95
	match kind_id():
		"flank":
			style = "rifle"
			intensity = 0.88
		"sneak":
			style = "scout"
			intensity = 0.7
		_:
			style = "rifle"
			intensity = 1.05
	MuzzleFlashScript.burst(
		self, Vector2(cos(rad), sin(rad)) * 14.0, rad, Color(1.0, 0.55, 0.2), intensity, style
	)
	apply_recoil_kick(rad)


func apply_recoil_kick(aim_rad: float = INF) -> void:
	var rad := aim_rad if aim_rad != INF else deg_to_rad(facing_deg)
	var back := Vector2(cos(rad), sin(rad)) * -1.0
	match kind_id():
		"flank":
			_recoil_off = back * 3.2
			_weapon_snap = 0.16
		"sneak":
			_recoil_off = back * 1.8
			_weapon_snap = 0.08
		_:
			_recoil_off = back * 4.0
			_weapon_snap = 0.2


func _ensure_death_mark() -> void:
	if death_mark != null and is_instance_valid(death_mark):
		return
	death_mark = Node2D.new()
	death_mark.name = "DeathMark"
	death_mark.z_index = 4
	var pool := Polygon2D.new()
	pool.name = "Pool"
	pool.polygon = PackedVector2Array([
		Vector2(-10, 5), Vector2(10, 5), Vector2(7, 13), Vector2(-7, 13)
	])
	pool.color = Color(0.10, 0.06, 0.06, 0.8)
	death_mark.add_child(pool)
	var xc := _kind_rim_color()
	var a := Line2D.new()
	a.width = 3.4
	a.default_color = Color(xc.r, xc.g, xc.b, 0.98)
	a.points = PackedVector2Array([Vector2(-8, -8), Vector2(8, 8)])
	death_mark.add_child(a)
	var b := Line2D.new()
	b.width = 3.4
	b.default_color = a.default_color
	b.points = PackedVector2Array([Vector2(8, -8), Vector2(-8, 8)])
	death_mark.add_child(b)
	add_child(death_mark)


func _play_death_fx() -> void:
	if trail:
		trail.points = PackedVector2Array()
	_trail_world = PackedVector2Array()
	_ensure_death_mark()
	if _death_tween != null:
		_death_tween.kill()
	if _is_power_saving():
		_fade_corpse = true
		if death_mark:
			death_mark.visible = true
			death_mark.modulate.a = 1.0
		if body:
			body.modulate.a = 0.0
		if body_outline:
			body_outline.modulate.a = 0.0
		if kind_rim:
			kind_rim.modulate.a = 0.0
		return
	_spawn_death_puff()
	if death_mark:
		death_mark.visible = true
		death_mark.modulate.a = 0.0
		death_mark.create_tween().tween_property(death_mark, "modulate:a", 1.0, 0.16)
	if body == null:
		return
	_death_tween = create_tween()
	var dir := _last_move_dir
	if dir.length_squared() < 0.04:
		dir = Vector2(0, 1)
	else:
		dir = dir.normalized()
	var dest: Vector2 = global_position + dir * 8.0
	_death_tween.tween_property(self, "global_position", dest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(body, "rotation", body.rotation + deg_to_rad(70.0), 0.16)
	_death_tween.parallel().tween_property(body, "scale", Vector2(1.22, 0.42), 0.16)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "rotation", body.rotation + deg_to_rad(70.0), 0.16)
		_death_tween.parallel().tween_property(body_outline, "scale", Vector2(1.22, 0.42), 0.16)
	_death_tween.tween_callback(func() -> void: _fade_corpse = true)
	_death_tween.tween_property(body, "modulate:a", 0.0, 0.20)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "modulate:a", 0.0, 0.20)
	if kind_rim:
		_death_tween.parallel().tween_property(kind_rim, "modulate:a", 0.0, 0.18)
	if chevron:
		_death_tween.parallel().tween_property(chevron, "modulate:a", 0.0, 0.16)
	if weapon:
		_death_tween.parallel().tween_property(weapon, "modulate:a", 0.0, 0.16)


func _reset_present_fx() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	_recoil_off = Vector2.ZERO
	_weapon_snap = 0.0
	_hit_punch = 0.0
	_dust_acc = 0.0
	_walk_phase = 0.0
	_walk_bob = 0.0
	_outline_boost = false
	_fade_corpse = false
	modulate.a = 1.0
	if _foot_dust != null and is_instance_valid(_foot_dust):
		_foot_dust.emitting = false
	if body:
		body.scale = Vector2.ONE
		body.position = Vector2.ZERO
		body.modulate.a = 1.0
		if _base_poly.size() >= 3:
			body.polygon = _base_poly
	if body_outline:
		body_outline.scale = Vector2.ONE
		body_outline.position = Vector2.ZERO
	if kind_rim:
		kind_rim.scale = Vector2.ONE
		kind_rim.position = Vector2.ZERO
		kind_rim.modulate = Color.WHITE
	if death_mark != null and is_instance_valid(death_mark):
		death_mark.visible = false
	if trail:
		trail.points = PackedVector2Array()
	if weapon != null and is_instance_valid(weapon):
		weapon.rotation = 0.0
		weapon.modulate = Color.WHITE
	if chevron != null and is_instance_valid(chevron):
		chevron.scale = Vector2.ONE
		chevron.modulate.a = 1.0


func _tick_foot_dust(delta: float) -> void:
	## Sparse pooled puffs while walking. Standard tier only — 省电 skips particles.
	if _is_power_saving() or not alive or not active:
		if _foot_dust != null and is_instance_valid(_foot_dust):
			_foot_dust.emitting = false
		return
	_dust_acc += delta
	var interval := 0.18 if kind_id() == "flank" else (0.36 if kind_id() == "sneak" else 0.26)
	if _dust_acc < interval:
		return
	_dust_acc = 0.0
	_ensure_foot_dust()
	if _foot_dust:
		_foot_dust.restart()
	_drop_boot_print()


func _drop_boot_print() -> void:
	if _is_power_saving() or not alive or not active:
		return
	var host: Node2D = get_parent() as Node2D
	if host == null:
		host = self
	var live := 0
	for c in host.get_children():
		if str(c.name).begins_with("BootPrint"):
			live += 1
	if live >= 10:
		return
	var n := Polygon2D.new()
	n.name = "BootPrint"
	n.z_index = -2
	n.show_behind_parent = true
	n.polygon = PackedVector2Array([
		Vector2(-3.2, -4.5), Vector2(2.6, -4.2), Vector2(3.0, 4.8), Vector2(-2.8, 4.5)
	])
	n.color = Color(_kind_color.r, _kind_color.g, _kind_color.b, 0.28)
	n.rotation = deg_to_rad(facing_deg)
	host.add_child(n)
	n.global_position = global_position + Vector2(0, 8)
	var tw := n.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(n, "modulate:a", 0.0, 0.55)
	tw.tween_callback(n.queue_free)


func boot_print_dropped() -> bool:
	var host: Node = get_parent()
	if host == null:
		return false
	for c in host.get_children():
		if str(c.name).begins_with("BootPrint"):
			return true
	return false


func _ensure_foot_dust() -> void:
	if _foot_dust != null and is_instance_valid(_foot_dust):
		return
	_foot_dust = CPUParticles2D.new()
	_foot_dust.name = "FootDust"
	_foot_dust.emitting = false
	_foot_dust.one_shot = true
	_foot_dust.explosiveness = 0.92
	_foot_dust.amount = 5
	_foot_dust.lifetime = 0.34
	_foot_dust.local_coords = false
	_foot_dust.direction = Vector2(0, 1)
	_foot_dust.spread = 48.0
	_foot_dust.initial_velocity_min = 5.0
	_foot_dust.initial_velocity_max = 14.0
	_foot_dust.gravity = Vector2(0, 26)
	_foot_dust.scale_amount_min = 0.35
	_foot_dust.scale_amount_max = 1.05
	_foot_dust.color = Color(0.52, 0.48, 0.36, 0.38)
	_foot_dust.z_index = -1
	_foot_dust.show_behind_parent = true
	add_child(_foot_dust)


func _cam_center_world() -> Vector2:
	var vp := get_viewport()
	if vp:
		var cam := vp.get_camera_2d()
		if cam:
			return cam.get_screen_center_position()
	return Vector2(640, 360)


func _tick_outline_boost() -> void:
	var near := global_position.distance_to(_cam_center_world()) <= 120.0
	if near == _outline_boost:
		return
	_outline_boost = near
	if body and _base_poly.size() >= 3:
		var pad := _outline_pad()
		var outline := PackedVector2Array()
		for p in _base_poly:
			var n := p
			if n.length_squared() > 0.01:
				n = n.normalized() * (p.length() + pad)
			outline.append(n)
		if body_outline:
			body_outline.polygon = outline
		_refresh_kind_rim()


func _tick_chevron_pulse() -> void:
	if chevron == null or not is_instance_valid(chevron):
		return
	if not alive or not alerted or _is_power_saving():
		chevron.scale = Vector2.ONE
		return
	var pulse := 0.5 + 0.5 * sin(_present_t * 8.5)
	chevron.scale = Vector2.ONE * (1.0 + 0.28 * pulse)


func hp_bar_watch_visible() -> bool:
	## Smoke / HUD hook: route-colored watch bar above the body (省电 hides).
	return hp_bar != null and is_instance_valid(hp_bar) and hp_bar.visible


func _ensure_hp_track() -> void:
	if hp_track != null and is_instance_valid(hp_track):
		return
	hp_track = get_node_or_null("HpTrack") as Polygon2D
	if hp_track == null:
		hp_track = Polygon2D.new()
		hp_track.name = "HpTrack"
		hp_track.z_index = 5
		add_child(hp_track)
		if hp_bar != null and is_instance_valid(hp_bar):
			move_child(hp_track, hp_bar.get_index())


func _update_hp_bar() -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		hp_bar = get_node_or_null("HpBar") as Polygon2D
	if hp_bar == null:
		return
	_ensure_hp_track()
	var saving := _is_power_saving()
	var shown := alive and not saving
	hp_bar.visible = shown
	if hp_track:
		hp_track.visible = shown
	if not shown:
		return
	var y0 := -28.0
	var h := 2.2
	var full := 26.0
	var w := full * clampf(hp / MAX_HP, 0.0, 1.0)
	if hp_track:
		hp_track.polygon = PackedVector2Array([
			Vector2(-13, y0), Vector2(13, y0), Vector2(13, y0 + h), Vector2(-13, y0 + h)
		])
		hp_track.color = Color(0.05, 0.05, 0.05, 0.78)
		hp_track.z_index = 5
	hp_bar.polygon = PackedVector2Array([
		Vector2(-13, y0), Vector2(-13 + w, y0), Vector2(-13 + w, y0 + h), Vector2(-13, y0 + h)
	])
	var rc := _kind_rim_color()
	hp_bar.color = Color(rc.r, rc.g, rc.b, 1.0)
	hp_bar.z_index = 6
