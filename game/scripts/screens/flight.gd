extends Control
## Launch, cruise map, orbit arrival (mode "out") and the trip home / data downlink (mode "home").
## The scene fills the whole 640 px; the mission log is a ticker in the console along the bottom.
## Art: res://art/flight (tools/art/gen_flight.py). Flames, smoke, sparks, glows, suns: scripts/fx.gd.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")

const RX: float = 336.0       # rocket centre x; these four match tools/art/gen_flight.py
const BASE_Y: float = 262.0   # rocket base, standing on the hold-down posts
const DECK_Y: float = 272.0   # front edge of the pad deck
const CON_Y: float = 298.0    # top of the console
const T_IGN: float = 2.4      # launch timeline in seconds: 3, 2, 1, ignition, liftoff, staging
const T_LIFT: float = 3.0
const T_SEP: float = 8.0
const T_LAUNCH_END: float = 10.8
const T_BOOM: float = 4.6
const T_CRUISE_P: float = 2.6
const T_CRUISE_END: float = 9.0
const T_ARRIVE_P: float = 2.6
const T_ARRIVE_END: float = 7.2
const T_HOME_END: float = 8.0
const AU_KM: float = 149597871.0
const SMOKE_WARM: Color = Color(1.0, 0.86, 0.72)
const SMOKE_COOL: Color = Color(0.80, 0.76, 0.90)
## Cassini's real flybys as [day, angle on the map in degrees, orbit radius on the map in px].
## Days: launch 15 Oct 1997, Venus 26 Apr 1998 and 24 Jun 1999, Earth 18 Aug 1999, Jupiter 30 Dec 2000 (NASA).
## The map is a diagram, not to scale.
const CASSINI: Array = [[0.0, 0.0, 52.0], [193.0, 200.0, 34.0], [405.0, 400.0, 72.0], [617.0, 575.0, 34.0],
	[672.0, 662.0, 52.0], [1172.0, 760.0, 160.0], [2447.0, 900.0, 262.0]]
## Engine nozzles of each launcher sprite (art/parts/lv_*.png): x from the sprite's left edge, plume width.
## The first one is the main engine; the others (side boosters) get slightly shorter plumes.
const NOZZLES: Dictionary = {"electron": [Vector2(6, 8)], "falcon9": [Vector2(11, 11)],
	"vulcan": [Vector2(17, 14), Vector2(7, 5), Vector2(28, 5)], "heavy": [Vector2(25, 11), Vector2(9, 11), Vector2(40, 11)]}
const FLYBYS: Array = [[193.0, "VENUS FLYBY"], [617.0, "VENUS FLYBY 2"], [672.0, "EARTH FLYBY"], [1172.0, "JUPITER FLYBY"]]

var stage: String = ""
var st: float = 0.0
var t: float = 0.0
var did: Dictionary = {}
var frozen: bool = false
var fast: bool = false

# ticker
var shown: int = 0
var lines: Array[Dictionary] = []
var new_t: float = 99.0
var hint: String = ""

# effects state
var parts: Array[Dictionary] = []
var spawn_acc: float = 0.0
var shake: float = 0.0
var flash_age: float = 9.0
var boom_age: float = -1.0
var storm_age: float = -1.0
var storm_hit: float = -1.0
var storm_speed: float = 200.0
var flyby_age: float = 9.0
var flyby_name: String = ""
var lost_p: float = 0.0

# cruise map
var map_c: Vector2 = Vector2(320, 156)
var map_sq: float = 0.48
var map_rot: float = 0.0
var map_sun: Vector2 = Vector2(320, 156)
var bodies: Array[Dictionary] = []
var others: Array[Dictionary] = []  # the rest of the Solar System: scenery, not part of the route
var sky: Array[Dictionary] = []     # Moon map only: the planets as far points in the sky
var tex_map: ImageTexture = null

# arrival
var orb_c: Vector2 = Vector2(400, 150)
var orb_rx: float = 190.0
var orb_ry: float = 52.0
var orb_tilt: float = 0.14

var tex_space: Texture2D = null
var tex_deep: Texture2D = null
var tex_rocket: Texture2D = null
var nozzles: Array[Vector2] = []
var tex_sky: Texture2D = null
var tex_far: Texture2D = null
var tex_near: Texture2D = null
var tex_front: Texture2D = null
var tex_tower: Texture2D = null
var tex_cap: Texture2D = null
var tex_arm: Texture2D = null
var tex_clamp: Texture2D = null
var tex_bird: Texture2D = null
var tex_limb: Texture2D = null
var tex_console: Texture2D = null
var tex_lamp: Texture2D = null
var tex_ship8: Texture2D = null
var tex_wave: Texture2D = null
var tex_capsule: Texture2D = null
var tex_orbiter: Texture2D = null
var tex_sample: Texture2D = null
var tex_earth_mid: Texture2D = null
var tex_big: Texture2D = null
var tex_big_back: Texture2D = null
var tex_big_front: Texture2D = null
var tex_clouds_near: Array[Texture2D] = []
var tex_clouds_far: Array[Texture2D] = []
var tex_small: Dictionary = {}
var tex_cam: Array[Texture2D] = []
## Online (decision D7): every player flies this screen from the same run and cruise seed, so they all
## see the same flight. Only the host moves on; the others hold the last frame until its "goto".
var left: bool = false

func _f(name: String) -> Texture2D:
	return Pix.img("flight/" + name)

func _ready() -> void:
	clip_contents = true
	tex_space = Pix.img("bg_space")
	tex_deep = _f("space_far")
	tex_rocket = ShipKit.launcher(Game.rocket_id)
	if tex_rocket == null:
		tex_rocket = Pix.img("rocket")
	_set_nozzles(Game.rocket_id)
	tex_sky = _f("sky")
	tex_far = _f("launch_far")
	tex_near = _f("launch_near")
	tex_front = _f("launch_front")
	tex_tower = _f("tower")
	tex_cap = _f("tower_cap")
	tex_arm = _f("arm")
	tex_clamp = _f("clamp")
	tex_bird = _f("bird")
	tex_limb = _f("limb")
	tex_console = _f("console")
	tex_lamp = _f("lamp")
	tex_ship8 = _f("ship8")
	tex_wave = _f("wave")
	tex_capsule = _f("capsule")
	tex_orbiter = Pix.img("orbiter")
	tex_sample = Pix.img("sample_moon_big")
	tex_earth_mid = Pix.planet(36, "earth")
	tex_big = _f("big_" + Game.dest_id)
	if Game.dest_id == "saturn":
		tex_big_back = _f("big_saturn_back")
		tex_big_front = _f("big_saturn_front")
	for i: int in 3:
		tex_clouds_near.append(_f("cloud_near_%d" % i))
		tex_clouds_far.append(_f("cloud_far_%d" % i))
	for n: String in ["earth", "mars", "moon", "venus", "jupiter", "mercury", "uranus", "neptune", "saturn"]:
		tex_small[n] = _f("p_" + n)
	tex_small["earth9"] = Pix.planet(9, "earth")
	tex_small["mars9"] = Pix.planet(9, "mars")
	tex_small["moon9"] = Pix.planet(9, "moon")
	tex_small["saturn9"] = Pix.planet(9, "saturn")
	tex_small["earth22"] = Pix.planet(22, "earth")
	for r: int in ([9, 12, 22] if Game.dest_id == "saturn" else [9, 12, 22, 36]):
		tex_cam.append(Pix.planet(r, Game.dest_id))
	_update_log(true)  # what happened before this screen sits in the ticker already, without the beeps
	_set_stage("launch" if Game.run.get("mode", "out") == "out" else "home")

func _set_nozzles(id: String) -> void:
	nozzles.clear()
	var rw: float = tex_rocket.get_width()
	var known: Array = NOZZLES.get(id, [])
	# a sprite of another size than the table was made for (stand-in art) gets one centred plume
	if known.is_empty() or Vector2(known[0]).x * 2.0 > rw + 4.0 or Vector2(known[0]).x * 2.0 < rw - 4.0:
		nozzles.append(Vector2(floorf(rw / 2.0), clampf(rw * 0.55, 8.0, 30.0)))
	else:
		for v: Vector2 in known:
			nozzles.append(v)

func _set_stage(s: String) -> void:
	stage = s
	st = 0.0
	did = {}
	parts.clear()
	shake = 0.0
	Audio.loop("thrust", false)
	if s == "cruise":
		_setup_map()
		Audio.music("drift")  # the long coast gets the calm track; the launch keeps "ascent"
	elif s == "arrive" or s == "home":
		var sat: bool = Game.dest_id == "saturn"
		if s == "arrive":
			orb_c = Vector2(396, 150) if sat else Vector2(404, 150)
		else:
			orb_c = Vector2(112, 160) if sat else Vector2(84, 196)
		orb_rx = 188.0 if sat else 172.0
		orb_ry = 64.0 if sat else 46.0
		orb_tilt = 0.244 if sat else 0.14
	_set_hint()

