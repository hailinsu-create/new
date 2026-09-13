class_name C2ContextPrompt
extends CanvasLayer

## Phone context hotspots. 1–2 fat verbs anchored on the world target,
## driven by the selected operator — not the last tap / mouse.

const Pathfinder := preload("res://scripts/raid/pathfinder.gd")

const PROBE_CRATE := 48.0
const PROBE_COVER := 22.0
const PROBE_KNIFE := 36.0
const PROBE_FLANK := 120.0
const PROBE_WHISTLE := 52.0
const HOLD_SEC := 1.2
const BTN_SIZE := Vector2(120, 48)
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
		b.add_theme_font_size_override("font_size", 16)
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


func _probe() -> Array:
	_guide = PackedVector2Array()
	_rings.clear()
	var op := _op()
	if op == null or not bool(op.alive) or not op.visible:
		return []
	var origin: Vector2 = op.global_position
	var moving := _moving(op)
	var cands: Array = []
	if host.get("raid_stashes") != null:
		var crate_r := 28.0 if moving else PROBE_CRATE
		for st in host.raid_stashes:
			if st == null or not is_instance_valid(st) or bool(st.collected):
				continue
			var d: float = origin.distance_to(st.global_position)
			if d <= crate_r:
				cands.append({"d": d, "pri": 1, "kind": "crate", "world": st.global_position, "node": st})
	if host.get("loot_piles") != null:
		var loot_r := 28.0 if moving else PROBE_CRATE
		for loot in host.loot_piles:
			if loot == null or not is_instance_valid(loot) or bool(loot.collected):
				continue
			var d2: float = origin.distance_to(loot.global_position)
			if d2 <= loot_r:
				cands.append({"d": d2, "pri": 1, "kind": "corpse", "world": loot.global_position, "node": loot})
	if not moving and host.has_method("_nearest_slot"):
		var slot = host._nearest_slot(origin, PROBE_COVER)
		if slot != null:
			cands.append({"d": origin.distance_to(slot.global_position), "pri": 6, "kind": "cover", "world": slot.global_position, "node": slot})
	var c2 = host.get("c2")
	if c2 != null and c2.get("sentries") != null:
		for s in c2.sentries:
			if s == null or not is_instance_valid(s):
				continue
			var d3: float = origin.distance_to(s.global_position)
			if bool(s.is_down()):
				if int(s.state) == 3 and d3 <= 40.0:
					cands.append({"d": d3, "pri": 2, "kind": "bind", "world": s.global_position, "node": s})
				continue
			var rear: bool = s.has_method("rear_hemisphere") and bool(s.rear_hemisphere(origin))
			var back: bool = s.has_method("in_backstab") and bool(s.in_backstab(origin))
			if back and d3 <= PROBE_KNIFE:
				cands.append({"d": d3, "pri": 0, "kind": "knife", "world": s.global_position, "node": s})
			elif rear and d3 <= PROBE_FLANK:
				cands.append({"d": d3, "pri": 3, "kind": "flank", "world": s.global_position, "node": s})
			elif (not rear) and d3 <= PROBE_WHISTLE and not moving:
				cands.append({"d": d3, "pri": 4, "kind": "whistle", "world": s.global_position, "node": s})
	if host.get("operators") != null:
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
		return [_act("knife", "割喉", top["world"], Color(0.72, 0.28, 0.20))]
	if kind == "flank":
		_guide = _flank_guide(op, top.get("node"))
		var dest: Vector2 = top["world"]
		if host != null and host.has_method("flank_dest_world") and top.get("node") != null:
			dest = host.flank_dest_world(top["node"], op)
		return [_act("flank", "绕背", dest, Color(0.78, 0.36, 0.22))]
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
	var cells: Array[Vector2i] = Pathfinder.find_path(host.grid, from_c, to_c)
	if cells.is_empty():
		out.append(op.global_position)
		out.append(dest)
		return out
	out.append(op.global_position)
	for c in cells:
		out.append(host.grid.cell_to_world_center(c))
	return out


func _act(cmd: String, caption: String, world: Vector2, tint: Color) -> Dictionary:
	return {"cmd": cmd, "caption": caption, "world": world, "tint": tint}


func _map_safe(vis: Vector2) -> Rect2:
	## Keep hotspots off the folded north chrome and the thumb bar.
	return Rect2(8.0, 56.0, vis.x - 16.0, vis.y - 56.0 - 140.0)


func _apply(actions: Array) -> void:
	_shown = actions
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var xf: Transform2D = host.get_viewport().get_canvas_transform() if host else Transform2D.IDENTITY
	var safe := _map_safe(vis)
	var op_screen := Vector2.INF
	var op := _op()
	if op:
		op_screen = xf * op.global_position
	for i in _btns.size():
		var b: Button = _btns[i]
		if i >= actions.size():
			b.visible = false
			continue
		var a: Dictionary = actions[i]
		b.visible = true
		b.text = str(a["caption"])
		b.set_meta("cmd", str(a["cmd"]))
		b.set_meta("world", a["world"])
		_style(b, a["tint"])
		var screen: Vector2 = xf * a["world"]
		var n: int = mini(actions.size(), 2)
		var x_off := (float(i) - (float(n) - 1.0) * 0.5) * (BTN_SIZE.x + 8.0)
		var pos := screen + Vector2(-BTN_SIZE.x * 0.5 + x_off, -BTN_SIZE.y - 22.0)
		if pos.y < safe.position.y:
			pos = screen + Vector2(18.0 + x_off, -BTN_SIZE.y * 0.5)
		if op_screen != Vector2.INF:
			var hr := Rect2(pos, BTN_SIZE)
			if hr.has_point(op_screen):
				pos.x = op_screen.x + 22.0
		pos.x = clampf(pos.x, safe.position.x, safe.end.x - BTN_SIZE.x)
		pos.y = clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - BTN_SIZE.y))
		b.position = pos
		b.size = BTN_SIZE


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
		var gcol := Color(0.86, 0.42, 0.28, 0.72)
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
				var span := 7.0 if on else 5.0
				var npos := minf(pos + span, len)
				if on:
					_draw.draw_line(a + dir * pos, a + dir * npos, gcol, 2.0, true)
				pos = npos
				on = not on
		var tip: Vector2 = xf * _guide[_guide.size() - 1]
		_draw.draw_circle(tip, 4.0, Color(0.90, 0.38, 0.22, 0.9))
