class_name OperatorUnit
extends Node2D

## Squad specialist: distinct Commandos-style kits (rifle / MG / scout).

enum Role { RIFLE, MG, SCOUT }
enum FireMode { ENGAGE_ON_SIGHT, HOLD_FOR_AMBUSH }

const MAX_HP := 100.0
const COVER_DAMAGE_MULT := 0.4
const EXPOSED_DAMAGE_MULT := 1.0
const LOOT_RANGE := 52.0
const CONE_RAYS := 14
const MuzzleFlashScript := preload("res://scripts/fx/muzzle_flash.gd")

signal died(op: OperatorUnit)
signal fired_shot(op: OperatorUnit, target_pos: Vector2)
signal ammo_empty(op: OperatorUnit)
signal ammo_repacked(op: OperatorUnit)

var op_id: int = 0
var display_name: String = "队员"
var role: int = Role.RIFLE
var facing_deg: float = 90.0
var locked: bool = false
var slot: CoverSlot = null
var alive: bool = true
var hp: float = MAX_HP
var ammo: int = 7
var shot_cd: float = 0.0
var fire_mode: int = FireMode.ENGAGE_ON_SIGHT
var fire_permitted: bool = true
var has_ammo_pack: bool = false
var ammo_pack_used: bool = false
var grid: AmbushGrid = null
## Last no_engage reason per enemy id; log only when it changes.
var last_deny: Dictionary = {}

# Kit stats (filled by apply_role)
var range_px: float = 220.0
var half_angle_deg: float = 28.0
var damage_per_shot: float = 34.0
var shot_interval: float = 0.18
var start_ammo: int = 7
var max_ammo: int = 14
var body_color: Color = Color(0.35, 0.65, 0.95)
var role_short: String = "步"

@onready var body: Polygon2D = $Body
@onready var cone: Polygon2D = $Cone
@onready var tag: Label = $Tag

var obs_ring: Line2D = null
var obs_fill: Polygon2D = null
var obs_tag: Label = null
var role_glyph: Polygon2D = null
var body_outline: Polygon2D = null
var weapon: Polygon2D = null
var kit_gear: Polygon2D = null
var kit_helm: Polygon2D = null
var tag_plate: Polygon2D = null
var death_mark: Node2D = null
var _hit_flash: float = 0.0
var _present_t: float = 0.0
var _death_tween: Tween = null
var _recoil_off: Vector2 = Vector2.ZERO
var _weapon_snap: float = 0.0


static func role_for_id(id: int) -> int:
	match id:
		2:
			return Role.MG
		3:
			return Role.SCOUT
		_:
			return Role.RIFLE


static func role_display(role_id: int) -> String:
	match role_id:
		Role.MG:
			return "机枪手"
		Role.SCOUT:
			return "侦察兵"
		_:
			return "步枪手"


static func role_codename(role_id: int) -> String:
	match role_id:
		Role.MG:
			return "铁砧"
		Role.SCOUT:
			return "夜枭"
		_:
			return "灰狼"


static func role_kit_color(role_id: int) -> Color:
	match role_id:
		Role.MG:
			return Color(0.68, 0.78, 0.36)
		Role.SCOUT:
			return Color(0.38, 0.82, 0.92)
		_:
			return Color(0.52, 0.72, 0.92)


func setup(id: int, pname: String, p_grid: AmbushGrid = null) -> void:
	op_id = id
	role = role_for_id(id)
	var generic := pname.strip_edges() in ["", "队员", "步枪手", "机枪手", "侦察兵"]
	display_name = role_codename(role) if generic else pname
	grid = p_grid
	_apply_role_kit()
	_ensure_observation_visual()
	_refresh_role_glyph()
	reset_loadout()
	set_observation_ring(false)


