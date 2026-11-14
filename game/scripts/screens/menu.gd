extends Control
## Title screen: the Solar System as a destination picker, one mission card for the picked world, a difficulty
## selector, a briefing before the builder, and the Tech Lab / how to play / sources overlays.
## Everything is drawn by hand on the 640x360 pixel grid; buttons are hit rectangles registered while drawing.
## Every fact shown comes from Data.DEST; sizes follow tools/art/gen_menu_system.py (compressed, order kept).

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const BG_TEX: Texture2D = preload("res://art/bg_space.png")

## Set by the report screen: open the Tech Lab as soon as the menu appears.
static var open_tech_next: bool = false

const FRAME_M: Array = [6, 6, 6, 8]
const BTN_M: Array = [4, 5, 4, 6]
const TILE_M: Array = [5, 5, 5, 6]

## Three text colours per view.
const C_TXT: Color = UI.TEXT
const C_DIM: Color = UI.DIM
const C_HI: Color = UI.YELLOW

## The strip, left to right in true order from the Sun. x = centre on screen.
const ROW_Y: int = 106
const BODIES: Array = [
	{"id": "mercury", "x": 50}, {"id": "venus", "x": 90}, {"id": "earth", "x": 130}, {"id": "moon", "x": 148, "dy": -10},
	{"id": "mars", "x": 180}, {"id": "jupiter", "x": 246}, {"id": "saturn", "x": 352}, {"id": "uranus", "x": 462}, {"id": "neptune", "x": 566},
]
## LEFT / RIGHT order = screen order.
const PICK_ORDER: Array[String] = ["mercury", "venus", "moon", "mars", "jupiter", "saturn", "uranus", "neptune"]
const SUN_C: Vector2 = Vector2(-63, ROW_Y)
## Which of Data.DEST[id]["facts"] the card shows (the one that surprises most and repeats the card least).
const FACT_IDX: Dictionary = {"moon": 3, "mercury": 1, "venus": 1, "mars": 2, "jupiter": 2, "saturn": 3, "uranus": 2, "neptune": 3}
const RES_ICON: Dictionary = {"mass": "mass", "power": "power", "fuel": "fuel", "budget": "money", "time": "time", "data": "data", "comms": "comms"}
const LEVEL_COL: Array[Color] = [UI.GREEN, UI.YELLOW, UI.RED]

const CARD: Rect2 = Rect2(10, 158, 620, 168)

var t: float = 0.0
var tex_cache: Dictionary = {}
var hits: Array = []
var blocked: bool = false
var hot: String = ""
var down: String = ""
var force_hot: String = ""

var sel: String = "moon"
var picked: bool = false   # the player chose a world this visit: the top line moves on
var sel_t: float = 0.0     # time since the pick, for the reticle snap
var tasks: Array = []      # Game.tasks() for `sel`, easiest first
var task_i: int = 0
var task_picked: bool = false

var overlay: String = ""
var ov_t: float = 0.0
var shown_funds: float = 0.0
var reset_armed: float = -10.0
var sparks: Array = []   # {pos, age, dur, tint}
var shake: Dictionary = {}  # tile id -> time of a denied click
var bought: Dictionary = {}  # tile id -> time of the purchase

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Data.DEST.has(Game.dest_id):
		sel = Game.dest_id
	for n: String in ["logo", "card", "plate", "tile", "tile_owned", "medal_gold", "medal_silver", "medal_bronze",
			"ic_play", "ic_coin", "ic_helmet", "ic_helmet_off", "ic_flask", "ic_help", "ic_fact", "ic_close", "ic_tick", "ic_dash",
			"pip_g", "pip_y", "pip_r", "pip_off", "ground_moon", "lamp_go", "lamp_nogo", "lamp_warn",
			"veh_lander", "veh_rover", "veh_orbiter", "veh_drone", "sun_edge",
			"tech_solar2", "tech_batt2", "tech_ka", "tech_rover2", "tech_armor", "tech_grant"]:
		_tx(n)
	for b: Dictionary in BODIES:
		_tx("sys_" + String(b["id"]))
	for n: String in ["btn_green", "btn_yellow", "btn_red", "btn_blue", "btn_grey"]:
		for s: String in ["n", "h", "p"]:
			_tx(n + "_" + s)
	for id: String in PICK_ORDER:
		_planet("planet_%s_%d" % [id, 22 if id == "saturn" else 36])
	_load_tasks()
	shown_funds = float(Game.funds)
	if open_tech_next:
		open_tech_next = false
		_open("tech")

