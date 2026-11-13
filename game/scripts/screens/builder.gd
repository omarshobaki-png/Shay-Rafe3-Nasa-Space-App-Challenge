extends Control
## Ship builder, built like Kerbal Space Program's Vehicle Assembly Building.
## Left: the parts bin. Middle: the craft on its stand (drawn through ship_kit.gd) and the launch vehicle.
## Right: Mission Control's GO / NO-GO board with a plain-words hint (all of its logic is in preflight.gd).
## Pick a part, snap it on the craft, build until every station says GO, then launch.
##
## Layers, back to front: this node (hall, craft), `glow` (additive flashes), `front` (foreground art,
## panels), the buttons, `over` (part in the hand, floating numbers, help callouts, the launch poll).

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")
const Meta = preload("res://scripts/vab_meta.gd")
const Preflight = preload("res://scripts/preflight.gd")

const TABS: Array[String] = ["launcher", "power", "comms", "science", "landing", "robot", "return", "fuel", "protect"]
const TAB_ICON: Dictionary = {"launcher": "launcher", "power": "power", "comms": "comms", "science": "science",
	"landing": "landing", "robot": "robot", "return": "return", "fuel": "fuel", "protect": "shield"}
const TAB_HELP: Dictionary = {"launcher": "Rocket and flight path", "power": "Makes and stores power", "comms": "Talks to Earth",
	"science": "Instruments and the drill", "landing": "Gets you down in one piece", "robot": "Collects the samples",
	"return": "Brings samples home", "fuel": "For braking and landing", "protect": "Guards against solar storms"}
const GOALS: Dictionary = {"moon": "Land, drill 3 samples, fly them home", "mars": "Land, drill 4 samples, send data home",
	"saturn": "Catch 5 ring grains, send data home"}
const ROLE_SHORT: Dictionary = {"planner": "PLAN", "engineer": "ENGR", "science": "SCI", "comms": "COMM"}
const WORD: Dictionary = {"ok": "GO", "warn": "GO, LOW", "bad": "NO-GO"}
## Flat colours for parts and rockets that have no sprite yet.
const CAT_COL: Dictionary = {"core": Color("c9a227"), "power": Color("2b6fd6"), "comms": Color("e8ecff"), "science": Color("6dff8a"),
	"landing": Color("a0a8c0"), "robot": Color("ff9f43"), "return": Color("d8dce8"), "fuel": Color("8a94b8"), "protect": Color("4fd6ff")}
const LV_SIZE: Dictionary = {"electron": Vector2(12, 70), "falcon9": Vector2(22, 190), "vulcan": Vector2(34, 165), "heavy": Vector2(50, 195)}
const AUTO_ORDER: Array[String] = ["solar", "solar_lite", "rtg", "battery", "battery_hi", "lga", "mga", "hga", "ka", "recorder",
	"camera", "spectro", "mag", "dust", "drill", "legs", "airbags", "heatshield", "chute", "rover", "rover_big", "drone",
	"ascent", "shield", "prop"]

const HALL: Rect2 = Rect2(150, 24, 320, 336)
const BIN: Rect2 = Rect2(0, 24, 150, 336)
const BOARD: Rect2 = Rect2(470, 24, 170, 336)
const GRID: Vector2 = Vector2(24, 40)
const ROWS_Y: float = 54.0
const VIEW_TOP: float = 30.0
const POLL_STEP: float = 0.22
const SLIDE: float = 0.07          # a new part slides in for this long before it clicks on
const GO_STEP: float = 0.07        # the all-GO wave lights one lamp per step

class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

var tab: String = "launcher"       # open bin category (main.gd's debug hook sets it, then calls refresh)
var stations: Array = []
var top: Dictionary = {}           # the NO-GO to fix first, {} when none
var rows: Array[Rect2] = []
var rows_end: float = 0.0
var missing: Array = []            # [{"id", "slot"}]: parts a NO-GO station needs, outlined on the craft
var sel: String = ""               # tile in the detail card: part id, "rocket:<id>" or "path:<index>"
var sel_station: String = ""
var hover_tile: String = ""
var hover_part: Dictionary = {}    # ship kit item under the pointer
var hover_row: int = -1
var hand: String = ""              # part id in the hand
var hand_slot: Dictionary = {}
var hand_fx: String = ""
var snapped: bool = false
var mouse: Vector2 = Vector2(320, 200)
var t: float = 0.0
var idle: float = 0.0
var origin: Vector2 = Vector2.ZERO  # ship origin on screen, before pan
var kick: Vector2 = Vector2.ZERO    # the craft is shoved when a part clicks on, and springs back
var snap_t: float = 9.0            # seconds since the last part clicked on (the stand lights flash)
var go_wave: float = -1.0          # the all-GO moment: seconds since it began, -1 when it is not running
var go_lit: int = 0                # lamps lit by the wave so far
var go_done: bool = false
var puffs: Array = []
var leavers: Array = []            # parts flying back to the bin
var fuzz: int = 0                  # debug_stress: frames of random input left
var fuzz_rng: RandomNumberGenerator = null
var lv_drop: float = 0.0
var lv_top: float = 100.0
var pan: float = 0.0
var pan_to: float = 0.0
var x10: bool = false
var help: bool = false
var pulse: Dictionary = {}         # tiles that fix the problem being shown: tile -> 1 add, -1 take off
var top_fix: Dictionary = {}       # the same for the first open problem (the red marks in the bin)
var pulse_t: float = 0.0
var blink: Dictionary = {}         # station id -> seconds left
var flashes: Array = []
var floats: Array = []
var sparks: Array = []
var flyers: Array = []
var queue: Array = []              # auto-build: [id, n] still to fly
var auto: bool = false
var auto_target: Dictionary = {}
var poll: Dictionary = {}          # {"i", "t", "phase": call | go | nogo}
var undo_stack: Array = []
var redo_stack: Array = []
var hint: Dictionary = {}

var tex_bg: Texture2D = null
var tex_fg: Texture2D = null
var tex_beacon: Texture2D = null
var tex_fork: Texture2D = null
var tex_cache: Dictionary = {}     # icons and launch vehicles, kept so they are never freed
var para_font: FontVariation = null
var extras: Dictionary = {}

var glow: Layer = null
var front: Layer = null
var over: Layer = null
var b_undo: Button = null
var b_redo: Button = null
var b_auto: Button = null
var b_launch: Button = null
var b_show: Button = null
var b_minus: Button = null
var b_plus: Button = null
var b_x10: Button = null
var b_fill: Button = null
var b_fix: Button = null
var b_anyway: Button = null
var b_go: Button = null            # the big launch button in the hint box, when every station is GO

# ---------------------------------------------------------------- setup

func _ready() -> void:
	extras = (Meta as Script).get_script_constant_map()
	tex_bg = _load("res://art/vab/bg.png")
	tex_fg = _load(String(extras.get("FG", "res://art/vab/fg.png")))
	tex_beacon = _load(String(extras.get("BEACON_SHEET", "")))
	tex_fork = _load(String(extras.get("FORKLIFT", "")))
	para_font = FontVariation.new()
	para_font.base_font = Pix.font()
	para_font.spacing_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	glow = _layer(_paint_glow)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	front = _layer(_paint_front)
	_btn(self, "< MENU", _menu, Rect2(2, 3, 48, 17))
	b_undo = _btn(self, "UNDO", _undo, Rect2(348, 3, 36, 17))
	b_redo = _btn(self, "REDO", _redo, Rect2(386, 3, 36, 17))
	b_auto = _btn(self, "AUTO-BUILD", _auto_build, Rect2(426, 3, 72, 17))
	var hb: Button = UI.icon_button("help", "", _toggle_help)
	_place(self, hb, Rect2(500, 3, 24, 17))
	b_launch = _btn(self, "LAUNCH", _start_poll, Rect2(526, 1, 112, 22))
	b_minus = _btn(self, "-", _minus, Rect2(24, 104, 18, 17))
	b_plus = _btn(self, "+", _plus, Rect2(86, 104, 18, 17))
	b_x10 = _btn(self, "x10", _toggle_x10, Rect2(111, 104, 36, 17))
	b_x10.toggle_mode = true
	b_fill = _btn(self, "FILL TO NEED", _fill, Rect2(24, 123, 123, 17))
	b_show = _btn(self, "SHOW ME", _show_me, Rect2(580, 300, 56, 17))
	b_go = UI.go_button("GO FOR LAUNCH", _start_poll, 10, 150)
	_place(self, b_go, Rect2(BOARD.position.x + 8, 334, BOARD.size.x - 16, 20))
	over = _layer(_paint_over)
	over.gui_input.connect(_over_input)
	b_fix = UI.go_button("FIX IT", _poll_fix, 10, 90)
	_place(over, b_fix, Rect2(0, 0, 90, 17))
	b_anyway = UI.danger_button("LAUNCH ANYWAY", _launch, 10, 100)
	_place(over, b_anyway, Rect2(0, 0, 100, 17))
	origin = Vector2(Meta.STAND_TOP.x, Meta.STAND_TOP.y - ShipKit.bounds(Game.build).end.y)
	help = Game.build.size() <= 1
	refresh()
	_open_fix_tab()

## Opens the bin on the tab that fixes the first open problem.
func _open_fix_tab() -> void:
	for tile: String in _fix_tiles(top):
		tab = _tab_of(tile)
		sel = tile
		refresh()
		break

func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null

func _layer(paint: Callable) -> Layer:
	var l: Layer = Layer.new()
	l.paint = paint
	l.size = Vector2(640, 360)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _place(parent: Node, b: Button, r: Rect2) -> void:
	parent.add_child(b)
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE

func _btn(parent: Node, text: String, cb: Callable, r: Rect2) -> Button:
	var b: Button = UI.button(text, cb)
	_place(parent, b, r)
	return b

# ---------------------------------------------------------------- bin model

func _tiles(tb: String) -> Array[String]:
	var out: Array[String] = []
	if tb == "launcher":
		for id: String in Data.ROCKETS:
			out.append("rocket:" + id)
		for i: int in (Game.dest()["traj"] as Array).size():
			out.append("path:%d" % i)
	else:
		for id: String in Data.PARTS:
			if Data.PARTS[id]["cat"] == tb:
				out.append(id)
	return out

func _tab_of(tile: String) -> String:
	if tile.begins_with("rocket:") or tile.begins_with("path:"):
		return "launcher"
	var cat: String = Data.PARTS[tile]["cat"] if Data.PARTS.has(tile) else ""
	return cat if TABS.has(cat) else tab

func _is_part(tile: String) -> bool:
	return Data.PARTS.has(tile)

## "ok", "lock" (Tech Lab), "off" (not for this destination), "max" (no more fit).
func _state(tile: String) -> String:
	if tile.begins_with("rocket:"):
		return "ok" if (Data.ROCKETS[tile.substr(7)]["cap"] as Dictionary).has(Game.dest_id) else "off"
	if not _is_part(tile):
		return "ok"
	var p: Dictionary = Data.PARTS[tile]
	if p.has("dest") and p["dest"] != Game.dest_id:
		return "off"
	if p.has("tech") and not Game.tech.has(p["tech"]):
		return "lock"
	return "max" if Game.count(tile) >= int(p["max"]) else "ok"

func _tab_rect(i: int) -> Rect2:
	return Rect2(2, 28 + i * 17, 20, 16)

func _tile_rect(i: int) -> Rect2:
	return Rect2(GRID.x + (i % 4) * 31, GRID.y + floorf(i / 4.0) * 31, 30, 30)

func _tile_at(pos: Vector2) -> String:
	var ids: Array[String] = _tiles(tab)
	for i: int in ids.size():
		if _tile_rect(i).has_point(pos):
			return ids[i]
	return ""

## Fuel moves ten units at a time with Shift or the x10 toggle.
func _step(id: String) -> int:
	return 10 if id == "prop" and (x10 or Input.is_key_pressed(KEY_SHIFT)) else 1

func _icon(tile: String) -> Texture2D:
	if not tex_cache.has(tile):
		var tex: Texture2D = null
		if tile.begins_with("rocket:"):
			tex = ShipKit.launcher_icon(tile.substr(7))
		elif _is_part(tile):
			tex = ShipKit.icon(tile)
		tex_cache[tile] = tex
	return tex_cache[tile]

func _lv(rocket: String) -> Texture2D:
	var key: String = "lv:" + rocket
	if not tex_cache.has(key):
		tex_cache[key] = ShipKit.launcher(rocket)
	return tex_cache[key]

# ---------------------------------------------------------------- state changes

func _snap() -> Dictionary:
	return {"build": Game.build.duplicate(), "rocket": Game.rocket_id, "traj": Game.traj_idx}

func _commit() -> void:
	if auto:
		return
	undo_stack.append(_snap())
	if undo_stack.size() > 200:
		undo_stack.pop_front()
	redo_stack.clear()

