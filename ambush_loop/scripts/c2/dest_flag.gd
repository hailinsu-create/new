class_name C2DestFlag
extends Node2D

## Commandos destination X. Stays until the selected op arrives.

var _life: float = 0.0
var _owner: Node2D = null


func _ready() -> void:
	z_index = 6
	visible = false


func plant(world: Vector2, owner: Node2D = null) -> void:
	global_position = world
	_owner = owner
	_life = 8.0
	visible = true
	queue_redraw()


func clear() -> void:
	visible = false
	_owner = null
	_life = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_life = maxf(_life - delta, 0.0)
	if _owner != null and is_instance_valid(_owner):
		if _owner.has_method("is_moving") and not bool(_owner.is_moving()):
			if global_position.distance_to(_owner.global_position) <= 18.0:
				clear()
				return
	elif _life <= 0.0:
		clear()
		return
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	var col := Color(0.92, 0.82, 0.28, 0.55 + 0.35 * pulse)
	draw_line(Vector2(-8, -8), Vector2(8, 8), col, 2.2, true)
	draw_line(Vector2(8, -8), Vector2(-8, 8), col, 2.2, true)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 18, Color(col.r, col.g, col.b, 0.35), 1.2, true)
	draw_circle(Vector2.ZERO, 2.2, col)
