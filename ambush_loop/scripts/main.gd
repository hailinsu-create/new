extends Node2D

## Ambush Loop — Commandos-style prep MVP.
## Deploy to cover, set overwatch, limited ammo, enemies return fire, loot corpses.
## Enemies follow FIXED routes.

enum Phase { SETUP, WATCHING, FAILED, WON }
enum Tool { DEPLOY, TRIPWIRE }

const MAX_TRIPWIRES := 1

var grid: AmbushGrid = AmbushGrid.new()
var phase: Phase = Phase.SETUP
var tool: Tool = Tool.DEPLOY
var loop_index: int = 1
var intel_paths: Array[PackedVector2Array] = []
var fail_reason: String = ""

var cover_slots: Array[CoverSlot] = []
var operators: Array[OperatorUnit] = []
var selected: OperatorUnit = null
var enemies: Array[EnemyRunner] = []
var tripwires: Array[Tripwire] = []
var loot_piles: Array[LootPickup] = []

var escape_world: Vector2
var hud_tick: float = 0.0

@onready var map_draw: Node2D = $World/MapDraw
@onready var entities: Node2D = $World/Entities
@onready var ghosts: Node2D = $World/Ghosts
@onready var covers: Node2D = $World/Covers
@onready var routes_draw: Node2D = $World/RoutesDraw
@onready var escape_marker: Node2D = $World/EscapeMarker
@onready var title_label: Label = $HUD/Root/TopBar/Title
@onready var status_label: Label = $HUD/Root/TopBar/Status
@onready var intel_label: Label = $HUD/Root/TopBar/Intel
@onready var help_label: Label = $HUD/Root/Help
@onready var alarm_button: Button = $HUD/Root/BottomBar/AlarmButton
@onready var clear_button: Button = $HUD/Root/BottomBar/ClearButton
@onready var tool_button: Button = $HUD/Root/BottomBar/ToolButton
@onready var result_panel: PanelContainer = $HUD/Root/ResultPanel
@onready var result_label: Label = $HUD/Root/ResultPanel/Margin/VBox/ResultLabel
@onready var continue_button: Button = $HUD/Root/ResultPanel/Margin/VBox/ContinueButton


func _ready() -> void:
	escape_world = grid.cell_to_world_center(Vector2i(31, 19))
	escape_marker.position = escape_world
	map_draw.set("grid", grid)
	map_draw.queue_redraw()
	_build_cover_slots()
	_build_operators()
	_draw_fixed_routes()
	alarm_button.pressed.connect(_on_alarm_pressed)
	clear_button.pressed.connect(_reset_deployments)
	tool_button.pressed.connect(_toggle_tool)
	continue_button.pressed.connect(_on_continue_pressed)
	result_panel.visible = false
	clear_button.text = "收回队员"
	tool_button.text = "工具: 部署队员"
	_start_setup(false)


func _cover_defs() -> Array:
	# cell, label, default facing deg
	return [
		{"cell": Vector2i(7, 11), "name": "西侧掩体", "face": 0.0},
		{"cell": Vector2i(15, 7), "name": "北廊掩体", "face": 90.0},
		{"cell": Vector2i(24, 8), "name": "东箱掩体", "face": 180.0},
		{"cell": Vector2i(25, 13), "name": "中庭掩体", "face": 90.0},
		{"cell": Vector2i(12, 15), "name": "南廊掩体", "face": 0.0},
		{"cell": Vector2i(28, 16), "name": "出口掩体", "face": 180.0},
	]


func _route_main() -> PackedVector2Array:
	var cells := [
		Vector2i(13, 3), Vector2i(13, 5), Vector2i(13, 7), Vector2i(13, 11),
		Vector2i(13, 15), Vector2i(17, 17), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
	]
	return _cells_to_world(cells)


func _route_flank() -> PackedVector2Array:
	var cells := [
		Vector2i(13, 3), Vector2i(13, 5), Vector2i(16, 6), Vector2i(23, 6),
		Vector2i(32, 6), Vector2i(32, 11), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
	]
	return _cells_to_world(cells)


