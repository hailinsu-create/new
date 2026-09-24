extends Control

## Tiny HUD firearm stamp. Muzzle to the right. Presentation only.

const WeaponArtScript := preload("res://scripts/art/weapon_art.gd")

var weapon_id: String = "rifle":
	set(v):
		weapon_id = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 16)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	if weapon_id == "" or weapon_id == "knife":
		return
	var c := Vector2(size.x * 0.5, size.y * 0.52)
	var pts := WeaponArtScript.icon_poly(weapon_id)
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(c + p * 0.85)
	if poly.size() >= 3:
		draw_colored_polygon(poly, WeaponArtScript.steel_color(weapon_id))
		var wood := WeaponArtScript.wood_color(weapon_id)
		draw_rect(Rect2(c.x - 10, c.y - 1.6, 6, 3.2), wood)
