extends Control
## Surface work on any landing world. Three jobs (V6_PLAN.md):
##   drill  the rover drives to glowing rocks and drills them, then drives back to the lander;
##   photo  the rover drives to flags and takes a picture at each (hold E), the photos go to Earth by radio;
##   crew   an astronaut on foot carries science stations from the lander to flags and sets them up (hold E)
##          while the suit's oxygen runs down, then walks back (Moon and Mars).
## The rover never jumps: it climbs small rocks slowly (rocker-bogie: the body tilts, each wheel follows
## the rock) and steers around big boulders by moving between two depth lanes (UP / DOWN).
## Depth in the style of a pixel racing game: three mountain ranges, a perspective floor
## (shaders/floor.gdshader), craters, hills and rocks at many depths, contact shadows, tracks.
## Every puff, glow, sparkle and sun goes through the shared effects kit (scripts/fx.gd).
## The world is read from Data.DEST: kind, air, returns, skin, hazards. Art is looked up by skin.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const EventCard = preload("res://scripts/event_card.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const WORLD: float = 4000.0
const PPM: float = 20.0          # px per metre at the front lane
const DAY_RATE: float = 0.3      # game rule: planet hours per real second (6 minutes a frame-second x 3)
const LANDER_X: float = 333.0
const LANDER_Y: float = 282.0    # the lander stands just behind both lanes
const HORIZON: float = 232.0
const LANE: float = 300.0        # screen y of the front lane (the floor shader's reference)
const LANES: Array[float] = [300.0, 286.0]   # front and back lane: UP / DOWN steers between them
const LANE_SPEED: float = 40.0   # px per second the rover steps back or forward in depth
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]
const CRATER_W: Array[int] = [18, 26, 40, 64, 98]
const HILL_W: Array[int] = [46, 84, 130]
const SPLIT: int = 38            # rover sprite rows above this are the body, below are the wheels
const WHEEL_X: Array[float] = [22.0, 43.0, 63.0]   # wheel centres in the 80 px rover frame
const WHEEL_EVENTS: Array[String] = ["stuck_wheel", "sharp_rocks"]
const ASCENT_MIN: float = 0.3    # game rule (Game.phase_home): the ascent stage needs 30% battery
const WHEEL_SLOW: float = 0.6    # game rule: a damaged wheel drags, the rover keeps 60% of its speed
const CLIMB_SLOW: float = 0.4    # game rule: climbing a rock, the rover crawls at 40% speed
const CLIMB_DRAW: float = 1.5    # game rule: and its motors draw 50% more power
const PHOTO_T: float = 1.2       # seconds to hold E for a picture
const PHOTO_GB: float = 0.5      # game rule: data per photo when no working science part makes any
const VF_RECT: Rect2 = Rect2(200, 104, 240, 135)   # where the viewfinder closes in (16:9)
const SETUP_T: float = 2.0       # seconds to hold E to set up a station
const STATION_GB: float = 1.0    # game rule: data per station when no working science part makes any
const SUIT_HOURS: float = 8.0    # real: an Apollo or Artemis suit carries about 8 hours of oxygen
const SUIT_SECONDS: float = 90.0 # game rule: those 8 hours pass in 90 s on NORMAL (EASY 150 s, HARD 64 s)
const O2_LOW: float = 0.25       # game rule: under a quarter left, head back to the lander
const WALK_SPEED: float = 70.0   # px per second on foot (game rule, faster than a real astronaut)
const HOP_M: float = 0.2         # m: height of a low-gravity lope (Apollo crews hopped like this)
## Game rule: the energy one target takes from the battery (drill motor and sample oven; camera and the
## radio that sends the picture; the station's start-up power from the lander), times Game.diff("drain").
const WORK_WH: Dictionary = {"drill": 0.42, "photo": 0.45, "crew": 0.55}   # share of the sized battery that all targets cost together (game rule)

## How each landing world looks (research/v5/skins.md). Art settings, not facts.
## shadow: px from the lander to the rim of a permanently shadowed crater that holds the samples.
const SKIN: Dictionary = {
	"moon": {"haze": "2a2c3a", "haze_max": 0.75, "haze_tint": "7a7c92", "dust": "b9b9c6", "fill": "", "tint": "ffffff",
		"light": "ffffff", "accent": "3a4a7a", "body": [0.03, 0.04, 0.08, 0.82], "noun": "ROCK", "stars": true, "earth": true},
	"mercury": {"haze": "141210", "haze_max": 0.7, "haze_tint": "4a443c", "dust": "a49684", "fill": "100e0b", "tint": "ffffff",
		"light": "ffffff", "accent": "6a6258", "body": [0.05, 0.045, 0.04, 0.85], "noun": "ICE", "stars": true, "big_sun": true, "shadow": 400.0},
	"venus": {"haze": "d8a650", "haze_max": 0.95, "haze_tint": "d8a650", "dust": "c08848", "fill": "d8a650", "tint": "ffffff",
		"light": "e6b878", "accent": "9a6a34", "body": [0.17, 0.09, 0.03, 0.86], "noun": "ROCK", "clouds": true, "bolts": true},
	"mars": {"haze": "c99470", "haze_max": 0.85, "haze_tint": "e8b890", "dust": "d98a55", "fill": "e8c49c", "tint": "dbccc7",
		"light": "ffffff", "accent": "8a5a3c", "body": [0.16, 0.08, 0.06, 0.85], "noun": "ROCK", "clouds": true, "devils": true, "moonlet": true},
}

var t: float = 0.0
var state: String = "explore"
var end_t: float = 0.0
var banner: String = ""
var d: Dictionary = {}
var sk: Dictionary = {}
var skin: String = "moon"
var air: String = "none"
var job: String = "drill"
var g: float = 1.62
var rx: float = LANDER_X + 85.0
var ry: float = LANE             # screen y under the rover or astronaut (moves between the lanes)
var lane: int = 0
var face: float = 1.0
var moving: bool = false
var has_rover: bool = false
var crew: bool = false
var speed: float = 100.0
var wheel_k: float = 1.0
var climbing: bool = false
var climb_told: bool = false
var drilling: float = 0.0
var drill_target: int = -1
var work: float = 0.0            # 0..1 progress of a held E (photo or station)
var samples: Array = []          # the job's targets: rocks, viewpoints or station sites {"x", "taken"}
var boulders: Array = []         # big boulders to steer around {"x" left edge, "lane"}
var rocks: Array = []            # small rocks to climb {"x" centre, "lane", "k", "h", "w"}
var got: int = 0
var goal: int = 3
var data: float = 0.0
var gb_each: float = 0.0
var battery: float = 0.0
var wh: float = 1.0
var base_draw: float = 0.0
var drill_draw: float = 0.0
var rover_draw: float = 0.0
var solar: float = 0.0
var rtg: float = 0.0
var gen_now: float = 0.0
var draw_now: float = 0.0
var hour: float = 8.0
var h_rate: float = DAY_RATE
var drain: float = 1.0           # Game.diff("drain"): battery and oxygen use by the level
var fail: int = 0                # Game.diff("fail"): 0 nothing is lost, 1 the last targets, 2 all of them
var assist: int = 2              # Game.diff("assist"): 2 every direction, 1 only the target marker, 0 none
var bite: float = 1.0
var cost: float = 0.0            # Wh each target takes (WORK_WH x drain)
var bat_shown: float = 0.0       # the battery the gauge shows: it slides down to the real value
var store_cap: float = 1e9       # Gb the recorders hold (Game.live_store)
var deny_t: float = -9.0
var banner_col: Color = UI.YELLOW
var gb_sample: float = 0.0
var shadow_x: float = -1.0       # world x where the crater's permanent shadow begins (-1 = none)
var life_min: float = 0.0        # minutes the lander lives here (0 = no heat clock)
var minutes: float = 0.0         # minutes spent on the surface (heat clock)
var min_rate: float = 0.0        # minutes per real second
var o2: float = 1.0              # suit oxygen left, 0..1 (crew)
var o2_secs: float = SUIT_SECONDS
var carrying: bool = false
var walk_d: float = 0.0
var hop_ph: float = 0.0
var fired: int = 0
var hazard_hit: bool = false
var ev_cool: float = 0.0
var card: Control = null
var card_ev: Dictionary = {}
var help_on: bool = false
var low_warned: bool = false
var auto: bool = false
var photos: Array[Texture2D] = []
var flash_t: float = -9.0
var tex_lander: Texture2D = null
var tex_rover: Texture2D = null
var tex_astro: Texture2D = null
var tex_station: Texture2D = null
var tex_box: Texture2D = null
var tex_flag: Texture2D = null
var tex_camera: Texture2D = null
var tex_earth: Texture2D = null
var tex_halo: Texture2D = null
var tex_dist: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_boulder: Texture2D = null
var tex_sample: Texture2D = null
var tex_pebble: Array[Texture2D] = []
var tex_crater: Array[Texture2D] = []
var tex_hill: Array[Texture2D] = []
var tex_sky_day: Texture2D = null
var tex_sky_night: Texture2D = null
var tex_cloud: Array[Texture2D] = []
var tex_phobos: Texture2D = null
var tex_sun: Texture2D = null
var tex_devil: Texture2D = null
var tex_sheet: Texture2D = null
var tex_streak: Texture2D = null
var tex_scorch: Texture2D = null
var tex_marker: Texture2D = null
var tex_arrow: Texture2D = null
var tex_chip: Texture2D = null
var puffs: Array = []
var chips: Array = []
var pops: Array = []
var decor: Array = []
var tracks: PackedVector2Array = PackedVector2Array()
var last_track: float = -100.0
var puff_t: float = 0.0
var chip_t: float = 0.0
var hit_t: float = 0.0
var got_t: float = -9.0
var haze_tint: Color = Color.WHITE
var dust_col: Color = Color.WHITE
var light: Color = Color.WHITE
var pan_accent: Color = Color("3a4a7a")
var pan_body: Color = Color(0.03, 0.04, 0.08, 0.82)
var hold: Dictionary = {}
var floor_mat: ShaderMaterial = null
var front: Control = null

## The job of this task: "drill", "photo" or "crew" (V6_PLAN.md; the debug hook can force it with job=).
func _job() -> String:
	return String(Game.run.get("job", Game.task().get("job", "drill")))

