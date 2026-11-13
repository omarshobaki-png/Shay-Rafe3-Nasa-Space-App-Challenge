extends RefCounted
## Art access: the pixel sprites, planets and backgrounds in res://art
## (made by tools/blender/ships.py, tools/art/gen_ships.py and tools/art/gen_bg.py),
## the pixel fonts, a twinkling star field, and the drawn half of the UI kit (frames, icons, gauges,
## lamps, key caps from res://art/ui, made by tools/art/gen_ui.py).

const PLANET_SIZES: Array[int] = [9, 12, 22, 36, 60]
## 9-slice margins [left, top, right, bottom] of the kit frames in res://art/ui (see slice()).
const SLICE: Dictionary = {
	"panel": [6, 6, 6, 6], "panel_dark": [6, 6, 6, 6], "panel_trim": [6, 6, 6, 6],
	"tooltip": [3, 3, 3, 3], "hud": [8, 8, 8, 8], "hud_trim": [8, 8, 8, 8], "keycap": [3, 3, 3, 4],
	"btn": [3, 3, 3, 4], "tab": [3, 4, 3, 1], "tile": [4, 4, 4, 4], "gauge_frame": [3, 3, 3, 3],
	"gauge_fill": [0, 1, 0, 1], "scroll": [2, 3, 2, 3],
}
const INK: Color = Color("05070d")

static var _font: FontFile = null
static var _dfont: FontFile = null
static var _ui: Dictionary = {}

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

## Bold display font (capitals, digits, common punctuation; lower case shows as capitals).
## Native size 12: draw it at 12, 24 or 36 only.
static func display_font() -> FontFile:
	if _dfont == null:
		_dfont = load("res://art/font_display.fnt") as FontFile
		_dfont.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		_dfont.fallbacks = [font()]  # a character the display font lacks shows in the thin font instead of vanishing
	return _dfont

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

## Pixel text with a dark outline all round, for text over busy backgrounds (terrain, sky, planets).
static func text_o(ci: CanvasItem, p: Vector2, s: String, size: int, c: Color, outline: Color = Color(0.02, 0.03, 0.05, 0.95)) -> void:
	var fs: int = fsize(size)
	var k: int = fs / 10
	var q: Vector2 = p.floor()
	var o: Color = Color(outline, outline.a * c.a)
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 2), Vector2(1, 2)]:
		ci.draw_string(font(), q + d * k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, o)
	ci.draw_string(font(), q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

static func text_oc(ci: CanvasItem, cx: float, y: float, s: String, size: int, c: Color) -> void:
	text_o(ci, Vector2(cx - text_w(s, size) / 2.0, y), s, size, c)

static func para(ci: CanvasItem, p: Vector2, s: String, width: float, c: Color) -> void:
	var q: Vector2 = p.floor()
	ci.draw_multiline_string(font(), q + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1, Color(0, 0, 0, 0.85))
	ci.draw_multiline_string(font(), q, s, HORIZONTAL_ALIGNMENT_LEFT, width, 10, -1, c)

## Width of a display-font string. scale: 1 (12 px), 2 (24 px) or 3 (36 px).
static func title_w(s: String, scale: int = 1) -> float:
	return display_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * clampi(scale, 1, 3)).x

## Bold display text for titles and big numbers, with a drop shadow. p is the baseline-left point
## (at scale 1 the glyphs stand 11 px above it and their dark lower edge sits 1 px below).
static func title(ci: CanvasItem, p: Vector2, s: String, c: Color, scale: int = 1) -> void:
	var k: int = clampi(scale, 1, 3)
	var q: Vector2 = p.floor()
	ci.draw_string(display_font(), q + Vector2(1, 1) * k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * k, Color(INK, 0.9 * c.a))
	ci.draw_string(display_font(), q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 * k, c)

static func title_c(ci: CanvasItem, cx: float, y: float, s: String, c: Color, scale: int = 1) -> void:
	title(ci, Vector2(cx - title_w(s, scale) / 2.0, y), s, c, scale)

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

# ---------------------------------------------------------------- UI kit, drawn

