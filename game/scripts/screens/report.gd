extends Control
## Mission report, the whole journey in three sections (pages, never a scroll):
##   OVERVIEW      goals as a checklist, the four scores with "what would raise it", the one lesson, the real mission
##   JOURNEY       every phase in order with each decision: the choice, the call, the cost, the real mission it came from
##   BUILD REPORT  per resource: what the mission needed, the green "well used" band, where the ship was, the rating
## Everything comes from Game.run["report"]; every key is read with a default so an old save or a debug jump never crashes.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const MenuScript = preload("res://scripts/screens/menu.gd")
const BG_TEX: Texture2D = preload("res://art/bg_space.png")

const FRAME_M: Array = [6, 6, 6, 8]
const BTN_M: Array = [4, 5, 4, 6]
const LINE: Color = Color("2a3558")
const COL_WELL: Color = UI.GREEN
const COL_RISK: Color = UI.RED
const COL_WASTE: Color = UI.YELLOW

const PAGE_Y: float = 94.0
const PAGE_H: float = 232.0
const CONTENT_H: int = 204       # journey items per page, below the page header

## [text to look for in the log, what to change next time]. Wording checked against research/v5/factcheck.md.
const TIPS: Array = [
	["TOO HEAVY", "ENGINEER + PLANNER: remove mass or pick a bigger rocket. A slower path can also save fuel."],
	["OUT OF POWER", "ENGINEER: far from the Sun, solar panels fail. Use nuclear power (RTGs), like Cassini and Perseverance."],
	["OVERHEATED", "ENGINEER: near the Sun, add a sunshade. MESSENGER flew behind one."],
	["NOT ENOUGH FUEL", "ENGINEER: add propellant until the FUEL gauge is in the green zone. Fuel grows fast with mass."],
	["BURNED UP", "SCIENTIST: where there is air, a heat shield is a must."],
	["CRUSHED", "ENGINEER: Venus air presses 92 times harder than Earth's. Add the pressure hull."],
	["NO PARACHUTE", "SCIENTIST: a parachute slows you from 420 to 85 m/s for free."],
	["CRASH", "PILOT: fire the engine earlier and touch down slowly. Legs or airbags raise the speed limit."],
	["STRANDED", "ENGINEER: bring more solar power or batteries, and keep 30% battery for the trip home."],
	["BATTERY EMPTY", "ENGINEER: Mars nights last about 12 hours. Add batteries or a nuclear battery (RTG)."],
	["RADIATION", "ENGINEER: add a radiation shield. Juno hides its computer in a titanium vault."],
	["SOLAR STORM", "ENGINEER: radiation shielding protects electronics from solar storms."],
	["Storage full", "COMMS: add a data recorder."],
	["Sent", "COMMS: a bigger antenna sends data faster. Radio speed falls with distance squared."],
	["No ascent stage", "SCIENTIST: add the ascent stage to bring samples home."],
	["drone was lost", "PILOT: save fuel to fly the drone back up to the orbiter."],
	["No drone", "SCIENTIST: giant planets have no ground. Add the sampling drone."],
	["Samples collected", "SCIENTIST: a rover and a drill reach more rocks. Watch the battery."],
	["Ring samples", "PILOT: fly through the ring band and grab the ice grains."],
	["LATE", "PLANNER: keep spare days. Fewer kinds of parts means less development time."],
]

const ROLE_ICON: Dictionary = {"planner": "clipboard", "engineer": "wrench", "science": "science", "comms": "comms"}
const ROLE_NAME: Dictionary = {"planner": "PLANNER", "engineer": "ENGINEER", "science": "SCIENTIST", "comms": "COMMS"}
const SCORE_KEYS: Array = ["success", "science", "efficiency", "decisions"]
const SCORE_ICON: Dictionary = {"success": "star", "science": "science", "efficiency": "money", "decisions": "clipboard"}
const RES_KEYS: Array = ["mass", "power", "battery", "fuel", "data", "comms", "budget", "time"]
const RES_ICON: Dictionary = {"mass": "mass", "power": "power", "battery": "battery", "fuel": "fuel", "data": "data", "comms": "comms", "budget": "money", "time": "time"}
const PHASE_ORDER: Array = ["launch", "cruise", "arrive", "landing", "site", "home"]
const SEC_NAMES: Array = ["OVERVIEW", "JOURNEY", "BUILD REPORT"]
const GROUND_TINT: Dictionary = {"moon": Color(1, 1, 1), "mars": Color(1.0, 0.55, 0.38), "venus": Color(1.0, 0.78, 0.4), "mercury": Color(0.82, 0.74, 0.68)}
const GRADE_WORD: Dictionary = {"good": "GOOD CALL", "risky": "RISKY CALL", "bad": "BAD CALL"}

# the run being shown
var r: Dictionary = {}
var rep: Dictionary = {}
var d: Dictionary = {}
var dest_id: String = "moon"
var score: int = 0          # objectives, 0-100 (the verdict)
var total: int = 0          # the four parts together, 0-100
var level: int = 0          # 0 fail, 1 partial, 2 success
var metal: String = "fail"
var head: String = ""
var diff_name: String = "NORMAL"
var task_name: String = ""
var grade: String = ""          # "A" "B" "C" or "" (no grade: the mission did not succeed)
var grade_lines: Array = []
var grade_rule_lines: Array = []
var fake_grade: Dictionary = {} # debug: fields merged into the made-up report
var goals: Array = []       # [name, ok]
var reward: int = 0
var funds_after: int = 0
var lesson_lines: Array = []
var real_lines: Array = []
var score_rows: Array = []  # {key, name, value, lines}
var build_rows: Array = []  # {key, name, u, lines, ...}
var well_count: int = 0
var pages: Array = []       # {sec, items?, n?, of?}
var sec_first: Array = [0, 1, 2]
var page: int = 0
var page_t0: float = 0.0

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
var boom_t: float = -9.0
var goals_start: float = 1.0
var cur_sh: Vector2 = Vector2.ZERO

func _ready() -> void:
	for n: String in ["ic_tick", "ic_cross", "ic_coin", "ic_flask", "ic_play", "ic_warn", "card", "veh_lander", "veh_orbiter", "ground_moon"]:
		_tx(n)
	for n: String in ["btn_green", "btn_grey", "btn_blue"]:
		for s: String in ["n", "h", "p"]:
			_tx(n + "_" + s)
	for dd: String in ["moon", "mars", "saturn"]:
		for m: String in ["gold", "silver", "bronze", "fail"]:
			_tx("patch_%s_%s" % [dd, m])
	_load(Game.run)

