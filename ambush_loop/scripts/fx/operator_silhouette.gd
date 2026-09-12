extends RefCounted

## Top-down operator as stacked volumes. Local -Y is facing after body.rotation = facing+90°.
## 灰狼 rifle / 铁砧 brick MG / 夜枭 hooded scout. Presentation only.

const WeaponArtScript := preload("res://scripts/art/weapon_art.gd")


static func body_poly(role: int) -> PackedVector2Array:
	match role:
		1:
			return _mg_body()
		2:
			return _scout_body()
		_:
			return _rifle_body()


static func weapon_poly(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-5.6, 3.6), Vector2(5.8, 3.6), Vector2(5.0, -3.4),
				Vector2(3.6, -15.6), Vector2(2.2, -24.6), Vector2(-1.8, -24.6),
				Vector2(-3.4, -15.6), Vector2(-4.8, -3.4)
			])
		2:
			return PackedVector2Array([
				Vector2(-1.05, -5.4), Vector2(1.05, -5.4), Vector2(0.82, -28.6),
				Vector2(0.42, -36.4), Vector2(-0.42, -36.4), Vector2(-0.82, -28.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-1.55, 4.0), Vector2(1.65, 4.0), Vector2(1.35, -5.6),
				Vector2(1.00, -22.4), Vector2(0.48, -32.2), Vector2(-0.48, -32.2),
				Vector2(-1.00, -22.4), Vector2(-1.35, -5.6)
			])


static func weapon_color(role: int) -> Color:
	match role:
		1:
			return Color(0.16, 0.14, 0.08, 0.98)
		2:
			return Color(0.10, 0.13, 0.12, 0.98)
		_:
			return Color(0.12, 0.14, 0.12, 0.98)


static func barrel_tip_y(role: int) -> float:
	match role:
		1:
			return -24.6
		2:
			return -36.4
		_:
			return -32.2


