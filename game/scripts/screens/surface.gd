extends Control
## Surface exploration: drive the rover under real gravity, drill rocks, watch the battery.
## Depth in the style of a pixel racing game: three mountain ranges, a perspective floor
## (shaders/floor.gdshader), craters, hills and rocks at many depths, contact shadows, tread tracks.
## Every puff, glow, sparkle and sun goes through the shared effects kit (scripts/fx.gd).

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const WORLD: float = 4000.0
const PPM: float = 20.0          # px per metre at the rover's lane
const JUMP_V: float = 3.2        # m/s take-off speed (game rule)
const HOURS_PER_SEC: float = 0.1 # 1 real second = 6 minutes on the planet
const LANDER_X: float = 333.0
const HORIZON: float = 232.0
const LANE: float = 300.0        # screen y of the ground under the rover
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]
const CRATER_W: Array[int] = [18, 26, 40, 64, 98]
const HILL_W: Array[int] = [46, 84, 130]
const SPLIT: int = 38            # rover sprite rows above this are the sprung body, below are the wheels

var t: float = 0.0
var state: String = "explore"
var end_t: float = 0.0
var g: float = 1.62
var rx: float = LANDER_X + 85.0
var ry: float = 0.0
var vy: float = 0.0
var on_ground: bool = true
var face: float = 1.0
var moving: bool = false
var has_rover: bool = false
var speed: float = 100.0
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
var hour: float = 8.0
var gb_sample: float = 0.0
var msg: String = ""
var msg_t: float = 0.0
var moon: bool = true
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
var pan_accent: Color = Color("3a4a7a")
var pan_body: Color = Color(0.03, 0.04, 0.08, 0.82)
var was_ground: bool = true
var hold: Dictionary = {}
var confirm_t: float = -10.0
var told: Dictionary = {}   # one-time tips already shown
var floor_mat: ShaderMaterial = null
var front: Control = null

func _ready() -> void:
	g = float(Game.dest()["gravity"])
	moon = Game.dest_id == "moon"
	var kind: String = "moon" if moon else "mars"
	goal = int(Game.dest()["samples_goal"])
	tex_lander = Pix.img("lander")
	tex_rover = Pix.img("rover")
	tex_earth = Pix.planet(22, "earth")
	tex_halo = Pix.img("surface/earth_halo")
	tex_dist = Pix.img("surface/%s_range_dist" % kind)
	tex_far = Pix.img(kind + "_range_far")
	tex_mid = Pix.img(kind + "_range_near")
	tex_boulder = {23: Pix.img("boulder_%s_23" % kind), 50: Pix.img("boulder_%s_50" % kind)}
	tex_sample = Pix.img("sample_%s_big" % kind)
	tex_scorch = Pix.img("surface/scorch")
	tex_marker = Pix.img("surface/marker")
	tex_arrow = Pix.img("surface/arrow_r")
	tex_chip = Pix.img("surface/chip")
	tex_streak = Pix.img("surface/streak")
	tex_rock = [Pix.img("surface/ic_rock0"), Pix.img("surface/ic_rock1")]
	for i: int in PEBBLE_W.size():
		tex_pebble.append(Pix.img("pebble_%s_%d" % [kind, i]))
	for i: int in CRATER_W.size():
		tex_crater.append(Pix.img("surface/crater_%s_%d" % [kind, i]))
	for i: int in HILL_W.size():
		tex_hill.append(Pix.img("surface/hill_%s_%d" % [kind, i]))
	if not moon:
		tex_sky_day = Pix.img("surface/mars_sky_day")
		tex_sky_night = Pix.img("surface/mars_sky_night")
		tex_cloud = [Pix.img("surface/mars_cloud_0"), Pix.img("surface/mars_cloud_1"), Pix.img("surface/mars_cloud_2")]
		tex_phobos = Pix.img("surface/phobos")
		tex_devil = Pix.img("surface/dust_devil")
		tex_sheet = Pix.img("surface/dust_sheet")
		pan_accent = Color("8a5a3c")
		pan_body = Color(0.16, 0.08, 0.06, 0.85)
	haze_tint = Color("7a7c92") if moon else Color("e8b890")
	dust_col = Color("b9b9c6") if moon else Color("d98a55")
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
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(p["gb"])
	# terrain features on the rover's lane
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7 if moon else 11
	if not has_rover:
		samples.append({"x": LANDER_X + 117.0, "taken": false})
	for i: int in goal + 2:
		var sx: float = 800.0 + i * 500.0 + rng.randf_range(-67, 67)
		var bh: float = 23.0
		if moon and i % 2 == 1:
			bh = 50.0
		boulders.append(Rect2(sx - 150.0, 0.0, 67.0, bh))
		samples.append({"x": sx, "taken": false})
	# scenery at many depths (s = distance, 1 at the lane, >1 behind, <1 in front):
	# k 0 rock, 1 crater, 2 low hill (only far away)
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = 21 if moon else 22
	for i: int in 300:
		var s: float = exp(rd.randf_range(log(0.55), log(9.0)))
		if s > 0.8 and s < 1.3:
			continue
		var span: float = 320.0 * s + 60.0
		var k: int = 0
		var roll: float = rd.randf()
		if s > 3.0 and roll < 0.18:
			k = 2
		elif s > 1.0 and roll < (0.45 if moon else 0.25):
			k = 1
		var size: float = rd.randf_range(8.0, 44.0) * (0.45 if s < 1.0 else 1.0)
		if k == 1:
			size = rd.randf_range(40.0, 160.0)
		elif k == 2:
			size = rd.randf_range(150.0, 700.0)
		decor.append({"x": rd.randf_range(320.0 - span, WORLD - 320.0 + span), "s": s, "b": size, "k": k})
	decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	ry = ground(rx)
	# layers: this node draws sky and mountains; then the floor; then the world and HUD
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + kind))
	floor_mat.set_shader_parameter("haze", Color("2a2c3a") if moon else Color("c99470"))
	floor_mat.set_shader_parameter("haze_max", 0.75 if moon else 0.85)
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

