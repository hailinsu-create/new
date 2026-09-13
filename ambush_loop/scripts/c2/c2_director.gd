class_name C2Director
extends Node2D

## Commandos 2 feel layer on top of RAID. Scout: sentries, stance, skills,
## portraits, minimap. Alert still freezes walking.

const Skills := preload("res://scripts/c2/c2_skills.gd")
const SentryScript := preload("res://scripts/c2/sentry.gd")
const DestFlagScript := preload("res://scripts/c2/dest_flag.gd")
const PortraitScript := preload("res://scripts/c2/portrait_strip.gd")
const SkillBarScript := preload("res://scripts/c2/skill_bar.gd")
const MinimapScript := preload("res://scripts/c2/minimap.gd")
const CursorScript := preload("res://scripts/c2/context_cursor.gd")
const ShadowScript := preload("res://scripts/c2/shadow_layer.gd")
const RingScript := preload("res://scripts/c2/sound_ring.gd")

var host: Node = null
var sentries: Array = []
var dest_flag: Node2D = null
var portraits: Control = null
var skill_bar: Control = null
var minimap: Control = null
var cursor: CanvasLayer = null
var shadows: Node2D = null
var help_chip: Label = null
var last_click_msec: int = 0
var last_click_world: Vector2 = Vector2.INF
var skill_cds: Dictionary = {} ## op_id -> {id: float}
var binoculars_t: float = 0.0
var quiet_yard: bool = false
var spotted_bark: bool = false
var cam_follow: bool = true
var _hud_root: Control = null


func bind(main: Node) -> void:
	host = main
	_ensure_world()
	_ensure_hud()


func _ensure_world() -> void:
	if dest_flag == null or not is_instance_valid(dest_flag):
		dest_flag = DestFlagScript.new()
		dest_flag.name = "C2DestFlag"
		var world: Node = host.get_node_or_null("World")
		if world:
			world.add_child(dest_flag)
		else:
			add_child(dest_flag)
	if shadows == null or not is_instance_valid(shadows):
		shadows = ShadowScript.new()
		shadows.name = "C2Shadows"
		shadows.z_index = -2
		var world2: Node = host.get_node_or_null("World")
		if world2:
			world2.add_child(shadows)
		else:
			add_child(shadows)


func _ensure_hud() -> void:
	_hud_root = host.get_node_or_null("HUD/Root") as Control
	if _hud_root == null:
		return
	if portraits == null or not is_instance_valid(portraits):
		portraits = PortraitScript.new()
		portraits.name = "C2Portraits"
		portraits.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		portraits.anchor_left = 0.5
		portraits.anchor_right = 0.5
		portraits.offset_left = -168.0
		portraits.offset_right = 168.0
		portraits.offset_top = -268.0
		portraits.offset_bottom = -156.0
		_hud_root.add_child(portraits)
		portraits.picked.connect(func(idx: int) -> void:
			if host.has_method("_select_op"):
				host._select_op(idx)
		)
	if skill_bar == null or not is_instance_valid(skill_bar):
		skill_bar = SkillBarScript.new()
		skill_bar.name = "C2Skills"
		skill_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		skill_bar.anchor_left = 1.0
		skill_bar.anchor_right = 1.0
		skill_bar.offset_left = -300.0
		skill_bar.offset_right = -16.0
		skill_bar.offset_top = -228.0
		skill_bar.offset_bottom = -160.0
		_hud_root.add_child(skill_bar)
		skill_bar.skill_pressed.connect(func(id: String) -> void:
			use_skill(id)
		)
	if minimap == null or not is_instance_valid(minimap):
		minimap = MinimapScript.new()
		minimap.name = "C2Minimap"
		minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		minimap.anchor_left = 1.0
		minimap.anchor_right = 1.0
		minimap.offset_left = -196.0
		minimap.offset_right = -12.0
		minimap.offset_top = 44.0
		minimap.offset_bottom = 148.0
		_hud_root.add_child(minimap)
		minimap.bind(host)
		minimap.pan_requested.connect(func(world: Vector2) -> void:
			_pan_to(world)
		)
	if cursor == null or not is_instance_valid(cursor):
		cursor = CursorScript.new()
		cursor.name = "C2Cursor"
		host.add_child(cursor)
	if help_chip == null or not is_instance_valid(help_chip):
		help_chip = Label.new()
		help_chip.name = "C2Help"
		help_chip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		help_chip.offset_left = 220.0
		help_chip.offset_right = -320.0
		help_chip.offset_top = -148.0
		help_chip.offset_bottom = -128.0
		help_chip.add_theme_font_size_override("font_size", 12)
		help_chip.add_theme_color_override("font_color", Color(0.86, 0.78, 0.42))
		help_chip.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
		help_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(help_chip)


