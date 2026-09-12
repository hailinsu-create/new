class_name CombatFx
extends RefCounted

## Presentation-only bursts: impact sparks, kill rings, trap snaps.
## Tween polygons — no particles, respects 省电, caps live children.

const PREFIX := "Cfx"
const LIVE_CAP := 10


static func hit_tick(host: Node2D, world_pos: Vector2, amount: float, tint: Color = Color(1.0, 0.86, 0.38), ally: bool = false) -> void:
	## Floating damage number. Presentation only.
	if not _ok(host) or not _budget(host, "CfxTick", 8):
		return
	var n := _spawn(host, "CfxTick", world_pos + Vector2(0, -10), 14)
	var lab := Label.new()
	lab.name = "Amt"
	var shown := maxi(int(round(amount)), 1)
	lab.text = "-%d" % shown
	lab.add_theme_font_size_override("font_size", 13 if not ally else 12)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	var col := Color(1.0, 0.42, 0.32) if ally else tint
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.position = Vector2(-10, -8)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(lab)
	if _saving():
		n.queue_free()
		return
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + Vector2(randf_range(-6.0, 6.0), -22.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.42)
	tw.tween_callback(n.queue_free)


static func knife_lunge(host: Node2D, from: Vector2, to: Vector2) -> void:
	if not _ok(host) or not _budget(host, "CfxLunge", 4):
		return
	var n := _spawn(host, "CfxLunge", from, 12)
	var slash := Line2D.new()
	slash.width = 2.4
	slash.default_color = Color(0.78, 0.76, 0.62, 0.95)
	slash.points = PackedVector2Array([Vector2.ZERO, to - from])
	n.add_child(slash)
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.16)
	tw.parallel().tween_property(slash, "width", 0.4, 0.16)
	tw.tween_callback(n.queue_free)


static func steel_spark(host: Node2D, world_pos: Vector2) -> void:
	impact(host, world_pos, Color(0.92, 0.78, 0.42), false)


static func grenade_scorch(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxScorch", world_pos + Vector2(0, 6), 1)
	var burn := Polygon2D.new()
	burn.polygon = PackedVector2Array([
		Vector2(-14, -4), Vector2(6, -7), Vector2(16, 1), Vector2(8, 8),
		Vector2(-6, 9), Vector2(-16, 3)
	])
	burn.color = Color(0.08, 0.06, 0.04, 0.62)
	n.add_child(burn)


static func impact(host: Node2D, world_pos: Vector2, tint: Color = Color(1.0, 0.82, 0.38), heavy: bool = false) -> void:
	if not _ok(host) or not _budget(host, "CfxImpact", 6):
		return
	var n := _spawn(host, "CfxImpact", world_pos, 12)
	var saving := _saving()
	var rays := 3 if saving else (8 if heavy else 6)
	var reach := 10.0 if saving else (20.0 if heavy else 15.0)
	for i in rays:
		var a := deg_to_rad(float(i) * (360.0 / float(rays)) + 12.0)
		var ln := Line2D.new()
		ln.width = 2.6 if heavy else 1.8
		ln.default_color = Color(tint.r, tint.g, tint.b, 0.95)
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		var r2 := reach * (0.55 if (i % 2) == 1 else 1.0)
		ln.points = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * r2])
		n.add_child(ln)
	var core := Polygon2D.new()
	core.polygon = _star(4 if saving else 7, 2.4, 6.2 if heavy else 4.6)
	core.color = Color(1.0, 0.96, 0.78, 0.95)
	n.add_child(core)
	if not saving:
		var halo := Line2D.new()
		halo.width = 1.6
		halo.closed = true
		halo.default_color = Color(tint.r, tint.g, tint.b, 0.70)
		var hpts := PackedVector2Array()
		for i in 8:
			var ha := TAU * float(i) / 8.0
			hpts.append(Vector2(cos(ha), sin(ha)) * (6.5 if heavy else 5.0))
		halo.points = hpts
		n.add_child(halo)
	var dur := 0.09 if saving else (0.18 if heavy else 0.13)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.55, 1.55) if heavy else Vector2(1.28, 1.28), dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, dur)
	tw.tween_callback(n.queue_free)


