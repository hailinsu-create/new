class_name C2SkillWheel
extends CanvasLayer

## Long-press portrait → overflow skills (binoculars / mine / decoy / aid).
## World verbs (开匣 / 割喉 / 拖尸) stay on context hotspots.

signal chosen(id: String)
signal cancelled

const Skills := preload("res://scripts/c2/c2_skills.gd")
const Icons := preload("res://scripts/c2/hud_icons.gd")
const RADIUS := 108.0

var _open: bool = false
var _ids: PackedStringArray = PackedStringArray()
var _origin: Vector2 = Vector2.ZERO
var _btns: Array = []
var _dim: ColorRect = null
var _cds: Dictionary = {}


func _ready() -> void:
	layer = 46
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.018, 0.012, 0.28)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			dismiss()
	)
	add_child(_dim)
	for i in 5:
		var b := Button.new()
		b.visible = false
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(92, 52)
		b.theme = NightOps.theme()
		b.add_theme_font_size_override("font_size", 13)
		var slot := i
		b.pressed.connect(func() -> void:
			_pick(slot)
		)
		b.draw.connect(func() -> void:
			_draw_slot(b, slot)
		)
		add_child(b)
		_btns.append(b)


func is_open() -> bool:
	return _open


func present(op: Node, cds: Dictionary, origin: Vector2) -> void:
	if op == null:
		return
	_cds = cds
	_origin = origin
	_ids = PackedStringArray()
	for id in Skills.for_role(int(op.role)):
		if id == "crouch" or id == "whistle":
			continue
		_ids.append(id)
	if _ids.is_empty():
		return
	_open = true
	visible = true
	var n := _ids.size()
	var start := -PI * 0.72
	var span := PI * 0.9
	for i in _btns.size():
		var b: Button = _btns[i]
		if i >= n:
			b.visible = false
			continue
		b.visible = true
		var id := _ids[i]
		var cd := float(_cds.get(id, 0.0))
		b.text = "%s%s" % [Skills.label_zh(id), "" if cd <= 0.05 else " %.0fs" % cd]
		b.disabled = cd > 0.05
		var ang := start + span * (float(i) + 0.5) / float(n)
		var pos := origin + Vector2(cos(ang), sin(ang)) * RADIUS - b.custom_minimum_size * 0.5
		pos.x = clampf(pos.x, 8.0, 1280.0 - 100.0)
		pos.y = clampf(pos.y, 48.0, 720.0 - 200.0)
		b.position = pos
		b.size = b.custom_minimum_size
		var bg := Color(0.08, 0.07, 0.05, 0.96)
		var border := NightOps.OLIVE_HI
		b.add_theme_stylebox_override("normal", NightOps.flat(bg, border, 1, 8, 8))
		b.queue_redraw()


func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	cancelled.emit()


func _pick(slot: int) -> void:
	if slot < 0 or slot >= _ids.size():
		return
	var id := _ids[slot]
	_open = false
	visible = false
	chosen.emit(id)


func _draw_slot(b: Button, slot: int) -> void:
	if slot >= _ids.size() or b == null:
		return
	Icons.by_id(b, _ids[slot], Vector2(16, b.size.y * 0.5), NightOps.OLIVE_HI)
