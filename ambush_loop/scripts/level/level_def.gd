class_name LevelDef
extends RefCounted

## Portrait mission definitions. The three maps share a 20x24 logical grid,
## but each teaches a different planning decision and uses its own geometry.

var level_id: String = "yard"
var title: String = "院子：交叉封锁"
var teaching: String = "掩体、射界与主/侧翼分工"
var cover_defs: Array = []
var routes: Dictionary = {}
var route_cells: Dictionary = {}
var spawn_schedule: Array = []
var escape_cell: Vector2i = Vector2i(9, 22)
var ambush_zone: Rect2 = Rect2()
var door_cell: Vector2i = Vector2i(-1, -1)
var door_blocks_route: String = ""
var alternate_route_cells: Array = []
var wall_extra: Array = []
var has_ammo_pack: bool = false
var tutorial: String = ""


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
	l.teaching = "用掩体与射界挡住主路和侧翼。"
	l.tutorial = "点队员卡选人，再点绿色掩体部署。左右按钮调射界，点地图瞄准只改变朝向；绊索可撤回，最后拉响警报。"
	l.escape_cell = Vector2i(9, 22)
	l.cover_defs = [
		{"cell": Vector2i(7, 5), "name": "西侧掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(9, 7), "name": "主路掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(11, 6), "name": "东侧箱", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(16, 10), "name": "侧翼掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(11, 15), "name": "中庭掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(8, 18), "name": "出口掩体", "face": 90.0, "protect": 270.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(9, 1), Vector2i(9, 5), Vector2i(9, 9), Vector2i(9, 13),
			Vector2i(9, 17), Vector2i(9, 22),
		],
		"flank": [
			Vector2i(10, 1), Vector2i(17, 1), Vector2i(17, 10), Vector2i(17, 17),
			Vector2i(17, 22), Vector2i(9, 22),
		],
	}
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 2},
		{"id": 2, "route": "main", "delay": 0.8, "loot": 0},
		{"id": 3, "route": "flank", "delay": 0.4, "loot": 2},
	]
	l.ambush_zone = Rect2(260, 320, 260, 190)
	return l


static func make_warehouse() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "warehouse"
	l.title = "第2关 · 仓道：弹药窗口"
	l.teaching = "入伏再打与稀缺补给：过早开火会空弹。"
	l.tutorial = "给一名队员分配备用弹包；把另一名设为入伏再打，再在黄色区域内让其开始射击。"
	l.escape_cell = Vector2i(10, 22)
	l.cover_defs = [
		{"cell": Vector2i(8, 5), "name": "仓门掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(9, 8), "name": "货架掩体", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(17, 6), "name": "侧廊掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(17, 11), "name": "装卸位", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(12, 16), "name": "南口掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(9, 19), "name": "闸口掩体", "face": 90.0, "protect": 270.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(9, 1), Vector2i(9, 6), Vector2i(9, 11), Vector2i(9, 16),
			Vector2i(10, 19), Vector2i(10, 22),
		],
		"flank": [
			Vector2i(10, 1), Vector2i(17, 1), Vector2i(17, 10), Vector2i(17, 16),
			Vector2i(17, 22), Vector2i(10, 22),
		],
	}
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 2},
		{"id": 2, "route": "flank", "delay": 0.5, "loot": 0},
		{"id": 3, "route": "main", "delay": 1.2, "loot": 2},
		{"id": 4, "route": "flank", "delay": 1.6, "loot": 0},
	]
	l.ambush_zone = Rect2(260, 300, 270, 250)
	l.has_ammo_pack = true
	return l


static func make_pump() -> LevelDef:
	var l := LevelDef.new()
	l.level_id = "pump"
	l.title = "第3关 · 泵站：关门之后"
	l.teaching = "锁门会改写侧翼接近方向，不是稳赢按钮。"
	l.tutorial = "门只在准备阶段可切换。锁门会封住东侧门格，侧翼改走西侧备用路线；警报后所有计划锁死。"
	l.escape_cell = Vector2i(10, 22)
	l.cover_defs = [
		{"cell": Vector2i(8, 5), "name": "泵房西", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(9, 8), "name": "阀廊", "face": 90.0, "protect": 270.0},
		{"cell": Vector2i(14, 7), "name": "东廊掩体", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(17, 12), "name": "管架", "face": 180.0, "protect": 0.0},
		{"cell": Vector2i(12, 16), "name": "侧背点", "face": 270.0, "protect": 90.0},
		{"cell": Vector2i(11, 19), "name": "出水口", "face": 90.0, "protect": 270.0},
	]
	l.route_cells = {
		"main": [
			Vector2i(11, 1), Vector2i(11, 6), Vector2i(11, 11), Vector2i(11, 17),
			Vector2i(11, 22), Vector2i(10, 22),
		],
		"flank": [
			Vector2i(10, 1), Vector2i(17, 1), Vector2i(17, 5), Vector2i(17, 10),
			Vector2i(17, 15), Vector2i(17, 19), Vector2i(17, 22), Vector2i(10, 22),
		],
	}
	l.alternate_route_cells = [
		Vector2i(10, 1), Vector2i(2, 1), Vector2i(2, 10), Vector2i(2, 17),
		Vector2i(6, 17), Vector2i(11, 17), Vector2i(11, 22), Vector2i(10, 22),
	]
	l.door_cell = Vector2i(17, 5)
	l.door_blocks_route = "flank"
	l.spawn_schedule = [
		{"id": 1, "route": "main", "delay": 0.0, "loot": 2},
		{"id": 2, "route": "flank", "delay": 0.6, "loot": 2},
		{"id": 3, "route": "main", "delay": 1.0, "loot": 0},
	]
	l.ambush_zone = Rect2(250, 280, 300, 260)
	l.has_ammo_pack = true
	return l