func _apply_role_kit() -> void:
	match role:
		Role.MG:
			# Wider cone, faster cadence, shorter reach, hungrier ammo — Commandos "heavy".
			# Range stays near the old 220 so yard east-crate still covers the north flank lane.
			range_px = 205.0
			half_angle_deg = 48.0
			damage_per_shot = 22.0
			shot_interval = 0.10
			start_ammo = 12
			max_ammo = 18
			body_color = Color(0.46, 0.54, 0.28)
			role_short = "机"
		Role.SCOUT:
			# Long narrow overwatch, scarce rounds — Commandos sniper/lookout.
			# 20° half-angle keeps the reference exit slot (facing 180) on the south corridor.
			range_px = 280.0
			half_angle_deg = 20.0
			damage_per_shot = 42.0
			shot_interval = 0.28
			start_ammo = 6
			max_ammo = 10
			body_color = Color(0.26, 0.52, 0.62)
			role_short = "侦"
		_:
			# Rifle: stable filler, same baseline as the original identical kits.
			range_px = 220.0
			half_angle_deg = 28.0
			damage_per_shot = 34.0
			shot_interval = 0.18
			start_ammo = 7
			max_ammo = 14
			body_color = Color(0.40, 0.55, 0.68)
			role_short = "步"


func reset_loadout() -> void:
	alive = true
	hp = MAX_HP
	ammo = start_ammo
	shot_cd = 0.0
	locked = false
	ammo_pack_used = false
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	last_deny.clear()
	_hit_flash = 0.0
	_reset_present_fx()
	if body:
		body.color = body_color
	_apply_body_modulate()
	_refresh_role_glyph()
	_refresh_tag()
	_rebuild_cone()


func set_fire_mode(mode: int) -> void:
	if locked:
		return
	fire_mode = mode
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	_refresh_tag()
	_rebuild_cone()


func cycle_fire_mode() -> void:
	set_fire_mode(FireMode.HOLD_FOR_AMBUSH if fire_mode == FireMode.ENGAGE_ON_SIGHT else FireMode.ENGAGE_ON_SIGHT)


func arm_ambush() -> void:
	if fire_mode == FireMode.HOLD_FOR_AMBUSH and not fire_permitted:
		fire_permitted = true
		_refresh_tag()
		_rebuild_cone()


func set_facing(deg: float) -> void:
	if locked:
		return
	facing_deg = fposmod(deg, 360.0)
	_rebuild_cone()


func rotate_by(delta_deg: float) -> void:
	set_facing(facing_deg + delta_deg)


func lock_plan() -> void:
	locked = true
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	_rebuild_cone()


func tick_cooldown(delta: float) -> void:
	if shot_cd > 0.0:
		shot_cd = maxf(shot_cd - delta, 0.0)


func _los_clip_distance(local_dir: Vector2) -> float:
	## March along ray in world space; stop at first blocked cell (Commandos LOS cone).
	if grid == null:
		return range_px
	var origin := global_position
	var step := float(AmbushGrid.TILE) * 0.5
	var traveled := step
	var last_ok := step
	while traveled <= range_px:
		var sample: Vector2 = origin + local_dir * traveled
		var cell := grid.world_to_cell(sample)
		var origin_cell := grid.world_to_cell(origin)
		if cell != origin_cell and grid.is_blocked(cell.x, cell.y):
			return maxf(last_ok, step)
		if not grid.has_los(origin, sample):
			return maxf(last_ok, step)
		last_ok = traveled
		traveled += step
	return range_px


