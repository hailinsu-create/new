class_name WeaponArt
extends RefCounted

## Top-down firearm silhouettes + HUD icons. Local -Y is muzzle.
## Original procedural art — WWII steel/wood, not modern polymer.


static func silhouette(id: String, role: int = 0) -> PackedVector2Array:
	match id:
		"knife":
			return PackedVector2Array([
				Vector2(-1.4, 3.2), Vector2(1.4, 3.2), Vector2(1.0, -4.0),
				Vector2(0.7, -14.0), Vector2(0.0, -19.2), Vector2(-0.55, -14.0),
				Vector2(-1.0, -4.0)
			])
		"kar98k":
			return PackedVector2Array([
				Vector2(-1.7, 5.2), Vector2(1.8, 5.2), Vector2(2.6, 2.2), Vector2(2.4, 0.6),
				Vector2(1.5, -6.0), Vector2(1.15, -24.0), Vector2(0.55, -36.8),
				Vector2(-0.55, -36.8), Vector2(-1.15, -24.0), Vector2(-1.5, -6.0)
			])
		"lee_enfield":
			return PackedVector2Array([
				Vector2(-2.1, 5.0), Vector2(2.2, 5.0), Vector2(3.4, 1.2), Vector2(3.2, -2.4),
				Vector2(1.9, -4.4), Vector2(1.2, -20.8), Vector2(0.55, -33.6),
				Vector2(-0.55, -33.6), Vector2(-1.2, -20.8), Vector2(-1.9, -4.4)
			])
		"m1_garand":
			return PackedVector2Array([
				Vector2(-2.0, 4.6), Vector2(2.4, 4.6), Vector2(2.6, 1.2), Vector2(2.4, -1.0),
				Vector2(2.2, -3.2), Vector2(1.4, -16.8), Vector2(0.7, -30.4),
				Vector2(-0.5, -30.4), Vector2(-1.3, -16.8), Vector2(-1.8, -3.2)
			])
		"mosin":
			return PackedVector2Array([
				Vector2(-1.6, 5.4), Vector2(1.7, 5.4), Vector2(1.4, -7.2),
				Vector2(1.05, -25.6), Vector2(0.48, -37.6), Vector2(-0.48, -37.6),
				Vector2(-1.05, -25.6), Vector2(-1.4, -7.2)
			])
		"gewehr43":
			return PackedVector2Array([
				Vector2(-2.4, 4.6), Vector2(2.6, 4.4), Vector2(2.2, -4.2),
				Vector2(1.5, -17.6), Vector2(0.7, -30.4), Vector2(-0.4, -30.4),
				Vector2(-1.3, -17.6), Vector2(-2.1, -4.2)
			])
		"svt40":
			return PackedVector2Array([
				Vector2(-2.0, 4.2), Vector2(2.2, 4.2), Vector2(1.9, -5.6),
				Vector2(1.2, -19.2), Vector2(0.55, -32.8), Vector2(-0.5, -32.8),
				Vector2(-1.15, -19.2), Vector2(-1.8, -5.6)
			])
		"mp38":
			return PackedVector2Array([
				Vector2(-2.8, 6.4), Vector2(2.0, 6.2), Vector2(1.6, -2.0),
				Vector2(1.1, -14.4), Vector2(0.7, -21.2), Vector2(-0.5, -21.2),
				Vector2(-1.4, -8.8), Vector2(-3.2, 2.4)
			])
		"mp40", "smg":
			return PackedVector2Array([
				Vector2(-2.4, 6.2), Vector2(2.0, 6.2), Vector2(1.6, -2.0),
				Vector2(1.1, -14.4), Vector2(0.7, -22.0), Vector2(-0.5, -22.0),
				Vector2(-1.4, -8.8), Vector2(-2.6, 1.6)
			])
		"sten":
			return PackedVector2Array([
				Vector2(-1.2, 5.4), Vector2(1.4, 5.4), Vector2(1.2, -4.0),
				Vector2(0.9, -16.0), Vector2(0.55, -24.8), Vector2(-0.4, -24.8),
				Vector2(-0.8, -16.0), Vector2(-3.8, -6.0), Vector2(-3.8, -1.2),
				Vector2(-1.1, -1.2)
			])
		"thompson":
			return PackedVector2Array([
				Vector2(-2.8, 6.8), Vector2(2.6, 6.8), Vector2(2.2, -1.2),
				Vector2(1.6, -10.4), Vector2(1.1, -20.8), Vector2(-0.4, -20.8),
				Vector2(-1.6, -8.0), Vector2(-3.4, 0.8)
			])
		"pps43":
			return PackedVector2Array([
				Vector2(-2.6, 6.0), Vector2(1.6, 5.4), Vector2(1.4, -3.2),
				Vector2(1.0, -15.6), Vector2(0.55, -24.0), Vector2(-0.4, -24.0),
				Vector2(-1.4, -9.2), Vector2(-2.8, 1.2)
			])
		"mg42":
			return PackedVector2Array([
				Vector2(-6.2, 4.2), Vector2(6.4, 4.2), Vector2(5.6, -2.8),
				Vector2(4.0, -14.0), Vector2(2.6, -26.8), Vector2(-1.8, -26.8),
				Vector2(-3.6, -14.0), Vector2(-5.4, -2.8)
			])
		"mg34":
			return PackedVector2Array([
				Vector2(-5.4, 3.8), Vector2(5.6, 3.8), Vector2(4.8, -3.6),
				Vector2(3.4, -16.4), Vector2(2.2, -25.6), Vector2(-1.6, -25.6),
				Vector2(-3.2, -16.4), Vector2(-4.8, -3.6)
			])
		"bar":
			return PackedVector2Array([
				Vector2(-4.2, 4.0), Vector2(4.4, 4.0), Vector2(3.8, -4.8),
				Vector2(2.4, -16.0), Vector2(1.4, -27.2), Vector2(-1.1, -27.2),
				Vector2(-2.4, -16.0), Vector2(-3.6, -4.8)
			])
		"bren":
			return PackedVector2Array([
				Vector2(-3.6, 3.6), Vector2(4.8, 3.6), Vector2(4.2, -5.2),
				Vector2(5.6, -8.4), Vector2(5.4, -14.0), Vector2(2.2, -17.2),
				Vector2(1.2, -26.4), Vector2(-1.0, -26.4), Vector2(-2.2, -17.2),
				Vector2(-3.2, -5.2)
			])
		"dp28":
			return PackedVector2Array([
				Vector2(-5.8, 3.2), Vector2(5.0, 3.2), Vector2(4.2, -4.0),
				Vector2(-6.8, -6.4), Vector2(-8.2, -10.8), Vector2(-4.0, -12.2),
				Vector2(2.4, -15.2), Vector2(1.3, -24.8), Vector2(-1.0, -24.8),
				Vector2(-2.6, -15.2), Vector2(-5.0, -4.0)
			])
		"m1911", "pistol":
			return PackedVector2Array([
				Vector2(-1.8, 3.6), Vector2(1.6, 3.6), Vector2(1.4, -2.4),
				Vector2(1.0, -12.8), Vector2(0.4, -16.8), Vector2(-0.4, -16.8),
				Vector2(-1.0, -12.8), Vector2(-1.6, -2.4)
			])
		"luger":
			return PackedVector2Array([
				Vector2(-2.8, 5.8), Vector2(1.0, 3.6), Vector2(1.4, -3.0),
				Vector2(0.9, -14.4), Vector2(0.35, -19.4), Vector2(-0.35, -19.4),
				Vector2(-0.9, -14.4), Vector2(-1.8, -1.6)
			])
		"p38":
			return PackedVector2Array([
				Vector2(-1.9, 4.0), Vector2(1.7, 4.0), Vector2(1.5, -2.8),
				Vector2(1.05, -13.6), Vector2(0.42, -17.6), Vector2(-0.42, -17.6),
				Vector2(-1.05, -13.6), Vector2(-1.7, -2.8)
			])
		"webley":
			return PackedVector2Array([
				Vector2(-3.2, 4.6), Vector2(2.2, 4.4), Vector2(1.8, -1.6),
				Vector2(1.1, -10.8), Vector2(0.5, -15.2), Vector2(-0.5, -15.2),
				Vector2(-1.2, -10.8), Vector2(-3.6, -0.4), Vector2(-3.8, 2.8)
			])
		"tt33":
			return PackedVector2Array([
				Vector2(-1.7, 3.8), Vector2(1.5, 3.8), Vector2(1.3, -3.2),
				Vector2(0.95, -13.2), Vector2(0.38, -17.2), Vector2(-0.38, -17.2),
				Vector2(-0.95, -13.2), Vector2(-1.5, -3.2)
			])
		"kar98k_zf":
			return PackedVector2Array([
				Vector2(-1.5, 4.2), Vector2(1.7, 4.2), Vector2(1.35, -6.4),
				Vector2(2.4, -18.0), Vector2(2.4, -22.0), Vector2(1.00, -24.8),
				Vector2(0.48, -39.4), Vector2(-0.48, -39.4), Vector2(-1.00, -24.8),
				Vector2(-1.35, -6.4)
			])
		"springfield":
			return PackedVector2Array([
				Vector2(-1.6, 4.0), Vector2(1.8, 4.0), Vector2(1.5, -6.0),
				Vector2(2.2, -16.8), Vector2(2.0, -20.4), Vector2(1.00, -24.8),
				Vector2(0.48, -37.8), Vector2(-0.48, -37.8), Vector2(-1.00, -24.8),
				Vector2(-1.35, -6.4)
			])
		"mosin_pu":
			return PackedVector2Array([
				Vector2(-1.4, 4.4), Vector2(1.6, 4.4), Vector2(1.3, -7.0),
				Vector2(2.6, -19.2), Vector2(2.5, -22.6), Vector2(0.95, -25.6),
				Vector2(0.42, -39.2), Vector2(-0.42, -39.2), Vector2(-0.95, -25.6),
				Vector2(-1.3, -7.0)
			])
		"enfield_t", "scout":
			return PackedVector2Array([
				Vector2(-1.5, 4.2), Vector2(1.7, 4.2), Vector2(1.35, -6.4),
				Vector2(1.00, -24.8), Vector2(0.48, -38.6), Vector2(-0.48, -38.6),
				Vector2(-1.00, -24.8), Vector2(-1.35, -6.4)
			])
		"m30_drilling":
			return PackedVector2Array([
				Vector2(-2.6, 5.0), Vector2(2.8, 5.0), Vector2(2.4, -3.6),
				Vector2(2.0, -14.0), Vector2(1.6, -23.4), Vector2(0.2, -23.4),
				Vector2(-0.2, -14.0), Vector2(-0.8, -23.0), Vector2(-1.8, -23.0),
				Vector2(-2.2, -3.6)
			])
		"ithaca37":
			return PackedVector2Array([
				Vector2(-2.2, 5.2), Vector2(2.8, 4.6), Vector2(2.4, -3.2),
				Vector2(1.7, -13.2), Vector2(1.2, -21.6), Vector2(-0.6, -21.6),
				Vector2(-1.5, -13.2), Vector2(-2.0, -3.2)
			])
		"winchester_m12", "shotgun":
			return PackedVector2Array([
				Vector2(-2.4, 5.0), Vector2(2.6, 5.0), Vector2(2.2, -3.6),
				Vector2(1.6, -14.0), Vector2(1.1, -22.4), Vector2(-0.7, -22.4),
				Vector2(-1.6, -14.0), Vector2(-2.2, -3.6)
			])
		"mg":
			return PackedVector2Array([
				Vector2(-5.6, 3.6), Vector2(5.8, 3.6), Vector2(5.0, -3.4),
				Vector2(3.6, -15.6), Vector2(2.2, -24.6), Vector2(-1.8, -24.6),
				Vector2(-3.4, -15.6), Vector2(-4.8, -3.4)
			])
		"rifle":
			return PackedVector2Array([
				Vector2(-1.55, 4.0), Vector2(1.65, 4.0), Vector2(1.35, -5.6),
				Vector2(1.00, -22.4), Vector2(0.48, -32.2), Vector2(-0.48, -32.2),
				Vector2(-1.00, -22.4), Vector2(-1.35, -5.6)
			])
		_:
			match role:
				1:
					return silhouette("mg", 0)
				2:
					return silhouette("scout", 0)
				_:
					return silhouette("rifle", 0)


