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
var _why: Label
var _glyph: Control
var _fill_col: Color = Color(0, 0, 0, 0)
var _normal: StyleBoxFlat
var _hot: StyleBoxFlat
var _hovered: bool = false
var _selected: bool = false
var _can_pick: bool = true
var _hp_shown: float = -1.0
var _hp_target: float = 0.0
var _pips: HBoxContainer = null
var _hurt_flash: float = 0.0
var _watching: bool = false
var _deployed: bool = false
var _fire_pulse: float = 0.0


func setup(i: int) -> void:
	idx = i
	custom_minimum_size = Vector2(204, 96)
	size_flags_vertical = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal = NightOps.flat(Color(0.055, 0.072, 0.062, 0.94), Color(0.28, 0.34, 0.22), 1, 8, 3)
	_normal.border_width_top = 2
	_normal.border_width_left = 4
	_normal.content_margin_left = 12
	_hot = NightOps.flat(Color(0.09, 0.12, 0.08, 0.98), NightOps.OLIVE_HI, 1, 8, 3)
	_hot.border_width_left = 6
	_hot.border_width_top = 3
	_hot.content_margin_left = 14
	_hot.shadow_size = 5
	_hot.shadow_color = Color(0.50, 0.58, 0.28, 0.22)
	_hot.shadow_offset = Vector2(0, 2)
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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_row)
	_glyph = RoleGlyphScript.new()
	_glyph.custom_minimum_size = Vector2(26, 26)
	name_row.add_child(_glyph)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 16)
	_name.add_theme_font_override("font", NightOps.ui_font_bold())
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
	_hp.custom_minimum_size = Vector2(110, 12)
	_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := NightOps.flat(Color(0.08, 0.10, 0.09), Color(0.18, 0.20, 0.16), 1, 0, 2)
	var fill := NightOps.flat(NightOps.HP_OK, NightOps.HP_OK, 0, 0, 2)
	_hp.add_theme_stylebox_override("background", bg)
	_hp.add_theme_stylebox_override("fill", fill)
	hp_row.add_child(_hp)
	_hp_txt = Label.new()
	_hp_txt.add_theme_font_size_override("font_size", 11)
	_hp_txt.add_theme_font_override("font", NightOps.ui_font_bold())
	_hp_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(_hp_txt)
	_pips = HBoxContainer.new()
	_pips.name = "AmmoPips"
	_pips.add_theme_constant_override("separation", 2)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pips)
	_meta = Label.new()
	_meta.add_theme_font_size_override("font_size", 11)
	_meta.add_theme_font_override("font", NightOps.ui_font_bold())
	_meta.add_theme_color_override("font_color", NightOps.TEXT)
	_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_meta)
	var slot_row := HBoxContainer.new()
	slot_row.name = "SlotRow"
	slot_row.add_theme_constant_override("separation", 8)
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_row.visible = false
	box.add_child(slot_row)
	_slot = Label.new()
	_slot.add_theme_font_size_override("font_size", 11)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_row.add_child(_slot)
	_why = Label.new()
	_why.add_theme_font_size_override("font_size", 11)
	_why.add_theme_font_override("font", NightOps.ui_font_bold())
	_why.add_theme_color_override("font_color", NightOps.OLIVE_HI)
	_why.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_why.autowrap_mode = TextServer.AUTOWRAP_OFF
	_why.clip_text = true
	_why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_why.visible = false
	slot_row.add_child(_why)


func _process(delta: float) -> void:
	if _hp == null:
		return
	if _hp_shown < 0.0:
		_hp_shown = _hp_target
	else:
		_hp_shown = lerpf(_hp_shown, _hp_target, 1.0 - exp(-delta * 10.0))
	_hp.value = _hp_shown
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(_hurt_flash - delta * 4.2, 0.0)
		_hp.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.55, 0.62, 0.38), _hurt_flash)
	else:
		_hp.modulate = Color.WHITE
	if _fire_pulse > 0.0:
		_fire_pulse = maxf(_fire_pulse - delta * 3.8, 0.0)
		_refresh_chrome()


func pulse_fire() -> void:
	## Muzzle-linked punch on the card while WATCHING.
	_fire_pulse = 1.0
	_refresh_chrome()