func _cells_to_world(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in cells:
		out.append(grid.cell_to_world_center(c))
	return out


func _build_cover_slots() -> void:
	for c in covers.get_children():
		c.queue_free()
	cover_slots.clear()
	var id := 0
	for d in _cover_defs():
		var slot := _make_slot(id, d["name"], grid.cell_to_world_center(d["cell"]))
		slot.set_meta("default_face", d["face"])
		covers.add_child(slot)
		cover_slots.append(slot)
		id += 1


func _make_slot(id: int, text: String, pos: Vector2) -> CoverSlot:
	var s := CoverSlot.new()
	s.position = pos
	var pad := Polygon2D.new()
	pad.name = "Pad"
	pad.polygon = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14), Vector2(14, 14), Vector2(-14, 14)
	])
	pad.color = Color(0.25, 0.45, 0.35, 0.35)
	s.add_child(pad)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = text
	tag.position = Vector2(-40, 16)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.65, 0.85, 0.7))
	s.add_child(tag)
	s.slot_id = id
	s.label_text = text
	return s


func _build_operators() -> void:
	for o in operators:
		if is_instance_valid(o):
			o.queue_free()
	operators.clear()
	var defs := [
		{"id": 1, "name": "机枪手"},
		{"id": 2, "name": "步枪手"},
		{"id": 3, "name": "侦察兵"},
	]
	for d in defs:
		var op := _make_operator(d["id"], d["name"])
		entities.add_child(op)
		op.setup(d["id"], d["name"])
		op.died.connect(_on_operator_died)
		op.visible = false
		operators.append(op)
	selected = operators[0]
	_refresh_selection_visual()


func _make_operator(id: int, pname: String) -> OperatorUnit:
	var op := OperatorUnit.new()
	op.op_id = id
	op.display_name = pname
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -11), Vector2(8, 9), Vector2(-8, 9)
	])
	body.color = Color(0.35, 0.65, 0.95)
	op.add_child(body)
	var cone := Polygon2D.new()
	cone.name = "Cone"
	op.add_child(cone)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = pname
	tag.position = Vector2(-28, -30)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	op.add_child(tag)
	return op


func _draw_fixed_routes() -> void:
	for c in routes_draw.get_children():
		c.queue_free()
	_add_route_line(_route_main(), Color(0.9, 0.4, 0.35, 0.35), "主路线")
	_add_route_line(_route_flank(), Color(0.95, 0.55, 0.2, 0.3), "侧翼路线")


func _add_route_line(points: PackedVector2Array, color: Color, label: String) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.points = points
	routes_draw.add_child(line)
	if points.size() > 1:
		var t := Label.new()
		t.text = label
		t.position = points[2] + Vector2(8, -18)
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", color)
		routes_draw.add_child(t)


func _start_setup(keep_intel: bool) -> void:
	phase = Phase.SETUP
	tool = Tool.DEPLOY
	fail_reason = ""
	_clear_enemies()
	_clear_tripwires()
	_clear_loot()
	_reset_deployments()
	if not keep_intel:
		intel_paths.clear()
		loop_index = 1
	_redraw_ghosts()
	alarm_button.disabled = false
	clear_button.disabled = false
	tool_button.disabled = false
	result_panel.visible = false
	_update_hud()


func _reset_deployments() -> void:
	for slot in cover_slots:
		slot.occupied_by = null
		slot.set_highlight(false)
	for op in operators:
		op.reset_loadout()
		op.slot = null
		op.visible = false
		op.position = Vector2(-1000, -1000)
	selected = operators[0]
	_refresh_selection_visual()
	_update_hud()


func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()


func _clear_tripwires() -> void:
	for t in tripwires:
		if is_instance_valid(t):
			t.queue_free()
	tripwires.clear()


func _clear_loot() -> void:
	for l in loot_piles:
		if is_instance_valid(l):
			l.queue_free()
	loot_piles.clear()
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n):
			n.queue_free()


