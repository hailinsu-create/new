extends Node2D

## Ambush Loop — vertical slice coordinator (blueprint §3–§6).
## SETUP → Alarm freezes PlanState → WATCHING (SimClock) → FAIL/WIN + BattleLog.

enum Phase { SETUP, WATCHING, FAILED, WON, REPLAY }
enum Tool { DEPLOY, TRIPWIRE }

const MAX_TRIPWIRES := 1
const TRIPWIRE_ROUTE_DIST := 24.0
const SNAPSHOT_EVERY := 6
const PROGRESS_PATH := "user://ambush_loop.cfg"
const LEVEL_ORDER := ["yard", "warehouse", "pump"]

var grid: AmbushGrid = AmbushGrid.new()
var phase: Phase = Phase.SETUP
var tool: Tool = Tool.DEPLOY
var loop_index: int = 1
var run_id: int = 0
var intel_paths: Array[PackedVector2Array] = []
var fail_reason: String = ""

var level: LevelDef = null
var level_index: int = 0
var sim: SimClock = SimClock.new()
var battle_log: BattleLog = BattleLog.new()
var last_plan: PlanState = PlanState.new()
var door_locked: bool = false

var cover_slots: Array[CoverSlot] = []
var operators: Array[OperatorUnit] = []
var selected: OperatorUnit = null
var enemies: Array[EnemyRunner] = []
var tripwires: Array[Tripwire] = []
var loot_piles: Array[LootPickup] = []

var pending_spawns: Array = [] # {id, route, delay, loot, spawned}
var route_world: Dictionary = {} # name -> PackedVector2Array
var escape_world: Vector2
var return_fire_fx: Array = []
var hud_tick: float = 0.0
var ambush_zone_poly: Polygon2D = null
var door_marker: Node2D = null
var all_spawns_done: bool = false

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

var speed_button: Button = null
var pause_button: Button = null
var mode_button: Button = null
var door_button: Button = null
var pack_button: Button = null
var event_log: Control = null
var level_label: Label = null
var tut_label: Label = null


func _ready() -> void:
	_resolve_optional_hud()
	alarm_button.pressed.connect(_on_alarm_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	tool_button.pressed.connect(_toggle_tool)
	continue_button.pressed.connect(_on_continue_pressed)
	result_panel.visible = false
	clear_button.text = "收回部署"
	tool_button.text = "工具: 部署队员"
	_load_progress()
	_load_level(LEVEL_ORDER[level_index], false, false)


func _resolve_optional_hud() -> void:
	var root: Control = $HUD/Root
	var bar: HBoxContainer = $HUD/Root/BottomBar
	speed_button = get_node_or_null("HUD/Root/BottomBar/SpeedButton") as Button
	pause_button = get_node_or_null("HUD/Root/BottomBar/PauseButton") as Button
	mode_button = get_node_or_null("HUD/Root/BottomBar/ModeButton") as Button
	door_button = get_node_or_null("HUD/Root/BottomBar/DoorButton") as Button
	pack_button = get_node_or_null("HUD/Root/BottomBar/PackButton") as Button
	event_log = get_node_or_null("HUD/Root/EventLog") as Control
	level_label = get_node_or_null("HUD/Root/TopBar/LevelLabel") as Label
	tut_label = get_node_or_null("HUD/Root/TutLabel") as Label

	var extra := HBoxContainer.new()
	extra.name = "ExtraBar"
	extra.alignment = BoxContainer.ALIGNMENT_CENTER
	extra.add_theme_constant_override("separation", 8)
	extra.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	extra.offset_left = -400.0
	extra.offset_right = 400.0
	extra.offset_top = -92.0
	extra.offset_bottom = -56.0
	root.add_child(extra)

	if speed_button == null:
		speed_button = _make_hud_btn("SpeedButton", "速度 1×", bar)
	if pause_button == null:
		pause_button = _make_hud_btn("PauseButton", "暂停", bar)
	if mode_button == null:
		mode_button = _make_hud_btn("ModeButton", "开火: 见敌即打 (F)", extra)
	if pack_button == null:
		pack_button = _make_hud_btn("PackButton", "弹包 (G)", extra)
	if door_button == null:
		door_button = _make_hud_btn("DoorButton", "门: 畅通 (B)", extra)

	speed_button.pressed.connect(_on_speed_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	mode_button.pressed.connect(_on_mode_pressed)
	pack_button.pressed.connect(_on_pack_pressed)
	door_button.pressed.connect(_on_door_pressed)

	if event_log == null:
		var rtl := RichTextLabel.new()
		rtl.name = "EventLog"
		rtl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		rtl.offset_left = -320.0
		rtl.offset_top = 120.0
		rtl.offset_right = -16.0
		rtl.offset_bottom = 320.0
		rtl.bbcode_enabled = true
		rtl.fit_content = false
		rtl.scroll_active = true
		rtl.add_theme_font_size_override("normal_font_size", 12)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rtl)
		event_log = rtl

	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		$HUD/Root/TopBar.add_child(level_label)
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))

	if tut_label == null:
		tut_label = Label.new()
		tut_label.name = "TutLabel"
		tut_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tut_label.offset_left = 16.0
		tut_label.offset_top = 118.0
		tut_label.offset_right = 520.0
		tut_label.offset_bottom = 170.0
		tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_label.add_theme_font_size_override("font_size", 13)
		tut_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.65))
		tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tut_label)