static func mount(body: Polygon2D, role: int, weapon_id: String = "") -> void:
	if body == null:
		return
	var saving := _saving()
	var cape := _poly(body, "Cape", _cape_poly(role), _cape_color(role), -2)
	cape.visible = role == 2
	cape.show_behind_parent = true
	_poly(body, "Pack", _pack(role), _pack_color(role), -1).visible = not saving or role != 2
	_poly(body, "BootL", _boot_l(role), _boot_color(role, 0.78), 0)
	_poly(body, "BootR", _boot_r(role), _boot_color(role, 0.92), 0)
	_poly(body, "PutteeL", _puttee_l(role), Color(0.32, 0.28, 0.18, 0.92), 0)
	_poly(body, "PutteeR", _puttee_r(role), Color(0.34, 0.30, 0.18, 0.92), 0)
	_poly(body, "LegL", _leg_l(role), _shade(role, 0.58), 0)
	_poly(body, "LegR", _leg_r(role), _shade(role, 0.72), 0)
	_poly(body, "Hip", _hip(role), _shade(role, 0.66), 0)
	_poly(body, "TorsoShade", _torso(role), _shade(role, 0.62), 0)
	_poly(body, "ShoulderL", _shoulder_l(role), _shade(role, 0.74), 1)
	_poly(body, "ShoulderR", _shoulder_r(role), _shade(role, 0.96), 1)
	_poly(body, "Collar", _collar(role), _head_color(role).lightened(0.08), 1)
	_poly(body, "ArmGun", _arm_gun(role), _shade(role, 0.82), 3)
	_poly(body, "Head", _head(role), _head_color(role), 2)
	_poly(body, "Visor", _visor(role), _visor_color(role), 3)
	_poly(body, "KitHelm", _helm(role), _helm_color(role), 3).visible = true
	_poly(body, "KitGear", _gear(role), _gear_color(role), 4).visible = true
	_poly(body, "Webbing", _webbing(role), Color(0.28, 0.22, 0.12, 0.92), 4).visible = true
	_poly(body, "PouchL", _pouch_l(role), Color(0.24, 0.18, 0.10, 0.94), 4).visible = true
	_poly(body, "PouchR", _pouch_r(role), Color(0.26, 0.20, 0.10, 0.94), 4).visible = true
	var wid := weapon_id if weapon_id != "" else ""
	var wpoly := weapon_poly(role)
	var wcol := weapon_color(role)
	if wid != "":
		wpoly = WeaponArtScript.silhouette(wid, role)
		wcol = WeaponArtScript.steel_color(wid)
	_poly(body, "Weapon", wpoly, wcol, 5).visible = true
	if wid != "" and wid != "knife":
		_poly(body, "Stock", WeaponArtScript.stock_poly(wid, role), WeaponArtScript.wood_color(wid), 4).visible = true
		var is_mg := wid in ["mg", "mg42", "mg34", "bar", "bren", "dp28"]
		var bl := _poly(body, "BipodL", PackedVector2Array([
			Vector2(-6.6, -8.2), Vector2(-5.2, -8.2), Vector2(-7.2, 2.6), Vector2(-8.4, 2.4)
		]), Color(0.14, 0.12, 0.08, 0.95), 5)
		var br := _poly(body, "BipodR", PackedVector2Array([
			Vector2(5.2, -8.2), Vector2(6.6, -8.2), Vector2(8.4, 2.4), Vector2(7.2, 2.6)
		]), Color(0.14, 0.12, 0.08, 0.95), 5)
		bl.visible = is_mg
		br.visible = is_mg
		var drum := _poly(body, "Drum", PackedVector2Array([
			Vector2(-4.8, -2.2), Vector2(-1.0, -2.4), Vector2(-1.2, 4.6), Vector2(-5.0, 4.4)
		]), Color(0.16, 0.14, 0.10, 0.95), 6)
		drum.visible = wid == "thompson"
		var knob := _poly(body, "BoltKnob", WeaponArtScript.bolt_knob_poly(wid), Color(0.22, 0.18, 0.10, 0.96), 7)
		knob.visible = WeaponArtScript.is_bolt(wid)
	else:
		var stock := body.get_node_or_null("Stock") as Polygon2D
		if stock:
			stock.visible = false
		for nam in ["Bipod", "BipodL", "BipodR", "Drum", "BoltKnob"]:
			var bipod_off := body.get_node_or_null(nam) as Polygon2D
			if bipod_off:
				bipod_off.visible = false
	var flash := _poly(body, "ShoulderFlash", _shoulder_flash(role), _flash_color(role), 2)
	flash.visible = true
	var rim := _poly(body, "RimLight", _rim_light(role), _rim_light_color(role), 4)
	rim.visible = not saving
	var moon := _poly(body, "MoonFill", _moon_fill(role), Color(0.78, 0.74, 0.52, 0.28 if not saving else 0.14), 4)
	moon.visible = not saving
	_sight(body, role)


