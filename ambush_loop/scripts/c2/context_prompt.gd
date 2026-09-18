class_name C2ContextPrompt
extends CanvasLayer

## Phone context hotspots. 1–2 fat verbs anchored on the world target,
## driven by the selected operator — not the last tap / mouse.

const Pathfinder := preload("res://scripts/raid/pathfinder.gd")

const PROBE_CRATE := 14.0
const PROBE_COVER := 12.0
const PROBE_KNIFE := 32.0
const PROBE_FLANK := 76.0
const PROBE_WHISTLE := 32.0
const HOLD_SEC := 0.55
const BTN_SIZE := Vector2(88, 36)
const FLANK_BTN := Vector2(88, 38)
const CRATE_BTN := Vector2(96, 42)
var host: Node = null
var _root: Control = null
var _draw: Control = null
var _btns: Array = []
var _hold_t: float = 0.0
var _shown: Array = []
var _rings: Array = []
var _guide: PackedVector2Array = PackedVector2Array()


func bind(main: Node) -> void:
	host = main


func _ready() -> void:
	layer = 40
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_draw = Control.new()
	_draw.name = "Rings"
	_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_draw_rings)
	_root.add_child(_draw)
	for i in 2:
		var b := Button.new()
		b.visible = false
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = BTN_SIZE
		b.theme = NightOps.theme()
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_font_override("font", NightOps.ui_font_bold())
		var slot := i
		b.pressed.connect(func() -> void:
			_fire(slot)
		)
		_root.add_child(b)
		_btns.append(b)
	set_process(true)


func hotspot_count() -> int:
	var n := 0
	for b in _btns:
		if b != null and b.visible:
			n += 1
	return n


func visible_captions() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _btns:
		if b != null and b.visible:
			out.append(str(b.text))
	return out


func visible_cmds() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _btns:
		if b != null and b.visible:
			out.append(str(b.get_meta("cmd", "")))
	return out


func has_caption(caption: String) -> bool:
	return visible_captions().has(caption)


func has_cmd(cmd: String) -> bool:
	return visible_cmds().has(cmd)


func fire_caption(caption: String) -> bool:
	for i in _btns.size():
		var b: Button = _btns[i]
		if b != null and b.visible and str(b.text) == caption:
			_fire(i)
			return true
	return false


func refresh_now() -> void:
	_hold_t = HOLD_SEC
	_apply(_probe())


func _process(delta: float) -> void:
	if host == null or not _phone() or not _command():
		_hide_all()
		_rings.clear()
		_guide = PackedVector2Array()
		if _draw:
			_draw.queue_redraw()
		return
	var actions: Array = _probe()
	if _draw:
		_draw.queue_redraw()
	if actions.is_empty():
		_hold_t = maxf(_hold_t - delta, 0.0)
		if _hold_t <= 0.0:
			_hide_all()
			_rings.clear()
			_guide = PackedVector2Array()
			if _draw:
				_draw.queue_redraw()
		return
	_hold_t = HOLD_SEC
	_apply(actions)


func _phone() -> bool:
	return host != null and host.has_method("_want_touch") and bool(host._want_touch())


func _command() -> bool:
	return host != null and host.has_method("_is_command_phase") and bool(host._is_command_phase())


func _op() -> Node:
	return host.selected if host else null


func _moving(op: Node) -> bool:
	return op != null and op.has_method("is_moving") and bool(op.is_moving())


func _cell_of(world: Vector2) -> Vector2i:
	if host != null and host.get("grid") != null:
		return host.grid.world_to_cell(world)
	return Vector2i(int(world.x / 32.0), int(world.y / 32.0))


func _on_cell(a: Vector2, b: Vector2) -> bool:
	return _cell_of(a) == _cell_of(b)


