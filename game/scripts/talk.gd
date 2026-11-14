extends Control
## The dialogue panel: the spacecraft builder's guide (a portrait and a speech bubble whose text types on),
## made into one component that every screen uses for mission explanations and for the short lead-in
## before an event card. It never asks anything: it has no buttons and no choices.
##
## API (the contract for the screens, see docs/V8_PLAN.md):
##   const Talk = preload("res://scripts/talk.gd")
##   var talk: Control = Talk.make(self, Vector2(8, 300))   # once, in _ready(); `at` = top left of the portrait
##   talk.say("One line.")                                   # or an Array of lines; queued after what is showing
##   talk.say(lines, {"who": "control", "hold": 2.5, "then": Callable, "urgent": false, "key": "site_task"})
##       who     "control" (Mission Control operator, the default) or "guide" (the builder's engineer)
##       hold    seconds a line stays after it has typed out (default Data.TALK hold)
##       then    called once when this say() has finished or was skipped
##       urgent  true: drop what is showing and say this now
##       key     a name for this explanation: Talk.said(key) is true once it has been shown in this run,
##               so a screen can avoid repeating it (replaying on request is always allowed)
##       space   true: Space also skips (only where Space does nothing else; default: Enter and a click
##               on the bubble)
##   talk.busy() -> bool      a line is showing or waiting
##   talk.skip()              finish typing the line, or go to the next one
##   talk.clear()             remove everything now and stop the chatter sound
##   Talk.said(key) -> bool   static
## Static helpers, for a screen that draws its own bubble (the builder): wrap_text(), typed_chars(), type_secs(),
## draw_bubble(), chatter_tick(), clear_all(). See "v8 talk as built" in docs/V8_PLAN.md.
## The panel draws nothing while it has nothing to say, and it stops its sound when it leaves the tree.
const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const D = preload("res://scripts/data.gd")

const BOX: Vector2 = Vector2(38, 42)   # the portrait box, as in the builder
const GAP: float = 5.0                 # portrait box to bubble, as in the builder
const BUBBLE_W: float = 258.0
const CPS: float = D.TALK["cps"]
const HOLD_S: float = D.TALK["hold_s"]
const PAPER: Color = Color("eef1fb")
const PAPER_HAPPY: Color = Color("dcffe4")
const INK_TEXT: Color = Color("141a2e")

static var _said: Dictionary = {}
static var _all: Array = []            # every Talk in the tree, so a card can silence them all
static var _font: FontVariation = null
static var _tex: Dictionary = {}

var queue: Array = []        # [{"text", "who", "hold", "then", "space"}]
var now: Dictionary = {}
var typed: float = 0.0       # seconds since the line began
var held: float = 0.0        # seconds since it finished typing
var shown: int = 0           # letters revealed so far (for the chatter)
var bubble: Rect2 = Rect2()  # last drawn bubble, local, for clicks
var t: float = 0.0

static func make(parent: Node, at: Vector2 = Vector2(8, 300)) -> Control:
	var node: Control = (load("res://scripts/talk.gd") as GDScript).new()
	node.position = at
	node.size = Vector2(BOX.x + GAP + BUBBLE_W, BOX.y)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 50
	parent.add_child(node)
	return node

static func said(key: String) -> bool:
	return _said.has(key)

## Silences every dialogue panel in the tree (an event card does this so two panels never show at once).
static func clear_all() -> void:
	for n: Variant in _all.duplicate():
		if is_instance_valid(n):
			n.clear()

func _enter_tree() -> void:
	_all.append(self)

func _exit_tree() -> void:
	_all.erase(self)
	if not now.is_empty():
		Audio.chatter_stop()

func say(lines: Variant, opts: Dictionary = {}) -> void:
	var list: Array = lines if lines is Array else [lines]
	if bool(opts.get("urgent", false)):
		clear()
	if opts.has("key"):
		_said[String(opts["key"])] = true
	var chunks: Array = []
	var per: int = int(D.TALK["max_lines"])
	for line: Variant in list:
		var text: String = String(line).strip_edges()
		if text == "":
			continue
		# a line longer than the bubble's 3 rows goes on in the next bubble
		var rows: PackedStringArray = wrap_text(text, BUBBLE_W - 14.0, -1).split("\n")
		for i: int in range(0, rows.size(), per):
			chunks.append(" ".join(rows.slice(i, i + per)))
	for i: int in chunks.size():
		queue.append({"text": chunks[i], "who": String(opts.get("who", "control")),
			"hold": float(opts.get("hold", HOLD_S)), "space": bool(opts.get("space", false)),
			"then": opts.get("then", Callable()) if i == chunks.size() - 1 else Callable()})
	if now.is_empty() and not queue.is_empty():
		_next()