func _ready() -> void:
	d = Game.dest()
	skin = String(d["skin"])
	sk = SKIN.get(skin, SKIN["moon"])
	air = String(d["air"])
	g = float(d["gravity"])
	goal = int(d["samples_goal"])
	job = _job()
	crew = job == "crew"
	var hz: float = Game.diff("surface_hazards")
	drain = Game.diff("drain")
	fail = int(Game.diff("fail"))
	assist = int(Game.diff("assist"))
	bite = Game.diff("bite")
	o2_secs = SUIT_SECONDS / drain
	# Game rule: all the targets together cost a share of the battery this mission is sized for (the green
	# line of the BATTERY lamp, at least one 2,000 Wh pack), so a well-built ship finishes on every world, a
	# short one runs dry and a bigger battery lasts longer. WORK_WH is that share per job, x drain per level.
	var bat_row: Dictionary = (Game.run.get("use", {}) as Dictionary).get("battery", {})
	var ref_wh: float = maxf(2000.0, float(bat_row.get("lo", 0.0)))
	cost = minf(float(WORK_WH.get(job, 0.6)) * drain * ref_wh / maxf(1.0, float(Game.dest()["samples_goal"])), 0.5 * float(Game.run.get("wh", 2000.0)))
	store_cap = Game.live_store()
	tex_lander = Pix.img("lander")
	tex_rover = Pix.img("rover")
	tex_astro = Pix.img("surface_v6/astronaut")
	tex_station = Pix.img("surface_v6/station")
	tex_box = Pix.img("surface_v6/station_box")
	tex_flag = Pix.img("surface_v6/flag_site" if crew else "surface_v6/flag_photo")
	tex_camera = Pix.img("surface_v6/ic_camera")
	tex_dist = Pix.img("surface/%s_range_dist" % skin)
	tex_far = Pix.img(skin + "_range_far")
	tex_mid = Pix.img(skin + "_range_near")
	tex_boulder = Pix.img("boulder_%s_50" % skin)
	tex_sample = Pix.img("sample_%s_big" % skin)
	tex_scorch = Pix.img("surface/scorch")
	tex_marker = Pix.img("surface/marker")
	tex_arrow = Pix.img("surface/arrow_r")
	tex_chip = Pix.img("surface/chip")
	tex_streak = Pix.img("surface/streak")
	for i: int in PEBBLE_W.size():
		tex_pebble.append(Pix.img("pebble_%s_%d" % [skin, i]))
	for i: int in CRATER_W.size():
		tex_crater.append(Pix.img("surface/crater_%s_%d" % [skin, i]))
	for i: int in HILL_W.size():
		tex_hill.append(Pix.img("surface/hill_%s_%d" % [skin, i]))
	if skin != "moon":
		tex_sky_day = Pix.img("surface/%s_sky_day" % skin)
		tex_sky_night = Pix.img("surface/%s_sky_night" % skin)
	if bool(sk.get("earth", false)):
		tex_earth = Pix.planet(22, "earth")
		tex_halo = Pix.img("surface/earth_halo")
	if bool(sk.get("clouds", false)):
		for i: int in 3:
			tex_cloud.append(Pix.img("surface/%s_cloud_%d" % [skin, i]))
	if bool(sk.get("moonlet", false)):
		tex_phobos = Pix.img("surface/phobos")
	if bool(sk.get("big_sun", false)):
		tex_sun = Pix.img("surface/%s_sun" % skin)
	if bool(sk.get("devils", false)):
		tex_devil = Pix.img("surface/dust_devil")
		tex_sheet = Pix.img("surface/dust_sheet")
	elif bool(sk.get("bolts", false)):
		tex_devil = Pix.img("surface/%s_lightning" % skin)
		tex_sheet = Pix.img("surface/%s_haze" % skin)
	haze_tint = Color(String(sk["haze_tint"]))
	dust_col = Color(String(sk["dust"]))
	light = Color(String(sk["light"]))
	pan_accent = Color(String(sk["accent"]))
	var bd: Array = sk["body"]
	pan_body = Color(float(bd[0]), float(bd[1]), float(bd[2]), float(bd[3]))
	var c: Dictionary = Game.run["calc"]
	has_rover = not crew and (Game.id_has("rover") or Game.id_has("rover_big"))
	if has_rover and Game.id_has("rover_big"):
		speed = 183.0
		rover_draw = float(Data.PARTS["rover_big"]["draw"])
	elif has_rover:
		rover_draw = float(Data.PARTS["rover"]["draw"])
	if Game.id_has("drill"):
		drill_draw = float(Data.PARTS["drill"]["draw"])
	base_draw = float(c["draw_ops"]) - drill_draw - rover_draw
	solar = float(c["solar_dest"])
	rtg = float(c["rtg"])
	wh = maxf(1.0, float(Game.run["wh"]))
	battery = float(Game.run["battery"])
	bat_shown = battery
	_reload()
	# the heat clock: where the lander lives only minutes, the whole site runs on its clock
	if d.has("surface_minutes"):
		life_min = float(d["surface_minutes"])
		if not Game.id_has("hull"):
			life_min *= 0.2   # game rule: without the pressure hull the lander would last a fraction of it
		min_rate = 1.25 + 1.25 * hz   # game rule: EASY 2.0, NORMAL 2.5, HARD 3.0 minutes per second
		h_rate = min_rate / 60.0
	_lay_out(hz)
	_scenery()
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + skin))
	floor_mat.set_shader_parameter("haze", Color(String(sk["haze"])))
	floor_mat.set_shader_parameter("haze_max", float(sk["haze_max"]))
	floor_mat.set_shader_parameter("horizon", HORIZON)
	floor_mat.set_shader_parameter("lane", LANE)
	floor_mat.set_shader_parameter("top", HORIZON)
	floor_mat.set_shader_parameter("size", Vector2(640, 360 - HORIZON))
	var fl: ColorRect = ColorRect.new()
	fl.position = Vector2(0, HORIZON)
	fl.size = Vector2(640, 360 - HORIZON)
	fl.material = floor_mat
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fl)
	front = Control.new()
	front.size = Vector2(640, 360)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)
	add_child(front)
	if DisplayServer.is_touchscreen_available():
		_hold_buttons()

## Where the targets, boulders and small rocks lie. Spacing by the difficulty: a normal visit is about a minute.
func _lay_out(hz: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(skin)
	if crew:
		rx = LANDER_X + 46.0
		carrying = true
		for i: int in goal:
			samples.append({"x": LANDER_X + 150.0 + i * (95.0 + 25.0 * hz) + rng.randf_range(-12, 12), "taken": false})
		return
	if not has_rover:
		samples.append({"x": LANDER_X + 117.0, "taken": false})   # only what the lander's own arm reaches
		return
	var gap: float = 230.0 + 110.0 * hz   # game rule: EASY 296 px apart, NORMAL 340, HARD 384
	var first: float = LANDER_X + 260.0 + 80.0 * hz
	if sk.has("shadow") and job == "drill":
		cost *= 0.5   # game rule: in the sunless crater the rover already lives on its battery, so each drill takes half
		shadow_x = LANDER_X + float(sk["shadow"])
		first = shadow_x + 100.0
	var prev: float = LANDER_X + 200.0
	for i: int in goal + 1:
		var sx: float = first + i * gap + rng.randf_range(-30, 30)
		samples.append({"x": sx, "taken": false})
		# one big boulder half-way (in a random lane) and a small rock or two to climb
		var mid: float = (prev + sx) * 0.5
		var b_lane: int = -1
		if sx - prev > 200.0 and rng.randf() < 0.45 + 0.35 * hz:
			b_lane = rng.randi() % 2
			boulders.append({"x": mid - 33.0, "lane": b_lane})
		for j: int in 1 + int(rng.randf() < hz * 0.5):
			var rxp: float = lerpf(prev + 30.0, sx - 50.0, rng.randf_range(0.0, 0.3) if j == 0 else rng.randf_range(0.7, 1.0))
			var k: int = 4 if rng.randf() < 0.3 * hz else 3
			var tex: Texture2D = tex_pebble[k]
			var r_lane: int = rng.randi() % 2
			if r_lane == b_lane and absf(rxp - mid) < 80.0:
				r_lane = 1 - r_lane
			rocks.append({"x": rxp, "lane": r_lane, "k": k, "h": float(tex.get_height() - 3), "w": float(tex.get_width() + 14)})
		prev = sx + 60.0

## Scenery at many depths (s = distance, 1 at the lane, >1 behind, <1 in front): k 0 rock, 1 crater, 2 low hill.
func _scenery() -> void:
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = hash(skin) + 21
	var crater_k: float = 0.45 if air == "none" else 0.25   # airless worlds keep every crater sharp
	for i: int in 300:
		var s: float = exp(rd.randf_range(log(0.55), log(9.0)))
		if s > 0.8 and s < 1.45:
			continue
		var span: float = 320.0 * s + 60.0
		var k: int = 0
		var roll2: float = rd.randf()
		if s > 3.0 and roll2 < 0.18:
			k = 2
		elif s > 1.0 and roll2 < crater_k:
			k = 1
		var size_px: float = rd.randf_range(8.0, 44.0) * (0.45 if s < 1.0 else 1.0)
		if k == 1:
			size_px = rd.randf_range(40.0, 160.0)
		elif k == 2:
			size_px = rd.randf_range(150.0, 700.0)
		decor.append({"x": rd.randf_range(320.0 - span, WORLD - 320.0 + span), "s": s, "b": size_px, "k": k})
	decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))

func _exit_tree() -> void:
	Engine.time_scale = 1.0   # the autopilot test speeds the game up
	Audio.loop("drill", false)
	Audio.loop("rover_loop", false)

## Data per target (sample, photo or station) from the instruments that still work (Game.part_science:
## on a photo task the camera makes a full panorama). If none is working, a labelled game rule.
func _reload() -> void:
	gb_sample = 0.0
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(Game.part_science(id)[0])
	gb_each = gb_sample
	if gb_each <= 0.0 and job != "drill":
		gb_each = PHOTO_GB if job == "photo" else STATION_GB

func _drill_ok() -> bool:
	return Game.id_has("drill") and not Game.run["broken"].has("drill")

## The job can still be done: a drill for drilling; photos and stations need nothing that events break.
func _tool_ok() -> bool:
	return _drill_ok() if job == "drill" else true

func _hold_buttons() -> void:
	var act: String = {"drill": "DRILL", "photo": "PHOTO", "crew": "SET UP"}.get(job, "E")
	var defs: Array = [["<", 8, 40, "l"], [">", 52, 40, "r"], [act, 540, 92, "e"]]
	if has_rover:
		defs.append(["UP", 400, 56, "u"])
		defs.append(["DOWN", 460, 70, "d"])
	for df: Array in defs:
		var b: Button = Button.new()
		b.text = df[0]
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
		b.position = Vector2(float(df[1]), 300)
		b.size = Vector2(float(df[2]), 28)
		var key: String = df[3]
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold.erase(key))

func _in_shadow(x: float) -> bool:
	return shadow_x >= 0.0 and x >= shadow_x

func _pressed(key: Key, act: String, h: String) -> bool:
	return hold.has(h) or Input.is_physical_key_pressed(key) or (act != "" and Input.is_action_pressed(act))

func _holding_e() -> bool:
	return hold.has("e") or Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_ENTER)