func _restore(s: Dictionary) -> void:
	var was: float = float(Game.calc()["mass"])
	Game.build = (s["build"] as Dictionary).duplicate()
	Game.rocket_id = s["rocket"]
	Game.traj_idx = s["traj"]
	Game.signed = {}
	hand = ""
	Audio.play("part_snap" if float(Game.calc()["mass"]) > was else "part_remove", -4.0)
	refresh()

func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snap())
	_restore(undo_stack.pop_back())

func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snap())
	_restore(redo_stack.pop_back())

func _menu() -> void:
	Game.goto("menu")

func _deny(text: String) -> void:
	Audio.play("part_deny")
	floats.append({"pos": mouse + Vector2(0, -8), "text": text, "age": 0.0, "col": UI.RED, "ship": false})

func _take(id: String) -> void:
	sel = id
	tab = _tab_of(id)
	var st: String = _state(id)
	if st != "ok":
		hand = ""
		_deny({"lock": "LOCKED: TECH LAB", "off": "NOT FOR THIS TRIP", "max": "NO MORE FIT"}[st])
		refresh()
		return
	hand = id
	Audio.play("part_pick")
	refresh()

func _put_away() -> void:
	if hand == "":
		return
	hand = ""
	Audio.play("ui_close", -4.0)
	refresh()

func _choose(tile: String) -> void:
	hand = ""
	if tile.begins_with("rocket:"):
		var id: String = tile.substr(7)
		if _state(tile) != "ok":
			_deny("CANNOT REACH %s" % Game.place())
			refresh()
			return
		if id != Game.rocket_id:
			_commit()
			Game.rocket_id = id
			lv_drop = 16.0
			Audio.play("part_snap", -1.0, 0.75)
	else:
		var i: int = int(tile.substr(5))
		if i != Game.traj_idx:
			_commit()
			Game.traj_idx = i
			Audio.play("confirm", -4.0)
	Game.signed = {}
	refresh()

## Adds n of a part to the craft, with the snap effects. Returns false when it cannot be added.
func _attach(id: String, n: int) -> bool:
	var slot: Dictionary = ShipKit.next_slot(Game.build, id)
	if slot.is_empty() or not Game.part_available(id):
		_deny("NO MORE FIT")
		return false
	var text: String = _effect_text(id, n)
	_commit()
	Game.add_part(id, n)
	# the part slides the last pixels toward its attach node, then clicks on (_impact)
	var away: Vector2 = (slot["rect"] as Rect2).get_center() - Vector2(slot["node"])
	var dir: Vector2 = Vector2(signf(away.x), 0) if absf(away.x) > absf(away.y) else Vector2(0, signf(away.y))
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	flashes.append({"slot": slot, "age": 0.0, "id": id, "dir": dir, "hit": false, "n": n})
	if not auto:
		floats.append({"pos": slot["node"], "text": text, "age": 0.0, "col": UI.GREEN, "ship": true})
	refresh()
	return true

## The moment a new part clicks on: shove, sparks, sound.
func _impact(f: Dictionary) -> void:
	f["hit"] = true
	var dir: Vector2 = f["dir"]
	var heavy: float = clampf(float(Data.PARTS[f["id"]]["mass"]) * int(f["n"]) / 300.0, 0.0, 1.0)
	kick = Vector2(-dir.x * (2.0 + heavy), -2.0 - heavy if dir.x == 0.0 else 0.0)
	snap_t = 0.0
	for i: int in 6 + int(heavy * 6.0):
		sparks.append({"pos": f["slot"]["node"], "vel": Vector2(randf_range(-70, 70), randf_range(-90, -10)) - dir * 30.0, "age": 0.0})
	Audio.play("part_snap", -5.0 if auto else 0.0, clampf(1.2 - float(Data.PARTS[f["id"]]["mass"]) / 700.0, 0.75, 1.2))

## Takes n of a part off the craft; to_hand keeps it in the hand so it can go back on.
func _remove(id: String, n: int, to_hand: bool) -> void:
	if Game.count(id) == 0:
		return
	if Data.PARTS[id].get("locked_in", false):
		sel = id
		_deny("THE BUS STAYS")
		return
	var at: Vector2 = Vector2.ZERO
	var last: Dictionary = {}
	for it: Dictionary in ShipKit.layout(Game.build):
		if it["id"] == id:
			at = (it["box"] as Rect2).get_center()
			last = it
	var text: String = _effect_text(id, -n)
	_commit()
	Game.add_part(id, -n)
	floats.append({"pos": at, "text": text, "age": 0.0, "col": UI.ORANGE, "ship": true})
	puffs.append({"pos": at, "age": 0.0})
	Audio.play("part_remove")
	sel = id
	tab = _tab_of(id)
	hand = id if to_hand else ""
	if not to_hand and not last.is_empty() and not auto:
		var idx: int = _tiles(tab).find(id)
		leavers.append({"id": id, "slot": {"rect": last["box"], "pos": last["pos"], "tex": last["tex"], "flip": last["flip"]},
			"from": _org() + at, "to": _tile_rect(maxi(idx, 0)).get_center(), "age": 0.0})
	refresh()

## A part flies from the bin to its slot by itself (double-click, the "+" button, auto-build).
func _fly(id: String, n: int, dur: float = 0.22) -> void:
	var slot: Dictionary = ShipKit.next_slot(Game.build, id)
	if slot.is_empty() or _state(id) != "ok":
		_deny("NO MORE FIT" if _state(id) == "max" else "NOT AVAILABLE")
		return
	var from: Vector2 = Vector2(75, 70)
	var idx: int = _tiles(tab).find(id)
	if idx >= 0:
		from = _tile_rect(idx).get_center()
	flyers.append({"id": id, "n": n, "from": from, "slot": slot, "age": 0.0, "dur": dur})

func _minus() -> void:
	if _is_part(sel):
		_remove(sel, _step(sel), false)

func _plus() -> void:
	if _is_part(sel):
		hand = ""
		_fly(sel, _step(sel))

func _toggle_x10() -> void:
	x10 = b_x10.button_pressed

## Sets the fuel to what the FUEL station needs for a green lamp. The need follows the dry mass only,
## so one pass is enough.
func _fill() -> void:
	var c: Dictionary = Game.calc()
	var want: int = mini(ceili(float(c["prop_need"]) * (1.0 + float(Game.dest()["margin"])) / 100.0), int(Data.PARTS["prop"]["max"]))
	var n: int = want - Game.count("prop")
	sel = "prop"
	hand = ""
	if n > 0:
		_attach("prop", n)
	elif n < 0:
		_remove("prop", -n, false)
	else:
		_deny("ALREADY RIGHT")

## The signature moment: the last NO-GO is gone. The board lights up lamp by lamp, then LAUNCH wakes up.
func _go_moment() -> void:
	go_wave = 0.0
	go_lit = 0
	go_done = false

func _toggle_help() -> void:
	help = not help
	Audio.play("ui_open" if help else "ui_close")

## What fixes a station and can be done now, best first: bin tiles to add or choose, "-<part id>" to take off.
func _fixes(s: Dictionary) -> Array:
	return (s.get("fix", []) as Array).filter(func(f: String) -> bool:
		if f.begins_with("-"):
			return Game.count(f.substr(1)) > 0
		return _state(f) == "ok" and f != "rocket:" + Game.rocket_id and f != "path:%d" % Game.traj_idx)