func _make_hud_btn(p_name: String, text: String, parent: Control) -> Button:
	var b := Button.new()
	b.name = p_name
	b.text = text
	b.custom_minimum_size = Vector2(120, 32)
	parent.add_child(b)
	return b


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		level_index = 0
		return
	var id := str(cfg.get_value("progress", "level_id", "yard"))
	level_index = LEVEL_ORDER.find(id)
	if level_index < 0:
		level_index = 0


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	cfg.set_value("progress", "level_id", level.level_id if level else "yard")
	cfg.set_value("progress", "level_index", level_index)
	cfg.set_value("progress", "loop_index", loop_index)
	cfg.save(PROGRESS_PATH)


func _load_level(level_id: String, keep_intel: bool, restore_plan: bool) -> void:
	level = LevelDef.by_id(level_id)
	var idx := LEVEL_ORDER.find(level.level_id)
	if idx >= 0:
		level_index = idx
	escape_world = grid.cell_to_world_center(level.escape_cell)
	escape_marker.position = escape_world
	map_draw.set("grid", grid)
	map_draw.queue_redraw()
	_build_route_world()
	_build_cover_slots()
	_build_operators()
	_draw_fixed_routes()
	_build_ambush_zone_visual()
	_build_door_marker()
	_start_setup(keep_intel, restore_plan)


func _build_route_world() -> void:
	route_world.clear()
	for key in level.route_cells.keys():
		route_world[key] = _cells_to_world(level.route_cells[key])


func _cells_to_world(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in cells:
		out.append(grid.cell_to_world_center(c as Vector2i))
	return out


func _all_routes() -> Array:
	var out: Array = []
	for key in route_world.keys():
		out.append(route_world[key])
	if door_locked and not level.alternate_route_cells.is_empty():
		out.append(_cells_to_world(level.alternate_route_cells))
	return out


func _build_cover_slots() -> void:
	for c in covers.get_children():
		c.queue_free()
	cover_slots.clear()
	var id := 0
	for d in level.cover_defs:
		var cell: Vector2i = d["cell"]
		var slot := _make_slot(id, str(d["name"]), grid.cell_to_world_center(cell))
		var face := float(d.get("face", 0.0))
		var protect := float(d.get("protect", face))
		slot.set_meta("default_face", face)
		slot.protect_facing_deg = protect
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
	s.setup(id, text, 0.0)
	return s


func _build_operators() -> void:
	for o in operators:
		if is_instance_valid(o):
			o.queue_free()
	operators.clear()
	var defs := [
		{"id": 1, "name": "队员甲"},
		{"id": 2, "name": "队员乙"},
		{"id": 3, "name": "队员丙"},
	]
	for d in defs:
		var op := _make_operator(int(d["id"]), str(d["name"]))
		entities.add_child(op)
		op.setup(int(d["id"]), str(d["name"]))
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
	var colors := {
		"main": Color(0.9, 0.4, 0.35, 0.35),
		"flank": Color(0.95, 0.55, 0.2, 0.3),
	}
	var labels := {"main": "主路线", "flank": "侧翼路线"}
	for key in route_world.keys():
		var col: Color = colors.get(key, Color(0.7, 0.7, 0.4, 0.3))
		_add_route_line(route_world[key], col, str(labels.get(key, key)))
	if not level.alternate_route_cells.is_empty():
		_add_route_line(
			_cells_to_world(level.alternate_route_cells),
			Color(0.55, 0.4, 0.85, 0.28),
			"备用接近"
		)


func _add_route_line(points: PackedVector2Array, color: Color, label: String) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.points = points
	routes_draw.add_child(line)
	if points.size() > 1:
		var t := Label.new()
		t.text = label
		var idx := mini(2, points.size() - 1)
		t.position = points[idx] + Vector2(8, -18)
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", color)
		routes_draw.add_child(t)


func _build_ambush_zone_visual() -> void:
	if ambush_zone_poly != null and is_instance_valid(ambush_zone_poly):
		ambush_zone_poly.queue_free()
	ambush_zone_poly = null
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var poly := Polygon2D.new()
	poly.name = "AmbushZone"
	var r := level.ambush_zone
	poly.polygon = PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
	poly.color = Color(0.95, 0.85, 0.2, 0.12)
	routes_draw.add_child(poly)
	ambush_zone_poly = poly
	var tag := Label.new()
	tag.text = "伏击区"
	tag.position = r.position + Vector2(8, 4)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 0.7))
	routes_draw.add_child(tag)


