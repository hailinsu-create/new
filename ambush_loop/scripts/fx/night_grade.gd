extends CanvasModulate

## Unified night grade plus cheap ground key-light discs. Presentation only.

const Ww2Pal := preload("res://scripts/art/ww2_palette.gd")

var atmosphere_id: String = "yard"
var keys: Node2D = null


func setup(id: String) -> void:
	atmosphere_id = id if id != "" else "yard"
	name = "NightGrade"
	color = _grade_color(atmosphere_id)
	_ensure_keys()
	if keys and keys.has_method("setup"):
		keys.setup(atmosphere_id)


func _grade_color(id: String) -> Color:
	return Ww2Pal.night_grade(id, _is_power_saving())


func _ensure_keys() -> void:
	var world: Node = get_parent().get_node_or_null("World") if get_parent() else null
	if world == null:
		return
	keys = world.get_node_or_null("NightKeys") as Node2D
	if keys == null or not is_instance_valid(keys):
		keys = Node2D.new()
		keys.name = "NightKeys"
		keys.set_script(load("res://scripts/fx/night_keys.gd") as GDScript)
		world.add_child(keys)
		var map_n: Node = world.get_node_or_null("MapDraw")
		if map_n:
			world.move_child(keys, mini(map_n.get_index() + 1, world.get_child_count() - 1))
	keys.z_index = 1


func _is_power_saving() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())
