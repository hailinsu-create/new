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
	# Kit tip is local -Y; rotate so the silhouette points along travel.
	facing_deg = rad_to_deg(aim.angle())
	body.rotation = aim.angle() + PI * 0.5
	if body_outline:
		body_outline.rotation = body.rotation
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
	_return_flash = 0.0
	if body:
		body.color = Color(0.35, 0.35, 0.38, 0.7)
	_apply_body_modulate()
	_play_death_fx()
	_refresh_tag()
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
	_tick_trail(delta)
	_tick_foot_dust(delta)
	_apply_body_modulate()


func kind_id() -> String:
	match spawn_route:
		"flank":
			return "flank"
		"sneak":
			return "sneak"
		_:
			return "main"


func kind_short() -> String:
	match kind_id():
		"flank":
			return "奔"
		"sneak":
			return "影"
		_:
			return "巡"


func _hostile_body_poly() -> PackedVector2Array:
	match kind_id():
		"flank":
			# Runner: elongated diamond, lean forward.
			return PackedVector2Array([
				Vector2(0, -17), Vector2(6.2, -5), Vector2(5.4, 12),
				Vector2(0, 9), Vector2(-5.4, 12), Vector2(-6.2, -5)
			])
		"sneak":
			# Shadow: low, wide, no helmet peak.
			return PackedVector2Array([
				Vector2(0, -9), Vector2(11, -2), Vector2(9, 8),
				Vector2(0, 10), Vector2(-9, 8), Vector2(-11, -2)
			])
		_:
			# Patrol rifleman: helmet block + torso diamond.
			return PackedVector2Array([
				Vector2(-4.5, -16), Vector2(4.5, -16), Vector2(7.5, -8),
				Vector2(9.5, 1), Vector2(5.5, 12), Vector2(-5.5, 12),
				Vector2(-9.5, 1), Vector2(-7.5, -8)
			])


func _kind_body_color() -> Color:
	match kind_id():
		"flank":
			return Color(0.90, 0.42, 0.12)
		"sneak":
			return Color(0.16, 0.20, 0.24)
		_:
			return Color(0.82, 0.16, 0.14)


func _kind_outline_color() -> Color:
	match kind_id():
		"flank":
			return Color(0.22, 0.08, 0.02, 0.96)
		"sneak":
			return Color(0.04, 0.08, 0.10, 0.96)
		_:
			return Color(0.18, 0.04, 0.04, 0.96)


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
	if weapon == null or not is_instance_valid(weapon):
		weapon = get_node_or_null("Weapon") as Polygon2D
	if weapon == null:
		weapon = Polygon2D.new()
		weapon.name = "Weapon"
		weapon.z_index = 2
		body.add_child(weapon)
	weapon.rotation = _weapon_snap
	match kind_id():
		"flank":
			weapon.polygon = PackedVector2Array([
				Vector2(-1.3, -6), Vector2(1.3, -6), Vector2(1.0, -20), Vector2(-1.0, -20)
			])
			weapon.color = Color(0.12, 0.10, 0.08, 0.96)
			weapon.visible = true
		"sneak":
			weapon.polygon = PackedVector2Array([
				Vector2(-0.7, -4), Vector2(0.7, -4), Vector2(0.5, -12), Vector2(-0.5, -12)
			])
			weapon.color = Color(0.08, 0.10, 0.12, 0.9)
			weapon.visible = true
		_:
			weapon.polygon = PackedVector2Array([
				Vector2(-1.4, -5), Vector2(1.4, -5), Vector2(1.1, -24),
				Vector2(0.3, -27), Vector2(-0.3, -27), Vector2(-1.1, -24)
			])
			weapon.color = Color(0.14, 0.12, 0.10, 0.98)
			weapon.visible = true


func _ensure_helm() -> void:
	if body == null:
		return
	if kit_helm == null or not is_instance_valid(kit_helm):
		kit_helm = get_node_or_null("KitHelm") as Polygon2D
	if kit_helm == null:
		kit_helm = Polygon2D.new()
		kit_helm.name = "KitHelm"
		kit_helm.z_index = 1
		body.add_child(kit_helm)
	match kind_id():
		"flank":
			kit_helm.polygon = PackedVector2Array([
				Vector2(-3.2, -18), Vector2(3.2, -18), Vector2(2.6, -13), Vector2(-2.6, -13)
			])
			kit_helm.color = Color(0.28, 0.12, 0.06, 0.95)
			kit_helm.visible = true
		"sneak":
			kit_helm.visible = false
		_:
			kit_helm.polygon = PackedVector2Array([
				Vector2(-5.2, -17), Vector2(5.2, -17), Vector2(4.4, -12), Vector2(-4.4, -12)
			])
			kit_helm.color = Color(0.22, 0.10, 0.08, 0.96)
			kit_helm.visible = true