func busy() -> bool:
	return not now.is_empty() or not queue.is_empty()

func skip() -> void:
	if now.is_empty():
		return
	if shown < String(now["text"]).length():
		typed = 9999.0
		shown = String(now["text"]).length()
		Audio.chatter_stop()
	else:
		_next()
	queue_redraw()

func clear() -> void:
	var was: bool = not now.is_empty()
	queue.clear()
	now = {}
	if was:
		Audio.chatter_stop()
	queue_redraw()

func _next() -> void:
	var done: Callable = now.get("then", Callable())
	var was: bool = not now.is_empty()
	now = {}
	if was:
		Audio.chatter_stop()
	if done.is_valid():
		done.call()
	if not queue.is_empty() and now.is_empty():
		now = queue.pop_front()
		typed = 0.0
		held = 0.0
		shown = 0
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	if now.is_empty():
		return
	typed += delta
	var text: String = now["text"]
	var n: int = typed_chars(text, typed)
	chatter_tick(text, shown, n)
	shown = n
	if n >= text.length():
		held += delta
		if held >= float(now["hold"]) + text.length() * float(D.TALK["hold_per_char"]):
			_next()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if now.is_empty() or not is_visible_in_tree():
		return
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER
			or (k.keycode == KEY_SPACE and bool(now.get("space", false)))):
		skip()
		get_viewport().set_input_as_handled()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and bubble.has_point(get_local_mouse_position()):
		skip()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if now.is_empty():
		return
	var text: String = now["text"]
	bubble = draw_bubble(self, Rect2(Vector2.ZERO, BOX), Vector2(BOX.x + GAP, 2.0), text, shown,
		String(now["who"]), false, not queue.is_empty() and shown >= text.length())

# ---------------------------------------------------------------- static helpers (also for the builder)

## Same as wrap_text(), for callers outside (Talk.wrap). Inside this file call wrap_text(): a bare wrap()
## is Godot's number wrap().
@warning_ignore("shadowed_global_identifier")
static func wrap(text: String, w: float = BUBBLE_W - 14.0, max_lines: int = 3) -> String:
	return wrap_text(text, w, max_lines)

## Word wrap at the builder's font size 10: spaces become "\n", so letter counts stay the same.
static func wrap_text(text: String, w: float = BUBBLE_W - 14.0, max_lines: int = 3) -> String:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" ", false):
		if line != "" and Pix.text_w(line + " " + word, 10) > w:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	lines.append(line)
	if max_lines > 0 and lines.size() > max_lines:
		lines.resize(max_lines)
	return "\n".join(lines)

## Seconds of pause after letter i: long after . ! ?, short after , : ; (only before a space, so 4.5 or
## 1:2 type straight on, and none after the last letter).
static func _pause_after(text: String, i: int) -> float:
	if i >= text.length() - 1 or (text[i + 1] != " " and text[i + 1] != "\n"):
		return 0.0
	if ".!?".contains(text[i]):
		return float(D.TALK["pause_long"])
	if ",:;".contains(text[i]):
		return float(D.TALK["pause_short"])
	return 0.0

## Letters of `text` shown `seconds` after it began: Data.TALK cps plus the punctuation pauses.
static func typed_chars(text: String, seconds: float) -> int:
	var per: float = 1.0 / float(D.TALK["cps"])
	var at: float = 0.0
	for i: int in text.length():
		at += per
		if at > seconds:
			return i
		at += _pause_after(text, i)
	return text.length()

## Seconds `text` takes to type out, pauses included.
static func type_secs(text: String) -> float:
	var s: float = text.length() / float(D.TALK["cps"])
	for i: int in text.length():
		s += _pause_after(text, i)
	return s

## One chatter blip per letter revealed between prev_chars and now_chars; stops the sound at the end.
static func chatter_tick(text: String, prev_chars: int, now_chars: int) -> void:
	for i: int in range(maxi(prev_chars, 0), mini(now_chars, text.length())):
		Audio.chatter(text[i])
	if now_chars >= text.length() and prev_chars < text.length():
		Audio.chatter_stop()