## The same as bin tiles: tile -> 1 (add or choose it) or -1 (take it off).
func _fix_tiles(s: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for f: String in _fixes(s):
		# one clear instruction: either the first part to take off, or the parts and rockets that would fix it
		if f.begins_with("-") and out.is_empty():
			return {f.substr(1): -1}
		if not f.begins_with("-"):
			out[f] = 1
	return out

func _show_me() -> void:
	var s: Dictionary = {}
	for st: Dictionary in stations:
		if st["id"] == hint.get("id", ""):
			s = st
	if s.is_empty():
		return
	pulse = _fix_tiles(s)
	pulse_t = 8.0
	hand = ""
	for tile: String in pulse:
		sel = tile
		tab = _tab_of(tile)
		break
	Audio.play("ui_tab")
	refresh()

func _auto_build() -> void:
	if auto:
		_auto_finish()
		return
	_commit()
	Game.example_build()
	auto_target = _snap()
	Game.build = {"bus": 1}
	auto = true
	help = false
	hand = ""
	lv_drop = 16.0
	queue.clear()
	var want: Dictionary = auto_target["build"]
	for id: String in AUTO_ORDER:
		var left: int = int(want.get(id, 0))
		var chunk: int = 4 if id == "prop" else 1
		while left > 0:
			queue.append([id, mini(chunk, left)])
			left -= chunk
	refresh()

func _auto_finish() -> void:
	Game.build = (auto_target["build"] as Dictionary).duplicate()
	queue.clear()
	flyers.clear()
	auto = false
	Audio.play("part_snap")
	snap_t = 0.0
	refresh()
	if top.is_empty():
		_go_moment()

# ---------------------------------------------------------------- launch poll

func _start_poll() -> void:
	if not poll.is_empty():
		return
	hand = ""
	help = false
	poll = {"i": -1, "t": 0.0, "phase": "call"}
	Audio.play("ui_open")
	refresh()

func _poll_end() -> void:
	poll["i"] = stations.size() - 1
	if top.is_empty():
		poll["phase"] = "go"
		poll["t"] = 0.0
		for r: Dictionary in Data.ROLES:
			Game.signed[r["id"]] = true
		Audio.play("all_go")
	else:
		poll["phase"] = "nogo"
		Audio.play("poll_nogo")
	refresh()

func _poll_fix() -> void:
	poll = {}
	sel_station = ""
	Audio.play("ui_close")
	_layout_hint()
	_show_me()

func _launch() -> void:
	Game.start_run()
	Game.run["mode"] = "out"
	Game.goto("flight")

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if not TABS.has(tab):
		tab = "launcher"
	if sel == "" or _tab_of(sel) != tab:
		sel = "rocket:" + Game.rocket_id if tab == "launcher" else _tiles(tab)[0]
	var before: Dictionary = {}
	for s: Dictionary in stations:
		before[s["id"]] = [s["status"], s["value"]]
	var was_go: bool = top.is_empty()
	stations = Preflight.stations()
	top = Preflight.top(stations)
	top_fix = _fix_tiles(top)
	rows.clear()
	var y: float = ROWS_Y
	for s: Dictionary in stations:
		var h: float = 20.0 if float(s["frac"]) >= 0.0 else 11.0
		rows.append(Rect2(BOARD.position.x + 3, y, BOARD.size.x - 6, h))
		y += h + 1.0
	rows_end = y
	missing.clear()
	var seen: Dictionary = {}
	for s: Dictionary in stations:
		if s["status"] != "bad":
			continue
		for id: String in s["need"]:
			if seen.has(id) or not _is_part(id) or not Game.part_available(id):
				continue
			seen[id] = true
			var slot: Dictionary = ShipKit.next_slot(Game.build, id)
			if slot.is_empty():
				continue
			# the socket mark sits on the attach node; marks never cover each other
			var at: Vector2 = slot["node"]
			var moved: bool = true
			while moved:
				moved = false
				for m: Dictionary in missing:
					if absf(Vector2(m["at"]).x - at.x) < 12.0 and absf(Vector2(m["at"]).y - at.y) < 12.0:
						at.x = Vector2(m["at"]).x + 12.0
						moved = true
			missing.append({"id": id, "slot": slot, "at": at})
	# what changed on the board: blink the rows, one sound for the whole change
	var better: bool = false
	var worse: bool = false
	for s: Dictionary in stations:
		if not before.has(s["id"]):
			continue
		var b: Array = before[s["id"]]
		if b[0] != s["status"] or b[1] != s["value"]:
			blink[s["id"]] = 0.5
		var d: int = int(Preflight.RANK[s["status"]]) - int(Preflight.RANK[b[0]])
		better = better or d < 0
		worse = worse or d > 0
	if not before.is_empty() and not auto and poll.is_empty():
		if top.is_empty() and not was_go:
			_go_moment()
		elif worse:
			Audio.play("station_nogo", -3.0)
		elif better:
			Audio.play("station_go", -3.0)
	if hand != "" and _state(hand) != "ok":
		hand = ""
	hand_slot = ShipKit.next_slot(Game.build, hand) if hand != "" else {}
	hand_fx = _effect_text(hand, _step(hand)) if hand != "" else ""
	# buttons
	var bad: int = Preflight.count(stations, "bad")
	b_launch.text = "GO FOR LAUNCH" if bad == 0 else "LAUNCH: %d NO-GO" % bad
	UI.color_button(b_launch, UI.GREEN if bad == 0 else UI.ORANGE)
	b_undo.disabled = undo_stack.is_empty()
	b_redo.disabled = redo_stack.is_empty()
	b_auto.text = "SKIP" if auto else "AUTO-BUILD"
	var part_sel: bool = _is_part(sel) and _tab_of(sel) == tab and not bool(Data.PARTS[sel].get("locked_in", false))
	b_minus.visible = part_sel
	b_plus.visible = part_sel
	if part_sel:
		b_minus.disabled = Game.count(sel) == 0
		b_plus.disabled = _state(sel) != "ok"
	b_x10.visible = tab == "fuel"
	b_fill.visible = tab == "fuel"
	if not top.is_empty():
		go_wave = -1.0
	b_go.visible = top.is_empty() and poll.is_empty() and not auto
	b_fix.visible = String(poll.get("phase", "")) == "nogo"
	b_anyway.visible = b_fix.visible
	over.mouse_filter = Control.MOUSE_FILTER_STOP if auto or not poll.is_empty() else Control.MOUSE_FILTER_IGNORE
	_layout_hint()

## The station the hint box talks about: the one clicked or hovered, else the top problem.
func _shown() -> Dictionary:
	var want: String = sel_station
	if hover_row >= 0 and hover_row < stations.size():
		want = String(stations[hover_row]["id"])
	for s: Dictionary in stations:
		if s["id"] == want:
			return s
	return top

func _layout_hint() -> void:
	var s: Dictionary = _shown()
	var w: float = BOARD.size.x - 14.0
	var h: Dictionary = {"title": "ALL STATIONS GO", "col": UI.GREEN, "body": "Every lamp is green. Mission Control is ready for the launch poll.", "fact": "", "fix": false, "id": ""}
	if s.is_empty():
		for st: Dictionary in stations:
			if st["status"] == "warn" and h["id"] == "":
				h["body"] = "Ready! To make it safer:"
				h["fact"] = "%s. %s" % [st["name"], st["headline"]]
				h["fix"] = not _fixes(st).is_empty()
				h["id"] = st["id"]
	else:
		h["id"] = s["id"]
		h["title"] = "%s: %s" % [s["name"], WORD[s["status"]]]
		h["col"] = UI.status_color(s["status"])
		h["body"] = ("%s %s" % [s["headline"], s["explain"]]).strip_edges()
		h["fix"] = not _fixes(s).is_empty()
		if sel_station != "" or hover_row >= 0:
			h["fact"] = s["fact"]
	var need: float = 4.0 + 17.0 + _para_h(h["body"], w) + 5.0
	if h["fact"] != "":
		need += _para_h(h["fact"], w) + 4.0
	if s.is_empty():
		need += 24.0   # the launch button
	var y0: float = minf(rows_end + 2.0, 358.0 - need)
	if y0 < rows_end:
		# a long explanation covers the lowest rows: start it on a row edge, never through a row
		for i: int in range(rows.size() - 1, -1, -1):
			if rows[i].position.y - 1.0 <= y0:
				y0 = rows[i].position.y - 1.0
				break
	h["rect"] = Rect2(BOARD.position.x + 2, y0, BOARD.size.x - 4, 358.0 - y0)
	hint = h
	b_show.visible = bool(h["fix"]) and poll.is_empty()
	b_show.position = Vector2(BOARD.end.x - 62, y0 + 3)

# ---------------------------------------------------------------- frame

func _org() -> Vector2:
	return (origin + kick + Vector2(0, pan)).round()

func _part_at(pos: Vector2) -> Dictionary:
	var p: Vector2 = pos - _org()
	var items: Array = ShipKit.layout(Game.build)
	for i: int in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		if _is_part(it["id"]) and (it["rect"] as Rect2).has_point(p):
			return it
	return {}

func _lv_rect() -> Rect2:
	return Rect2(Meta.LAUNCHER_BASE.x - 30, lv_top, 60, Meta.LAUNCHER_BASE.y + pan - lv_top)

func _update_hand() -> void:
	snapped = false
	if hand == "" or hand_slot.is_empty():
		return
	var zone: Rect2 = ShipKit.bounds(Game.build).merge(hand_slot["rect"]).grow(30)
	var org: Vector2 = _org()
	snapped = HALL.has_point(mouse) and (zone.has_point(mouse - org) or mouse.distance_to(org + Vector2(hand_slot["node"])) < 44.0)

func _process(delta: float) -> void:
	t += delta
	idle += delta
	# the craft stands on the stand; it rises to make room for a part held under it
	var b: Rect2 = ShipKit.bounds(Game.build)
	if hand != "" and not hand_slot.is_empty():
		b = b.merge(hand_slot["rect"])
	var k: float = 1.0 - exp(-14.0 * delta)
	var target_y: float = Meta.STAND_TOP.y - b.end.y
	origin = Vector2(Meta.STAND_TOP.x, lerpf(origin.y, target_y, k))
	# pan: a tall craft slides down so the slot being filled stays in view
	var max_pan: float = maxf(0.0, VIEW_TOP - (target_y + b.position.y))
	if hand != "" and not hand_slot.is_empty():
		var r: Rect2 = hand_slot["rect"]
		pan_to = maxf(pan_to, VIEW_TOP + 8.0 - (target_y + r.position.y))
		pan_to = minf(pan_to, maxf(0.0, 340.0 - (target_y + r.end.y)))
	pan_to = clampf(pan_to, 0.0, max_pan)
	pan = lerpf(pan, pan_to, k)
	kick = kick.move_toward(Vector2.ZERO, 30.0 * delta)
	snap_t += delta
	for f: Dictionary in flashes:
		if not f["hit"] and float(f["age"]) + delta >= SLIDE:
			_impact(f)
	_go_tick(delta)
	if fuzz > 0:
		_fuzz_step()
	lv_drop = move_toward(lv_drop, 0.0, 90.0 * delta)
	_update_hand()
	for id: String in blink.keys():
		blink[id] = float(blink[id]) - delta
		if float(blink[id]) <= 0.0:
			blink.erase(id)
	if pulse_t > 0.0:
		pulse_t -= delta
		if pulse_t <= 0.0:
			pulse.clear()
	# nothing done for a while and something is NO-GO: point at the tiles that fix it
	if idle > 6.0 and pulse.is_empty() and not top.is_empty() and hand == "" and poll.is_empty() and not auto and not help:
		pulse = _fix_tiles(top)
		pulse_t = 4.0
		idle = 0.0
	for pair: Array in [[flashes, SLIDE + 0.2], [floats, 1.1], [sparks, 0.4], [puffs, 0.35], [leavers, 0.2]]:
		var list: Array = pair[0]
		for i: int in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[i]
			e["age"] = float(e["age"]) + delta
			if float(e["age"]) > float(pair[1]):
				list.remove_at(i)
	for f: Dictionary in flyers:
		f["age"] = float(f["age"]) + delta
	while not flyers.is_empty() and float(flyers[0]["age"]) >= float(flyers[0]["dur"]):
		var f: Dictionary = flyers.pop_front()
		_attach(f["id"], f["n"])
	if auto and flyers.is_empty():
		if queue.is_empty():
			auto = false
			refresh()
			if top.is_empty():
				_go_moment()
		else:
			var q: Array = queue.pop_front()
			sel = q[0]
			tab = _tab_of(sel)
			_fly(q[0], q[1], 0.11)
			refresh()
	if not poll.is_empty():
		_poll_tick(delta)
	var glowing: Color = Color.WHITE.lerp(Color(1.25, 1.25, 1.25), 0.5 + 0.5 * sin(t * 5.0))
	if go_wave >= 0.0:   # dark while the lamps come on, then a flash
		var since: float = go_wave - stations.size() * GO_STEP
		glowing = Color(0.55, 0.55, 0.55) if since < 0.0 else Color.WHITE.lerp(Color(2.2, 2.2, 2.2), clampf(1.0 - since / 0.5, 0.0, 1.0))
	b_launch.modulate = glowing if top.is_empty() else Color.WHITE
	b_go.modulate = b_launch.modulate
	var beat: float = 0.5 + 0.5 * sin(t * 9.0)
	var want: int = int(pulse.get(sel, 0))
	b_plus.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.0), beat) if want > 0 and sel != "prop" else Color.WHITE
	b_minus.modulate = Color.WHITE.lerp(Color(1.8, 1.3, 0.9), beat) if want < 0 and sel != "prop" else Color.WHITE
	b_fill.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.0), beat) if want != 0 and sel == "prop" else Color.WHITE
	_layout_hint()
	queue_redraw()
	glow.queue_redraw()
	front.queue_redraw()
	over.queue_redraw()

func _go_tick(delta: float) -> void:
	if go_wave < 0.0:
		return
	go_wave += delta
	while go_lit < stations.size() and go_wave >= (go_lit + 1) * GO_STEP:
		Audio.play("poll_blip", -9.0, 0.9 + 0.05 * go_lit)
		go_lit += 1
	if not go_done and go_lit >= stations.size():
		go_done = true
		Audio.play("all_go")
	if go_wave > stations.size() * GO_STEP + 1.4:
		go_wave = -1.0

func _poll_tick(delta: float) -> void:
	if poll.get("freeze", false):
		return
	poll["t"] = float(poll["t"]) + delta
	if poll["phase"] == "call":
		var idx: int = int(float(poll["t"]) / POLL_STEP)
		if idx >= stations.size():
			_poll_end()
		elif idx > int(poll["i"]):
			poll["i"] = idx
			var bad: bool = stations[idx]["status"] == "bad"
			Audio.play("poll_blip", -2.0, 0.8 if bad else 1.0 + 0.02 * idx)
	elif poll["phase"] == "go" and float(poll["t"]) > 1.3:
		_launch()