## Kit texture res://art/ui/<name>.png, cached here so it is never freed. Null when the file is missing.
static func ui_tex(name: String) -> Texture2D:
	if not _ui.has(name):
		var path: String = "res://art/ui/%s.png" % name
		_ui[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _ui[name]

## 9-slice margins [left, top, right, bottom] of a kit texture ("btn_go_hover" uses the "btn" entry).
static func slice(name: String) -> Array:
	if SLICE.has(name):
		return SLICE[name]
	if name.begins_with("btn") and name.ends_with("_pressed"):
		return [3, 4, 3, 3]
	for k: String in ["btn", "tab", "tile", "scroll"]:
		if name.begins_with(k):
			return SLICE[k]
	return [0, 0, 0, 0]

## Any kit frame stretched as a 9-slice over r, on whole pixels: "panel", "panel_dark", "tooltip",
## "btn_normal", "btn_go_normal", "btn_danger_normal", "tile_normal", "tile_sel", "keycap", "gauge_frame" ...
static func frame(ci: CanvasItem, r: Rect2, name: String, mod: Color = Color.WHITE) -> void:
	var tex: Texture2D = ui_tex(name)
	if tex == null:
		return
	var m: Array = slice(name)
	RenderingServer.canvas_item_add_nine_patch(ci.get_canvas_item(), Rect2(r.position.floor(), r.size.floor()),
		Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(), Vector2(m[0], m[1]), Vector2(m[2], m[3]),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, mod)

## A HUD panel: dark glass, a black outline, and corner brackets and a thin line in the accent colour.
## `body` tints the glass (a warm dark for Mars, for example).
static func panel(ci: CanvasItem, r: Rect2, accent: Color = Color("3a4a7a"), body: Color = Color(0.03, 0.04, 0.08, 0.8)) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(q.grow(-1), body)
	frame(ci, q, "hud")
	frame(ci, q, "hud_trim", accent.lightened(0.25))

## A 12 x 12 icon (or any kit picture) with its top-left corner at pos. name: "mass" or "icon_mass".
static func icon(ci: CanvasItem, name: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	var tex: Texture2D = ui_tex(name)
	if tex == null:
		tex = ui_tex("icon_" + name)
	if tex != null:
		ci.draw_texture(tex, pos.floor(), mod)

## A framed bar. frac 0..1 fills it in `colour`; marker_frac 0..1 adds a yellow notch (a limit or a target).
## The frame takes 2 px on every side, so r should be at least 6 px tall (8 is the usual height).
static func gauge(ci: CanvasItem, r: Rect2, frac: float, colour: Color = Color("6dff8a"), marker_frac: float = -1.0) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	frame(ci, q, "gauge_frame")
	var inner: Rect2 = q.grow(-2)
	var w: float = floorf(inner.size.x * clampf(frac, 0.0, 1.0))
	if frac > 0.0:
		frame(ci, Rect2(inner.position, Vector2(maxf(w, 1.0), inner.size.y)), "gauge_fill", colour)
	if marker_frac >= 0.0:
		var x: float = inner.position.x + floorf((inner.size.x - 1.0) * clampf(marker_frac, 0.0, 1.0))
		ci.draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), Color("ffd75e"))
		icon(ci, "gauge_mark", Vector2(x - 2, q.position.y - 3))

## A 10 x 10 status lamp with its top-left corner at pos. status: "ok", "warn", "bad"; anything else is off.
static func lamp(ci: CanvasItem, pos: Vector2, status: String) -> void:
	icon(ci, "lamp_" + (status if status in ["ok", "warn", "bad"] else "off"), pos)

## A key cap with its top-left corner at pos (13 px tall, at least 13 wide). Returns its width.
static func keycap(ci: CanvasItem, pos: Vector2, key: String) -> float:
	var q: Vector2 = pos.floor()
	var tw: float = text_w(key, 10)
	var w: float = maxf(13.0, tw + 7.0)
	frame(ci, Rect2(q, Vector2(w, 13)), "keycap")
	ci.draw_string(font(), q + Vector2(floorf((w - tw + 1.0) / 2.0), 9), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("141a2e"))
	return w

## A key cap followed by what the key does ("E" then "DRILL"). Returns the total width, so hints can be chained.
static func key_hint(ci: CanvasItem, pos: Vector2, key: String, label: String, c: Color = Color("e8ecff")) -> float:
	var w: float = keycap(ci, pos, key)
	text_o(ci, pos.floor() + Vector2(w + 4, 9), label, 10, c)
	return w + 4.0 + text_w(label, 10)

## A button face with centred text, for buttons drawn in _draw (touch controls, HUD prompts).
## kind: "btn", "btn_go", "btn_danger"; state: "normal", "hover", "pressed", "disabled" (17 px tall or more).
static func button(ci: CanvasItem, r: Rect2, label: String, kind: String = "btn", state: String = "normal") -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	frame(ci, q, "btn_disabled" if state == "disabled" else "%s_%s" % [kind, state])
	var c: Color = Color("4a5270") if state == "disabled" else Color("04260f") if kind == "btn_go" else Color("300a04") if kind == "btn_danger" else Color("e8ecff")
	var y: float = q.position.y + floorf((q.size.y - 3.0) / 2.0) + (5.0 if state == "pressed" else 4.0)
	ci.draw_string(font(), Vector2(q.position.x + floorf((q.size.x - text_w(label, 10)) / 2.0), y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)
