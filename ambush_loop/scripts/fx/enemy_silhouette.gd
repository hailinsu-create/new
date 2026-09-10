extends RefCounted

## Top-down hostile figure. Local -Y is travel after body.rotation = aim+90°.
## Patrol / runner / shadow — not a shared diamond. Presentation only.


static func body_poly(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return _flank_body()
		"sneak":
			return _sneak_body()
		_:
			return _patrol_body()


static func weapon_poly(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-1.4, -4.0), Vector2(1.4, -4.0),
				Vector2(1.15, -18.0), Vector2(-1.15, -18.0)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-0.85, -3.0), Vector2(0.85, -3.0),
				Vector2(0.65, -13.5), Vector2(-0.65, -13.5)
			])
		_:
			return PackedVector2Array([
				Vector2(-1.5, 2.0), Vector2(1.6, 2.0), Vector2(1.3, -8.0),
				Vector2(1.05, -22.0), Vector2(0.4, -27.0), Vector2(-0.4, -27.0),
				Vector2(-1.05, -22.0), Vector2(-1.3, -8.0)
			])


static func weapon_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.12, 0.10, 0.08, 0.96)
		"sneak":
			return Color(0.08, 0.10, 0.12, 0.90)
		_:
			return Color(0.14, 0.12, 0.10, 0.98)


static func mount(body: Polygon2D, kind: String) -> void:
	if body == null:
		return
	_poly(body, "Cape", _cape(kind), _cape_color(kind), -1)
	var cape := body.get_node_or_null("Cape") as Polygon2D
	if cape:
		cape.visible = kind == "sneak"
		cape.show_behind_parent = true
	_poly(body, "ShoulderL", _shoulder_l(kind), _shade(kind, 0.72), 0)
	_poly(body, "ShoulderR", _shoulder_r(kind), _shade(kind, 0.88), 0)
	_poly(body, "TorsoShade", _torso(kind), _shade(kind, 0.64), 0)
	_poly(body, "LegL", _leg_l(kind), _shade(kind, 0.55), 0)
	_poly(body, "LegR", _leg_r(kind), _shade(kind, 0.70), 0)
	_poly(body, "Head", _head(kind), _head_color(kind), 1)
	_poly(body, "Visor", _visor(kind), _visor_color(kind), 2)
	var helm := _poly(body, "KitHelm", _helm(kind), _helm_color(kind), 2)
	helm.visible = kind != "sneak"
	_poly(body, "Weapon", weapon_poly(kind), weapon_color(kind), 3)
	_sight(body, kind)


static func pose_parts(body: Polygon2D, kind: String, pose: Dictionary) -> void:
	if body == null:
		return
	var saving := bool(pose.get("saving", false))
	var alive := bool(pose.get("alive", true))
	var active := bool(pose.get("active", false))
	var alerted := bool(pose.get("alerted", false))
	var phase := float(pose.get("phase", 0.0))
	var recoil := float(pose.get("recoil", 0.0))
	var stride := 0.0
	var sway := 0.0
	if alive and active and not saving:
		var amp := 1.15 if kind == "flank" else (0.7 if kind == "sneak" else 0.95)
		if alerted:
			amp *= 1.25
		stride = sin(phase) * amp
		sway = cos(phase) * amp * 0.35
	_shift(body, "LegL", Vector2(-sway * 0.5, stride))
	_shift(body, "LegR", Vector2(sway * 0.5, -stride))
	_shift(body, "Head", Vector2(sway * 0.2, -absf(stride) * 0.25))
	_shift(body, "Visor", Vector2(sway * 0.2, -absf(stride) * 0.25))
	var weap := body.get_node_or_null("Weapon") as Polygon2D
	if weap:
		weap.rotation = recoil
	var cape := body.get_node_or_null("Cape") as Polygon2D
	if cape and kind == "sneak" and alive and not saving:
		cape.rotation = deg_to_rad(sin(phase * 0.7) * 6.0)
	elif cape:
		cape.rotation = 0.0


