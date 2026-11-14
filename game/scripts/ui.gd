extends RefCounted
## UI kit: palette, theme and small widget builders. All static.
## The look comes from the 9-slice textures in res://art/ui (made by tools/art/gen_ui.py);
## the drawn half of the kit (HUD frames, icons, gauges for _draw code) is in scripts/pix.gd.

const Pix = preload("res://scripts/pix.gd")

const BG: Color = Color("0b0e1a")
const PANEL: Color = Color("141a2e")
const PANEL2: Color = Color("1d2540")
const BORDER: Color = Color("3a4a7a")
const TEXT: Color = Color("e8ecff")
const DIM: Color = Color("8a94b8")
const CYAN: Color = Color("4fd6ff")
const YELLOW: Color = Color("ffd75e")
const RED: Color = Color("ff5a5a")
const GREEN: Color = Color("6dff8a")
## Consequence colours for small texts (v7): a loss, a chance, a gain. Use these three everywhere.
const BAD: Color = Color("ff5a5a")
const RISK: Color = Color("ffd75e")
const GOOD: Color = Color("6dff8a")
const PINK: Color = Color("ff7ad9")
const ORANGE: Color = Color("ff9f43")
## Text colours for the bright button faces.
const INK_GO: Color = Color("04260f")
const INK_DANGER: Color = Color("300a04")
const INK_KEY: Color = Color("141a2e")

static var _icons: Dictionary = {}
static var _boxes: Dictionary = {}

## Panel style in two 9-slice layers: the plate, then a trim tinted in any colour.
class PlateBox extends StyleBox:
	var plate: Texture2D = null
	var trim: Texture2D = null
	var trim_color: Color = Color(0, 0, 0, 0)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var src: Rect2 = Rect2(Vector2.ZERO, plate.get_size())
		RenderingServer.canvas_item_add_nine_patch(to_canvas_item, rect, src, plate.get_rid(), Vector2(6, 6), Vector2(6, 6))
		if trim_color.a > 0.0 and trim != null:
			RenderingServer.canvas_item_add_nine_patch(to_canvas_item, rect, src, trim.get_rid(), Vector2(6, 6), Vector2(6, 6),
				RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, trim_color)

## A framed bar: `frac` 0..1 filled in `color`, `marker` 0..1 a yellow notch (-1 hides it). Made by UI.gauge().
class Gauge extends Control:
	var frac: float = 0.0:
		set(v):
			frac = v
			queue_redraw()
	var color: Color = Color("6dff8a"):
		set(v):
			color = v
			queue_redraw()
	var marker: float = -1.0:
		set(v):
			marker = v
			queue_redraw()

	func _draw() -> void:
		Pix.gauge(self, Rect2(Vector2.ZERO, size), frac, color, marker)

