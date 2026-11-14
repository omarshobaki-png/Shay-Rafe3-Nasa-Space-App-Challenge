extends Control
## The decision pop-up every screen shares. Two kinds you tell apart at a glance (v6):
##   ev["from"] == "ship"   amber ALERT: hazard stripes, a warning sign, the alarm sound
##   ev["from"] == "earth"  blue MESSAGE FROM EARTH: a radio mast, the operator's portrait, "SENT ... AGO"
##                          (the destination's real light delay), a radio blip
##
##   const EventCard = preload("res://scripts/event_card.gd")
##   EventCard.open(parent: Control, ev: Dictionary, done: Callable) -> Control
##       ev is an event from Game.next_event(phase). The card covers `parent` (640 x 360), takes the mouse
##       and the keys, shows the title, what happened and two big choices (keys 1-2, click or tap), calls
##       Game.resolve_event(ev, choice), shows the outcome, and on CONTINUE (Enter, Space, click or tap)
##       frees itself and calls done.call(result) with the Dictionary Game.resolve_event returned.
##       (The event's "real" line stays in the data for the end report; it is not drawn here.)
##   EventCard.is_open() -> bool
##       true while a card is up: the screen stops its own clock, movement and input while it is.
##   EventCard.demo(parent, id = "", choice = -1) -> Control
##       for debug hooks and screenshots: opens event `id` (any id from scripts/events.gd; "" = the next
##       planned one) on the current mission; choice >= 0 also picks that choice, to show the outcome.
## Sounds (all in scripts/audio.gd): "alarm" (ALERT) or "radio_blip" (MESSAGE) when it opens,
## "confirm" / "error" for the outcome, "ui_deny" for a closed choice.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Events = preload("res://scripts/events.gd")

const W: float = 480.0           # a multiple of 16: the stripe tile repeats evenly
const PAD: float = 12.0
const PHASE_WORDS: Dictionary = {"cruise": "ON THE WAY", "site": "AT THE SITE", "home": "AFTER THE SITE"}
const GRADE_WORDS: Dictionary = {"good": "A SOUND CALL", "risky": "A RISKY CALL", "bad": "A BAD CALL"}
const INPUT_DELAY: float = 0.4   # s: keys held from the game below must not pick a choice by accident
const AMBER: Color = Color("f08a2a")
const AMBER_HI: Color = Color("ffc060")
const RADIO: Color = Color("39a0c8")
const RADIO_BAR: Color = Color("1d5a80")
const RADIO_HI: Color = Color("8fe3f5")

static var _current: Control = null

var ev: Dictionary = {}
var done: Callable = Callable()
var result: Dictionary = {}
var infos: Array = []
var hover: int = -1
var pressed: int = -1
var age: float = 0.0
var earth: bool = false
var role_col: Color = UI.CYAN
var card: Rect2 = Rect2()
var hit: Array[Rect2] = []       # choice buttons, or the CONTINUE button alone once there is a result
var lh: float = 11.0
var lh2: float = 20.0
# textures live in members so they are never freed before they draw
var tex_stripes: Texture2D = null
var tex_alert: Texture2D = null
var tex_radio: Texture2D = null
var tex_operator: Texture2D = null

static func is_open() -> bool:
	return _current != null and is_instance_valid(_current) and not _current.is_queued_for_deletion()

static func open(parent: Control, event: Dictionary, on_done: Callable) -> Control:
	if is_open():
		_current.queue_free()
	var c: Control = (load("res://scripts/event_card.gd") as GDScript).new()
	c.set("ev", event)
	c.set("done", on_done)
	_current = c
	parent.add_child(c)
	return c

static func demo(parent: Control, id: String = "", choice: int = -1) -> Control:
	if Game.run.is_empty():
		Game.start_run()
	var event: Dictionary = Game.event_by_id(id) if id != "" else Game.next_event("cruise")
	if event.is_empty():
		event = Game.event_by_id("storm")
	var c: Control = open(parent, event, func(_r: Dictionary) -> void: pass)
	if choice >= 0:
		c.call("_choose", choice)
	return c

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	lh = Pix.font().get_height(10) + 1.0
	lh2 = Pix.font().get_height(20)
	earth = String(ev.get("from", "ship")) == "earth"
	tex_stripes = Pix.ui_tex("event_stripes")
	tex_alert = Pix.ui_tex("event_alert")
	tex_radio = Pix.ui_tex("event_radio")
	tex_operator = Pix.ui_tex("event_operator")
	for r: Dictionary in Data.ROLES:
		if r["id"] == ev.get("role", ""):
			role_col = r["color"]
	for i: int in (ev["choices"] as Array).size():
		infos.append(Game.event_choice(ev, i))
	if earth:
		Audio.play("radio_blip", -2.0)
	else:
		Audio.play("alarm", -8.0)

