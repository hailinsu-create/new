extends RefCounted

## Top-down hostile volumes. Local -Y is travel after body.rotation = aim+90°.
## 巡卫 rifleman / 奔袭 lean runner / 影探 crouched hood / 回波 radio-runner. Presentation only.


static func body_poly(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return _flank_body()
		"sneak":
			return _sneak_body()
		"echo":
			return _echo_body()
		_:
			return _patrol_body()


static func weapon_poly(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-1.5, -3.6), Vector2(1.5, -3.6),
				Vector2(1.2, -18.4), Vector2(-1.2, -18.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-0.9, -2.8), Vector2(0.9, -2.8),
				Vector2(0.7, -13.8), Vector2(-0.7, -13.8)
			])
		"echo":
			return PackedVector2Array([
				Vector2(-1.1, 1.4), Vector2(1.2, 1.4), Vector2(1.0, -10.2),
				Vector2(0.6, -24.8), Vector2(-0.6, -24.8), Vector2(-1.0, -10.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-1.6, 2.2), Vector2(1.7, 2.2), Vector2(1.4, -8.2),
				Vector2(1.1, -22.4), Vector2(0.45, -27.4), Vector2(-0.45, -27.4),
				Vector2(-1.1, -22.4), Vector2(-1.4, -8.2)
			])


static func weapon_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.12, 0.09, 0.07, 0.96)
		"sneak":
			return Color(0.08, 0.10, 0.10, 0.90)
		"echo":
			return Color(0.16, 0.28, 0.32, 0.96)
		_:
			return Color(0.14, 0.11, 0.09, 0.98)


static func mount(body: Polygon2D, kind: String) -> void:
	if body == null:
		return
	var saving := _saving()
	var cape := _poly(body, "Cape", _cape(kind), _cape_color(kind), -1)
	cape.visible = kind == "sneak"
	cape.show_behind_parent = true
	_poly(body, "BootL", _boot_l(kind), _boot_color(kind, 0.78), 0)
	_poly(body, "BootR", _boot_r(kind), _boot_color(kind, 0.92), 0)
	_poly(body, "ShoulderL", _shoulder_l(kind), _shade(kind, 0.70), 0)
	_poly(body, "ShoulderR", _shoulder_r(kind), _shade(kind, 0.90), 0)
	_poly(body, "TorsoShade", _torso(kind), _shade(kind, 0.62), 0)
	var bag := _poly(body, "BreadBag", _breadbag(kind), Color(0.28, 0.22, 0.12, 0.90), 1)
	bag.visible = kind == "flank"
	_poly(body, "LegL", _leg_l(kind), _shade(kind, 0.52), 0)
	_poly(body, "LegR", _leg_r(kind), _shade(kind, 0.68), 0)
	_poly(body, "Head", _head(kind), _head_color(kind), 1)
	_poly(body, "Visor", _visor(kind), _visor_color(kind), 2)
	var helm := _poly(body, "KitHelm", _helm(kind), _helm_color(kind), 2)
	helm.visible = kind != "sneak"
	_poly(body, "Weapon", weapon_poly(kind), weapon_color(kind), 3)
	var band := _poly(body, "Armband", _armband(kind), Color(0.62, 0.14, 0.10, 0.96), 2)
	band.visible = kind != "sneak"
	var moon := _poly(body, "MoonFill", _moon_fill(kind), Color(0.82, 0.74, 0.52, 0.22 if not saving else 0.10), 3)
	moon.visible = not saving
	var mast := _poly(body, "EchoMast", _echo_mast_poly(), Color(0.28, 0.26, 0.20, 0.95), 4)
	mast.visible = kind == "echo"
	var tip := _poly(body, "MastTip", _mast_tip_poly(), Color(0.62, 0.48, 0.22, 0.95), 5)
	tip.visible = kind == "echo"
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
		var amp := 1.35 if kind == "flank" else (0.75 if kind == "sneak" else (1.12 if kind == "echo" else 1.05))
		if alerted:
			amp *= 1.30
		stride = sin(phase) * amp
		sway = cos(phase) * amp * 0.38
	if not alive:
		_shift(body, "LegL", Vector2(-3.0, 2.2))
		_shift(body, "LegR", Vector2(3.4, 1.4))
		_rot(body, "LegL", 0.50)
		_rot(body, "LegR", -0.38)
		_shift(body, "Head", Vector2(2.2, 4.6))
		_shift(body, "Visor", Vector2(2.2, 4.6))
		_rot(body, "Head", 0.32)
		_rot(body, "Cape", 0.18)
		_rot(body, "Weapon", 0.48)
		return
	_shift(body, "LegL", Vector2(-sway * 0.55, stride))
	_shift(body, "LegR", Vector2(sway * 0.55, -stride))
	_rot(body, "LegL", stride * 0.16)
	_rot(body, "LegR", -stride * 0.16)
	_shift(body, "BootL", Vector2(-sway * 0.6, stride * 1.15 + maxf(0.0, stride) * 0.5))
	_shift(body, "BootR", Vector2(sway * 0.6, -stride * 1.15 + maxf(0.0, -stride) * 0.5))
	_shift(body, "Head", Vector2(sway * 0.22, -absf(stride) * 0.28))
	_shift(body, "Visor", Vector2(sway * 0.22, -absf(stride) * 0.28))
	_shift(body, "KitHelm", Vector2(sway * 0.18, -absf(stride) * 0.24))
	_shift(body, "ShoulderL", Vector2(-stride * 0.35, recoil * 4.0))
	_shift(body, "ShoulderR", Vector2(stride * 0.35, recoil * 4.0))
	var weap := body.get_node_or_null("Weapon") as Polygon2D
	if weap:
		weap.rotation = recoil
		weap.position = Vector2(0.0, recoil * 8.0)
	var cape := body.get_node_or_null("Cape") as Polygon2D
	if cape and kind == "sneak" and alive and not saving:
		cape.rotation = deg_to_rad(sin(phase * 0.7) * 8.0)
		cape.position = Vector2(sway * 0.3, absf(stride) * 0.25)
	elif cape:
		cape.rotation = 0.0
		cape.position = Vector2.ZERO
	var moon := body.get_node_or_null("MoonFill") as Polygon2D
	if moon:
		moon.visible = alive and not saving
	var pm := body.get_node_or_null("EchoMast") as Polygon2D
	if pm:
		pm.visible = kind == "echo" and alive
		pm.position = Vector2(sway * 0.12, -absf(stride) * 0.2)
	var tip := body.get_node_or_null("MastTip") as Polygon2D
	if tip:
		tip.visible = kind == "echo" and alive
		tip.position = Vector2(sway * 0.12, -absf(stride) * 0.2)


