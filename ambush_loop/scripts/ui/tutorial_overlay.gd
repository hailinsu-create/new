class_name TutorialOverlay
extends CanvasLayer

## Per-level SETUP pages. Page 1 cannot be dismissed accidentally.

signal dismissed

const YARD_STEPS := [
	{
		"title": "1 / 3  ·  部署",
		"body": "左侧三张作战卡是灰狼（步枪补漏）、铁砧（机枪宽锥）、夜枭（侦察长窄）。卡上写本关必须带谁。点选一张，再点掩体部署。红线主路从北门进南闸，橙线侧翼从东廊绕出——灰狼锁主路第一枪，铁砧扫东箱，夜枭锁南闸，只锁一条会漏。",
	},
	{
		"title": "2 / 3  ·  射界与角色",
		"body": "A/D、右键，或底栏 ↺↻ / 拖已部署队员调朝向。黄锥是墙裁切后的真射界；青弧方向来袭才有掩体减免，侧背全伤。这关手感：灰狼主路第一枪、铁砧东箱扫橙线、夜枭长窄锁南闸。红=主路，橙=侧翼。",
	},
	{
		"title": "3 / 3  ·  锁死观看",
		"body": "空格或底栏「警报」拉响后计划冻结，不能再微操，只能暂停/变速观看。失败三种：逃逸、全灭、中止（X 留目前情报）。下一世恢复上轮计划，可以改朝向。陷阱路线：橙线侧翼从东廊绕出，只锁红线主路会漏。地图上的虚线箭头是第二层，跟着走。",
	},
]

const WAREHOUSE_STEPS := [
	{
		"title": "仓道 1 / 3  ·  入伏再打（F）",
		"body": "过早开火是这关的陷阱，会把弹打空让侧翼漏出。选中已部署队员，F 或底栏「开火」切到「入伏再打」：黄锥变暗，等他们走进黄色伏击区——入伏后再打才是这关的爽点。警报后不能再改开火条件。",
	},
	{
		"title": "仓道 2 / 3  ·  弹包（G）",
		"body": "G 或底栏「弹包」把唯一备用弹包交给已部署队员。空弹时自动补一次本轮起始弹药，不能转交。这关必须给铁砧：宽锥最容易空，弹包续上才打得完窗口。仓道之后泵站、信号楼、油库、电台也都只有一包。",
	},
	{
		"title": "仓道 3 / 3  ·  油桶",
		"body": "东廊橙色油桶是关卡预置杀器：敌人靠近才在模拟结算里引爆（准备期地图上有「爆心」提示），执行中不能点击引爆。别把灰狼/铁砧放进爆破圈。陷阱路线：橙线侧翼走东廊，过早开火打空后从爆心外漏出。虚线箭头标第二层：过早开火会打空。",
	},
]

const PUMP_STEPS := [
	{
		"title": "泵站 1 / 2  ·  锁门（B）",
		"body": "B 或底栏「门锁」切换锁门。锁上后东廊关闭，不是稳赢——那是陷阱。侧翼奔袭会在决策格改走作者写好的紫色备用接近，从西侧绕到你没罩住的侧背。",
	},
	{
		"title": "泵站 2 / 2  ·  侧背与出口",
		"body": "紫色备用接近从西侧绕来，青弧没罩住的方向是全伤。这关夜枭锁出水口；铁砧把侧背对准紫线——锁门后紫线改道被你罩住，才是这关的爽点。警报后计划冻结，只能观看。陷阱路线：锁门后橙线改走西侧紫备用接近，不是消失。虚线箭头就是那条紫线。",
	},
]

const DEPOT_STEPS := [
	{
		"title": "油库 1 / 2  ·  三路合围",
		"body": "三路合围：红线主路巡卫、橙线东廊奔袭、绿线西暗道影探。中间油罐挡住对射，一个锥罩不住两路。三人不够锁三条——必须用唯一绊索封西暗道。",
	},
	{
		"title": "油库 2 / 2  ·  西暗道 2.2s",
		"body": "西暗道影探晚 2.2 秒才从西墙夹缝南下（SETUP 暗芯片倒计时）。灰狼锁主路，铁砧朝北等东廊，夜枭看南闸。绊索就是第四人：Tab 铺在西暗道（7,11 一带），抽中这一下才爽。先到的两路会把南闸弹药打空。弹包一人。警报后不能微操。陷阱路线：绿线西暗道晚 2.2 秒，忽略它南闸会被先到两路打空。虚线箭头标第二层：东廊先到会打空南闸。",
	},
]

const RADIO_STEPS := [
	{
		"title": "电台 1 / 2  ·  灯塔回波",
		"body": "油库切断后，电台还能把下一班叫回来。红线主路走灯塔脊，橙线东廊先到一班，绿线西暗道晚 3.6 秒，青线回波晚 5.2 秒走碟台夹缝——不是东廊那一枪。中间碟厅挡住对射。",
	},
	{
		"title": "电台 2 / 2  ·  绊索与回波",
		"body": "铁砧站碟台朝南等 5.2 秒灯塔回波——等住这一枪才爽。灰狼锁灯塔脊，夜枭朝北锁东廊。绊索就是第四人：Tab 铺在西暗道（7,11 一带）。弹包一人。警报后不能微操。陷阱路线：绿线西暗道 3.6 秒先漏，虚线箭头标第二层：暗道要绊索。回波是修好暗道之后的下一刀。",
	},
]

const RAILCUT_STEPS := [
	{
		"title": "信号楼 1 / 2  ·  双走廊",
		"body": "西廊与东廊被中间的信号塔隔开，对向射不过去。陷阱是把三人全放南闸：出口一个人罩不住两条走廊，先到的西廊巡卫会把弹药打空，东廊再漏。",
	},
	{
		"title": "信号楼 2 / 2  ·  延迟侧翼",
		"body": "东廊奔袭晚 3.8 秒才从北过道折下来（SETUP 图例橙芯片标了延迟）。这关必须带铁砧朝北等东廊——等住这一枪才爽。灰狼补西廊；夜枭锁南闸防漏。绊索只能铺一条走廊；弹包一人。警报后不能微操。陷阱路线：橙线东廊晚 3.8 秒，南闸先被西廊主路打空。虚线箭头标第二层：别把弹药堆在南闸。"
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
	dim.name = "Dimmer"
	dim.color = Color(0.015, 0.025, 0.018, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dimmer_input)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = NightOps.theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -196.0
	panel.offset_bottom = 214.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
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
		"radio":
			return RADIO_STEPS
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


func _on_dimmer_input(event: InputEvent) -> void:
	## Page 1 (and later pages) cannot be skipped by clicking the dimmer.
	## Dimmer is MOUSE_FILTER_STOP; this handler must not dismiss.
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			var dim := get_node_or_null("Dimmer") as Control
			if dim:
				dim.accept_event()


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
