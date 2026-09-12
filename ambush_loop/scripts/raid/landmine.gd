class_name RaidMine
extends Node2D

## Player-placed mine from inventory. Sim-tick proximity, like tripwire.

signal triggered

const RADIUS := 20.0

var armed: bool = true
var spent: bool = false
var damage: float = 120.0
var _pulse_t: float = 0.0


func _ready() -> void:
	z_index = 3
	_ensure_visual()
	set_process(true)


func _ensure_visual() -> void:
	if get_node_or_null("Disc") != null:
		return
	var disc := Polygon2D.new()
	disc.name = "Disc"
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	disc.polygon = pts
	disc.color = Color(0.22, 0.20, 0.12, 0.95)
	add_child(disc)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	var rpts := PackedVector2Array()
	for i in 12:
		var ra := TAU * float(i) / 12.0
		rpts.append(Vector2(cos(ra), sin(ra)) * 6.4)
	rim.polygon = rpts
	rim.color = Color(0.16, 0.14, 0.08, 0.90)
	add_child(rim)
	var stud := Polygon2D.new()
	stud.name = "Stud"
	stud.polygon = PackedVector2Array([
		Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(2.2, 2.2), Vector2(-2.2, 2.2)
	])
	stud.color = Color(0.62, 0.22, 0.12, 0.95)
	add_child(stud)
	var plate := Polygon2D.new()
	plate.name = "Pressure"
	var ppts := PackedVector2Array()
	for i in 10:
		var pa := TAU * float(i) / 10.0
		ppts.append(Vector2(cos(pa), sin(pa)) * 4.4)
	plate.polygon = ppts
	plate.color = Color(0.42, 0.28, 0.10, 0.88)
	add_child(plate)
	var spider := Line2D.new()
	spider.name = "Spider"
	spider.width = 1.2
	spider.default_color = Color(0.18, 0.14, 0.08, 0.80)
	spider.points = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, 0), Vector2(0, -5), Vector2(0, 5)])
	add_child(spider)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "雷"
	tag.position = Vector2(-10, -20)
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.72, 0.52, 0.22))
	add_child(tag)


func _process(delta: float) -> void:
	_pulse_t += delta
	if spent or not armed:
		return
	var wave := 0.5 + 0.5 * sin(_pulse_t * 5.0)
	modulate = Color(1.0, 1.0, 1.0, 0.78 + 0.22 * wave)


func sim_check(active_enemies: Array) -> EnemyRunner:
	if not armed or spent:
		return null
	for node in active_enemies:
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= RADIUS:
				_trip(node)
				return node
	return null


func _trip(enemy: EnemyRunner) -> void:
	spent = true
	armed = false
	if enemy.has_method("apply_fire"):
		enemy.apply_fire(damage, null)
	elif enemy.has_method("kill"):
		enemy.kill()
	modulate = Color(0.4, 0.4, 0.38, 0.45)
	triggered.emit()
