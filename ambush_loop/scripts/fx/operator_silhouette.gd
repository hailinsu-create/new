extends RefCounted

## Top-down operator figure. Local -Y is facing after body.rotation = facing+90°.
## Head / shoulders / torso / two legs — not a chevron. Presentation only.


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
			# 铁砧 — thick receiver + stubby barrel (bipod is KitGear).
			return PackedVector2Array([
				Vector2(-4.2, 2.5), Vector2(4.4, 2.5), Vector2(3.8, -4.0),
				Vector2(2.6, -16.0), Vector2(1.4, -22.5), Vector2(-1.2, -22.5),
				Vector2(-2.6, -16.0), Vector2(-3.6, -4.0)
			])
		2:
			# 夜枭 — long thin barrel past the hood.
			return PackedVector2Array([
				Vector2(-1.05, -6.0), Vector2(1.05, -6.0), Vector2(0.85, -28.0),
				Vector2(0.45, -34.0), Vector2(-0.45, -34.0), Vector2(-0.85, -28.0)
			])
		_:
			# 灰狼 — rifle stock + long barrel.
			return PackedVector2Array([
				Vector2(-1.6, 3.5), Vector2(1.7, 3.5), Vector2(1.5, -6.0),
				Vector2(1.15, -22.0), Vector2(0.55, -30.5), Vector2(-0.55, -30.5),
				Vector2(-1.15, -22.0), Vector2(-1.4, -6.0)
			])


static func weapon_color(role: int) -> Color:
	match role:
		1:
			return Color(0.14, 0.12, 0.08, 0.98)
		2:
			return Color(0.10, 0.14, 0.18, 0.98)
		_:
			return Color(0.12, 0.14, 0.16, 0.98)


static func barrel_tip_y(role: int) -> float:
	match role:
		1:
			return -22.5
		2:
			return -34.0
		_:
			return -30.5


static func mount(body: Polygon2D, role: int) -> void:
	if body == null:
		return
	var cape := _poly(body, "Cape", _cape_poly(role), _cape_color(role), -1, role == 2)
	cape.visible = role == 2
	_poly(body, "ShoulderL", _shoulder_l(role), _shade(role, 0.78), 0, true)
	_poly(body, "ShoulderR", _shoulder_r(role), _shade(role, 0.92), 0, true)
	_poly(body, "TorsoShade", _torso(role), _shade(role, 0.70), 0, true)
	_poly(body, "LegL", _leg_l(role), _shade(role, 0.62), 0, true)
	_poly(body, "LegR", _leg_r(role), _shade(role, 0.74), 0, true)
	_poly(body, "Head", _head(role), _head_color(role), 1, true)
	_poly(body, "Visor", _visor(role), _visor_color(role), 2, true)
	_poly(body, "ArmGun", _arm_gun(role), _shade(role, 0.80), 3, true)
	var helm := _poly(body, "KitHelm", _helm(role), _helm_color(role), 2, true)
	helm.visible = true
	var gear := _poly(body, "KitGear", _gear(role), _gear_color(role), 3, true)
	gear.visible = true
	var weap := _poly(body, "Weapon", weapon_poly(role), weapon_color(role), 4, true)
	weap.visible = true
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
	if alive and not saving:
		stride = sin(t * 3.15 + op_id * 1.7) * 0.85
		sway = cos(t * 1.85 + op_id) * 0.35
	var kick := recoil * (2.4 if role == 1 else 1.6)
	var punch := hit * 0.8
	_shift(body, "LegL", Vector2(-sway * 0.4 - punch * 0.2, stride + kick * 0.35))
	_shift(body, "LegR", Vector2(sway * 0.4 + punch * 0.2, -stride + kick * 0.15))
	_shift(body, "Head", Vector2(sway * 0.25, -absf(stride) * 0.2 - punch * 0.4))
	_shift(body, "Visor", Vector2(sway * 0.25, -absf(stride) * 0.2 - punch * 0.4))
	_shift(body, "ShoulderL", Vector2(-kick * 0.15, kick * 0.2))
	_shift(body, "ShoulderR", Vector2(kick * 0.1, kick * 0.2))
	var arm := body.get_node_or_null("ArmGun") as Polygon2D
	if arm:
		arm.rotation = recoil
		arm.position = Vector2(0.0, kick * 0.15)
	var cape := body.get_node_or_null("Cape") as Polygon2D
	if cape:
		cape.visible = role == 2
		if role == 2 and alive and not saving:
			cape.rotation = deg_to_rad(sin(t * 2.1 + op_id) * 4.0)
		else:
			cape.rotation = 0.0
	var sight := body.get_node_or_null("Sight") as Line2D
	if sight:
		sight.visible = alive
		sight.rotation = recoil * 0.6