# ---------------------------------------------------------------- input

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		help = false   # the callouts go at the first click, wherever it lands
	if ev is InputEventMouseMotion:
		mouse = (ev as InputEventMouseMotion).position
		_hover()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var key: InputEventKey = ev
		idle = 0.0
		if poll.get("phase", "") == "nogo" and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			_poll_fix()
		elif key.keycode == KEY_ESCAPE:
			if not poll.is_empty():
				poll = {}
				refresh()
			elif help:
				help = false
			else:
				_put_away()
		elif key.ctrl_pressed and key.keycode == KEY_Z and poll.is_empty() and not auto:
			_undo()
		elif key.ctrl_pressed and key.keycode == KEY_Y and poll.is_empty() and not auto:
			_redo()
		elif key.keycode == KEY_SHIFT and hand == "prop":
			refresh()
	if ev is InputEventKey and not (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_SHIFT and hand == "prop":
		refresh()

func _hover() -> void:
	var ht: String = ""
	var row: int = -1
	var was_on: String = String(hover_part.get("id", ""))
	hover_part = {}
	if not poll.is_empty() or auto:
		pass
	elif BIN.has_point(mouse):
		ht = _tile_at(mouse)
	elif BOARD.has_point(mouse):
		for i: int in rows.size():
			if rows[i].grow(0.5).has_point(mouse):
				row = i
	elif hand == "":
		hover_part = _part_at(mouse)
		if not hover_part.is_empty() and hover_part["id"] != was_on:
			Audio.play("ui_hover", -12.0)
		# a missing part's socket or outline shows that part's card
		var org: Vector2 = _org()
		for m: Dictionary in missing:
			var r: Rect2 = m["slot"]["rect"]
			r.position += org
			if mouse.distance_to(org + Vector2(m["at"])) < 8.0 or (hover_part.is_empty() and _wanted(m["id"]) and r.grow(3).has_point(mouse)):
				ht = m["id"]
				hover_part = {}
				break
	if (ht != hover_tile and ht != "") or (row != hover_row and row >= 0):
		Audio.play("ui_hover", -10.0)
	hover_tile = ht
	hover_row = row

func _gui_input(ev: InputEvent) -> void:
	if not ev is InputEventMouseButton or not (ev as InputEventMouseButton).pressed:
		return
	var mb: InputEventMouseButton = ev
	mouse = mb.position
	idle = 0.0
	if not pulse.is_empty() and pulse_t <= 4.0:
		pulse.clear()
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		pan_to += 24.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -24.0
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	help = false
	_hover()
	_update_hand()
	var left: bool = mb.button_index == MOUSE_BUTTON_LEFT
	if not left and hand != "":
		_put_away()
	elif BIN.has_point(mouse):
		if left:
			_bin_click(mb.double_click)
	elif BOARD.has_point(mouse):
		if left and hover_row >= 0:
			var id: String = stations[hover_row]["id"]
			sel_station = "" if sel_station == id else id
			Audio.play("blip", -4.0)
			_layout_hint()
	else:
		_hall_click(left)

func _bin_click(double: bool) -> void:
	for i: int in TABS.size():
		if _tab_rect(i).grow(1).has_point(mouse):
			if tab != TABS[i]:
				tab = TABS[i]
				hand = ""
				sel = ""
				Audio.play("ui_tab")
				refresh()
			return
	var tile: String = _tile_at(mouse)
	if tile == "":
		_put_away()
	elif not _is_part(tile):
		sel = tile
		_choose(tile)
	elif double and _state(tile) == "ok":
		sel = tile
		hand = ""
		_fly(tile, _step(tile))
		refresh()
	elif hand == tile:
		_put_away()
	else:
		_take(tile)

func _hall_click(left: bool) -> void:
	var org: Vector2 = _org()
	if hand != "":
		if snapped:
			var id: String = hand
			_attach(id, _step(id))
		else:
			_put_away()
		return
	# a missing part's socket, then a part on the craft, then the dashed outline around it
	var it: Dictionary = _part_at(mouse)
	if left:
		for m: Dictionary in missing:
			var r: Rect2 = m["slot"]["rect"]
			r.position += org
			if mouse.distance_to(org + Vector2(m["at"])) < 8.0 or (it.is_empty() and _wanted(m["id"]) and r.grow(3).has_point(mouse)):
				_take(m["id"])
				return
	if not it.is_empty():
		_remove(it["id"], _step(it["id"]), left)
	elif left and (_lv_rect().has_point(mouse) or _sign_rect().has_point(mouse)):
		tab = "launcher"
		sel = "rocket:" + Game.rocket_id
		Audio.play("ui_tab")
		refresh()
	elif sel_station != "":
		sel_station = ""

func _over_input(ev: InputEvent) -> void:
	if not ev is InputEventMouseButton or not (ev as InputEventMouseButton).pressed or (ev as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if auto:
		_auto_finish()
	elif poll.get("phase", "") == "call":
		_poll_end()
	elif poll.get("phase", "") == "go":
		_launch()

# ---------------------------------------------------------------- text helpers

## Breaks a text into lines at spaces only (the engine would also break "4 m/s" after the slash).
func _wrap(text: String, w: float, max_lines: int = -1) -> String:
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
	return "
".join(lines)

func _para_h(text: String, w: float, max_lines: int = -1) -> float:
	return para_font.get_multiline_string_size(_wrap(text, w, max_lines), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).y if text != "" else 0.0

## Wrapped text with a drop shadow; pos is the top-left corner. Returns the height used.
func _para(ci: CanvasItem, pos: Vector2, text: String, w: float, col: Color, max_lines: int = -1) -> float:
	if text == "" or max_lines == 0:
		return 0.0
	if ci == null:
		return _para_h(text, w, max_lines)
	var q: Vector2 = pos.floor() + Vector2(0, 7)
	var lines: String = _wrap(text, w, max_lines)
	ci.draw_multiline_string(para_font, q + Vector2(1, 1), lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, -1, Color(0, 0, 0, 0.85 * col.a))
	ci.draw_multiline_string(para_font, q, lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, -1, col)
	return _para_h(text, w, max_lines)

func _text_r(ci: CanvasItem, right: float, y: float, s: String, col: Color) -> void:
	Pix.text(ci, Vector2(right - Pix.text_w(s, 10), y), s, 10, col)

func _signed(v: float, unit: String) -> String:
	return ("+" if v > 0.0 else "-") + Game.fmt(absf(v)) + unit

func _rate(mbps: float) -> String:
	return "%s Mbps" % Game.fmt(mbps) if mbps >= 0.1 else "%s kbps" % Game.fmt(mbps * 1000.0)

## What n more (or fewer) of a part change, as one short line: "+33 kg  +$5M  +335 W".
func _effect_text(id: String, n: int) -> String:
	var e: Dictionary = Preflight.effect(id, n)
	var out: PackedStringArray = [_signed(float(e["mass"]), " kg")]
	var cost: float = e["cost"]
	if absf(cost) >= 0.05:
		out.append(("+" if cost > 0.0 else "-") + Preflight.money(absf(cost)))
	for pair: Array in [["gen", " W"], ["wh", " Wh"], ["store", " Gb"]]:
		if absf(float(e[pair[0]])) >= 0.5:
			out.append(_signed(float(e[pair[0]]), pair[1]))
	if absf(float(e["rate"])) > 0.0:
		out.append(("+" if float(e["rate"]) > 0.0 else "-") + _rate(absf(float(e["rate"]))))
	var draw: float = e["draw_ops"]
	if absf(draw) >= 0.5:
		out.append("%s %s W" % ["uses" if draw > 0.0 else "frees", Game.fmt(absf(draw))])
	if id != "prop" and absf(float(e["prop_need"])) >= 1.0:
		out.append("fuel need %s" % _signed(float(e["prop_need"]), " kg"))
	return "  ".join(out)

# ---------------------------------------------------------------- drawing: hall and craft

func _draw() -> void:
	var off: Vector2 = Vector2(0, roundf(pan))
	draw_rect(Rect2(0, 0, 640, 360), Color("0a0d18"))
	if tex_bg != null:
		draw_texture(tex_bg, off)
	else:
		# no art yet: a plain dark hall with a floor and a stand
		draw_rect(Rect2(0, 300 + off.y, 640, 60), Color("141a2b"))
		draw_rect(Rect2(Meta.STAND_TOP.x - 90, Meta.STAND_TOP.y + off.y, 180, 14), Color("2a3350"))
		draw_rect(Rect2(Meta.LAUNCHER_BASE.x - 34, Meta.LAUNCHER_BASE.y + off.y, 68, 8), Color("2a3350"))
	_draw_life(off)
	_draw_launcher(off)
	_draw_craft(off)

## Small signs of life: twinkling sky, lamp flicker, warning beacons, chasing stand lights, welding, a forklift.
func _draw_life(off: Vector2) -> void:
	var sky: Rect2 = extras.get("WINDOW_SKY", Meta.WINDOW)
	var hook: Rect2 = extras.get("WINDOW_HOOK", Rect2())
	for i: int in 8:
		var p: Vector2 = sky.position + Vector2((i * 37 + 9) % int(sky.size.x), (i * 23 + 4) % 40)
		if not hook.has_point(p) and p.distance_to(Vector2(337, 122)) > 12.0:
			draw_rect(Rect2(p + off, Vector2(1, 1)), Color(0.9, 0.92, 1.0, 0.15 + 0.6 * absf(sin(t * 0.8 + i * 1.7))))
	for i: int in Meta.LAMPS.size():
		var a: float = 0.2 + 0.04 * sin(t * 2.0 + i)
		if i == 3 and fposmod(t, 9.0) < 0.5 and int(t * 22.0) % 2 == 0:
			a = 0.03
		Fx.glow(self, Meta.LAMPS[i] + off, 8.0, Color(1.0, 0.94, 0.78, a), true)
	if tex_beacon != null:
		var fs: Vector2 = Vector2(extras.get("BEACON_FRAME", Vector2i(16, 16)))
		var bo: Vector2 = extras.get("BEACON_ORIGIN", Vector2(7, 8))
		for i: int in Meta.BEACONS.size():
			var ph: float = fposmod(t * 0.9 + i * 0.37, 1.0)
			var frame: int = [1, 2, 2, 3][int(ph * 8.0)] if ph < 0.5 else 0
			draw_texture_rect_region(tex_beacon, Rect2(Meta.BEACONS[i] - bo + off, fs), Rect2(Vector2(frame * fs.x, 0), fs))
	var lights: Array = extras.get("STAND_LIGHTS", [])
	for i: int in lights.size():
		var on: bool = (i + int(t * 2.0)) % 2 == 0 or snap_t < 0.18
		draw_rect(Rect2(Vector2(lights[i]) + off, Vector2(2, 2)), (Color.WHITE if snap_t < 0.09 else Color("8ff4ff")) if on else Color("1b2a44"))
		if snap_t < 0.18:
			Fx.glow(self, Vector2(lights[i]) + off + Vector2(1, 1), 6.0, Color(0.56, 0.96, 1.0, 0.5 * (1.0 - snap_t / 0.18)), true)
	for i: int in Meta.SPARKS.size():
		var ph: float = fposmod(t + i * 3.7, 6.5)
		if ph > 1.0:
			continue
		var p: Vector2 = Meta.SPARKS[i] + off
		Fx.glow(self, p, 12.0, Color(0.6, 0.8, 1.0, 0.25 + 0.2 * absf(sin(t * 40.0))), true)
		Fx.sparkle(self, p, fposmod(ph * 6.0, 1.0), Color("bfe8ff"), 0)
		for j: int in 4:
			var age: float = fposmod(ph * 2.5 + j * 0.25, 1.0)
			draw_rect(Rect2((p + Vector2((j - 1.5) * 5.0 * age, 16.0 * age * age)).floor(), Vector2(1, 1)), Color(1.0, 0.85, 0.5, 1.0 - age))
	if tex_fork != null:
		# parked, drives across behind the stand, parked, drives back
		var a: Vector2 = extras.get("FORKLIFT_POS", Vector2(204, 270))
		var bx: float = Vector2(extras.get("FORKLIFT_RUN", Vector2(204, 336))).y
		var ph: float = fposmod(t, 44.0)
		var u: float = clampf((ph - 12.0) / 8.0, 0.0, 1.0) - clampf((ph - 34.0) / 8.0, 0.0, 1.0)
		var moving: bool = (ph > 12.0 and ph < 20.0) or (ph > 34.0 and ph < 42.0)
		var fp: Vector2 = Vector2(roundf(lerpf(a.x, bx, smoothstep(0.0, 1.0, u))), a.y + (int(t * 8.0) % 2 if moving else 0)) + off
		var w: float = tex_fork.get_width()
		draw_texture_rect(tex_fork, Rect2(fp, Vector2(-w if ph >= 20.0 and ph < 42.0 else w, tex_fork.get_height())), false)

func _draw_launcher(off: Vector2) -> void:
	var base: Vector2 = Meta.LAUNCHER_BASE + off - Vector2(0, roundf(lv_drop))
	var tex: Texture2D = _lv(Game.rocket_id)
	if tex != null:
		draw_texture(tex, base - Vector2(floorf(tex.get_width() / 2.0), tex.get_height()))
		lv_top = base.y - tex.get_height()
		return
	# no sprite yet: a plain rocket
	var s: Vector2 = LV_SIZE.get(Game.rocket_id, Vector2(30, 180))
	var x: float = base.x - floorf(s.x / 2.0)
	draw_rect(Rect2(x, base.y - s.y + 8, s.x, s.y - 8), Color("d8dce8"))
	draw_rect(Rect2(x + floorf(s.x * 0.7), base.y - s.y + 8, ceilf(s.x * 0.3), s.y - 8), Color("9aa2b8"))
	for i: int in 4:
		draw_rect(Rect2(x + i * 2, base.y - s.y + 6 - i * 2, s.x - i * 4, 2), Color("d8dce8"))
	draw_rect(Rect2(x, base.y - floorf(s.y * 0.45), s.x, 3), Color("20263a"))
	draw_rect(Rect2(x + 2, base.y - 6, s.x - 4, 6), Color("3a4258"))
	lv_top = base.y - s.y

func _sign_lines() -> Array:
	var rk: Dictionary = Data.ROCKETS[Game.rocket_id]
	var can: bool = (rk["cap"] as Dictionary).has(Game.dest_id)
	return [String(rk["name"]).to_upper(), "LIFTS %s kg" % Game.fmt(Game.rocket_cap()) if can else "CANNOT REACH", Preflight.money(float(rk["cost"]))]

func _sign_rect() -> Rect2:
	var w: float = 0.0
	for s: String in _sign_lines():
		w = maxf(w, Pix.text_w(s, 10))
	w += 14.0
	var x: float = minf(Meta.LAUNCHER_BASE.x - floorf(w / 2.0), HALL.end.x - w - 2.0)
	return Rect2(x, 62.0 + roundf(pan), w, 39)

## True for a missing part of the station the hint box is talking about: it gets the full outline.
func _wanted(id: String) -> bool:
	for st: Dictionary in stations:
		if st["id"] == hint.get("id", ""):
			return (st["need"] as Array).has(id)
	return false

## One ship kit slot or item: its sprite, or a flat box while the kit has no sprite for it.
func _part(ci: CanvasItem, d: Dictionary, at: Vector2, mod: Color, id: String) -> void:
	var r: Rect2 = d["rect"]
	var tex: Texture2D = d.get("tex")
	if tex != null:
		var s: Vector2 = tex.get_size()
		ci.draw_texture_rect(tex, Rect2(at + Vector2(d["pos"]), Vector2(-s.x if d.get("flip", false) else s.x, s.y)), false, mod)
	else:
		ci.draw_rect(Rect2(at + r.position, r.size), Color(CAT_COL.get(Data.PARTS[id]["cat"], Color.WHITE)) * mod)

func _dashed(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var ph: int = int(t * 8.0) % 6
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	var x: float = -ph
	while x < q.size.x:
		var x0: float = maxf(x, 0.0)
		var x1: float = minf(x + 3.0, q.size.x)
		if x1 > x0:
			ci.draw_rect(Rect2(q.position.x + x0, q.position.y, x1 - x0, 1), col)
			ci.draw_rect(Rect2(q.end.x - x1, q.end.y - 1, x1 - x0, 1), col)
		x += 6.0
	var y: float = -ph
	while y < q.size.y:
		var y0: float = maxf(y, 0.0)
		var y1: float = minf(y + 3.0, q.size.y)
		if y1 > y0:
			ci.draw_rect(Rect2(q.end.x - 1, q.position.y + y0, 1, y1 - y0), col)
			ci.draw_rect(Rect2(q.position.x, q.end.y - y1, 1, y1 - y0), col)
		y += 6.0

func _brackets(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	var n: float = minf(5.0, floorf(minf(q.size.x, q.size.y) / 2.0))
	for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = q.position + c * (q.size - Vector2(1, 1))
		ci.draw_rect(Rect2(p.x - (n - 1.0) * c.x, p.y, n, 1), col)
		ci.draw_rect(Rect2(p.x, p.y - (n - 1.0) * c.y, 1, n), col)

func _draw_craft(off: Vector2) -> void:
	var org: Vector2 = _org()
	var b: Rect2 = ShipKit.bounds(Game.build)
	Fx.glow(self, Vector2(org.x + b.get_center().x, Meta.STAND_TOP.y + off.y + 1), clampf(b.size.x * 0.6, 24.0, 64.0), Color(0, 0, 0, 0.6))
	var nudge: Dictionary = {}
	for f: Dictionary in flashes:
		if not f["hit"]:
			var u: float = float(f["age"]) / SLIDE
			nudge = {"id": f["id"], "box": f["slot"]["rect"], "off": (Vector2(f["dir"]) * 6.0 * (1.0 - u * u)).round()}
	ShipKit.draw(self, org, Game.build, Color.WHITE, String(hover_part.get("id", "")), nudge)
	# parts the hint says to take off
	for tile: String in pulse:
		if int(pulse[tile]) >= 0 or hand != "":
			continue
		var said: bool = false
		for it: Dictionary in ShipKit.layout(Game.build):
			if it["id"] != tile or not (it["rect"] as Rect2).has_area():
				continue
			var r: Rect2 = it["rect"]
			r.position += org
			draw_rect(r.grow(2), Color(Pix.INK, 0.6), false, 1.0)
			_dashed(self, r.grow(2), UI.ORANGE.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 9.0)))
			if not said:
				said = true
				Pix.text_oc(self, clampf(r.get_center().x, HALL.position.x + 30, HALL.end.x - 30), maxf(r.position.y - 5.0, 36.0), "SPARE FUEL" if tile == "prop" else "TAKE OFF", 10, UI.ORANGE)
	# what is missing, shown where it would go
	var beat: float = 0.5 + 0.5 * sin(t * 4.0)
	for m: Dictionary in missing:
		if hand != "" or auto:
			continue
		var slot: Dictionary = m["slot"]
		var red: Color = UI.RED.lerp(Color.WHITE, 0.5 * beat)
		if _wanted(m["id"]):
			var r: Rect2 = slot["rect"]
			r.position += org
			_part(self, slot, org, Color(1.0, 0.88, 0.84, 0.5 + 0.3 * beat), m["id"])
			draw_rect(r.grow(1), Color(Pix.INK, 0.6), false, 1.0)
			_dashed(self, r.grow(1), red)
		else:
			# a socket: a part belongs here
			var c: Vector2 = org + Vector2(m["at"])
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(11, 11)), Color(Pix.INK, 0.8))
			draw_rect(Rect2(c - Vector2(4, 4), Vector2(9, 9)), red, false, 1.0)
			draw_rect(Rect2(c.x - 2, c.y, 5, 1), red)
			draw_rect(Rect2(c.x, c.y - 2, 1, 5), red)
	if not hover_part.is_empty():
		var hr: Rect2 = hover_part["rect"]
		hr.position += org
		_brackets(self, hr.grow(2), UI.CYAN)
	# the held part: a ghost in its slot and the attach node
	if hand != "" and not hand_slot.is_empty():
		_part(self, hand_slot, org, Color(0.75, 1.0, 0.8, 0.9) if snapped else Color(1, 1, 1, 0.38 + 0.14 * beat), hand)
		var node: Vector2 = org + Vector2(hand_slot["node"])
		Fx.glow(self, node, 8.0, Color(0.35, 1.0, 0.55, 0.35 + 0.35 * beat), true)
		Pix.icon(self, "node", node - Vector2(4, 4), Color(1, 1, 1, 0.7 + 0.3 * beat))
		if UI.icon("node") == null:
			draw_rect(Rect2(node - Vector2(2, 2), Vector2(5, 5)), Color(UI.GREEN, 0.7 + 0.3 * beat))
	# launcher sign and the scale on the stand
	var lines: Array = _sign_lines()
	var sr: Rect2 = _sign_rect()
	var reach: bool = lines[1] != "CANNOT REACH"
	if lv_top > sr.end.y + 2.0:   # a tag wire from the sign down to the rocket's nose
		draw_rect(Rect2(Meta.LAUNCHER_BASE.x, sr.end.y, 2, lv_top - sr.end.y), Color(Pix.INK, 0.7))
		draw_rect(Rect2(Meta.LAUNCHER_BASE.x, sr.end.y, 1, lv_top - sr.end.y - 1.0), Color(UI.YELLOW if reach else UI.RED, 0.55))
	Pix.panel(self, sr, UI.YELLOW if reach else UI.RED)
	Pix.text(self, sr.position + Vector2(7, 12), lines[0], 10, UI.YELLOW)
	Pix.text(self, sr.position + Vector2(7, 23), lines[1], 10, UI.TEXT if reach else UI.RED)
	Pix.text(self, sr.position + Vector2(7, 34), lines[2], 10, UI.DIM)
	if help:
		return
	var boost: Dictionary = stations[0] if not stations.is_empty() else {}
	var txt: String = String(boost.get("short", ""))
	var w: float = Pix.text_w(txt, 10) + 24.0
	var scale_r: Rect2 = Rect2(Meta.STAND_TOP.x - floorf(w / 2.0), Meta.STAND_TOP.y + off.y + 21, w, 14)
	Pix.frame(self, scale_r, "tooltip")
	Pix.icon(self, "mass", scale_r.position + Vector2(3, 1))
	Pix.text(self, scale_r.position + Vector2(17, 10), txt, 10, UI.status_color(String(boost.get("status", "ok"))))