func _input(event: InputEvent) -> void:
	if EventCard.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_E or k.keycode == KEY_ENTER:
			_use()
		elif k.physical_keycode == KEY_H or k.physical_keycode == KEY_SLASH or k.physical_keycode == KEY_F1:
			help_on = not help_on
			Audio.play("ui_click", -8.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _help_rect().has_point((event as InputEventMouseButton).position) or help_on:
			help_on = not help_on
			Audio.play("ui_click", -8.0)

func _help_rect() -> Rect2:
	return Rect2(617, 6, 17, 17)

func _reach() -> float:
	if crew:
		return 18.0
	if not has_rover:
		return 150.0
	return 28.0 if job == "photo" else 40.0

func _at_lander() -> bool:
	if not has_rover and not crew:
		return true   # nothing moves: the lander is where we are
	return absf(rx - LANDER_X) < (50.0 if crew else 70.0)

## Index of the closest target still to do, or -1. On foot the stations go out in order.
func _nearest() -> int:
	var best: int = -1
	var bd: float = 1e9
	for i: int in samples.size():
		if samples[i]["taken"]:
			continue
		if crew:
			return i
		if absf(float(samples[i]["x"]) - rx) < bd:
			bd = absf(float(samples[i]["x"]) - rx)
			best = i
	return best

## True when it is time to head for the lander: all done, nothing left to do, or the battery (oxygen) low.
func _go_home() -> bool:
	if crew:
		return got >= goal or _nearest() < 0 or o2 < O2_LOW
	return got >= goal or _nearest() < 0 or not _tool_ok() or _low()

## Battery under 20% and still falling (charging in the sun is fine).
func _low() -> bool:
	return battery / wh < 0.2 and gen_now < draw_now

## World x of where to go now.
func _target() -> float:
	if _go_home() or (crew and not carrying):
		return LANDER_X
	return float(samples[_nearest()]["x"])

## The target in reach right now (index), or -1.
func _at_target() -> int:
	if _go_home() or (crew and not carrying):
		return -1
	var i: int = _nearest()
	return i if absf(float(samples[i]["x"]) - rx) < _reach() else -1

func _word() -> String:
	if job == "photo":
		return "PHOTOS"
	if crew:
		return "STATIONS"
	return "SAMPLES" if String(sk["noun"]) == "ROCK" else "ICE SAMPLES"

## E pressed once: drill the rock in reach (drill job); on the other jobs E is held (see _work).
func _use() -> void:
	if state != "explore" or drilling > 0.0 or EventCard.is_open():
		return
	if job != "drill":
		if _at_target() < 0 and not _go_home():
			_deny("FIRST GO TO THE FLAG")
		return
	var i: int = _at_target()
	if i < 0:
		if not _go_home():
			_deny("NOTHING TO DRILL HERE")
		return
	if battery < cost:
		_deny("NEED %d Wh TO DRILL: WAIT IN THE SUN" % roundi(cost))
		return
	drilling = 2.0
	drill_target = i
	_pop(rx, ry - 70.0, "-%d Wh" % roundi(cost), UI.BAD)
	face = 1.0 if float(samples[i]["x"]) >= rx or not has_rover else -1.0

## A small text over the scene, coloured by what it means: UI.BAD a loss, UI.RISK a warning, UI.GOOD a gain.
func _pop(x: float, y: float, s: String, c: Color = UI.RISK) -> void:
	pops.append({"x": x, "y": y, "age": 0.0, "s": s, "spark": false, "c": c})

## A refused action: a yellow pop and a buzz, at most twice a second.
func _deny(s: String) -> void:
	if t - deny_t < 0.6:
		return
	deny_t = t
	_pop(rx, ry - 70.0, s, UI.RISK)
	Audio.play("ui_deny", -6.0)

## The battery or the suit ran out. What it costs depends on the level (V7_PLAN.md, Game.diff("fail")):
## EASY nothing, the outing ends with what was collected; NORMAL the last target(s), x bite; HARD all of
## them when it happens away from the lander (or on foot).
func _empty(cause: String, fix: String, easy: String) -> void:
	var lost: int = 0
	if fail >= 2 and (crew or not _at_lander()):
		lost = got
	elif fail >= 1:
		lost = mini(got, ceili(bite))
	if lost <= 0:
		_finish(easy, UI.RISK if fail == 0 else UI.BAD)
		return
	var all: bool = lost == got
	got -= lost
	data = maxf(0.0, data - gb_each * lost)
	_pop(rx, ry - 84.0, "-%d %s" % [lost, _word()], UI.BAD)
	_finish("%s: %s%d %s LOST. FIX: %s" % [cause, "ALL " if all and lost > 1 else "", lost, _word(), fix], UI.BAD)

func _finish(text: String, col: Color = UI.YELLOW) -> void:
	if state != "explore":
		return
	state = "done"
	end_t = t + 2.5
	banner = text
	banner_col = col
	hold.clear()
	work = 0.0
	if auto:
		print("SURFACE AUTOPILOT (%s): %s. %d/%d, battery %d%%, oxygen %d%%, events %d, t %.1f s" % [job, text, got, goal, roundi(100.0 * battery / wh), roundi(o2 * 100.0), fired, t])
	Audio.loop("drill", false)
	Audio.loop("rover_loop", false)
	var bad: bool = battery <= 0.0 or o2 <= 0.0 or (life_min > 0.0 and _life_left() <= 0.0)
	Audio.play("error" if bad else "confirm", -4.0)

func _life_left() -> float:
	return life_min - minutes - float(Game.run.get("minutes_lost", 0.0))

func _physics_process(delta: float) -> void:
	if auto:
		_auto_step()
	if EventCard.is_open():
		Audio.loop("drill", false)
		Audio.loop("rover_loop", false)
		return
	t += delta
	ev_cool -= delta
	_particles(delta)
	if state != "explore":
		if t > end_t:
			set_physics_process(false)
			Game.surface_result(got, battery, data)
			Game.goto("cheer")
		return
	if hold.has("e") and job == "drill":
		hold.erase("e")
		_use()
	# power: the Sun (day and night where there are nights, nothing inside the crater's shadow)
	var draw: float = base_draw
	var sun: float = 1.0
	if float(d["night_hours"]) > 0.0:
		hour = fposmod(8.0 + t * h_rate, 24.66)
		sun = maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 1.57
	if _in_shadow(rx):
		sun = 0.0
	var gen: float = solar * float(Game.run["gen_mult"]) * sun + rtg
	moving = false
	if drilling > 0.0:
		draw += drill_draw
		battery = maxf(0.0, battery - cost * minf(delta, drilling) / 2.0)   # the drill's share, over its 2 s
		drilling -= delta
		if drilling <= 0.0:
			drilling = 0.0
			_score(drill_target, "+1 SAMPLE")
	elif has_rover:
		draw += _drive(delta)
	elif crew:
		_walk(delta)
	_work(delta)
	if crew:
		o2 = maxf(0.0, o2 - delta / o2_secs)
	Audio.loop("drill", drilling > 0.0, -12.0)
	Audio.loop("rover_loop", moving and has_rover, -10.0 if not climbing else -6.0, 0.8 if climbing else 1.0)
	gen_now = gen
	draw_now = draw
	var net: float = gen - draw
	if net < 0.0:
		net *= drain
	battery = clampf(battery + net * delta * h_rate, 0.0, wh)
	if life_min > 0.0:
		minutes += delta * min_rate
	# hazards: the moments a site event may come up
	if _in_shadow(rx) or _night() > 0.3 or (life_min > 0.0 and _life_left() < life_min * 0.5) or got >= 2:
		hazard_hit = true
	var low: bool = o2 < O2_LOW if crew else _low()
	if low and not low_warned:
		low_warned = true
		hazard_hit = true
		Audio.play("alarm" if crew else "battery_low", -4.0)
		_pop(rx, ry - 84.0, "OXYGEN LOW: WALK BACK" if crew else "LOW BATTERY: HEAD BACK", UI.RISK)
	if battery <= 0.0:
		_empty("BATTERY EMPTY" + ("" if _at_lander() else " FAR FROM THE LANDER"), "MORE BATTERY OR SOLAR, WAIT IN THE SUN",
			"BATTERY EMPTY: THE %s SHUT DOWN" % ("ROVER" if has_rover else "LANDER"))
	elif crew and o2 <= 0.0:
		_empty("OXYGEN EMPTY", "WALK BACK WHEN OXYGEN TURNS YELLOW", "OXYGEN EMPTY: THE RESERVE TANK GOT YOU BACK")
	elif life_min > 0.0 and _life_left() <= 0.0:
		_finish("TOO HOT: THE LANDER DIED AFTER %d min" % roundi(minutes), UI.BAD)
	elif job == "photo" and got >= goal:
		_finish("ALL %d PHOTOS SENT TO EARTH" % goal, UI.GOOD)
	elif _go_home() and _at_lander():
		_finish("BACK AT THE LANDER: %d OF %d %s" % [got, goal, _word()], UI.GOOD if got >= goal else UI.RISK)
	else:
		_maybe_event()

## One target done: count it, its data, a pop and a sound.
func _score(i: int, text: String) -> void:
	samples[i]["taken"] = true
	got += 1
	var add: float = minf(gb_each, maxf(0.0, store_cap - data))
	data += add
	got_t = t
	var sx: float = float(samples[i]["x"])
	pops.append({"x": sx, "y": LANE - 30.0, "age": 0.0, "s": text, "spark": true, "c": UI.GOOD})
	if add < gb_each:
		_pop(sx, LANE - 58.0, "STORAGE FULL: DATA LOST", UI.BAD)
	elif add > 0.0:
		_pop(sx, LANE - 58.0, "+%s Gb" % String.num(add, 1), UI.GOOD)
	Audio.play("pickup")
	if got == goal:
		Audio.play("success", -4.0)

## The rover: LEFT / RIGHT drive, UP / DOWN step between the lanes; boulders block, small rocks slow it.
## Returns the power the wheels draw.
func _drive(delta: float) -> float:
	var dir: float = 0.0
	if _pressed(KEY_A, "ui_left", "l"):
		dir -= 1.0
	if _pressed(KEY_D, "ui_right", "r"):
		dir += 1.0
	if lane == 0 and _pressed(KEY_W, "ui_up", "u"):
		_switch(1)
	elif lane == 1 and _pressed(KEY_S, "ui_down", "d"):
		_switch(0)
	ry = move_toward(ry, LANES[lane], LANE_SPEED * delta)
	var was: bool = climbing
	climbing = _wheel_lift(0) > 0.5 or _wheel_lift(1) > 0.5 or _wheel_lift(2) > 0.5
	if climbing and not was and not climb_told:
		climb_told = true
		_pop(rx, ry - 70.0, "SMALL ROCK: CLIMBING SLOWLY", UI.RISK)
	if dir == 0.0 or work > 0.0:
		return 0.0
	face = dir
	var nx: float = clampf(rx + dir * speed * wheel_k * (CLIMB_SLOW if climbing else 1.0) * delta, 40.0, WORLD - 40.0)
	if _blocked(nx, ry):
		return 0.0
	rx = nx
	moving = true
	if absf(rx - last_track) >= 3.0:
		tracks.append(Vector2(rx, ry))  # no wind on an airless world: tracks there last for millions of years
		last_track = rx
		if tracks.size() > 3000:
			tracks.remove_at(0)
	return rover_draw * (CLIMB_DRAW if climbing else 1.0)

func _switch(to: int) -> void:
	if _blocked(rx, LANES[to]):
		return
	lane = to
	Audio.play("ui_tab", -12.0)

## A big boulder in the way of a rover at x on the lane at screen y.
func _blocked(x: float, y: float) -> bool:
	for b: Dictionary in boulders:
		var bx: float = float(b["x"])
		if absf(LANES[int(b["lane"])] - y) < 10.0 and x + 34.0 > bx + 6.0 and x - 30.0 < bx + 61.0:
			return true
	return false

## The nearest boulder ahead on the rover's lane within `look` px, or -1.
func _boulder_ahead(dir: float, look: float = 130.0) -> int:
	for i: int in boulders.size():
		var b: Dictionary = boulders[i]
		if int(b["lane"]) != lane:
			continue
		var bx: float = float(b["x"]) + 33.0
		if signf(bx - rx) == dir and absf(bx - rx) < look:
			return i
	return -1

## How high a small rock lifts the rover's wheel w (0 rear, 1 middle, 2 front) on its lane, in px.
func _wheel_lift(w: int) -> float:
	return _lift(rx + face * (WHEEL_X[w] - 37.0))

func _lift(x: float) -> float:
	var y: float = 0.0
	for r: Dictionary in rocks:
		if absf(LANES[int(r["lane"])] - ry) > 4.0:
			continue
		var hw: float = float(r["w"]) * 0.5
		var dx: float = absf(x - float(r["x"]))
		if dx < hw:
			y = maxf(y, float(r["h"]) * 0.5 * (1.0 + cos(PI * dx / hw)))
	return y

## The astronaut: LEFT / RIGHT walk (a lope on the Moon). Picks up the next station at the lander.
func _walk(delta: float) -> void:
	var dir: float = 0.0
	if _pressed(KEY_A, "ui_left", "l"):
		dir -= 1.0
	if _pressed(KEY_D, "ui_right", "r"):
		dir += 1.0
	if dir != 0.0 and work <= 0.0:
		face = dir
		rx = clampf(rx + dir * WALK_SPEED * delta, 40.0, WORLD - 40.0)
		moving = true
		walk_d += WALK_SPEED * delta
		if _lope():
			var air_t: float = 2.0 * sqrt(2.0 * HOP_M / g)   # real ballistic hop time
			var before: float = hop_ph
			hop_ph = fposmod(hop_ph + delta / air_t, 1.0)
			if hop_ph < before:   # boots down: a print and a little dust
				_boot_down()
		elif int(walk_d / 20.0) != int((walk_d - WALK_SPEED * delta) / 20.0):
			_boot_down()
	else:
		hop_ph = 0.0
	if not carrying and not _go_home() and absf(rx - LANDER_X) < 50.0:
		carrying = true
		_pop(LANDER_X, LANDER_Y - 80.0, "STATION %d OF %d" % [got + 1, goal], UI.TEXT)
		Audio.play("part_pick", -4.0)

func _lope() -> bool:
	return g < 2.0

func _boot_down() -> void:
	tracks.append(Vector2(rx + face * 2.0, ry))
	if tracks.size() > 3000:
		tracks.remove_at(0)
	for i: int in 3:
		puffs.append({"p": Vector2(rx + randf_range(-4, 4), ry - 1.0), "v": Vector2(randf_range(-14, 14), -randf_range(4, 14)), "age": 0.0, "life": randf_range(0.3, 0.6), "size": 0})

## Held E: a picture at a flag (photo) or a station set up at a flag (crew).
func _work(delta: float) -> void:
	if job == "drill":
		return
	var i: int = _at_target()
	if i < 0 or moving or not _holding_e():
		work = maxf(0.0, work - delta * 3.0)
		return
	if work <= 0.0:
		if battery < cost:
			_deny("NEED %d Wh: WAIT IN THE SUN" % roundi(cost))
			return
		_pop(rx, ry - 70.0, "-%d Wh" % roundi(cost), UI.BAD)
	if not has_rover and not crew:
		face = 1.0
	if crew:
		# kneel beside the flag, facing it, with the station in front of the hands
		var sx: float = float(samples[i]["x"])
		face = 1.0 if sx >= rx else -1.0
		rx = move_toward(rx, sx - face * 16.0, 60.0 * delta)
	var step: float = delta / (SETUP_T if crew else PHOTO_T)
	work += step
	battery = maxf(0.0, battery - cost * step)   # the camera and radio, or the station, draw while E is held
	if work < 1.0:
		return
	work = 0.0
	if crew:
		carrying = false
		_score(i, "+1 STATION")
		Audio.play("part_snap", -2.0)
	else:
		_snap()
		_score(i, "+1 PHOTO")
		flash_t = t
		Audio.play("part_snap", -2.0, 1.4)

## The picture: what the viewfinder framed on the last drawn frame, shrunk to a print for the HUD.
func _snap() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		photos.append(null)
		return
	var k: Vector2 = Vector2(img.get_width() / 640.0, img.get_height() / 360.0)
	var r: Rect2 = VF_RECT.grow(-4)
	var crop: Image = img.get_region(Rect2i(Vector2i((r.position * k).floor()), Vector2i((r.size * k).floor())))
	crop.resize(36, 20, Image.INTERPOLATE_CUBIC)
	photos.append(ImageTexture.create_from_image(crop))

# ---------------------------------------------------------------- decision events

## Site events come after the first target, then at a hazard (shadow, dusk, half the heat clock, low).
func _maybe_event() -> void:
	if ev_cool > 0.0 or drilling > 0.0 or work > 0.0 or state != "explore":
		return
	var ev: Dictionary = Game.next_event("site")
	if ev.is_empty():
		return
	if WHEEL_EVENTS.has(String(ev.get("id", ""))) and not has_rover:
		ev["done"] = true   # a wheel event needs a rover: with none on the ground it never happens
		return
	var ready: bool = got >= 1 if fired == 0 else (hazard_hit and got >= 1)
	if fired >= 2:
		ready = hazard_hit and got >= 2
	if ready:
		fired += 1
		_open_event(ev)

func _open_event(ev: Dictionary) -> void:
	Game.run["battery"] = battery
	Game.run["data"] = data
	Game.run["samples"] = got
	hold.erase("l")
	hold.erase("r")
	hold.erase("u")
	hold.erase("d")
	hold.erase("e")
	moving = false
	work = 0.0
	card_ev = ev
	card = EventCard.open(self, ev, _after_event)

## Reads the ship back after a card, and shows what changed out in the world.
func _after_event(res: Dictionary) -> void:
	battery = clampf(float(Game.run["battery"]), 0.0, wh)
	data = float(Game.run["data"])
	got = int(Game.run["samples"])
	card = null
	ev_cool = 5.0
	if auto:
		print("SURFACE AUTOPILOT EVENT %s: %s" % [card_ev.get("id", ""), res.get("text", "")])
	var drill_was: bool = gb_sample > 0.0 and _drill_ok()
	_reload()
	var y: float = ry - 72.0
	if has_rover and WHEEL_EVENTS.has(String(card_ev.get("id", ""))) and not bool(res.get("ok", true)) and wheel_k > WHEEL_SLOW:
		wheel_k = WHEEL_SLOW
		_pop(rx, y, "WHEEL DAMAGED: SLOWER", UI.BAD)
		y -= 12.0
	var ap: Dictionary = res.get("applied", {})
	if ap.has("power") and solar > 0.0:
		_pop(rx, y, "LESS CHARGE: SOLAR %d W" % roundi(solar * float(Game.run["gen_mult"])), UI.BAD)
		y -= 12.0
	if job == "drill" and drill_was and not _drill_ok():
		_pop(rx, y, "DRILL BROKEN: NO MORE SAMPLES", UI.BAD)
		y -= 12.0
	for ch: Array in res.get("chips", []):
		_pop(rx, y, String(ch[1]).to_upper(), UI.BAD if ch.size() > 2 and bool(ch[2]) else UI.GOOD)
		y -= 12.0
	if bool(Game.run.get("dead", false)):
		_finish("MISSION LOST", UI.BAD)

# ---------------------------------------------------------------- particles

## Wheel dust as puffs, rock chips from the drill. With no air the dust flies on clean arcs and falls
## straight back; thin air lets it hang and drift with the wind; thick air holds it like water.
func _particles(delta: float) -> void:
	puff_t -= delta
	if has_rover and moving and puff_t <= 0.0:
		puff_t = 0.07 if not climbing else 0.14
		for wx: float in [-22.0, 26.0]:
			var life: float = randf_range(0.35, 0.6) if air == "none" else (randf_range(0.8, 1.4) if air == "thin" else randf_range(1.4, 2.2))
			puffs.append({"p": Vector2(rx + face * wx - face * 6.0, ry - 2.0), "v": Vector2(-face * randf_range(10, 34), -randf_range(10, 26)),
				"age": 0.0, "life": life, "size": 0})
		if wheel_k < 1.0 and randf() < 0.3:   # the damaged wheel scrapes
			chips.append({"p": Vector2(rx - face * 22.0, ry - 3.0), "v": Vector2(-face * randf_range(10, 30), -randf_range(20, 40)), "age": 0.0, "rest": ry + randf_range(0, 2)})
	var drag: float = 0.0 if air == "none" else (2.2 if air == "thin" else 5.0)
	for p: Dictionary in puffs:
		var v: Vector2 = p["v"]
		if air == "none":
			v.y += g * PPM * delta
		elif air == "thin":
			v.x += 14.0 * delta     # wind
			v.y -= 3.0 * delta
		else:
			v.x += 4.0 * delta      # slow, heavy air
			v.y -= 1.0 * delta
		v *= 1.0 - drag * delta
		p["v"] = v
		p["p"] = Vector2(p["p"]) + v * delta
		p["age"] = float(p["age"]) + delta
	puffs = puffs.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	# drill: the bit grinds after it reaches the rock, chips fly
	if drilling > 0.0 and drilling < 1.6:
		chip_t -= delta
		hit_t -= delta
		var bit: Vector2 = _bit_world()
		if chip_t <= 0.0:
			chip_t = 0.06
			chips.append({"p": bit + Vector2(randf_range(-2, 2), -2), "v": Vector2(randf_range(-40, 40), -randf_range(30, 70)), "age": 0.0, "rest": bit.y + randf_range(1, 4)})
			if randf() < 0.5:
				puffs.append({"p": bit, "v": Vector2(randf_range(-14, 14), -randf_range(4, 14)), "age": 0.0, "life": 0.7, "size": 0})
		if hit_t <= 0.0:
			hit_t = 0.42
			Audio.play("drill_hit", -10.0, randf_range(0.9, 1.1))
	for c: Dictionary in chips:
		var p: Vector2 = c["p"]
		var v: Vector2 = c["v"]
		if p.y < float(c["rest"]) or v.y < 0.0:
			v.y += g * PPM * 2.0 * delta
			p += v * delta
			if p.y >= float(c["rest"]):
				p.y = float(c["rest"])
				v = Vector2.ZERO
		c["p"] = p
		c["v"] = v
		c["age"] = float(c["age"]) + delta
	chips = chips.filter(func(c: Dictionary) -> bool: return float(c["age"]) < 1.4)
	for p: Dictionary in pops:
		p["age"] = float(p["age"]) + delta
	pops = pops.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 2.2)

