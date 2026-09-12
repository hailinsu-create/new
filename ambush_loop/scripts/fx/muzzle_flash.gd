class_name MuzzleFlash
extends Node2D

## Brief scale+fade flash at a weapon muzzle. Presentation only.
## intensity: rifle ~1, MG ~1.45, scout ~0.8. Heavy kits get a wider bloom.

var intensity: float = 1.0
var style: String = "rifle"


func _ready() -> void:
	z_index = 8
	var is_mg := style == "mg" or intensity >= 1.3
	var is_smg := style == "smg"
	var is_rifle := style == "rifle" and not is_mg and not is_smg
	var glow := Polygon2D.new()
	glow.name = "Glow"
	if is_mg:
		glow.polygon = PackedVector2Array([
			Vector2(30, 0), Vector2(9, 15), Vector2(-7, 4), Vector2(-7, -4), Vector2(9, -15)
		])
		glow.color = Color(1.0, 0.52, 0.16, 0.82)
	elif is_smg:
		glow.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(5, 5.2), Vector2(-3, 1.6), Vector2(-3, -1.6), Vector2(5, -5.2)
		])
		glow.color = Color(1.0, 0.70, 0.28, 0.70)
	elif style == "scout":
		glow.polygon = PackedVector2Array([
			Vector2(18, 0), Vector2(4, 3.6), Vector2(-3, 1.4), Vector2(-3, -1.4), Vector2(4, -3.6)
		])
		glow.color = Color(0.92, 0.86, 0.58, 0.55)
	else:
		glow.polygon = PackedVector2Array([
			Vector2(16, 0), Vector2(5, 7), Vector2(-4, 2), Vector2(-4, -2), Vector2(5, -7)
		])
		glow.color = Color(1.0, 0.68, 0.22, 0.58)
	add_child(glow)
	var core := Polygon2D.new()
	core.name = "Core"
	if is_mg:
		core.polygon = PackedVector2Array([
			Vector2(16, 0), Vector2(5, 5.4), Vector2(-3, 2.0), Vector2(-3, -2.0), Vector2(5, -5.4)
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
			Vector2(10, 0), Vector2(2, 14), Vector2(-2, 3), Vector2(-2, -3), Vector2(2, -14)
		])
		bloom.color = Color(1.0, 0.85, 0.35, 0.40)
		add_child(bloom)
	var s0 := (0.50 if is_rifle else 0.42) * intensity
	var s1 := (Vector2(1.55, 1.05) if is_rifle else (Vector2(1.72, 1.28) if is_mg else Vector2(1.4, 1.18))) * intensity
	scale = Vector2(s0, s0)
	# Soft smoke blob behind the spark so a burst reads as a shot, not a sticker.
	var smoke := Polygon2D.new()
	smoke.name = "Smoke"
	smoke.polygon = PackedVector2Array([
		Vector2(2, -5), Vector2(10, -7), Vector2(16, -2), Vector2(12, 5), Vector2(3, 4), Vector2(-2, 1)
	])
	smoke.color = Color(0.28, 0.24, 0.18, 0.36 if is_mg else 0.22)
	smoke.z_index = -1
	smoke.show_behind_parent = true
	add_child(smoke)
	var spark := Line2D.new()
	spark.name = "Spark"
	spark.width = 1.8 if is_mg else 1.3
	spark.default_color = Color(1.0, 0.98, 0.82, 0.95)
	spark.begin_cap_mode = Line2D.LINE_CAP_ROUND
	spark.end_cap_mode = Line2D.LINE_CAP_ROUND
	var reach := 22.0 if is_mg else (16.0 if is_rifle else 20.0)
	spark.points = PackedVector2Array([Vector2(2, 0), Vector2(reach, 0)])
	add_child(spark)
	var tw := create_tween()
	var pop := 0.028 if is_rifle else 0.04
	var fade := 0.055 if is_rifle else (0.10 if is_mg else 0.08)
	tw.tween_property(self, "scale", s1, pop)
	tw.parallel().tween_property(self, "modulate:a", 0.0, fade)
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