func _tx(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/menu/%s.png" % name) as Texture2D
	return tex_cache[name]

func _planet(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/%s.png" % name) as Texture2D
	return tex_cache[name]

# ---------------------------------------------------------------- input

func _process(delta: float) -> void:
	t += delta
	sel_t += delta
	var h: String = _hit_at(get_local_mouse_position())
	if force_hot != "":
		h = force_hot
	if h != hot:
		hot = h
		if h != "" and h != "o:panel" and h != "o:dim":
			Audio.play("ui_hover", -9.0)
	if overlay != "":
		ov_t += delta
	var gap: float = absf(shown_funds - float(Game.funds))
	shown_funds = move_toward(shown_funds, float(Game.funds), maxf(60.0 * delta, gap * 6.0 * delta))
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["dur"]):
			sparks.remove_at(i)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		down = _hit_at(e.position)
		hot = down
	else:
		var up: String = _hit_at(e.position)
		if up != "" and up == down:
			_activate(up)
		down = ""

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			_close()
		KEY_LEFT, KEY_RIGHT:
			if overlay == "":
				var i: int = PICK_ORDER.find(sel) + (1 if k.keycode == KEY_RIGHT else -1)
				_pick(PICK_ORDER[posmod(i, PICK_ORDER.size())])
		KEY_UP, KEY_DOWN:
			if overlay == "" and not tasks.is_empty():
				_pick_task(clampi(task_i + (1 if k.keycode == KEY_DOWN else -1), 0, tasks.size() - 1))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if overlay == "":
				_activate("play")
			elif overlay == "brief":
				_activate("o:start")

func _hit_at(p: Vector2) -> String:
	for i: int in range(hits.size() - 1, -1, -1):
		var r: Rect2 = hits[i][0]
		if r.has_point(p):
			return hits[i][1]
	return ""

func _hit(r: Rect2, id: String) -> void:
	if blocked and not id.begins_with("o:"):
		return
	hits.append([r, id])

func _activate(id: String) -> void:
	if id == "o:panel":
		return
	if id == "o:dim":
		_close()
	elif id.begins_with("dest:"):
		_pick(id.substr(5))
	elif id == "play":
		Audio.play("confirm")
		_open("brief")
	elif id == "o:start":
		_start()
	elif id.begins_with("task:"):
		_pick_task(int(id.substr(5)))
	elif id.begins_with("pl:"):
		Audio.play("ui_tab")
		Game.players = int(id.substr(3))
	elif id == "tech" or id == "help" or id == "src":
		_open(id)
	elif id == "o:close":
		_close()
	elif id.begins_with("o:buy:"):
		_buy(id.substr(6))
	elif id == "o:reset":
		_reset()

func _pick(id: String) -> void:
	if id != sel:
		Audio.play("ui_tab")
		sel_t = 0.0
		sel = id
		task_picked = false
		_load_tasks()
	picked = true

func _pick_task(i: int) -> void:
	if i != task_i:
		Audio.play("ui_tab")
	task_i = i
	task_picked = true

## The three tasks of `sel` from the core (Game.tasks() reads Game.dest_id). Until the core has tasks,
## the three difficulty levels stand in, so the menu never breaks.
func _load_tasks() -> void:
	tasks = []
	if Game.has_method("tasks"):
		Game.dest_id = sel
		tasks = Game.call("tasks")
	if tasks.is_empty():
		for i: int in 3:
			var lv: String = String(Data.DIFFICULTY[i]["name"])
			tasks.append({"id": lv.to_lower(), "name": lv.capitalize() + " mission", "diff": i, "level": lv, "text": String(Data.DEST[sel]["goal"]), "goal": String(Data.DEST[sel]["goal"]), "samples": 0})
	task_i = clampi(task_i, 0, tasks.size() - 1)

func _start() -> void:
	Audio.play("confirm")
	Audio.play("ignition", -6.0)
	Game.new_mission(sel)
	if Game.has_method("set_task"):
		Game.call("set_task", task_i)
	else:
		Game.difficulty = int(tasks[task_i]["diff"])
	Game.save_game()
	Game.goto("builder")

func _open(which: String) -> void:
	overlay = which
	ov_t = 0.0
	Audio.play("ui_open")

func _close() -> void:
	if overlay != "":
		Audio.play("ui_close")
	overlay = ""

func _buy(id: String) -> void:
	var cost: int = int(Data.TECH[id]["cost"])
	if Game.tech.has(id):
		return
	if Game.funds < cost:
		Audio.play("ui_deny")
		shake[id] = t
		return
	if Game.buy_tech(id):
		Audio.play("coin")
		Audio.play("confirm", -3.0)
		bought[id] = t
		var c: Vector2 = _tile_rect(id).get_center()
		for k: int in 5:
			sparks.append({"pos": c + Vector2((k - 2) * 26, ((k * 7) % 5) * 7 - 14), "age": -0.07 * k, "dur": 0.55, "tint": Color("ffd75e")})

func _reset() -> void:
	if t - reset_armed < 3.0:
		reset_armed = -10.0
		Game.reset_save()
		Audio.play("ui_close")
		shown_funds = float(Game.funds)
	else:
		reset_armed = t
		Audio.play("ui_deny", -6.0)

# ---------------------------------------------------------------- drawing helpers

func _nine(r: Rect2, name: String, m: Array, mod: Color = Color.WHITE) -> void:
	var tx: Texture2D = _tx(name)
	RenderingServer.canvas_item_add_nine_patch(get_canvas_item(), Rect2(r.position.floor(), r.size.floor()), Rect2(Vector2.ZERO, tx.get_size()),
		tx.get_rid(), Vector2(m[0], m[1]), Vector2(m[2], m[3]), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, mod)

func _blit(tx: Texture2D, pos: Vector2, clip: Rect2, mod: Color = Color.WHITE) -> void:
	var dst: Rect2 = Rect2(pos, tx.get_size()).intersection(clip)
	if dst.size.x <= 0.0 or dst.size.y <= 0.0:
		return
	draw_texture_rect_region(tx, dst, Rect2(dst.position - pos, dst.size), mod)

func _img(name: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	draw_texture(_tx(name), pos.floor(), mod)

func _para(p: Vector2, s: String, w: float, c: Color, lines_max: int = 9) -> int:
	## Word-wrapped 10 px text, baseline-left at p, 12 px per line. Returns the number of lines used.
	var f: Font = Pix.font()
	var line: String = ""
	var n: int = 0
	for wd: String in s.split(" "):
		var test: String = wd if line == "" else line + " " + wd
		if line != "" and f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > w:
			Pix.text(self, p + Vector2(0, n * 12), line, 10, c)
			n += 1
			line = wd
			if n >= lines_max:
				return n
		else:
			line = test
	if line != "":
		Pix.text(self, p + Vector2(0, n * 12), line, 10, c)
		n += 1
	return n

## A face from art/menu with a label and an optional 14 px icon. owns_hit false: the caller registered the hit.
func _button(r: Rect2, id: String, label: String, kind: String, icon: String = "", enabled: bool = true, mod: Color = Color.WHITE, owns_hit: bool = true) -> void:
	if owns_hit:
		_hit(r, id)
	var state: String = "n"
	if enabled and hot == id:
		state = "p" if down == id else "h"
	if not enabled:
		kind = "btn_grey"
	var drop: int = 2 if state == "p" else 0
	_nine(Rect2(r.position, Vector2(r.size.x, 24)), "%s_%s" % [kind, state], BTN_M, mod)
	var ink: Color = Color("f4f8ff")
	if kind == "btn_yellow":
		ink = Color("2a1c04")
	if not enabled:
		ink = Color("6a7490")
	var w: float = Pix.text_w(label, 10) + (16.0 if icon != "" else 0.0)
	var x: float = r.position.x + floorf((r.size.x - w) / 2.0)
	var by: float = r.position.y + 15.0 + drop
	if icon != "":
		_img(icon, Vector2(x, by - 11), mod * Color(1, 1, 1, 1.0 if enabled else 0.5))
		x += 16.0
	Pix.text(self, Vector2(x, by), label, 10, ink * mod)

## Critical resources as icon + name in a row. Returns the end x.
func _critical_row(p: Vector2, id: String) -> float:
	var x: float = p.x
	for res: String in Data.DEST[id]["critical"]:
		Pix.icon(self, String(RES_ICON.get(res, "warn")), Vector2(x, p.y - 10))
		var nm: String = String(Data.USE_NAMES.get(res, res.to_upper()))
		Pix.text(self, Vector2(x + 15, p.y), nm, 10, C_TXT)
		x += 15.0 + Pix.text_w(nm, 10) + 12.0
	return x

## Four 3 px corner brackets around r (the selection reticle).
func _brackets(r: Rect2, c: Color) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	for corner: Vector2 in [q.position, Vector2(q.end.x - 1, q.position.y), Vector2(q.position.x, q.end.y - 1), q.end - Vector2.ONE]:
		var sx: float = 1.0 if corner.x == q.position.x else -1.0
		var sy: float = 1.0 if corner.y == q.position.y else -1.0
		draw_rect(Rect2(corner.x if sx > 0 else corner.x - 3, corner.y, 4, 1), c)
		draw_rect(Rect2(corner.x, corner.y if sy > 0 else corner.y - 3, 1, 4), c)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	hits.clear()
	blocked = overlay != ""
	_draw_background()
	_draw_system()
	_draw_title()
	_draw_card()
	_draw_bar()
	for s: Dictionary in sparks:
		if float(s["age"]) >= 0.0:
			Fx.sparkle(self, s["pos"], float(s["age"]) / float(s["dur"]), s["tint"], 1)
	if overlay != "":
		_draw_overlay()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	Pix.tiled(self, BG_TEX, 0, t * 2.0, 640.0, Color(0.85, 0.85, 1.0))
	Pix.stars(self, t, Vector2(640, 360), 50, 11, Vector2(-t * 1.5, 0))
	Pix.stars(self, t * 1.3, Vector2(640, 360), 26, 5, Vector2(-t * 4.0, 0))

func _draw_title() -> void:
	var lg: Texture2D = _tx("logo")
	var by: float = floorf(sin(t * 1.1) * 1.4)
	draw_texture(lg, Vector2(floorf((640.0 - lg.get_width()) / 2.0), 2.0 + by))
	var gp: float = fposmod(t, 4.5) / 0.7
	if gp < 1.0:
		Fx.sparkle(self, Vector2(190.0 + gp * 260.0, 14.0 + by), gp, Color("fff4b8"), 1)
	# what to do now: stays until the player has done it
	var head: String = "PICK A DESTINATION"
	var tail: String = "  CLICK A PLANET, OR LEFT / RIGHT"
	if picked and not task_picked:
		head = "PICK A TASK"
		tail = "  ON THE CARD, OR UP / DOWN"
	elif picked:
		head = "PRESS PLAY"
		tail = "  OR ENTER"
	var w: float = Pix.title_w(head, 1) + Pix.text_w(tail, 10)
	var x: float = floorf(320.0 - w / 2.0)
	var blink: bool = fposmod(t, 1.0) < 0.6
	Pix.text(self, Vector2(x - 12, 68), ">" if blink else " ", 10, C_HI)
	Pix.title(self, Vector2(x, 68), head, C_HI, 1)
	Pix.text(self, Vector2(x + Pix.title_w(head, 1), 68), tail, 10, C_TXT)

func _body_pos(i: int) -> Vector2:
	var b: Dictionary = BODIES[i]
	var bob: float = roundf(sin(t * 0.6 + i * 1.3) * 1.2)
	return Vector2(float(b["x"]), ROW_Y + float(b.get("dy", 0)) + bob)

func _draw_system() -> void:
	# orbits: faint dotted arcs centred on the Sun
	for b: Dictionary in BODIES:
		if b["id"] == "moon":
			continue
		var rad: float = float(b["x"]) - SUN_C.x
		var steps: int = int(rad * 0.9 / 4.0)
		for k: int in range(-steps, steps + 1):
			var a: float = k * 4.0 / rad
			var p: Vector2 = SUN_C + Vector2(cos(a), sin(a)) * rad
			if p.y > 74.0 and p.y < 141.0:
				draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.5, 0.6, 1.0, 0.16))
	# the Sun at the left edge
	var sun: Texture2D = _tx("sun_edge")
	draw_texture(sun, Vector2(0, ROW_Y - floorf(sun.get_height() / 2.0)))
	Fx.glow(self, Vector2(6, ROW_Y), 60.0, Color(1.0, 0.75, 0.3, 0.22 + 0.04 * sin(t * 1.7)), true)
	Pix.text_o(self, Vector2(3, ROW_Y + 4), "SUN", 10, C_DIM)
	_draw_comet()
	# hover preview vs the picked world
	var hov: String = hot.substr(5) if hot.begins_with("dest:") else ""
	for i: int in BODIES.size():
		var id: String = BODIES[i]["id"]
		var tx: Texture2D = _tx("sys_" + id)
		var c: Vector2 = _body_pos(i)
		var hw: float = floorf(tx.get_width() / 2.0)
		var hh: float = floorf(tx.get_height() / 2.0)
		var is_sel: bool = id == sel
		if is_sel:
			Fx.glow(self, c, maxf(hw, 10.0) + 12.0, Color(1.0, 0.85, 0.45, 0.16 + 0.05 * sin(t * 3.0)), true)
		draw_texture(tx, (c - Vector2(hw, hh)).floor())
		# label: below, the Moon's above (it sits beside the Earth)
		var ly: float = c.y - hh - 6.0 if id == "moon" else c.y + hh + 10.0
		var nm: String = "EARTH" if id == "earth" else String(Data.DEST[id]["name"])
		var col: Color = C_HI if (is_sel or id == hov) else (C_DIM if id == "earth" else C_TXT)
		Pix.text_oc(self, c.x, ly, nm, 10, col)
		if id == "earth":
			Pix.text_oc(self, c.x, ly + 11.0, "HOME", 10, C_DIM)
			continue
		var box: Rect2 = Rect2(c.x - maxf(hw + 3.0, 15.0), c.y - maxf(hh + 3.0, 13.0), 2.0 * maxf(hw + 3.0, 15.0), 2.0 * maxf(hh + 3.0, 13.0))
		_hit(box.merge(Rect2(c.x - 22.0, ly - 10.0, 44.0, 13.0)), "dest:" + id)
		if is_sel:
			var grow: float = maxf(0.0, 4.0 - sel_t * 24.0) + roundf(sin(t * 4.0) * 0.6 + 0.4)
			_brackets(Rect2(c - Vector2(hw, hh), Vector2(hw, hh) * 2.0 + Vector2.ONE).grow(3.0 + grow), C_HI)
		elif id == hov:
			_brackets(Rect2(c - Vector2(hw, hh), Vector2(hw, hh) * 2.0 + Vector2.ONE).grow(3.0), C_TXT)
	Pix.text(self, Vector2(634 - Pix.text_w("SIZES AND DISTANCES NOT TO SCALE", 10), 152), "SIZES AND DISTANCES NOT TO SCALE", 10, C_DIM)

