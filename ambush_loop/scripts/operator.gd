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
const CombatFxScript := preload("res://scripts/fx/combat_fx.gd")
const Silhouette := preload("res://scripts/fx/operator_silhouette.gd")

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
var role_rim: Line2D = null
var moon_rim: Line2D = null
var weapon: Polygon2D = null
var kit_gear: Polygon2D = null
var kit_helm: Polygon2D = null
var tag_emphasis: bool = false
var tag_plate: Polygon2D = null
var death_mark: Node2D = null
var _hit_flash: float = 0.0
var _present_t: float = 0.0
var _death_tween: Tween = null
var _recoil_off: Vector2 = Vector2.ZERO
var _weapon_snap: float = 0.0
var _hit_punch: float = 0.0
var hp_bar: Polygon2D = null
var shield_glyph: Polygon2D = null
var _hp_pulse: float = 0.0
var _shield_pulse: float = 0.0
var _cone_plan_color: Color = Color(0.95, 0.75, 0.25, 0.30)
var _cover_lean: Vector2 = Vector2.ZERO
var _outline_boost: bool = false
var cone_edge: Line2D = null
var sel_ring: Line2D = null
var face_chip: Label = null
var pack_glyph: Polygon2D = null
var _selected_visual: bool = false
var _land_pop: float = 0.0
var _face_tick: float = 0.0


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
	_ensure_hp_bar()
	_ensure_shield()
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
	_hp_pulse = 0.0
	_shield_pulse = 0.0
	_reset_present_fx()
	if body:
		body.color = body_color
	_apply_body_modulate()
	_refresh_role_glyph()
	_refresh_tag()
	_rebuild_cone()
	_update_hp_bar()
	_refresh_shield()


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
		CombatFxScript.ambush_arm(self, global_position)


func set_facing(deg: float) -> void:
	if locked:
		return
	var prev := facing_deg
	facing_deg = fposmod(deg, 360.0)
	if absf(angle_diff_deg(prev, facing_deg)) > 0.4:
		_face_tick = 1.0
	_rebuild_cone()
	_refresh_face_chip()


func rotate_by(delta_deg: float) -> void:
	set_facing(facing_deg + delta_deg)


func lock_plan() -> void:
	# Snapshot the SETUP cone tint, then freeze it for WATCHING (no alarm-red swap).
	_rebuild_cone()
	locked = true
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	_rebuild_cone()
	_refresh_face_chip()
	_tick_sel_ring()


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
	elif locked:
		var frozen := _cone_plan_color
		frozen.a = clampf(minf(frozen.a, 0.16), 0.10, 0.18)
		cone.color = frozen
		cone.visible = true
	else:
		if not fire_permitted:
			cone.color = Color(0.55, 0.55, 0.2, 0.22)
		elif ammo <= 0:
			cone.color = Color(0.45, 0.45, 0.5, 0.18)
		else:
			cone.color = Color(0.95, 0.75, 0.25, 0.30)
		# Snapshot the un-boosted hue so WATCHING freeze doesn't depend on selection.
		_cone_plan_color = cone.color
		if _selected_visual:
			var hot := cone.color
			hot.a = minf(hot.a + 0.08, 0.42)
			cone.color = hot
		cone.visible = true
	_rebuild_cone_edge(pts)
	if body:
		body.rotation = deg_to_rad(facing_deg + 90.0)
		# Human silhouette: head / shoulders / torso / two legs + kit.
		var poly := _role_body_poly()
		body.polygon = poly
		_ensure_body_outline()
		_ensure_role_rim()
		_ensure_moon_rim()
		_ensure_weapon()
		_ensure_kit_bits()
		_ensure_contact_shadow()
		if body_outline:
			body_outline.rotation = body.rotation
			body_outline.polygon = _inflate_poly(poly, _outline_pad())
			body_outline.color = _outline_color()
		_refresh_role_rim(poly)


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
	_hit_punch = 1.0
	_hp_pulse = 1.0
	if slot != null and from_pos != Vector2.INF and slot.protects_from(from_pos):
		_shield_pulse = 1.0
	_apply_body_modulate()
	_refresh_tag()
	_update_hp_bar()
	_refresh_shield()
	if hp <= 0.0:
		_die()
	else:
		CombatFxScript.impact(self, global_position, Color(1.0, 0.55, 0.32), false)
		_play_hit_sfx()


