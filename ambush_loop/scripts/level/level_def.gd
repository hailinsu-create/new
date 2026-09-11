class_name LevelDef
extends RefCounted

## In-code level definitions for the authored mission catalog (blueprint §6 + B1).

var level_id: String = "yard"
var atmosphere_id: String = "yard"
var title: String = "院子：交叉封锁"
var teaching: String = "掩体、射界与主/侧翼分工"
var cover_defs: Array = []
var routes: Dictionary = {} # name -> PackedVector2Array of cells as Vector2i arrays stored separately
var route_cells: Dictionary = {} # name -> Array[Vector2i]
var spawn_schedule: Array = [] # {id, route, delay, loot}
var escape_cell: Vector2i = Vector2i(31, 19)
var ambush_zone: Rect2 = Rect2() # world-space, for 入伏再打
var door_cell: Vector2i = Vector2i(-1, -1) # invalid = no door
var door_blocks_route: String = "" # which route is blocked when locked
var alternate_route_cells: Array = [] # used when door locked
## Authored fork: enemies on door_blocks_route switch to alt here when locked.
var decision_cell: Vector2i = Vector2i(-1, -1)
var wall_extra: Array = [] # extra blocked cells
var has_ammo_pack: bool = false
var tutorial: String = ""
## Authored explosive; (-1,-1) = none. Detonates on enemy proximity during sim_tick only.
var barrel_cell: Vector2i = Vector2i(-1, -1)
## Authored teaching beat (no new mechanics): ambush_zone | barrel | decision | flank_delay | sneak_delay
var beat_kind: String = ""
var beat_text: String = ""
## SETUP HUD one-liners (delayed flank/sneak timing, trap route). Not a sixth mission.
var spawn_teaching: Array = []
## One punchy beat the player should feel this mission. Copy only.
var highlight_hook: String = ""
## Why this squad, this map. Briefing + card why-line.
var must_bring: String = ""
var role_why: Dictionary = {} # rifle / mg / scout -> 本关短评
## Fail-loop "change one thing" sentence. Presentation only.
var fix_one: String = ""
## World paragraph for the briefing dossier. Copy only — not a mechanic.
var situation: String = ""
## Recovered radio chatter shown after a fail. Copy only.
var intel_chatter: Array = []
## Win debrief campaign beat. Copy only.
var campaign_beat: String = ""
## Raid: insertion cells for the three operators (walkable).
var insert_cells: Array = []
## Raid: authored crates {cell, kind, amount}.
var stashes: Array = []
## Raid: array of spawn_schedule arrays. Empty = one wave from spawn_schedule.
var waves: Array = []


func wave_count() -> int:
	if waves.is_empty():
		return 1
	return waves.size()


func spawns_for_wave(index: int) -> Array:
	if waves.is_empty():
		return spawn_schedule
	if index < 0 or index >= waves.size():
		return []
	return waves[index]


func insert_cell_for(op_index: int) -> Vector2i:
	if insert_cells.is_empty():
		return Vector2i(6, 16)
	return insert_cells[clampi(op_index, 0, insert_cells.size() - 1)]


static func campaign_frame() -> String:
	return "北区补给链 · 第三夜"


static func campaign_kicker() -> String:
	return "天亮前切断夜班巡线。搜刮组火力，埋伏拉警报，打扫带进下一波。"


static func chatter_for(id: String, reason: String = "") -> String:
	var def: LevelDef = by_id(id)
	if def.intel_chatter.is_empty():
		return ""
	var idx := 0
	match str(reason):
		"wipe":
			idx = mini(1, def.intel_chatter.size() - 1)
		"abort":
			idx = mini(2, def.intel_chatter.size() - 1)
		_:
			idx = 0
	return str(def.intel_chatter[idx]).strip_edges()


static func catalog() -> Array:
	return [make_yard(), make_warehouse(), make_pump(), make_railcut(), make_depot(), make_radio()]


static func by_id(id: String) -> LevelDef:
	for l in catalog():
		if l.level_id == id:
			return l
	return make_yard()


func first_route_delay(route: String) -> float:
	var best := INF
	for spec in spawn_schedule:
		if str(spec.get("route", "")) == route:
			best = minf(best, float(spec.get("delay", 0.0)))
	return 0.0 if best == INF else best


func delay_for_actor(id: int) -> float:
	for spec in spawn_schedule:
		if int(spec.get("id", 0)) == id:
			return float(spec.get("delay", 0.0))
	return 0.0


func teaching_note_for(route: String) -> String:
	## First authored teaching_note on this route, if any. SETUP legend only.
	for spec in spawn_schedule:
		if str(spec.get("route", "")) != route:
			continue
		var note := str(spec.get("teaching_note", "")).strip_edges()
		if note != "":
			return note
	return ""