## World position of the drill bit: under the sample being drilled.
func _bit_world() -> Vector2:
	if drill_target < 0:
		return Vector2(rx, LANE)
	return Vector2(float(samples[drill_target]["x"]), LANE - 3.0)

func _cam() -> float:
	return floorf(clampf(rx - 320.0, 0.0, WORLD - 640.0))

func _night() -> float:
	if float(d["night_hours"]) <= 0.0:
		return 0.0
	return 1.0 - clampf(maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 3.0, 0.0, 1.0)

func _process(delta: float) -> void:
	bat_shown = move_toward(bat_shown, battery, maxf(wh * 0.5, absf(battery - bat_shown) * 3.0) * delta)
	var night: float = _night()
	floor_mat.set_shader_parameter("cam", _cam())
	floor_mat.set_shader_parameter("tint", Color(String(sk["tint"])).darkened(night * 0.6))
	floor_mat.set_shader_parameter("haze", Color(String(sk["haze"])).darkened(night * 0.6))
	queue_redraw()
	front.queue_redraw()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(front, p, s, size, c)

# ---------------------------------------------------------------- back layer: sky and ranges

func _draw() -> void:
	var cam: float = _cam()
	var night: float = _night()
	var dim: Color = Color.WHITE.darkened(night * 0.6)
	if tex_sky_day == null:
		draw_rect(Rect2(0, 0, 640, 360), Color("04050a"))
	else:
		draw_rect(Rect2(0, 200, 640, 60), Color(String(sk["fill"])).darkened(night * 0.6))
		draw_texture(tex_sky_day, Vector2(0, -40))
		if night > 0.0:
			draw_texture(tex_sky_night, Vector2(0, -40), Color(1, 1, 1, night))
	if bool(sk.get("stars", false)):
		Pix.stars(self, t, Vector2(640, 200), 110, 8, Vector2(-cam * 0.03, 0))   # no air: stars by day
	elif night > 0.6:
		Pix.stars(self, t, Vector2(640, 200), 70, 4)
		var mt: float = fposmod(t, 9.0)   # a meteor burning up in the thin air now and then
		if mt < 0.6:
			draw_texture(tex_streak, Vector2(floorf(80.0 + mt * 260.0), floorf(40.0 + mt * 50.0)), Color(1, 1, 1, 1.0 - mt / 0.6))
	if tex_earth != null:
		Pix.sprite(self, tex_halo, Vector2(520, 70))
		Pix.sprite(self, tex_earth, Vector2(520, 70))
	if tex_sun != null:
		# the Sun skims the horizon at the pole, two to three times wider than from Earth
		Pix.sprite(self, tex_sun, Vector2(110, 150))
	if tex_phobos != null:
		var sun_k: float = maxf(0.0, sin(PI * (hour - 6.0) / 12.33))
		if sun_k > 0.0:
			# Mars sunsets glow blue: fine dust scatters blue light forward (NASA Curiosity images).
			var sp: Vector2 = Vector2(120 + (hour - 6.0) * 30.0, 250.0 - 190.0 * sun_k).floor()
			Fx.sun(self, sp, 1, Color("fff0d8").lerp(Color("bcd8ff"), clampf(1.0 - sun_k * 2.5, 0.0, 1.0)), t)
		# Phobos crosses the sky fast: it orbits Mars three times a day
		draw_texture(tex_phobos, Vector2(floorf(fposmod(560.0 - t * 4.0, 760.0) - 60.0), 46.0), dim.lightened(night * 0.4))
	for i: int in (5 if not tex_cloud.is_empty() else 0):
		var cx: float = fposmod(i * 173.0 + t * (2.0 + i % 2) - cam * 0.02, 780.0) - 130.0
		draw_texture(tex_cloud[i % 3], Vector2(floorf(cx), floorf(50.0 + i * 24.0)), Color(dim, 0.7))
	Pix.tiled(self, tex_dist, HORIZON - tex_dist.get_height() + 4, cam * 0.02, 640, dim)
	Pix.tiled(self, tex_far, HORIZON - tex_far.get_height() + 3, cam * 0.06, 640, dim)
	if tex_devil != null:
		for i: int in 2:
			var dvx: float = fposmod(t * (5.0 + i * 3.0) + 380.0 + i * 310.0 - cam * 0.1, 760.0) - 60.0
			var fr: int = (int(t * 6.0) + i) % 4
			if bool(sk.get("bolts", false)):
				# lightning: mostly nothing (frame 3), a bolt, a fade and a glow every few seconds
				dvx = fposmod(170.0 + i * 290.0 - cam * 0.1, 760.0) - 60.0
				var ph: float = fposmod(t + i * 1.9, 3.7)
				fr = 0 if ph < 0.07 else (1 if ph < 0.14 else (2 if ph < 0.32 else 3))
			draw_texture_rect_region(tex_devil, Rect2(floorf(dvx), HORIZON - 38.0 - i * 4.0, 16, 34), Rect2(16 * fr, 0, 16, 34), Color(dim, 0.75 - i * 0.2))
	Pix.tiled(self, tex_mid, HORIZON - tex_mid.get_height() + 8, cam * 0.16, 640, dim)
	if tex_sheet != null:
		Pix.tiled(self, tex_sheet, HORIZON - 14.0, cam * 0.2 - t * 9.0, 640.0, Color(dim, 0.85))

