extends Control
## Surface exploration on any landing world: drive the rover under real gravity, drill rocks (or ice),
## watch the battery, and decide what to do when something goes wrong (site events, scripts/events.gd).
## Depth in the style of a pixel racing game: three mountain ranges, a perspective floor
## (shaders/floor.gdshader), craters, hills and rocks at many depths, contact shadows, tread tracks.
## Every puff, glow, sparkle and sun goes through the shared effects kit (scripts/fx.gd).
## The world is read from Data.DEST: kind, air, returns, skin, hazards. Art is looked up by skin.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const EventCard = preload("res://scripts/event_card.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const WORLD: float = 4000.0
const PPM: float = 20.0          # px per metre at the rover's lane
const JUMP_V: float = 3.2        # m/s take-off speed (game rule)
const DAY_RATE: float = 0.3      # game rule: planet hours per real second (6 minutes a frame-second x 3)
const LANDER_X: float = 333.0
const HORIZON: float = 232.0
const LANE: float = 300.0        # screen y of the ground under the rover
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]
const CRATER_W: Array[int] = [18, 26, 40, 64, 98]
const HILL_W: Array[int] = [46, 84, 130]
const SPLIT: int = 38            # rover sprite rows above this are the sprung body, below are the wheels
const WHEEL_EVENTS: Array[String] = ["stuck_wheel", "sharp_rocks"]
const ASCENT_MIN: float = 0.3   # game rule (Game.phase_home): the ascent stage needs 30% battery
const WHEEL_SLOW: float = 0.6    # game rule: a damaged wheel drags, the rover keeps 60% of its speed

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
var g: float = 1.62
var rx: float = LANDER_X + 85.0
var ry: float = 0.0
var vy: float = 0.0
var on_ground: bool = true
var face: float = 1.0
var moving: bool = false
var has_rover: bool = false
var speed: float = 100.0
var wheel_k: float = 1.0
var drilling: float = 0.0
var drill_target: int = -1
var samples: Array = []
var boulders: Array = []
var got: int = 0
var goal: int = 3
var data: float = 0.0
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
var drain_k: float = 1.0
var gb_sample: float = 0.0
var shadow_x: float = -1.0       # world x where the crater's permanent shadow begins (-1 = none)
var life_min: float = 0.0        # minutes the lander lives here (0 = no heat clock)
var minutes: float = 0.0         # minutes spent on the surface (heat clock)
var min_rate: float = 0.0        # minutes per real second
var crit: String = "battery"     # the highlighted gauge: battery, data or heat
var fired: int = 0
var hazard_hit: bool = false
var ev_cool: float = 0.0
var card: Control = null
var card_ev: Dictionary = {}
var help_on: bool = false
var low_warned: bool = false
var auto: bool = false
var tex_lander: Texture2D = null
var tex_rover: Texture2D = null
var tex_earth: Texture2D = null
var tex_halo: Texture2D = null
var tex_dist: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_boulder: Dictionary = {}
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
var tex_rock: Array[Texture2D] = []
var puffs: Array = []
var chips: Array = []
var pops: Array = []
var decor: Array = []
var tracks: PackedFloat32Array = PackedFloat32Array()
var last_track: float = -100.0
var puff_t: float = 0.0
var chip_t: float = 0.0
var hit_t: float = 0.0
var land_t: float = -9.0
var land_x: float = 0.0
var got_t: float = -9.0
var haze_tint: Color = Color.WHITE
var dust_col: Color = Color.WHITE
var light: Color = Color.WHITE
var pan_accent: Color = Color("3a4a7a")
var pan_body: Color = Color(0.03, 0.04, 0.08, 0.82)
var was_ground: bool = true
var hold: Dictionary = {}
var confirm_t: float = -10.0
var floor_mat: ShaderMaterial = null
var front: Control = null