func _rebuild_cone() -> void:
	if cone == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(CONE_RAYS + 1):
		var t := lerpf(-half_angle_deg, half_angle_deg, float(i) / float(CONE_RAYS))
		var rad := deg_to_rad(facing_deg + t)
		var dir := Vector2(cos(rad), sin(rad))
		var dist := _los_clip_distance(dir)
		pts.append(dir * dist)
	cone.polygon = pts
	if not alive:
		cone.color = Color(0.2, 0.2, 0.2, 0.12)
	elif not fire_permitted:
		cone.color = Color(0.55, 0.55, 0.2, 0.22)
	elif ammo <= 0:
		cone.color = Color(0.45, 0.45, 0.5, 0.18)
	elif locked:
		cone.color = Color(0.85, 0.35, 0.2, 0.24)
	else:
		cone.color = Color(0.95, 0.75, 0.25, 0.30)
	if body:
		body.rotation = deg_to_rad(facing_deg + 90.0)
		# Distinct Commandos-lite kits: rifle lean, MG wide+bipod, scout slim+binocs.
		var poly := _role_body_poly()
		body.polygon = poly
		_ensure_body_outline()
		_ensure_weapon()
		_ensure_kit_bits()
		if body_outline:
			body_outline.rotation = body.rotation
			body_outline.polygon = _inflate_poly(poly, 3.4)
			body_outline.color = _outline_color()


func in_fire_geometry(target: Vector2, p_grid: AmbushGrid) -> bool:
	## Range + cone + LOS only — ignore ammo, hold-fire, and alive.
	var to_v := target - global_position
	var dist := to_v.length()
	if dist < 8.0 or dist > range_px:
		return false
	var ang := rad_to_deg(atan2(to_v.y, to_v.x))
	if absf(angle_diff_deg(facing_deg, ang)) > half_angle_deg:
		return false
	var g := p_grid if p_grid != null else grid
	if g == null:
		return false
	return g.has_los(global_position, target)


func engage_block_reason(target: Vector2, p_grid: AmbushGrid) -> String:
	## "" | hold | ammo | range | cone | los
	if not fire_permitted:
		return "hold"
	if ammo <= 0:
		return "ammo"
	var to_v := target - global_position
	var dist := to_v.length()
	if dist < 8.0 or dist > range_px:
		return "range"
	var ang := rad_to_deg(atan2(to_v.y, to_v.x))
	if absf(angle_diff_deg(facing_deg, ang)) > half_angle_deg:
		return "cone"
	var g := p_grid if p_grid != null else grid
	if g == null or not g.has_los(global_position, target):
		return "los"
	return ""


func can_engage(target: Vector2, p_grid: AmbushGrid) -> bool:
	if not alive:
		return false
	return engage_block_reason(target, p_grid) == ""


func try_fire(target: EnemyRunner, p_grid: AmbushGrid) -> bool:
	if not can_engage(target.global_position, p_grid):
		return false
	if shot_cd > 0.0:
		return false
	shot_cd = shot_interval
	ammo = maxi(ammo - 1, 0)
	fired_shot.emit(self, target.global_position)
	target.apply_fire(damage_per_shot, self)
	_spawn_muzzle_flash()
	if ammo == 0:
		var before := ammo
		_try_ammo_pack()
		if ammo > before:
			ammo_repacked.emit(self)
		else:
			ammo_empty.emit(self)
	_refresh_tag()
	_rebuild_cone()
	return true


func _try_ammo_pack() -> void:
	if has_ammo_pack and not ammo_pack_used:
		ammo_pack_used = true
		ammo = start_ammo
		_refresh_tag()


func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if not alive:
		return
	var mult := EXPOSED_DAMAGE_MULT
	if slot != null and from_pos != Vector2.INF and slot.protects_from(from_pos):
		mult = COVER_DAMAGE_MULT
	elif slot != null and from_pos == Vector2.INF:
		mult = COVER_DAMAGE_MULT
	# MG is heavier silhouette — slightly more exposed when not covered.
	if role == Role.MG and mult >= EXPOSED_DAMAGE_MULT:
		mult *= 1.15
	hp -= amount * mult
	_hit_flash = 1.0
	_apply_body_modulate()
	_refresh_tag()
	if hp <= 0.0:
		_die()


func _process(delta: float) -> void:
	_present_t += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta * 5.5, 0.0)
		_apply_body_modulate()
	_apply_idle_bob()