func _hold_buttons() -> void:
	var defs: Array = [["<", 8, 40, "l"], [">", 52, 40, "r"], ["JUMP", 452, 80, "u"], ["DRILL", 540, 92, "e"]]
	for d: Array in defs:
		var b: Button = Button.new()
		b.text = d[0]
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
		b.position = Vector2(float(d[1]), 326)
		b.size = Vector2(float(d[2]), 28)
		var key: String = d[3]
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold.erase(key))

func ground(x: float) -> float:
	var y: float = LANE
	for b: Rect2 in boulders:
		if x >= b.position.x and x <= b.position.x + b.size.x:
			y = minf(y, LANE - b.size.y)
	return y

func _pressed(key: Key, act: String, h: String) -> bool:
	return hold.has(h) or Input.is_physical_key_pressed(key) or (act != "" and Input.is_action_pressed(act))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_E or k.keycode == KEY_ENTER:
			_use()

func _reach() -> float:
	return 40.0 if has_rover else 150.0

func _at_lander() -> bool:
	return absf(rx - LANDER_X) < 70.0 and (has_rover or got > 0 or not Game.id_has("drill"))

## Index of the closest sample still on the ground, or -1.
func _nearest() -> int:
	var best: int = -1
	var bd: float = 1e9
	for i: int in samples.size():
		if not samples[i]["taken"] and absf(float(samples[i]["x"]) - rx) < bd:
			bd = absf(float(samples[i]["x"]) - rx)
			best = i
	return best

func _use() -> void:
	if state != "explore" or drilling > 0.0:
		return
	if _at_lander():
		if got == 0 and t > confirm_t:
			confirm_t = t + 3.0
			_say("No samples yet! Press E again to end anyway.")
			Audio.play("ui_deny", -6.0)
			return
		_finish("Back at the lander. Exploration complete.")
		return
	for i: int in samples.size():
		var s: Dictionary = samples[i]
		if not s["taken"] and absf(rx - float(s["x"])) < _reach():
			if not Game.id_has("drill"):
				_say("No drill on board: you can't pick it up!")
				Audio.play("ui_deny", -6.0)
				return
			drilling = 2.0
			drill_target = i
			face = 1.0 if float(s["x"]) >= rx or not has_rover else -1.0
			return
	_say("Nothing to drill here. Follow the arrow to a glowing rock.")
	Audio.play("ui_deny", -6.0)

func _say(s: String, secs: float = 3.0) -> void:
	msg = s
	msg_t = secs

