class_name PayoffCopy
extends RefCounted

## Presentation copy for deploy→alarm→watch juice. No sim, no damage numbers.


static func combo_window_ticks() -> int:
	return 48


static func first_shot_text(name: String, target_id: int) -> String:
	var nm := name.strip_edges()
	if nm == "":
		nm = "队员"
	if target_id >= 1:
		return "第一枪是%s → 敌%d" % [nm, target_id]
	return "第一枪是%s" % nm


static func watching_text(kind: String, payload: Dictionary = {}) -> String:
	var nm := str(payload.get("name", "")).strip_edges()
	var eid := int(payload.get("enemy_id", 0))
	match kind:
		"first_fire":
			return first_shot_text(nm, eid)
		"combo":
			var n := maxi(int(payload.get("combo", 2)), 2)
			return "击杀连击 ×%d" % n
		"trip":
			if eid >= 1:
				return "绊索抽中 敌%d — 你铺对了" % eid
			return "绊索抽中 — 你铺对了"
		"barrel":
			var hits := int(payload.get("hits", 0))
			if hits > 0:
				return "油桶炸到人 · %d" % hits
			return "油桶爆炸"
		"ambush":
			if nm != "":
				return "%s 入伏许可 — 现在打" % nm
			return "入伏许可 — 现在打"
		"repack":
			if nm != "":
				return "%s 弹包续上 — 窗口还在" % nm
			return "弹包续上 — 窗口还在"
		"route_choice":
			if bool(payload.get("covered", false)):
				return "紫线改道 — 被你罩住了"
			return "紫线改道 — 侧背还没罩住"
		"hold_mode":
			return "入伏再打 — 等他们走进黄区"
		"pack_mg":
			return "弹包给铁砧 — 这关就该这样"
		"pack_other":
			if nm != "":
				return "弹包给了%s（铁砧更耗弹）" % nm
			return "弹包已交（铁砧更耗弹）"
		_:
			return str(payload.get("text", ""))


static func watching_color(kind: String) -> Color:
	match kind:
		"first_fire":
			return Color(1.0, 0.86, 0.38)
		"combo":
			return Color(1.0, 0.92, 0.45)
		"trip":
			return Color(0.45, 0.95, 0.55)
		"barrel":
			return Color(1.0, 0.55, 0.22)
		"ambush", "hold_mode", "repack":
			return Color(0.45, 0.88, 0.95)
		"route_choice":
			return Color(0.78, 0.55, 1.0)
		"pack_mg":
			return Color(0.62, 0.88, 0.40)
		_:
			return Color(0.95, 0.82, 0.40)


static func hitch_for(kind: String) -> Vector2:
	match kind:
		"first_fire":
			return Vector2(3.2, -2.2)
		"combo":
			return Vector2(4.4, -3.0)
		"trip":
			return Vector2(6.0, -4.0)
		"route_choice":
			return Vector2(3.0, -2.0)
		"ambush", "repack":
			return Vector2(2.4, -1.6)
		_:
			return Vector2.ZERO


static func timeline_tag(kind: String) -> String:
	match kind:
		"first_fire":
			return "枪"
		"combo":
			return "连"
		"trip":
			return "绊"
		"barrel":
			return "桶"
		"ambush":
			return "伏"
		"repack":
			return "包"
		"route_choice":
			return "改"
		_:
			return "★"


static func timeline_marks(log) -> Array:
	var out: Array = []
	if log == null:
		return out
	var first_fire := log.first_of_type("fire")
	if not first_fire.is_empty():
		var nm := str(first_fire.get("payload", {}).get("name", "")).strip_edges()
		out.append({
			"t": float(first_fire.get("tick", 0)) / 60.0,
			"kind": "first_fire",
			"label": "枪" if nm == "" else nm.substr(0, 1),
		})
	var combo_ticks := _combo_peak_ticks(log)
	for t in combo_ticks:
		out.append({"t": float(t) / 60.0, "kind": "combo", "label": "连"})
	for typ in ["trip", "barrel", "ambush_armed", "repack", "route_choice"]:
		var ev := log.first_of_type(typ)
		if ev.is_empty():
			continue
		var kind := typ
		if typ == "ambush_armed":
			kind = "ambush"
		out.append({
			"t": float(ev.get("tick", 0)) / 60.0,
			"kind": kind,
			"label": timeline_tag(kind),
		})
	return out


static func highlight_result_line(level, log, won: bool) -> String:
	if level == null:
		return ""
	var hook := str(level.highlight_hook).strip_edges()
	if hook == "":
		return ""
	var hit := hook_hit(level, log)
	if won and hit:
		return "打中了：%s" % hook
	if won:
		return "本关高光：%s" % hook
	if hit:
		return "打中过：%s（还没封锁）" % hook
	return "没打中：%s" % hook


static func hook_hit(level, log) -> bool:
	if level == null or log == null:
		return false
	match str(level.level_id):
		"warehouse":
			return log.has_type("ambush_armed") or log.has_type("repack") or _barrel_hit_someone(log)
		"pump":
			return log.has_type("route_choice")
		"railcut":
			return _delayed_flank_shot(log, 3.8)
		"depot":
			return log.has_type("trip")
		_:
			return log.has_type("fire")


static func leak_road_name(level, route: String, branched: bool = false) -> String:
	if branched:
		return "西侧紫备用接近"
	match route:
		"sneak":
			return "西暗道"
		"flank":
			if level != null and str(level.level_id) == "railcut":
				return "东廊（晚 3.8 秒）"
			return "东廊"
		"alt":
			return "西侧紫备用接近"
		_:
			return "主路南闸"


static func max_kill_combo(log, window_ticks: int = -1) -> int:
	if log == null:
		return 0
	if log.has_method("max_kill_combo"):
		var win := window_ticks if window_ticks > 0 else combo_window_ticks()
		return int(log.max_kill_combo(win))
	return 0


static func _combo_peak_ticks(log) -> Array:
	var ticks: Array = []
	if log == null:
		return ticks
	var win := combo_window_ticks()
	var run := 0
	var last := -99999
	for ev in log.events:
		if str(ev.get("type", "")) != "kill":
			continue
		var t := int(ev.get("tick", 0))
		if t - last <= win and last >= 0:
			run += 1
		else:
			run = 1
		last = t
		if run == 2:
			ticks.append(t)
	return ticks


static func _barrel_hit_someone(log) -> bool:
	var ev := log.first_of_type("barrel")
	if ev.is_empty():
		return false
	return int(ev.get("payload", {}).get("hits", 0)) > 0


static func _delayed_flank_shot(log, delay_sec: float) -> bool:
	var min_tick := int(round(delay_sec * 60.0))
	for ev in log.events:
		if str(ev.get("type", "")) != "fire":
			continue
		if int(ev.get("tick", 0)) < min_tick:
			continue
		return true
	return false
