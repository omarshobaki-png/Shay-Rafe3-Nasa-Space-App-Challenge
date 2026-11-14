extends Control
## Ship builder, built like Kerbal Space Program's Vehicle Assembly Building, kept calm for a first-time student.
## Left: the parts bin; every part says how much this mission needs it (Preflight.part_need).
## Middle: the craft on its stand (drawn through ship_kit.gd) and the launch vehicle. Above it the build
## steps (Preflight.checklist): only the first unfinished one is lit, and everything that glows belongs to it.
## Right: Mission Control, one lamp per station; the numbers show only for the station you point at.
##
## Layers, back to front: this node (hall, craft), `glow` (additive flashes), `front` (foreground art,
## panels), the buttons, `over` (part in the hand, the direction, the controls list, the launch poll).

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")
const Meta = preload("res://scripts/vab_meta.gd")
const TeamUI = preload("res://scripts/team_ui.gd")
const Preflight = preload("res://scripts/preflight.gd")

const TABS: Array[String] = ["launcher", "power", "comms", "science", "landing", "robot", "return", "fuel", "protect"]
const TAB_ICON: Dictionary = {"launcher": "launcher", "power": "power", "comms": "comms", "science": "science",
	"landing": "landing", "robot": "robot", "return": "return", "fuel": "fuel", "protect": "shield"}
## The tab column: a 26 x 26 picture per category (art/vab/tabs.png, in TABS order, from tools/art/gen_vab.py),
## its word under it (6 letters at most) and its accent colour.
const TAB_LABEL: Dictionary = {"launcher": "ROCKET", "power": "POWER", "comms": "COMMS", "science": "SCI",
	"landing": "LAND", "robot": "ROVER", "return": "RETURN", "fuel": "FUEL", "protect": "SHIELD"}
const TAB_ACCENT: Dictionary = {"launcher": Color("f0503c"), "power": Color("ffd75e"), "comms": Color("4fd6ff"),
	"science": Color("6dff8a"), "landing": Color("ff9f43"), "robot": Color("b48cff"), "return": Color("e8ecff"),
	"fuel": Color("ff7ad9"), "protect": Color("5a8cff")}
const TAB_ICON_PX: float = 26.0
const ROLE_SHORT: Dictionary = {"planner": "PLAN", "engineer": "ENGR", "science": "SCI", "comms": "COMM"}
const WORD: Dictionary = {"ok": "GO", "warn": "GO, AT RISK", "bad": "NO-GO"}
const NEED_RANK: Dictionary = {"required": 0, "recommended": 1, "optional": 2, "not_needed": 3}
## Stations whose gauge is a fixed limit being used up (the others show something the ship carries).
const LIMITS: Array[String] = ["booster", "budget", "time"]
## Station id -> its row in Game.calc()["use"].
const USE_KEY: Dictionary = {"booster": "mass", "power": "power", "fuel": "fuel", "data": "data", "comms": "comms", "budget": "budget", "time": "time"}
## What "more than the mission needs" costs, per use row (default: wasted mass).
const WASTE: Dictionary = {"mass": "a smaller rocket fits", "budget": "money to spare"}
const CONTROLS: Array[String] = ["CLICK a part, then the ship: attach it", "DOUBLE-CLICK a part: attach it at once",
	"CLICK a part on the ship: lift it off", "RIGHT-CLICK: put it back in the bin", "WHEEL: slide a tall ship up or down",
	"CTRL+Z, CTRL+Y: undo, redo", "CLICK a lamp: keep its numbers open"]
## Flat colours for parts and rockets that have no sprite yet.
const CAT_COL: Dictionary = {"core": Color("c9a227"), "power": Color("2b6fd6"), "comms": Color("e8ecff"), "science": Color("6dff8a"),
	"landing": Color("a0a8c0"), "robot": Color("ff9f43"), "return": Color("d8dce8"), "fuel": Color("8a94b8"), "protect": Color("4fd6ff")}
const LV_SIZE: Dictionary = {"electron": Vector2(12, 70), "falcon9": Vector2(22, 190), "vulcan": Vector2(34, 165), "heavy": Vector2(50, 195)}

const HALL: Rect2 = Rect2(160, 24, 310, 336)
const BIN: Rect2 = Rect2(0, 24, 160, 336)
const BOARD: Rect2 = Rect2(470, 24, 170, 336)
const GRID: Vector2 = Vector2(43, 41)
const TILE: float = 36.0           # bin tiles: three a row, TILE + 3 apart
const ROW_H: float = 14.0          # one Mission Control lamp row
const VIEW_TOP: float = 80.0       # the guide talks above this line; a tall craft pans below it
## The bin tab that holds rovers, the drone and the crew cabin.
const CAT_LABEL: Dictionary = {"robot": "EXPLORE", "launcher": "LAUNCHER"}
## The guide: what each build step is about, said before the step's own hint (Preflight.checklist()).
const INTRO: Dictionary = {"power": "First, power!", "radio": "Now a radio.", "science": "Now the science tools.",
	"down": "Now the safe landing.", "fuel": "Time to fuel up.", "rocket": "Last, the rocket.", "crew": "Now the crew cabin."}
const CHEER: Array[String] = ["Nice!", "Great job!", "Perfect!"]
const GUIDE_BOX: Rect2 = Rect2(163, 27, 38, 42)    # the guide's portrait
const BUBBLE_X: float = 206.0
const BUBBLE_W: float = 258.0
const DELTA_T: float = 1.8         # how long a lamp shows what the last change did to it ("+12%", "-40 kg")
const SAY_CPS: float = 55.0        # how fast the guide's line types on, characters per second
const GHOST_LOOP: float = 3.2      # the ghost cursor shows the move again every this many seconds
const POLL_STEP: float = 0.22
const SLIDE: float = 0.07          # a new part slides in for this long before it clicks on
const GO_STEP: float = 0.07        # the all-GO wave lights one lamp per step

class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

var tab: String = "launcher"       # open bin category (main.gd's debug hook sets it, then calls refresh)
var calc: Dictionary = {}          # Game.calc() of the last refresh
var stations: Array = []
var top: Dictionary = {}           # the NO-GO to fix first, {} when none
var steps: Array = []              # Preflight.checklist()
var lit: Dictionary = {}           # the one step to do now: a checklist step, or the first NO-GO station; {} = all GO
var lit_fix: Dictionary = {}       # what does it: bin tile -> 1 (add or choose it) or -1 (take it off)
var lit_key: String = ""
var keep_hand: bool = false        # a part was just lifted off the craft: the bin stays where it is
var guide: int = 1                 # which direction is showing (1 to 3; 4 whenever everything is GO)
var rows: Array[Rect2] = []
var rows_end: float = 0.0
var want: Dictionary = {}          # the one outline in the hall: {"tile", "sign", "rect", "slot"}
var need_cache: Dictionary = {}    # part id -> Preflight.part_need(id), until the next refresh
var fix_cache: Dictionary = {}     # station id -> _fix_tiles(station), until the next refresh
var sel: String = ""               # tile in the detail card: part id, "rocket:<id>" or "path:<index>"
var info_for: String = ""          # the tile whose source line is open (the small "i")
var sel_station: String = ""
var hover_tile: String = ""
var hover_part: Dictionary = {}    # ship kit item under the pointer
var hover_row: int = -1
var hand: String = ""              # part id in the hand
var hand_slot: Dictionary = {}
var snapped: bool = false
var mouse: Vector2 = Vector2(320, 200)
var t: float = 0.0
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
var lv_shift: float = 0.0          # the parked launcher rolls right while the craft is too wide for its mark
var lv_top: float = 100.0
var pan: float = 0.0
var pan_to: float = 0.0
var x10: bool = false
var help: bool = false             # the "?" list of controls
var pulse: Dictionary = {}         # SHOW ME: these tiles flash for a few seconds (same shape as lit_fix)
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
var card_y: float = 150.0          # top of the detail card in the bin (under the tiles and their buttons)
var close_r: Rect2 = Rect2()       # the close mark of the pinned station pop-up
# the guide
var guide_on: bool = true
var g_step: String = ""            # the step the guide talks about: a checklist id, "fix:<station>", "go", "auto"
var g_key: String = ""             # g_step plus what the hand holds: a new key types the line again
var g_text: String = ""
var g_t: float = 99.0              # seconds since the line started typing
var g_happy: float = 0.0           # seconds left of the "done!" face
var g_cheer: String = ""
var ghost_t: float = 0.0
var ghost_freeze: float = -1.0     # debug: hold the ghost cursor at this point of its loop

var tex_bg: Texture2D = null
var tex_fg: Texture2D = null
var tex_fork: Texture2D = null
var tex_redo: ImageTexture = null
var tex_guide: Texture2D = null    # 4 frames of 32 x 36: idle, blink, talk, happy
var tex_cursor: Texture2D = null   # 2 frames of 12 x 15: up, pressed
var tex_tabs: Texture2D = null     # the bin tab pictures, 26 x 26 each, in TABS order
var deltas: Dictionary = {}        # station id -> {"text", "col", "age"}: what the last change did to that lamp
var has_missing_line: bool = false # preflight.gd has the v7 short "what is missing" line for NORMAL
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
var b_info: Button = null
var b_fix: Button = null
var b_anyway: Button = null
var b_go: Button = null            # the big launch button in the hint box, when every station is GO
var b_guide: Button = null         # hides or brings back the guide

# multiplayer (decision D7): roles lock the bin, the host's game is the truth, every role signs
var multi: bool = false
var team: Control = null           # team_ui.gd: chat, REQUEST, toasts
var b_menu: Button = null
var b_sign: Button = null
var b_req: Button = null
var b_chat: Button = null
var sent_snap: Dictionary = {}     # host: the last build sent to the others
var seen_snap: Dictionary = {}     # the build the board was last worked out for
var remote_edit: bool = false      # host: applying another player's edit (their role, not ours)
var last_signed: int = 0

# ---------------------------------------------------------------- setup

func _ready() -> void:
	extras = (Meta as Script).get_script_constant_map()
	tex_bg = _load("res://art/vab/bg.png")
	tex_fg = _load(String(extras.get("FG", "res://art/vab/fg.png")))
	tex_fork = _load(String(extras.get("FORKLIFT", "")))
	tex_guide = _load("res://art/vab/guide.png")
	tex_cursor = _load("res://art/vab/cursor.png")
	tex_tabs = _load("res://art/vab/tabs.png")
	for m: Dictionary in (Preflight as GDScript).get_script_method_list():
		has_missing_line = has_missing_line or String(m["name"]) == "missing_line"
	para_font = FontVariation.new()
	para_font.base_font = Pix.font()
	para_font.spacing_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	glow = _layer(_paint_glow)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	front = _layer(_paint_front)
	multi = Game.multi()
	_btn(self, "< MENU", _menu, Rect2(2, 3, 48, 17))
	# undo and redo: two small arrows (redo is the same picture mirrored)
	b_undo = UI.icon_button("back", "", _undo)
	_place(self, b_undo, Rect2(434, 3, 21, 17))
	b_redo = UI.button("", _redo)
	if b_undo.icon != null:
		var img: Image = b_undo.icon.get_image()
		img.flip_x()
		tex_redo = ImageTexture.create_from_image(img)
		b_redo.icon = tex_redo
	_place(self, b_redo, Rect2(456, 3, 21, 17))
	b_auto = _btn(self, "AUTO-BUILD", _auto_build, Rect2(480, 3, 70, 17))
	b_auto.visible = _hints() >= 2
	if not b_auto.visible:   # the undo pair moves up to the help button
		b_undo.position.x += 70.0
		b_redo.position.x += 70.0
	var hb: Button = UI.icon_button("help", "", _toggle_help)
	_place(self, hb, Rect2(552, 3, 22, 17))
	b_launch = _btn(self, "LAUNCH", _start_poll, Rect2(576, 1, 62, 22))
	if multi:
		# undo, redo and auto-build (the example ship) are off in multiplayer: they would change other roles' parts
		for b: Button in [b_undo, b_redo, b_auto]:
			b.visible = false
		b_sign = _btn(self, "SIGN", _toggle_sign, Rect2(398, 3, 42, 17))
		b_req = _btn(self, "REQUEST", _request, Rect2(442, 3, 62, 17))
		b_chat = _btn(self, "CHAT", _chat, Rect2(506, 3, 42, 17))
		Game.signed = {}
		Game.team_reset()
		Net.received.connect(_on_net)
	# the count buttons sit under the tiles; refresh() moves them to the open category's last row
	b_minus = _btn(self, "-", _minus, Rect2(GRID.x, 104, 20, 17))
	b_plus = _btn(self, "+", _plus, Rect2(GRID.x + 52, 104, 20, 17))
	b_x10 = _btn(self, "x10", _toggle_x10, Rect2(GRID.x + 78, 104, 36, 17))
	b_x10.toggle_mode = true
	b_fill = _btn(self, "FILL TO NEED", _fill, Rect2(GRID.x, 123, 114, 17))
	b_info = _btn(self, "i", _toggle_info, Rect2(BIN.end.x - 20.0, 340, 16, 17))
	b_guide = _btn(self, "HIDE", _toggle_guide, Rect2(GUIDE_BOX.position.x, GUIDE_BOX.end.y + 2, GUIDE_BOX.size.x, 14))
	b_show = _btn(self, "SHOW ME", _show_me, Rect2(580, 300, 56, 17))
	b_go = UI.go_button("LAUNCH", _start_poll, 10, 150)
	_place(self, b_go, Rect2(BOARD.position.x + 8, 334, BOARD.size.x - 16, 20))
	over = _layer(_paint_over)
	over.gui_input.connect(_over_input)
	b_fix = UI.go_button("FIX IT" if _hints() >= 2 else "BACK", _poll_fix, 10, 90)
	_place(over, b_fix, Rect2(0, 0, 90, 17))
	b_anyway = UI.danger_button("LAUNCH ANYWAY", _launch, 10, 100)
	_place(over, b_anyway, Rect2(0, 0, 100, 17))
	origin = Vector2(Meta.STAND_TOP.x, Meta.STAND_TOP.y - ShipKit.bounds(Game.build).end.y)
	if multi:
		team = TeamUI.new()
		add_child(team)
		seen_snap = Game.snap()
	guide = 1 if Game.build.size() <= 1 else 3
	guide_on = _hints() >= 1
	b_guide.visible = guide_on
	refresh()
	lv_shift = _lv_shift()

## How much this mission needs a part (Preflight.part_need), remembered until the ship changes.
func _need(id: String) -> Dictionary:
	if not need_cache.has(id):
		need_cache[id] = Preflight.part_need(id)
	return need_cache[id]

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

