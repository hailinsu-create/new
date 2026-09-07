extends Node2D

var grid: AmbushGrid


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
