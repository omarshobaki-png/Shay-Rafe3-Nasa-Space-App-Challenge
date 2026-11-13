extends Control
## The builder's team layer in multiplayer (decision D7): quick chat, REQUEST between roles, and toasts.
## The builder adds it on top of everything when Game.multi() is true. Messages go through Net (net.gd):
##   "chat"    {"msg": i}                                   index into Data.QUICK_CHAT
##   "request" {"id", "from", "to", "text"}                 the target role answers ACCEPT or DECLINE
##   "reply"   {"id", "ok"}
## Offline (testing with -- roles=...), a request to a role the computer plays is accepted at once.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

const TOAST_SECS: float = 4.5      # how long a toast stays (look only)
const TOAST_MAX: int = 5
const TOP: float = 28.0

var toasts: Array = []             # {"text", "col", "age"}
var seen: Dictionary = {}          # request id -> its message, to name the outcome
var queue: Array = []              # requests waiting for this player's answer
var asked_n: int = 0
var chat_box: PanelContainer = null
var req_box: PanelContainer = null
var answer_box: PanelContainer = null
var req_to: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)
	Net.received.connect(_on_net)

func _process(delta: float) -> void:
	for i: int in range(toasts.size() - 1, -1, -1):
		toasts[i]["age"] = float(toasts[i]["age"]) + delta
		if float(toasts[i]["age"]) > TOAST_SECS:
			toasts.remove_at(i)
	if answer_box == null and not queue.is_empty():
		_show_answer(queue.pop_front())
	queue_redraw()

func _draw() -> void:
	var y: float = TOP
	for tt: Dictionary in toasts:
		var text: String = tt["text"]
		var col: Color = tt["col"]
		var a: float = clampf((TOAST_SECS - float(tt["age"])) / 0.4, 0.0, 1.0)
		var w: float = Pix.text_w(text, 10) + 14.0
		var r: Rect2 = Rect2(floorf(310.0 - w / 2.0), y, w, 15)
		Pix.panel(self, r, Color(col, a), Color(0.03, 0.04, 0.08, 0.9 * a))
		Pix.text(self, r.position + Vector2(7, 11), text, 10, Color(col, a))
		y += 17.0

func toast(text: String, col: Color = UI.TEXT) -> void:
	toasts.push_front({"text": text, "col": col, "age": 0.0})
	if toasts.size() > TOAST_MAX:
		toasts.pop_back()
	Audio.play("radio_blip", -8.0)

## Which role a player id plays (its first one), for the colour of their chat.
func _role_of(from_id: int) -> String:
	for p: Variant in Net.lobby().get("players", []):
		var pd: Dictionary = p
		if int(pd.get("id", -1)) == from_id and not (pd.get("roles", []) as Array).is_empty():
			return String((pd["roles"] as Array)[0])
	return ""

func _short(role: String) -> String:
	return Game.role_name(role) if role != "" else "SOMEONE"

# ---------------------------------------------------------------- quick chat

func _input(ev: InputEvent) -> void:
	var k: InputEventKey = ev as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed:
		return
	var i: int = k.keycode - KEY_1
	if i >= 0 and i < mini(8, Data.QUICK_CHAT.size()):
		chat(i)
		get_viewport().set_input_as_handled()

func chat(i: int) -> void:
	_close_chat()
	Net.send("chat", {"msg": i})
	toast("%s: %s" % [_short(Game.my_role()), Data.QUICK_CHAT[i]], Game.role_color(Game.my_role()))

