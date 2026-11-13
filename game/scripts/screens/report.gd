extends Control
## Mission report: a verdict with a mission patch, goals that tick in, team scores, what went wrong and why
## (cause, what to change, the real NASA story), credits that fly into the total.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const MenuScript = preload("res://scripts/screens/menu.gd")
const BG_TEX: Texture2D = preload("res://art/bg_space.png")

const FRAME_M: Array = [6, 6, 6, 8]
const BTN_M: Array = [4, 5, 4, 6]

## [text to look for in the log, what to change, the real story]
const TIPS: Array = [
	["TOO HEAVY", "ENGINEER + PLANNER: remove mass or pick a bigger rocket. A slower path can also save fuel mass.",
		"Every extra kilogram needs fuel, and that fuel needs more fuel. Falcon 9 can send about 4,020 kg to Mars."],
	["OUT OF POWER", "ENGINEER: far from the Sun, solar panels fail. Use an MMRTG nuclear generator, like Cassini and Perseverance.",
		"Sunlight at Saturn is 14.8 W/m2, about 1% of Earth's. Cassini ran on 3 nuclear RTGs."],
	["NOT ENOUGH FUEL", "ENGINEER: add propellant until the FUEL bar is green. Fuel grows fast with mass (rocket equation).",
		"Cassini took gravity assists from Venus, Earth and Jupiter to reach Saturn with the fuel it could carry."],
	["BURNED UP", "SCIENTIST: Mars has air. A heat shield is a must.",
		"Perseverance dived into the thin Martian air behind a heat shield, then used a parachute and a sky crane."],
	["NO PARACHUTE", "SCIENTIST: a parachute slows you from 420 to 90 m/s for free.",
		"Perseverance opened a parachute before its sky crane lowered it on cables."],
	["CRASH", "Pilot: fire the engine earlier and touch down slowly. Landing legs or airbags raise the speed limit.",
		"Lander legs are built to crush and soak up the touchdown, but only up to a speed limit."],
	["STRANDED", "ENGINEER: bring more solar power or batteries, and keep 30% battery for the trip home.",
		"The Apollo ascent engine had to start on the first try: there was no second chance to leave the Moon."],
	["BATTERY EMPTY", "ENGINEER: Mars nights last 12 hours. Add batteries or an MMRTG.",
		"A Mars night lasts about 12 hours and is very cold. Perseverance has a nuclear MMRTG, so it works day and night."],
	["SOLAR STORM", "ENGINEER: radiation shielding protects electronics from solar storms.",
		"NASA's DONKI database logs real solar storms. Strong ones can damage spacecraft electronics."],
	["Storage full", "COMMS: add a data recorder.",
		"Science only counts once it is sent home, so real missions plan memory and radio time together."],
	["Sent", "COMMS: a bigger antenna sends data faster. Radio speed falls with distance squared.",
		"Radio delay to Mars is 4 to 24 minutes, and to Saturn about 80 minutes each way."],
	["No ascent stage", "SCIENTIST: add the ascent stage to bring samples home.",
		"Apollo 11 brought home 21.5 kg of Moon rock because its ascent stage lifted off the Moon."],
	["drone was lost", "Pilot: save fuel to fly the drone back up to the orbiter.",
		"In its 2017 Grand Finale Cassini dived 22 times between Saturn and its rings."],
	["No drone", "SCIENTIST: Saturn has no ground. Add the sampling drone.",
		"Saturn is a giant ball of gas with no surface, so the rings are studied from orbit or by flying into them."],
	["Samples collected", "SCIENTIST: a rover and a drill reach more rocks. Watch the battery.",
		"Apollo 11 brought home 21.5 kg of Moon rock. Perseverance is caching rock samples on Mars."],
	["Ring samples", "Pilot: fly through the ring band and grab the ice grains.",
		"Cassini's Grand Finale dived 22 times between Saturn and its rings."],
]

const ROLE_ICON: Dictionary = {"planner": "clipboard", "engineer": "wrench", "science": "science", "comms": "comms"}
const ROLE_NAME: Dictionary = {"planner": "Planner", "engineer": "Engineer", "science": "Scientist", "comms": "Comms"}