func _probe() -> Array:
	_guide = PackedVector2Array()
	_rings.clear()
	var op := _op()
	if op == null or not bool(op.alive) or not op.visible:
		return []
	var origin: Vector2 = op.global_position
	var moving := _moving(op)
	var cands: Array = []
	if not moving and host.get("raid_stashes") != null:
		for st in host.raid_stashes:
			if st == null or not is_instance_valid(st) or bool(st.collected):
				continue
			var d: float = origin.distance_to(st.global_position)
			if _on_cell(origin, st.global_position) or d <= PROBE_CRATE:
				cands.append({"d": d, "pri": 1, "kind": "crate", "world": st.global_position, "node": st})
	if not moving and host.get("loot_piles") != null:
		for loot in host.loot_piles:
			if loot == null or not is_instance_valid(loot) or bool(loot.collected):
				continue
			var d2: float = origin.distance_to(loot.global_position)
			if _on_cell(origin, loot.global_position) or d2 <= PROBE_CRATE:
				cands.append({"d": d2, "pri": 1, "kind": "corpse", "world": loot.global_position, "node": loot})
	if not moving and host.has_method("_nearest_slot"):
		var slot = host._nearest_slot(origin, PROBE_COVER)
		if slot != null and _on_cell(origin, slot.global_position):
			cands.append({"d": origin.distance_to(slot.global_position), "pri": 6, "kind": "cover", "world": slot.global_position, "node": slot})
	var c2 = host.get("c2")
	if c2 != null and c2.get("sentries") != null:
		for s in c2.sentries:
			if s == null or not is_instance_valid(s):
				continue
			var d3: float = origin.distance_to(s.global_position)
			if bool(s.is_down()):
				if not moving and int(s.state) == 3 and d3 <= 40.0:
					cands.append({"d": d3, "pri": 2, "kind": "bind", "world": s.global_position, "node": s})
				continue
			var rear: bool = s.has_method("rear_hemisphere") and bool(s.rear_hemisphere(origin))
			var flank_arc: bool = s.has_method("flank_hemisphere") and bool(s.flank_hemisphere(origin))
			if not flank_arc:
				flank_arc = rear
			var back: bool = s.has_method("in_backstab") and bool(s.in_backstab(origin))
			if back and d3 <= PROBE_KNIFE:
				cands.append({"d": d3, "pri": 0, "kind": "knife", "world": s.global_position, "node": s})
			elif flank_arc and (not back) and d3 <= PROBE_FLANK:
				cands.append({"d": d3, "pri": 3, "kind": "flank", "world": s.global_position, "node": s})
			elif (not flank_arc) and d3 <= PROBE_WHISTLE and not moving:
				cands.append({"d": d3, "pri": 4, "kind": "whistle", "world": s.global_position, "node": s})
	if not moving and host.get("operators") != null:
		for other in host.operators:
			if other == null or other == op or not bool(other.alive):
				continue
			if float(other.hp) >= 99.5:
				continue
			var d4: float = origin.distance_to(other.global_position)
			if d4 <= 40.0:
				cands.append({"d": d4, "pri": 5, "kind": "aid", "world": other.global_position, "node": other})
	if cands.is_empty():
		return []
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["pri"]) != int(b["pri"]):
			return int(a["pri"]) < int(b["pri"])
		return float(a["d"]) < float(b["d"])
	)
	var top: Dictionary = cands[0]
	var kind := str(top["kind"])
	_rings = [top["world"]]
	if kind == "corpse":
		return [
			_act("loot", "搜尸", top["world"], Color(0.72, 0.62, 0.28)),
			_act("haul", "拖尸", top["world"], Color(0.55, 0.48, 0.32))
		]
	if kind == "crate":
		return [_act("crate", "开匣", top["world"], Color(0.62, 0.52, 0.28))]
	if kind == "cover":
		return [_act("cover", "上掩体", top["world"], Color(0.38, 0.48, 0.32))]
	if kind == "knife":
		var kact := _act("knife", "割喉", top["world"], Color(0.72, 0.28, 0.20))
		kact["anchor"] = origin
		return [kact]
	if kind == "flank":
		_guide = _flank_guide(op, top.get("node"))
		var dest: Vector2 = top["world"]
		if host != null and host.has_method("flank_dest_world") and top.get("node") != null:
			dest = host.flank_dest_world(top["node"], op)
		var fact := _act("flank", "绕背", dest, Color(0.78, 0.36, 0.22))
		## Pin the fat verb to the operator, not the dest cell (west-court crates).
		fact["anchor"] = origin
		return [fact]
	if kind == "whistle":
		return [_act("whistle", "口哨", top["world"], Color(0.82, 0.72, 0.28))]
	if kind == "bind":
		return [_act("bind", "捆绑", top["world"], Color(0.55, 0.48, 0.28))]
	if kind == "aid":
		return [_act("aid", "包扎", top["world"], Color(0.72, 0.32, 0.22))]
	return []