## The tiles of a bin category. Parts: required first, then recommended, optional, and not needed here last.
func _tiles(tb: String) -> Array[String]:
	var out: Array[String] = []
	if tb == "launcher":
		for id: String in Data.ROCKETS:
			out.append("rocket:" + id)
		for i: int in (Game.dest()["traj"] as Array).size():
			out.append("path:%d" % i)
	else:
		for rank: int in 4:
			for id: String in Data.PARTS:
				if Data.PARTS[id]["cat"] == tb and int(NEED_RANK[_need(id)["level"]]) == rank:
					out.append(id)
	return out

func _tab_of(tile: String) -> String:
	if tile.begins_with("rocket:") or tile.begins_with("path:"):
		return "launcher"
	var cat: String = Data.PARTS[tile]["cat"] if Data.PARTS.has(tile) else ""
	return cat if TABS.has(cat) else tab

func _is_part(tile: String) -> bool:
	return Data.PARTS.has(tile)

## "ok", "lock" (Tech Lab), "off" (cannot fly to this destination), "max" (no more fit).
func _state(tile: String) -> String:
	if tile.begins_with("rocket:"):
		return "ok" if (Data.ROCKETS[tile.substr(7)]["cap"] as Dictionary).has(Game.dest_id) else "off"
	if not _is_part(tile):
		return "ok"
	var p: Dictionary = Data.PARTS[tile]
	if p.has("tech") and not Game.tech.has(p["tech"]):
		return "lock"
	if not Game.part_available(tile):
		return "off"
	return "max" if Game.count(tile) >= int(p["max"]) else "ok"

func _tile_pos(tile: String) -> Vector2:
	return _tile_rect(maxi(_tiles(tab).find(tile), 0)).get_center()

func _tab_rect(i: int) -> Rect2:
	return Rect2(3, 26 + i * 37, 36, 36)

func _tile_rect(i: int) -> Rect2:
	return Rect2(GRID.x + (i % 3) * (TILE + 3.0), GRID.y + floorf(i / 3.0) * (TILE + 3.0), TILE, TILE)

## How much the builder helps (Data.DIFFICULTY "hints"): 2 EASY, everything; 1 NORMAL, the guide names what is
## missing and nothing glows; 0 HARD, only the lamps and their numbers.
func _hints() -> int:
	return int(Game.diff("hints"))

## The y just under the last row of tiles of the open category.
func _tiles_end() -> float:
	return _tile_rect(maxi(0, _tiles(tab).size() - 1)).end.y

func _cat_name(tb: String) -> String:
	return String(CAT_LABEL.get(tb, Data.CAT_NAMES.get(tb, tb.to_upper())))

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
	if multi:
		return
	if undo_stack.is_empty():
		return
	redo_stack.append(_snap())
	_restore(undo_stack.pop_back())

func _redo() -> void:
	if multi:
		return
	if redo_stack.is_empty():
		return
	undo_stack.append(_snap())
	_restore(redo_stack.pop_back())

func _menu() -> void:
	if Net.is_online():
		Game.leave_room()
	else:
		Game.goto("menu")

func _deny(text: String) -> void:
	Audio.play("part_deny")
	floats.append({"pos": mouse + Vector2(0, -8), "text": text, "age": 0.0, "col": UI.RED, "ship": false})

func _take(id: String) -> void:
	var locked_role: String = _locked(id)
	if locked_role != "":
		hand = ""
		_deny_role(locked_role)
		return
	sel = id
	tab = _tab_of(id)
	var st: String = _state(id)
	if st != "ok":
		hand = ""
		_deny({"lock": "LOCKED: TECH LAB", "off": "NOT NEEDED HERE", "max": "NO MORE FIT"}[st])
		refresh()
		return
	hand = id
	if guide == 1:
		guide = 2
	Audio.play("part_pick")
	refresh()

func _put_away() -> void:
	if hand == "":
		return
	hand = ""
	Audio.play("ui_close", -4.0)
	refresh()

func _choose(tile: String) -> void:
	var locked_role: String = _locked(tile)
	if locked_role != "":
		hand = ""
		_deny_role(locked_role)
		return
	hand = ""
	if tile.begins_with("rocket:"):
		var id: String = tile.substr(7)
		if _state(tile) != "ok":
			_deny("CANNOT REACH %s" % Game.place())
			refresh()
			return
		if _remote():
			Net.send("edit", {"op": "rocket", "id": id})
			return
		if id != Game.rocket_id:
			_commit()
			Game.rocket_id = id
			Game.signed = {}
			lv_drop = 16.0
			Audio.play("part_snap", -1.0, 0.75)
	else:
		var i: int = int(tile.substr(5))
		if _remote():
			Net.send("edit", {"op": "traj", "i": i})
			return
		if i != Game.traj_idx:
			_commit()
			Game.traj_idx = i
			Game.signed = {}
			Audio.play("confirm", -4.0)
	refresh()

## Adds n of a part to the craft, with the snap effects. Returns false when it cannot be added.
func _attach(id: String, n: int) -> bool:
	var locked_role: String = _locked(id)
	if locked_role != "":
		hand = ""
		_deny_role(locked_role)
		return false
	if _remote():
		Net.send("edit", {"op": "add", "id": id, "n": n})
		return true
	var slot: Dictionary = ShipKit.next_slot(Game.build, id)
	if slot.is_empty() or not Game.part_available(id):
		_deny("NO MORE FIT")
		return false
	_commit()
	Game.add_part(id, n)
	guide = maxi(guide, 3)
	# the part slides the last pixels toward its attach node, then clicks on (_impact)
	var away: Vector2 = (slot["rect"] as Rect2).get_center() - Vector2(slot["node"])
	var dir: Vector2 = Vector2(signf(away.x), 0) if absf(away.x) > absf(away.y) else Vector2(0, signf(away.y))
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	flashes.append({"slot": slot, "age": 0.0, "id": id, "dir": dir, "hit": false, "n": n})
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
	var locked_role: String = _locked(id)
	if locked_role != "":
		hand = ""
		_deny_role(locked_role)
		return
	if Game.count(id) == 0:
		return
	if Data.PARTS[id].get("locked_in", false):
		sel = id
		_deny("THE BUS STAYS")
		return
	if _remote():
		Net.send("edit", {"op": "remove", "id": id, "n": n})
		hand = id if to_hand else ""
		return
	var at: Vector2 = Vector2.ZERO
	var last: Dictionary = {}
	for it: Dictionary in ShipKit.layout(Game.build):
		if it["id"] == id:
			at = (it["box"] as Rect2).get_center()
			last = it
	_commit()
	Game.add_part(id, -n)
	puffs.append({"pos": at, "age": 0.0})
	Audio.play("part_remove")
	sel = id
	tab = _tab_of(id)
	hand = id if to_hand else ""
	if not to_hand and not last.is_empty() and not auto:
		leavers.append({"id": id, "slot": {"rect": last["box"], "pos": last["pos"], "tex": last["tex"], "flip": last["flip"]},
			"from": _org() + at, "to": _tile_pos(id), "age": 0.0})
	keep_hand = to_hand
	refresh()
	keep_hand = false

## A part flies from the bin to its slot by itself (double-click, the "+" button, auto-build).
func _fly(id: String, n: int, dur: float = 0.22) -> void:
	var locked_role: String = _locked(id)
	if locked_role != "":
		hand = ""
		_deny_role(locked_role)
		return
	var slot: Dictionary = ShipKit.next_slot(Game.build, id)
	if slot.is_empty() or _state(id) != "ok":
		_deny("NO MORE FIT" if _state(id) == "max" else "NOT AVAILABLE")
		return
	var from: Vector2 = Vector2(75, 70)
	if _tiles(tab).has(id):
		from = _tile_pos(id)
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

## Sets the fuel to the start of the green band. The need follows the dry mass only, so one pass is enough.
func _fill() -> void:
	var n: int = _fuel_units() - Game.count("prop")
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

func _toggle_guide() -> void:
	guide_on = not guide_on
	g_key = ""
	Audio.play("ui_open" if guide_on else "ui_close")
	refresh()

func _toggle_help() -> void:
	help = not help
	Audio.play("ui_open" if help else "ui_close")

func _toggle_info() -> void:
	var tile: String = _card_tile()
	info_for = "" if info_for == tile else tile
	Audio.play("blip", -4.0)

func _station(id: String) -> Dictionary:
	for s: Dictionary in stations:
		if s["id"] == id:
			return s
	return {}

## What the lit checklist step asks for, as bin tiles: tile -> 1 (add or choose it) or -1 (take it off).
## Empty when the step offers nothing that can be done now.
func _lit_tiles() -> Dictionary:
	if lit.is_empty():
		return {}
	if lit["id"] == "rocket":
		var tile: String = (lit["parts"] as Array)[0]
		var boost: Dictionary = _station("booster")
		var must: bool = boost.get("status", "") == "bad"
		if tile != "rocket:" + Game.rocket_id and _state(tile) == "ok":
			# a rocket that lifts the ship at all may cost another lamp; one chosen only for its margin may not
			var after: Array = _what_if(tile, 1)[0]
			if (must and not _breaks(after)) or Preflight.count(after, "bad") == 0:
				return {tile: 1}
		return _fix_tiles(boost) if must else {}   # no rocket lifts it: what to take off
	var part: String = lit["next"] if lit["next"] != "" else String((lit["parts"] as Array)[0])
	return {part: 1} if _is_part(part) and _state(part) == "ok" else {}

## Fuel units for the start of the green band: the planned speed change plus the margin (Game.calc()["prop_ok"]).
func _fuel_units() -> int:
	return mini(ceili(float(Game.calc()["prop_ok"]) / float(Data.PARTS["prop"]["mass"]) - 0.0001), int(Data.PARTS["prop"]["max"]))

## True when adding this part (one or a few more of it), or choosing this rocket or path, and then the fuel
## that calls for, leaves no NO-GO and fewer yellow lamps.
func _improves(tile: String) -> bool:
	var now: int = Preflight.count(stations, "warn")
	for n: int in (int(Data.PARTS[tile]["max"]) - Game.count(tile) if _is_part(tile) else 1):
		var after: Array = _what_if(tile, n + 1, true)[0]
		if Preflight.count(after, "bad") > 0:
			return false
		if Preflight.count(after, "warn") < now:
			return true
	return false

## When Mission Control offers no fix for a NO-GO: a part that can come off without undoing a build step,
## one that clears a NO-GO first, else the least needed.
func _way_out() -> Dictionary:
	var bad_now: int = Preflight.count(stations, "bad")
	var spare: String = ""
	for rank: int in [3, 2, 1, 0]:
		for id: String in Game.build.keys():
			if id == "prop" or bool(Data.PARTS[id].get("locked_in", false)) or int(NEED_RANK[_need(id)["level"]]) != rank:
				continue
			var left: int = _without(id)
			if left >= 0 and left < bad_now:
				return {id: -1}
			if left >= 0 and spare == "":
				spare = id
	return {spare: -1} if spare != "" else {}

## Picks the one thing to do now: the first unfinished checklist step, else the first NO-GO station, else a
## yellow lamp that one more part turns green without harming another. When it changes, the bin opens on it.
func _light() -> void:
	lit = {}
	for s: Dictionary in steps:
		if not bool(s["done"]):
			lit = s
			break
	lit_fix = _lit_tiles()
	if lit_fix.is_empty():
		lit = {}
		if not top.is_empty():
			lit = {"id": "fix", "title": top["name"], "hint": top["headline"], "station": top}
			lit_fix = _fix_tiles(top)
			if lit_fix.is_empty():
				lit_fix = _way_out()
		for s: Dictionary in stations:
			if not lit.is_empty() or s["status"] != "warn":
				continue
			for f: String in _fixes(s):
				if not f.begins_with("-") and _improves(f):
					lit = {"id": "fix", "title": s["name"], "hint": s["headline"], "station": s}
					lit_fix = {f: 1}
					break
	var key: String = "%s %s" % [lit.get("id", ""), " ".join(PackedStringArray(lit_fix.keys()))]
	if key != lit_key:
		lit_key = key
		if not auto and not keep_hand and _hints() >= 2:   # NORMAL and HARD: the player finds the part
			_open_lit()

func _open_lit() -> void:
	for tile: String in lit_fix:
		tab = _tab_of(tile)
		sel = tile
		if hand != tile:
			hand = ""
		break

## The tiles to highlight: what SHOW ME is flashing, else what the lit step asks for.
## Nothing glows above EASY.
func _hot() -> Dictionary:
	if _hints() < 2:
		return {}
	return pulse if not pulse.is_empty() else lit_fix

## The one outline in the hall: where the first highlighted part goes, the part to take off, or the rocket
## to change. {} while a part is in the hand.
func _want() -> Dictionary:
	if hand != "" or auto or not poll.is_empty():
		return {}
	var org: Vector2 = _org()
	for tile: String in _hot():
		var sign_n: int = int(_hot()[tile])
		if sign_n < 0:
			for it: Dictionary in ShipKit.layout(Game.build):
				if it["id"] == tile and (it["rect"] as Rect2).has_area():
					return {"tile": tile, "sign": -1, "rect": Rect2((it["rect"] as Rect2).position + org, (it["rect"] as Rect2).size)}
		elif _is_part(tile):
			var slot: Dictionary = ShipKit.next_slot(Game.build, tile)
			if not slot.is_empty():
				return {"tile": tile, "sign": 1, "slot": slot, "rect": Rect2((slot["rect"] as Rect2).position + org, (slot["rect"] as Rect2).size)}
		elif tile.begins_with("rocket:"):
			return {"tile": tile, "sign": 1, "rect": _lv_rect().intersection(HALL.grow(-3))}
		break
	return {}

func _on_want() -> bool:
	return want.has("slot") and (want["rect"] as Rect2).grow(3).has_point(mouse)

## What fixes a station and can be done now, best first: bin tiles to add or choose, "-<part id>" to take off.
func _fixes(s: Dictionary) -> Array:
	return (s.get("fix", []) as Array).filter(func(f: String) -> bool:
		if f.begins_with("-"):
			return Game.count(f.substr(1)) > 0
		return _state(f) == "ok" and f != "rocket:" + Game.rocket_id and f != "path:%d" % Game.traj_idx)