func _paint_glow(ci: Control) -> void:
	var org: Vector2 = _org()
	for f: Dictionary in flashes:
		if not f["hit"]:
			continue
		var age: float = float(f["age"]) - SLIDE
		var slot: Dictionary = f["slot"]
		for _n: int in (3 if age < 0.06 else 1):
			_part(ci, slot, org, Color(1, 1, 1, clampf(1.0 - age / 0.2, 0.0, 1.0)), f["id"])
		Fx.glow(ci, org + Vector2(slot["node"]), 16.0, Color(0.55, 1.0, 0.7, 0.7 * clampf(1.0 - age / 0.2, 0.0, 1.0)), true)

# ---------------------------------------------------------------- drawing: panels

func _paint_front(ci: Control) -> void:
	if tex_fg != null:
		ci.draw_texture(tex_fg, Vector2(0, roundf(pan)))
	# top bar
	ci.draw_rect(Rect2(0, 0, 640, 24), Color(0.03, 0.04, 0.08, 0.9))
	ci.draw_rect(Rect2(0, 23, 640, 1), UI.BORDER)
	var d: Dictionary = Game.dest()
	Pix.title(ci, Vector2(56, 17), String(d["name"]), Color(d["color"]).lightened(0.2))
	Pix.text(ci, Vector2(64 + Pix.title_w(String(d["name"])), 15), String(GOALS[Game.dest_id]), 10, UI.TEXT)
	if top.is_empty():
		Fx.glow(ci, b_launch.position + b_launch.size / 2.0, 64.0, Color(0.3, 1.0, 0.5, 0.2 + 0.15 * sin(t * 5.0)))
	_draw_bin(ci)
	_draw_board(ci)

func _draw_bin(ci: Control) -> void:
	Pix.panel(ci, BIN, UI.RED if hand != "" else UI.BORDER)
	var hot: Dictionary = {}
	for tile: String in pulse:
		hot[_tab_of(tile)] = true
	var fix_tabs: Dictionary = {}
	for tile: String in top_fix:
		fix_tabs[_tab_of(tile)] = true
	var beat: float = 0.5 + 0.5 * sin(t * 9.0)
	for i: int in TABS.size():
		var r: Rect2 = _tab_rect(i)
		var on: bool = TABS[i] == tab
		Pix.frame(ci, r, "tile_sel" if on else "tile_normal")
		Pix.icon(ci, TAB_ICON[TABS[i]], r.position + Vector2(4, 2), Color.WHITE if on else Color(1, 1, 1, 0.75))
		if hot.has(TABS[i]) and not on:
			Pix.frame(ci, r.grow(1), "btn_focus", Color(1, 1, 1, beat))
		if fix_tabs.has(TABS[i]):
			_dot(ci, r.position + Vector2(15, 1))
	Pix.text(ci, Vector2(GRID.x, 36), "LAUNCHER" if tab == "launcher" else String(Data.CAT_NAMES[tab]), 10, UI.CYAN)
	var ids: Array[String] = _tiles(tab)
	for i: int in ids.size():
		_draw_tile(ci, ids[i], _tile_rect(i), beat)
	if b_minus.visible:
		Pix.text_c(ci, 64, 116, "%d/%d" % [Game.count(sel), int(Data.PARTS[sel]["max"])], 10, UI.YELLOW if Game.count(sel) > 0 else UI.DIM)
	# how to, in three lines
	var y: float = 144.0 if tab == "fuel" else 124.0
	if hand != "":
		_para(ci, Vector2(GRID.x, y), "IN HAND: click the ship to fit it. Click here or right-click to put it back.", 122, UI.YELLOW, 4)
	elif tab == "launcher":
		_para(ci, Vector2(GRID.x, y), "Click a rocket or a flight path to choose it.", 122, UI.DIM, 3)
	elif tab == "fuel":
		_para(ci, Vector2(GRID.x, y), "1 unit = 100 kg. Shift or x10 moves ten at a time.", 122, UI.DIM, 3)
	else:
		_para(ci, Vector2(GRID.x, y), "%s. Click a part, then the ship. Double-click fits it at once." % TAB_HELP[tab], 122, UI.DIM, 5)
	_draw_card(ci, _card_tile())

func _draw_tile(ci: Control, tile: String, r: Rect2, beat: float) -> void:
	var st: String = _state(tile)
	var off: bool = st == "lock" or st == "off"
	var chosen: bool = tile == hand or tile == "rocket:" + Game.rocket_id or tile == "path:%d" % Game.traj_idx
	Pix.frame(ci, r, "tile_off" if off else ("tile_sel" if chosen else ("tile_hover" if tile == hover_tile or tile == sel else "tile_normal")))
	var mod: Color = Color(1, 1, 1, 0.3) if off else Color.WHITE
	var ic: Texture2D = _icon(tile)
	if tile.begins_with("path:"):
		var days: float = (Game.dest()["traj"] as Array)[int(tile.substr(5))]["days"]
		Pix.icon(ci, "path", r.position + Vector2(9, 3))
		Pix.text_c(ci, r.position.x + 15, r.position.y + 25, "%dd" % int(days) if days < 1000.0 else "%.1fy" % (days / 365.0), 10, UI.TEXT)
	elif ic != null:
		ci.draw_texture(ic, r.position + ((r.size - ic.get_size()) / 2.0).floor(), mod)
	elif tile.begins_with("rocket:"):
		var h: float = floorf(LV_SIZE[tile.substr(7)].y / 9.0)
		var w: float = clampf(floorf(LV_SIZE[tile.substr(7)].x / 5.0), 3.0, 10.0)
		ci.draw_rect(Rect2(r.position.x + 15 - floorf(w / 2.0), r.position.y + 26 - h, w, h), Color("d8dce8") * mod)
	else:
		Pix.icon(ci, TAB_ICON.get(Data.PARTS[tile]["cat"], "core"), r.position + Vector2(9, 4), mod)
		Pix.text_c(ci, r.position.x + 15, r.position.y + 26, tile.substr(0, 4).to_upper(), 10, Color(UI.TEXT, mod.a))
	if st == "lock":
		Pix.icon(ci, "lock", r.position + Vector2(16, 16))
	var n: int = Game.count(tile) if _is_part(tile) else 0
	if n > 0:
		var txt: String = str(n)
		var w: float = Pix.text_w(txt, 10) + 3.0
		ci.draw_rect(Rect2(r.end.x - w - 2, r.end.y - 11, w, 9), Color(Pix.INK, 0.9))
		Pix.text(ci, Vector2(r.end.x - w, r.end.y - 3), txt, 10, UI.YELLOW)
	if top_fix.has(tile):
		_dot(ci, r.position + Vector2(2, 2))
	if pulse.has(tile):
		Pix.frame(ci, r.grow(1.0 + roundf(beat)), "btn_focus", Color(1.0, 0.55, 0.3) if int(pulse[tile]) < 0 else Color(1, 1, 1, 0.6 + 0.4 * beat))