func _build_door_marker() -> void:
	if door_marker != null and is_instance_valid(door_marker):
		door_marker.queue_free()
	door_marker = null
	if level.door_cell.x < 0:
		return
	var n := Node2D.new()
	n.name = "DoorMarker"
	n.position = grid.cell_to_world_center(level.door_cell)
	var pad := Polygon2D.new()
	pad.polygon = PackedVector2Array([
		Vector2(-10, -14), Vector2(10, -14), Vector2(10, 14), Vector2(-10, 14)
	])
	pad.color = Color(0.55, 0.4, 0.25, 0.7)
	n.add_child(pad)
	var tag := Label.new()
	tag.text = "门"
	tag.position = Vector2(-10, -28)
	tag.add_theme_font_size_override("font_size", 12)
	n.add_child(tag)
	routes_draw.add_child(n)
	door_marker = n
	_refresh_door_visual()


func _refresh_door_visual() -> void:
	if door_marker == null or not is_instance_valid(door_marker):
		return
	var pad := door_marker.get_node_or_null("Polygon2D") as Polygon2D
	if pad == null and door_marker.get_child_count() > 0:
		pad = door_marker.get_child(0) as Polygon2D
	if pad:
		pad.color = Color(0.85, 0.25, 0.2, 0.85) if door_locked else Color(0.55, 0.4, 0.25, 0.7)
	if door_button:
		door_button.text = "门: 锁闭 (B)" if door_locked else "门: 畅通 (B)"
		door_button.visible = level != null and level.door_cell.x >= 0


func _start_setup(keep_intel: bool, restore_plan: bool) -> void:
	phase = Phase.SETUP
	tool = Tool.DEPLOY
	fail_reason = ""
	run_id += 1
	sim.reset()
	battle_log.clear()
	pending_spawns.clear()
	all_spawns_done = false
	_clear_enemies()
	_clear_tripwires()
	_clear_loot()
	_clear_return_fx()
	if not keep_intel:
		intel_paths.clear()
		loop_index = 1
		last_plan.clear()
		door_locked = false
	if restore_plan and not last_plan.deployments.is_empty():
		_restore_last_plan()
	else:
		_clear_deployments()
		door_locked = last_plan.door_locked if restore_plan else false
	_redraw_ghosts()
	_refresh_door_visual()
	alarm_button.disabled = false
	clear_button.disabled = false
	tool_button.disabled = false
	if mode_button:
		mode_button.disabled = false
	if pack_button:
		pack_button.disabled = false
		pack_button.visible = level != null and level.has_ammo_pack
	if door_button:
		door_button.disabled = false
		door_button.visible = level != null and level.door_cell.x >= 0
	if pause_button:
		pause_button.disabled = true
		pause_button.text = "暂停"
	if speed_button:
		speed_button.disabled = true
		speed_button.text = "速度 1×"
	result_panel.visible = false
	_update_event_log()
	_update_hud()


func _on_clear_pressed() -> void:
	if phase != Phase.SETUP:
		return
	_clear_deployments()
	status_label.text = "已收回部署（记忆与绊索保留）"
	_update_hud()


