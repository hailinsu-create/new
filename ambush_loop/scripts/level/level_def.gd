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


static func catalog() -> Array:
	return [make_yard(), make_warehouse(), make_pump(), make_railcut(), make_depot()]


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


func teaching_note_for(route: String) -> String:
	## First authored teaching_note on this route, if any. SETUP legend only.
	for spec in spawn_schedule:
		if str(spec.get("route", "")) != route:
			continue
		var note := str(spec.get("teaching_note", "")).strip_edges()
		if note != "":
			return note
	return ""


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
		_:
			return "初阵"


static func make_yard() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "yard"
	l.atmosphere_id = "yard"
	l.title = "第1关 · 院子：交叉封锁"
	l.teaching = "夜巡小队从北门进院子，要在南闸汇合前切断。灰狼补主路巡卫，铁砧宽锥扫东箱侧翼，夜枭长窄锁出口。陷阱：只盯主路，侧翼奔袭会从东廊绕出。青弧朝向才有掩体减免，侧背全伤。"
	l.tutorial = "左卡选 灰狼/铁砧/夜枭（1/2/3）。点掩体部署；青弧=保护方向（来袭减伤 60%，侧背全伤）。黄锥是墙裁切后的真射界。夜枭部署后有淡青观察环（仅准备期）。A/D、右键或底栏↺↻调朝向，空格拉警报锁死。X 中止留情报。跑掉或全灭都穿梭并恢复上轮计划。红线=主路，橙线=侧翼。"
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
	l.ambush_zone = Rect2(320, 280, 400, 160)
	l.has_ammo_pack = false
	l.beat_kind = "ambush_zone"
	l.beat_text = "侧翼从东廊随后到"
	l.spawn_teaching = ["陷阱路线：橙线侧翼从东廊随后到 — 只锁红线主路会漏。"]
	return l


static func make_warehouse() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "warehouse"
	l.atmosphere_id = "warehouse"
	l.title = "第2关 · 仓道：弹药窗口"
	l.teaching = "弹药窗口：仓道里的夜班搬运队会把弹打空。过早开火是陷阱——铁砧最容易空，把弹包给他。东廊橙色油桶在敌人靠近时自动炸（伤及友军），别把灰狼塞进爆心。F 入伏再打，等他们走进黄区。"
	l.tutorial = "G 把唯一弹包交给已部署队员（空弹自动补一次，本轮不能转交）。F 切「入伏再打」，黄锥变暗，等敌人进黄色伏击区。东廊油桶是预置杀器：敌人踩近才在模拟里炸，执行中不能点爆。红=主路，橙=侧翼。X 中止留情报；时间轴只读。M 静音。"
	# East flank corridor — away from reference slots 1/3/5 so smoke stays a skill check.
	l.barrel_cell = Vector2i(32, 10)
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
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0, "teaching_note": "别站爆心"},
		{"id": 3, "route": "main", "delay": 1.2, "loot": 1},
		{"id": 4, "route": "flank", "delay": 1.6, "loot": 0},
	]
	l.ambush_zone = Rect2(360, 300, 360, 200)
	l.has_ammo_pack = true
	l.beat_kind = "barrel"
	l.beat_text = "油桶靠近才炸 · 别站爆心"
	l.spawn_teaching = ["陷阱路线：过早开火打空弹药，橙线侧翼从东廊漏出。"]
	return l