static func _patrol_body() -> PackedVector2Array:
	## 巡卫 — helmet block, rifle torso, two boots. 23 verts.
	return PackedVector2Array([
		Vector2(-4.4, -17.0), Vector2(4.4, -17.0), Vector2(5.0, -12.8),
		Vector2(2.8, -11.2), Vector2(8.4, -8.8), Vector2(9.2, -3.2),
		Vector2(7.2, 2.0), Vector2(6.4, 5.8), Vector2(6.8, 11.4),
		Vector2(5.8, 16.2), Vector2(2.6, 16.4), Vector2(2.2, 9.0),
		Vector2(0.0, 6.8), Vector2(-2.2, 9.0), Vector2(-2.6, 16.4),
		Vector2(-5.8, 16.2), Vector2(-6.8, 11.4), Vector2(-6.4, 5.8),
		Vector2(-7.2, 2.0), Vector2(-9.2, -3.2), Vector2(-8.4, -8.8),
		Vector2(-2.8, -11.2), Vector2(-5.0, -12.8)
	])


static func _flank_body() -> PackedVector2Array:
	## 奔袭 — lean, long stride, forward-weighted. 24 verts.
	return PackedVector2Array([
		Vector2(0.0, -18.8), Vector2(-3.0, -17.0), Vector2(-3.4, -13.6),
		Vector2(-2.0, -11.8), Vector2(-7.0, -9.4), Vector2(-7.8, -4.2),
		Vector2(-6.0, 0.8), Vector2(-7.0, 6.6), Vector2(-8.0, 13.4),
		Vector2(-6.6, 17.8), Vector2(-3.2, 17.4), Vector2(-2.4, 9.6),
		Vector2(0.0, 6.4), Vector2(2.6, 10.2), Vector2(3.4, 17.0),
		Vector2(6.6, 16.6), Vector2(7.2, 11.2), Vector2(6.4, 5.0),
		Vector2(5.6, 0.4), Vector2(7.6, -4.6), Vector2(6.8, -9.8),
		Vector2(2.0, -11.8), Vector2(3.4, -13.6), Vector2(3.0, -17.0)
	])