func _dead() -> bool:
	return bool(Game.run["dead"])

func _once(key: String, at: float) -> bool:
	if st < at or did.has(key):
		return false
	did[key] = true
	return true

func _process(delta: float) -> void:
	fast = Input.is_key_pressed(KEY_SPACE)
	if not frozen:
		_step(delta * (4.0 if fast else 1.0))
	queue_redraw()

func _step(dt: float) -> void:
	t += dt
	st += dt
	new_t += dt
	flash_age += dt
	flyby_age += dt
	shake = maxf(0.0, shake - dt * 3.0)
	if boom_age >= 0.0:
		boom_age += dt
	if storm_age >= 0.0:
		storm_age += dt
	if storm_hit >= 0.0:
		storm_hit += dt
	match stage:
		"launch":
			_step_launch(dt)
		"cruise":
			_step_cruise()
		"arrive":
			_step_arrive(dt)
		"home":
			if _once("p", 0.5):
				Game.phase_home()
				_set_hint()
			if float(Game.run["sent"]) > 0.0 and st < 5.8 and _once("rb%d" % int(st / 0.7), 0.8):
				Audio.play("radio_blip", -14.0, 1.0 + 0.12 * (int(st / 0.7) % 3))  # data packets leaving
			if st > T_HOME_END:
				_end()
	_step_parts(dt)
	_update_log(false)

func _next(s: String) -> void:
	if _dead():
		_end()
	else:
		_set_stage(s)

func _end() -> void:
	if left:
		return
	left = true
	Game.finish()
	Game.flow("report")

# ------------------------------------------------------------- ticker and hints

