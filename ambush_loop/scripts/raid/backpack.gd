class_name RaidBackpack
extends RefCounted

## Per-operator Commandos-style pack. Six slots. Guns and throwables occupy
## a slot; ammo pools live on the operator and do not take a grid cell.

const SLOT_COUNT := 6
const Weapons := preload("res://scripts/raid/weapon_catalog.gd")

var slots: Array = [] ## {kind: String, amount: int}


func clear() -> void:
	slots.clear()


func occupied() -> int:
	return slots.size()


func free_slots() -> int:
	return maxi(SLOT_COUNT - slots.size(), 0)


func is_full() -> bool:
	return slots.size() >= SLOT_COUNT


func count_of(kind: String) -> int:
	var n := 0
	for s in slots:
		if str(s.get("kind", "")) == kind:
			n += int(s.get("amount", 0))
	return n


func has_kind(kind: String) -> bool:
	return count_of(kind) > 0


func stack_cap(kind: String) -> int:
	match kind:
		"grenade":
			return 3
		"mine", "decoy":
			return 2
		"ammo", "pistol_ammo", "rifle_ammo", "mg_ammo", "scout_ammo", "shotgun_ammo", "smg_ammo":
			return 24
		_:
			return 1


func _slot_index(kind: String) -> int:
	for i in slots.size():
		if str(slots[i].get("kind", "")) == kind:
			return i
	return -1


func can_fit(kind: String, amount: int = 1) -> bool:
	var n := maxi(amount, 1)
	if kind == "knife" or kind == "":
		return true
	if Weapons.is_typed_ammo(kind) or kind == "ammo":
		## Loose ammo rides the mag/pool, not the grid.
		return true
	if kind == "radio_part":
		return can_fit("decoy", 1)
	var cap := stack_cap(kind)
	if cap > 1:
		var idx := _slot_index(kind)
		var leftover := n
		if idx >= 0:
			leftover -= maxi(cap - int(slots[idx].get("amount", 0)), 0)
		if leftover <= 0:
			return true
		var need := int(ceili(float(leftover) / float(cap)))
		return slots.size() + need <= SLOT_COUNT
	## Firearms and unique kit: one slot if not already carried.
	if has_kind(kind):
		return true
	return slots.size() < SLOT_COUNT


func add_item(kind: String, amount: int = 1) -> Dictionary:
	var n := maxi(amount, 1)
	if kind == "knife" or kind == "":
		return {"ok": true, "text": "", "added": 0}
	if kind == "radio_part":
		return add_item("decoy", 1)
	if Weapons.is_typed_ammo(kind) or kind == "ammo":
		return {"ok": true, "text": "", "added": n, "pooled": true}
	if not can_fit(kind, n):
		return {"ok": false, "full": true, "text": "背包满", "added": 0}
	var cap := stack_cap(kind)
	if cap > 1:
		var idx := _slot_index(kind)
		if idx < 0:
			var put := mini(n, cap)
			slots.append({"kind": kind, "amount": put})
			n -= put
			idx = slots.size() - 1
		else:
			var room := maxi(cap - int(slots[idx].get("amount", 0)), 0)
			var put := mini(n, room)
			slots[idx]["amount"] = int(slots[idx]["amount"]) + put
			n -= put
		while n > 0 and slots.size() < SLOT_COUNT:
			var put := mini(n, cap)
			slots.append({"kind": kind, "amount": put})
			n -= put
		return {"ok": true, "text": "+%s" % Weapons.display_name(kind), "added": amount - n}
	var idx := _slot_index(kind)
	if idx >= 0:
		slots[idx]["amount"] = int(slots[idx].get("amount", 0)) + n
		return {"ok": true, "text": "补%s" % Weapons.display_name(kind), "added": n, "stacked": true}
	slots.append({"kind": kind, "amount": n})
	return {"ok": true, "text": "入包%s" % Weapons.display_name(kind), "added": n}


func take(kind: String, amount: int = 1) -> int:
	var need := maxi(amount, 1)
	var got := 0
	var i := 0
	while i < slots.size() and got < need:
		if str(slots[i].get("kind", "")) != kind:
			i += 1
			continue
		var have := int(slots[i].get("amount", 0))
		var use := mini(have, need - got)
		slots[i]["amount"] = have - use
		got += use
		if int(slots[i]["amount"]) <= 0:
			slots.remove_at(i)
		else:
			i += 1
	return got


func ensure_firearm(kind: String, ammo_n: int = 1) -> void:
	if not Weapons.is_firearm(kind):
		return
	var idx := _slot_index(kind)
	if idx >= 0:
		slots[idx]["amount"] = maxi(int(slots[idx].get("amount", 0)), ammo_n)
		return
	if slots.size() < SLOT_COUNT:
		slots.append({"kind": kind, "amount": maxi(ammo_n, 1)})


func remove_kind(kind: String) -> Dictionary:
	var idx := _slot_index(kind)
	if idx < 0:
		return {}
	var rec: Dictionary = slots[idx].duplicate()
	slots.remove_at(idx)
	return rec


func items() -> Array:
	return slots.duplicate(true)


func firearms() -> PackedStringArray:
	var out := PackedStringArray()
	for s in slots:
		var k := str(s.get("kind", ""))
		if Weapons.is_firearm(k):
			out.append(k)
	return out


func line() -> String:
	return "%d/%d" % [occupied(), SLOT_COUNT]