static func _sneak_body() -> PackedVector2Array:
	## 影探 — crouched hood, wide stance, short legs. 18 verts.
	return PackedVector2Array([
		Vector2(0.0, -10.8), Vector2(-4.4, -8.8), Vector2(-5.2, -5.4),
		Vector2(-10.0, -2.4), Vector2(-11.8, 2.6), Vector2(-9.2, 7.0),
		Vector2(-8.6, 10.8), Vector2(-4.8, 11.4), Vector2(-4.0, 8.2),
		Vector2(0.0, 6.6), Vector2(4.0, 8.2), Vector2(4.8, 11.4),
		Vector2(8.6, 10.8), Vector2(9.2, 7.0), Vector2(11.8, 2.6),
		Vector2(10.0, -2.4), Vector2(5.2, -5.4), Vector2(4.4, -8.8)
	])


static func _echo_body() -> PackedVector2Array:
	## 回波 — slim radio runner, antenna pack, 21 verts. Distinct from 巡卫.
	return PackedVector2Array([
		Vector2(-3.2, -18.4), Vector2(3.2, -18.4), Vector2(3.8, -14.0),
		Vector2(2.0, -12.2), Vector2(6.4, -9.6), Vector2(7.0, -4.0),
		Vector2(5.4, 1.2), Vector2(4.6, 6.2), Vector2(5.0, 12.0),
		Vector2(4.2, 16.6), Vector2(1.8, 16.8), Vector2(1.4, 9.2),
		Vector2(0.0, 7.0), Vector2(-1.4, 9.2), Vector2(-1.8, 16.8),
		Vector2(-4.2, 16.6), Vector2(-5.0, 12.0), Vector2(-4.6, 6.2),
		Vector2(-5.4, 1.2), Vector2(-7.0, -4.0), Vector2(-6.4, -9.6)
	])


static func _echo_mast_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-1.3, -16.0), Vector2(1.3, -16.0),
		Vector2(1.0, -38.0), Vector2(-1.0, -38.0)
	])


static func _mast_tip_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-2.6, -36.0), Vector2(2.6, -36.0),
		Vector2(1.6, -41.0), Vector2(-1.6, -41.0)
	])


static func _head(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(0.0, -18.6), Vector2(-2.8, -16.6),
				Vector2(-2.6, -12.6), Vector2(2.6, -12.6), Vector2(2.8, -16.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(0.0, -10.6), Vector2(-3.8, -8.4),
				Vector2(-3.4, -4.6), Vector2(3.4, -4.6), Vector2(3.8, -8.4)
			])
		"echo":
			return PackedVector2Array([
				Vector2(-3.0, -18.2), Vector2(3.0, -18.2),
				Vector2(2.6, -12.4), Vector2(-2.6, -12.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-4.2, -17.0), Vector2(4.2, -17.0),
				Vector2(3.8, -11.6), Vector2(-3.8, -11.6)
			])


static func _visor(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-2.0, -15.8), Vector2(2.0, -15.8),
				Vector2(1.8, -13.6), Vector2(-1.8, -13.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-1.8, -8.6), Vector2(1.8, -8.6),
				Vector2(1.6, -6.4), Vector2(-1.6, -6.4)
			])
		"echo":
			return PackedVector2Array([
				Vector2(-2.6, -16.0), Vector2(2.6, -16.0),
				Vector2(2.4, -13.2), Vector2(-2.4, -13.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.8, -15.0), Vector2(2.8, -15.0),
				Vector2(2.6, -12.8), Vector2(-2.6, -12.8)
			])


static func _torso(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-4.4, -4.0), Vector2(4.4, -4.0),
				Vector2(3.8, 5.6), Vector2(-3.8, 5.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-6.6, -2.0), Vector2(6.6, -2.0),
				Vector2(5.6, 6.2), Vector2(-5.6, 6.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-5.6, -4.4), Vector2(5.6, -4.4),
				Vector2(4.8, 6.0), Vector2(-4.8, 6.0)
			])


