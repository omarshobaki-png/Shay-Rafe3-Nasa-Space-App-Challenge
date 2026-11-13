extends RefCounted
## Art access: the pixel sprites, planets and backgrounds in res://art
## (made by tools/blender/ships.py, tools/art/gen_ships.py and tools/art/gen_bg.py),
## the pixel font, and a twinkling star field.

const PLANET_SIZES: Array[int] = [9, 12, 22, 36, 60]

static var _font: FontFile = null

static func img(name: String) -> Texture2D:
	return load("res://art/%s.png" % name) as Texture2D

## Pre-rendered planet nearest to radius r. kind: "earth", "moon", "mars", "saturn".
static func planet(r: int, kind: String) -> Texture2D:
	var best: int = PLANET_SIZES[0]
	for s: int in PLANET_SIZES:
		if absi(s - r) < absi(best - r):
			best = s
	return img("planet_%s_%d" % [kind, best])

static func font() -> FontFile:
	if _font == null:
		_font = load("res://art/font.fnt") as FontFile
		_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return _font

## Pixel font size: 10 (1x) or 20 (2x) so glyphs stay on the pixel grid.
static func fsize(size: int) -> int:
	return 20 if size >= 16 else 10

static func text_w(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize(size)).x

## Pixel text with a 1px drop shadow. p is the baseline-left point, like draw_string.
static func text(ci: CanvasItem, p: Vector2, s: String, size: int, c: Color) -> void:
	var fs: int = fsize(size)
	var q: Vector2 = p.floor()
	ci.draw_string(font(), q + Vector2(1, 1) * (fs / 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85 * c.a))
	ci.draw_string(font(), q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

static func text_c(ci: CanvasItem, cx: float, y: float, s: String, size: int, c: Color) -> void:
	text(ci, Vector2(cx - text_w(s, size) / 2.0, y), s, size, c)

static func para(ci: CanvasItem, p: Vector2, s: String, width: float, c: Color) -> void:
	var q: Vector2 = p.floor()
	ci.draw_multiline_string(font(), q + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1, Color(0, 0, 0, 0.85))
	ci.draw_multiline_string(font(), q, s, HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1, c)

## A horizontally tiling layer scrolled by `scroll` px (parallax), drawn across `w`.
static func tiled(ci: CanvasItem, tex: Texture2D, y: float, scroll: float, w: float = 640.0, mod: Color = Color.WHITE) -> void:
	var tw: float = tex.get_width()
	var x: float = -fposmod(floorf(scroll), tw)
	while x < w:
		ci.draw_texture(tex, Vector2(x, floorf(y)), mod)
		x += tw

## A centred sprite at its native size.
static func sprite(ci: CanvasItem, tex: Texture2D, center: Vector2, mod: Color = Color.WHITE) -> void:
	ci.draw_texture(tex, (center - tex.get_size() / 2.0).floor(), mod)

## Twinkling star field. Call from a _draw().
static func stars(ci: CanvasItem, t: float, area: Vector2, count: int = 90, seed_n: int = 7, offset: Vector2 = Vector2.ZERO) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_n
	for i: int in count:
		var p: Vector2 = Vector2(rng.randf() * area.x, rng.randf() * area.y)
		p = Vector2(fposmod(p.x + offset.x, area.x), fposmod(p.y + offset.y, area.y))
		var tw: float = 0.5 + 0.5 * sin(t * rng.randf_range(1.0, 3.0) + i)
		var big: bool = rng.randf() < 0.12
		var c: Color = Color(0.8, 0.85, 1.0, 0.35 + 0.65 * tw)
		ci.draw_rect(Rect2(p.floor(), Vector2(2, 2) if big else Vector2(1, 1)), c)

## A HUD panel: dark glass with a 1px frame and a lit top edge.
static func panel(ci: CanvasItem, r: Rect2, accent: Color = Color("3a4a7a")) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(q, Color(0.03, 0.04, 0.08, 0.78))
	ci.draw_rect(q, accent, false, 1.0)
	ci.draw_rect(Rect2(q.position + Vector2(1, 1), Vector2(q.size.x - 2, 1)), Color(accent, 0.55))
	ci.draw_rect(Rect2(q.position + Vector2(-1, -1), Vector2(3, 3)), accent.lightened(0.3))
	ci.draw_rect(Rect2(q.end - Vector2(2, 2), Vector2(3, 3)), accent.lightened(0.3))