func _ready() -> void:
	d = Game.dest()
	skin = String(d["skin"])
	sk = SKIN.get(skin, SKIN["moon"])
	air = String(d["air"])
	g = float(d["gravity"])
	goal = int(d["samples_goal"])
	var hz: float = Game.diff("surface_hazards")
	drain_k = minf(hz, 1.2)   # EASY: the battery drains 40% slower (game rule)
	tex_lander = Pix.img("lander")
	tex_rover = Pix.img("rover")
	tex_dist = Pix.img("surface/%s_range_dist" % skin)
	tex_far = Pix.img(skin + "_range_far")
	tex_mid = Pix.img(skin + "_range_near")
	tex_boulder = {23: Pix.img("boulder_%s_23" % skin), 50: Pix.img("boulder_%s_50" % skin)}
	tex_sample = Pix.img("sample_%s_big" % skin)
	tex_scorch = Pix.img("surface/scorch")
	tex_marker = Pix.img("surface/marker")
	tex_arrow = Pix.img("surface/arrow_r")
	tex_chip = Pix.img("surface/chip")
	tex_streak = Pix.img("surface/streak")
	tex_rock = [Pix.img("surface/ic_rock0"), Pix.img("surface/ic_rock1")]
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
	has_rover = Game.id_has("rover") or Game.id_has("rover_big")
	if Game.id_has("rover_big"):
		speed = 183.0
		rover_draw = float(Data.PARTS["rover_big"]["draw"])
	elif Game.id_has("rover"):
		rover_draw = float(Data.PARTS["rover"]["draw"])
	if Game.id_has("drill"):
		drill_draw = float(Data.PARTS["drill"]["draw"])
	base_draw = float(c["draw_ops"]) - drill_draw - rover_draw
	solar = float(c["solar_dest"])
	rtg = float(c["rtg"])
	wh = maxf(1.0, float(Game.run["wh"]))
	battery = float(Game.run["battery"])
	_reload()
	# the heat clock: where the lander lives only minutes, the whole site runs on its clock
	if d.has("surface_minutes"):
		life_min = float(d["surface_minutes"])
		if not Game.id_has("hull"):
			life_min *= 0.2   # game rule: without the pressure hull the lander would last a fraction of it
		min_rate = 1.25 + 1.25 * hz   # game rule: EASY 2.0, NORMAL 2.5, HARD 3.0 minutes per second
		h_rate = min_rate / 60.0
	# which gauge is the critical one here (Data critical list, mapped to what the surface shows)
	for r: String in d["critical"]:
		if r == "power":
			crit = "battery"
			break
		if r == "time" and life_min > 0.0:
			crit = "heat"
			break
		if r == "data" or r == "comms":
			crit = "data"
			break
	# terrain on the rover's lane: boulders the jump can clear, samples spread by the difficulty
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(skin)
	var hop_px: float = pow(JUMP_V, 2) / (2.0 * g) * PPM
	var gap: float = 300.0 + 150.0 * hz   # game rule: EASY rocks 390 px apart, NORMAL 450, HARD 510
	var first: float = LANDER_X + 300.0 + 100.0 * hz
	if sk.has("shadow"):
		shadow_x = LANDER_X + float(sk["shadow"])
		first = shadow_x + 100.0
	if not has_rover:
		samples.append({"x": LANDER_X + 117.0, "taken": false})
	for i: int in goal + 2:
		var sx: float = first + i * gap + rng.randf_range(-40, 40)
		var roll: float = rng.randf()
		var bh: float = 50.0 if hop_px > 55.0 and i % 2 == 1 else 23.0
		if hop_px > 26.0 and roll < 0.45 + 0.4 * hz:
			boulders.append(Rect2(sx - 150.0, 0.0, 67.0, bh))
		samples.append({"x": sx, "taken": false})
	# scenery at many depths (s = distance, 1 at the lane, >1 behind, <1 in front):
	# k 0 rock, 1 crater, 2 low hill (only far away)
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = hash(skin) + 21
	var crater_k: float = 0.45 if air == "none" else 0.25   # airless worlds keep every crater sharp
	for i: int in 300:
		var s: float = exp(rd.randf_range(log(0.55), log(9.0)))
		if s > 0.8 and s < 1.3:
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
	ry = ground(rx)
	# layers: this node draws sky and mountains; then the floor; then the world and HUD
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

func _exit_tree() -> void:
	Engine.time_scale = 1.0   # the autopilot test speeds the game up
	Audio.loop("drill", false)
	Audio.loop("rover_loop", false)

## Science per sample from the instruments that still work.
func _reload() -> void:
	gb_sample = 0.0
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(p.get("gb", 0.0))

func _drill_ok() -> bool:
	return Game.id_has("drill") and not Game.run["broken"].has("drill")

func _hold_buttons() -> void:
	var defs: Array = [["<", 8, 40, "l"], [">", 52, 40, "r"], ["JUMP", 452, 80, "u"], ["DRILL", 540, 92, "e"]]
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

func ground(x: float) -> float:
	var y: float = LANE
	for b: Rect2 in boulders:
		if x >= b.position.x and x <= b.position.x + b.size.x:
			y = minf(y, LANE - b.size.y)
	return y

func _in_shadow(x: float) -> bool:
	return shadow_x >= 0.0 and x >= shadow_x

func _pressed(key: Key, act: String, h: String) -> bool:
	return hold.has(h) or Input.is_physical_key_pressed(key) or (act != "" and Input.is_action_pressed(act))

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
	return 40.0 if has_rover else 150.0

func _at_lander() -> bool:
	return absf(rx - LANDER_X) < 70.0 and (has_rover or got > 0 or not _drill_ok())

## Index of the closest sample still on the ground, or -1.
func _nearest() -> int:
	var best: int = -1
	var bd: float = 1e9
	for i: int in samples.size():
		if not samples[i]["taken"] and absf(float(samples[i]["x"]) - rx) < bd:
			bd = absf(float(samples[i]["x"]) - rx)
			best = i
	return best