func suggested_cover_name(role_id: int) -> String:
	## SETUP pad pulse. Presentation only.
	match str(level_id):
		"warehouse":
			match role_id:
				1:
					return "货架掩体"
				2:
					return "闸口掩体"
				_:
					return "仓门掩体"
		"pump":
			match role_id:
				1:
					return "侧背点"
				2:
					return "出水口"
				_:
					return "阀廊"
		"railcut":
			match role_id:
				1:
					return "东廊"
				2:
					return "南闸"
				_:
					return "西廊脊"
		"depot":
			match role_id:
				1:
					return "东廊"
				2:
					return "南闸"
				_:
					return "主路脊"
		"radio":
			match role_id:
				1:
					return "碟台"
				2:
					return "东廊"
				_:
					return "灯塔脊"
		_:
			match role_id:
				1:
					return "东箱掩体"
				2:
					return "出口掩体"
				_:
					return "西侧掩体"


func role_why_for(role_id: int) -> String:
	## Card / briefing one-liner. role_id matches OperatorUnit.Role (rifle=0, mg=1, scout=2).
	match role_id:
		1:
			return str(role_why.get("mg", "")).strip_edges()
		2:
			return str(role_why.get("scout", "")).strip_edges()
		_:
			return str(role_why.get("rifle", "")).strip_edges()


func route_spawn_marks() -> Array:
	## Authored spawn ticks for the debrief strip. Does not invent routes.
	var out: Array = []
	for spec in spawn_schedule:
		out.append({
			"route": str(spec.get("route", "main")),
			"delay": float(spec.get("delay", 0.0)),
			"id": int(spec.get("id", 0)),
		})
	return out


static func signature_color(id: String) -> Color:
	## Per-mission title/identity tint. Visual only — not a gameplay flag.
	match str(id):
		"warehouse":
			return Color(0.94, 0.68, 0.18) # amber
		"pump":
			return Color(0.18, 0.74, 0.70) # teal
		"railcut":
			return Color(0.92, 0.16, 0.16) # signal red
		"depot":
			return Color(0.98, 0.48, 0.10) # hazard orange
		"radio":
			return Color(0.38, 0.78, 0.96) # phosphor
		_:
			return Color(0.62, 0.74, 0.32) # olive


static func mood_tag(id: String) -> String:
	match str(id):
		"warehouse":
			return "深仓"
		"pump":
			return "闸站"
		"railcut":
			return "信号"
		"depot":
			return "油库"
		"radio":
			return "终夜"
		_:
			return "初阵"


static func operation_codename(id: String) -> String:
	## Briefing dossier header. Presentation only.
	match str(id):
		"warehouse":
			return "行动·深仓"
		"pump":
			return "行动·泵站"
		"railcut":
			return "行动·信号"
		"depot":
			return "行动·油库"
		"radio":
			return "行动·电台"
		_:
			return "行动·院子"


static func night_index(id: String) -> int:
	var cat: Array = catalog()
	for i in cat.size():
		if str(cat[i].level_id) == str(id):
			return i
	return 0


static func night_count() -> int:
	return catalog().size()


static func previous_campaign_beat(id: String) -> String:
	var idx := night_index(id)
	if idx <= 0:
		return ""
	return str(catalog()[idx - 1].campaign_beat).strip_edges()


static func chain_progress_line(just_cleared: String) -> String:
	## Win-debrief strip: 初阵✓ 深仓✓ → 下一夜：闸站
	var bits: PackedStringArray = PackedStringArray()
	var passed := true
	for def in catalog():
		var lid := str(def.level_id)
		if lid == just_cleared:
			bits.append("%s✓" % mood_tag(lid))
			passed = false
			continue
		if passed:
			bits.append("%s✓" % mood_tag(lid))
		else:
			bits.append("下一夜：%s" % mood_tag(lid))
			break
	return "  ".join(bits)


static func campaign_chain_names() -> String:
	return "院子 / 仓道 / 泵站 / 信号楼 / 油库 / 电台"


static func campaign_recap_body() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s 全部封锁。" % campaign_chain_names())
	for def in catalog():
		var beat := str(def.campaign_beat).strip_edges()
		if beat != "":
			lines.append("%s — %s" % [def.title, beat])
	lines.append("")
	lines.append("北区补给链第三夜已切断。灯塔停转。情报已归档。搜刮、埋伏、打扫过的那些波次，就是这场胜负。")
	lines.append("")
	lines.append("感谢游玩。")
	return "\n".join(lines)


static func handoff_title(from_id: String, to_id: String) -> String:
	## Letterbox kicker between nights. Presentation only.
	return "第%d夜已封锁  ·  下一夜：%s" % [night_index(from_id) + 1, mood_tag(to_id)]


static func handoff_body(from_id: String, to_id: String) -> String:
	var from_def: LevelDef = by_id(from_id)
	var to_def: LevelDef = by_id(to_id)
	var beat := str(from_def.campaign_beat).strip_edges()
	var sit := str(to_def.situation).strip_edges()
	var hook := str(to_def.highlight_hook).strip_edges()
	var lines: PackedStringArray = PackedStringArray()
	if beat != "":
		lines.append(beat)
	lines.append("")
	lines.append("下一夜 · %s" % to_def.title)
	if sit != "":
		lines.append(sit)
	if hook != "":
		lines.append("高光 · %s" % hook)
	var must := str(to_def.must_bring).strip_edges()
	if must != "":
		lines.append("必须带 · %s" % must)
	return "\n".join(lines)