# ---------------------------------------------------------------- front layer

## A soft pixel ellipse on the ground (contact shadow), pushed right: the sun is on the left.
## With no air to scatter light, shadows are darker and sharper.
func _shadow(cx: float, y: float, w: float, a: float) -> void:
	var k: float = 1.7 if air == "none" else 1.0
	for dy: int in range(-2, 3):
		var hw: float = floorf(w * 0.5 * sqrt(1.0 - pow(dy / 2.6, 2.0)))
		front.draw_rect(Rect2(floorf(cx + 5.0 * k - hw), floorf(y) + dy, hw * 2.0, 1), Color(0, 0, 0, minf(0.85, a * k)))

func _pick(widths: Array[int], want: float) -> int:
	var k: int = 0
	while k < widths.size() - 1 and widths[k + 1] <= want:
		k += 1
	return k

## Light on a thing at world x: the world's light, darkened at night and in the crater's shadow.
func _lit(x: float, dim: Color) -> Color:
	return dim * light * (Color(0.26, 0.28, 0.36) if _in_shadow(x) else Color.WHITE)

## The crater's permanent shadow on the floor: a hard black edge (no air, nothing softens it).
func _draw_crater_shadow(cam: float) -> void:
	if shadow_x < 0.0:
		return
	var ex: float = shadow_x - cam - 320.0
	var bx: float = 320.0 + ex * (360.0 - HORIZON) / (LANE - HORIZON)
	var pts: PackedVector2Array = PackedVector2Array([Vector2(320.0 + ex * 0.02, HORIZON), Vector2(bx, 360.0), Vector2(4000, 360.0), Vector2(4000, HORIZON)])
	front.draw_colored_polygon(pts, Color(0.0, 0.0, 0.02, 0.8))

## Scenery: `near` draws the rocks in front of the lane (after the rover).
func _decor(cam: float, near: bool, dim: Color) -> void:
	var hmax: float = float(sk["haze_max"])
	for p: Dictionary in decor:
		var s: float = p["s"]
		if (s < 1.0) != near:
			continue
		var sx: float = 320.0 + (float(p["x"]) - cam - 320.0) / s
		if sx < -80.0 or sx > 720.0:
			continue
		var sy: float = HORIZON + (LANE - HORIZON) / s
		var want: float = float(p["b"]) / s
		var fog: float = clampf((s - 1.0) / 9.0, 0.0, 1.0) * hmax
		var mod: Color = _lit(float(p["x"]), dim) * Color.WHITE.lerp(haze_tint, fog)
		match int(p["k"]):
			1:
				var ct: Texture2D = tex_crater[_pick(CRATER_W, want)]
				front.draw_texture(ct, Vector2(floorf(sx - ct.get_width() * 0.5), floorf(sy - ct.get_height() * 0.5)), mod)
			2:
				var ht: Texture2D = tex_hill[_pick(HILL_W, want)]
				front.draw_texture(ht, Vector2(floorf(sx - ht.get_width() * 0.5), floorf(sy - ht.get_height() + 1)), mod)
			_:
				var k: int = _pick(PEBBLE_W, want)
				var tex: Texture2D = tex_pebble[k]
				var w: float = tex.get_width()
				if k >= 2:
					_shadow(sx, sy, w * 0.9, 0.25)
				front.draw_texture(tex, Vector2(floorf(sx - w * 0.5), floorf(sy - tex.get_height() + 2)), mod)

## Rover sprite point (lx, ly in the 80x60 frame drawn facing right) to the screen, honouring the mirror.
func _rl(rp: Vector2, lx: float, ly: float) -> Vector2:
	return Vector2(rp.x + face * (lx - 37.0), rp.y - 58.0 + ly)

func _draw_front() -> void:
	var cam: float = _cam()
	var night: float = _night()
	var dim: Color = Color.WHITE.darkened(night * 0.6)
	_draw_crater_shadow(cam)
	_decor(cam, false, dim)
	_draw_tracks(cam)
	# lander, just behind the lanes, on its own engine scorch
	var lx: float = floorf(LANDER_X - cam)
	if lx > -120.0 and lx < 760.0:
		var lc: Color = _lit(LANDER_X, dim)
		front.draw_texture(tex_scorch, Vector2(lx - 34.0, LANDER_Y - 8.0), Color(lc, 0.55))
		_shadow(lx + 10.0, LANDER_Y, 92.0, 0.35)
		front.draw_texture(tex_lander, Vector2(lx - 38.0, LANDER_Y - 71.0), lc)
		if fposmod(t, 1.4) < 0.18:
			Fx.glow(front, Vector2(lx + 16.0, LANDER_Y - 53.0), 4.0, Color(1.0, 0.35, 0.3, 0.7), true)
			front.draw_rect(Rect2(lx + 15.0, LANDER_Y - 54.0, 2, 2), Color("ffb0a0"))
	var back: bool = ry < (LANES[0] + LANES[1]) * 0.5
	_draw_lane(cam, dim, 1)
	if back:
		_draw_actor(cam, night, dim)
	_draw_lane(cam, dim, 0)
	_draw_targets(cam, dim)
	if not back:
		_draw_actor(cam, night, dim)
	for c: Dictionary in chips:
		var cp: Vector2 = c["p"]
		front.draw_texture(tex_chip, (cp - Vector2(cam + 1.0, 1.0)).floor(), _lit(cp.x, dim))
	_decor(cam, true, dim)
	for p: Dictionary in pops:
		var a: float = float(p["age"])
		if bool(p["spark"]):
			Fx.sparkle(front, Vector2(floorf(float(p["x"]) - cam), float(p["y"]) + 8.0), clampf(a * 1.6, 0.0, 1.0), UI.CYAN, 2)
		Pix.text_oc(front, floorf(float(p["x"]) - cam), floorf(float(p["y"]) - a * 14.0), String(p["s"]), 10, Color(p.get("c", UI.RISK), clampf(2.2 - a, 0.0, 1.0)))
	_draw_guides(cam)
	_draw_viewfinder()
	_draw_hud(night)

## Tread tracks (a chevron every few pixels) or boot prints, on whichever lane they were made.
func _draw_tracks(cam: float) -> void:
	for p: Vector2 in tracks:
		var tx: float = floorf(p.x - cam)
		if tx < -2.0 or tx > 642.0:
			continue
		if crew:
			front.draw_rect(Rect2(tx - 1, p.y, 3, 1), Color(0, 0, 0, 0.3))
			continue
		var odd: bool = int(p.x / 3.0) % 2 == 0
		front.draw_rect(Rect2(tx - 1, p.y + 1, 3, 1), Color(0, 0, 0, 0.3))
		front.draw_rect(Rect2(tx + (0.0 if odd else 1.0), p.y + 2, 1, 1), Color(0, 0, 0, 0.22))
		front.draw_rect(Rect2(tx - 1, p.y - 5, 3, 1), Color(0, 0, 0, 0.18))

## Boulders and small rocks on one lane.
func _draw_lane(cam: float, dim: Color, ln: int) -> void:
	var y: float = LANES[ln]
	for b: Dictionary in boulders:
		if int(b["lane"]) != ln:
			continue
		var bx: float = floorf(float(b["x"]) - cam)
		if bx < -80 or bx > 720:
			continue
		_shadow(bx + 34.0, y + 1.0, 78.0, 0.35)
		front.draw_texture(tex_boulder, Vector2(bx, y - 50.0), _lit(float(b["x"]) + 33.0, dim))
	for r: Dictionary in rocks:
		if int(r["lane"]) != ln:
			continue
		var tex: Texture2D = tex_pebble[int(r["k"])]
		var sx: float = floorf(float(r["x"]) - cam)
		if sx < -40 or sx > 680:
			continue
		_shadow(sx, y + 1.0, tex.get_width() * 0.9, 0.3)
		front.draw_texture(tex, Vector2(floorf(sx - tex.get_width() * 0.5), y - tex.get_height() + 2.0), _lit(float(r["x"]), dim))