## A comet now and then. Its tail points away from the Sun, as real ones do.
func _draw_comet() -> void:
	var period: float = 17.0
	var n: int = int((t + 6.0) / period)
	var u: float = fposmod(t + 6.0, period) / 5.0
	if u >= 1.0:
		return
	var y0: float = 78.0 + fposmod(float(n) * 23.0, 26.0)
	var head: Vector2 = Vector2(660.0 - u * 520.0, y0 + u * 18.0)
	var away: Vector2 = (head - SUN_C).normalized()
	for j: int in 16:
		var p: Vector2 = head + away * (j * 1.3)
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.75, 0.9, 1.0, 0.6 * (1.0 - j / 16.0)))
	draw_rect(Rect2(head.floor() - Vector2.ONE, Vector2(2, 2)), Color(0.92, 0.97, 1.0))

## The job of a task: "drill" (samples), "photo" or "crew". Read defensively: the core may not set it yet.
func _tjob(tk: Dictionary) -> String:
	return String(tk.get("job", "drill"))

func _job_word(job: String) -> String:
	return {"photo": "PHOTOS", "crew": "CREW"}.get(job, "SAMPLES")

## What reaches Earth, in plain words.
func _goes_to_earth(tk: Dictionary) -> String:
	var job: String = _tjob(tk)
	if job == "crew":
		return "data + the crew"
	if job == "drill" and bool(tk.get("returns", false)):
		return "data + sample capsule"
	return "data by radio"