static func handoff_cta(to_id: String) -> String:
	return "进入%s" % mood_tag(to_id)


func kit_for_actor(id: int) -> String:
	for spec in spawn_schedule:
		if int(spec.get("id", 0)) == id:
			return str(spec.get("kit", "")).strip_edges()
	return ""


func second_trap_text() -> String:
	## SETUP second-layer callout. Copy only — does not change routes.
	match str(level_id):
		"warehouse":
			return "第二层：等黄区再打（F 入伏）"
		"pump":
			return "第二层：锁门后改走紫线"
		"railcut":
			return "第二层：南闸堆人会被西廊打空"
		"depot":
			return "第二层：东廊先到，南闸会空"
		"radio":
			return "第二层：暗道 3.6s 要绊索"
		_:
			return "第二层：橙线东廊绕出"


func second_trap_cell() -> Vector2i:
	match str(level_id):
		"warehouse":
			return Vector2i(17, 12)
		"pump":
			return door_cell if door_cell.x >= 0 else Vector2i(28, 6)
		"railcut":
			return Vector2i(29, 17)
		"depot":
			return Vector2i(32, 11)
		"radio":
			return Vector2i(7, 11)
		_:
			return Vector2i(32, 11)


func second_trap_route() -> String:
	## Authored route the second-layer trap actually walks. SETUP overlay only.
	match str(level_id):
		"warehouse":
			return "flank"
		"pump":
			return "alt"
		"railcut":
			return "flank"
		"depot":
			return "sneak"
		"radio":
			return "sneak"
		_:
			return "flank"


static func make_yard() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "yard"
	l.atmosphere_id = "yard"
	l.title = "第1关 · 院子：交叉封锁"
	l.teaching = "这关必须带铁砧扫东箱侧翼，灰狼补主路第一枪，夜枭长窄锁南闸。夜巡小队从北门进院子，要在南闸汇合前切断。陷阱：只盯主路，侧翼奔袭会从东廊绕出。青弧朝向才有掩体减免，侧背全伤。失败三种：逃逸、全灭、中止（X 留情报）。"
	l.tutorial = "三人从西插入点出发，开局只有刀。点地走路，走近匣拾步枪/机枪/手雷/地雷，点掩体趴下。空格拉第一波警报；清完打扫，空格拉第二波（橙线侧翼）。逃逸或全灭失败。红线=主路，橙线=侧翼。"
	l.escape_cell = Vector2i(31, 19)
	# All covers on open cells (yard crates leave spine / lanes free).
	l.cover_defs = [
		{"cell": Vector2i(7, 11), "name": "西侧掩体", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(15, 7), "name": "北廊掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(24, 7), "name": "东箱掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(25, 13), "name": "中庭掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(12, 15), "name": "南廊掩体", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(28, 16), "name": "出口掩体", "face": 180.0, "protect": 0.0},
	]
	# Waypoints stay off crates; south bend goes around (16-20,14-16).
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(13, 7), Vector2i(13, 11),
			Vector2i(13, 15), Vector2i(13, 17), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(16, 6), Vector2i(23, 6),
			Vector2i(32, 6), Vector2i(32, 11), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
		],
	}
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 2},
		{"id": 2, "route": "main", "delay": 0.8, "loot": 0},
		{"id": 3, "route": "flank", "delay": 0.4, "loot": 2, "teaching_note": "东廊绕出"},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 2},
			{"id": 2, "route": "main", "delay": 0.6, "loot": 0},
		],
		[
			{"id": 3, "route": "flank", "delay": 0.2, "loot": 2, "teaching_note": "东廊绕出"},
		],
	]
	l.insert_cells = [Vector2i(6, 16), Vector2i(7, 17), Vector2i(8, 17)]
	l.stashes = [
		{"cell": Vector2i(6, 12), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(26, 12), "kind": "mg", "amount": 12},
		{"cell": Vector2i(29, 16), "kind": "scout", "amount": 6},
		{"cell": Vector2i(11, 16), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(10, 13), "kind": "mine", "amount": 1},
		{"cell": Vector2i(23, 13), "kind": "ammo", "amount": 6},
		{"cell": Vector2i(6, 17), "kind": "pistol", "amount": 8},
	]
	l.ambush_zone = Rect2(320, 280, 400, 160)
	l.has_ammo_pack = false
	l.beat_kind = "ambush_zone"
	l.beat_text = "交叉封锁 · 侧翼从东廊随后到"
	l.highlight_hook = "交叉封锁第一枪"
	l.must_bring = "铁砧扫东箱侧翼，灰狼补主路第一枪，夜枭锁南闸。"
	l.role_why = {
		"rifle": "本关：主路第一枪",
		"mg": "本关：东箱扫橙线",
		"scout": "本关：长窄锁南闸",
	}
	l.fix_one = "改一处就能赢：把铁砧转到东箱扫橙线侧翼，灰狼继续锁主路。"
	l.spawn_teaching = [
		"陷阱路线：橙线侧翼从东廊随后到 — 只锁红线主路会漏。必须带铁砧扫东箱。",
		"第二层：只锁红线主路，东廊橙线会自己绕出。",
	]
	l.situation = "北门院子是补给链最外一圈。夜巡小队要从北门进南闸汇合，再转入仓区。切断这一班，内院才不会提前亮灯。"
	l.intel_chatter = [
		"北门呼叫：南闸还亮着。侧翼已从东廊出去。",
		"院子对讲：有人还在打。巡卫没回来。",
		"北门：行动中止。夜班改走备用时间。",
	]
	l.campaign_beat = "院子已静。仓道的夜班还不知道外圈断了。"
	return l