func _play_hit_sfx() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio = tree.root.get_node_or_null("/root/AudioDirector")
	if audio and audio.has_method("play"):
		audio.play("hit")


func cover_idle_planted() -> bool:
	return alive and visible and slot != null


func play_land_pop() -> void:
	_land_pop = 1.0
	CombatFxScript.land_dust(self, global_position)


func set_selected_visual(on: bool) -> void:
	_selected_visual = on and visible and alive
	_ensure_sel_ring()
	_refresh_face_chip()
	_rebuild_cone()


func _process(delta: float) -> void:
	_present_t += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta * 5.5, 0.0)
		_apply_body_modulate()
	if _hit_punch > 0.0:
		_hit_punch = maxf(_hit_punch - delta * 7.0, 0.0)
	if _hp_pulse > 0.0:
		_hp_pulse = maxf(_hp_pulse - delta * 5.0, 0.0)
		_update_hp_bar()
	if _shield_pulse > 0.0:
		_shield_pulse = maxf(_shield_pulse - delta * 3.6, 0.0)
		_refresh_shield()
	elif shield_glyph != null and is_instance_valid(shield_glyph) and shield_glyph.visible:
		shield_glyph.visible = false
	if _land_pop > 0.0:
		_land_pop = maxf(_land_pop - delta * 5.5, 0.0)
	if _face_tick > 0.0:
		_face_tick = maxf(_face_tick - delta * 4.8, 0.0)
		if cone_edge:
			cone_edge.width = 2.0 + _face_tick * 2.4
	_recoil_off = _recoil_off.lerp(Vector2.ZERO, 1.0 - exp(-delta * 16.0))
	if _recoil_off.length_squared() < 0.04:
		_recoil_off = Vector2.ZERO
	_weapon_snap = move_toward(_weapon_snap, 0.0, delta * 7.5)
	_cover_lean = _cover_lean.lerp(Vector2.ZERO, 1.0 - exp(-delta * 11.0))
	if _cover_lean.length_squared() < 0.04:
		_cover_lean = Vector2.ZERO
	_apply_idle_bob()
	_tick_outline_boost()
	_tick_sel_ring()
	_refresh_pack_glyph()


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
	_hp_pulse = 0.0
	_shield_pulse = 0.0
	if body:
		body.color = Color(0.25, 0.28, 0.32)
	_apply_body_modulate()
	_rebuild_cone()
	_refresh_tag()
	_refresh_role_glyph()
	_update_hp_bar()
	_refresh_shield()
	_play_death_fx()
	died.emit(self)


func _role_body_poly() -> PackedVector2Array:
	return Silhouette.body_poly(role)


func _ensure_weapon() -> void:
	if body == null:
		return
	Silhouette.mount(body, role)
	if weapon == null or not is_instance_valid(weapon):
		weapon = body.get_node_or_null("Weapon") as Polygon2D
	if weapon == null:
		weapon = get_node_or_null("Weapon") as Polygon2D
	if weapon:
		weapon.rotation = _weapon_snap
		weapon.visible = true
		weapon.modulate = Color(0.55, 0.55, 0.55, 0.75) if not alive else Color.WHITE


func _ensure_kit_bits() -> void:
	if body == null:
		return
	Silhouette.mount(body, role)
	if kit_helm == null or not is_instance_valid(kit_helm):
		kit_helm = body.get_node_or_null("KitHelm") as Polygon2D
	if kit_gear == null or not is_instance_valid(kit_gear):
		kit_gear = body.get_node_or_null("KitGear") as Polygon2D
	var dead_m := Color(0.55, 0.55, 0.55, 0.75) if not alive else Color.WHITE
	if kit_helm:
		kit_helm.visible = true
		kit_helm.modulate = dead_m
	if kit_gear:
		kit_gear.visible = true
		kit_gear.modulate = dead_m