## The dust, then the rover, the astronaut or the lander's arm.
func _draw_actor(cam: float, night: float, dim: Color) -> void:
	for i: int in puffs.size():
		var p: Dictionary = puffs[i]
		var pp: Vector2 = p["p"]
		Fx.puff(front, (pp - Vector2(cam, 0)).floor(), float(p["age"]) / float(p["life"]), int(p["size"]), dust_col * _lit(pp.x, dim), i % 4)
	if has_rover:
		_draw_rover(cam, night, dim)
	elif crew:
		_draw_astronaut(cam, dim)
	elif drilling > 0.0 or work > 0.0:
		# the lander's own arm reaches out to the rock
		var bit: Vector2 = Vector2(floorf(float(samples[0]["x"]) - cam), LANE - 3.0)
		var lx: float = floorf(LANDER_X - cam)
		front.draw_line(Vector2(lx + 20, LANDER_Y - 34), bit, Color("c8ccd8"), 1.0)
		Fx.sparkle(front, bit, fposmod(t * 3.0, 1.0), UI.YELLOW, 0)

## Rocks to drill, flags for pictures, flags and stations on foot; a bobbing marker over the next one.
func _draw_targets(cam: float, dim: Color) -> void:
	var near_i: int = _nearest()
	var next_i: int = -1 if _go_home() or (crew and not carrying) else near_i
	for i: int in samples.size():
		var sd: Dictionary = samples[i]
		var wx: float = float(sd["x"])
		var sx: float = floorf(wx - cam)
		if sx < -40.0 or sx > 680.0:
			continue
		var sy: float = LANE
		var lc: Color = _lit(wx, dim)
		if job == "drill":
			if sd["taken"]:
				continue
			var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + i)
			Fx.glow(front, Vector2(sx, sy), 12.0, Color(UI.CYAN, 0.25 + 0.2 * pulse))
			_shadow(sx, sy + 1.0, 22.0, 0.3)
			front.draw_texture(tex_sample, Vector2(sx - 10, sy - 11), lc.lightened(0.35 if _in_shadow(wx) else 0.0))
			var gl: float = fposmod(t + i * 0.7, 2.0)
			if gl < 0.5:
				Fx.sparkle(front, Vector2(sx + 3, sy - 9), gl / 0.5, UI.CYAN, 0)
			if i == drill_target and drilling > 0.0:
				continue
		elif crew and sd["taken"]:
			_shadow(sx, sy + 1.0, 20.0, 0.35)
			front.draw_texture(tex_station, Vector2(sx - 12.0, sy - 21.0), lc)
			if fposmod(t + i * 0.4, 1.2) < 0.25:
				Fx.glow(front, Vector2(sx + 8.0, sy - 21.0), 3.0, Color(1.0, 0.35, 0.3, 0.8), true)
			continue
		else:
			_shadow(sx + 2.0, sy + 1.0, 8.0, 0.3)
			front.draw_texture(tex_flag, Vector2(sx - 2.0, sy - 22.0), lc if not sd["taken"] else Color(lc, 0.45))
			if crew and i == next_i and work > 0.0:
				front.draw_texture(tex_box, Vector2(sx - 5.0, sy - 8.0), lc)
			if sd["taken"]:
				continue
		if i != next_i or state != "explore":
			continue
		var by: float = floorf(sy - (36.0 if job != "drill" else 30.0) - absf(sin(t * 3.0)) * 4.0)
		if absf(rx - wx) >= _reach() and assist >= 1:
			front.draw_texture(tex_marker, Vector2(sx - 4, by), Color.WHITE)
			Pix.text_oc(front, sx, by - 3.0, "%d m" % roundi(absf(wx - rx) / PPM), 10, UI.TEXT)

func _draw_rover(cam: float, night: float, dim: Color) -> void:
	var rp: Vector2 = Vector2(floorf(rx - cam), floorf(ry))
	var rc: Color = _lit(rx, dim)
	var lamps: float = maxf(night, 1.0 if _in_shadow(rx) else 0.0)
	_shadow(rp.x, ry + 1.0, 74.0, 0.42)
	# headlights in the dark: a pool of light on the ground ahead and a beam
	if lamps > 0.25:
		Fx.glow(front, Vector2(rp.x + face * 72.0, ry + 1.0), 48.0, Color(1.0, 0.9, 0.65, 0.5 * lamps))
		Fx.beam(front, _rl(rp, 72, 34), Vector2(face, 0), 96.0, 33.0, t, Color(1.0, 0.92, 0.7, 0.55 * lamps))
	# scanner: sweeps the next rock (or flag) while it is close
	var ni: int = _nearest()
	if ni >= 0 and drilling <= 0.0 and not _go_home():
		var dx: float = float(samples[ni]["x"]) - rx
		if absf(dx) < 110.0 and absf(dx) > 20.0 and signf(dx) == face:
			Fx.beam(front, _rl(rp, 66, 44), Vector2(face, 0), absf(dx) - 26.0, 9.0, t)
	var fr: int = (int(rx / 1.25) % 8) if moving else 0
	# sprung body: bobs on the suspension when driving; a damaged wheel limps
	var bob: float = 0.0
	if moving and not climbing:
		bob = 1.0 if fposmod(rx, 14.0) < 7.0 else 0.0
		if wheel_k < 1.0 and fposmod(rx, 30.0) < 6.0:
			bob = 2.0
	var lifts: Array[float] = [floorf(_wheel_lift(0)), floorf(_wheel_lift(1)), floorf(_wheel_lift(2))]
	if lifts[0] + lifts[1] + lifts[2] > 0.0:
		_rover_climb(rp, fr, lifts, rc)
	else:
		_rover_part(rp, Rect2(fr * 80, 0, 80, SPLIT), 0.0 + bob, rc)
		_rover_part(rp, Rect2(fr * 80, SPLIT, 80, 60 - SPLIT), float(SPLIT), rc)
	var body_lift: float = (lifts[0] + lifts[2]) * 0.5
	# blinking beacon on the mast, a lamp on the bumper
	if fposmod(t, 1.0) < 0.2:
		var bp: Vector2 = _rl(rp, 58, 8 + bob - lifts[2])
		Fx.glow(front, bp, 4.0, Color(1.0, 0.3, 0.25, 0.8), true)
		front.draw_rect(Rect2(bp.floor(), Vector2(1, 1)), Color("ffd0c8"))
	if lamps > 0.25:
		var hp: Vector2 = _rl(rp, 71, 34 + bob - lifts[2])
		Fx.glow(front, hp, 6.0, Color(1.0, 0.95, 0.75, 0.8), true)
		front.draw_rect(Rect2(hp.floor() - Vector2(0, 1), Vector2(2, 2)), Color("fff6d8"))
	if drilling > 0.0:
		_draw_drill(rp, cam, bob - body_lift)

## Rocker-bogie on a rock: each wheel rides the rock's top on its own, the body tilts between the
## rear and front wheels. Drawn as 2 px columns shifted up (no rotated texture: pixels stay on the grid).
func _rover_climb(rp: Vector2, fr: int, lifts: Array[float], mod: Color) -> void:
	if face < 0.0:
		front.draw_set_transform(Vector2(rp.x, 0), 0.0, Vector2(-1, 1))
	var ox: float = 0.0 if face < 0.0 else rp.x
	# the body is rigid: it rises by the wheels' mean and pitches by the rear-to-front difference
	var mean: float = (lifts[0] + lifts[1] + lifts[2]) / 3.0
	var slope: float = (lifts[2] - lifts[0]) / (WHEEL_X[2] - WHEEL_X[0])
	for col: int in range(0, 80, 2):
		var lx: float = col + 1.0
		var body: float = maxf(0.0, mean + slope * (lx - WHEEL_X[1]))
		var wl: float = lifts[0] if lx < 33.0 else (lifts[1] if lx < 54.0 else lifts[2])
		var x: float = ox - 37.0 + col
		front.draw_texture_rect_region(tex_rover, Rect2(x, rp.y - 58.0 - floorf(body), 2, SPLIT), Rect2(fr * 80 + col, 0, 2, SPLIT), mod)
		front.draw_texture_rect_region(tex_rover, Rect2(x, rp.y - 58.0 + SPLIT - wl, 2, 60 - SPLIT), Rect2(fr * 80 + col, SPLIT, 2, 60 - SPLIT), mod)
	front.draw_set_transform(Vector2.ZERO)

## Drill arm: swings out from the bumper, the shaft reaches down into the rock and grinds.
func _draw_drill(rp: Vector2, cam: float, bob: float) -> void:
	var prog: float = 1.0 - drilling / 2.0
	var mount: Vector2 = _rl(rp, 70, 30 + bob).floor()
	var bit: Vector2 = (_bit_world() - Vector2(cam, 0)).floor()
	var reach: float = clampf(prog / 0.2, 0.0, 1.0)
	var top_y: float = mount.y
	var bot_y: float = floorf(lerpf(top_y + 4.0, bit.y, reach))
	if drilling < 1.6:
		bot_y += floorf(absf(sin(t * 40.0)) * 2.0)
	var x0: float = minf(mount.x, bit.x)
	var x1: float = maxf(mount.x, bit.x)
	# boom (outline, metal, highlight)
	front.draw_rect(Rect2(x0 - 1.0, top_y - 1.0, x1 - x0 + 3.0, 4), Color("0c0a14"))
	front.draw_rect(Rect2(x0, top_y, x1 - x0 + 1.0, 2), Color("8a90a8"))
	front.draw_rect(Rect2(x0, top_y, x1 - x0 + 1.0, 1), Color("d6dcea"))
	# shaft and bit
	front.draw_rect(Rect2(bit.x - 2.0, top_y, 4, bot_y - top_y), Color("0c0a14"))
	front.draw_rect(Rect2(bit.x - 1.0, top_y, 2, bot_y - top_y), Color("c8ccd8"))
	front.draw_rect(Rect2(bit.x - 1.0, top_y, 1, bot_y - top_y), Color.WHITE)
	front.draw_rect(Rect2(bit.x - 2.0, bot_y - 3.0, 4, 3), UI.YELLOW.darkened(0.2))
	if drilling < 1.6:
		Fx.sparkle(front, Vector2(bit.x, bot_y), fposmod(t * 5.0, 1.0), Color("fff2c0"), 0)
		Fx.puff(front, Vector2(bit.x, bot_y - 2.0), fposmod(t * 2.0, 1.0), 1, dust_col, int(t * 2.0) % 4)
		# progress gauge over the rover
		Pix.gauge(front, Rect2(rp.x - 20.0, rp.y - 74.0, 40, 7), clampf((prog - 0.2) / 0.8, 0.0, 1.0), UI.CYAN)

func _rover_part(rp: Vector2, src: Rect2, oy: float, mod: Color) -> void:
	var y: float = rp.y - 58.0 + oy
	if face > 0.0:
		front.draw_texture_rect_region(tex_rover, Rect2(rp.x - 37.0, y, src.size.x, src.size.y), src, mod)
	else:
		front.draw_set_transform(Vector2(rp.x, 0), 0.0, Vector2(-1, 1))
		front.draw_texture_rect_region(tex_rover, Rect2(-37.0, y, src.size.x, src.size.y), src, mod)
		front.draw_set_transform(Vector2.ZERO)