func _wrap(s: String, n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in s.split(" ", false):
		if line.length() + word.length() + 1 > n and line != "":
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		out.append(line)
	return out

func _update_log(silent: bool) -> void:
	var lg: Array = Game.run["log"]
	while shown < lg.size():
		var e: Dictionary = lg[shown]
		var txt: String = String(e["text"])
		# the storm report waits until the wave has reached the ship
		if stage == "cruise" and storm_hit < 0.0 and txt.to_lower().contains("storm"):
			break
		var ok: bool = e["ok"]
		for s: String in _wrap(txt, 70):
			lines.append({"s": s, "ok": ok, "e": shown})
		shown += 1
		if not silent:
			new_t = 0.0
			Audio.play("radio_blip" if ok else "error", -6.0 if ok else -3.0)

func _set_hint() -> void:
	var c: Dictionary = Game.run["calc"]
	var tr: Dictionary = Game.traj()
	match stage:
		"launch":
			hint = "Rocket limit on this path: %s kg. Your ship: %s kg. Heavier would not fly." % [Game.fmt(c["cap"]), Game.fmt(c["mass"])]
			if did.has("p") and _dead():
				hint = "Too heavy for this rocket. Remove parts or fuel, or pick a bigger rocket."
		"cruise":
			hint = "%s days of coasting. Sunlight fades with distance, so power must last the trip." % Game.fmt(tr["days"])
			if did.has("p") and _dead():
				hint = "The ship ran out of power. Add solar arrays or nuclear power (RTG)."
			elif storm_age >= 0.0:
				hint = "A real solar storm from NASA records. Shielding protects science and radio parts."
		"arrive":
			var dv: float = float(Game.dv_plan()["capture"])
			if dv <= 0.0:
				hint = "Aerobraking: the heat shield rubs on Mars' air to slow down. No fuel needed."
			else:
				hint = "Braking burn: %s km/s to be caught by gravity. Your fuel decides this." % str(dv)
			if did.has("p") and _dead():
				hint = "Not enough fuel to slow down. Carry more propellant or choose a gentler path."
		"home":
			hint = "Radio delay: %s. Antenna speed and storage decide how much gets home." % Game.dest()["light_delay"]

# ------------------------------------------------------------- particles

func _puff(p: Vector2, v: Vector2, life: float, size: int, tint: Color, rise: float = 8.0) -> void:
	if parts.size() < 220:
		parts.append({"k": 0, "p": p, "v": v, "age": 0.0, "life": life, "size": size, "tint": tint, "rise": rise, "n": parts.size()})

func _spark(p: Vector2, v: Vector2, life: float, tint: Color, grav: float = 220.0) -> void:
	if parts.size() < 220:
		parts.append({"k": 1, "p": p, "v": v, "age": 0.0, "life": life, "size": 0, "tint": tint, "rise": -grav, "n": parts.size()})

func _step_parts(dt: float) -> void:
	var i: int = parts.size() - 1
	while i >= 0:
		var q: Dictionary = parts[i]
		q["age"] = float(q["age"]) + dt
		if float(q["age"]) >= float(q["life"]):
			parts.remove_at(i)
		else:
			var v: Vector2 = q["v"]
			if int(q["k"]) == 0:
				v.x *= exp(-1.8 * dt)
				v.y = v.y * exp(-1.2 * dt) - float(q["rise"]) * dt
			else:
				v.y -= float(q["rise"]) * dt
			q["v"] = v
			q["p"] = Vector2(q["p"]) + v * dt
		i -= 1

func _draw_parts(off: Vector2) -> void:
	for q: Dictionary in parts:
		var p: Vector2 = Vector2(q["p"]) + off
		if p.y < -30.0 or p.y > 380.0:
			continue
		var a: float = float(q["age"]) / float(q["life"])
		if int(q["k"]) == 0:
			Fx.puff(self, p, a, int(q["size"]), Color(q["tint"]).lerp(SMOKE_COOL, a), int(q["n"]))
		else:
			Fx.sparkle(self, p, a, Color(q["tint"]), int(q["size"]))

# ------------------------------------------------------------- launch

func _launch_failed() -> bool:
	return did.has("p") and _dead()

## Height climbed above the pad, in pixels.
func _launch_h() -> float:
	var tl: float = st - T_LIFT
	if tl <= 0.0:
		return 0.0
	if _launch_failed():
		return minf(14.0 * tl * tl, 34.0 + 3.0 * sin(tl * 9.0))
	return 20.0 * pow(tl, 2.2)

func _burning() -> bool:
	if st < T_IGN:
		return false
	if _launch_failed():
		return st < T_BOOM
	return st < T_SEP - 0.3 or st > T_SEP + 0.6

func _step_launch(dt: float) -> void:
	for i: int in 3:
		if _once("beep%d" % i, float(i)):
			Audio.play("countdown_beep", -5.0)
	var rw: float = tex_rocket.get_width()
	var rh: float = tex_rocket.get_height()
	if st < T_IGN and randf() < dt * 7.0:  # oxygen vapour drifting off the tanks
		_puff(Vector2(RX + rw * 0.5, BASE_Y - rh * randf_range(0.45, 0.6)), Vector2(randf_range(8, 20), randf_range(2, 10)), 1.4, 0, Color(0.95, 0.9, 1.0, 0.8), -6.0)
	if _once("ign", T_IGN):
		Audio.play("ignition", -2.0)
		shake = 5.0
		flash_age = 0.0
		for i: int in 18:
			var sd: float = -1.0 if i % 2 == 0 else 1.0
			_spark(Vector2(RX + sd * 4.0, DECK_Y - 4.0), Vector2(sd * randf_range(50, 190), -randf_range(10, 110)), randf_range(0.35, 0.8), Color("ffb84d"))
	if _once("p", T_LIFT):
		Game.phase_launch()
		Audio.play("launch", -2.0)
		Audio.play("countdown_beep", -4.0, 2.0)
		shake = 4.0
		_set_hint()
	var failed: bool = _launch_failed()
	var h: float = _launch_h()
	if st > T_IGN and h < 400.0 and _burning():
		shake = maxf(shake, 1.6)
	if _burning() and st < T_SEP:
		spawn_acc += dt * (46.0 if h < 110.0 else 26.0)
		while spawn_acc >= 1.0:
			spawn_acc -= 1.0
			if h < 110.0:  # the flame trench throws the exhaust out along the ground
				var side: float = -1.0 if randf() < 0.5 else 1.0
				var from_mouth: bool = randf() < 0.35
				var p0: Vector2 = Vector2(RX + side * randf_range(4, 26), 288.0 - randf() * 5.0) if from_mouth else Vector2(RX + side * randf_range(96, 112), 284.0 - randf() * 6.0)
				_puff(p0, Vector2(side * randf_range(40, 150), -randf_range(2, 26)), randf_range(1.5, 2.9), 2 if randf() < 0.65 else 1, SMOKE_WARM, randf_range(6, 20))
			else:  # the trail stays behind in the sky
				_puff(Vector2(RX + randf_range(-5, 5), BASE_Y - h + randf_range(36, 70)), Vector2(randf_range(-10, 10), randf_range(20, 60)), randf_range(1.2, 2.2), 2 if randf() < 0.5 else 1, SMOKE_WARM, 0.0)
	if failed:
		if _once("boom", T_BOOM):
			Audio.play("explosion")
			boom_age = 0.0
			shake = 7.0
			flash_age = 0.0
			for i: int in 26:
				var a: float = randf() * TAU
				_spark(Vector2(RX, BASE_Y - h - rh * randf()), Vector2(cos(a), sin(a)) * randf_range(40, 200), randf_range(0.5, 1.3), Color("ff9f43"), 160.0)
			for i: int in 22:
				_puff(Vector2(RX + randf_range(-20, 20), BASE_Y - h - rh * randf()), Vector2(randf_range(-50, 50), randf_range(-40, 10)), randf_range(1.6, 3.0), 2, Color(0.45, 0.4, 0.5), 14.0)
		if st > T_BOOM + 3.4:
			_next("cruise")
		return
	if _once("sep", T_SEP):
		Audio.play("stage_sep", -2.0)
		shake = 2.5
		var jy: float = BASE_Y - h - rh + floorf(rh * 0.42)
		for i: int in 10:
			var sd2: float = -1.0 if i % 2 == 0 else 1.0
			_puff(Vector2(RX + sd2 * rw * 0.4, jy), Vector2(sd2 * randf_range(30, 90), _launch_speed() * -1.0 + randf_range(-20, 20)), randf_range(0.6, 1.1), 1 if i < 6 else 0, Color(1, 1, 1, 0.9), 0.0)
		for i: int in 8:
			_spark(Vector2(RX, jy), Vector2(randf_range(-120, 120), _launch_speed() * -1.0 + randf_range(-60, 60)), 0.6, Color("fff3b0"), 0.0)
	Audio.loop("thrust", st > T_SEP + 0.6, -9.0)
	if st > T_LAUNCH_END:
		_next("cruise")

## Climb rate in px/s, so separation puffs start out moving with the rocket.
func _launch_speed() -> float:
	return 44.0 * pow(maxf(0.0, st - T_LIFT), 1.2)

func _draw_launch() -> void:
	var failed: bool = _launch_failed()
	var h: float = _launch_h()
	var rw: float = tex_rocket.get_width()
	var rh: float = tex_rocket.get_height()
	var ts: float = st - T_SEP
	var lift: float = 40.0 + 64.0 * smoothstep(0.0, 1.4, ts)   # after staging the camera recentres on the upper stage
	var cam: float = floorf(maxf(0.0, h - lift))
	var k: float = clampf(cam / 900.0, 0.0, 1.0)
	var off: Vector2 = Vector2(0, cam)
	var cloud_c: Color = Color(1, 1, 1, 1.0 - smoothstep(0.22, 0.5, k))  # no clouds in space
	if shake > 0.05:
		off += Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).floor()
	# sky: stars behind a tall dawn strip that slides up with altitude
	if k > 0.25:
		draw_texture(tex_space, Vector2.ZERO)
		Pix.stars(self, t, Vector2(640, 300), 70, 9, Vector2(0, cam * 0.02))
	draw_texture_rect_region(tex_sky, Rect2(0, 0, 640, 360), Rect2(0, floorf(720.0 * (1.0 - k)), 640, 360))
	var fy: float = 208.0 + floorf(cam * 0.35) + off.y - cam
	if fy < 360.0:
		Fx.sun(self, Vector2(104, fy + 19.0), 2, Color("ffd75e"), t)
	for i: int in 9:  # far clouds, slow parallax
		var ct: Texture2D = tex_clouds_far[i % 3]
		var cx: float = fposmod(40.0 + i * 163.0 + t * (1.5 + i % 2), 720.0) - 80.0
		var cy: float = 196.0 - i * 62.0 - (i % 3) * 17.0 + cam * 0.5
		if cy > -20.0 and cy < 300.0:
			draw_texture(ct, Vector2(floorf(cx), floorf(cy)), cloud_c)
	if fy < 360.0:
		_layer(tex_far, Vector2(off.x, fy))
		for i: int in 6:  # birds over the lagoon; the ignition scares them off
			var bt: float = maxf(0.0, st - T_IGN - i * 0.05)
			var bp: Vector2 = Vector2(86.0 + i * 13.0 + (i % 2) * 5.0 + t * 5.0, 232.0 - (i % 3) * 6.0 + sin(t * 2.0 + i) * 2.0)
			bp += Vector2(-36.0 - i * 5.0, -30.0 - (i % 3) * 9.0) * bt
			var fr: int = int(t * (5.0 if bt <= 0.0 else 11.0) + i) % 2
			draw_texture_rect_region(tex_bird, Rect2((bp + Vector2(off.x, fy - 208.0)).floor(), Vector2(7, 5)), Rect2(fr * 7, 0, 7, 5))
	var on_pad: bool = cam + off.y - cam < 400.0 and cam < 380.0
	var burning: bool = _burning()
	var base: Vector2 = Vector2(RX, BASE_Y - h) + off
	if on_pad:
		_layer(tex_near, off)
		for lp: Vector2 in [Vector2(159, 168), Vector2(245, 196), Vector2(585, 180)]:  # floodlights
			Fx.glow(self, lp + off, 12.0, Color(1.0, 0.95, 0.75, 0.45 + 0.05 * sin(t * 30.0 + lp.x)), true)
		if int(t * 1.6) % 2 == 0:  # red beacons on the mast tops
			for bx: float in [RX - 116.0, RX + 116.0]:
				Fx.glow(self, Vector2(bx, 46) + off, 6.0, Color(1.0, 0.25, 0.2, 0.7), true)
		# service tower sized to the rocket, arms swing away at T-2
		var tr_x: float = floorf(RX - rw / 2.0) - 22.0
		var th: float = minf(tex_tower.get_height(), rh + 16.0)
		var tw: float = tex_tower.get_width()
		draw_texture_rect_region(tex_tower, Rect2(Vector2(tr_x - tw, 266.0 - th) + off, Vector2(tw, th)), Rect2(0, tex_tower.get_height() - th, tw, th))
		draw_texture(tex_cap, Vector2(tr_x - tw - 4.0, 266.0 - th - tex_cap.get_height()) + off)
		if int(t * 1.6) % 2 == 1:
			Fx.glow(self, Vector2(tr_x - tw + 12.0, 266.0 - th - 22.0) + off, 6.0, Color(1.0, 0.25, 0.2, 0.7), true)
		var arm_f: int = 0 if st < 1.0 else (1 if st < 1.5 else 2)
		for frac: float in [0.36, 0.62, 0.86]:
			draw_texture_rect_region(tex_arm, Rect2(Vector2(tr_x, floorf(BASE_Y - rh * frac) - 3.0) + off, Vector2(24, 7)), Rect2(0, arm_f * 7, 24, 7))
		if burning and h < 140.0:  # engine light on the pad and in the trench
			var gl: float = 1.0 - h / 140.0
			Fx.glow(self, Vector2(RX, 270) + off, 96.0 * gl, Color(1.0, 0.72, 0.36, 0.55 * gl))
	# the rocket: flame first, then the hull (two pieces after staging)
	var split: float = floorf(rh * 0.42)
	var top: Vector2 = Vector2(floorf(base.x - rw / 2.0), floorf(base.y - rh))
	var fw: float = clampf(rw * 0.55, 8.0, 30.0)
	if failed and boom_age >= 0.15:
		pass  # nothing left to draw
	elif ts < 0.0:
		if burning:
			var grow: float = clampf((st - T_IGN) / 0.5, 0.2, 1.0)
			var fl: float = minf((34.0 + rh * 0.42) * grow, h + 14.0) if h < 90.0 else 34.0 + rh * 0.42
			if failed:
				fl *= 0.5 + 0.5 * absf(sin(st * 17.0))  # the engine is struggling
			for i: int in nozzles.size():  # thinner air: the plume balloons
				var nz: Vector2 = nozzles[i]
				Fx.flame(self, Vector2(top.x + nz.x, base.y - 1.0), Vector2.DOWN, fl * (1.0 if i == 0 else 0.85), nz.y * (1.0 + 0.9 * k), t + i * 0.37)
		draw_texture(tex_rocket, top)
		if burning:  # warm light on the lowest part of the hull
			draw_texture_rect_region(tex_rocket, Rect2(top + Vector2(0, rh - 26.0), Vector2(rw, 26)), Rect2(0, rh - 26.0, rw, 26), Color(1.0, 0.8, 0.55))
	else:
		var fall: Vector2 = Vector2(floorf(-7.0 * ts), floorf(split + 4.0 + 80.0 * ts * ts))
		draw_texture_rect_region(tex_rocket, Rect2(top + fall, Vector2(rw, rh - split)), Rect2(0, split, rw, rh - split), Color(0.8, 0.8, 0.9))
		if burning:
			Fx.flame(self, top + Vector2(rw / 2.0, split - 1.0), Vector2.DOWN, 40.0, maxf(5.0, fw * 0.6), t, Color(0.8, 0.9, 1.0))
		draw_texture_rect_region(tex_rocket, Rect2(top, Vector2(rw, split)), Rect2(0, 0, rw, split))
	if on_pad:
		var cf: int = 0 if st < T_LIFT else 1
		draw_texture_rect_region(tex_clamp, Rect2(Vector2(floorf(RX - rw / 2.0) - 7.0, 253) + off, Vector2(9, 13)), Rect2(cf * 9, 0, 9, 13))
		draw_texture_rect_region(tex_clamp, Rect2(Vector2(floorf(RX + rw / 2.0) - 2.0, 253) + off, Vector2(-9, 13)), Rect2(cf * 9, 0, 9, 13))
		_layer(tex_front, off)
		if burning and h < 60.0:
			Fx.glow(self, Vector2(RX, 286) + off, 24.0, Color(1.0, 0.8, 0.4, 0.6))
		if st > T_LIFT and st < T_LIFT + 0.9:
			Fx.shockwave(self, Vector2(RX, 288) + off, (st - T_LIFT) / 0.9, 2, Color(1.0, 0.9, 0.8))
	_draw_parts(off)
	if boom_age >= 0.0:
		var bc: Vector2 = Vector2(RX, BASE_Y - h - rh * 0.5) + off
		Fx.explosion(self, bc + Vector2(0, rh * 0.25), boom_age, 2, 110.0)
		Fx.explosion(self, bc + Vector2(-6, -rh * 0.2), boom_age - 0.14, 2, 110.0)
		Fx.explosion(self, bc + Vector2(8, 0), boom_age - 0.3, 1, 110.0)
	for i: int in 7:  # near clouds rush past in front of the rocket
		var nt: Texture2D = tex_clouds_near[i % 3]
		var nx: float = float((i * 263 + 20) % 700) - 90.0
		var ny: float = -150.0 - i * 105.0 + cam * 1.25
		if ny > -50.0 and ny < 300.0:
			draw_texture(nt, Vector2(floorf(nx), floorf(ny)), cloud_c)
	if k > 0.45:  # the curved edge of the Earth rises into view
		draw_texture(tex_limb, Vector2(0, floorf(360.0 - (k - 0.45) / 0.55 * 150.0)))
	Fx.flash(self, flash_age, 0.2, Color(1.0, 0.95, 0.85))
	# telemetry
	var rk: Dictionary = Data.ROCKETS[Game.rocket_id]
	var tl: float = st - T_LIFT
	Pix.panel(self, Rect2(6, 6, 252, 42))
	if tl < 0.0:
		_text(Vector2(13, 28), "T-%d" % ceili(-tl), 20, UI.YELLOW)
		_text(Vector2(64, 20), String(rk["name"]), 10, UI.TEXT)
		_text(Vector2(64, 34), "IGNITION" if st >= T_IGN else ("ARMS CLEAR" if st >= 1.0 else "COUNTDOWN"), 10, UI.YELLOW)
		if st < T_IGN:
			_big(170.0, 140.0, str(ceili(T_LIFT - st)), Color.WHITE if fposmod(st, 1.0) < 0.12 else UI.YELLOW)
	else:
		_text(Vector2(13, 28), "T+%d" % int(tl * 30.0), 20, UI.TEXT)
		_text(Vector2(100, 20), String(rk["name"]), 10, UI.DIM)
		if failed:
			_text(Vector2(100, 34), "NO THRUST MARGIN", 10, UI.RED)
		elif ts > 0.0:
			_text(Vector2(100, 34), "STAGE 2 BURN" if ts > 0.6 else "STAGING", 10, UI.GREEN)
		else:
			_text(Vector2(100, 34), "LIFTOFF!", 10, UI.GREEN)
		if not failed:
			var alt: float = 70.0 * pow(tl / 5.0, 2.2)
			_alt_tape(alt)
			var alt_s: String = "%d km" % int(alt)
			_text(Vector2(250.0 - Pix.text_w("ALTITUDE", 10), 20), "ALTITUDE", 10, UI.DIM)
			_text(Vector2(250.0 - Pix.text_w(alt_s, 10), 34), alt_s, 10, UI.YELLOW)
	if failed and boom_age >= 0.0:
		_big(320.0, 150.0, "LAUNCH FAILED", UI.RED if int(t * 4.0) % 2 == 0 else Color("ff9f9f"))