## A child that clips its drawing: the scrolling feed.
class Feed extends Control:
	var host: Control = null

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		host.call("_draw_feed", self)

# the run being shown
var r: Dictionary = {}
var dest_id: String = "moon"
var score: int = 0
var level: int = 0          # 0 fail, 1 partial, 2 success
var metal: String = "fail"
var head: String = ""
var goals: Array = []       # [name, ok]
var roles: Dictionary = {}
var reward: int = 0
var funds_after: int = 0
var items: Array = []       # feed rows
var feed_h: int = 0
var stats: Array = []       # [icon, text]
var real_text: String = ""

var t: float = 0.0
var tex_cache: Dictionary = {}
var hits: Array = []
var hot: String = ""
var down: String = ""
var fired: Dictionary = {}
var shake_t: float = -9.0
var sparks: Array = []
var coins: Array = []       # {t0, from, to, val}
var coins_in: int = 0
var shown_total: float = 0.0
var scroll: float = 0.0
var feed: Feed = null
var boom_t: float = -9.0
var goals_start: float = 1.0
var cur_sh: Vector2 = Vector2.ZERO

func _ready() -> void:
	for n: String in ["ic_tick", "ic_cross", "ic_coin", "ic_flask", "ic_wrench", "ic_play", "ic_warn", "card",
			"veh_lander", "veh_orbiter", "ground_moon"]:
		_tx(n)
	for n: String in ["btn_green", "btn_red", "btn_blue", "btn_grey", "btn_yellow"]:
		for s: String in ["n", "h", "p"]:
			_tx(n + "_" + s)
	for d: String in ["moon", "mars", "saturn"]:
		for m: String in ["gold", "silver", "bronze", "fail"]:
			_tx("patch_%s_%s" % [d, m])
	feed = Feed.new()
	feed.host = self
	add_child(feed)
	feed.position = Vector2(196, 138)
	feed.size = Vector2(284, 176)
	_load(Game.run)