func _refresh_role_glyph() -> void:
	if role_glyph == null or not is_instance_valid(role_glyph):
		role_glyph = get_node_or_null("RoleGlyph") as Polygon2D
	if role_glyph == null:
		return
	role_glyph.position = Vector2(15, -13)
	role_glyph.z_index = 3
	role_glyph.visible = true
	match role:
		Role.MG:
			role_glyph.polygon = PackedVector2Array([
				Vector2(-6, -4), Vector2(6, -4), Vector2(5.2, 6), Vector2(-5.2, 6)
			])
			role_glyph.color = role_kit_color(role)
		Role.SCOUT:
			role_glyph.polygon = PackedVector2Array([
				Vector2(0, -7), Vector2(6.5, 0), Vector2(0, 7), Vector2(-6.5, 0)
			])
			role_glyph.color = role_kit_color(role)
		_:
			role_glyph.polygon = PackedVector2Array([
				Vector2(0, -7), Vector2(5.5, 6), Vector2(-5.5, 6)
			])
			role_glyph.color = role_kit_color(role)
	role_glyph.modulate = Color(0.55, 0.55, 0.55, 0.8) if not alive else Color.WHITE


func _die() -> void:
	alive = false
	hp = 0.0
	_hit_flash = 0.0
	if body:
		body.color = Color(0.25, 0.28, 0.32)
	_apply_body_modulate()
	_rebuild_cone()
	_refresh_tag()
	_refresh_role_glyph()
	_play_death_fx()
	died.emit(self)


func _role_body_poly() -> PackedVector2Array:
	match role:
		Role.MG:
			# Wide shoulders, flat helmet, blocky hips — readable as the heavy.
			return PackedVector2Array([
				Vector2(-5.5, -14), Vector2(5.5, -14),
				Vector2(8.5, -10), Vector2(13, -3), Vector2(13, 5),
				Vector2(9, 12), Vector2(4.5, 14), Vector2(-4.5, 14),
				Vector2(-9, 12), Vector2(-13, 5), Vector2(-13, -3), Vector2(-8.5, -10)
			])
		Role.SCOUT:
			# Slim diamond with a binocular bump on the right temple.
			return PackedVector2Array([
				Vector2(0, -17), Vector2(2.8, -14), Vector2(6.2, -12),
				Vector2(4.4, -7), Vector2(5.2, 7), Vector2(2.4, 13),
				Vector2(-2.4, 13), Vector2(-4.8, 7), Vector2(-3.8, -7), Vector2(-2.6, -14)
			])
		_:
			# Lean rifleman: narrow shoulders, long silhouette.
			return PackedVector2Array([
				Vector2(0, -16), Vector2(3.4, -13), Vector2(4.4, -7),
				Vector2(6.8, -1), Vector2(5.6, 8), Vector2(3.0, 13),
				Vector2(-1.6, 13), Vector2(-5.2, 8), Vector2(-6.2, -1),
				Vector2(-4.2, -7), Vector2(-3.0, -13)
			])


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
	# Local -Y is aim after body.rotation = facing+90°. Recoil snap is extra local rot.
	weapon.rotation = _weapon_snap
	match role:
		Role.MG:
			weapon.polygon = PackedVector2Array([
				Vector2(-3.6, -2), Vector2(3.8, -2), Vector2(3.2, -18),
				Vector2(1.2, -24), Vector2(-1.4, -24), Vector2(-3.0, -18)
			])
			weapon.color = Color(0.14, 0.12, 0.08, 0.98)
		Role.SCOUT:
			weapon.polygon = PackedVector2Array([
				Vector2(-0.95, -8), Vector2(0.95, -8), Vector2(0.7, -30),
				Vector2(0.2, -33), Vector2(-0.2, -33), Vector2(-0.7, -30)
			])
			weapon.color = Color(0.10, 0.14, 0.18, 0.98)
		_:
			weapon.polygon = PackedVector2Array([
				Vector2(-1.35, -5), Vector2(1.35, -5), Vector2(1.05, -26),
				Vector2(0.35, -30), Vector2(-0.35, -30), Vector2(-1.05, -26)
			])
			weapon.color = Color(0.12, 0.14, 0.16, 0.98)
	weapon.visible = true
	weapon.modulate = Color(0.55, 0.55, 0.55, 0.75) if not alive else Color.WHITE