## 12x12 job icon on whole pixels: a sample jar, a camera (drawn), a helmet.
func _job_icon(pos: Vector2, job: String, c: Color) -> void:
	var p: Vector2 = pos.floor()
	if job == "photo":
		draw_rect(Rect2(p.x + 1, p.y + 3, 10, 7), c)
		draw_rect(Rect2(p.x + 3, p.y + 1, 3, 2), c)
		draw_rect(Rect2(p.x + 4, p.y + 4, 4, 4), Color(0.05, 0.05, 0.1))
		draw_rect(Rect2(p.x + 5, p.y + 5, 2, 2), C_TXT)
	else:
		Pix.icon(self, "icon_helmet" if job == "crew" else "icon_sample", p)

func _draw_job(x: float, y: float, tk: Dictionary, c: Color) -> void:
	var job: String = _tjob(tk)
	_job_icon(Vector2(x, y - 9), job, c)
	Pix.text(self, Vector2(x + 16, y), _job_word(job), 10, c)

## The mission card of the picked world.
func _draw_card() -> void:
	var id: String = sel
	var d: Dictionary = Data.DEST[id]
	var r: Rect2 = CARD
	_nine(r, "card", FRAME_M)
	# a notch on the top edge pointing at the world
	for b: Dictionary in BODIES:
		if b["id"] == id:
			var px: float = float(b["x"])
			for k: int in 4:
				draw_rect(Rect2(px - k, r.position.y - 4 + k, 2 * k + 1, 1), C_HI)
	var x0: float = r.position.x + 14.0
	var y0: float = r.position.y
	# --- left: name, best, what matters here, the vehicles, one fact
	var nm: String = String(d["name"])
	Pix.title(self, Vector2(x0, y0 + 30), nm, C_HI, 2)
	var best: String = "BEST %d%%" % int(Game.best[id]) if Game.best.has(id) else "NOT FLOWN YET"
	Pix.text(self, Vector2(x0 + Pix.title_w(nm, 2) + 12.0, y0 + 28), best, 10, C_DIM)
	Pix.text(self, Vector2(x0, y0 + 48), "CRITICAL HERE", 10, C_DIM)
	_critical_row(Vector2(x0, y0 + 62), id)
	var ring: bool = d["kind"] == "ring"
	var v1: Texture2D = _tx("veh_orbiter" if ring else "veh_lander")
	var v2: Texture2D = _tx("veh_drone" if ring else "veh_rover")
	var vy: float = y0 + 112.0
	draw_texture(v1, Vector2(x0, vy - v1.get_height()))
	draw_texture(v2, Vector2(x0 + 44.0, vy - v2.get_height() - (8.0 + roundf(sin(t * 2.0)) if ring else 0.0)))
	Pix.text(self, Vector2(x0 + 96, y0 + 98), "ORBIT, THEN FLY A DRONE" if ring else ("LAND, THEN WALK AS AN ASTRONAUT" if String(Game.task().get("job", "drill")) == "crew" else "LAND, THEN DRIVE A ROVER"), 10, C_TXT)
	var facts: Array = d["facts"]
	var fact: String = String(facts[clampi(int(FACT_IDX.get(id, 0)), 0, facts.size() - 1)])
	_img("ic_fact", Vector2(x0 - 1, y0 + 120))
	_para(Vector2(x0 + 17, y0 + 130), fact, 270.0, C_TXT, 2)
	# --- right: the three tasks, easiest first; the task carries the difficulty
	var x1: float = r.position.x + 318.0
	for i: int in tasks.size():
		var tk: Dictionary = tasks[i]
		var on: bool = i == task_i
		var tr: Rect2 = Rect2(x1, y0 + 10 + i * 26, 288, 24)
		_hit(tr, "task:%d" % i)
		var lit: bool = on or hot == "task:%d" % i
		_nine(tr, "tile", TILE_M, Color(1.25, 1.2, 1.0) if on else (Color.WHITE if lit else Color(0.75, 0.75, 0.85)))
		if on:
			_brackets(tr.grow(1.0), C_HI)
		Pix.text(self, tr.position + Vector2(8, 16), String(tk["name"]), 10, C_HI if on else C_TXT)
		_draw_job(tr.position.x + 150.0, tr.position.y + 16, tk, C_DIM)
		var lv: String = String(tk["level"])
		Pix.text(self, Vector2(tr.end.x - 8 - Pix.text_w(lv, 10), tr.position.y + 16), lv, 10, LEVEL_COL[clampi(int(tk["diff"]), 0, 2)])
	if not tasks.is_empty():
		_para(Vector2(x1 + 2, y0 + 100), String(tasks[task_i]["text"]), 286.0, C_TXT, 2)
	_button(Rect2(r.end.x - 148, y0 + 134, 136, 24), "play", "PLAY  " + nm, "btn_green", "ic_play")

