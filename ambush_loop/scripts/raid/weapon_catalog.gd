class_name WeaponCatalog
extends RefCounted

## Commandos 2 kit: five firearm families × (Allied 1 + Axis 1) = 10 named guns.
## Class ids (rifle/mg/scout/...) still resolve crates and keep raid smoke.

const KNIFE := "knife"
const PISTOL := "pistol"
const RIFLE := "rifle"
const MG := "mg"
const SCOUT := "scout"
const SHOTGUN := "shotgun"
const SMG := "smg"
const AMMO := "ammo"
const GRENADE := "grenade"
const MINE := "mine"
const DECOY := "decoy"

const M1911 := "m1911"
const LUGER := "luger"
const M1_GARAND := "m1_garand"
const KAR98K := "kar98k"
const THOMPSON := "thompson"
const MP40 := "mp40"
const BAR := "bar"
const MG42 := "mg42"
const SPRINGFIELD := "springfield"
const KAR98K_ZF := "kar98k_zf"


static func all_ids() -> PackedStringArray:
	var out := PackedStringArray([KNIFE, PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG, AMMO, GRENADE, MINE, DECOY])
	out.append_array(model_ids())
	return out


static func model_ids() -> PackedStringArray:
	return PackedStringArray([
		M1911, LUGER,
		M1_GARAND, KAR98K,
		THOMPSON, MP40,
		BAR, MG42,
		SPRINGFIELD, KAR98K_ZF,
	])


static func kit_table() -> Array:
	return [
		{"family": PISTOL, "zh": "手枪", "allied": M1911, "axis": LUGER},
		{"family": RIFLE, "zh": "步枪", "allied": M1_GARAND, "axis": KAR98K},
		{"family": SMG, "zh": "冲锋枪", "allied": THOMPSON, "axis": MP40},
		{"family": MG, "zh": "轻机枪", "allied": BAR, "axis": MG42},
		{"family": SCOUT, "zh": "狙击", "allied": SPRINGFIELD, "axis": KAR98K_ZF},
	]


static func banned_tail() -> PackedStringArray:
	return PackedStringArray([
		"gewehr43", "svt40", "mosin", "lee_enfield",
		"pps43", "mp38", "sten",
		"mg34", "bren", "dp28",
		"webley", "p38", "tt33",
		"enfield_t", "mosin_pu",
		"winchester_m12", "ithaca37", "m30_drilling",
	])


static func class_firearm_ids() -> PackedStringArray:
	return PackedStringArray([PISTOL, RIFLE, MG, SCOUT, SMG])


static func is_firearm(id: String) -> bool:
	if id in [PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG]:
		return true
	return id in model_ids()


static func is_throwable(id: String) -> bool:
	return id in [GRENADE, MINE, DECOY]


static func family_of(id: String) -> String:
	match id:
		"pistol_ammo":
			return PISTOL
		"rifle_ammo":
			return RIFLE
		"mg_ammo":
			return MG
		"scout_ammo":
			return SCOUT
		"shotgun_ammo":
			return SHOTGUN
		"smg_ammo":
			return SMG
		M1_GARAND, KAR98K:
			return RIFLE
		THOMPSON, MP40, SMG:
			return SMG
		MG42, BAR:
			return MG
		M1911, LUGER:
			return PISTOL
		KAR98K_ZF, SPRINGFIELD:
			return SCOUT
		_:
			return id


static func side_of(id: String) -> String:
	match id:
		M1911, M1_GARAND, THOMPSON, BAR, SPRINGFIELD:
			return "allied"
		LUGER, KAR98K, MP40, MG42, KAR98K_ZF:
			return "axis"
		_:
			return ""


