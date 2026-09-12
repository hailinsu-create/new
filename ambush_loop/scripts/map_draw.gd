extends Node2D

## Night map: static wall/floor tiles are rasterized into a SubViewport and
## only rebuilt when grid geometry, doors, or quality tier change. Escape
## glow, fail flash, and barrel highlight stay on the live overlay.

const Ww2Pal := preload("res://scripts/art/ww2_palette.gd")

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
var atmosphere_id: String = "yard":
	set(value):
		if atmosphere_id == value:
			return
		atmosphere_id = value
		invalidate_static_cache()
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


func _exit_tree() -> void:
	set_process(false)
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("changed") and gs.changed.is_connected(_on_settings_changed):
		gs.changed.disconnect(_on_settings_changed)
	_teardown_static_cache()


func _teardown_static_cache() -> void:
	## Immediate free so headless quit does not leak SubViewport CanvasItem RIDs.
	if _cache_layer != null and is_instance_valid(_cache_layer):
		_cache_layer.map = null
		var lp := _cache_layer.get_parent()
		if lp:
			lp.remove_child(_cache_layer)
		_cache_layer.free()
	_cache_layer = null
	if _cache_vp != null and is_instance_valid(_cache_vp):
		_cache_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var vp := _cache_vp
		_cache_vp = null
		var pp := vp.get_parent()
		if pp:
			pp.remove_child(vp)
		vp.free()
	_cache_vp = null
	_cache_sig = ""


func signature_tint() -> Color:
	return LevelDef.signature_color(_atmo())


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
	## layout_id + atmosphere_id must both be in the key so a level switch rebuilds
	## even if blocked-bit hashes collide.
	var geo := "none"
	var layout := ""
	if grid != null:
		var h := 0
		var blocked := grid.blocked
		for i in blocked.size():
			h = ((h << 5) - h + int(blocked[i])) & 0x7fffffff
		layout = str(grid.layout_id)
		geo = "%s:%d:%d:%d:%d" % [
			layout, grid.door_cell.x, grid.door_cell.y, int(grid.door_locked), h
		]
	var atmo := atmosphere_id
	if atmo == "" and layout != "":
		atmo = layout
	return "%s|%s|%s|%s" % [geo, "p" if _is_power_saving() else "s", atmo, layout]


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
	_draw_static_landmarks(c)
	_draw_floor_accent_stripe(c)
	_draw_doorway_detail(c)
	_draw_floor_stain_wash(c)
	_draw_wall_ao(c)


func _atmo() -> String:
	if atmosphere_id != "":
		return atmosphere_id
	if grid != null:
		return grid.layout_id
	return "yard"


func _floor_palette() -> Dictionary:
	var a: Color = Ww2Pal.floor_a(_atmo())
	var b: Color = Ww2Pal.floor_b(_atmo())
	match _atmo():
		"warehouse":
			return {
				"a": a, "b": b,
				"grain": Color(0.28, 0.18, 0.08, 1),
				"grid": Color(0.24, 0.16, 0.08, 0.12),
			}
		"pump":
			return {
				"a": a, "b": b,
				"grain": Color(0.22, 0.24, 0.16, 1),
				"grid": Color(0.18, 0.20, 0.14, 0.12),
			}
		"railcut":
			return {
				"a": a, "b": b,
				"grain": Color(0.22, 0.20, 0.16, 1),
				"grid": Color(0.20, 0.18, 0.14, 0.12),
			}
		"depot":
			return {
				"a": a, "b": b,
				"grain": Color(0.36, 0.20, 0.08, 1),
				"grid": Color(0.30, 0.16, 0.06, 0.12),
			}
		"radio":
			return {
				"a": a, "b": b,
				"grain": Color(0.22, 0.24, 0.20, 1),
				"grid": Color(0.18, 0.20, 0.16, 0.12),
			}
		_:
			return {
				"a": a, "b": b,
				"grain": Color(0.20, 0.22, 0.14, 1),
				"grid": Color(0.16, 0.18, 0.12, 0.10),
			}


func _wall_palette() -> Dictionary:
	match _atmo():
		"warehouse":
			return {
				"base": Color(0.16, 0.12, 0.07),
				"fill_a": Color(0.42, 0.32, 0.16),
				"fill_b": Color(0.36, 0.26, 0.12),
				"edge": Color(0.58, 0.46, 0.22, 0.85),
				"rim": Color(0.78, 0.62, 0.32, 0.88),
				"mortar": Color(0.12, 0.08, 0.04, 0.50),
			}
		"pump":
			return {
				"base": Color(0.08, 0.10, 0.08),
				"fill_a": Color(0.22, 0.24, 0.16),
				"fill_b": Color(0.18, 0.20, 0.14),
				"edge": Color(0.40, 0.38, 0.24, 0.80),
				"rim": Color(0.58, 0.52, 0.32, 0.78),
				"mortar": Color(0.08, 0.10, 0.08, 0.55),
			}
		"railcut":
			return {
				"base": Color(0.10, 0.10, 0.09),
				"fill_a": Color(0.28, 0.26, 0.22),
				"fill_b": Color(0.22, 0.20, 0.17),
				"edge": Color(0.48, 0.46, 0.38, 0.80),
				"rim": Color(0.70, 0.68, 0.52, 0.82),
				"mortar": Color(0.08, 0.08, 0.07, 0.50),
			}
		"depot":
			return {
				"base": Color(0.16, 0.08, 0.04),
				"fill_a": Color(0.42, 0.22, 0.08),
				"fill_b": Color(0.34, 0.16, 0.06),
				"edge": Color(0.72, 0.42, 0.14, 0.82),
				"rim": Color(0.90, 0.58, 0.22, 0.85),
				"mortar": Color(0.14, 0.06, 0.03, 0.50),
			}
		"radio":
			return {
				"base": Color(0.08, 0.08, 0.07),
				"fill_a": Color(0.22, 0.22, 0.18),
				"fill_b": Color(0.16, 0.16, 0.14),
				"edge": Color(0.42, 0.40, 0.30, 0.82),
				"rim": Color(0.62, 0.58, 0.42, 0.85),
				"mortar": Color(0.08, 0.08, 0.07, 0.50),
			}
		_:
			return {
				"base": Color(0.12, 0.09, 0.05),
				"fill_a": Color(0.34, 0.26, 0.14),
				"fill_b": Color(0.28, 0.20, 0.10),
				"edge": Color(0.46, 0.34, 0.16, 0.80),
				"rim": Color(0.62, 0.50, 0.28, 0.88),
				"mortar": Color(0.12, 0.09, 0.04, 0.50),
			}


func _draw_wall_language(c: CanvasItem, inset: Rect2, pal: Dictionary, x: int, y: int) -> void:
	var lang := wall_language()
	var mortar: Color = pal["mortar"]
	match lang:
		"pipe":
			var mid_y := inset.position.y + inset.size.y * 0.5
			c.draw_line(
				Vector2(inset.position.x + 1.0, mid_y),
				Vector2(inset.position.x + inset.size.x - 1.0, mid_y),
				Color(0.22, 0.48, 0.40, 0.70),
				3.2
			)
			c.draw_line(
				Vector2(inset.position.x + 1.0, mid_y - 6.0),
				Vector2(inset.position.x + inset.size.x - 1.0, mid_y - 6.0),
				Color(mortar.r, mortar.g, mortar.b, 0.55),
				1.2
			)
			if (x + y) % 2 == 0:
				c.draw_circle(Vector2(inset.position.x + inset.size.x * 0.5, mid_y), 3.2, Color(0.18, 0.40, 0.34, 0.80))
		"concrete":
			c.draw_line(
				Vector2(inset.position.x + 2.0, inset.position.y + inset.size.y * 0.33),
				Vector2(inset.position.x + inset.size.x - 2.0, inset.position.y + inset.size.y * 0.33),
				mortar,
				1.4
			)
			c.draw_line(
				Vector2(inset.position.x + inset.size.x * 0.5, inset.position.y + 2.0),
				Vector2(inset.position.x + inset.size.x * 0.5, inset.position.y + inset.size.y - 2.0),
				Color(mortar.r, mortar.g, mortar.b, mortar.a * 0.7),
				1.2
			)
		"mesh":
			var hole := Color(0.08, 0.14, 0.18, 0.55)
			var gx0 := inset.position.x + 4.0
			var gy0 := inset.position.y + 4.0
			while gy0 < inset.position.y + inset.size.y - 3.0:
				var gx := gx0 + (2.0 if int(gy0) % 2 == 0 else 0.0)
				while gx < inset.position.x + inset.size.x - 3.0:
					c.draw_circle(Vector2(gx, gy0), 1.4, hole)
					gx += 6.0
				gy0 += 6.0
			c.draw_rect(inset.grow(-2.0), Color(pal["edge"].r, pal["edge"].g, pal["edge"].b, 0.28), false, 1.0)
		"plate":
			var chev := Color(0.72, 0.42, 0.12, 0.35)
			c.draw_line(
				Vector2(inset.position.x + 4.0, inset.position.y + 6.0),
				Vector2(inset.position.x + inset.size.x - 6.0, inset.position.y + inset.size.y - 4.0),
				chev,
				2.0
			)
			c.draw_line(
				Vector2(inset.position.x + 8.0, inset.position.y + 4.0),
				Vector2(inset.position.x + inset.size.x - 4.0, inset.position.y + inset.size.y - 8.0),
				Color(chev.r, chev.g, chev.b, 0.22),
				1.4
			)
			c.draw_rect(inset.grow(-3.0), Color(pal["edge"].r, pal["edge"].g, pal["edge"].b, 0.35), false, 1.2)
		_:
			if (x + y) % 7 == 0:
				c.draw_line(
					Vector2(inset.position.x + 3.0, inset.position.y + 4.0),
					Vector2(inset.position.x + inset.size.x - 4.0, inset.position.y + inset.size.y - 5.0),
					Color(0.42, 0.22, 0.08, 0.22),
					1.4, true
				)
			var y0 := inset.position.y + 5.0
			var row := 0
			while y0 < inset.position.y + inset.size.y - 2.0:
				c.draw_line(
					Vector2(inset.position.x + 1.0, y0),
					Vector2(inset.position.x + inset.size.x - 1.0, y0),
					mortar,
					1.0
				)
				var joint_x := inset.position.x + (8.0 if (row % 2) == 0 else 16.0)
				while joint_x < inset.position.x + inset.size.x - 2.0:
					c.draw_line(
						Vector2(joint_x, y0 - 5.0),
						Vector2(joint_x, y0),
						Color(mortar.r * 0.85, mortar.g * 0.85, mortar.b, mortar.a * 0.8),
						1.0
					)
					joint_x += 16.0
				y0 += 7.0
				row += 1