func _exit_tree() -> void:
	if _current == self:
		_current = null

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

# ---------------------------------------------------------------- input

func _choose(i: int) -> void:
	if not result.is_empty() or i < 0 or i >= infos.size():
		return
	var res: Dictionary = Game.resolve_event(ev, i)
	if res.has("refused"):
		Audio.play("ui_deny")
		return
	result = res
	hover = -1
	pressed = -1
	age = maxf(age, INPUT_DELAY) - 0.25   # a short beat before CONTINUE can be pressed
	Audio.play("confirm" if bool(res["ok"]) else "error", -3.0)

func _continue() -> void:
	var cb: Callable = done
	var res: Dictionary = result
	if _current == self:
		_current = null
	queue_free()
	if cb.is_valid():
		cb.call(res)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()   # the screen below gets no keys while the card is up
	var k: InputEventKey = event
	if not k.pressed or k.echo or age < INPUT_DELAY:
		return
	if result.is_empty():
		var n: int = -1
		match k.keycode:
			KEY_1, KEY_KP_1:
				n = 0
			KEY_2, KEY_KP_2:
				n = 1
			KEY_3, KEY_KP_3:
				n = 2
		_choose(n)
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_continue()

func _gui_input(event: InputEvent) -> void:
	accept_event()
	if event is InputEventMouseMotion:
		hover = _at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		var i: int = _at(mb.position)
		if mb.pressed:
			pressed = i
		else:
			if i >= 0 and i == pressed and age >= INPUT_DELAY:
				if result.is_empty():
					_choose(i)
				else:
					_continue()
			pressed = -1

func _at(p: Vector2) -> int:
	for i: int in hit.size():
		if hit[i].has_point(p):
			return i
	return -1

# ---------------------------------------------------------------- drawing

func _lines(s: String, width: float, fs: int = 10) -> int:
	if s == "":
		return 0
	var f: FontFile = Pix.font()
	return maxi(1, roundi(f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y / f.get_height(fs)))

## Wrapped text with a drop shadow; returns the height it took. fs: 10 or 20.
func _para(pos: Vector2, s: String, width: float, c: Color, fs: int = 10) -> float:
	var f: FontFile = Pix.font()
	var q: Vector2 = pos.floor() + Vector2(0, f.get_ascent(fs))
	var k: float = fs / 10.0
	draw_multiline_string(f, q + Vector2(k, k), s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, -1, Color(0, 0, 0, 0.85))
	draw_multiline_string(f, q, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, -1, c)
	return _lines(s, width, fs) * f.get_height(fs)

## The title in the bold font: twice the size when it fits.
func _title_scale(s: String, width: float) -> int:
	return 2 if Pix.title_w(s, 2) <= width else 1

func _stripes(y: float) -> void:
	if tex_stripes == null:
		return
	var x0: float = card.position.x + 3.0
	var x1: float = card.end.x - 3.0
	var tw: float = tex_stripes.get_width()
	var x: float = x0 - fposmod(floorf(age * 12.0), tw)   # the stripes crawl slowly, like a warning light
	while x < x1:
		var a: float = maxf(x, x0)
		var b: float = minf(x + tw, x1)
		draw_texture_rect_region(tex_stripes, Rect2(a, y, b - a, tex_stripes.get_height()), Rect2(a - x, 0, b - a, tex_stripes.get_height()))
		x += tw