func _finish(text: String) -> void:
	if state != "explore":
		return
	state = "done"
	end_t = t + 2.5
	_say(text)
	Audio.loop("drill", false)
	Audio.loop("rover_loop", false)
	Audio.play("error" if battery <= 0.0 else "confirm", -4.0)

func _physics_process(delta: float) -> void:
	t += delta
	msg_t -= delta
	_particles(delta)
	if state != "explore":
		if t > end_t:
			set_physics_process(false)
			Game.surface_result(got, battery, data)
			Game.run["mode"] = "home"
			Game.goto("flight")
		return
	_tips()
	if hold.has("e"):
		hold.erase("e")
		_use()
	# power
	var draw: float = base_draw
	var sun: float = 1.0
	if float(Game.dest()["night_hours"]) > 0.0:
		hour = fposmod(8.0 + t * HOURS_PER_SEC * 3.0, 24.66)
		sun = maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 1.57
	var gen: float = solar * sun + rtg
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
			pops.append({"x": sx, "y": ground(sx) - 18.0, "age": 0.0, "s": "+1 SAMPLE"})
			Audio.play("pickup")
			if got == goal:
				Audio.play("success", -4.0)
				_say("All %d samples! Drive back to the lander and press E." % goal, 4.0)
			else:
				_say("Sample %d collected! +%s Gb of science." % [got, Game.fmt(gb_sample)])
	elif has_rover:
		var dir: float = 0.0
		if _pressed(KEY_A, "ui_left", "l"):
			dir -= 1.0
		if _pressed(KEY_D, "ui_right", "r"):
			dir += 1.0
		if dir != 0.0:
			face = dir
			var nx: float = clampf(rx + dir * speed * delta, 40.0, WORLD - 40.0)
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
		tracks.append(rx)  # no wind on the Moon: tracks there last for millions of years
		last_track = rx
		if tracks.size() > 3000:
			tracks.remove_at(0)
	if on_ground and not was_ground:
		Audio.play("land", -12.0)
		land_t = t
		land_x = rx
		for i: int in 8:
			puffs.append({"p": Vector2(rx + randf_range(-30, 30), ry - 2.0), "v": Vector2(randf_range(-40, 40), -randf_range(4, 18)), "age": 0.0, "life": randf_range(0.6, 1.1), "size": 1})
	was_ground = on_ground
	Audio.loop("drill", drilling > 0.0, -12.0)
	Audio.loop("rover_loop", moving and on_ground, -10.0)
	battery = clampf(battery + (gen - draw) * delta * HOURS_PER_SEC * 3.0, 0.0, wh)
	if battery <= 0.0:
		_finish("BATTERY EMPTY. The robot shut down.")

## One-time tips, each shown once, when it first matters.
func _tips() -> void:
	if moon and t > 1.0 and not told.has("ascent"):
		told["ascent"] = true
		_say("The ascent home needs 30% battery: keep above the yellow mark.", 4.0)
	if battery / wh < 0.2 and not told.has("low"):
		told["low"] = true
		Audio.play("battery_low", -4.0)
		_say("BATTERY LOW: head back to the lander.", 4.0)
	if not moon and _night() > 0.5 and not told.has("night"):
		told["night"] = true
		_say("Night on Mars: no solar power. Headlights on, battery draining.", 4.0)

## Wheel dust as puffs, rock chips from the drill. No air on the Moon (dust falls straight back),
## thin air on Mars (it hangs and drifts with the wind).
func _particles(delta: float) -> void:
	puff_t -= delta
	if has_rover and moving and on_ground and puff_t <= 0.0:
		puff_t = 0.07
		for wx: float in [-22.0, 26.0]:
			puffs.append({"p": Vector2(rx + face * wx - face * 6.0, ry - 2.0), "v": Vector2(-face * randf_range(10, 34), -randf_range(10, 26)),
				"age": 0.0, "life": randf_range(0.35, 0.6) if moon else randf_range(0.8, 1.4), "size": 0})
	var drag: float = 0.0 if moon else 2.2
	for d: Dictionary in puffs:
		var v: Vector2 = d["v"]
		if moon:
			v.y += g * PPM * delta
		else:
			v.x += 14.0 * delta     # wind
			v.y -= 3.0 * delta
		v *= 1.0 - drag * delta
		d["v"] = v
		d["p"] = Vector2(d["p"]) + v * delta
		d["age"] = float(d["age"]) + delta
	puffs = puffs.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["life"]))
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
	pops = pops.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 1.5)

