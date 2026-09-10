extends CanvasModulate

## Unified night grade plus cheap ground key-light discs. Presentation only.

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
	var saving := _is_power_saving()
	var mild := 0.12 if saving else 0.0
	match id:
		"warehouse":
			return Color(0.86 + mild, 0.72 + mild * 0.5, 0.50, 1.0)
		"pump":
			return Color(0.66 + mild, 0.84, 0.74, 1.0)
		"railcut":
			return Color(0.68 + mild, 0.78, 0.86, 1.0)
		"depot":
			return Color(0.88, 0.74 + mild * 0.4, 0.54, 1.0)
		_:
			return Color(0.70 + mild, 0.80, 0.66, 1.0)


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