static func kill_stamp(host: Node2D, world_pos: Vector2, enemy_id: int = 0, tint: Color = Color(1.0, 0.82, 0.32)) -> void:
	if not _ok(host) or not _budget(host, "CfxStamp", 6):
		return
	var n := _spawn(host, "CfxStamp", world_pos, 13)
	var x1 := Line2D.new()
	x1.width = 2.6
	x1.default_color = Color(tint.r, tint.g, tint.b, 0.95)
	x1.points = PackedVector2Array([Vector2(-9, -9), Vector2(9, 9)])
	n.add_child(x1)
	var x2 := Line2D.new()
	x2.width = 2.6
	x2.default_color = Color(tint.r, tint.g, tint.b, 0.95)
	x2.points = PackedVector2Array([Vector2(9, -9), Vector2(-9, 9)])
	n.add_child(x2)
	var lab := Label.new()
	lab.name = "Tag"
	lab.text = "×敌%d" % enemy_id if enemy_id >= 1 else "×"
	lab.position = Vector2(-16, -22)
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_font_override("font", NightOps.ui_font_bold())
	lab.add_theme_color_override("font_color", tint)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.94))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(lab)
	if _saving():
		n.queue_free()
		return
	var tw := n.create_tween()
	tw.tween_interval(0.55)
	tw.tween_property(n, "modulate:a", 0.0, 0.55)
	tw.tween_callback(n.queue_free)


static func kill_burst(host: Node2D, world_pos: Vector2, tint: Color = Color(0.95, 0.28, 0.18)) -> void:
	if not _ok(host) or not _budget(host, "CfxKill", 4):
		return
	var n := _spawn(host, "CfxKill", world_pos, 13)
	var saving := _saving()
	var ring := Line2D.new()
	ring.width = 2.6
	ring.closed = true
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.92)
	var rpts := PackedVector2Array()
	var steps := 8 if saving else 14
	for i in steps:
		var a := TAU * float(i) / float(steps)
		rpts.append(Vector2(cos(a), sin(a)) * 8.0)
	ring.points = rpts
	n.add_child(ring)
	var fill := Polygon2D.new()
	fill.polygon = rpts
	fill.color = Color(tint.r, tint.g, tint.b, 0.28)
	n.add_child(fill)
	if not saving:
		for i in 8:
			var a := deg_to_rad(float(i) * 45.0 + 8.0)
			var shard := Polygon2D.new()
			shard.polygon = PackedVector2Array([
				Vector2(0, -1.6), Vector2(13, 0), Vector2(0, 1.6)
			])
			shard.rotation = a
			shard.color = Color(1.0, 0.85, 0.45, 0.88)
			n.add_child(shard)
		var x1 := Line2D.new()
		x1.width = 2.2
		x1.default_color = Color(1.0, 0.92, 0.55, 0.80)
		x1.points = PackedVector2Array([Vector2(-7, -7), Vector2(7, 7)])
		n.add_child(x1)
		var x2 := Line2D.new()
		x2.width = 2.2
		x2.default_color = Color(1.0, 0.92, 0.55, 0.80)
		x2.points = PackedVector2Array([Vector2(7, -7), Vector2(-7, 7)])
		n.add_child(x2)
	var tw := n.create_tween()
	var grow := Vector2(3.4, 3.4) if not saving else Vector2(2.2, 2.2)
	tw.tween_property(n, "scale", grow, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


static func trip_snap(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxTrip", world_pos, 12)
	var slash := Line2D.new()
	slash.width = 3.2
	slash.default_color = Color(0.82, 1.0, 0.62, 0.95)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.points = PackedVector2Array([Vector2(-16, -10), Vector2(16, 10)])
	n.add_child(slash)
	var slash2 := Line2D.new()
	slash2.width = 2.0
	slash2.default_color = Color(1.0, 1.0, 0.82, 0.7)
	slash2.points = PackedVector2Array([Vector2(-12, 8), Vector2(14, -6)])
	n.add_child(slash2)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(0.62, 0.52, 0.28, 0.85)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	ring.points = pts
	n.add_child(ring)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.8, 1.8), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.18)
	tw.tween_callback(n.queue_free)