static func pose_parts(body: Polygon2D, role: int, pose: Dictionary) -> void:
	if body == null:
		return
	var saving := bool(pose.get("saving", false))
	var alive := bool(pose.get("alive", true))
	var t := float(pose.get("t", 0.0))
	var recoil := float(pose.get("recoil", 0.0))
	var hit := float(pose.get("hit", 0.0))
	var op_id := float(pose.get("id", 0.0))
	var stride := 0.0
	var sway := 0.0
	var planted := bool(pose.get("planted", false))
	if alive and not saving:
		if planted:
			# Cover idle: planted feet, small breath. Not a walk cycle.
			stride = sin(t * 1.15 + op_id) * 0.16
			sway = cos(t * 1.35 + op_id) * 0.45
		else:
			var gait := 3.35 if role == 1 else (2.85 if role == 2 else 3.15)
			stride = sin(t * gait + op_id * 1.7)
			sway = cos(t * 1.85 + op_id)
	var kick := recoil * (2.8 if role == 1 else (1.4 if role == 2 else 1.8))
	var punch := hit * 0.9
	var bolt := float(pose.get("bolt", 0.0))
	var wid := str(pose.get("weapon_id", ""))
	var leg_amp := 2.4 if role == 1 else (1.6 if role == 2 else 2.0)
	if saving:
		leg_amp *= 0.35
	if not alive:
		_shift(body, "LegL", Vector2(-3.2, 2.4))
		_shift(body, "LegR", Vector2(3.6, 1.6))
		_rot(body, "LegL", 0.55)
		_rot(body, "LegR", -0.42)
		_shift(body, "BootL", Vector2(-3.6, 3.2))
		_shift(body, "BootR", Vector2(4.0, 2.2))
		_shift(body, "Head", Vector2(2.4, 5.0))
		_shift(body, "Visor", Vector2(2.4, 5.0))
		_shift(body, "KitHelm", Vector2(2.2, 4.6))
		_rot(body, "Head", 0.35)
		_rot(body, "Cape", 0.22)
		_rot(body, "Weapon", 0.55)
		return
	_shift(body, "LegL", Vector2(-sway * 0.55 - punch * 0.2, stride * leg_amp + kick * 0.28))
	_shift(body, "LegR", Vector2(sway * 0.55 + punch * 0.2, -stride * leg_amp + kick * 0.12))
	_rot(body, "LegL", stride * 0.28)
	_rot(body, "LegR", -stride * 0.28)
	_shift(body, "BootL", Vector2(-sway * 0.6, stride * (leg_amp + 0.6) + maxf(0.0, stride) * 0.8))
	_shift(body, "BootR", Vector2(sway * 0.6, -stride * (leg_amp + 0.6) + maxf(0.0, -stride) * 0.8))
	_shift(body, "Hip", Vector2(sway * 0.35, absf(stride) * 0.2))
	_shift(body, "Head", Vector2(sway * 0.28, -absf(stride) * 0.35 - punch * 0.5 - kick * 0.12))
	_shift(body, "Visor", Vector2(sway * 0.28, -absf(stride) * 0.35 - punch * 0.5 - kick * 0.12))
	_shift(body, "KitHelm", Vector2(sway * 0.22, -absf(stride) * 0.32 - punch * 0.4))
	_shift(body, "Collar", Vector2(sway * 0.18, -absf(stride) * 0.2))
	_shift(body, "ShoulderL", Vector2(-kick * 0.22 - stride * 0.4, kick * 0.28))
	_shift(body, "ShoulderR", Vector2(kick * 0.16 + stride * 0.4, kick * 0.28))
	_rot(body, "ShoulderL", -stride * 0.12 - recoil * 0.4)
	_rot(body, "ShoulderR", stride * 0.12 + recoil * 0.15)
	var bolt_yaw := 0.0
	var bolt_pull := 0.0
	if bolt > 0.02:
		if bolt > 0.62:
			bolt_yaw = (1.0 - (bolt - 0.62) / 0.38) * 0.72
		elif bolt > 0.28:
			bolt_yaw = 0.72
			bolt_pull = (0.62 - bolt) / 0.34
		else:
			bolt_yaw = 0.72 * (bolt / 0.28)
			bolt_pull = bolt / 0.28
	var arm := body.get_node_or_null("ArmGun") as Polygon2D
	if arm:
		arm.rotation = recoil * 1.15 + bolt_yaw * 0.55
		arm.position = Vector2(-kick * 0.15 + bolt_yaw * 1.6, kick * 0.45 + bolt_pull * 3.2)
	var weap := body.get_node_or_null("Weapon") as Polygon2D
	if weap:
		weap.rotation = recoil + bolt_yaw * 0.18
		weap.position = Vector2(bolt_yaw * 1.4, kick * 0.55 + bolt_pull * 2.6)
	var knob := body.get_node_or_null("BoltKnob") as Polygon2D
	if knob:
		knob.visible = WeaponArtScript.is_bolt(wid) and alive
		if knob.visible:
			knob.rotation = bolt_yaw
			knob.position = Vector2(bolt_yaw * 2.8, kick * 0.4 + bolt_pull * 5.4)
			knob.color = Color(0.22, 0.18, 0.10, 0.96).lerp(Color(0.62, 0.48, 0.22, 0.98), bolt_yaw)
	var cape := body.get_node_or_null("Cape") as Polygon2D
	if cape:
		cape.visible = role == 2
		if role == 2 and alive and not saving:
			cape.rotation = deg_to_rad(sin(t * 2.1 + op_id) * 7.0)
			cape.position = Vector2(sway * 0.4, absf(stride) * 0.3)
		else:
			cape.rotation = 0.0
			cape.position = Vector2.ZERO
	var pack := body.get_node_or_null("Pack") as Polygon2D
	if pack:
		pack.position = Vector2(-sway * 0.2, absf(stride) * 0.15)
	var sight := body.get_node_or_null("Sight") as Line2D
	if sight:
		sight.visible = alive
		sight.rotation = recoil * 0.7
		sight.position = Vector2(0.0, kick * 0.4)
	var bead := body.get_node_or_null("FrontSight") as Polygon2D
	if bead:
		bead.rotation = recoil * 0.7
		bead.position = Vector2(0.0, kick * 0.4)
	var moon := body.get_node_or_null("MoonFill") as Polygon2D
	if moon:
		moon.visible = alive and not saving
		moon.position = Vector2(sway * 0.1, -absf(stride) * 0.1)
	var flash := body.get_node_or_null("ShoulderFlash") as Polygon2D
	if flash:
		flash.position = Vector2(sway * 0.16 + kick * 0.08, -absf(stride) * 0.18)
	var rim := body.get_node_or_null("RimLight") as Polygon2D
	if rim:
		rim.visible = alive and not saving
		rim.position = Vector2(-sway * 0.12, -absf(stride) * 0.12)