static func make_warehouse() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "warehouse"
	l.atmosphere_id = "warehouse"
	l.title = "第2关 · 仓道：弹药窗口"
	l.teaching = "这关弹包给铁砧，F 入伏再打才有弹药窗口。仓道里的夜班搬运队会把弹打空。过早开火是陷阱——铁砧最容易空。东廊橙色油桶在敌人靠近时自动炸（伤及友军），别把灰狼塞进爆心。参考：铁砧拿弹包看窗口，夜枭锁闸口。"
	l.tutorial = "G 把唯一弹包交给已部署队员（空弹自动补一次，本轮不能转交；铁砧优先）。F 切「入伏再打」，黄锥变暗，等敌人进黄色伏击区——打中这个窗口才爽。东廊油桶是预置杀器：敌人踩近才在模拟里炸，执行中不能点爆。红=主路，橙=侧翼。X 中止留情报；时间轴只读。M 静音。"
	# Next to 侧廊, not on flank waypoint (32,10). Blast is a deploy don't, not an auto-kill.
	l.barrel_cell = Vector2i(22, 8)
	l.escape_cell = Vector2i(31, 19)
	# Covers sit only in walkable corridor cells for warehouse shelves.
	l.cover_defs = [
		{"cell": Vector2i(11, 8), "name": "仓门掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(15, 12), "name": "货架掩体", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(22, 7), "name": "侧廊掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(28, 14), "name": "装卸位", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(18, 16), "name": "南口掩体", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(29, 17), "name": "闸口掩体", "face": 180.0, "protect": 0.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 6), Vector2i(13, 10), Vector2i(13, 14),
			Vector2i(13, 17), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(18, 5), Vector2i(24, 5),
			Vector2i(32, 5), Vector2i(32, 10), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
		],
	}
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0, "teaching_note": "东廊侧翼"},
		{"id": 3, "route": "main", "delay": 1.2, "loot": 1},
		{"id": 4, "route": "flank", "delay": 1.6, "loot": 0},
		{"id": 5, "route": "flank", "delay": 2.4, "loot": 0},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
			{"id": 3, "route": "main", "delay": 0.8, "loot": 1},
		],
		[
			{"id": 2, "route": "flank", "delay": 0.3, "loot": 0, "teaching_note": "东廊侧翼"},
			{"id": 4, "route": "flank", "delay": 0.9, "loot": 0},
			{"id": 5, "route": "flank", "delay": 1.4, "loot": 2},
		],
	]
	l.insert_cells = [Vector2i(10, 16), Vector2i(11, 17), Vector2i(12, 16)]
	l.stashes = [
		{"cell": Vector2i(11, 7), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(16, 13), "kind": "mg", "amount": 12},
		{"cell": Vector2i(29, 16), "kind": "scout", "amount": 6},
		{"cell": Vector2i(27, 13), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(10, 13), "kind": "mine", "amount": 1},
		{"cell": Vector2i(23, 6), "kind": "ammo", "amount": 8},
	]
	l.ambush_zone = Rect2(360, 300, 360, 200)
	l.has_ammo_pack = true
	l.beat_kind = "barrel"
	l.beat_text = "入伏再打 · 油桶靠近才炸 · 别站爆心"
	l.highlight_hook = "入伏再打，弹包续上"
	l.must_bring = "铁砧拿唯一弹包；过早开火会空。夜枭锁闸口。"
	l.role_why = {
		"rifle": "本关：别站爆心",
		"mg": "本关：弹包优先 · 入伏再打",
		"scout": "本关：长窄锁闸口",
	}
	l.fix_one = "改一处就能赢：F 入伏再打，G 把弹包给铁砧，别在仓口见敌就打。"
	l.spawn_teaching = [
		"陷阱路线：过早开火打空弹药，橙线侧翼从东廊漏出。弹包给铁砧。",
		"第二层：等黄区再打（F 入伏），不是站爆心外。",
	]
	l.situation = "仓道是夜班搬运队的弹药窗。货架挡住对射，东廊还堆着他们自己的油桶。过早开火会把弹打空，侧翼就从爆心外漏。"
	l.intel_chatter = [
		"仓班：有人提前开枪。东廊油桶还在，侧翼已绕出。",
		"装卸口：搬运队还在还击。弹窗已经乱了。",
		"仓班：中止。油桶留给下一班。",
	]
	l.campaign_beat = "仓道熄灯。泵站的阀还在转，水还在往油库压。"
	return l