func _clear_deployments() -> void:
	for slot in cover_slots:
		slot.occupied_by = null
		slot.set_highlight(false)
	for op in operators:
		op.has_ammo_pack = false
		op.fire_mode = OperatorUnit.FireMode.ENGAGE_ON_SIGHT
		op.reset_loadout()
		op.slot = null
		op.visible = false
		op.position = Vector2(-1000, -1000)
	selected = operators[0] if operators.size() > 0 else null
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()


func _capture_plan() -> void:
	last_plan.clear()
	for op in operators:
		if op.visible and op.slot != null:
			last_plan.deployments.append({
				"op_id": op.op_id,
				"slot_id": op.slot.slot_id,
				"facing": op.facing_deg,
				"fire_mode": op.fire_mode,
				"has_ammo_pack": op.has_ammo_pack,
			})
	last_plan.tripwire_positions.clear()
	for t in tripwires:
		if is_instance_valid(t):
			last_plan.tripwire_positions.append(t.position)
	last_plan.door_locked = door_locked


func _restore_last_plan() -> void:
	_clear_deployments()
	_clear_tripwires()
	door_locked = last_plan.door_locked
	for entry in last_plan.deployments:
		var op := _op_by_id(int(entry["op_id"]))
		var slot := _slot_by_id(int(entry["slot_id"]))
		if op == null or slot == null:
			continue
		selected = op
		_deploy_selected_to(slot, false)
		op.fire_mode = int(entry.get("fire_mode", OperatorUnit.FireMode.ENGAGE_ON_SIGHT))
		op.has_ammo_pack = bool(entry.get("has_ammo_pack", false))
		op.reset_loadout()
		op.set_facing(float(entry["facing"]))
	for pos in last_plan.tripwire_positions:
		var tw := _make_tripwire(pos)
		entities.add_child(tw)
		tripwires.append(tw)
	if operators.size() > 0:
		selected = operators[0]
		_refresh_selection_visual()
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
	status_label.text = "已恢复上轮计划（满血满弹）"


func _op_by_id(id: int) -> OperatorUnit:
	for op in operators:
		if op.op_id == id:
			return op
	return null


func _slot_by_id(id: int) -> CoverSlot:
	for s in cover_slots:
		if s.slot_id == id:
			return s
	return null


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


func _clear_return_fx() -> void:
	for fx in return_fire_fx:
		if is_instance_valid(fx):
			fx.queue_free()
	return_fire_fx.clear()


func _toggle_tool() -> void:
	if phase != Phase.SETUP:
		return
	tool = Tool.TRIPWIRE if tool == Tool.DEPLOY else Tool.DEPLOY
	tool_button.text = "工具: 部署队员" if tool == Tool.DEPLOY else "工具: 绊索(后勤)"
	status_label.text = "部署到掩体位，A/D 调整射界" if tool == Tool.DEPLOY else "在路线线段附近放绊索（最多1）"
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_run"):
		loop_index = 1
		intel_paths.clear()
		last_plan.clear()
		_start_setup(false, false)
		get_viewport().set_input_as_handled()
		return

	if phase == Phase.WATCHING:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_P, KEY_SPACE:
					_on_pause_pressed()
				KEY_EQUAL, KEY_KP_ADD:
					sim.set_speed(2.0)
					if speed_button:
						speed_button.text = "速度 2×"
				KEY_MINUS, KEY_KP_SUBTRACT:
					sim.set_speed(1.0)
					if speed_button:
						speed_button.text = "速度 1×"
			get_viewport().set_input_as_handled()
		return

	if phase != Phase.SETUP:
		return

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
			KEY_F:
				_on_mode_pressed()
			KEY_G:
				_on_pack_pressed()
			KEY_B:
				_on_door_pressed()
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
	_refresh_mode_pack_buttons()
	status_label.text = "已选择 %s（能力相同）— 点掩体部署，右键朝向" % selected.display_name
	_update_hud()


func _refresh_selection_visual() -> void:
	for op in operators:
		if op.body:
			op.body.color = Color(0.95, 0.85, 0.35) if op == selected and op.visible else Color(0.35, 0.65, 0.95)


func _refresh_mode_pack_buttons() -> void:
	if mode_button and selected:
		mode_button.text = "开火: %s (F)" % selected.fire_mode_label()
	if pack_button:
		pack_button.visible = level != null and level.has_ammo_pack
		if selected and selected.has_ammo_pack:
			pack_button.text = "弹包: %s (G)" % selected.display_name
		else:
			pack_button.text = "弹包分配 (G)"