func _draw_floor_tile(c: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	var pal := _floor_palette()
	var checker := ((x + y) % 2) == 0
	var base: Color = pal["a"] if checker else pal["b"]
	var wobble := 0.012 * (_frac(x * 19 + y * 47) - 0.5)
	base = Color(
		clampf(base.r + wobble * 0.3, 0.0, 1.0),
		clampf(base.g + wobble * 0.4, 0.0, 1.0),
		clampf(base.b + wobble, 0.0, 1.0)
	)
	c.draw_rect(rect, base)
	# North bevel so asphalt reads as a slab, not a flat fill.
	c.draw_line(
		rect.position + Vector2(1, 1),
		rect.position + Vector2(rect.size.x - 1, 1),
		Color(base.r + 0.04, base.g + 0.05, base.b + 0.04, 0.35),
		1.0
	)
	var dense := not _is_power_saving()
	var grain: Color = pal["grain"]
	if dense:
		var cx := rect.position.x
		var cy := rect.position.y
		var seed_n := x * 73 + y * 191
		var specks := 5 if _atmo() == "railcut" else 8
		for i in specks:
			var gx := cx + 3.0 + _frac(seed_n + i * 17) * 26.0
			var gy := cy + 3.0 + _frac(seed_n + i * 41 + 9) * 26.0
			var ga := 0.035 + _frac(seed_n + i * 7) * 0.07
			var gw := 1.0 + _frac(seed_n + i * 13) * 2.0
			c.draw_rect(
				Rect2(gx, gy, gw, 1.0 + _frac(seed_n + i * 3) * 1.5),
				Color(grain.r, grain.g, grain.b, ga)
			)
		if _atmo() == "warehouse" and (seed_n % 9) == 0:
			# Oil sheen streak.
			c.draw_line(
				Vector2(cx + 4.0, cy + 18.0),
				Vector2(cx + 26.0, cy + 22.0),
				Color(0.22, 0.38, 0.32, 0.16),
				1.6, true
			)
		elif _atmo() == "pump" and (seed_n % 8) == 0:
			c.draw_circle(Vector2(cx + 16.0, cy + 18.0), 6.0, Color(0.18, 0.42, 0.38, 0.12))
		elif _atmo() == "railcut" and (y == 5 or y == 6 or y == 16 or y == 17):
			# Rail ties only on railcut north/south connectors.
			c.draw_rect(Rect2(cx + 2.0, cy + 12.0, 28.0, 6.0), Color(0.18, 0.12, 0.07, 0.55))
			c.draw_rect(Rect2(cx + 2.0, cy + 13.0, 28.0, 1.5), Color(0.32, 0.22, 0.10, 0.35))
		elif _atmo() == "depot" and ((x + y) % 6) == 0 and x > 14 and x < 25 and y > 14:
			c.draw_rect(Rect2(cx + 2.0, cy + 14.0, 28.0, 5.0), Color(0.92, 0.62, 0.12, 0.18))
		elif _atmo() == "radio" and (y == 5 or y == 6):
			c.draw_rect(Rect2(cx + 4.0, cy + 10.0, 24.0, 2.0), Color(0.28, 0.55, 0.68, 0.16))
		elif _atmo() == "radio" and x == 24 and y >= 5 and y <= 15:
			# Echo hall wash — the authored 5.2s path, not the east corridor.
			c.draw_rect(Rect2(cx + 6.0, cy + 1.0, 20.0, 30.0), Color(0.22, 0.22, 0.16, 0.22))
			c.draw_rect(Rect2(cx + 12.0, cy + 2.0, 8.0, 28.0), Color(0.42, 0.38, 0.24, 0.18))
		_draw_layout_decal(c, rect, x, y, seed_n)
		if (seed_n % 11) == 0:
			var sx := cx + 4.0 + _frac(seed_n + 3) * 8.0
			var sy := cy + 6.0 + _frac(seed_n + 8) * 14.0
			var sl := 10.0 + _frac(seed_n + 21) * 12.0
			var sa := 0.07 + _frac(seed_n + 5) * 0.08
			c.draw_line(
				Vector2(sx, sy),
				Vector2(sx + sl, sy + 2.0 * (_frac(seed_n) - 0.5)),
				Color(grain.r, grain.g, grain.b, sa),
				1.2, true
			)
		elif (seed_n % 17) == 0:
			var ox := cx + 8.0 + _frac(seed_n + 11) * 10.0
			var oy := cy + 10.0
			c.draw_arc(Vector2(ox, oy), 5.0, 0.2, 2.4, 6, Color(grain.r, grain.g, grain.b, 0.08), 1.0, true)
		if (seed_n % 21) == 0:
			# Ground stain blob — layout dirt, not a collider.
			var stain := Color(grain.r * 0.45, grain.g * 0.40, grain.b * 0.35, 0.16)
			c.draw_circle(
				Vector2(cx + 10.0 + _frac(seed_n + 2) * 12.0, cy + 12.0 + _frac(seed_n + 6) * 8.0),
				7.0 + _frac(seed_n + 4) * 5.0,
				stain
			)
		if (seed_n % 23) == 0:
			# Bullet pock — steel/brick nick, visual only.
			var px := cx + 8.0 + _frac(seed_n + 5) * 16.0
			var py := cy + 8.0 + _frac(seed_n + 11) * 16.0
			c.draw_circle(Vector2(px, py), 1.6, Color(0.08, 0.07, 0.05, 0.55))
			c.draw_circle(Vector2(px + 0.6, py - 0.4), 0.7, Color(0.22, 0.18, 0.12, 0.35))
	var grid_c: Color = pal["grid"]
	c.draw_rect(rect, Color(grid_c.r, grid_c.g, grid_c.b, 0.16), false, 1.0)
	if x % 4 == 0:
		c.draw_line(rect.position, rect.position + Vector2(0, rect.size.y), grid_c, 1.0)
	if y % 4 == 0:
		c.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), grid_c, 1.0)


func _draw_layout_decal(c: CanvasItem, rect: Rect2, x: int, y: int, seed_n: int) -> void:
	## Extra floor identity per layout_id. Visual only — never writes grid.blocked.
	var cx := rect.position.x
	var cy := rect.position.y
	match _atmo():
		"yard":
			if (seed_n % 13) == 0:
				c.draw_line(
					Vector2(cx + 3.0, cy + 8.0 + _frac(seed_n) * 10.0),
					Vector2(cx + 22.0, cy + 14.0),
					Color(0.10, 0.14, 0.12, 0.22),
					1.1, true
				)
			elif (seed_n % 19) == 0:
				c.draw_arc(Vector2(cx + 18.0, cy + 20.0), 7.0, 0.4, 2.6, 5, Color(0.18, 0.28, 0.16, 0.12), 1.2, true)
		"warehouse":
			if y == 16 and x % 3 == 0:
				c.draw_rect(Rect2(cx + 6.0, cy + 22.0, 20.0, 4.0), Color(0.55, 0.42, 0.12, 0.22))
			elif (seed_n % 14) == 0:
				c.draw_rect(Rect2(cx + 8.0, cy + 4.0, 14.0, 2.0), Color(0.32, 0.22, 0.08, 0.18))
		"pump":
			if (x + y) % 5 == 0:
				c.draw_rect(Rect2(cx + 4.0, cy + 4.0, 24.0, 24.0), Color(0.08, 0.16, 0.14, 0.10), false, 1.0)
				c.draw_line(Vector2(cx + 4.0, cy + 16.0), Vector2(cx + 28.0, cy + 16.0), Color(0.12, 0.28, 0.24, 0.16), 1.0)
			elif (seed_n % 10) == 0:
				c.draw_circle(Vector2(cx + 10.0, cy + 22.0), 4.0, Color(0.14, 0.32, 0.28, 0.14))
		"railcut":
			if y == 5 or y == 6 or y == 16 or y == 17:
				c.draw_line(Vector2(cx, cy + 8.0), Vector2(cx + 32.0, cy + 8.0), Color(0.38, 0.36, 0.30, 0.22), 1.4)
			elif (seed_n % 16) == 0:
				c.draw_rect(Rect2(cx + 12.0, cy + 4.0, 6.0, 22.0), Color(0.16, 0.14, 0.10, 0.16))
		"depot":
			if (seed_n % 12) == 0:
				c.draw_circle(Vector2(cx + 20.0, cy + 18.0), 5.0, Color(0.22, 0.10, 0.04, 0.20))
			elif x > 15 and x < 24 and (y == 15 or y == 16):
				c.draw_rect(Rect2(cx + 2.0, cy + 20.0, 28.0, 3.0), Color(0.18, 0.10, 0.04, 0.16))
		"radio":
			if (seed_n % 11) == 0:
				c.draw_rect(Rect2(cx + 10.0, cy + 6.0, 4.0, 18.0), Color(0.16, 0.28, 0.34, 0.20))
			elif y == 16 and x % 4 == 0:
				c.draw_rect(Rect2(cx + 8.0, cy + 20.0, 16.0, 3.0), Color(0.22, 0.48, 0.62, 0.18))
		_:
			pass