func _draw() -> void:
	var accent: Color = RADIO if earth else AMBER
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.07, 0.76) if earth else Color(0.06, 0.02, 0.01, 0.74))
	var tw: float = W - PAD * 2.0
	var choices: Array = ev["choices"]
	var title: String = String(ev["title"])
	# the body sits beside the portrait on a message, under the header on an alert
	var body_x: float = 34.0 if earth else 0.0
	var body_w: float = tw - body_x
	var ts: int = _title_scale(title, body_w)
	var h_title: float = 32.0 if ts == 2 else 18.0
	var h_text: float = _lines(String(ev["text"]), body_w, 20) * lh2
	var h_head: float = 30.0 if earth else 36.0
	var bw: float = floorf((tw - 8.0) / 2.0)
	var h_btn: float = 0.0
	var h_body: float = 0.0
	if result.is_empty():
		for i: int in choices.size():
			var note: String = _note(infos[i])
			h_btn = maxf(h_btn, 24.0 + _lines(String(choices[i]["text"]), bw - 14.0) * lh + _lines(note, bw - 14.0) * lh + 6.0)
		h_body = h_btn + 6.0 + 14.0
	else:
		h_body = 20.0 + _lines(String(result["text"]), tw) * lh + 8.0 + 18.0 + 8.0 + lh + 6.0 + 24.0
	var h_top: float = maxf(h_title + h_text, 30.0) if earth else h_title + h_text
	var total: float = h_head + h_top + 10.0 + h_body + (14.0 if not earth else 8.0)
	var slide: float = floorf(8.0 * (1.0 - clampf(age / 0.12, 0.0, 1.0)))
	card = Rect2(floorf((640.0 - W) / 2.0), floorf((360.0 - total) / 2.0) + slide, W, floorf(total))
	var x: float = card.position.x + PAD
	var y: float = card.position.y
	Pix.frame(self, card, "panel")
	Pix.frame(self, card, "panel_trim", accent)
	var ph: String = String(PHASE_WORDS.get(ev["phase"], ""))
	if earth:
		# blue header bar: radio mast, who is calling, how long ago they sent it
		draw_rect(Rect2(card.position.x + 3.0, y + 3.0, W - 6.0, 22.0), RADIO_BAR)
		draw_rect(Rect2(card.position.x + 3.0, y + 24.0, W - 6.0, 1.0), Color("0f2b40"))
		draw_rect(Rect2(card.position.x + 3.0, y + 3.0, W - 6.0, 1.0), RADIO)
		if tex_radio != null:
			var wave: Color = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(age * 5.0)))
			draw_texture(tex_radio, Vector2(x - 2.0, y + 5.0), wave)
		Pix.title(self, Vector2(x + 22.0, y + 18.0), "MESSAGE FROM EARTH", UI.TEXT)
		var sent: String = "SENT %s AGO" % String(Game.dest().get("light_delay", "")).to_upper()
		Pix.text(self, Vector2(card.end.x - PAD - Pix.text_w(sent, 10), y + 17.0), sent, 10, RADIO_HI)
		y += h_head
		# the operator on the left, the message beside her
		Pix.frame(self, Rect2(x - 2.0, y - 2.0, 28.0, 28.0), "tooltip", RADIO)
		if tex_operator != null:
			draw_texture(tex_operator, Vector2(x, y))
		Pix.title(self, Vector2(x + body_x, y + (22.0 if ts == 2 else 11.0)), title, RADIO_HI, ts)
		_para(Vector2(x + body_x, y + h_title), String(ev["text"]), body_w, UI.TEXT, 20)
		y += h_top + 10.0
	else:
		# amber hazard stripes, the warning sign and a blinking ALERT
		_stripes(y + 3.0)
		y += 12.0
		if tex_alert != null:
			draw_texture(tex_alert, Vector2(x, y))
		var blink: bool = age < 1.6 and int(age * 4.0) % 2 == 1
		Pix.title(self, Vector2(x + 26.0, y + 14.0), "ALERT", AMBER_HI if blink else AMBER)
		Pix.text(self, Vector2(x + 30.0 + Pix.title_w("ALERT"), y + 13.0), "SOMETHING HAPPENED TO THE SHIP", 10, UI.DIM)
		Pix.text(self, Vector2(card.end.x - PAD - Pix.text_w(ph, 10), y + 13.0), ph, 10, UI.DIM)
		y += h_head - 12.0
		Pix.title(self, Vector2(x, y + (22.0 if ts == 2 else 11.0)), title, UI.TEXT, ts)
		_para(Vector2(x, y + h_title), String(ev["text"]), tw, UI.TEXT, 20)
		y += h_top + 10.0
	hit.clear()
	if result.is_empty():
		for i: int in choices.size():
			var info: Dictionary = infos[i]
			var can: bool = info["can"]
			var r: Rect2 = Rect2(x + (bw + 8.0) * i, y, bw, h_btn)
			hit.append(r if can else Rect2())
			var face: String = "btn_disabled" if not can else ("btn_pressed" if pressed == i else ("btn_hover" if hover == i else "btn_normal"))
			Pix.frame(self, r, face)
			var dy: float = 1.0 if pressed == i and can else 0.0
			Pix.keycap(self, Vector2(r.position.x + 6.0, r.position.y + 6.0 + dy), str(i + 1))
			Pix.title(self, Vector2(r.position.x + 24.0, r.position.y + 17.0 + dy), String(choices[i]["label"]), UI.TEXT if can else UI.DIM)
			var ty: float = r.position.y + 24.0 + dy
			ty += _para(Vector2(r.position.x + 7.0, ty), String(choices[i]["text"]), bw - 14.0, UI.TEXT if can else Color("5a6488"))
			var note: String = _note(info)
			if note != "":
				var nc: Color = UI.RED if not can else (UI.YELLOW if String(info["warn"]) != "" else (UI.GREEN if bool(info["safe"]) else UI.DIM))
				_para(Vector2(r.position.x + 7.0, ty), note, bw - 14.0, nc)
		y += h_btn + 6.0
		var keys: String = "PRESS 1 OR 2, OR CLICK A CHOICE"
		Pix.text(self, Vector2(x, y + 9.0), keys, 10, UI.DIM if int(age * 2.0) % 2 == 0 else UI.TEXT)
		var role: String = "%s DECIDES" % String(Events.ROLE_WORD.get(ev["role"], "CREW"))
		Pix.text(self, Vector2(card.end.x - PAD - Pix.text_w(role, 10), y + 9.0), role, 10, role_col)
	else:
		var ok: bool = result["ok"]
		var col: Color = UI.GREEN if ok else UI.RED
		Pix.icon(self, "ok" if ok else "bad", Vector2(x, y + 3.0))
		Pix.title(self, Vector2(x + 16.0, y + 14.0), "%s: %s" % [String(ev["choices"][int(ev["choice"])]["label"]), "IT WENT WELL" if ok else "IT WENT WRONG"], col)
		y += 20.0
		y += _para(Vector2(x, y), String(result["text"]), tw, UI.TEXT) + 8.0
		# what it changed, as chips
		var cx: float = x
		for chip: Array in result["chips"]:
			var cwid: float = Pix.text_w(String(chip[1]), 10) + 24.0
			if cx + cwid > card.end.x - PAD:
				break
			Pix.frame(self, Rect2(cx, y, cwid, 17.0), "tooltip")
			Pix.icon(self, String(chip[0]), Vector2(cx + 3.0, y + 2.0))
			Pix.text(self, Vector2(cx + 18.0, y + 12.0), String(chip[1]), 10, UI.RED if bool(chip[2]) else UI.GREEN)
			cx += cwid + 4.0
		if (result["chips"] as Array).is_empty():
			Pix.text(self, Vector2(x, y + 12.0), "Nothing was lost.", 10, UI.GREEN)
		y += 18.0 + 8.0
		Pix.text(self, Vector2(x, y + 9.0), "The report counts this as %s." % String(GRADE_WORDS[result["grade"]]), 10, UI.DIM)
		y += lh + 6.0
		var br: Rect2 = Rect2(card.get_center().x - 80.0, y, 160.0, 21.0)
		hit.append(br)
		Pix.button(self, br, "CONTINUE", "btn_go", "pressed" if pressed == 0 else ("hover" if hover == 0 else "normal"))
		Pix.keycap(self, Vector2(br.end.x + 6.0, y + 4.0), "ENTER")
	if not earth:
		_stripes(card.end.y - 9.0)

## The line under a choice in the ship's own numbers: why it is closed, what it leaves short, or the price.
func _note(info: Dictionary) -> String:
	if not bool(info["can"]):
		return String(info["why"])
	if String(info["warn"]) != "":
		return String(info["warn"])
	return String(info["line"]).to_upper() if bool(info["safe"]) else String(info["line"])