func begin_scout() -> void:
	spotted_bark = false
	quiet_yard = false
	binoculars_t = 0.0
	skill_cds.clear()
	_clear_sentries()
	if shadows and host.get("level") != null:
		shadows.setup(host.grid, str(host.level.level_id))
	_spawn_sentries()
	refresh_hud()
	_hint("点选队员 · 点地走 · C匍匐 · Q技能 · 岗哨有黄锥")


func begin_alert() -> void:
	quiet_yard = _all_sentries_down()
	_clear_sentries()
	if dest_flag:
		dest_flag.clear()
	if cursor:
		cursor.set_mode(CursorScript.Mode.NONE)
	refresh_hud()


func begin_sweep() -> void:
	_clear_sentries()
	refresh_hud()
	_hint("打扫：搜尸 / 包扎 / 换枪。岗哨已随警报撤走。")


func _all_sentries_down() -> bool:
	if sentries.is_empty():
		return false
	for s in sentries:
		if s != null and is_instance_valid(s) and not bool(s.is_down()):
			return false
	return true


func _clear_sentries() -> void:
	for s in sentries:
		if s != null and is_instance_valid(s):
			s.queue_free()
	sentries.clear()


func _spawn_sentries() -> void:
	if host == null or host.get("level") == null or host.get("grid") == null:
		return
	var cells: Array = []
	if host.level.route_cells.has("main"):
		cells = host.level.route_cells["main"]
	if cells.size() < 4:
		return
	var slice: PackedVector2Array = PackedVector2Array()
	var n := mini(5, cells.size() - 2)
	for i in range(1, n + 1):
		slice.append(host.grid.cell_to_world_center(cells[i]))
	if slice.size() < 2:
		return
	var world: Node = host.get_node_or_null("World/Entities")
	if world == null:
		world = host.get_node_or_null("World")
	var s = SentryScript.new()
	s.name = "C2Sentry"
	if world:
		world.add_child(s)
	else:
		add_child(s)
	s.setup(1, slice, host.grid)
	s.spotted.connect(_on_sentry_spotted)
	sentries.append(s)
	if str(host.level.level_id) in ["depot", "radio", "railcut"] and host.level.route_cells.has("flank"):
		var fc: Array = host.level.route_cells["flank"]
		if fc.size() >= 4:
			var sl2 := PackedVector2Array()
			for i in range(1, mini(4, fc.size())):
				sl2.append(host.grid.cell_to_world_center(fc[i]))
			var s2 = SentryScript.new()
			s2.name = "C2Sentry2"
			if world:
				world.add_child(s2)
			else:
				add_child(s2)
			s2.setup(2, sl2, host.grid)
			s2.spotted.connect(_on_sentry_spotted)
			sentries.append(s2)


func _on_sentry_spotted(_s: Node, op: Node) -> void:
	if spotted_bark:
		return
	spotted_bark = true
	_hint("岗哨看见了 — 蹲进阴影或绕背后割喉。拉警报仍由你决定。")
	if host.has_method("_sfx"):
		host._sfx("echo_ping")
	if op != null and host.has_method("_operator_bark"):
		host._operator_bark(op, "spotted")


