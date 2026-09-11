class_name RaidGrenade
extends Node2D

## Thrown charge. Fuse ticks in sim_step only.

signal detonated(pos: Vector2, radius: float, damage: float)

var fuse: float = 0.55
var radius: float = 78.0
var damage: float = 78.0
var target: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var _flight: float = 0.0
var _flight_t: float = 0.18
var _done: bool = false
var _t: float = 0.0
var cooked: float = 0.0
var cook_max: float = 0.55
var bounced: bool = false


func setup(from: Vector2, to: Vector2, p_fuse: float = 0.55, p_radius: float = 78.0, p_dmg: float = 78.0) -> void:
	global_position = from
	_origin = from
	target = to
	fuse = p_fuse
	radius = p_radius
	damage = p_dmg
	_flight = 0.0
	_done = false
	z_index = 8
	_ensure_visual()


func _ensure_visual() -> void:
	if get_node_or_null("Body") != null:
		return
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-5, -4), Vector2(5, -4), Vector2(4, 6), Vector2(-4, 6)
	])
	body.color = Color(0.42, 0.48, 0.28, 0.96)
	add_child(body)
	var pin := Polygon2D.new()
	pin.name = "Pin"
	pin.polygon = PackedVector2Array([
		Vector2(-2, -8), Vector2(2, -8), Vector2(2, -4), Vector2(-2, -4)
	])
	pin.color = Color(0.82, 0.72, 0.28, 0.95)
	add_child(pin)


func sim_step(dt: float) -> bool:
	if _done:
		return true
	_t += dt
	if _flight < 1.0:
		_flight = minf(_flight + dt / maxf(_flight_t, 0.05), 1.0)
		var lift := sin(_flight * PI) * 18.0
		global_position = _origin.lerp(target, _flight) + Vector2(0, -lift)
		rotation = _t * 8.0
		return false
	if not bounced:
		bounced = true
		target += Vector2(8, 6)
		_flight = 0.55
		_flight_t = 0.10
		return false
	fuse -= dt
	cooked = 1.0 - clampf(fuse / maxf(cook_max, 0.05), 0.0, 1.0)
	global_position = target
	var pin := get_node_or_null("Pin") as Polygon2D
	if pin:
		pin.modulate = Color(1.0, 0.45 + 0.55 * cooked, 0.2, 1.0)
	if fuse <= 0.0:
		_detonate()
		return true
	return false


func _detonate() -> void:
	_done = true
	detonated.emit(global_position, radius, damage)
	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.55, 0.18, 0.95)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	if pts.size() > 0:
		pts.append(pts[0])
	ring.points = pts
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.8, 2.8), 0.18)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func spent() -> bool:
	return _done