func _handle_setup_click(world_pos: Vector2) -> void:
	if tool == Tool.TRIPWIRE:
		_try_place_tripwire(world_pos)
		return
	var slot := _nearest_slot(world_pos, 28.0)
	if slot:
		_deploy_selected_to(slot, true)
		return
	for op in operators:
		if op.visible and op.global_position.distance_to(world_pos) <= 20.0:
			selected = op
			_refresh_selection_visual()
			_refresh_mode_pack_buttons()
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


func _deploy_selected_to(slot: CoverSlot, announce: bool = true) -> void:
	if selected == null:
		return
	if selected.slot:
		selected.slot.occupied_by = null
		selected.slot.set_highlight(false)
	if slot.occupied_by and slot.occupied_by != selected:
		var other: OperatorUnit = slot.occupied_by
		other.slot = null
		other.visible = false
		other.position = Vector2(-1000, -1000)
	slot.occupied_by = selected
	slot.set_highlight(true)
	selected.slot = slot
	selected.visible = true
	selected.global_position = slot.global_position
	var face := float(slot.get_meta("default_face"))
	selected.reset_loadout()
	selected.set_facing(face)
	_refresh_selection_visual()
	_refresh_mode_pack_buttons()
	if announce:
		status_label.text = "%s →「%s」弹%d 掩体减伤60%%" % [selected.display_name, slot.label_text, selected.ammo]
	_update_hud()


func _try_place_tripwire(world_pos: Vector2) -> void:
	if tripwires.size() >= MAX_TRIPWIRES:
		status_label.text = "绊索已用完（后勤限额 1）"
		return
	if not _near_any_route_segment(world_pos, TRIPWIRE_ROUTE_DIST):
		status_label.text = "绊索只能布在路线线段附近"
		return
	var tw := _make_tripwire(world_pos)
	entities.add_child(tw)
	tripwires.append(tw)
	status_label.text = "绊索已埋伏"
	_update_hud()


func _near_any_route_segment(pos: Vector2, max_dist: float) -> bool:
	for route in _all_routes():
		if _dist_to_polyline(pos, route) <= max_dist:
			return true
	return false


func _dist_to_polyline(pos: Vector2, points: PackedVector2Array) -> float:
	if points.is_empty():
		return INF
	if points.size() == 1:
		return pos.distance_to(points[0])
	var best := INF
	for i in range(points.size() - 1):
		best = minf(best, _dist_point_to_segment(pos, points[i], points[i + 1]))
	return best


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


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


func _on_mode_pressed() -> void:
	if phase != Phase.SETUP or selected == null or not selected.visible:
		return
	selected.cycle_fire_mode()
	_refresh_mode_pack_buttons()
	status_label.text = "%s 开火模式：%s" % [selected.display_name, selected.fire_mode_label()]
	_update_hud()


func _on_pack_pressed() -> void:
	if phase != Phase.SETUP or level == null or not level.has_ammo_pack:
		return
	if selected == null or not selected.visible:
		status_label.text = "先部署并选中一名队员再分配弹包"
		return
	if selected.has_ammo_pack:
		selected.has_ammo_pack = false
		selected.reset_loadout()
		status_label.text = "%s 卸下备用弹包" % selected.display_name
	else:
		for op in operators:
			op.has_ammo_pack = false
			if op.visible:
				op.reset_loadout()
				op.set_facing(op.facing_deg)
		selected.has_ammo_pack = true
		selected.reset_loadout()
		selected.set_facing(selected.facing_deg)
		status_label.text = "%s 携带备用弹包（空弹自动补一次）" % selected.display_name
	_refresh_mode_pack_buttons()
	_update_hud()


func _on_door_pressed() -> void:
	if phase != Phase.SETUP or level == null or level.door_cell.x < 0:
		return
	door_locked = not door_locked
	_refresh_door_visual()
	status_label.text = "门已锁闭 — 侧翼改走备用接近" if door_locked else "门保持畅通"
	_update_hud()


func _on_speed_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.set_speed(1.0 if sim.speed >= 1.5 else 2.0)
	if speed_button:
		speed_button.text = "速度 2×" if sim.speed >= 1.5 else "速度 1×"


func _on_pause_pressed() -> void:
	if phase != Phase.WATCHING:
		return
	sim.toggle_pause()
	if pause_button:
		pause_button.text = "继续" if sim.paused else "暂停"