static func _rifle_body() -> PackedVector2Array:
	## Lean rifleman: helmet, narrow shoulders, two boots.
	return PackedVector2Array([
		Vector2(0.0, -18.0), Vector2(-3.2, -16.8), Vector2(-3.8, -13.4),
		Vector2(-2.2, -11.6), Vector2(-7.4, -10.0), Vector2(-8.6, -6.2),
		Vector2(-6.8, -3.6), Vector2(-5.6, 1.2), Vector2(-6.4, 5.2),
		Vector2(-6.8, 11.0), Vector2(-6.0, 16.4), Vector2(-2.8, 16.4),
		Vector2(-2.2, 9.0), Vector2(0.0, 6.8), Vector2(2.2, 9.0),
		Vector2(2.8, 16.4), Vector2(6.0, 16.4), Vector2(6.8, 11.0),
		Vector2(6.4, 5.2), Vector2(5.6, 1.2), Vector2(6.8, -3.6),
		Vector2(8.6, -6.2), Vector2(7.4, -10.0), Vector2(2.2, -11.6),
		Vector2(3.8, -13.4), Vector2(3.2, -16.8)
	])


static func _mg_body() -> PackedVector2Array:
	## 铁砧 — brick helmet, wide shoulders, thick thighs.
	return PackedVector2Array([
		Vector2(-4.6, -16.6), Vector2(4.6, -16.6), Vector2(5.2, -12.4),
		Vector2(3.4, -10.8), Vector2(11.2, -8.4), Vector2(12.4, -3.2),
		Vector2(10.0, 1.6), Vector2(8.4, 6.0), Vector2(8.8, 11.6),
		Vector2(7.6, 16.2), Vector2(3.4, 16.2), Vector2(2.6, 9.2),
		Vector2(0.0, 7.0), Vector2(-2.6, 9.2), Vector2(-3.4, 16.2),
		Vector2(-7.6, 16.2), Vector2(-8.8, 11.6), Vector2(-8.4, 6.0),
		Vector2(-10.0, 1.6), Vector2(-12.4, -3.2), Vector2(-11.2, -8.4),
		Vector2(-3.4, -10.8), Vector2(-5.2, -12.4)
	])


static func _scout_body() -> PackedVector2Array:
	## 夜枭 — hooded head, narrow chest, cloak hem, slim legs.
	return PackedVector2Array([
		Vector2(0.0, -17.6), Vector2(-2.6, -16.2), Vector2(-3.4, -13.0),
		Vector2(-2.0, -11.2), Vector2(-5.4, -9.4), Vector2(-6.2, -5.6),
		Vector2(-5.0, -2.2), Vector2(-7.6, 2.8), Vector2(-9.2, 7.4),
		Vector2(-5.4, 8.6), Vector2(-5.0, 12.4), Vector2(-4.2, 15.6),
		Vector2(-1.8, 15.6), Vector2(-1.6, 9.6), Vector2(0.0, 7.6),
		Vector2(1.6, 9.6), Vector2(1.8, 15.6), Vector2(4.2, 15.6),
		Vector2(5.0, 12.4), Vector2(5.4, 8.6), Vector2(9.2, 7.4),
		Vector2(7.6, 2.8), Vector2(5.0, -2.2), Vector2(6.2, -5.6),
		Vector2(5.4, -9.4), Vector2(2.0, -11.2), Vector2(3.4, -13.0),
		Vector2(2.6, -16.2)
	])


static func _head(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-4.4, -16.4), Vector2(4.4, -16.4),
				Vector2(4.0, -11.6), Vector2(-4.0, -11.6)
			])
		2:
			return PackedVector2Array([
				Vector2(0.0, -17.4), Vector2(-3.0, -15.4),
				Vector2(-2.6, -11.8), Vector2(2.6, -11.8), Vector2(3.0, -15.4)
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, -18.0), Vector2(-3.0, -16.4),
				Vector2(-3.2, -12.6), Vector2(3.2, -12.6), Vector2(3.0, -16.4)
			])


