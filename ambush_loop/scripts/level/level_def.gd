class_name LevelDef
extends RefCounted

## In-code level definitions for the 3-mission vertical slice (blueprint §6).

var level_id: String = "yard"
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
var wall_extra: Array = [] # extra blocked cells
var has_ammo_pack: bool = false
var tutorial: String = ""
## Authored explosive; (-1,-1) = none. Detonates on enemy proximity during sim_tick only.
var barrel_cell: Vector2i = Vector2i(-1, -1)


static func catalog() -> Array:
	return [make_yard(), make_warehouse(), make_pump()]


static func by_id(id: String) -> LevelDef:
	for l in catalog():
		if l.level_id == id:
			return l
	return make_yard()


static func make_yard() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "yard"
	l.title = "第1关 · 院子：交叉封锁"
	l.teaching = "步枪补漏、机枪扫面、侦察锁线。主路和侧翼都要有射界；青色扇形朝向才有掩体减免，侧背无减免。"
	l.tutorial = "左上角色卡或 1/2/3 选步枪手/机枪手/侦察兵。点掩体部署；青色扇形=掩体保护方向（该方向来袭减伤 60%，侧背全伤）。黄锥是墙体裁切后的真实射界。A/D 或右键调朝向，空格拉警报。跑掉或全灭都会穿梭并恢复上轮计划。"
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
	l.title = "第2关 · 仓道：弹药窗口"
	l.teaching = "入伏再打与稀缺补给：过早开火会空弹。东廊橙色油桶在敌人靠近时自动引爆（伤及友军），不能在执行中点击引爆。"
	l.tutorial = "G 把「备用弹包」交给一名已部署队员（空弹自动补一次，本轮不能转交）。F 切「入伏再打」，等敌人进入黄色伏击区再开火。东廊格子上的橙色「油桶」是关卡预置：敌人踩近才炸，准备期只能预览爆心，注意别把队员放进爆破圈。"
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
	l.title = "第3关 · 泵站：关门之后"
	l.teaching = "锁门会改写侧翼接近方向，不是稳赢按钮。关门后从新方向接近，要重布保护弧与侦察锁线。"
	l.tutorial = "B 切换锁门。锁门后东廊关闭，侧翼改走作者写好的紫色备用接近——敌人不会自由寻路。注意侧背：青弧没罩住的方向是全伤。机枪侧背更危险；侦察适合锁出口。"
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
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 1},
		{"id": 2, "route": "flank", "delay": 0.6, "loot": 2},
		{"id": 3, "route": "main", "delay": 1.0, "loot": 0},
	]
	l.ambush_zone = Rect2(300, 250, 420, 220)
	l.has_ammo_pack = true
	return l