static func make_pump() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "pump"
	l.atmosphere_id = "pump"
	l.title = "第3关 · 泵站：关门之后"
	l.teaching = "这关夜枭锁出水口；锁门后铁砧必须把侧背对准紫线。泵站夜班要过东廊阀门。B 锁门不是稳赢——那是陷阱：侧翼奔袭在决策格改走西侧紫色备用接近，从你没罩住的侧背进来。开锁两条线都能解，锁门必须改朝向。"
	l.tutorial = "B 切换锁门。锁上后东廊关闭，侧翼在决策格改走作者写好的紫色备用接近，不会自由寻路。青弧没罩住=全伤。夜枭锁出水口；铁砧侧背对准紫线才是这关的爽点。G 弹包一人。红=主路，橙=侧翼（开），紫=关门后的陷阱接近。X 中止留情报；时间轴只读。M 静音。"
	l.escape_cell = Vector2i(31, 19)
	l.cover_defs = [
		{"cell": Vector2i(10, 8), "name": "泵房西", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(14, 7), "name": "阀廊", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(23, 8), "name": "东廊掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(21, 14), "name": "管架", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(27, 12), "name": "侧背点", "face": 270.0, "protect": 90.0},
		{"cell": Vector2i(29, 17), "name": "出水口", "face": 180.0, "protect": 0.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 6), Vector2i(13, 11), Vector2i(13, 15),
			Vector2i(16, 17), Vector2i(22, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(20, 6), Vector2i(28, 6),
			Vector2i(32, 6), Vector2i(32, 12), Vector2i(31, 17), Vector2i(31, 19)
		],
	}
	# Locked door: west approach, then (22,14) where 铁砧 facing west can cut.
	# Suffix then runs (30,16) so the old east facing and mouth scout miss.
	l.alternate_route_cells = [
		Vector2i(13, 3), Vector2i(13, 5), Vector2i(9, 8), Vector2i(9, 14),
		Vector2i(22, 14), Vector2i(30, 16), Vector2i(31, 19)
	]
	l.door_cell = Vector2i(28, 6)
	l.door_blocks_route = "flank"
	l.decision_cell = Vector2i(13, 5)
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.6, "loot": 2, "teaching_note": "锁门改线"},
		{"id": 3, "route": "main", "delay": 1.0, "loot": 0},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
			{"id": 3, "route": "main", "delay": 0.7, "loot": 0},
		],
		[
			{"id": 2, "route": "flank", "delay": 0.3, "loot": 2, "teaching_note": "锁门改线"},
		],
	]
	l.insert_cells = [Vector2i(10, 16), Vector2i(11, 17), Vector2i(12, 16)]
	l.stashes = [
		{"cell": Vector2i(10, 12), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(22, 13), "kind": "mg", "amount": 12},
		{"cell": Vector2i(29, 16), "kind": "scout", "amount": 6},
		{"cell": Vector2i(16, 8), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(9, 12), "kind": "mine", "amount": 1},
		{"cell": Vector2i(23, 16), "kind": "ammo", "amount": 6},
	]
	l.ambush_zone = Rect2(300, 250, 420, 220)
	l.has_ammo_pack = true
	l.beat_kind = "decision"
	l.beat_text = "决策格 · 锁门改线 · 紫线要罩住"
	l.highlight_hook = "锁门后紫线改道被你罩住"
	l.must_bring = "夜枭锁出水口；铁砧侧背对准西侧紫线。"
	l.role_why = {
		"rifle": "本关：阀廊补主路",
		"mg": "本关：侧背对准紫线",
		"scout": "本关：锁出水口",
	}
	l.fix_one = "改一处就能赢：锁门后把青弧转向西侧紫备用接近，夜枭锁出水口。"
	l.spawn_teaching = [
		"陷阱路线：锁门后橙线在决策格改走西侧紫备用接近。夜枭锁出水口。",
		"第二层：锁门不是把人关没，紫线要从侧背罩住。",
	]
	l.situation = "泵站给油库压水。夜班要过东廊阀门；锁门不是把他们关没，是逼他们在决策格改走西侧备用管廊。"
	l.intel_chatter = [
		"阀廊：东门关上了。改走西管。出水口还没人守。",
		"泵房：有交火。备用接近还通。",
		"泵站：中止。阀门保持夜班状态。",
	]
	l.campaign_beat = "泵停了。信号楼还在调度西廊和东廊的巡轨。"
	return l