## World position of the drill bit: under the sample being drilled.
func _bit_world() -> Vector2:
	if drill_target < 0:
		return Vector2(rx, LANE)
	var sx: float = float(samples[drill_target]["x"])
	return Vector2(sx, ground(sx) - 3.0)

func _cam() -> float:
	return floorf(clampf(rx - 320.0, 0.0, WORLD - 640.0))

func _night() -> float:
	if moon:
		return 0.0
	return 1.0 - clampf(maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 3.0, 0.0, 1.0)

func _process(_delta: float) -> void:
	floor_mat.set_shader_parameter("cam", _cam())
	var tint: Color = Color.WHITE if moon else Color(0.86, 0.8, 0.78)
	floor_mat.set_shader_parameter("tint", tint.darkened(_night() * 0.6))
	floor_mat.set_shader_parameter("haze", (Color("2a2c3a") if moon else Color("c99470")).darkened(_night() * 0.6))
	queue_redraw()
	front.queue_redraw()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(front, p, s, size, c)

# ---------------------------------------------------------------- back layer: sky and ranges

func _draw() -> void:
	var cam: float = _cam()
	var night: float = _night()
	var dim: Color = Color.WHITE.darkened(night * 0.6)
	if moon:
		draw_rect(Rect2(0, 0, 640, 360), Color("04050a"))
		Pix.stars(self, t, Vector2(640, 230), 110, 8, Vector2(-cam * 0.03, 0))
		# a meteor now and then
		var mt: float = fposmod(t, 9.0)
		if mt < 0.6:
			draw_texture(tex_streak, Vector2(floorf(80.0 + mt * 260.0), floorf(40.0 + mt * 50.0)), Color(1, 1, 1, 1.0 - mt / 0.6))
		Pix.sprite(self, tex_halo, Vector2(520, 70))
		Pix.sprite(self, tex_earth, Vector2(520, 70))
	else:
		var sun_k: float = maxf(0.0, sin(PI * (hour - 6.0) / 12.33))
		draw_rect(Rect2(0, 200, 640, 60), Color("e8c49c").darkened(night * 0.6))
		draw_texture(tex_sky_day, Vector2(0, -40))
		if night > 0.0:
			draw_texture(tex_sky_night, Vector2(0, -40), Color(1, 1, 1, night))
		if night > 0.6:
			Pix.stars(self, t, Vector2(640, 200), 70, 4)
		if sun_k > 0.0:
			# Mars sunsets glow blue: fine dust scatters blue light forward (NASA Curiosity images).
			var sp: Vector2 = Vector2(120 + (hour - 6.0) * 30.0, 250.0 - 190.0 * sun_k).floor()
			Fx.sun(self, sp, 1, Color("fff0d8").lerp(Color("bcd8ff"), clampf(1.0 - sun_k * 2.5, 0.0, 1.0)), t)
		# Phobos crosses the sky fast: it orbits Mars three times a day
		draw_texture(tex_phobos, Vector2(floorf(fposmod(560.0 - t * 4.0, 760.0) - 60.0), 46.0), dim.lightened(night * 0.4))
		for i: int in 5:
			var cx: float = fposmod(i * 173.0 + t * (2.0 + i % 2) - cam * 0.02, 780.0) - 130.0
			draw_texture(tex_cloud[i % 3], Vector2(floorf(cx), floorf(50.0 + i * 24.0)), Color(dim, 0.7))
	Pix.tiled(self, tex_dist, HORIZON - tex_dist.get_height() + 4, cam * 0.02, 640, dim)
	Pix.tiled(self, tex_far, HORIZON - tex_far.get_height() + 3, cam * 0.06, 640, dim)
	if not moon:
		for i: int in 2:
			var dvx: float = fposmod(t * (5.0 + i * 3.0) + 380.0 + i * 310.0 - cam * 0.1, 760.0) - 60.0
			draw_texture_rect_region(tex_devil, Rect2(floorf(dvx), HORIZON - 38.0 - i * 4.0, 16, 34), Rect2(16 * ((int(t * 6.0) + i) % 4), 0, 16, 34), Color(dim, 0.75 - i * 0.2))
	Pix.tiled(self, tex_mid, HORIZON - tex_mid.get_height() + 8, cam * 0.16, 640, dim)
	if not moon:
		Pix.tiled(self, tex_sheet, HORIZON - 14.0, cam * 0.2 - t * 9.0, 640.0, Color(dim, 0.85))