## Preflight.checklist(), guarded. With airbags in place of legs and another landing part still missing it
## reads the name of a part "" (preflight.gd, the "down" step), so the legs are lent to it for that call.
## (shortcut: with the lent legs, 50 kg, the fuel and rocket ticks may be a step late; drop this when preflight.gd is fixed.)
func _checklist() -> Array:
	if not Game.id_has("airbags") or Game.id_has("legs"):
		return Preflight.checklist()
	Game.build["legs"] = 1
	var out: Array = Preflight.checklist()
	Game.build.erase("legs")
	for s: Dictionary in out:
		if s["id"] == "down" and not bool(s["done"]):
			return out
	return Preflight.checklist()   # nothing else is missing: the plain call is safe

## Mission Control's board and the build steps as they would be after one change: n of a part added (or
## taken off, n < 0), a rocket or a path chosen; `fuel` also tops the fuel up to what the new ship needs.
## Returns [stations, checklist]. Nothing is changed.
func _what_if(tile: String, n: int, fuel: bool = false) -> Array:
	var keep: Dictionary = _snap()
	if _is_part(tile):
		if Game.count(tile) + n > 0:
			Game.build[tile] = Game.count(tile) + n
		else:
			Game.build.erase(tile)
	elif tile.begins_with("rocket:"):
		Game.rocket_id = tile.substr(7)
	else:
		Game.traj_idx = int(tile.substr(5))
	if fuel:
		Game.build["prop"] = maxi(Game.count("prop"), _fuel_units())
	var out: Array = [Preflight.stations(), _checklist()]
	Game.build = keep["build"]
	Game.rocket_id = keep["rocket"]
	Game.traj_idx = keep["traj"]
	return out

## True when the board `after` has a NO-GO at a station that is not NO-GO now.
func _breaks(after: Array) -> bool:
	for i: int in after.size():
		if after[i]["status"] == "bad" and stations[i]["status"] != "bad":
			return true
	return false

## How many stations are NO-GO with one `id` taken off; -1 when an unfinished build step would then ask
## for that same part.
func _without(id: String) -> int:
	var w: Array = _what_if(id, -1)
	for s: Dictionary in w[1]:
		if not bool(s["done"]) and (s["next"] == id or (s["next"] == "" and (s["parts"] as Array).has(id))):
			return -1
	return Preflight.count(w[0], "bad")

## The same as bin tiles: tile -> 1 (add or choose it) or -1 (take it off). One clear instruction: either the
## first part to take off, or the parts and rockets that would fix it. A part is never offered for taking
## off when a build step would ask for it back (_without).
func _fix_tiles(s: Dictionary) -> Dictionary:
	if s.is_empty():
		return {}
	if not fix_cache.has(s["id"]):
		var out: Dictionary = {}
		for f: String in _fixes(s):
			if not f.begins_with("-"):
				out[f] = 1
			elif out.is_empty() and (f == "-prop" or _without(f.substr(1)) >= 0):
				out = {f.substr(1): -1}
				break
		fix_cache[s["id"]] = out
	return fix_cache[s["id"]]

## SHOW ME: opens the bin on what fixes the station being looked at, or on the lit step, and flashes it.
func _show_me() -> void:
	if _hints() < 2:
		return
	var s: Dictionary = _shown()
	pulse = (_fix_tiles(s) if not s.is_empty() else lit_fix).duplicate()
	if pulse.is_empty():
		return
	pulse_t = 4.0
	hand = ""
	for tile: String in pulse:
		sel = tile
		tab = _tab_of(tile)
		break
	Audio.play("ui_tab")
	refresh()

func _auto_build() -> void:
	if multi:
		return
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
	guide = 3
	lv_drop = 16.0
	queue.clear()
	var want_b: Dictionary = auto_target["build"]
	var order: Array = Data.PARTS.keys()
	order.erase("prop")
	order.append("prop")   # fuel goes on last
	for id: String in order:
		var left: int = int(want_b.get(id, 0)) if id != "bus" else 0
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
	if multi:
		# LAUNCH needs all 4 roles signed; only the host presses it, then the poll runs for everyone
		if _remote():
			_deny("ONLY THE HOST CAN LAUNCH")
			return
		if not Game.all_signed():
			_deny("ALL 4 ROLES MUST SIGN FIRST")
			return
		if Net.is_online():
			var s: Dictionary = Game.snap()
			s["poll"] = "start"
			Net.send("build", s)
	_open_poll()

func _poll_end() -> void:
	poll["i"] = stations.size() - 1
	if top.is_empty():
		poll["phase"] = "go"
		poll["t"] = 0.0
		if not multi:
			for r: Dictionary in Data.ROLES:
				Game.signed[r["id"]] = true
		Audio.play("all_go")
	else:
		poll["phase"] = "nogo"
		Audio.play("poll_nogo")
	refresh()

func _poll_fix() -> void:
	if _remote():
		return
	_stop_poll_all()
	poll = {}
	sel_station = ""
	hover_row = -1
	Audio.play("ui_close")
	_show_me()
	refresh()

func _launch() -> void:
	if multi:
		if _remote() or not Game.all_signed():
			return
		Game.launch()
		return
	Game.start_run()
	Game.run["mode"] = "out"
	Game.goto("flight")

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if not TABS.has(tab):
		tab = "launcher"
	need_cache.clear()
	fix_cache.clear()
	var before: Dictionary = {}
	for s: Dictionary in stations:
		before[s["id"]] = [s["status"], s["value"]]
	var was_go: bool = top.is_empty()
	var prev_use: Dictionary = calc.get("use", {})
	calc = Game.calc()
	stations = Preflight.stations()
	top = Preflight.top(stations)
	steps = _checklist()
	_light()
	if sel == "" or _tab_of(sel) != tab:
		sel = "rocket:" + Game.rocket_id if tab == "launcher" else _tiles(tab)[0]
	rows.clear()
	var y: float = 56.0 if Game.players > 1 else 44.0   # two or more players: a line for who watches what
	for s: Dictionary in stations:
		rows.append(Rect2(BOARD.position.x + 4, y, BOARD.size.x - 8, ROW_H))
		y += ROW_H
	rows_end = y
	# what changed on the board: blink the rows, one sound for the whole change
	var better: bool = false
	var worse: bool = false
	for s: Dictionary in stations:
		if not before.has(s["id"]):
			continue
		var b: Array = before[s["id"]]
		if b[0] != s["status"] or b[1] != s["value"]:
			blink[s["id"]] = 0.5
			var dl: Dictionary = _delta(s, prev_use, calc["use"]) if not auto and poll.is_empty() else {}
			if not dl.is_empty():
				deltas[s["id"]] = dl
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
	# buttons
	UI.color_button(b_launch, UI.GREEN if top.is_empty() else UI.BORDER)
	b_undo.disabled = undo_stack.is_empty()
	b_redo.disabled = redo_stack.is_empty()
	b_undo.modulate.a = 0.35 if b_undo.disabled else 1.0
	b_redo.modulate.a = 0.35 if b_redo.disabled else 1.0
	b_auto.text = "SKIP" if auto else "AUTO-BUILD"
	var part_sel: bool = _is_part(sel) and _tab_of(sel) == tab and not bool(Data.PARTS[sel].get("locked_in", false))
	b_minus.visible = part_sel
	b_plus.visible = part_sel
	if part_sel:
		b_minus.disabled = Game.count(sel) == 0
		b_plus.disabled = _state(sel) != "ok"
	b_x10.visible = tab == "fuel"
	b_fill.visible = tab == "fuel"
	var by: float = _tiles_end() + 3.0
	for b: Button in [b_minus, b_plus, b_x10]:
		b.position.y = by
	b_fill.position.y = by + 19.0
	card_y = by + (19.0 if part_sel else 0.0) + (19.0 if b_fill.visible else 0.0) + 3.0
	b_guide.text = "HIDE" if guide_on else "GUIDE"
	if not top.is_empty():
		go_wave = -1.0
	b_fix.visible = String(poll.get("phase", "")) == "nogo"
	b_anyway.visible = b_fix.visible
	if multi:
		b_launch.disabled = _remote() or not Game.all_signed()
		b_go.disabled = b_launch.disabled
		b_anyway.disabled = b_launch.disabled
		b_fix.disabled = _remote()
		b_fill.disabled = _locked("prop") != ""
		if part_sel:
			b_minus.disabled = b_minus.disabled or _locked(sel) != ""
			b_plus.disabled = b_plus.disabled or _locked(sel) != ""
	over.mouse_filter = Control.MOUSE_FILTER_STOP if auto or not poll.is_empty() else Control.MOUSE_FILTER_IGNORE
	_layout_hint()

## What one change did to a lamp, as a short chip beside its gauge: the margin of what the ship carries in
## percentage points ("+12%"), or the change of a fixed limit's use ("-40 kg", "+$5M", "+3 days").
## Green when it moves the resource toward its green band, red when away, yellow when the lamp is now at risk.
func _delta(s: Dictionary, old: Dictionary, now: Dictionary) -> Dictionary:
	var key: String = _use_key(s)
	if key == "" or not old.has(key) or not now.has(key):
		return {}
	var a: Dictionary = old[key]
	var b: Dictionary = now[key]
	var on_have: bool = String(b["band_on"]) == "have"
	var text: String = ""
	var up: bool = false   # the change helps when nothing else decides
	if on_have:
		var m0: float = float(a["have"]) / float(a["need"]) * 100.0 if float(a["need"]) > 0.0 else float(a["have"])
		var m1: float = float(b["have"]) / float(b["need"]) * 100.0 if float(b["need"]) > 0.0 else float(b["have"])
		var pts: int = roundi(m1 - m0)
		if pts == 0:
			return {}
		text = "%+d%%" % pts if float(b["need"]) > 0.0 else "%+d %s" % [pts, String(b["unit"])]
		up = pts > 0
	else:
		var dv: float = float(b["need"]) - float(a["need"])
		if absf(dv) < 0.5 and key != "budget":
			return {}
		if absf(dv) < 0.05:
			return {}
		var sgn: String = "+" if dv > 0.0 else "-"
		text = sgn + Preflight.money(absf(dv)) if key == "budget" else "%s%s %s" % [sgn, Game.fmt(absf(dv)), String(b["unit"])]
		up = dv < 0.0
	var d0: float = _band_dist(a)
	var d1: float = _band_dist(b)
	var good: bool = d1 < d0 - 0.001 or (absf(d1 - d0) <= 0.001 and up)
	var col: Color = UI.GOOD if good else UI.BAD
	if s["status"] == "warn":
		col = UI.RISK
	return {"text": text, "col": col, "age": 0.0}

## How far a resource row sits outside its green band, as a share of the band edge (0 inside it).
func _band_dist(u: Dictionary) -> float:
	var v: float = float(u["have"] if String(u["band_on"]) == "have" else u["need"])
	var lo: float = float(u["lo"])
	var hi: float = float(u["hi"])
	if v < lo:
		return (lo - v) / maxf(lo, 0.001)
	if v > hi:
		return (v - hi) / maxf(hi, 0.001)
	return 0.0

## The station the pop-up talks about: the pinned one (clicked), else the hovered one; {} = none.
## A pinned pop-up stays put while the pointer travels over other lamps to its SHOW ME button.
func _shown() -> Dictionary:
	var want_id: String = sel_station
	if want_id == "" and hover_row >= 0 and hover_row < stations.size():
		want_id = String(stations[hover_row]["id"])
	return _station(want_id) if want_id != "" else {}

## Pins a station's pop-up, or lets it go when it is already the pinned one.
func _pin(id: String) -> void:
	sel_station = "" if sel_station == id else id
	Audio.play("blip" if sel_station != "" else "ui_close", -4.0)
	_layout_hint()

## The key of Game.calc()["use"] behind a station's gauge; "" for a station without a green band.
func _use_key(s: Dictionary) -> String:
	if float(s["lo"]) < 0.0 or not USE_KEY.has(s["id"]):
		return ""
	if s["id"] == "power" and String(s["short"]).ends_with("Wh"):
		return "battery"   # the POWER station shows the battery while that is the weaker of the two
	return USE_KEY[s["id"]]

## Fills `hint` (the pop-up under the lamps) and places its buttons. It shows the station pointed at or
## pinned; with nothing pointed at, the guide does the talking and the box only says how to use the lamps.
## Without the guide it shows the lit build step, as before. It never grows over the lamps: a long text
## loses its fact line first, then lines of its explanation.
func _layout_hint() -> void:
	var s: Dictionary = _shown()
	var h: Dictionary = {"title": "ALL STATIONS GO", "col": UI.GREEN, "body": "", "fact": "", "station": s, "show": false,
		"pinned": not s.is_empty() and sel_station == String(s["id"]), "lines": -1, "step": false,
		"rect": Rect2(BOARD.position.x + 3, rows_end + 3, BOARD.size.x - 6, 356.0 - rows_end)}
	if not s.is_empty():
		h["title"] = s["name"]
		h["col"] = UI.status_color(s["status"])
		h["body"] = ("%s %s" % [s["headline"], s["explain"]]).strip_edges()
		h["fact"] = s["fact"]
		h["show"] = _hints() >= 2 and not _fix_tiles(s).is_empty()
		if _hints() == 0:   # HARD: the numbers and the problem, no advice
			h["body"] = s["headline"]
			h["fact"] = ""
	elif not lit.is_empty() and guide_on:
		h["title"] = ""
		h["body"] = "Point at a lamp to see its numbers. Click it to keep them open."
		h["col"] = UI.DIM
	elif _hints() < 2 and not top.is_empty():   # no guide: only what the lamps say
		var bad: int = Preflight.count(stations, "bad")
		h["title"] = "%d NO-GO" % bad
		h["col"] = UI.BAD
		h["body"] = "Point at a lamp to see its numbers."
	elif not lit.is_empty() and _hints() >= 2:
		h["body"] = lit["hint"]
		h["show"] = not lit_fix.is_empty()
		h["step"] = not lit.has("station")
		if lit.has("station"):
			h["title"] = lit["title"]
			h["col"] = UI.status_color(lit["station"]["status"])
			h["station_word"] = WORD[lit["station"]["status"]]
	else:
		var warn: int = Preflight.count(stations, "warn")
		if warn > 0:
			h["fact"] = "%d yellow lamp%s: GO, but at risk." % [warn, "" if warn == 1 else "s"]
	hint = h
	var quiet: bool = poll.is_empty() and not auto
	b_show.visible = bool(h["show"]) and quiet
	b_go.visible = s.is_empty() and (lit.is_empty() if _hints() >= 2 else top.is_empty()) and quiet
	var room: float = 354.0 - (22.0 if b_show.visible or b_go.visible else 0.0)
	var by: float = _hint_flow(null)
	if by > room and h["fact"] != "":
		h["fact"] = ""
		by = _hint_flow(null)
	while by > room and int(h["lines"]) != 1:
		var n: int = int(_para_h(String(h["body"]), hint["rect"].size.x - 11.0) / 11.0) if int(h["lines"]) < 0 else int(h["lines"])
		h["lines"] = maxi(1, n - 1)
		by = _hint_flow(null)
	b_show.position = Vector2(BOARD.position.x + 9, by)
	b_go.position = Vector2(BOARD.position.x + 9, by)
	b_go.size = Vector2(BOARD.size.x - 18, 20)