static func make_railcut() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "railcut"
	l.atmosphere_id = "railcut"
	l.title = "第4关 · 信号楼：双走廊延迟"
	l.teaching = "这关必须带铁砧朝北等 3.8 秒东廊。信号楼要切断两路巡轨：西廊巡卫立刻出发，东廊奔袭晚 3.8 秒才折下来。陷阱是南闸堆人——先到的西廊把弹药打空，延迟东廊再漏。核心墙挡住对射，必须分廊锁线。绊索只能铺一条。"
	l.tutorial = "西廊立刻走脊，东廊从北过道晚 3.8 秒才到。核心设备挡住东西对射。铁砧朝北等东廊——等住这一枪才爽。灰狼补西廊，夜枭锁南闸。Tab 绊索一条走廊；G 弹包一人。没有门。红=西廊主路，橙=东廊延迟。X 中止留情报；时间轴只读。M 静音。"
	l.escape_cell = Vector2i(31, 19)
	# Six slots on open cells: west spine, east corridor, south mouth. No door (pump already teaches B).
	l.cover_defs = [
		{"cell": Vector2i(11, 8), "name": "西窗", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(13, 12), "name": "西廊脊", "face": 270.0, "protect": 270.0},
		{"cell": Vector2i(15, 16), "name": "南折", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(22, 6), "name": "北过道", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(32, 11), "name": "东廊", "face": 270.0, "protect": 270.0},
		{"cell": Vector2i(29, 17), "name": "南闸", "face": 180.0, "protect": 0.0},
	]
	# Main: west spine then south lane to the shared mouth. Flank: north lane then east spine.
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(13, 9), Vector2i(13, 13),
			Vector2i(13, 16), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(20, 5), Vector2i(28, 5),
			Vector2i(32, 5), Vector2i(32, 10), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
		],
	}
	# Delayed east pair: first wave is west-only; dumping all fire at the mouth empties ammo / misses the east spine.
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "main", "delay": 0.7, "loot": 0},
		{"id": 3, "route": "flank", "delay": 3.8, "loot": 2, "ambush_window": 3.8, "teaching_note": "晚到东廊"},
		{"id": 4, "route": "flank", "delay": 4.6, "loot": 0, "ambush_window": 3.8},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
			{"id": 2, "route": "main", "delay": 0.6, "loot": 0},
		],
		[
			{"id": 3, "route": "flank", "delay": 0.4, "loot": 2, "teaching_note": "晚到东廊"},
			{"id": 4, "route": "flank", "delay": 1.0, "loot": 0},
		],
	]
	l.insert_cells = [Vector2i(11, 16), Vector2i(12, 17), Vector2i(14, 16)]
	l.stashes = [
		{"cell": Vector2i(11, 10), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(32, 13), "kind": "mg", "amount": 12},
		{"cell": Vector2i(29, 16), "kind": "scout", "amount": 6},
		{"cell": Vector2i(16, 17), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(7, 11), "kind": "mine", "amount": 1},
		{"cell": Vector2i(22, 16), "kind": "ammo", "amount": 6},
	]
	l.ambush_zone = Rect2(280, 240, 500, 280)
	l.has_ammo_pack = true
	l.beat_kind = "flank_delay"
	l.beat_text = "东廊延迟 3.8s · 铁砧等住"
	l.highlight_hook = "3.8s 东廊迟到，铁砧等住"
	l.must_bring = "铁砧朝北等 3.8 秒东廊；灰狼补西廊；夜枭锁南闸。"
	l.role_why = {
		"rifle": "本关：西廊立刻到",
		"mg": "本关：朝北等 3.8s 东廊",
		"scout": "本关：南闸防漏",
	}
	l.fix_one = "改一处就能赢：铁砧朝北等 3.8 秒东廊，别把弹药堆在南闸。"
	l.spawn_teaching = [
		"东廊奔袭晚 3.8 秒才折下 — 南闸堆人会先被西廊打空弹药。铁砧朝北等。",
		"第二层：西廊立刻到，弹药留给 3.8 秒东廊。",
	]
	l.situation = "信号楼把西廊巡轨和东廊检修错开。东廊那班晚 3.8 秒才折下来——他们以为灯塔还亮着，南闸可以一起汇合。"
	l.intel_chatter = [
		"信号楼：西廊先到，东廊还在北过道。南闸弹药已经空了。",
		"巡轨：塔下有交火。东廊仍按 3.8 走。",
		"信号楼：中止。时刻表不改。",
	]
	l.campaign_beat = "双廊切断。油库的三路夜班还按旧表走。"
	return l


