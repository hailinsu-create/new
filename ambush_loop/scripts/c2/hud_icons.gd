class_name C2HudIcons
extends RefCounted

## Tiny Commandos-style HUD glyphs. Olive/brass, not candy icons.


static func draw_crouch(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(5, 8), p + Vector2(-5, 8)
	]), col.darkened(0.35))
	c.draw_circle(p + Vector2(0, -4), 3.2, col)
	c.draw_rect(Rect2(p.x - 6, p.y - 1, 12, 5), col)


static func draw_knife(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_line(p + Vector2(-8, 6), p + Vector2(8, -6), col, 2.2, true)
	c.draw_line(p + Vector2(-8, 6), p + Vector2(-4, 8), Color(0.42, 0.32, 0.16), 2.4, true)


static func draw_whistle(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_circle(p, 4.8, col)
	c.draw_arc(p, 8.0, -0.6, 0.6, 8, col, 1.4, true)
	c.draw_arc(p, 11.0, -0.5, 0.5, 8, col, 1.1, true)


static func draw_binoculars(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_circle(p + Vector2(-5, 0), 4.4, col)
	c.draw_circle(p + Vector2(5, 0), 4.4, col)
	c.draw_rect(Rect2(p.x - 5, p.y - 1.6, 10, 3.2), col.darkened(0.2))
	c.draw_circle(p + Vector2(-5, 0), 2.2, Color(0.08, 0.10, 0.12, 0.95))
	c.draw_circle(p + Vector2(5, 0), 2.2, Color(0.08, 0.10, 0.12, 0.95))


static func draw_aid(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_rect(Rect2(p.x - 7, p.y - 4, 14, 8), col)
	c.draw_rect(Rect2(p.x - 1.4, p.y - 6, 2.8, 12), Color(0.72, 0.18, 0.14))
	c.draw_rect(Rect2(p.x - 6, p.y - 1.2, 12, 2.4), Color(0.72, 0.18, 0.14))


static func draw_bind(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_arc(p, 6.5, 0.4, TAU - 0.4, 12, col, 2.0, true)
	c.draw_line(p + Vector2(5, -4), p + Vector2(9, -8), col, 1.6, true)


static func draw_sprint(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-2, -7), p + Vector2(8, 0), p + Vector2(-2, 7)
	]), col)
	c.draw_line(p + Vector2(-8, -4), p + Vector2(-3, -4), col, 1.5, true)
	c.draw_line(p + Vector2(-8, 0), p + Vector2(-3, 0), col, 1.5, true)
	c.draw_line(p + Vector2(-8, 4), p + Vector2(-3, 4), col, 1.5, true)


static func draw_decoy(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_circle(p + Vector2(0, 2), 5.5, col)
	c.draw_circle(p + Vector2(1, 1), 2.0, col.lightened(0.35))


static func draw_mine(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_circle(p, 6.0, col)
	c.draw_circle(p, 2.4, Color(0.18, 0.12, 0.08))
	c.draw_line(p + Vector2(0, -6), p + Vector2(0, -9), col, 1.4, true)


static func by_id(c: CanvasItem, id: String, p: Vector2, col: Color) -> void:
	match id:
		"crouch":
			draw_crouch(c, p, col)
		"knife":
			draw_knife(c, p, col)
		"whistle":
			draw_whistle(c, p, col)
		"binoculars":
			draw_binoculars(c, p, col)
		"aid":
			draw_aid(c, p, col)
		"bind":
			draw_bind(c, p, col)
		"sprint":
			draw_sprint(c, p, col)
		"decoy":
			draw_decoy(c, p, col)
		"mine":
			draw_mine(c, p, col)
		_:
			c.draw_circle(p, 4.0, col)
