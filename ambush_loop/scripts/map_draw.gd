extends Node2D

## Night map: static wall/floor tiles are rasterized into a SubViewport and
## only rebuilt when grid geometry, doors, or quality tier change. Escape
## glow, fail flash, and barrel highlight stay on the live overlay.

class StaticCacheLayer extends Node2D:
	var map: Node2D

	func _draw() -> void:
		if map and map.has_method("_draw_static_into"):
			map._draw_static_into(self)


var grid: AmbushGrid:
	set(value):
		grid = value
		invalidate_static_cache()

var escape_cell: Vector2i = Vector2i(-1, -1)
var barrel_cell: Vector2i = Vector2i(-1, -1)
var escape_flash: bool = false
var _flash_t: float = 0.0
var _glow_t: float = 0.0

var _cache_vp: SubViewport
var _cache_layer: StaticCacheLayer
var _cache_sig: String = ""
var _cache_live_frames: int = 0


func _ready() -> void:
	_ensure_cache_vp()
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and not gs.changed.is_connected(_on_settings_changed):
		gs.changed.connect(_on_settings_changed)
	invalidate_static_cache()


func uses_static_cache() -> bool:
	_ensure_cache_vp()
	return _cache_vp != null and _cache_layer != null


func invalidate_static_cache() -> void:
	_cache_sig = ""
	if is_inside_tree():
		_ensure_cache_current()
	queue_redraw()


func _on_settings_changed() -> void:
	invalidate_static_cache()


func _process(delta: float) -> void:
	_glow_t += delta
	if escape_flash:
		_flash_t += delta
	_ensure_cache_current()
	queue_redraw()


func _ensure_cache_vp() -> void:
	if _cache_vp != null and is_instance_valid(_cache_vp):
		return
	if not is_inside_tree():
		return
	var tile := AmbushGrid.TILE
	_cache_vp = SubViewport.new()
	_cache_vp.name = "StaticCache"
	_cache_vp.size = Vector2i(AmbushGrid.COLS * tile, AmbushGrid.ROWS * tile)
	_cache_vp.transparent_bg = false
	_cache_vp.disable_3d = true
	_cache_vp.handle_input_locally = false
	_cache_vp.gui_disable_input = true
	_cache_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cache_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_cache_vp.snap_2d_transforms_to_pixel = true
	add_child(_cache_vp)
	_cache_layer = StaticCacheLayer.new()
	_cache_layer.name = "StaticLayer"
	_cache_layer.map = self
	_cache_vp.add_child(_cache_layer)


func _ensure_cache_current() -> void:
	_ensure_cache_vp()
	if _cache_vp == null:
		return
	var sig := _cache_signature()
	if sig != _cache_sig:
		_cache_sig = sig
		if _cache_layer:
			_cache_layer.queue_redraw()
		_cache_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_cache_live_frames = 2
	elif _cache_live_frames > 0:
		_cache_live_frames -= 1
		if _cache_live_frames <= 0:
			_cache_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _cache_signature() -> String:
	var geo := "none"
	if grid != null:
		var h := 0
		var blocked := grid.blocked
		for i in blocked.size():
			h = ((h << 5) - h + int(blocked[i])) & 0x7fffffff
		geo = "%s:%d:%d:%d:%d" % [
			grid.layout_id, grid.door_cell.x, grid.door_cell.y, int(grid.door_locked), h
		]
	return "%s|%s" % [geo, "p" if _is_power_saving() else "s"]


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


func _draw() -> void:
	if grid == null:
		return
	var tex: Texture2D = null
	if _cache_vp:
		tex = _cache_vp.get_texture()
	if tex:
		draw_texture(tex, Vector2.ZERO)
	else:
		_draw_static_into(self)
	var tile := AmbushGrid.TILE
	if barrel_cell.x >= 0:
		var brect := Rect2(
			barrel_cell.x * tile, barrel_cell.y * tile, tile, tile
		)
		draw_rect(brect, Color(0.98, 0.42, 0.08, 0.28))
		draw_rect(brect, Color(1.0, 0.55, 0.18, 0.7), false, 2.0)
	if escape_cell.x >= 0:
		_draw_escape_mouth(Rect2(escape_cell.x * tile, escape_cell.y * tile, tile, tile))


func _draw_static_into(c: CanvasItem) -> void:
	if grid == null or c == null:
		return
	var tile := AmbushGrid.TILE
	for y in AmbushGrid.ROWS:
		for x in AmbushGrid.COLS:
			var rect := Rect2(x * tile, y * tile, tile, tile)
			if grid.is_blocked(x, y):
				_draw_wall_tile(c, rect, x, y)
			else:
				_draw_floor_tile(c, rect, x, y)


