extends Node2D

enum Phase { SETUP, WATCHING, FAILED, WON }

const MAX_MINES := 3
const ENEMY_SCENE_POINTS := [
	Vector2(12.5, 2.5),
	Vector2(10.5, 2.5),
	Vector2(28.5, 2.5),
]

var grid: AmbushGrid = AmbushGrid.new()
var phase: Phase = Phase.SETUP
var loop_index: int = 1
var intel_paths: Array[PackedVector2Array] = []
var mines: Array[PlacedMine] = []
var enemies: Array[EnemyRunner] = []
var escape_cell := Vector2i(35, 19)
var escape_world: Vector2

@onready var map_draw: Node2D = $World/MapDraw
@onready var entities: Node2D = $World/Entities
@onready var ghosts: Node2D = $World/Ghosts
@onready var escape_marker: Node2D = $World/EscapeMarker
@onready var title_label: Label = $HUD/Root/TopBar/Title
@onready var status_label: Label = $HUD/Root/TopBar/Status
@onready var intel_label: Label = $HUD/Root/TopBar/Intel
@onready var help_label: Label = $HUD/Root/Help
@onready var alarm_button: Button = $HUD/Root/BottomBar/AlarmButton
@onready var clear_button: Button = $HUD/Root/BottomBar/ClearButton
@onready var result_panel: PanelContainer = $HUD/Root/ResultPanel
@onready var result_label: Label = $HUD/Root/ResultPanel/Margin/VBox/ResultLabel
@onready var continue_button: Button = $HUD/Root/ResultPanel/Margin/VBox/ContinueButton


func _ready() -> void:
	escape_world = grid.cell_to_world_center(escape_cell)
	escape_marker.position = escape_world
	map_draw.set("grid", grid)
	map_draw.queue_redraw()
	alarm_button.pressed.connect(_on_alarm_pressed)
	clear_button.pressed.connect(_clear_mines)
	continue_button.pressed.connect(_on_continue_pressed)
	result_panel.visible = false
	_start_setup(false)
	_update_hud()


func _start_setup(keep_intel: bool) -> void:
	phase = Phase.SETUP
	_clear_enemies()
	_clear_mines()
	if not keep_intel:
		intel_paths.clear()
		loop_index = 1
	_redraw_ghosts()
	alarm_button.disabled = false
	clear_button.disabled = false
	result_panel.visible = false
	_update_hud()


func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()


func _clear_mines() -> void:
	for m in mines:
		if is_instance_valid(m):
			m.queue_free()
	mines.clear()
	_update_hud()


func _spawn_enemies() -> void:
	_clear_enemies()
	var id := 1
	for cell_f in ENEMY_SCENE_POINTS:
		var enemy := _make_enemy(id)
		entities.add_child(enemy)
		enemy.position = Vector2(cell_f.x * AmbushGrid.TILE, cell_f.y * AmbushGrid.TILE)
		enemy.setup(grid, escape_world, id)
		enemies.append(enemy)
		id += 1


func _make_enemy(id: int) -> EnemyRunner:
	var e := EnemyRunner.new()
	e.name = "Enemy%d" % id

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(9, 8), Vector2(-9, 8)
	])
	body.color = Color(0.75, 0.22, 0.2)
	e.add_child(body)

	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-10, -28)
	tag.add_theme_font_size_override("font_size", 12)
	e.add_child(tag)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	cs.shape = shape
	e.add_child(cs)

	e.escaped.connect(_on_enemy_escaped)
	e.died.connect(_on_enemy_died)
	e.monitoring = true
	e.monitorable = true
	return e


func _make_mine(pos: Vector2) -> PlacedMine:
	var m := PlacedMine.new()
	m.position = pos

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	visual.color = Color(0.85, 0.7, 0.2)
	m.add_child(visual)

	var blast := Polygon2D.new()
	blast.name = "Blast"
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 36.0)
	blast.polygon = pts
	blast.color = Color(1.0, 0.45, 0.15, 0.55)
	blast.visible = false
	m.add_child(blast)
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_run"):
		loop_index = 1
		_start_setup(false)
		get_viewport().set_input_as_handled()
		return

	if phase != Phase.SETUP:
		return

	if event.is_action_pressed("sound_alarm"):
		_on_alarm_pressed()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var world_pos := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_mine(world_pos)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_remove_mine(world_pos)
			get_viewport().set_input_as_handled()