func tick(delta: float) -> void:
	_tick_cds(delta)
	binoculars_t = maxf(binoculars_t - delta, 0.0)
	if host != null and host.has_method("_is_command_phase") and bool(host._is_command_phase()):
		_tick_hidden()
		_tick_sentries(delta)
		_tick_cursor()
		_tick_edge_pan(delta)
		_tick_arrows(delta)
	refresh_hud_light()


func _tick_cds(delta: float) -> void:
	for oid in skill_cds.keys():
		var rec: Dictionary = skill_cds[oid]
		for k in rec.keys():
			rec[k] = maxf(float(rec[k]) - delta, 0.0)
		skill_cds[oid] = rec


func _tick_hidden() -> void:
	if host == null:
		return
	for op in host.operators:
		if op == null:
			continue
		var hid := false
		if shadows and op.has_method("grid_cell"):
			var cell: Vector2i = op.grid_cell()
			var crouch := op.get("stance") != null and int(op.stance) == 1
			if crouch and bool(shadows.hides_at(cell)):
				hid = true
		if op.get("hidden_in_shadow") != null:
			op.hidden_in_shadow = hid
		if op.body:
			op.modulate = Color(0.72, 0.78, 0.62) if hid else Color.WHITE


func _tick_sentries(delta: float) -> void:
	var hidden_at := func(op: Node) -> bool:
		return op != null and op.get("hidden_in_shadow") != null and bool(op.hidden_in_shadow)
	for s in sentries:
		if s == null or not is_instance_valid(s):
			continue
		s.tick(delta, host.operators, hidden_at)
		for op in host.operators:
			if op == null or not op.visible or not bool(op.alive):
				continue
			if op.has_method("noise_level"):
				var n := float(op.noise_level())
				if n > 0.05:
					s.hear_at(op.global_position, n)


func _tick_cursor() -> void:
	if cursor == null or host == null:
		return
	if not bool(host._is_command_phase()):
		cursor.set_mode(CursorScript.Mode.NONE)
		return
	var world: Vector2 = host.get_global_mouse_position() if host.has_method("get_global_mouse_position") else Vector2.ZERO
	var mode := CursorScript.Mode.WALK
	for op in host.operators:
		if op.visible and op.alive and op.global_position.distance_to(world) <= 22.0:
			mode = CursorScript.Mode.OP
			break
	if mode == CursorScript.Mode.WALK:
		for st in host.raid_stashes:
			if st != null and is_instance_valid(st) and not bool(st.collected) and st.global_position.distance_to(world) <= 22.0:
				mode = CursorScript.Mode.CRATE
				break
	if mode == CursorScript.Mode.WALK:
		for loot in host.loot_piles:
			if loot != null and is_instance_valid(loot) and not bool(loot.collected) and loot.global_position.distance_to(world) <= 22.0:
				mode = CursorScript.Mode.CORPSE
				break
	if mode == CursorScript.Mode.WALK and host.has_method("_nearest_slot"):
		var slot = host._nearest_slot(world, 26.0)
		if slot:
			mode = CursorScript.Mode.COVER
	if mode == CursorScript.Mode.WALK:
		for s in sentries:
			if s != null and is_instance_valid(s) and not bool(s.is_down()) and s.global_position.distance_to(world) <= 26.0:
				mode = CursorScript.Mode.KNIFE
				break
	cursor.set_mode(mode)


func _tick_edge_pan(delta: float) -> void:
	if host == null:
		return
	var mp := host.get_viewport().get_mouse_position()
	var sz := host.get_viewport().get_visible_rect().size
	var v := Vector2.ZERO
	var m := 18.0
	if mp.x < m:
		v.x -= 1.0
	elif mp.x > sz.x - m:
		v.x += 1.0
	if mp.y < m:
		v.y -= 1.0
	elif mp.y > sz.y - m:
		v.y += 1.0
	if v == Vector2.ZERO:
		return
	host._cam_pan += v * 220.0 * delta / maxf(float(host._cam_zoom), 0.01)
	if host.has_method("_apply_cam"):
		host._apply_cam()