static func make_depot() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "depot"
	l.atmosphere_id = "depot"
	l.title = "第5关 · 油库：三路合围"
	l.teaching = "油库夜班三路合围：主路巡卫、东廊奔袭、西暗道影探（晚 2.2 秒）。中间油罐挡住对射。陷阱是南闸堆人+忽略西暗道——先到的两路打空弹药，影探再从西夹缝漏。唯一绊索封西暗道（7,11 一带），弹包给铁砧。绊索就是第四人。"
	l.tutorial = "三路合围。西暗道晚 2.2 秒才从西墙夹缝南下。灰狼锁主路，铁砧朝北等东廊，夜枭看南闸；Tab 把唯一绊索铺在西暗道（7,11 一带）——抽中这一下才爽。G 弹包一人。没有门、没有油桶。红=主路，橙=东廊，绿=西暗道陷阱。X 中止留情报；时间轴只读。M 静音。"
	l.escape_cell = Vector2i(31, 19)
	l.cover_defs = [
		{"cell": Vector2i(6, 10), "name": "西暗道", "face": 0.0, "protect": 0.0},
		{"cell": Vector2i(13, 12), "name": "主路脊", "face": 270.0, "protect": 270.0},
		{"cell": Vector2i(15, 16), "name": "南折", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(22, 6), "name": "北过道", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(32, 11), "name": "东廊", "face": 270.0, "protect": 270.0},
		{"cell": Vector2i(29, 17), "name": "南闸", "face": 180.0, "protect": 0.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(13, 9), Vector2i(13, 13),
			Vector2i(13, 16), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(20, 5), Vector2i(28, 5),
			Vector2i(32, 5), Vector2i(32, 10), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
		],
		"sneak": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(7, 5), Vector2i(7, 11),
			Vector2i(7, 16), Vector2i(14, 15), Vector2i(24, 15), Vector2i(31, 15),
			Vector2i(31, 19)
		],
	}
	# Two on the spine immediately, east close behind, west alley delayed so a south-only stack dumps ammo first.
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0},
		{"id": 3, "route": "sneak", "delay": 2.2, "loot": 2, "ambush_window": 2.2, "teaching_note": "西夹缝"},
		{"id": 4, "route": "main", "delay": 0.9, "loot": 0},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
			{"id": 4, "route": "main", "delay": 0.6, "loot": 0},
			{"id": 2, "route": "flank", "delay": 0.4, "loot": 0},
		],
		[
			{"id": 3, "route": "sneak", "delay": 0.4, "loot": 2, "teaching_note": "西夹缝"},
		],
	]
	l.insert_cells = [Vector2i(6, 16), Vector2i(7, 17), Vector2i(8, 16)]
	l.stashes = [
		{"cell": Vector2i(13, 16), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(32, 13), "kind": "mg", "amount": 12},
		{"cell": Vector2i(29, 16), "kind": "scout", "amount": 6},
		{"cell": Vector2i(15, 15), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(7, 12), "kind": "mine", "amount": 1},
		{"cell": Vector2i(22, 16), "kind": "shotgun", "amount": 4},
		{"cell": Vector2i(6, 8), "kind": "decoy", "amount": 1},
	]
	l.ambush_zone = Rect2(260, 230, 520, 280)
	l.has_ammo_pack = true
	l.beat_kind = "sneak_delay"
	l.beat_text = "西暗道 2.2s · 绊索抽中"
	l.highlight_hook = "2.2s 西暗道绊索抽中"
	l.must_bring = "绊索就是第四人：铺在西暗道 7,11。铁砧等东廊，灰狼锁主路。"
	l.role_why = {
		"rifle": "本关：锁主路脊",
		"mg": "本关：朝北等东廊",
		"scout": "本关：南闸看口",
	}
	l.fix_one = "改一处就能赢：Tab 绊索铺在西暗道（7,11），等 2.2 秒影探自己踩上。"
	l.spawn_teaching = [
		"西暗道影探晚 2.2 秒 — 先到的主路/东廊会打空南闸，绊索封暗道。",
		"第二层：绊索只封暗道，东廊还要铁砧朝北等。",
	]
	l.situation = "油库是这条链的心脏。巡卫走主路，奔袭走东廊，影探晚 2.2 秒钻西夹缝。中间油罐挡住对射，三人锁不住三条——绊索才是第四人。"
	l.intel_chatter = [
		"油库：西暗道没人守。影探已从夹缝南下。",
		"罐区：南闸还在打。西墙有人。",
		"油库：中止。油罐灯还亮。",
	]
	l.campaign_beat = "油库熄火。电台还能把下一班叫回来——灯塔还在扫。"
	return l


