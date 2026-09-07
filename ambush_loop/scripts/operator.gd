class_name OperatorUnit
extends Node2D

## Squad member in cover: limited ammo, can die to return fire, scavenges corpses.

const RANGE := 220.0
const HALF_ANGLE_DEG := 28.0
const DAMAGE_PER_SHOT := 34.0
const SHOT_INTERVAL := 0.18
const MAX_HP := 100.0
const START_AMMO := 7
const MAX_AMMO := 14
const COVER_DAMAGE_MULT := 0.4
const LOOT_RANGE := 52.0

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
	if body:
		body.color = Color(0.35, 0.65, 0.95)
		body.modulate = Color.WHITE
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
	_rebuild_cone()


## Cooldown advances on the simulation clock even with no target (blueprint P0).
func tick_cooldown(delta: float) -> void:
	if shot_cd > 0.0:
		shot_cd = maxf(shot_cd - delta, 0.0)


func _rebuild_cone() -> void:
	if cone == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 10
	for i in range(steps + 1):
		var t := lerpf(-HALF_ANGLE_DEG, HALF_ANGLE_DEG, float(i) / float(steps))
		var rad := deg_to_rad(facing_deg + t)
		pts.append(Vector2(cos(rad), sin(rad)) * RANGE)
	cone.polygon = pts
	if not alive:
		cone.color = Color(0.2, 0.2, 0.2, 0.12)
	elif ammo <= 0:
		cone.color = Color(0.45, 0.45, 0.5, 0.18)
	elif locked:
		cone.color = Color(0.85, 0.35, 0.2, 0.22)
	else:
		cone.color = Color(0.95, 0.75, 0.25, 0.28)
	if body:
		body.rotation = deg_to_rad(facing_deg + 90.0)


func can_engage(target: Vector2, grid: AmbushGrid) -> bool:
	if not alive or ammo <= 0:
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
	_refresh_tag()
	_rebuild_cone()
	return true


func take_damage(amount: float) -> void:
	if not alive:
		return
	# P0: flat cover mitigation; direction-aware cover is P2.
	hp -= amount * COVER_DAMAGE_MULT
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


func _refresh_tag() -> void:
	if tag == null:
		return
	if not alive:
		tag.text = "%s [阵亡]" % display_name
	else:
		tag.text = "%s  弹%d  HP%d" % [display_name, ammo, int(ceil(hp))]


static func angle_diff_deg(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0