## True when the rover should head home: everything drilled, nothing left to drill, or the battery low.
func _go_home() -> bool:
	return got >= goal or _nearest() < 0 or not _drill_ok() or _low()

## Battery under 20% and still falling (charging in the sun is fine).
func _low() -> bool:
	return battery / wh < 0.2 and gen_now < draw_now

func _use() -> void:
	if state != "explore" or drilling > 0.0 or EventCard.is_open():
		return
	if _at_lander():
		if got == 0 and t > confirm_t:
			confirm_t = t + 4.0
			Audio.play("ui_deny", -6.0)
			return
		_finish("BACK AT THE LANDER: %d OF %d SAMPLES" % [got, goal])
		return
	for i: int in samples.size():
		var s: Dictionary = samples[i]
		if not s["taken"] and absf(rx - float(s["x"])) < _reach():
			if not _drill_ok():
				_pop(rx, ry - 70.0, "NO WORKING DRILL")
				Audio.play("ui_deny", -6.0)
				return
			drilling = 2.0
			drill_target = i
			face = 1.0 if float(s["x"]) >= rx or not has_rover else -1.0
			return
	_pop(rx, ry - 70.0, "NOTHING TO DRILL HERE")
	Audio.play("ui_deny", -6.0)

func _pop(x: float, y: float, s: String) -> void:
	pops.append({"x": x, "y": y, "age": 0.0, "s": s, "spark": false})

func _finish(text: String) -> void:
	if state != "explore":
		return
	state = "done"
	end_t = t + 2.5
	banner = text
	hold.clear()
	if auto:
		print("SURFACE AUTOPILOT: %s. samples %d/%d, battery %d%%, events %d, t %.1f s" % [text, got, goal, roundi(100.0 * battery / wh), fired, t])
	Audio.loop("drill", false)
	Audio.loop("rover_loop", false)
	Audio.play("error" if battery <= 0.0 or (life_min > 0.0 and _life_left() <= 0.0) else "confirm", -4.0)

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
			if bool(Game.run.get("dead", false)):
				Game.finish()
				Game.goto("report")
				return
			Game.run["mode"] = "home"
			Game.goto("flight")
		return
	if hold.has("e"):
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
		drilling -= delta
		if drilling <= 0.0:
			drilling = 0.0
			samples[drill_target]["taken"] = true
			got += 1
			data += gb_sample
			got_t = t
			var sx: float = float(samples[drill_target]["x"])
			pops.append({"x": sx, "y": ground(sx) - 18.0, "age": 0.0, "s": "+1 SAMPLE", "spark": true})
			Audio.play("pickup")
			if got == goal:
				Audio.play("success", -4.0)
	elif has_rover:
		var dir: float = 0.0
		if _pressed(KEY_A, "ui_left", "l"):
			dir -= 1.0
		if _pressed(KEY_D, "ui_right", "r"):
			dir += 1.0
		if dir != 0.0:
			face = dir
			var nx: float = clampf(rx + dir * speed * wheel_k * delta, 40.0, WORLD - 40.0)
			if ground(nx + dir * 28.0) >= ry - 3.0 and ground(nx) >= ry - 3.0:
				rx = nx
			moving = true
			draw += rover_draw
		if on_ground and (_pressed(KEY_W, "ui_up", "u") or Input.is_physical_key_pressed(KEY_SPACE)):
			vy = -JUMP_V * PPM * (1.25 if Game.id_has("rover_big") else 1.0)
			on_ground = false
			Audio.play("jump", -8.0)
	# gravity (real value, scaled to pixels)
	vy += g * PPM * delta
	ry += vy * delta
	var gy: float = ground(rx)
	if ry >= gy:
		ry = gy
		vy = 0.0
		on_ground = true
	else:
		on_ground = false
	if moving and on_ground and ry >= LANE - 1.0 and absf(rx - last_track) >= 3.0:
		tracks.append(rx)  # no wind on an airless world: tracks there last for millions of years
		last_track = rx
		if tracks.size() > 3000:
			tracks.remove_at(0)
	if on_ground and not was_ground:
		Audio.play("land", -12.0)
		land_t = t
		land_x = rx
		if ry < LANE - 1.0:
			hazard_hit = true   # made it onto a boulder
		for i: int in 8:
			puffs.append({"p": Vector2(rx + randf_range(-30, 30), ry - 2.0), "v": Vector2(randf_range(-40, 40), -randf_range(4, 18)), "age": 0.0, "life": randf_range(0.6, 1.1), "size": 1})
	was_ground = on_ground
	Audio.loop("drill", drilling > 0.0, -12.0)
	Audio.loop("rover_loop", moving and on_ground, -10.0)
	gen_now = gen
	draw_now = draw
	var net: float = gen - draw
	if net < 0.0:
		net *= drain_k
	battery = clampf(battery + net * delta * h_rate, 0.0, wh)
	if life_min > 0.0:
		minutes += delta * min_rate
	# hazards: the moments a site event may come up
	if _in_shadow(rx) or _night() > 0.3 or (life_min > 0.0 and _life_left() < life_min * 0.5) or got >= 2:
		hazard_hit = true
	if _low() and not low_warned:
		low_warned = true
		hazard_hit = true
		Audio.play("battery_low", -4.0)
	if battery <= 0.0:
		_finish("BATTERY EMPTY: THE ROVER SHUT DOWN")
	elif life_min > 0.0 and _life_left() <= 0.0:
		_finish("TOO HOT: THE LANDER DIED AFTER %d min" % roundi(minutes))
	else:
		_maybe_event()