static func barrel_tip_y(id: String, role: int = 0) -> float:
	var pts := silhouette(id, role)
	var tip := 0.0
	for p in pts:
		tip = minf(tip, p.y)
	return tip


static func steel_color(id: String) -> Color:
	match id:
		"mg", "mg42", "mg34", "bar", "bren", "dp28":
			return Color(0.16, 0.14, 0.08, 0.98)
		"scout", "kar98k_zf", "springfield", "enfield_t", "mosin_pu":
			return Color(0.10, 0.12, 0.10, 0.98)
		"mp40", "sten", "thompson", "pps43", "mp38", "smg":
			return Color(0.18, 0.16, 0.12, 0.98)
		"shotgun", "winchester_m12", "ithaca37", "m30_drilling":
			return Color(0.22, 0.16, 0.10, 0.98)
		"luger", "p38":
			return Color(0.20, 0.20, 0.18, 0.98)
		"knife":
			return Color(0.62, 0.62, 0.56, 0.96)
		_:
			return Color(0.13, 0.14, 0.12, 0.98)


static func stock_poly(id: String, _role: int = 0) -> PackedVector2Array:
	var fam := id
	if WeaponCatalog.is_firearm(id):
		fam = WeaponCatalog.family_of(id)
	match fam:
		"mg":
			return PackedVector2Array([
				Vector2(-3.6, 4.4), Vector2(3.8, 4.4), Vector2(3.2, 9.2), Vector2(-3.0, 9.2)
			])
		"smg":
			return PackedVector2Array([
				Vector2(-2.4, 5.4), Vector2(1.8, 5.4), Vector2(1.4, 10.6), Vector2(-2.8, 10.6)
			])
		"pistol", "knife":
			return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
		"scout":
			return PackedVector2Array([
				Vector2(-1.8, 3.8), Vector2(1.8, 3.8), Vector2(1.4, 8.8), Vector2(-1.6, 8.8)
			])
		_:
			return PackedVector2Array([
				Vector2(-2.2, 3.6), Vector2(2.2, 3.6), Vector2(1.8, 9.0), Vector2(-2.0, 9.0)
			])