static func ammo_kind_of(id: String) -> String:
	match id:
		PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG:
			return id
		"pistol_ammo":
			return PISTOL
		"rifle_ammo":
			return RIFLE
		"mg_ammo":
			return MG
		"scout_ammo":
			return SCOUT
		"shotgun_ammo":
			return SHOTGUN
		"smg_ammo":
			return SMG
		AMMO:
			return ""
		_:
			if is_firearm(id):
				return family_of(id)
			return ""


static func is_typed_ammo(id: String) -> bool:
	match id:
		"pistol_ammo", "rifle_ammo", "mg_ammo", "scout_ammo", "shotgun_ammo", "smg_ammo":
			return true
		_:
			return false


static func display_name(id: String) -> String:
	match id:
		KNIFE:
			return "刀"
		PISTOL:
			return "手枪"
		RIFLE:
			return "步枪"
		MG:
			return "机枪"
		SCOUT:
			return "狙"
		SHOTGUN:
			return "散弹"
		SMG:
			return "冲锋枪"
		AMMO:
			return "弹药"
		"pistol_ammo":
			return "手枪弹"
		"rifle_ammo":
			return "步枪弹"
		"mg_ammo":
			return "机枪弹"
		"scout_ammo":
			return "狙弹"
		"shotgun_ammo":
			return "散弹"
		"smg_ammo":
			return "冲锋枪弹"
		"radio_part":
			return "电台零件"
		GRENADE:
			return "手雷"
		MINE:
			return "地雷"
		DECOY:
			return "诱饵"
		KAR98K:
			return "Kar98k"
		M1_GARAND:
			return "M1加兰德"
		MP40:
			return "MP40"
		THOMPSON:
			return "汤姆逊"
		MG42:
			return "MG42"
		BAR:
			return "BAR"
		M1911:
			return "M1911"
		LUGER:
			return "卢格"
		KAR98K_ZF:
			return "98K瞄准镜"
		SPRINGFIELD:
			return "春田"
		_:
			return id


static func tag_zh(id: String) -> String:
	return display_name(id)


