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
				# Warmer umber / olive walls vs cool floor.
				draw_rect(rect, Color(0.27, 0.21, 0.12))
				draw_rect(rect, Color(0.46, 0.36, 0.18), false, 1.0)
			else:
				var checker := ((x + y) % 2) == 0
				draw_rect(rect, Color(0.075, 0.10, 0.12) if checker else Color(0.065, 0.088, 0.105))
				draw_rect(rect, Color(0.12, 0.16, 0.18, 0.22), false, 1.0)
	if barrel_cell.x >= 0:
		var brect := Rect2(
			barrel_cell.x * tile, barrel_cell.y * tile, tile, tile
		)
		draw_rect(brect, Color(0.85, 0.38, 0.12, 0.22))
		draw_rect(brect, Color(0.95, 0.5, 0.2, 0.55), false, 1.5)
	if escape_cell.x >= 0:
		var erect := Rect2(escape_cell.x * tile, escape_cell.y * tile, tile, tile)
		# Soft mouth glow so the exit stays readable even before a fail flash.
		var cx := erect.get_center()
		for i in 4:
			var r := 18.0 + float(3 - i) * 10.0
			var a := 0.05 + float(i) * 0.04
			draw_circle(cx, r, Color(0.25, 0.9, 0.58, a))
		if escape_flash:
			var pulse := 0.28 + 0.32 * (0.5 + 0.5 * sin(_flash_t * 9.0))
			draw_rect(erect, Color(1.0, 0.18, 0.12, pulse))
			draw_rect(erect, Color(1.0, 0.92, 0.35, 0.95), false, 3.0)
		else:
			draw_rect(erect, Color(0.18, 0.72, 0.48, 0.22))
			draw_rect(erect, Color(0.40, 0.95, 0.62, 0.70), false, 2.0)