## A small red mark: "the fix for the open problem is here".
func _dot(ci: Control, pos: Vector2) -> void:
	ci.draw_rect(Rect2(pos, Vector2(5, 5)), Pix.INK)
	ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(3, 3)), UI.RED.lerp(Color.WHITE, 0.4 * absf(sin(t * 4.0))))

## Name, one sentence, stat chips and the source of a tile.
func _card(tile: String) -> Dictionary:
	var c: Dictionary = {"name": "", "body": "", "note": "", "note_col": UI.ORANGE, "chips": [], "src": ""}
	if tile.begins_with("rocket:"):
		var r: Dictionary = Data.ROCKETS[tile.substr(7)]
		c["name"] = r["name"]
		c["src"] = r["src"]
		c["chips"] = [["money", Preflight.money(float(r["cost"]))]]
		if _state(tile) == "off":
			c["body"] = "Cannot reach %s." % Preflight.place()
			c["note"] = "Pick another rocket."
			c["note_col"] = UI.RED
		else:
			var w: Dictionary = Preflight.what_if(tile.substr(7), Game.traj_idx)
			var spare: float = float(w["cap"]) - float(w["mass"])
			c["body"] = "Lifts %s kg to %s on this flight path." % [Game.fmt(w["cap"]), Preflight.place()]
			(c["chips"] as Array).push_front(["mass", "%s kg" % Game.fmt(w["cap"])])
			c["note"] = "Your ship fits, %s kg to spare." % Game.fmt(spare) if spare >= 0.0 else "Your ship is %s kg too heavy for it." % Game.fmt(-spare)
			c["note_col"] = UI.GREEN if spare >= 0.0 else UI.RED
	elif tile.begins_with("path:"):
		var i: int = int(tile.substr(5))
		var tr: Dictionary = (Game.dest()["traj"] as Array)[i]
		var w: Dictionary = Preflight.what_if(Game.rocket_id, i)
		var words: PackedStringArray = ["%s days to %s." % [Game.fmt(tr["days"]), Preflight.place()]]
		if float(tr["dv_mult"]) < 1.0:
			words.append("Slower, but braking needs less fuel.")
		elif float(tr["dv_mult"]) > 1.0:
			words.append("Faster, so braking needs more fuel.")
		if float(tr["cap_mult"]) < 1.0:
			words.append("The rocket must push harder, so it lifts less.")
		c["name"] = tr["name"]
		c["body"] = " ".join(words)
		c["chips"] = [["time", "%s days" % Game.fmt(tr["days"])], ["fuel", "need %s kg" % Game.fmt(w["prop_need"])],
			["mass", "lifts %s kg" % Game.fmt(w["cap"])], ["money", "mission %s" % Preflight.money(float(w["cost"]))]]
		c["src"] = tr["src"]
	elif _is_part(tile):
		var p: Dictionary = Data.PARTS[tile]
		var st: String = _state(tile)
		c["name"] = p["name"]
		c["body"] = p["desc"]
		c["src"] = p["src"]
		if st == "lock":
			var tech: Dictionary = Data.TECH[p["tech"]]
			c["note"] = "LOCKED. Buy it in the Tech Lab on the menu: %d credits." % int(tech["cost"])
		elif st == "off":
			c["note"] = "Not for this trip."
		elif p.get("locked_in", false):
			c["note"] = "Always on the ship."
			c["note_col"] = UI.DIM
		elif (Preflight.DEAD[Game.dest_id] as Array).has(tile):
			c["note"] = "No use at %s: it only adds weight." % Preflight.place()
		elif st == "max":
			c["note"] = "No more fit on the ship."
			c["note_col"] = UI.DIM
		var chips: Array = [["mass", "%s kg" % Game.fmt(p["mass"])], ["money", Preflight.money(float(p["cost"]))]]
		if p.has("gen"):
			chips.append(["power", "+%s W at %s" % [Game.fmt(Preflight.effect(tile, 1)["gen"]), Preflight.place()]])
		if p.has("draw"):
			chips.append(["power", "uses %s W" % Game.fmt(p["draw"])])
		if p.has("wh"):
			chips.append(["battery", "%s Wh" % Game.fmt(p["wh"])])
		if p.has("store_gb"):
			chips.append(["data", "%s Gb" % Game.fmt(p["store_gb"])])
		if p.has("rate"):
			var au: float = Game.dest()["earth_au"]
			chips.append(["comms", "%s here" % _rate(minf(float(p["rate"]) / (au * au), float(p["rate_cap"])))])
		if p.has("gb"):
			chips.append(["science", "%s Gb, %d pt%s" % [Game.fmt(p["gb"]), int(p["pts"]), "" if int(p["pts"]) == 1 else "s"]])
		if p.has("touch"):
			chips.append(["landing", "up to %d m/s" % int(p["touch"])])
		if p.has("speed"):
			chips.append(["speed", "speed x%s" % str(p["speed"])])
		c["chips"] = chips
	return c

func _card_tile() -> String:
	if hover_tile != "":
		return hover_tile
	if hand != "":
		return hand
	return String(hover_part.get("id", sel))

## Draws the detail card (ci = null only measures). Returns how many source lines did not fit.
func _draw_card(ci: Control, tile: String) -> int:
	var x: float = 7.0
	var y: float = 187.0
	var w: float = 136.0
	if ci != null:
		ci.draw_rect(Rect2(4, 183, 142, 1), Color(UI.BORDER, 0.9))
	var c: Dictionary = _card(tile)
	y += _para(ci, Vector2(x, y), String(c["name"]).to_upper(), w, UI.YELLOW, 2) + 2.0
	y += _para(ci, Vector2(x, y), c["body"], w, UI.TEXT, 5) + 2.0
	if c["note"] != "":
		y += _para(ci, Vector2(x, y), c["note"], w, c["note_col"], 3) + 2.0
	var cx: float = x
	for chip: Array in c["chips"]:
		var cw: float = 15.0 + Pix.text_w(chip[1], 10)
		if cx > x and cx + cw > x + w:
			cx = x
			y += 13.0
		if ci != null:
			Pix.icon(ci, chip[0], Vector2(cx, y))
			Pix.text(ci, Vector2(cx + 14, y + 10), chip[1], 10, UI.TEXT)
		cx += cw + 8.0
	y += 15.0
	var lines: int = int((356.0 - y) / 11.0)
	var src: String = "Source: %s" % c["src"]
	_para(ci, Vector2(x, y), src, w, Color(UI.DIM, 0.75), lines)
	return maxi(0, roundi(_para_h(src, w) / 11.0) - lines)

func _draw_board(ci: Control) -> void:
	Pix.panel(ci, BOARD)
	Pix.title(ci, Vector2(BOARD.position.x + 7, 39), "MISSION CONTROL", UI.CYAN)
	# who watches which lamp
	var lx: float = BOARD.position.x + 7
	for i: int in Data.ROLES.size():
		var r: Dictionary = Data.ROLES[i]
		ci.draw_rect(Rect2(lx, 43, 9, 9), r["color"])
		if Game.players > 1:
			ci.draw_string(Pix.font(), Vector2(lx + 2, 51), str(i % Game.players + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK_KEY)
		Pix.text(ci, Vector2(lx + 11, 51), ROLE_SHORT[r["id"]], 10, UI.DIM)
		lx += 17.0 + Pix.text_w(ROLE_SHORT[r["id"]], 10)
	var shown: Dictionary = _shown()
	var flash_on: bool = int(t * 12.0) % 2 == 0
	for i: int in stations.size():
		var s: Dictionary = stations[i]
		var r: Rect2 = rows[i]
		var st: String = s["status"]
		var col: Color = UI.status_color(st)
		if i == hover_row or (not shown.is_empty() and shown["id"] == s["id"] and (sel_station != "" or hover_row >= 0)):
			ci.draw_rect(r.grow(1), Color(1, 1, 1, 0.08))
		var lamp: String = st
		if blink.has(s["id"]) and flash_on:
			lamp = "off"
		if poll.get("phase", "") == "call":
			lamp = "off" if i > int(poll["i"]) or (i == int(poll["i"]) and flash_on) else st
		var lit: float = go_wave - (i + 1) * GO_STEP if go_wave >= 0.0 and poll.is_empty() else 9.0
		if lit < 0.0:
			lamp = "off"
		elif lit < 0.35:
			ci.draw_rect(r.grow(1), Color(0.43, 1.0, 0.54, 0.3 * (1.0 - lit / 0.35)))
		var role_col: Color = UI.DIM
		var who: int = 0
		for j: int in Data.ROLES.size():
			if Data.ROLES[j]["id"] == s["role"]:
				role_col = Data.ROLES[j]["color"]
				who = j % Game.players + 1
		var ind: float = 0.0
		ci.draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), role_col)
		if Game.players > 1:
			ind = 8.0
			ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 9, 9), role_col)
			ci.draw_string(Pix.font(), r.position + Vector2(2, 9), str(who), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK_KEY)
		Pix.lamp(ci, r.position + Vector2(5 + ind, 0), lamp)
		if lit >= 0.0 and lit < 0.3:
			Fx.glow(ci, r.position + Vector2(10 + ind, 5), 12.0, Color(0.6, 1.0, 0.7, 0.8 * (1.0 - lit / 0.3)), true)
		Pix.text(ci, r.position + Vector2(18 + ind, 8), s["name"], 10, UI.TEXT)
		if float(s["frac"]) >= 0.0:
			Pix.gauge(ci, Rect2(r.position.x + 84 + ind, r.position.y + 1, r.size.x - 86 - ind, 8), float(s["frac"]), col)
			_text_r(ci, r.end.x - 2, r.position.y + 18, s["value"], col if st != "ok" else UI.DIM)
		else:
			var v: String = s["value"]
			if Pix.text_w(v, 10) > r.size.x - 68 - ind:
				v = s["short"]
			_text_r(ci, r.end.x - 2, r.position.y + 8, v, col if st != "ok" else UI.DIM)
	# the hint: the most important open problem, or the station that was clicked
	var hr: Rect2 = hint["rect"]
	var hc: Color = hint["col"]
	Pix.panel(ci, hr, hc, Color(0.03, 0.09, 0.06, 0.96) if hc == UI.GREEN else Color(0.04, 0.05, 0.1, 0.96))
	Pix.text(ci, hr.position + Vector2(6, 14), hint["title"], 10, hc)
	var y: float = hr.position.y + 21
	y += _para(ci, Vector2(hr.position.x + 6, y), hint["body"], hr.size.x - 10, UI.TEXT) + 4.0
	_para(ci, Vector2(hr.position.x + 6, y), hint["fact"], hr.size.x - 10, UI.YELLOW if hc == UI.GREEN else UI.DIM)

# ---------------------------------------------------------------- drawing: on top

