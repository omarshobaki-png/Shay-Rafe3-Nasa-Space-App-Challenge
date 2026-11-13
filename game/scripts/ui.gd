extends RefCounted
## UI kit: palette, theme and small widget builders. All static.

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
const PINK: Color = Color("ff7ad9")
const ORANGE: Color = Color("ff9f43")

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

## Pixel font sizes: 1x, 2x or 3x of the 10 px font, so glyphs stay on the pixel grid.
static func px(size: int) -> int:
	if size >= 26:
		return 30
	if size >= 14:
		return 20
	return 10

static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	var f: FontFile = load("res://art/font.fnt") as FontFile
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	t.default_font = f
	t.default_font_size = 10
	t.set_constant("line_spacing", "Label", 3)
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, BORDER, 1, 5))
	t.set_stylebox("panel", "Panel", flat(PANEL, BORDER, 1, 5))
	t.set_stylebox("normal", "Button", flat(PANEL2, BORDER, 1))
	t.set_stylebox("hover", "Button", flat(Color("2a3560"), CYAN, 1))
	t.set_stylebox("pressed", "Button", flat(Color("0f1426"), YELLOW, 1))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), YELLOW, 1))
	t.set_stylebox("disabled", "Button", flat(Color("10131f"), Color("252b40"), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", YELLOW)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("4a5270"))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "TooltipPanel", flat(Color("05070d"), YELLOW, 1, 5))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 10)
	t.set_stylebox("scroll", "VScrollBar", flat(Color("0f1426"), Color("0f1426"), 0, 2))
	t.set_stylebox("grabber", "VScrollBar", flat(BORDER, BORDER, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(CYAN, CYAN, 0, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(YELLOW, YELLOW, 0, 2))
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

static func button(text: String, cb: Callable, size: int = 10, min_w: float = 0.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px(size))
	b.pressed.connect(cb)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func color_button(b: Button, c: Color) -> void:
	b.add_theme_stylebox_override("normal", flat(c.darkened(0.6), c, 1))
	b.add_theme_stylebox_override("hover", flat(c.darkened(0.4), c.lightened(0.3), 1))
	b.add_theme_color_override("font_color", c.lightened(0.4))

static func panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, border, 1, 5))
	return p

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