static func _visor(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-3.2, -14.6), Vector2(3.2, -14.6),
				Vector2(3.0, -12.8), Vector2(-3.0, -12.8)
			])
		2:
			return PackedVector2Array([
				Vector2(-1.6, -15.2), Vector2(1.6, -15.2),
				Vector2(1.4, -13.2), Vector2(-1.4, -13.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.2, -15.6), Vector2(2.2, -15.6),
				Vector2(2.0, -13.6), Vector2(-2.0, -13.6)
			])


static func _torso(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-7.5, -4.0), Vector2(7.5, -4.0),
				Vector2(6.2, 6.5), Vector2(-6.2, 6.5)
			])
		2:
			return PackedVector2Array([
				Vector2(-3.6, -4.5), Vector2(3.6, -4.5),
				Vector2(3.2, 6.0), Vector2(-3.2, 6.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.6, -4.2), Vector2(4.6, -4.2),
				Vector2(4.0, 5.6), Vector2(-4.0, 5.6)
			])


static func _shoulder_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-12.0, -8.6), Vector2(-6.0, -9.4),
				Vector2(-6.4, -2.4), Vector2(-11.4, -2.8)
			])
		2:
			return PackedVector2Array([
				Vector2(-6.0, -9.6), Vector2(-2.4, -9.0),
				Vector2(-2.6, -4.6), Vector2(-5.6, -5.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-8.4, -10.2), Vector2(-3.2, -9.6),
				Vector2(-3.6, -4.0), Vector2(-7.8, -4.6)
			])


static func _shoulder_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(6.0, -9.4), Vector2(12.0, -8.6),
				Vector2(11.4, -2.8), Vector2(6.4, -2.4)
			])
		2:
			return PackedVector2Array([
				Vector2(2.4, -9.0), Vector2(6.0, -9.6),
				Vector2(5.6, -5.0), Vector2(2.6, -4.6)
			])
		_:
			return PackedVector2Array([
				Vector2(3.2, -9.6), Vector2(8.4, -10.2),
				Vector2(7.8, -4.6), Vector2(3.6, -4.0)
			])


static func _leg_l(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-7.6, 6.2), Vector2(-2.2, 6.6),
				Vector2(-3.0, 16.2), Vector2(-7.4, 16.2)
			])
		2:
			return PackedVector2Array([
				Vector2(-4.6, 8.2), Vector2(-1.4, 8.4),
				Vector2(-1.8, 15.6), Vector2(-4.2, 15.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.2, 6.4), Vector2(-2.0, 6.8),
				Vector2(-2.6, 16.4), Vector2(-6.0, 16.4)
			])


static func _leg_r(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(2.2, 6.6), Vector2(7.6, 6.2),
				Vector2(7.4, 16.2), Vector2(3.0, 16.2)
			])
		2:
			return PackedVector2Array([
				Vector2(1.4, 8.4), Vector2(4.6, 8.2),
				Vector2(4.2, 15.6), Vector2(1.8, 15.6)
			])
		_:
			return PackedVector2Array([
				Vector2(2.0, 6.8), Vector2(6.2, 6.4),
				Vector2(6.0, 16.4), Vector2(2.6, 16.4)
			])


static func _arm_gun(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(3.0, -6.0), Vector2(8.4, -5.2),
				Vector2(4.2, -14.0), Vector2(1.2, -13.2)
			])
		2:
			return PackedVector2Array([
				Vector2(1.2, -7.0), Vector2(4.4, -6.4),
				Vector2(1.6, -18.0), Vector2(0.2, -17.4)
			])
		_:
			return PackedVector2Array([
				Vector2(2.0, -6.2), Vector2(6.2, -5.6),
				Vector2(2.4, -16.5), Vector2(0.4, -15.8)
			])


static func _helm(role: int) -> PackedVector2Array:
	match role:
		1:
			return PackedVector2Array([
				Vector2(-5.2, -17.2), Vector2(5.2, -17.2),
				Vector2(5.6, -14.8), Vector2(-5.6, -14.8)
			])
		2:
			return PackedVector2Array([
				Vector2(-3.4, -18.0), Vector2(3.4, -18.0),
				Vector2(3.0, -14.6), Vector2(-3.0, -14.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-3.4, -18.4), Vector2(3.4, -18.4),
				Vector2(3.2, -15.2), Vector2(-3.2, -15.2)
			])


