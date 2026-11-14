extends Control
## The decision pop-up every screen shares.
##
##   const EventCard = preload("res://scripts/event_card.gd")
##   EventCard.open(parent: Control, ev: Dictionary, done: Callable) -> Control
##       ev is an event from Game.next_event(phase). The card covers `parent` (640 x 360), takes the mouse
##       and the keys, shows who decides, the title and what happened (the event's "real" line is kept in
##       the data for the end report, it is not drawn here), lets the player choose (keys 1-3, click or tap), calls
##       Game.resolve_event(ev, choice), shows the outcome, and on CONTINUE (Enter, Space, click or tap)
##       frees itself and calls done.call(result) with the Dictionary Game.resolve_event returned.
##   EventCard.is_open() -> bool
##       true while a card is up: the screen stops its own clock, movement and input while it is.
##   EventCard.demo(parent, id = "", choice = -1) -> Control
##       for debug hooks and screenshots: opens event `id` (any id from scripts/events.gd; "" = the next
##       planned one) on the current mission; choice >= 0 also picks that choice, to show the outcome.
## Sounds: "alarm" or "radio_blip" when it opens, "confirm" / "error" for the outcome.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Events = preload("res://scripts/events.gd")

const W: float = 456.0
const PAD: float = 12.0
const ROLE_ICON: Dictionary = {"planner": "clipboard", "engineer": "wrench", "science": "science", "comms": "comms"}
const PHASE_WORDS: Dictionary = {"cruise": "ON THE WAY", "site": "AT THE SITE", "home": "AFTER THE SITE"}
const GRADE_WORDS: Dictionary = {"good": "A SOUND CALL", "risky": "A RISKY CALL", "bad": "A BAD CALL"}
const INPUT_DELAY: float = 0.4   # s: keys held from the game below must not pick a choice by accident

static var _current: Control = null

var ev: Dictionary = {}
var done: Callable = Callable()
var result: Dictionary = {}
var infos: Array = []
var hover: int = -1
var pressed: int = -1
var age: float = 0.0
var role_col: Color = UI.CYAN
var card: Rect2 = Rect2()
var hit: Array[Rect2] = []       # choice buttons, or the CONTINUE button alone once there is a result
var lh: float = 11.0

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
	for r: Dictionary in Data.ROLES:
		if r["id"] == ev.get("role", ""):
			role_col = r["color"]
	for i: int in (ev["choices"] as Array).size():
		infos.append(Game.event_choice(ev, i))
	var danger: bool = false
	for ch: Dictionary in ev["choices"]:
		var bad: Dictionary = (ch.get("risk", {}) as Dictionary).get("bad", {})
		if bad.has("fail") or bad.has("break"):
			danger = true
	Audio.play("alarm" if danger else "radio_blip", -8.0 if danger else -2.0)

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

func _lines(s: String, width: float) -> int:
	if s == "":
		return 0
	return maxi(1, roundi(Pix.font().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, 10).y / Pix.font().get_height(10)))