# ---------------------------------------------------------------- front layer

## A soft pixel ellipse on the ground (contact shadow), pushed right: the sun is on the left.
func _shadow(cx: float, y: float, w: float, a: float) -> void:
	for dy: int in range(-2, 3):
		var hw: float = floorf(w * 0.5 * sqrt(1.0 - pow(dy / 2.6, 2.0)))
		front.draw_rect(Rect2(floorf(cx + 5.0 - hw), floorf(y) + dy, hw * 2.0, 1), Color(0, 0, 0, a))

func _pick(widths: Array[int], want: float) -> int:
	var k: int = 0
	while k < widths.size() - 1 and widths[k + 1] <= want:
		k += 1
	return k

## Scenery: `near` draws the rocks in front of the lane (after the rover).
func _decor(cam: float, near: bool, dim: Color) -> void:
	var hmax: float = float(floor_mat.get_shader_parameter("haze_max"))
	for d: Dictionary in decor:
		var s: float = d["s"]
		if (s < 1.0) != near:
			continue
		var sx: float = 320.0 + (float(d["x"]) - cam - 320.0) / s
		if sx < -80.0 or sx > 720.0:
			continue
		var sy: float = HORIZON + (LANE - HORIZON) / s
		var want: float = float(d["b"]) / s
		var fog: float = clampf((s - 1.0) / 9.0, 0.0, 1.0) * hmax
		var mod: Color = dim * Color.WHITE.lerp(haze_tint, fog)
		match int(d["k"]):
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
		front.draw_texture(tex_scorch, Vector2(lx - 34.0, LANE - 14.0), Color(dim, 0.55))
		_shadow(lx + 10.0, LANE - 6.0, 92.0, 0.35)
		front.draw_texture(tex_lander, Vector2(lx - 38.0, LANE - 6.0 - 71.0), dim)
		if fposmod(t, 1.4) < 0.18:
			Fx.glow(front, Vector2(lx + 16.0, LANE - 59.0), 4.0, Color(1.0, 0.35, 0.3, 0.7), true)
			front.draw_rect(Rect2(lx + 15.0, LANE - 60.0, 2, 2), Color("ffb0a0"))
	for b: Rect2 in boulders:
		var bx: float = floorf(b.position.x - cam)
		if bx < -80 or bx > 720:
			continue
		_shadow(bx + 34.0, LANE + 1.0, 78.0, 0.35)
		front.draw_texture(tex_boulder[int(b.size.y)], Vector2(bx, LANE - b.size.y), dim)
	_draw_samples(cam, dim)
	# dust behind the rover
	for i: int in puffs.size():
		var d: Dictionary = puffs[i]
		Fx.puff(front, (Vector2(d["p"]) - Vector2(cam, 0)).floor(), float(d["age"]) / float(d["life"]), int(d["size"]), dust_col * dim, i % 4)
	if t - land_t < 0.5:
		Fx.shockwave(front, Vector2(floorf(land_x - cam), LANE + 1.0), (t - land_t) / 0.5, 1, dust_col)
	if has_rover:
		_draw_rover(cam, night, dim)
	elif drilling > 0.0:
		# the lander's own arm reaches out to the rock
		var bit: Vector2 = _bit_world() - Vector2(cam, 0)
		front.draw_line(Vector2(lx + 20, LANE - 40), bit, Color("c8ccd8"), 1.0)
		Fx.sparkle(front, bit, fposmod(t * 3.0, 1.0), UI.YELLOW, 0)
	for c: Dictionary in chips:
		front.draw_texture(tex_chip, (Vector2(c["p"]) - Vector2(cam + 1.0, 1.0)).floor(), dim)
	_decor(cam, true, dim)
	for p: Dictionary in pops:
		var a: float = float(p["age"])
		Fx.sparkle(front, Vector2(floorf(float(p["x"]) - cam), float(p["y"]) + 8.0), clampf(a * 1.6, 0.0, 1.0), UI.CYAN, 2)
		Pix.text_oc(front, floorf(float(p["x"]) - cam), floorf(float(p["y"]) - a * 22.0), String(p["s"]), 10, Color(UI.YELLOW, clampf(1.5 - a, 0.0, 1.0)))
	_draw_guides(cam)
	_draw_hud(night)

