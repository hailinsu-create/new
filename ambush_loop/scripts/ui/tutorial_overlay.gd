class_name TutorialOverlay
extends CanvasLayer

## Per-level SETUP pages. Page 1 cannot be dismissed accidentally.

signal dismissed

const YARD_STEPS := [
	{
		"title": "1 / 3  ·  部署",
		"body": "左侧三张作战卡是步枪手、机枪手、侦察兵。点选一张，再点地图上的掩体位——把三人放到能交叉封锁主路与侧翼的位置。",
	},
	{
		"title": "2 / 3  ·  射界与角色",
		"body": "A/D、右键，或底栏 ↺↻ / 拖已部署队员调整朝向。黄锥是被墙裁切后的真实射界；青弧方向来袭才有掩体减免，侧背全伤。步枪补漏、机枪宽锥短距、侦察长窄锁线。",
	},
	{
		"title": "3 / 3  ·  锁死观看",
		"body": "空格或底栏「警报」拉响后计划冻结，不能再微操，只能暂停/变速观看。逃逸或全灭都会穿梭失败，但会带回路线情报。下一世可以改计划。",
	},
]

const WAREHOUSE_STEPS := [
	{
		"title": "仓道 1 / 3  ·  入伏再打（F）",
		"body": "过早开火会把弹打空。选中已部署队员，按 F 或底栏「开火」切到「入伏再打」：黄锥变暗，等敌人走进黄色伏击区再开火。警报后不能再改开火条件。",
	},
	{
		"title": "仓道 2 / 3  ·  弹包（G）",
		"body": "G 或底栏「弹包」把唯一的备用弹包交给一名已部署队员。空弹时自动补一次本轮起始弹药，不能转交。机枪手最容易空，步枪也可以吃包补漏。",
	},
	{
		"title": "仓道 3 / 3  ·  油桶",
		"body": "东廊橙色油桶是关卡预置：敌人靠近才在模拟结算里引爆，准备期只能预览爆心，执行中不能点击引爆。别把队员放进爆破圈。",
	},
]

const PUMP_STEPS := [
	{
		"title": "泵站 1 / 2  ·  锁门（B）",
		"body": "B 或底栏「门锁」切换锁门。锁上后东廊关闭，不是稳赢按钮——侧翼敌人会在决策格改走作者写好的紫色备用接近，不会自由寻路。",
	},
	{
		"title": "泵站 2 / 2  ·  侧背与出口",
		"body": "备用接近从西侧绕来，青弧没罩住的方向是全伤；机枪侧背更危险。侦察适合锁出口。警报后计划冻结，只能观看。",
	},
]

const DEPOT_STEPS := [
	{
		"title": "油库 1 / 2  ·  三路",
		"body": "西暗道、主路、东廊三条接近。中间油罐挡住对射，不能用一个锥罩住两路。三人不够同时锁三条，必须用绊索封一条。",
	},
	{
		"title": "油库 2 / 2  ·  绊索换人",
		"body": "西暗道敌人晚几秒才从西墙夹缝南下。步枪锁主路，机枪朝北等东廊，侦察看南闸；把唯一的绊索铺在西暗道。弹包一人。警报后不能微操。",
	},
]

const RAILCUT_STEPS := [
	{
		"title": "信号楼 1 / 2  ·  双走廊",
		"body": "西廊与东廊被中间的信号设备隔开，对向射不过去。不要把三人全放在南闸：出口一个人罩不住两条走廊，先到的西廊会把弹药打空。",
	},
	{
		"title": "信号楼 2 / 2  ·  延迟侧翼",
		"body": "东廊敌人晚几秒才从北过道折下来。机枪适合朝北锁东廊等他们；步枪补西廊；侦察锁南闸防漏。绊索只能铺一条走廊；弹包一人。警报后不能微操。",
	},
]

var _open: bool = false
var _page: int = 0
var _steps: Array = YARD_STEPS
var _title: Label
var _body: Label
var _back: Button
var _next: Button
var _check: CheckBox
var _level_id: String = "yard"


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -180.0
	panel.offset_bottom = 200.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", NightOps.TEXT)
	_body.custom_minimum_size = Vector2(500, 128)
	box.add_child(_body)
	_check = CheckBox.new()
	_check.text = "不再显示"
	_check.visible = false
	box.add_child(_check)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_back = Button.new()
	_back.text = "上一步"
	_back.custom_minimum_size = Vector2(110, 48)
	_back.pressed.connect(_on_back)
	row.add_child(_back)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(140, 48)
	_next.pressed.connect(_on_next)
	row.add_child(_next)


func is_open() -> bool:
	return _open


func present(level_id: String = "yard") -> void:
	_level_id = level_id
	_steps = pages_for(level_id)
	_open = true
	_page = 0
	_check.button_pressed = false
	visible = true
	_refresh()


static func pages_for(level_id: String) -> Array:
	match level_id:
		"warehouse":
			return WAREHOUSE_STEPS
		"pump":
			return PUMP_STEPS
		"railcut":
			return RAILCUT_STEPS
		"depot":
			return DEPOT_STEPS
		_:
			return YARD_STEPS


func _refresh() -> void:
	if _steps.is_empty():
		_steps = YARD_STEPS
	var step: Dictionary = _steps[_page]
	_title.text = str(step["title"])
	_body.text = str(step["body"])
	_back.visible = _page > 0
	_check.visible = _page == _steps.size() - 1
	if _page == 0:
		_next.text = "下一步"
	elif _page < _steps.size() - 1:
		_next.text = "下一步"
	else:
		_next.text = "开始布置"


func _on_back() -> void:
	if _page <= 0:
		return
	_page -= 1
	_refresh()


func _on_next() -> void:
	if _page < _steps.size() - 1:
		_page += 1
		_refresh()
		return
	_finish()


func _finish() -> void:
	_open = false
	visible = false
	dismissed.emit()