static func _gear(role: int) -> PackedVector2Array:
	match role:
		1:
			# Bipod U under the barrel.
			return PackedVector2Array([
				Vector2(-8.6, -18.0), Vector2(8.6, -18.0), Vector2(10.2, -5.5),
				Vector2(6.4, -5.5), Vector2(2.4, -14.6), Vector2(-2.4, -14.6),
				Vector2(-6.4, -5.5), Vector2(-10.2, -5.5)
			])
		2:
			# Binocular tube on the right temple.
			return PackedVector2Array([
				Vector2(3.6, -16.0), Vector2(8.2, -16.0),
				Vector2(8.2, -7.2), Vector2(3.6, -7.2)
			])
		_:
			# Mag well under the receiver.
			return PackedVector2Array([
				Vector2(-2.0, 1.2), Vector2(2.0, 1.2),
				Vector2(1.6, 7.4), Vector2(-1.6, 7.4)
			])


static func _cape_poly(role: int) -> PackedVector2Array:
	if role != 2:
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	return PackedVector2Array([
		Vector2(-4.5, -9.0), Vector2(4.5, -9.0),
		Vector2(10.4, 6.8), Vector2(0.0, 11.0), Vector2(-10.4, 6.8)
	])


static func _sight(body: Polygon2D, role: int) -> void:
	var ln := body.get_node_or_null("Sight") as Line2D
	if ln == null:
		ln = Line2D.new()
		ln.name = "Sight"
		ln.z_index = 5
		ln.width = 1.5
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.add_child(ln)
	var tip := barrel_tip_y(role)
	ln.points = PackedVector2Array([Vector2(0.0, -8.0), Vector2(0.0, tip - 1.5)])
	match role:
		1:
			ln.default_color = Color(0.22, 0.20, 0.10, 0.95)
			ln.width = 2.2
		2:
			ln.default_color = Color(0.55, 0.92, 1.0, 0.85)
			ln.width = 1.15
		_:
			ln.default_color = Color(0.10, 0.12, 0.14, 0.95)
			ln.width = 1.5
	var bead := body.get_node_or_null("FrontSight") as Polygon2D
	if bead == null:
		bead = Polygon2D.new()
		bead.name = "FrontSight"
		bead.z_index = 6
		body.add_child(bead)
	bead.polygon = PackedVector2Array([
		Vector2(-1.1, tip + 0.4), Vector2(1.1, tip + 0.4),
		Vector2(0.0, tip - 2.6)
	])
	bead.color = Color(0.95, 0.88, 0.42, 0.95) if role != 2 else Color(0.70, 0.95, 1.0, 0.95)


static func _poly(
	body: Polygon2D, nam: String, pts: PackedVector2Array, col: Color, z: int, behind: bool
) -> Polygon2D:
	var n := body.get_node_or_null(nam) as Polygon2D
	if n == null:
		n = Polygon2D.new()
		n.name = nam
		body.add_child(n)
	n.polygon = pts
	n.color = col
	n.z_index = z
	n.show_behind_parent = behind and nam == "Cape"
	return n


static func _shift(body: Polygon2D, nam: String, off: Vector2) -> void:
	var n := body.get_node_or_null(nam) as Node2D
	if n:
		n.position = off


static func _shade(role: int, k: float) -> Color:
	var c := _base(role)
	return Color(c.r * k, c.g * k, c.b * k, 0.95)


static func _base(role: int) -> Color:
	match role:
		1:
			return Color(0.46, 0.54, 0.28)
		2:
			return Color(0.26, 0.52, 0.62)
		_:
			return Color(0.40, 0.55, 0.68)


static func _head_color(role: int) -> Color:
	match role:
		1:
			return Color(0.28, 0.32, 0.16, 0.98)
		2:
			return Color(0.16, 0.28, 0.32, 0.98)
		_:
			return Color(0.22, 0.30, 0.36, 0.98)


static func _visor_color(role: int) -> Color:
	match role:
		1:
			return Color(0.12, 0.14, 0.08, 0.92)
		2:
			return Color(0.18, 0.55, 0.62, 0.90)
		_:
			return Color(0.10, 0.16, 0.20, 0.92)


static func _helm_color(role: int) -> Color:
	match role:
		1:
			return Color(0.22, 0.24, 0.14, 0.96)
		2:
			return Color(0.12, 0.22, 0.26, 0.96)
		_:
			return Color(0.16, 0.22, 0.28, 0.96)


static func _gear_color(role: int) -> Color:
	match role:
		1:
			return Color(0.18, 0.16, 0.10, 0.95)
		2:
			return Color(0.18, 0.28, 0.32, 0.96)
		_:
			return Color(0.22, 0.28, 0.24, 0.85)


static func _cape_color(role: int) -> Color:
	if role != 2:
		return Color(0, 0, 0, 0)
	return Color(0.10, 0.22, 0.28, 0.88)
