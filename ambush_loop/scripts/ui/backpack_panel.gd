class_name BackpackPanel
extends CanvasLayer

## Commandos-style per-operator pack. I / 背包 toggles. Click a gun to equip.

signal equip_requested(kind: String)
signal pass_requested(kind: String)
signal drop_requested(kind: String)
signal closed

const Weapons := preload("res://scripts/raid/weapon_catalog.gd")
const GunStampScript := preload("res://scripts/ui/gun_stamp.gd")

var _open: bool = false
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _grid: GridContainer
var _hint: Label
var _equip_btn: Button
var _pass_btn: Button
var _drop_btn: Button
var _close_btn: Button
var _picked: String = ""
var _slot_btns: Array = []


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.018, 0.012, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			dismiss()
	)
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.theme = NightOps.theme()
	_panel.add_theme_stylebox_override("panel", NightOps.dossier(NightOps.PANEL, NightOps.OLIVE_HI, 14, 4))
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -420.0
	_panel.offset_right = -18.0
	_panel.offset_top = -210.0
	_panel.offset_bottom = 210.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_font_override("font", NightOps.ui_font_bold())
	_title.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_title.text = "背包"
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	for i in 6:
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 72)
		b.theme = NightOps.theme()
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stamp := GunStampScript.new()
		stamp.name = "Stamp"
		stamp.position = Vector2(8, 6)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(stamp)
		var idx := i
		b.pressed.connect(func() -> void:
			_on_slot(idx)
		)
		_grid.add_child(b)
		_slot_btns.append(b)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", NightOps.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = "点枪装备。容量 6 格，枪/雷/饵占格。"
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_equip_btn = _act("装备")
	_pass_btn = _act("递给队友")
	_drop_btn = _act("丢掉")
	_equip_btn.pressed.connect(func() -> void:
		if _picked != "":
			equip_requested.emit(_picked)
	)
	_pass_btn.pressed.connect(func() -> void:
		if _picked != "":
			pass_requested.emit(_picked)
	)
	_drop_btn.pressed.connect(func() -> void:
		if _picked != "":
			drop_requested.emit(_picked)
	)
	row.add_child(_equip_btn)
	row.add_child(_pass_btn)
	row.add_child(_drop_btn)
	_close_btn = _act("关闭 (I)")
	_close_btn.pressed.connect(dismiss)
	box.add_child(_close_btn)


func _act(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.theme = NightOps.theme()
	b.focus_mode = Control.FOCUS_NONE
	return b


func is_open() -> bool:
	return _open


func present(op: OperatorUnit) -> void:
	_open = true
	visible = true
	refresh(op)


func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_picked = ""
	closed.emit()


func refresh(op: OperatorUnit) -> void:
	if op == null:
		_title.text = "背包"
		return
	var pack = op.pack if op.get("pack") != null else null
	var used := 0
	if pack != null:
		used = int(pack.occupied())
	_title.text = "%s  背包 %d/%d" % [op.display_name, used, 6]
	var items: Array = pack.items() if pack != null else []
	if _picked != "":
		var still := false
		for s in items:
			if str(s.get("kind", "")) == _picked:
				still = true
				break
		if not still:
			_picked = ""
	for i in _slot_btns.size():
		var b: Button = _slot_btns[i]
		var stamp: Control = b.get_node_or_null("Stamp")
		if i >= items.size():
			b.text = "空"
			b.disabled = false
			b.set_meta("kind", "")
			_paint_slot(b, false, true)
			if stamp:
				stamp.set("weapon_id", "knife")
			continue
		var rec: Dictionary = items[i]
		var kind := str(rec.get("kind", ""))
		var amt := int(rec.get("amount", 1))
		var name := Weapons.display_name(kind)
		var equipped := str(op.weapon_id) == kind
		var line := name
		if Weapons.is_firearm(kind):
			line = "%s%s" % [name, " · 握" if equipped else ""]
		elif amt > 1:
			line = "%s ×%d" % [name, amt]
		b.text = line
		b.set_meta("kind", kind)
		_paint_slot(b, kind == _picked, false)
		if stamp:
			stamp.set("weapon_id", kind if Weapons.is_firearm(kind) else "knife")
	if _picked == "":
		_hint.text = "点一格：枪可装备，雷/饵可递给走近的队友。满了就丢掉。"
	else:
		_hint.text = "已选 %s。装备 / 递给队友 / 丢掉。" % Weapons.display_name(_picked)
	_equip_btn.disabled = _picked == "" or not Weapons.is_firearm(_picked)
	_pass_btn.disabled = _picked == ""
	_drop_btn.disabled = _picked == ""


func _paint_slot(b: Button, hot: bool, empty: bool) -> void:
	var bg := Color(0.08, 0.07, 0.05, 0.96)
	var border := Color(0.36, 0.32, 0.22, 0.85)
	if empty:
		bg = Color(0.06, 0.055, 0.04, 0.88)
		border = Color(0.24, 0.22, 0.16, 0.55)
	if hot:
		bg = Color(0.14, 0.12, 0.07, 0.98)
		border = NightOps.OLIVE_HI
	b.add_theme_stylebox_override("normal", NightOps.flat(bg, border, 1 if not hot else 2, 8, 4))
	b.add_theme_stylebox_override("hover", NightOps.flat(bg.lightened(0.12), border.lightened(0.15), 2, 8, 4))
	b.add_theme_color_override("font_color", NightOps.TEXT if not empty else NightOps.MUTED)


func _on_slot(idx: int) -> void:
	if idx < 0 or idx >= _slot_btns.size():
		return
	var kind := str(_slot_btns[idx].get_meta("kind", ""))
	if kind == "":
		_picked = ""
		return
	if _picked == kind and Weapons.is_firearm(kind):
		equip_requested.emit(kind)
		return
	_picked = kind
