class_name EnemyRunner
extends Area2D

signal escaped(enemy: EnemyRunner, path: PackedVector2Array)
signal died(enemy: EnemyRunner)

const SPEED := 96.0
const RECORD_DIST := 8.0

var grid: AmbushGrid
var escape_world: Vector2
var alive: bool = true
var active: bool = false
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var recorded: PackedVector2Array = PackedVector2Array()
var label_id: int = 0

@onready var body: Polygon2D = $Body
@onready var tag: Label = $Tag


func setup(p_grid: AmbushGrid, p_escape: Vector2, p_id: int) -> void:
	grid = p_grid
	escape_world = p_escape
	label_id = p_id
	add_to_group("enemies")
	if tag:
		tag.text = "E%d" % p_id
	recorded.append(global_position)


func activate() -> void:
	active = true
	_repath()


func _repath() -> void:
	path = grid.find_path(global_position, escape_world)
	path_index = 0


## Prefer _process so headless/script runs stay consistent.
func _process(delta: float) -> void:
	if not active or not alive:
		return

	if path.is_empty() or path_index >= path.size():
		_repath()
		if path.is_empty():
			global_position = global_position.move_toward(escape_world, SPEED * delta)
			_record()
			return

	var target: Vector2 = path[path_index]
	global_position = global_position.move_toward(target, SPEED * delta)
	if global_position.distance_to(target) < 2.0:
		path_index += 1
	_record()


func _record() -> void:
	if recorded.is_empty() or global_position.distance_to(recorded[recorded.size() - 1]) >= RECORD_DIST:
		recorded.append(global_position)


func kill() -> void:
	if not alive:
		return
	alive = false
	active = false
	body.color = Color(0.35, 0.35, 0.38, 0.7)
	died.emit(self)


func mark_escaped() -> void:
	if not alive:
		return
	alive = false
	active = false
	recorded.append(global_position)
	escaped.emit(self, recorded.duplicate())