## Lays out the pop-up, and draws it when ci is given. Returns the y where its text ends (and its button goes).
func _hint_flow(ci: Control) -> float:
	var r: Rect2 = hint["rect"]
	var x: float = r.position.x + 6.0
	var w: float = r.size.x - 11.0
	var y: float = r.position.y + 5.0
	var s: Dictionary = hint["station"]
	if bool(hint["step"]):
		# the lit build step (guide hidden): its number, its name, the one thing to do
		if ci != null:
			Pix.text(ci, Vector2(x, y + 8), "STEP %d OF %d" % [steps.find(lit) + 1, steps.size()], 10, UI.DIM)
			Pix.title(ci, Vector2(x, y + 25), lit["title"], UI.YELLOW)
		y += 31.0
	elif hint["title"] != "":
		# the station's name big in its lamp colour, its GO word after it; pinned: a pin and a close mark
		var word: String = WORD[s["status"]] if not s.is_empty() else String(hint.get("station_word", ""))
		var right: float = r.end.x - 4.0
		close_r = Rect2()
		if bool(hint["pinned"]):
			close_r = Rect2(right - 13.0, r.position.y + 2.0, 13, 13)
			right = close_r.position.x - 12.0
			if ci != null:
				_close_mark(ci, close_r)
				_pin_mark(ci, Vector2(right + 2.0, r.position.y + 3.0))
		var tw: float = Pix.title_w(hint["title"])
		if ci != null:
			Pix.title(ci, Vector2(x, y + 11), hint["title"], hint["col"])
		if word != "" and x + tw + 6.0 + Pix.text_w(word, 10) <= right:
			if ci != null:
				Pix.text(ci, Vector2(x + tw + 6.0, y + 11), word, 10, hint["col"])
			y += 17.0
		else:
			y += 15.0
			if word != "":
				if ci != null:
					Pix.text(ci, Vector2(x, y + 8), word, 10, hint["col"])
				y += 12.0
	if not s.is_empty() and float(s["frac"]) >= 0.0:
		if ci != null:
			_band_gauge(ci, Rect2(x, y, w, 8), s)
		y += 11.0
		var key: String = _use_key(s)
		if key != "":
			var u: Dictionary = calc["use"][key]
			var word: String = "WELL USED"
			var col: Color = UI.GREEN
			if u["state"] == "risk":
				word = "%s: at risk" % String(u["rating"]).to_upper()
				col = UI.RED if s["status"] == "bad" else UI.YELLOW
			elif u["state"] == "waste":
				word = "%s: %s" % [String(u["rating"]).to_upper(), WASTE.get(key, "wasted mass")]
				col = UI.YELLOW
			if ci != null:
				Pix.text(ci, Vector2(x, y + 8), word, 10, col)
			y += 11.0
		if ci != null:
			Pix.text(ci, Vector2(x, y + 8), s["value"], 10, UI.DIM)
		y += 13.0
	y += _para(ci, Vector2(x, y), hint["body"], w, hint["col"] if hint["title"] == "" and s.is_empty() else UI.TEXT, int(hint["lines"])) + 4.0
	if hint["fact"] != "":
		y += _para(ci, Vector2(x, y), hint["fact"], w, UI.DIM) + 4.0
	return y + 1.0

## The close mark of a pinned pop-up: an X in a small frame.
func _close_mark(ci: Control, r: Rect2) -> void:
	var hot: bool = r.grow(2).has_point(mouse)
	ci.draw_rect(r, Color(1, 1, 1, 0.16) if hot else Color(0, 0, 0, 0.35))
	_outline(ci, r, UI.TEXT if hot else UI.DIM)
	for i: int in 7:
		ci.draw_rect(Rect2(r.position.x + 3 + i, r.position.y + 3 + i, 1, 1), UI.TEXT)
		ci.draw_rect(Rect2(r.position.x + 9 - i, r.position.y + 3 + i, 1, 1), UI.TEXT)

## A small yellow push pin (9 x 11): the pop-up stays open until it is closed.
func _pin_mark(ci: Control, p: Vector2) -> void:
	ci.draw_rect(Rect2(p.x + 2, p.y, 5, 1), Pix.INK)
	ci.draw_rect(Rect2(p.x + 1, p.y + 1, 7, 4), Pix.INK)
	ci.draw_rect(Rect2(p.x + 2, p.y + 1, 5, 3), UI.YELLOW)
	ci.draw_rect(Rect2(p.x + 2, p.y + 1, 2, 1), Color("fff2a8"))
	ci.draw_rect(Rect2(p.x, p.y + 5, 9, 2), Pix.INK)
	ci.draw_rect(Rect2(p.x + 1, p.y + 5, 7, 1), Color("c9a227"))
	ci.draw_rect(Rect2(p.x + 4, p.y + 7, 1, 4), UI.TEXT)

## A station's gauge: the green WELL USED zone between its lo and hi ticks, and a marker where the ship is.
## It reads left to right as "more": before the zone is UNDER, past it is OVER, the same words as
## Game.calc()["use"]. (A station's frac is need / have, so for things the ship carries the bar is mirrored.)
func _band_gauge(ci: Control, r: Rect2, s: Dictionary) -> void:
	var mirror: bool = not LIMITS.has(s["id"])
	var at: float = clampf(float(s["frac"]), 0.0, 1.0)
	var lo: float = s["lo"]
	var hi: float = s["hi"]
	if mirror:
		at = 1.0 - at
		lo = 1.0 - float(s["hi"])
		hi = 1.0 - float(s["lo"])
	Pix.frame(ci, r, "gauge_frame")
	var inner: Rect2 = Rect2(r.position.floor(), r.size.floor()).grow(-2)
	if float(s["lo"]) >= 0.0:
		var x0: float = inner.position.x + floorf(inner.size.x * lo)
		var x1: float = maxf(inner.position.x + ceilf(inner.size.x * hi), x0 + 3.0)
		x0 = minf(x0, inner.end.x - 3.0)
		x1 = minf(x1, inner.end.x)
		ci.draw_rect(Rect2(x0, inner.position.y, x1 - x0, inner.size.y), Color("2f9e4a"))
		ci.draw_rect(Rect2(x0, inner.position.y, 1, inner.size.y), UI.GREEN)
		ci.draw_rect(Rect2(x1 - 1.0, inner.position.y, 1, inner.size.y), UI.GREEN)
	var mx: float = inner.position.x + roundf((inner.size.x - 2.0) * at)
	ci.draw_rect(Rect2(mx - 1.0, r.position.y, 4, r.size.y), Pix.INK)
	ci.draw_rect(Rect2(mx, r.position.y, 2, r.size.y), Color.WHITE)

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
	return Rect2(Meta.LAUNCHER_BASE.x + roundf(lv_shift) - 30, lv_top, 60, Meta.LAUNCHER_BASE.y + pan - lv_top)

func _update_hand() -> void:
	snapped = false
	if hand == "" or hand_slot.is_empty():
		return
	var zone: Rect2 = ShipKit.bounds(Game.build).merge(hand_slot["rect"]).grow(30)
	var org: Vector2 = _org()
	snapped = HALL.has_point(mouse) and (zone.has_point(mouse - org) or mouse.distance_to(org + Vector2(hand_slot["node"])) < 44.0)

func _process(delta: float) -> void:
	if multi:
		_team_tick()
	t += delta
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
	lv_shift = move_toward(lv_shift, _lv_shift(), 120.0 * delta)
	_update_hand()
	for id: String in blink.keys():
		blink[id] = float(blink[id]) - delta
		if float(blink[id]) <= 0.0:
			blink.erase(id)
	for id: String in deltas.keys():
		deltas[id]["age"] = float(deltas[id]["age"]) + delta
		if float(deltas[id]["age"]) > DELTA_T:
			deltas.erase(id)
	if pulse_t > 0.0:
		pulse_t -= delta
		if pulse_t <= 0.0:
			pulse.clear()
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
	want = _want()
	# the only things that glow: the launch buttons once everything is GO, and FILL TO NEED on the fuel step
	var all_go: bool = lit.is_empty() and top.is_empty()
	var glowing: Color = Color.WHITE.lerp(Color(1.25, 1.25, 1.25), _beat())
	if go_wave >= 0.0:   # dark while the lamps come on, then a flash
		var since: float = go_wave - stations.size() * GO_STEP
		glowing = Color(0.55, 0.55, 0.55) if since < 0.0 else Color.WHITE.lerp(Color(2.2, 2.2, 2.2), clampf(1.0 - since / 0.5, 0.0, 1.0))
	b_launch.modulate = glowing if all_go else Color.WHITE
	b_go.modulate = b_launch.modulate
	var hot_n: int = int(_hot().get(sel, 0))
	b_fill.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.0), _beat()) if _hot().has("prop") else Color.WHITE
	b_minus.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.0), _beat()) if hot_n < 0 and sel != "prop" else Color.WHITE
	_layout_hint()
	_guide_tick(delta)
	queue_redraw()
	glow.queue_redraw()
	front.queue_redraw()
	over.queue_redraw()

## The slow pulse of whatever is lit (0..1). SHOW ME quickens it for a few seconds.
func _beat() -> float:
	return 0.5 + 0.5 * sin(t * (9.0 if pulse_t > 0.0 else 3.5))

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
		help = false   # the controls list goes at the next click, wherever it lands
	if ev is InputEventMouseMotion:
		mouse = (ev as InputEventMouseMotion).position
		_hover()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var key: InputEventKey = ev
		if poll.get("phase", "") == "nogo" and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
			_poll_fix()
		elif key.keycode == KEY_ESCAPE:
			if not poll.is_empty():
				if _remote():
					return
				_stop_poll_all()
				poll = {}
				refresh()
			elif help:
				help = false
			elif sel_station != "":
				_pin(sel_station)
			else:
				_put_away()
		elif key.ctrl_pressed and key.keycode == KEY_Z and poll.is_empty() and not auto:
			_undo()
		elif key.ctrl_pressed and key.keycode == KEY_Y and poll.is_empty() and not auto:
			_redo()

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
			if rows[i].has_point(mouse):
				row = i
	elif hand == "":
		hover_part = _part_at(mouse)
		if not hover_part.is_empty() and hover_part["id"] != was_on:
			Audio.play("ui_hover", -12.0)
		# the outlined slot shows the card of the part that belongs there
		want = _want()
		if hover_part.is_empty() and _on_want():
			ht = want["tile"]
	if (ht != hover_tile and ht != "") or (row != hover_row and row >= 0):
		Audio.play("ui_hover", -10.0)
	hover_tile = ht
	hover_row = row

func _gui_input(ev: InputEvent) -> void:
	if not ev is InputEventMouseButton or not (ev as InputEventMouseButton).pressed:
		return
	var mb: InputEventMouseButton = ev
	mouse = mb.position
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		pan_to += 24.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -24.0
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	help = false
	pulse.clear()
	pulse_t = 0.0
	_hover()
	_update_hand()
	var left: bool = mb.button_index == MOUSE_BUTTON_LEFT
	if not left and hand != "":
		_put_away()
	elif BIN.has_point(mouse):
		if left:
			_bin_click(mb.double_click)
	elif BOARD.has_point(mouse):
		if left and close_r.has_area() and close_r.grow(2).has_point(mouse) and sel_station != "":
			_pin(sel_station)
		elif left and hover_row >= 0:
			_pin(String(stations[hover_row]["id"]))
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
	if hand != "":
		if snapped:
			var id: String = hand
			_attach(id, _step(id))
		else:
			_put_away()
		return
	# the outlined slot of the lit part, then a part on the craft, then the launcher
	var it: Dictionary = _part_at(mouse)
	want = _want()
	if left and it.is_empty() and _on_want():
		_take(want["tile"])
	elif not it.is_empty():
		_remove(it["id"], _step(it["id"]), left)
	elif left and (_lv_rect().has_point(mouse) or _sign_rect().has_point(mouse)):
		tab = "launcher"
		sel = String(want["tile"]) if String(want.get("tile", "")).begins_with("rocket:") else "rocket:" + Game.rocket_id
		Audio.play("ui_tab")
		refresh()

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

func _rate(mbps: float) -> String:
	return "%s Mbps" % Game.fmt(mbps) if mbps >= 0.1 else "%s kbps" % Game.fmt(mbps * 1000.0)

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

## A hall at rest: steady lamps and a parked forklift. Nothing moves by itself; only the stand lights
## answer when a part clicks on.
func _draw_life(off: Vector2) -> void:
	for i: int in Meta.LAMPS.size():
		Fx.glow(self, Meta.LAMPS[i] + off, 8.0, Color(1.0, 0.94, 0.78, 0.2), true)
	var lights: Array = extras.get("STAND_LIGHTS", [])
	for i: int in lights.size():
		var on: bool = i % 2 == 0 or snap_t < 0.18
		draw_rect(Rect2(Vector2(lights[i]) + off, Vector2(2, 2)), (Color.WHITE if snap_t < 0.09 else Color("8ff4ff")) if on else Color("1b2a44"))
		if snap_t < 0.18:
			Fx.glow(self, Vector2(lights[i]) + off + Vector2(1, 1), 6.0, Color(0.56, 0.96, 1.0, 0.5 * (1.0 - snap_t / 0.18)), true)
	if tex_fork != null:
		draw_texture(tex_fork, Vector2(extras.get("FORKLIFT_POS", Vector2(204, 270))) + off)

## How far the parked launcher stands right of its mark so that a wide craft never covers it.
func _lv_shift() -> float:
	var tex: Texture2D = _lv(Game.rocket_id)
	var half: float = floorf(tex.get_width() / 2.0) if tex != null else floorf(Vector2(LV_SIZE.get(Game.rocket_id, Vector2(30, 180))).x / 2.0)
	var ship_right: float = Meta.STAND_TOP.x + ShipKit.bounds(Game.build).end.x
	return maxf(0.0, ship_right + 3.0 - (Meta.LAUNCHER_BASE.x - half))

func _draw_launcher(off: Vector2) -> void:
	var base: Vector2 = Meta.LAUNCHER_BASE + off - Vector2(-roundf(lv_shift), roundf(lv_drop))
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
	var lines: Array = [String(rk["name"]).to_upper()]
	if not (rk["cap"] as Dictionary).has(Game.dest_id):
		lines.append("CANNOT REACH")
	return lines

