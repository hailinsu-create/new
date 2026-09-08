class_name NightOps
extends RefCounted

## Night-ops palette + fonts. Asphalt / olive, not purple or terracotta cream.

const BG := Color(0.055, 0.07, 0.062)
const ASPHALT := Color(0.10, 0.125, 0.11)
const OLIVE := Color(0.38, 0.44, 0.28)
const OLIVE_HI := Color(0.78, 0.84, 0.50)
const OLIVE_DIM := Color(0.55, 0.60, 0.42)
const WALL := Color(0.28, 0.22, 0.12)
const TEXT := Color(0.86, 0.88, 0.80)
const MUTED := Color(0.58, 0.62, 0.54)
const DANGER := Color(0.82, 0.36, 0.22)
const HP_OK := Color(0.42, 0.70, 0.38)
const HP_LOW := Color(0.82, 0.40, 0.22)
const PANEL := Color(0.07, 0.09, 0.08, 0.94)
const ACCENT_LINE := Color(0.62, 0.68, 0.38, 0.85)


static func display_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans Display", "Noto Sans", "DejaVu Sans"])
	f.font_weight = 800
	f.font_stretch = 70
	f.fallbacks = [ui_font()]
	return f


static func ui_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["WenQuanYi Micro Hei", "Droid Sans Fallback", "Noto Sans Display"])
	f.font_weight = 600
	return f


static func ui_font_bold() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["WenQuanYi Micro Hei", "Droid Sans Fallback", "Noto Sans Display"])
	f.font_weight = 800
	return f


static func flat(bg: Color, border: Color, bw: int = 1, pad: int = 10, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad - 2
	s.content_margin_bottom = pad - 2
	return s


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", OLIVE_HI)
	t.set_color("font_pressed_color", "Button", Color(0.95, 0.96, 0.82))
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.44, 0.40))
	t.set_stylebox("normal", "Button", flat(Color(0.12, 0.15, 0.12, 0.96), Color(0.36, 0.42, 0.26), 1, 12, 3))
	t.set_stylebox("hover", "Button", flat(Color(0.18, 0.22, 0.14, 0.98), OLIVE_HI, 1, 12, 3))
	t.set_stylebox("pressed", "Button", flat(Color(0.10, 0.14, 0.09, 1), OLIVE, 2, 12, 3))
	t.set_stylebox("disabled", "Button", flat(Color(0.09, 0.10, 0.09, 0.85), Color(0.22, 0.24, 0.20), 1, 12, 3))
	t.set_stylebox("focus", "Button", flat(Color(0.12, 0.15, 0.12, 0.96), OLIVE_HI, 2, 12, 3))
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, Color(0.40, 0.46, 0.28), 2, 16, 6))
	t.set_stylebox("panel", "Panel", flat(PANEL, Color(0.40, 0.46, 0.28), 2, 12, 4))
	t.set_font("font", "Label", ui_font())
	t.set_font("font", "Button", ui_font_bold())
	t.set_font_size("font_size", "Button", 16)
	return t


static func hp_color(ratio: float) -> Color:
	if ratio <= 0.35:
		return HP_LOW
	return HP_OK