func _draw_bar() -> void:
	_nine(Rect2(10, 330, 620, 28), "plate", FRAME_M)
	Pix.text(self, Vector2(22, 348), "PLAYERS", 10, C_DIM)
	for n: int in 4:
		var r: Rect2 = Rect2(68 + n * 20, 332, 20, 24)
		_hit(r, "pl:%d" % (n + 1))
		var lift: int = 1 if hot == "pl:%d" % (n + 1) else 0
		_img("ic_helmet" if n + 1 <= Game.players else "ic_helmet_off", Vector2(r.position.x + 3, r.position.y + 4 - lift))
		if n + 1 == Game.players:
			draw_rect(Rect2(r.position.x + 3, r.position.y + 20, 14, 2), UI.CYAN)
	var shown: int = roundi(shown_funds)
	Pix.text(self, Vector2(166, 348), "CREDITS", 10, C_DIM)
	_img("ic_coin", Vector2(212, 336))
	Pix.title(self, Vector2(230, 349), str(shown), C_HI, 1)
	_button(Rect2(358, 332, 88, 24), "tech", "TECH LAB", "btn_blue", "ic_flask")
	_button(Rect2(450, 332, 92, 24), "help", "HOW TO PLAY", "btn_grey", "ic_help")
	_button(Rect2(546, 332, 78, 24), "src", "NASA DATA", "btn_grey", "ic_fact")