static func wood_color(id: String) -> Color:
	match id:
		"lee_enfield", "enfield_t", "webley":
			return Color(0.28, 0.18, 0.10, 0.95)
		"m1_garand", "springfield", "m1911", "bar", "winchester_m12":
			return Color(0.32, 0.20, 0.10, 0.95)
		"mosin", "mosin_pu", "svt40", "dp28", "tt33":
			return Color(0.24, 0.16, 0.08, 0.95)
		_:
			return Color(0.26, 0.17, 0.08, 0.95)


static func icon_poly(id: String) -> PackedVector2Array:
	## HUD stamp, ~22px wide, muzzle to the right. Per-model, not family blobs.
	match id:
		"mg42":
			return PackedVector2Array([
				Vector2(-11, -5.2), Vector2(12, -4.6), Vector2(13, 0), Vector2(12, 4.6),
				Vector2(-11, 5.2), Vector2(-12, 0)
			])
		"mg34":
			return PackedVector2Array([
				Vector2(-10, -3.6), Vector2(12, -3.2), Vector2(12, 3.2), Vector2(-10, 3.6)
			])
		"bar":
			return PackedVector2Array([
				Vector2(-9, -3.2), Vector2(11, -3.2), Vector2(11, 3.2), Vector2(-4, 3.2),
				Vector2(-5, 7.2), Vector2(-9, 7.2)
			])
		"bren":
			return PackedVector2Array([
				Vector2(-9, -3.0), Vector2(-2, -3.0), Vector2(-2, -8.2), Vector2(2.4, -8.2),
				Vector2(2.4, -3.0), Vector2(11, -3.0), Vector2(11, 3.0), Vector2(-9, 3.0)
			])
		"dp28":
			return PackedVector2Array([
				Vector2(-9, -3.0), Vector2(-5, -3.0), Vector2(-4, -8.4), Vector2(4, -8.4),
				Vector2(5, -3.0), Vector2(11, -3.0), Vector2(11, 3.0), Vector2(-9, 3.0)
			])
		"kar98k":
			return PackedVector2Array([
				Vector2(-10, -2.2), Vector2(13, -1.8), Vector2(13.6, 0), Vector2(13, 1.8),
				Vector2(-10, 2.2), Vector2(-8, 0)
			])
		"lee_enfield":
			return PackedVector2Array([
				Vector2(-10, -2.4), Vector2(12, -2.4), Vector2(12, 2.4), Vector2(-4, 2.4),
				Vector2(-4, 6.2), Vector2(-8, 6.2), Vector2(-10, 2.4)
			])
		"m1_garand":
			return PackedVector2Array([
				Vector2(-10, -2.6), Vector2(-3, -2.6), Vector2(-1, -6.0), Vector2(2, -6.0),
				Vector2(3, -2.6), Vector2(12, -2.6), Vector2(12, 2.6), Vector2(-10, 2.6)
			])
		"mosin":
			return PackedVector2Array([
				Vector2(-9, -1.8), Vector2(14, -1.6), Vector2(14.4, 0), Vector2(14, 1.6),
				Vector2(-9, 1.8)
			])
		"gewehr43":
			return PackedVector2Array([
				Vector2(-10, -2.8), Vector2(12, -2.8), Vector2(12, 2.8), Vector2(2, 2.8),
				Vector2(2, 6.4), Vector2(-2, 6.4), Vector2(-2, 2.8), Vector2(-10, 2.8)
			])
		"svt40":
			return PackedVector2Array([
				Vector2(-10, -2.4), Vector2(13, -2.4), Vector2(13, 2.4), Vector2(3, 2.4),
				Vector2(3, 5.6), Vector2(0, 5.6), Vector2(-1, 2.4), Vector2(-10, 2.4)
			])
		"sten":
			return PackedVector2Array([
				Vector2(-8, -2.4), Vector2(10, -2.4), Vector2(10, 2.4), Vector2(-8, 2.4),
				Vector2(-2, 2.4), Vector2(-2, 8.4), Vector2(2, 8.4), Vector2(2, 2.4)
			])
		"thompson":
			return PackedVector2Array([
				Vector2(-9, -3.4), Vector2(-6, -3.4), Vector2(-5, -8.0), Vector2(1, -8.0),
				Vector2(2, -3.4), Vector2(10, -3.4), Vector2(10, 3.4), Vector2(-9, 3.4)
			])
		"pps43":
			return PackedVector2Array([
				Vector2(-7, -2.6), Vector2(11, -2.2), Vector2(11, 2.2), Vector2(-7, 2.6),
				Vector2(-10, 6.4), Vector2(-7, 6.4)
			])
		"mp38":
			return PackedVector2Array([
				Vector2(-9, -2.8), Vector2(9, -2.8), Vector2(9, 2.8), Vector2(-9, 2.8),
				Vector2(-11, 7.2), Vector2(-8, 7.2)
			])
		"mp40", "smg":
			return PackedVector2Array([
				Vector2(-8, -3), Vector2(9, -3), Vector2(9, 3), Vector2(-4, 3),
				Vector2(-8, 8), Vector2(-11, 8), Vector2(-11, 3)
			])
		"luger":
			return PackedVector2Array([
				Vector2(-5, -2.2), Vector2(9, -2.2), Vector2(10, 0), Vector2(8, 2.4),
				Vector2(-2, 2.4), Vector2(-6, 7.2), Vector2(-9, 6.0)
			])
		"webley":
			return PackedVector2Array([
				Vector2(-6, -3.6), Vector2(7, -2.4), Vector2(8, 0), Vector2(6, 3.8),
				Vector2(-6, 4.2), Vector2(-8, 0)
			])
		"p38":
			return PackedVector2Array([
				Vector2(-6, -2.4), Vector2(8, -2.4), Vector2(9, 0.4), Vector2(7, 3.2),
				Vector2(-6, 3.2)
			])
		"tt33":
			return PackedVector2Array([
				Vector2(-5, -2.0), Vector2(9, -2.0), Vector2(9.6, 0), Vector2(8, 2.2),
				Vector2(-5, 2.2)
			])
		"m1911", "pistol":
			return PackedVector2Array([
				Vector2(-6, -2.6), Vector2(7, -2.6), Vector2(8, 0), Vector2(6, 3.4),
				Vector2(-6, 3.4)
			])
		"kar98k_zf":
			return PackedVector2Array([
				Vector2(-9, -1.8), Vector2(-2, -1.8), Vector2(-2, -5.4), Vector2(4, -5.4),
				Vector2(4, -1.8), Vector2(14, -1.6), Vector2(14, 1.6), Vector2(-9, 1.8)
			])
		"springfield":
			return PackedVector2Array([
				Vector2(-9, -2.0), Vector2(0, -2.0), Vector2(0, -5.0), Vector2(5, -5.0),
				Vector2(5, -2.0), Vector2(13, -2.0), Vector2(13, 2.0), Vector2(-9, 2.0)
			])
		"mosin_pu":
			return PackedVector2Array([
				Vector2(-8, -1.6), Vector2(-1, -1.6), Vector2(-1, -5.6), Vector2(3.6, -5.6),
				Vector2(3.6, -1.6), Vector2(14, -1.4), Vector2(14, 1.4), Vector2(-8, 1.6)
			])
		"enfield_t", "scout":
			return PackedVector2Array([
				Vector2(-8, -2.2), Vector2(12, -2.2), Vector2(12, 2.2), Vector2(-8, 2.2)
			])
		"m30_drilling":
			return PackedVector2Array([
				Vector2(-9, -4.6), Vector2(11, -4.6), Vector2(11, -1.2), Vector2(-9, -1.2),
				Vector2(-9, 1.2), Vector2(11, 1.2), Vector2(11, 4.6), Vector2(-9, 4.6)
			])
		"ithaca37":
			return PackedVector2Array([
				Vector2(-9, -3.0), Vector2(11, -4.2), Vector2(11, 2.6), Vector2(-9, 3.8)
			])
		"winchester_m12", "shotgun":
			return PackedVector2Array([
				Vector2(-9, -3.4), Vector2(10, -4.4), Vector2(10, 4.4), Vector2(-9, 3.4)
			])
		"knife":
			return PackedVector2Array([
				Vector2(-6, -1.4), Vector2(8, -1.4), Vector2(10, 0), Vector2(8, 1.4),
				Vector2(-6, 1.4)
			])
		_:
			var fam := id
			if WeaponCatalog.is_firearm(id):
				fam = WeaponCatalog.family_of(id)
			match fam:
				"mg":
					return PackedVector2Array([
						Vector2(-10, -4), Vector2(11, -4), Vector2(11, 4), Vector2(-10, 4)
					])
				"scout":
					return PackedVector2Array([
						Vector2(-8, -2.2), Vector2(12, -2.2), Vector2(12, 2.2), Vector2(-8, 2.2)
					])
				"smg":
					return PackedVector2Array([
						Vector2(-8, -3), Vector2(9, -3), Vector2(9, 3), Vector2(-4, 3),
						Vector2(-8, 8), Vector2(-11, 8), Vector2(-11, 3)
					])
				"shotgun":
					return PackedVector2Array([
						Vector2(-9, -3.4), Vector2(10, -4.4), Vector2(10, 4.4), Vector2(-9, 3.4)
					])
				"pistol":
					return PackedVector2Array([
						Vector2(-6, -2.6), Vector2(7, -2.6), Vector2(8, 0), Vector2(6, 3.4),
						Vector2(-6, 3.4)
					])
				_:
					return PackedVector2Array([
						Vector2(-9, -2.6), Vector2(11, -2.6), Vector2(11, 2.6), Vector2(-9, 2.6)
					])