func _ensure_kit_bits() -> void:
	if body == null:
		return
	if kit_helm == null or not is_instance_valid(kit_helm):
		kit_helm = get_node_or_null("KitHelm") as Polygon2D
	if kit_helm == null:
		kit_helm = Polygon2D.new()
		kit_helm.name = "KitHelm"
		kit_helm.z_index = 1
		body.add_child(kit_helm)
	if kit_gear == null or not is_instance_valid(kit_gear):
		kit_gear = get_node_or_null("KitGear") as Polygon2D
	if kit_gear == null:
		kit_gear = Polygon2D.new()
		kit_gear.name = "KitGear"
		kit_gear.z_index = 3
		body.add_child(kit_gear)
	match role:
		Role.MG:
			kit_helm.polygon = PackedVector2Array([
				Vector2(-6.5, -15), Vector2(6.5, -15), Vector2(5.5, -10), Vector2(-5.5, -10)
			])
			kit_helm.color = Color(0.22, 0.24, 0.14, 0.96)
			# Single bipod block (U) under the barrel — one polygon, no split fill.
			kit_gear.polygon = PackedVector2Array([
				Vector2(-8.5, -17), Vector2(8.5, -17), Vector2(10.0, -5), Vector2(6.2, -5),
				Vector2(2.2, -14), Vector2(-2.2, -14), Vector2(-6.2, -5), Vector2(-10.0, -5)
			])
			kit_gear.color = Color(0.18, 0.16, 0.10, 0.95)
		Role.SCOUT:
			kit_helm.polygon = PackedVector2Array([
				Vector2(-3.2, -18), Vector2(3.2, -18), Vector2(2.6, -13), Vector2(-2.6, -13)
			])
			kit_helm.color = Color(0.12, 0.22, 0.26, 0.96)
			# Binocular tube on the right temple.
			kit_gear.polygon = PackedVector2Array([
				Vector2(4.0, -15.5), Vector2(8.4, -15.5), Vector2(8.4, -6.0), Vector2(4.0, -6.0)
			])
			kit_gear.color = Color(0.18, 0.28, 0.32, 0.96)
		_:
			kit_helm.polygon = PackedVector2Array([
				Vector2(-3.6, -17), Vector2(3.6, -17), Vector2(3.0, -12.5), Vector2(-3.0, -12.5)
			])
			kit_helm.color = Color(0.16, 0.22, 0.28, 0.96)
			kit_gear.polygon = PackedVector2Array([
				Vector2(-2.2, 2), Vector2(2.2, 2), Vector2(1.6, 8), Vector2(-1.6, 8)
			])
			kit_gear.color = Color(0.22, 0.28, 0.24, 0.85)
	kit_helm.visible = true
	kit_gear.visible = true
	var dead_m := Color(0.55, 0.55, 0.55, 0.75) if not alive else Color.WHITE
	kit_helm.modulate = dead_m
	kit_gear.modulate = dead_m


func _outline_color() -> Color:
	match role:
		Role.MG:
			return Color(0.10, 0.12, 0.04, 0.98)
		Role.SCOUT:
			return Color(0.04, 0.12, 0.16, 0.98)
		_:
			return Color(0.05, 0.10, 0.16, 0.98)


func _spawn_muzzle_flash() -> void:
	var rad := deg_to_rad(facing_deg)
	var tip := Vector2(cos(rad), sin(rad)) * 20.0
	MuzzleFlashScript.burst(self, tip, rad)