func _outline_pad() -> float:
	## Fixed +2px over the old 3.4 stroke, scaled slightly with viewport height.
	var h := 720.0
	var vp := get_viewport()
	if vp:
		h = maxf(vp.get_visible_rect().size.y, 360.0)
	var pad := 5.4 * clampf(720.0 / h, 0.9, 1.35)
	if _outline_boost:
		pad += 1.0
	return pad


func _outline_color() -> Color:
	var kit := role_kit_color(role)
	return Color(
		clampf(kit.r * 0.42 + 0.08, 0.0, 1.0),
		clampf(kit.g * 0.48 + 0.10, 0.0, 1.0),
		clampf(kit.b * 0.40 + 0.08, 0.0, 1.0),
		1.0
	)


func _rim_color() -> Color:
	var kit := role_kit_color(role)
	return Color(kit.r, kit.g, kit.b, 0.95 if alive else 0.45)


func _spawn_muzzle_flash() -> void:
	var rad := deg_to_rad(facing_deg)
	var tip_len := absf(Silhouette.barrel_tip_y(role))
	var intensity := 1.0
	var style := "rifle"
	var tint := Color.WHITE
	match role:
		Role.MG:
			intensity = 1.48
			style = "mg"
			tint = Color(1.0, 0.88, 0.55)
		Role.SCOUT:
			intensity = 0.82
			style = "scout"
			tint = Color(0.85, 0.95, 1.0)
		_:
			intensity = 1.05
			style = "rifle"
	var tip := Vector2(cos(rad), sin(rad)) * tip_len
	MuzzleFlashScript.burst(self, tip, rad, tint, intensity, style)
	apply_recoil_kick()


func apply_recoil_kick() -> void:
	var rad := deg_to_rad(facing_deg)
	var back := Vector2(cos(rad), sin(rad)) * -1.0
	match role:
		Role.MG:
			_recoil_off = back * 5.4
			_weapon_snap = 0.28
		Role.SCOUT:
			_recoil_off = back * 2.6
			_weapon_snap = 0.12
		_:
			_recoil_off = back * 3.8
			_weapon_snap = 0.18
	_hit_punch = maxf(_hit_punch, 0.35)
	var lean_px := 4.6 if role == Role.MG else 3.0
	_cover_lean = Vector2(cos(rad), sin(rad)) * lean_px
	if slot != null and is_instance_valid(slot) and slot.has_method("kick_fire_lean"):
		slot.kick_fire_lean(facing_deg, role == Role.MG)


