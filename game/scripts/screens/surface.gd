extends Control
## Surface exploration: drive the rover under real gravity, drill rocks, watch the battery.
## Depth in the style of a pixel racing game: lit 3D-rendered mountain ranges, a perspective
## floor (shaders/floor.gdshader), rocks scattered at many depths, contact shadows, tyre tracks.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const WORLD: float = 4000.0
const PPM: float = 20.0          # px per metre at the rover's lane
const JUMP_V: float = 3.2        # m/s take-off speed (game rule)
const HOURS_PER_SEC: float = 0.1 # 1 real second = 6 minutes on the planet
const LANDER_X: float = 333.0
const HORIZON: float = 232.0
const LANE: float = 300.0        # screen y of the ground under the rover
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]

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
var tex_lander: Texture2D = null
var tex_rover: Texture2D = null
var tex_earth: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_boulder: Dictionary = {}
var tex_sample: Texture2D = null
var tex_pebble: Array[Texture2D] = []
var tex_sky_day: Texture2D = null
var tex_sky_night: Texture2D = null
var dust: Array = []
var decor: Array = []
var tracks: PackedFloat32Array = PackedFloat32Array()
var last_track: float = -100.0
var haze_tint: Color = Color.WHITE
var was_ground: bool = true
var hold: Dictionary = {}
var confirm_t: float = -10.0
var floor_mat: ShaderMaterial = null
var front: Control = null

func _ready() -> void:
	g = float(Game.dest()["gravity"])
	var kind: String = "moon" if Game.dest_id == "moon" else "mars"
	tex_lander = Pix.img("lander")
	tex_rover = Pix.img("rover")
	tex_earth = Pix.planet(22, "earth")
	tex_far = Pix.img(kind + "_range_far")
	tex_mid = Pix.img(kind + "_range_near")
	tex_boulder = {23: Pix.img("boulder_%s_23" % kind), 50: Pix.img("boulder_%s_50" % kind)}
	tex_sample = Pix.img("sample_%s_big" % kind)
	for i: int in PEBBLE_W.size():
		tex_pebble.append(Pix.img("pebble_%s_%d" % [kind, i]))
	if kind == "mars":
		tex_sky_day = Pix.img("mars_sky_day")
		tex_sky_night = Pix.img("mars_sky_night")
	haze_tint = Color("7a7c92") if kind == "moon" else Color("f0c49a")
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
	rng.seed = 7 if Game.dest_id == "moon" else 11
	var goal: int = int(Game.dest()["samples_goal"])
	if not has_rover:
		samples.append({"x": LANDER_X + 117.0, "taken": false})
	for i: int in goal + 2:
		var sx: float = 800.0 + i * 500.0 + rng.randf_range(-67, 67)
		var bh: float = 23.0
		if Game.dest_id == "moon" and i % 2 == 1:
			bh = 50.0
		boulders.append(Rect2(sx - 150.0, 0.0, 67.0, bh))
		samples.append({"x": sx, "taken": false})
	# scenery rocks at many depths (s = distance, 1 at the lane, >1 behind, <1 in front)
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = 21 if kind == "moon" else 22
	for i: int in 260:
		var s: float = exp(rd.randf_range(log(0.55), log(9.0)))
		if s > 0.8 and s < 1.3:
			continue
		var span: float = 320.0 * s + 60.0
		var size: float = rd.randf_range(8.0, 44.0) * (0.45 if s < 1.0 else 1.0)
		decor.append({"x": rd.randf_range(320.0 - span, WORLD - 320.0 + span), "s": s, "b": size})
	decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	ry = ground(rx)
	# layers: this node draws sky and mountains; then the floor; then the world and HUD
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + kind))
	floor_mat.set_shader_parameter("haze", Color("1c1d28") if kind == "moon" else Color("b07a56"))
	floor_mat.set_shader_parameter("haze_max", 0.75 if kind == "moon" else 0.9)
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
	_hold_buttons()