func _toggle_tool() -> void:
	if phase != Phase.SETUP:
		return
	tool = Tool.TRIPWIRE if tool == Tool.DEPLOY else Tool.DEPLOY
	tool_button.text = "工具: 部署队员" if tool == Tool.DEPLOY else "工具: 拌索(后勤)"
	status_label.text = "部署到掩体位，A/D 调整射界" if tool == Tool.DEPLOY else "在固定路线上放拌索（最多1）"
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_run"):
		loop_index = 1
		_start_setup(false)
		get_viewport().set_input_as_handled()
		return

	if phase == Phase.SETUP:
		if event.is_action_pressed("sound_alarm"):
			_on_alarm_pressed()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_1:
					_select_op(0)
				KEY_2:
					_select_op(1)
				KEY_3:
					_select_op(2)
				KEY_A, KEY_Q:
					if selected and selected.visible:
						selected.rotate_by(-15.0)
				KEY_D, KEY_E:
					if selected and selected.visible:
						selected.rotate_by(15.0)
				KEY_TAB:
					_toggle_tool()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_setup_click(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if selected and selected.visible and not selected.locked:
				# Face toward cursor
				var v := get_global_mouse_position() - selected.global_position
				selected.set_facing(rad_to_deg(atan2(v.y, v.x)))
			get_viewport().set_input_as_handled()
			return


func _select_op(idx: int) -> void:
	if idx < 0 or idx >= operators.size():
		return
	selected = operators[idx]
	tool = Tool.DEPLOY
	tool_button.text = "工具: 部署队员"
	_refresh_selection_visual()
	status_label.text = "已选择 %s — 点击掩体位部署，右键朝向光标" % selected.display_name
	_update_hud()


func _refresh_selection_visual() -> void:
	for op in operators:
		if op.body:
			op.body.color = Color(0.95, 0.85, 0.35) if op == selected and op.visible else Color(0.35, 0.65, 0.95)


func _handle_setup_click(world_pos: Vector2) -> void:
	if tool == Tool.TRIPWIRE:
		_try_place_tripwire(world_pos)
		return
	# Prefer clicking a cover slot
	var slot := _nearest_slot(world_pos, 28.0)
	if slot:
		_deploy_selected_to(slot)
		return
	# Click existing operator to select
	for op in operators:
		if op.visible and op.global_position.distance_to(world_pos) <= 20.0:
			selected = op
			_refresh_selection_visual()
			status_label.text = "已选择 %s" % op.display_name
			_update_hud()
			return


func _nearest_slot(world_pos: Vector2, max_dist: float) -> CoverSlot:
	var best: CoverSlot = null
	var best_d := max_dist
	for s in cover_slots:
		var d := s.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = s
	return best


func _deploy_selected_to(slot: CoverSlot) -> void:
	if selected == null:
		return
	# Free previous
	if selected.slot:
		selected.slot.occupied_by = null
		selected.slot.set_highlight(false)
	if slot.occupied_by and slot.occupied_by != selected:
		# Swap: send occupant back to roster
		var other: OperatorUnit = slot.occupied_by
		other.slot = null
		other.visible = false
		other.position = Vector2(-1000, -1000)
	slot.occupied_by = selected
	slot.set_highlight(true)
	selected.slot = slot
	selected.visible = true
	selected.global_position = slot.global_position
	selected.reset_loadout()
	selected.set_facing(float(slot.get_meta("default_face")))
	_refresh_selection_visual()
	status_label.text = "%s 已进入「%s」— 弹药 %d | A/D 或右键调整射界" % [selected.display_name, slot.label_text, selected.ammo]
	_update_hud()


func _try_place_tripwire(world_pos: Vector2) -> void:
	if tripwires.size() >= MAX_TRIPWIRES:
		status_label.text = "拌索已用完（后勤限额 1）"
		return
	# Must be near a fixed route
	if not _near_any_route(world_pos, 28.0):
		status_label.text = "拌索只能布在已知路线附近"
		return
	var tw := _make_tripwire(world_pos)
	entities.add_child(tw)
	tripwires.append(tw)
	status_label.text = "拌索已埋伏"
	_update_hud()


func _near_any_route(pos: Vector2, max_dist: float) -> bool:
	for route in [_route_main(), _route_flank()]:
		for p in route:
			if pos.distance_to(p) <= max_dist:
				return true
	return false


func _make_tripwire(pos: Vector2) -> Tripwire:
	var t := Tripwire.new()
	t.position = pos
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-10, -3), Vector2(10, -3), Vector2(10, 3), Vector2(-10, 3)
	])
	visual.color = Color(0.85, 0.8, 0.35)
	t.add_child(visual)
	return t