func _sign_rect() -> Rect2:
	var lines: Array = _sign_lines()
	var w: float = 0.0
	for s: String in lines:
		w = maxf(w, Pix.text_w(s, 10))
	w += 14.0
	var x: float = minf(Meta.LAUNCHER_BASE.x + roundf(lv_shift) - floorf(w / 2.0), HALL.end.x - w - 2.0)
	return Rect2(x, 62.0 + roundf(pan), w, 6.0 + 11.0 * lines.size())

func _outline(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var q: Rect2 = Rect2(r.position.floor(), r.size.floor())
	ci.draw_rect(Rect2(q.position, Vector2(q.size.x, 1)), col)
	ci.draw_rect(Rect2(q.position.x, q.end.y - 1.0, q.size.x, 1), col)
	ci.draw_rect(Rect2(q.position, Vector2(1, q.size.y)), col)
	ci.draw_rect(Rect2(q.end.x - 1.0, q.position.y, 1, q.size.y), col)

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
	var ph: int = int(t * 5.0) % 6
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
	# the one outline: where the lit part goes, the part to take off, or the rocket to change
	if not want.is_empty():
		var r: Rect2 = (want["rect"] as Rect2).grow(2)
		if want.has("slot"):
			_part(self, want["slot"], org, Color(1.0, 1.0, 0.9, 0.6), want["tile"])
		_outline(self, r, Color(Pix.INK, 0.6))
		_dashed(self, r, UI.YELLOW)
		if int(want["sign"]) < 0:
			Pix.text_oc(self, clampf(r.get_center().x, HALL.position.x + 30, HALL.end.x - 30), maxf(r.position.y - 4.0, VIEW_TOP + 8.0), "TAKE OFF", 10, UI.YELLOW)
	if not hover_part.is_empty():
		var hr: Rect2 = hover_part["rect"]
		hr.position += org
		_brackets(self, hr.grow(2), UI.TEXT)
	# the held part: a ghost in its slot and the attach node
	if hand != "" and not hand_slot.is_empty():
		_part(self, hand_slot, org, Color(0.75, 1.0, 0.8, 0.9) if snapped else Color(1, 1, 1, 0.45), hand)
		var node: Vector2 = org + Vector2(hand_slot["node"])
		Fx.glow(self, node, 8.0, Color(0.35, 1.0, 0.55, 0.5), true)
		Pix.icon(self, "node", node - Vector2(4, 4))
		if UI.icon("node") == null:
			draw_rect(Rect2(node - Vector2(2, 2), Vector2(5, 5)), UI.GREEN)
	# the scale on the stand
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
	# the launcher's name tag, in front of the hall's cables
	var lines: Array = _sign_lines()
	var sr: Rect2 = _sign_rect()
	Pix.frame(ci, sr, "tooltip")
	for i: int in lines.size():
		Pix.text(ci, sr.position + Vector2(7, 11 + 11 * i), lines[i], 10, UI.TEXT if i == 0 else UI.RED)
	# top bar: where to, the task and its level, the goal
	ci.draw_rect(Rect2(0, 0, 640, 24), Color(0.03, 0.04, 0.08, 0.9))
	ci.draw_rect(Rect2(0, 23, 640, 1), UI.BORDER)
	var d: Dictionary = Game.dest()
	var task: Dictionary = Game.call("task") if Game.has_method("task") else {}
	var level: String = String(task.get("level", Game.difficulty_name()))
	var x: float = 56.0
	var rx: float = x
	if 64.0 + Pix.title_w(String(d["name"])) + Pix.text_w(String(d["goal"]), 10) <= 430.0:
		Pix.title(ci, Vector2(x, 17), String(d["name"]), UI.TEXT)
		x = 64.0 + Pix.title_w(String(d["name"]))
		rx = x
	else:   # a long goal needs the whole bar: the name goes small, in front of the task
		Pix.text(ci, Vector2(x, 10), String(d["name"]), 10, UI.TEXT)
		rx = x + Pix.text_w(String(d["name"]), 10) + 8.0
	if task.has("name"):
		Pix.text(ci, Vector2(rx, 10), String(task["name"]), 10, UI.YELLOW)
		rx += Pix.text_w(String(task["name"]), 10) + 6.0
	_outline(ci, Rect2(rx, 1, Pix.text_w(level, 10) + 7.0, 11), UI.DIM)
	Pix.text(ci, Vector2(rx + 4.0, 10), level, 10, UI.DIM)
	Pix.text(ci, Vector2(x, 21), String(d["goal"]), 10, UI.TEXT)
	if lit.is_empty() and top.is_empty() and poll.is_empty():
		Fx.glow(ci, b_launch.position + b_launch.size / 2.0, 48.0, Color(0.3, 1.0, 0.5, 0.2 + 0.15 * sin(t * 3.5)))
	_draw_bin(ci)
	_draw_board(ci)
	_draw_guide(ci)

## A small tick, 7 x 6, top-left corner at p.
func _tick(ci: Control, p: Vector2, col: Color) -> void:
	for i: int in 3:
		ci.draw_rect(Rect2(p.x + i, p.y + 2 + i, 1, 2), col)
	for i: int in 4:
		ci.draw_rect(Rect2(p.x + 3 + i, p.y + 3 - i, 1, 2), col)

func _draw_bin(ci: Control) -> void:
	Pix.panel(ci, BIN)
	var hot_tabs: Dictionary = {}
	for tile: String in _hot():
		hot_tabs[_tab_of(tile)] = true
	# the tab column: a big picture and its word; the open one is lit in its accent colour and joins the tiles
	for i: int in TABS.size():
		var r: Rect2 = _tab_rect(i)
		var on: bool = TABS[i] == tab
		var acc: Color = TAB_ACCENT[TABS[i]]
		if on:
			ci.draw_rect(Rect2(r.position, r.size + Vector2(2, 0)), Color(acc.darkened(0.55), 0.95))
			ci.draw_rect(Rect2(r.position.x, r.position.y, 2, r.size.y), acc)
			ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x + 2.0, 1), Color(acc, 0.8))
			ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x + 2.0, 1), Color(acc, 0.8))
		else:
			ci.draw_rect(r, Color(1, 1, 1, 0.1) if r.has_point(mouse) else Color(0.08, 0.1, 0.18, 0.85))
		var ip: Vector2 = r.position + Vector2(floorf((r.size.x - TAB_ICON_PX) / 2.0) + 1.0, 1)
		if tex_tabs != null:
			ci.draw_texture_rect_region(tex_tabs, Rect2(ip, Vector2(TAB_ICON_PX, TAB_ICON_PX)), Rect2(i * TAB_ICON_PX, 0, TAB_ICON_PX, TAB_ICON_PX),
				Color.WHITE if on else Color(0.72, 0.74, 0.82))
		else:
			Pix.icon(ci, TAB_ICON[TABS[i]], ip + Vector2(7, 7))
		Pix.text_c(ci, r.get_center().x + 1.0, r.end.y - 2.0, TAB_LABEL[TABS[i]], 10, acc if on else UI.DIM)
		if hot_tabs.has(TABS[i]) and not on:   # the lit part is in this category
			Pix.frame(ci, r.grow(1), "btn_focus", Color(1, 1, 1, 0.55 + 0.45 * _beat()))
	Pix.title(ci, Vector2(GRID.x, 38), _cat_name(tab), UI.DIM)
	var ids: Array[String] = _tiles(tab)
	for i: int in ids.size():
		_draw_tile(ci, ids[i], _tile_rect(i))
	if b_minus.visible:
		Pix.text_c(ci, GRID.x + 36, b_minus.position.y + 12, "%d/%d" % [Game.count(sel), int(Data.PARTS[sel]["max"])], 10, UI.TEXT if Game.count(sel) > 0 else UI.DIM)
	_draw_card(ci, _card_tile())

func _draw_tile(ci: Control, tile: String, r: Rect2) -> void:
	var st: String = _state(tile)
	var level: String = String(_need(tile)["level"]) if _is_part(tile) and _hints() > 0 else ""
	var off: bool = st == "lock" or st == "off" or level == "not_needed"
	var chosen: bool = tile == hand or tile == "rocket:" + Game.rocket_id or tile == "path:%d" % Game.traj_idx
	Pix.frame(ci, r, "tile_off" if off else ("tile_sel" if chosen else ("tile_hover" if tile == hover_tile or tile == sel else "tile_normal")))
	var mod: Color = Color(1, 1, 1, 0.3) if off else Color.WHITE
	var ic: Texture2D = _icon(tile)
	if tile.begins_with("path:"):
		var days: float = (Game.dest()["traj"] as Array)[int(tile.substr(5))]["days"]
		Pix.icon(ci, "path", r.position + Vector2(12, 5))
		Pix.text_c(ci, r.position.x + 18, r.position.y + 30, "%dd" % int(days) if days < 1000.0 else "%.1fy" % (days / 365.0), 10, UI.TEXT)
	elif ic != null:
		ci.draw_texture(ic, r.position + ((r.size - ic.get_size()) / 2.0).floor(), mod)
	elif tile.begins_with("rocket:"):
		var h: float = floorf(LV_SIZE[tile.substr(7)].y / 9.0)
		var w: float = clampf(floorf(LV_SIZE[tile.substr(7)].x / 5.0), 3.0, 10.0)
		ci.draw_rect(Rect2(r.position.x + 15 - floorf(w / 2.0), r.position.y + 26 - h, w, h), Color("d8dce8") * mod)
	else:
		Pix.icon(ci, TAB_ICON.get(Data.PARTS[tile]["cat"], "core"), r.position + Vector2(12, 6), mod)
		Pix.text_c(ci, r.position.x + 18, r.position.y + 31, tile.substr(0, 4).to_upper(), 10, Color(UI.TEXT, mod.a))
	if st == "lock" or _locked(tile) != "":
		Pix.icon(ci, "lock", r.position + Vector2(21, 21))
	# the need badge: a solid corner for REQUIRED, a small pale one for RECOMMENDED
	if level == "required":
		_badge(ci, r.position + Vector2(2, 2), 8.0, UI.YELLOW)
	elif level == "recommended":
		_badge(ci, r.position + Vector2(2, 2), 5.0, UI.TEXT)
	var n: int = Game.count(tile) if _is_part(tile) else 0
	if n > 0:
		var txt: String = str(n)
		var w: float = Pix.text_w(txt, 10) + 3.0
		ci.draw_rect(Rect2(r.end.x - w - 2, r.end.y - 11, w, 9), Color(Pix.INK, 0.9))
		Pix.text(ci, Vector2(r.end.x - w, r.end.y - 3), txt, 10, UI.TEXT)
	if _hot().has(tile) and not (tile == "prop" and tab == "fuel"):   # on the fuel step FILL TO NEED glows instead
		Pix.frame(ci, r.grow(1), "btn_focus", Color(1, 1, 1, 0.55 + 0.45 * _beat()))

## A solid corner badge with its right angle at p.
func _badge(ci: Control, p: Vector2, size: float, col: Color) -> void:
	for i: int in int(size) + 1:
		ci.draw_rect(Rect2(p.x, p.y + i, size + 1.0 - i, 1), Pix.INK)
	for i: int in int(size):
		ci.draw_rect(Rect2(p.x, p.y + i, size - i, 1), col)

## The first sentence of a description.
func _first(text: String) -> String:
	var i: int = text.find(". ")
	return text if i < 0 else text.substr(0, i + 1)

## What the detail card says about a tile: name, how much the mission needs it and why, one sentence,
## a few stat chips, and the source (shown through the small "i").
func _card(tile: String) -> Dictionary:
	var c: Dictionary = {"name": "", "tag": "", "level": "", "why": "", "why_col": UI.TEXT, "body": "", "chips": [], "src": ""}
	if tile.begins_with("rocket:"):
		var r: Dictionary = Data.ROCKETS[tile.substr(7)]
		c["name"] = r["name"]
		c["src"] = "Source: %s" % r["src"]
		c["chips"] = [["money", Preflight.money(float(r["cost"]))]]
		if _state(tile) == "off":
			c["why"] = "Cannot reach %s." % Preflight.place()
			c["why_col"] = UI.RED
		else:
			var w: Dictionary = Preflight.what_if(tile.substr(7), Game.traj_idx)
			var fits: bool = float(w["cap"]) >= float(w["mass"])
			c["why"] = "Your ship fits." if fits else "Too small for your ship."
			c["why_col"] = UI.GREEN if fits else UI.RED
			c["body"] = "Lifts %s kg to %s on this flight path." % [Game.fmt(w["cap"]), Preflight.place()]
			(c["chips"] as Array).push_front(["mass", "%s kg" % Game.fmt(w["cap"])])
	elif tile.begins_with("path:"):
		var i: int = int(tile.substr(5))
		var tr: Dictionary = (Game.dest()["traj"] as Array)[i]
		var w: Dictionary = Preflight.what_if(Game.rocket_id, i)
		var words: PackedStringArray = []
		if float(tr["dv_mult"]) < 1.0:
			words.append("Slower, but braking needs less fuel.")
		elif float(tr["dv_mult"]) > 1.0:
			words.append("Faster, so braking needs more fuel.")
		if float(tr["cap_mult"]) < 1.0:
			words.append("The rocket must push harder, so it lifts less.")
		if words.is_empty():
			words.append("The usual way to %s." % Preflight.place())
		c["name"] = tr["name"]
		c["body"] = " ".join(words)
		c["chips"] = [["time", "%s days" % Game.fmt(tr["days"])], ["fuel", "need %s kg" % Game.fmt(w["prop_need"])],
			["mass", "lifts %s kg" % Game.fmt(w["cap"])]]
		c["src"] = "Source: %s" % tr["src"]
	elif _is_part(tile):
		var p: Dictionary = Data.PARTS[tile]
		var need: Dictionary = _need(tile)
		c["name"] = p["name"]
		if _hints() > 0:   # HARD: no "REQUIRED" plates or reasons, only the part and its numbers
			c["tag"] = need["label"]
			c["level"] = need["level"]
			c["why"] = need["why"]
		c["body"] = "" if c["why"] != "" else _first(p["desc"])
		c["src"] = "%s Source: %s" % [String(p["desc"]).substr(String(c["body"]).length()).strip_edges(), p["src"]]
		if _state(tile) == "lock":
			c["body"] = "LOCKED. Buy it in the Tech Lab on the menu: %d credits." % int(Data.TECH[p["tech"]]["cost"])
		var chips: Array = [["mass", "%s kg" % Game.fmt(p["mass"])], ["money", Preflight.money(float(p["cost"]))]]
		if p.has("gen"):
			chips.append(["power", "+%s W here" % Game.fmt(Preflight.effect(tile, 1)["gen"])])
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
		c["chips"] = chips.slice(0, 4)
	return c