func _hold_buttons() -> void:
	var defs: Array = [["<", 8, "l"], [">", 52, "r"], ["JUMP", 96, "u"], ["DRILL / E", 170, "e"]]
	for d: Array in defs:
		var b: Button = Button.new()
		b.text = d[0]
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.6)
		add_child(b)
		b.position = Vector2(float(d[1]), 330)
		var key: String = d[2]
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

func _use() -> void:
	if state != "explore" or drilling > 0.0:
		return
	if absf(rx - LANDER_X) < 70.0 and (has_rover or got > 0 or not Game.id_has("drill")):
		if got == 0 and t > confirm_t:
			confirm_t = t + 3.0
			_say("No samples yet! Press E again to end anyway.")
			return
		_finish("Back at the lander. Exploration complete.")
		return
	for i: int in samples.size():
		var s: Dictionary = samples[i]
		var reach: float = 40.0 if has_rover else 150.0
		if not s["taken"] and absf(rx - float(s["x"])) < reach:
			if not Game.id_has("drill"):
				_say("No drill on board: you can't pick it up!")
				return
			drilling = 2.0
			drill_target = i
			return
	_say("Nothing to drill here. Find a glowing rock.")

func _say(s: String) -> void:
	msg = s
	msg_t = 3.0

func _finish(text: String) -> void:
	if state != "explore":
		return
	state = "done"
	end_t = t + 2.5
	_say(text)
	Audio.loop("drill", false)
	Audio.play("error" if battery <= 0.0 else "confirm", -4.0)

func _physics_process(delta: float) -> void:
	t += delta
	msg_t -= delta
	if state != "explore":
		if t > end_t:
			set_physics_process(false)
			Game.surface_result(got, battery, data)
			Game.run["mode"] = "home"
			Game.goto("flight")
		return
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
			_say("Sample %d collected! +%s Gb of science." % [got, Game.fmt(gb_sample)])
			Audio.play("pickup")
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
	_dust(delta)
	Audio.loop("drill", drilling > 0.0, -12.0)
	battery = clampf(battery + (gen - draw) * delta * HOURS_PER_SEC * 3.0, 0.0, wh)
	if battery <= 0.0:
		_finish("BATTERY EMPTY. The robot shut down.")

## Wheel dust flies on real ballistic arcs: no air on the Moon, thin air (drag) on Mars.
func _dust(delta: float) -> void:
	if has_rover and moving and on_ground and randf() < 0.8:
		dust.append({"p": Vector2(rx - face * 30.0, ry - 1.0), "v": Vector2(-face * randf_range(12, 56), -randf_range(20, 76)), "life": 2.5})
	if on_ground and not was_ground:
		Audio.play("land", -12.0)
		for i: int in 14:
			dust.append({"p": Vector2(rx + randf_range(-30, 30), ry - 1.0), "v": Vector2(randf_range(-66, 66), -randf_range(16, 50)), "life": 2.0})
	was_ground = on_ground
	var drag: float = 0.0 if Game.dest_id == "moon" else 2.2
	for d: Dictionary in dust:
		var v: Vector2 = d["v"]
		v.y += g * PPM * delta
		v *= 1.0 - drag * delta
		d["v"] = v
		d["p"] = Vector2(d["p"]) + v * delta
		d["life"] = float(d["life"]) - delta
	dust = dust.filter(func(d: Dictionary) -> bool: return float(d["life"]) > 0.0 and Vector2(d["p"]).y <= LANE + 1.0)

func _cam() -> float:
	return floorf(clampf(rx - 320.0, 0.0, WORLD - 640.0))

func _night() -> float:
	if Game.dest_id == "moon":
		return 0.0
	return 1.0 - clampf(maxf(0.0, sin(PI * (hour - 6.0) / 12.33)) * 3.0, 0.0, 1.0)

func _process(_delta: float) -> void:
	floor_mat.set_shader_parameter("cam", _cam())
	floor_mat.set_shader_parameter("tint", Color.WHITE.darkened(_night() * 0.6))
	queue_redraw()
	front.queue_redraw()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(front, p, s, size, c)