## The astronaut (art/surface_v6/astronaut.png, 28 x 40 frames): rows walk, walk carrying, lope
## (4 empty-handed, 4 carrying), then kneel x2, stand, stand carrying. On the Moon a hop arc lifts the
## sprite: the real ballistic height of a 20 cm hop, the way Apollo crews moved.
func _draw_astronaut(cam: float, dim: Color) -> void:
	var col: int = 0
	var row: int = 3
	var hop: float = 0.0
	if work > 0.0:
		col = int(t * 4.0) % 2
	elif moving and _lope():
		row = 2
		var p: float = hop_ph
		col = (0 if p < 0.1 else (1 if p < 0.25 else (2 if p < 0.75 else 3))) + (4 if carrying else 0)
		var q: float = clampf((p - 0.1) / 0.9, 0.0, 1.0)
		hop = floorf(4.0 * HOP_M * PPM * q * (1.0 - q))
	elif moving:
		row = 1 if carrying else 0
		col = int(walk_d / 5.0) % 8
	else:
		col = 3 if carrying else 2
	var rp: Vector2 = Vector2(floorf(rx - cam), floorf(ry))
	_shadow(rp.x - 4.0, ry + 1.0, 16.0 - hop, 0.42)
	var src: Rect2 = Rect2(col * 28, row * 40, 28, 40)
	var mod: Color = _lit(rx, dim)
	if face > 0.0:
		front.draw_texture_rect_region(tex_astro, Rect2(rp.x - 12.0, rp.y - 39.0 - hop, 28, 40), src, mod)
	else:
		front.draw_set_transform(Vector2(rp.x, 0), 0.0, Vector2(-1, 1))
		front.draw_texture_rect_region(tex_astro, Rect2(-12.0, rp.y - 39.0 - hop, 28, 40), src, mod)
		front.draw_set_transform(Vector2.ZERO)
	if work > 0.0:
		Pix.gauge(front, Rect2(rp.x - 20.0, rp.y - 54.0, 40, 7), work, UI.CYAN)

## The way to go: an arrow at the screen edge to the next target, or back to the lander.
func _draw_guides(cam: float) -> void:
	if state != "explore" or assist < 1:
		return   # HARD: no arrows, only what the player can see
	var tx: float = _target()
	var home: bool = tx == LANDER_X
	var label: String = "LANDER" if home else _noun()
	var sx: float = tx - cam
	if home and sx > -20.0 and sx < 660.0:
		if not _at_lander():
			front.draw_texture(tex_marker, Vector2(floorf(sx - 4.0), LANDER_Y - 92.0 - floorf(absf(sin(t * 3.0)) * 4.0)), UI.GREEN)
		return
	if sx >= 0.0 and sx <= 640.0:
		return
	var right: bool = sx > 640.0
	var y: float = LANE - 50.0
	var nudge: float = floorf(fposmod(t * 2.0, 1.0) * 3.0)
	var acol: Color = Color(0.5, 1.4, 0.6) if home else Color.WHITE
	var dist: String = "%s %d m" % [label, roundi(absf(tx - rx) / PPM)]
	var w2: float = Pix.text_w(dist, 10) + 26.0
	var px: float = 622.0 - w2 if right else 18.0
	Pix.panel(front, Rect2(px - 4.0, y - 8.0, w2 + 8.0, 20), pan_accent, pan_body)
	if right:
		front.draw_texture(tex_arrow, Vector2(px + w2 - 10.0 + nudge, y - 2.0), acol)
		_text(Vector2(px + 2.0, y + 6.0), dist, 10, UI.TEXT)
	else:
		front.draw_set_transform(Vector2(px + 8.0 - nudge, 0), 0.0, Vector2(-1, 1))
		front.draw_texture(tex_arrow, Vector2(0, y - 2.0), acol)
		front.draw_set_transform(Vector2.ZERO)
		_text(Vector2(px + 14.0, y + 6.0), dist, 10, UI.TEXT)

## What the next target is called on the guide arrow.
func _noun() -> String:
	return String(sk["noun"]) if job == "drill" else "FLAG"

## The camera's viewfinder: corner brackets close in while E is held; a white flash for the picture,
## then the print flies up to its slot in the HUD.
func _draw_viewfinder() -> void:
	if job != "photo":
		return
	if work > 0.0:
		var k: float = ease(clampf(work, 0.0, 1.0), 0.4)
		var r: Rect2 = Rect2(Vector2(8, 8).lerp(VF_RECT.position, k), Vector2(624, 344).lerp(VF_RECT.size, k))
		r = Rect2(r.position.floor(), r.size.floor())
		var col: Color = Color(1, 1, 1, 0.5 + 0.5 * k)
		for cx: int in 2:
			for cy: int in 2:
				var p: Vector2 = Vector2(r.position.x + cx * (r.size.x - 2.0), r.position.y + cy * (r.size.y - 2.0))
				var hx: float = 1.0 if cx == 0 else -1.0
				var hy: float = 1.0 if cy == 0 else -1.0
				for o: Vector2 in [Vector2(1, 1), Vector2.ZERO]:
					var c2: Color = Color(0, 0, 0, 0.7) if o != Vector2.ZERO else col
					front.draw_rect(Rect2(minf(p.x, p.x + hx * 14.0) + o.x, p.y + o.y, 16, 2), c2)
					front.draw_rect(Rect2(p.x + o.x, minf(p.y, p.y + hy * 10.0) + o.y, 2, 12), c2)
		var c: Vector2 = r.get_center().floor()
		front.draw_rect(Rect2(c.x - 4, c.y, 9, 1), col)
		front.draw_rect(Rect2(c.x, c.y - 4, 1, 9), col)
		if fposmod(t, 0.8) < 0.5:
			Pix.text_o(front, r.position + Vector2(2, -5), "REC", 10, UI.RED)
	var ft: float = t - flash_t
	if ft < 0.35:
		front.draw_rect(Rect2(0, 0, 640, 360), Color(1, 1, 1, 0.85 * (1.0 - ft / 0.35)))

# ---------------------------------------------------------------- directions and HUD

## The one thing to do now: [key cap, words, is a warning]. It changes only when the player has done it.
## EASY shows every direction; NORMAL and HARD only the warnings and the end (see _draw_hud).
func _direction() -> Array:
	if state != "explore":
		return ["", banner, true]
	if drilling > 0.0:
		return ["", "DRILLING: THE BATTERY PAYS %d Wh" % roundi(cost), false]
	var tx: float = _target()
	var side: String = "RIGHT" if tx > rx else "LEFT"
	var key: String = ">" if tx > rx else "<"
	var go: String = "WALK" if crew else "DRIVE"
	if _go_home():
		var why: String = ""
		if crew and o2 < O2_LOW and got < goal:
			why = "OXYGEN LOW: "
		elif crew:
			why = "ALL SET UP: "
		elif _low() and got < goal:
			why = "BATTERY LOW: "
		elif not _tool_ok() and got < goal:
			why = "NO WORKING DRILL: "
		return [key, why + "%s BACK TO THE LANDER" % go, why != "" and why != "ALL SET UP: "]
	if crew and not carrying:
		return [key, "WALK BACK TO THE LANDER FOR THE NEXT ONE", false]
	if _at_target() >= 0:
		if battery < cost and work <= 0.0:
			return ["", "WAIT IN THE SUN: %d OF %d Wh" % [roundi(battery), roundi(cost)], true]
		match job:
			"photo":
				return ["E", "HOLD E TO TAKE A PICTURE", false]
			"crew":
				return ["E", "HOLD E TO SET UP THE STATION", false]
			_:
				return ["E", "PRESS E TO DRILL THE %s" % String(sk["noun"]), false]
	if crew:
		return [key, "HOLD %s: CARRY THE STATION TO THE FLAG" % side, false]
	var dir: float = signf(tx - rx)
	if _boulder_ahead(dir) >= 0:
		return ["UP" if lane == 0 else "DOWN", "PRESS %s TO STEER AROUND THE BOULDER" % ("UP" if lane == 0 else "DOWN"), false]
	if shadow_x >= 0.0 and rx < shadow_x and tx > shadow_x:
		return [key, "HOLD %s: DRIVE INTO THE DARK CRATER" % side, false]
	if job == "photo":
		return [key, "HOLD %s TO DRIVE TO THE FLAG" % side, false]
	return [key, "HOLD %s TO DRIVE TO THE GLOWING %s" % [side, String(sk["noun"])], false]

## Big and plain: the count, the battery (or the suit's oxygen), the heat clock on Venus, the direction.
func _draw_hud(night: float) -> void:
	var slot_w: float = 42.0
	var w: float = maxf(236.0, 16.0 + goal * slot_w)
	var h: float = 60.0 + (30.0 if job == "photo" else 0.0)
	Pix.panel(front, Rect2(6, 6, w, h), pan_accent, pan_body)
	# the count
	if job == "photo":
		front.draw_texture(tex_camera, Vector2(12, 12))
	else:
		Pix.icon(front, "science" if crew else "sample", Vector2(12, 12), UI.CYAN)
	_text(Vector2(30, 22), _word(), 10, UI.YELLOW)
	var cnt: String = "%d / %d" % [got, goal]
	var cc: Color = UI.GREEN if got >= goal or t - got_t < 0.6 else UI.TEXT
	Pix.text(front, Vector2(floorf(6.0 + w - 10.0 - Pix.text_w(cnt, 20)), 28), cnt, 20, cc)
	# battery, or the suit's oxygen
	var frac: float = o2 if crew else bat_shown / wh
	var low: bool = frac < (O2_LOW if crew else 0.2)
	var col: Color = UI.GOOD if frac > 0.4 else (UI.RISK if not low else (UI.BAD if fposmod(t, 0.6) < 0.3 else UI.RISK))
	if not crew and _paying():
		col = UI.BAD   # red while the battery is paying for a drill, a photo or a station
	Pix.icon(front, "helmet" if crew else "battery", Vector2(12, 34), col)
	_text(Vector2(30, 44), "OXYGEN" if crew else "BATTERY", 10, UI.TEXT)
	var marker: float = O2_LOW if crew else (ASCENT_MIN if bool(d["returns"]) else -1.0)
	var gw: float = w - 150.0
	Pix.gauge(front, Rect2(84, 35, gw, 11), frac, col, marker)
	var val: String = "%d Wh" % roundi(bat_shown)
	if crew:
		var hrs: float = frac * SUIT_HOURS
		val = "%d:%02d h" % [int(hrs), int(fposmod(hrs, 1.0) * 60.0)]
	_text(Vector2(90.0 + gw, 44), val, 10, UI.TEXT)
	# the power budget, so every part is felt: generation now, use now, and what each target costs
	var px: float = 12.0
	if crew:
		px = _seg(px, "LANDER %d Wh" % roundi(bat_shown), UI.BAD if _paying() else (UI.GOOD if battery / wh > 0.4 else UI.RISK))
	else:
		px = _seg(px, "%s +%d W" % ["SUN" if rtg <= 0.0 else "POWER", roundi(gen_now)], UI.GOOD if gen_now >= draw_now else UI.RISK)
		px = _seg(px, "USE -%d W" % roundi(draw_now), UI.DIM)
	_seg(px, "%s -%d Wh" % [{"drill": "DRILL", "photo": "PHOTO", "crew": "STATION"}.get(job, "EACH"), roundi(cost)], UI.BAD)
	if job == "photo":
		for i: int in goal:
			var r: Rect2 = Rect2(12.0 + i * slot_w, 64, 40, 24)
			if i < photos.size():
				var fly: float = clampf((t - flash_t) / 0.5, 0.0, 1.0) if i == photos.size() - 1 else 1.0
				var to: Vector2 = r.position
				var from: Vector2 = VF_RECT.get_center() - Vector2(20, 12)
				var pos: Vector2 = from.lerp(to, ease(fly, 0.3)).floor()
				front.draw_rect(Rect2(pos, Vector2(40, 24)), Color("e8ecff"))
				front.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(36, 20)), Color("141a2e"))
				if photos[i] != null:
					front.draw_texture(photos[i], pos + Vector2(2, 2))
			else:
				front.draw_rect(r, Color(0, 0, 0, 0.35))
				front.draw_rect(r, Color(UI.DIM, 0.6), false, 1.0)
				front.draw_texture(tex_camera, r.position + Vector2(14, 6), Color(1, 1, 1, 0.25))
	# why the battery falls: no sunlight now
	if not crew and solar > 0.0 and gen_now < draw_now:
		var dark: String = "SHADOW" if _in_shadow(rx) else ("NIGHT" if night > 0.5 else "")
		if dark != "":
			Pix.text_o(front, Vector2(12, 6 + h + 12), "%s: NO SUNLIGHT FOR THE PANELS" % dark, 10, UI.RISK)
	Pix.panel(front, _help_rect(), pan_accent, pan_body)
	_text(Vector2(623, 18), "?", 10, UI.YELLOW if help_on else UI.TEXT)
	if life_min > 0.0:
		_draw_heat()
	# the one direction, at the bottom, big
	var dr: Array = _direction()
	var words: String = String(dr[1])
	if assist < 2 and not bool(dr[2]):
		words = ""   # NORMAL and HARD: no step-by-step directions, only warnings and the end
	var wcol: Color = banner_col if state != "explore" else (UI.RISK if bool(dr[2]) else UI.YELLOW)
	if words != "":
		var kw: float = maxf(13.0, Pix.text_w(String(dr[0]), 10) + 7.0) + 8.0 if String(dr[0]) != "" else 0.0
		var tw: float = Pix.text_w(words, 20)
		var size: int = 20 if kw + tw + 20.0 <= 628.0 else 10
		var bw: float = kw + Pix.text_w(words, size) + 20.0
		var x0: float = floorf(320.0 - bw / 2.0)
		Pix.panel(front, Rect2(x0, 326, bw, 28), pan_accent, pan_body)
		if kw > 0.0:
			Pix.keycap(front, Vector2(x0 + 10.0, 333), String(dr[0]))
		_text(Vector2(x0 + 10.0 + kw, 348 if size == 20 else 344), words, size, wcol)
	if help_on:
		_draw_help()

