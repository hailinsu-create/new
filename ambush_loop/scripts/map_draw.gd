extends Node2D

var grid: AmbushGrid


func _draw() -> void:
	if grid == null:
		return
	# Rain-dark industrial yard: decorative markings never alter grid collision.
	var bounds := Rect2(AmbushGrid.WORLD_ORIGIN, Vector2(AmbushGrid.COLS * AmbushGrid.TILE, AmbushGrid.ROWS * AmbushGrid.TILE))
	draw_rect(bounds.grow(8.0), Color(0.025, 0.045, 0.065), true)
	for y in AmbushGrid.ROWS:
		for x in AmbushGrid.COLS:
			var rect := Rect2(
				AmbushGrid.WORLD_ORIGIN + Vector2(x * AmbushGrid.TILE, y * AmbushGrid.TILE),
				Vector2(AmbushGrid.TILE, AmbushGrid.TILE)
			)
			if grid.is_blocked(x, y):
				draw_rect(rect, Color(0.12, 0.16, 0.19))
				draw_rect(rect.grow(-3.0), Color(0.21, 0.29, 0.32))
				draw_line(rect.position + Vector2(3, 4), Vector2(rect.end.x - 3, rect.position.y + 4), Color(0.46, 0.58, 0.57, 0.45), 2.0)
				draw_rect(rect, Color(0.38, 0.52, 0.52, 0.7), false, 1.0)
			else:
				var checker := ((x + y) % 2) == 0
				draw_rect(rect, Color(0.09, 0.125, 0.15) if checker else Color(0.075, 0.108, 0.135))
				if (x * 7 + y * 3) % 5 == 0:
					draw_circle(rect.get_center() + Vector2(-5, 4), 2.0, Color(0.28, 0.42, 0.46, 0.22))
				draw_line(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.end.x, rect.end.y - 1), Color(0.28, 0.38, 0.42, 0.18), 1.0)
