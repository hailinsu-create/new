extends Control

## Debrief strip + WATCHING live playhead. Authored spawn ticks as colored dots.

var marks: Array = []
var t_max: float = 1.0
var elapsed: float = 0.0
var live: bool = false
var preview_upcoming: int = 0
var payoff_marks: Array = [] # {t, kind, label} — watching / debrief highlight ticks
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


func upcoming_marks(n: int) -> Array:
	## Soonest authored spawns at or after elapsed. SETUP uses this for 下一波 dots.
	if n <= 0:
		return []
	var sorted: Array = marks.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		return float(a.get("delay", 0.0)) < float(b.get("delay", 0.0))
	)
	var out: Array = []
	for m in sorted:
		if float(m.get("delay", 0.0)) + 0.05 < elapsed:
			continue
		out.append(m)
		if out.size() >= n:
			break
	return out


func preview_count() -> int:
	return upcoming_marks(preview_upcoming).size()


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
	if preview_upcoming > 0 and not live:
		caption = "路线时间轴 · 下一波"
	draw_string(ThemeDB.fallback_font, Vector2(8, 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.84, 0.62, 0.9))
	var tmax := maxf(t_max, 0.5)
	if live:
		var px := 8.0 + (w - 16.0) * clampf(elapsed / tmax, 0.0, 1.0)
		draw_line(Vector2(px, y - 11), Vector2(px, y + 11), Color(0.95, 0.92, 0.55, 0.82), 1.5)
	var active := active_route() if live else ""
	var pulse := 0.5 + 0.5 * sin(_pulse * 7.2)
	var preview := upcoming_marks(preview_upcoming) if preview_upcoming > 0 and not live else []
	var preview_ids: Dictionary = {}
	for pm in preview:
		preview_ids[int(pm.get("id", -1))] = true
	var first_preview := true
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
		var is_preview := preview_ids.has(int(m.get("id", -2)))
		if is_active:
			draw_circle(Vector2(x, y), 8.2 + 3.2 * pulse, Color(col.r, col.g, col.b, 0.22 + 0.28 * pulse))
		elif is_preview:
			draw_circle(Vector2(x, y), 7.4, Color(col.r, col.g, col.b, 0.28))
		draw_circle(Vector2(x, y), 6.2 if (is_active or is_preview) else 5.5, col)
		draw_circle(Vector2(x, y), 6.2 if (is_active or is_preview) else 5.5, Color(0.05, 0.05, 0.04, 0.85), false, 1.1)
		var tag := "%s%.1f" % [lab, t]
		if is_preview and first_preview:
			tag = "下一波"
			first_preview = false
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 10, y + 16),
			tag,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			col.lightened(0.15)
		)
	_draw_payoff_marks(w, y, tmax, pulse)


func _draw_payoff_marks(w: float, y: float, tmax: float, pulse: float) -> void:
	if payoff_marks.is_empty() or w < 8.0:
		return
	for m in payoff_marks:
		var t := float(m.get("t", 0.0))
		var x := 8.0 + (w - 16.0) * clampf(t / tmax, 0.0, 1.0)
		var kind := str(m.get("kind", ""))
		var col := Color(1.0, 0.86, 0.38)
		match kind:
			"trip":
				col = Color(0.42, 0.92, 0.52)
			"barrel":
				col = Color(1.0, 0.55, 0.22)
			"ambush", "repack":
				col = Color(0.45, 0.88, 0.95)
			"route_choice":
				col = Color(0.78, 0.55, 1.0)
			"combo":
				col = Color(1.0, 0.92, 0.48)
		var r := 4.6 + (1.6 * pulse if live else 0.0)
		var diamond := PackedVector2Array([
			Vector2(x, y - 16.0 - r),
			Vector2(x + r, y - 16.0),
			Vector2(x, y - 16.0 + r),
			Vector2(x - r, y - 16.0),
		])
		draw_colored_polygon(diamond, Color(col.r, col.g, col.b, 0.92))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.05, 0.05, 0.04, 0.9), 1.0)
		var lab := str(m.get("label", "★"))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 6, y - 26),
			lab,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			col.lightened(0.12)
		)
