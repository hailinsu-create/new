class_name AmbushGrid
extends RefCounted

## Per-level collision/LOS geometry. Rebuilt on every level load.

const TILE := 32
const COLS := 20
const ROWS := 24
## The logical map is 640x768 and sits below the portrait header.
## Simulation positions, route points, and rendered map cells all use this
## same root-space origin so screen taps and LOS share one coordinate system.
const WORLD_ORIGIN := Vector2(40, 144)

var blocked: PackedByteArray = PackedByteArray()
var layout_id: String = "yard"
var door_cell: Vector2i = Vector2i(-1, -1)
var door_locked: bool = false


func _init() -> void:
	blocked.resize(COLS * ROWS)
	rebuild("yard")


func rebuild(level_id: String) -> void:
	layout_id = level_id
	# A layout rebuild starts from a clean door state.  Keeping the previous
	# door cell alive here could leave an old pump gate blocked after a reload.
	door_cell = Vector2i(-1, -1)
	door_locked = false
	blocked.fill(0)
	_build_shell()
	match level_id:
		"warehouse":
			_build_warehouse()
		"pump":
			_build_pump()
		_:
			_build_yard()
	_apply_door()


func set_door_state(cell: Vector2i, locked: bool) -> void:
	# Rebuild without the previous gate first, then apply only the requested
	# state.  This prevents stale blocked cells when returning to the yard or
	# switching between open and locked pump plans.
	var requested_cell := cell
	var requested_locked := locked
	door_cell = Vector2i(-1, -1)
	door_locked = false
	rebuild(layout_id)
	door_cell = requested_cell
	door_locked = requested_locked
	_apply_door()


func _apply_door() -> void:
	if door_cell.x < 0:
		return
	if door_locked:
		set_blocked(door_cell.x, door_cell.y, true)
	else:
		set_blocked(door_cell.x, door_cell.y, false)


func _build_shell() -> void:
	for x in COLS:
		set_blocked(x, 0, true)
		set_blocked(x, ROWS - 1, true)
	for y in ROWS:
		set_blocked(0, y, true)
		set_blocked(COLS - 1, y, true)
	# North entry and south escape mouth.
	set_blocked(9, 0, false)
	set_blocked(10, 0, false)
	set_blocked(9, ROWS - 1, false)
	set_blocked(10, ROWS - 1, false)


func _build_yard() -> void:
	_block_rect(2, 4, 5, 7)
	_block_rect(13, 4, 16, 6)
	_block_rect(3, 11, 6, 14)
	_block_rect(12, 12, 15, 15)
	_block_rect(3, 18, 5, 20)
	_block_rect(13, 18, 16, 20)


func _build_warehouse() -> void:
	_block_rect(3, 5, 6, 7)
	_block_rect(12, 5, 16, 6)
	_block_rect(3, 11, 6, 13)
	_block_rect(12, 11, 16, 13)
	_block_rect(5, 17, 8, 19)
	_block_rect(12, 17, 15, 19)


func _build_pump() -> void:
	_block_rect(3, 5, 6, 8)
	_block_rect(12, 4, 16, 6)
	_block_rect(3, 12, 6, 16)
	_block_rect(12, 12, 16, 15)
	_block_rect(7, 18, 10, 20)
	_block_rect(12, 18, 15, 20)


func _block_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			set_blocked(x, y, true)


func idx(x: int, y: int) -> int:
	return y * COLS + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < COLS and y < ROWS


func is_blocked(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return blocked[idx(x, y)] == 1


func set_blocked(x: int, y: int, value: bool) -> void:
	if in_bounds(x, y):
		blocked[idx(x, y)] = 1 if value else 0


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori((pos.x - WORLD_ORIGIN.x) / TILE),
		floori((pos.y - WORLD_ORIGIN.y) / TILE)
	)


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return WORLD_ORIGIN + Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)


func has_los(from: Vector2, to: Vector2) -> bool:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		if Vector2i(x0, y0) != a and Vector2i(x0, y0) != b:
			if is_blocked(x0, y0):
				return false
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true


## Assert covers stand on open cells and active route polylines never cross blocked cells.
## When `blocked_route` is set (door locked), that named primary route is skipped and `alt_route` is required.
func validate_level_geometry(
	cover_defs: Array,
	route_cells: Dictionary,
	alt_route: Array = [],
	blocked_route: String = ""
) -> PackedStringArray:
	var errs := PackedStringArray()
	for d in cover_defs:
		var c: Vector2i = d["cell"]
		if is_blocked(c.x, c.y):
			errs.append("cover blocked %s %s" % [d.get("name", "?"), str(c)])
	for key in route_cells.keys():
		if blocked_route != "" and str(key) == blocked_route:
			continue
		errs.append_array(_validate_route_cells(str(key), route_cells[key]))
	if not alt_route.is_empty():
		errs.append_array(_validate_route_cells("alternate", alt_route))
	elif blocked_route != "":
		errs.append("door locked but alternate route empty")
	return errs


func _validate_route_cells(name: String, cells: Array) -> PackedStringArray:
	var errs := PackedStringArray()
	for i in cells.size():
		var c: Vector2i = cells[i]
		if is_blocked(c.x, c.y):
			errs.append("route %s waypoint[%d] blocked %s" % [name, i, str(c)])
		if i > 0:
			var prev: Vector2i = cells[i - 1]
			errs.append_array(_validate_segment(name, prev, c))
	return errs


func _validate_segment(name: String, a: Vector2i, b: Vector2i) -> PackedStringArray:
	var errs := PackedStringArray()
	# Sample Bresenham cells between waypoint centers (same idea as LOS).
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		if Vector2i(x0, y0) != a and Vector2i(x0, y0) != b and is_blocked(x0, y0):
			errs.append("route %s segment hits blocked (%d,%d)" % [name, x0, y0])
			break
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return errs
