extends Node2D

var grid: AmbushGrid
var escape_cell: Vector2i = Vector2i(-1, -1)
var barrel_cell: Vector2i = Vector2i(-1, -1)
var escape_flash: bool = false
var _flash_t: float = 0.0


func _process(delta: float) -> void:
	if escape_flash:
		_flash_t += delta
		queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var tile := AmbushGrid.TILE
	for y in AmbushGrid.ROWS:
		for x in AmbushGrid.COLS:
			var rect := Rect2(x * tile, y * tile, tile, tile)
			if grid.is_blocked(x, y):
				_draw_wall_tile(rect, x, y)
			else:
				_draw_floor_tile(rect, x, y)
	if barrel_cell.x >= 0:
		var brect := Rect2(
			barrel_cell.x * tile, barrel_cell.y * tile, tile, tile
		)
		draw_rect(brect, Color(0.98, 0.42, 0.08, 0.28))
		draw_rect(brect, Color(1.0, 0.55, 0.18, 0.7), false, 2.0)
	if escape_cell.x >= 0:
		_draw_escape_mouth(Rect2(escape_cell.x * tile, escape_cell.y * tile, tile, tile))


func _draw_floor_tile(rect: Rect2, x: int, y: int) -> void:
	var checker := ((x + y) % 2) == 0
	# Cool night asphalt — slightly uneven so the grid reads as ground, not UI.
	var base := Color(0.070, 0.092, 0.108) if checker else Color(0.058, 0.078, 0.094)
	draw_rect(rect, base)
	# Inner grain: deterministic speckle, no purple.
	var cx := rect.position.x
	var cy := rect.position.y
	var seed_n := x * 73 + y * 191
	for i in 5:
		var gx := cx + 4.0 + _frac(seed_n + i * 17) * 24.0
		var gy := cy + 4.0 + _frac(seed_n + i * 41 + 9) * 24.0
		var ga := 0.04 + _frac(seed_n + i * 7) * 0.06
		draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(0.14, 0.18, 0.16, ga))
	# Hairline grid on the cool floor.
	draw_rect(rect, Color(0.16, 0.22, 0.20, 0.18), false, 1.0)
	if x % 4 == 0:
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color(0.18, 0.24, 0.22, 0.10), 1.0)
	if y % 4 == 0:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.18, 0.24, 0.22, 0.10), 1.0)


func _draw_wall_tile(rect: Rect2, x: int, y: int) -> void:
	# Warmer, heavier masonry vs the cool floor — umber core, dark grout.
	draw_rect(rect, Color(0.18, 0.12, 0.07))
	var inset := rect.grow(-2.0)
	var warm := Color(0.36, 0.26, 0.12) if ((x + y) % 2) == 0 else Color(0.32, 0.22, 0.10)
	draw_rect(inset, warm)
	# Brick-ish hatch so walls don't read as flat UI panels.
	var y0 := inset.position.y + 6.0
	while y0 < inset.position.y + inset.size.y - 2.0:
		draw_line(
			Vector2(inset.position.x + 1.0, y0),
			Vector2(inset.position.x + inset.size.x - 1.0, y0),
			Color(0.16, 0.10, 0.05, 0.45),
			1.0
		)
		y0 += 7.0
	draw_rect(rect, Color(0.55, 0.40, 0.18, 0.85), false, 1.5)
	draw_rect(inset, Color(0.22, 0.14, 0.06, 0.55), false, 1.0)


func _draw_escape_mouth(erect: Rect2) -> void:
	# Warm lime/gold mouth — readable as an exit, never purple.
	var cx := erect.get_center()
	for i in 5:
		var r := 16.0 + float(4 - i) * 11.0
		var a := 0.04 + float(i) * 0.045
		draw_circle(cx, r, Color(0.72, 0.92, 0.28, a))
	draw_circle(cx, 22.0, Color(0.95, 0.78, 0.22, 0.10))
	if escape_flash:
		var pulse := 0.28 + 0.32 * (0.5 + 0.5 * sin(_flash_t * 9.0))
		draw_rect(erect, Color(1.0, 0.18, 0.12, pulse))
		draw_rect(erect, Color(1.0, 0.92, 0.35, 0.95), false, 3.0)
	else:
		draw_rect(erect, Color(0.42, 0.72, 0.16, 0.28))
		draw_rect(erect, Color(0.92, 0.88, 0.32, 0.82), false, 2.2)


func _frac(n: int) -> float:
	var s := sin(float(n) * 12.9898) * 43758.5453
	return s - floor(s)
