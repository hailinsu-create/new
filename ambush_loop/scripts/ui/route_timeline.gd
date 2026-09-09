extends Control

## Debrief strip + WATCHING live playhead. Authored spawn ticks as colored dots.

var marks: Array = []
var t_max: float = 1.0
var elapsed: float = 0.0
var live: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 40)


func set_live(on: bool) -> void:
	live = on
	set_process(on)
	if not on:
		_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not live:
		return
	_pulse += delta
	queue_redraw()


func active_route() -> String:
	## Latest authored spawn whose delay has been reached; else the first upcoming.
	var now := elapsed
	var best_t := -1.0
	var best := ""
	var next_t := INF
	var next_r := ""
	for m in marks:
		var t := float(m.get("delay", 0.0))
		var route := str(m.get("route", "main"))
		if t <= now + 0.05 and t >= best_t:
			best_t = t
			best = route
		elif t > now + 0.05 and t < next_t:
			next_t = t
			next_r = route
	if best != "":
		return best
	return next_r


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0:
		return
	var y := h * 0.58
	draw_line(Vector2(8, y), Vector2(w - 8, y), Color(0.55, 0.58, 0.42, 0.55), 2.0)
	var caption := "路线时间轴 · 观战" if live else "路线时间轴"
	draw_string(ThemeDB.fallback_font, Vector2(8, 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.84, 0.62, 0.9))
	var tmax := maxf(t_max, 0.5)
	if live:
		var px := 8.0 + (w - 16.0) * clampf(elapsed / tmax, 0.0, 1.0)
		draw_line(Vector2(px, y - 11), Vector2(px, y + 11), Color(0.95, 0.92, 0.55, 0.82), 1.5)
	var active := active_route() if live else ""
	var pulse := 0.5 + 0.5 * sin(_pulse * 7.2)
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
		var is_active := live and route == active
		if is_active:
			draw_circle(Vector2(x, y), 8.2 + 3.2 * pulse, Color(col.r, col.g, col.b, 0.22 + 0.28 * pulse))
		draw_circle(Vector2(x, y), 6.2 if is_active else 5.5, col)
		draw_circle(Vector2(x, y), 6.2 if is_active else 5.5, Color(0.05, 0.05, 0.04, 0.85), false, 1.1)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 10, y + 16),
			"%s%.1f" % [lab, t],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			col.lightened(0.15)
		)
