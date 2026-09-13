class_name C2PortraitStrip
extends Control

## Commandos 2 bottom portraits. Click / 1-2-3 still select.

signal picked(idx: int)

const RoleGlyphScript := preload("res://scripts/ui/role_glyph.gd")
const GunStampScript := preload("res://scripts/ui/gun_stamp.gd")

var _cards: Array = []
var _stance: Array = []
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(320, 108)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 108)
		b.focus_mode = Control.FOCUS_NONE
		b.theme = NightOps.theme()
		var idx := i
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.double_click:
				picked.emit(idx)
				if get_parent() != null:
					var main = get_tree().current_scene
					if main and main.has_method("_reset_cam_view") and main.get("operators") != null and idx < main.operators.size():
						var op = main.operators[idx]
						if op:
							var center := Vector2(640, 360)
							main._cam_pan = (op.global_position - center) * 0.42
							main._apply_cam()
		)
		b.pressed.connect(func() -> void:
			picked.emit(idx)
		)
		var gly := RoleGlyphScript.new()
		gly.name = "Glyph"
		gly.position = Vector2(8, 10)
		gly.custom_minimum_size = Vector2(36, 36)
		b.add_child(gly)
		var gun := GunStampScript.new()
		gun.name = "Gun"
		gun.position = Vector2(50, 14)
		gun.custom_minimum_size = Vector2(40, 18)
		b.add_child(gun)
		var num := Label.new()
		num.name = "Num"
		num.text = str(i + 1)
		num.position = Vector2(6, 78)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_font_override("font", NightOps.ui_font_bold())
		num.add_theme_color_override("font_color", NightOps.OLIVE_HI)
		b.add_child(num)
		var nam := Label.new()
		nam.name = "Nam"
		nam.position = Vector2(22, 76)
		nam.add_theme_font_size_override("font_size", 12)
		nam.add_theme_color_override("font_color", NightOps.TEXT)
		b.add_child(nam)
		var hp := ColorRect.new()
		hp.name = "Hp"
		hp.position = Vector2(8, 96)
		hp.size = Vector2(84, 4)
		hp.color = NightOps.HP_OK
		b.add_child(hp)
		var st := Label.new()
		st.name = "Stance"
		st.position = Vector2(70, 48)
		st.add_theme_font_size_override("font_size", 10)
		st.add_theme_color_override("font_color", NightOps.MUTED)
		st.text = ""
		b.add_child(st)
		row.add_child(b)
		_cards.append(b)
		_stance.append(st)
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta * 4.2
	for b in _cards:
		if b == null:
			continue
		var hot := str(b.get_meta("sel", "")) == "1"
		if hot:
			b.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.18, 1.12, 0.82), 0.5 + 0.5 * sin(_pulse))


func bind_ops(ops: Array, selected: Node, command_phase: bool) -> void:
	for i in _cards.size():
		var b: Button = _cards[i]
		if i >= ops.size() or ops[i] == null:
			b.visible = false
			continue
		b.visible = true
		var op = ops[i]
		var sel: bool = op == selected
		var kit: Color = OperatorUnit.role_kit_color(op.role)
		var bg := Color(0.06, 0.055, 0.04, 0.94)
		var border := Color(kit.r, kit.g, kit.b, 0.70)
		if sel:
			bg = Color(0.12, 0.11, 0.06, 0.98)
			border = NightOps.OLIVE_HI
		b.add_theme_stylebox_override("normal", NightOps.flat(bg, border, 2 if sel else 1, 6, 6))
		b.add_theme_stylebox_override("hover", NightOps.flat(bg.lightened(0.12), border.lightened(0.15), 2, 6, 6))
		b.set_meta("sel", "1" if sel else "0")
		if not op.alive:
			b.modulate = Color(0.45, 0.42, 0.40, 0.7)
			var nam_dead: Label = b.get_node_or_null("Nam")
			if nam_dead:
				nam_dead.text = "阵亡"
		elif not sel:
			b.modulate = Color.WHITE
		var gly = b.get_node_or_null("Glyph")
		if gly:
			gly.set("role", op.role)
		var gun = b.get_node_or_null("Gun")
		if gun:
			gun.set("weapon_id", op.weapon_id)
		var nam: Label = b.get_node_or_null("Nam")
		if nam:
			nam.text = str(op.display_name)
		var hp: ColorRect = b.get_node_or_null("Hp")
		if hp:
			var ratio := clampf((op.hp if op.alive else 0.0) / OperatorUnit.MAX_HP, 0.0, 1.0)
			hp.size.x = 84.0 * ratio
			hp.color = NightOps.hp_color(ratio)
		var st: Label = b.get_node_or_null("Stance")
		if st:
			var bits: PackedStringArray = PackedStringArray()
			if op.get("stance") != null and int(op.stance) == 1:
				bits.append("匍")
			if op.get("sprinting") != null and bool(op.sprinting):
				bits.append("奔")
			if op.get("hidden_in_shadow") != null and bool(op.hidden_in_shadow):
				bits.append("隐")
			st.text = " ".join(bits)
		b.disabled = not command_phase and not sel