func _apply_idle_bob() -> void:
	var bob := 0.0
	var lean := 0.0
	if alive and visible:
		var amp := 0.55 if _is_power_saving() else 2.65
		bob = sin(_present_t * 3.15 + float(op_id) * 1.7) * amp
		# Subtle aim lean only while planning (alarm lock_plan sets locked).
		if not locked:
			lean = deg_to_rad(sin(_present_t * 1.85 + float(op_id)) * 3.4)
	if body:
		body.position = Vector2(0.0, bob) + _recoil_off + _cover_lean
		body.rotation = deg_to_rad(facing_deg + 90.0) + lean
		if alive and (_death_tween == null or not is_instance_valid(_death_tween)):
			var breath := 0.004 if _is_power_saving() else 0.016
			var punch := 1.0 + _hit_punch * 0.16
			var land := Vector2(1.0 + _land_pop * 0.22, 1.0 - _land_pop * 0.20)
			body.scale = Vector2(punch, punch * (1.0 + sin(_present_t * 2.15 + float(op_id)) * breath)) * land
	if body_outline:
		body_outline.position = Vector2(0.0, bob) + _recoil_off + _cover_lean
		body_outline.rotation = body.rotation if body else body_outline.rotation
		if body:
			body_outline.scale = body.scale
	if role_rim:
		role_rim.position = Vector2(0.0, bob) + _recoil_off + _cover_lean
		role_rim.rotation = body.rotation if body else role_rim.rotation
		if body:
			role_rim.scale = body.scale
	if moon_rim:
		moon_rim.position = Vector2(1.3, -1.7) + Vector2(0.0, bob) + _recoil_off + _cover_lean
		moon_rim.rotation = body.rotation if body else moon_rim.rotation
		if body:
			moon_rim.scale = body.scale
	if role_glyph:
		role_glyph.position = Vector2(15, -13 + bob * 0.4)
	if weapon and is_instance_valid(weapon):
		var sway := 0.0
		if alive and visible and not locked:
			sway = deg_to_rad(sin(_present_t * 1.65 + float(op_id) * 0.7) * 2.0)
		weapon.rotation = _weapon_snap + sway
	if body:
		Silhouette.pose_parts(body, role, {
			"t": _present_t,
			"recoil": _weapon_snap,
			"hit": _hit_punch,
			"alive": alive and visible,
			"saving": _is_power_saving(),
			"id": float(op_id),
			"planted": cover_idle_planted(),
		})
	if hp_bar:
		hp_bar.position = Vector2(0.0, bob * 0.2)
	if shield_glyph:
		shield_glyph.position = Vector2(-20, -8 + bob * 0.3)
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
		Vector2(-14, 5), Vector2(14, 5), Vector2(10, 16), Vector2(-10, 16)
	])
	pool.color = Color(0.08, 0.06, 0.05, 0.82)
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
	var squash := Vector2(1.28, 0.42)
	match role:
		Role.MG:
			squash = Vector2(1.46, 0.36)
		Role.SCOUT:
			squash = Vector2(1.08, 0.40)
		_:
			squash = Vector2(1.32, 0.38)
	var collapse := deg_to_rad(-72.0 if role == Role.SCOUT else (-58.0 if role == Role.MG else -64.0))
	_death_tween.tween_property(body, "scale", Vector2(1.22, 1.22), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "scale", Vector2(1.22, 1.22), 0.05)
	if role_rim:
		_death_tween.parallel().tween_property(role_rim, "scale", Vector2(1.22, 1.22), 0.05)
	_death_tween.tween_property(body, "scale", squash, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(body, "rotation", body.rotation + collapse, 0.16)
	if body_outline:
		_death_tween.parallel().tween_property(body_outline, "scale", squash, 0.16)
		_death_tween.parallel().tween_property(body_outline, "rotation", body.rotation + collapse, 0.16)
	if role_rim:
		_death_tween.parallel().tween_property(role_rim, "scale", squash, 0.16)
		_death_tween.parallel().tween_property(role_rim, "rotation", body.rotation + collapse, 0.16)
		_death_tween.parallel().tween_property(role_rim, "modulate:a", 0.25, 0.18)
	if role == Role.SCOUT:
		_death_tween.parallel().tween_property(body, "modulate:a", 0.42, 0.22)


func _reset_present_fx() -> void:
	if _death_tween != null:
		_death_tween.kill()
		_death_tween = null
	_recoil_off = Vector2.ZERO
	_weapon_snap = 0.0
	_hit_punch = 0.0
	_cover_lean = Vector2.ZERO
	_outline_boost = false
	if body:
		body.scale = Vector2.ONE
		body.position = Vector2.ZERO
		body.modulate.a = 1.0
	if body_outline:
		body_outline.scale = Vector2.ONE
		body_outline.position = Vector2.ZERO
	if role_rim:
		role_rim.scale = Vector2.ONE
		role_rim.position = Vector2.ZERO
		role_rim.modulate = Color.WHITE
	if moon_rim:
		moon_rim.scale = Vector2.ONE
		moon_rim.position = Vector2(1.3, -1.7)
		moon_rim.modulate = Color.WHITE
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
	_hp_pulse = 0.0
	_shield_pulse = 0.0
	_land_pop = 0.0
	_face_tick = 0.0
	if shield_glyph != null and is_instance_valid(shield_glyph):
		shield_glyph.visible = false
		shield_glyph.scale = Vector2.ONE
	if sel_ring:
		sel_ring.visible = false
	var br := get_node_or_null("SelBracket") as Node2D
	if br:
		br.visible = false
	if face_chip:
		face_chip.visible = false
	_update_hp_bar()


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


func _ensure_contact_shadow() -> void:
	var sh := get_node_or_null("ContactShadow") as Polygon2D
	if sh == null:
		sh = Polygon2D.new()
		sh.name = "ContactShadow"
		sh.z_index = -4
		sh.show_behind_parent = true
		add_child(sh)
		move_child(sh, 0)
	var rx := 11.0
	var ry := 5.2
	match role:
		Role.MG:
			rx = 13.6
			ry = 6.1
		Role.SCOUT:
			rx = 9.4
			ry = 4.5
		_:
			rx = 11.2
			ry = 5.2
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry + 11.6))
	sh.polygon = pts
	sh.rotation = 0.0
	sh.position = Vector2(2.6, 2.0)
	var a0 := 0.52 if alive else 0.22
	if _is_power_saving():
		a0 *= 0.65
	sh.color = Color(0.02, 0.03, 0.02, a0)
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
		cpts.append(Vector2(cos(a) * rx * 0.55, sin(a) * ry * 0.55 + 11.2))
	core.polygon = cpts
	core.position = Vector2(1.2, 1.0)
	core.color = Color(0.01, 0.02, 0.01, a0 * 1.25)
	core.visible = visible and not _is_power_saving()


