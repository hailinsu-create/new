extends SceneTree

## Fast WWII weapon-model + silhouette probe. Exit 0 prints SMOKE_OK_WEAPON_MODELS.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var W: GDScript = load("res://scripts/raid/weapon_catalog.gd") as GDScript
	var Art: GDScript = load("res://scripts/art/weapon_art.gd") as GDScript
	if W == null or Art == null:
		push_error("PROBE_LOAD")
		quit(1)
		return
	if str(W.def("rifle").get("id", "")) != "rifle":
		push_error("PROBE_RIFLE_ID")
		quit(2)
		return
	if W.family_of("kar98k") != "rifle" or W.family_of("mp40") != "smg":
		push_error("PROBE_FAMILY")
		quit(3)
		return
	if float(W.def("kar98k").get("shot_interval", 0.0)) <= float(W.def("m1_garand").get("shot_interval", 0.0)):
		push_error("PROBE_CADENCE")
		quit(4)
		return
	if float(W.def("mg42").get("shot_interval", 1.0)) >= float(W.def("bar").get("shot_interval", 0.0)):
		push_error("PROBE_MG")
		quit(5)
		return
	if Art.silhouette("kar98k") == Art.silhouette("m1_garand"):
		push_error("PROBE_SIL")
		quit(6)
		return
	if not bool(Art.is_bolt("kar98k")) or bool(Art.is_bolt("mg42")):
		push_error("PROBE_BOLT")
		quit(8)
		return
	if Art.bolt_knob_poly("kar98k") == Art.bolt_knob_poly("mosin"):
		push_error("PROBE_BOLT_KNOB")
		quit(8)
		return
	if Art.icon_poly("mg42") == Art.icon_poly("bar") or Art.icon_poly("sten") == Art.icon_poly("luger"):
		push_error("PROBE_ICON")
		quit(9)
		return
	if Art.ground_poly("kar98k").is_empty():
		push_error("PROBE_GROUND")
		quit(9)
		return
	if str(W.sfx_cue("mg42")) == str(W.sfx_cue("kar98k")):
		push_error("PROBE_SFX")
		quit(7)
		return
	print("SMOKE_OK_WEAPON_MODELS n=", W.model_ids().size())
	print("ART_WEAPON_PROBE_OK")
	quit(0)
