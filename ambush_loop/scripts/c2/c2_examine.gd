class_name C2Examine
extends RefCounted

## Commandos-style examine lines. Flavor only.


static func crate(kind: String) -> String:
	match str(kind):
		"kar98k":
			return "Kar98k。栓动，一发一个坑。"
		"m1_garand":
			return "M1加兰德。半自动，打空会叮一声。"
		"mg42":
			return "MG42。弹链吼，射界慢转。"
		"bar":
			return "BAR。比MG42稳，比步枪饿。"
		"thompson":
			return "汤姆逊。院子里的短喷。"
		"mp40":
			return "MP40。稳，不贪。"
		"m1911":
			return "M1911。备弹多，备用好。"
		"luger":
			return "卢格。远一点，稳一点。"
		"springfield", "kar98k_zf":
			return "带镜的长步枪。留给夜枭。"
		"grenade":
			return "手雷。警报里会自己丢。"
		"mine":
			return "地雷。Tab 埋在路上。"
		"decoy":
			return "石子/烟头。岗哨会转头。"
		"ammo":
			return "弹包。对口才进匣。"
		"pistol":
			return "手枪匣。会变成 1911 或卢格。"
		"rifle":
			return "步枪匣。院子里是 Kar98k。"
		"mg":
			return "机枪匣。院子里是 MG42。"
		"scout":
			return "狙击匣。带镜的长枪。"
		"smg":
			return "冲锋枪匣。汤姆逊或 MP40。"
		_:
			return "木匣。站上去开盖。"


static func sentry_line(state: int) -> String:
	match state:
		0:
			return "岗哨在走线。黄锥是真视野。"
		1:
			return "他在找声音。别跑。"
		2:
			return "他看见人了。蹲进阴影。"
		3:
			return "击倒了。捆上或拖走。"
		4:
			return "捆好了。拉警报前他不会醒。"
		_:
			return "岗哨。"