## Small UI picture from res://art/ui/<name>.png (icons, lamps, tiles). Null when the file does not exist.
## Cached here, so callers never lose the texture.
static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path: String = "res://art/ui/%s.png" % name
		_icons[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[name]

static func status_color(s: String) -> Color:
	if s == "ok":
		return GREEN
	if s == "warn":
		return YELLOW
	return RED

static func flat(bg: Color, border: Color, w: int = 1, pad: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(2, pad - 2)
	sb.content_margin_bottom = maxi(2, pad - 2)
	sb.anti_aliasing = false
	return sb

## 9-slice style from a kit texture ("panel", "tooltip", "btn_normal", "tile_sel", "keycap", "gauge_frame" ...).
## pad_* are the content margins (how far text stays from the edge); `tint` multiplies the texture.
static func frame_box(name: String, pad_l: int = 4, pad_t: int = 4, pad_r: int = 4, pad_b: int = 4, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = icon(name)
	var m: Array = Pix.slice(name)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = pad_l
	sb.content_margin_top = pad_t
	sb.content_margin_right = pad_r
	sb.content_margin_bottom = pad_b
	sb.modulate_color = tint
	return sb

## Button style of one state. kind: "btn", "btn_go", "btn_danger", "btn_tint"; the pressed face sits 1 px lower.
## `big` adds room above 20 and 30 px text so capitals sit in the middle of the face.
static func _btn_box(kind: String, state: String, big: int = 0, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var key: String = "%s|%s|%d|%s" % [kind, state, big, tint.to_html()]
	if not _boxes.has(key):
		var down: int = 1 if state == "pressed" else 0
		_boxes[key] = frame_box("%s_%s" % [kind, state], 6, 4 + big + down, 6, 3 - down, tint)
	return _boxes[key]

## Gives a button one of the kit's faces in every state. Sizes above 10 px get their own margins.
static func _skin(b: Button, kind: String, tint: Color = Color.WHITE) -> void:
	var big: int = maxi(0, b.get_theme_font_size("font_size") / 10 - 1) * 2
	b.add_theme_stylebox_override("normal", _btn_box(kind, "normal", big, tint))
	b.add_theme_stylebox_override("hover", _btn_box(kind, "hover", big, tint))
	b.add_theme_stylebox_override("pressed", _btn_box(kind, "pressed", big, tint))
	b.add_theme_stylebox_override("hover_pressed", _btn_box(kind, "pressed", big, tint))
	b.add_theme_stylebox_override("disabled", _btn_box("btn", "disabled", big))
	b.add_theme_stylebox_override("focus", _btn_box("btn", "focus", big))

static func _ink(b: Button, c: Color) -> void:
	for n: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(n, c)

static func _plate(name: String, trim_color: Color = Color(0, 0, 0, 0)) -> PlateBox:
	var sb: PlateBox = PlateBox.new()
	sb.plate = icon(name)
	sb.trim = icon("panel_trim")
	sb.trim_color = trim_color
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

## Pixel font sizes: 1x, 2x or 3x of the 10 px font, so glyphs stay on the pixel grid.
static func px(size: int) -> int:
	if size >= 26:
		return 30
	if size >= 14:
		return 20
	return 10

static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = Pix.font()
	t.default_font_size = 10
	t.set_constant("line_spacing", "Label", 3)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _plate("panel"))
	t.set_stylebox("panel", "Panel", _plate("panel"))
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, _btn_box("btn", "normal"))
		t.set_stylebox("hover", type, _btn_box("btn", "hover"))
		t.set_stylebox("pressed", type, _btn_box("btn", "pressed"))
		t.set_stylebox("hover_pressed", type, _btn_box("btn", "pressed"))
		t.set_stylebox("disabled", type, _btn_box("btn", "disabled"))
		t.set_stylebox("focus", type, frame_box("btn_focus", 6, 4, 6, 3))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, YELLOW)
		t.set_color("font_hover_pressed_color", type, YELLOW)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color("4a5270"))
		t.set_constant("h_separation", type, 3)
	t.set_stylebox("panel", "TooltipPanel", frame_box("tooltip", 6, 4, 6, 3))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 10)
	t.set_stylebox("panel", "PopupPanel", _plate("panel_dark"))
	t.set_stylebox("panel", "PopupMenu", _plate("panel_dark"))
	for bar: String in ["VScrollBar", "HScrollBar"]:
		var v: bool = bar == "VScrollBar"
		t.set_stylebox("scroll", bar, frame_box("scroll_track", 3, 3, 3, 3))
		t.set_stylebox("scroll_focus", bar, frame_box("scroll_track", 3, 3, 3, 3))
		for pair: Array in [["grabber", "scroll_grab"], ["grabber_highlight", "scroll_grab_hover"], ["grabber_pressed", "scroll_grab_pressed"]]:
			t.set_stylebox(pair[0], bar, frame_box(pair[1], 3, 4, 3, 4) if v else frame_box(pair[1], 4, 3, 4, 3))
	t.set_stylebox("separator", "HSeparator", frame_box("sep_h", 0, 1, 0, 1))
	t.set_stylebox("separator", "VSeparator", frame_box("sep_v", 1, 0, 1, 0))
	t.set_constant("separation", "HSeparator", 4)
	t.set_constant("separation", "VSeparator", 4)
	for pair: Array in [["checked", "check_on"], ["unchecked", "check_off"], ["radio_checked", "radio_on"], ["radio_unchecked", "radio_off"],
			["checked_disabled", "check_on"], ["unchecked_disabled", "check_off"], ["radio_checked_disabled", "radio_on"], ["radio_unchecked_disabled", "radio_off"]]:
		t.set_icon(pair[0], "CheckBox", icon(pair[1]))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	return t

static func label(text: String, size: int = 10, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	return l

static func wrap_label(text: String, size: int = 9, color: Color = DIM, min_w: float = 100.0) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min_w, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## Title or big number in the bold display font. scale 1 = 12 px, 2 = 24 px, 3 = 36 px.
## Capitals, digits and . , : ; ! ? % $ / + - = ( ) ' " & < > _ only; lower case shows as capitals.
static func title_label(text: String, color: Color = YELLOW, scale: int = 1) -> Label:
	var k: int = clampi(scale, 1, 3)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", Pix.display_font())
	l.add_theme_font_size_override("font_size", 12 * k)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(Pix.INK, 0.9))
	l.add_theme_constant_override("shadow_offset_x", k)
	l.add_theme_constant_override("shadow_offset_y", k)
	return l

static func button(text: String, cb: Callable, size: int = 10, min_w: float = 0.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px(size))
	b.pressed.connect(cb)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if px(size) > 10:
		_skin(b, "btn")
	return b