static func _rifle_body() -> PackedVector2Array:
	## 灰狼 — slimmer oval helm, narrow shoulders, two boots. 26 verts.
	return PackedVector2Array([
		Vector2(0.0, -19.0), Vector2(-2.8, -17.4), Vector2(-3.4, -13.4),
		Vector2(-2.0, -11.6), Vector2(-6.6, -10.4), Vector2(-7.8, -5.8),
		Vector2(-6.2, -2.6), Vector2(-5.0, 1.6), Vector2(-5.6, 6.0),
		Vector2(-6.2, 11.4), Vector2(-5.6, 16.8), Vector2(-2.8, 17.2),
		Vector2(-2.0, 9.4), Vector2(0.0, 7.0), Vector2(2.0, 9.4),
		Vector2(2.8, 17.2), Vector2(5.6, 16.8), Vector2(6.2, 11.4),
		Vector2(5.6, 6.0), Vector2(5.0, 1.6), Vector2(6.2, -2.6),
		Vector2(7.8, -5.8), Vector2(6.6, -10.4), Vector2(2.0, -11.6),
		Vector2(3.4, -13.4), Vector2(2.8, -17.4)
	])


static func _mg_body() -> PackedVector2Array:
	## 铁砧 — brick helm, wide plate, thick thighs. 22 verts.
	return PackedVector2Array([
		Vector2(-6.2, -17.2), Vector2(6.2, -17.2), Vector2(6.8, -12.4),
		Vector2(4.2, -10.4), Vector2(13.6, -8.2), Vector2(15.0, -2.4),
		Vector2(12.0, 2.4), Vector2(10.0, 6.8), Vector2(10.4, 12.2),
		Vector2(9.0, 17.0), Vector2(4.0, 17.2), Vector2(3.2, 9.4),
		Vector2(0.0, 7.0), Vector2(-3.2, 9.4), Vector2(-4.0, 17.2),
		Vector2(-9.0, 17.0), Vector2(-10.4, 12.2), Vector2(-10.0, 6.8),
		Vector2(-12.0, 2.4), Vector2(-15.0, -2.4), Vector2(-13.6, -8.2),
		Vector2(-4.2, -10.4)
	])


static func _scout_body() -> PackedVector2Array:
	## 夜枭 — pointed hood, narrow chest, cloak hem, slim legs. 28 verts.
	return PackedVector2Array([
		Vector2(0.0, -19.6), Vector2(-2.6, -16.8), Vector2(-3.2, -13.0),
		Vector2(-1.8, -11.2), Vector2(-5.0, -9.4), Vector2(-5.6, -5.2),
		Vector2(-4.6, -1.6), Vector2(-8.8, 3.6), Vector2(-11.0, 8.2),
		Vector2(-6.0, 9.0), Vector2(-4.8, 12.8), Vector2(-4.0, 16.2),
		Vector2(-1.8, 16.4), Vector2(-1.4, 9.8), Vector2(0.0, 7.8),
		Vector2(1.4, 9.8), Vector2(1.8, 16.4), Vector2(4.0, 16.2),
		Vector2(4.8, 12.8), Vector2(6.0, 9.0), Vector2(11.0, 8.2),
		Vector2(8.8, 3.6), Vector2(4.6, -1.6), Vector2(5.6, -5.2),
		Vector2(5.0, -9.4), Vector2(1.8, -11.2), Vector2(3.2, -13.0),
		Vector2(2.6, -16.8)
	])