static func barrel_boom(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxBoom", world_pos, 14)
	var saving := _saving()
	var flash := Polygon2D.new()
	flash.polygon = _star(8, 6.0, 16.0)
	flash.color = Color(1.0, 0.92, 0.55, 0.9)
	n.add_child(flash)
	var inner := Polygon2D.new()
	inner.polygon = _star(5, 3.0, 8.0)
	inner.color = Color(1.0, 0.55, 0.12, 0.85)
	n.add_child(inner)
	if not saving:
		for i in 8:
			var a := deg_to_rad(float(i) * 45.0 + 10.0)
			var shard := Polygon2D.new()
			shard.polygon = PackedVector2Array([
				Vector2(0, -2.2), Vector2(18, 0), Vector2(0, 2.2)
			])
			shard.rotation = a
			shard.color = Color(0.95, 0.42, 0.10, 0.88)
			n.add_child(shard)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(2.6, 2.6) if not saving else Vector2(1.8, 1.8), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.26)
	tw.tween_callback(n.queue_free)


static func loot_streak(host: Node2D, from: Vector2, to: Vector2) -> void:
	if not _ok(host) or _saving():
		return
	var n := _spawn(host, "CfxLootStreak", from, 11)
	var ln := Line2D.new()
	ln.name = "Streak"
	ln.width = 2.4
	ln.default_color = Color(0.98, 0.82, 0.28, 0.92)
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.points = PackedVector2Array([Vector2.ZERO, to - from])
	n.add_child(ln)
	var pip := Polygon2D.new()
	pip.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	pip.color = Color(1.0, 0.88, 0.32, 0.95)
	n.add_child(pip)
	var tw := n.create_tween()
	tw.tween_property(pip, "position", to - from, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


static func loot_spark(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxLoot", world_pos, 11)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(8, 0), Vector2(0, 10), Vector2(-8, 0)
	])
	diamond.color = Color(0.98, 0.88, 0.32, 0.92)
	n.add_child(diamond)
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + Vector2(0, -16), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(n, "scale", Vector2(1.4, 1.4), 0.22)
	tw.tween_callback(n.queue_free)


static func ambush_arm(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host) or _saving():
		return
	var n := _spawn(host, "CfxArm", world_pos, 11)
	var ring := Line2D.new()
	ring.width = 2.2
	ring.closed = true
	ring.default_color = Color(0.95, 0.82, 0.28, 0.9)
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	ring.points = pts
	n.add_child(ring)
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)
	])
	gem.color = Color(0.98, 0.88, 0.32, 0.72)
	n.add_child(gem)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(2.4, 2.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.28)
	tw.tween_callback(n.queue_free)


static func escape_streak(host: Node2D, world_pos: Vector2, dir: Vector2 = Vector2(0, 1)) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxEsc", world_pos, 12)
	var d := dir.normalized() if dir.length_squared() > 0.01 else Vector2(0, 1)
	var perp := Vector2(-d.y, d.x)
	var streak := Polygon2D.new()
	streak.polygon = PackedVector2Array([
		perp * -7.0, d * 8.0 + perp * -2.0, d * 36.0, d * 8.0 + perp * 2.0, perp * 7.0
	])
	streak.color = Color(1.0, 0.32, 0.18, 0.82)
	n.add_child(streak)
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + d * 42.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.28)
	tw.tween_callback(n.queue_free)


static func mud_print(host: Node2D, world_pos: Vector2, facing_rad: float = 0.0) -> void:
	if not _ok(host) or _saving() or not _budget(host, "CfxPrint", 6):
		return
	var n := _spawn(host, "CfxPrint", world_pos + Vector2(0, 10), 1)
	var boot := Polygon2D.new()
	boot.polygon = PackedVector2Array([
		Vector2(-3.2, -5.0), Vector2(3.2, -5.0), Vector2(2.6, 5.2), Vector2(-2.6, 5.2)
	])
	boot.rotation = facing_rad + PI * 0.5
	boot.color = Color(0.16, 0.12, 0.08, 0.42)
	n.add_child(boot)
	var tw := n.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(n, "modulate:a", 0.0, 1.1)
	tw.tween_callback(n.queue_free)


static func brass_eject(host: Node2D, world_pos: Vector2, facing_rad: float, heavy: bool = false) -> void:
	if not _ok(host) or _saving() or not _budget(host, "CfxBrass", 8):
		return
	var n := _spawn(host, "CfxBrass", world_pos, 11)
	var shell := Polygon2D.new()
	shell.polygon = PackedVector2Array([
		Vector2(-1.2, -3.4), Vector2(1.2, -3.4), Vector2(1.4, 3.0), Vector2(-1.4, 3.0)
	])
	shell.color = Color(0.78, 0.58, 0.22, 0.95)
	n.add_child(shell)
	var side := Vector2(-sin(facing_rad), cos(facing_rad))
	var kick := side * (10.0 if heavy else 7.0) + Vector2(0, 6)
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + kick, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation", 1.8 if heavy else 1.1, 0.22)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.28)
	tw.tween_callback(n.queue_free)