func _para(pos: Vector2, s: String, width: float, c: Color) -> float:
	Pix.para(self, pos + Vector2(0, 8), s, width, c)
	return _lines(s, width) * lh

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.74))
	var tw: float = W - PAD * 2.0
	var cw: float = tw - 30.0
	var choices: Array = ev["choices"]
	# heights first, so the card can be centred
	var h_text: float = _lines(String(ev["text"]), tw) * lh
	var h_body: float = 0.0
	var ch_h: Array[float] = []
	if result.is_empty():
		for i: int in choices.size():
			var info: Dictionary = infos[i]
			var note: String = _note(info)
			var hh: float = 6.0 + 14.0 + _lines(String(choices[i]["text"]), cw) * lh + (lh if note != "" else 0.0) + 4.0
			ch_h.append(hh)
			h_body += hh + 4.0
		h_body += 12.0
	else:
		h_body = 20.0 + _lines(String(result["text"]), tw) * lh + 8.0 + 18.0 + 8.0 + lh + 6.0 + 24.0
	var total: float = 22.0 + 20.0 + h_text + 10.0 + h_body + 8.0
	var slide: float = floorf(8.0 * (1.0 - clampf(age / 0.12, 0.0, 1.0)))
	card = Rect2(floorf((640.0 - W) / 2.0), floorf((360.0 - total) / 2.0) + slide, W, total)
	var x: float = card.position.x + PAD
	var y: float = card.position.y
	Pix.frame(self, card, "panel")
	Pix.frame(self, card, "panel_trim", role_col)
	# who decides
	var role: String = "%s DECIDES" % String(Events.ROLE_WORD.get(ev["role"], "CREW"))
	var tag_w: float = Pix.text_w(role, 10) + 30.0
	draw_rect(Rect2(card.position.x + 6.0, y + 5.0, tag_w, 15.0), role_col)
	draw_rect(Rect2(card.position.x + 6.0, y + 19.0, tag_w, 1.0), role_col.darkened(0.35))
	Pix.icon(self, String(ROLE_ICON.get(ev["role"], "helmet")), Vector2(card.position.x + 10.0, y + 6.0), Color(0.05, 0.07, 0.12))
	draw_string(Pix.font(), Vector2(card.position.x + 26.0, y + 16.0), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.07, 0.12))
	var ph: String = String(PHASE_WORDS.get(ev["phase"], ""))
	Pix.text(self, Vector2(card.end.x - PAD - Pix.text_w(ph, 10), y + 16.0), ph, 10, UI.DIM)
	y += 22.0
	Pix.title(self, Vector2(x, y + 14.0), String(ev["title"]), UI.TEXT)
	y += 20.0
	y += _para(Vector2(x, y), String(ev["text"]), tw, UI.TEXT) + 10.0
	hit.clear()
	if result.is_empty():
		for i: int in choices.size():
			var info: Dictionary = infos[i]
			var can: bool = info["can"]
			var r: Rect2 = Rect2(x - 4.0, y, tw + 8.0, ch_h[i])
			hit.append(r if can else Rect2())
			var face: String = "btn_disabled" if not can else ("btn_pressed" if pressed == i else ("btn_hover" if hover == i else "btn_normal"))
			Pix.frame(self, r, face)
			var dy: float = 1.0 if pressed == i and can else 0.0
			Pix.keycap(self, Vector2(x + 2.0, y + 6.0 + dy), str(i + 1))
			Pix.title(self, Vector2(x + 24.0, y + 17.0 + dy), String(choices[i]["label"]), UI.TEXT if can else UI.DIM)
			var ty: float = y + 20.0 + dy
			ty += _para(Vector2(x + 24.0, ty), String(choices[i]["text"]), cw, UI.TEXT if can else Color("5a6488"))
			var note: String = _note(info)
			if note != "":
				Pix.text(self, Vector2(x + 24.0, ty + 8.0), note, 10, UI.RED if not can else (UI.YELLOW if String(info["warn"]) != "" else (UI.GREEN if bool(info["safe"]) else UI.DIM)))
			y += ch_h[i] + 4.0
		var keys: String = "PRESS 1 OR 2, OR CLICK A CHOICE" if choices.size() == 2 else "PRESS 1, 2 OR 3, OR CLICK A CHOICE"
		Pix.text_c(self, card.get_center().x, y + 9.0, keys, 10, UI.DIM if int(age * 2.0) % 2 == 0 else UI.TEXT)
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

## The line under a choice in the ship's own numbers: why it is closed, what it leaves short, or the price.
func _note(info: Dictionary) -> String:
	if not bool(info["can"]):
		return String(info["why"])
	if String(info["warn"]) != "":
		return String(info["warn"])
	return String(info["line"]).to_upper() if bool(info["safe"]) else String(info["line"])
