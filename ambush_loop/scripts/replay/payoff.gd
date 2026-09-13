class_name PayoffCopy
extends RefCounted

## Presentation copy for deploy→alarm→watch juice. No sim, no damage numbers.


static func combo_window_ticks() -> int:
	return 48


static func bark_text(kind: String, name: String = "") -> String:
	var nm := name.strip_edges()
	if nm == "":
		nm = "队员"
	match kind:
		"contact":
			return "%s：接触" % nm
		"empty":
			return "%s：弹尽" % nm
		"last":
			return "%s：最后一个" % nm
		"kill":
			return "%s：倒了" % nm
		"loot":
			return "%s：搜到了" % nm
		"sweep":
			return "打扫战场"
		"wave":
			return "下一波"
		"crate":
			return "%s：有匣" % nm
		"mine_ready":
			return "%s：雷好了" % nm
		_:
			return ""


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
		"echo":
			if eid >= 1:
				return "灯塔回波到了 — 敌%d" % eid
			return "灯塔回波到了"
		"wave":
			var note := str(payload.get("note", "")).strip_edges()
			var route := str(payload.get("route", ""))
			if note != "":
				return "%s到了" % note
			if route == "sneak":
				return "暗道影探到了"
			if route == "echo":
				return "灯塔回波到了"
			if route == "flank":
				return "延迟侧翼到了"
			if eid >= 1:
				return "下一波到了 — 敌%d" % eid
			return "下一波到了"
		_:
			return str(payload.get("text", ""))


static func watching_color(kind: String) -> Color:
	match kind:
		"first_fire":
			return Color(1.0, 0.86, 0.38)
		"combo":
			return Color(1.0, 0.92, 0.45)
		"trip":
			return Color(0.52, 0.48, 0.28)
		"barrel":
			return Color(1.0, 0.55, 0.22)
		"ambush", "hold_mode", "repack":
			return Color(0.72, 0.62, 0.36)
		"route_choice":
			return Color(0.62, 0.42, 0.22)
		"pack_mg":
			return Color(0.52, 0.46, 0.24)
		"echo":
			return Color(0.70, 0.58, 0.32)
		"wave":
			return Color(0.95, 0.72, 0.32)
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
		"echo":
			return "回"
		"wave":
			return "波"
		_:
			return "★"


static func timeline_marks(log: Variant) -> Array:
	var out: Array = []
	if log == null or not log.has_method("first_of_type"):
		return out
	var first_fire: Dictionary = log.first_of_type("fire")
	if not first_fire.is_empty():
		var nm := str(first_fire.get("payload", {}).get("name", "")).strip_edges()
		out.append({
			"t": float(first_fire.get("tick", 0)) / 60.0,
			"kind": "first_fire",
			"label": "枪" if nm == "" else nm.substr(0, 1),
		})
	var combo_ticks: Array = _combo_peak_ticks(log)
	for t in combo_ticks:
		out.append({"t": float(t) / 60.0, "kind": "combo", "label": "连"})
	for typ in ["trip", "barrel", "ambush_armed", "repack", "route_choice"]:
		var ev: Dictionary = log.first_of_type(str(typ))
		if ev.is_empty():
			continue
		var kind: String = str(typ)
		if kind == "ambush_armed":
			kind = "ambush"
		out.append({
			"t": float(ev.get("tick", 0)) / 60.0,
			"kind": kind,
			"label": timeline_tag(kind),
		})
	return out


static func highlight_result_line(level: Variant, log: Variant, won: bool) -> String:
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


static func hook_hit(level: Variant, log: Variant) -> bool:
	if level == null or log == null:
		return false
	match str(level.level_id):
		"warehouse":
			return log.has_type("ambush_armed") or log.has_type("repack")
		"pump":
			return log.has_type("route_choice")
		"railcut":
			return _delayed_flank_shot(log, 3.8)
		"depot":
			return log.has_type("trip")
		"radio":
			return log.has_type("trip") and _delayed_flank_shot(log, 5.2)
		_:
			return log.has_type("fire")


static func leak_road_name(level: Variant, route: String, branched: bool = false) -> String:
	if branched:
		return "西侧紫备用接近"
	match route:
		"sneak":
			return "西暗道"
		"echo":
			return "碟台夹缝（晚 5.2 秒回波）"
		"flank":
			if level != null and str(level.level_id) == "railcut":
				return "东廊（晚 3.8 秒）"
			return "东廊"
		"alt":
			return "西侧紫备用接近"
		_:
			return "主路南闸"


static func max_kill_combo(log: Variant, window_ticks: int = -1) -> int:
	if log == null:
		return 0
	if log.has_method("max_kill_combo"):
		var win := window_ticks if window_ticks > 0 else combo_window_ticks()
		return int(log.max_kill_combo(win))
	return 0


static func _combo_peak_ticks(log: Variant) -> Array:
	var ticks: Array = []
	if log == null:
		return ticks
	var win := combo_window_ticks()
	var run := 0
	var last := -99999
	for raw in log.events:
		var ev: Dictionary = raw
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


static func _delayed_flank_shot(log: Variant, delay_sec: float) -> bool:
	if log == null:
		return false
	var min_tick := int(round(delay_sec * 60.0))
	for raw in log.events:
		var ev: Dictionary = raw
		if str(ev.get("type", "")) != "fire":
			continue
		if int(ev.get("tick", 0)) < min_tick:
			continue
		return true
	return false
