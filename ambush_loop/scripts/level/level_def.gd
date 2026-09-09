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


static func catalog() -> Array:
	return [make_yard(), make_warehouse(), make_pump(), make_railcut(), make_depot()]


static func by_id(id: String) -> LevelDef:
	for l in catalog():
		if l.level_id == id:
			return l
	return make_yard()


static func make_yard() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "yard"
	l.atmosphere_id = "yard"
	l.title = "第1关 · 院子：交叉封锁"
	l.teaching = "步枪补漏主路、机枪宽锥扫面、侦察长窄锁出口。主路和侧翼都要有射界；青色扇形朝向才有掩体减免，侧背无减免。三角=友军，菱形=敌军。"
	l.tutorial = "左上角色卡选步枪手/机枪手/侦察兵（键盘 1/2/3）。点掩体部署；青色扇形=掩体保护方向（该方向来袭减伤 60%，侧背全伤）。黄锥是墙体裁切后的真实射界。侦察兵部署后有淡青「观察环」（仅准备期）。A/D、右键或底栏↺↻调朝向，空格或底栏警报。X / 底栏中止保留情报。手机返回键打开菜单。跑掉或全灭都会穿梭并恢复上轮计划。"
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
		{"id": 3, "route": "flank", "delay": 0.4, "loot": 2},
	]
	l.ambush_zone = Rect2(320, 280, 400, 160)
	l.has_ammo_pack = false
	return l


static func make_warehouse() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "warehouse"
	l.atmosphere_id = "warehouse"
	l.title = "第2关 · 仓道：弹药窗口"
	l.teaching = "F 入伏再打、G 弹包给最容易空的人；过早开火会空弹漏人。东廊橙色油桶在敌人靠近时自动引爆（伤及友军），不能在执行中点击引爆。"
	l.tutorial = "G 把「备用弹包」交给一名已部署队员（空弹自动补一次，本轮不能转交）。F 切「入伏再打」，等敌人进入黄色伏击区再开火。东廊格子上的橙色「油桶」是关卡预置：敌人踩近才炸，准备期只能预览爆心，注意别把队员放进爆破圈。角色射界与青弧保护方向仍决定谁能活。X 中止保留情报；时间轴复盘只读。M 静音。"
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
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0},
		{"id": 3, "route": "main", "delay": 1.2, "loot": 1},
		{"id": 4, "route": "flank", "delay": 1.6, "loot": 0},
	]
	l.ambush_zone = Rect2(360, 300, 360, 200)
	l.has_ammo_pack = true
	return l


static func make_pump() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "pump"
	l.atmosphere_id = "pump"
	l.title = "第3关 · 泵站：关门之后"
	l.teaching = "B 锁门会改写侧翼接近，不是稳赢按钮。关门后从西侧备用接近绕来，要重布保护弧与侦察锁线；侧背没罩住就是全伤。"
	l.tutorial = "B 切换锁门。锁门后东廊关闭，侧翼改走作者写好的紫色备用接近——敌人不会自由寻路。注意侧背：青弧没罩住的方向是全伤。机枪侧背更危险；侦察适合锁出口（准备期可见观察环）。X 中止保留情报；时间轴复盘只读。M 静音。"
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
		{"id": 2, "route": "flank", "delay": 0.6, "loot": 2},
		{"id": 3, "route": "main", "delay": 1.0, "loot": 0},
	]
	l.ambush_zone = Rect2(300, 250, 420, 220)
	l.has_ammo_pack = true
	return l


static func make_railcut() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "railcut"
	l.atmosphere_id = "railcut"
	l.title = "第4关 · 信号楼：双走廊延迟"
	l.teaching = "西廊先到、东廊延迟。核心墙挡住对向走廊，不能把三人全堆在南闸出口空弹；两条走廊都要有射界。绊索只能铺一条，弹包留给容易空的人。"
	l.tutorial = "西廊敌人立刻出发，东廊晚几秒才从北过道折下东廊。核心设备挡住东西对射，南闸一个人罩不住两条走廊。机枪适合锁东廊北向等延迟侧翼，步枪补西廊，侦察锁南闸防漏。Tab 绊索只能铺一条走廊；G 弹包一人。没有门。X 中止保留情报；时间轴复盘只读。M 静音。"
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
		{"id": 3, "route": "flank", "delay": 3.8, "loot": 2},
		{"id": 4, "route": "flank", "delay": 4.6, "loot": 0},
	]
	l.ambush_zone = Rect2(280, 240, 500, 280)
	l.has_ammo_pack = true
	return l


static func make_depot() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "depot"
	l.atmosphere_id = "depot"
	l.title = "第5关 · 油库：三路合围"
	l.teaching = "西暗道、主路、东廊同时有人。中间油罐挡住对射，三人罩不住三路，必须用唯一的绊索封一条；弹包留给容易空的人。"
	l.tutorial = "西暗道敌人晚几秒才从西墙夹缝南下。别把三人全堆南闸——先到的主路和东廊会把弹药打空，暗道再从西面漏。步枪锁主路，机枪朝北等东廊，侦察看南闸；Tab 把绊索铺在西暗道。G 弹包一人。没有门、没有油桶。X 中止保留情报；时间轴复盘只读。M 静音。"
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
		{"id": 3, "route": "sneak", "delay": 2.2, "loot": 2},
		{"id": 4, "route": "main", "delay": 0.9, "loot": 0},
	]
	l.ambush_zone = Rect2(260, 230, 520, 280)
	l.has_ammo_pack = true
	return l
