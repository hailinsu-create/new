class_name NightOps
extends RefCounted

## Night-ops palette + fonts. Asphalt / olive, not purple or terracotta cream.

const BG := Color(0.040, 0.042, 0.034)
const ASPHALT := Color(0.10, 0.10, 0.08)
const OLIVE := Color(0.42, 0.38, 0.24)
const OLIVE_HI := Color(0.74, 0.66, 0.40)
const OLIVE_DIM := Color(0.52, 0.48, 0.34)
const WALL := Color(0.28, 0.20, 0.12)
const TEXT := Color(0.86, 0.80, 0.64)
const MUTED := Color(0.56, 0.52, 0.42)
const DANGER := Color(0.72, 0.32, 0.16)
const HP_OK := Color(0.42, 0.52, 0.30)
const HP_LOW := Color(0.72, 0.34, 0.16)
const PANEL := Color(0.055, 0.052, 0.040, 0.96)
const ACCENT_LINE := Color(0.62, 0.52, 0.28, 0.85)
const INK := Color(0.028, 0.024, 0.018, 0.94)
const RAIL := Color(0.70, 0.58, 0.30, 0.92)


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


static func dossier(bg: Color, border: Color, pad: int = 14, radius: int = 4) -> StyleBoxFlat:
	## Night-ops panel: asphalt fill, olive top rail, inset floor.
	var s := flat(bg, border, 1, pad, radius)
	s.border_width_top = 3
	s.border_color = border
	s.shadow_size = 8
	s.shadow_color = Color(0.01, 0.02, 0.01, 0.55)
	s.shadow_offset = Vector2(0, 3)
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
	var bn := flat(Color(0.12, 0.11, 0.08, 0.96), Color(0.42, 0.34, 0.18), 1, 12, 3)
	bn.border_width_top = 2
	var bh := flat(Color(0.16, 0.20, 0.13, 0.98), OLIVE_HI, 1, 12, 3)
	bh.border_width_top = 2
	var bp := flat(Color(0.09, 0.12, 0.08, 1), OLIVE, 2, 12, 3)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", flat(Color(0.09, 0.10, 0.09, 0.85), Color(0.22, 0.24, 0.20), 1, 12, 3))
	t.set_stylebox("focus", "Button", flat(Color(0.12, 0.15, 0.12, 0.96), OLIVE_HI, 2, 12, 3))
	t.set_stylebox("panel", "PanelContainer", dossier(PANEL, Color(0.42, 0.48, 0.28), 16, 6))
	t.set_stylebox("panel", "Panel", dossier(PANEL, Color(0.40, 0.46, 0.28), 12, 4))
	t.set_font("font", "Label", ui_font())
	t.set_font("font", "Button", ui_font_bold())
	t.set_font_size("font_size", "Button", 16)
	return t


static func hp_color(ratio: float) -> Color:
	if ratio <= 0.35:
		return HP_LOW
	return HP_OK