func _flank_guide(op: Node, sentry) -> PackedVector2Array:
	var out := PackedVector2Array()
	if op == null or sentry == null or host == null or host.get("grid") == null:
		return out
	var dest: Vector2 = sentry.global_position
	if host.has_method("flank_dest_world"):
		dest = host.flank_dest_world(sentry, op)
	elif sentry.has_method("backstab_world"):
		dest = sentry.backstab_world()
	var from_c: Vector2i = op.grid_cell() if op.has_method("grid_cell") else host.grid.world_to_cell(op.global_position)
	var to_c: Vector2i = host.grid.world_to_cell(dest)
	var cells: Array[Vector2i] = []
	if host.has_method("flank_path_cells"):
		cells = host.flank_path_cells(sentry, op)
	if cells.is_empty() and host.has_method("stealth_path_cells"):
		cells = host.stealth_path_cells(from_c, to_c, op)
	if cells.is_empty():
		cells = Pathfinder.find_path(host.grid, from_c, to_c)
	out.append(op.global_position)
	for c in cells:
		var w: Vector2 = host.grid.cell_to_world_center(c)
		if out.size() > 0 and w.distance_to(out[out.size() - 1]) < 6.0:
			continue
		out.append(w)
	if dest.distance_to(out[out.size() - 1]) > 10.0:
		out.append(dest)
	return out


func guide_points() -> PackedVector2Array:
	return _guide


func guide_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if host == null or host.get("grid") == null:
		return cells
	for w in _guide:
		var c: Vector2i = host.grid.world_to_cell(w)
		if cells.is_empty() or cells[cells.size() - 1] != c:
			cells.append(c)
	return cells


func guide_cell_count() -> int:
	return guide_cells().size()


func guide_complete() -> bool:
	if _guide.size() < 2:
		return false
	if host == null or host.get("grid") == null:
		return _guide.size() >= 2
	var cells: Array[Vector2i] = guide_cells()
	if cells.size() < 2:
		return false
	for i in range(1, cells.size()):
		var d: int = absi(cells[i].x - cells[i - 1].x) + absi(cells[i].y - cells[i - 1].y)
		if d > 1:
			return false
	return true


func guide_wraps() -> bool:
	if not guide_complete():
		return false
	return guide_cell_count() >= 4


func _act(cmd: String, caption: String, world: Vector2, tint: Color) -> Dictionary:
	return {"cmd": cmd, "caption": caption, "world": world, "tint": tint}


func _map_safe(vis: Vector2) -> Rect2:
	## Keep hotspots off the title band / north wall and the thumb bar.
	return Rect2(8.0, 64.0, vis.x - 16.0, vis.y - 64.0 - 148.0)


func _btn_sz(cmd: String) -> Vector2:
	if cmd == "flank":
		return FLANK_BTN
	if cmd == "crate":
		return CRATE_BTN
	if cmd == "cover":
		return Vector2(84, 34)
	return BTN_SIZE