## Scenery layer with a second copy beside it, so camera shake never opens a gap at the screen edge.
func _layer(tex: Texture2D, pos: Vector2) -> void:
	draw_texture(tex, pos)
	if pos.x != 0.0:
		draw_texture(tex, pos - Vector2(signf(pos.x) * 640.0, 0))

## Altitude tape on the right edge: a marker climbing past the cloud tops and the edge of space.
func _alt_tape(alt_km: float) -> void:
	var x: float = 618.0
	var y0: float = 280.0
	var hgt: float = 216.0
	Pix.panel(self, Rect2(x, y0 - hgt - 4.0, 16, hgt + 8.0))
	for i: int in 10:
		draw_rect(Rect2(x + 10.0, floorf(y0 - hgt * i / 9.0), 4, 1), UI.BORDER)
	var marks: Array = [[12.0, "CLOUD TOPS"], [100.0, "SPACE 100 km"]]
	for m: Array in marks:
		var my: float = floorf(y0 - hgt * float(m[0]) / 180.0)
		draw_rect(Rect2(x + 2.0, my, 12, 1), UI.CYAN if alt_km >= float(m[0]) else UI.DIM)
		_text(Vector2(x - 4.0 - Pix.text_w(String(m[1]), 10), my + 4.0), String(m[1]), 10, UI.CYAN if alt_km >= float(m[0]) else UI.DIM)
	var ay: float = floorf(y0 - hgt * clampf(alt_km / 180.0, 0.0, 1.0))
	draw_rect(Rect2(x + 3.0, ay - 2.0, 8, 5), UI.YELLOW)
	draw_rect(Rect2(x + 1.0, ay, 12, 1), Color.WHITE)

# ------------------------------------------------------------- cruise

func _map_pt(ang_deg: float, r: float) -> Vector2:
	var a: float = deg_to_rad(ang_deg + map_rot)
	return map_c + Vector2(cos(a) * r, -sin(a) * r * map_sq)

func _body(tex_name: String, label: String, r: float, a0: float, d0: float, rate: float) -> void:
	bodies.append({"tex": tex_small[tex_name], "name": label, "r": r, "a0": a0, "d0": d0, "rate": rate})

## A planet that is not on the route. `screen_deg` is where it sits on the map at the END of the trip.
func _other(tex_name: String, label: String, r: float, screen_deg: float, d0: float, rate: float) -> void:
	others.append({"tex": tex_small[tex_name], "name": label, "r": r, "a0": screen_deg - map_rot, "d0": d0, "rate": rate})