static func _tex_of(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

static func _para_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = Pix.font()
		_font.spacing_bottom = 1
	return _font

## The portrait box and the speech bubble, exactly the builder guide's look. portrait_rect: the 38 x 42 box.
## bubble_pos: top left of the bubble. text: raw or already wrapped (3 rows at most are shown). typed_chars:
## letters shown. who: "guide" or "control". happy: the green cheer. more: a small ENTER hint (more lines wait).
## Returns the bubble rect, for click tests.
static func draw_bubble(ci: CanvasItem, portrait_rect: Rect2, bubble_pos: Vector2, text: String, typed_chars: int,
		who: String = "guide", happy: bool = false, more: bool = false) -> Rect2:
	var r: Rect2 = portrait_rect
	var clock: float = Time.get_ticks_msec() / 1000.0
	Pix.panel(ci, r, UI.CYAN, Color(0.05, 0.07, 0.14, 0.95))
	var full: String = wrap_text(text.replace("\n", " "), BUBBLE_W - 14.0, int(D.TALK["max_lines"]))
	var n: int = clampi(typed_chars, 0, full.length())
	var frame: int = 0   # idle, blink, talking, happy
	if happy:
		frame = 3
	elif n < full.length():
		frame = 2 if int(clock * 10.0) % 2 == 0 else 0
	elif fmod(clock, 3.7) < 0.13:
		frame = 1
	if who == "control":
		_draw_operator(ci, r, frame)
	else:
		var tex: Texture2D = _tex_of("res://art/vab/guide.png")
		if tex != null:
			ci.draw_texture_rect_region(tex, Rect2(r.position + Vector2(3, 3), Vector2(32, 36)), Rect2(frame * 32, 0, 32, 36))
	# the bubble: light, dark ink, a tail toward the portrait
	var w: float = 0.0
	for line: String in full.split("\n"):
		w = maxf(w, Pix.text_w(line, 10))
	var lines: int = full.count("\n") + 1
	var b: Rect2 = Rect2(bubble_pos, Vector2(floorf(w) + 14.0, 11.0 * lines + 9.0))
	var paper: Color = PAPER_HAPPY if happy else PAPER
	ci.draw_rect(b.grow(1), Pix.INK)
	ci.draw_rect(b, paper)
	ci.draw_rect(Rect2(b.position.x, b.end.y - 1.0, b.size.x, 1), Color("aab4cc"))
	for k: int in 4:   # the tail
		ci.draw_rect(Rect2(b.position.x - 1.0 - k, b.position.y + 6.0 + k, 1, 8 - 2 * k), Pix.INK)
		ci.draw_rect(Rect2(b.position.x - k, b.position.y + 7.0 + k, 1, maxf(0.0, 6.0 - 2.0 * k)), paper)
	ci.draw_multiline_string(_para_font(), b.position + Vector2(7, 12), full.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, -1, INK_TEXT)
	if more and int(clock * 2.0) % 2 == 0:
		Pix.keycap(ci, Vector2(b.end.x + 4.0, b.end.y - 13.0), "ENTER")
	return b

## The MESSAGE FROM EARTH operator (24 x 24, art/ui/event_operator.png) in the portrait box. Her one frame
## gets eyelids for the blink and a mouth drawn here: a line, open while talking, a smile when happy.
static func _draw_operator(ci: CanvasItem, r: Rect2, frame: int) -> void:
	var tex: Texture2D = _tex_of("res://art/ui/event_operator.png")
	var o: Vector2 = r.position + Vector2(7, 15)   # the shirt sits on the bottom edge of the box
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(32, 36)), Color("1d5a80"))
	if tex != null:
		ci.draw_texture(tex, o)
	var lid: Color = Color8(200, 138, 100)
	var lip: Color = Color8(150, 94, 66)
	match frame:
		1:
			ci.draw_rect(Rect2(o + Vector2(8, 10), Vector2(2, 2)), lid)
			ci.draw_rect(Rect2(o + Vector2(14, 10), Vector2(2, 2)), lid)
			ci.draw_rect(Rect2(o + Vector2(11, 16), Vector2(2, 1)), lip)
		2:
			ci.draw_rect(Rect2(o + Vector2(11, 16), Vector2(2, 2)), Color("5a2a2a"))
		3:
			ci.draw_rect(Rect2(o + Vector2(10, 17), Vector2(4, 1)), lip)
			ci.draw_rect(Rect2(o + Vector2(9, 16), Vector2(1, 1)), lip)
			ci.draw_rect(Rect2(o + Vector2(14, 16), Vector2(1, 1)), lip)
		_:
			ci.draw_rect(Rect2(o + Vector2(11, 16), Vector2(2, 1)), lip)