func _tx(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/menu/%s.png" % name) as Texture2D
	return tex_cache[name]

## Reads a finished run (the real Game.run, or a made-up one from a debug_ method) and plans the show.
func _load(run: Dictionary) -> void:
	r = run
	dest_id = Game.dest_id
	var d: Dictionary = Data.DEST[dest_id]
	score = int(r.get("score", 0))
	level = 2 if score >= 100 else (1 if score >= 50 else 0)
	head = ["MISSION FAILED", "PARTIAL SUCCESS", "MISSION SUCCESS"][level]
	metal = "fail" if level == 0 else ("gold" if score >= 100 else ("silver" if score >= 75 else "bronze"))
	reward = int(r.get("reward", 0))
	funds_after = Game.funds
	shown_total = float(funds_after - reward)
	roles = r.get("roles", {})
	goals.clear()
	var obj: Dictionary = r.get("obj", {})
	for o: String in obj:
		var nm: String = String(Data.OBJ_NAMES[o])
		if o == "samples":
			nm += " (%d/%d)" % [int(r.get("samples", 0)), int(d["samples_goal"])]
		goals.append([nm, bool(obj[o])])
	# the feed: what went wrong, what to change, the real story, then the whole log
	items.clear()
	var tips: Array = []
	var facts: Array = []
	var wrong: Array = []
	var log: Array = r.get("log", [])
	for e: Dictionary in log:
		if bool(e["ok"]):
			continue
		var txt: String = String(e["text"])
		wrong.append(txt)
		for tp: Array in TIPS:
			if txt.contains(String(tp[0])):
				var tip: String = String(tp[1])
				var fact: String = String(tp[2])
				if String(tp[0]) == "Samples collected":
					fact = {"moon": "Apollo 11 brought home 21.5 kg of Moon rock.", "mars": "Perseverance is caching rock samples on Mars for a future trip home.",
						"saturn": "Cassini's Grand Finale dived 22 times between Saturn and its rings."}[dest_id]
					if dest_id == "saturn":
						tip = "Pilot: fly through the ring band more often and grab ice grains before the fuel runs out."
				if not tips.has(tip):
					tips.append(tip)
				if not facts.has(fact):
					facts.append(fact)
				break
	var missed: PackedStringArray = PackedStringArray()
	for gl: Array in goals:
		if not bool(gl[1]):
			missed.append(String(gl[0]))
	if wrong.is_empty() and missed.is_empty():
		items.append({"k": "head", "text": "WHAT WENT RIGHT", "col": UI.GREEN})
		items.append({"k": "text", "text": "Every goal was met. The flight log below shows each step.", "col": UI.TEXT})
	else:
		items.append({"k": "head", "text": "WHAT WENT WRONG", "col": UI.RED})
		if wrong.is_empty():  # a goal can be missed without a failure line in the log (the mission ended first)
			items.append({"k": "text", "text": "Goals not reached: %s." % ", ".join(missed), "col": Color("ffd0d0")})
		for w: String in wrong:
			items.append({"k": "text", "text": w, "col": Color("ffd0d0")})
		if not tips.is_empty():
			items.append({"k": "head", "text": "WHAT TO CHANGE NEXT TIME", "col": UI.YELLOW})
			for tp2: String in tips.slice(0, 2):
				items.append({"k": "text", "text": tp2, "col": UI.TEXT})
		if not facts.is_empty():
			items.append({"k": "head", "text": "THE REAL STORY (NASA)", "col": UI.CYAN})
			for f2: String in facts.slice(0, 2):
				items.append({"k": "text", "text": f2, "col": Color("bfeaff")})
	items.append({"k": "head", "text": "FLIGHT LOG", "col": UI.DIM})
	for e2: Dictionary in log:
		items.append({"k": "log", "text": String(e2["text"]), "ok": bool(e2["ok"])})
	feed_h = 0
	for it: Dictionary in items:
		var is_log: bool = it["k"] == "log"
		var lines: Array = _wrap(String(it["text"]), 258.0 if is_log else 276.0)
		it["lines"] = lines
		var h: int = 17
		if is_log:
			h = maxi(14, lines.size() * 12) + 4
		elif it["k"] == "text":
			h = lines.size() * 12 + 6
		it["h"] = h
		feed_h += h
	scroll = 0.0
	real_text = String(d["real"])
	var c: Dictionary = r.get("calc", {})
	stats.clear()
	if not c.is_empty():
		stats = [["mass", "%s kg" % Game.fmt(c["mass"])], ["money", "$%dM" % roundi(c["cost"])],
			["power", "%d W at %s" % [roundi(c["gen"]), Game.place().capitalize()]], ["comms", "%s Mbps" % Game.fmt(c["rate"])]]
	t = 0.0
	fired.clear()
	sparks.clear()
	coins.clear()
	coins_in = 0
	boom_t = -9.0
	shake_t = -9.0

# ---------------------------------------------------------------- timeline

func _tl(name: String) -> float:
	## Seconds at which a step of the show starts.
	var n: int = goals.size()
	match name:
		"patch":
			return 0.3
		"verdict":
			return 0.75
		"goals", "score":
			return goals_start
		"roles":
			return goals_start + 0.45 * n + 0.1
		"coins":
			return goals_start + 0.45 * n + 0.5
		"panels":
			return 0.7
	return 0.0

func _fire(key: String, at: float) -> bool:
	if t >= at and not fired.has(key):
		fired[key] = true
		return true
	return false

func _process(delta: float) -> void:
	t += delta
	if _fire("land", _tl("patch") + 0.3):
		shake_t = t
		Audio.play("land", -3.0)
		Audio.play("sting_win" if level >= 1 else "sting_fail", -2.0)
		for k: int in 5:
			sparks.append({"pos": Vector2(50.0 + cos(k * 1.26) * 38.0, 54.0 + sin(k * 1.26) * 38.0), "age": 0.0, "dur": 0.5,
				"tint": Color("ffd75e") if level >= 1 else Color("ff8a6a")})
		if level == 0:
			boom_t = t
			Audio.play("explosion", -5.0)
	if _fire("verdict", _tl("verdict")):
		Audio.play("ui_open", -4.0)
	for k: int in goals.size():
		if _fire("g%d" % k, _tl("goals") + 0.45 * k):
			var ok: bool = bool(goals[k][1])
			Audio.play("station_go" if ok else "station_nogo", -4.0)
			if ok:
				sparks.append({"pos": Vector2(23.0, 145.0 + k * 15.0), "age": 0.0, "dur": 0.45, "tint": Color("6dff8a")})
	if _fire("roles", _tl("roles")):
		Audio.play("blip", -4.0)
		if level == 2:
			Audio.play("all_go", -3.0)
	if _fire("coins", _tl("coins")) and reward > 0:
		var n: int = clampi(reward / 12, 3, 14)
		for k: int in n:
			coins.append({"t0": t + 0.07 * k, "from": Vector2(232, 346), "to": Vector2(307, 339), "val": float(reward) / n})
	for i: int in range(coins.size() - 1, -1, -1):
		var cn: Dictionary = coins[i]
		if t >= float(cn["t0"]) + 0.55:
			shown_total = minf(float(funds_after), shown_total + float(cn["val"]))
			coins_in += 1
			Audio.play("pickup", -10.0, 1.0 + 0.04 * coins_in)
			sparks.append({"pos": Vector2(307, 339), "age": 0.0, "dur": 0.35, "tint": Color("ffd75e")})
			coins.remove_at(i)
	if t > _tl("coins") + 3.0:
		shown_total = float(funds_after)
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["dur"]):
			sparks.remove_at(i)
	var h: String = ""
	var mp: Vector2 = get_local_mouse_position()
	for i: int in range(hits.size() - 1, -1, -1):
		var rr: Rect2 = hits[i][0]
		if rr.has_point(mp):
			h = hits[i][1]
			break
	if h != hot:
		hot = h
		if h != "":
			Audio.play("ui_hover", -9.0)
	feed.visible = _panel_on(0.12)
	feed.position.y = 138.0 + _panel_dy(0.12)
	feed.queue_redraw()
	queue_redraw()

