class_name MuzzleFlash
extends Node2D

## Brief scale+fade flash at a weapon muzzle. Presentation only.

func _ready() -> void:
	z_index = 8
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(4, 6), Vector2(-4, 2), Vector2(-4, -2), Vector2(4, -6)
	])
	glow.color = Color(1.0, 0.72, 0.22, 0.55)
	add_child(glow)
	var core := Polygon2D.new()
	core.name = "Core"
	core.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(3, 3.2), Vector2(-2, 1.4), Vector2(-2, -1.4), Vector2(3, -3.2)
	])
	core.color = Color(1.0, 0.96, 0.72, 1.0)
	add_child(core)
	scale = Vector2(0.42, 0.42)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.18), 0.04)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.chain().tween_callback(queue_free)


static func burst(host: Node2D, local_pos: Vector2, facing_rad: float, tint: Color = Color.WHITE) -> void:
	if host == null or not is_instance_valid(host):
		return
	var fx := (load("res://scripts/fx/muzzle_flash.gd") as GDScript).new() as MuzzleFlash
	fx.position = local_pos
	fx.rotation = facing_rad
	fx.modulate = tint
	host.add_child(fx)