func _setup_map() -> void:
	var tr: Dictionary = Game.traj()
	var days: float = float(tr["days"])
	bodies.clear()
	others.clear()
	sky.clear()
	map_rot = 0.0
	storm_age = -1.0
	storm_hit = -1.0
	var radii: Array[float] = []
	var belt: Vector2 = Vector2.ZERO
	if Game.dest_id == "moon":
		map_c = Vector2(130, 196)
		map_sq = 0.451
		map_sun = Vector2(-520, 60)
		radii = [419.0]
		_body("moon9", "MOON", 419.0, 25.0, days, 360.0 / 27.32)
		# seen from the Earth-Moon system the planets are far points of light in the sky
		var spots: Array = [["mercury", "MERCURY", 206, 276], ["venus", "VENUS", 262, 252], ["mars", "MARS", 326, 272],
			["jupiter", "JUPITER", 396, 248], ["saturn", "SATURN", 462, 274], ["uranus", "URANUS", 528, 250], ["neptune", "NEPTUNE", 594, 272]]
		for sp: Array in spots:
			sky.append({"tex": tex_small[sp[0]], "name": sp[1], "pos": Vector2(sp[2], sp[3])})
	elif Game.dest_id == "mars":
		map_c = Vector2(320, 156)
		map_sq = 0.5
		map_sun = map_c
		radii = [120.0, 182.0]
		_body("earth9", "EARTH", 120.0, 0.0, 0.0, 360.0 / 365.25)
		_body("mars9", "MARS", 182.0, 180.0, days, 360.0 / 687.0)
		radii.append_array([44.0, 80.0, 226.0, 256.0, 280.0, 300.0])
		_other("mercury", "", 44.0, 300.0, days, 360.0 / 87.97)
		_other("venus", "VENUS", 80.0, 140.0, days, 360.0 / 224.7)
		_other("jupiter", "JUPITER", 226.0, 200.0, days, 360.0 / 4332.6)
		_other("saturn", "SATURN", 256.0, 348.0, days, 360.0 / 10759.0)
		_other("uranus", "URANUS", 280.0, 165.0, days, 360.0 / 30687.0)
		_other("neptune", "NEPTUNE", 300.0, 325.0, days, 360.0 / 60190.0)
	else:
		map_c = Vector2(320, 158)
		map_sq = 0.48
		map_sun = map_c
		radii = [34.0, 52.0, 74.0, 160.0, 262.0]
		belt = Vector2(96.0, 124.0)
		var assist: bool = tr["id"] == "assist"
		map_rot = 60.0 if assist else 0.0
		_body("venus", "", 34.0, 200.0, 193.0, 1.7335)
		_body("earth", "EARTH", 52.0, 0.0, 0.0, 360.0 / 365.25)
		_body("mars", "", 74.0, 100.0, 0.0, 360.0 / 687.0)
		_body("jupiter", "JUPITER", 160.0, 760.0 if assist else 60.0, 1172.0, 360.0 / 4332.6)
		_body("saturn9", "SATURN", 262.0, 900.0 if assist else 180.0, days, 360.0 / 10759.0)
		radii.append_array([20.0, 292.0, 314.0])
		_other("mercury", "", 20.0, 250.0, days, 360.0 / 87.97)
		_other("uranus", "URANUS", 292.0, 350.0, days, 360.0 / 30687.0)
		_other("neptune", "NEPTUNE", 314.0, 215.0, days, 360.0 / 60190.0)
	# orbits and the asteroid belt are baked once into one texture
	var im: Image = Image.create(640, 300, false, Image.FORMAT_RGBA8)
	for r: float in radii:
		var n: int = int(r * 7.0)
		for i: int in n:
			var p: Vector2 = _map_pt(360.0 * i / n, r)
			if p.x >= 0.0 and p.x < 640.0 and p.y >= 0.0 and p.y < 298.0:
				var near_side: bool = p.y > map_c.y
				im.set_pixel(int(p.x), int(p.y), Color(0.42, 0.52, 0.86, 0.62 if near_side else 0.36))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	if belt.y > 0.0:
		for i: int in 420:
			var bp: Vector2 = _map_pt(rng.randf() * 360.0, rng.randf_range(belt.x, belt.y))
			im.set_pixel(int(bp.x), int(bp.y), Color(0.62, 0.58, 0.52, rng.randf_range(0.25, 0.7)))
	tex_map = ImageTexture.create_from_image(im)

func _body_pos(b: Dictionary, day: float) -> Vector2:
	return _map_pt(float(b["a0"]) + (day - float(b["d0"])) * float(b["rate"]), float(b["r"]))

## Where the ship is on the map after the fraction p of the trip.
func _path(p: float) -> Vector2:
	var tr: Dictionary = Game.traj()
	if Game.dest_id == "moon":
		var a: Vector2 = map_c + Vector2(20, -12)
		var b: Vector2 = _map_pt(25.0, 419.0) + Vector2(-9, 5)
		if tr["id"] == "low":  # CAPSTONE swung far past the Moon and fell back
			return a.bezier_interpolate(Vector2(330, 0), Vector2(680, 30), b, p)
		return a.bezier_interpolate(Vector2(230, 96), Vector2(400, 60), b, p)
	if tr["id"] == "assist":
		var d: float = p * 2447.0
		for i: int in CASSINI.size() - 1:
			var w0: Array = CASSINI[i]
			var w1: Array = CASSINI[i + 1]
			if d <= float(w1[0]) or i == CASSINI.size() - 2:
				var u: float = clampf((d - float(w0[0])) / (float(w1[0]) - float(w0[0])), 0.0, 1.0)
				return _map_pt(lerpf(float(w0[1]), float(w1[1]), u), lerpf(float(w0[2]), float(w1[2]), smoothstep(0.0, 1.0, u)))
	var re: float = float(bodies[0]["r"]) if Game.dest_id == "mars" else 52.0
	var rd: float = float(bodies[bodies.size() - 1]["r"])
	var e: float = (rd - re) / (rd + re)
	var th: float = PI * p
	return _map_pt(rad_to_deg(th), (re + rd) / 2.0 * (1.0 - e * e) / (1.0 + e * cos(th)))

func _cruise_p() -> float:
	if did.has("p") and _dead():
		return lost_p
	return clampf(st / (T_CRUISE_END - 0.6), 0.0, 1.0)

func _step_cruise() -> void:
	var p: float = _cruise_p()
	var days: float = float(Game.traj()["days"])
	if Game.traj()["id"] == "assist" and not _dead():
		for fb: Array in FLYBYS:
			if p * days >= float(fb[0]) and not did.has(fb[1]):
				did[fb[1]] = true
				flyby_age = 0.0
				flyby_name = String(fb[1])
				Audio.play("radio_blip", -4.0, 1.4)
	if _once("p", T_CRUISE_P):
		lost_p = p
		Game.phase_cruise()
		if not Game.run["storm"].is_empty():
			Audio.play("alarm", -6.0)
			storm_age = 0.0
			storm_speed = maxf(150.0, (_path(p) - map_sun).length() / 1.3)
		_set_hint()
	if storm_age >= 0.0 and storm_hit < 0.0 and storm_age * storm_speed >= (_path(p) - map_sun).length():
		storm_hit = 0.0
		flash_age = 0.0
		shake = 3.0 if _storm_big() else 1.0
	if st > T_CRUISE_END:
		_next("arrive")

func _storm_big() -> bool:
	var ev: Dictionary = Game.run["storm"]
	return not ev.is_empty() and float(ev["kp"]) >= 7.5