# ---------------------------------------------------------------- overlays

func _panel_rect() -> Rect2:
	var e: float = clampf(ov_t / 0.18, 0.0, 1.0)
	e = 1.0 - pow(1.0 - e, 3.0)
	return Rect2(40, 14 + roundi((1.0 - e) * 14.0), 560, 326)

func _draw_overlay() -> void:
	var e: float = clampf(ov_t / 0.18, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.07, 0.8 * e))
	_hit(Rect2(0, 0, 640, 360), "o:dim")
	var pr: Rect2 = _panel_rect()
	_hit(pr, "o:panel")
	_nine(pr, "card", FRAME_M)
	var title: String = {"tech": "TECH LAB", "help": "HOW TO PLAY", "src": "NASA DATA & CREDITS", "brief": "MISSION BRIEFING"}[overlay]
	Pix.title(self, pr.position + Vector2(16, 28), title, C_HI, 2)
	_button(Rect2(pr.end.x - 38, pr.position.y + 8, 28, 24), "o:close", "", "btn_red", "ic_close")
	draw_rect(Rect2(pr.position.x + 10, pr.position.y + 38, pr.size.x - 20, 1), Color("2a3558"))
	match overlay:
		"tech":
			_draw_tech(pr)
		"help":
			_draw_help(pr)
		"src":
			_draw_sources(pr)
		"brief":
			_draw_brief(pr)

## What will end the mission here, in plain words, from the destination's hazards, air and kind (at most 3).
func _enders(id: String) -> Array[String]:
	var d: Dictionary = Data.DEST[id]
	var hz: Array = d["hazards"]
	var out: Array[String] = []
	if hz.has("heat") and float(d["sun_wm2"]) > Data.SHADE_ABOVE_WM2:
		out.append("Overheating without a sunshade")
	if hz.has("pressure"):
		out.append("Being crushed without a pressure hull")
	if d["air"] != "none":
		out.append("Burning up without a heat shield")
	if d.has("surface_minutes"):
		out.append("The heat ends any lander after %d minutes" % roundi(float(d["surface_minutes"])))
	if hz.has("radiation"):
		out.append("Radiation breaking unshielded parts")
	if hz.has("dark"):
		out.append("Solar power too weak this far from the Sun")
	if hz.has("night"):
		out.append("A battery too small for the %s-hour night" % str(d["night_hours"]))
	out.append("Losing the drone on a ring rock" if d["kind"] == "ring" else "A crash landing")
	out.append("Running out of fuel")
	out.append("A ship too heavy for its rocket")
	return out.slice(0, 3)

func _draw_brief(pr: Rect2) -> void:
	var d: Dictionary = Data.DEST[sel]
	var x: float = pr.position.x + 16.0
	var y: float = pr.position.y
	Pix.text(self, Vector2(x, y + 56), "DESTINATION", 10, C_DIM)
	Pix.title(self, Vector2(x + 72, y + 57), String(d["name"]), C_TXT, 1)
	Pix.text(self, Vector2(x + 180, y + 56), "DIFFICULTY", 10, C_DIM)
	Pix.title(self, Vector2(x + 246, y + 57), String(tasks[task_i]["level"]), C_TXT, 1)
	# the world itself, top right
	var pt: Texture2D = _planet("planet_%s_%d" % [sel, 22 if sel == "saturn" else 36])
	draw_texture(pt, Vector2(pr.end.x - 24 - pt.get_width(), y + 44 + floorf(sin(t) * 1.5)))
	# three things to know
	var rows: Array = [["YOUR GOAL", "icon_star"], ["WHAT IS CRITICAL HERE", "icon_warn"], ["WHAT WILL END THE MISSION", "icon_bad"]]
	var ry: float = y + 84.0
	for i: int in 3:
		Pix.icon(self, String(rows[i][1]), Vector2(x, ry - 10))
		Pix.text(self, Vector2(x + 16, ry), String(rows[i][0]), 10, C_HI)
		match i:
			0:
				var tk: Dictionary = tasks[task_i]
				Pix.text(self, Vector2(x + 16, ry + 14), String(tk["name"]), 10, C_TXT)
				var lv: String = String(tk["level"])
				Pix.text(self, Vector2(x + 24 + Pix.text_w(String(tk["name"]), 10), ry + 14), lv, 10, LEVEL_COL[clampi(int(tk["diff"]), 0, 2)])
				_draw_job(x + 24.0 + Pix.text_w(String(tk["name"]), 10) + Pix.text_w(lv, 10) + 12.0, ry + 14, tk, C_DIM)
				var ly0: float = ry + 26.0 + 12.0 * _para(Vector2(x + 16, ry + 26), String(tk["text"]), 380.0, C_TXT, 2)
				Pix.text(self, Vector2(x + 16, ly0 + 2), "GOES TO EARTH:", 10, C_DIM)
				Pix.text(self, Vector2(x + 16 + Pix.text_w("GOES TO EARTH: ", 10), ly0 + 2), _goes_to_earth(tk), 10, C_HI)
				ry = ly0 + 18.0
			1:
				_critical_row(Vector2(x + 16, ry + 15), sel)
				var ny: float = ry + 29.0
				for line: String in (d["needs"] as Array).slice(0, 3):
					_img("ic_dash", Vector2(x + 14, ny - 10))
					Pix.text(self, Vector2(x + 30, ny), line, 10, C_TXT)
					ny += 12.0
				ry = ny + 8.0
			2:
				var ly: float = ry + 14.0
				for line: String in _enders(sel):
					_img("ic_dash", Vector2(x + 14, ly - 10))
					Pix.text(self, Vector2(x + 30, ly), line, 10, C_TXT)
					ly += 12.0
	# the three steps of every mission, the first lit
	var steps: Array[String] = ["BUILD THE SHIP", "FLY IT", "READ THE REPORT"]
	var sx: float = x
	var sy: float = pr.end.y - 66.0
	for i: int in 3:
		var w: float = 160.0
		var tr: Rect2 = Rect2(sx + i * (w + 8), sy, w, 26)
		_nine(tr, "tile", TILE_M, Color.WHITE if i == 0 else Color(0.7, 0.7, 0.8))
		Pix.title(self, tr.position + Vector2(8, 18), str(i + 1), C_HI if i == 0 else C_DIM, 1)
		Pix.text(self, tr.position + Vector2(24, 17), steps[i], 10, C_TXT if i == 0 else C_DIM)
	_button(Rect2(x, pr.end.y - 34, 80, 24), "o:close", "BACK", "btn_grey")
	Pix.keycap(self, Vector2(x + 88, pr.end.y - 28), "ESC")
	var bw: float = 170.0
	_button(Rect2(pr.end.x - 16 - bw, pr.end.y - 34, bw, 24), "o:start", "START BUILDING", "btn_green", "ic_play")
	Pix.keycap(self, Vector2(pr.end.x - 16 - bw - 52, pr.end.y - 28), "ENTER")