func _ensure_role_rim() -> void:
	if role_rim != null and is_instance_valid(role_rim):
		return
	role_rim = get_node_or_null("RoleRim") as Line2D
	if role_rim == null:
		role_rim = Line2D.new()
		role_rim.name = "RoleRim"
		role_rim.closed = true
		role_rim.joint_mode = Line2D.LINE_JOINT_ROUND
		role_rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
		role_rim.end_cap_mode = Line2D.LINE_CAP_ROUND
		role_rim.z_index = 0
		add_child(role_rim)
		if body_outline != null and is_instance_valid(body_outline):
			move_child(role_rim, body_outline.get_index() + 1)


func _refresh_role_rim(poly: PackedVector2Array) -> void:
	_ensure_role_rim()
	if role_rim == null:
		return
	var pts := _inflate_poly(poly, _outline_pad() + 1.4)
	if pts.size() > 0:
		var loop := pts.duplicate()
		loop.append(loop[0])
		role_rim.points = loop
	role_rim.width = 2.2 if _is_power_saving() else 2.8
	role_rim.default_color = _rim_color()
	role_rim.visible = true
	if body:
		role_rim.rotation = body.rotation
	_refresh_moon_rim(poly)


func _ensure_moon_rim() -> void:
	if moon_rim != null and is_instance_valid(moon_rim):
		return
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


func _refresh_moon_rim(poly: PackedVector2Array) -> void:
	_ensure_moon_rim()
	if moon_rim == null:
		return
	var pts := _inflate_poly(poly, _outline_pad() + 2.2)
	var lit := PackedVector2Array()
	for p in pts:
		if p.x + p.y < 2.0:
			lit.append(p)
	if lit.size() < 3:
		lit = pts
	moon_rim.points = lit
	moon_rim.width = 1.4 if _is_power_saving() else 2.1
	moon_rim.default_color = Color(0.90, 0.96, 0.74, 0.88 if alive else 0.28)
	moon_rim.visible = alive
	if body:
		moon_rim.rotation = body.rotation


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
		if role_rim:
			role_rim.modulate = Color(0.55, 0.55, 0.55, 0.55)
		if moon_rim:
			moon_rim.modulate = Color(0.55, 0.55, 0.55, 0.45)
		if weapon:
			weapon.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_helm:
			kit_helm.modulate = Color(0.5, 0.5, 0.52, 0.7)
		if kit_gear:
			kit_gear.modulate = Color(0.5, 0.5, 0.52, 0.7)
		_tint_figure_parts(Color(0.55, 0.55, 0.58, 0.78))
		return
	var flash := Color(1.55, 1.55, 1.55).lerp(Color(1.85, 0.22, 0.16), _hit_flash)
	if hp < MAX_HP * 0.5:
		var wound := clampf((MAX_HP * 0.5 - hp) / (MAX_HP * 0.5), 0.0, 1.0)
		flash = flash.lerp(Color(1.28, 0.30, 0.22), 0.32 + 0.38 * wound)
	body.modulate = flash
	if body_outline:
		body_outline.modulate = Color(1, 1, 1, 1).lerp(Color(1.4, 1.1, 0.4), _hit_flash)
	if role_rim:
		role_rim.modulate = Color(1, 1, 1, 1).lerp(Color(1.5, 1.2, 0.5), _hit_flash)
	if weapon:
		weapon.modulate = flash
	if kit_helm:
		kit_helm.modulate = flash
	if kit_gear:
		kit_gear.modulate = flash
	_tint_figure_parts(flash)