# ---------------------------------------------------------------- decision events

## Site events come after the first sample, then at a hazard (shadow, dusk, half the heat clock, a boulder).
func _maybe_event() -> void:
	if ev_cool > 0.0 or drilling > 0.0 or not on_ground or state != "explore":
		return
	var ev: Dictionary = Game.next_event("site")
	if ev.is_empty():
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
	moving = false
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
	if WHEEL_EVENTS.has(String(card_ev.get("id", ""))) and not bool(res.get("ok", true)) and wheel_k > WHEEL_SLOW:
		wheel_k = WHEEL_SLOW
		_pop(rx, y, "WHEEL DAMAGED: SLOWER")
		y -= 12.0
	var ap: Dictionary = res.get("applied", {})
	if ap.has("power") and solar > 0.0:
		_pop(rx, y, "LESS CHARGE: SOLAR %d W" % roundi(solar * float(Game.run["gen_mult"])))
		y -= 12.0
	if drill_was and not _drill_ok():
		_pop(rx, y, "DRILL BROKEN: NO MORE SAMPLES")
		y -= 12.0
	for ch: Array in res.get("chips", []):
		_pop(rx, y, String(ch[1]).to_upper())
		y -= 12.0
	if bool(Game.run.get("dead", false)):
		_finish("MISSION LOST")

# ---------------------------------------------------------------- particles

## Wheel dust as puffs, rock chips from the drill. With no air the dust flies on clean arcs and falls
## straight back; thin air lets it hang and drift with the wind; thick air holds it like water.
func _particles(delta: float) -> void:
	puff_t -= delta
	if has_rover and moving and on_ground and puff_t <= 0.0:
		puff_t = 0.07
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
	var sx: float = float(samples[drill_target]["x"])
	return Vector2(sx, ground(sx) - 3.0)

func _cam() -> float:
	return floorf(clampf(rx - 320.0, 0.0, WORLD - 640.0))

func _night() -> float:
	if float(d["night_hours"]) <= 0.0:
		return 0.0
	return 1.0 - clampf(maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 3.0, 0.0, 1.0)

func _process(_delta: float) -> void:
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
	# tread tracks: near and far wheels, a chevron every few pixels
	for x: float in tracks:
		var tx: float = floorf(x - cam)
		if tx < -2.0 or tx > 642.0:
			continue
		var odd: bool = int(x / 3.0) % 2 == 0
		front.draw_rect(Rect2(tx - 1, LANE + 1, 3, 1), Color(0, 0, 0, 0.3))
		front.draw_rect(Rect2(tx + (0.0 if odd else 1.0), LANE + 2, 1, 1), Color(0, 0, 0, 0.22))
		front.draw_rect(Rect2(tx - 1, LANE - 5, 3, 1), Color(0, 0, 0, 0.18))
	# lander, set slightly behind the lane, on its own engine scorch
	var lx: float = floorf(LANDER_X - cam)
	if lx > -120.0 and lx < 760.0:
		var lc: Color = _lit(LANDER_X, dim)
		front.draw_texture(tex_scorch, Vector2(lx - 34.0, LANE - 14.0), Color(lc, 0.55))
		_shadow(lx + 10.0, LANE - 6.0, 92.0, 0.35)
		front.draw_texture(tex_lander, Vector2(lx - 38.0, LANE - 6.0 - 71.0), lc)
		if fposmod(t, 1.4) < 0.18:
			Fx.glow(front, Vector2(lx + 16.0, LANE - 59.0), 4.0, Color(1.0, 0.35, 0.3, 0.7), true)
			front.draw_rect(Rect2(lx + 15.0, LANE - 60.0, 2, 2), Color("ffb0a0"))
	for b: Rect2 in boulders:
		var bx: float = floorf(b.position.x - cam)
		if bx < -80 or bx > 720:
			continue
		_shadow(bx + 34.0, LANE + 1.0, 78.0, 0.35)
		front.draw_texture(tex_boulder[int(b.size.y)], Vector2(bx, LANE - b.size.y), _lit(b.position.x + 33.0, dim))
	_draw_samples(cam, dim)
	# dust behind the rover
	for i: int in puffs.size():
		var p: Dictionary = puffs[i]
		var pp: Vector2 = p["p"]
		Fx.puff(front, (pp - Vector2(cam, 0)).floor(), float(p["age"]) / float(p["life"]), int(p["size"]), dust_col * _lit(pp.x, dim), i % 4)
	if t - land_t < 0.5:
		Fx.shockwave(front, Vector2(floorf(land_x - cam), LANE + 1.0), (t - land_t) / 0.5, 1, dust_col * _lit(land_x, dim))
	if has_rover:
		_draw_rover(cam, night, dim)
	elif drilling > 0.0:
		# the lander's own arm reaches out to the rock
		var bit: Vector2 = _bit_world() - Vector2(cam, 0)
		front.draw_line(Vector2(lx + 20, LANE - 40), bit, Color("c8ccd8"), 1.0)
		Fx.sparkle(front, bit, fposmod(t * 3.0, 1.0), UI.YELLOW, 0)
	for c: Dictionary in chips:
		var cp: Vector2 = c["p"]
		front.draw_texture(tex_chip, (cp - Vector2(cam + 1.0, 1.0)).floor(), _lit(cp.x, dim))
	_decor(cam, true, dim)
	for p: Dictionary in pops:
		var a: float = float(p["age"])
		if bool(p["spark"]):
			Fx.sparkle(front, Vector2(floorf(float(p["x"]) - cam), float(p["y"]) + 8.0), clampf(a * 1.6, 0.0, 1.0), UI.CYAN, 2)
		Pix.text_oc(front, floorf(float(p["x"]) - cam), floorf(float(p["y"]) - a * 14.0), String(p["s"]), 10, Color(UI.YELLOW, clampf(2.2 - a, 0.0, 1.0)))
	_draw_guides(cam)
	_draw_hud(night)