## Recolours a button. Greens take the "go" face and reds and oranges the "danger" face;
## any other colour tints the neutral face. Text turns dark on bright faces.
static func color_button(b: Button, c: Color) -> void:
	if c.s > 0.25 and c.h > 0.2 and c.h < 0.47:
		_skin(b, "btn_go")
		_ink(b, INK_GO)
	elif c.s > 0.25 and (c.h < 0.1 or c.h > 0.95):
		_skin(b, "btn_danger")
		_ink(b, INK_DANGER)
	else:
		_skin(b, "btn_tint", c)
		_ink(b, c.darkened(0.82) if c.get_luminance() > 0.3 else c.lightened(0.75))

## The green button for the one main action of a screen (PLAY, LAUNCH, CONTINUE).
static func go_button(text: String, cb: Callable, size: int = 10, min_w: float = 0.0) -> Button:
	var b: Button = button(text, cb, size, min_w)
	color_button(b, GREEN)
	return b

## The red-orange button for actions that throw something away (RESET, ABORT, SELL).
static func danger_button(text: String, cb: Callable, size: int = 10, min_w: float = 0.0) -> Button:
	var b: Button = button(text, cb, size, min_w)
	color_button(b, RED)
	return b

## A button with a 12 x 12 kit icon on the left of its text: icon_button("launcher", "LAUNCH", cb).
static func icon_button(icon_name: String, text: String, cb: Callable, size: int = 10, min_w: float = 0.0) -> Button:
	var b: Button = button(text, cb, size, min_w)
	b.icon = _find_icon(icon_name)
	return b

## A tab that joins the panel under it. Rebuild or call set_tab() when the selection changes.
static func tab(text: String, cb: Callable, selected: bool = false, min_w: float = 0.0) -> Button:
	var b: Button = button(text, cb, 10, min_w)
	set_tab(b, selected)
	return b

static func set_tab(b: Button, selected: bool) -> void:
	var name: String = "tab_sel" if selected else "tab_normal"
	if not _boxes.has(name):
		_boxes[name] = frame_box(name, 6, 5, 6, 2)
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, _boxes[name])
	_ink(b, YELLOW if selected else DIM)
	b.add_theme_color_override("font_hover_color", YELLOW if selected else TEXT)

## bg darker than UI.PANEL gives the dark plate; a border other than UI.BORDER tints the rim in that colour.
static func panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var dark: bool = bg.get_luminance() < PANEL.get_luminance() - 0.01
	if dark or border != BORDER:
		p.add_theme_stylebox_override("panel", _plate("panel_dark" if dark else "panel", border if border != BORDER else Color(0, 0, 0, 0)))
	return p

static func _find_icon(name: String) -> Texture2D:
	var tex: Texture2D = icon(name)
	return tex if tex != null else icon("icon_" + name)

## A kit picture as a Control at its native size: icon_rect("mass"), icon_rect("tile_normal"), icon_rect("node").
static func icon_rect(name: String) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = _find_icon(name)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r.texture != null:
		r.custom_minimum_size = r.texture.get_size()
	return r

## Icon + text in a row. The Label is child 1: (row.get_child(1) as Label).text = "...".
static func icon_label(icon_name: String, text: String, color: Color = TEXT, size: int = 10) -> HBoxContainer:
	var h: HBoxContainer = hbox(3)
	h.add_child(icon_rect(icon_name))
	var l: Label = label(text, size, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

## A framed bar (8 px tall). Set .frac, .color and .marker on the returned Gauge to update it.
## marker 0..1 draws a yellow notch for a limit or a target.
static func gauge(frac: float, color: Color = GREEN, min_w: float = 60.0, marker: float = -1.0) -> Gauge:
	var g: Gauge = Gauge.new()
	g.frac = frac
	g.color = color
	g.marker = marker
	g.custom_minimum_size = Vector2(min_w, 8)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return g

## A 10 x 10 status lamp. status: "ok" (green), "warn" (yellow), "bad" (red); anything else is off.
static func lamp(status: String) -> TextureRect:
	var r: TextureRect = icon_rect("lamp_off")
	set_lamp(r, status)
	return r

static func set_lamp(r: TextureRect, status: String) -> void:
	r.texture = icon("lamp_" + (status if status in ["ok", "warn", "bad"] else "off"))

## A key cap for key prompts: keycap("E"), keycap("SPACE").
static func keycap(key: String) -> Label:
	var l: Label = label(key, 10, INK_KEY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not _boxes.has("keycap"):
		_boxes["keycap"] = frame_box("keycap", 4, 2, 3, 1)
	l.add_theme_stylebox_override("normal", _boxes["keycap"])
	l.custom_minimum_size = Vector2(13, 13)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

## An engraved horizontal line between groups.
static func divider() -> HSeparator:
	return HSeparator.new()

static func vbox(sep: int = 3) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 4) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	return c

static func clear(node: Node) -> void:
	for ch: Node in node.get_children():
		ch.queue_free()