func visible_hotspot_rects() -> Array:
	var out: Array = []
	for b in _btns:
		if b == null or not b.visible:
			continue
		out.append({
			"cmd": str(b.get_meta("cmd", "")),
			"caption": str(b.text),
			"rect": Rect2(b.position, b.size),
		})
	return out


func hotspot_hits_west_operable() -> int:
	var n := 0
	if host == null:
		return 0
	var xf: Transform2D = host.get_viewport().get_canvas_transform()
	for rec in visible_hotspot_rects():
		var hr: Rect2 = rec["rect"]
		for world in _west_operable_worlds():
			if hr.intersects(_world_screen_rect(xf, world, 14.0)):
				n += 1
	return n


func _west_operable_worlds() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host == null:
		return out
	if host.get("raid_stashes") != null:
		for st in host.raid_stashes:
			if st == null or not is_instance_valid(st) or bool(st.collected):
				continue
			if _cell_of(st.global_position).x <= 12:
				out.append(st.global_position)
	if host.get("cover_slots") != null:
		for slot in host.cover_slots:
			if slot == null or not is_instance_valid(slot):
				continue
			if _cell_of(slot.global_position).x <= 12:
				out.append(slot.global_position)
	if host.get("loot_piles") != null:
		for loot in host.loot_piles:
			if loot == null or not is_instance_valid(loot) or bool(loot.collected):
				continue
			if _cell_of(loot.global_position).x <= 12:
				out.append(loot.global_position)
	return out


func _world_screen_rect(xf: Transform2D, world: Vector2, half: float) -> Rect2:
	var p: Vector2 = xf * world
	var hx := absf(xf.x.x) * half
	var hy := absf(xf.y.y) * half
	if hx < 8.0:
		hx = half
	if hy < 8.0:
		hy = half
	return Rect2(p - Vector2(hx, hy), Vector2(hx * 2.0, hy * 2.0))


func _operable_rects(xf: Transform2D, cmd: String, target: Vector2) -> Array:
	var rects: Array = []
	if host == null:
		return rects
	var pad := 12.0
	if cmd == "flank":
		pad = 16.0
	var skip_d := 18.0 if cmd != "flank" else 4.0
	if host.get("raid_stashes") != null:
		for st in host.raid_stashes:
			if st == null or not is_instance_valid(st) or bool(st.collected):
				continue
			if st.global_position.distance_to(target) <= skip_d:
				continue
			var extra := pad
			if _cell_of(st.global_position).x <= 12:
				extra = pad + 6.0
			rects.append(_world_screen_rect(xf, st.global_position, extra))
	if host.get("cover_slots") != null:
		for slot in host.cover_slots:
			if slot == null or not is_instance_valid(slot):
				continue
			if slot.global_position.distance_to(target) <= skip_d:
				continue
			var extra2 := pad
			if _cell_of(slot.global_position).x <= 12:
				extra2 = pad + 6.0
			rects.append(_world_screen_rect(xf, slot.global_position, extra2))
	return rects


func _rect_hits_any(hr: Rect2, rects: Array) -> bool:
	for r in rects:
		if hr.intersects(r):
			return true
	return false


func _count_hits(hr: Rect2, rects: Array) -> int:
	var n := 0
	for r in rects:
		if hr.intersects(r):
			n += 1
	return n


