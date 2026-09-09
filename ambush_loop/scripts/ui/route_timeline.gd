extends Control

## Debrief strip: authored spawn ticks as colored dots (main/flank/sneak).

var marks: Array = []
var t_max: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 40)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0:
		return
	var y := h * 0.58
	draw_line(Vector2(8, y), Vector2(w - 8, y), Color(0.55, 0.58, 0.42, 0.55), 2.0)
	var caption := "路线时间轴"
	draw_string(ThemeDB.fallback_font, Vector2(8, 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.84, 0.62, 0.9))
	var tmax := maxf(t_max, 0.5)
	for m in marks:
		var route := str(m.get("route", "main"))
		var t := float(m.get("delay", 0.0))
		var x := 8.0 + (w - 16.0) * clampf(t / tmax, 0.0, 1.0)
		var col := Color(0.92, 0.28, 0.22)
		var lab := "主"
		match route:
			"flank":
				col = Color(0.95, 0.55, 0.16)
				lab = "侧"
			"sneak":
				col = Color(0.38, 0.78, 0.52)
				lab = "暗"
		draw_circle(Vector2(x, y), 5.5, col)
		draw_circle(Vector2(x, y), 5.5, Color(0.05, 0.05, 0.04, 0.85), false, 1.1)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 10, y + 16),
			"%s%.1f" % [lab, t],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			col.lightened(0.15)
		)