static func def(id: String) -> Dictionary:
	match id:
		KNIFE:
			return {
				"id": KNIFE, "family": KNIFE, "range_px": 36.0, "half_angle_deg": 40.0,
				"damage": 90.0, "shot_interval": 0.42, "start_ammo": 0, "max_ammo": 0,
				"melee": true, "recoil": 0.4, "spread_deg": 0.0, "reload_s": 0.0,
				"muzzle": "rifle", "muzzle_i": 0.0, "sfx": "", "rarity": 0, "loot_weight": 0,
			}
		PISTOL:
			return _class_gun(PISTOL, PISTOL, 150.0, 22.0, 28.0, 0.16, 8, 16, 0.85, 2.0, 0.42, "pistol", 0.78, "fire_pistol")
		RIFLE:
			return _class_gun(RIFLE, RIFLE, 220.0, 28.0, 34.0, 0.18, 7, 14, 1.0, 1.5, 0.55, "rifle", 1.05, "fire")
		MG:
			return _class_gun(MG, MG, 205.0, 48.0, 22.0, 0.10, 12, 18, 1.45, 4.0, 1.10, "mg", 1.48, "fire_mg")
		SCOUT:
			return _class_gun(SCOUT, SCOUT, 280.0, 20.0, 42.0, 0.28, 6, 10, 0.72, 0.8, 0.85, "scout", 0.82, "fire_scout")
		SHOTGUN:
			return _class_gun(SHOTGUN, SHOTGUN, 110.0, 52.0, 48.0, 0.36, 4, 8, 1.35, 6.0, 0.70, "shotgun", 1.35, "fire_shotgun")
		SMG:
			return _class_gun(SMG, SMG, 138.0, 38.0, 18.0, 0.08, 24, 32, 0.70, 5.5, 0.90, "smg", 0.92, "fire_smg")
		GRENADE:
			return {
				"id": GRENADE, "fuse": 0.55, "radius": 78.0, "damage": 78.0,
				"throw_range": 160.0, "auto_cd": 3.6, "cone_half_deg": 52.0,
				"ff_radius_mul": 0.55,
			}
		MINE:
			return {"id": MINE, "radius": 22.0, "damage": 120.0}
		DECOY:
			return {"id": DECOY, "radius": 90.0, "delay": 1.4}
		AMMO:
			return {"id": AMMO, "amount": 6}
		KAR98K:
			return _model(KAR98K, RIFLE, 248.0, 18.0, 48.0, 0.52, 5, 10, 1.35, 0.6, 1.15, "rifle", 0.95, "fire_bolt", 2, 6)
		M1_GARAND:
			return _model(M1_GARAND, RIFLE, 228.0, 24.0, 36.0, 0.20, 8, 16, 1.10, 1.4, 0.48, "rifle", 1.12, "fire_garand", 3, 5)
		MP40:
			return _model(MP40, SMG, 142.0, 34.0, 18.0, 0.078, 32, 32, 0.62, 4.8, 0.95, "smg", 0.88, "fire_smg", 2, 8)
		THOMPSON:
			return _model(THOMPSON, SMG, 136.0, 40.0, 21.0, 0.068, 20, 30, 0.82, 5.4, 1.05, "smg", 1.10, "fire_smg", 3, 5)
		MG42:
			return _model(MG42, MG, 198.0, 54.0, 18.0, 0.055, 50, 50, 1.85, 6.5, 1.40, "mg", 1.72, "fire_mg42", 3, 3)
		BAR:
			return _model(BAR, MG, 216.0, 34.0, 28.0, 0.115, 20, 20, 1.15, 2.8, 0.95, "mg", 1.22, "fire_mg", 3, 5)
		M1911:
			return _model(M1911, PISTOL, 146.0, 20.0, 26.0, 0.18, 7, 21, 0.90, 2.2, 0.50, "pistol", 0.80, "fire_pistol", 2, 8)
		LUGER:
			return _model(LUGER, PISTOL, 158.0, 16.0, 22.0, 0.15, 8, 24, 0.70, 1.6, 0.55, "pistol", 0.72, "fire_pistol", 3, 5)
		KAR98K_ZF:
			return _model(KAR98K_ZF, SCOUT, 322.0, 11.0, 58.0, 0.62, 5, 10, 1.55, 0.4, 1.35, "scout", 0.70, "fire_scout", 4, 2)
		SPRINGFIELD:
			return _model(SPRINGFIELD, SCOUT, 312.0, 13.0, 52.0, 0.48, 5, 10, 1.25, 0.5, 1.10, "scout", 0.76, "fire_scout", 4, 2)
		_:
			return def(KNIFE)


static func _class_gun(
	id: String, family: String, rng: float, half: float, dmg: float, interval: float,
	start_a: int, max_a: int, recoil: float, spread: float, reload: float,
	muzzle: String, muzzle_i: float, sfx: String
) -> Dictionary:
	return {
		"id": id, "family": family, "range_px": rng, "half_angle_deg": half,
		"damage": dmg, "shot_interval": interval, "start_ammo": start_a, "max_ammo": max_a,
		"melee": false, "recoil": recoil, "spread_deg": spread, "reload_s": reload,
		"muzzle": muzzle, "muzzle_i": muzzle_i, "sfx": sfx, "rarity": 1, "loot_weight": 8,
	}


static func _model(
	id: String, family: String, rng: float, half: float, dmg: float, interval: float,
	start_a: int, max_a: int, recoil: float, spread: float, reload: float,
	muzzle: String, muzzle_i: float, sfx: String, rarity: int, weight: int
) -> Dictionary:
	return {
		"id": id, "family": family, "range_px": rng, "half_angle_deg": half,
		"damage": dmg, "shot_interval": interval, "start_ammo": start_a, "max_ammo": max_a,
		"melee": false, "recoil": recoil, "spread_deg": spread, "reload_s": reload,
		"muzzle": muzzle, "muzzle_i": muzzle_i, "sfx": sfx, "rarity": rarity, "loot_weight": weight,
	}