func _draw_samples(cam: float, dim: Color) -> void:
	var near_i: int = _nearest()
	for i: int in samples.size():
		var sd: Dictionary = samples[i]
		if sd["taken"]:
			continue
		var wx: float = float(sd["x"])
		var sx: float = floorf(wx - cam)
		if sx < -40.0 or sx > 680.0:
			continue
		var sy: float = floorf(ground(wx))
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + i)
		Fx.glow(front, Vector2(sx, sy), 12.0, Color(UI.CYAN, 0.25 + 0.2 * pulse))
		_shadow(sx, sy + 1.0, 22.0, 0.3)
		front.draw_texture(tex_sample, Vector2(sx - 10, sy - 11), _lit(wx, dim).lightened(0.35 if _in_shadow(wx) else 0.0))
		var gl: float = fposmod(t + i * 0.7, 2.0)
		if gl < 0.5:
			Fx.sparkle(front, Vector2(sx + 3, sy - 9), gl / 0.5, UI.CYAN, 0)
		if i == drill_target and drilling > 0.0:
			continue
		# a bobbing marker over the next one, with its distance
		var by: float = floorf(sy - 30.0 - absf(sin(t * 3.0)) * 4.0)
		if absf(rx - wx) >= _reach() or state != "explore":
			front.draw_texture(tex_marker, Vector2(sx - 4, by), Color.WHITE if i == near_i else Color(1, 1, 1, 0.55))
			if i == near_i:
				Pix.text_oc(front, sx, by - 3.0, "%d m" % roundi(absf(wx - rx) / PPM), 10, UI.TEXT)

func _draw_rover(cam: float, night: float, dim: Color) -> void:
	var rp: Vector2 = Vector2(floorf(rx - cam), floorf(ry))
	var lift: float = clampf((ground(rx) - ry) / 110.0, 0.0, 0.6)
	var rc: Color = _lit(rx, dim)
	var lamps: float = maxf(night, 1.0 if _in_shadow(rx) else 0.0)
	_shadow(rp.x, ground(rx) + 1.0, 74.0 * (1.0 - lift), 0.42 * (1.0 - lift))
	# headlights in the dark: a pool of light on the ground ahead and a beam
	if lamps > 0.25:
		Fx.glow(front, Vector2(rp.x + face * 72.0, LANE + 1.0), 48.0, Color(1.0, 0.9, 0.65, 0.5 * lamps))
		Fx.beam(front, _rl(rp, 72, 34), Vector2(face, 0), 96.0, 33.0, t, Color(1.0, 0.92, 0.7, 0.55 * lamps))
	# scanner: sweeps the nearest rock while it is close
	var ni: int = _nearest()
	if ni >= 0 and drilling <= 0.0:
		var dx: float = float(samples[ni]["x"]) - rx
		if absf(dx) < 110.0 and absf(dx) > 20.0 and signf(dx) == face:
			Fx.beam(front, _rl(rp, 66, 44), Vector2(face, 0), absf(dx) - 26.0, 9.0, t)
	var fr: int = (int(rx / 1.25) % 8) if moving else 0
	# sprung body: bobs on the suspension when driving, squashes on landing; a damaged wheel limps
	var bob: float = 0.0
	if moving and on_ground:
		bob = 1.0 if fposmod(rx, 14.0) < 7.0 else 0.0
		if wheel_k < 1.0 and fposmod(rx, 30.0) < 6.0:
			bob = 2.0
	if t - land_t < 0.15:
		bob = 2.0
	_rover_part(rp, Rect2(fr * 80, 0, 80, SPLIT), 0.0 + bob, rc)
	_rover_part(rp, Rect2(fr * 80, SPLIT, 80, 60 - SPLIT), float(SPLIT), rc)
	# blinking beacon on the mast, a lamp on the bumper
	if fposmod(t, 1.0) < 0.2:
		var bp: Vector2 = _rl(rp, 58, 8 + bob)
		Fx.glow(front, bp, 4.0, Color(1.0, 0.3, 0.25, 0.8), true)
		front.draw_rect(Rect2(bp.floor(), Vector2(1, 1)), Color("ffd0c8"))
	if lamps > 0.25:
		var hp: Vector2 = _rl(rp, 71, 34 + bob)
		Fx.glow(front, hp, 6.0, Color(1.0, 0.95, 0.75, 0.8), true)
		front.draw_rect(Rect2(hp.floor() - Vector2(0, 1), Vector2(2, 2)), Color("fff6d8"))
	if drilling > 0.0:
		_draw_drill(rp, cam, bob)

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