static func _shoulder_l(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-7.6, -9.6), Vector2(-2.6, -9.0),
				Vector2(-3.0, -3.6), Vector2(-7.2, -4.0)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-11.0, -3.2), Vector2(-4.4, -4.0),
				Vector2(-4.8, 1.8), Vector2(-10.4, 2.2)
			])
		_:
			return PackedVector2Array([
				Vector2(-9.0, -9.0), Vector2(-3.2, -8.4),
				Vector2(-3.6, -2.8), Vector2(-8.4, -3.2)
			])


static func _shoulder_r(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(2.6, -9.0), Vector2(7.6, -9.6),
				Vector2(7.2, -4.0), Vector2(3.0, -3.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(4.4, -4.0), Vector2(11.0, -3.2),
				Vector2(10.4, 2.2), Vector2(4.8, 1.8)
			])
		_:
			return PackedVector2Array([
				Vector2(3.2, -8.4), Vector2(9.0, -9.0),
				Vector2(8.4, -3.2), Vector2(3.6, -2.8)
			])


static func _leg_l(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-6.6, 6.0), Vector2(-2.2, 6.2),
				Vector2(-3.0, 16.8), Vector2(-6.6, 17.0)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-8.4, 6.4), Vector2(-3.6, 6.6),
				Vector2(-4.6, 11.0), Vector2(-8.4, 10.4)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.2, 6.0), Vector2(-2.2, 6.4),
				Vector2(-2.6, 15.6), Vector2(-5.8, 15.6)
			])


static func _leg_r(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(2.4, 6.2), Vector2(6.4, 5.6),
				Vector2(6.6, 16.2), Vector2(3.2, 16.6)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(3.6, 6.6), Vector2(8.4, 6.4),
				Vector2(8.4, 10.4), Vector2(4.6, 11.0)
			])
		_:
			return PackedVector2Array([
				Vector2(2.2, 6.4), Vector2(6.2, 6.0),
				Vector2(5.8, 15.6), Vector2(2.6, 15.6)
			])


static func _boot_l(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-7.0, 15.4), Vector2(-2.2, 15.6),
				Vector2(-2.6, 18.6), Vector2(-7.4, 18.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-8.8, 9.4), Vector2(-3.8, 9.8),
				Vector2(-4.4, 12.4), Vector2(-9.0, 11.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.4, 14.4), Vector2(-2.0, 14.6),
				Vector2(-2.4, 17.4), Vector2(-6.8, 17.2)
			])


static func _boot_r(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(2.4, 15.6), Vector2(6.8, 15.2),
				Vector2(7.2, 18.0), Vector2(2.8, 18.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(3.8, 9.8), Vector2(8.8, 9.4),
				Vector2(9.0, 11.8), Vector2(4.4, 12.4)
			])
		_:
			return PackedVector2Array([
				Vector2(2.0, 14.6), Vector2(6.4, 14.4),
				Vector2(6.8, 17.2), Vector2(2.4, 17.4)
			])


static func _breadbag(kind: String) -> PackedVector2Array:
	if kind != "flank":
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	return PackedVector2Array([
		Vector2(4.2, 1.2), Vector2(8.4, 1.6), Vector2(8.0, 6.8), Vector2(3.8, 6.2)
	])


static func _armband(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-7.8, -3.2), Vector2(-3.0, -2.8),
				Vector2(-3.2, 0.6), Vector2(-7.4, 0.2)
			])
		"echo":
			return PackedVector2Array([
				Vector2(-6.8, -3.6), Vector2(-2.6, -3.2),
				Vector2(-2.8, 0.4), Vector2(-6.4, 0.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-8.6, -3.4), Vector2(-3.4, -2.8),
				Vector2(-3.6, 0.8), Vector2(-8.2, 0.2)
			])


static func _helm(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-3.6, -19.4), Vector2(3.6, -19.4),
				Vector2(4.2, -15.4), Vector2(-4.2, -15.4)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-2.2, -10.4), Vector2(2.2, -10.4),
				Vector2(1.8, -7.2), Vector2(-1.8, -7.2)
			])
		"echo":
			return PackedVector2Array([
				Vector2(-4.0, -19.2), Vector2(4.0, -19.2),
				Vector2(4.6, -14.8), Vector2(-4.6, -14.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-5.6, -18.2), Vector2(5.6, -18.2),
				Vector2(6.2, -13.6), Vector2(-6.2, -13.6)
			])


