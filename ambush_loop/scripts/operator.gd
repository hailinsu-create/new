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


func setup(id: int, pname: String, p_grid: AmbushGrid = null) -> void:
	op_id = id
	role = role_for_id(id)
	display_name = pname if pname != "" else role_display(role)
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
			body_color = Color(0.45, 0.55, 0.35)
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
			body_color = Color(0.35, 0.55, 0.75)
			role_short = "侦"
		_:
			# Rifle: stable filler, same baseline as the original identical kits.
			range_px = 220.0
			half_angle_deg = 28.0
			damage_per_shot = 34.0
			shot_interval = 0.18
			start_ammo = 7
			max_ammo = 14
			body_color = Color(0.35, 0.65, 0.95)
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
	if body:
		body.color = body_color
		body.modulate = Color.WHITE
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
		# Distinct silhouettes per role (Commandos readability).
		match role:
			Role.MG:
				body.polygon = PackedVector2Array([
					Vector2(0, -10), Vector2(10, 8), Vector2(4, 10), Vector2(-4, 10), Vector2(-10, 8)
				])
			Role.SCOUT:
				body.polygon = PackedVector2Array([
					Vector2(0, -13), Vector2(6, 8), Vector2(-6, 8)
				])
			_:
				body.polygon = PackedVector2Array([
					Vector2(0, -11), Vector2(8, 9), Vector2(-8, 9)
				])


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
	_refresh_tag()
	if hp <= 0.0:
		_die()


func _refresh_role_glyph() -> void:
	if role_glyph == null or not is_instance_valid(role_glyph):
		role_glyph = get_node_or_null("RoleGlyph") as Polygon2D
	if role_glyph == null:
		return
	role_glyph.position = Vector2(13, -11)
	role_glyph.z_index = 2
	match role:
		Role.MG:
			role_glyph.polygon = PackedVector2Array([
				Vector2(-5, -3), Vector2(5, -3), Vector2(4, 5), Vector2(-4, 5)
			])
			role_glyph.color = Color(0.62, 0.74, 0.38)
		Role.SCOUT:
			role_glyph.polygon = PackedVector2Array([
				Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)
			])
			role_glyph.color = Color(0.42, 0.78, 0.92)
		_:
			role_glyph.polygon = PackedVector2Array([
				Vector2(0, -6), Vector2(5, 5), Vector2(-5, 5)
			])
			role_glyph.color = Color(0.42, 0.72, 0.96)
	role_glyph.modulate = Color(0.55, 0.55, 0.55, 0.8) if not alive else Color.WHITE


func _die() -> void:
	alive = false
	hp = 0.0
	if body:
		body.color = Color(0.25, 0.28, 0.32)
		body.modulate = Color(0.6, 0.6, 0.6, 0.85)
	_rebuild_cone()
	_refresh_tag()
	_refresh_role_glyph()
	died.emit(self)


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
			return "宽射界·高射速·短距·耗弹快；侧背更危险"
		Role.SCOUT:
			return "远距·窄扇区·弹少打重；适合出口/侧翼锁线。准备期淡青观察环=射程，不透视战斗"
		_:
			return "均衡步枪：补漏与持续压制"


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
	if not alive:
		tag.text = "%s [阵亡]" % display_name
		return
	var pack := "包" if has_ammo_pack and not ammo_pack_used else ("已用包" if has_ammo_pack else "")
	var mode := "伏" if fire_mode == FireMode.HOLD_FOR_AMBUSH else "即"
	if fire_mode == FireMode.HOLD_FOR_AMBUSH and not fire_permitted:
		mode = "等"
	tag.text = "%s[%s] %s 弹%d%s" % [
		display_name, role_short, mode, ammo, (" " + pack) if pack != "" else ""
	]


static func angle_diff_deg(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