func _draw_floor_tile(c: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	var checker := ((x + y) % 2) == 0
	# Cooler night asphalt — teal-gray, never purple.
	var base := Color(0.062, 0.086, 0.102) if checker else Color(0.050, 0.072, 0.088)
	var wobble := 0.012 * (_frac(x * 19 + y * 47) - 0.5)
	base = Color(base.r, clampf(base.g + wobble * 0.4, 0.0, 1.0), clampf(base.b + wobble, 0.0, 1.0))
	c.draw_rect(rect, base)
	var dense := not _is_power_saving()
	if dense:
		var cx := rect.position.x
		var cy := rect.position.y
		var seed_n := x * 73 + y * 191
		for i in 8:
			var gx := cx + 3.0 + _frac(seed_n + i * 17) * 26.0
			var gy := cy + 3.0 + _frac(seed_n + i * 41 + 9) * 26.0
			var ga := 0.035 + _frac(seed_n + i * 7) * 0.07
			var gw := 1.0 + _frac(seed_n + i * 13) * 2.0
			c.draw_rect(Rect2(gx, gy, gw, 1.0 + _frac(seed_n + i * 3) * 1.5), Color(0.16, 0.20, 0.19, ga))
		# Occasional tire / scrap scratch.
		if (seed_n % 11) == 0:
			var sx := cx + 4.0 + _frac(seed_n + 3) * 8.0
			var sy := cy + 6.0 + _frac(seed_n + 8) * 14.0
			var sl := 10.0 + _frac(seed_n + 21) * 12.0
			var sa := 0.07 + _frac(seed_n + 5) * 0.08
			c.draw_line(Vector2(sx, sy), Vector2(sx + sl, sy + 2.0 * (_frac(seed_n) - 0.5)), Color(0.22, 0.24, 0.20, sa), 1.2, true)
		elif (seed_n % 17) == 0:
			var ox := cx + 8.0 + _frac(seed_n + 11) * 10.0
			var oy := cy + 10.0
			c.draw_arc(Vector2(ox, oy), 5.0, 0.2, 2.4, 6, Color(0.18, 0.20, 0.18, 0.08), 1.0, true)
	c.draw_rect(rect, Color(0.14, 0.20, 0.19, 0.16), false, 1.0)
	if x % 4 == 0:
		c.draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color(0.16, 0.22, 0.22, 0.10), 1.0)
	if y % 4 == 0:
		c.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.16, 0.22, 0.22, 0.10), 1.0)


func _draw_wall_tile(c: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	# Umber masonry with north/west rim light so blocks read as crates/brick, not UI cards.
	c.draw_rect(rect, Color(0.14, 0.09, 0.05))
	var inset := rect.grow(-2.0)
	var warm := Color(0.38, 0.27, 0.13) if ((x + y) % 2) == 0 else Color(0.33, 0.23, 0.10)
	c.draw_rect(inset, warm)
	if not _is_power_saving():
		var y0 := inset.position.y + 5.0
		var row := 0
		while y0 < inset.position.y + inset.size.y - 2.0:
			c.draw_line(
				Vector2(inset.position.x + 1.0, y0),
				Vector2(inset.position.x + inset.size.x - 1.0, y0),
				Color(0.14, 0.09, 0.04, 0.50),
				1.0
			)
			# Offset brick joints.
			var joint_x := inset.position.x + (8.0 if (row % 2) == 0 else 16.0)
			while joint_x < inset.position.x + inset.size.x - 2.0:
				c.draw_line(
					Vector2(joint_x, y0 - 5.0),
					Vector2(joint_x, y0),
					Color(0.12, 0.07, 0.04, 0.40),
					1.0
				)
				joint_x += 16.0
			y0 += 7.0
			row += 1
	c.draw_rect(rect, Color(0.48, 0.34, 0.14, 0.80), false, 1.4)
	c.draw_rect(inset, Color(0.20, 0.12, 0.05, 0.50), false, 1.0)
	var north_open := y <= 0 or not grid.is_blocked(x, y - 1)
	var west_open := x <= 0 or not grid.is_blocked(x - 1, y)
	if north_open:
		c.draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(rect.size.x - 1, 1),
			Color(0.78, 0.62, 0.34, 0.88),
			2.0
		)
	if west_open:
		c.draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(1, rect.size.y - 1),
			Color(0.68, 0.52, 0.28, 0.78),
			2.0
		)
	var south_open := y + 1 >= AmbushGrid.ROWS or not grid.is_blocked(x, y + 1)
	var east_open := x + 1 >= AmbushGrid.COLS or not grid.is_blocked(x + 1, y)
	if south_open:
		c.draw_line(
			rect.position + Vector2(0, rect.size.y - 1),
			rect.position + Vector2(rect.size.x, rect.size.y - 1),
			Color(0.06, 0.03, 0.02, 0.75),
			2.0
		)
	if east_open:
		c.draw_line(
			rect.position + Vector2(rect.size.x - 1, 0),
			rect.position + Vector2(rect.size.x - 1, rect.size.y),
			Color(0.08, 0.04, 0.02, 0.55),
			1.5
		)


func _draw_escape_mouth(erect: Rect2) -> void:
	# Warm lime/gold mouth — readable as an exit, never purple. Soft idle glow; fail flash kept.
	var cx := erect.get_center()
	var breathe := 0.5 + 0.5 * sin(_glow_t * 2.15)
	var rings := 3 if _is_power_saving() else 5
	for i in rings:
		var r := 16.0 + float(rings - 1 - i) * 11.0 + breathe * 3.0
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