func wall_language() -> String:
	match _atmo():
		"pump":
			return "pipe"
		"railcut":
			return "concrete"
		"depot":
			return "plate"
		"radio":
			return "mesh"
		_:
			return "brick"


func _draw_wall_tile(c: CanvasItem, rect: Rect2, x: int, y: int) -> void:
	var pal := _wall_palette()
	# Drop mass so walls read thicker than the floor grid.
	c.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.04, 0.03, 0.02, 0.55))
	c.draw_rect(rect, pal["base"])
	var inset := rect.grow(-1.2)
	var warm: Color = pal["fill_a"] if ((x + y) % 2) == 0 else pal["fill_b"]
	c.draw_rect(inset, warm)
	if not _is_power_saving():
		_draw_wall_language(c, inset, pal, x, y)
	var edge: Color = pal["edge"]
	c.draw_rect(rect, edge, false, 2.2)
	c.draw_rect(inset, Color(pal["base"].r, pal["base"].g, pal["base"].b, 0.50), false, 1.2)
	var north_open := y <= 0 or not grid.is_blocked(x, y - 1)
	var west_open := x <= 0 or not grid.is_blocked(x - 1, y)
	var rim: Color = pal["rim"]
	if north_open:
		c.draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(rect.size.x - 1, 1),
			rim,
			3.2
		)
		c.draw_line(
			rect.position + Vector2(2, 4),
			rect.position + Vector2(rect.size.x - 2, 4),
			Color(rim.r, rim.g, rim.b, rim.a * 0.35),
			1.4
		)
	if west_open:
		c.draw_line(
			rect.position + Vector2(1, 1),
			rect.position + Vector2(1, rect.size.y - 1),
			Color(rim.r * 0.88, rim.g * 0.85, rim.b * 0.82, rim.a * 0.9),
			3.0
		)
	var south_open := y + 1 >= AmbushGrid.ROWS or not grid.is_blocked(x, y + 1)
	var east_open := x + 1 >= AmbushGrid.COLS or not grid.is_blocked(x + 1, y)
	if south_open:
		c.draw_line(
			rect.position + Vector2(0, rect.size.y - 1),
			rect.position + Vector2(rect.size.x, rect.size.y - 1),
			Color(0.06, 0.03, 0.02, 0.82),
			3.2
		)
	if east_open:
		c.draw_line(
			rect.position + Vector2(rect.size.x - 1, 0),
			rect.position + Vector2(rect.size.x - 1, rect.size.y),
			Color(0.08, 0.04, 0.02, 0.62),
			2.4
		)


func _draw_escape_mouth(erect: Rect2) -> void:
	# Live overlay only — never baked into the static cache.
	var cx := erect.get_center()
	var breathe := 0.5 + 0.5 * sin(_glow_t * 2.15)
	var sig := signature_tint()
	var rings := 3 if _is_power_saving() else 6
	for i in rings:
		var r := 16.0 + float(rings - 1 - i) * 11.0 + breathe * 3.0
		var a := (0.035 + float(i) * 0.040) * (0.82 + 0.28 * breathe)
		draw_circle(cx, r, Color(sig.r, sig.g, sig.b, a))
	draw_circle(cx, 22.0 + breathe * 2.0, Color(sig.r, sig.g, sig.b, 0.08 + 0.05 * breathe))
	# Signature rim — mission identity on the mouth, independent of the fail flash.
	draw_rect(erect.grow(5.0), Color(sig.r, sig.g, sig.b, 0.16 + 0.08 * breathe), false, 3.4)
	draw_rect(erect.grow(2.0), Color(sig.r, sig.g, sig.b, 0.55 + 0.20 * breathe), false, 2.0)
	if escape_flash:
		var pulse := 0.34 + 0.40 * (0.5 + 0.5 * sin(_flash_t * 9.0))
		var wash := 42.0 + 18.0 * pulse
		draw_circle(cx, wash, Color(1.0, 0.16, 0.10, 0.10 + 0.10 * pulse))
		draw_circle(cx, 30.0 + 8.0 * pulse, Color(1.0, 0.55, 0.12, 0.16 + 0.12 * pulse))
		draw_rect(erect.grow(8.0), Color(1.0, 0.18, 0.10, pulse * 0.55))
		draw_rect(erect, Color(1.0, 0.22, 0.12, pulse))
		draw_rect(erect, Color(1.0, 0.92, 0.35, 0.95), false, 3.4)
		# Hazard X so the mouth stays readable under the red wash.
		var inset := 6.0
		draw_line(
			erect.position + Vector2(inset, inset),
			erect.position + erect.size - Vector2(inset, inset),
			Color(1.0, 0.95, 0.45, 0.85),
			2.4, true
		)
		draw_line(
			erect.position + Vector2(erect.size.x - inset, inset),
			erect.position + Vector2(inset, erect.size.y - inset),
			Color(1.0, 0.95, 0.45, 0.85),
			2.4, true
		)
	else:
		draw_rect(erect, Color(sig.r, sig.g, sig.b, 0.20 + 0.10 * breathe))
		draw_rect(erect, Color(sig.r, sig.g, sig.b, 0.78 + 0.16 * breathe), false, 2.4)


func _draw_floor_accent_stripe(c: CanvasItem) -> void:
	## Cached per-mission floor color stripe. Overlay only — never writes grid.blocked.
	var t := AmbushGrid.TILE
	match _atmo():
		"warehouse":
			c.draw_rect(Rect2(10.0 * t, 16.85 * t, 22.0 * t, 6.0), Color(0.78, 0.48, 0.10, 0.10))
		"pump":
			c.draw_rect(Rect2(7.0 * t, 14.75 * t, 20.0 * t, 5.0), Color(0.12, 0.42, 0.36, 0.10))
		"railcut":
			c.draw_rect(Rect2(12.0 * t, 5.28 * t, 3.0 * t, 7.0), Color(0.42, 0.55, 0.68, 0.11))
			c.draw_rect(Rect2(31.0 * t, 5.28 * t, 3.0 * t, 7.0), Color(0.42, 0.55, 0.68, 0.11))
		"depot":
			c.draw_rect(Rect2(14.0 * t, 14.15 * t, 14.0 * t, 6.0), Color(0.78, 0.34, 0.08, 0.11))
		"radio":
			# Echo hall phosphor ribbon down the authored x=24 gap.
			c.draw_rect(Rect2(23.72 * t, 5.05 * t, 1.56 * t, 11.1 * t), Color(0.28, 0.78, 0.96, 0.16))
			c.draw_rect(Rect2(24.12 * t, 5.05 * t, 0.62 * t, 11.1 * t), Color(0.55, 0.92, 1.0, 0.12))
		_:
			c.draw_rect(Rect2(22.0 * t, 4.55 * t, 14.0 * t, 5.0), Color(0.62, 0.78, 0.52, 0.08))
			c.draw_rect(Rect2(8.0 * t, 16.35 * t, 18.0 * t, 4.0), Color(0.16, 0.26, 0.16, 0.07))