func _card_tile() -> String:
	if hover_tile != "":
		return hover_tile
	if hand != "":
		return hand
	return String(hover_part.get("id", sel))

## Draws the detail card (ci = null only measures). Returns how many pixels of it did not fit.
func _draw_card(ci: Control, tile: String) -> float:
	var x: float = GRID.x
	var y: float = card_y + 5.0
	var w: float = BIN.end.x - x - 5.0
	if ci != null:
		ci.draw_rect(Rect2(x, card_y, w, 1), Color(UI.BORDER, 0.9))
	var c: Dictionary = _card(tile)
	var nm: String = String(c["name"]).to_upper()
	if Pix.title_w(nm) <= w:   # short names in the big type
		if ci != null:
			Pix.title(ci, Vector2(x, y + 11), nm, UI.YELLOW)
		y += 16.0
	else:
		y += _para(ci, Vector2(x, y), nm, w, UI.YELLOW, 2) + 3.0
	if c["tag"] != "":
		# the need label: a solid plate for REQUIRED, an outline for the others
		var tw: float = Pix.text_w(c["tag"], 10) + 7.0
		if ci != null:
			var plate: Rect2 = Rect2(x, y, tw, 11)
			if c["level"] == "required":
				ci.draw_rect(plate, UI.YELLOW)
				ci.draw_string(Pix.font(), plate.position + Vector2(4, 9), c["tag"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK_KEY)
			else:
				_outline(ci, plate, UI.TEXT if c["level"] == "recommended" else UI.DIM)
				Pix.text(ci, plate.position + Vector2(4, 9), c["tag"], 10, UI.TEXT if c["level"] == "recommended" else UI.DIM)
		y += 14.0
	if c["why"] != "":
		y += _para(ci, Vector2(x, y), c["why"], w, c["why_col"], 4) + 4.0
	y += _para(ci, Vector2(x, y), c["body"], w, UI.DIM, 4) + 4.0
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
	var over_px: float = maxf(0.0, y - 340.0)
	if info_for == tile:
		_para(ci, Vector2(x, y), String(c["src"]), w, UI.DIM, maxi(0, int((338.0 - y) / 11.0)))
	return over_px

func _draw_board(ci: Control) -> void:
	Pix.panel(ci, BOARD)
	Pix.title(ci, Vector2(BOARD.position.x + 7, 39), "MISSION CONTROL", UI.TEXT)
	# two or more players: who watches which lamp
	if Game.players > 1:
		var lx: float = BOARD.position.x + 7
		for i: int in Data.ROLES.size():
			var r: Dictionary = Data.ROLES[i]
			ci.draw_rect(Rect2(lx, 44, 9, 9), r["color"])
			ci.draw_string(Pix.font(), Vector2(lx + 2, 52), str(i % Game.players + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK_KEY)
			Pix.text(ci, Vector2(lx + 11, 52), ROLE_SHORT[r["id"]], 10, UI.DIM)
			lx += 17.0 + Pix.text_w(ROLE_SHORT[r["id"]], 10)
	var shown: Dictionary = _shown()
	var flash_on: bool = int(t * 12.0) % 2 == 0
	for i: int in stations.size():
		var s: Dictionary = stations[i]
		var r: Rect2 = rows[i]
		var st: String = s["status"]
		if sel_station == s["id"]:   # pinned: a lit frame that stays
			ci.draw_rect(r, Color(UI.YELLOW, 0.16))
			_outline(ci, r.grow(1), UI.YELLOW)
		elif (not shown.is_empty() and shown["id"] == s["id"]) or i == hover_row:
			ci.draw_rect(r, Color(1, 1, 1, 0.1))
		var lamp: String = st
		if blink.has(s["id"]) and flash_on:
			lamp = "off"
		if poll.get("phase", "") == "call":
			lamp = "off" if i > int(poll["i"]) or (i == int(poll["i"]) and flash_on) else st
		var lit_t: float = go_wave - (i + 1) * GO_STEP if go_wave >= 0.0 and poll.is_empty() else 9.0
		if lit_t < 0.0:
			lamp = "off"
		elif lit_t < 0.35:
			ci.draw_rect(r, Color(0.43, 1.0, 0.54, 0.3 * (1.0 - lit_t / 0.35)))
		var ind: float = 0.0
		if Game.players > 1:
			ind = 10.0
			for j: int in Data.ROLES.size():
				if Data.ROLES[j]["id"] == s["role"]:
					ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 9, 9), Data.ROLES[j]["color"])
					ci.draw_string(Pix.font(), r.position + Vector2(2, 9), str(j % Game.players + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK_KEY)
		Pix.lamp(ci, r.position + Vector2(1 + ind, 2), lamp)
		if lit_t >= 0.0 and lit_t < 0.3:
			Fx.glow(ci, r.position + Vector2(6 + ind, 7), 12.0, Color(0.6, 1.0, 0.7, 0.8 * (1.0 - lit_t / 0.3)), true)
		var nx: float = r.position.x + 14.0 + ind
		Pix.title(ci, Vector2(nx, r.position.y + 12), s["name"], Color("aab3d4"))   # big but soft: the lamp carries the colour
		nx += Pix.title_w(s["name"]) + 5.0
		if float(s["frac"]) >= 0.0:
			_band_gauge(ci, Rect2(r.end.x - 44.0, r.position.y + 3, 42, 8), s)
		else:
			var v: String = s["value"]
			if Pix.text_w(v, 10) > r.end.x - 2.0 - nx:
				v = s["short"]
			if Pix.text_w(v, 10) <= r.end.x - 2.0 - nx:
				_text_r(ci, r.end.x - 2, r.position.y + 11, v, UI.DIM)   # the lamp carries the colour
		if deltas.has(s["id"]):   # what the last change did: over the gauge, outlined, fading out
			var dl: Dictionary = deltas[s["id"]]
			var a: float = clampf((DELTA_T - float(dl["age"])) / 0.4, 0.0, 1.0)
			var dw: float = Pix.text_w(dl["text"], 10)
			var rise: float = floorf(2.0 * clampf(1.0 - float(dl["age"]) / 0.15, 0.0, 1.0))
			ci.draw_rect(Rect2(r.end.x - dw - 6.0, r.position.y + 1.0 + rise, dw + 5.0, r.size.y - 2.0), Color(Pix.INK, 0.85 * a))
			Pix.text(ci, Vector2(r.end.x - dw - 3.0, r.position.y + 11.0 + rise), dl["text"], 10, Color(Color(dl["col"]), a))
	# the hint: the lit step, or the station that is pointed at
	var hr: Rect2 = hint["rect"]
	var hc: Color = hint["col"]
	if hr.position.y < rows_end:
		ci.draw_rect(Rect2(hr.position.x, hr.position.y - 3.0, hr.size.x, hr.size.y + 3.0), Color("080b16"))
	ci.draw_rect(Rect2(hr.position.x + 2.0, hr.position.y - 2.0, hr.size.x - 4.0, 1), Color(UI.BORDER, 0.9))
	if hint["station"].is_empty() and lit.is_empty():
		ci.draw_rect(hr, Color(0.1, 0.5, 0.2, 0.12))
	_hint_flow(ci)

# ---------------------------------------------------------------- drawing: on top

func _paint_over(ci: Control) -> void:
	if multi:
		var sx: float = HALL.position.x + 6.0
		for role: Dictionary in Data.ROLES:
			var rid: String = String(role["id"])
			Pix.text(ci, Vector2(sx, 354), "%s %s" % [ROLE_SHORT[rid], "GO" if bool(Game.signed.get(rid, false)) else "--"], 10, UI.GREEN if bool(Game.signed.get(rid, false)) else UI.DIM)
			sx += 76.0
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
			for i: int in (6 if bt.visible else 0):
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
		var p: Vector2 = Vector2(f["pos"]) - Vector2(0, 10.0 + 22.0 * age)
		var w: float = Pix.text_w(f["text"], 10)
		p.x = clampf(p.x - w / 2.0, 4.0, 636.0 - w)
		Pix.text_o(ci, p, f["text"], 10, Color(Color(f["col"]), clampf(2.2 - age * 2.0, 0.0, 1.0)))
	if hand != "" and not hand_slot.is_empty() and poll.is_empty() and not snapped:
		var r: Rect2 = hand_slot["rect"]
		_part(ci, hand_slot, (mouse - r.get_center()).round(), Color(1, 1, 1, 0.7), hand)
	if not poll.is_empty():
		_draw_poll(ci)
	elif auto and not guide_on:
		Pix.text_oc(ci, 310, 54, "AUTO-BUILD: click to skip", 10, UI.TEXT)
	elif help:
		_draw_help(ci)
	else:
		_draw_ghost(ci)

## ---------------------------------------------------------------- the guide

## Sentence case for a step title: "GETTING DOWN" -> "Getting down".
func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1).to_lower()

func _lines(text: String) -> int:
	return _wrap(text, BUBBLE_W - 14.0).count("\n") + 1

## What the guide says now: [step, key, line]. The step changes when the player has done one (the guide
## cheers); the key also changes when a part is picked up (the line types on again).
func _guide_now() -> Array:
	if auto:
		return ["auto", "auto", "Watch me build an example ship. Click to skip."]
	if lit.is_empty():
		if top.is_empty():
			return ["go", "go", "Every lamp is green. Press LAUNCH!"]
		return ["stuck", "stuck", "A lamp is red. Point at it to see why."]
	if _hints() < 2:   # NORMAL: one short line, what is still missing
		var miss: String = _missing_line()
		return ["fix:" + String(lit["station"]["id"]) if lit.has("station") else String(lit["id"]), miss, miss]
	var step: String = String(lit["id"])
	var say: String = String(lit["hint"])
	if lit.has("station"):
		step = "fix:" + String(lit["station"]["id"])
		say = "%s is %s. %s" % [_cap(String(lit["title"])), "red" if lit["station"]["status"] == "bad" else "at risk", say]
	else:
		var intro: String = String(INTRO.get("crew" if lit.get("next", "") == "crew" else step, ""))
		if intro != "" and _lines(intro + " " + say) <= 2:
			say = intro + " " + say
	if hand != "" and lit_fix.has(hand) and int(lit_fix[hand]) > 0:
		return [step, step + "|hand", "Now click the ship where it glows."]
	return [step, step, say]

## NORMAL's guide line: what is still missing, by name only (preflight.gd's own line when it has one).
func _missing_line() -> String:
	if has_missing_line:
		var line: String = String((Preflight as GDScript).call("missing_line"))
		if line != "":
			return line
	var miss: PackedStringArray = []
	for st: Dictionary in steps:
		if not bool(st["done"]):
			miss.append(_cap(String(st["title"])))
	if not miss.is_empty():
		return "Still missing: %s." % ", ".join(miss)
	if not top.is_empty():
		return "%s is red." % _cap(String(top["name"]))
	for st: Dictionary in stations:
		if st["status"] == "warn":
			return "%s is at risk." % _cap(String(st["name"]))
	return "Every lamp is green. Press LAUNCH!"

func _guide_tick(delta: float) -> void:
	g_t += delta
	ghost_t += delta
	var now: Array = _guide_now()
	if not guide_on:
		g_step = now[0]
		return
	if g_happy > 0.0:
		g_happy -= delta
		if g_happy > 0.0:
			return       # the cheer stays a moment
		g_key = ""
	if now[0] != g_step:
		var was: String = g_step
		g_step = now[0]
		ghost_t = 0.0
		var done_title: String = ""
		for st: Dictionary in steps:
			if st["id"] == was and bool(st["done"]):
				done_title = st["title"]
		if done_title != "" or (g_step == "go" and was != "" and was != "auto"):
			g_happy = 1.4
			g_text = CHEER[randi() % CHEER.size()] + (" %s is done." % _cap(done_title) if done_title != "" else "")
			g_t = 0.0
			g_key = ""
			if g_step != "go":   # the all-GO moment has its own sound
				Audio.play("confirm", -6.0)
			return
	if now[1] != g_key:
		g_key = now[1]
		g_text = now[2]
		g_t = 0.0
		ghost_t = 0.0
	else:
		g_text = now[2]   # only a number in the line changed: no typing again

## The guide in the top-left corner of the hall: portrait, speech bubble, and one pip per build step.
func _draw_guide(ci: Control) -> void:
	if not guide_on:
		return
	var r: Rect2 = GUIDE_BOX
	Pix.panel(ci, r, UI.CYAN, Color(0.05, 0.07, 0.14, 0.95))
	var full: String = _wrap(g_text, BUBBLE_W - 14.0, 2)
	var n: int = mini(full.length(), int(g_t * SAY_CPS))
	var frame: int = 0
	if g_happy > 0.0:
		frame = 3
	elif n < full.length():
		frame = 2 if int(t * 10.0) % 2 == 0 else 0
	elif fmod(t, 3.7) < 0.13:
		frame = 1
	if tex_guide != null:
		ci.draw_texture_rect_region(tex_guide, Rect2(r.position + Vector2(3, 3), Vector2(32, 36)), Rect2(frame * 32, 0, 32, 36))
	# the bubble: light, dark ink, a tail toward the portrait
	var w: float = 0.0
	for line: String in full.split("\n"):
		w = maxf(w, Pix.text_w(line, 10))
	var lines: int = full.count("\n") + 1
	var b: Rect2 = Rect2(BUBBLE_X, r.position.y + 2.0, floorf(w) + 14.0, 11.0 * lines + 9.0)
	var paper: Color = Color("eef1fb") if g_happy <= 0.0 else Color("dcffe4")
	ci.draw_rect(b.grow(1), Pix.INK)
	ci.draw_rect(b, paper)
	ci.draw_rect(Rect2(b.position.x, b.end.y - 1.0, b.size.x, 1), Color("aab4cc"))
	for k: int in 4:   # the tail
		ci.draw_rect(Rect2(b.position.x - 1.0 - k, b.position.y + 6.0 + k, 1, 8 - 2 * k), Pix.INK)
		ci.draw_rect(Rect2(b.position.x - k, b.position.y + 7.0 + k, 1, maxf(0.0, 6.0 - 2.0 * k)), paper)
	ci.draw_multiline_string(para_font, b.position + Vector2(7, 12), full.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, -1, Color("141a2e"))
	# progress: one pip per build step
	var px: float = BUBBLE_X + 1.0
	for st: Dictionary in steps:
		var pr: Rect2 = Rect2(px, GUIDE_BOX.end.y + 6.0, 6, 6)
		var on: bool = lit.get("id", "") == st["id"]
		ci.draw_rect(pr.grow(1), Pix.INK)
		ci.draw_rect(pr, UI.GREEN if bool(st["done"]) else (UI.YELLOW if on else Color(UI.BORDER, 0.9)))
		px += 9.0