func _tint_figure_parts(flash: Color) -> void:
	if body == null:
		return
	for nam in ["Head", "Visor", "LegL", "LegR", "ShoulderL", "ShoulderR", "TorsoShade", "ArmGun", "Cape", "FrontSight", "Sight", "BootL", "BootR", "Hip", "Pack", "Collar", "MoonFill", "KitHelm", "KitGear"]:
		var n := body.get_node_or_null(nam)
		if n is CanvasItem:
			(n as CanvasItem).modulate = flash


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
			return "铁砧 · 宽锥短距、耗弹最快；弹包第一优先。适合扫侧翼、等迟到走廊。"
		Role.SCOUT:
			return "夜枭 · 远距窄扇、弹少打重；锁出口/闸口。准备期淡青观察环=射程，不透视战斗。"
		_:
			return "灰狼 · 均衡步枪，主路补漏与第一枪。谁漏了就把他补上。"


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


func _ensure_hp_bar() -> void:
	if hp_bar != null and is_instance_valid(hp_bar):
		return
	hp_bar = get_node_or_null("HpBar") as Polygon2D
	if hp_bar == null:
		hp_bar = Polygon2D.new()
		hp_bar.name = "HpBar"
		hp_bar.z_index = 5
		add_child(hp_bar)


func _update_hp_bar() -> void:
	_ensure_hp_bar()
	if hp_bar == null:
		return
	var shown := visible and alive
	hp_bar.visible = shown
	if not shown:
		return
	var w := 26.0 * clampf(hp / MAX_HP, 0.0, 1.0)
	hp_bar.polygon = PackedVector2Array([
		Vector2(-13, -16), Vector2(-13 + w, -16), Vector2(-13 + w, -13), Vector2(-13, -13)
	])
	var pulse := 1.0 + _hp_pulse * 0.42
	hp_bar.scale = Vector2(pulse, pulse)
	if _hp_pulse > 0.05:
		hp_bar.color = Color(1.0, 0.55, 0.28).lerp(
			Color(0.22, 0.90, 0.42) if hp > 40.0 else Color(0.95, 0.28, 0.18),
			1.0 - _hp_pulse
		)
	else:
		hp_bar.color = Color(0.22, 0.88, 0.40) if hp > 40.0 else Color(0.92, 0.28, 0.18)


func _ensure_shield() -> void:
	if shield_glyph != null and is_instance_valid(shield_glyph):
		return
	shield_glyph = get_node_or_null("CoverShield") as Polygon2D
	if shield_glyph == null:
		shield_glyph = Polygon2D.new()
		shield_glyph.name = "CoverShield"
		shield_glyph.z_index = 6
		shield_glyph.polygon = PackedVector2Array([
			Vector2(0, -9), Vector2(8, -4), Vector2(6, 6), Vector2(0, 10), Vector2(-6, 6), Vector2(-8, -4)
		])
		shield_glyph.color = Color(0.55, 0.88, 0.95, 0.92)
		add_child(shield_glyph)
	shield_glyph.position = Vector2(-20, -8)