static func color(id: String) -> Color:
	var fam := family_of(id)
	match fam:
		MG:
			return Color(0.58, 0.52, 0.28)
		SCOUT:
			return Color(0.42, 0.48, 0.36)
		SHOTGUN:
			return Color(0.62, 0.42, 0.22)
		SMG:
			return Color(0.48, 0.40, 0.26)
		GRENADE:
			return Color(0.62, 0.38, 0.16)
		MINE:
			return Color(0.42, 0.40, 0.22)
		DECOY:
			return Color(0.70, 0.58, 0.28)
		PISTOL:
			return Color(0.58, 0.56, 0.48)
		AMMO, "pistol_ammo", "rifle_ammo", "mg_ammo", "scout_ammo", "shotgun_ammo", "smg_ammo":
			return Color(0.72, 0.56, 0.24)
		KNIFE:
			return Color(0.70, 0.68, 0.60)
		_:
			return Color(0.48, 0.46, 0.32)


static func sfx_cue(id: String) -> String:
	var d: Dictionary = def(id)
	var cue := str(d.get("sfx", ""))
	if cue != "":
		return cue
	match family_of(id):
		MG:
			return "fire_mg"
		SCOUT:
			return "fire_scout"
		SMG:
			return "fire_smg"
		PISTOL:
			return "fire_pistol"
		SHOTGUN:
			return "fire_shotgun"
		_:
			return "fire"


static func is_class_firearm(id: String) -> bool:
	return id in [PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG]


static func grenade_variant_for(weapon_id: String, night_id: String = "") -> String:
	var side := side_of(weapon_id)
	if side == "allied":
		return "mk2" if night_id in ["depot", "radio"] else "mills"
	if side == "axis":
		return "stiel"
	match str(night_id):
		"pump":
			return "mills"
		"depot", "radio":
			return "mk2"
		_:
			return "stiel"


static func signature_model(night_id: String, family: String) -> String:
	## Stable per-night named gun from the 10-gun kit.
	match str(night_id):
		"warehouse":
			match family:
				RIFLE:
					return KAR98K
				MG:
					return BAR
				SCOUT:
					return SPRINGFIELD
				SMG:
					return MP40
				PISTOL:
					return LUGER
				_:
					return ""
		"pump":
			match family:
				RIFLE:
					return M1_GARAND
				MG:
					return BAR
				SCOUT:
					return SPRINGFIELD
				SMG:
					return THOMPSON
				PISTOL:
					return M1911
				_:
					return ""
		"railcut":
			match family:
				RIFLE:
					return KAR98K
				MG:
					return MG42
				SCOUT:
					return KAR98K_ZF
				SMG:
					return MP40
				PISTOL:
					return LUGER
				_:
					return ""
		"depot":
			match family:
				RIFLE:
					return M1_GARAND
				MG:
					return BAR
				SCOUT:
					return SPRINGFIELD
				SMG:
					return THOMPSON
				PISTOL:
					return M1911
				_:
					return ""
		"radio":
			match family:
				RIFLE:
					return KAR98K
				MG:
					return MG42
				SCOUT:
					return SPRINGFIELD
				SMG:
					return MP40
				PISTOL:
					return LUGER
				_:
					return ""
		_:
			match family:
				RIFLE:
					return KAR98K
				MG:
					return MG42
				SCOUT:
					return KAR98K_ZF
				SMG:
					return THOMPSON
				PISTOL:
					return M1911
				_:
					return ""


static func resolve_crate_kind(kind: String, night_id: String, index: int = 0) -> String:
	var k := str(kind)
	if k in banned_tail():
		var fam := family_of(k)
		var sig := signature_model(night_id, fam if fam != k else RIFLE)
		return sig if sig != "" else k
	if not is_firearm(k) or not is_class_firearm(k):
		return k
	if k == SHOTGUN:
		return signature_model(night_id, SMG)
	var sig := signature_model(night_id, k)
	if sig != "":
		return sig
	var fam := models_in_family(k)
	if fam.is_empty():
		return k
	return fam[absi(index) % fam.size()]