func _draw_wall_ao(c: CanvasItem) -> void:
	if grid == null:
		return
	var t := float(AmbushGrid.TILE)
	var south := Color(0.02, 0.03, 0.02, 0.50)
	var south_hard := Color(0.01, 0.02, 0.01, 0.66)
	var east := Color(0.03, 0.04, 0.03, 0.36)
	var east_hard := Color(0.02, 0.02, 0.02, 0.48)
	var inner := Color(0.01, 0.02, 0.01, 0.28)
	for y in AmbushGrid.ROWS:
		for x in AmbushGrid.COLS:
			if not grid.is_blocked(x, y):
				continue
			if y + 1 < AmbushGrid.ROWS and not grid.is_blocked(x, y + 1):
				c.draw_rect(Rect2(float(x) * t, float(y + 1) * t, t, 13.0), south)
				c.draw_rect(Rect2(float(x) * t, float(y + 1) * t, t, 5.0), south_hard)
			if x + 1 < AmbushGrid.COLS and not grid.is_blocked(x + 1, y):
				c.draw_rect(Rect2(float(x + 1) * t, float(y) * t, 9.0, t), east)
				c.draw_rect(Rect2(float(x + 1) * t, float(y) * t, 3.5, t), east_hard)
			# Inner corner pit where two open floors meet a wall.
			if y + 1 < AmbushGrid.ROWS and x + 1 < AmbushGrid.COLS:
				if not grid.is_blocked(x, y + 1) and not grid.is_blocked(x + 1, y) and not grid.is_blocked(x + 1, y + 1):
					c.draw_rect(Rect2(float(x + 1) * t, float(y + 1) * t, 14.0, 14.0), inner)
	if grid.door_cell.x >= 0:
		var dc := grid.door_cell
		var r := Rect2(float(dc.x) * t, float(dc.y) * t, t, t)
		c.draw_rect(r.grow(-3.0), Color(0.02, 0.03, 0.03, 0.40))


func _draw_doorway_detail(c: CanvasItem) -> void:
	## Doorway jamb and threshold on the authored door cell. Overlay only.
	if grid == null or grid.door_cell.x < 0:
		return
	var t := AmbushGrid.TILE
	var dc := grid.door_cell
	var r := Rect2(dc.x * t, dc.y * t, t, t)
	var locked := grid.door_locked
	var frame := Color(0.72, 0.28, 0.16, 0.55) if locked else Color(0.42, 0.32, 0.16, 0.50)
	c.draw_rect(r.grow(2.0), frame, false, 3.0)
	c.draw_rect(Rect2(r.position.x + 4.0, r.position.y + t - 6.0, t - 8.0, 5.0), Color(0.14, 0.10, 0.06, 0.70))
	c.draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, 5.0, t - 4.0), Color(0.18, 0.12, 0.08, 0.55))
	c.draw_rect(Rect2(r.position.x + t - 7.0, r.position.y + 2.0, 5.0, t - 4.0), Color(0.18, 0.12, 0.08, 0.55))
	if locked:
		c.draw_rect(r.grow(-6.0), Color(0.82, 0.18, 0.12, 0.22))


func _draw_floor_stain_wash(c: CanvasItem) -> void:
	## Large cached ground stains per mission. Never writes grid.blocked.
	if _is_power_saving():
		return
	var t := AmbushGrid.TILE
	match _atmo():
		"warehouse":
			c.draw_circle(Vector2(14.5 * t, 15.2 * t), 22.0, Color(0.10, 0.16, 0.12, 0.14))
			c.draw_circle(Vector2(27.0 * t, 8.6 * t), 16.0, Color(0.16, 0.12, 0.06, 0.12))
		"pump":
			c.draw_circle(Vector2(13.8 * t, 15.6 * t), 26.0, Color(0.10, 0.22, 0.20, 0.16))
			c.draw_circle(Vector2(22.4 * t, 13.2 * t), 14.0, Color(0.08, 0.18, 0.16, 0.12))
		"railcut":
			c.draw_circle(Vector2(18.5 * t, 16.4 * t), 18.0, Color(0.12, 0.10, 0.08, 0.14))
			c.draw_circle(Vector2(33.2 * t, 8.4 * t), 14.0, Color(0.10, 0.10, 0.08, 0.12))
		"depot":
			c.draw_circle(Vector2(12.6 * t, 16.2 * t), 20.0, Color(0.18, 0.08, 0.04, 0.16))
			c.draw_circle(Vector2(26.4 * t, 15.8 * t), 18.0, Color(0.16, 0.08, 0.04, 0.14))
		"radio":
			c.draw_circle(Vector2(19.2 * t, 11.2 * t), 24.0, Color(0.08, 0.16, 0.22, 0.16))
			c.draw_circle(Vector2(32.4 * t, 8.6 * t), 16.0, Color(0.10, 0.18, 0.24, 0.12))
			c.draw_rect(Rect2(23.65 * t, 5.15 * t, 1.7 * t, 10.6 * t), Color(0.10, 0.28, 0.38, 0.14))
		_:
			c.draw_circle(Vector2(10.8 * t, 14.8 * t), 20.0, Color(0.08, 0.12, 0.08, 0.14))
			c.draw_circle(Vector2(24.6 * t, 8.2 * t), 16.0, Color(0.10, 0.12, 0.08, 0.10))


func _draw_static_landmarks(c: CanvasItem) -> void:
	## Decorative overlays on top of tiles. Never writes grid.blocked.
	match _atmo():
		"warehouse":
			_landmark_warehouse(c)
		"pump":
			_landmark_pump(c)
		"railcut":
			_landmark_railcut(c)
		"depot":
			_landmark_depot(c)
		"radio":
			_landmark_radio(c)
		_:
			_landmark_yard(c)
	_draw_signature_silhouette(c)


func _cell_rect(x: int, y: int, w: int = 1, h: int = 1) -> Rect2:
	var t := AmbushGrid.TILE
	return Rect2(x * t, y * t, w * t, h * t)


func _landmark_yard(c: CanvasItem) -> void:
	# Warm window in the NE interior wall — courtyard read.
	var win := _cell_rect(33, 6, 2, 2)
	c.draw_rect(win.grow(-6), Color(0.95, 0.68, 0.22, 0.55))
	c.draw_rect(win.grow(-10), Color(1.0, 0.82, 0.40, 0.35))
	c.draw_rect(win.grow(-6), Color(0.55, 0.32, 0.10, 0.8), false, 1.5)
	_lamp_post(c, Vector2(10.6 * AmbushGrid.TILE, 8.4 * AmbushGrid.TILE), Color(0.82, 0.90, 0.62))
	_lamp_post(c, Vector2(27.4 * AmbushGrid.TILE, 15.2 * AmbushGrid.TILE), Color(0.78, 0.86, 0.58))
	# Courtyard crate-stack silhouette on the mid island (already blocked).
	var crate := _cell_rect(19, 10, 3, 2)
	c.draw_rect(crate.grow(-4), Color(0.28, 0.20, 0.10, 0.45))
	c.draw_rect(Rect2(crate.position + Vector2(8, 6), Vector2(22, 14)), Color(0.38, 0.28, 0.12, 0.55))
	c.draw_rect(Rect2(crate.position + Vector2(36, 10), Vector2(18, 18)), Color(0.32, 0.22, 0.10, 0.5))
	var t := AmbushGrid.TILE
	# Clothesline across the west yard (overlay; does not block spine x=13).
	c.draw_line(Vector2(8.2 * t, 7.15 * t), Vector2(17.6 * t, 7.05 * t), Color(0.22, 0.20, 0.14, 0.70), 1.6, true)
	for i in 5:
		var hx := 8.8 * t + float(i) * 22.0
		c.draw_rect(Rect2(hx, 7.15 * t, 8.0, 16.0 + float(i % 3) * 4.0), Color(0.42, 0.48, 0.36, 0.28))
	# Bicycle wreck west of the spine, south of the west crates.
	var bike := Vector2(10.2 * t, 12.6 * t)
	c.draw_circle(bike, 7.0, Color(0.10, 0.10, 0.08, 0.55))
	c.draw_circle(bike + Vector2(16, 2), 7.0, Color(0.10, 0.10, 0.08, 0.50))
	c.draw_line(bike + Vector2(-2, 0), bike + Vector2(16, 2), Color(0.18, 0.16, 0.12, 0.70), 2.0, true)
	c.draw_line(bike + Vector2(8, -8), bike + Vector2(10, 6), Color(0.16, 0.14, 0.10, 0.65), 1.6, true)
	# Gate shadow at the north entry (12-14,4) — wash only.
	c.draw_rect(Rect2(12.0 * t, 4.0 * t, 3.0 * t, 18.0), Color(0.02, 0.03, 0.03, 0.22))
	c.draw_rect(Rect2(12.2 * t, 3.7 * t, 2.6 * t, 6.0), Color(0.08, 0.10, 0.08, 0.35))
	# Duty board on the east interior wall, south of the warm window.
	c.draw_rect(Rect2(33.15 * t, 9.2 * t, 1.5 * t, 1.8 * t), Color(0.22, 0.18, 0.10, 0.70))
	c.draw_rect(Rect2(33.25 * t, 9.35 * t, 1.3 * t, 1.5 * t), Color(0.42, 0.48, 0.32, 0.45))
	c.draw_line(Vector2(33.35 * t, 9.6 * t), Vector2(34.2 * t, 9.6 * t), Color(0.12, 0.12, 0.08, 0.55), 1.2)
	c.draw_line(Vector2(33.35 * t, 9.95 * t), Vector2(34.05 * t, 9.95 * t), Color(0.12, 0.12, 0.08, 0.40), 1.0)
	# Rain barrel west of the bike wreck, off the spine.
	c.draw_rect(Rect2(8.4 * t, 14.3 * t, 14.0, 18.0), Color(0.16, 0.18, 0.12, 0.62))
	c.draw_rect(Rect2(8.5 * t, 14.2 * t, 12.0, 4.0), Color(0.22, 0.24, 0.16, 0.55))
	c.draw_circle(Vector2(8.85 * t, 14.55 * t), 3.0, Color(0.32, 0.38, 0.22, 0.45))
	# Courtyard well ring south of the west lamp, off the spine.
	var well := Vector2(10.6 * t, 16.6 * t)
	c.draw_circle(well, 10.0, Color(0.12, 0.14, 0.10, 0.55))
	c.draw_circle(well, 6.0, Color(0.06, 0.08, 0.06, 0.70))
	c.draw_arc(well, 10.0, 0.2, 5.6, 10, Color(0.28, 0.32, 0.22, 0.55), 1.6, true)