func _refresh_shield() -> void:
	_ensure_shield()
	if shield_glyph == null:
		return
	if _shield_pulse <= 0.02 or not alive or not visible:
		shield_glyph.visible = false
		shield_glyph.scale = Vector2.ONE
		return
	shield_glyph.visible = true
	var s := 1.0 + _shield_pulse * 0.28
	shield_glyph.scale = Vector2(s, s)
	shield_glyph.modulate = Color(1.25, 1.35, 1.2, 0.35 + 0.65 * _shield_pulse)


func hit_feedback() -> float:
	return _hp_pulse


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
	if body:
		var poly := body.polygon
		if body_outline:
			body_outline.polygon = _inflate_poly(poly, _outline_pad())
		_refresh_role_rim(poly)


func watching_cone_frozen() -> bool:
	## WATCHING keeps the SETUP cone hue, faint, so cover arcs stay readable.
	if not locked or cone == null or not is_instance_valid(cone):
		return false
	if not cone.visible or cone.polygon.size() < 4:
		return false
	var c := cone.color
	return c.a >= 0.08 and c.a <= 0.22 and c.g > 0.40


func _rebuild_cone_edge(pts: PackedVector2Array) -> void:
	if cone_edge == null or not is_instance_valid(cone_edge):
		cone_edge = get_node_or_null("ConeEdge") as Line2D
	if cone_edge == null:
		cone_edge = Line2D.new()
		cone_edge.name = "ConeEdge"
		cone_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		cone_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		cone_edge.joint_mode = Line2D.LINE_JOINT_ROUND
		cone_edge.z_index = -1
		cone_edge.show_behind_parent = true
		add_child(cone_edge)
	if pts.size() < 3:
		cone_edge.visible = false
		return
	var loop := PackedVector2Array()
	loop.append(pts[0])
	for i in range(1, pts.size()):
		loop.append(pts[i])
	loop.append(pts[0])
	cone_edge.points = loop
	cone_edge.visible = alive and visible
	var hot := _selected_visual and not locked
	cone_edge.width = (2.8 if hot else 1.7) + _face_tick * 2.2
	var kit := role_kit_color(role)
	if not alive:
		cone_edge.default_color = Color(0.35, 0.35, 0.35, 0.25)
	elif locked:
		cone_edge.default_color = Color(kit.r, kit.g, kit.b, 0.28)
	elif not fire_permitted:
		cone_edge.default_color = Color(0.72, 0.68, 0.22, 0.55 if hot else 0.38)
	else:
		cone_edge.default_color = Color(1.0, 0.86, 0.38, 0.82 if hot else 0.48)


func _ensure_sel_ring() -> void:
	if sel_ring == null or not is_instance_valid(sel_ring):
		sel_ring = get_node_or_null("SelRing") as Line2D
		if sel_ring == null:
			sel_ring = Line2D.new()
			sel_ring.name = "SelRing"
			sel_ring.width = 2.0
			sel_ring.closed = true
			sel_ring.z_index = 4
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * float(i) / 20.0
				pts.append(Vector2(cos(a), sin(a)) * 22.0)
			sel_ring.points = pts
			add_child(sel_ring)
	_ensure_sel_brackets()


func _ensure_sel_brackets() -> void:
	if get_node_or_null("SelBracket") != null:
		return
	var host := Node2D.new()
	host.name = "SelBracket"
	host.z_index = 5
	add_child(host)
	var s := 18.0
	var arm := 7.5
	var col := Color(1.0, 0.92, 0.42, 0.9)
	var corners: Array = [
		[Vector2(-s + arm, -s), Vector2(-s, -s), Vector2(-s, -s + arm)],
		[Vector2(-s, s - arm), Vector2(-s, s), Vector2(-s + arm, s)],
		[Vector2(s - arm, s), Vector2(s, s), Vector2(s, s - arm)],
		[Vector2(s, -s + arm), Vector2(s, -s), Vector2(s - arm, -s)],
	]
	for pts in corners:
		var ln := Line2D.new()
		ln.width = 2.3
		ln.default_color = col
		ln.begin_cap_mode = Line2D.LINE_CAP_BOX
		ln.end_cap_mode = Line2D.LINE_CAP_BOX
		ln.points = PackedVector2Array(pts)
		host.add_child(ln)