## Back layer: sky, sun or Earth, two mountain ranges.
func _draw() -> void:
	var moon: bool = Game.dest_id == "moon"
	var cam: float = _cam()
	var night: float = _night()
	var dim: Color = Color.WHITE.darkened(night * 0.6)
	if moon:
		draw_rect(Rect2(0, 0, 640, 360), Color("04050a"))
		Pix.stars(self, t, Vector2(640, 230), 110, 8, Vector2(-cam * 0.03, 0))
		Pix.sprite(self, tex_earth, Vector2(520, 58))
	else:
		var sun_k: float = maxf(0.0, sin(PI * (hour - 6.0) / 12.33))
		draw_texture(tex_sky_day, Vector2.ZERO)
		if night > 0.0:
			draw_texture(tex_sky_night, Vector2.ZERO, Color(1, 1, 1, night))
		if night > 0.6:
			Pix.stars(self, t, Vector2(640, 200), 70, 4)
		var sun: Vector2 = Vector2(120 + (hour - 6.0) * 30.0, 250.0 - 190.0 * sun_k).floor()
		if sun_k > 0.0:
			# Mars sunsets glow blue: fine dust scatters blue light forward (NASA Curiosity images).
			var glow: Color = Color("e8d6b0").lerp(Color("8ab4e8"), clampf(1.0 - sun_k * 2.5, 0.0, 1.0))
			draw_circle(sun, 14.0, Color(glow, 0.18))
			draw_circle(sun, 8.0, Color(glow, 0.35))
			draw_circle(sun, 4.0, Color("fff6e0"))
	Pix.tiled(self, tex_far, HORIZON - tex_far.get_height() + 3, cam * 0.06, 640, dim)
	Pix.tiled(self, tex_mid, HORIZON - tex_mid.get_height() + 2, cam * 0.16, 640, dim)
	if not moon and night < 0.9:
		for i: int in 40:
			var dx: float = fposmod(i * 97.0 + t * (18.0 + (i % 3) * 9.0) - cam * 0.5, 680.0) - 20.0
			var dy: float = 110.0 + float((i * 53) % 120) + sin(t * 1.3 + i) * 4.0
			draw_rect(Rect2(floorf(dx), floorf(dy), 1, 1), Color(0.95, 0.75, 0.55, 0.35 * (1.0 - night)))

## A soft pixel ellipse on the ground (contact shadow), pushed right: the sun is on the left.
func _shadow(cx: float, y: float, w: float, a: float) -> void:
	for dy: int in range(-2, 3):
		var hw: float = floorf(w * 0.5 * sqrt(1.0 - pow(dy / 2.6, 2.0)))
		front.draw_rect(Rect2(floorf(cx + 5.0 - hw), floorf(y) + dy, hw * 2.0, 1), Color(0, 0, 0, a))

## Scenery rocks: `near` draws the ones in front of the lane (after the rover).
func _decor(cam: float, near: bool, dim: Color) -> void:
	var hmax: float = float(floor_mat.get_shader_parameter("haze_max"))
	for d: Dictionary in decor:
		var s: float = d["s"]
		if (s < 1.0) != near:
			continue
		var sx: float = 320.0 + (float(d["x"]) - cam - 320.0) / s
		if sx < -50.0 or sx > 690.0:
			continue
		var sy: float = HORIZON + (LANE - HORIZON) / s
		var want: float = float(d["b"]) / s
		var k: int = 0
		while k < PEBBLE_W.size() - 1 and PEBBLE_W[k + 1] <= want:
			k += 1
		var tex: Texture2D = tex_pebble[k]
		var fog: float = clampf((s - 1.0) / 9.0, 0.0, 1.0) * hmax
		var w: float = tex.get_width()
		if k >= 2:
			_shadow(sx, sy, w * 0.9, 0.25)
		front.draw_texture(tex, Vector2(floorf(sx - w * 0.5), floorf(sy - tex.get_height() + 2)), dim * Color.WHITE.lerp(haze_tint, fog))

