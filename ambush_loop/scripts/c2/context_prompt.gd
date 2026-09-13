class_name C2ContextPrompt
extends CanvasLayer

## Phone context hotspots. 1–2 fat verbs anchored on the world target,
## driven by the selected operator — not the last tap / mouse.

const PROBE := 58.0
const HOLD_SEC := 1.2
const BTN_SIZE := Vector2(128, 52)
var host: Node = null
var _root: Control = null
var _draw: Control = null
var _btns: Array = []
var _hold_t: float = 0.0
var _shown: Array = []
var _rings: Array = []


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


func has_caption(caption: String) -> bool:
	return visible_captions().has(caption)


func refresh_now() -> void:
	_hold_t = HOLD_SEC
	_apply(_probe())


func _process(delta: float) -> void:
	if host == null or not _phone() or not _command():
		_hide_all()
		_rings.clear()
		if _draw:
			_draw.queue_redraw()
		return
	var actions: Array = _probe()
	_rings = _probe_rings()
	if _draw:
		_draw.queue_redraw()
	if actions.is_empty():
		_hold_t = maxf(_hold_t - delta, 0.0)
		if _hold_t <= 0.0:
			_hide_all()
		return
	_hold_t = HOLD_SEC
	_apply(actions)


func _phone() -> bool:
	return host != null and host.has_method("_want_touch") and bool(host._want_touch())


func _command() -> bool:
	return host != null and host.has_method("_is_command_phase") and bool(host._is_command_phase())


func _op() -> Node:
	return host.selected if host else null


func _probe() -> Array:
	var op := _op()
	if op == null or not bool(op.alive) or not op.visible:
		return []
	var origin: Vector2 = op.global_position
	var cands: Array = []
	if host.get("raid_stashes") != null:
		for st in host.raid_stashes:
			if st == null or not is_instance_valid(st) or bool(st.collected):
				continue
			var d: float = origin.distance_to(st.global_position)
			if d <= PROBE:
				cands.append({"d": d, "kind": "crate", "world": st.global_position, "node": st})
	if host.get("loot_piles") != null:
		for loot in host.loot_piles:
			if loot == null or not is_instance_valid(loot) or bool(loot.collected):
				continue
			var d2: float = origin.distance_to(loot.global_position)
			if d2 <= PROBE:
				cands.append({"d": d2, "kind": "corpse", "world": loot.global_position, "node": loot})
	if host.has_method("_nearest_slot"):
		var slot = host._nearest_slot(origin, PROBE)
		if slot != null:
			cands.append({"d": origin.distance_to(slot.global_position), "kind": "cover", "world": slot.global_position, "node": slot})
	var c2 = host.get("c2")
	if c2 != null and c2.get("sentries") != null:
		for s in c2.sentries:
			if s == null or not is_instance_valid(s):
				continue
			var d3: float = origin.distance_to(s.global_position)
			if d3 > PROBE:
				continue
			if bool(s.is_down()):
				if int(s.state) == 3:
					cands.append({"d": d3, "kind": "bind", "world": s.global_position, "node": s})
			else:
				var back: bool = s.has_method("in_backstab") and bool(s.in_backstab(origin))
				cands.append({
					"d": d3,
					"kind": "knife" if back else "whistle",
					"world": s.global_position,
					"node": s
				})
	if host.get("operators") != null:
		for other in host.operators:
			if other == null or other == op or not bool(other.alive):
				continue
			if float(other.hp) >= 99.5:
				continue
			var d4: float = origin.distance_to(other.global_position)
			if d4 <= PROBE:
				cands.append({"d": d4, "kind": "aid", "world": other.global_position, "node": other})
	if cands.is_empty():
		return []
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	var top: Dictionary = cands[0]
	var kind := str(top["kind"])
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
	if kind == "whistle":
		return [_act("whistle", "口哨", top["world"], Color(0.82, 0.72, 0.28))]
	if kind == "bind":
		return [_act("bind", "捆绑", top["world"], Color(0.55, 0.48, 0.28))]
	if kind == "aid":
		return [_act("aid", "包扎", top["world"], Color(0.72, 0.32, 0.22))]
	return []


func _probe_rings() -> Array:
	var op := _op()
	if op == null:
		return []
	var origin: Vector2 = op.global_position
	var r := PROBE * 1.75
	var out: Array = []
	if host.get("raid_stashes") != null:
		for st in host.raid_stashes:
			if st != null and is_instance_valid(st) and not bool(st.collected) and origin.distance_to(st.global_position) <= r:
				out.append(st.global_position)
	if host.get("loot_piles") != null:
		for loot in host.loot_piles:
			if loot != null and is_instance_valid(loot) and not bool(loot.collected) and origin.distance_to(loot.global_position) <= r:
				out.append(loot.global_position)
	var c2 = host.get("c2")
	if c2 != null and c2.get("sentries") != null:
		for s in c2.sentries:
			if s != null and is_instance_valid(s) and origin.distance_to(s.global_position) <= r:
				out.append(s.global_position)
	if host.has_method("_nearest_slot"):
		var slot = host._nearest_slot(origin, r)
		if slot:
			out.append(slot.global_position)
	return out


func _act(cmd: String, caption: String, world: Vector2, tint: Color) -> Dictionary:
	return {"cmd": cmd, "caption": caption, "world": world, "tint": tint}


func _apply(actions: Array) -> void:
	_shown = actions
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var xf: Transform2D = host.get_viewport().get_canvas_transform() if host else Transform2D.IDENTITY
	var bar_top := vis.y - 140.0
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
		var pos := screen + Vector2(-BTN_SIZE.x * 0.5 + x_off, -BTN_SIZE.y - 28.0)
		pos.x = clampf(pos.x, 8.0, vis.x - BTN_SIZE.x - 8.0)
		if pos.y + BTN_SIZE.y > bar_top:
			pos.y = bar_top - BTN_SIZE.y - 6.0
		pos.y = clampf(pos.y, 48.0, bar_top - BTN_SIZE.y)
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
