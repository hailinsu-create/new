class_name Ww2Palette
extends RefCounted

## Commandos night-raid materials: wool, mud, rust, steel, cordite.
## No neon, no modern polymer, no purple night.


const WOOL := Color(0.40, 0.36, 0.26)
const WOOL_DARK := Color(0.22, 0.20, 0.16)
const OLIVE_DRAB := Color(0.30, 0.32, 0.20)
const KHAKI := Color(0.52, 0.46, 0.30)
const FELDGRAU := Color(0.34, 0.36, 0.32)
const MUD := Color(0.20, 0.15, 0.09)
const RUST := Color(0.50, 0.26, 0.10)
const STEEL := Color(0.26, 0.27, 0.25)
const STEEL_HI := Color(0.48, 0.50, 0.46)
const BRASS := Color(0.72, 0.56, 0.26)
const CORDITE := Color(0.16, 0.14, 0.11)
const PAPER := Color(0.82, 0.76, 0.58)
const INK := Color(0.10, 0.09, 0.07)
const MOON := Color(0.78, 0.82, 0.68)
const SODIUM := Color(0.84, 0.54, 0.16)
const BLOOD := Color(0.38, 0.10, 0.08)
const ARMBAND := Color(0.62, 0.14, 0.10)


static func night_grade(id: String, saving: bool = false) -> Color:
	var mild := 0.10 if saving else 0.0
	match id:
		"warehouse":
			return Color(0.92 + mild * 0.2, 0.66 + mild * 0.3, 0.38, 1.0)
		"pump":
			return Color(0.62 + mild, 0.68, 0.52, 1.0)
		"railcut":
			return Color(0.62 + mild, 0.64, 0.60, 1.0)
		"depot":
			return Color(0.94, 0.56 + mild * 0.3, 0.26, 1.0)
		"radio":
			return Color(0.58 + mild, 0.66, 0.62, 1.0)
		_:
			return Color(0.62 + mild, 0.68, 0.48, 1.0)


static func saving_contrast(c: Color) -> Color:
	## Power-saving still has to split wool from feldgrau without neon.
	return Color(
		clampf(c.r * 0.82 + 0.04, 0.0, 1.0),
		clampf(c.g * 0.88 + 0.02, 0.0, 1.0),
		clampf(c.b * 0.78, 0.0, 1.0),
		c.a
	)


static func floor_a(id: String) -> Color:
	match id:
		"warehouse":
			return Color(0.074, 0.058, 0.040)
		"pump":
			return Color(0.050, 0.056, 0.044)
		"railcut":
			return Color(0.056, 0.054, 0.048)
		"depot":
			return Color(0.076, 0.050, 0.030)
		"radio":
			return Color(0.046, 0.052, 0.050)
		_:
			return Color(0.056, 0.060, 0.044)


static func floor_b(id: String) -> Color:
	match id:
		"warehouse":
			return Color(0.058, 0.046, 0.032)
		"pump":
			return Color(0.040, 0.046, 0.038)
		"railcut":
			return Color(0.046, 0.044, 0.040)
		"depot":
			return Color(0.060, 0.040, 0.024)
		"radio":
			return Color(0.038, 0.044, 0.042)
		_:
			return Color(0.044, 0.048, 0.036)


static func op_wool(role: int) -> Color:
	match role:
		1:
			return Color(0.38, 0.36, 0.22)
		2:
			return Color(0.24, 0.28, 0.22)
		_:
			return Color(0.36, 0.34, 0.24)


static func enemy_feldgrau(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.46, 0.30, 0.16)
		"sneak":
			return Color(0.16, 0.18, 0.14)
		"echo":
			return Color(0.28, 0.32, 0.30)
		_:
			return Color(0.36, 0.34, 0.28)