## Front layer: everything that stands on the floor, then the HUD.
func _draw_front() -> void:
	var moon: bool = Game.dest_id == "moon"
	var cam: float = _cam()
	var night: float = _night()
	var dim: Color = Color.WHITE.darkened(night * 0.6)
	_decor(cam, false, dim)
	# tyre tracks: near and far wheels
	for x: float in tracks:
		var tx: float = floorf(x - cam)
		if tx < -2.0 or tx > 642.0:
			continue
		front.draw_rect(Rect2(tx - 1, LANE + 1, 2, 1), Color(0, 0, 0, 0.28))
		front.draw_rect(Rect2(tx - 1, LANE - 5, 2, 1), Color(0, 0, 0, 0.2))
	# lander, set slightly behind the lane
	var lx: float = floorf(LANDER_X - cam)
	_shadow(lx, LANE - 6.0, 92.0, 0.35)
	front.draw_texture(tex_lander, Vector2(lx - 38.0, LANE - 6.0 - 71.0), dim)
	for b: Rect2 in boulders:
		var bx: float = floorf(b.position.x - cam)
		if bx < -80 or bx > 720:
			continue
		_shadow(bx + 34.0, LANE + 1.0, 78.0, 0.35)
		front.draw_texture(tex_boulder[int(b.size.y)], Vector2(bx, LANE - b.size.y), dim)
	# samples
	for sd: Dictionary in samples:
		if sd["taken"]:
			continue
		var sx3: float = floorf(float(sd["x"]) - cam)
		var sy: float = floorf(ground(float(sd["x"])))
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		_shadow(sx3, sy + 1.0, 22.0, 0.3)
		front.draw_texture(tex_sample, Vector2(sx3 - 10, sy - 11), dim)
		front.draw_rect(Rect2(sx3 - 2, sy - 7, 2, 1), UI.CYAN.lerp(UI.YELLOW, pulse))
		front.draw_rect(Rect2(sx3 + 3, sy - 5, 1, 1), UI.CYAN.lerp(UI.YELLOW, 1.0 - pulse))
		var by: float = floorf(sy - 26.0 - pulse * 3.0)
		front.draw_rect(Rect2(sx3 - 2, by, 5, 1), Color(UI.YELLOW, 0.9))
		front.draw_rect(Rect2(sx3 - 1, by + 1, 3, 1), Color(UI.YELLOW, 0.9))
		front.draw_rect(Rect2(sx3, by + 2, 1, 2), Color(UI.YELLOW, 0.9))
	# dust
	var dcol: Color = Color("b4b4c4") if moon else Color("d08858")
	for d: Dictionary in dust:
		var dp: Vector2 = Vector2(d["p"]) - Vector2(cam, 0)
		front.draw_rect(Rect2(dp.floor(), Vector2(1, 1)), Color(dcol * dim, clampf(float(d["life"]), 0.0, 1.0)))
	# rover
	if has_rover:
		var rp: Vector2 = Vector2(floorf(rx - cam), floorf(ry))
		var lift: float = clampf((ground(rx) - ry) / 110.0, 0.0, 0.6)
		_shadow(rp.x, ground(rx) + 1.0, 74.0 * (1.0 - lift), 0.42 * (1.0 - lift))
		var fr: int = (int(rx / 1.25) % 8) if moving else 0
		var src: Rect2 = Rect2(fr * 80, 0, 80, 60)
		if face > 0.0:
			front.draw_texture_rect_region(tex_rover, Rect2(rp.x - 37, rp.y - 58, 80, 60), src, dim)
		else:
			front.draw_set_transform(Vector2(rp.x, 0), 0.0, Vector2(-1, 1))
			front.draw_texture_rect_region(tex_rover, Rect2(-37, rp.y - 58, 80, 60), src, dim)
			front.draw_set_transform(Vector2.ZERO)
		if night > 0.25:
			var a: float = 0.14 * night
			var hx: float = rp.x + face * 24.0
			var hy: float = rp.y - 26.0
			front.draw_colored_polygon(PackedVector2Array([Vector2(hx, hy - 2), Vector2(hx + face * 170.0, hy - 30), Vector2(hx + face * 170.0, rp.y + 8), Vector2(hx, hy + 3)]), Color(1, 0.9, 0.65, a))
			for dy: int in range(-3, 4):
				var hw: float = floorf(46.0 * sqrt(1.0 - pow(dy / 3.6, 2.0)))
				front.draw_rect(Rect2(hx + face * 96.0 - hw, LANE + dy, hw * 2.0, 1), Color(1, 0.9, 0.65, a * 1.3))
			front.draw_rect(Rect2(hx - 1, hy - 1, 2, 2), Color("fff2c0"))
		if drilling > 0.0:
			var dy2: float = 3.0 * absf(sin(t * 30.0))
			var bx2: float = rp.x + face * 30.0
			front.draw_rect(Rect2(bx2, rp.y - 22.0 + dy2, 1, 20), UI.YELLOW)
			if int(t * 20.0) % 2 == 0:
				front.draw_rect(Rect2(bx2 + randf_range(-4, 4), rp.y - randf_range(1, 6), 1, 1), Color("fff2c0"))
	elif drilling > 0.0:
		var tx2: float = float(samples[drill_target]["x"]) - cam
		front.draw_line(Vector2(lx + 20, LANE - 40), Vector2(tx2, ground(float(samples[drill_target]["x"])) - 6), UI.YELLOW, 1.0)
	_decor(cam, true, dim)
	# HUD
	Pix.panel(front, Rect2(8, 8, 276, 88))
	_text(Vector2(15, 22), "EXPLORING %s" % Game.place(), 11, UI.YELLOW)
	var pct: float = battery / wh
	_text(Vector2(15, 37), "BATTERY %d%%  (%s Wh)" % [roundi(pct * 100.0), Game.fmt(battery)], 10, UI.GREEN if pct > 0.3 else UI.RED)
	front.draw_rect(Rect2(15, 41, 262, 5), Color("0f1426"))
	front.draw_rect(Rect2(15, 41, floorf(262 * pct), 5), UI.GREEN if pct > 0.3 else UI.RED)
	front.draw_rect(Rect2(15, 41, floorf(262 * pct), 1), Color(1, 1, 1, 0.35))
	if moon:
		front.draw_rect(Rect2(floorf(15 + 262 * 0.3), 40, 1, 7), UI.YELLOW)
	_text(Vector2(15, 59), "SAMPLES %d / %d     DATA %s Gb" % [got, int(Game.dest()["samples_goal"]), Game.fmt(data)], 10, UI.CYAN)
	var jump_m: float = pow(JUMP_V, 2) / (2.0 * g)
	_text(Vector2(15, 73), "GRAVITY %s m/s2: jump %.1f m (Earth %.1f m)" % [str(g), jump_m, pow(JUMP_V, 2) / (2.0 * 9.81)], 9, UI.TEXT)
	if not moon:
		_text(Vector2(15, 87), "MARS TIME %02d:%02d  %s" % [int(hour), int(fposmod(hour, 1.0) * 60.0), "NIGHT: on battery" if night > 0.5 else "DAY: solar charging"], 9, UI.ORANGE)
	else:
		_text(Vector2(15, 87), "Ascent home needs 30% battery (yellow mark)", 9, UI.ORANGE)
	if not has_rover:
		_text(Vector2(296, 22), "NO ROVER: only rocks next to the lander.", 9, UI.RED)
	Pix.text_c(front, 400, 322, "ARROWS = DRIVE   UP = JUMP   E = DRILL   E AT LANDER = FINISH", 8, UI.DIM)
	if msg_t > 0.0:
		Pix.text_c(front, 320, 140, msg, 12, UI.YELLOW)