func _apply_idle_bob() -> void:
	var bob := 0.0
	var lean := 0.0
	if alive and visible:
		var amp := 1.15 if _is_power_saving() else 1.55
		bob = sin(_present_t * 3.15 + float(op_id) * 1.7) * amp
		# Subtle aim lean only while planning (alarm lock_plan sets locked).
		if not locked:
			lean = deg_to_rad(sin(_present_t * 1.85 + float(op_id)) * 3.4)
	if body:
		body.position = Vector2(0.0, bob) + _recoil_off
		body.rotation = deg_to_rad(facing_deg + 90.0) + lean
	if body_outline:
		body_outline.position = Vector2(0.0, bob) + _recoil_off
		body_outline.rotation = body.rotation if body else body_outline.rotation
	if role_glyph:
		role_glyph.position = Vector2(15, -13 + bob * 0.4)
	if weapon and is_instance_valid(weapon):
		weapon.rotation = _weapon_snap
	_ensure_tag_plate(bob)


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _ensure_tag_plate(bob: float = 0.0) -> void:
	if tag == null:
		return
	if tag_plate == null or not is_instance_valid(tag_plate):
		tag_plate = get_node_or_null("TagPlate") as Polygon2D
	if tag_plate == null:
		tag_plate = Polygon2D.new()
		tag_plate.name = "TagPlate"
		tag_plate.z_index = 2
		add_child(tag_plate)
		if tag.get_parent() == self:
			move_child(tag_plate, tag.get_index())
	tag_plate.polygon = PackedVector2Array([
		Vector2(-32, -32), Vector2(36, -32), Vector2(36, -18), Vector2(-32, -18)
	])
	var plate := role_kit_color(role)
	tag_plate.color = Color(plate.r * 0.12, plate.g * 0.12, plate.b * 0.12, 0.72)
	tag_plate.position = Vector2(0.0, bob * 0.25)
	tag.position = Vector2(-30, -32 + bob * 0.25)
	tag.add_theme_color_override("font_color", role_kit_color(role) if alive else Color(0.62, 0.62, 0.64))
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.03, 0.9))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)


func _ensure_death_mark() -> void:
	if death_mark != null and is_instance_valid(death_mark):
		return
	death_mark = Node2D.new()
	death_mark.name = "DeathMark"
	death_mark.z_index = 4
	var pool := Polygon2D.new()
	pool.name = "Pool"
	pool.polygon = PackedVector2Array([
		Vector2(-11, 6), Vector2(11, 6), Vector2(8, 14), Vector2(-8, 14)
	])
	pool.color = Color(0.10, 0.08, 0.08, 0.78)
	death_mark.add_child(pool)
	var mark_c := role_kit_color(role).darkened(0.45)
	var a := Line2D.new()
	a.width = 2.8
	a.default_color = Color(mark_c.r, mark_c.g, mark_c.b, 0.95)
	a.points = PackedVector2Array([Vector2(-8, -8), Vector2(8, 8)])
	death_mark.add_child(a)
	var b := Line2D.new()
	b.width = 2.8
	b.default_color = Color(mark_c.r, mark_c.g, mark_c.b, 0.95)
	b.points = PackedVector2Array([Vector2(8, -8), Vector2(-8, 8)])
	death_mark.add_child(b)
	add_child(death_mark)


func _play_death_fx() -> void:
	_ensure_death_mark()
	if death_mark:
		death_mark.visible = true
		death_mark.modulate.a = 0.0
		var fade := death_mark.create_tween()
		fade.tween_property(death_mark, "modulate:a", 1.0, 0.20)
	if _death_tween != null:
		_death_tween.kill()
	if body == null:
		return
	_death_tween = create_tween()
	var squash := Vector2(1.12, 0.58)
	var extra_rot := 0.18
	match role:
		Role.MG:
			squash = Vector2(1.32, 0.42)
			extra_rot = 0.08
		Role.SCOUT:
			squash = Vector2(0.82, 0.52)
			extra_rot = 0.55
		_:
			squash = Vector2(1.18, 0.48)
			extra_rot = 0.32
	_death_tween.tween_property(body, "scale", squash, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(body, "rotation", body.rotation + extra_rot, 0.18)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "scale", squash, 0.18)
		_death_tween.parallel().tween_property(body_outline, "rotation", body.rotation + extra_rot, 0.18)
	if role == Role.SCOUT:
		_death_tween.parallel().tween_property(body, "modulate:a", 0.42, 0.22)