static func _patrol_body() -> PackedVector2Array:
	## 巡卫 — helmet block, rifleman torso, two boots.
	return PackedVector2Array([
		Vector2(-4.2, -16.8), Vector2(4.2, -16.8), Vector2(4.8, -12.6),
		Vector2(2.6, -11.0), Vector2(8.0, -8.6), Vector2(8.8, -3.4),
		Vector2(7.0, 1.8), Vector2(6.2, 5.6), Vector2(6.6, 11.2),
		Vector2(5.6, 15.8), Vector2(2.4, 15.8), Vector2(2.0, 8.8),
		Vector2(0.0, 6.6), Vector2(-2.0, 8.8), Vector2(-2.4, 15.8),
		Vector2(-5.6, 15.8), Vector2(-6.6, 11.2), Vector2(-6.2, 5.6),
		Vector2(-7.0, 1.8), Vector2(-8.8, -3.4), Vector2(-8.0, -8.6),
		Vector2(-2.6, -11.0), Vector2(-4.8, -12.6)
	])


static func _flank_body() -> PackedVector2Array:
	## 奔袭 — lean, long stride, forward-weighted.
	return PackedVector2Array([
		Vector2(0.0, -18.4), Vector2(-2.8, -16.8), Vector2(-3.2, -13.4),
		Vector2(-1.8, -11.6), Vector2(-6.6, -9.2), Vector2(-7.4, -4.4),
		Vector2(-5.8, 0.6), Vector2(-6.8, 6.4), Vector2(-7.6, 13.2),
		Vector2(-6.4, 17.6), Vector2(-3.0, 17.2), Vector2(-2.2, 9.4),
		Vector2(0.0, 6.2), Vector2(2.4, 10.0), Vector2(3.2, 16.8),
		Vector2(6.4, 16.4), Vector2(7.0, 11.0), Vector2(6.2, 4.8),
		Vector2(5.4, 0.2), Vector2(7.2, -4.8), Vector2(6.4, -9.6),
		Vector2(1.8, -11.6), Vector2(3.2, -13.4), Vector2(2.8, -16.8)
	])


static func _sneak_body() -> PackedVector2Array:
	## 影探 — crouched hood, wide stance, short legs.
	return PackedVector2Array([
		Vector2(0.0, -10.4), Vector2(-4.2, -8.6), Vector2(-5.0, -5.4),
		Vector2(-9.6, -2.6), Vector2(-11.4, 2.4), Vector2(-9.0, 6.8),
		Vector2(-8.4, 10.6), Vector2(-4.6, 11.2), Vector2(-3.8, 8.0),
		Vector2(0.0, 6.4), Vector2(3.8, 8.0), Vector2(4.6, 11.2),
		Vector2(8.4, 10.6), Vector2(9.0, 6.8), Vector2(11.4, 2.4),
		Vector2(9.6, -2.6), Vector2(5.0, -5.4), Vector2(4.2, -8.6)
	])


static func _head(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(0.0, -18.2), Vector2(-2.6, -16.4),
				Vector2(-2.4, -12.6), Vector2(2.4, -12.6), Vector2(2.6, -16.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(0.0, -10.2), Vector2(-3.6, -8.2),
				Vector2(-3.2, -4.8), Vector2(3.2, -4.8), Vector2(3.6, -8.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.0, -16.8), Vector2(4.0, -16.8),
				Vector2(3.6, -11.8), Vector2(-3.6, -11.8)
			])


static func _visor(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-1.8, -15.6), Vector2(1.8, -15.6),
				Vector2(1.6, -13.6), Vector2(-1.6, -13.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-1.6, -8.4), Vector2(1.6, -8.4),
				Vector2(1.4, -6.4), Vector2(-1.4, -6.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.6, -14.8), Vector2(2.6, -14.8),
				Vector2(2.4, -12.8), Vector2(-2.4, -12.8)
			])


static func _torso(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-4.2, -4.0), Vector2(4.2, -4.0),
				Vector2(3.6, 5.4), Vector2(-3.6, 5.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-6.4, -2.0), Vector2(6.4, -2.0),
				Vector2(5.4, 6.0), Vector2(-5.4, 6.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-5.4, -4.4), Vector2(5.4, -4.4),
				Vector2(4.6, 5.8), Vector2(-4.6, 5.8)
			])


static func _shoulder_l(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-7.2, -9.4), Vector2(-2.4, -8.8),
				Vector2(-2.8, -3.6), Vector2(-6.8, -4.0)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-10.6, -3.2), Vector2(-4.2, -4.0),
				Vector2(-4.6, 1.6), Vector2(-10.0, 2.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-8.6, -8.8), Vector2(-3.0, -8.2),
				Vector2(-3.4, -2.8), Vector2(-8.0, -3.2)
			])