## Where the ghost cursor shows the move: [from, to, carried slot or {}, tile]; [] when there is nothing to show.
## It only demonstrates: nothing is placed.
func _ghost_path() -> Array:
	if not guide_on or _hints() < 2 or hand != "" or auto or not poll.is_empty() or help or g_happy > 0.0:
		return []
	if lit.is_empty():
		if top.is_empty() and b_go.visible:
			var c: Vector2 = b_go.position + Vector2(24, 8)
			return [c, c, {}, ""]
		return []
	if lit_fix.is_empty():
		return []
	var tile: String = lit_fix.keys()[0]
	if not _tiles(tab).has(tile):   # the bin shows another category: its tab first
		var c: Vector2 = _tab_rect(TABS.find(_tab_of(tile))).get_center()
		return [c, c, {}, tile]
	var at: Vector2 = _tile_pos(tile)
	if tile == "prop" and b_fill.visible:
		var c: Vector2 = b_fill.position + Vector2(30, 8)
		return [c, c, {}, tile]
	if int(lit_fix[tile]) < 0:
		if want.get("tile", "") == tile:
			return [(want["rect"] as Rect2).get_center(), at, {}, tile]
		return [at, at, {}, tile]
	if want.get("tile", "") == tile and want.has("slot"):
		return [at, _org() + Vector2(want["slot"]["node"]), want["slot"], tile]
	return [at, at, {}, tile]

## The ghost cursor: a see-through pointer that picks the part up, glides to its place and lets go, again
## and again; or a single click on a button or a tab.
func _draw_ghost(ci: Control) -> void:
	var path: Array = _ghost_path()
	if path.is_empty() or tex_cursor == null:
		return
	var a: Vector2 = path[0]
	var b: Vector2 = path[1]
	var slot: Dictionary = path[2]
	var click: bool = a.distance_to(b) < 2.0
	var u: float = fmod(ghost_t if ghost_freeze < 0.0 else ghost_freeze, 2.2 if click else GHOST_LOOP)
	var pos: Vector2 = a
	var pressed: bool = false
	var alpha: float = 1.0
	var carry: bool = false
	var ring: float = -1.0
	if click:
		alpha = clampf(u / 0.25, 0.0, 1.0) * clampf((1.6 - u) / 0.3, 0.0, 1.0)
		pressed = u > 0.5 and u < 0.8
		ring = (u - 0.5) / 0.35
	else:
		alpha = clampf(u / 0.25, 0.0, 1.0) * clampf((2.1 - u) / 0.35, 0.0, 1.0)
		pressed = u > 0.3 and u < 1.6
		carry = pressed
		var k: float = clampf((u - 0.45) / 1.0, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		pos = a.lerp(b, k) - Vector2(0, 18.0 * sin(k * PI))
		ring = (u - 1.6) / 0.35
	if alpha <= 0.0:
		return
	if carry and not slot.is_empty():
		var sr: Rect2 = slot["rect"]
		_part(ci, slot, (pos - sr.get_center()).round(), Color(1, 1, 1, 0.65 * alpha), path[3])
	if ring >= 0.0 and ring <= 1.0:
		Fx.sparkle(ci, pos, ring, Color("d8ffe0"), 0)
	ci.draw_texture_rect_region(tex_cursor, Rect2(pos.round() - Vector2(1, 1), Vector2(12, 15)), Rect2(12 if pressed else 0, 0, 12, 15), Color(1, 1, 1, 0.9 * alpha))

## The "?" button: every control, as a list.
func _draw_help(ci: Control) -> void:
	var r: Rect2 = Rect2(184, 96, 252, 32.0 + 12.0 * CONTROLS.size() + 18.0)
	Pix.panel(ci, r, UI.YELLOW, Color(0.05, 0.06, 0.12, 0.96))
	Pix.title(ci, r.position + Vector2(10, 20), "CONTROLS", UI.YELLOW)
	for i: int in CONTROLS.size():
		var line: String = CONTROLS[i]
		var key: String = line.get_slice(" ", 0) if not line.begins_with("CTRL") else line.get_slice(":", 0)
		Pix.text(ci, r.position + Vector2(10, 38 + 12 * i), key, 10, UI.YELLOW)
		Pix.text(ci, r.position + Vector2(10 + Pix.text_w(key, 10), 38 + 12 * i), line.substr(key.length()), 10, UI.TEXT)
	Pix.text(ci, r.position + Vector2(10, r.size.y - 8), "Click anywhere to close.", 10, UI.DIM)

func _draw_poll(ci: Control) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.06, 0.6))
	var phase: String = poll["phase"]
	if phase == "nogo":
		# the stations that said NO-GO, by name; only the first one to fix gets its sentence
		var bad: Array = []
		for s: Dictionary in stations:
			if s["status"] == "bad":
				bad.append(s)
		var lines: float = ceilf(bad.size() / 3.0)
		var first: String = "Fix first: %s. %s" % [String(top.get("name", "")), String(top.get("headline", ""))]
		var h: float = 30.0 + lines * 13.0 + 6.0 + _para_h(first, 288) + 6.0
		var box: Rect2 = Rect2(156, floorf((360.0 - h - 44.0) / 2.0), 312, h + 44.0)
		Pix.panel(ci, box, UI.RED, Color(0.07, 0.04, 0.06, 0.97))
		Pix.title_c(ci, 320, box.position.y + 19, "NO-GO: %d STATION%s" % [bad.size(), "" if bad.size() == 1 else "S"], UI.RED)
		for i: int in bad.size():
			var p: Vector2 = box.position + Vector2(14 + (i % 3) * 98, 30 + floorf(i / 3.0) * 13.0)
			Pix.lamp(ci, p, "bad")
			Pix.text(ci, p + Vector2(14, 8), bad[i]["name"], 10, UI.TEXT)
		var by: float = box.position.y + 36.0 + lines * 13.0
		by += _para(ci, Vector2(box.position.x + 12, by), first, 288, UI.TEXT) + 6.0
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

## A new mission: the bare ship, as a first-time player meets it.
func debug_bare() -> void:
	Game.new_mission(Game.dest_id)
	undo_stack.clear()
	guide = 1
	lit_key = ""
	refresh()
	deltas.clear()

## The lit part in the hand, away from the ship (direction 2).
func debug_hold() -> void:
	debug_bare()
	_take(String(lit_fix.keys()[0]))
	origin.y = Meta.STAND_TOP.y - ShipKit.bounds(Game.build).merge(hand_slot["rect"]).end.y
	mouse = Vector2(236, 150)

func debug_snap() -> void:
	debug_hold()
	mouse = _org() + Vector2(hand_slot["node"]) + Vector2(6, 4)

## One station pointed at: its gauge with the green band, the numbers and the reason.
func debug_station() -> void:
	sel_station = "fuel"

## A gauge pointed at (not pinned): the pop-up follows the pointer.
func debug_gauge() -> void:
	for i: int in stations.size():
		if stations[i]["id"] == "budget":
			hover_row = i
			mouse = rows[i].get_center()

## A pinned gauge with the pointer away in the hall: the pop-up stays, with its pin and close mark.
## (On a bare ship the BUDGET is green, so the pin goes on the first NO-GO station.)
func debug_pin() -> void:
	debug_bare()
	var id: String = String(top.get("id", "budget"))
	_pin(id)
	hover_row = -1
	mouse = Vector2(250, 250)

## A pinned gauge, then the pointer passes over another lamp on its way to SHOW ME: the pin wins.
func debug_pin_pass() -> void:
	debug_pin()
	hover_row = 1
	_check(String(_shown().get("id", "")) == sel_station, "a pinned pop-up stays while the pointer crosses another lamp")
	_pin(sel_station)
	_check(sel_station == "", "a second click on the gauge closes the pop-up")
	_pin("fuel")
	_pin("power")
	_check(sel_station == "power", "clicking another gauge pins that one instead")
	_layout_hint()
	_click(close_r.get_center())
	_check(sel_station == "", "the close mark closes the pinned pop-up")
	_pin("power")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_input(esc)
	_check(sel_station == "", "Esc closes the pinned pop-up")
	print("debug_pin_pass done")

## Self-check: the guide cheers when the player finishes a step, then talks about the next one.
func debug_cheer() -> void:
	debug_bare()
	_guide_tick(0.0)
	var first: String = g_step
	for i: int in 12:
		if g_step != first:
			break
		_follow_lit()
		_guide_tick(0.0)
	_check(g_happy > 0.0 and (g_text.begins_with(CHEER[0]) or g_text.begins_with(CHEER[1]) or g_text.begins_with(CHEER[2])), "the guide cheers when a step is done: '%s'" % g_text)
	_guide_tick(1.5)
	_check(g_happy <= 0.0 and g_step != first and not g_text.is_empty(), "then the guide talks about the next step: '%s'" % g_text)
	hand = String(lit_fix.keys()[0]) if not lit_fix.is_empty() else ""
	_guide_tick(0.0)
	_check(hand == "" or g_text.begins_with("Now click the ship"), "with the part in the hand the guide says where to click: '%s'" % g_text)
	hand = ""
	print("debug_cheer done: %s -> %s" % [first, g_step])

## The guide mid-step on a bare ship: the line typed out, the ghost cursor halfway from the bin to the ship.
func debug_guide() -> void:
	debug_bare()
	_guide_tick(0.0)
	g_t = 99.0
	ghost_freeze = 0.95

## The EXPLORE bin (rovers, the drone, the crew cabin) with the crew cabin's card.
func debug_explore() -> void:
	tab = "robot"
	sel = "crew" if Data.PARTS.has("crew") else ""
	refresh()
	hover_tile = sel

## The guide hidden: the pop-up under the lamps shows the lit build step instead, as in v5.
func debug_noguide() -> void:
	debug_bare()
	_toggle_guide()

func debug_station_power() -> void:
	sel_station = "power"

func debug_station_booster() -> void:
	sel_station = "booster"

## An over-built ship: far more fuel and power than the mission needs (the markers sit past the bands).
func debug_over() -> void:
	Game.build["prop"] = mini(int(Data.PARTS["prop"]["max"]), Game.count("prop") * 2 + 12)
	var maker: String = "rtg" if Game.count("rtg") > 0 else "solar"
	Game.build[maker] = int(Data.PARTS[maker]["max"])
	refresh()
	sel_station = "fuel"

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
	for e: Dictionary in flashes:
		e["age"] = -0.8

## Two parts added to a bare ship: the lamps they moved show their delta chips (held on screen).
func debug_delta() -> void:
	debug_bare()
	_attach("solar", 1)
	_attach("battery", 1)
	for id: String in deltas:
		deltas[id]["age"] = -2.0

## A craft taller than the view, panned up by the mouse wheel.
func debug_pan() -> void:
	debug_max()
	pan_to = 60.0

## The example ship through the poll and on to the launch screen.
func debug_launch() -> void:
	_start_poll()

## SHOW ME from a bin left on another category.
func debug_show() -> void:
	debug_bare()
	tab = "launcher"
	sel = ""
	refresh()
	_show_me()

func debug_card() -> void:
	hover_tile = _tiles(tab)[1]

## A tile of one need level with its card: 0 required, 1 recommended, 2 optional, 3 not needed here.
func _debug_need(rank: int) -> void:
	for id: String in Data.PARTS:
		if id != "bus" and id != "prop" and int(NEED_RANK[_need(id)["level"]]) == rank:
			tab = _tab_of(id)
			sel = id
			hand = ""
			refresh()
			hover_tile = id
			return

func debug_need0() -> void:
	_debug_need(0)

func debug_need1() -> void:
	_debug_need(1)

func debug_need2() -> void:
	_debug_need(2)

func debug_need3() -> void:
	_debug_need(3)

## The card with its source line open (the small "i").
func debug_info() -> void:
	info_for = _card_tile()

func debug_help() -> void:
	help = true

func debug_p3() -> void:
	Game.players = 3
	refresh()

func debug_p4() -> void:
	Game.players = 4
	refresh()

## Every Tech Lab part unlocked.
func debug_tech() -> void:
	for id: String in Data.TECH:
		Game.tech[id] = true
	refresh()

## The all-GO moment: the last missing part goes on (shot at wait 0.5 to 1.2).
func debug_go() -> void:
	var last: String = "drone" if Game.count("drone") > 0 else "drill"
	Game.build.erase(last)
	refresh()
	_attach(last, 1)

## A ship that is too heavy because of spare fuel: the lit step says what to take off.
func debug_heavy() -> void:
	Game.build["prop"] = int(Data.PARTS["prop"]["max"])
	Game.rocket_id = "falcon9"
	refresh()

## From the bare ship, does what the lit step says until build step n is the lit one.
func _debug_to(n: int) -> void:
	debug_bare()
	auto = true
	for i: int in 60:
		if lit.is_empty() or lit.has("station") or steps.find(lit) >= n - 1:
			break
		_follow_lit()
	auto = false
	flashes.clear()
	guide = 3
	lit_key = ""
	refresh()

func debug_step2() -> void:
	_debug_to(2)

func debug_step3() -> void:
	_debug_to(3)

func debug_step4() -> void:
	_debug_to(4)

func debug_step5() -> void:
	_debug_to(5)

func debug_step6() -> void:
	_debug_to(6)

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
			var acts: Array[Callable] = [_undo, _redo, _plus, _minus, _fill, _toggle_help, _toggle_info, _show_me, _auto_build, _start_poll, _poll_fix]
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
		for open: String in ["", id]:
			info_for = open
			if _draw_card(null, id) > 0.0:
				print("debug_all %s: the card of %s does not fit" % [Game.dest_id, id])
		_remove(id, 1, true)
		_put_away()
		_remove(id, 99, false)
		if Game.count(id) != (1 if Data.PARTS[id].get("locked_in", false) else 0) and Game.part_available(id):
			print("debug_all: %s was not removed" % id)
		if n > 0 and Game.part_available(id):
			Game.build[id] = n
	for tile: String in _tiles("launcher"):
		_choose(tile)
		if _draw_card(null, tile) > 0.0:
			print("debug_all %s: the card of %s does not fit" % [Game.dest_id, tile])
	info_for = ""
	_fill()
	while not undo_stack.is_empty():
		_undo()
	_restore(keep)
	floats.clear()
	print("debug_all %s done" % Game.dest_id)

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

