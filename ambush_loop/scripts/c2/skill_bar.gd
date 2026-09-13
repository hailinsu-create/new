class_name C2SkillBar
extends Control

## Commandos 2 skill hotbar for the selected commando.

signal skill_pressed(id: String)

const Skills := preload("res://scripts/c2/c2_skills.gd")
const Icons := preload("res://scripts/c2/hud_icons.gd")

var _btns: Array = []
var _ids: PackedStringArray = PackedStringArray()
var _cds: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(280, 64)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	for i in 5:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.theme = NightOps.theme()
		b.add_theme_font_size_override("font_size", 10)
		var slot := i
		b.pressed.connect(func() -> void:
			if slot < _ids.size():
				skill_pressed.emit(_ids[slot])
		)
		b.draw.connect(func() -> void:
			_draw_slot(b, slot)
		)
		row.add_child(b)
		_btns.append(b)


func bind(op: Node, cds: Dictionary, command_phase: bool) -> void:
	_cds = cds
	if op == null:
		_ids = PackedStringArray()
		visible = false
		return
	visible = true
	_ids = Skills.for_role(int(op.role))
	for i in _btns.size():
		var b: Button = _btns[i]
		if i >= _ids.size():
			b.visible = false
			continue
		b.visible = true
		var id := _ids[i]
		var key := Skills.hotkey(id)
		b.text = "%s\n%s" % [key, Skills.label_zh(id)]
		b.disabled = not command_phase and id != "crouch"
		var cd := float(cds.get(id, 0.0))
		var hot := id == "crouch" and op.get("stance") != null and int(op.stance) == 1
		var bg := Color(0.08, 0.07, 0.05, 0.94)
		var border := Color(0.42, 0.36, 0.22, 0.85)
		if hot:
			border = NightOps.OLIVE_HI
			bg = Color(0.14, 0.12, 0.06, 0.96)
		if cd > 0.05:
			bg = Color(0.06, 0.06, 0.05, 0.9)
		b.add_theme_stylebox_override("normal", NightOps.flat(bg, border, 1 if not hot else 2, 4, 6))
		b.queue_redraw()


func _draw_slot(b: Button, slot: int) -> void:
	if slot >= _ids.size() or b == null:
		return
	var id := _ids[slot]
	var col := NightOps.OLIVE_HI
	Icons.by_id(b, id, Vector2(b.size.x * 0.5, 16), col)
	var cd := float(_cds.get(id, 0.0))
	if cd > 0.05:
		var cap := maxf(Skills.cooldown(id), 0.1)
		var h := b.size.y * clampf(cd / cap, 0.0, 1.0)
		b.draw_rect(Rect2(0, b.size.y - h, b.size.x, h), Color(0.02, 0.02, 0.02, 0.45))