func _deployed_count() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.slot != null:
			n += 1
	return n


func _on_alarm_pressed() -> void:
	if phase != Phase.SETUP:
		return
	if _deployed_count() < 1:
		status_label.text = "至少部署一名队员到掩体"
		return
	phase = Phase.WATCHING
	alarm_button.disabled = true
	clear_button.disabled = true
	tool_button.disabled = true
	for op in operators:
		if op.visible:
			op.lock_plan()
	_spawn_enemies()
	status_label.text = "方案锁死 — 敌军会还击，注意弹药。跑掉或全灭均失败。"
	_update_hud()


func _spawn_enemies() -> void:
	_clear_enemies()
	_clear_loot()
	var specs := [
		{"id": 1, "route": _route_main(), "delay": 0.0},
		{"id": 2, "route": _route_main(), "delay": 0.8},
		{"id": 3, "route": _route_flank(), "delay": 0.4},
	]
	for spec in specs:
		var e := _make_enemy(spec["id"], spec["route"])
		entities.add_child(e)
		e.setup(spec["id"], spec["route"])
		enemies.append(e)
		_activate_later(e, float(spec["delay"]))


func _activate_later(enemy: EnemyRunner, delay: float) -> void:
	if delay <= 0.0:
		enemy.activate()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(enemy) and phase == Phase.WATCHING:
			enemy.activate()
	)


func _make_enemy(id: int, route: PackedVector2Array) -> EnemyRunner:
	var e := EnemyRunner.new()
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(0, -10), Vector2(9, 8), Vector2(-9, 8)])
	body.color = Color(0.75, 0.22, 0.2)
	e.add_child(body)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "敌%d" % id
	tag.position = Vector2(-12, -34)
	tag.add_theme_font_size_override("font_size", 12)
	e.add_child(tag)
	var hp := Polygon2D.new()
	hp.name = "HpBar"
	e.add_child(hp)
	e.escaped.connect(_on_enemy_escaped)
	e.died.connect(_on_enemy_died)
	return e


func _spawn_loot_at(pos: Vector2, amount: int) -> void:
	var loot := LootPickup.new()
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)
	])
	visual.color = Color(0.95, 0.85, 0.25)
	loot.add_child(visual)
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-14, -22)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	loot.add_child(tag)
	entities.add_child(loot)
	loot.global_position = pos
	loot.setup(amount)
	loot_piles.append(loot)


func _process(delta: float) -> void:
	if phase != Phase.WATCHING:
		return

	# Each operator fires at the nearest valid target in cone (ammo limited)
	for op in operators:
		if not op.visible or not op.locked or not op.alive:
			continue
		var best: EnemyRunner = null
		var best_d := INF
		for enemy in enemies:
			if not enemy.alive or not enemy.active:
				continue
			if op.can_engage(enemy.global_position, grid):
				var d := op.global_position.distance_to(enemy.global_position)
				if d < best_d:
					best_d = d
					best = enemy
		if best:
			op.try_fire(delta, best, grid)

	# Auto-scavenge nearby corpse ammo (watch-only logistics)
	for loot in loot_piles.duplicate():
		if not is_instance_valid(loot) or loot.collected:
			continue
		for op in operators:
			if op.visible and op.alive and op.try_loot(loot):
				status_label.text = "%s 搜刮尸体 +弹药" % op.display_name
				break
	# Prune freed loot refs
	loot_piles = loot_piles.filter(func(l: LootPickup) -> bool: return is_instance_valid(l) and not l.collected)

	hud_tick += delta
	if hud_tick >= 0.35:
		hud_tick = 0.0
		_update_hud()