func _draw_samples(cam: float, dim: Color) -> void:
	var near_i: int = _nearest()
	for i: int in samples.size():
		var sd: Dictionary = samples[i]
		if sd["taken"]:
			continue
		var sx: float = floorf(float(sd["x"]) - cam)
		if sx < -40.0 or sx > 680.0:
			continue
		var sy: float = floorf(ground(float(sd["x"])))
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + i)
		Fx.glow(front, Vector2(sx, sy), 12.0, Color(UI.CYAN, 0.25 + 0.2 * pulse))
		_shadow(sx, sy + 1.0, 22.0, 0.3)
		front.draw_texture(tex_sample, Vector2(sx - 10, sy - 11), dim)
		var gl: float = fposmod(t + i * 0.7, 2.0)
		if gl < 0.5:
			Fx.sparkle(front, Vector2(sx + 3, sy - 9), gl / 0.5, UI.CYAN, 0)
		if i == drill_target and drilling > 0.0:
			continue
		# a bobbing marker; in reach it turns into the E prompt
		var by: float = floorf(sy - 30.0 - absf(sin(t * 3.0)) * 4.0)
		if absf(rx - float(sd["x"])) < _reach() and state == "explore" and Game.id_has("drill"):
			var w: float = Pix.text_w("DRILL", 10) + 17.0
			Pix.key_hint(front, Vector2(sx - floorf(w / 2.0), by - 6.0), "E", "DRILL", UI.YELLOW)
		else:
			front.draw_texture(tex_marker, Vector2(sx - 4, by), Color.WHITE if i == near_i else Color(1, 1, 1, 0.55))
			if i == near_i:
				Pix.text_oc(front, sx, by - 3.0, "%d m" % roundi(absf(float(sd["x"]) - rx) / PPM), 10, UI.TEXT)

func _draw_rover(cam: float, night: float, dim: Color) -> void:
	var rp: Vector2 = Vector2(floorf(rx - cam), floorf(ry))
	var lift: float = clampf((ground(rx) - ry) / 110.0, 0.0, 0.6)
	_shadow(rp.x, ground(rx) + 1.0, 74.0 * (1.0 - lift), 0.42 * (1.0 - lift))
	# headlights at night: a pool of light on the ground ahead and a beam
	if night > 0.25:
		Fx.glow(front, Vector2(rp.x + face * 72.0, LANE + 1.0), 48.0, Color(1.0, 0.9, 0.65, 0.5 * night))
		Fx.beam(front, _rl(rp, 72, 34), Vector2(face, 0), 96.0, 33.0, t, Color(1.0, 0.92, 0.7, 0.55 * night))
	# scanner: sweeps the nearest rock while it is close
	var ni: int = _nearest()
	if ni >= 0 and drilling <= 0.0:
		var dx: float = float(samples[ni]["x"]) - rx
		if absf(dx) < 110.0 and absf(dx) > 20.0 and signf(dx) == face:
			Fx.beam(front, _rl(rp, 66, 44), Vector2(face, 0), absf(dx) - 26.0, 9.0, t)
	var fr: int = (int(rx / 1.25) % 8) if moving else 0
	# sprung body: bobs on the suspension when driving, squashes on landing
	var bob: float = 0.0
	if moving and on_ground:
		bob = 1.0 if fposmod(rx, 14.0) < 7.0 else 0.0
	if t - land_t < 0.15:
		bob = 2.0
	_rover_part(rp, Rect2(fr * 80, 0, 80, SPLIT), 0.0 + bob, dim)
	_rover_part(rp, Rect2(fr * 80, SPLIT, 80, 60 - SPLIT), float(SPLIT), dim)
	# blinking beacon on the mast, a lamp on the bumper
	if fposmod(t, 1.0) < 0.2:
		var bp: Vector2 = _rl(rp, 58, 8 + bob)
		Fx.glow(front, bp, 4.0, Color(1.0, 0.3, 0.25, 0.8), true)
		front.draw_rect(Rect2(bp.floor(), Vector2(1, 1)), Color("ffd0c8"))
	if night > 0.25:
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