## The way to go: an arrow at the screen edge to the nearest rock, or back to the lander when done.
func _draw_guides(cam: float) -> void:
	if state != "explore":
		return
	var ni: int = _nearest()
	var home: bool = _go_home()
	var tx: float = LANDER_X if home else float(samples[ni]["x"])
	var label: String = "LANDER" if home else String(sk["noun"])
	var sx: float = tx - cam
	if home and sx > -20.0 and sx < 660.0:
		if not _at_lander():
			front.draw_texture(tex_marker, Vector2(floorf(sx - 4.0), LANE - 98.0 - floorf(absf(sin(t * 3.0)) * 4.0)), UI.GREEN)
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

# ---------------------------------------------------------------- directions and HUD

## The one thing to do now: [key cap, words]. It changes only when the player has done it.
func _direction() -> Array:
	if state != "explore":
		return ["", banner]
	if drilling > 0.0:
		return ["", "DRILLING: WAIT FOR THE SAMPLE"]
	if t < confirm_t and _at_lander():
		return ["E", "NO SAMPLES YET: PRESS E AGAIN TO LEAVE ANYWAY"]
	var ni: int = _nearest()
	if _go_home():
		var why: String = ""
		if _low() and got < goal:
			why = "BATTERY LOW: "
		elif not _drill_ok() and got < goal:
			why = "NO WORKING DRILL: "
		if _at_lander():
			return ["E", why + "PRESS E TO FINISH"]
		var lk: String = ">" if LANDER_X > rx else "<"
		return [lk, why + "DRIVE BACK TO THE LANDER, PRESS E"]
	var sx: float = float(samples[ni]["x"])
	var noun: String = String(sk["noun"])
	if absf(rx - sx) < _reach():
		return ["E", "PRESS E TO DRILL THE GLOWING %s" % noun]
	if not has_rover:
		return ["", "NO ROVER: ONLY THE ROCK NEXT TO THE LANDER"]
	var dir: float = signf(sx - rx)
	if on_ground and ground(rx + dir * 40.0) < ry - 3.0:
		return ["UP", "PRESS UP TO JUMP ONTO THE BOULDER"]
	var side: String = "RIGHT" if dir > 0.0 else "LEFT"
	if shadow_x >= 0.0 and rx < shadow_x and sx > shadow_x:
		return [">" if dir > 0.0 else "<", "HOLD %s TO DRIVE INTO THE DARK CRATER" % side]
	return [">" if dir > 0.0 else "<", "HOLD %s TO DRIVE TO THE GLOWING %s" % [side, noun]]