func _tick_sel_ring() -> void:
	_ensure_sel_ring()
	if sel_ring == null:
		return
	var on := _selected_visual and alive and visible and not locked
	sel_ring.visible = on
	var br := get_node_or_null("SelBracket") as Node2D
	if br:
		br.visible = on
	if not on:
		return
	var wave := 0.5 + 0.5 * sin(_present_t * 5.2)
	sel_ring.default_color = Color(0.98, 0.88, 0.38, 0.40 + 0.40 * wave)
	sel_ring.scale = Vector2.ONE * (1.0 + wave * 0.08)
	sel_ring.width = 2.4 + wave * 1.2
	if br:
		br.scale = Vector2.ONE * (1.0 + wave * 0.05)
		var col := Color(1.0, 0.92, 0.42, 0.70 + 0.28 * wave)
		for c in br.get_children():
			if c is Line2D:
				(c as Line2D).default_color = col


func _refresh_face_chip() -> void:
	if face_chip == null or not is_instance_valid(face_chip):
		face_chip = get_node_or_null("FaceChip") as Label
	if face_chip == null:
		face_chip = Label.new()
		face_chip.name = "FaceChip"
		face_chip.add_theme_font_size_override("font_size", 11)
		face_chip.add_theme_font_override("font", NightOps.ui_font_bold())
		face_chip.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.02, 0.92))
		face_chip.add_theme_constant_override("shadow_offset_x", 1)
		face_chip.add_theme_constant_override("shadow_offset_y", 1)
		face_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_chip.z_index = 5
		add_child(face_chip)
	var on := _selected_visual and alive and visible and not locked
	face_chip.visible = on
	if not on:
		return
	face_chip.text = "朝%s %d°" % [facing_compass(), int(round(facing_deg))]
	face_chip.position = Vector2(-28, 16)
	var kit := role_kit_color(role)
	face_chip.add_theme_color_override("font_color", Color(kit.r, kit.g, kit.b, 0.95).lerp(Color(1.0, 0.92, 0.45), _face_tick))


func _refresh_pack_glyph() -> void:
	if pack_glyph == null or not is_instance_valid(pack_glyph):
		pack_glyph = get_node_or_null("PackGlyph") as Polygon2D
	if pack_glyph == null:
		pack_glyph = Polygon2D.new()
		pack_glyph.name = "PackGlyph"
		pack_glyph.polygon = PackedVector2Array([
			Vector2(-6, -4), Vector2(6, -4), Vector2(5, 6), Vector2(-5, 6)
		])
		pack_glyph.color = Color(0.82, 0.68, 0.22, 0.95)
		pack_glyph.z_index = 4
		add_child(pack_glyph)
	var show := visible and alive and has_ammo_pack and not ammo_pack_used
	pack_glyph.visible = show
	if show:
		pack_glyph.position = Vector2(-16, 8)
		pack_glyph.modulate = Color(1.15, 1.1, 0.85)


func _refresh_tag() -> void:
	if tag == null:
		return
	tag.add_theme_font_size_override("font_size", 13 if tag_emphasis else 12)
	tag.add_theme_font_override("font", NightOps.ui_font_bold())
	if not alive:
		tag.text = "%s 阵亡" % display_name
		tag.add_theme_color_override("font_color", Color(0.62, 0.62, 0.64))
		return
	var pack := "包" if has_ammo_pack and not ammo_pack_used else ("已用包" if has_ammo_pack else "")
	var mode := "伏" if fire_mode == FireMode.HOLD_FOR_AMBUSH else "即"
	if fire_mode == FireMode.HOLD_FOR_AMBUSH and not fire_permitted:
		mode = "等"
	if tag_emphasis:
		tag.text = "%s  %s 弹%d%s" % [
			display_name, mode, ammo, (" " + pack) if pack != "" else ""
		]
	else:
		tag.text = "%s[%s] %s 弹%d%s" % [
			display_name, role_short, mode, ammo, (" " + pack) if pack != "" else ""
		]
	tag.add_theme_color_override("font_color", role_kit_color(role))


static func angle_diff_deg(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