func _paint_over(ci: Control) -> void:
	var org: Vector2 = _org()
	for f: Dictionary in flyers:
		var u: float = clampf(float(f["age"]) / float(f["dur"]), 0.0, 1.0)
		var slot: Dictionary = f["slot"]
		var r: Rect2 = slot["rect"]
		var p: Vector2 = Vector2(f["from"]).lerp(org + r.get_center(), u * u * (3.0 - 2.0 * u)) - Vector2(0, 26.0 * sin(u * PI))
		_part(ci, slot, (p - r.get_center()).round(), Color(1, 1, 1, 0.9), f["id"])
	for f: Dictionary in leavers:
		var u: float = clampf(float(f["age"]) / 0.2, 0.0, 1.0)
		var r: Rect2 = f["slot"]["rect"]
		var p: Vector2 = Vector2(f["from"]).lerp(f["to"], u * u) - Vector2(0, 18.0 * sin(u * PI))
		_part(ci, f["slot"], (p - r.get_center()).round(), Color(1, 1, 1, 0.9 - 0.6 * u), f["id"])
	for f: Dictionary in puffs:
		Fx.puff(ci, org + Vector2(f["pos"]), float(f["age"]) / 0.35, 1)
	if go_wave >= 0.0 and go_done and poll.is_empty():
		# LAUNCH wakes up: a ring of sparkles around both launch buttons
		var since: float = go_wave - stations.size() * GO_STEP
		for bt: Button in [b_launch, b_go]:
			for i: int in 6:
				var c: Vector2 = bt.position + Vector2(bt.size.x * (0.08 + 0.168 * i), bt.size.y * (0.1 if i % 2 == 0 else 0.9))
				Fx.sparkle(ci, c, (since - 0.05 * i) / 0.45, Color("b8ffc8"), 1 if i % 3 == 0 else 0)
	for s: Dictionary in sparks:
		var age: float = s["age"]
		var p: Vector2 = org + Vector2(s["pos"]) + Vector2(s["vel"]) * age + Vector2(0, 260.0 * age * age)
		ci.draw_rect(Rect2(p.floor(), Vector2(1, 1) if age > 0.2 else Vector2(2, 2)), Color("fff2a8") if age < 0.2 else Color("ffb347"))
	for f: Dictionary in flashes:
		Fx.sparkle(ci, org + Vector2(f["slot"]["node"]), (float(f["age"]) - SLIDE) / 0.2, Color("d8ffe0"), 1)
	for f: Dictionary in floats:
		var age: float = f["age"]
		var p: Vector2 = Vector2(f["pos"]) + (org if f["ship"] else Vector2.ZERO) - Vector2(0, 10.0 + 22.0 * age)
		var w: float = Pix.text_w(f["text"], 10)
		p.x = clampf(p.x - w / 2.0, HALL.position.x + 4.0 if f["ship"] else 4.0, maxf(HALL.position.x + 4.0, (HALL.end.x if f["ship"] else 640.0) - 4.0 - w))
		Pix.text_o(ci, p, f["text"], 10, Color(Color(f["col"]), clampf(2.2 - age * 2.0, 0.0, 1.0)))
	if hand != "" and not hand_slot.is_empty() and poll.is_empty():
		var r: Rect2 = hand_slot["rect"]
		if not snapped:
			_part(ci, hand_slot, (mouse - r.get_center()).round(), Color(1, 1, 1, 0.7), hand)
	if hand != "" and not hand_slot.is_empty() and poll.is_empty() and floats.is_empty():
		var r: Rect2 = hand_slot["rect"]
		# what this part will change, before it is placed
		var at: Vector2 = org + Vector2(r.get_center().x, r.position.y - 6) if snapped else mouse + Vector2(0, -r.size.y / 2.0 - 6)
		var w: float = Pix.text_w(hand_fx, 10)
		Pix.text_o(ci, Vector2(clampf(at.x - w / 2.0, HALL.position.x + 4.0, maxf(HALL.position.x + 4.0, HALL.end.x - 4.0 - w)), maxf(at.y, 36.0)), hand_fx, 10, UI.GREEN)
	if help:
		_draw_help(ci, org)
	if not poll.is_empty():
		_draw_poll(ci)
	elif auto:
		Pix.text_oc(ci, 310, 40, "AUTO-BUILD: click to skip", 10, UI.YELLOW)

## A numbered callout with an arrow from the box to `tip` (left, right or down, whichever the tip lies in).
func _callout(ci: Control, r: Rect2, num: String, text: String, tip: Vector2) -> void:
	var bob: float = roundf(2.0 * absf(sin(t * 4.0)))
	var dir: Vector2 = Vector2.DOWN
	var from: Vector2 = Vector2(clampf(tip.x, r.position.x + 8, r.end.x - 8), r.end.y)
	if tip.x < r.position.x:
		dir = Vector2.LEFT
		from = Vector2(r.position.x, clampf(tip.y, r.position.y + 8, r.end.y - 8))
	elif tip.x > r.end.x:
		dir = Vector2.RIGHT
		from = Vector2(r.end.x, clampf(tip.y, r.position.y + 8, r.end.y - 8))
	var end: Vector2 = tip - dir * bob
	var side: Vector2 = Vector2(absf(dir.y), absf(dir.x))
	for pass_n: int in 2:
		var col: Color = Pix.INK if pass_n == 0 else UI.YELLOW
		var g: float = 1.0 if pass_n == 0 else 0.0
		var a: Vector2 = from - side * (1.0 + g)
		var shaft: Rect2 = Rect2(a, Vector2.ZERO).expand(end - dir * 6.0 + side * (2.0 + g))
		ci.draw_rect(shaft, col)
		for k: int in 6:
			var c: Vector2 = end - dir * (k + 1.0 - g)
			ci.draw_rect(Rect2(c - side * (k + g), Vector2.ZERO).expand(c + side * (k + 1.0 + g) + dir.abs()), col)
	Pix.panel(ci, r, UI.YELLOW, Color(0.05, 0.06, 0.12, 0.96))
	Pix.title(ci, r.position + Vector2(8, floorf(r.size.y / 2.0) + 9), num, UI.YELLOW, 2)
	_para(ci, r.position + Vector2(30, floorf((r.size.y - _para_h(text, r.size.x - 36)) / 2.0)), text, r.size.x - 36, UI.TEXT)

func _draw_help(ci: Control, org: Vector2) -> void:
	ci.draw_rect(Rect2(0, 24, 640, 336), Color(0.02, 0.03, 0.06, 0.35))
	_callout(ci, Rect2(170, 40, 112, 32), "1", "PICK A PART", Vector2(152, 56))
	var topy: float = org.y + ShipKit.bounds(Game.build).position.y - 5.0
	_callout(ci, Rect2(org.x - 82, topy - 58, 164, 32), "2", "DROP IT ON THE SHIP", Vector2(org.x, topy))
	_callout(ci, Rect2(304, 112, 150, 44), "3", "TURN EVERY LIGHT GREEN, THEN LAUNCH", Vector2(468, 134))
	Pix.text_oc(ci, 310, 352, "Click anywhere to start. The ? button shows this again.", 10, UI.DIM)

func _draw_poll(ci: Control) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.06, 0.6))
	var phase: String = poll["phase"]
	if phase == "nogo":
		var bad: Array = []
		var h: float = 34.0
		for s: Dictionary in stations:
			if s["status"] == "bad":
				bad.append(s)
				h += maxf(12.0, _para_h(s["headline"], 218)) + 4.0
		var box: Rect2 = Rect2(156, floorf((360.0 - h - 44.0) / 2.0), 312, h + 44.0)
		Pix.panel(ci, box, UI.RED, Color(0.07, 0.04, 0.06, 0.97))
		Pix.title_c(ci, 320, box.position.y + 19, "NO-GO: %d STATION%s" % [bad.size(), "" if bad.size() == 1 else "S"], UI.RED)
		var by: float = box.position.y + 30
		for s: Dictionary in bad:
			Pix.lamp(ci, Vector2(box.position.x + 9, by), "bad")
			Pix.text(ci, Vector2(box.position.x + 23, by + 8), s["name"], 10, UI.YELLOW)
			by += maxf(12.0, _para(ci, Vector2(box.position.x + 84, by + 1), s["headline"], 218, UI.TEXT)) + 4.0
		Pix.text_c(ci, 320, box.end.y - 30, "You may fly it anyway and find out what fails.", 10, UI.DIM)
		b_fix.position = Vector2(box.position.x + 60, box.end.y - 23)
		b_anyway.position = Vector2(box.end.x - 60 - b_anyway.size.x, box.end.y - 23)
		return
	var n: int = stations.size()
	var r: Rect2 = Rect2(210, floorf((360.0 - n * 13.0 - 62.0) / 2.0), 220, n * 13.0 + 62.0)
	Pix.panel(ci, r, UI.GREEN if phase == "go" else UI.YELLOW, Color(0.04, 0.05, 0.1, 0.97))
	Pix.title_c(ci, 320, r.position.y + 19, "GO / NO-GO POLL", UI.YELLOW)
	for i: int in n:
		var s: Dictionary = stations[i]
		var y: float = r.position.y + 28 + i * 13.0
		var called: bool = i <= int(poll["i"])
		var now: bool = i == int(poll["i"]) and phase == "call"
		var st: String = s["status"]
		Pix.lamp(ci, Vector2(r.position.x + 12, y), st if called and not (now and int(t * 12.0) % 2 == 0) else "off")
		Pix.text(ci, Vector2(r.position.x + 28, y + 8), s["name"], 10, UI.TEXT if called else UI.DIM)
		Pix.text(ci, Vector2(r.position.x + 82, y + 8), ". . . . . . . .", 10, Color(UI.DIM, 0.5))
		if called:
			_text_r(ci, r.end.x - 12, y + 8, "NO-GO" if st == "bad" else "GO", UI.status_color(st))
	if phase == "go":
		var pt: float = poll["t"]
		Fx.glow(ci, Vector2(320, r.end.y - 18), 96.0, Color(0.3, 1.0, 0.5, 0.35 * clampf(1.0 - pt / 0.6, 0.0, 1.0)))
		Pix.title_c(ci, 320, r.end.y - 12, "ALL STATIONS GO", Color.WHITE if pt < 0.08 else UI.GREEN)
		for i: int in 5:
			Fx.sparkle(ci, Vector2(r.position.x + 24 + i * 43, r.end.y - 16 - (i % 2) * 6), (pt - 0.06 * i) / 0.45, Color("b8ffc8"), 1)
	else:
		Pix.text_c(ci, 320, r.end.y - 12, "Click to skip", 10, UI.DIM)

# ---------------------------------------------------------------- debug states for screenshots

func debug_empty() -> void:
	debug_bare()
	help = true

func debug_bare() -> void:
	Game.build = {"bus": 1}
	help = false
	refresh()
	_open_fix_tab()

func debug_hold() -> void:
	help = false
	_take("rtg" if Game.dest_id == "saturn" else "solar")
	origin.y = Meta.STAND_TOP.y - ShipKit.bounds(Game.build).merge(hand_slot["rect"]).end.y
	mouse = Vector2(196, 96)

func debug_snap() -> void:
	debug_hold()
	mouse = _org() + Vector2(hand_slot["node"]) + Vector2(6, 4)

func debug_hint() -> void:
	for id: String in ["solar", "solar_lite", "rtg"]:
		Game.build.erase(id)
	refresh()
	sel_station = "power"

func debug_poll() -> void:
	_start_poll()
	poll["i"] = 5
	poll["freeze"] = true

func debug_nogo() -> void:
	Game.build = {"bus": 1}
	_start_poll()
	_poll_end()

func debug_max() -> void:
	for id: String in Data.PARTS:
		if Game.part_available(id):
			Game.build[id] = int(Data.PARTS[id]["max"])
	Game.rocket_id = "heavy"
	refresh()

## The part starts to slide in 0.8 s after the screen opens and clicks on at 0.87 s: shoot at wait 0.8 to 1.1.
func debug_attach() -> void:
	debug_snap()
	_update_hand()
	_hall_click(true)
	blink.clear()
	for list: Array in [flashes, floats]:
		for e: Dictionary in list:
			e["age"] = -0.8

## A craft taller than the view, panned up by the mouse wheel.
func debug_pan() -> void:
	debug_max()
	Game.build.erase("heatshield")
	_take("heatshield")
	mouse = Vector2(200, 100)
	pan_to = 60.0

## The example ship through the poll and on to the flight screen (shot at wait=4 shows the launch).
func debug_launch() -> void:
	_start_poll()

func debug_show() -> void:
	debug_bare()
	_show_me()

func debug_card() -> void:
	hover_tile = _tiles(tab)[1]

func debug_p3() -> void:
	Game.players = 3

func debug_p4() -> void:
	Game.players = 4

## Every Tech Lab part unlocked.
func debug_tech() -> void:
	for id: String in Data.TECH:
		Game.tech[id] = true
	refresh()

## The all-GO moment: the last missing part goes on (shot at wait 0.5 to 1.2).
func debug_go() -> void:
	var last: String = "drone" if Game.dest_id == "saturn" else "drill"
	Game.build.erase(last)
	refresh()
	_attach(last, 1)

## A ship that is too heavy because of spare fuel: the hint says what to take off.
func debug_heavy() -> void:
	Game.build["prop"] = 80
	Game.rocket_id = "heavy" if Game.dest_id == "saturn" else "falcon9"
	refresh()
	_show_me()

## Random clicks, keys and buttons for many frames, drawn in between. Any script error shows in the log.
func debug_stress() -> void:
	fuzz = 400
	fuzz_rng = RandomNumberGenerator.new()
	fuzz_rng.seed = 11

func _fuzz_step() -> void:
	fuzz -= 1
	var g: RandomNumberGenerator = fuzz_rng
	if fuzz % 50 == 0:
		Game.players = 1 + (fuzz / 50) % 4
		Game.tech = {}
		if fuzz % 100 == 0:
			debug_tech()
	for k: int in 6:
		var roll: int = g.randi_range(0, 30)
		var pos: Vector2 = Vector2(g.randf_range(0, 640), g.randf_range(24, 360))
		if roll < 6:
			pos = _tile_rect(g.randi_range(0, 7)).get_center()
		elif roll < 9:
			pos = _tab_rect(g.randi_range(0, TABS.size() - 1)).get_center()
		elif roll < 13:
			pos = _org() + Vector2(g.randf_range(-150, 150), g.randf_range(-110, 190))
		mouse = pos
		if roll < 22:
			var ev: InputEventMouseMotion = InputEventMouseMotion.new()
			ev.position = pos
			_input(ev)
			if not poll.is_empty() or auto:
				_fuzz_over()
			else:
				_click(pos, [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN][g.randi_range(0, 5)], g.randf() < 0.3)
		else:
			var acts: Array[Callable] = [_undo, _redo, _plus, _minus, _fill, _toggle_help, _show_me, _auto_build, _start_poll, _poll_fix]
			if (poll.is_empty() and not auto) or roll > 28:
				acts[g.randi_range(0, acts.size() - 1)].call()
		if poll.get("phase", "") == "go":   # never leave the screen
			poll = {}
			refresh()
	if fuzz == 0:
		print("STRESS %s done: %s" % [Game.dest_id, str(Game.build)])

