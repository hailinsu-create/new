class_name TutorialOverlay
extends CanvasLayer

## Per-level SETUP pages. Page 1 cannot be dismissed accidentally.

signal dismissed

const YARD_STEPS := [
	{
		"title": "1 / 3  ·  搜刮",
		"body": "三人从插入点出发，开局只有刀。点选队员，点地走路，走近武器匣站定 0.4 秒开匣。步枪弹不能塞进机枪。点掩体趴下，青弧才有保护。红线主路，橙线侧翼第二波才到。先搜匣再埋伏。",
	},
	{
		"title": "2 / 3  ·  射界与角色",
		"body": "A/D、右键，或底栏 ↺↻ / 拖已部署队员调朝向。黄锥是墙裁切后的真射界；青弧方向来袭才有掩体减免，侧背全伤。这关手感：灰狼主路第一枪、铁砧东箱扫橙线、夜枭长窄锁南闸。红=主路，橙=侧翼。",
	},
	{
		"title": "3 / 3  ·  警报与打扫",
		"body": "空格拉警报，本波敌人按作者路线冲逃逸口，队员按射界自动开火，可丢已准备的手雷。清波后进入打扫：走近尸体搜刮，空格拉下一波。最后一波打扫后撤离才算封锁。逃逸或全灭失败，装备重置，情报留下。陷阱路线：橙线侧翼第二波从东廊绕出。虚线箭头标第二层。",
	},
]

const WAREHOUSE_STEPS := [
	{
		"title": "仓道 1 / 3  ·  两波入伏",
		"body": "两波警报。第一波主路，打扫后再打东廊侧翼。过早开火会把弹打空。选中队员，F 切「入伏再打」：黄锥变暗，等他们走进黄色伏击区。第一波打完会解锁开火，第二波不用再等黄区。",
	},
	{
		"title": "仓道 2 / 3  ·  弹包（G）",
		"body": "底栏「弹包」把唯一备用弹包交给已部署队员（G 是丢手雷）。空弹时自动补一次本轮起始弹药。这关必须给铁砧。第二波侧翼走东廊，油桶靠近才炸，打扫后再拉警报。",
	},
	{
		"title": "仓道 3 / 3  ·  油桶",
		"body": "东廊橙色油桶是关卡预置杀器：敌人靠近才在模拟结算里引爆（准备期地图上有「爆心」提示），执行中不能点击引爆。别把灰狼/铁砧放进爆破圈。陷阱路线：橙线侧翼走东廊。虚线是侧翼；课是 F 入伏等黄区，不是站爆心外。",
	},
]

const PUMP_STEPS := [
	{
		"title": "泵站 1 / 2  ·  锁门（B）",
		"body": "两波。先打主路，打扫后再打侧翼。B 锁门不是稳赢——侧翼会在决策格改走紫色备用接近。第一波打扫完再决定锁不锁门，第二波前把青弧转过去。",
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
		"body": "西暗道影探晚 2.2 秒才从西墙夹缝南下（SETUP 暗芯片倒计时）。灰狼锁主路，铁砧朝北等东廊，夜枭看南闸。绊索就是第四人：Tab 铺在西暗道（7,11 一带），抽中这一下才爽。先到的两路会把南闸弹药打空。弹包一人。警报中可丢手雷，走位等打扫。陷阱路线：绿线西暗道晚 2.2 秒，忽略它南闸会被先到两路打空。虚线箭头标第二层：东廊先到会打空南闸。",
	},
]

const RADIO_STEPS := [
	{
		"title": "电台 1 / 2  ·  灯塔回波",
		"body": "油库切断后，电台还能把下一班叫回来。红线主路走灯塔脊，橙线东廊先到一班，绿线西暗道晚 3.6 秒，青线回波晚 5.2 秒走碟台夹缝——不是东廊那一枪。中间碟厅挡住对射。",
	},
	{
		"title": "电台 2 / 2  ·  绊索与回波",
		"body": "铁砧站碟台朝南等 5.2 秒灯塔回波——等住这一枪才爽。灰狼锁灯塔脊，夜枭朝北锁东廊。绊索就是第四人：Tab 铺在西暗道（7,11 一带）。弹包一人。警报中可丢手雷，走位等打扫。陷阱路线：绿线西暗道 3.6 秒先漏，虚线箭头标第二层：暗道要绊索。回波是修好暗道之后的下一刀。",
	},
]

const RAILCUT_STEPS := [
	{
		"title": "信号楼 1 / 2  ·  双走廊",
		"body": "西廊与东廊被中间的信号塔隔开，对向射不过去。陷阱是把三人全放南闸：出口一个人罩不住两条走廊，先到的西廊巡卫会把弹药打空，东廊再漏。",
	},
	{
		"title": "信号楼 2 / 2  ·  延迟侧翼",
		"body": "东廊奔袭晚 3.8 秒才从北过道折下来（SETUP 图例橙芯片标了延迟）。这关必须带铁砧朝北等东廊——等住这一枪才爽。灰狼补西廊；夜枭锁南闸防漏。绊索只能铺一条走廊；弹包一人。警报中可丢手雷，走位等打扫。陷阱路线：橙线东廊晚 3.8 秒，南闸先被西廊主路打空。虚线箭头标第二层：别把弹药堆在南闸。"
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
	dim.color = Color(0.018, 0.016, 0.010, 0.82)
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