static func _head(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-5.6, -17.0), Vector2(5.6, -17.0),
				Vector2(5.2, -11.2), Vector2(-5.2, -11.2)
			])
		2:
			return PackedVector2Array([
				Vector2(0.0, -19.2), Vector2(-3.4, -15.8),
				Vector2(-2.6, -11.4), Vector2(2.6, -11.4), Vector2(3.4, -15.8)
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, -19.0), Vector2(-2.6, -16.8),
				Vector2(-2.8, -12.4), Vector2(2.8, -12.4), Vector2(2.6, -16.8)
			])


static func _visor(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-3.6, -14.8), Vector2(3.6, -14.8),
				Vector2(3.4, -12.6), Vector2(-3.4, -12.6)
			])
		2:
			return PackedVector2Array([
				Vector2(-2.2, -15.6), Vector2(2.2, -15.6),
				Vector2(2.0, -13.0), Vector2(-2.0, -13.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.4, -15.8), Vector2(2.4, -15.8),
				Vector2(2.2, -13.4), Vector2(-2.2, -13.4)
			])


static func _collar(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-4.2, -11.2), Vector2(4.2, -11.2),
				Vector2(3.4, -8.6), Vector2(-3.4, -8.6)
			])
		2:
			return PackedVector2Array([
				Vector2(-2.6, -11.4), Vector2(2.6, -11.4),
				Vector2(2.2, -8.8), Vector2(-2.2, -8.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-3.0, -11.6), Vector2(3.0, -11.6),
				Vector2(2.4, -9.0), Vector2(-2.4, -9.0)
			])


static func _torso(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-8.0, -4.2), Vector2(8.0, -4.2),
				Vector2(6.6, 6.8), Vector2(-6.6, 6.8)
			])
		2:
			return PackedVector2Array([
				Vector2(-3.8, -4.6), Vector2(3.8, -4.6),
				Vector2(3.4, 6.2), Vector2(-3.4, 6.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.8, -4.4), Vector2(4.8, -4.4),
				Vector2(4.2, 5.8), Vector2(-4.2, 5.8)
			])


static func _hip(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-6.4, 5.4), Vector2(6.4, 5.4),
				Vector2(5.2, 9.2), Vector2(-5.2, 9.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-3.2, 5.6), Vector2(3.2, 5.6),
				Vector2(2.6, 8.6), Vector2(-2.6, 8.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.4, 5.2), Vector2(4.4, 5.2),
				Vector2(3.6, 8.8), Vector2(-3.6, 8.8)
			])


static func _shoulder_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-14.4, -9.0), Vector2(-6.4, -10.0),
				Vector2(-6.8, -1.8), Vector2(-13.6, -2.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-6.0, -9.8), Vector2(-2.2, -9.2),
				Vector2(-2.4, -4.4), Vector2(-5.6, -4.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-7.6, -10.6), Vector2(-2.8, -10.0),
				Vector2(-3.2, -4.0), Vector2(-7.2, -4.6)
			])


static func _shoulder_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(6.4, -10.0), Vector2(14.4, -9.0),
				Vector2(13.6, -2.2), Vector2(6.8, -1.8)
			])
		2:
			return PackedVector2Array([
				Vector2(2.2, -9.2), Vector2(6.0, -9.8),
				Vector2(5.6, -4.8), Vector2(2.4, -4.4)
			])
		_:
			return PackedVector2Array([
				Vector2(2.8, -10.0), Vector2(7.6, -10.6),
				Vector2(7.2, -4.6), Vector2(3.2, -4.0)
			])


static func _leg_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-8.0, 6.4), Vector2(-2.4, 6.8),
				Vector2(-3.2, 16.0), Vector2(-7.8, 16.0)
			])
		2:
			return PackedVector2Array([
				Vector2(-4.8, 8.4), Vector2(-1.4, 8.6),
				Vector2(-1.8, 15.4), Vector2(-4.4, 15.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.4, 6.6), Vector2(-2.0, 7.0),
				Vector2(-2.6, 16.0), Vector2(-6.2, 16.0)
			])