func _draw_cruise() -> void:
	var tr: Dictionary = Game.traj()
	var days: float = float(tr["days"])
	var p: float = _cruise_p()
	var day: float = p * days
	var lost: bool = did.has("p") and _dead()
	var off: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).floor() if shake > 0.05 else Vector2.ZERO
	draw_texture(tex_deep, Vector2.ZERO)
	Pix.stars(self, t, Vector2(640, 298), 46, 21)
	draw_texture(tex_map, off)
	if Game.dest_id == "moon":
		Pix.sprite(self, tex_small["earth22"], map_c + off)
		_text_c(map_c.x + off.x, map_c.y + 40.0, "EARTH", UI.DIM)
	else:
		Fx.glow(self, map_sun + off, 48.0, Color(1.0, 0.75, 0.35, 0.35))
		Fx.sun(self, map_sun + off, 2, Color("ffd75e"), t)
	for sk: Dictionary in sky:
		var st2: Texture2D = sk["tex"]
		var sp2: Vector2 = Vector2(sk["pos"]) + off
		Pix.sprite(self, st2, sp2, Color(1, 1, 1, 0.8))
		_text_c(sp2.x, sp2.y + st2.get_height() / 2.0 + 11.0, String(sk["name"]), Color(UI.DIM, 0.7))
	for ob: Dictionary in others:
		var op: Vector2 = _body_pos(ob, day) + off
		var ot: Texture2D = ob["tex"]
		Pix.sprite(self, ot, op)
		if String(ob["name"]) != "":
			_text_c(op.x, op.y + ot.get_height() / 2.0 + 11.0, String(ob["name"]), Color(UI.DIM, 0.75))
	for b: Dictionary in bodies:
		var bp: Vector2 = _body_pos(b, day) + off
		var bt: Texture2D = b["tex"]
		Pix.sprite(self, bt, bp)
		if String(b["name"]) != "":
			_text_c(bp.x, bp.y + bt.get_height() / 2.0 + 11.0, String(b["name"]), UI.DIM)
	# the road ahead (dotted) and the road travelled (bright near the ship)
	var n: int = 220 if tr["id"] == "assist" else 110
	for i: int in n:
		var q: float = float(i) / n
		var pt: Vector2 = (_path(q) + off).floor()
		if q <= p:
			draw_rect(Rect2(pt, Vector2(1, 1)), Color(UI.CYAN, 0.25 + 0.75 * pow(q / maxf(p, 0.001), 6.0)))
		elif i % 3 == 0:
			draw_rect(Rect2(pt, Vector2(1, 1)), Color(1, 1, 1, 0.22))
	var ship: Vector2 = (_path(p) + off).floor()
	var dir: Vector2 = _path(minf(1.0, p + 0.004)) - _path(maxf(0.0, p - 0.004))
	_draw_storm(off, ship)
	var fr: int = posmod(roundi(atan2(-dir.y, dir.x) / (PI / 4.0)), 8)
	if lost:  # a dead ship tumbles slowly through its eight headings
		draw_texture_rect_region(tex_ship8, Rect2(ship - Vector2(11, 11), Vector2(23, 23)), Rect2((int(t * 2.0) % 8) * 23, 0, 23, 23), Color(0.45, 0.45, 0.55))
	else:
		if p > 0.0 and p < 1.0:
			for j: int in 4:  # engine trail twinkles along the path just flown
				var tp: Vector2 = _path(maxf(0.0, p - 0.012 * (j + 1))) + off
				Fx.sparkle(self, tp, fposmod(t * 2.0 + j * 0.25, 1.0), Color("9fe8ff"), 0)
		draw_texture_rect_region(tex_ship8, Rect2(ship - Vector2(11, 11), Vector2(23, 23)), Rect2(fr * 23, 0, 23, 23))
		if fposmod(t, 3.0) < 0.3:  # sunlight glinting off the solar panels
			Fx.sparkle(self, ship + Vector2(-3, -4), fposmod(t, 3.0) / 0.3, Color.WHITE, 0)
	if lost:
		if int(t * 4.0) % 2 == 0:
			Pix.text_oc(self, ship.x, ship.y - 16.0, "SIGNAL LOST", 10, UI.RED)
	elif flyby_age < 1.0:
		Fx.sparkle(self, ship, flyby_age, UI.YELLOW, 2)
		Fx.glow(self, ship, 16.0, Color(1.0, 0.9, 0.5, 0.5 * (1.0 - flyby_age)), true)
		Pix.text_oc(self, 320.0, 84.0, flyby_name + ": FREE SPEED FROM GRAVITY", 10, UI.YELLOW)  # clear of the crowded inner planets
	Fx.flash(self, flash_age, 0.3, Color(1.0, 0.6, 0.2, 0.5))
	_draw_cam(p, lost)
	# day counter, path name, distance and a timeline
	Pix.panel(self, Rect2(6, 6, 232, 62))
	_text(Vector2(13, 28), "DAY %s" % (("%.1f" % day) if days < 10.0 else Game.fmt(int(day))), 20, UI.TEXT)
	_text(Vector2(232.0 - Pix.text_w("of %s" % Game.fmt(days), 10), 20), "of %s" % Game.fmt(days), 10, UI.DIM)
	_text(Vector2(13, 41), String(tr["name"]), 10, UI.DIM)
	var km: float = float(Game.dest()["earth_au"]) * AU_KM * p
	var far: String = "%s km" % Game.fmt(km) if km < 1.0e6 else "%.1f million km" % (km / 1.0e6)
	_text(Vector2(13, 53), far + " from Earth", 10, UI.CYAN)
	var bx: float = 13.0
	var bw: float = 218.0
	draw_rect(Rect2(bx, 58, bw, 5), Color("05070d"))
	draw_rect(Rect2(bx + 1.0, 59, floorf((bw - 2.0) * p), 3), UI.CYAN)
	if tr["id"] == "assist":
		for fb: Array in FLYBYS:
			draw_rect(Rect2(bx + floorf(bw * float(fb[0]) / 2447.0), 57, 1, 7), UI.YELLOW)
	if storm_age >= 0.0:
		draw_rect(Rect2(bx + floorf(bw * lost_p) - 1.0, 57, 3, 7), UI.ORANGE)
	if storm_age >= 0.0 and storm_age < 4.2:
		var ev: Dictionary = Game.run["storm"]
		var sy: float = floorf(lerpf(-34.0, 6.0, clampf(storm_age / 0.25, 0.0, 1.0)))
		Pix.panel(self, Rect2(246, sy, 230, 32), UI.ORANGE if int(t * 5.0) % 2 == 0 else UI.RED)
		_text(Vector2(254, sy + 13.0), "SOLAR STORM WARNING   Kp %s" % str(ev["kp"]), 10, UI.YELLOW)
		_text(Vector2(254, sy + 26.0), "Real event %s (NASA DONKI)" % ev["time"], 10, UI.TEXT)

## The storm front: a ring of charged particles racing out from the Sun, then its effect on the ship.
func _draw_storm(off: Vector2, ship: Vector2) -> void:
	if storm_age < 0.0:
		return
	var big: bool = _storm_big()
	var r: float = storm_age * storm_speed
	var fade: float = clampf(1.0 - (r - 520.0) / 300.0, 0.0, 1.0)
	if fade > 0.0:
		var c: Vector2 = map_sun + off
		var wide: bool = Game.dest_id != "moon"
		var span: float = PI if wide else 0.42
		var n: int = 110 if wide else 46
		for i: int in n:
			var a: float = -span + 2.0 * span * (i + 0.5 * sin(i * 12.9)) / n
			var layer: int = i % 3
			var rr: float = r - layer * 9.0 - 6.0 * sin(i * 7.3)
			var pp: Vector2 = c + Vector2(cos(a) * rr, sin(a) * rr * (map_sq if wide else 1.0))
			if rr > 4.0 and pp.x > -8.0 and pp.x < 648.0 and pp.y > -8.0 and pp.y < CON_Y:
				Fx.sparkle(self, pp, fposmod(t * 1.7 + i * 0.37, 1.0) * (1.0 - 0.5 * fade), Color("ffd75e") if layer == 0 else Color("ff9f43"), (1 if big else 0) if layer == 0 else 0)
	if storm_hit >= 0.0 and storm_hit < 1.2:
		var k: float = storm_hit / 1.2
		if big and Game.id_has("shield"):
			Fx.glow(self, ship, 16.0, Color(0.3, 0.85, 1.0, 0.7 * (1.0 - k)), true)
			Fx.shockwave(self, ship + Vector2(0, 2), k, 0, UI.CYAN)
		else:
			for j: int in 5:
				Fx.sparkle(self, ship + Vector2(cos(j * 1.3 + t * 9.0), sin(j * 2.1 + t * 7.0)) * (6.0 + 10.0 * k), k, UI.RED if big else UI.YELLOW, 1 if big else 0)

func _blit(tex: Texture2D, pos: Vector2, clip: Rect2, mod: Color = Color.WHITE) -> void:
	var r: Rect2 = Rect2(pos.floor(), tex.get_size()).intersection(clip)
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_texture_rect_region(tex, r, Rect2(r.position - pos.floor(), r.size), mod)

## Close-up window: the ship with the destination growing ahead of it.
func _draw_cam(p: float, lost: bool) -> void:
	var win: Rect2 = Rect2(486, 32, 148, 92)
	draw_rect(win.grow(2.0), Color("05070d"))
	draw_rect(win.grow(1.0), UI.BORDER, false, 1.0)
	if lost:
		draw_rect(win, Color("0b0e1a"))
		for i: int in 160:  # snow
			draw_rect(Rect2(win.position + Vector2(randi() % 146, randi() % 91), Vector2(2, 1)), Color(1, 1, 1, randf_range(0.15, 0.5)))
		Pix.text_oc(self, win.get_center().x, win.get_center().y + 4.0, "NO SIGNAL", 10, UI.RED if int(t * 4.0) % 2 == 0 else Color("ff9f9f"))
		return
	draw_texture_rect_region(tex_space, win, Rect2(fposmod(t * 7.0, 480.0), 120, win.size.x, win.size.y))
	var pt: Texture2D = tex_cam[mini(tex_cam.size() - 1, int(p * tex_cam.size()))]
	_blit(pt, win.position + Vector2(112, 30) - pt.get_size() / 2.0, win)
	var sp: Vector2 = win.position + Vector2(52, 50) + Vector2(0, roundf(sin(t * 1.3) * 2.0))
	if storm_hit >= 0.0 and storm_hit < 1.6:
		var k: float = storm_hit / 1.6
		for i: int in 14:
			var sx: float = fposmod(i * 37.0 + t * 260.0, win.size.x - 8.0) + 4.0
			Fx.sparkle(self, win.position + Vector2(sx, 8.0 + fposmod(i * 23.0, win.size.y - 16.0)), k, Color("ffb84d"), 0)
		if _storm_big() and Game.id_has("shield"):
			Fx.glow(self, sp, 48.0, Color(0.3, 0.85, 1.0, 0.6 * (1.0 - k)), true)
	_blit(tex_orbiter, sp - tex_orbiter.get_size() / 2.0, win)
	_text(win.position + Vector2(4, 11), "SHIP CAM", 10, UI.DIM)
	if int(t * 1.5) % 2 == 0:
		draw_rect(Rect2(win.end.x - 9.0, win.position.y + 4.0, 5, 5), UI.RED)

# ------------------------------------------------------------- arrival

func _orbit_pt(a: float) -> Vector2:
	return orb_c + Vector2(cos(a) * orb_rx, sin(a) * orb_ry).rotated(orb_tilt)

func _aerobrake() -> bool:
	return Game.dest_id == "mars" and Game.id_has("heatshield")

func _arrive_failed() -> bool:
	return did.has("p") and _dead()

