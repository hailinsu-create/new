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
	for y in AmbushGrid.ROWS:
		for x in AmbushGrid.COLS:
			var rect := Rect2(x * AmbushGrid.TILE, y * AmbushGrid.TILE, AmbushGrid.TILE, AmbushGrid.TILE)
			if grid.is_blocked(x, y):
				draw_rect(rect, Color(0.16, 0.18, 0.22))
				draw_rect(rect, Color(0.28, 0.32, 0.38), false, 1.0)
			else:
				var checker := ((x + y) % 2) == 0
				draw_rect(rect, Color(0.12, 0.14, 0.16) if checker else Color(0.11, 0.125, 0.145))
	if barrel_cell.x >= 0:
		var brect := Rect2(
			barrel_cell.x * AmbushGrid.TILE, barrel_cell.y * AmbushGrid.TILE,
			AmbushGrid.TILE, AmbushGrid.TILE
		)
		draw_rect(brect, Color(0.85, 0.38, 0.12, 0.22))
		draw_rect(brect, Color(0.95, 0.5, 0.2, 0.55), false, 1.5)
	if escape_cell.x >= 0:
		var erect := Rect2(
			escape_cell.x * AmbushGrid.TILE, escape_cell.y * AmbushGrid.TILE,
			AmbushGrid.TILE, AmbushGrid.TILE
		)
		if escape_flash:
			var pulse := 0.28 + 0.32 * (0.5 + 0.5 * sin(_flash_t * 9.0))
			draw_rect(erect, Color(1.0, 0.18, 0.12, pulse))
			draw_rect(erect, Color(1.0, 0.92, 0.35, 0.95), false, 3.0)
		else:
			draw_rect(erect, Color(0.2, 0.85, 0.55, 0.16))
			draw_rect(erect, Color(0.35, 0.9, 0.6, 0.45), false, 1.5)