func _landmark_warehouse(c: CanvasItem) -> void:
	# Shelf uprights on the mid stacks + sodium lamp housings.
	for cell in [Vector2i(8, 11), Vector2i(20, 11), Vector2i(25, 9)]:
		var r := _cell_rect(cell.x, cell.y)
		c.draw_rect(r.grow(-8), Color(0.18, 0.12, 0.06, 0.55))
		c.draw_rect(Rect2(r.position + Vector2(6, 4), Vector2(20, 3)), Color(0.55, 0.42, 0.18, 0.45))
		c.draw_rect(Rect2(r.position + Vector2(6, 14), Vector2(20, 3)), Color(0.50, 0.38, 0.14, 0.4))
	for lamp in [Vector2i(13, 5), Vector2i(24, 5), Vector2i(32, 8)]:
		var p := Vector2(lamp.x * AmbushGrid.TILE + 16, lamp.y * AmbushGrid.TILE + 10)
		c.draw_circle(p, 6.0, Color(0.22, 0.16, 0.08, 0.85))
		c.draw_circle(p, 3.0, Color(0.95, 0.72, 0.22, 0.7))
		_lamp_post(c, p + Vector2(0, 18), Color(0.95, 0.62, 0.14), false)
	var t := AmbushGrid.TILE
	# Forklift silhouette parked off the spine (open floor, not a collider).
	var fk := Vector2(16.4 * t, 8.4 * t)
	c.draw_rect(Rect2(fk.x, fk.y, 28.0, 16.0), Color(0.22, 0.16, 0.08, 0.55))
	c.draw_rect(Rect2(fk.x + 22.0, fk.y - 10.0, 8.0, 12.0), Color(0.18, 0.14, 0.07, 0.55))
	c.draw_circle(fk + Vector2(6, 16), 5.0, Color(0.10, 0.08, 0.05, 0.7))
	c.draw_circle(fk + Vector2(22, 16), 5.0, Color(0.10, 0.08, 0.05, 0.7))
	# Stacked pallet shadows beside the mid shelves.
	c.draw_rect(Rect2(21.2 * t, 13.3 * t, 22.0, 10.0), Color(0.16, 0.12, 0.06, 0.40))
	c.draw_rect(Rect2(21.5 * t, 13.05 * t, 16.0, 8.0), Color(0.28, 0.20, 0.10, 0.38))
	c.draw_rect(Rect2(7.4 * t, 13.4 * t, 20.0, 9.0), Color(0.16, 0.12, 0.06, 0.36))
	# Loading dock stripe on the south lane.
	c.draw_rect(Rect2(18.0 * t, 17.15 * t, 10.0 * t, 8.0), Color(0.72, 0.48, 0.10, 0.22))
	c.draw_rect(Rect2(18.0 * t, 17.15 * t, 10.0 * t, 8.0), Color(0.90, 0.72, 0.22, 0.35), false, 1.6)
	# Shift roster clipped to the west shelf upright (blocked cell).
	c.draw_rect(Rect2(7.25 * t, 10.35 * t, 18.0, 22.0), Color(0.55, 0.48, 0.28, 0.50))
	c.draw_rect(Rect2(7.4 * t, 10.5 * t, 14.0, 3.0), Color(0.18, 0.12, 0.06, 0.55))
	c.draw_rect(Rect2(7.4 * t, 11.0 * t, 12.0, 2.0), Color(0.18, 0.12, 0.06, 0.40))
	# Oil stain on the south loading stripe.
	c.draw_circle(Vector2(22.6 * t, 17.55 * t), 10.0, Color(0.08, 0.10, 0.06, 0.32))
	c.draw_circle(Vector2(23.2 * t, 17.7 * t), 6.0, Color(0.12, 0.14, 0.08, 0.22))
	# Conveyor rollers along the east shelf face (blocked cells).
	for i in 4:
		var rx := 26.2 * t + float(i) * 10.0
		var ry := 11.35 * t
		c.draw_circle(Vector2(rx, ry), 4.0, Color(0.22, 0.16, 0.08, 0.55))
		c.draw_rect(Rect2(rx - 4.0, ry - 2.0, 8.0, 4.0), Color(0.38, 0.28, 0.10, 0.40))


func _landmark_pump(c: CanvasItem) -> void:
	# Teal pipe runs across the machinery — visual only.
	var t := AmbushGrid.TILE
	c.draw_rect(Rect2(7 * t + 8, 11 * t + 10, 12 * t, 8), Color(0.18, 0.42, 0.36, 0.55))
	c.draw_rect(Rect2(7 * t + 8, 11 * t + 12, 12 * t, 4), Color(0.28, 0.62, 0.52, 0.35))
	c.draw_rect(Rect2(18 * t + 10, 10 * t, 8, 3 * t), Color(0.16, 0.38, 0.32, 0.55))
	c.draw_rect(Rect2(24 * t + 6, 11 * t + 4, 2 * t, 10), Color(0.18, 0.40, 0.34, 0.5))
	# Valve wheels.
	for p in [Vector2(18.4 * t, 11.2 * t), Vector2(25.2 * t, 12.2 * t), Vector2(8.6 * t, 11.4 * t)]:
		c.draw_circle(p, 8.0, Color(0.22, 0.55, 0.42, 0.72))
		c.draw_circle(p, 3.0, Color(0.10, 0.18, 0.14, 0.85))
		c.draw_line(p + Vector2(-7, 0), p + Vector2(7, 0), Color(0.10, 0.16, 0.12, 0.8), 1.4)
		c.draw_line(p + Vector2(0, -7), p + Vector2(0, 7), Color(0.10, 0.16, 0.12, 0.8), 1.4)
	# Warning triangle on the east machinery face.
	var tri := PackedVector2Array([
		Vector2(26.6 * t, 10.4 * t),
		Vector2(27.6 * t, 12.1 * t),
		Vector2(25.6 * t, 12.1 * t),
	])
	c.draw_colored_polygon(tri, Color(0.92, 0.72, 0.12, 0.72))
	var tri_loop := tri.duplicate()
	tri_loop.append(tri[0])
	c.draw_polyline(tri_loop, Color(0.12, 0.10, 0.04, 0.85), 1.4, true)
	c.draw_rect(Rect2(26.45 * t, 11.15 * t, 3.0, 8.0), Color(0.08, 0.08, 0.06, 0.85))
	# Puddle plates on walkable floor (not a collider).
	c.draw_circle(Vector2(13.5 * t, 15.5 * t), 14.0, Color(0.12, 0.28, 0.26, 0.28))
	c.draw_circle(Vector2(16.2 * t, 15.8 * t), 10.0, Color(0.12, 0.26, 0.24, 0.22))
	_lamp_post(c, Vector2(10.4 * t, 14.2 * t), Color(0.32, 0.82, 0.62))
	_lamp_post(c, Vector2(22.6 * t, 13.6 * t), Color(0.28, 0.78, 0.58))
	# Valve log on the west machine face.
	c.draw_rect(Rect2(7.15 * t, 10.2 * t, 16.0, 20.0), Color(0.12, 0.22, 0.18, 0.55))
	c.draw_rect(Rect2(7.3 * t, 10.35 * t, 12.0, 3.0), Color(0.28, 0.55, 0.42, 0.45))
	# Hose coil on the south walk, off the spine.
	var hose := Vector2(18.6 * t, 15.2 * t)
	c.draw_arc(hose, 10.0, 0.2, 5.8, 12, Color(0.16, 0.32, 0.28, 0.55), 3.0, true)
	c.draw_arc(hose, 6.0, 0.8, 6.4, 10, Color(0.22, 0.42, 0.36, 0.45), 2.2, true)
	# Pressure gauge on the east machine face.
	var gauge := Vector2(26.4 * t, 13.4 * t)
	c.draw_circle(gauge, 8.0, Color(0.12, 0.18, 0.16, 0.75))
	c.draw_circle(gauge, 5.0, Color(0.28, 0.55, 0.42, 0.45))
	c.draw_line(gauge, gauge + Vector2(3.0, -4.0), Color(0.92, 0.28, 0.16, 0.80), 1.4, true)


