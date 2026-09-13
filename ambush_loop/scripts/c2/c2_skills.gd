class_name C2Skills
extends RefCounted

## Per-role Commandos 2 hotbar. RAID keeps auto-fire during ALERT;
## these verbs are SCOUT / SWEEP only.


static func all_ids() -> PackedStringArray:
	return PackedStringArray(["crouch", "knife", "whistle", "binoculars", "aid", "bind", "decoy", "mine"])


static func for_role(role: int) -> PackedStringArray:
	match role:
		1: ## MG 铁砧
			return PackedStringArray(["crouch", "mine", "whistle", "aid", "bind"])
		2: ## SCOUT 夜枭
			return PackedStringArray(["crouch", "binoculars", "decoy", "knife", "bind"])
		_:
			return PackedStringArray(["crouch", "knife", "decoy", "aid", "bind"])


static func hotkey(id: String) -> String:
	match id:
		"crouch":
			return "C"
		"knife":
			return "Q"
		"mine":
			return "Q"
		"binoculars":
			return "Q"
		"whistle":
			return "W"
		"decoy":
			return "W"
		"aid":
			return "Z"
		"bind":
			return "Z"
		_:
			return ""


static func label_zh(id: String) -> String:
	match id:
		"crouch":
			return "匍匐"
		"knife":
			return "割喉"
		"whistle":
			return "口哨"
		"binoculars":
			return "望远镜"
		"aid":
			return "包扎"
		"bind":
			return "捆绑"
		"decoy":
			return "诱饵"
		"mine":
			return "埋雷"
		_:
			return id


static func hint_zh(id: String) -> String:
	match id:
		"crouch":
			return "蹲下慢走，声音小，影子矮。阴影/灌木里岗哨看不见。"
		"knife":
			return "贴近岗哨背后割喉。正面会惊动。"
		"whistle":
			return "短哨把岗哨拽偏一格，像石子。"
		"binoculars":
			return "拉远视锥，标出岗哨朝向。"
		"aid":
			return "站住包扎 8 秒外的伤。打扫期更快。"
		"bind":
			return "捆住已击倒的岗哨，免得醒。Z 靠近再用。"
		"decoy":
			return "丢石子/烟头，岗哨转头。"
		"mine":
			return "脚下埋雷，警报波才踩。"
		_:
			return ""


static func cooldown(id: String) -> float:
	match id:
		"whistle":
			return 4.2
		"binoculars":
			return 6.0
		"aid":
			return 8.0
		"knife":
			return 0.9
		"bind":
			return 0.8
		"decoy":
			return 2.4
		"mine":
			return 0.4
		_:
			return 0.0


static func keycode(id: String) -> int:
	match hotkey(id):
		"C":
			return KEY_C
		"Q":
			return KEY_Q
		"W":
			return KEY_W
		"Z":
			return KEY_Z
		_:
			return 0