static func models_in_family(fam: String) -> PackedStringArray:
	var out := PackedStringArray()
	for mid in model_ids():
		if family_of(mid) == fam:
			out.append(mid)
	return out


static func distinct_cadence_pair(fam: String) -> PackedStringArray:
	var ids := models_in_family(fam)
	if ids.size() < 2:
		return PackedStringArray()
	var a := ids[0]
	var b := ids[1]
	var ia := float(def(a).get("shot_interval", 0.2))
	var ib := float(def(b).get("shot_interval", 0.2))
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var x := ids[i]
			var y := ids[j]
			var dx: float = absf(float(def(x).get("shot_interval", 0.0)) - float(def(y).get("shot_interval", 0.0)))
			if dx > absf(ia - ib):
				a = x
				b = y
				ia = float(def(x).get("shot_interval", 0.0))
				ib = float(def(y).get("shot_interval", 0.0))
	return PackedStringArray([a, b])


static func enemy_drop_for(loot_ammo: int, kit: String = "", night_id: String = "", seed_n: int = 0) -> Dictionary:
	if str(kit) == "echo":
		return {"kind": "radio_part", "amount": 1}
	var table: Array = drop_table_for_night(night_id)
	var idx := absi(loot_ammo + seed_n) % maxi(table.size(), 1)
	var pick: Dictionary = table[idx] if not table.is_empty() else {"kind": AMMO, "amount": 3}
	if loot_ammo <= 0:
		return {"kind": AMMO, "amount": 2}
	if loot_ammo == 1:
		return {"kind": AMMO, "amount": maxi(int(pick.get("amount", 3)), 3)}
	return {"kind": str(pick.get("kind", AMMO)), "amount": int(pick.get("amount", maxi(loot_ammo, 3)))}


static func drop_table_for_night(night_id: String) -> Array:
	match str(night_id):
		"warehouse":
			return [
				{"kind": AMMO, "amount": 5},
				{"kind": GRENADE, "amount": 1},
				{"kind": "rifle_ammo", "amount": 4},
				{"kind": KAR98K, "amount": 5},
				{"kind": MP40, "amount": 32},
			]
		"pump":
			return [
				{"kind": AMMO, "amount": 4},
				{"kind": MINE, "amount": 1},
				{"kind": GRENADE, "amount": 1},
				{"kind": M1_GARAND, "amount": 8},
				{"kind": THOMPSON, "amount": 20},
			]
		"railcut":
			return [
				{"kind": "mg_ammo", "amount": 6},
				{"kind": AMMO, "amount": 4},
				{"kind": GRENADE, "amount": 1},
				{"kind": MG42, "amount": 50},
				{"kind": BAR, "amount": 20},
			]
		"depot":
			return [
				{"kind": MINE, "amount": 1},
				{"kind": "smg_ammo", "amount": 12},
				{"kind": AMMO, "amount": 5},
				{"kind": THOMPSON, "amount": 20},
				{"kind": M1_GARAND, "amount": 8},
			]
		"radio":
			return [
				{"kind": DECOY, "amount": 1},
				{"kind": "scout_ammo", "amount": 3},
				{"kind": AMMO, "amount": 5},
				{"kind": SPRINGFIELD, "amount": 5},
				{"kind": LUGER, "amount": 8},
			]
		_:
			return [
				{"kind": GRENADE, "amount": 1},
				{"kind": MINE, "amount": 1},
				{"kind": AMMO, "amount": 4},
				{"kind": AMMO, "amount": 3},
				{"kind": M1911, "amount": 7},
				{"kind": KAR98K, "amount": 5},
			]