func _fuzz_over() -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	if poll.get("phase", "") != "go":
		_over_input(ev)

func debug_fly() -> void:
	_auto_build()

## Adds and removes every part once, chooses every rocket and path, undoes it all. Prints nothing when all is well.
func debug_all() -> void:
	var keep: Dictionary = _snap()
	for id: String in Data.PARTS:
		var n: int = Game.count(id)
		_take(id)
		mouse = _org() + Vector2(ShipKit.next_slot(Game.build, id).get("node", Vector2.ZERO))
		_update_hand()
		if hand != "":
			_hall_click(true)
		_fly(id, 1)
		while not flyers.is_empty():
			var f: Dictionary = flyers.pop_front()
			_attach(f["id"], f["n"])
		if _draw_card(null, id) > 0:
			print("debug_all: the card of %s does not fit" % id)
		_remove(id, 1, true)
		_put_away()
		_remove(id, 99, false)
		if Game.count(id) != (1 if Data.PARTS[id].get("locked_in", false) else 0) and Game.part_available(id):
			print("debug_all: %s was not removed" % id)
		if n > 0 and Game.part_available(id):
			Game.build[id] = n
	for tile: String in _tiles("launcher"):
		_choose(tile)
		if _draw_card(null, tile) > 0:
			print("debug_all: the card of %s does not fit" % tile)
	_fill()
	while not undo_stack.is_empty():
		_undo()
	_restore(keep)
	floats.clear()

func _click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.position = pos
	ev.button_index = button
	ev.pressed = true
	ev.double_click = double
	_gui_input(ev)

func _check(ok: bool, what: String) -> void:
	if not ok:
		print("debug_clicks FAILED: " + what)

func _item_center(id: String) -> Vector2:
	for it: Dictionary in ShipKit.layout(Game.build):
		if it["id"] == id and (it["rect"] as Rect2).has_area():
			return _org() + (it["rect"] as Rect2).get_center()
	return Vector2(-99, -99)

## Self-check: plays the screen with real click events on a bare Moon ship. Prints only what fails.
func debug_clicks() -> void:
	Game.build = {"bus": 1}
	help = false
	refresh()
	_click(_tab_rect(1).get_center())
	_check(tab == "power" and sel == "solar", "tab click opens POWER")
	_click(_tile_rect(0).get_center())
	_check(hand == "solar", "tile click puts the part in the hand")
	_click(_org())
	_check(Game.count("solar") == 1 and hand == "solar", "click on the craft attaches, part stays in the hand")
	_click(_org(), MOUSE_BUTTON_RIGHT)
	_check(hand == "", "right-click puts the part away")
	_click(_tile_rect(3).get_center())
	_click(_tile_rect(3).get_center(), MOUSE_BUTTON_LEFT, true)
	_check(flyers.size() == 1 and hand == "", "double-click sends the part flying")
	_process(0.5)
	_check(Game.count("battery") == 1 and flyers.is_empty(), "the flying part lands")
	if _state("solar_lite") == "lock":
		_click(_tile_rect(1).get_center())
		_check(hand == "" and Game.count("solar_lite") == 0 and sel == "solar_lite", "a locked tile only shows its card")
	_click(_item_center("solar"))
	_check(Game.count("solar") == 0 and hand == "solar", "click on a part lifts it into the hand")
	_click(Vector2(190, 60))
	_check(hand == "" and Game.count("solar") == 0, "dropping away from the craft returns it to the bin")
	_click(_item_center("battery"), MOUSE_BUTTON_RIGHT)
	_check(Game.count("battery") == 0 and hand == "", "right-click removes a part")
	_remove("bus", 1, true)
	_check(Game.count("bus") == 1 and hand == "", "the bus stays")
	_check(String(hint["id"]) == "power", "the hint shows POWER first on a bare ship")
	var want: String = ""
	for m: Dictionary in missing:
		if _wanted(m["id"]) and hand == "":
			want = m["id"]
			_click(_org() + Vector2(m["at"]))
	_check(want != "" and hand == want, "click on a missing part's socket takes that part")
	_click(_org())
	_put_away()
	var n: int = Game.count(want)
	_undo()
	_check(Game.count(want) == n - 1, "undo")
	_redo()
	_check(Game.count(want) == n, "redo")
	_click(_tab_rect(7).get_center())
	_fill()
	_check(stations[2]["id"] == "fuel" and stations[2]["status"] == "ok", "FILL TO NEED turns FUEL green")
	x10 = true
	var fuel: int = Game.count("prop")
	_click(_tile_rect(0).get_center())
	_click(_org())
	_check(Game.count("prop") == fuel + 10, "x10 adds ten fuel units")
	_put_away()
	x10 = false
	_click(rows[1].get_center())
	_check(sel_station == "power", "click on a station row selects it")
	_click(_tab_rect(0).get_center())
	_click(_tile_rect(3).get_center())
	_check(Game.rocket_id == "heavy", "rocket tile chooses the rocket")
	_click(_tile_rect(5).get_center())
	_check(Game.traj_idx == 1, "path tile chooses the path")
	_click(Vector2(320, 200), MOUSE_BUTTON_WHEEL_UP)
	_start_poll()
	_check(over.mouse_filter == Control.MOUSE_FILTER_STOP, "the poll blocks the screen")
	_poll_end()
	_check(poll["phase"] == "nogo" and b_fix.visible, "a NO-GO ship stops at the poll result")
	_poll_fix()
	_check(poll.is_empty() and not pulse.is_empty(), "FIX IT closes the poll and points at the fix")
	_auto_build()
	_check(auto and not queue.is_empty(), "auto-build starts")
	_auto_finish()
	_check(top.is_empty(), "the example ship is all GO")
	print("debug_clicks done")

## Does what the hint box says for the first open problem, the way SHOW ME points: the first usable fix.
## Returns what it did, "" when the hint offers nothing.
func _follow_hint() -> String:
	var fx: Array = _fixes(top)
	if fx.is_empty():
		return ""
	var f: String = fx[0]
	var id: String = f.trim_prefix("-")
	if id == "prop":
		sel = "prop"
		tab = "fuel"
		_fill()
		return "FILL TO NEED"
	if f.begins_with("-"):
		_remove(id, 1, false)
	elif _is_part(id):
		_attach(id, 1)
	else:
		_choose(id)
	return f

## Follows the hints until every station is GO. Returns "" when it gets there, else why it stopped.
func _follow(say: bool) -> String:
	var seen: Dictionary = {}
	for step: int in 150:
		if top.is_empty():
			return ""
		var id: String = top["id"]
		var words: String = "%s %s" % [top["headline"], top["explain"]]
		var key: String = "%s%s%d" % [str(Game.build), Game.rocket_id, Game.traj_idx]
		if seen.has(key):
			return "%s: the hints go in a circle. '%s'" % [id, words]
		seen[key] = true
		var did: String = _follow_hint()
		if did == "":
			return "%s: no fix offered. '%s'" % [id, words]
		if say:
			print("JUDGE %s %d: %s -> %s" % [Game.dest_id, step + 1, id, did])
	return "still NO-GO after 150 steps"

## Self-check: a first-time player who starts with the bare ship and only does what the hint box says.
func debug_judge() -> void:
	Game.new_mission(Game.dest_id)
	help = false
	refresh()
	var why: String = _follow(true)
	print("JUDGE %s: %s. %d warn. %s on %s" % [Game.dest_id, "ALL GO" if why == "" else "STUCK at " + why,
		Preflight.count(stations, "warn"), str(Game.build), Game.rocket_id])
	# then the yellow lamps, one at a time, fixing any NO-GO that a fix causes
	for step: int in 30:
		var w: Dictionary = {}
		for s: Dictionary in stations:
			if s["status"] == "warn" and w.is_empty() and not _fixes(s).is_empty():
				w = s
		if w.is_empty():
			break
		var f: String = _fixes(w)[0]
		if _is_part(f):
			_attach(f, 1)
		else:
			_choose(f)
		print("JUDGE %s warn %s -> %s%s" % [Game.dest_id, w["id"], f, "" if _follow(true) == "" else "  STUCK"])
	for s: Dictionary in stations:
		if s["status"] != "ok":
			print("JUDGE %s left %s: %s '%s %s'" % [Game.dest_id, s["status"], s["id"], s["headline"], s["explain"]])
	print("JUDGE %s end: %s on %s" % [Game.dest_id, str(Game.build), Game.rocket_id])

## Self-check: from many random ships (any parts, any rocket, any path), following the hints must always
## end with every station GO. Prints only what fails, once per kind.
func debug_fixes() -> void:
	var keep: Dictionary = _snap()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var said: Dictionary = {}
	auto = true   # no undo history, no floating numbers
	var tech0: Dictionary = Game.tech.duplicate()
	for trial: int in 300:
		Game.tech = tech0.duplicate()
		if trial >= 150:
			for id: String in Data.TECH:
				Game.tech[id] = true
		Game.build = {"bus": 1}
		for id: String in Data.PARTS:
			if Game.part_available(id) and rng.randf() < 0.55:
				var mx: int = int(Data.PARTS[id]["max"])
				Game.build[id] = 1 if mx == 1 else rng.randi_range(1, mx if rng.randf() < 0.3 else maxi(1, mx / 3))
		Game.rocket_id = Data.ROCKETS.keys()[rng.randi_range(0, Data.ROCKETS.size() - 1)]
		Game.traj_idx = rng.randi_range(0, 1)
		var start: String = "%s %s path %d" % [str(Game.build), Game.rocket_id, Game.traj_idx]
		refresh()
		var why: String = _follow(false)
		if why != "" and not said.has(why.get_slice("'", 0)):
			said[why.get_slice("'", 0)] = true
			print("FIXES %s STUCK at %s
   from %s
   at %s %s path %d" % [Game.dest_id, why, start, str(Game.build), Game.rocket_id, Game.traj_idx])
	auto = false
	Game.tech = tech0
	_restore(keep)
	for list: Array in [floats, flashes, sparks, puffs, leavers]:
		list.clear()
	print("FIXES %s done: 300 random ships, %d kinds of dead end" % [Game.dest_id, said.size()])

func debug_electron() -> void:
	sel = "rocket:electron"
	_choose(sel)

func debug_vulcan() -> void:
	sel = "rocket:vulcan"
	_choose(sel)

## Self-check with real input events pushed through the viewport (not calls to _gui_input): the click
## must reach the screen through the layers and buttons exactly as a mouse or a finger would.
func debug_route() -> void:
	Game.build = {"bus": 1}
	help = false
	tab = "power"
	sel = ""
	refresh()
	var steps: Array = [[_tile_rect(0).get_center(), false], [Vector2.INF, false], [Vector2(-1, 0), false], [b_plus.position + b_plus.size / 2.0, false],
		[b_launch.position + b_launch.size / 2.0, false]]
	var want: Array = ["hand == solar", "solar on the ship", "", "plus button adds one more", "LAUNCH opens the poll"]
	for i: int in steps.size():
		var pos: Vector2 = steps[i][0]
		if pos == Vector2.INF:
			pos = _org()
		elif pos.x < 0.0:
			pos = Vector2(190, 60)   # empty hall: puts the part back
		for pressed: bool in [true, false]:
			var ev: InputEventMouseButton = InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			get_viewport().push_input(ev)
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var ok: bool = [hand == "solar", Game.count("solar") == 1, hand == "", Game.count("solar") == 2, not poll.is_empty()][i]
		if not ok:
			print("debug_route FAILED: %s" % want[i])
	print("debug_route done: solar %d, poll %s" % [Game.count("solar"), str(poll.get("phase", "none"))])

## The pointer rests on a part of the craft.
func debug_hover() -> void:
	mouse = _item_center("drill" if Game.count("drill") > 0 else "hga")
	_hover()

## Prints the cost of one frame of this screen (update + all four paint passes), in milliseconds.
func debug_perf() -> void:
	await get_tree().create_timer(0.5).timeout
	var t0: int = Time.get_ticks_usec()
	for i: int in 50:
		_process(0.016)
		_draw_bin_probe()
	print("debug_perf %s: %.2f ms per frame (update + hint + card + layout), %d parts" % [Game.dest_id, (Time.get_ticks_usec() - t0) / 50000.0, ShipKit.layout(Game.build).size()])

func _draw_bin_probe() -> void:
	_draw_card(null, _card_tile())
	ShipKit.layout(Game.build)
	ShipKit.bounds(Game.build)
	_part_at(mouse)