func _draw_hud(night: float) -> void:
	var pct: float = battery / wh
	var dim_c: Color = UI.DIM
	# left: battery, samples and data, gravity
	Pix.panel(front, Rect2(6, 6, 186, 62), pan_accent, pan_body)
	var bcol: Color = UI.GREEN if pct > 0.3 else (UI.RED if fposmod(t, 0.6) < 0.3 or pct > 0.2 else UI.YELLOW)
	var ascent: float = ASCENT_MIN if bool(d["returns"]) else -1.0
	Pix.icon(front, "battery", Vector2(12, 11), bcol)
	_text(Vector2(28, 21), "BATTERY", 10, UI.YELLOW if crit == "battery" else dim_c)
	Pix.gauge(front, Rect2(76, 13, 76, 8), pct, bcol, ascent)
	_text(Vector2(156, 21), "%d %%" % roundi(pct * 100.0), 10, UI.TEXT)
	for i: int in goal:
		var on: bool = i < got
		var pop: float = 1.0 if on and i == got - 1 and t - got_t < 0.25 else 0.0
		front.draw_texture(tex_rock[1], Vector2(12 + i * 15, 27 - pop), Color.WHITE if on else Color(0.3, 0.33, 0.45, 0.9))
	var dx: float = 16.0 + goal * 15.0
	_text(Vector2(dx, 36), "%d/%d" % [got, goal], 10, UI.TEXT)
	Pix.icon(front, "data", Vector2(dx + 30.0, 25), UI.CYAN)
	_text(Vector2(dx + 46.0, 36), "%s Gb" % Game.fmt(data), 10, UI.YELLOW if crit == "data" else UI.TEXT)
	var jump_m: float = pow(JUMP_V, 2) / (2.0 * g)
	Pix.icon(front, "gravity", Vector2(12, 43), dim_c)
	_text(Vector2(28, 53), "%.2f m/s2: JUMP %.1f m" % [g, jump_m], 10, UI.TEXT)
	_text(Vector2(28, 63), "ON EARTH: %.1f m" % (pow(JUMP_V, 2) / (2.0 * 9.81)), 10, dim_c)
	var hl: Rect2 = Rect2(9, 9, 180, 15) if crit == "battery" else Rect2(dx + 26.0, 23, 186.0 - dx - 26.0, 16)
	if crit != "heat":
		front.draw_rect(hl, Color(UI.YELLOW, 0.8), false, 1.0)
	# fact box under it: a verified fact for this world, one at a time
	var facts: Array = d["facts"]
	var fact: String = String(facts[int(t / 10.0) % facts.size()])
	Pix.panel(front, Rect2(6, 70, 186, 36), pan_accent, pan_body)
	Pix.para(front, Vector2(12, 81), fact, 176, dim_c)
	# right: power, the day clock, the "?" key
	var rows: int = 3 if float(d["night_hours"]) > 0.0 else 2
	Pix.panel(front, Rect2(500, 6, 114, 8 + rows * 11), pan_accent, pan_body)
	var y: float = 17.0
	if rows == 3:
		Pix.icon(front, "time", Vector2(505, y - 9), dim_c)
		_text(Vector2(520, y), "SOL %02d:%02d" % [int(hour), int(fposmod(hour, 1.0) * 60.0)], 10, UI.TEXT)
		y += 11.0
	var dark: String = "SHADOW" if _in_shadow(rx) else ("NIGHT" if night > 0.5 else "")
	var sol_txt: String = "SOLAR %d W" % roundi(gen_now - rtg)
	if solar <= 0.0 and rtg <= 0.0:
		sol_txt = "NO SUN: BATTERY"
	elif dark != "":
		sol_txt = "%s: SOLAR 0 W" % dark
	Pix.lamp(front, Vector2(505, y - 9), "ok" if gen_now >= draw_now else "warn")
	_text(Vector2(520, y), sol_txt, 10, UI.TEXT)
	y += 11.0
	Pix.icon(front, "power", Vector2(505, y - 9), dim_c)
	_text(Vector2(520, y), "USING %d W" % roundi(draw_now), 10, dim_c)
	Pix.panel(front, _help_rect(), pan_accent, pan_body)
	_text(Vector2(623, 18), "?", 10, UI.YELLOW if help_on else UI.TEXT)
	if life_min > 0.0:
		_draw_heat()
	# the one direction, at the bottom
	var dr: Array = _direction()
	var words: String = String(dr[1])
	if words != "":
		var kw: float = maxf(13.0, Pix.text_w(String(dr[0]), 10) + 7.0) + 6.0 if String(dr[0]) != "" else 0.0
		var w: float = kw + Pix.text_w(words, 10) + 16.0
		var x0: float = floorf(320.0 - w / 2.0)
		Pix.panel(front, Rect2(x0, 334, w, 21), pan_accent, pan_body)
		if kw > 0.0:
			Pix.keycap(front, Vector2(x0 + 8.0, 338), String(dr[0]))
		_text(Vector2(x0 + 8.0 + kw, 348), words, 10, UI.YELLOW)
	if help_on:
		_draw_help()

## The heat clock: how much of the lander's life is gone. It only goes up.
func _draw_heat() -> void:
	var used: float = clampf(1.0 - _life_left() / maxf(1.0, life_min), 0.0, 1.0)
	var col: Color = UI.YELLOW if used < 0.6 else (UI.ORANGE if used < 0.85 else (UI.RED if fposmod(t, 0.5) < 0.3 else UI.ORANGE))
	var r: Rect2 = Rect2(206, 6, 228, 36)
	Pix.panel(front, r, pan_accent, pan_body)
	front.draw_rect(r.grow(-2), Color(UI.YELLOW, 0.8), false, 1.0)
	Pix.icon(front, "hull", Vector2(212, 11), col)
	_text(Vector2(228, 20), "HULL HEAT", 10, UI.YELLOW)
	_text(Vector2(310, 20), "%d min LEFT OF %d min" % [maxi(0, roundi(_life_left())), roundi(life_min)], 10, UI.TEXT)
	Pix.gauge(front, Rect2(212, 26, 216, 11), used, col)