func _tx(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/menu/%s.png" % name) as Texture2D
	return tex_cache[name]

## Art in res://art (the planets). Kept in tex_cache so the texture is never freed while drawing.
func _ta(name: String) -> Texture2D:
	var key: String = "a:" + name
	if not tex_cache.has(key):
		tex_cache[key] = load("res://art/%s.png" % name) as Texture2D
	return tex_cache[key]

# ---------------------------------------------------------------- reading the run

## Reads a finished run (the real Game.run, or a made-up one from a debug_ method) and plans the show and the pages.
func _load(run: Dictionary) -> void:
	r = run
	rep = r.get("report", {}) as Dictionary
	dest_id = Game.dest_id
	d = Data.DEST.get(dest_id, Data.DEST["moon"]) as Dictionary
	# goals
	goals.clear()
	var objs: Array = rep.get("objectives", []) as Array
	if objs.is_empty():
		var obj: Dictionary = r.get("obj", {}) as Dictionary
		for o: String in obj:
			objs.append({"id": o, "name": String(Data.OBJ_NAMES.get(o, o)), "done": bool(obj[o])})
	var done: int = 0
	for o2: Dictionary in objs:
		var nm: String = String(o2.get("name", ""))
		var ok: bool = bool(o2.get("done", false))
		if String(o2.get("id", "")) == "samples":
			nm += " (%d/%d)" % [int(r.get("samples", 0)), int(d.get("samples_goal", 0))]
		goals.append([nm, ok])
		if ok:
			done += 1
	score = int(r.get("score", roundi(100.0 * done / maxf(1.0, goals.size()))))
	level = 2 if score >= 100 else (1 if score >= 50 else 0)
	head = ["MISSION FAILED", "PARTIAL SUCCESS", "MISSION SUCCESS"][level]
	metal = "fail" if level == 0 else ("gold" if score >= 100 else ("silver" if score >= 75 else "bronze"))
	total = int(rep.get("total", r.get("total", score)))
	diff_name = String(rep.get("difficulty", Data.DIFFICULTY[clampi(Game.difficulty, 0, 2)]["name"]))
	task_name = ""
	if Game.has_method("task"):
		task_name = String((Game.call("task") as Dictionary).get("name", ""))
	grade = String(rep.get("grade", "")).to_upper()
	grade_lines = _wrap_cap(String(rep.get("grade_text", "")), 112.0, 5) if grade != "" else []
	grade_rule_lines = _wrap_cap(String(rep.get("grade_rule", "")), 294.0, 2) if grade != "" else []
	reward = int(rep.get("credits", r.get("reward", 0)))
	funds_after = Game.funds
	shown_total = float(funds_after - reward)
	# the four score parts
	var sc: Dictionary = rep.get("scores", r.get("scores", {})) as Dictionary
	score_rows.clear()
	for key: String in SCORE_KEYS:
		var row: Dictionary = sc.get(key, {}) as Dictionary
		score_rows.append({"key": key, "name": String(row.get("name", key.to_upper())), "value": int(row.get("value", 0)),
			"lines": _wrap(String(row.get("tip", "No data for this flight.")), 294.0, 2)})
	# the lesson and the real mission
	lesson_lines = _wrap(_lesson(sc), 290.0, 3)
	real_lines = _wrap(String(d.get("real", "")), 290.0, 4)
	_build_rows()
	_build_pages()
	page = 0
	page_t0 = 0.0
	t = 0.0
	fired.clear()
	sparks.clear()
	coins.clear()
	coins_in = 0
	boom_t = -9.0
	shake_t = -9.0

## The one most important lesson: the first thing that went wrong, else the weakest score part.
func _lesson(sc: Dictionary) -> String:
	for ph: Dictionary in _phases():
		for ln: Dictionary in ph["lines"]:
			if bool(ln["ok"]):
				continue
			var txt: String = String(ln["text"])
			for tp: Array in TIPS:
				if txt.contains(String(tp[0])):
					return String(tp[1])
	var worst: String = ""
	var low: int = 100
	for row: Dictionary in score_rows:
		if String(row["key"]) == "decisions" and _decisions().is_empty():
			continue   # nothing to learn from a part that had no events
		if int(row["value"]) < low:
			low = int(row["value"])
			worst = String(row["key"])
	if worst != "":
		return "To raise %s: %s" % [String((sc.get(worst, {}) as Dictionary).get("name", worst)), String((sc.get(worst, {}) as Dictionary).get("tip", ""))]
	return "Every part was well sized and every call was sound. Try a harder difficulty."

func _build_rows() -> void:
	build_rows.clear()
	well_count = 0
	var use: Dictionary = rep.get("build", r.get("use", {})) as Dictionary
	for key: String in RES_KEYS:
		if not use.has(key):
			continue
		var u: Dictionary = use[key] as Dictionary
		if String(u.get("rating", "well")) == "well":
			well_count += 1
		build_rows.append({"key": key, "u": u, "lines": _wrap(String(u.get("tip", "")), 210.0, 2)})

# ---------------------------------------------------------------- pages

## Phases in flight order, one entry per phase, from the report (or, for an old save, the plain log).
func _phases() -> Array:
	var src: Array = rep.get("phases", []) as Array
	if src.is_empty():
		var lines: Array = []
		for e: Dictionary in r.get("log", []) as Array:
			lines.append({"ok": bool(e.get("ok", true)), "text": String(e.get("text", ""))})
		if not lines.is_empty():
			src = [{"id": "launch", "name": "THE FLIGHT", "ok": true, "lines": lines}]
	var by_id: Dictionary = {}
	var order: Array = []
	for ph: Dictionary in src:
		var id: String = String(ph.get("id", ""))
		if not by_id.has(id):
			by_id[id] = {"id": id, "ok": true, "lines": []}
			order.append(id)
		for ln: Dictionary in ph.get("lines", []) as Array:
			(by_id[id]["lines"] as Array).append(ln)
			if not bool(ln.get("ok", true)):
				by_id[id]["ok"] = false
	for dc: Dictionary in _decisions():
		var pid: String = String(dc.get("phase", "cruise"))
		if not by_id.has(pid):
			by_id[pid] = {"id": pid, "ok": true, "lines": []}
			order.append(pid)
		if not bool(dc.get("ok", true)):
			by_id[pid]["ok"] = false
	order.sort_custom(func(a: String, b: String) -> bool:
		var ia: int = PHASE_ORDER.find(a)
		var ib: int = PHASE_ORDER.find(b)
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	var out: Array = []
	for id2: String in order:
		var p: Dictionary = by_id[id2]
		p["name"] = _phase_name(id2)
		out.append(p)
	return out

func _decisions() -> Array:
	return rep.get("decisions", r.get("decisions", [])) as Array

func _phase_name(id: String) -> String:
	var ring: bool = String(d.get("kind", "land")) == "ring"
	match id:
		"launch":
			return "LAUNCH"
		"cruise":
			return "CRUISE"
		"arrive":
			return "ARRIVAL"
		"landing":
			return "LANDING"
		"site":
			return "RING DRONE" if ring else "ON THE SURFACE"
		"home":
			return "TRIP HOME" if bool(d.get("returns", false)) else "DOWNLINK TO EARTH"
	return id.to_upper()

## One journey item per row: a phase head, a log line or a decision card, each with its wrapped text and height.
## mode 0 is the full text; modes 1 to 3 shorten the cards and lines until the journey fits 3 pages.
func _journey_items(mode: int) -> Array:
	var items: Array = []
	var decs: Array = _decisions()
	var line_cap: int = [3, 2, 2, 1][mode]
	for ph: Dictionary in _phases():
		items.append({"k": "head", "name": String(ph["name"]), "ok": bool(ph["ok"]), "h": 17})
		for ln: Dictionary in ph["lines"]:
			var txt: String = String(ln.get("text", ""))
			if txt.begins_with("DECISION,"):
				continue   # shown as a card below
			var lines: Array = _wrap_cap(txt, 572.0, line_cap)
			items.append({"k": "line", "ok": bool(ln.get("ok", true)), "lines": lines, "h": lines.size() * 12 + 3})
		for dc: Dictionary in decs:
			if String(dc.get("phase", "")) != String(ph["id"]):
				continue
			items.append(_decision_item(dc, mode))
	return items

func _decision_item(dc: Dictionary, mode: int) -> Dictionary:
	var cost: String = String(dc.get("cost", "nothing"))
	var text: String = String(dc.get("text", ""))
	if cost != "nothing":
		text = text.replace(" " + cost + ".", "")
	var real: String = ""
	if Game.has_method("event_by_id"):
		real = String((Game.event_by_id(String(dc.get("id", ""))) as Dictionary).get("real", ""))
	var l_choice: Array = []
	var l_res: Array = []
	var choice_s: String = "CHOSE: %s    COST: %s" % [String(dc.get("choice", "?")), cost]
	if mode == 0:
		l_choice = _wrap_cap(choice_s, 562.0, 2)
		l_res = _wrap_cap(text, 562.0, 2)
	else:
		l_choice = _wrap_cap(choice_s + "    " + text, 562.0, 1 if mode == 3 else 2)   # the outcome joins the choice line
	var l_real: Array = _wrap_cap("TRUE STORY: " + real, 562.0, 2 if mode < 2 else 1) if real != "" else []
	var h: int = (6 if mode == 0 else 4) + 14 + (l_choice.size() + l_res.size() + l_real.size()) * 12 + (6 if mode == 0 else 3)
	return {"k": "dec", "d": dc, "choice": l_choice, "res": l_res, "real": l_real, "h": h}

## Fills pages greedily; a head is never the last thing on a page, and a continued phase repeats its head.
func _paginate(items: Array) -> Array:
	var chunks: Array = []
	var cur: Array = []
	var used: int = 0
	var last_head: Dictionary = {}
	for i: int in items.size():
		var it: Dictionary = items[i]
		var need: int = int(it["h"])
		if it["k"] == "head":
			last_head = it
			if i + 1 < items.size():
				need += int(items[i + 1]["h"])
		if used + need > CONTENT_H and not cur.is_empty():
			chunks.append(cur)
			cur = []
			used = 0
			if it["k"] != "head" and not last_head.is_empty():
				var cont: Dictionary = last_head.duplicate()
				cont["name"] = String(cont["name"]) + " (CONTINUED)"
				cur.append(cont)
				used += int(cont["h"])
		cur.append(it)
		used += int(it["h"])
	if not cur.is_empty():
		chunks.append(cur)
	return chunks

func _build_pages() -> void:
	pages.clear()
	pages.append({"sec": 0})
	var chunks: Array = []
	for mode: int in 4:
		chunks = _paginate(_journey_items(mode))
		if chunks.size() <= 3:
			break
	if chunks.is_empty():
		chunks.append([{"k": "line", "ok": true, "lines": ["No flight log was saved for this run."], "h": 15}])
	sec_first = [0, 1, 1 + chunks.size()]
	for n: int in chunks.size():
		pages.append({"sec": 1, "items": chunks[n], "n": n + 1, "of": chunks.size()})
	pages.append({"sec": 2})

func _sec() -> int:
	return int((pages[page] as Dictionary)["sec"])

func _flip(step: int) -> void:
	_go_page(clampi(page + step, 0, pages.size() - 1))

func _go_page(p: int) -> void:
	if p == page:
		return
	page = p
	page_t0 = t
	Audio.play("click", -7.0, 1.15)

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
		"grade":
			return _tl("verdict") + 1.0
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
			sparks.append({"pos": Vector2(38.0 + cos(k * 1.26) * 36.0, 34.0 + sin(k * 1.26) * 30.0), "age": 0.0, "dur": 0.5,
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
			if ok and page == 0:
				sparks.append({"pos": Vector2(23.0, 124.0 + k * 13.0), "age": 0.0, "dur": 0.45, "tint": Color("6dff8a")})
	if grade != "" and _fire("grade", _tl("grade") + 0.2):
		shake_t = t
		Audio.play("all_go", -3.0)
		Audio.play("land", -8.0, 1.3)
		for k: int in 4:
			sparks.append({"pos": Vector2(502.0 + cos(k * 1.6) * 24.0, 21.0 + sin(k * 1.6) * 20.0), "age": 0.0, "dur": 0.45, "tint": Color("ffd75e")})
	if _fire("roles", _tl("roles")):
		Audio.play("blip", -4.0)
		if level == 2:
			Audio.play("all_go", -3.0)
	if _fire("coins", _tl("coins")) and reward > 0:
		var n: int = clampi(reward / 12, 3, 14)
		for k: int in n:
			coins.append({"t0": t + 0.07 * k, "from": Vector2(236, 346), "to": Vector2(287, 339), "val": float(reward) / n})
	for i: int in range(coins.size() - 1, -1, -1):
		var cn: Dictionary = coins[i]
		if t >= float(cn["t0"]) + 0.55:
			shown_total = minf(float(funds_after), shown_total + float(cn["val"]))
			coins_in += 1
			Audio.play("pickup", -10.0, 1.0 + 0.04 * coins_in)
			sparks.append({"pos": Vector2(287, 339), "age": 0.0, "dur": 0.35, "tint": Color("ffd75e")})
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
	queue_redraw()

func _skip() -> void:
	## Jump to the end of the show: everything shown, coins counted.
	t = maxf(t, 12.0)
	for k: int in goals.size():
		fired["g%d" % k] = true
	if level == 0 and boom_t < 0.0:
		boom_t = t - 0.6
	for key: String in ["land", "verdict", "roles", "coins", "grade"]:
		fired[key] = true
	coins.clear()
	shown_total = float(funds_after)

func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_LEFT, KEY_A:
			_flip(-1)
		KEY_RIGHT, KEY_D:
			_flip(1)
		KEY_1:
			_go_page(int(sec_first[0]))
		KEY_2:
			_go_page(int(sec_first[1]))
		KEY_3:
			_go_page(int(sec_first[2]))
		_:
			return
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null:
		return
	if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_flip(1)
		return
	if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
		_flip(-1)
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
	if id.begins_with("sec"):
		_go_page(int(sec_first[int(id.substr(3))]))
		return
	Audio.play("click")
	match id:
		"prev":
			_flip(-1)
		"next":
			_flip(1)
		"again":
			if Net.is_online() and not Net.is_host():
				return
			Game.signed = {}
			Game.flow("builder")
		"menu":
			Game.leave_room()
		"tech":
			MenuScript.open_tech_next = true
			Game.leave_room()

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
	if line != "" and out.size() < lines_max:
		out.append(line)
	return out

## Wraps to at most n lines; text that does not fit ends in "..." instead of being cut silently.
func _wrap_cap(s: String, w: float, n: int) -> Array:
	var all: Array = _wrap(s, w)
	if all.size() <= n:
		return all
	var out: Array = all.slice(0, n)
	var last: String = String(out[n - 1])
	while last.length() > 3 and Pix.text_w(last + "...", 10) > w:
		last = last.substr(0, last.length() - 1)
	out[n - 1] = last + "..."
	return out

func _lines(p: Vector2, arr: Array, c: Color) -> void:
	for i: int in arr.size():
		Pix.text(self, p + Vector2(0, i * 12), String(arr[i]), 10, c)

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
	return roundf(pow(1.0 - e, 3.0) * 16.0)

func _panel_on(delay: float) -> bool:
	return t >= _tl("panels") + delay

func _shift(dy: float) -> void:
	draw_set_transform(cur_sh + Vector2(0, dy))

func _sep(x: float, y: float, w: float) -> void:
	draw_rect(Rect2(x, y, w, 1), LINE)

func _val_text(v: float, unit: String) -> String:
	var n: String = "0" if absf(v) < 0.005 else Game.fmt(v)
	return "$%sM" % n if unit == "$M" else "%s %s" % [n, unit]

func _score_col(v: int) -> Color:
	return COL_WELL if v >= 75 else (COL_WASTE if v >= 50 else COL_RISK)

func _state_col(state: String) -> Color:
	return COL_WELL if state == "well" else (COL_RISK if state == "risk" else COL_WASTE)

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
	if _panel_on(0.0):
		_shift(_panel_dy(0.0))
		_draw_tabs()
		match _sec():
			0:
				_draw_overview()
			1:
				_draw_journey()
			2:
				_draw_build()
	_shift(0.0)
	_draw_bottom()
	for s: Dictionary in sparks:
		Fx.sparkle(self, s["pos"], float(s["age"]) / float(s["dur"]), s["tint"], 1)
	draw_set_transform(Vector2.ZERO)

func _draw_band() -> void:
	draw_rect(Rect2(-4, -4, 648, 368), UI.BG)
	Pix.tiled(self, BG_TEX, 0, t * 2.0, 640.0, Color(0.8, 0.8, 1.0))
	Pix.stars(self, t, Vector2(640, 70), 30, 11, Vector2(-t * 4.0, 0))
	draw_rect(Rect2(0, 68, 640, 3), Color(0.02, 0.03, 0.07))
	draw_rect(Rect2(0, 71, 640, 1), LINE)
	var col: Color = UI.GREEN if level == 2 else (UI.YELLOW if level == 1 else UI.RED)
	if grade == "":
		_draw_vignette()
	else:
		_draw_grade()
	# the patch drops in
	var dt: float = t - _tl("patch")
	if dt >= 0.0:
		var py: float = 3.0
		if dt < 0.3:
			var u: float = dt / 0.3
			py = -66.0 + 69.0 * u * u
		else:
			var d2: float = dt - 0.3
			py = 3.0 - floorf(absf(sin(d2 * 13.0)) * 7.0 * exp(-d2 * 6.0))
			Fx.glow(self, Vector2(38, 35), 48.0, Color(col.r, col.g, col.b, 0.26), true)
		_draw_patch(Vector2(6, py))
	# the verdict, typed in; the score counts up under it
	var vt: float = t - _tl("verdict")
	if vt >= 0.0:
		var shown_chars: int = mini(head.length(), int(vt * 30.0) + 1)
		Pix.title(self, Vector2(80, 36), head.substr(0, shown_chars), col, 3)
		if vt > 0.4:
			_draw_subline()
			var sc: int = roundi(float(total) * clampf((t - _tl("score")) / 1.4, 0.0, 1.0))
			Pix.text(self, Vector2(82, 65), "TOTAL SCORE", 10, UI.DIM)
			Pix.title(self, Vector2(158, 66), "%d / 100" % sc, UI.YELLOW, 1)
			if reward > 0:
				_img("ic_coin", Vector2(246, 55))
				Pix.text(self, Vector2(264, 65), "+%d CREDITS" % reward, 10, UI.YELLOW)
			if sc < total and sc / 8 != int(fired.get("sc", 0)) / 8:
				Audio.play("poll_blip", -12.0, 0.8 + sc / 100.0)
			fired["sc"] = sc

## "MOON - TASK NAME [NORMAL] - 5 of 5 goals": the level is a small tag after the task.
func _draw_subline() -> void:
	var x: float = 82.0
	var y: float = 51.0
	var head_s: String = String(d.get("name", ""))
	if task_name != "":
		head_s += "  -  " + task_name
	Pix.text(self, Vector2(x, y), head_s, 10, UI.DIM)
	x += Pix.text_w(head_s, 10) + 8.0
	var tcol: Color = [UI.GREEN, UI.CYAN, UI.ORANGE][clampi(["EASY", "NORMAL", "HARD"].find(diff_name), 0, 2)]
	var tw: float = Pix.text_w(diff_name, 10) + 8.0
	draw_rect(Rect2(x, y - 9.0, tw, 12), tcol)
	draw_rect(Rect2(x + 1, y - 8.0, tw - 2, 10), Color(0.02, 0.03, 0.07))
	Pix.text(self, Vector2(x + 4.0, y), diff_name, 10, tcol)
	Pix.text(self, Vector2(x + tw + 8.0, y), "%d of %d goals" % [_goals_done(), goals.size()], 10, UI.DIM)

## The grade stamp (success only): a medal with the letter that drops in after the verdict, the text beside it.
func _draw_grade() -> void:
	var gt: float = t - _tl("grade")
	if gt < 0.0:
		return
	var py: float = 3.0
	if gt < 0.2:
		var u: float = gt / 0.2
		py = -44.0 + 47.0 * u * u
	else:
		var d2: float = gt - 0.2
		py = 3.0 - floorf(absf(sin(d2 * 13.0)) * 6.0 * exp(-d2 * 6.0))
		Fx.glow(self, Vector2(502, 23), 32.0, Color(1.0, 0.85, 0.35, 0.25), true)
	var tx: Texture2D = _medal(grade)
	draw_texture(tx, Vector2(482, py).floor())
	var ink: Color = Color("fff6d0")
	Pix.title_c(self, 502.0, py + 31.0, grade, ink, 2)
	Pix.text(self, Vector2(528, 12), "GRADE", 10, UI.TEXT)
	for i: int in grade_lines.size():
		Pix.text(self, Vector2(528, 25.0 + i * 10.0), String(grade_lines[i]), 10, UI.DIM)

## A 40 x 40 pixel medal (outline, shaded ring, flat disc), light from the upper left; gold A, silver B, bronze C.
func _medal(g: String) -> Texture2D:
	var key: String = "medal" + g
	if tex_cache.has(key):
		return tex_cache[key]
	var tones: Array = {"A": ["ffe98a", "ffd75e", "d9a02a", "8f5f14", "c58a1c", "e0a830"], "B": ["f2f6ff", "c9d0e0", "8f98b0", "5a6280", "8a93ac", "aab3c8"],
		"C": ["ffc99a", "e0925a", "a85c2e", "6a3414", "a8683a", "c98250"]}.get(g, ["f2f6ff", "c9d0e0", "8f98b0", "5a6280", "8a93ac", "aab3c8"])
	var img: Image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for yy: int in 40:
		for xx: int in 40:
			var dx: float = xx - 19.5
			var dy: float = yy - 19.5
			var rr: float = sqrt(dx * dx + dy * dy)
			if rr > 19.5:
				continue
			var c: Color = Color("0c0a14")
			if rr <= 18.0:
				var lum: float = (dx * -0.7 + dy * -0.7) / maxf(rr, 0.01)
				if rr > 13.5:
					c = Color(tones[0]) if lum > 0.55 else (Color(tones[1]) if lum > -0.25 else Color(tones[2]))
				elif rr > 12.0:
					c = Color(tones[3])
				else:
					c = Color(tones[5]) if (dy < -5.0 and dx < 0.0 and rr > 9.0) else Color(tones[4])
					if dy > 9.0:
						c = Color(tones[3])
			img.set_pixel(xx, yy, c)
	var out: ImageTexture = ImageTexture.create_from_image(img)
	tex_cache[key] = out
	return out

## The vehicle on the ground (land) or in orbit (ring), or what is left of it.
func _draw_vignette() -> void:
	var vx: float = 580.0
	var ground: float = 68.0
	var dim: Color = Color.WHITE if level > 0 else Color(0.32, 0.3, 0.34)
	var wreck: Vector2 = Vector2(vx, 40.0)
	if String(d.get("kind", "land")) == "ring":
		var pl: Texture2D = _ta("planet_%s_22" % dest_id)
		draw_texture(pl, Vector2(vx - 46.0 - pl.get_width() / 2.0 + 20.0, 36.0 - pl.get_height() / 2.0 + 10.0).floor(), dim)
		var bob: float = floorf(sin(t * 1.4) * 2.0)
		draw_texture(_tx("veh_orbiter"), Vector2(vx - 20.0, 12.0 + bob), dim)
		if level > 0:
			Fx.trail(self, Vector2(vx - 20.0, 30.0 + bob), Vector2.LEFT, 48.0, 3.0, t)
	else:
		var gt: Texture2D = _tx("ground_moon")
		var gx: float = 470.0
		var gmod: Color = GROUND_TINT.get(dest_id, Color.WHITE) as Color
		while gx < 640.0:
			draw_texture(gt, Vector2(gx, ground - 14.0), gmod)
			gx += gt.get_width()
		var lt: Texture2D = _tx("veh_lander")
		draw_texture(lt, Vector2(vx - 20.0, ground - 10.0 - lt.get_height()), dim)
		if level == 1:
			_img("ic_warn", Vector2(vx - 7.0, ground - 50.0 - floorf(absf(sin(t * 3.0)) * 3.0)))
	if level == 0 and boom_t > -1.0:
		Fx.explosion(self, wreck, t - boom_t, 1, 20.0)
		if t - boom_t > 0.5:
			for k: int in 3:
				var age: float = fposmod(t * 0.6 + k * 0.33, 1.0)
				Fx.puff(self, wreck + Vector2((k - 1) * 8.0, 8.0 - age * 30.0), age, 1, Color(0.5, 0.5, 0.55, 0.8), k)
	elif level == 2:
		for k: int in 2:
			var age2: float = fposmod(t * 0.7 + k * 0.5, 1.0)
			var spot: float = floorf(sin(k * 3.0 + floorf(t * 0.7 + k * 0.5)) * 6.0)
			Fx.sparkle(self, Vector2(vx - 28.0 + k * 52.0 + spot, 30.0 + k * 10.0), age2, Color("fff4b8"), 1)

## The mission patch (Moon, Mars, Saturn) or the planet in a medal-coloured frame.
func _draw_patch(pos: Vector2) -> void:
	if dest_id in ["moon", "mars", "saturn"]:
		draw_texture(_tx("patch_%s_%s" % [dest_id, metal]), pos.floor())
		return
	var accent: Color = {"gold": Color("ffd75e"), "silver": Color("c9d0e0"), "bronze": Color("d9945a"), "fail": Color("6a6a78")}[metal]
	Pix.panel(self, Rect2(pos, Vector2(64, 64)), accent, Color(0.02, 0.03, 0.07, 0.95))
	draw_texture(_ta("planet_%s_22" % dest_id), (pos + Vector2(8, 8)).floor(), Color.WHITE if level > 0 else Color(0.45, 0.42, 0.45))

func _goals_done() -> int:
	var n: int = 0
	for g: Array in goals:
		if bool(g[1]):
			n += 1
	return n

func _draw_tabs() -> void:
	var xs: Array = [8.0, 106.0, 204.0]
	var ws: Array = [96.0, 96.0, 118.0]
	for i: int in 3:
		var on: bool = i == _sec()
		var rc: Rect2 = Rect2(float(xs[i]), 75.0, float(ws[i]), 19.0)
		hits.append([rc, "sec%d" % i])
		Pix.frame(self, rc, "tab_sel" if on else "tab_normal", Color.WHITE if (on or hot == "sec%d" % i) else Color(0.8, 0.82, 0.9))
		var label: String = "%d %s" % [i + 1, SEC_NAMES[i]]
		Pix.text_c(self, rc.position.x + rc.size.x / 2.0, rc.position.y + 13.0, label, 10, UI.TEXT if on else UI.DIM)
	# the one line that says what to do
	var x: float = 336.0
	x += Pix.keycap(self, Vector2(x, 78), "LEFT") + 2.0
	x += Pix.keycap(self, Vector2(x, 78), "RIGHT") + 5.0
	Pix.text(self, Vector2(x, 88), "MORE PAGES", 10, UI.TEXT)
	Pix.text(self, Vector2(x + 72.0, 88), "PAGE %d / %d" % [page + 1, pages.size()], 10, UI.CYAN)

func _head(rect: Rect2, title: String) -> void:
	_nine(rect, "card", FRAME_M)
	Pix.title(self, rect.position + Vector2(10, 16), title, UI.CYAN, 1)
	_sep(rect.position.x + 8, rect.position.y + 21, rect.size.x - 16)

# ---------------------------------------------------------------- page 1: overview

func _draw_overview() -> void:
	# goals as a checklist
	var pg: Rect2 = Rect2(8, PAGE_Y, 310, 104)
	_head(pg, "MISSION GOALS")
	var rowh: float = minf(13.0, 76.0 / maxf(1.0, goals.size()))
	for k: int in goals.size():
		var rt: float = t - (_tl("goals") + 0.45 * k)
		var y: float = pg.position.y + 26.0 + k * rowh
		if rt < 0.0:
			Pix.text(self, Vector2(pg.position.x + 28, y + 10), String(goals[k][0]), 10, Color("3a4a7a"))
			continue
		var ok: bool = bool(goals[k][1])
		var pop: float = floorf(maxf(0.0, 1.0 - rt / 0.2) * 4.0)
		_img("ic_tick" if ok else "ic_cross", Vector2(pg.position.x + 10, y - pop))
		Pix.text(self, Vector2(pg.position.x + 28, y + 10), String(goals[k][0]), 10, UI.TEXT if ok else COL_RISK)
	# the lesson and the real thing
	var pl: Rect2 = Rect2(8, PAGE_Y + 108.0, 310, PAGE_H - 108.0)
	_head(pl, "THE LESSON")
	_lines(pl.position + Vector2(10, 33), lesson_lines, UI.TEXT)
	var ry: float = pl.position.y + 33.0 + lesson_lines.size() * 12.0 + 8.0
	Pix.text(self, Vector2(pl.position.x + 10, ry + 8), "THE REAL THING", 10, UI.CYAN)
	_sep(pl.position.x + 8, ry + 12, 294)
	_lines(Vector2(pl.position.x + 10, ry + 24), real_lines, UI.DIM)
	# the four scores
	var pr: Rect2 = Rect2(322, PAGE_Y, 310, PAGE_H)
	_head(pr, "THE FOUR SCORES")
	if Net.is_online() and Game.run.has("team_sync"):
		Pix.text(self, Vector2(pr.end.x - 115, pr.position.y + 14), "TEAM SYNC %d" % int(Game.run["team_sync"]), 10, UI.CYAN)
	var gk: float = clampf((t - maxf(_tl("roles"), page_t0)) / 0.9, 0.0, 1.0)
	var pitch: float = 45.0 if grade != "" else 51.0
	for i: int in score_rows.size():
		var row: Dictionary = score_rows[i]
		var y2: float = pr.position.y + 25.0 + i * pitch
		var v: int = int(row["value"])
		var col: Color = _score_col(v)
		Pix.icon(self, String(SCORE_ICON[row["key"]]), Vector2(pr.position.x + 10, y2))
		Pix.text(self, Vector2(pr.position.x + 26, y2 + 10), String(row["name"]), 10, UI.TEXT)
		var vs: String = "%d / 100" % roundi(v * gk)
		Pix.text(self, Vector2(pr.position.x + pr.size.x - 10.0 - Pix.text_w(vs, 10), y2 + 10), vs, 10, col)
		Pix.gauge(self, Rect2(pr.position.x + 10, y2 + 14, 290, 9), float(v) / 100.0 * gk, col)
		var tl: Array = row["lines"]
		for j: int in tl.size():
			Pix.text(self, Vector2(pr.position.x + 10, y2 + 35.0 + j * (10.0 if grade != "" else 12.0)), String(tl[j]), 10, UI.DIM)
	if grade != "":
		var gy: float = pr.position.y + 25.0 + 4.0 * pitch
		_sep(pr.position.x + 8, gy - 2, 294)
		for j: int in grade_rule_lines.size():
			Pix.text(self, Vector2(pr.position.x + 10, gy + 9.0 + j * 10.0), String(grade_rule_lines[j]), 10, UI.CYAN)

# ---------------------------------------------------------------- page 2: journey

func _draw_journey() -> void:
	var pg: Rect2 = Rect2(8, PAGE_Y, 624, PAGE_H)
	var pp: Dictionary = pages[page]
	_head(pg, "THE JOURNEY")
	var part: String = "PART %d OF %d" % [int(pp["n"]), int(pp["of"])]
	Pix.text(self, Vector2(pg.position.x + pg.size.x - 10.0 - Pix.text_w(part, 10), pg.position.y + 15), part, 10, UI.DIM)
	var top: float = pg.position.y + 26.0
	var items: Array = pp["items"]
	draw_rect(Rect2(19, top, 1, CONTENT_H - 4), LINE)   # the timeline spine
	var y: float = top
	for it: Dictionary in items:
		var h: int = int(it["h"])
		match String(it["k"]):
			"head":
				var ok: bool = bool(it["ok"])
				_img("ic_tick" if ok else "ic_cross", Vector2(12, y))
				Pix.title(self, Vector2(32, y + 12), String(it["name"]), UI.TEXT, 1)
			"line":
				var good: bool = bool(it["ok"])
				draw_rect(Rect2(28, y + 4, 3, 3), COL_WELL if good else COL_RISK)
				_lines(Vector2(36, y + 9), it["lines"], UI.TEXT if good else COL_RISK)
			"dec":
				_draw_decision(it, y)
		y += h

func _draw_decision(it: Dictionary, y: float) -> void:
	var dc: Dictionary = it["d"]
	var grade: String = String(dc.get("grade", "good"))
	var gcol: Color = COL_WELL if grade == "good" else (COL_WASTE if grade == "risky" else COL_RISK)
	var rc: Rect2 = Rect2(30, y + 1, 592, int(it["h"]) - 3)
	Pix.panel(self, rc, gcol, Color(0.03, 0.04, 0.08, 0.9))
	var x0: float = rc.position.x + 10.0
	var role: String = String(dc.get("role", "planner"))
	Pix.icon(self, String(ROLE_ICON.get(role, "clipboard")), Vector2(x0, rc.position.y + 5))
	Pix.title(self, Vector2(x0 + 16, rc.position.y + 15), String(dc.get("title", "")), UI.CYAN, 1)
	var gw: String = String(GRADE_WORD.get(grade, "CALL"))
	Pix.text(self, Vector2(rc.end.x - 10.0 - Pix.text_w(gw, 10), rc.position.y + 14), gw, 10, gcol)
	var rw: String = String(ROLE_NAME.get(role, ""))
	Pix.text(self, Vector2(rc.end.x - 20.0 - Pix.text_w(gw, 10) - Pix.text_w(rw, 10), rc.position.y + 14), rw, 10, UI.DIM)
	var ly: float = rc.position.y + 27.0
	_lines(Vector2(x0, ly), it["choice"], UI.TEXT)
	ly += (it["choice"] as Array).size() * 12.0
	_lines(Vector2(x0, ly), it["res"], gcol)
	ly += (it["res"] as Array).size() * 12.0
	_lines(Vector2(x0, ly), it["real"], UI.DIM)

# ---------------------------------------------------------------- page 3: build report

func _draw_build() -> void:
	var pg: Rect2 = Rect2(8, PAGE_Y, 624, PAGE_H)
	_head(pg, "BUILD REPORT")
	var n: int = build_rows.size()
	var sum: String = "%d of %d WELL USED" % [well_count, n]
	var scol: Color = COL_WELL if well_count >= n - 1 else (COL_WASTE if well_count * 2 >= n else COL_RISK)
	Pix.title(self, Vector2(pg.position.x + 150, pg.position.y + 16), sum, scol, 1)
	# legend, right
	var lx: float = pg.position.x + pg.size.x - 10.0
	var l3: String = "WHAT IT NEEDED"
	lx -= Pix.text_w(l3, 10)
	Pix.text(self, Vector2(lx, pg.position.y + 15), l3, 10, UI.DIM)
	draw_rect(Rect2(lx - 8, pg.position.y + 6, 1, 10), UI.CYAN)
	lx -= 18.0
	var l2: String = "YOUR SHIP"
	lx -= Pix.text_w(l2, 10)
	Pix.text(self, Vector2(lx, pg.position.y + 15), l2, 10, UI.DIM)
	draw_rect(Rect2(lx - 8, pg.position.y + 6, 3, 10), UI.TEXT)
	lx -= 18.0
	var l1: String = "WELL USED"
	lx -= Pix.text_w(l1, 10)
	Pix.text(self, Vector2(lx, pg.position.y + 15), l1, 10, UI.DIM)
	draw_rect(Rect2(lx - 14, pg.position.y + 6, 10, 10), Color(0.25, 0.8, 0.4, 0.8))
	var bk: float = clampf((t - maxf(_tl("panels"), page_t0)) / 0.6, 0.0, 1.0)
	for i: int in n:
		var row: Dictionary = build_rows[i]
		var u: Dictionary = row["u"]
		var ry: float = pg.position.y + 26.0 + i * 23.0
		var rating: String = String(u.get("rating", "well"))
		var state: String = String(u.get("state", "well"))
		var col: Color = _state_col(state)
		if i > 0:
			_sep(pg.position.x + 8, ry - 1, 608)
		Pix.icon(self, String(RES_ICON[row["key"]]), Vector2(pg.position.x + 10, ry + 1))
		Pix.text(self, Vector2(pg.position.x + 26, ry + 10), String(u.get("name", row["key"].to_upper())), 10, UI.TEXT)
		var unit: String = String(u.get("unit", ""))
		var have_type: bool = String(u.get("band_on", "have")) == "have"
		_band_gauge(Rect2(pg.position.x + 112, ry + 1, 180, 9), u, col, bk)
		var l_a: String = "need %s  have %s" if have_type else "uses %s  max %s"
		Pix.text(self, Vector2(pg.position.x + 112, ry + 20), l_a % [_val_text(float(u.get("need", 0.0)), unit), _val_text(float(u.get("have", 0.0)), unit)], 10, UI.DIM)
		var word: String = ("UNDER-USED" if rating == "under" else ("OVER-USED" if rating == "over" else "WELL USED"))
		if state != "well":
			word += ": RISKY" if state == "risk" else ": WASTED"
		Pix.text(self, Vector2(pg.position.x + 304, ry + 10), word, 10, col)
		var tl: Array = row["lines"]
		var ty: float = ry + (14.0 if tl.size() < 2 else 9.0)
		for j: int in tl.size():
			Pix.text(self, Vector2(pg.position.x + 412, ty + j * 10.0), String(tl[j]), 10, UI.TEXT if state != "well" else UI.DIM)
	_sep(pg.position.x + 8, pg.position.y + 26.0 + n * 23.0 - 1.0, 608)
	Pix.text(self, Vector2(pg.position.x + 10, pg.end.y - 7.0), "GREEN = THE NEED PLUS NASA/JPL MARGIN. ABOVE THE TOP OF THE GREEN COUNTS AS WASTE (GAME RULE).", 10, UI.DIM)

## A gauge with the green "well used" band, a pin where the ship was and a cyan tick for what the mission needed.
func _band_gauge(rc: Rect2, u: Dictionary, col: Color, k: float) -> void:
	var have_type: bool = String(u.get("band_on", "have")) == "have"
	var need: float = float(u.get("need", 0.0))
	var have: float = float(u.get("have", 0.0))
	var lo: float = float(u.get("lo", 0.0))
	var hi: float = float(u.get("hi", 0.0))
	var v: float = have if have_type else need
	var other: float = need if have_type else have
	var axis: float = maxf(maxf(hi * 1.3, v * 1.12), maxf(other * 1.12, 0.001))
	Pix.gauge(self, rc, 0.0)
	var inner: Rect2 = rc.grow(-2)
	var bx0: float = inner.position.x + floorf(inner.size.x * clampf(lo / axis, 0.0, 1.0))
	var bx1: float = inner.position.x + floorf(inner.size.x * clampf(hi / axis, 0.0, 1.0))
	draw_rect(Rect2(bx0, inner.position.y, maxf(1.0, bx1 - bx0), inner.size.y), Color(0.25, 0.8, 0.4, 0.8))
	draw_rect(Rect2(bx0, inner.position.y - 1, 1, inner.size.y + 2), COL_WELL)
	draw_rect(Rect2(bx1 - 1.0, inner.position.y - 1, 1, inner.size.y + 2), COL_WELL)
	var ox: float = inner.position.x + floorf((inner.size.x - 1.0) * clampf(other / axis, 0.0, 1.0))
	draw_rect(Rect2(ox, inner.position.y - 2, 1, inner.size.y + 4), UI.CYAN)
	var px: float = inner.position.x + floorf((inner.size.x - 3.0) * clampf(v / axis * k, 0.0, 1.0))
	draw_rect(Rect2(px - 1, inner.position.y - 2, 5, inner.size.y + 4), Color(0.02, 0.03, 0.07))
	draw_rect(Rect2(px, inner.position.y - 1, 3, inner.size.y + 2), UI.TEXT if col == COL_WELL else col)

# ---------------------------------------------------------------- bottom row

func _draw_bottom() -> void:
	_button(Rect2(8, 332, 118, 24), "menu", "MISSION SELECT", "btn_grey")
	_button(Rect2(130, 332, 86, 24), "tech", "TECH LAB", "btn_blue", "ic_flask")
	if t >= _tl("coins") - 0.2 and reward > 0:
		Pix.text(self, Vector2(222, 348), "+%d" % reward, 10, UI.YELLOW)
	var tot: String = str(roundi(shown_total))
	_img("ic_coin", Vector2(280, 332))
	Pix.title(self, Vector2(299, 350), tot, UI.YELLOW, 1)
	Pix.text(self, Vector2(299.0 + Pix.title_w(tot, 1) + 6.0, 348), "CREDITS", 10, UI.DIM)
	for cn: Dictionary in coins:
		var u: float = (t - float(cn["t0"])) / 0.55
		if u < 0.0 or u >= 1.0:
			continue
		var p: Vector2 = (cn["from"] as Vector2).lerp(cn["to"] as Vector2, u) + Vector2(0, -sin(u * PI) * 22.0)
		draw_texture(_tx("ic_coin"), (p - Vector2(7, 7)).floor())
	if page > 0:
		_button(Rect2(396, 332, 36, 24), "prev", "<", "btn_grey")
	if page < pages.size() - 1:
		_button(Rect2(436, 332, 36, 24), "next", ">", "btn_blue")
	_button(Rect2(476, 332, 156, 24), "again", "REDESIGN & FLY AGAIN", "btn_green", "ic_play")

# ---------------------------------------------------------------- debug (screenshots)

## Rebuilds the shown run from made-up pieces on top of the real one, without touching Game.run.
## lines: [phase id, ok, text]; vals: the four score values.
func _fake(goal_ok: Array, lines: Array, scr: int, rew: int, vals: Array, decs: Array = []) -> void:
	var f: Dictionary = r.duplicate(true)
	var fr: Dictionary = (rep.duplicate(true) as Dictionary)
	var obj: Dictionary = {}
	var objs: Array = []
	var names: Array = d["objectives"]
	for i: int in names.size():
		obj[String(names[i])] = bool(goal_ok[i]) if i < goal_ok.size() else false
		objs.append({"id": String(names[i]), "name": String(Data.OBJ_NAMES[names[i]]), "done": obj[String(names[i])]})
	f["obj"] = obj
	f["score"] = scr
	f["reward"] = rew
	var phases: Array = []
	for ln: Array in lines:
		if phases.is_empty() or phases[-1]["id"] != ln[0]:
			phases.append({"id": ln[0], "name": String(ln[0]).to_upper(), "ok": true, "lines": []})
		phases[-1]["lines"].append({"ok": ln[1], "text": ln[2]})
		if not bool(ln[1]):
			phases[-1]["ok"] = false
	var tips: Array = ["Every goal was met.", "Collect all samples.", "Fuel UNDER: add propellant until the bar is in the green band.", "Every call was sound."]
	var sc: Dictionary = {}
	for i: int in 4:
		var key: String = SCORE_KEYS[i]
		sc[key] = {"name": ["MISSION SUCCESS", "SCIENCE VALUE", "RESOURCE EFFICIENCY", "GOOD DECISIONS"][i], "value": vals[i], "tip": tips[i]}
	fr["phases"] = phases
	fr["objectives"] = objs
	fr["scores"] = sc
	fr["total"] = roundi((vals[0] * 2.0 + vals[1] + vals[2] + vals[3]) / 5.0)
	fr["credits"] = rew
	fr["decisions"] = decs
	fr.merge(fake_grade, true)
	f["report"] = fr
	_load(f)

func _fake_decs() -> Array:
	return [
		{"id": "storm", "title": "SOLAR STORM INCOMING", "phase": "cruise", "role": "engineer", "choice": "TURN TAIL TO THE STORM", "ok": true, "good": true, "grade": "good", "points": 100, "cost": "-8 kg fuel, +2 days", "text": "It worked. -8 kg fuel, +2 days."},
		{"id": "micro", "title": "MICROMETEOROID HIT", "phase": "cruise", "role": "engineer", "choice": "LIVE WITH IT", "ok": true, "good": false, "grade": "risky", "points": 70, "cost": "power x0.88", "text": "It worked. power x0.88. The power margin is thinner now."},
		{"id": "tipped", "title": "LANDER LEANS: NO SUN", "phase": "site", "role": "engineer", "choice": "WAIT FOR THE SUN", "ok": false, "good": false, "grade": "bad", "points": 15, "cost": "-40% battery", "text": "It went wrong. -40% battery."},
		{"id": "tank", "title": "TANK PRESSURE DROPS", "phase": "home", "role": "engineer", "choice": "VENT AND RESTART", "ok": true, "good": true, "grade": "good", "points": 100, "cost": "nothing", "text": "Done."},
	]

func _fake_log() -> Array:
	return [
		["launch", true, "LAUNCH. The rocket lifted 3,950 kg of ship."],
		["cruise", true, "Cruise: 3 days. Solar power 998 W, course corrections used 12 kg of fuel."],
		["cruise", true, "DECISION, SOLAR STORM INCOMING: TURN TAIL TO THE STORM. It worked. -8 kg fuel, +2 days."],
		["arrive", true, "Arrived at the Moon in 3 days and braked into orbit."],
		["landing", true, "TOUCHDOWN at 1.4 m/s (limit 4 m/s). 120 kg of fuel left."],
		["site", true, "Samples collected: 3 of 3."],
		["site", false, "DECISION, LANDER LEANS: NO SUN: WAIT FOR THE SUN. It went wrong. -40% battery."],
		["home", true, "The ascent stage lifted off and brought 3 samples back to Earth."],
	]

func debug_success() -> void:
	_fake([true, true, true, true, true, true], _fake_log(), 100, 160, [100, 92, 88, 85], _fake_decs())
	_skip()

func debug_partial() -> void:
	_fake([true, true, true, false, false], [
		["launch", true, "LAUNCH. The rocket lifted 3,950 kg of ship."],
		["landing", true, "TOUCHDOWN at 2.1 m/s (limit 4 m/s)."],
		["site", false, "Samples collected: 1 of 3. The battery ran out before the drill finished."],
		["home", false, "STRANDED. Battery at 12%: the game rule says the ascent needs 30%. No way home."]], 60, 80, [60, 33, 55, 70], _fake_decs().slice(0, 2))
	_skip()

func debug_fail() -> void:
	_fake([true, false, false, false, false], [
		["launch", true, "LAUNCH. The rocket lifted 3,950 kg of ship."],
		["arrive", false, "NOT ENOUGH FUEL to brake into orbit. Braking by 0.9 km/s needed 410 kg of fuel; you had 120 kg. The ship flew past the Moon."]], 20, 20, [20, 0, 35, 70])
	_skip()

func _grade_debug(g: String, txt: String) -> void:
	fake_grade = {"grade": g, "grade_text": txt, "grade_rule": "A: all goals, no waste. B: all goals. C: the mission just succeeds."}
	debug_success()
	fake_grade = {}

func debug_grade_a() -> void:
	_grade_debug("A", "Top grade: every goal met and every resource well used.")

func debug_grade_b() -> void:
	_grade_debug("B", "One step from A: keep the budget reserve and waste no mass.")

func debug_grade_c() -> void:
	_grade_debug("C", "To reach B, bring all the science home and make better calls.")

## Many decisions (a HARD flight): the journey grows to several pages.
func debug_many() -> void:
	var decs: Array = _fake_decs()
	decs.append_array(_fake_decs())
	_fake([true, true, true, true, true, true], _fake_log(), 100, 160, [100, 92, 88, 70], decs)
	_skip()

## A run with nothing in it: an old save or a jump with no report must not crash.
func debug_empty() -> void:
	_load({})
	_skip()

## Mixed ratings: under (risky), over (wasted), and the fixed limits too tight or too roomy.
func debug_mixed() -> void:
	var f: Dictionary = r.duplicate(true)
	var fr: Dictionary = f.get("report", {}) as Dictionary
	var b: Dictionary = fr.get("build", {}) as Dictionary
	b["fuel"].merge({"rating": "under", "state": "risk", "have": 120.0, "tip": "Add propellant until the bar is in the green band."}, true)
	b["power"].merge({"rating": "over", "state": "waste", "have": 3000.0, "tip": "More power than the ship uses: take a power part off."}, true)
	b["mass"].merge({"rating": "over", "state": "risk", "need": 11000.0, "tip": "Under 35% of the lift spare: lighter ship or bigger rocket."}, true)
	b["budget"].merge({"rating": "under", "state": "waste", "need": 150.0, "tip": "Money to spare: add science, it raises the score."}, true)
	b["comms"].merge({"rating": "under", "state": "risk", "have": 0.9, "tip": "Use a bigger antenna, or lighter instruments."}, true)
	_load(f)
	_go_page(pages.size() - 1)
	_skip()

func debug_overview() -> void:
	_go_page(0)
	_skip()

func debug_journey() -> void:
	_go_page(1)
	_skip()

func debug_journey2() -> void:
	_go_page(mini(2, pages.size() - 2))
	_skip()

func debug_journey3() -> void:
	_go_page(mini(3, pages.size() - 2))
	_skip()

func debug_build() -> void:
	_go_page(pages.size() - 1)
	_skip()

## Presses RIGHT twice, then 1, then clicks the BUILD REPORT tab: prints the page after each.
func debug_keys() -> void:
	for kc: int in [KEY_RIGHT, KEY_RIGHT, KEY_1, KEY_3, KEY_LEFT]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = kc as Key
		ev.pressed = true
		_input(ev)
		print("KEYS ", kc, " -> page ", page, " of ", pages.size(), " sec ", _sec())
	_activate("sec2")
	print("KEYS click tab 3 -> page ", page)
	_skip()

func debug_skip() -> void:
	_skip()

func debug_dump() -> void:
	print("DUMP ", JSON.stringify(rep.get("build", {})))
	print("DUMP pages ", pages.size(), " ", JSON.stringify(rep.get("phases", [])))
