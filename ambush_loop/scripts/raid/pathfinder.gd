class_name RaidPathfinder
extends RefCounted

## 4-connected A* on AmbushGrid. Small map (40x22).


static func find_path(grid: AmbushGrid, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if grid == null:
		return empty
	if not grid.in_bounds(from.x, from.y) or not grid.in_bounds(to.x, to.y):
		return empty
	if grid.is_blocked(to.x, to.y):
		to = nearest_open(grid, to)
		if to.x < 0:
			return empty
	if grid.is_blocked(from.x, from.y):
		from = nearest_open(grid, from)
		if from.x < 0:
			return empty
	if from == to:
		return [from]
	var open: Array[Vector2i] = [from]
	var came := {}
	var gscore := {}
	var fscore := {}
	gscore[from] = 0
	fscore[from] = _h(from, to)
	var closed := {}
	var guard := 0
	while not open.is_empty() and guard < 1200:
		guard += 1
		var cur_i := 0
		var cur: Vector2i = open[0]
		var best_f: int = int(fscore.get(cur, 99999))
		for i in range(1, open.size()):
			var c: Vector2i = open[i]
			var f: int = int(fscore.get(c, 99999))
			if f < best_f:
				best_f = f
				cur = c
				cur_i = i
		if cur == to:
			return _rebuild(came, cur, from)
		open.remove_at(cur_i)
		closed[cur] = true
		for n in _neighbors(grid, cur):
			if closed.has(n):
				continue
			var tg: int = int(gscore.get(cur, 99999)) + 1
			if tg < int(gscore.get(n, 99999)):
				came[n] = cur
				gscore[n] = tg
				fscore[n] = tg + _h(n, to)
				if open.find(n) < 0:
					open.append(n)
	return empty


static func _rebuild(came: Dictionary, cur: Vector2i, origin: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [cur]
	var guard := 0
	while came.has(cur) and guard < 400:
		guard += 1
		cur = came[cur]
		path.append(cur)
	path.reverse()
	if path.is_empty() or path[0] != origin:
		path.insert(0, origin)
	return path


static func _h(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _neighbors(grid: AmbushGrid, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n: Vector2i = c + d
		if grid.in_bounds(n.x, n.y) and not grid.is_blocked(n.x, n.y):
			out.append(n)
	return out


static func nearest_open(grid: AmbushGrid, cell: Vector2i) -> Vector2i:
	if grid.in_bounds(cell.x, cell.y) and not grid.is_blocked(cell.x, cell.y):
		return cell
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := Vector2i(cell.x + dx, cell.y + dy)
				if grid.in_bounds(n.x, n.y) and not grid.is_blocked(n.x, n.y):
					return n
	return Vector2i(-1, -1)


static func walkable(grid: AmbushGrid, cell: Vector2i) -> bool:
	return grid != null and grid.in_bounds(cell.x, cell.y) and not grid.is_blocked(cell.x, cell.y)
