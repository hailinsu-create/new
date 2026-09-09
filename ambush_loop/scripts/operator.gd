class_name OperatorUnit
extends Node2D

## Squad member: ammo, fire modes, directional cover, optional ammo pack.

const RANGE := 220.0
const HALF_ANGLE_DEG := 28.0
const DAMAGE_PER_SHOT := 34.0
const SHOT_INTERVAL := 0.18
const MAX_HP := 100.0
const START_AMMO := 7
const MAX_AMMO := 14
const COVER_DAMAGE_MULT := 0.4
const EXPOSED_DAMAGE_MULT := 1.0
const LOOT_RANGE := 52.0

enum FireMode { ENGAGE_ON_SIGHT, HOLD_FOR_AMBUSH }

signal died(op: OperatorUnit)

var op_id: int = 0
var display_name: String = "队员"
var facing_deg: float = 90.0
var locked: bool = false
var slot: CoverSlot = null
var alive: bool = true
var hp: float = MAX_HP
var ammo: int = START_AMMO
var shot_cd: float = 0.0
var fire_mode: int = FireMode.ENGAGE_ON_SIGHT
var fire_permitted: bool = true # HOLD_FOR_AMBUSH starts false until zone trigger
var has_ammo_pack: bool = false
var ammo_pack_used: bool = false

@onready var body: Polygon2D = $Body
@onready var cone: Polygon2D = $Cone
@onready var tag: Label = $Tag


func setup(id: int, pname: String) -> void:
	op_id = id
	display_name = pname
	reset_loadout()


func reset_loadout() -> void:
	alive = true
	hp = MAX_HP
	ammo = START_AMMO
	shot_cd = 0.0
	locked = false
	ammo_pack_used = false
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	if body:
		body.color = Color(0.35, 0.65, 0.95)
		body.modulate = Color.WHITE
	_refresh_tag()
	_rebuild_cone()


func set_fire_mode(mode: int) -> void:
	if locked:
		return
	fire_mode = mode
	fire_permitted = fire_mode == FireMode.ENGAGE_ON_SIGHT
	_refresh_tag()


func cycle_fire_mode() -> void:
	set_fire_mode(FireMode.HOLD_FOR_AMBUSH if fire_mode == FireMode.ENGAGE_ON_SIGHT else FireMode.ENGAGE_ON_SIGHT)


func arm_ambush() -> void:
	if fire_mode == FireMode.HOLD_FOR_AMBUSH and not fire_permitted:
		fire_permitted = true
		_refresh_tag()


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


func _rebuild_cone() -> void:
	if cone == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(11):
		var t := lerpf(-HALF_ANGLE_DEG, HALF_ANGLE_DEG, float(i) / 10.0)
		var rad := deg_to_rad(facing_deg + t)
		pts.append(Vector2(cos(rad), sin(rad)) * RANGE)
	cone.polygon = pts
	if not alive:
		cone.color = Color(0.2, 0.2, 0.2, 0.12)
	elif not fire_permitted:
		cone.color = Color(0.55, 0.55, 0.2, 0.2)
	elif ammo <= 0:
		cone.color = Color(0.45, 0.45, 0.5, 0.18)
	elif locked:
		cone.color = Color(0.85, 0.35, 0.2, 0.22)
	else:
		cone.color = Color(0.95, 0.75, 0.25, 0.28)
	if body:
		body.rotation = deg_to_rad(facing_deg + 90.0)
	# The presentation children share the body orientation, while the cone above
	# remains in simulation coordinates.  This cannot affect aiming or damage.
	for visual_name in ["Outline", "Weapon"]:
		var visual := get_node_or_null(visual_name) as Node2D
		if visual != null:
			visual.rotation = deg_to_rad(facing_deg + 90.0)


func can_engage(target: Vector2, grid: AmbushGrid) -> bool:
	if not alive or ammo <= 0 or not fire_permitted:
		return false
	var to_v := target - global_position
	var dist := to_v.length()
	if dist < 8.0 or dist > RANGE:
		return false
	var ang := rad_to_deg(atan2(to_v.y, to_v.x))
	if absf(angle_diff_deg(facing_deg, ang)) > HALF_ANGLE_DEG:
		return false
	return grid.has_los(global_position, target)


func try_fire(target: EnemyRunner, grid: AmbushGrid) -> bool:
	if not can_engage(target.global_position, grid):
		return false
	if shot_cd > 0.0:
		return false
	shot_cd = SHOT_INTERVAL
	ammo = maxi(ammo - 1, 0)
	target.apply_fire(DAMAGE_PER_SHOT, self)
	if ammo == 0:
		_try_ammo_pack()
	_refresh_tag()
	_rebuild_cone()
	return true


func _try_ammo_pack() -> void:
	if has_ammo_pack and not ammo_pack_used:
		ammo_pack_used = true
		ammo = START_AMMO
		_refresh_tag()


func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if not alive:
		return
	var mult := EXPOSED_DAMAGE_MULT
	if slot != null and from_pos != Vector2.INF and slot.protects_from(from_pos):
		mult = COVER_DAMAGE_MULT
	elif slot != null and from_pos == Vector2.INF:
		mult = COVER_DAMAGE_MULT # legacy callers
	hp -= amount * mult
	_refresh_tag()
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	hp = 0.0
	if body:
		body.color = Color(0.25, 0.28, 0.32)
		body.modulate = Color(0.6, 0.6, 0.6, 0.85)
	_rebuild_cone()
	_refresh_tag()
	died.emit(self)


func can_reach_loot(loot_pos: Vector2, grid: AmbushGrid) -> bool:
	if not alive:
		return false
	if global_position.distance_to(loot_pos) > LOOT_RANGE:
		return false
	return grid.has_los(global_position, loot_pos)


func receive_ammo(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var room := MAX_AMMO - ammo
	var gained := mini(amount, room)
	ammo += gained
	_refresh_tag()
	_rebuild_cone()
	return gained


func fire_mode_label() -> String:
	return "见敌即打" if fire_mode == FireMode.ENGAGE_ON_SIGHT else "入伏再打"


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
	tag.text = "%s %s 弹%d%s" % [display_name, mode, ammo, (" " + pack) if pack != "" else ""]


static func angle_diff_deg(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
