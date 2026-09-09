class_name OpCard
extends PanelContainer

## Left-rail operator card: name/role, HP, ammo, fire mode, deploy slot.

signal picked(idx: int)

const RoleGlyphScript := preload("res://scripts/ui/role_glyph.gd")

var idx: int = 0
var _name: Label
var _role: Label
var _hp: ProgressBar
var _hp_txt: Label
var _meta: Label
var _slot: Label
var _glyph: Control
var _accent: ColorRect
var _fill_col: Color = Color(0, 0, 0, 0)
var _normal: StyleBoxFlat
var _hot: StyleBoxFlat
var _hovered: bool = false
var _selected: bool = false
var _can_pick: bool = true
var _hp_shown: float = -1.0
var _hp_target: float = 0.0


func setup(i: int) -> void:
	idx = i
	custom_minimum_size = Vector2(196, 108)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal = NightOps.flat(Color(0.07, 0.09, 0.08, 0.92), Color(0.32, 0.38, 0.24), 1, 8, 4)
	_hot = NightOps.flat(Color(0.14, 0.18, 0.10, 0.97), NightOps.OLIVE_HI, 2, 10, 4)
	_hot.border_width_left = 5
	_hot.content_margin_left = 12
	add_theme_stylebox_override("panel", _normal)
	gui_input.connect(_on_gui)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_refresh_chrome()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh_chrome()
	)
	_accent = ColorRect.new()
	_accent.name = "Accent"
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent.color = NightOps.OLIVE_HI
	_accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_accent.anchor_bottom = 1.0
	_accent.offset_left = 0.0
	_accent.offset_top = 4.0
	_accent.offset_right = 4.0
	_accent.offset_bottom = -4.0
	_accent.visible = false
	add_child(_accent)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_row)
	_glyph = RoleGlyphScript.new()
	_glyph.custom_minimum_size = Vector2(18, 18)
	name_row.add_child(_glyph)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 15)
	_name.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_role = Label.new()
	_role.add_theme_font_size_override("font_size", 11)
	_role.add_theme_color_override("font_color", NightOps.MUTED)
	_role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_role)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp_row)
	_hp = ProgressBar.new()
	_hp.min_value = 0.0
	_hp.max_value = OperatorUnit.MAX_HP
	_hp.show_percentage = false
	_hp.custom_minimum_size = Vector2(110, 10)
	_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := NightOps.flat(Color(0.08, 0.10, 0.09), Color(0.18, 0.20, 0.16), 1, 0, 2)
	var fill := NightOps.flat(NightOps.HP_OK, NightOps.HP_OK, 0, 0, 2)
	_hp.add_theme_stylebox_override("background", bg)
	_hp.add_theme_stylebox_override("fill", fill)
	hp_row.add_child(_hp)
	_hp_txt = Label.new()
	_hp_txt.add_theme_font_size_override("font_size", 11)
	_hp_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(_hp_txt)
	_meta = Label.new()
	_meta.add_theme_font_size_override("font_size", 12)
	_meta.add_theme_color_override("font_color", NightOps.TEXT)
	_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_meta)
	_slot = Label.new()
	_slot.add_theme_font_size_override("font_size", 12)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_slot)


func _process(delta: float) -> void:
	if _hp == null:
		return
	if _hp_shown < 0.0:
		_hp_shown = _hp_target
	else:
		_hp_shown = lerpf(_hp_shown, _hp_target, 1.0 - exp(-delta * 10.0))
	_hp.value = _hp_shown


func bind(op: OperatorUnit, is_sel: bool, can_pick: bool) -> void:
	if op == null:
		visible = false
		return
	visible = true
	_selected = is_sel
	_can_pick = can_pick
	_refresh_chrome()
	if _glyph:
		_glyph.set("role", op.role)
	_name.text = op.display_name
	_role.text = "%s · %s" % [OperatorUnit.role_display(op.role), _kit_short(op)]
	var hp := op.hp if op.alive else 0.0
	_hp_target = hp
	if _hp_shown < 0.0:
		_hp_shown = hp
	var col := NightOps.hp_color(hp / OperatorUnit.MAX_HP)
	if _fill_col != col:
		_fill_col = col
		_hp.add_theme_stylebox_override("fill", NightOps.flat(col, Color(0, 0, 0, 0), 0, 0, 2))
	_hp_txt.text = "0" if not op.alive else str(int(round(hp)))
	_meta.text = "弹药 %d/%d    %s" % [op.ammo, op.max_ammo, op.fire_mode_label()]
	if not op.visible or op.slot == null:
		_slot.text = "未部署"
		_slot.add_theme_color_override("font_color", Color(0.72, 0.55, 0.32))
	else:
		_slot.text = op.slot.label_text
		_slot.add_theme_color_override("font_color", NightOps.OLIVE_DIM)


func _refresh_chrome() -> void:
	add_theme_stylebox_override("panel", _hot if _selected else _normal)
	if _accent:
		_accent.visible = _selected
	if not _can_pick:
		modulate = Color(1, 1, 1, 0.5)
	elif _hovered and not _selected:
		modulate = Color(1.14, 1.16, 1.06)
	elif _selected:
		modulate = Color(1.08, 1.10, 1.02)
	else:
		modulate = Color.WHITE


func _kit_short(op: OperatorUnit) -> String:
	match op.role:
		OperatorUnit.Role.MG:
			return "宽锥短距"
		OperatorUnit.Role.SCOUT:
			return "长窄锁线"
		_:
			return "均衡补漏"


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(idx)
		accept_event()
		return
	if event is InputEventScreenTouch and event.pressed:
		picked.emit(idx)
		accept_event()