func _landmark_railcut(c: CanvasItem) -> void:
	var t := AmbushGrid.TILE
	# Signal tower on the core wall.
	var base := Vector2(21.5 * t, 10.5 * t)
	c.draw_rect(Rect2(base.x - 10, base.y - 36, 20, 40), Color(0.16, 0.16, 0.14, 0.75))
	c.draw_rect(Rect2(base.x - 14, base.y - 44, 28, 10), Color(0.22, 0.20, 0.16, 0.8))
	c.draw_circle(base + Vector2(0, -48), 6.0, Color(0.85, 0.42, 0.12, 0.85))
	c.draw_rect(Rect2(base.x - 3, base.y - 20, 6, 22), Color(0.10, 0.10, 0.09, 0.7))
	# Extra rail steel on the two corridors (ties are in floor tiles).
	c.draw_rect(Rect2(12 * t, 5 * t + 10, 3 * t, 4), Color(0.42, 0.42, 0.38, 0.28))
	c.draw_rect(Rect2(31 * t, 5 * t + 10, 3 * t, 4), Color(0.42, 0.42, 0.38, 0.28))
	# Secondary signal mast on the west face of the core.
	var mast := Vector2(16.2 * t, 8.2 * t)
	c.draw_rect(Rect2(mast.x - 3, mast.y - 28, 6, 32), Color(0.14, 0.14, 0.12, 0.75))
	c.draw_circle(mast + Vector2(0, -32), 5.0, Color(0.85, 0.22, 0.12, 0.8))
	c.draw_circle(mast + Vector2(0, -24), 4.0, Color(0.18, 0.18, 0.12, 0.7))
	# Cable run along the north face of the core.
	c.draw_line(Vector2(15.2 * t, 7.25 * t), Vector2(28.4 * t, 7.35 * t), Color(0.12, 0.12, 0.10, 0.7), 2.2, true)
	c.draw_line(Vector2(15.2 * t, 7.45 * t), Vector2(28.4 * t, 7.55 * t), Color(0.22, 0.18, 0.10, 0.4), 1.4, true)
	_lamp_post(c, Vector2(13.6 * t, 8.4 * t), Color(0.70, 0.80, 0.92))
	_lamp_post(c, Vector2(32.4 * t, 8.4 * t), Color(0.70, 0.80, 0.92))
	# Timetable slate on the west face of the core.
	c.draw_rect(Rect2(15.15 * t, 8.3 * t, 18.0, 24.0), Color(0.10, 0.10, 0.08, 0.70))
	c.draw_rect(Rect2(15.3 * t, 8.45 * t, 14.0, 3.0), Color(0.85, 0.28, 0.16, 0.55))
	c.draw_rect(Rect2(15.3 * t, 8.85 * t, 12.0, 2.0), Color(0.70, 0.68, 0.52, 0.35))
	# Crossing gate bar at the south mouth — overlay, not a collider.
	c.draw_rect(Rect2(29.4 * t, 17.35 * t, 4.2 * t, 5.0), Color(0.72, 0.18, 0.12, 0.42))
	c.draw_rect(Rect2(29.4 * t, 17.35 * t, 18.0, 5.0), Color(0.92, 0.82, 0.22, 0.45))
	c.draw_rect(Rect2(31.6 * t, 16.6 * t, 5.0, 22.0), Color(0.16, 0.14, 0.10, 0.55))
	# Switch box on the east corridor wall.
	c.draw_rect(Rect2(33.2 * t, 12.2 * t, 12.0, 16.0), Color(0.14, 0.14, 0.12, 0.70))
	c.draw_rect(Rect2(33.4 * t, 12.4 * t, 8.0, 5.0), Color(0.85, 0.28, 0.14, 0.55))
	c.draw_rect(Rect2(33.4 * t, 13.1 * t, 8.0, 4.0), Color(0.18, 0.42, 0.22, 0.45))
	# Milepost on the west corridor, off the spine walk.
	c.draw_rect(Rect2(11.35 * t, 10.2 * t, 5.0, 22.0), Color(0.16, 0.14, 0.10, 0.70))
	c.draw_rect(Rect2(11.15 * t, 10.0 * t, 10.0, 8.0), Color(0.85, 0.28, 0.14, 0.55))
	c.draw_rect(Rect2(11.25 * t, 10.15 * t, 7.0, 2.0), Color(0.92, 0.82, 0.22, 0.50))


func _landmark_depot(c: CanvasItem) -> void:
	var t := AmbushGrid.TILE
	# Fuel tank silhouettes on the mid blocked island — fat circles, not a mast.
	var a := Vector2(18.4 * t, 11.1 * t)
	var b := Vector2(21.7 * t, 10.5 * t)
	var d := Vector2(20.0 * t, 12.35 * t)
	c.draw_circle(a, 38.0, Color(0.22, 0.12, 0.06, 0.82))
	c.draw_circle(a, 30.0, Color(0.42, 0.20, 0.08, 0.58))
	c.draw_circle(a, 18.0, Color(0.18, 0.08, 0.04, 0.45))
	c.draw_rect(Rect2(a.x - 8, a.y - 46, 16, 22), Color(0.18, 0.10, 0.05, 0.85))
	c.draw_rect(Rect2(a.x - 5, a.y - 52, 10, 8), Color(0.28, 0.14, 0.06, 0.75))
	c.draw_circle(b, 30.0, Color(0.20, 0.10, 0.05, 0.78))
	c.draw_circle(b, 22.0, Color(0.38, 0.16, 0.06, 0.52))
	c.draw_circle(d, 22.0, Color(0.24, 0.12, 0.05, 0.70))
	c.draw_circle(d, 15.0, Color(0.40, 0.18, 0.06, 0.42))
	# Hazard chevrons along the south face of the tanks.
	for i in 7:
		var x := 15.6 * t + float(i) * 16.0
		var y := 14.0 * t + 4.0
		var col := Color(0.92, 0.62, 0.10, 0.62) if (i % 2) == 0 else Color(0.08, 0.07, 0.05, 0.62)
		c.draw_rect(Rect2(x, y, 15.0, 9.0), col)
	# Fuel pipe run from tanks toward the east wall (overlay on blocked core).
	c.draw_rect(Rect2(22.2 * t, 10.7 * t, 6.0 * t, 7.0), Color(0.28, 0.14, 0.06, 0.55))
	c.draw_rect(Rect2(22.2 * t, 10.85 * t, 6.0 * t, 3.0), Color(0.42, 0.22, 0.08, 0.35))
	c.draw_circle(Vector2(28.0 * t, 10.95 * t), 6.0, Color(0.22, 0.12, 0.06, 0.6))
	# Hazard cone row along the south connector, off the sneak alley.
	for i in 6:
		var cx := 16.5 * t + float(i) * 22.0
		var cy := 15.55 * t
		c.draw_colored_polygon(
			PackedVector2Array([Vector2(cx, cy - 10), Vector2(cx + 7, cy + 6), Vector2(cx - 7, cy + 6)]),
			Color(0.92, 0.48, 0.10, 0.62)
		)
		c.draw_rect(Rect2(cx - 3, cy + 5, 6.0, 3.0), Color(0.12, 0.08, 0.04, 0.55))
	_lamp_post(c, Vector2(12.4 * t, 8.6 * t), Color(0.55, 0.72, 0.82))
	_lamp_post(c, Vector2(26.2 * t, 15.4 * t), Color(0.92, 0.48, 0.12))
	# Fuel ticket clipped to the west tank stair.
	c.draw_rect(Rect2(15.2 * t, 8.2 * t, 14.0, 18.0), Color(0.92, 0.78, 0.42, 0.50))
	c.draw_rect(Rect2(15.35 * t, 8.35 * t, 10.0, 3.0), Color(0.22, 0.10, 0.04, 0.55))
	# Chain-link shadow along the west alley wall (x=8-9 is blocked; sneak is x=7).
	c.draw_rect(Rect2(8.15 * t, 7.2 * t, 6.0, 6.2 * t), Color(0.08, 0.10, 0.08, 0.28))
	for i in 8:
		var ly := 7.4 * t + float(i) * 22.0
		c.draw_line(Vector2(8.2 * t, ly), Vector2(8.55 * t, ly + 14.0), Color(0.42, 0.48, 0.40, 0.22), 1.0)
	# Drip pan under the east tank stair.
	c.draw_rect(Rect2(23.4 * t, 13.6 * t, 28.0, 8.0), Color(0.18, 0.10, 0.05, 0.45))
	c.draw_rect(Rect2(23.6 * t, 13.75 * t, 24.0, 3.0), Color(0.42, 0.22, 0.08, 0.28))
	# Fill nozzle hanging off the east pipe run.
	c.draw_rect(Rect2(27.6 * t, 11.15 * t, 16.0, 5.0), Color(0.28, 0.14, 0.06, 0.60))
	c.draw_circle(Vector2(28.7 * t, 11.55 * t), 5.0, Color(0.42, 0.22, 0.08, 0.55))
	c.draw_rect(Rect2(28.4 * t, 11.55 * t, 4.0, 10.0), Color(0.18, 0.10, 0.05, 0.55))