func _apply_hostile_silhouette() -> void:
	if body == null:
		return
	_kind_color = _kind_body_color()
	body.polygon = _hostile_body_poly()
	body.color = _kind_color
	_ensure_chevron()
	_ensure_weapon()
	_ensure_helm()
	_ensure_trail()
	if body_outline == null or not is_instance_valid(body_outline):
		body_outline = get_node_or_null("BodyOutline") as Polygon2D
	if body_outline == null:
		body_outline = Polygon2D.new()
		body_outline.name = "BodyOutline"
		add_child(body_outline)
		move_child(body_outline, body.get_index())
	var pad := 3.2
	var outline := PackedVector2Array()
	for p in body.polygon:
		var n := p
		if n.length_squared() > 0.01:
			n = n.normalized() * (p.length() + pad)
		outline.append(n)
	body_outline.polygon = outline
	body_outline.color = _kind_outline_color()
	body_outline.rotation = body.rotation
	_refresh_tag()


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
	tag.text = "%s%d%s" % [kind_short(), label_id, bang]
	var col := _kind_color.lightened(0.25)
	if kind_id() == "sneak":
		col = Color(0.62, 0.78, 0.72)
	tag.add_theme_color_override("font_color", col)


func _apply_body_modulate() -> void:
	if body == null:
		return
	if not alive:
		body.modulate = Color(0.62, 0.62, 0.64, 0.72)
		if body_outline:
			body_outline.modulate = Color(0.55, 0.55, 0.55, 0.7)
		if chevron:
			chevron.modulate = Color(0.55, 0.55, 0.55, 0.65)
		if weapon:
			weapon.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_helm:
			kit_helm.modulate = Color(0.5, 0.5, 0.52, 0.7)
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
	if chevron:
		chevron.modulate = flash
	if weapon:
		weapon.modulate = flash
	if kit_helm:
		kit_helm.modulate = flash


func _apply_walk_bob() -> void:
	var bob := 0.0
	if alive and active:
		var amp := 0.7 if _is_power_saving() else 1.45
		var rate := 9.2 if kind_id() == "sneak" else (13.5 if kind_id() == "flank" else 11.5)
		bob = sin(_present_t * rate + float(label_id)) * amp
	if body:
		body.position = Vector2(0.0, bob) + _recoil_off
		if alive and (_death_tween == null or not is_instance_valid(_death_tween)):
			var punch := 1.0 + _hit_punch * 0.18
			body.scale = Vector2(punch, punch)
	if body_outline:
		body_outline.position = Vector2(0.0, bob) + _recoil_off
		if body:
			body_outline.scale = body.scale
	if weapon and is_instance_valid(weapon):
		weapon.rotation = _weapon_snap


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
	var xc := _kind_outline_color()
	var a := Line2D.new()
	a.width = 2.6
	a.default_color = Color(xc.r + 0.15, xc.g + 0.08, xc.b + 0.08, 0.95)
	a.points = PackedVector2Array([Vector2(-7, -7), Vector2(7, 7)])
	death_mark.add_child(a)
	var b := Line2D.new()
	b.width = 2.6
	b.default_color = a.default_color
	b.points = PackedVector2Array([Vector2(7, -7), Vector2(-7, 7)])
	death_mark.add_child(b)
	add_child(death_mark)


func _play_death_fx() -> void:
	if trail:
		trail.points = PackedVector2Array()
	_trail_world = PackedVector2Array()
	_ensure_death_mark()
	if death_mark:
		death_mark.visible = true
		death_mark.modulate.a = 0.0
		death_mark.create_tween().tween_property(death_mark, "modulate:a", 1.0, 0.16)
	if _death_tween != null:
		_death_tween.kill()
	if body == null:
		return
	_death_tween = create_tween()
	var squash := Vector2(1.12, 0.52)
	var extra := 0.22
	match kind_id():
		"flank":
			squash = Vector2(1.05, 0.40)
			extra = 0.72
		"sneak":
			squash = Vector2(1.22, 0.38)
			extra = 0.08
		_:
			squash = Vector2(1.18, 0.48)
			extra = 0.28
	_death_tween.tween_property(body, "scale", Vector2(1.24, 1.24), 0.05)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "scale", Vector2(1.24, 1.24), 0.05)
	_death_tween.tween_property(body, "scale", squash, 0.15)
	_death_tween.parallel().tween_property(body, "rotation", body.rotation + extra, 0.15)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "scale", squash, 0.15)
		_death_tween.parallel().tween_property(body_outline, "rotation", body.rotation + extra, 0.15)
	if kind_id() == "sneak":
		_death_tween.parallel().tween_property(body, "modulate:a", 0.35, 0.20)


func _reset_present_fx() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	_recoil_off = Vector2.ZERO
	_weapon_snap = 0.0
	_hit_punch = 0.0
	_dust_acc = 0.0
	if _foot_dust != null and is_instance_valid(_foot_dust):
		_foot_dust.emitting = false
	if body:
		body.scale = Vector2.ONE
		body.position = Vector2.ZERO
		body.modulate.a = 1.0
	if body_outline:
		body_outline.scale = Vector2.ONE
		body_outline.position = Vector2.ZERO
	if death_mark != null and is_instance_valid(death_mark):
		death_mark.visible = false
	if trail:
		trail.points = PackedVector2Array()
	if weapon != null and is_instance_valid(weapon):
		weapon.rotation = 0.0
		weapon.modulate = Color.WHITE


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


func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	var w := 24.0 * clampf(hp / MAX_HP, 0.0, 1.0)
	hp_bar.polygon = PackedVector2Array([
		Vector2(-12, -18), Vector2(-12 + w, -18), Vector2(-12 + w, -15), Vector2(-12, -15)
	])
	hp_bar.color = Color(0.2, 0.85, 0.35) if hp > 40.0 else Color(0.9, 0.25, 0.2)