func _tile_rect(id: String) -> Rect2:
	var pr: Rect2 = _panel_rect()
	var idx: int = Data.TECH.keys().find(id)
	return Rect2(pr.position.x + 8 + (idx % 3) * 184, pr.position.y + 62 + floori(idx / 3.0) * 114, 176, 110)

func _draw_tech(pr: Rect2) -> void:
	_img("ic_coin", Vector2(pr.end.x - 150, pr.position.y + 12))
	Pix.title(self, Vector2(pr.end.x - 130, pr.position.y + 28), str(roundi(shown_funds)), C_HI, 2)
	Pix.text(self, pr.position + Vector2(16, 54), "Earn credits by finishing mission goals. Spend them on new parts for your ships.", 10, C_DIM)
	for id: String in Data.TECH:
		var td: Dictionary = Data.TECH[id]
		var r: Rect2 = _tile_rect(id)
		var owned: bool = Game.tech.has(id)
		var cost: int = int(td["cost"])
		var can: bool = Game.funds >= cost
		if shake.has(id) and t - float(shake[id]) < 0.3:
			r.position.x += floorf(sin((t - float(shake[id])) * 60.0) * 2.0)
		var flash: float = clampf(1.0 - (t - float(bought.get(id, -9.0))) / 0.5, 0.0, 1.0)
		_nine(r, "tile_owned" if owned else "tile", TILE_M, Color(1, 1, 1).lerp(Color(1.6, 1.5, 1.0), flash))
		_img("tech_" + id, r.position + Vector2(8, 8), Color.WHITE if (owned or can) else Color(0.72, 0.72, 0.84))
		Pix.text(self, r.position + Vector2(40, 18), String(td["name"]), 10, C_TXT)
		_para(r.position + Vector2(40, 32), String(td["desc"]), 128.0, C_DIM, 4)
		if owned:
			_img("ic_tick", Vector2(r.position.x + 56, r.end.y - 28))
			Pix.text(self, Vector2(r.position.x + 76, r.end.y - 17), "OWNED", 10, C_HI)
		else:
			_button(Rect2(r.position.x + 8, r.end.y - 31, r.size.x - 16, 24), "o:buy:" + id, "BUY  %d" % cost, "btn_green" if can else "btn_grey", "ic_coin", can)
	var armed: bool = t - reset_armed < 3.0
	_button(Rect2(pr.position.x + 8, pr.end.y - 34, 150, 24), "o:reset", "SURE? CLICK AGAIN" if armed else "RESET SAVE", "btn_red" if armed else "btn_grey", "")
	Pix.text(self, Vector2(pr.position.x + 172, pr.end.y - 17), "New parts appear in the builder after you buy them.", 10, C_DIM)

func _draw_help(pr: Rect2) -> void:
	var titles: Array = ["PICK A PLANET AND A TASK", "BUILD UNTIL MISSION CONTROL SAYS GO", "FLY IT", "READ THE REPORT"]
	var bodies: Array = [
		"Each world needs a different ship. Each task says how hard it is.",
		"Follow the lit step. Red lamps mean something is still missing.",
		"Fly the launch, make the calls when things go wrong, then land or fly the drone.",
		"The full report and the build report show what to change next time.",
	]
	for n: int in 4:
		var r: Rect2 = Rect2(pr.position.x + 8 + n * 137, pr.position.y + 50, 130, 216)
		_nine(r, "tile", TILE_M)
		var pw: Rect2 = Rect2(r.position.x + 6, r.position.y + 6, 118, 84)
		draw_rect(pw, Color("090c18"))
		draw_rect(Rect2(pw.position.x, pw.end.y - 1, pw.size.x, 1), Color("2a3558"))
		_help_picture(n, pw)
		var ny: float = r.position.y + 100.0
		var lines: int = _para(Vector2(r.position.x + 8, ny + 8), String(titles[n]), 116.0, C_HI, 4)
		_para(Vector2(r.position.x + 8, ny + 14 + lines * 12), String(bodies[n]), 116.0, C_TXT, 7)
		draw_rect(Rect2(pw.position.x + 3, pw.position.y + 3, 18, 20), Color(0.02, 0.03, 0.07, 0.7))
		Pix.title(self, pw.position + Vector2(6, 21), str(n + 1), C_HI, 1)
	Pix.text(self, pr.position + Vector2(16, 294), "Up to 4 players share the roles: planner, engineer, scientist, comms.", 10, C_DIM)
	Pix.text(self, pr.position + Vector2(16, 308), "Each screen shows one direction at a time: do it and the next one appears.", 10, C_DIM)