func _on_alarm_pressed() -> void:
	if phase != Phase.SETUP:
		return
	if _deployed_count() < 1:
		status_label.text = "至少部署一名队员到掩体"
		return
	_capture_plan()
	run_id += 1
	var this_run := run_id
	phase = Phase.WATCHING
	sim.reset()
	battle_log.clear()
	alarm_button.disabled = true
	clear_button.disabled = true
	tool_button.disabled = true
	if mode_button:
		mode_button.disabled = true
	if pack_button:
		pack_button.disabled = true
	if door_button:
		door_button.disabled = true
	if pause_button:
		pause_button.disabled = false
	if speed_button:
		speed_button.disabled = false
	for op in operators:
		if op.visible:
			op.lock_plan()
	battle_log.add_event(0, "door", -1, -1, Vector2.ZERO, {"locked": door_locked})
	_queue_spawns(this_run)
	status_label.text = "方案锁死 — 暂停/变速仅改变观看。跑掉或全灭均失败。"
	_update_event_log()
	_update_hud()


func _queue_spawns(_this_run: int) -> void:
	_clear_enemies()
	_clear_loot()
	pending_spawns.clear()
	all_spawns_done = false
	for spec in level.spawn_schedule:
		pending_spawns.append({
			"id": int(spec["id"]),
			"route": str(spec["route"]),
			"delay": float(spec["delay"]),
			"loot": int(spec["loot"]),
			"spawned": false,
		})


func _route_for_spawn(route_name: String) -> PackedVector2Array:
	if door_locked and route_name == level.door_blocks_route and not level.alternate_route_cells.is_empty():
		return _cells_to_world(level.alternate_route_cells)
	if route_world.has(route_name):
		return route_world[route_name]
	# fallback first route
	for key in route_world.keys():
		return route_world[key]
	return PackedVector2Array()


func _spawn_one(spec: Dictionary) -> void:
	var e := _make_enemy(int(spec["id"]))
	entities.add_child(e)
	var route := _route_for_spawn(str(spec["route"]))
	e.setup(int(spec["id"]), route, grid, int(spec["loot"]))
	e.return_fired.connect(_on_return_fired)
	enemies.append(e)
	e.activate()
	battle_log.add_event(sim.tick, "spawn", e.label_id, -1, e.global_position)
	_update_event_log()


func _make_enemy(id: int) -> EnemyRunner:
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
	if amount <= 0:
		return
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


func _on_return_fired(from: EnemyRunner, to: OperatorUnit) -> void:
	battle_log.add_event(sim.tick, "return_fire", from.label_id, to.op_id, from.global_position)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.55, 0.15, 0.85)
	line.points = PackedVector2Array([from.global_position, to.global_position])
	entities.add_child(line)
	return_fire_fx.append(line)
	# Tween owned by the line so level reloads don't leave dangling captures.
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)


func _process(delta: float) -> void:
	if phase != Phase.WATCHING:
		return
	var steps := sim.steps_for_frame(delta)
	for _i in steps:
		if phase != Phase.WATCHING:
			break
		_sim_tick()
	hud_tick += delta
	if hud_tick >= 0.35:
		hud_tick = 0.0
		_update_hud()


func _sim_tick() -> void:
	var this_run := run_id
	# 1) Spawn schedule by sim time
	var tsec := sim.time_sec()
	all_spawns_done = true
	for spec in pending_spawns:
		if spec["spawned"]:
			continue
		if tsec + 0.0001 >= float(spec["delay"]):
			if run_id != this_run or phase != Phase.WATCHING:
				return
			spec["spawned"] = true
			_spawn_one(spec)
		else:
			all_spawns_done = false

	# 2) Cooldowns
	for op in operators:
		if op.visible and op.alive:
			op.tick_cooldown(SimClock.TICK_DT)

	# 3) Ambush zone arming
	_tick_ambush_zone()

	# 4) Operator fire — nearest legal, stable ID on tie
	for op in operators:
		if not op.visible or not op.locked or not op.alive:
			continue
		var best: EnemyRunner = null
		var best_d := INF
		for enemy in enemies:
			if not enemy.alive or not enemy.active:
				continue
			if not op.can_engage(enemy.global_position, grid):
				continue
			var d := op.global_position.distance_to(enemy.global_position)
			if d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and best != null and enemy.label_id < best.label_id):
				best_d = d
				best = enemy
			elif best == null:
				best_d = d
				best = enemy
		if best:
			if op.try_fire(best, grid):
				battle_log.add_event(sim.tick, "fire", op.op_id, best.label_id, op.global_position)
				if op.ammo <= 0:
					battle_log.add_event(sim.tick, "empty", op.op_id)

	# 5) Enemy move + return fire
	for enemy in enemies:
		if enemy.alive and enemy.active:
			enemy.sim_step(SimClock.TICK_DT)
		if phase != Phase.WATCHING:
			sim.advance()
			return

	# 6) Loot: nearest + LOS + stable op_id
	for loot in loot_piles.duplicate():
		if not is_instance_valid(loot) or loot.collected:
			continue
		_try_assign_loot(loot)
	loot_piles = loot_piles.filter(func(l: LootPickup) -> bool: return is_instance_valid(l) and not l.collected)

	# 7) Snapshots
	if sim.tick % SNAPSHOT_EVERY == 0:
		battle_log.add_snapshot(sim.tick, _snapshot_data())

	sim.advance()
	if phase == Phase.WATCHING:
		_check_win()