static func make_radio() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "radio"
	l.atmosphere_id = "radio"
	l.title = "第6关 · 电台：灯塔回波"
	l.teaching = "油库切断后，电台还能把下一班叫回来。主路巡卫走灯塔脊，东廊奔袭先到一班，西暗道影探晚 3.6 秒，灯塔回波再在 5.2 秒走碟台夹缝——不是东廊那一枪。陷阱是不铺绊索：影探先从西夹缝漏。铁砧要在碟台朝南等回波，夜枭锁东廊。"
	l.tutorial = "终夜。四条作者路：红主路、橙东廊、绿暗道、青回波。西暗道晚 3.6 秒，回波晚 5.2 秒走碟台夹缝（x=24），不是东廊。灰狼锁灯塔脊，铁砧碟台朝南等回波，夜枭朝北锁东廊；Tab 绊索铺西暗道（7,11）。G 弹包一人。没有门、没有油桶。X 中止留情报；时间轴只读。M 静音。"
	l.escape_cell = Vector2i(31, 19)
	# Unique stations vs depot: 灯塔脊 / 碟台 / 东廊. 碟台 looks south down the echo hall.
	l.cover_defs = [
		{"cell": Vector2i(6, 10), "name": "西夹缝", "face": 0.0, "protect": 0.0},
		{"cell": Vector2i(13, 12), "name": "灯塔脊", "face": 270.0, "protect": 270.0},
		{"cell": Vector2i(15, 16), "name": "南折", "face": 0.0, "protect": 180.0},
		{"cell": Vector2i(29, 17), "name": "南闸", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(24, 6), "name": "碟台", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(32, 11), "name": "东廊", "face": 270.0, "protect": 270.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(13, 9), Vector2i(13, 13),
			Vector2i(13, 16), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
		"flank": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(20, 5), Vector2i(28, 5),
			Vector2i(32, 5), Vector2i(32, 10), Vector2i(32, 15), Vector2i(31, 17), Vector2i(31, 19)
		],
		"sneak": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(7, 5), Vector2i(7, 11),
			Vector2i(7, 16), Vector2i(14, 15), Vector2i(24, 15), Vector2i(31, 15),
			Vector2i(31, 19)
		],
		# Authored echo hall: the 1-cell gap at x=24 between core tanks and east annex.
		# 铁砧 on 东廊 facing north cannot see this path.
		"echo": [
			Vector2i(13, 3), Vector2i(13, 5), Vector2i(20, 5), Vector2i(24, 5),
			Vector2i(24, 8), Vector2i(24, 12), Vector2i(24, 15), Vector2i(31, 15),
			Vector2i(31, 19)
		],
	}
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0, "teaching_note": "东廊先到"},
		{"id": 3, "route": "sneak", "delay": 3.6, "loot": 2, "ambush_window": 3.6, "teaching_note": "西夹缝"},
		{"id": 4, "route": "main", "delay": 0.9, "loot": 0},
		{"id": 5, "route": "echo", "delay": 5.2, "loot": 0, "ambush_window": 5.2, "teaching_note": "灯塔回波", "kit": "echo"},
	]
	l.waves = [
		[
			{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
			{"id": 4, "route": "main", "delay": 0.6, "loot": 0},
			{"id": 2, "route": "flank", "delay": 0.4, "loot": 0, "teaching_note": "东廊先到"},
		],
		[
			{"id": 3, "route": "sneak", "delay": 0.4, "loot": 2, "teaching_note": "西夹缝"},
		],
		[
			{"id": 5, "route": "echo", "delay": 0.5, "loot": 2, "teaching_note": "灯塔回波", "kit": "echo"},
		],
	]
	l.insert_cells = [Vector2i(6, 16), Vector2i(7, 17), Vector2i(8, 16)]
	l.stashes = [
		{"cell": Vector2i(13, 16), "kind": "rifle", "amount": 7},
		{"cell": Vector2i(24, 16), "kind": "mg", "amount": 12},
		{"cell": Vector2i(32, 13), "kind": "scout", "amount": 6},
		{"cell": Vector2i(15, 15), "kind": "grenade", "amount": 2},
		{"cell": Vector2i(7, 12), "kind": "mine", "amount": 1},
		{"cell": Vector2i(22, 6), "kind": "decoy", "amount": 1},
		{"cell": Vector2i(29, 16), "kind": "ammo", "amount": 8},
	]
	l.ambush_zone = Rect2(260, 230, 520, 280)
	l.has_ammo_pack = true
	l.beat_kind = "radio_echo"
	l.beat_text = "灯塔回波 5.2s · 绊索封暗道"
	l.highlight_hook = "5.2s 灯塔回波，绊索抽中"
	l.must_bring = "绊索封西暗道 7,11；铁砧碟台朝南等 5.2 秒回波。夜枭锁东廊。"
	l.role_why = {
		"rifle": "本关：锁灯塔脊",
		"mg": "本关：碟台朝南等 5.2s 回波",
		"scout": "本关：东廊等先到侧翼",
	}
	l.fix_one = "改一处就能赢：Tab 绊索铺西暗道（7,11），等 3.6 秒影探自己踩上。"
	l.spawn_teaching = [
		"灯塔回波晚 5.2 秒走碟台夹缝 — 西暗道影探 3.6 秒先到。绊索封暗道，铁砧等回波。",
		"第二层：暗道 3.6s 要绊索。回波是修好暗道之后的下一刀。",
	]
	l.situation = "油库切断后，电台还亮着。灯塔一扫，下一班从碟台夹缝折下来，不是东廊那条。西暗道影探仍走夹缝。这一刀要叠：绊索是第四人，铁砧要在碟台等回波。"
	l.intel_chatter = [
		"电台：灯塔已扫过。回波按 5.2 走碟缝。西暗道没人守。",
		"报务：有交火。回波还在排。",
		"电台：中止。灯塔保持扫描。",
	]
	l.campaign_beat = "灯塔停转。北区补给链这一夜被切断。"
	return l
