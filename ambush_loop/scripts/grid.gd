class_name AmbushGrid
extends RefCounted

## Static yard geometry for drawing + LOS checks. Enemies do NOT pathfind —
## they follow authored routes. Operators only stand on cover slots.

const TILE := 32
const COLS := 40
const ROWS := 22

var blocked: PackedByteArray = PackedByteArray()


func _init() -> void:
	blocked.resize(COLS * ROWS)
	blocked.fill(0)
	_build_yard()


func _build_yard() -> void:
	for x in COLS:
		set_blocked(x, 0, true)
		set_blocked(x, ROWS - 1, true)
	for y in ROWS:
		set_blocked(0, y, true)
		set_blocked(COLS - 1, y, true)

	# Compound shell
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

	# Interior cover blocks (crates / low walls) — LOS blockers
	_block_rect(8, 8, 11, 10)
	_block_rect(18, 9, 22, 12)
	_block_rect(27, 7, 30, 9)
	_block_rect(16, 14, 20, 16)

	# South escape mouth
	set_blocked(30, 18, false)
	set_blocked(31, 18, false)
	set_blocked(32, 18, false)


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


## Bresenham LOS — walls block shooting through crates.
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
