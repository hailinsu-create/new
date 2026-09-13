class_name C2PortraitStrip
extends Control

## Commandos 2 bottom portraits. Click / 1-2-3 still select.

signal picked(idx: int)
signal long_pressed(idx: int)
signal follow_toggled(idx: int)

const RoleGlyphScript := preload("res://scripts/ui/role_glyph.gd")
const GunStampScript := preload("res://scripts/ui/gun_stamp.gd")

var _cards: Array = []
var _stance: Array = []
var _pulse: float = 0.0
var _hold_idx: int = -1
var _hold_msec: int = 0
var _hold_fired: bool = false
var _ignore_pick: bool = false
const LONG_MS := 350


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
			if not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT:
				return
			if ev.pressed:
				_hold_idx = idx
				_hold_msec = Time.get_ticks_msec()
				_hold_fired = false
				if ev.double_click:
					picked.emit(idx)
					_hold_idx = -1
					var main = get_tree().current_scene
					if main and main.get("operators") != null and idx < main.operators.size():
						var op = main.operators[idx]
						if op:
							var center := Vector2(640, 360)
							main._cam_pan = (op.global_position - center) * 0.42
							if main.has_method("_apply_cam"):
								main._apply_cam()
			else:
				if _ignore_pick:
					_ignore_pick = false
					_hold_idx = -1
					return
				if _hold_idx == idx and not _hold_fired:
					picked.emit(idx)
				_hold_idx = -1
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
		var fol := Button.new()
		fol.name = "Follow"
		fol.text = "跟"
		fol.focus_mode = Control.FOCUS_NONE
		fol.theme = NightOps.theme()
		fol.add_theme_font_size_override("font_size", 11)
		fol.add_theme_font_override("font", NightOps.ui_font_bold())
		fol.position = Vector2(58, 2)
		fol.size = Vector2(44, 22)
		fol.custom_minimum_size = Vector2(44, 22)
		fol.visible = false
		fol.pressed.connect(func() -> void:
			_ignore_pick = true
			_hold_idx = -1
			_hold_fired = true
			follow_toggled.emit(idx)
		)
		b.add_child(fol)
		row.add_child(b)
		_cards.append(b)
		_stance.append(st)
	set_process(true)


func card_global_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= _cards.size() or _cards[idx] == null:
		return get_global_rect()
	return (_cards[idx] as Control).get_global_rect()


func _process(delta: float) -> void:
	if _hold_idx >= 0 and not _hold_fired and Time.get_ticks_msec() - _hold_msec >= LONG_MS:
		_hold_fired = true
		long_pressed.emit(_hold_idx)
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
			if op.get("follow_lead") != null and bool(op.follow_lead) and not sel:
				bits.append("跟")
			st.text = " ".join(bits)
		var fol: Button = b.get_node_or_null("Follow") as Button
		if fol:
			var phone := _phone_strip()
			fol.visible = phone and command_phase and op.alive and not sel
			var on_follow: bool = op.get("follow_lead") != null and bool(op.follow_lead)
			fol.text = "跟上" if on_follow else "跟"
			fol.modulate = Color(1.18, 1.10, 0.72) if on_follow else Color.WHITE
			var fbg := Color(0.18, 0.16, 0.08, 0.95) if on_follow else Color(0.08, 0.08, 0.06, 0.92)
			var fbd := Color(0.86, 0.72, 0.38, 0.95) if on_follow else Color(0.50, 0.46, 0.32, 0.8)
			fol.add_theme_stylebox_override("normal", NightOps.flat(fbg, fbd, 1, 6, 4))
			fol.add_theme_stylebox_override("hover", NightOps.flat(fbg.lightened(0.12), fbd.lightened(0.15), 1, 6, 4))
			fol.add_theme_color_override("font_color", Color(0.96, 0.90, 0.62) if on_follow else Color(0.82, 0.78, 0.58))
		b.disabled = not command_phase and not sel


func _phone_strip() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("want_touch_controls"):
		return bool(gs.want_touch_controls())
	return false