func _on_enemy_escaped(_enemy: EnemyRunner, path: PackedVector2Array) -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "escape"
	phase = Phase.FAILED
	for e in enemies:
		e.active = false
	intel_paths.append(path)
	_redraw_ghosts()
	result_panel.visible = true
	result_label.text = "有人活着走出封锁区。\n第 %d 世失败。\n漏网路线已写入记忆。\n弹药会在穿梭后补满，情报留下。" % loop_index
	continue_button.text = "带着情报穿梭回去"
	status_label.text = "逃逸 — 穿梭"
	_update_hud()


func _on_enemy_died(enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING:
		return
	_spawn_loot_at(enemy.global_position, enemy.loot_ammo)
	_check_win()


func _on_operator_died(op: OperatorUnit) -> void:
	if phase != Phase.WATCHING:
		return
	status_label.text = "%s 阵亡 — 敌军在还击" % op.display_name
	if _living_ops() == 0:
		_fail_squad_wipe()


func _living_ops() -> int:
	var n := 0
	for op in operators:
		if op.visible and op.alive:
			n += 1
	return n


func _fail_squad_wipe() -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "wipe"
	phase = Phase.FAILED
	for e in enemies:
		e.active = false
	result_panel.visible = true
	result_label.text = "小队覆灭。\n第 %d 世失败。\n敌军还击撕开了埋伏。\n穿梭回去：少暴露射界，或先集火再搜刮弹药。" % loop_index
	continue_button.text = "带着情报穿梭回去"
	status_label.text = "全灭 — 穿梭"
	_update_hud()


func _check_win() -> void:
	for e in enemies:
		if e.alive:
			return
	if _living_ops() == 0:
		_fail_squad_wipe()
		return
	phase = Phase.WON
	result_panel.visible = true
	result_label.text = "零逃逸。\n埋伏成立。\n用了 %d 世；弹药与还击都算进计划里。" % loop_index
	continue_button.text = "再玩一局（清空记忆）"
	status_label.text = "计划奏效"
	_update_hud()


func _on_continue_pressed() -> void:
	if phase == Phase.FAILED:
		loop_index += 1
		_start_setup(true)
	elif phase == Phase.WON:
		_start_setup(false)


func _redraw_ghosts() -> void:
	for c in ghosts.get_children():
		c.queue_free()
	var gi := 0
	for path in intel_paths:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.35, 0.75, 1.0, 0.5 - minf(0.15, float(gi) * 0.04))
		line.points = path
		ghosts.add_child(line)
		gi += 1


func _ammo_summary() -> String:
	var parts: PackedStringArray = []
	for op in operators:
		if op.visible:
			if not op.alive:
				parts.append("%s:亡" % op.display_name)
			else:
				parts.append("%s:%d弹" % [op.display_name.substr(0, 2), op.ammo])
	return "  ".join(parts)


func _update_hud() -> void:
	title_label.text = "AMBUSH LOOP  ·  第 %d 世" % loop_index
	intel_label.text = "漏网记忆：%d   |   %s" % [intel_paths.size(), _ammo_summary()]
	var dep := _deployed_count()
	if phase == Phase.SETUP:
		help_label.text = "准备：点掩体部署（%d/3）| 1/2/3选人 | A/D转射界 | 右键朝向\n每人出发仅 %d 发；被打会还击；尸体可搜弹药。空格拉警报。跑掉/全灭=穿梭。R重置。" % [dep, OperatorUnit.START_AMMO]
	elif phase == Phase.WATCHING:
		help_label.text = "锁死看戏：耗弹、还击、搜尸自动发生。射界外漏人、或小队打光都会失败。"
	elif phase == Phase.FAILED:
		help_label.text = "根据幽灵路线改掩体/朝向；别让一人扛整波还击。"
	elif phase == Phase.WON:
		help_label.text = "战前准备 + 弹药节奏决定战斗。"