func toggle_chat(at: Vector2) -> void:
	if chat_box != null:
		_close_chat()
		return
	_close_request()
	chat_box = UI.panel(UI.PANEL2)
	var v: VBoxContainer = UI.vbox(2)
	chat_box.add_child(v)
	v.add_child(UI.label("QUICK CHAT  (KEYS 1-8)", 10, UI.CYAN))
	for i: int in mini(8, Data.QUICK_CHAT.size()):
		var b: Button = UI.button("%d  %s" % [i + 1, Data.QUICK_CHAT[i]], chat.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		v.add_child(b)
	add_child(chat_box)
	chat_box.position = at

func _close_chat() -> void:
	if chat_box != null:
		chat_box.queue_free()
		chat_box = null

# ---------------------------------------------------------------- REQUEST

func toggle_request() -> void:
	if req_box != null:
		_close_request()
		return
	_close_chat()
	req_to = ""
	_build_request()

func _build_request() -> void:
	if req_box != null:
		req_box.queue_free()
	req_box = UI.panel(UI.PANEL2)
	var v: VBoxContainer = UI.vbox(3)
	req_box.add_child(v)
	v.add_child(UI.label("REQUEST: ASK ANOTHER ROLE", 10, UI.YELLOW))
	var row: HBoxContainer = UI.hbox(3)
	v.add_child(row)
	for r: Dictionary in Data.ROLES:
		var id: String = r["id"]
		var b: Button = UI.button(String(r["name"]).split(" ")[0] if id != "planner" else "PLANNER", _pick_to.bind(id))
		b.focus_mode = Control.FOCUS_NONE
		if id == req_to:
			UI.color_button(b, r["color"])
		b.disabled = Net.owns(id) and Net.my_roles().size() < Net.ALL_ROLES.size()
		row.add_child(b)
	v.add_child(UI.label("THEN PICK WHAT YOU NEED:" if req_to == "" else "ASK THE %s:" % Game.role_name(req_to), 10, UI.DIM))
	for i: int in Data.REQUESTS.size():
		var b: Button = UI.button(Data.REQUESTS[i], _send_request.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = req_to == ""
		v.add_child(b)
	var c: Button = UI.button("CANCEL", _close_request)
	c.focus_mode = Control.FOCUS_NONE
	v.add_child(c)
	add_child(req_box)
	req_box.position = Vector2(196, 40)

func _pick_to(role: String) -> void:
	req_to = role
	Audio.play("ui_tab")
	_build_request()

func _close_request() -> void:
	if req_box != null:
		req_box.queue_free()
		req_box = null

func _send_request(i: int) -> void:
	if req_to == "":
		return
	asked_n += 1
	var d: Dictionary = {"id": "r%d_%d" % [Net.my_id(), asked_n], "from": Game.my_role(), "to": req_to, "text": Data.REQUESTS[i]}
	_close_request()
	Net.send("request", d)
	Game.team_request(String(d["id"]))
	_got_request(d)

func _got_request(d: Dictionary) -> void:
	var id: String = String(d.get("id", ""))
	var to: String = String(d.get("to", ""))
	seen[id] = d
	toast("%s ASKS %s: %s" % [_short(String(d.get("from", ""))), _short(to), String(d.get("text", ""))], Game.role_color(String(d.get("from", ""))))
	if Game.cpu(to):
		_answer(d, true)   # offline testing: the computer plays that role and agrees
	elif Net.owns(to):
		queue.append(d)

func _show_answer(d: Dictionary) -> void:
	answer_box = UI.panel(UI.PANEL2, Game.role_color(String(d.get("from", ""))))
	var v: VBoxContainer = UI.vbox(4)
	answer_box.add_child(v)
	v.add_child(UI.label("%s ASKS YOU (%s):" % [_short(String(d.get("from", ""))), _short(String(d.get("to", "")))], 10, UI.CYAN))
	v.add_child(UI.label(String(d.get("text", "")), 10, UI.TEXT))
	var row: HBoxContainer = UI.hbox(6)
	v.add_child(row)
	var ok: Button = UI.go_button("ACCEPT", _answer.bind(d, true), 10, 70)
	var no: Button = UI.danger_button("DECLINE", _answer.bind(d, false), 10, 70)
	ok.focus_mode = Control.FOCUS_NONE
	no.focus_mode = Control.FOCUS_NONE
	row.add_child(ok)
	row.add_child(no)
	add_child(answer_box)
	answer_box.position = Vector2(196, 286)
	Audio.play("ui_open")

func _answer(d: Dictionary, ok: bool) -> void:
	if answer_box != null:
		answer_box.queue_free()
		answer_box = null
	var reply: Dictionary = {"id": String(d.get("id", "")), "ok": ok}
	Net.send("reply", reply)
	Game.team_reply(String(reply["id"]))
	_got_reply(reply, String(d.get("to", "")))

func _got_reply(d: Dictionary, by: String = "") -> void:
	var req: Dictionary = seen.get(String(d.get("id", "")), {})
	var who: String = by if by != "" else String(req.get("to", ""))
	var ok: bool = bool(d.get("ok", false))
	toast("%s %s: %s" % [_short(who), "ACCEPTED" if ok else "DECLINED", String(req.get("text", "REQUEST"))], UI.GREEN if ok else UI.RED)

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
	match kind:
		"chat":
			var i: int = int(d.get("msg", -1))
			if i >= 0 and i < Data.QUICK_CHAT.size():
				var role: String = _role_of(from_id)
				toast("%s: %s" % [_short(role), Data.QUICK_CHAT[i]], Game.role_color(role))
		"request":
			_got_request(d)
		"reply":
			# a request this player answered elsewhere is no longer waiting
			var id: String = String(d.get("id", ""))
			queue = queue.filter(func(q: Dictionary) -> bool: return String(q.get("id", "")) != id)
			_got_reply(d)