func _place_hotspot(
	cmd: String,
	screen: Vector2,
	op_screen: Vector2,
	safe: Rect2,
	blocked: Array,
	i: int,
	n: int
) -> Vector2:
	var sz := _btn_sz(cmd)
	var x_off := (float(i) - (float(n) - 1.0) * 0.5) * (sz.x + 8.0)
	## 开匣: dump 07 sat left in the west-wall soap. Pin above the crate,
	## biased east (courtyard), never west of the crate screen x.
	if cmd == "crate":
		var anchor: Vector2 = screen if screen != Vector2.INF else op_screen
		if op_screen != Vector2.INF:
			anchor.y = minf(anchor.y, op_screen.y)
		var pin := Vector2(anchor.x - sz.x * 0.22, anchor.y - sz.y - 24.0)
		if op_screen != Vector2.INF:
			pin.y = minf(pin.y, op_screen.y - sz.y - 22.0)
		if screen != Vector2.INF:
			pin.x = maxf(pin.x, screen.x - 6.0)
		pin.x = clampf(pin.x, safe.position.x, safe.end.x - sz.x)
		pin.y = clampf(pin.y, safe.position.y, maxf(safe.position.y, safe.end.y - sz.y))
		return pin
	var cands: Array[Vector2] = []
	if cmd == "flank" or cmd == "knife":
		## Thumb target above the operator, not parked on the sentry body.
		if op_screen != Vector2.INF:
			cands.append(op_screen + Vector2(-sz.x * 0.5, -sz.y - 28.0))
			cands.append(op_screen + Vector2(-sz.x * 0.5, -sz.y - 8.0))
			cands.append(op_screen + Vector2(22.0, -sz.y - 22.0))
			cands.append(op_screen + Vector2(-sz.x - 22.0, -sz.y - 22.0))
			cands.append(op_screen + Vector2(22.0, 8.0))
			cands.append(op_screen + Vector2(-sz.x - 22.0, 8.0))
		cands.append(screen + Vector2(-sz.x * 0.5 + x_off, -sz.y - 22.0))
	elif cmd == "crate":
		## Dump 07_west_crate: 开匣 sat left in the soap. Prefer above the
		## soldier / crate, then right, then left as last resort.
		if op_screen != Vector2.INF:
			cands.append(op_screen + Vector2(-sz.x * 0.5, -sz.y - 22.0))
			cands.append(op_screen + Vector2(10.0, -sz.y - 18.0))
		cands.append(screen + Vector2(-sz.x * 0.5 + x_off, -sz.y - 20.0))
		cands.append(screen + Vector2(16.0 + x_off, -sz.y - 10.0))
		cands.append(screen + Vector2(-sz.x * 0.5 + x_off, 10.0))
		cands.append(screen + Vector2(-sz.x - 16.0 + x_off, -sz.y - 8.0))
	else:
		cands.append(screen + Vector2(-sz.x * 0.5 + x_off, -sz.y - 12.0))
		cands.append(screen + Vector2(14.0 + x_off, -sz.y - 6.0))
		cands.append(screen + Vector2(-sz.x - 14.0 + x_off, -sz.y - 6.0))
		cands.append(screen + Vector2(-sz.x * 0.5 + x_off, 8.0))
	var best := cands[0]
	var best_hits := 999
	var best_above := Vector2.INF
	var best_above_hits := 999
	for raw in cands:
		var pos := raw
		pos.x = clampf(pos.x, safe.position.x, safe.end.x - sz.x)
		pos.y = clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - sz.y))
		var hr := Rect2(pos, sz)
		if op_screen != Vector2.INF and cmd != "flank" and cmd != "knife" and cmd != "crate":
			if hr.grow(8.0).has_point(op_screen):
				continue
		if cmd == "crate" and op_screen != Vector2.INF:
			if hr.grow(4.0).has_point(op_screen) and pos.y + sz.y > op_screen.y - 8.0:
				continue
		var hits := _count_hits(hr, blocked)
		var above := op_screen != Vector2.INF and (pos.y + sz.y) <= (op_screen.y - 4.0)
		if above and hits < best_above_hits:
			best_above_hits = hits
			best_above = pos
		if hits < best_hits:
			best_hits = hits
			best = pos
		if hits == 0 and (cmd != "crate" or above or best_above == Vector2.INF):
			if cmd == "crate" and above:
				return pos
			if cmd != "crate":
				return pos
	if cmd == "crate" and best_above != Vector2.INF:
		return best_above
	return best


