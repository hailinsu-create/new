class_name TutorialOverlay
extends CanvasLayer

## First-run yard SETUP: three pages. Page 1 cannot be dismissed accidentally.

signal dismissed

const STEPS := [
	{
		"title": "1 / 3  ·  部署",
		"body": "左侧三张作战卡是步枪手、机枪手、侦察兵。点选一张，再点地图上的掩体位——把三人放到能交叉封锁主路与侧翼的位置。",
	},
	{
		"title": "2 / 3  ·  射界与角色",
		"body": "A/D 或右键调整朝向。黄锥是被墙裁切后的真实射界；青弧方向来袭才有掩体减免，侧背全伤。步枪补漏、机枪宽锥短距、侦察长窄锁线。",
	},
	{
		"title": "3 / 3  ·  锁死观看",
		"body": "空格拉响警报后计划冻结，不能再微操，只能暂停/变速观看。逃逸或全灭都会穿梭失败，但会带回路线情报。下一世可以改计划。",
	},
]

var _open: bool = false
var _page: int = 0
var _title: Label
var _body: Label
var _back: Button
var _next: Button
var _check: CheckBox


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
	panel.offset_top = -170.0
	panel.offset_bottom = 190.0
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
	_body.custom_minimum_size = Vector2(500, 120)
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
	_back.custom_minimum_size = Vector2(110, 36)
	_back.pressed.connect(_on_back)
	row.add_child(_back)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(140, 36)
	_next.pressed.connect(_on_next)
	row.add_child(_next)


func is_open() -> bool:
	return _open


func present() -> void:
	_open = true
	_page = 0
	_check.button_pressed = false
	visible = true
	_refresh()


func _refresh() -> void:
	var step: Dictionary = STEPS[_page]
	_title.text = str(step["title"])
	_body.text = str(step["body"])
	_back.visible = _page > 0
	_check.visible = _page == STEPS.size() - 1
	if _page == 0:
		_next.text = "下一步"
	elif _page < STEPS.size() - 1:
		_next.text = "下一步"
	else:
		_next.text = "开始布置"


func _on_back() -> void:
	if _page <= 0:
		return
	_page -= 1
	_refresh()


func _on_next() -> void:
	if _page < STEPS.size() - 1:
		_page += 1
		_refresh()
		return
	_finish()


func _finish() -> void:
	_open = false
	visible = false
	dismissed.emit()