func _try_place_mine(world_pos: Vector2) -> void:
	if mines.size() >= MAX_MINES:
		status_label.text = "地雷已用完（最多 %d）" % MAX_MINES
		return
	if not grid.is_world_walkable(world_pos):
		status_label.text = "不能放在墙上"
		return
	var cell := grid.world_to_cell(world_pos)
	var snapped := grid.cell_to_world_center(cell)
	for m in mines:
		if m.position.distance_to(snapped) < 8.0:
			status_label.text = "这里已有地雷"
			return
	var mine := _make_mine(snapped)
	entities.add_child(mine)
	mines.append(mine)
	_update_hud()


func _try_remove_mine(world_pos: Vector2) -> void:
	for i in range(mines.size() - 1, -1, -1):
		if mines[i].position.distance_to(world_pos) <= 20.0:
			mines[i].queue_free()
			mines.remove_at(i)
			_update_hud()
			return


func _on_alarm_pressed() -> void:
	if phase != Phase.SETUP:
		return
	if mines.is_empty():
		status_label.text = "至少放一颗地雷再拉警报"
		return
	phase = Phase.WATCHING
	alarm_button.disabled = true
	clear_button.disabled = true
	_spawn_enemies()
	for e in enemies:
		e.activate()
	status_label.text = "方案已锁死 — 只能看戏。跑掉一个就重来。"
	_update_hud()


func _on_enemy_escaped(_enemy: EnemyRunner, path: PackedVector2Array) -> void:
	if phase != Phase.WATCHING:
		return
	phase = Phase.FAILED
	for e in enemies:
		e.active = false
	intel_paths.append(path)
	_redraw_ghosts()
	result_panel.visible = true
	result_label.text = "有人逃出封锁区。\n第 %d 世失败。\n逃逸路径已写入记忆。" % loop_index
	continue_button.text = "带着情报穿梭回去"
	status_label.text = "逃逸！时空穿梭准备中…"
	_update_hud()


func _on_enemy_died(_enemy: EnemyRunner) -> void:
	if phase != Phase.WATCHING:
		return
	_check_win()


func _check_win() -> void:
	if phase != Phase.WATCHING:
		return
	for e in enemies:
		if e.alive:
			return
	phase = Phase.WON
	result_panel.visible = true
	result_label.text = "零逃逸。\n杀局成立。\n用了 %d 世完成布局。" % loop_index
	continue_button.text = "再玩一局（清空记忆）"
	status_label.text = "完美封锁"
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
		line.default_color = Color(0.35, 0.75, 1.0, 0.45 - minf(0.12, float(gi) * 0.04))
		line.points = path
		ghosts.add_child(line)
		if path.size() > 0:
			var tip := Polygon2D.new()
			tip.polygon = PackedVector2Array([
				Vector2(0, -6), Vector2(6, 6), Vector2(-6, 6)
			])
			tip.color = Color(0.4, 0.85, 1.0, 0.8)
			tip.position = path[path.size() - 1]
			ghosts.add_child(tip)
		gi += 1


func _update_hud() -> void:
	title_label.text = "AMBUSH LOOP  ·  第 %d 世" % loop_index
	intel_label.text = "记忆中的逃逸路径：%d" % intel_paths.size()
	if phase == Phase.SETUP:
		help_label.text = "左键放地雷（%d/%d）  右键移除  空格/按钮拉警报\n警报后方案锁死。任何人逃出封锁区 = 失败并穿梭。R 重置全部记忆。" % [mines.size(), MAX_MINES]
	elif phase == Phase.WATCHING:
		help_label.text = "布置已锁死。观察交叉火力是否封死退路。"
	elif phase == Phase.FAILED:
		help_label.text = "记下那条漏网路径，回去补洞。"
	elif phase == Phase.WON:
		help_label.text = "导演成功：计划即一切。"


func _process(_delta: float) -> void:
	if phase != Phase.WATCHING:
		return
	for e in enemies:
		if not e.alive:
			continue
		var cell := grid.world_to_cell(e.global_position)
		if cell.x >= escape_cell.x - 1 and cell.y >= escape_cell.y - 1:
			e.mark_escaped()
			return
