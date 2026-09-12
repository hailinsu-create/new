class_name RaidDecoy
extends Node2D

## Noise pebble. Nearby active enemies pause / face it for a short sim window.

var radius: float = 90.0
var life: float = 1.6
var spent: bool = false
var _t: float = 0.0


func setup(p_radius: float = 90.0, p_life: float = 1.6) -> void:
	radius = p_radius
	life = p_life
	spent = false
	z_index = 4
	_ensure_visual()


func _ensure_visual() -> void:
	if get_node_or_null("Pebble") != null:
		return
	var p := Polygon2D.new()
	p.name = "Pebble"
	p.polygon = PackedVector2Array([
		Vector2(-4, -3), Vector2(5, -2), Vector2(3, 4), Vector2(-5, 3)
	])
	p.color = Color(0.42, 0.36, 0.24, 0.95)
	var chip := Polygon2D.new()
	chip.name = "Chip"
	chip.polygon = PackedVector2Array([
		Vector2(-2, -1), Vector2(3, 0), Vector2(1, 2), Vector2(-3, 1)
	])
	chip.color = Color(0.32, 0.28, 0.18, 0.92)
	add_child(chip)
	add_child(p)
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 1.4
	ring.closed = true
	ring.default_color = Color(0.92, 0.82, 0.28, 0.55)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	if pts.size() > 0:
		pts.append(pts[0])
	ring.points = pts
	add_child(ring)


func sim_step(dt: float, enemies: Array) -> void:
	if spent:
		return
	life -= dt
	_t += dt
	var ring := get_node_or_null("Ring") as Line2D
	if ring:
		ring.modulate.a = 0.35 + 0.35 * sin(_t * 8.0)
		ring.scale = Vector2.ONE * (1.0 + 0.15 * sin(_t * 6.0))
	for node in enemies:
		if node is EnemyRunner and node.alive and node.active:
			if global_position.distance_to(node.global_position) <= radius:
				if node.has_method("distract"):
					node.distract(global_position, 0.35)
	if life <= 0.0:
		spent = true
		queue_free()
