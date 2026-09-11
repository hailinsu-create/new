class_name WeaponCatalog
extends RefCounted

## Firearm and throwable defs. Roles still bias move speed; weapons replace cones.

const KNIFE := "knife"
const PISTOL := "pistol"
const RIFLE := "rifle"
const MG := "mg"
const SCOUT := "scout"
const SHOTGUN := "shotgun"
const AMMO := "ammo"
const GRENADE := "grenade"
const MINE := "mine"
const DECOY := "decoy"


static func all_ids() -> PackedStringArray:
	return PackedStringArray([KNIFE, PISTOL, RIFLE, MG, SCOUT, SHOTGUN, AMMO, GRENADE, MINE, DECOY])


static func is_firearm(id: String) -> bool:
	return id in [PISTOL, RIFLE, MG, SCOUT, SHOTGUN]


static func is_throwable(id: String) -> bool:
	return id in [GRENADE, MINE, DECOY]


static func ammo_kind_of(id: String) -> String:
	## Firearm id that this loot feeds. Empty = not ammo / not a gun.
	match id:
		PISTOL, RIFLE, MG, SCOUT, SHOTGUN:
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
		AMMO:
			return ""
		_:
			return ""


static func is_typed_ammo(id: String) -> bool:
	return ammo_kind_of(id) != "" and not is_firearm(id)


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
		"radio_part":
			return "电台零件"
		GRENADE:
			return "手雷"
		MINE:
			return "地雷"
		DECOY:
			return "诱饵"
		_:
			return id


static func tag_zh(id: String) -> String:
	return display_name(id)


static func def(id: String) -> Dictionary:
	match id:
		KNIFE:
			return {
				"id": KNIFE,
				"range_px": 36.0,
				"half_angle_deg": 40.0,
				"damage": 90.0,
				"shot_interval": 0.42,
				"start_ammo": 0,
				"max_ammo": 0,
				"melee": true,
			}
		PISTOL:
			return {
				"id": PISTOL,
				"range_px": 150.0,
				"half_angle_deg": 22.0,
				"damage": 28.0,
				"shot_interval": 0.16,
				"start_ammo": 8,
				"max_ammo": 16,
			}
		RIFLE:
			return {
				"id": RIFLE,
				"range_px": 220.0,
				"half_angle_deg": 28.0,
				"damage": 34.0,
				"shot_interval": 0.18,
				"start_ammo": 7,
				"max_ammo": 14,
			}
		MG:
			return {
				"id": MG,
				"range_px": 205.0,
				"half_angle_deg": 48.0,
				"damage": 22.0,
				"shot_interval": 0.10,
				"start_ammo": 12,
				"max_ammo": 18,
			}
		SCOUT:
			return {
				"id": SCOUT,
				"range_px": 280.0,
				"half_angle_deg": 20.0,
				"damage": 42.0,
				"shot_interval": 0.28,
				"start_ammo": 6,
				"max_ammo": 10,
			}
		SHOTGUN:
			return {
				"id": SHOTGUN,
				"range_px": 110.0,
				"half_angle_deg": 52.0,
				"damage": 48.0,
				"shot_interval": 0.36,
				"start_ammo": 4,
				"max_ammo": 8,
			}
		GRENADE:
			return {
				"id": GRENADE,
				"fuse": 0.55,
				"radius": 78.0,
				"damage": 78.0,
				"throw_range": 160.0,
			}
		MINE:
			return {
				"id": MINE,
				"radius": 22.0,
				"damage": 120.0,
			}
		DECOY:
			return {
				"id": DECOY,
				"radius": 90.0,
				"delay": 1.4,
			}
		AMMO:
			return {"id": AMMO, "amount": 6}
		_:
			return def(KNIFE)


static func color(id: String) -> Color:
	match id:
		MG:
			return Color(0.68, 0.78, 0.36)
		SCOUT:
			return Color(0.38, 0.82, 0.92)
		SHOTGUN:
			return Color(0.86, 0.58, 0.22)
		GRENADE:
			return Color(0.82, 0.42, 0.18)
		MINE:
			return Color(0.55, 0.72, 0.28)
		DECOY:
			return Color(0.92, 0.78, 0.28)
		PISTOL:
			return Color(0.70, 0.70, 0.62)
		AMMO, "pistol_ammo", "rifle_ammo", "mg_ammo", "scout_ammo", "shotgun_ammo":
			return Color(0.92, 0.74, 0.28)
		KNIFE:
			return Color(0.78, 0.78, 0.72)
		_:
			return Color(0.52, 0.72, 0.92)


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
			]
		"pump":
			return [
				{"kind": AMMO, "amount": 4},
				{"kind": MINE, "amount": 1},
				{"kind": GRENADE, "amount": 1},
			]
		"railcut":
			return [
				{"kind": "mg_ammo", "amount": 6},
				{"kind": AMMO, "amount": 4},
				{"kind": GRENADE, "amount": 1},
			]
		"depot":
			return [
				{"kind": MINE, "amount": 1},
				{"kind": "shotgun_ammo", "amount": 3},
				{"kind": AMMO, "amount": 5},
			]
		"radio":
			return [
				{"kind": DECOY, "amount": 1},
				{"kind": "scout_ammo", "amount": 3},
				{"kind": AMMO, "amount": 5},
			]
		_:
			return [
				{"kind": GRENADE, "amount": 1},
				{"kind": MINE, "amount": 1},
				{"kind": PISTOL, "amount": 6},
				{"kind": AMMO, "amount": 4},
				{"kind": AMMO, "amount": 3},
			]