func _draw_help() -> void:
	var lines: Array = [
		["< >", "HOLD TO DRIVE (A, D)"],
		["UP", "JUMP (W, SPACE)"],
		["E", "DRILL A GLOWING %s / FINISH AT THE LANDER" % String(sk["noun"])],
		["?", "SHOW OR HIDE THIS LIST (H)"],
	]
	var extra: String = ""
	if bool(d["returns"]):
		extra = "Game rule: the ascent needs %d%% battery. Stay above yellow." % roundi(ASCENT_MIN * 100.0)
	elif life_min > 0.0:
		extra = "The lander lives %d min here. Full HULL HEAT ends it." % roundi(life_min)
	elif shadow_x >= 0.0:
		extra = "No sun in the crater: the panels stop, the battery drains."
	elif float(d["night_hours"]) > 0.0:
		extra = "At night the panels stop: the battery must last till dawn."
	var h: float = 26.0 + lines.size() * 17.0 + (14.0 if extra != "" else 0.0)
	var r: Rect2 = Rect2(150, floorf(170.0 - h / 2.0), 340, h)
	Pix.panel(front, r, pan_accent, Color(pan_body, 0.95))
	_text(r.position + Vector2(10, 14), "CONTROLS", 10, UI.YELLOW)
	var y: float = r.position.y + 22.0
	for ln: Array in lines:
		Pix.key_hint(front, Vector2(r.position.x + 10.0, y), String(ln[0]), String(ln[1]), UI.TEXT)
		y += 17.0
	if extra != "":
		_text(Vector2(r.position.x + 10.0, y + 8.0), extra, 10, UI.DIM)

# ---------------------------------------------------------------- autopilot (tests and demos)

## Plays the site by itself: drives to each rock, jumps boulders, drills, answers cards, goes home.
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
	hold.erase("l")
	hold.erase("r")
	hold.erase("u")
	if state != "explore" or drilling > 0.0:
		return
	var home: bool = _go_home()
	var tx: float = LANDER_X if home else float(samples[_nearest()]["x"])
	if (home and _at_lander()) or (not home and absf(tx - rx) < _reach() - 8.0):
		if on_ground:
			_use()
			if home:
				_use()   # a second press confirms leaving with no samples
		return
	var dir: float = signf(tx - rx)
	hold["r" if dir > 0.0 else "l"] = true
	if on_ground and ground(rx + dir * 40.0) < ry - 3.0:
		hold["u"] = true

# ---------------------------------------------------------------- debug hooks (screenshots and tests)

## Mars night: headlights on, driving right.
func debug_night() -> void:
	t = 45.0
	hour = fposmod(8.0 + t * h_rate, 24.66)
	hold["r"] = true

func debug_drive() -> void:
	hold["r"] = true

## Parked at the first rock out on the plain, half-way through drilling it.
func debug_drill() -> void:
	var i: int = 1 if not has_rover else 0
	rx = float(samples[i]["x"]) - 36.0
	ry = ground(rx)
	face = 1.0
	drilling = 1.0
	drill_target = i
	t = 10.0
	ev_cool = 99.0

## In the air over the first boulder.
func debug_jump() -> void:
	if boulders.is_empty():
		return
	var b: Rect2 = boulders[0]
	rx = b.position.x + b.size.x * 0.5
	ry = LANE - b.size.y - 20.0
	vy = -JUMP_V * PPM * 0.3
	on_ground = false
	was_ground = false
	face = 1.0
	t = 10.0
	ev_cool = 99.0

## Inside the crater's permanent shadow (or far out on the plain), driving on to the second sample.
func debug_crater() -> void:
	rx = float(samples[0]["x"]) + 60.0
	ry = ground(rx)
	samples[0]["taken"] = true
	got = 1
	data = gb_sample
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

## Every sample on board, driving home: the arrow points back to the lander.
func debug_done() -> void:
	for i: int in goal:
		samples[i + (0 if has_rover else 1)]["taken"] = true
	got = goal
	data = gb_sample * goal
	rx = 1400.0
	ry = ground(rx)
	face = -1.0
	t = 10.0
	ev_cool = 99.0

## At the lander with the samples: the direction says PRESS E TO FINISH.
func debug_home() -> void:
	debug_done()
	rx = LANDER_X + 40.0
	ry = ground(rx)

func debug_lowbatt() -> void:
	battery = wh * 0.18

func debug_help() -> void:
	help_on = true

## The autopilot plays the whole site at 3x speed, then the game moves on to the next screen.
func debug_auto() -> void:
	auto = true
	Engine.time_scale = 3.0

## What a bad stuck-wheel call looks like out in the world: the rover limps on at reduced speed.
func debug_outcome() -> void:
	debug_crater()
	card_ev = Game.event_by_id("stuck_wheel")
	_after_event({"ok": false, "chips": [["battery", "-40% battery", true]], "applied": {}})
