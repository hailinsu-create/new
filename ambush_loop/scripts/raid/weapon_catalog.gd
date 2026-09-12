class_name WeaponCatalog
extends RefCounted

## Firearm defs. Class ids (rifle/mg/scout/...) keep raid smoke.
## WWII models add cadence, recoil, mag, muzzle, sfx, loot weight.

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

const KAR98K := "kar98k"
const LEE_ENFIELD := "lee_enfield"
const M1_GARAND := "m1_garand"
const MOSIN := "mosin"
const GEWEHR43 := "gewehr43"
const SVT40 := "svt40"
const MP40 := "mp40"
const STEN := "sten"
const THOMPSON := "thompson"
const PPS43 := "pps43"
const MP38 := "mp38"
const MG42 := "mg42"
const MG34 := "mg34"
const BAR := "bar"
const BREN := "bren"
const DP28 := "dp28"
const M1911 := "m1911"
const LUGER := "luger"
const P38 := "p38"
const WEBLEY := "webley"
const TT33 := "tt33"
const KAR98K_ZF := "kar98k_zf"
const SPRINGFIELD := "springfield"
const ENFIELD_T := "enfield_t"
const MOSIN_PU := "mosin_pu"
const WINCHESTER_M12 := "winchester_m12"
const ITHACA37 := "ithaca37"
const M30_DRILLING := "m30_drilling"


static func all_ids() -> PackedStringArray:
	var out := PackedStringArray([KNIFE, PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG, AMMO, GRENADE, MINE, DECOY])
	out.append_array(model_ids())
	return out


static func model_ids() -> PackedStringArray:
	return PackedStringArray([
		KAR98K, LEE_ENFIELD, M1_GARAND, MOSIN, GEWEHR43, SVT40,
		MP40, STEN, THOMPSON, PPS43, MP38,
		MG42, MG34, BAR, BREN, DP28,
		M1911, LUGER, P38, WEBLEY, TT33,
		KAR98K_ZF, SPRINGFIELD, ENFIELD_T, MOSIN_PU,
		WINCHESTER_M12, ITHACA37, M30_DRILLING,
	])


static func class_firearm_ids() -> PackedStringArray:
	return PackedStringArray([PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG])