func _reset_present_fx() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	_recoil_off = Vector2.ZERO
	_weapon_snap = 0.0
	if body:
		body.scale = Vector2.ONE
		body.position = Vector2.ZERO
		body.modulate.a = 1.0
	if body_outline:
		body_outline.scale = Vector2.ONE
		body_outline.position = Vector2.ZERO
	if death_mark != null and is_instance_valid(death_mark):
		death_mark.visible = false
	if weapon != null and is_instance_valid(weapon):
		weapon.modulate = Color.WHITE
		weapon.visible = true
		weapon.rotation = 0.0
	if kit_helm != null and is_instance_valid(kit_helm):
		kit_helm.modulate = Color.WHITE
	if kit_gear != null and is_instance_valid(kit_gear):
		kit_gear.modulate = Color.WHITE


func _ensure_body_outline() -> void:
	if body_outline != null and is_instance_valid(body_outline):
		return
	body_outline = get_node_or_null("BodyOutline") as Polygon2D
	if body_outline == null and body != null:
		body_outline = Polygon2D.new()
		body_outline.name = "BodyOutline"
		body_outline.z_index = -1
		body_outline.show_behind_parent = false
		add_child(body_outline)
		move_child(body_outline, body.get_index())


func _inflate_poly(src: PackedVector2Array, pad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		var n := p
		if n.length_squared() > 0.01:
			n = n.normalized() * (p.length() + pad)
		out.append(n)
	return out


func _apply_body_modulate() -> void:
	if body == null:
		return
	if not alive:
		body.modulate = Color(0.55, 0.55, 0.58, 0.78)
		if body_outline:
			body_outline.modulate = Color(0.5, 0.5, 0.5, 0.7)
		if weapon:
			weapon.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_helm:
			kit_helm.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_gear:
			kit_gear.modulate = Color(0.5, 0.5, 0.52, 0.7)
		return
	var flash := Color(1.0, 1.0, 1.0).lerp(Color(1.85, 1.55, 0.55), _hit_flash)
	body.modulate = flash
	if body_outline:
		body_outline.modulate = Color(1, 1, 1, 1).lerp(Color(1.4, 1.1, 0.4), _hit_flash)
	if weapon:
		weapon.modulate = flash
	if kit_helm:
		kit_helm.modulate = flash
	if kit_gear:
		kit_gear.modulate = flash


func can_reach_loot(loot_pos: Vector2, p_grid: AmbushGrid) -> bool:
	if not alive:
		return false
	if global_position.distance_to(loot_pos) > LOOT_RANGE:
		return false
	var g := p_grid if p_grid != null else grid
	if g == null:
		return false
	return g.has_los(global_position, loot_pos)


func receive_ammo(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var room := max_ammo - ammo
	var gained := mini(amount, room)
	ammo += gained
	_refresh_tag()
	_rebuild_cone()
	return gained


func fire_mode_label() -> String:
	return "见敌即打" if fire_mode == FireMode.ENGAGE_ON_SIGHT else "入伏再打"


func _ensure_observation_visual() -> void:
	if role != Role.SCOUT:
		return
	if obs_fill == null or not is_instance_valid(obs_fill):
		obs_fill = Polygon2D.new()
		obs_fill.name = "ObsFill"
		obs_fill.z_index = -2
		obs_fill.show_behind_parent = true
		add_child(obs_fill)
	if obs_ring == null or not is_instance_valid(obs_ring):
		obs_ring = Line2D.new()
		obs_ring.name = "ObsRing"
		obs_ring.width = 1.6
		obs_ring.closed = true
		obs_ring.default_color = Color(0.42, 0.88, 1.0, 0.38)
		obs_ring.z_index = -1
		obs_ring.show_behind_parent = true
		add_child(obs_ring)
	if obs_tag == null or not is_instance_valid(obs_tag):
		obs_tag = Label.new()
		obs_tag.name = "ObsTag"
		obs_tag.text = "观察环"
		obs_tag.position = Vector2(-28, -48)
		obs_tag.add_theme_font_size_override("font_size", 11)
		obs_tag.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 0.75))
		obs_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(obs_tag)
	_rebuild_observation_ring()