func _rover_part(rp: Vector2, src: Rect2, oy: float, dim: Color) -> void:
	var y: float = rp.y - 58.0 + oy
	if face > 0.0:
		front.draw_texture_rect_region(tex_rover, Rect2(rp.x - 37.0, y, src.size.x, src.size.y), src, dim)
	else:
		front.draw_set_transform(Vector2(rp.x, 0), 0.0, Vector2(-1, 1))
		front.draw_texture_rect_region(tex_rover, Rect2(-37.0, y, src.size.x, src.size.y), src, dim)
		front.draw_set_transform(Vector2.ZERO)

## The way to go: an arrow at the screen edge to the nearest rock, or back to the lander when done.
func _draw_guides(cam: float) -> void:
	if state != "explore":
		return
	var tx: float = -1.0
	var label: String = ""
	var ni: int = _nearest()
	var home: bool = got >= goal or ni < 0
	if home:
		tx = LANDER_X
		label = "LANDER"
	else:
		tx = float(samples[ni]["x"])
		label = "ROCK"
	var sx: float = tx - cam
	if home and sx > -20.0 and sx < 660.0:
		# lander on screen: say what E does there
		if _at_lander():
			var w: float = Pix.text_w("FINISH", 10) + 17.0
			Pix.key_hint(front, Vector2(floorf(sx - w / 2.0), LANE - 104.0 - floorf(absf(sin(t * 3.0)) * 3.0)), "E", "FINISH", UI.GREEN)
		else:
			front.draw_texture(tex_marker, Vector2(floorf(sx - 4.0), LANE - 98.0 - floorf(absf(sin(t * 3.0)) * 4.0)), UI.GREEN)
		return
	if sx >= 0.0 and sx <= 640.0:
		return
	var right: bool = sx > 640.0
	var y: float = LANE - 50.0
	var nudge: float = floorf(fposmod(t * 2.0, 1.0) * 3.0)
	var col: Color = UI.GREEN if home else UI.YELLOW
	var acol: Color = Color(0.5, 1.4, 0.6) if home else Color.WHITE
	var dist: String = "%s %d m" % [label, roundi(absf(tx - rx) / PPM)]
	var w2: float = Pix.text_w(dist, 10) + 26.0
	var px: float = 622.0 - w2 if right else 18.0
	Pix.panel(front, Rect2(px - 4.0, y - 8.0, w2 + 8.0, 20), pan_accent, pan_body)
	if right:
		front.draw_texture(tex_arrow, Vector2(px + w2 - 10.0 + nudge, y - 2.0), acol)
		_text(Vector2(px + 2.0, y + 6.0), dist, 10, col)
	else:
		front.draw_set_transform(Vector2(px + 8.0 - nudge, 0), 0.0, Vector2(-1, 1))
		front.draw_texture(tex_arrow, Vector2(0, y - 2.0), acol)
		front.draw_set_transform(Vector2.ZERO)
		_text(Vector2(px + 14.0, y + 6.0), dist, 10, col)

# ---------------------------------------------------------------- HUD