## Ship position in the arrival scene and whether it is behind the planet.
func _arrive_ship() -> Vector2:
	var a0: float = 2.25
	var p2: Vector2 = _orbit_pt(a0)
	var dir: Vector2 = (_orbit_pt(a0 - 0.05) - p2).normalized()
	if st < T_ARRIVE_P:
		var u: float = st / T_ARRIVE_P
		u = 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - 0.35 * u)  # arrives fast, slows as it brakes
		var p1: Vector2 = p2 - dir * 150.0
		return Vector2(-70, p1.y - 24.0).bezier_interpolate(p1.lerp(Vector2(-70, p1.y - 24.0), 0.5), p1, p2, u)
	if _arrive_failed():
		return p2 + (dir * 0.8 + Vector2(0.6, -0.12)).normalized() * 210.0 * (st - T_ARRIVE_P)
	return _orbit_pt(a0 - 1.2 * (st - T_ARRIVE_P))

func _step_arrive(dt: float) -> void:
	var burning: bool = st < T_ARRIVE_P and not _aerobrake()
	Audio.loop("thrust", burning, -8.0)
	if st < T_ARRIVE_P and _aerobrake() and randf() < dt * 30.0:
		_spark(_arrive_ship() + Vector2(randf_range(10, 30), randf_range(-14, 20)), Vector2(-randf_range(60, 140), randf_range(-20, 20)), 0.5, Color("ff9f43"), 0.0)
	if _once("p", T_ARRIVE_P):
		Game.phase_arrive()
		if _dead():
			Audio.play("alarm", -5.0)
			for i: int in 6:
				_puff(_arrive_ship() + Vector2(28, 6), Vector2(randf_range(10, 50), randf_range(-16, 16)), 0.9, 0, Color(0.7, 0.7, 0.8), 0.0)
		else:
			Audio.play("arrive", -3.0)
			flyby_age = 0.0
		_set_hint()
	if st > T_ARRIVE_END:
		if _dead():
			_end()
		elif not left:
			left = true
			Game.flow("probe" if Game.dest_id == "saturn" else "landing")

func _orbit_half(front: bool, done: bool) -> void:
	var n: int = 150
	for j: int in n:
		var a: float = TAU * j / n
		if (sin(a) >= 0.0) != front or (not done and j % 2 == 0):
			continue
		draw_rect(Rect2(_orbit_pt(a).floor(), Vector2(1, 1)), Color(UI.CYAN, (0.75 if front else 0.3) * (1.0 if done else 0.6)))

func _draw_big_planet(layer: int) -> void:
	var tex: Texture2D = [tex_big_back, tex_big, tex_big_front][layer]
	if tex != null:
		Pix.sprite(self, tex, orb_c)

func _draw_orbiter(pos: Vector2, flip: bool) -> void:
	var s: Vector2 = tex_orbiter.get_size()
	var tl: Vector2 = (pos - s / 2.0).floor()
	if flip:
		draw_texture_rect(tex_orbiter, Rect2(tl, Vector2(-s.x, s.y)), false)  # a negative width mirrors in place
	else:
		draw_texture(tex_orbiter, tl)

func _draw_arrive() -> void:
	var ua: float = clampf(st / T_ARRIVE_P, 0.0, 1.0)
	var scroll: float = 3.0 * st + 70.0 * T_ARRIVE_P * (1.0 - pow(1.0 - ua, 3.0)) / 3.0  # fast in, slow once caught
	Pix.tiled(self, tex_space, 0, scroll * 0.5)
	Pix.stars(self, t, Vector2(640, 298), 60, 33, Vector2(-scroll, 0))
	var failed: bool = _arrive_failed()
	var done: bool = did.has("p") and not failed
	var ship: Vector2 = _arrive_ship().floor()
	var a_now: float = 2.25 - 1.2 * (st - T_ARRIVE_P)
	var behind: bool = done and sin(a_now) < 0.0
	_draw_big_planet(0)
	_orbit_half(false, done)
	if behind:
		_draw_orbiter(ship, true)
	_draw_big_planet(1)
	_draw_big_planet(2)
	_orbit_half(true, done)
	if not behind:
		if st < T_ARRIVE_P:
			if _aerobrake():
				Fx.glow(self, ship + Vector2(30, 4), 24.0, Color(1.0, 0.55, 0.2, 0.7), true)
			else:
				Fx.flame(self, ship + Vector2(25, 6), Vector2.RIGHT, 38.0, 11.0, t)
				Fx.glow(self, ship + Vector2(40, 6), 24.0, Color(1.0, 0.7, 0.35, 0.4), true)
		_draw_orbiter(ship, true)
	_draw_parts(Vector2.ZERO)
	if done and flyby_age < 1.0:
		Fx.sparkle(self, ship, flyby_age, UI.GREEN, 2)
	Pix.panel(self, Rect2(6, 6, 250, 42))
	_text(Vector2(13, 28), Game.place(), 20, UI.TEXT)
	if failed:
		_text(Vector2(13, 42), "NO FUEL TO BRAKE: FLYING PAST", 10, UI.RED)
	elif done:
		_text(Vector2(13, 42), "IN ORBIT", 10, UI.GREEN)
	else:
		_text(Vector2(13, 42), "AEROBRAKING..." if _aerobrake() else "BRAKING BURN...", 10, UI.ORANGE)
		var dv: float = float(Game.dv_plan()["capture"])
		if dv > 0.0:
			var dv_s: String = "%.2f of %.2f km/s" % [dv * ua, dv]
			_text(Vector2(250.0 - Pix.text_w(dv_s, 10), 42), dv_s, 10, UI.YELLOW)

# ------------------------------------------------------------- home

func _draw_home() -> void:
	Pix.tiled(self, tex_space, 0, t * 2.0)
	Pix.stars(self, t, Vector2(640, 298), 60, 44)
	var moon: bool = Game.dest_id == "moon"
	var obj: Dictionary = Game.run["obj"]
	var sent: float = float(Game.run["sent"])
	var made: float = maxf(float(Game.run["data"]), 0.001)
	var e_pos: Vector2 = Vector2(540, 104) if moon else Vector2(586, 74)
	_draw_big_planet(0)
	_draw_big_planet(1)
	_draw_big_planet(2)
	if moon:
		Pix.sprite(self, tex_earth_mid, e_pos)
	else:
		Fx.glow(self, e_pos, 12.0, Color(0.4, 0.7, 1.0, 0.4), true)
		Pix.sprite(self, tex_small["earth"], e_pos)
	_text_c(e_pos.x, e_pos.y + (52.0 if moon else 20.0), "EARTH", UI.DIM)
	var ship: Vector2 = Vector2(300, 178) if moon else Vector2(318, 170)
	ship += Vector2(0, roundf(sin(t * 1.2) * 2.0))
	var dish: Vector2 = ship + Vector2(42, 2)
	if sent > 0.0:  # radio waves crawl to Earth
		for i: int in 6:
			var k: float = fposmod(st * 0.3 + i / 6.0, 1.0)
			var wp: Vector2 = dish.lerp(e_pos + Vector2(-14, 4), k).floor()
			var wf: int = mini(2, int(k * 3.0))
			draw_texture_rect_region(tex_wave, Rect2(wp - Vector2(6, 22), Vector2(12, 44)), Rect2(wf * 12, 0, 12, 44), Color(1, 1, 1, minf(1.0, 3.0 * (1.0 - k))))
	_draw_orbiter(ship, false)
	var title: String = "SENDING SCIENCE HOME"
	var sub: String = ""
	var sub_c: Color = UI.DIM
	if moon and did.has("p"):
		if obj.get("return", false):
			var p: float = clampf((st - 1.2) / 5.6, 0.0, 1.0)
			var from: Vector2 = orb_c + Vector2(70, -72)
			var pos: Vector2 = from.bezier_interpolate(Vector2(250, 40), Vector2(420, 30), e_pos + Vector2(-34, 6), p).floor()
			if p > 0.0 and p < 1.0:
				if p < 0.35:
					Fx.flame(self, pos + Vector2(-8, 0), Vector2.LEFT, 14.0, 5.0, t)
				else:
					Fx.trail(self, pos + Vector2(-8, 0), Vector2.LEFT, 32.0, 3.0, t)
				if p > 0.85:
					Fx.glow(self, pos + Vector2(8, 0), 12.0, Color(1.0, 0.6, 0.25, 0.7), true)
				Pix.sprite(self, tex_capsule, pos)
			elif p >= 1.0:
				Fx.sparkle(self, e_pos + Vector2(-30, 6), fposmod(t, 1.0), UI.GREEN, 2)
			title = "SAMPLES COMING HOME"
			sub = "%d Moon samples on board" % int(Game.run["samples"])
			sub_c = UI.GREEN
		else:
			title = "NO RIDE HOME"
			sub = "The samples stay on the Moon"
			sub_c = UI.RED
	Pix.panel(self, Rect2(6, 6, 262, 62))
	_text(Vector2(13, 28), title, 20, UI.TEXT)
	if sub != "":
		_text(Vector2(13, 42), sub, 10, sub_c)
	if not did.has("p"):
		return
	var shown_gb: float = sent * clampf((st - 0.8) / 5.0, 0.0, 1.0)
	_text(Vector2(13, 55), "DATA", 10, UI.DIM)
	Pix.gauge(self, Rect2(42, 48, 120, 8), clampf(shown_gb / made, 0.0, 1.0), UI.CYAN if sent / made >= 0.9 else UI.YELLOW)
	if sent > 0.0:
		_text(Vector2(168, 55), "%s of %s Gb" % [Game.fmt(shown_gb), Game.fmt(made)], 10, UI.TEXT)
	else:
		_text(Vector2(168, 55), "NOTHING SENT", 10, UI.RED)
	if moon and obj.get("return", false):
		for i: int in mini(8, int(Game.run["samples"])):
			draw_texture(tex_sample, Vector2(180 + i * 11, 30))