func _rebuild_observation_ring() -> void:
	if obs_ring == null and obs_fill == null:
		return
	var pts := PackedVector2Array()
	const RAYS := 36
	for i in RAYS:
		var r := deg_to_rad(float(i) * (360.0 / float(RAYS)))
		pts.append(Vector2(cos(r), sin(r)) * range_px)
	if obs_ring:
		var loop := pts.duplicate()
		if loop.size() > 0:
			loop.append(loop[0])
		obs_ring.points = loop
	if obs_fill:
		obs_fill.polygon = pts
		obs_fill.color = Color(0.35, 0.8, 0.95, 0.045)


func set_observation_ring(show: bool) -> void:
	_ensure_observation_visual()
	var on := show and role == Role.SCOUT and visible and alive
	if obs_ring:
		obs_ring.visible = on
	if obs_fill:
		obs_fill.visible = on
	if obs_tag:
		obs_tag.visible = on


func observation_ring_visible() -> bool:
	return role == Role.SCOUT and obs_ring != null and is_instance_valid(obs_ring) and obs_ring.visible


func kit_blurb() -> String:
	match role:
		Role.MG:
			return "铁砧 · 宽射界·高射速·短距·耗弹快；侧背更危险"
		Role.SCOUT:
			return "夜枭 · 远距·窄扇区·弹少打重；适合出口/侧翼锁线。准备期淡青观察环=射程，不透视战斗"
		_:
			return "灰狼 · 均衡步枪：补漏与持续压制"


func facing_compass() -> String:
	var d := fposmod(facing_deg, 360.0)
	if d >= 315.0 or d < 45.0:
		return "东"
	if d < 135.0:
		return "南"
	if d < 225.0:
		return "西"
	return "北"


func kit_card_text() -> String:
	var dep := "未部署"
	if visible and slot != null:
		dep = slot.label_text
	var cone := int(round(half_angle_deg * 2.0))
	if not visible or slot == null:
		return "%s [%s]  %s\n%s  弹%d/%d  锥%d°  射程%d" % [
			display_name, role_short, dep, fire_mode_label(), ammo, max_ammo, cone, int(range_px)
		]
	return "%s [%s]  %s\n%s  弹%d/%d  锥%d°  朝%s %d°" % [
		display_name,
		role_short,
		dep,
		fire_mode_label(),
		ammo,
		max_ammo,
		cone,
		facing_compass(),
		int(facing_deg),
	]


func _refresh_tag() -> void:
	if tag == null:
		return
	tag.add_theme_font_size_override("font_size", 12)
	if not alive:
		tag.text = "%s 阵亡" % display_name
		tag.add_theme_color_override("font_color", Color(0.62, 0.62, 0.64))
		return
	var pack := "包" if has_ammo_pack and not ammo_pack_used else ("已用包" if has_ammo_pack else "")
	var mode := "伏" if fire_mode == FireMode.HOLD_FOR_AMBUSH else "即"
	if fire_mode == FireMode.HOLD_FOR_AMBUSH and not fire_permitted:
		mode = "等"
	tag.text = "%s[%s] %s 弹%d%s" % [
		display_name, role_short, mode, ammo, (" " + pack) if pack != "" else ""
	]
	tag.add_theme_color_override("font_color", role_kit_color(role))


static func angle_diff_deg(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