## Self-check: plays the screen with real click events on a bare ship. Prints only what fails.
func debug_clicks() -> void:
	debug_bare()
	var first: String = lit_fix.keys()[0]
	_check(tab == _tab_of(first) and sel == first and guide == 1, "the bin opens on the lit step's part")
	_click(_tab_rect(2).get_center())
	_check(tab == "comms", "a tab click opens that category")
	_show_me()
	_check(tab == _tab_of(first) and pulse.has(first), "SHOW ME brings the bin back to the lit part")
	_click(_tile_pos(first))
	_check(hand == first and guide == 2, "tile click puts the part in the hand; the direction moves to 2")
	_click(_org())
	_check(Game.count(first) == 1 and guide == 3, "click on the craft attaches; the direction moves to 3")
	_check(hand == "" and not lit_fix.has(first) and sel == String(lit_fix.keys()[0]), "the step moves on: the hand lets go and the bin shows the next part")
	tab = _tab_of(first)
	refresh()
	_click(_tile_pos(first))
	_click(_org(), MOUSE_BUTTON_RIGHT)
	_check(hand == "", "right-click puts the part away")
	var second: String = lit_fix.keys()[0]   # may be the same part again (Saturn needs a second RTG)
	var n2: int = Game.count(second)
	tab = _tab_of(second)
	refresh()
	_click(_tile_pos(second))
	_click(_tile_pos(second), MOUSE_BUTTON_LEFT, true)
	_check(flyers.size() == 1 and hand == "", "double-click sends the part flying")
	_process(0.5)
	_check(Game.count(second) == n2 + 1 and flyers.is_empty(), "the flying part lands")
	if _state("solar_lite") == "lock":
		tab = "power"
		refresh()
		_click(_tile_pos("solar_lite"))
		_check(hand == "" and Game.count("solar_lite") == 0 and sel == "solar_lite", "a locked tile only shows its card")
	var n1: int = Game.count(first) - 1
	_click(_item_center(first))
	_check(Game.count(first) == n1 and hand == first, "click on a part lifts it into the hand")
	_click(Vector2(190, 110))
	_check(hand == "" and Game.count(first) == n1, "dropping away from the craft returns it to the bin")
	n2 = Game.count(second) - 1
	_click(_item_center(second), MOUSE_BUTTON_RIGHT)
	_check(Game.count(second) == n2 and hand == "", "right-click removes a part")
	_remove("bus", 1, true)
	_check(Game.count("bus") == 1 and hand == "", "the bus stays")
	_check(lit.get("id", "") == "power" and lit_fix.has(first), "POWER is the lit step on a bare ship")
	want = _want()
	_check(want.get("tile", "") == first and want.has("slot"), "the lit part's slot is the one outline on the craft")
	_click((want["rect"] as Rect2).get_center())
	_check(hand == first, "click on the outlined slot takes that part")
	_click(_org())
	_put_away()
	var n: int = Game.count(first)
	_undo()
	_check(Game.count(first) == n - 1, "undo")
	_redo()
	_check(Game.count(first) == n, "redo")
	_click(_tab_rect(7).get_center())
	_fill()
	_check(_station("fuel")["status"] == "ok" and calc["use"]["fuel"]["rating"] == "well", "FILL TO NEED puts FUEL in the green band")
	tab = "fuel"
	refresh()
	x10 = true
	var fuel: int = Game.count("prop")
	_click(_tile_pos("prop"))
	_click(_org())
	_check(Game.count("prop") == fuel + 10, "x10 adds ten fuel units")
	_check(calc["use"]["fuel"]["rating"] == "over", "ten spare tanks rate as OVER")
	_put_away()
	x10 = false
	_click(rows[1].get_center())
	_check(sel_station == "power" and hint["station"]["id"] == "power", "click on a station row shows that station")
	_click(rows[1].get_center())
	_check(sel_station == "", "a second click lets it go")
	_click(_tab_rect(0).get_center())
	_click(_tile_pos("rocket:heavy"))
	_check(Game.rocket_id == "heavy", "rocket tile chooses the rocket")
	_click(_tile_pos("path:1"))
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
	_check(top.is_empty() and lit.is_empty() and b_go.visible, "the example ship is all GO: no step is lit, LAUNCH shows")
	print("debug_clicks %s done" % Game.dest_id)

## Does what the lit step says, the way SHOW ME points: its first highlighted tile.
## Returns what it did, "" when nothing is offered.
func _follow_lit() -> String:
	if lit_fix.is_empty():
		return ""
	var tile: String = lit_fix.keys()[0]
	var take_off: bool = int(lit_fix[tile]) < 0
	if tile == "prop":
		sel = "prop"
		tab = "fuel"
		_fill()
		return "FILL TO NEED"
	if take_off:
		_remove(tile, 1, false)
	elif _is_part(tile):
		_attach(tile, 1)
	else:
		_choose(tile)
	return ("-" if take_off else "") + tile

## Follows the lit step until nothing is lit and every station is GO. Returns "" when it gets there, else why it stopped.
func _follow(say: bool) -> String:
	var seen: Dictionary = {}
	for step: int in 150:
		if lit.is_empty():
			return "" if top.is_empty() else "%s is NO-GO but no step is lit" % top["id"]
		var what: String = "%s '%s'" % [String(lit["station"]["id"]) if lit.has("station") else String(lit["id"]), lit["hint"]]
		var key: String = "%s%s%d" % [str(Game.build), Game.rocket_id, Game.traj_idx]
		if seen.has(key):
			return "%s: the steps go in a circle" % what
		seen[key] = true
		var did: String = _follow_lit()
		if did == "":
			return "%s: nothing to do is offered" % what
		if say:
			print("JUDGE %s %d: %s -> %s" % [Game.dest_id, step + 1, what, did])
	return "still not GO after 150 steps"

## Self-check: a first-time player who starts with the bare ship and only does what the lit step says.
func debug_judge() -> void:
	debug_bare()
	var why: String = _follow(true)
	print("JUDGE %s: %s. %d warn. %s on %s" % [Game.dest_id, "ALL GO" if why == "" else "STUCK at " + why,
		Preflight.count(stations, "warn"), str(Game.build), Game.rocket_id])
	for s: Dictionary in stations:
		if s["status"] != "ok":
			print("JUDGE %s left %s: %s '%s' fixes %s" % [Game.dest_id, s["status"], s["id"], s["headline"], str(_fixes(s))])
	for key: String in calc["use"]:
		if calc["use"][key]["rating"] != "well":
			print("JUDGE %s use %s: %s" % [Game.dest_id, key, calc["use"][key]["rating"]])

## Follows the lit step from the ship in the environment variable VAB_SHIP
## ("<build as JSON>|<rocket id>|<path index>", as debug_fixes prints it), printing every step.
func debug_trace() -> void:
	var parts: PackedStringArray = OS.get_environment("VAB_SHIP").split("|")
	if parts.size() < 3:
		return
	var b: Dictionary = JSON.parse_string(parts[0])
	Game.build = {"bus": 1}
	for id: String in b:
		Game.build[id] = int(b[id])
	Game.rocket_id = parts[1]
	Game.traj_idx = int(parts[2])
	auto = true
	refresh()
	print("JUDGE trace: %s" % _follow(true))
	auto = false
	refresh()

## Self-check: from many random ships (any parts, any rocket, any path), following the lit step must always
## end with every station GO. Prints only what fails, once per kind.
func debug_fixes() -> void:
	var keep: Dictionary = _snap()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var said: Dictionary = {}
	auto = true   # no undo history, no effects, the bin stays put
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
		Game.traj_idx = rng.randi_range(0, (Game.dest()["traj"] as Array).size() - 1)
		var start: String = "%s %s path %d" % [str(Game.build), Game.rocket_id, Game.traj_idx]
		refresh()
		var why: String = _follow(false)
		if why != "" and not said.has(why.get_slice("'", 0)):
			said[why.get_slice("'", 0)] = true
			print("FIXES %s STUCK at %s\n   from %s\n   at %s %s path %d" % [Game.dest_id, why, start, str(Game.build), Game.rocket_id, Game.traj_idx])
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
	debug_bare()
	var first: String = lit_fix.keys()[0]
	var steps_xy: Array = [_tile_pos(first), Vector2.INF, b_plus.position + b_plus.size / 2.0, b_launch.position + b_launch.size / 2.0]
	var said: Array = ["the lit part is in the hand", "it is on the ship", "the plus button adds the next part", "LAUNCH opens the poll"]
	for i: int in steps_xy.size():
		var pos: Vector2 = steps_xy[i]
		if pos == Vector2.INF:
			pos = _org()
		var next: String = sel
		for pressed: bool in [true, false]:
			var ev: InputEventMouseButton = InputEventMouseButton.new()
			ev.position = pos
			ev.global_position = pos
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			get_viewport().push_input(ev)
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var ok: bool = [hand == first, Game.count(first) == 1, Game.count(next) == 1, not poll.is_empty()][i]
		if not ok:
			print("debug_route FAILED: %s" % said[i])
	print("debug_route done: %s %d, poll %s" % [first, Game.count(first), str(poll.get("phase", "none"))])

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
	t0 = Time.get_ticks_usec()
	for i: int in 10:
		refresh()
	print("debug_perf %s: %.2f ms per refresh (after every change to the ship)" % [Game.dest_id, (Time.get_ticks_usec() - t0) / 10000.0])

func _draw_bin_probe() -> void:
	_draw_card(null, _card_tile())
	ShipKit.layout(Game.build)
	ShipKit.bounds(Game.build)
	_part_at(mouse)

func _role_of(tile: String) -> String:
	var tb: String = _tab_of(tile)
	return String(Data.TAB_ROLE[tb]) if tb != "src" and Data.TAB_ROLE.has(tb) else ""

## "" when this player may change the tile, else the role whose part it is.

func _locked(tile: String) -> String:
	if not multi or remote_edit:
		return ""
	var r: String = _role_of(tile)
	return "" if r == "" or Net.owns(r) else r

func _deny_role(role: String) -> void:
	_deny("%s's part: use REQUEST" % Game.role_name(role))

## Online, a player who is not the host sends edits; the host applies them and sends the new build back.

func _remote() -> bool:
	return Net.is_online() and not Net.is_host()

## Host: another player's builder action, applied through the same code as a click, if they own that role.

func _apply_edit(d: Dictionary, from_id: int) -> void:
	var op: String = String(d.get("op", ""))
	var keep: Array = [sel, tab, hand, sel_station]
	remote_edit = true
	match op:
		"add", "remove":
			var id: String = String(d.get("id", ""))
			if Data.PARTS.has(id) and Game.sender_owns(from_id, _role_of(id)):
				var n: int = clampi(int(d.get("n", 1)), 1, int(Data.PARTS[id]["max"]))
				if op == "add":
					_attach(id, n)
				else:
					_remove(id, n, false)
		"rocket":
			var rk: String = String(d.get("id", ""))
			if Data.ROCKETS.has(rk) and Game.sender_owns(from_id, "planner"):
				_choose("rocket:" + rk)
		"traj":
			var i: int = int(d.get("i", -1))
			if i >= 0 and i < (Game.dest()["traj"] as Array).size() and Game.sender_owns(from_id, "planner"):
				_choose("path:%d" % i)
	remote_edit = false
	sel = keep[0]
	tab = keep[1]
	hand = keep[2]
	sel_station = keep[3]
	refresh()

func _toggle_sign() -> void:
	var mine: Array[String] = Net.my_roles()
	var on: bool = false
	for r: String in mine:
		on = on or not bool(Game.signed.get(r, false))
	for r: String in mine:
		Game.signed[r] = on
		Net.send("sign", {"role": r, "on": on})
	Audio.play("confirm" if on else "ui_close", -3.0)
	if on:
		var names: PackedStringArray = []
		for r: String in mine:
			names.append(Game.role_name(r))
		team.call("toast", "%s SIGNED" % " + ".join(names), Game.role_color(Game.my_role()))
	refresh()

func _request() -> void:
	team.call("toggle_request")

func _chat() -> void:
	team.call("toggle_chat", Vector2(b_chat.position.x - 120, 24))

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
	match kind:
		"edit":
			if Net.is_host():
				_apply_edit(d, from_id)
		"build":
			# Game has applied the snapshot already; the host also starts and stops the launch poll here
			if not Net.is_host() and Game.sender_is_host(from_id) and d.has("poll"):
				if String(d["poll"]) == "start" and poll.is_empty():
					_open_poll()
				elif String(d["poll"]) == "stop" and not poll.is_empty():
					poll = {}
					refresh()
		"sign":
			var role: String = String(d.get("role", ""))
			if bool(d.get("on", false)) and Game.sender_owns(from_id, role):
				team.call("toast", "%s SIGNED" % Game.role_name(role), Game.role_color(role))
			refresh()

## Every frame in multiplayer: the host sends its build when it changed; every player redraws the board
## for a new build, and hears when a change wiped the signatures.

func _team_tick() -> void:
	if not _remote() and not poll.is_empty() and not Game.all_signed():
		_stop_poll_all()
		poll = {}
		refresh()
	var s: Dictionary = Game.snap()
	if Net.is_online() and Net.is_host() and s != sent_snap:
		sent_snap = s
		Net.send("build", s)
	if s != seen_snap:
		if not poll.is_empty():
			_stop_poll_all()
			poll = {}
		seen_snap = s
		if _remote():
			Audio.play("part_snap", -4.0)
		if last_signed > 0 and Game.signed.is_empty():
			team.call("toast", "THE BUILD CHANGED: EVERYONE SIGNS AGAIN", UI.ORANGE)
		refresh()
	var n: int = Game.signed_count()
	if n != last_signed:
		last_signed = n
		refresh()
	Game.team_tick(top.is_empty(), Game.all_signed())
	var mine_signed: bool = true
	for r: String in Net.my_roles():
		mine_signed = mine_signed and bool(Game.signed.get(r, false))
	var want: String = "SIGNED" if mine_signed else "SIGN"
	if b_sign.text != want:
		b_sign.text = want
		if mine_signed:
			UI.color_button(b_sign, UI.GREEN)
		else:
			for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				b_sign.remove_theme_stylebox_override(st)
			for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b_sign.remove_theme_color_override(c)

func _open_poll() -> void:
	hand = ""
	help = false
	poll = {"i": -1, "t": 0.0, "phase": "call"}
	Audio.play("ui_open")
	refresh()

func _stop_poll_all() -> void:
	if Net.is_online() and Net.is_host() and not poll.is_empty():
		var s: Dictionary = Game.snap()
		s["poll"] = "stop"
		Net.send("build", s)