static func ground_poly(id: String) -> PackedVector2Array:
	## Dropped firearm on the mud: muzzle to the right, flattened silhouette.
	var pts := silhouette(id)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(-p.y * 0.52, p.x * 0.52))
	return out


static func is_bolt(id: String) -> bool:
	match id:
		"kar98k", "mosin", "lee_enfield", "kar98k_zf", "springfield", "enfield_t", "mosin_pu":
			return true
		_:
			return false


static func bolt_knob_poly(id: String) -> PackedVector2Array:
	## Right-side bolt handle. Local space matches silhouette (muzzle -Y).
	if not is_bolt(id):
		return PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)])
	var reach := 4.6 if id in ["mosin", "mosin_pu"] else 4.0
	var y := 1.4 if id.begins_with("kar98") else (0.6 if id in ["lee_enfield", "enfield_t"] else 1.0)
	return PackedVector2Array([
		Vector2(1.4, y - 0.6), Vector2(reach, y - 1.2), Vector2(reach + 0.6, y + 0.6), Vector2(1.6, y + 1.2)
	])


static func muzzle_style(id: String) -> String:
	var d: Dictionary = WeaponCatalog.def(id)
	return str(d.get("muzzle", "rifle"))


static func muzzle_intensity(id: String) -> float:
	var d: Dictionary = WeaponCatalog.def(id)
	return float(d.get("muzzle_i", 1.0))