# ------------------------------------------------------------- shared drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	match stage:
		"launch":
			_draw_launch()
		"cruise":
			_draw_cruise()
		"arrive":
			_draw_arrive()
		"home":
			_draw_home()
	if st < 0.32 and t > st + 0.01:  # not on the first phase: main.gd fades the screen in itself
		draw_rect(Rect2(0, 0, 640, CON_Y), Color(0, 0, 0, 1.0 - floorf(st / 0.08) * 0.25))
	_draw_console()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(self, p, s, size, c)

func _text_c(cx: float, y: float, s: String, c: Color) -> void:
	Pix.text_c(self, cx, y, s, 10, c)

## 30 px display text, centred (countdown digits, the failure stamp).
func _big(cx: float, y: float, s: String, c: Color) -> void:
	var f: FontFile = Pix.font()
	var p: Vector2 = Vector2(floorf(cx - f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x / 2.0), y)
	draw_string(f, p + Vector2(3, 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.8))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)

func _lamp(center: Vector2, state: int) -> void:
	draw_texture_rect_region(tex_lamp, Rect2(center - Vector2(5, 5), Vector2(11, 11)), Rect2(state * 11, 0, 11, 11))

func _gauge(y: float, label: String, frac: float, value: String) -> void:
	_text(Vector2(8, y + 8.0), label, 10, UI.DIM)
	var col: Color = UI.GREEN if frac > 0.35 else (UI.YELLOW if frac > 0.15 else UI.RED)
	Pix.gauge(self, Rect2(34, y, 80, 8), frac, col)
	_text(Vector2(118, y + 8.0), value, 10, UI.TEXT)

## Mission-control console: phase lamps, fuel and battery gauges, hint line and the log ticker.
func _draw_console() -> void:
	draw_texture(tex_console, Vector2(0, CON_Y))
	var r: Dictionary = Game.run
	var cur: int = {"launch": 0, "cruise": 1, "arrive": 2, "home": 4}[stage]
	var names: Array[String] = ["LIFT", "CRUISE", "ORBIT", "RINGS" if Game.dest_id == "saturn" else "LAND", "HOME"]
	for i: int in 5:
		var state: int = 0
		if i < cur:
			state = 1
			if i == 3 and int(r["samples"]) == 0 and not bool(r["obj"].get("land", false)):
				state = 3
		elif i == cur:
			state = 3 if _dead() else (2 if int(t * 3.0) % 2 == 0 else 0)
		var cx: float = 24.0 + i * 35.0
		_lamp(Vector2(cx, CON_Y + 14.0), state)
		_text_c(cx, CON_Y + 31.0, names[i], UI.TEXT if i == cur else UI.DIM)
	var prop0: float = maxf(1.0, float(r["calc"]["prop"]))
	_gauge(CON_Y + 36.0, "FUEL", float(r["prop"]) / prop0, "%s kg" % Game.fmt(r["prop"]))
	var bat: float = float(r["battery"]) / maxf(1.0, float(r["wh"]))
	_gauge(CON_Y + 47.0, "BATT", bat, "%d%%" % roundi(bat * 100.0) if float(r["wh"]) > 0.0 else "none")
	# ticker: the hint, then the last three log lines with the newest entry typed out and lit
	_text(Vector2(192, CON_Y + 17.0), hint, 10, UI.YELLOW)
	var first: int = maxi(0, lines.size() - 3)
	var typed: int = int(new_t * 140.0)
	for i: int in range(first, lines.size()):
		var ln: Dictionary = lines[i]
		var y: float = CON_Y + 28.0 + (i - first) * 11.0
		var newest: bool = int(ln["e"]) == shown - 1
		var s: String = String(ln["s"])
		if newest:
			s = s.substr(0, maxi(0, typed))
			typed -= String(ln["s"]).length()
		var ok: bool = ln["ok"]
		if i == 0 or int(lines[i - 1]["e"]) != int(ln["e"]):
			draw_rect(Rect2(192, y - 6.0, 4, 4), (UI.GREEN if ok else UI.RED) if newest else UI.BORDER)
		_text(Vector2(200, y), s, 10, (UI.TEXT if ok else UI.RED) if newest else UI.DIM)
	# key hint: the same framed key cap strip as the landing, surface and drone screens
	var kl: String = "4x SPEED" if fast else "SPEED UP"
	var kw: float = Pix.text_w("SPACE", 10) + 7.0 + 4.0 + Pix.text_w(kl, 10) + 12.0
	Pix.panel(self, Rect2(634.0 - kw, 6, kw, 20))
	Pix.key_hint(self, Vector2(640.0 - kw, 10.0 if fast else 9.0), "SPACE", kl, UI.YELLOW if fast else UI.TEXT)

# ------------------------------------------------------------- debug hooks for screenshots (tools/dev/shot.sh call=...)

func _warp(to_stage: String, to_st: float) -> void:
	var guard: int = 0
	while (stage != to_stage or st < to_st) and guard < 4000 and is_inside_tree():
		_step(1.0 / 30.0)
		guard += 1

func debug_freeze() -> void:
	frozen = true

## The widest launcher the ship kit may hand over (60 x 200), to check that tower, clamps and flame follow it.
func debug_big_rocket() -> void:
	var im: Image = tex_rocket.get_image()
	im.resize(60, 200, Image.INTERPOLATE_NEAREST)
	tex_rocket = ImageTexture.create_from_image(im)
	_set_nozzles("")

## Each real launcher sprite from the ship kit on the pad (Game.rocket_id only changes the name shown).
func _debug_lv(id: String) -> void:
	Game.rocket_id = id
	tex_rocket = ShipKit.launcher(id)
	_set_nozzles(id)

func debug_lv_electron() -> void:
	_debug_lv("electron")

func debug_lv_falcon9() -> void:
	_debug_lv("falcon9")

func debug_lv_vulcan() -> void:
	_debug_lv("vulcan")

func debug_lv_heavy() -> void:
	_debug_lv("heavy")

func debug_countdown() -> void:
	_warp("launch", 1.3)

func debug_ignition() -> void:
	_warp("launch", T_IGN + 0.45)

func debug_liftoff() -> void:
	_warp("launch", T_LIFT + 1.5)

func debug_climb() -> void:
	_warp("launch", T_LIFT + 3.3)

func debug_sep() -> void:
	_warp("launch", T_SEP + 0.5)

func debug_launch_fail() -> void:
	Game.run["calc"]["mass"] = float(Game.run["calc"]["cap"]) * 2.0
	_warp("launch", T_BOOM + 0.25)

func debug_cruise() -> void:
	_warp("cruise", 1.6)

func debug_flyby() -> void:
	_warp("cruise", 2.2)

func debug_storm() -> void:
	_warp("cruise", T_CRUISE_P + 0.9)

func debug_cruise_late() -> void:
	_warp("cruise", 6.5)

func debug_cruise_lost() -> void:
	Game.run["calc"]["draw_cruise"] = 99999.0
	_warp("cruise", T_CRUISE_P + 1.0)

func debug_arrive() -> void:
	_warp("arrive", 1.7)

func debug_orbit() -> void:
	_warp("arrive", T_ARRIVE_P + 1.0)

func debug_orbit_behind() -> void:
	_warp("arrive", T_ARRIVE_P + 2.4)

func debug_arrive_fail() -> void:
	_warp("arrive", 0.1)
	Game.run["prop"] = 0.0
	_warp("arrive", T_ARRIVE_P + 0.7)

func debug_home() -> void:
	if stage != "home":
		_set_stage("home")
	if Game.dest_id == "moon":
		Game.run["samples"] = 3
		Game.run["obj"]["land"] = true
	Game.run["data"] = maxf(float(Game.run["data"]), 12.0)
	_warp("home", 3.6)