func _tick_arrows(delta: float) -> void:
	if host == null:
		return
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v == Vector2.ZERO:
		return
	host._cam_pan += v * 260.0 * delta / maxf(float(host._cam_zoom), 0.01)
	if host.has_method("_apply_cam"):
		host._apply_cam()


func _pan_to(world: Vector2) -> void:
	if host == null:
		return
	var center := Vector2(640, 360)
	host._cam_pan = (world - center) * 0.42
	if host.has_method("_apply_cam"):
		host._apply_cam()


func handle_key(code: int) -> bool:
	if host == null or not bool(host._is_command_phase()):
		return false
	match code:
		KEY_C:
			use_skill("crouch")
			return true
		KEY_Q:
			_use_role_slot("Q")
			return true
		KEY_W:
			_use_role_slot("W")
			return true
		KEY_Z:
			_use_role_slot("Z")
			return true
		KEY_K:
			use_skill("knife")
			return true
		KEY_F1:
			cam_follow = not cam_follow
			_hint("镜头跟随 %s" % ("开" if cam_follow else "关"))
			return true
	return false


func _use_role_slot(hot: String) -> void:
	var op = host.selected
	if op == null:
		return
	for id in Skills.for_role(int(op.role)):
		if Skills.hotkey(id) == hot:
			use_skill(id)
			return


func handle_click(world: Vector2) -> Dictionary:
	var now := Time.get_ticks_msec()
	var sprint := false
	if last_click_world != Vector2.INF and now - last_click_msec <= 280 and world.distance_to(last_click_world) <= 22.0:
		sprint = true
	last_click_msec = now
	last_click_world = world
	for s in sentries:
		if s == null or not is_instance_valid(s):
			continue
		if s.global_position.distance_to(world) <= 22.0:
			if s.is_down():
				use_skill("bind")
				return {"handled": true, "sprint": false}
			use_skill("knife")
			return {"handled": true, "sprint": false}
	return {"handled": false, "sprint": sprint}


func plant_dest(world: Vector2, op: Node) -> void:
	if dest_flag:
		dest_flag.plant(world, op)


func use_skill(id: String) -> void:
	if host == null or host.selected == null:
		return
	if not bool(host._is_command_phase()) and id != "crouch":
		return
	var op = host.selected
	var oid := int(op.op_id)
	if not skill_cds.has(oid):
		skill_cds[oid] = {}
	var rec: Dictionary = skill_cds[oid]
	if float(rec.get(id, 0.0)) > 0.05:
		_hint("%s 冷却中" % Skills.label_zh(id))
		return
	var ok := false
	match id:
		"crouch":
			ok = _skill_crouch(op)
		"knife":
			ok = _skill_knife(op)
		"whistle":
			ok = _skill_whistle(op)
		"binoculars":
			ok = _skill_binoculars(op)
		"aid":
			ok = _skill_aid(op)
		"bind":
			ok = _skill_bind(op)
		"decoy":
			ok = _skill_decoy(op)
		"mine":
			ok = _skill_mine(op)
	if ok:
		rec[id] = Skills.cooldown(id)
		skill_cds[oid] = rec
		if host.has_method("_sfx"):
			host._sfx("ui")
	refresh_hud()


func _skill_crouch(op: Node) -> bool:
	if not op.has_method("toggle_crouch"):
		if op.get("stance") != null:
			op.stance = 0 if int(op.stance) == 1 else 1
			if op.has_method("apply_stance_speed"):
				op.apply_stance_speed()
		return true
	op.toggle_crouch()
	_hint("匍匐" if int(op.stance) == 1 else "站立")
	return true


func _skill_knife(op: Node) -> bool:
	var best = null
	var best_d := 32.0
	for s in sentries:
		if s == null or not is_instance_valid(s) or bool(s.is_down()):
			continue
		var d: float = op.global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	if best == null:
		_hint("贴近岗哨背后才能割喉")
		return false
	var back := bool(best.in_backstab(op.global_position))
	var crouch := op.get("stance") != null and int(op.stance) == 1
	if not back and not crouch:
		best.hear_at(op.global_position, 0.9)
		_hint("正面惊动了岗哨")
		return true
	best.knock_out()
	_spawn_ring(best.global_position, 36.0, Color(0.72, 0.22, 0.18, 0.4))
	_hint("割喉 — 拖开或捆上")
	if host.has_method("_sfx"):
		host._sfx("knife")
	return true


