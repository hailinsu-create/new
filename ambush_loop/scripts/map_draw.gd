extends Node2D

var grid: AmbushGrid
var escape_cell: Vector2i = Vector2i(-1, -1)
var barrel_cell: Vector2i = Vector2i(-1, -1)
var escape_flash: bool = false
var _flash_t: float = 0.0
var _glow_t: float = 0.0


func _process(delta: float) -> void:
	_glow_t += delta
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
	# Cooler night asphalt — teal-gray, never purple.
	var base := Color(0.062, 0.086, 0.102) if checker else Color(0.050, 0.072, 0.088)
	var wobble := 0.012 * (_frac(x * 19 + y * 47) - 0.5)
	base = Color(base.r, clampf(base.g + wobble * 0.4, 0.0, 1.0), clampf(base.b + wobble, 0.0, 1.0))
	draw_rect(rect, base)
	var cx := rect.position.x
	var cy := rect.position.y
	var seed_n := x * 73 + y * 191
	for i in 8:
		var gx := cx + 3.0 + _frac(seed_n + i * 17) * 26.0
		var gy := cy + 3.0 + _frac(seed_n + i * 41 + 9) * 26.0
		var ga := 0.035 + _frac(seed_n + i * 7) * 0.07
		var gw := 1.0 + _frac(seed_n + i * 13) * 2.0
		draw_rect(Rect2(gx, gy, gw, 1.0 + _frac(seed_n + i * 3) * 1.5), Color(0.16, 0.20, 0.19, ga))
	# Occasional tire / scrap scratch.
	if (seed_n % 11) == 0:
		var sx := cx + 4.0 + _frac(seed_n + 3) * 8.0
		var sy := cy + 6.0 + _frac(seed_n + 8) * 14.0
		var sl := 10.0 + _frac(seed_n + 21) * 12.0
		var sa := 0.07 + _frac(seed_n + 5) * 0.08
		draw_line(Vector2(sx, sy), Vector2(sx + sl, sy + 2.0 * (_frac(seed_n) - 0.5)), Color(0.22, 0.24, 0.20, sa), 1.2, true)
	elif (seed_n % 17) == 0:
		var ox := cx + 8.0 + _frac(seed_n + 11) * 10.0
		var oy := cy + 10.0
		draw_arc(Vector2(ox, oy), 5.0, 0.2, 2.4, 6, Color(0.18, 0.20, 0.18, 0.08), 1.0, true)
	draw_rect(rect, Color(0.14, 0.20, 0.19, 0.16), false, 1.0)
	if x % 4 == 0:
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color(0.16, 0.22, 0.22, 0.10), 1.0)
	if y % 4 == 0:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.16, 0.22, 0.22, 0.10), 1.0)


func _draw_wall_tile(rect: Rect2, x: int, y: int) -> void:
	# Umber masonry with north/west rim light so blocks read as crates/brick, not UI cards.
	draw_rect(rect, Color(0.14, 0.09, 0.05))
	var inset := rect.grow(-2.0)
	var warm := Color(0.38, 0.27, 0.13) if ((x + y) % 2) == 0 else Color(0.33, 0.23, 0.10)
	draw_rect(inset, warm)
	var y0 := inset.position.y + 5.0
	var row := 0
	while y0 < inset.position.y + inset.size.y - 2.0:
		draw_line(
			Vector2(inset.position.x + 1.0, y0),
			Vector2(inset.position.x + inset.size.x - 1.0, y0),
			Color(0.14, 0.09, 0.04, 0.50),
			1.0
		)
		# Offset brick joints.
		var joint_x := inset.position.x + (8.0 if (row % 2) == 0 else 16.0)
		while joint_x < inset.position.x + inset.size.x - 2.0:
			draw_line(
				Vector2(joint_x, y0 - 5.0),
				Vector2(joint_x, y0),
				Color(0.12, 0.07, 0.04, 0.40),
				1.0
			)
			joint_x += 16.0
		y0 += 7.0
		row += 1
	draw_rect(rect, Color(0.48, 0.34, 0.14, 0.80), false, 1.4)
	draw_rect(inset, Color(0.20, 0.12, 0.05, 0.50), false, 1.0)
	var north_open := y <= 0 or not grid.is_blocked(x, y - 1)
	var west_open := x <= 0 or not grid.is_blocked(x - 1, y)
	if north_open:
		draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(rect.size.x - 1, 1),
			Color(0.78, 0.62, 0.34, 0.88),
			2.0
		)
	if west_open:
		draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(1, rect.size.y - 1),
			Color(0.68, 0.52, 0.28, 0.78),
			2.0
		)
	var south_open := y + 1 >= AmbushGrid.ROWS or not grid.is_blocked(x, y + 1)
	var east_open := x + 1 >= AmbushGrid.COLS or not grid.is_blocked(x + 1, y)
	if south_open:
		draw_line(
			rect.position + Vector2(0, rect.size.y - 1),
			rect.position + Vector2(rect.size.x, rect.size.y - 1),
			Color(0.06, 0.03, 0.02, 0.75),
			2.0
		)
	if east_open:
		draw_line(
			rect.position + Vector2(rect.size.x - 1, 0),
			rect.position + Vector2(rect.size.x - 1, rect.size.y),
			Color(0.08, 0.04, 0.02, 0.55),
			1.5
		)


func _draw_escape_mouth(erect: Rect2) -> void:
	# Warm lime/gold mouth — readable as an exit, never purple. Soft idle glow; fail flash kept.
	var cx := erect.get_center()
	var breathe := 0.5 + 0.5 * sin(_glow_t * 2.15)
	for i in 5:
		var r := 16.0 + float(4 - i) * 11.0 + breathe * 3.0
		var a := (0.035 + float(i) * 0.040) * (0.82 + 0.28 * breathe)
		draw_circle(cx, r, Color(0.72, 0.92, 0.28, a))
	draw_circle(cx, 22.0 + breathe * 2.0, Color(0.95, 0.78, 0.22, 0.08 + 0.05 * breathe))
	if escape_flash:
		var pulse := 0.28 + 0.32 * (0.5 + 0.5 * sin(_flash_t * 9.0))
		draw_rect(erect, Color(1.0, 0.18, 0.12, pulse))
		draw_rect(erect, Color(1.0, 0.92, 0.35, 0.95), false, 3.0)
	else:
		draw_rect(erect, Color(0.42, 0.72, 0.16, 0.22 + 0.10 * breathe))
		draw_rect(erect, Color(0.92, 0.88, 0.32, 0.70 + 0.18 * breathe), false, 2.2)


func _frac(n: int) -> float:
	var s := sin(float(n) * 12.9898) * 43758.5453
	return s - floor(s)