static func is_firearm(id: String) -> bool:
	match id:
		PISTOL, RIFLE, MG, SCOUT, SHOTGUN, SMG:
			return true
		KAR98K, LEE_ENFIELD, M1_GARAND, MOSIN, GEWEHR43, SVT40:
			return true
		MP40, STEN, THOMPSON, PPS43, MP38:
			return true
		MG42, MG34, BAR, BREN, DP28:
			return true
		M1911, LUGER, P38, WEBLEY, TT33:
			return true
		KAR98K_ZF, SPRINGFIELD, ENFIELD_T, MOSIN_PU:
			return true
		WINCHESTER_M12, ITHACA37, M30_DRILLING:
			return true
		_:
			return false


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
		KAR98K, LEE_ENFIELD, M1_GARAND, MOSIN, GEWEHR43, SVT40:
			return RIFLE
		MP40, STEN, THOMPSON, PPS43, MP38, SMG:
			return SMG
		MG42, MG34, BAR, BREN, DP28:
			return MG
		M1911, LUGER, P38, WEBLEY, TT33:
			return PISTOL
		KAR98K_ZF, SPRINGFIELD, ENFIELD_T, MOSIN_PU:
			return SCOUT
		WINCHESTER_M12, ITHACA37, M30_DRILLING:
			return SHOTGUN
		_:
			return id


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
		LEE_ENFIELD:
			return "恩菲尔德"
		M1_GARAND:
			return "M1加兰德"
		MOSIN:
			return "莫辛"
		GEWEHR43:
			return "G43"
		SVT40:
			return "SVT-40"
		MP40:
			return "MP40"
		STEN:
			return "斯登"
		THOMPSON:
			return "汤姆逊"
		PPS43:
			return "PPS-43"
		MP38:
			return "MP38"
		MG42:
			return "MG42"
		MG34:
			return "MG34"
		BAR:
			return "BAR"
		BREN:
			return "布伦"
		DP28:
			return "DP-28"
		M1911:
			return "M1911"
		LUGER:
			return "卢格"
		P38:
			return "P38"
		WEBLEY:
			return "韦伯利"
		TT33:
			return "TT-33"
		KAR98K_ZF:
			return "98K瞄准镜"
		SPRINGFIELD:
			return "春田"
		ENFIELD_T:
			return "恩菲尔德T"
		MOSIN_PU:
			return "莫辛PU"
		WINCHESTER_M12:
			return "M12温彻斯特"
		ITHACA37:
			return "伊萨卡37"
		M30_DRILLING:
			return "M30钻枪"
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
			return _class_gun(PISTOL, PISTOL, 150.0, 22.0, 28.0, 0.16, 8, 16, 0.85, 2.0, 0.42, "pistol", 0.78, "fire")
		RIFLE:
			return _class_gun(RIFLE, RIFLE, 220.0, 28.0, 34.0, 0.18, 7, 14, 1.0, 1.5, 0.55, "rifle", 1.05, "fire")
		MG:
			return _class_gun(MG, MG, 205.0, 48.0, 22.0, 0.10, 12, 18, 1.45, 4.0, 1.10, "mg", 1.48, "fire_mg")
		SCOUT:
			return _class_gun(SCOUT, SCOUT, 280.0, 20.0, 42.0, 0.28, 6, 10, 0.72, 0.8, 0.85, "scout", 0.82, "fire_scout")
		SHOTGUN:
			return _class_gun(SHOTGUN, SHOTGUN, 110.0, 52.0, 48.0, 0.36, 4, 8, 1.35, 6.0, 0.70, "shotgun", 1.35, "fire")
		SMG:
			return _class_gun(SMG, SMG, 138.0, 38.0, 18.0, 0.08, 24, 32, 0.70, 5.5, 0.90, "smg", 0.92, "fire_smg")
		GRENADE:
			return {"id": GRENADE, "fuse": 0.55, "radius": 78.0, "damage": 78.0, "throw_range": 160.0}
		MINE:
			return {"id": MINE, "radius": 22.0, "damage": 120.0}
		DECOY:
			return {"id": DECOY, "radius": 90.0, "delay": 1.4}
		AMMO:
			return {"id": AMMO, "amount": 6}
		KAR98K:
			return _model(KAR98K, RIFLE, 248.0, 18.0, 48.0, 0.52, 5, 10, 1.35, 0.6, 1.15, "rifle", 0.95, "fire_bolt", 2, 6)
		LEE_ENFIELD:
			return _model(LEE_ENFIELD, RIFLE, 236.0, 22.0, 40.0, 0.34, 10, 20, 1.05, 1.1, 0.85, "rifle", 1.00, "fire_bolt", 2, 7)
		M1_GARAND:
			return _model(M1_GARAND, RIFLE, 228.0, 24.0, 36.0, 0.20, 8, 16, 1.10, 1.4, 0.48, "rifle", 1.12, "fire_garand", 3, 5)
		MOSIN:
			return _model(MOSIN, RIFLE, 252.0, 19.0, 46.0, 0.50, 5, 10, 1.40, 0.7, 1.20, "rifle", 0.98, "fire_bolt", 2, 6)
		GEWEHR43:
			return _model(GEWEHR43, RIFLE, 224.0, 26.0, 35.0, 0.22, 10, 20, 1.05, 1.8, 0.62, "rifle", 1.08, "fire", 3, 4)
		SVT40:
			return _model(SVT40, RIFLE, 226.0, 25.0, 34.0, 0.21, 10, 20, 1.00, 1.7, 0.64, "rifle", 1.06, "fire", 3, 4)
		MP40:
			return _model(MP40, SMG, 142.0, 34.0, 18.0, 0.078, 32, 32, 0.62, 4.8, 0.95, "smg", 0.88, "fire_smg", 2, 8)
		STEN:
			return _model(STEN, SMG, 128.0, 44.0, 15.0, 0.090, 32, 32, 0.55, 7.2, 0.80, "smg", 0.78, "fire_smg", 1, 10)
		THOMPSON:
			return _model(THOMPSON, SMG, 136.0, 40.0, 21.0, 0.068, 20, 30, 0.82, 5.4, 1.05, "smg", 1.10, "fire_smg", 3, 5)
		PPS43:
			return _model(PPS43, SMG, 132.0, 38.0, 17.0, 0.074, 35, 35, 0.58, 5.0, 0.88, "smg", 0.84, "fire_smg", 2, 7)
		MP38:
			return _model(MP38, SMG, 144.0, 32.0, 18.0, 0.084, 32, 32, 0.60, 4.2, 0.98, "smg", 0.86, "fire_smg", 2, 6)
		MG42:
			return _model(MG42, MG, 198.0, 54.0, 18.0, 0.055, 50, 50, 1.85, 6.5, 1.40, "mg", 1.72, "fire_mg42", 3, 3)
		MG34:
			return _model(MG34, MG, 210.0, 42.0, 21.0, 0.088, 50, 50, 1.35, 3.6, 1.20, "mg", 1.40, "fire_mg", 3, 4)
		BAR:
			return _model(BAR, MG, 216.0, 34.0, 28.0, 0.115, 20, 20, 1.15, 2.8, 0.95, "mg", 1.22, "fire_mg", 3, 5)
		BREN:
			return _model(BREN, MG, 218.0, 32.0, 26.0, 0.125, 30, 30, 1.08, 2.4, 1.05, "mg", 1.18, "fire_mg", 2, 5)
		DP28:
			return _model(DP28, MG, 206.0, 40.0, 24.0, 0.102, 47, 47, 1.22, 3.8, 1.15, "mg", 1.28, "fire_mg", 2, 5)
		M1911:
			return _model(M1911, PISTOL, 146.0, 20.0, 26.0, 0.18, 7, 21, 0.90, 2.2, 0.50, "pistol", 0.80, "fire", 2, 8)
		LUGER:
			return _model(LUGER, PISTOL, 158.0, 16.0, 22.0, 0.15, 8, 24, 0.70, 1.6, 0.55, "pistol", 0.72, "fire", 3, 5)
		P38:
			return _model(P38, PISTOL, 152.0, 19.0, 24.0, 0.16, 8, 24, 0.78, 1.9, 0.52, "pistol", 0.76, "fire", 2, 7)
		WEBLEY:
			return _model(WEBLEY, PISTOL, 138.0, 26.0, 32.0, 0.24, 6, 18, 1.20, 3.4, 0.70, "pistol", 0.90, "fire", 2, 5)
		TT33:
			return _model(TT33, PISTOL, 148.0, 21.0, 25.0, 0.17, 8, 24, 0.82, 2.0, 0.54, "pistol", 0.74, "fire", 2, 6)
		KAR98K_ZF:
			return _model(KAR98K_ZF, SCOUT, 322.0, 11.0, 58.0, 0.62, 5, 10, 1.55, 0.4, 1.35, "scout", 0.70, "fire_scout", 4, 2)
		SPRINGFIELD:
			return _model(SPRINGFIELD, SCOUT, 312.0, 13.0, 52.0, 0.48, 5, 10, 1.25, 0.5, 1.10, "scout", 0.76, "fire_scout", 4, 2)
		ENFIELD_T:
			return _model(ENFIELD_T, SCOUT, 300.0, 15.0, 48.0, 0.40, 10, 20, 1.05, 0.7, 0.95, "scout", 0.80, "fire_scout", 3, 3)
		MOSIN_PU:
			return _model(MOSIN_PU, SCOUT, 316.0, 12.0, 55.0, 0.56, 5, 10, 1.45, 0.45, 1.28, "scout", 0.72, "fire_scout", 3, 2)
		WINCHESTER_M12:
			return _model(WINCHESTER_M12, SHOTGUN, 108.0, 50.0, 52.0, 0.40, 5, 10, 1.40, 5.5, 0.62, "shotgun", 1.38, "fire", 2, 5)
		ITHACA37:
			return _model(ITHACA37, SHOTGUN, 104.0, 48.0, 50.0, 0.34, 5, 10, 1.28, 5.0, 0.58, "shotgun", 1.30, "fire", 2, 5)
		M30_DRILLING:
			return _model(M30_DRILLING, SHOTGUN, 118.0, 44.0, 58.0, 0.48, 2, 6, 1.60, 4.2, 0.85, "shotgun", 1.50, "fire", 3, 3)
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
		_:
			return "fire"


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
				{"kind": LEE_ENFIELD, "amount": 10},
				{"kind": STEN, "amount": 32},
			]
		"railcut":
			return [
				{"kind": "mg_ammo", "amount": 6},
				{"kind": AMMO, "amount": 4},
				{"kind": GRENADE, "amount": 1},
				{"kind": MG42, "amount": 50},
				{"kind": BREN, "amount": 30},
			]
		"depot":
			return [
				{"kind": MINE, "amount": 1},
				{"kind": "shotgun_ammo", "amount": 3},
				{"kind": AMMO, "amount": 5},
				{"kind": THOMPSON, "amount": 20},
				{"kind": WINCHESTER_M12, "amount": 5},
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
				{"kind": PISTOL, "amount": 6},
				{"kind": AMMO, "amount": 4},
				{"kind": AMMO, "amount": 3},
				{"kind": M1911, "amount": 7},
				{"kind": KAR98K, "amount": 5},
			]