func _skip() -> void:
	## Jump to the end of the show: everything shown, coins counted.
	t = maxf(t, 12.0)
	for k: int in goals.size():
		fired["g%d" % k] = true
	if level == 0 and boom_t < 0.0:
		boom_t = t - 0.6
	for key: String in ["land", "verdict", "roles", "coins"]:
		fired[key] = true
	coins.clear()
	shown_total = float(funds_after)

func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null:
		return
	if e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP):
		var step: float = 24.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -24.0
		scroll = clampf(scroll + step, 0.0, maxf(0.0, feed_h - 176.0))
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		down = hot
		if hot == "":
			_skip()
	else:
		if hot != "" and hot == down:
			_activate(hot)
		down = ""

func _activate(id: String) -> void:
	Audio.play("click")
	match id:
		"again":
			Game.signed = {}
			Game.goto("builder")
		"menu":
			Game.goto("menu")
		"tech":
			MenuScript.open_tech_next = true
			Game.goto("menu")

# ---------------------------------------------------------------- drawing helpers

func _nine(rect: Rect2, name: String, m: Array, mod: Color = Color.WHITE) -> void:
	var tx: Texture2D = _tx(name)
	RenderingServer.canvas_item_add_nine_patch(get_canvas_item(), Rect2(rect.position.floor(), rect.size.floor()), Rect2(Vector2.ZERO, tx.get_size()),
		tx.get_rid(), Vector2(m[0], m[1]), Vector2(m[2], m[3]), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, mod)