func bind(op: OperatorUnit, is_sel: bool, can_pick: bool, watching: bool = false, why: String = "") -> void:
	if op == null:
		visible = false
		return
	visible = true
	size_flags_vertical = 0
	_selected = is_sel
	_can_pick = can_pick
	_watching = watching
	_deployed = op.visible and op.slot != null and op.alive
	_refresh_chrome()
	if _glyph:
		_glyph.set("role", op.role)
		_glyph.visible = true
	var kit := OperatorUnit.role_kit_color(op.role)
	var stripe := kit.lerp(NightOps.OLIVE, 0.42)
	_name.text = op.display_name
	_name.add_theme_color_override("font_color", stripe.lerp(NightOps.OLIVE_HI, 0.55))
	if _normal:
		_normal.border_color = Color(stripe.r, stripe.g, stripe.b, 0.70)
	if _hot:
		_hot.border_color = stripe.lerp(NightOps.OLIVE_HI, 0.35)
		_hot.shadow_color = Color(0.50, 0.58, 0.28, 0.22)
	_role.text = "%s · %s" % [OperatorUnit.role_display(op.role), _kit_short(op)]
	_role.add_theme_color_override("font_color", stripe.lerp(NightOps.MUTED, 0.40))
	var hp := op.hp if op.alive else 0.0
	_hp_target = hp
	if op.has_method("hit_feedback"):
		var pulse := float(op.hit_feedback())
		if pulse > 0.12:
			_hurt_flash = maxf(_hurt_flash, pulse)
	if _hp_shown < 0.0:
		_hp_shown = hp
	var col := NightOps.hp_color(hp / OperatorUnit.MAX_HP)
	if _fill_col != col:
		_fill_col = col
		_hp.add_theme_stylebox_override("fill", NightOps.flat(col, Color(0, 0, 0, 0), 0, 0, 2))
	_hp_txt.text = "HP 0" if not op.alive else "HP %d" % int(round(hp))
	_refresh_ammo_pips(op)
	var ammo_mark := "●" if op.ammo > 0 else "○"
	var slot_txt := "未部署"
	if op.visible and op.slot != null:
		slot_txt = op.slot.label_text
	if op.has_method("inventory_line"):
		_meta.text = "%s  %s" % [op.inventory_line(), op.fire_mode_label()]
	else:
		_meta.text = "%s 弹 %d/%d  %s  ·  %s" % [ammo_mark, op.ammo, op.max_ammo, op.fire_mode_label(), slot_txt]
	if not op.visible:
		_slot.text = "未上场"
		_slot.add_theme_color_override("font_color", Color(0.72, 0.55, 0.32))
	elif op.slot == null:
		_slot.text = "机动"
		_slot.add_theme_color_override("font_color", Color(0.72, 0.55, 0.32))
	else:
		_slot.text = op.slot.label_text
		_slot.add_theme_color_override("font_color", NightOps.OLIVE_DIM)
	_slot.visible = false
	if _why:
		var line := why.strip_edges()
		if line == "":
			line = _default_why(op)
		_why.text = line
		_why.visible = false
		_why.add_theme_color_override("font_color", kit.lerp(NightOps.OLIVE_HI, 0.45))


func _refresh_chrome() -> void:
	add_theme_stylebox_override("panel", _hot if _selected else _normal)
	if _watching and not _deployed:
		modulate = Color(0.50, 0.50, 0.48, 0.48)
	elif _fire_pulse > 0.04:
		modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.28, 1.22, 0.78), _fire_pulse)
	elif not _can_pick:
		modulate = Color(1, 1, 1, 0.5)
	elif _hovered and not _selected:
		modulate = Color(1.10, 1.12, 1.04)
	elif _selected:
		modulate = Color(1.08, 1.10, 1.04)
	else:
		modulate = Color.WHITE


func _refresh_ammo_pips(op: OperatorUnit) -> void:
	if _pips == null:
		return
	var n := mini(maxi(op.max_ammo, 1), 12)
	while _pips.get_child_count() > n:
		var last := _pips.get_child(_pips.get_child_count() - 1)
		_pips.remove_child(last)
		last.free()
	while _pips.get_child_count() < n:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8, 7)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)
	var filled := int(round(float(maxi(op.ammo, 0)) / float(maxi(op.max_ammo, 1)) * float(n)))
	if not op.alive:
		filled = 0
	var kit := OperatorUnit.role_kit_color(op.role)
	for i in n:
		var pip: ColorRect = _pips.get_child(i) as ColorRect
		if pip == null:
			continue
		if i < filled:
			pip.color = Color(kit.r, kit.g, kit.b, 0.92).lerp(NightOps.OLIVE_HI, 0.18)
		else:
			pip.color = Color(0.16, 0.18, 0.14, 0.85)


func _kit_short(op: OperatorUnit) -> String:
	if op.has_method("inventory_line"):
		return op.inventory_line()
	match op.role:
		OperatorUnit.Role.MG:
			return "铁砧 · 宽锥短距"
		OperatorUnit.Role.SCOUT:
			return "夜枭 · 长窄锁线"
		_:
			return "灰狼 · 均衡补漏"


func _default_why(op: OperatorUnit) -> String:
	match op.role:
		OperatorUnit.Role.MG:
			return "弹包第一优先 · 宽锥扫侧翼"
		OperatorUnit.Role.SCOUT:
			return "出口/迟到侧翼锁线"
		_:
			return "主路补漏 · 第一枪"


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(idx)
		accept_event()
		return
	if event is InputEventScreenTouch and event.pressed:
		picked.emit(idx)
		accept_event()