static func _shoulder_r(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(2.4, -8.8), Vector2(7.2, -9.4),
				Vector2(6.8, -4.0), Vector2(2.8, -3.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(4.2, -4.0), Vector2(10.6, -3.2),
				Vector2(10.0, 2.0), Vector2(4.6, 1.6)
			])
		_:
			return PackedVector2Array([
				Vector2(3.0, -8.2), Vector2(8.6, -8.8),
				Vector2(8.0, -3.2), Vector2(3.4, -2.8)
			])


static func _leg_l(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-6.4, 6.0), Vector2(-2.0, 6.2),
				Vector2(-2.8, 17.2), Vector2(-6.4, 17.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-8.2, 6.4), Vector2(-3.4, 6.6),
				Vector2(-4.4, 11.2), Vector2(-8.2, 10.6)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.0, 6.0), Vector2(-2.0, 6.4),
				Vector2(-2.4, 15.8), Vector2(-5.6, 15.8)
			])


static func _leg_r(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(2.2, 6.2), Vector2(6.2, 5.6),
				Vector2(6.4, 16.4), Vector2(3.0, 16.8)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(3.4, 6.6), Vector2(8.2, 6.4),
				Vector2(8.2, 10.6), Vector2(4.4, 11.2)
			])
		_:
			return PackedVector2Array([
				Vector2(2.0, 6.4), Vector2(6.0, 6.0),
				Vector2(5.6, 15.8), Vector2(2.4, 15.8)
			])


static func _helm(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-3.0, -18.6), Vector2(3.0, -18.6),
				Vector2(2.6, -14.8), Vector2(-2.6, -14.8)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-2.0, -10.0), Vector2(2.0, -10.0),
				Vector2(1.6, -7.0), Vector2(-1.6, -7.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-5.0, -17.4), Vector2(5.0, -17.4),
				Vector2(4.4, -13.4), Vector2(-4.4, -13.4)
			])


static func _cape(kind: String) -> PackedVector2Array:
	if kind != "sneak":
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	return PackedVector2Array([
		Vector2(-5.0, -6.5), Vector2(5.0, -6.5),
		Vector2(12.2, 4.8), Vector2(0.0, 8.6), Vector2(-12.2, 4.8)
	])


static func _sight(body: Polygon2D, kind: String) -> void:
	var ln := body.get_node_or_null("Sight") as Line2D
	if ln == null:
		ln = Line2D.new()
		ln.name = "Sight"
		ln.z_index = 5
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.add_child(ln)
	var tip := -27.0
	match kind:
		"flank":
			tip = -18.0
			ln.width = 1.4
			ln.default_color = Color(0.18, 0.10, 0.06, 0.92)
		"sneak":
			tip = -13.5
			ln.width = 1.1
			ln.default_color = Color(0.22, 0.32, 0.28, 0.80)
		_:
			tip = -27.0
			ln.width = 1.6
			ln.default_color = Color(0.12, 0.08, 0.06, 0.95)
	ln.points = PackedVector2Array([Vector2(0.0, -6.0), Vector2(0.0, tip)])
	var bead := body.get_node_or_null("FrontSight") as Polygon2D
	if bead == null:
		bead = Polygon2D.new()
		bead.name = "FrontSight"
		bead.z_index = 6
		body.add_child(bead)
	bead.polygon = PackedVector2Array([
		Vector2(-1.0, tip + 0.4), Vector2(1.0, tip + 0.4), Vector2(0.0, tip - 2.2)
	])
	bead.color = Color(1.0, 0.72, 0.28, 0.95)


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


static func _shade(kind: String, k: float) -> Color:
	var c := _base(kind)
	return Color(c.r * k, c.g * k, c.b * k, 0.94)


static func _base(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.90, 0.42, 0.12)
		"sneak":
			return Color(0.16, 0.20, 0.24)
		_:
			return Color(0.82, 0.16, 0.14)


static func _head_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.32, 0.14, 0.08, 0.98)
		"sneak":
			return Color(0.10, 0.14, 0.16, 0.96)
		_:
			return Color(0.28, 0.10, 0.08, 0.98)


static func _visor_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.18, 0.08, 0.04, 0.90)
		"sneak":
			return Color(0.22, 0.42, 0.38, 0.85)
		_:
			return Color(0.12, 0.04, 0.04, 0.92)


static func _helm_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.28, 0.12, 0.06, 0.95)
		"sneak":
			return Color(0.10, 0.14, 0.14, 0.90)
		_:
			return Color(0.22, 0.10, 0.08, 0.96)


static func _cape_color(kind: String) -> Color:
	if kind != "sneak":
		return Color(0, 0, 0, 0)
	return Color(0.08, 0.12, 0.12, 0.86)