func _landmark_radio(c: CanvasItem) -> void:
	var t := AmbushGrid.TILE
	# Lighthouse mast on the blocked core (~cell 18-20, y 8-11). 90+ px, not a tank circle.
	var mast := Vector2(19.2 * t, 11.55 * t)
	var mast_h := 118.0
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(mast.x - 18, mast.y + 12),
			Vector2(mast.x + 18, mast.y + 12),
			Vector2(mast.x + 10, mast.y - mast_h + 24),
			Vector2(mast.x - 10, mast.y - mast_h + 24),
		]),
		Color(0.08, 0.14, 0.18, 0.90)
	)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(mast.x - 7, mast.y + 10),
			Vector2(mast.x - 1, mast.y + 10),
			Vector2(mast.x + 2, mast.y - mast_h + 26),
			Vector2(mast.x - 4, mast.y - mast_h + 26),
		]),
		Color(0.32, 0.58, 0.68, 0.28)
	)
	# Lighthouse bands so the shaft reads as a beacon tower, not a pipe.
	c.draw_rect(Rect2(mast.x - 15, mast.y - 16, 30.0, 11.0), Color(0.78, 0.92, 0.98, 0.32))
	c.draw_rect(Rect2(mast.x - 13, mast.y - 52, 26.0, 10.0), Color(0.78, 0.92, 0.98, 0.26))
	c.draw_rect(Rect2(mast.x - 11, mast.y - 86, 22.0, 9.0), Color(0.78, 0.92, 0.98, 0.22))
	c.draw_rect(Rect2(mast.x - 4, mast.y - 42, 8.0, 16.0), Color(0.42, 0.82, 0.96, 0.42))
	c.draw_rect(Rect2(mast.x - 3, mast.y - 74, 6.0, 12.0), Color(0.42, 0.82, 0.96, 0.36))
	# Lantern house + cyan beacon glass.
	c.draw_rect(Rect2(mast.x - 13, mast.y - mast_h, 26.0, 24.0), Color(0.14, 0.26, 0.32, 0.92))
	c.draw_rect(Rect2(mast.x - 16, mast.y - mast_h - 7, 32.0, 9.0), Color(0.22, 0.38, 0.44, 0.90))
	c.draw_rect(Rect2(mast.x - 17, mast.y - mast_h + 20, 34.0, 5.0), Color(0.18, 0.30, 0.36, 0.80))
	c.draw_circle(Vector2(mast.x, mast.y - mast_h + 11), 9.0, Color(0.55, 0.92, 1.0, 0.82))
	c.draw_circle(Vector2(mast.x, mast.y - mast_h + 11), 4.5, Color(0.92, 0.98, 1.0, 0.92))
	c.draw_rect(Rect2(mast.x - 22, mast.y + 10, 44.0, 8.0), Color(0.08, 0.12, 0.16, 0.75))
	# Radio dish / Dish array — large parabolas on the east annex (blocked cells x=25-28).
	var dish_a := Vector2(27.05 * t, 9.45 * t)
	c.draw_arc(dish_a, 56.0, -2.62, 0.48, 18, Color(0.50, 0.84, 0.98, 0.68), 6.0, true)
	c.draw_arc(dish_a, 44.0, -2.62, 0.48, 16, Color(0.16, 0.32, 0.40, 0.80), 3.4, true)
	c.draw_line(dish_a, dish_a + Vector2(30, -28), Color(0.62, 0.90, 1.0, 0.78), 2.4, true)
	c.draw_circle(dish_a + Vector2(30, -28), 5.5, Color(0.80, 0.96, 1.0, 0.92))
	var dish_b := Vector2(27.55 * t, 11.25 * t)
	c.draw_arc(dish_b, 46.0, -2.15, 0.90, 16, Color(0.42, 0.76, 0.90, 0.58), 5.0, true)
	c.draw_arc(dish_b, 34.0, -2.15, 0.90, 14, Color(0.16, 0.30, 0.38, 0.72), 2.8, true)
	c.draw_line(dish_b, dish_b + Vector2(24, -18), Color(0.55, 0.86, 0.96, 0.70), 2.0, true)
	c.draw_circle(dish_b + Vector2(24, -18), 4.0, Color(0.72, 0.94, 1.0, 0.85))
	var dish_c := Vector2(25.85 * t, 10.95 * t)
	c.draw_arc(dish_c, 40.0, -2.75, 0.28, 14, Color(0.36, 0.68, 0.82, 0.50), 4.2, true)
	c.draw_arc(dish_c, 30.0, -2.75, 0.28, 12, Color(0.14, 0.26, 0.34, 0.62), 2.2, true)
	# Guy wire from dish hall to east annex.
	c.draw_line(Vector2(mast.x + 10, mast.y - 88), Vector2(27.0 * t, 9.6 * t), Color(0.55, 0.78, 0.88, 0.48), 1.6, true)
	c.draw_line(Vector2(16.4 * t, 8.2 * t), Vector2(12.2 * t, 12.4 * t), Color(0.55, 0.78, 0.88, 0.32), 1.2, true)
	c.draw_line(Vector2(mast.x - 8, mast.y - 70), Vector2(15.4 * t, 8.6 * t), Color(0.50, 0.74, 0.86, 0.36), 1.3, true)
	# Morse hut on the east annex (already blocked).
	c.draw_rect(Rect2(25.4 * t, 8.4 * t, 2.4 * t, 2.8 * t), Color(0.10, 0.16, 0.20, 0.70))
	c.draw_rect(Rect2(25.6 * t, 8.6 * t, 2.0 * t, 10.0), Color(0.32, 0.72, 0.88, 0.35))
	c.draw_rect(Rect2(26.2 * t, 8.2 * t, 8.0, 6.0), Color(0.55, 0.88, 1.0, 0.45))
	# Call log tucked under the Morse hut window.
	c.draw_rect(Rect2(25.55 * t, 10.6 * t, 16.0, 12.0), Color(0.10, 0.16, 0.20, 0.55))
	c.draw_rect(Rect2(25.7 * t, 10.75 * t, 12.0, 2.0), Color(0.42, 0.82, 0.95, 0.45))
	# Antenna mast west of the core, off the sneak alley.
	var west_mast := Vector2(10.4 * t, 9.2 * t)
	c.draw_rect(Rect2(west_mast.x - 2, west_mast.y - 40, 4.0, 44.0), Color(0.14, 0.18, 0.22, 0.80))
	c.draw_circle(west_mast + Vector2(0, -44), 5.0, Color(0.42, 0.88, 0.95, 0.80))
	c.draw_line(west_mast + Vector2(0, -20), west_mast + Vector2(14, -8), Color(0.40, 0.70, 0.82, 0.40), 1.2, true)
	_lamp_post(c, Vector2(13.6 * t, 8.4 * t), Color(0.55, 0.86, 0.98))
	_lamp_post(c, Vector2(32.4 * t, 8.4 * t), Color(0.55, 0.86, 0.98))
	# Cable run along the south face of the core.
	c.draw_line(Vector2(15.2 * t, 14.35 * t), Vector2(23.6 * t, 14.45 * t), Color(0.12, 0.18, 0.22, 0.70), 2.2, true)
	c.draw_line(Vector2(15.2 * t, 14.55 * t), Vector2(23.6 * t, 14.65 * t), Color(0.28, 0.48, 0.58, 0.40), 1.4, true)
	# Spare dish leaning on the west annex, off the sneak alley.
	var spare := Vector2(9.6 * t, 13.4 * t)
	c.draw_arc(spare, 16.0, 0.4, 3.2, 10, Color(0.32, 0.52, 0.62, 0.50), 2.4, true)
	c.draw_line(spare + Vector2(-10, 8), spare + Vector2(12, -6), Color(0.40, 0.62, 0.72, 0.40), 1.4, true)
	# Sandbag row along the south mouth, not on the escape cell.
	for i in 5:
		var bx := 18.4 * t + float(i) * 18.0
		var by := 18.15 * t
		c.draw_rect(Rect2(bx, by, 14.0, 8.0), Color(0.28, 0.24, 0.14, 0.55))
		c.draw_rect(Rect2(bx + 1.0, by + 1.0, 12.0, 3.0), Color(0.38, 0.32, 0.16, 0.40))
	# Phosphor ticks down the echo hall (x=24), distinct from depot tank farm.
	# Echo hall phosphor — brighter and denser than the old 4-tick wash.
	c.draw_rect(Rect2(24.08 * t, 5.25 * t, 0.84 * t, 10.4 * t), Color(0.32, 0.78, 0.95, 0.22))
	for i in 11:
		var ey := 5.45 * t + float(i) * 28.0
		c.draw_rect(Rect2(24.22 * t, ey, 16.0, 4.0), Color(0.55, 0.92, 1.0, 0.50))
		c.draw_rect(Rect2(24.38 * t, ey + 1.0, 8.0, 2.0), Color(0.82, 0.98, 1.0, 0.58))
	# Horn speaker on the east annex roof.
	var horn := Vector2(27.6 * t, 8.15 * t)
	c.draw_circle(horn, 6.0, Color(0.18, 0.28, 0.32, 0.70))
	c.draw_colored_polygon(
		PackedVector2Array([horn + Vector2(4, -3), horn + Vector2(16, -8), horn + Vector2(16, 8), horn + Vector2(4, 3)]),
		Color(0.32, 0.62, 0.72, 0.50)
	)


