class_name AmbushGrid
extends RefCounted

const TILE := 32
const COLS := 40
const ROWS := 22

var blocked: PackedByteArray = PackedByteArray()


func _init() -> void:
	blocked.resize(COLS * ROWS)
	blocked.fill(0)
	_build_default_map()


func _build_default_map() -> void:
	# Outer walls
	for x in COLS:
		set_blocked(x, 0, true)
		set_blocked(x, ROWS - 1, true)
	for y in ROWS:
		set_blocked(0, y, true)
		set_blocked(COLS - 1, y, true)

	# Fill northern band as wall, then carve two isolated spawn pockets
	for y in range(1, 6):
		for x in range(1, COLS - 1):
			set_blocked(x, y, true)

	# West spawn pocket + main breach
	for x in range(10, 15):
		for y in range(2, 5):
			set_blocked(x, y, false)
	set_blocked(12, 5, false)
	set_blocked(13, 5, false)

	# East spawn pocket + side breach
	for x in range(26, 31):
		for y in range(2, 5):
			set_blocked(x, y, false)
	set_blocked(28, 5, false)
	set_blocked(29, 5, false)

	# Central bunker splits south yard into west/east corridors
	for x in range(16, 25):
		for y in range(6, 16):
			set_blocked(x, y, true)

	# Keep runners from early edge-hugging to the escape
	for y in range(6, 17):
		set_blocked(36, y, true)
		set_blocked(37, y, true)
		set_blocked(38, y, true)

	# South wall with SE funnel into escape pocket
	for x in range(1, 30):
		set_blocked(x, 18, true)
	for y in range(18, 21):
		set_blocked(29, y, true)


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


func is_world_walkable(pos: Vector2) -> bool:
	var c := world_to_cell(pos)
	return not is_blocked(c.x, c.y)


func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var start := world_to_cell(from_world)
	var goal := world_to_cell(to_world)
	if is_blocked(start.x, start.y) or is_blocked(goal.x, goal.y):
		return PackedVector2Array()

	var came_from: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	came_from[start] = start
	var found := false
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for d in dirs:
			var n := cur + d
			if is_blocked(n.x, n.y):
				continue
			if came_from.has(n):
				continue
			came_from[n] = cur
			queue.append(n)

	var out := PackedVector2Array()
	if not found:
		return out

	var walk := goal
	var cells: Array[Vector2i] = []
	while walk != start:
		cells.push_front(walk)
		walk = came_from[walk]
	for c in cells:
		out.append(cell_to_world_center(c))
	return out