func _draw_hud(night: float) -> void:
	var pct: float = battery / wh
	Pix.panel(front, Rect2(6, 6, 178, 58), pan_accent, pan_body)
	# battery, with the 30% ascent mark on the Moon
	var bcol: Color = UI.GREEN if pct > 0.3 else (UI.RED if fposmod(t, 0.6) < 0.3 or pct > 0.2 else UI.YELLOW)
	Pix.icon(front, "battery", Vector2(12, 12), bcol)
	Pix.gauge(front, Rect2(28, 14, 112, 8), pct, bcol, 0.3 if moon else -1.0)
	_text(Vector2(146, 22), "%d%%" % roundi(pct * 100.0), 10, bcol)
	# sample slots fill up; data collected
	for i: int in goal:
		var on: bool = i < got
		var pop: float = 1.0 if on and i == got - 1 and t - got_t < 0.25 else 0.0
		front.draw_texture(tex_rock[1], Vector2(12 + i * 15, 29 - pop), Color.WHITE if on else Color(0.3, 0.33, 0.45, 0.9))
	Pix.icon(front, "data", Vector2(16 + goal * 15, 27), UI.CYAN)
	_text(Vector2(31 + goal * 15, 37), "%s Gb" % Game.fmt(data), 10, UI.CYAN)
	# gravity: the jump height it gives here, next to Earth's
	var jump_m: float = pow(JUMP_V, 2) / (2.0 * g)
	Pix.icon(front, "gravity", Vector2(12, 45), UI.DIM)
	_text(Vector2(28, 55), "%s m/s2  JUMP %.1f m" % [str(g), jump_m], 10, UI.TEXT)
	_text(Vector2(28 + Pix.text_w("%s m/s2  JUMP %.1f m" % [str(g), jump_m], 10) + 4.0, 55), "(EARTH %.1f)" % (pow(JUMP_V, 2) / (2.0 * 9.81)), 10, UI.DIM)
	if not moon:
		# Mars clock: day or night decides whether the panels charge
		Pix.panel(front, Rect2(536, 6, 98, 30), pan_accent, pan_body)
		Pix.icon(front, "time", Vector2(542, 11), UI.ORANGE)
		_text(Vector2(558, 20), "SOL %02d:%02d" % [int(hour), int(fposmod(hour, 1.0) * 60.0)], 10, UI.TEXT)
		var nt: bool = night > 0.5
		Pix.lamp(front, Vector2(542, 23), "warn" if nt else "ok")
		_text(Vector2(558, 32), "NIGHT" if nt else "SOLAR ON", 10, UI.ORANGE if nt else UI.GREEN)
	if not has_rover:
		Pix.panel(front, Rect2(196, 6, 236, 18), pan_accent, pan_body)
		_text(Vector2(202, 18), "NO ROVER: only rocks next to the lander.", 10, UI.RED)
	# first seconds: the keys, as key caps
	if state == "explore" and t < 9.0 and has_rover and not DisplayServer.is_touchscreen_available():
		# bottom right, like the key strips of the landing and drone screens
		var w: float = 15.0 + 17.0 + Pix.text_w("DRIVE", 10) + 10.0 + 23.0 + Pix.text_w("JUMP", 10) + 10.0 + 17.0 + Pix.text_w("DRILL / FINISH", 10) + 12.0
		var x0: float = 634.0 - w
		Pix.panel(front, Rect2(x0, 334, w, 20), pan_accent, pan_body)
		var kx: float = x0 + 6.0
		kx += Pix.keycap(front, Vector2(kx, 337), "<") + 2.0
		kx += Pix.key_hint(front, Vector2(kx, 337), ">", "DRIVE") + 10.0
		kx += Pix.key_hint(front, Vector2(kx, 337), "UP", "JUMP") + 10.0
		kx += Pix.key_hint(front, Vector2(kx, 337), "E", "DRILL / FINISH")
	if msg_t > 0.0 and msg != "":
		var mw: float = Pix.text_w(msg, 10) + 20.0
		var a: float = clampf(msg_t * 3.0, 0.0, 1.0)
		Pix.panel(front, Rect2(floorf(320.0 - mw / 2.0), 92, mw, 20), pan_accent, Color(pan_body, pan_body.a * a))
		Pix.text_oc(front, 320, 105, msg, 10, Color(UI.YELLOW, a))

# ---------------------------------------------------------------- debug hooks (screenshots only)

## Mars night: headlights on, driving right.
func debug_night() -> void:
	t = 45.0
	hour = fposmod(8.0 + t * HOURS_PER_SEC * 3.0, 24.66)
	told["night"] = true
	told["ascent"] = true
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
	told["ascent"] = true
	t = 10.0

## In the air over the first boulder.
func debug_jump() -> void:
	var b: Rect2 = boulders[0]
	rx = b.position.x + b.size.x * 0.5
	ry = LANE - b.size.y - 34.0
	vy = -JUMP_V * PPM * 0.4
	on_ground = false
	was_ground = false
	face = 1.0
	told["ascent"] = true
	t = 10.0

## Every sample on board, driving home: the arrow points back to the lander.
func debug_done() -> void:
	for i: int in goal:
		samples[i + (0 if has_rover else 1)]["taken"] = true
	got = goal
	data = gb_sample * goal
	rx = 1400.0
	ry = ground(rx)
	face = -1.0
	told["ascent"] = true
	t = 10.0

## At the lander with the samples: the E prompt says FINISH.
func debug_home() -> void:
	debug_done()
	rx = LANDER_X + 40.0
	ry = ground(rx)

func debug_lowbatt() -> void:
	battery = wh * 0.18