func _help_picture(n: int, pw: Rect2) -> void:
	var c: Vector2 = pw.get_center()
	match n:
		0:
			var names: Array[String] = ["sys_moon", "sys_mars", "sys_jupiter"]
			var pick: int = int(t / 1.2) % 3
			var xs: Array[float] = [pw.position.x + 30, pw.position.x + 48, pw.position.x + 88]
			for j: int in 3:
				var tx: Texture2D = _tx(names[j])
				var p: Vector2 = Vector2(xs[j], c.y - 8.0)
				draw_texture(tx, (p - tx.get_size() / 2.0).floor())
				if j == pick:
					_brackets(Rect2(p - tx.get_size() / 2.0, tx.get_size()).grow(2.0), C_HI)
			for j: int in 3:
				_img(["pip_g", "pip_y", "pip_r"][j] if j <= pick else "pip_off", Vector2(c.x - 15 + j * 10, pw.end.y - 16))
		1:
			var phase: int = int(t / 0.7) % 7
			for j: int in 5:
				var lamp: String = "lamp_go" if j < phase else ("lamp_warn" if j == phase else "lamp_nogo")
				_img(lamp, Vector2(pw.position.x + 10 + j * 20, pw.position.y + 8))
			_img("veh_lander", Vector2(c.x - 20, pw.position.y + 24))
			var go: bool = phase >= 5
			Pix.text_c(self, c.x, pw.end.y - 6.0, "GO" if go else "NO-GO", 10, C_HI if go else C_DIM)
		2:
			var ph: float = fposmod(t, 2.4) / 2.4
			var ly: float = pw.position.y + 6.0 + ph * 26.0
			var gt: Texture2D = _tx("ground_moon")
			_blit(gt, Vector2(pw.position.x, pw.end.y - 13), pw)
			Fx.flame(self, Vector2(c.x - 1, ly + 34), Vector2.DOWN, 12.0, 5.0, t)
			_img("veh_lander", Vector2(c.x - 20, ly))
		3:
			var m: int = int(t / 1.1) % 3
			_img(["medal_bronze", "medal_silver", "medal_gold"][m], Vector2(c.x - 9, pw.position.y + 8))
			_img("ic_coin", Vector2(c.x - 26, pw.end.y - 24))
			Pix.text(self, Vector2(c.x - 8, pw.end.y - 12), "+%d" % (60 + 20 * m), 10, C_HI)
			Fx.sparkle(self, Vector2(c.x + 18, pw.position.y + 14), fposmod(t, 1.1) / 1.1, Color("fff4b8"), 0)

func _draw_sources(pr: Rect2) -> void:
	var y: float = pr.position.y + 54.0
	Pix.text(self, Vector2(pr.position.x + 16, y), "DATA SOURCES", 10, C_HI)
	y += 8.0
	for s: String in Data.SOURCES:
		_img("ic_dash", Vector2(pr.position.x + 14, y - 1))
		var n: int = _para(Vector2(pr.position.x + 30, y + 9), s, 510.0, C_TXT, 3)
		y += 4.0 + n * 12.0
	y += 8.0
	Pix.text(self, Vector2(pr.position.x + 16, y + 6), "AI USE (SPACE APPS RULES)", 10, C_HI)
	_para(Vector2(pr.position.x + 16, y + 20), "Game idea and design: Team Shay Rafe3 (NASA Space Apps Challenge 2026). Code, code-drawn pixel art and code-made sound were written with help from Claude (AI) and checked by the team. No NASA logos are used.", 526.0, C_TXT, 4)

# ---------------------------------------------------------------- debug (screenshots)

func debug_tech() -> void:
	_open("tech")
	ov_t = 1.0

func debug_help() -> void:
	_open("help")
	ov_t = 1.0

func debug_sources() -> void:
	_open("src")
	ov_t = 1.0

func debug_brief() -> void:
	_open("brief")
	ov_t = 1.0

func debug_moon() -> void: _pick("moon")
func debug_mercury() -> void: _pick("mercury")
func debug_venus() -> void: _pick("venus")
func debug_mars() -> void: _pick("mars")
func debug_jupiter() -> void: _pick("jupiter")
func debug_saturn() -> void: _pick("saturn")
func debug_uranus() -> void: _pick("uranus")
func debug_neptune() -> void: _pick("neptune")

func debug_task0() -> void: _pick_task(0)
func debug_task1() -> void: _pick_task(1)
func debug_task2() -> void: _pick_task(2)

## Hover light on Saturn while another world stays picked.
func debug_hover_saturn() -> void:
	force_hot = "dest:saturn"

func debug_medals() -> void:
	Game.best = {"moon": 100, "mars": 60, "saturn": 20}

## Presses START BUILDING for the picked world (the screenshot then shows the builder).
func debug_go() -> void:
	_start()

func debug_owned() -> void:
	Game.tech["solar2"] = true
	Game.tech["ka"] = true
