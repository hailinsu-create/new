class_name MuzzleFlash
extends Node2D

## Brief scale+fade flash at a weapon muzzle. Presentation only.
## intensity: rifle ~1, MG ~1.45, scout ~0.8. Heavy kits get a wider bloom.

var intensity: float = 1.0
var style: String = "rifle"


func _ready() -> void:
	z_index = 8
	var is_mg := style == "mg" or intensity >= 1.3
	var glow := Polygon2D.new()
	glow.name = "Glow"
	if is_mg:
		glow.polygon = PackedVector2Array([
			Vector2(18, 0), Vector2(6, 9), Vector2(-5, 3), Vector2(-5, -3), Vector2(6, -9)
		])
		glow.color = Color(1.0, 0.62, 0.16, 0.72)
	else:
		glow.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(4, 6), Vector2(-4, 2), Vector2(-4, -2), Vector2(4, -6)
		])
		glow.color = Color(1.0, 0.72, 0.22, 0.55)
	add_child(glow)
	var core := Polygon2D.new()
	core.name = "Core"
	if is_mg:
		core.polygon = PackedVector2Array([
			Vector2(13, 0), Vector2(4, 4.4), Vector2(-3, 1.8), Vector2(-3, -1.8), Vector2(4, -4.4)
		])
		core.color = Color(1.0, 0.98, 0.82, 1.0)
	else:
		core.polygon = PackedVector2Array([
			Vector2(10, 0), Vector2(3, 3.2), Vector2(-2, 1.4), Vector2(-2, -1.4), Vector2(3, -3.2)
		])
		core.color = Color(1.0, 0.96, 0.72, 1.0)
	add_child(core)
	if is_mg:
		var bloom := Polygon2D.new()
		bloom.name = "Bloom"
		bloom.polygon = PackedVector2Array([
			Vector2(8, 0), Vector2(2, 10), Vector2(-1, 2), Vector2(-1, -2), Vector2(2, -10)
		])
		bloom.color = Color(1.0, 0.85, 0.35, 0.35)
		add_child(bloom)
	var s0 := 0.42 * intensity
	var s1 := Vector2(1.4, 1.18) * intensity
	scale = Vector2(s0, s0)
	var tw := create_tween()
	tw.tween_property(self, "scale", s1, 0.04)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08 if not is_mg else 0.10)
	tw.chain().tween_callback(queue_free)


static func burst(
	host: Node2D,
	local_pos: Vector2,
	facing_rad: float,
	tint: Color = Color.WHITE,
	intensity: float = 1.0,
	style: String = "rifle"
) -> void:
	if host == null or not is_instance_valid(host):
		return
	var fx := (load("res://scripts/fx/muzzle_flash.gd") as GDScript).new() as MuzzleFlash
	fx.position = local_pos
	fx.rotation = facing_rad
	fx.modulate = tint
	fx.intensity = intensity
	fx.style = style
	host.add_child(fx)