func _skill_whistle(op: Node) -> bool:
	var pos: Vector2 = op.global_position + Vector2(cos(deg_to_rad(op.facing_deg)), sin(deg_to_rad(op.facing_deg))) * 48.0
	for s in sentries:
		if s != null and is_instance_valid(s) and not bool(s.is_down()):
			s.hear_at(pos, 0.95)
	_spawn_ring(op.global_position, 90.0, Color(0.82, 0.78, 0.32, 0.45))
	_hint("口哨 — 岗哨转头")
	if host.has_method("_sfx"):
		host._sfx("whistle")
	return true


func _skill_binoculars(op: Node) -> bool:
	binoculars_t = 5.5
	for s in sentries:
		if s != null and is_instance_valid(s) and s.cone:
			s.cone.visible = true
			var c: Color = s.cone.color
			c.a = minf(c.a + 0.12, 0.42)
			s.cone.color = c
	_hint("%s 举起望远镜" % op.display_name)
	return true


func _skill_aid(op: Node) -> bool:
	if float(op.hp) >= OperatorUnit.MAX_HP - 0.5:
		_hint("没有外伤")
		return false
	op.hp = minf(float(op.hp) + 18.0, OperatorUnit.MAX_HP)
	if op.has_method("_update_hp_bar"):
		op._update_hp_bar()
	_hint("包扎 +18")
	return true


func _skill_bind(op: Node) -> bool:
	var best = null
	var best_d := 34.0
	for s in sentries:
		if s == null or not is_instance_valid(s):
			continue
		if int(s.state) != 3:
			continue
		var d: float = op.global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	if best == null:
		_hint("走近击倒的岗哨再捆")
		return false
	best.bind_gag()
	_hint("捆好了")
	return true


func _skill_decoy(op: Node) -> bool:
	if host.has_method("_throw_decoy_at"):
		var pos: Vector2 = op.global_position + Vector2(cos(deg_to_rad(op.facing_deg)), sin(deg_to_rad(op.facing_deg))) * 72.0
		host._throw_decoy_at(pos)
		return true
	return false


func _skill_mine(op: Node) -> bool:
	if host.has_method("_try_place_inventory_mine"):
		host._try_place_inventory_mine(op.global_position)
		return true
	return false


func _spawn_ring(world: Vector2, r: float, col: Color) -> void:
	var ring = RingScript.new()
	var worldn: Node = host.get_node_or_null("World")
	if worldn:
		worldn.add_child(ring)
	else:
		add_child(ring)
	ring.boom(world, r, col)


func _hint(text: String) -> void:
	if help_chip:
		help_chip.text = text
	if host != null and host.get("status_label") != null:
		host.status_label.text = text


func refresh_hud() -> void:
	refresh_hud_light()
	if skill_bar and host:
		var cds: Dictionary = {}
		if host.selected:
			cds = skill_cds.get(int(host.selected.op_id), {})
		skill_bar.bind(host.selected, cds, bool(host._is_command_phase()) if host.has_method("_is_command_phase") else true)
	if minimap:
		minimap.bind(host)
		minimap.visible = true
	if portraits:
		portraits.visible = true
	if skill_bar:
		skill_bar.visible = host != null and host.has_method("_is_command_phase") and bool(host._is_command_phase())


func refresh_hud_light() -> void:
	if portraits and host:
		portraits.bind_ops(host.operators, host.selected, bool(host._is_command_phase()) if host.has_method("_is_command_phase") else true)


func sentry_count() -> int:
	var n := 0
	for s in sentries:
		if s != null and is_instance_valid(s):
			n += 1
	return n


func downed_sentry_count() -> int:
	var n := 0
	for s in sentries:
		if s != null and is_instance_valid(s) and bool(s.is_down()):
			n += 1
	return n
