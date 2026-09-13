class_name C2ShadowLayer
extends Node2D

## Bushes + contact shadows. Crouch here to drop out of sentry cones.

var cells: Array[Vector2i] = []
var bush_cells: Array[Vector2i] = []
var _grid = null


func setup(grid, level_id: String) -> void:
	_grid = grid
	cells.clear()
	bush_cells.clear()
	match str(level_id):
		"warehouse":
			_add_strip(Vector2i(6, 14), Vector2i(6, 17), false)
			_add_strip(Vector2i(10, 16), Vector2i(12, 17), true)
			_add_strip(Vector2i(22, 15), Vector2i(24, 16), true)
		"pump":
			_add_strip(Vector2i(6, 14), Vector2i(6, 17), false)
			_add_strip(Vector2i(21, 16), Vector2i(23, 17), true)
		"railcut":
			_add_strip(Vector2i(10, 16), Vector2i(12, 17), true)
			_add_strip(Vector2i(31, 15), Vector2i(33, 16), false)
		"depot":
			_add_strip(Vector2i(6, 14), Vector2i(8, 17), true)
			_add_strip(Vector2i(29, 15), Vector2i(30, 17), false)
		"radio":
			_add_strip(Vector2i(6, 14), Vector2i(8, 17), true)
			_add_strip(Vector2i(23, 15), Vector2i(24, 17), false)
		_:
			_add_strip(Vector2i(5, 11), Vector2i(5, 17), false)
			_add_strip(Vector2i(9, 17), Vector2i(11, 17), true)
			_add_strip(Vector2i(7, 10), Vector2i(7, 10), false)
			_add_strip(Vector2i(23, 12), Vector2i(23, 13), false)
			_add_strip(Vector2i(16, 17), Vector2i(18, 17), true)
			_add_strip(Vector2i(21, 16), Vector2i(22, 17), true)
	queue_redraw()


func _add_strip(a: Vector2i, b: Vector2i, bush: bool) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var c := Vector2i(x, y)
			if _grid != null and _grid.has_method("is_blocked") and bool(_grid.is_blocked(x, y)):
				continue
			cells.append(c)
			if bush:
				bush_cells.append(c)


func hides_at(cell: Vector2i) -> bool:
	return cells.has(cell)


func is_bush(cell: Vector2i) -> bool:
	return bush_cells.has(cell)


func _draw() -> void:
	if _grid == null:
		return
	for c in cells:
		var w: Vector2 = _grid.cell_to_world_center(c)
		var local := to_local(w)
		var bush := bush_cells.has(c)
		if bush:
			draw_colored_polygon(PackedVector2Array([
				local + Vector2(-10, 6), local + Vector2(-4, -6), local + Vector2(3, 2),
				local + Vector2(10, -4), local + Vector2(8, 8), local + Vector2(-8, 8)
			]), Color(0.16, 0.22, 0.12, 0.55))
			draw_circle(local + Vector2(-2, 2), 4.0, Color(0.12, 0.18, 0.10, 0.5))
		else:
			draw_rect(Rect2(local.x - 14, local.y - 10, 28, 22), Color(0.04, 0.05, 0.04, 0.28))