static func _cape(kind: String) -> PackedVector2Array:
	if kind != "sneak":
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	return PackedVector2Array([
		Vector2(-5.4, -6.8), Vector2(5.4, -6.8),
		Vector2(14.2, 4.4), Vector2(6.0, 8.6), Vector2(0.0, 10.4),
		Vector2(-6.0, 8.6), Vector2(-14.2, 4.4)
	])


static func _moon_fill(kind: String) -> PackedVector2Array:
	match kind:
		"flank":
			return PackedVector2Array([
				Vector2(-6.4, -10.0), Vector2(-0.6, -17.4),
				Vector2(1.8, -14.8), Vector2(-2.8, -5.2)
			])
		"sneak":
			return PackedVector2Array([
				Vector2(-6.0, -4.0), Vector2(0.0, -10.0),
				Vector2(2.0, -7.0), Vector2(-2.4, -1.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-7.6, -10.2), Vector2(-1.2, -16.4),
				Vector2(2.0, -14.6), Vector2(-3.0, -5.0)
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
	var tip := -27.4
	match kind:
		"flank":
			tip = -18.4
			ln.width = 1.5
			ln.default_color = Color(0.20, 0.10, 0.06, 0.92)
		"sneak":
			tip = -13.8
			ln.width = 1.15
			ln.default_color = Color(0.28, 0.42, 0.32, 0.80)
		"echo":
			tip = -24.8
			ln.width = 1.35
			ln.default_color = Color(0.28, 0.24, 0.16, 0.90)
		_:
			tip = -27.4
			ln.width = 1.65
			ln.default_color = Color(0.14, 0.08, 0.06, 0.95)
	ln.points = PackedVector2Array([Vector2(0.0, -6.0), Vector2(0.0, tip)])
	var bead := body.get_node_or_null("FrontSight") as Polygon2D
	if bead == null:
		bead = Polygon2D.new()
		bead.name = "FrontSight"
		bead.z_index = 6
		body.add_child(bead)
	bead.polygon = PackedVector2Array([
		Vector2(-1.05, tip + 0.4), Vector2(1.05, tip + 0.4), Vector2(0.0, tip - 2.3)
	])
	bead.color = Color(0.72, 0.58, 0.28, 0.95) if kind == "echo" else Color(0.82, 0.62, 0.28, 0.95)


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


static func _shade(kind: String, k: float) -> Color:
	var c := _base(kind)
	return Color(c.r * k, c.g * k, c.b * k, 0.94)


static func _base(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.46, 0.30, 0.16)
		"sneak":
			return Color(0.16, 0.18, 0.14)
		"echo":
			return Color(0.28, 0.32, 0.30)
		_:
			return Color(0.36, 0.34, 0.28)


static func _head_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.30, 0.12, 0.06, 0.98)
		"sneak":
			return Color(0.10, 0.14, 0.12, 0.96)
		"echo":
			return Color(0.16, 0.28, 0.34, 0.98)
		_:
			return Color(0.28, 0.10, 0.08, 0.98)


static func _visor_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.16, 0.10, 0.06, 0.90)
		"sneak":
			return Color(0.18, 0.22, 0.16, 0.85)
		"echo":
			return Color(0.22, 0.24, 0.20, 0.92)
		_:
			return Color(0.12, 0.08, 0.06, 0.92)


static func _helm_color(kind: String) -> Color:
	match kind:
		"flank":
			return Color(0.26, 0.10, 0.05, 0.95)
		"sneak":
			return Color(0.10, 0.14, 0.12, 0.90)
		"echo":
			return Color(0.14, 0.26, 0.32, 0.96)
		_:
			return Color(0.20, 0.08, 0.06, 0.96)


static func _boot_color(kind: String, k: float) -> Color:
	var c := Color(0.10, 0.08, 0.06, 0.95)
	match kind:
		"flank":
			c = Color(0.16, 0.08, 0.04, 0.95)
		"sneak":
			c = Color(0.08, 0.10, 0.09, 0.92)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _cape_color(kind: String) -> Color:
	if kind != "sneak":
		return Color(0, 0, 0, 0)
	return Color(0.07, 0.12, 0.10, 0.88)