func _tick_ambush_zone() -> void:
	if level.ambush_zone.size == Vector2.ZERO:
		return
	var any_in := false
	for enemy in enemies:
		if enemy.alive and enemy.active and level.ambush_zone.has_point(enemy.global_position):
			any_in = true
			break
	if not any_in:
		return
	for op in operators:
		if not op.visible or not op.alive:
			continue
		if op.fire_mode == OperatorUnit.FireMode.HOLD_FOR_AMBUSH and not op.fire_permitted:
			op.arm_ambush()
			battle_log.add_event(sim.tick, "ambush_armed", op.op_id)


func _snapshot_data() -> Dictionary:
	var ops := []
	for op in operators:
		if op.visible:
			ops.append({"id": op.op_id, "hp": op.hp, "ammo": op.ammo, "alive": op.alive, "pos": op.global_position})
	var ens := []
	for e in enemies:
		ens.append({"id": e.label_id, "hp": e.hp, "alive": e.alive, "pos": e.global_position})
	return {"ops": ops, "enemies": ens}


func _try_assign_loot(loot: LootPickup) -> void:
	var candidates: Array[OperatorUnit] = []
	for op in operators:
		if op.visible and op.can_reach_loot(loot.global_position, grid):
			candidates.append(op)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: OperatorUnit, b: OperatorUnit) -> bool:
		var da := a.global_position.distance_to(loot.global_position)
		var db := b.global_position.distance_to(loot.global_position)
		if absf(da - db) > 0.01:
			return da < db
		return a.op_id < b.op_id
	)
	for op in candidates:
		var amount := loot.ammo_amount
		var gained := op.receive_ammo(amount)
		if gained > 0:
			loot.collect()
			battle_log.add_event(sim.tick, "loot", op.op_id, -1, loot.global_position, {"amount": gained})
			status_label.text = "%s 搜刮 +%d弹" % [op.display_name, gained]
			_update_event_log()
			return


func _on_enemy_escaped(enemy: EnemyRunner, path: PackedVector2Array) -> void:
	if phase != Phase.WATCHING:
		return
	fail_reason = "escape"
	phase = Phase.FAILED
	battle_log.add_event(sim.tick, "escape", enemy.label_id, -1, enemy.global_position)
	battle_log.mark_terminal(sim.tick, "escape")
	for e in enemies:
		e.active = false
	intel_paths.append(path)
	_redraw_ghosts()
	_show_fail_result()


