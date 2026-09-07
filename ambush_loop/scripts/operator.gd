class_name OperatorUnit
extends Node2D

## A squad member stationed in cover with a locked overwatch cone.

const RANGE := 220.0
const HALF_ANGLE_DEG := 28.0
const DPS := 90.0

var op_id: int = 0
var display_name: String = "队员"
var facing_deg: float = 90.0
var locked: bool = false
var slot: CoverSlot = null

@onready var body: Polygon2D = $Body
@onready var cone: Polygon2D = $Cone
@onready var tag: Label = $Tag


func setup(id: int, pname: String) -> void:
	op_id = id
	display_name = pname
	if tag:
		tag.text = pname
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
	if cone:
		cone.color = Color(0.85, 0.35, 0.2, 0.22)


func _rebuild_cone() -> void:
	if cone == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 10
	var half := HALF_ANGLE_DEG
	for i in range(steps + 1):
		var t := lerpf(-half, half, float(i) / float(steps))
		var rad := deg_to_rad(facing_deg + t)
		pts.append(Vector2(cos(rad), sin(rad)) * RANGE)
	cone.polygon = pts
	cone.color = Color(0.95, 0.75, 0.25, 0.28) if not locked else Color(0.85, 0.35, 0.2, 0.22)
	if body:
		body.rotation = deg_to_rad(facing_deg + 90.0)


func can_engage(target: Vector2, grid: AmbushGrid) -> bool:
	var to_v := target - global_position
	var dist := to_v.length()
	if dist < 8.0 or dist > RANGE:
		return false
	var ang := rad_to_deg(atan2(to_v.y, to_v.x))
	var delta := absf(angle_diff_deg(facing_deg, ang))
	if delta > HALF_ANGLE_DEG:
		return false
	return grid.has_los(global_position, target)


static func angle_diff_deg(a: float, b: float) -> float:
	var d := fposmod(b - a + 180.0, 360.0) - 180.0
	return d