func _img(name: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	draw_texture(_tx(name), pos.floor(), mod)

func _wrap(s: String, w: float, lines_max: int = 60) -> Array:
	var f: Font = Pix.font()
	var out: Array = []
	var line: String = ""
	for wd: String in s.split(" "):
		var test: String = wd if line == "" else line + " " + wd
		if line != "" and f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > w:
			out.append(line)
			line = wd
			if out.size() >= lines_max:
				return out
		else:
			line = test
	if line != "":
		out.append(line)
	return out

func _lines(p: Vector2, s: String, w: float, c: Color, lines_max: int = 60) -> int:
	var arr: Array = _wrap(s, w, lines_max)
	for i: int in arr.size():
		Pix.text(self, p + Vector2(0, i * 12), String(arr[i]), 10, c)
	return arr.size()

func _button(rect: Rect2, id: String, label: String, kind: String, icon: String = "") -> void:
	hits.append([rect, id])
	var state: String = "n"
	if hot == id:
		state = "p" if down == id else "h"
	var drop: int = 2 if state == "p" else 0
	_nine(Rect2(rect.position, Vector2(rect.size.x, 24)), "%s_%s" % [kind, state], BTN_M)
	var w: float = Pix.text_w(label, 10) + (16.0 if icon != "" else 0.0)
	var x: float = rect.position.x + floorf((rect.size.x - w) / 2.0)
	var by: float = rect.position.y + 15.0 + drop
	if icon != "":
		_img(icon, Vector2(x, by - 11))
		x += 16.0
	Pix.text(self, Vector2(x, by), label, 10, Color("f4f8ff"))

func _panel_dy(delay: float) -> float:
	var e: float = clampf((t - _tl("panels") - delay) / 0.25, 0.0, 1.0)
	return roundf((1.0 - pow(1.0 - e, 3.0)) * 16.0)

func _panel_on(delay: float) -> bool:
	return t >= _tl("panels") + delay

func _shift(dy: float) -> void:
	draw_set_transform(cur_sh + Vector2(0, dy))

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	hits.clear()
	cur_sh = Vector2.ZERO
	var st: float = t - shake_t
	if st >= 0.0 and st < 0.3:
		var k: float = 1.0 - st / 0.3
		cur_sh = Vector2(floorf(sin(st * 70.0) * 2.0 * k), floorf(cos(st * 55.0) * 2.0 * k))
	_shift(0.0)
	_draw_band()
	_draw_panels()
	_draw_bottom()
	for s: Dictionary in sparks:
		Fx.sparkle(self, s["pos"], float(s["age"]) / float(s["dur"]), s["tint"], 1)
	draw_set_transform(Vector2.ZERO)

func _draw_band() -> void:
	draw_rect(Rect2(-4, -4, 648, 368), UI.BG)
	Pix.tiled(self, BG_TEX, 0, t * 2.0, 640.0, Color(0.8, 0.8, 1.0))
	Pix.stars(self, t, Vector2(640, 110), 40, 11, Vector2(-t * 4.0, 0))
	draw_rect(Rect2(0, 104, 640, 4), Color(0.02, 0.03, 0.07))
	draw_rect(Rect2(0, 108, 640, 1), Color("2a3558"))
	var col: Color = UI.GREEN if level == 2 else (UI.YELLOW if level == 1 else UI.RED)
	# the vignette on the right: the vehicle on the ground, or what is left of it
	var vx: float = 556.0
	var ground: float = 104.0
	var dim: Color = Color.WHITE if level > 0 else Color(0.32, 0.3, 0.34)
	if dest_id != "saturn":
		var gt: Texture2D = _tx("ground_moon")
		var gx: float = 440.0
		var gmod: Color = Color(1, 1, 1) if dest_id == "moon" else Color(1.0, 0.55, 0.38)
		while gx < 640.0:
			draw_texture(gt, Vector2(gx, ground - 14.0), gmod)
			gx += gt.get_width()
		var lt: Texture2D = _tx("veh_lander")
		draw_texture(lt, Vector2(vx - 20.0, ground - 10.0 - lt.get_height()), dim)
		if level == 1:
			_img("ic_warn", Vector2(vx - 7.0, ground - 54.0 - floorf(absf(sin(t * 3.0)) * 3.0)))
	else:
		var bob: float = floorf(sin(t * 1.4) * 2.0)
		draw_texture(_tx("veh_orbiter"), Vector2(vx - 20.0, 52.0 + bob), dim)
		if level > 0:
			Fx.trail(self, Vector2(vx - 20.0, 70.0 + bob), Vector2.LEFT, 48.0, 3.0, t)
	var wreck: Vector2 = Vector2(vx, 70.0)
	if level == 0 and boom_t > -1.0:
		Fx.explosion(self, wreck, t - boom_t, 1, 20.0)
		if t - boom_t > 0.5:
			for k: int in 3:
				var age: float = fposmod(t * 0.6 + k * 0.33, 1.0)
				Fx.puff(self, wreck + Vector2((k - 1) * 8.0, 8.0 - age * 40.0), age, 1, Color(0.5, 0.5, 0.55, 0.8), k)
	elif level == 2:
		for k: int in 2:
			var age2: float = fposmod(t * 0.7 + k * 0.5, 1.0)
			var spot: float = floorf(sin(k * 3.0 + floorf(t * 0.7 + k * 0.5)) * 6.0)
			Fx.sparkle(self, Vector2(vx - 28.0 + k * 52.0 + spot, 54.0 + k * 10.0), age2, Color("fff4b8"), 1)
	# the patch drops in
	var dt: float = t - _tl("patch")
	if dt >= 0.0:
		var py: float = 22.0
		if dt < 0.3:
			var u: float = dt / 0.3
			py = -70.0 + 92.0 * u * u
		else:
			var d2: float = dt - 0.3
			py = 22.0 - floorf(absf(sin(d2 * 13.0)) * 9.0 * exp(-d2 * 6.0))
			Fx.glow(self, Vector2(50, 54), 48.0, Color(col.r, col.g, col.b, 0.28), true)
		draw_texture(_tx("patch_%s_%s" % [dest_id, metal]), Vector2(18, py))
	# the verdict, typed in; the score counts up under it
	var vt: float = t - _tl("verdict")
	if vt >= 0.0:
		var shown_chars: int = mini(head.length(), int(vt * 30.0) + 1)
		Pix.title(self, Vector2(100, 56), head.substr(0, shown_chars), col, 3)
		if vt > 0.4:
			Pix.text(self, Vector2(102, 76), "%s  -  %d of %d goals" % [Data.DEST[dest_id]["name"], _goals_done(), goals.size()], 10, UI.DIM)
			var sc: int = roundi(float(score) * clampf((t - _tl("score")) / 1.4, 0.0, 1.0))
			Pix.text(self, Vector2(102, 95), "SCORE", 10, UI.DIM)
			Pix.title(self, Vector2(146, 97), "%d%%" % sc, UI.YELLOW, 1)
			if sc < score and sc / 8 != int(fired.get("sc", 0)) / 8:
				Audio.play("poll_blip", -12.0, 0.8 + sc / 100.0)
			fired["sc"] = sc

func _goals_done() -> int:
	var n: int = 0
	for g: Array in goals:
		if bool(g[1]):
			n += 1
	return n

func _draw_panels() -> void:
	# --- A: goals and team
	var pa: Rect2 = Rect2(8, 114, 176, 210)
	if _panel_on(0.0):
		_shift(_panel_dy(0.0))
		_nine(pa, "card", FRAME_M)
		Pix.text(self, pa.position + Vector2(10, 16), "GOALS", 10, UI.CYAN)
		draw_rect(Rect2(pa.position.x + 8, pa.position.y + 20, 160, 1), Color("2a3558"))
		for k: int in goals.size():
			var rt: float = t - (_tl("goals") + 0.45 * k)
			var y: float = pa.position.y + 24.0 + k * 15.0
			if rt < 0.0:
				Pix.text(self, Vector2(pa.position.x + 26, y + 10), String(goals[k][0]), 10, Color("3a4a7a"))
				continue
			var ok: bool = bool(goals[k][1])
			var pop: float = floorf(maxf(0.0, 1.0 - rt / 0.2) * 4.0)
			_img("ic_tick" if ok else "ic_cross", Vector2(pa.position.x + 8, y - pop))
			Pix.text(self, Vector2(pa.position.x + 26, y + 10), String(goals[k][0]), 10, UI.GREEN if ok else UI.RED)
		var ty: float = pa.position.y + 24.0 + goals.size() * 15.0 + 8.0
		Pix.text(self, Vector2(pa.position.x + 10, ty + 8), "TEAM SCORES", 10, UI.CYAN)
		draw_rect(Rect2(pa.position.x + 8, ty + 12, 160, 1), Color("2a3558"))
		var rf: float = clampf((t - _tl("roles")) / 0.9, 0.0, 1.0)
		var i: int = 0
		for role: Dictionary in Data.ROLES:
			var rid: String = String(role["id"])
			var v: int = int(roles.get(rid, 0))
			var ry: float = ty + 17.0 + i * 15.0
			var ic: String = String(ROLE_ICON[rid])
			if ic == "wrench" or ic == "science":
				_img("ic_flask" if ic == "science" else "ic_wrench", Vector2(pa.position.x + 8, ry))
			else:
				Pix.icon(self, ic, Vector2(pa.position.x + 8, ry))
			Pix.text(self, Vector2(pa.position.x + 26, ry + 10), String(ROLE_NAME[rid]), 10, role["color"])
			Pix.gauge(self, Rect2(pa.position.x + 82, ry + 3, 56, 8), float(v) / 100.0 * rf, role["color"])
			Pix.text(self, Vector2(pa.position.x + 144, ry + 10), "%d" % roundi(v * rf), 10, UI.TEXT)
			i += 1
	# --- B: what happened and why (the feed is a child control)
	if _panel_on(0.12):
		_shift(_panel_dy(0.12))
		var pb: Rect2 = Rect2(188, 114, 300, 210)
		_nine(pb, "card", FRAME_M)
		Pix.text(self, pb.position + Vector2(10, 16), "WHAT HAPPENED, AND WHY", 10, UI.YELLOW)
		draw_rect(Rect2(pb.position.x + 8, pb.position.y + 20, 284, 1), Color("2a3558"))
	# --- C: the real thing
	if _panel_on(0.24):
		_shift(_panel_dy(0.24))
		var pc: Rect2 = Rect2(492, 114, 140, 210)
		_nine(pc, "card", FRAME_M)
		Pix.text(self, pc.position + Vector2(10, 16), "THE REAL THING", 10, UI.CYAN)
		draw_rect(Rect2(pc.position.x + 8, pc.position.y + 20, 124, 1), Color("2a3558"))
		var n: int = _lines(pc.position + Vector2(10, 34), real_text, 122.0, UI.TEXT, 11)
		var sy: float = pc.position.y + 34.0 + n * 12.0 + 6.0
		Pix.text(self, Vector2(pc.position.x + 10, sy + 8), "YOUR SHIP", 10, UI.CYAN)
		draw_rect(Rect2(pc.position.x + 8, sy + 12, 124, 1), Color("2a3558"))
		for k: int in stats.size():
			var yy: float = sy + 16.0 + k * 14.0
			Pix.icon(self, String(stats[k][0]), Vector2(pc.position.x + 8, yy - 1))
			Pix.text(self, Vector2(pc.position.x + 26, yy + 8), String(stats[k][1]), 10, UI.DIM)
	_shift(0.0)

func _draw_feed(c: CanvasItem) -> void:
	var y: float = -scroll
	var w: float = 276.0
	for it: Dictionary in items:
		var h: int = int(it["h"])
		if y + h < 0.0 or y > 176.0:
			y += h
			continue
		var lines: Array = it["lines"]
		match String(it["k"]):
			"head":
				var hc: Color = it["col"]
				c.draw_rect(Rect2(0, y + 2, w, 13), Color(hc.r, hc.g, hc.b, 0.18))
				c.draw_rect(Rect2(0, y + 2, 2, 13), hc)
				Pix.text(c, Vector2(7, y + 12), String(it["text"]), 10, hc)
			"text":
				for i: int in lines.size():
					Pix.text(c, Vector2(2, y + 11 + i * 12), String(lines[i]), 10, it["col"])
			"log":
				var ok: bool = bool(it["ok"])
				c.draw_texture(_tx("ic_tick" if ok else "ic_cross"), Vector2(0, y + 1))
				for i: int in lines.size():
					Pix.text(c, Vector2(18, y + 11 + i * 12), String(lines[i]), 10, Color("9fe8b0") if ok else UI.RED)
		y += h
	if feed_h > 176:
		var bh: float = maxf(12.0, 176.0 * 176.0 / feed_h)
		var by: float = (176.0 - bh) * scroll / maxf(1.0, feed_h - 176.0)
		c.draw_rect(Rect2(280, 0, 3, 176), Color(0.02, 0.03, 0.07, 0.7))
		c.draw_rect(Rect2(280, floorf(by), 3, floorf(bh)), Color("5a6aa0"))

func _draw_bottom() -> void:
	_button(Rect2(8, 332, 118, 24), "menu", "MISSION SELECT", "btn_grey")
	_button(Rect2(130, 332, 86, 24), "tech", "TECH LAB", "btn_blue", "ic_flask")
	if t >= _tl("coins") - 0.2 and reward > 0:
		Pix.text(self, Vector2(228, 348), "+%d" % reward, 10, UI.YELLOW)
	var tot: String = str(roundi(shown_total))
	_img("ic_coin", Vector2(300, 332))
	Pix.title(self, Vector2(320, 350), tot, UI.YELLOW, 1)
	Pix.text(self, Vector2(320.0 + Pix.title_w(tot, 1) + 6.0, 348), "CREDITS", 10, UI.DIM)
	for cn: Dictionary in coins:
		var u: float = (t - float(cn["t0"])) / 0.55
		if u < 0.0 or u >= 1.0:
			continue
		var p: Vector2 = (cn["from"] as Vector2).lerp(cn["to"] as Vector2, u) + Vector2(0, -sin(u * PI) * 22.0)
		draw_texture(_tx("ic_coin"), (p - Vector2(7, 7)).floor())
	_button(Rect2(476, 332, 156, 24), "again", "REDESIGN & FLY AGAIN", "btn_green", "ic_play")

# ---------------------------------------------------------------- debug (screenshots)

func _fake(goal_ok: Array, log: Array, scr: int, rew: int) -> void:
	## Builds a made-up finished run from the real one, without touching Game.run.
	var f: Dictionary = r.duplicate(true)
	var obj: Dictionary = {}
	var names: Array = Data.DEST[dest_id]["objectives"]
	for i: int in names.size():
		obj[String(names[i])] = bool(goal_ok[i]) if i < goal_ok.size() else false
	f["obj"] = obj
	f["log"] = log
	f["score"] = scr
	f["reward"] = rew
	f["roles"] = {"planner": 100 if scr >= 50 else 40, "engineer": 85 if scr >= 50 else 35, "science": 66 if scr >= 50 else 0, "comms": 100 if scr >= 100 else 0}
	_load(f)

func debug_success() -> void:
	_fake([true, true, true, true, true, true], [
		{"ok": true, "text": "LAUNCH. The rocket lifted 3,950 kg of ship."},
		{"ok": true, "text": "Arrived at the Moon in 3 days and braked into orbit."},
		{"ok": true, "text": "TOUCHDOWN at 1.4 m/s (limit 4 m/s). 120 kg of fuel left."},
		{"ok": true, "text": "Samples collected: 3 of 3."},
		{"ok": true, "text": "The ascent stage lifted off and brought 3 samples back to Earth."}], 100, 160)

func debug_partial() -> void:
	_fake([true, true, true, false, false], [
		{"ok": true, "text": "LAUNCH. The rocket lifted 3,950 kg of ship."},
		{"ok": true, "text": "TOUCHDOWN at 2.1 m/s (limit 4 m/s)."},
		{"ok": false, "text": "Samples collected: 1 of 3. The battery ran out before the drill finished."},
		{"ok": false, "text": "STRANDED. Battery at 12%: the ascent engine needs 30% to start. You can't go home."}], 60, 80)

func debug_fail() -> void:
	_fake([true, false, false, false, false], [
		{"ok": true, "text": "LAUNCH. The rocket lifted 3,950 kg of ship."},
		{"ok": false, "text": "NOT ENOUGH FUEL to brake into orbit. Braking by 0.9 km/s needed 410 kg of fuel; you had 120 kg. The ship flew past %s." % String(Game.dest()["name"]).capitalize()}], 20, 20)

func debug_skip() -> void:
	_skip()