func _apply(actions: Array) -> void:
	_shown = actions
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var xf: Transform2D = host.get_viewport().get_canvas_transform() if host else Transform2D.IDENTITY
	var safe := _map_safe(vis)
	var op_screen := Vector2.INF
	var op := _op()
	if op:
		op_screen = xf * op.global_position
	var n: int = mini(actions.size(), 2)
	for i in _btns.size():
		var b: Button = _btns[i]
		if i >= actions.size():
			b.visible = false
			continue
		var a: Dictionary = actions[i]
		var cmd := str(a["cmd"])
		var sz := _btn_sz(cmd)
		b.visible = true
		b.text = str(a["caption"])
		b.set_meta("cmd", cmd)
		b.set_meta("world", a["world"])
		_style(b, a["tint"])
		var place_world: Vector2 = a.get("anchor", a["world"])
		var screen: Vector2 = xf * place_world
		var blocked: Array = _operable_rects(xf, cmd, a["world"])
		var pos := _place_hotspot(cmd, screen, op_screen, safe, blocked, i, n)
		b.position = pos
		b.size = sz
		b.custom_minimum_size = sz


func _style(b: Button, tint: Color) -> void:
	var bg := Color(tint.r * 0.22, tint.g * 0.20, tint.b * 0.16, 0.96)
	var border := Color(tint.r, tint.g, tint.b, 0.92).lightened(0.12)
	b.add_theme_stylebox_override("normal", NightOps.flat(bg, border, 2, 10, 8))
	b.add_theme_stylebox_override("hover", NightOps.flat(bg.lightened(0.16), border.lightened(0.2), 2, 10, 8))
	b.add_theme_stylebox_override("pressed", NightOps.flat(bg.darkened(0.16), border, 2, 10, 8))
	b.add_theme_color_override("font_color", Color(0.96, 0.94, 0.82))


func _hide_all() -> void:
	_shown.clear()
	for b in _btns:
		if b:
			b.visible = false


func _fire(slot: int) -> void:
	if slot < 0 or slot >= _btns.size():
		return
	var b: Button = _btns[slot]
	if b == null or not b.visible:
		return
	var cmd := str(b.get_meta("cmd", ""))
	var world: Vector2 = b.get_meta("world", Vector2.ZERO)
	if host != null and host.has_method("apply_context_action"):
		host.apply_context_action(cmd, world)
	elif host != null and host.has_method("apply_touch_command"):
		host.apply_touch_command(cmd)


func _draw_rings() -> void:
	if _draw == null or host == null:
		return
	var xf: Transform2D = host.get_viewport().get_canvas_transform()
	var col := Color(0.86, 0.78, 0.38, 0.38)
	for w in _rings:
		var p: Vector2 = xf * w
		_draw.draw_arc(p, 16.0, 0.0, TAU, 22, col, 1.6, true)
		_draw.draw_arc(p, 7.0, 0.0, TAU, 14, Color(col.r, col.g, col.b, 0.22), 1.0, true)
	if _guide.size() >= 2:
		var gcol := Color(0.92, 0.46, 0.24, 0.90)
		for i in range(1, _guide.size()):
			var a: Vector2 = xf * _guide[i - 1]
			var b: Vector2 = xf * _guide[i]
			var v: Vector2 = b - a
			var len := v.length()
			if len < 2.0:
				continue
			var dir := v / len
			var pos := 0.0
			var on := true
			while pos < len:
				var span := 8.0 if on else 4.0
				var npos := minf(pos + span, len)
				if on:
					_draw.draw_line(a + dir * pos, a + dir * npos, gcol, 3.2, true)
				pos = npos
				on = not on
			_draw.draw_circle(a, 2.4, Color(0.94, 0.52, 0.22, 0.80))
		var tip: Vector2 = xf * _guide[_guide.size() - 1]
		_draw.draw_circle(tip, 5.5, Color(0.96, 0.40, 0.18, 0.95))