static func make_pump() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "pump"
	l.atmosphere_id = "pump"
	l.title = "第3关 · 泵站：关门之后"
	l.teaching = "泵站夜班要过东廊阀门。B 锁门不是稳赢——那是陷阱：侧翼奔袭在决策格改走西侧紫色备用接近，从你没罩住的侧背进来。重布青弧与夜枭锁线；铁砧侧背更危险。"
	l.tutorial = "B 切换锁门。锁上后东廊关闭，侧翼在决策格改走作者写好的紫色备用接近，不会自由寻路。青弧没罩住=全伤。夜枭锁出水口。红=主路，橙=侧翼（开），紫=关门后的陷阱接近。X 中止留情报；时间轴只读。M 静音。"
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
	# Locked door: west-then-south approach, never through machinery blocks.
	l.alternate_route_cells = [
		Vector2i(13, 3), Vector2i(13, 5), Vector2i(11, 8), Vector2i(11, 14),
		Vector2i(16, 17), Vector2i(24, 17), Vector2i(31, 17), Vector2i(31, 19)
	]
	l.door_cell = Vector2i(28, 6)
	l.door_blocks_route = "flank"
	l.decision_cell = Vector2i(13, 5)
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.6, "loot": 2, "teaching_note": "锁门改线"},
		{"id": 3, "route": "main", "delay": 1.0, "loot": 0},
	]
	l.ambush_zone = Rect2(300, 250, 420, 220)
	l.has_ammo_pack = true
	l.beat_kind = "decision"
	l.beat_text = "决策格 · 锁门改线"
	l.spawn_teaching = ["陷阱路线：锁门后橙线在决策格改走西侧紫备用接近。"]
	return l


static func make_railcut() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "railcut"
	l.atmosphere_id = "railcut"
	l.title = "第4关 · 信号楼：双走廊延迟"
	l.teaching = "信号楼要切断两路巡轨：西廊巡卫立刻出发，东廊奔袭晚几秒才折下来。陷阱是南闸堆人——先到的西廊把弹药打空，延迟东廊再漏。核心墙挡住对射，必须分廊锁线。绊索只能铺一条。"
	l.tutorial = "西廊立刻走脊，东廊从北过道晚到。核心设备挡住东西对射。铁砧朝北等东廊，灰狼补西廊，夜枭锁南闸。Tab 绊索一条走廊；G 弹包一人。没有门。红=西廊主路，橙=东廊延迟。X 中止留情报；时间轴只读。M 静音。"
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
	l.ambush_zone = Rect2(280, 240, 500, 280)
	l.has_ammo_pack = true
	l.beat_kind = "flank_delay"
	l.beat_text = "东廊延迟"
	l.spawn_teaching = ["东廊奔袭晚 3.8 秒才折下 — 南闸堆人会先被西廊打空弹药。"]
	return l


static func make_depot() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "depot"
	l.atmosphere_id = "depot"
	l.title = "第5关 · 油库：三路合围"
	l.teaching = "油库夜班三路合围：主路巡卫、东廊奔袭、西暗道影探。中间油罐挡住对射。陷阱是南闸堆人+忽略西暗道——先到的两路打空弹药，影探再从西夹缝漏。唯一绊索封暗道，弹包给铁砧。"
	l.tutorial = "西暗道晚几秒才从西墙夹缝南下。灰狼锁主路，铁砧朝北等东廊，夜枭看南闸；Tab 把唯一绊索铺在西暗道（7,11 一带）。G 弹包一人。没有门、没有油桶。红=主路，橙=东廊，绿=西暗道陷阱。X 中止留情报；时间轴只读。M 静音。"
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
			Vector2i(7, 16), Vector2i(16, 17), Vector2i(31, 17), Vector2i(31, 19)
		],
	}
	# Two on the spine immediately, east close behind, west alley delayed so a south-only stack dumps ammo first.
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0},
		{"id": 3, "route": "sneak", "delay": 2.2, "loot": 2, "ambush_window": 2.2, "teaching_note": "西夹缝"},
		{"id": 4, "route": "main", "delay": 0.9, "loot": 0},
	]
	l.ambush_zone = Rect2(260, 230, 520, 280)
	l.has_ammo_pack = true
	l.beat_kind = "sneak_delay"
	l.beat_text = "西暗道影探延迟"
	l.spawn_teaching = ["西暗道影探晚 2.2 秒 — 先到的主路/东廊会打空南闸，绊索封暗道。"]
	return l