static func _leg_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(2.4, 6.8), Vector2(8.0, 6.4),
				Vector2(7.8, 16.0), Vector2(3.2, 16.0)
			])
		2:
			return PackedVector2Array([
				Vector2(1.4, 8.6), Vector2(4.8, 8.4),
				Vector2(4.4, 15.4), Vector2(1.8, 15.4)
			])
		_:
			return PackedVector2Array([
				Vector2(2.0, 7.0), Vector2(6.4, 6.6),
				Vector2(6.2, 16.0), Vector2(2.6, 16.0)
			])


static func _puttee_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-7.6, 11.4), Vector2(-2.8, 11.6), Vector2(-3.0, 14.4), Vector2(-7.8, 14.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-4.6, 12.2), Vector2(-1.6, 12.4), Vector2(-1.8, 14.2), Vector2(-4.8, 14.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.2, 11.6), Vector2(-2.2, 11.8), Vector2(-2.4, 14.4), Vector2(-6.4, 14.2)
			])


static func _puttee_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(2.8, 11.6), Vector2(7.6, 11.4), Vector2(7.8, 14.2), Vector2(3.0, 14.4)
			])
		2:
			return PackedVector2Array([
				Vector2(1.6, 12.4), Vector2(4.6, 12.2), Vector2(4.8, 14.0), Vector2(1.8, 14.2)
			])
		_:
			return PackedVector2Array([
				Vector2(2.2, 11.8), Vector2(6.2, 11.6), Vector2(6.4, 14.2), Vector2(2.4, 14.4)
			])


static func _boot_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-8.4, 14.6), Vector2(-2.2, 14.8),
				Vector2(-2.6, 18.2), Vector2(-8.8, 18.0)
			])
		2:
			return PackedVector2Array([
				Vector2(-5.0, 14.2), Vector2(-1.2, 14.4),
				Vector2(-1.6, 17.0), Vector2(-5.2, 16.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.8, 14.6), Vector2(-1.8, 14.8),
				Vector2(-2.2, 18.0), Vector2(-7.2, 17.8)
			])


static func _boot_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(2.2, 14.8), Vector2(8.4, 14.6),
				Vector2(8.8, 18.0), Vector2(2.6, 18.2)
			])
		2:
			return PackedVector2Array([
				Vector2(1.2, 14.4), Vector2(5.0, 14.2),
				Vector2(5.2, 16.8), Vector2(1.6, 17.0)
			])
		_:
			return PackedVector2Array([
				Vector2(1.8, 14.8), Vector2(6.8, 14.6),
				Vector2(7.2, 17.8), Vector2(2.2, 18.0)
			])


static func _arm_gun(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(3.4, -6.0), Vector2(10.2, -4.8),
				Vector2(5.2, -15.2), Vector2(1.0, -14.2)
			])
		2:
			return PackedVector2Array([
				Vector2(1.0, -7.4), Vector2(4.2, -6.6),
				Vector2(1.4, -19.6), Vector2(0.1, -18.8)
			])
		_:
			return PackedVector2Array([
				Vector2(1.8, -6.6), Vector2(5.8, -5.8),
				Vector2(2.2, -17.4), Vector2(0.3, -16.6)
			])


static func _helm(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-6.6, -18.0), Vector2(6.6, -18.0),
				Vector2(7.0, -14.2), Vector2(-7.0, -14.2)
			])
		2:
			return PackedVector2Array([
				Vector2(0.0, -20.6), Vector2(-4.4, -16.6),
				Vector2(-3.4, -14.0), Vector2(3.4, -14.0), Vector2(4.4, -16.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.8, -19.4), Vector2(2.8, -19.4),
				Vector2(2.6, -15.2), Vector2(-2.6, -15.2)
			])


static func _pouch_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-10.4, 0.2), Vector2(-6.0, 0.4), Vector2(-6.2, 4.6), Vector2(-10.2, 4.4)
			])
		2:
			return PackedVector2Array([
				Vector2(-5.6, 0.6), Vector2(-2.8, 0.8), Vector2(-3.0, 3.6), Vector2(-5.4, 3.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-7.2, 0.4), Vector2(-3.8, 0.6), Vector2(-4.0, 4.0), Vector2(-7.0, 3.8)
			])


