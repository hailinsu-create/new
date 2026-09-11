class_name PlanState
extends RefCounted

## Editable / frozen ambush plan (blueprint §5).

var deployments: Array = [] # {op_id, slot_id, facing, fire_mode, has_ammo_pack}
var tripwire_positions: Array[Vector2] = []
var door_locked: bool = false


func clear() -> void:
	deployments.clear()
	tripwire_positions.clear()
	door_locked = false


func duplicate_plan() -> PlanState:
	var p := PlanState.new()
	for d in deployments:
		p.deployments.append(d.duplicate(true))
	p.tripwire_positions = tripwire_positions.duplicate()
	p.door_locked = door_locked
	return p
