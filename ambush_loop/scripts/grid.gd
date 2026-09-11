class_name AmbushGrid
extends RefCounted

## Per-level collision/LOS geometry. Rebuilt on every level load.

const TILE := 32
const COLS := 40
const ROWS := 22

var blocked: PackedByteArray = PackedByteArray()
var layout_id: String = "yard"
var door_cell: Vector2i = Vector2i(-1, -1)
var door_locked: bool = false


func _init() -> void:
	blocked.resize(COLS * ROWS)
	rebuild("yard")


func rebuild(level_id: String) -> void:
	layout_id = level_id
	blocked.fill(0)
	_build_shell()
	match level_id:
		"warehouse":
			_build_warehouse()
		"pump":
			_build_pump()
		"railcut":
			_build_railcut()
		"depot":
			_build_depot()
		"radio":
			_build_radio()
		_:
			_build_yard()
	_apply_door()


func set_door_state(cell: Vector2i, locked: bool) -> void:
	door_cell = cell
	door_locked = locked
	rebuild(layout_id)
	door_cell = cell
	door_locked = locked
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
	for x in range(4, 36):
		set_blocked(x, 4, true)
		set_blocked(x, 18, true)
	for y in range(4, 19):
		set_blocked(4, y, true)
		set_blocked(35, y, true)
	# North entry
	set_blocked(12, 4, false)
	set_blocked(13, 4, false)
	set_blocked(14, 4, false)
	# South escape mouth
	set_blocked(30, 18, false)
	set_blocked(31, 18, false)
	set_blocked(32, 18, false)


func _build_yard() -> void:
	# Interior crates — leave spine x=12-14 and east lane x=31-33 open.
	_block_rect(8, 8, 11, 10)
	_block_rect(18, 9, 22, 12)
	_block_rect(27, 8, 30, 10)
	_block_rect(16, 14, 20, 16)


func _build_warehouse() -> void:
	# Shelves leave spine x=13, north lane y=5-6, and east x=32 open.
	_block_rect(7, 10, 9, 13)
	_block_rect(19, 10, 21, 13)
	_block_rect(25, 8, 26, 11)


func _build_pump() -> void:
	# Machinery; keep west approach, spine, and east corridor clear unless door locks.
	# East machine stays north of y=12 so 侧背点 has LOS west-south to (22,14).
	_block_rect(7, 10, 8, 13)
	_block_rect(17, 10, 19, 12)
	_block_rect(24, 10, 26, 11)


func _build_railcut() -> void:
	# Signal-tower core splits west spine (x=12-14) from east corridor (x=31-33).
	# North lane y=5-6 and south lane y=16-17 stay open so both authored routes walk.
	_block_rect(6, 7, 9, 13)
	_block_rect(15, 7, 28, 14)


func _build_depot() -> void:
	# Fuel tanks in the middle; west alley x=6-8 is the sneak. Spine x=12-14 and
	# east x=31-33 stay open. North y=5-6 and south y=16-17 remain the connectors.
	# A short crate row north of 南闸 blocks mouth-west LOS onto the sneak suffix.
	_block_rect(9, 7, 11, 13)
	_block_rect(15, 8, 23, 14)
	_block_rect(25, 8, 28, 12)
	_block_rect(25, 16, 27, 16)


func _build_radio() -> void:
	# Same corridor contract as depot: west alley x=6-8, spine x=12-14, east x=31-33.
	# North y=5-6 and south y=16-17 stay the connectors. Extra dish pad sits on
	# the core north face (y=7) so the layout is not a depot clone.
	_block_rect(9, 7, 11, 13)
	_block_rect(15, 8, 23, 14)
	_block_rect(25, 8, 28, 12)
	_block_rect(25, 16, 27, 16)
	_block_rect(16, 7, 22, 7)


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
	return Vector2i(int(pos.x / TILE), int(pos.y / TILE))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)


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
	blocked_route: String = "",
	barrel_cell: Vector2i = Vector2i(-1, -1)
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
	if barrel_cell.x >= 0:
		if is_blocked(barrel_cell.x, barrel_cell.y):
			errs.append("barrel blocked %s" % str(barrel_cell))
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