func _on_enemy_died(enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING:
		return
	battle_log.add_event(sim.tick, "kill", enemy.label_id)
	_spawn_loot_at(enemy.global_position, enemy.loot_ammo)
	_update_event_log()
	_check_win()


func _on_operator_died(op: OperatorUnit) -> void:
	if phase != Phase.WATCHING:
		return
	battle_log.add_event(sim.tick, "op_down", op.op_id)
	status_label.text = "%s 阵亡 — 敌军还击（需 LOS）" % op.display_name
	_update_event_log()
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
	battle_log.mark_terminal(sim.tick, "wipe")
	for e in enemies:
		e.active = false
		if e.recorded.size() > 1:
			intel_paths.append(e.recorded.duplicate())
	_redraw_ghosts()
	_show_fail_result()


func _show_fail_result() -> void:
	result_panel.visible = true
	var lines := battle_log.summary_lines(10)
	var summary := "\n".join(lines)
	var reason_zh := "逃逸" if fail_reason == "escape" else "全灭"
	result_label.text = "第 %d 世失败（%s）。\n穿梭后恢复上轮计划，满血满弹。\n\n—— 事件摘要 ——\n%s" % [loop_index, reason_zh, summary]
	continue_button.text = "带着情报穿梭回去"
	status_label.text = "%s — 穿梭" % reason_zh
	_update_event_log()
	_update_hud()


func _check_win() -> void:
	if phase != Phase.WATCHING:
		return
	if not all_spawns_done:
		return
	for e in enemies:
		if e.alive:
			return
	if _living_ops() == 0:
		_fail_squad_wipe()
		return
	phase = Phase.WON
	battle_log.mark_terminal(sim.tick, "win")
	result_panel.visible = true
	var lines := battle_log.summary_lines(8)
	var has_next := level_index + 1 < LEVEL_ORDER.size()
	if has_next:
		result_label.text = "零逃逸。埋伏成立。\n用了 %d 世。\n\n%s\n\n—— 事件 ——\n%s" % [
			loop_index, level.teaching, "\n".join(lines)
		]
		continue_button.text = "下一关"
	else:
		result_label.text = "全部关卡封锁完成。\n总世数记忆保留于存档。\n\n%s" % "\n".join(lines)
		continue_button.text = "再玩一局（清空记忆）"
	status_label.text = "计划奏效"
	_save_progress()
	_update_event_log()
	_update_hud()


func _on_continue_pressed() -> void:
	if phase == Phase.FAILED:
		loop_index += 1
		_start_setup(true, true)
	elif phase == Phase.WON:
		if level_index + 1 < LEVEL_ORDER.size():
			level_index += 1
			_save_progress()
			_load_level(LEVEL_ORDER[level_index], false, false)
		else:
			level_index = 0
			_save_progress()
			_load_level(LEVEL_ORDER[0], false, false)
	elif phase == Phase.REPLAY:
		_start_setup(true, true)


func _redraw_ghosts() -> void:
	for c in ghosts.get_children():
		c.queue_free()
	var gi := 0
	var start_i := maxi(intel_paths.size() - 3, 0)
	for i in range(start_i, intel_paths.size()):
		var path: PackedVector2Array = intel_paths[i]
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.35, 0.75, 1.0, 0.55 - minf(0.15, float(gi) * 0.05))
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
				parts.append("%s:%d弹%s" % [op.display_name, op.ammo, ("·" + op.fire_mode_label()) if phase == Phase.SETUP else ""])
	return "  ".join(parts)


func _update_event_log() -> void:
	if event_log == null:
		return
	var lines := battle_log.summary_lines(14)
	var text := "[b]事件日志[/b]\n" + "\n".join(lines)
	if event_log is RichTextLabel:
		(event_log as RichTextLabel).text = text
	elif event_log is Label:
		(event_log as Label).text = "\n".join(lines)


func _update_hud() -> void:
	var lv_title := level.title if level else "AMBUSH LOOP"
	title_label.text = "AMBUSH LOOP  ·  第 %d 世" % loop_index
	if level_label:
		level_label.text = lv_title
	if tut_label and level:
		tut_label.text = level.tutorial if phase == Phase.SETUP else level.teaching
	intel_label.text = "漏网记忆：%d   |   %s" % [intel_paths.size(), _ammo_summary()]
	var dep := _deployed_count()
	if phase == Phase.SETUP:
		help_label.text = "准备：点掩体（%d/3）| 1/2/3选人 | A/D射界 | F开火模式 | G弹包 | B锁门 | Tab绊索\n空格拉警报。R清空记忆。「收回部署」只清空队员位。" % dep
	elif phase == Phase.WATCHING:
		var spd := "暂停" if sim.paused else ("2×" if sim.speed >= 1.5 else "1×")
		help_label.text = "锁死看戏 t=%.1fs [%s]：冷却独立；还击需LOS；伏击区触发入伏；搜尸最近+LOS。" % [sim.time_sec(), spd]
	elif phase == Phase.FAILED:
		help_label.text = "失败原因：%s。改朝向/掩体/开火条件后再警报。" % fail_reason
	elif phase == Phase.WON:
		help_label.text = "战前准备决定战斗。"
	elif phase == Phase.REPLAY:
		help_label.text = "复盘：只读事件，不重演模拟。"
	_refresh_door_visual()
	_refresh_mode_pack_buttons()