static func land_dust(host: Node2D, world_pos: Vector2) -> void:
	if not _ok(host) or _saving() or not _budget(host, "CfxLand", 4):
		return
	var n := _spawn(host, "CfxLand", world_pos, 5)
	for i in 6:
		var puff := Polygon2D.new()
		var a := deg_to_rad(float(i) * 60.0 + 18.0)
		puff.polygon = PackedVector2Array([
			Vector2(-4.0, -1.8), Vector2(4.6, -1.4), Vector2(3.8, 2.2), Vector2(-2.8, 2.0)
		])
		puff.position = Vector2(cos(a), sin(a)) * 8.0 + Vector2(0, 8)
		puff.color = Color(0.58, 0.54, 0.38, 0.62)
		n.add_child(puff)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.85, 0.62), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.22)
	tw.tween_callback(n.queue_free)


static func death_stain(host: Node2D, world_pos: Vector2, tint: Color = Color(0.55, 0.12, 0.10)) -> void:
	if not _ok(host):
		return
	var n := _spawn(host, "CfxStain", world_pos + Vector2(0, 10), 2)
	var pool := Polygon2D.new()
	pool.polygon = PackedVector2Array([
		Vector2(-11, -3), Vector2(4, -6), Vector2(13, -1), Vector2(10, 6),
		Vector2(-2, 8), Vector2(-12, 4)
	])
	pool.color = Color(tint.r * 0.35, tint.g * 0.18, tint.b * 0.16, 0.72)
	n.add_child(pool)
	var drip := Polygon2D.new()
	drip.polygon = PackedVector2Array([
		Vector2(-4, 4), Vector2(3, 5), Vector2(1, 11), Vector2(-3, 9)
	])
	drip.color = Color(tint.r * 0.28, tint.g * 0.12, tint.b * 0.12, 0.55)
	n.add_child(drip)


static func spawn_pop(host: Node2D, world_pos: Vector2, tint: Color = Color(0.95, 0.32, 0.22)) -> void:
	if not _ok(host) or _saving() or not _budget(host, "CfxSpawn", 4):
		return
	var n := _spawn(host, "CfxSpawn", world_pos, 11)
	var ring := Line2D.new()
	ring.width = 2.4
	ring.closed = true
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.92)
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	ring.points = pts
	n.add_child(ring)
	var chev := Polygon2D.new()
	chev.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(5, 4), Vector2(0, 1), Vector2(-5, 4)
	])
	chev.color = Color(tint.r, tint.g, tint.b, 0.88)
	n.add_child(chev)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.8, 1.8), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.20)
	tw.tween_callback(n.queue_free)


static func select_ping(host: Node2D, world_pos: Vector2, tint: Color = Color(0.95, 0.85, 0.35)) -> void:
	if not _ok(host) or _saving():
		return
	var n := _spawn(host, "CfxSel", world_pos, 10)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.9)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 12.0)
	ring.points = pts
	n.add_child(ring)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.7, 1.7), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.18)
	tw.tween_callback(n.queue_free)


static func _spawn(host: Node2D, nam: String, world_pos: Vector2, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = nam
	n.z_index = z
	host.add_child(n)
	n.global_position = world_pos
	return n


static func _ok(host: Node) -> bool:
	return host != null and is_instance_valid(host)


static func _saving() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var gs = tree.root.get_node_or_null("/root/GameSettings")
	return gs != null and gs.has_method("is_power_saving") and bool(gs.is_power_saving())


static func _budget(host: Node2D, prefix: String, cap: int) -> bool:
	var n := 0
	for c in host.get_children():
		if str(c.name).begins_with(prefix):
			n += 1
			if n >= cap:
				return false
	return true


static func _star(points: int, inner_r: float, outer_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(points, 3)
	for i in n * 2:
		var a := float(i) * PI / float(n) - PI * 0.5
		var r := outer_r if (i % 2) == 0 else inner_r
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