static func _pouch_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(6.0, 0.4), Vector2(10.4, 0.2), Vector2(10.2, 4.4), Vector2(6.2, 4.6)
			])
		2:
			return PackedVector2Array([
				Vector2(2.8, 0.8), Vector2(5.6, 0.6), Vector2(5.4, 3.4), Vector2(3.0, 3.6)
			])
		_:
			return PackedVector2Array([
				Vector2(3.8, 0.6), Vector2(7.2, 0.4), Vector2(7.0, 3.8), Vector2(4.0, 4.0)
			])


static func _webbing(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-7.4, -3.2), Vector2(7.4, -3.2),
				Vector2(6.6, -0.4), Vector2(-6.6, -0.4)
			])
		2:
			return PackedVector2Array([
				Vector2(-3.2, -3.6), Vector2(3.2, -3.6),
				Vector2(2.8, -1.0), Vector2(-2.8, -1.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.6, -3.4), Vector2(4.6, -3.4),
				Vector2(4.0, -0.8), Vector2(-4.0, -0.8)
			])


static func _gear(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-10.4, -18.4), Vector2(10.4, -18.4), Vector2(12.2, -4.6),
				Vector2(7.4, -4.6), Vector2(3.0, -14.6), Vector2(-3.0, -14.6),
				Vector2(-7.4, -4.6), Vector2(-12.2, -4.6)
			])
		2:
			return PackedVector2Array([
				Vector2(3.6, -16.8), Vector2(9.2, -16.8),
				Vector2(9.2, -6.4), Vector2(3.6, -6.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.0, 1.2), Vector2(2.0, 1.2),
				Vector2(1.6, 7.2), Vector2(-1.6, 7.2)
			])


static func _pack(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-6.4, 0.4), Vector2(6.4, 0.4),
				Vector2(5.6, 9.2), Vector2(-5.6, 9.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-2.4, 0.6), Vector2(2.4, 0.6),
				Vector2(2.0, 6.2), Vector2(-2.0, 6.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-3.4, 0.8), Vector2(3.4, 0.8),
				Vector2(2.8, 6.8), Vector2(-2.8, 6.8)
			])


static func _cape_poly(role: int) -> PackedVector2Array:
	if role != 2:
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	return PackedVector2Array([
		Vector2(-5.6, -10.2), Vector2(5.6, -10.2),
		Vector2(13.8, 8.6), Vector2(0.0, 14.8), Vector2(-13.8, 8.6)
	])


static func _moon_fill(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-10.0, -10.0), Vector2(-2.0, -16.0),
				Vector2(2.0, -15.0), Vector2(-4.0, -4.0)
			])
		2:
			return PackedVector2Array([
				Vector2(-5.2, -10.0), Vector2(0.0, -17.0),
				Vector2(2.2, -14.0), Vector2(-2.4, -6.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-7.4, -10.6), Vector2(-1.0, -17.2),
				Vector2(2.0, -15.4), Vector2(-3.2, -5.0)
			])


static func _shoulder_flash(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-11.2, -8.6), Vector2(11.2, -8.6),
				Vector2(10.2, -5.2), Vector2(-10.2, -5.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-2.2, -19.2), Vector2(2.2, -19.2),
				Vector2(1.6, -16.0), Vector2(-1.6, -16.0)
			])
		_:
			return PackedVector2Array([
				Vector2(3.2, -10.6), Vector2(7.8, -11.0),
				Vector2(7.2, -6.8), Vector2(2.8, -6.4)
			])


static func _flash_color(role: int) -> Color:
	match role:
		1:
			return Color(0.62, 0.48, 0.18, 0.92)
		2:
			return Color(0.42, 0.46, 0.32, 0.92)
		_:
			return Color(0.55, 0.48, 0.28, 0.92)


static func _rim_light(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-14.8, -9.4), Vector2(-11.2, -10.0),
				Vector2(-10.4, 2.0), Vector2(-13.6, 1.4)
			])
		2:
			return PackedVector2Array([
				Vector2(-6.4, -10.4), Vector2(-3.8, -10.8),
				Vector2(-3.2, 2.6), Vector2(-6.0, 2.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-8.2, -10.8), Vector2(-5.4, -11.2),
				Vector2(-4.8, 1.6), Vector2(-7.6, 1.2)
			])


static func _rim_light_color(role: int) -> Color:
	match role:
		1:
			return Color(0.82, 0.74, 0.42, 0.38)
		2:
			return Color(0.70, 0.74, 0.58, 0.36)
		_:
			return Color(0.78, 0.76, 0.52, 0.36)