## A drill, a photo or a station is taking its share of the battery right now.
func _paying() -> bool:
	return drilling > 0.0 or (work > 0.0 and _holding_e())

## One coloured piece of the HUD's power line; returns where the next one starts.
func _seg(x: float, s: String, c: Color) -> float:
	_text(Vector2(x, 58), s, 10, c)
	return x + Pix.text_w(s, 10) + 7.0

## The heat clock: how much of the lander's life is gone. It only goes up.
func _draw_heat() -> void:
	var used: float = clampf(1.0 - _life_left() / maxf(1.0, life_min), 0.0, 1.0)
	var col: Color = UI.RISK if used < 0.85 else (UI.BAD if fposmod(t, 0.5) < 0.3 else UI.RISK)
	var r: Rect2 = Rect2(256, 6, 228, 36)
	Pix.panel(front, r, pan_accent, pan_body)
	front.draw_rect(r.grow(-2), Color(UI.YELLOW, 0.8), false, 1.0)
	Pix.icon(front, "hull", Vector2(262, 11), col)
	_text(Vector2(278, 20), "HULL HEAT", 10, UI.YELLOW)
	_text(Vector2(360, 20), "%d min LEFT OF %d" % [maxi(0, roundi(_life_left())), roundi(life_min)], 10, UI.TEXT)
	Pix.gauge(front, Rect2(262, 26, 216, 11), used, col)

func _draw_help() -> void:
	var lines: Array = []
	if crew:
		lines = [["< >", "HOLD TO WALK (A, D)"], ["E", "HOLD AT A FLAG: SET UP THE STATION"]]
	else:
		lines = [["< >", "HOLD TO DRIVE (A, D)"], ["UP DOWN", "STEER AROUND BIG BOULDERS (W, S)"],
			["E", "HOLD AT A FLAG: TAKE A PICTURE" if job == "photo" else "DRILL A GLOWING %s" % String(sk["noun"])]]
	lines.append(["?", "SHOW OR HIDE THIS LIST (H)"])
	var extra: String = ""
	if crew:
		extra = "A suit holds about %d h of oxygen. Game rule: here it lasts %d s." % [roundi(SUIT_HOURS), roundi(o2_secs)]
	elif life_min > 0.0:
		extra = "The lander lives %d min here. Full HULL HEAT ends it." % roundi(life_min)
	elif bool(d["returns"]):
		extra = "Game rule: the ascent needs %d%% battery. Stay above yellow." % roundi(ASCENT_MIN * 100.0)
	elif shadow_x >= 0.0:
		extra = "No sun in the crater: the panels stop, the battery drains."
	elif float(d["night_hours"]) > 0.0:
		extra = "At night the panels stop: the battery must last till dawn."
	if has_rover:
		lines.append(["", "Small rocks: the rover climbs over them, slowly."])
	var h: float = 26.0 + lines.size() * 17.0 + (14.0 if extra != "" else 0.0)
	var r: Rect2 = Rect2(140, floorf(170.0 - h / 2.0), 360, h)
	Pix.panel(front, r, pan_accent, Color(pan_body, 0.95))
	_text(r.position + Vector2(10, 14), "CONTROLS", 10, UI.YELLOW)
	var y: float = r.position.y + 22.0
	for ln: Array in lines:
		if String(ln[0]) == "":
			_text(Vector2(r.position.x + 10.0, y + 9.0), String(ln[1]), 10, UI.TEXT)
		else:
			Pix.key_hint(front, Vector2(r.position.x + 10.0, y), String(ln[0]), String(ln[1]), UI.TEXT)
		y += 17.0
	if extra != "":
		_text(Vector2(r.position.x + 10.0, y + 8.0), extra, 10, UI.DIM)

# ---------------------------------------------------------------- autopilot (tests and demos)

## Plays the site by itself on any job: drives or walks to each target, steers round boulders (it never
## jumps), drills or holds E, answers cards, heads back to the lander.
func _auto_step() -> void:
	if EventCard.is_open():
		if card == null or not is_instance_valid(card) or float(card.get("age")) < 0.6:
			return
		if (card.get("result") as Dictionary).is_empty():
			var pick: int = 0
			for i: int in (card_ev["choices"] as Array).size():
				var info: Dictionary = Game.event_choice(card_ev, i)
				if bool(info["can"]) and String(info["warn"]) == "":
					pick = i
					break
			card.call("_choose", pick)
		else:
			card.call("_continue")
		return
	for k: String in ["l", "r", "u", "d", "e"]:
		hold.erase(k)
	if state != "explore" or drilling > 0.0:
		return
	var tx: float = _target()
	if _at_target() >= 0:
		if job == "drill":
			if absf(tx - rx) < _reach() - 8.0 or not has_rover:
				_use()
				return
		else:
			hold["e"] = true
			return
	if not has_rover and not crew:
		return
	var dir: float = signf(tx - rx)
	if dir == 0.0:
		return
	if has_rover and _boulder_ahead(dir, 100.0) >= 0:
		hold["u" if lane == 0 else "d"] = true
	hold["r" if dir > 0.0 else "l"] = true

# ---------------------------------------------------------------- debug hooks (screenshots and tests)

## Mars night: headlights on, driving right.
func debug_night() -> void:
	t = 45.0
	hour = fposmod(8.0 + t * h_rate, 24.66)
	hold["r"] = true

func debug_drive() -> void:
	hold["r"] = true

## Parked at the first target, half-way through drilling it (or holding E for a photo or a station).
func debug_drill() -> void:
	if job != "drill":
		debug_photo()
		return
	rx = float(samples[0]["x"]) - (36.0 if has_rover else 0.0)
	face = 1.0
	drilling = 1.0
	drill_target = 0
	t = 10.0
	ev_cool = 99.0
	battery -= cost * 0.5   # the first half of the drill's share is already paid
	_pop(rx, ry - 70.0, "-%d Wh" % roundi(cost), UI.BAD)

## At the first flag, holding E: the viewfinder closes and the picture is taken (or a station set up).
func debug_photo() -> void:
	if not has_rover and not crew:
		hold["e"] = true
		return
	rx = float(samples[0]["x"]) - (10.0 if crew else 0.0)
	face = 1.0
	t = 10.0
	ev_cool = 99.0
	hold["e"] = true

## The setup of a station on foot (same as debug_photo on the crew job).
func debug_setup() -> void:
	debug_photo()

## Climbing a small rock: the wheels follow the rock, the body tilts.
func debug_climb() -> void:
	if rocks.is_empty():
		return
	var r: Dictionary = rocks[0]
	lane = int(r["lane"])
	ry = LANES[lane]
	rx = float(r["x"]) - 4.0
	face = 1.0
	t = 10.0
	ev_cool = 99.0

## Kept for the old test list: the rover no longer jumps, so this shows it climbing a rock.
func debug_jump() -> void:
	debug_climb()

## Steering round the first boulder: half-way between the lanes beside it.
func debug_lane() -> void:
	if boulders.is_empty():
		return
	var b: Dictionary = boulders[0]
	lane = 1 - int(b["lane"])
	ry = (LANES[0] + LANES[1]) * 0.5
	rx = float(b["x"]) - 40.0
	face = 1.0
	t = 10.0
	ev_cool = 99.0
	hold["r"] = true

## Inside the crater's permanent shadow (or far out on the plain), going on to the second target.
func debug_crater() -> void:
	rx = float(samples[0]["x"]) + 60.0
	samples[0]["taken"] = true
	got = 1
	data = gb_each
	carrying = false
	battery = wh * 0.62
	t = 20.0
	ev_cool = 99.0
	hold["r"] = true

## The heat clock nearly out.
func debug_hot() -> void:
	debug_crater()
	minutes = maxf(0.0, life_min - float(Game.run.get("minutes_lost", 0.0)) - 9.0)

## A site event card open, through the real path (sync, card, read back).
func debug_event() -> void:
	debug_crater()
	hold.clear()
	var ev: Dictionary = Game.next_event("site")
	if ev.is_empty():
		ev = Game.event_by_id("reboot")
	fired += 1
	_open_event(ev)

## Every target done, heading home: the arrow points back to the lander.
func debug_done() -> void:
	for i: int in goal:
		if i < samples.size():
			samples[i]["taken"] = true
	got = goal
	data = gb_each * goal
	carrying = false
	rx = minf(1400.0, LANDER_X + 400.0) if crew else 1400.0
	face = -1.0
	t = 10.0
	ev_cool = 99.0

## Next to the lander with everything done: the visit ends by itself.
func debug_home() -> void:
	debug_done()
	rx = LANDER_X + 40.0

func debug_lowbatt() -> void:
	battery = wh * 0.18
	o2 = 0.2

func debug_help() -> void:
	help_on = true

## The autopilot plays the whole site at 3x speed, then the game moves on to the next screen.
func debug_auto() -> void:
	auto = true
	Engine.time_scale = 3.0
	print("SURFACE POWER (%s %s): wh %d, battery %d, solar %d x%.2f, rtg %d, draw base %d drill %d rover %d, drain x%.1f" % [skin, job, roundi(wh), roundi(battery), roundi(solar), float(Game.run["gen_mult"]), roundi(rtg), roundi(base_draw), roundi(drill_draw), roundi(rover_draw), Game.diff("drain")])

## What a bad stuck-wheel call looks like out in the world: the rover limps on at reduced speed.
func debug_outcome() -> void:
	debug_crater()
	card_ev = Game.event_by_id("stuck_wheel")
	_after_event({"ok": false, "chips": [["battery", "-40% battery", true]], "applied": {}})