func _draw_signature_silhouette(c: CanvasItem) -> void:
	## One large cached identity prop per mission. Overlay polygons only.
	match _atmo():
		"warehouse":
			_silhouette_warehouse_roof(c)
		"pump":
			_silhouette_pump_chimney(c)
		"railcut":
			_silhouette_railcut_tower(c)
		"depot":
			_silhouette_depot_tanks(c)
		"radio":
			_silhouette_radio_dish(c)
		_:
			_silhouette_yard_tree(c)


func _silhouette_yard_tree(c: CanvasItem) -> void:
	# yard tree — west garden, off the spine (x=13) and bike wreck.
	var t := AmbushGrid.TILE
	var base := Vector2(5.4 * t, 15.6 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(base.x - 6, base.y + 8),
			Vector2(base.x + 6, base.y + 8),
			Vector2(base.x + 4, base.y - 18),
			Vector2(base.x - 4, base.y - 18),
		]),
		Color(0.10, 0.08, 0.05, 0.70)
	)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(base.x, base.y - 78),
			Vector2(base.x + 36, base.y - 18),
			Vector2(base.x + 18, base.y - 14),
			Vector2(base.x, base.y - 22),
			Vector2(base.x - 18, base.y - 14),
			Vector2(base.x - 36, base.y - 18),
		]),
		Color(0.12, 0.18, 0.10, 0.62)
	)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(base.x - 4, base.y - 70),
			Vector2(base.x + 22, base.y - 32),
			Vector2(base.x - 20, base.y - 28),
		]),
		Color(0.16, 0.24, 0.12, 0.40)
	)


func _silhouette_warehouse_roof(c: CanvasItem) -> void:
	# warehouse roof peak — mid shelf island, already blocked.
	var t := AmbushGrid.TILE
	var origin := Vector2(19.2 * t, 9.2 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(origin.x, origin.y - 52),
			Vector2(origin.x + 92, origin.y + 18),
			Vector2(origin.x + 84, origin.y + 28),
			Vector2(origin.x, origin.y - 8),
			Vector2(origin.x - 84, origin.y + 28),
			Vector2(origin.x - 92, origin.y + 18),
		]),
		Color(0.18, 0.12, 0.06, 0.55)
	)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(origin.x, origin.y - 52),
			Vector2(origin.x + 92, origin.y + 18),
			Vector2(origin.x, origin.y - 8),
		]),
		Color(0.42, 0.28, 0.10, 0.28)
	)


func _silhouette_pump_chimney(c: CanvasItem) -> void:
	# pump chimney — east machinery face, blocked cells.
	var t := AmbushGrid.TILE
	var x := 25.35 * t
	var y := 10.2 * t
	c.draw_rect(Rect2(x, y - 88, 18.0, 96.0), Color(0.10, 0.18, 0.16, 0.72))
	c.draw_rect(Rect2(x + 3, y - 88, 5.0, 96.0), Color(0.22, 0.40, 0.34, 0.28))
	c.draw_rect(Rect2(x - 6, y - 98, 30.0, 12.0), Color(0.12, 0.22, 0.18, 0.80))
	c.draw_circle(Vector2(x + 9, y - 104), 8.0, Color(0.16, 0.28, 0.24, 0.55))
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 4, y - 110),
			Vector2(x + 22, y - 110),
			Vector2(x + 16, y - 128),
			Vector2(x + 2, y - 128),
		]),
		Color(0.14, 0.22, 0.20, 0.45)
	)


func _silhouette_railcut_tower(c: CanvasItem) -> void:
	# railcut tower block — core wall mass behind the signal lamp.
	var t := AmbushGrid.TILE
	var p := Vector2(21.5 * t, 10.6 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(p.x - 28, p.y + 18),
			Vector2(p.x + 28, p.y + 18),
			Vector2(p.x + 22, p.y - 70),
			Vector2(p.x - 22, p.y - 70),
		]),
		Color(0.12, 0.12, 0.10, 0.78)
	)
	c.draw_rect(Rect2(p.x - 34, p.y - 82, 68.0, 14.0), Color(0.18, 0.16, 0.12, 0.82))
	c.draw_rect(Rect2(p.x - 8, p.y - 118, 16.0, 36.0), Color(0.14, 0.14, 0.12, 0.75))
	c.draw_rect(Rect2(p.x - 18, p.y - 126, 36.0, 10.0), Color(0.22, 0.18, 0.12, 0.80))


func _silhouette_depot_tanks(c: CanvasItem) -> void:
	# depot tank farm — extra tanks on the blocked island, west of existing pair.
	var t := AmbushGrid.TILE
	var a := Vector2(16.5 * t, 11.4 * t)
	var b := Vector2(23.9 * t, 11.7 * t)
	var d := Vector2(20.2 * t, 12.6 * t)
	c.draw_circle(a, 42.0, Color(0.16, 0.08, 0.04, 0.74))
	c.draw_circle(a, 32.0, Color(0.34, 0.14, 0.06, 0.46))
	c.draw_rect(Rect2(a.x - 8, a.y - 50, 16.0, 22.0), Color(0.14, 0.08, 0.04, 0.82))
	c.draw_circle(b, 32.0, Color(0.18, 0.08, 0.04, 0.68))
	c.draw_circle(b, 22.0, Color(0.38, 0.16, 0.06, 0.40))
	c.draw_circle(d, 24.0, Color(0.20, 0.10, 0.04, 0.55))
	c.draw_rect(Rect2(17.2 * t, 13.55 * t, 7.6 * t, 9.0), Color(0.22, 0.10, 0.04, 0.48))


func _silhouette_radio_dish(c: CanvasItem) -> void:
	# dish hall — lighthouse mast + dish array, not a tank rectangle.
	var t := AmbushGrid.TILE
	var p := Vector2(19.2 * t, 11.55 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(p.x - 20, p.y + 14),
			Vector2(p.x + 20, p.y + 14),
			Vector2(p.x + 11, p.y - 96),
			Vector2(p.x - 11, p.y - 96),
		]),
		Color(0.08, 0.14, 0.18, 0.78)
	)
	c.draw_rect(Rect2(p.x - 16, p.y - 118, 32.0, 24.0), Color(0.12, 0.22, 0.28, 0.82))
	c.draw_rect(Rect2(p.x - 18, p.y - 126, 36.0, 10.0), Color(0.18, 0.32, 0.38, 0.80))
	c.draw_circle(Vector2(p.x, p.y - 108), 8.0, Color(0.42, 0.82, 0.96, 0.55))
	# Dish array bowls on the east annex (blocked x=25-28).
	var d1 := Vector2(27.05 * t, 9.5 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(d1.x - 52, d1.y + 16),
			Vector2(d1.x + 8, d1.y - 58),
			Vector2(d1.x + 24, d1.y - 44),
			Vector2(d1.x - 22, d1.y + 22),
		]),
		Color(0.10, 0.18, 0.24, 0.62)
	)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(d1.x - 38, d1.y + 8),
			Vector2(d1.x + 4, d1.y - 46),
			Vector2(d1.x + 14, d1.y - 36),
			Vector2(d1.x - 12, d1.y + 12),
		]),
		Color(0.28, 0.52, 0.64, 0.34)
	)
	var d2 := Vector2(27.5 * t, 11.3 * t)
	c.draw_colored_polygon(
		PackedVector2Array([
			Vector2(d2.x - 40, d2.y + 14),
			Vector2(d2.x + 6, d2.y - 42),
			Vector2(d2.x + 18, d2.y - 30),
			Vector2(d2.x - 16, d2.y + 18),
		]),
		Color(0.10, 0.16, 0.22, 0.50)
	)
	# Echo hall phosphor ribbon so x=24 reads as the dish-gap path.
	c.draw_rect(Rect2(24.05 * t, 5.2 * t, 0.9 * t, 10.5 * t), Color(0.28, 0.72, 0.92, 0.22))


func _lamp_post(c: CanvasItem, p: Vector2, glow: Color, stem: bool = true) -> void:
	## Decorative lamp. Overlay only — never writes grid.blocked.
	if stem:
		c.draw_rect(Rect2(p.x - 1.5, p.y - 22.0, 3.0, 22.0), Color(0.12, 0.10, 0.07, 0.85))
		c.draw_rect(Rect2(p.x - 5.0, p.y - 26.0, 10.0, 6.0), Color(0.16, 0.14, 0.08, 0.90))
	var saving := _is_power_saving()
	c.draw_circle(p + Vector2(0, 10), 22.0 if saving else 28.0, Color(glow.r, glow.g, glow.b, 0.07 if saving else 0.12))
	c.draw_circle(p, 5.0, Color(glow.r, glow.g, glow.b, 0.55 if saving else 0.72))
	c.draw_circle(p, 2.2, Color(0.98, 0.96, 0.82, 0.85))


func _frac(n: int) -> float:
	var s := sin(float(n) * 12.9898) * 43758.5453
	return s - floor(s)