static func _sight(body: Polygon2D, role: int) -> void:
	var ln := body.get_node_or_null("Sight") as Line2D
	if ln == null:
		ln = Line2D.new()
		ln.name = "Sight"
		ln.z_index = 6
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.add_child(ln)
	var tip := barrel_tip_y(role)
	ln.points = PackedVector2Array([Vector2(0.0, -8.0), Vector2(0.0, tip - 1.6)])
	match role:
		1:
			ln.default_color = Color(0.26, 0.22, 0.08, 0.95)
			ln.width = 3.0
		2:
			ln.default_color = Color(0.22, 0.20, 0.12, 0.90)
			ln.width = 1.05
		_:
			ln.default_color = Color(0.12, 0.16, 0.12, 0.95)
			ln.width = 1.45
	var bead := body.get_node_or_null("FrontSight") as Polygon2D
	if bead == null:
		bead = Polygon2D.new()
		bead.name = "FrontSight"
		bead.z_index = 7
		body.add_child(bead)
	bead.polygon = PackedVector2Array([
		Vector2(-1.2, tip + 0.4), Vector2(1.2, tip + 0.4),
		Vector2(0.0, tip - 2.8)
	])
	bead.color = Color(0.72, 0.56, 0.26, 0.95)


static func _poly(body: Polygon2D, nam: String, pts: PackedVector2Array, col: Color, z: int) -> Polygon2D:
	var n := body.get_node_or_null(nam) as Polygon2D
	if n == null:
		n = Polygon2D.new()
		n.name = nam
		body.add_child(n)
	n.polygon = pts
	n.color = col
	n.z_index = z
	return n


static func _shift(body: Polygon2D, nam: String, off: Vector2) -> void:
	var n := body.get_node_or_null(nam) as Node2D
	if n:
		n.position = off


static func _rot(body: Polygon2D, nam: String, rad: float) -> void:
	var n := body.get_node_or_null(nam) as Node2D
	if n:
		n.rotation = rad


static func _saving() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var gs = tree.root.get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


static func _shade(role: int, k: float) -> Color:
	var c := _base(role)
	return Color(c.r * k, c.g * k, c.b * k, 0.96)


static func _base(role: int) -> Color:
	match role:
		1:
			return Color(0.38, 0.36, 0.22)
		2:
			return Color(0.24, 0.28, 0.22)
		_:
			return Color(0.36, 0.34, 0.24)


static func _head_color(role: int) -> Color:
	match role:
		1:
			return Color(0.22, 0.20, 0.12, 0.98)
		2:
			return Color(0.16, 0.18, 0.14, 0.98)
		_:
			return Color(0.20, 0.18, 0.12, 0.98)


static func _visor_color(role: int) -> Color:
	match role:
		1:
			return Color(0.14, 0.12, 0.08, 0.94)
		2:
			return Color(0.18, 0.20, 0.14, 0.92)
		_:
			return Color(0.12, 0.10, 0.08, 0.94)


static func _helm_color(role: int) -> Color:
	match role:
		1:
			return Color(0.18, 0.16, 0.10, 0.96)
		2:
			return Color(0.12, 0.14, 0.10, 0.96)
		_:
			return Color(0.16, 0.14, 0.10, 0.96)


static func _gear_color(role: int) -> Color:
	match role:
		1:
			return Color(0.16, 0.14, 0.08, 0.95)
		2:
			return Color(0.16, 0.14, 0.10, 0.96)
		_:
			return Color(0.20, 0.16, 0.10, 0.88)


static func _pack_color(role: int) -> Color:
	match role:
		1:
			return Color(0.22, 0.18, 0.10, 0.90)
		2:
			return Color(0.12, 0.11, 0.08, 0.88)
		_:
			return Color(0.18, 0.14, 0.08, 0.88)


static func _boot_color(role: int, k: float) -> Color:
	var c := Color(0.10, 0.10, 0.08, 0.96)
	match role:
		1:
			c = Color(0.14, 0.12, 0.06, 0.96)
		2:
			c = Color(0.10, 0.09, 0.07, 0.94)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _cape_color(role: int) -> Color:
	if role != 2:
		return Color(0, 0, 0, 0)
	return Color(0.14, 0.12, 0.08, 0.90)
