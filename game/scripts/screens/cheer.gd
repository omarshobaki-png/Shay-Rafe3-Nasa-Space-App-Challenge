extends Control
## v6 discovery cutscene, between the site and the report (about 8.6 s, SPACE / Enter / click skips after 1 s).
## main.gd has already called Game.phase_home() and Game.finish(): this screen only presents.
##   Beat 1 (0 - 2.2 s): the haul leaves. Ring worlds: the drone docks with the player's own ship (ShipKit).
##     Land worlds: the data beam leaves the lander for Earth, or the capsule lifts off (sample or crew return).
##   Beat 2: the celebration. Robotic tasks: the science team at mission control on Earth watching the live
##     feed (nobody is on board a robotic ship). Crew tasks: the two astronauts in their capsule, split screen
##     with mission control. Short of the goal: a smaller celebration (clapping) and "PARTIAL RESULT".
## Art: res://art/cheer/ and audio/cheer.wav, both from tools/art/gen_cheer.py.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")

const BEAT1: float = 2.2
const LENGTH: float = 8.6
const SKIP_AFTER: float = 1.0
const CW: int = 20
const CH: int = 36
const SCREEN: Rect2 = Rect2(172, 22, 296, 126)   # inner wall screen in room.png
const BACK_MONS: Array[int] = [22, 102, 182, 262, 352, 432, 512, 592]   # same as gen_cheer.py
const BACK_FEET: float = 236.0
const MID_FEET: float = 302.0
const DESK_BACK_Y: float = 198.0
const DESK_FRONT_Y: float = 266.0
const ASTRONAUTS: Array[int] = [12, 13]   # rows of people.png
const CONFETTI: Array[Color] = [Color("ffd75e"), Color("4fd6ff"), Color("ff7ad9"), Color("6dff8a"), Color("ff9f43"), Color("f4f6fb")]
## One true headline per destination, and what the haul will help scientists study (never a claimed discovery).
const HEADLINE: Dictionary = {
	"moon": ["WATER ICE CONFIRMED IN DARK POLAR CRATERS (LCROSS, 2009)", "where the Moon's water came from"],
	"mercury": ["MESSENGER FOUND WATER ICE IN MERCURY'S SHADOWED CRATERS (2012)", "how the planet nearest the Sun formed"],
	"venus": ["VENERA 13 SENT THE FIRST COLOUR PICTURES FROM VENUS (1982)", "why Venus became so hot"],
	"mars": ["CURIOSITY FOUND AN ANCIENT LAKE BED IN GALE CRATER (2013)", "whether Mars was ever home to life"],
	"jupiter": ["VOYAGER 1 DISCOVERED JUPITER'S FAINT RINGS (1979)", "how dust from small moons makes the rings"],
	"saturn": ["CASSINI DIVED 22 TIMES BETWEEN SATURN AND ITS RINGS (2017)", "how old the rings are"],
	"uranus": ["URANUS HAS 13 KNOWN RINGS, THE FIRST FOUND IN 1977", "what makes the rings so dark"],
	"neptune": ["VOYAGER 2 PHOTOGRAPHED NEPTUNE'S RING ARCS (1989)", "why the ring arcs stay clumped"],
}
const CREW_TOPIC: Dictionary = {"moon": "moonquakes, dust and the Moon's water", "mars": "the ground future crews will live on"}

var t: float = 0.0
var done: bool = false
var skin: String = "moon"
var ring: bool = false
var job: String = "drill"
var crew: bool = false
var lift: bool = false      # a capsule (samples or crew) lifts off instead of a data beam
var got: int = 0
var goal: int = 1
var full: bool = true
var noun: String = "SAMPLES"
var head: String = ""
var sub: String = ""
var counted: int = 0
var cheered: bool = false
var docked: bool = false
var lifted: bool = false

var tex_room: Texture2D = null
var tex_desk_b: Texture2D = null
var tex_desk_f: Texture2D = null
var tex_people: Texture2D = null
var tex_capsule: Texture2D = null
var tex_find: Texture2D = null
var tex_photo: Texture2D = null
var tex_space: Texture2D = null
var tex_lander: Texture2D = null
var tex_cap: Texture2D = null
var tex_earth: Texture2D = null
var tex_planet: Texture2D = null
var tex_big: Array[Texture2D] = []
var tex_sky: Texture2D = null
var tex_far: Texture2D = null
var tex_near: Texture2D = null
var tex_floor: Texture2D = null
var tex_drone: Texture2D = null
var drone_slot: Vector2 = Vector2.ZERO
var build_nodrone: Dictionary = {}

var people: Array[Dictionary] = []
var confetti: Array[Dictionary] = []
var papers: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _job() -> String:
	return String(Game.run.get("job", Game.task().get("job", "drill")))

func _ready() -> void:
	rng.seed = 2026
	var d: Dictionary = Game.dest()
	skin = String(d.get("skin", Game.dest_id))
	ring = String(d.get("kind", "land")) == "ring"
	job = _job()
	crew = job == "crew" and not ring
	var obj: Dictionary = Game.run.get("obj", {})
	lift = not ring and (crew or bool(obj.get("return", false)))
	got = int(Game.run.get("samples", 0))
	goal = maxi(1, int(d.get("samples_goal", 1)))
	full = got >= goal
	if job == "photo":
		noun = "PHOTOS"
	elif crew:
		noun = "STATIONS"
	else:
		noun = "GRAINS" if ring else "SAMPLES"
	var hl: Array = HEADLINE.get(Game.dest_id, HEADLINE["moon"])
	head = String(hl[0])
	var topic: String = String(CREW_TOPIC.get(Game.dest_id, hl[1])) if crew else String(hl[1])
	sub = "Your %s will help scientists study %s." % [noun.to_lower(), topic]
	_load()
	_cast()

func _tex(name: String) -> Texture2D:
	return Pix.img(name) if ResourceLoader.exists("res://art/%s.png" % name) else null

func _load() -> void:
	tex_room = _tex("cheer/room")
	tex_desk_b = _tex("cheer/desk_back")
	tex_desk_f = _tex("cheer/desk_front")
	tex_people = _tex("cheer/people")
	tex_capsule = _tex("cheer/capsule")
	tex_space = _tex("bg_space")
	tex_earth = _tex("planet_earth_22")
	tex_planet = Pix.planet(22, skin)
	if ring:
		for n: String in ["big_%s_back", "big_%s", "big_%s_front"]:
			var bt: Texture2D = _tex("flight/" + n % skin)
			if bt != null:
				tex_big.append(bt)
		var crystal: String = "probe/crystal" if skin == "saturn" else "probe/%s_crystal" % skin
		tex_find = _tex(crystal)
		if tex_find == null:
			tex_find = _tex("probe/crystal")
		tex_photo = _tex("flight/big_" + skin)
		# the player's own ship, with its drone drawn on its own so it can fly in and dock
		build_nodrone = Game.build.duplicate()
		for it: Dictionary in ShipKit.layout(Game.build):
			if String(it["id"]) == "drone" and it["tex"] != null:
				tex_drone = it["tex"]
				drone_slot = it["pos"]
		build_nodrone.erase("drone")
		if tex_drone == null:
			tex_drone = _tex("drone")
	else:
		tex_lander = _tex("lander")
		tex_cap = _tex("flight/capsule")
		tex_find = _tex("cheer/find_" + skin)
		tex_far = _tex(skin + "_range_far")
		tex_near = _tex(skin + "_range_near")
		tex_floor = _tex("ground_" + skin)
		if tex_floor == null:
			tex_floor = _tex("floor_" + skin)
		tex_sky = _tex("mars_sky_day") if skin == "mars" else null
		tex_photo = tex_far

## Who stands where and how they celebrate.
func _cast() -> void:
	var row: int = 0
	var roles: Array[String] = ["jump", "clap", "pump", "jump", "clap", "jump", "pump"]
	# back row: between the monitors, upper body over the desk
	for i: int in BACK_MONS.size() - 1:
		var x0: float = BACK_MONS[i] + 26.0
		var x1: float = BACK_MONS[i + 1] - 2.0
		var n: int = 2 if x1 - x0 < 70.0 else 3
		for k: int in n:
			_add(floorf(x0 + (x1 - x0) * (k + 0.5) / n), BACK_FEET, row % 12, roles[(row * 3) % roles.size()], true)
			row += 1
	# middle row: behind the front desk, between its monitors (gen_cheer.py FRONT_MONS); one pair hugging
	var mids: Array[float] = [24.0, 112.0, 122.0, 160.0, 192.0, 270.0, 302.0, 336.0, 372.0, 462.0, 496.0, 506.0, 540.0, 618.0]
	var mroles: Array[String] = ["pump", "hug", "hug2", "jump", "clap", "jump", "pump", "jump", "clap", "jump", "hug", "hug2", "pump", "jump"]
	for i: int in mids.size():
		_add(mids[i], MID_FEET, (row + i * 5) % 12, mroles[i], false)
		if mroles[i] == "hug2":   # a hugging pair moves together
			people[-1]["off"] = people[-2]["off"]
			people[-1]["rate"] = people[-2]["rate"]
	if crew:
		_add(150.0, 0.0, ASTRONAUTS[0], "astro_a", false)
		_add(162.0, 0.0, ASTRONAUTS[1], "astro_b", false)

func _add(x: float, feet: float, v: int, role: String, back: bool) -> void:
	if not full and not role.begins_with("astro"):
		role = "clap" if rng.randf() < 0.75 else "idle"
	people.append({"x": x, "feet": feet, "v": v, "role": role, "back": back,
		"off": BEAT1 + 0.55 + (x / 640.0) * 0.35 + rng.randf() * 0.25, "rate": rng.randf_range(0.85, 1.2),
		"h": rng.randf_range(2.0, 4.0), "threw": false})

func _process(delta: float) -> void:
	t += delta
	var u: float = t - BEAT1
	# beat 1 sounds
	if ring and not docked and t >= 1.35:
		docked = true
		Audio.play("dock")
		for i: int in 3:
			sparks.append({"p": _ship_pos() + drone_slot + Vector2(10 + i * 6, 6 - i * 3), "age": -0.1 * i})
	if lift and not lifted and t >= 0.3:
		lifted = true
		Audio.play("ignition", -4.0)
	if not ring and not lift and not lifted and t >= 0.3:
		lifted = true
		Audio.play("radio_blip")
	# beat 2: the count rolls up, then the room erupts
	if u >= 0.0:
		var c: int = mini(got, int(u / 0.12) + 1)
		if c > counted:
			counted = c
			Audio.play("blip", -4.0, 1.0 + 0.06 * c)
		if not cheered and u >= 0.6:
			cheered = true
			Audio.play("cheer", 0.0 if full else -9.0)
			if full:
				Audio.play("success", -3.0)
				_burst()
	_tick_bits(delta)
	if t >= LENGTH:
		_finish()
	queue_redraw()

func _finish() -> void:
	if done:
		return
	done = true
	Game.goto("report")

func _input(event: InputEvent) -> void:
	if t < SKIP_AFTER or done:
		return
	var k: InputEventKey = event as InputEventKey
	var m: InputEventMouseButton = event as InputEventMouseButton
	if (k != null and k.pressed and not k.echo and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (m != null and m.pressed):
		get_viewport().set_input_as_handled()
		_finish()

# ---------------------------------------------------------------- particles

func _burst() -> void:
	for side: int in [-1, 1]:   # two confetti cannons beside the wall screen, and a rain from the ceiling
		var o: Vector2 = Vector2(320 + side * 160, 30)
		for i: int in 60:
			var a: float = deg_to_rad(-90.0 + side * rng.randf_range(10.0, 70.0))
			confetti.append({"p": o, "v": Vector2(cos(a), sin(a)) * rng.randf_range(60.0, 170.0),
				"c": CONFETTI[i % CONFETTI.size()], "ph": rng.randf() * 6.0})
	for i: int in 70:
		confetti.append({"p": Vector2(rng.randf() * 640.0, -rng.randf() * 120.0), "v": Vector2(rng.randf_range(-10, 10), rng.randf_range(15, 35)),
			"c": CONFETTI[i % CONFETTI.size()], "ph": rng.randf() * 6.0})
	for i: int in 6:
		sparks.append({"p": Vector2(SCREEN.position.x + rng.randf() * SCREEN.size.x, SCREEN.position.y + rng.randf() * SCREEN.size.y), "age": -0.15 * i})

func _tick_bits(delta: float) -> void:
	for c: Dictionary in confetti:
		var v: Vector2 = c["v"]
		v.y = minf(v.y + 90.0 * delta, 28.0)          # paper flutters down at a slow terminal speed
		v.x = lerpf(v.x, 8.0 * sin(t * 3.0 + float(c["ph"])), delta * 2.0)
		c["v"] = v
		c["p"] = Vector2(c["p"]) + v * delta
	for p: Dictionary in papers:
		var v: Vector2 = p["v"]
		v.y = minf(v.y + 120.0 * delta, 22.0)
		v.x = lerpf(v.x, 14.0 * sin(t * 2.2 + float(p["ph"])), delta * 1.5)
		p["v"] = v
		p["p"] = Vector2(p["p"]) + v * delta
	for s: Dictionary in sparks:
		s["age"] = float(s["age"]) + delta * 1.6
	sparks = sparks.filter(func(s: Dictionary) -> bool: return float(s["age"]) < 1.0)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	if t < BEAT1:
		if ring:
			_draw_dock()
		else:
			_draw_site()
	else:
		if crew:
			_draw_room(160.0)
			_draw_cabin()
			draw_rect(Rect2(318, 0, 4, 360), Color("1e2232"))
			draw_rect(Rect2(319, 0, 1, 360), Color("454d66"))
			_tag(Vector2(8, 298), "CREW CABIN")
			_tag(Vector2(330, 298), "MISSION CONTROL")
		else:
			_draw_room(0.0)
			_tag(Vector2(8, 298), "SCIENCE TEAM, MISSION CONTROL")
		for p: Dictionary in papers:
			_paper(p)
		for c: Dictionary in confetti:
			_confetti(c)
		for s: Dictionary in sparks:
			if float(s["age"]) >= 0.0:
				Fx.sparkle(self, Vector2(s["p"]).floor(), float(s["age"]), Color("fff6c0"), 1)
		_lower_third()
		Fx.flash(self, t - BEAT1, 0.25)
	if t >= SKIP_AFTER:
		Pix.key_hint(self, Vector2(574, 8), "SPACE", "SKIP", UI.DIM)

func _tag(p: Vector2, s: String) -> void:
	Pix.panel(self, Rect2(p, Vector2(Pix.text_w(s, 10) + 12, 17)))
	Pix.text(self, p + Vector2(6, 12), s, 10, UI.CYAN)

func _caption(s: String, small: String) -> void:
	Pix.text_oc(self, 320, 40, s, 20, UI.YELLOW)
	if small != "":
		Pix.text_oc(self, 320, 58, small, 10, UI.TEXT)

func _ship_pos() -> Vector2:
	return Vector2(300, 130)

## Beat 1, ring worlds: the drone flies in and docks with the player's ship above the planet.
func _draw_dock() -> void:
	if tex_space != null:
		draw_texture(tex_space, Vector2.ZERO)
	Pix.stars(self, t, Vector2(640, 360), 70, 11)
	for bt: Texture2D in tex_big:
		Pix.sprite(self, bt, Vector2(470, 330))
	var o: Vector2 = _ship_pos()
	ShipKit.draw(self, o, build_nodrone)
	if tex_drone != null:
		var k: float = clampf(t / 1.35, 0.0, 1.0)
		var e: float = smoothstep(0.0, 1.0, k)   # glides in and brakes, visible after the fade-in
		var at: Vector2 = Vector2(700, 300).lerp(o + drone_slot, e).floor()
		if k < 1.0:
			Fx.trail(self, at + Vector2(tex_drone.get_width(), floorf(tex_drone.get_height() / 2.0)), Vector2.RIGHT, 40.0 * (1.0 - e) + 8.0, 3, t)
		draw_texture(tex_drone, at)
	for s: Dictionary in sparks:
		if float(s["age"]) >= 0.0:
			Fx.sparkle(self, Vector2(s["p"]).floor(), float(s["age"]), Color("9fe8ff"), 1)
	if docked:
		_caption("DRONE DOCKED", "%d %s SAFE ON BOARD. THE DATA GOES TO EARTH BY RADIO." % [got, noun])
	else:
		_caption("DRONE COMING HOME", "")

## Beat 1, land worlds: the lander on the ground, the data beam leaves for Earth or the capsule lifts off.
func _draw_site() -> void:
	if tex_sky != null:
		draw_texture(tex_sky, Vector2.ZERO)
	elif skin == "venus":
		for i: int in 65:   # thick yellow cloud sky
			draw_rect(Rect2(0, i * 4, 640, 4), Color("6e4a24").lerp(Color("d8b070"), i / 64.0))
	else:
		Pix.stars(self, t, Vector2(640, 200), 80, 5)
	var earth: Vector2 = Vector2(520, 70)
	if skin == "moon" and tex_earth != null:
		Pix.sprite(self, tex_earth, earth)
	elif skin != "venus":
		draw_rect(Rect2(earth - Vector2(1, 1), Vector2(3, 3)), Color("bcd8ff"))
		Pix.text_o(self, earth + Vector2(6, 4), "EARTH", 10, UI.DIM)
	if tex_far != null:
		draw_texture(tex_far, Vector2(0, 110))
	if tex_near != null:
		draw_texture(tex_near, Vector2(0, 196))
	if tex_floor != null:
		for y: float in [270.0, 270.0 + tex_floor.get_height()]:
			Pix.tiled(self, tex_floor, y, 0.0)
	var base: Vector2 = Vector2(260, 306)
	var lh: float = 60.0
	if tex_lander != null:
		lh = tex_lander.get_height()
		draw_texture(tex_lander, (base - Vector2(tex_lander.get_width() / 2.0, lh)).floor())
	var top: Vector2 = base - Vector2(0, lh)
	if lift:
		var u: float = maxf(t - 0.3, 0.0)
		var cap: Vector2 = (top + Vector2(0, 8) - Vector2(0, 30.0 * u * u + 18.0 * u)).floor()
		if u > 0.0:
			Fx.glow(self, cap + Vector2(0, 10), 6, Color(1.0, 0.75, 0.4, 0.5), true)
			Fx.flame(self, cap + Vector2(0, 9), Vector2.DOWN, 12.0 + 8.0 * minf(u, 1.0), 5, t)
		if tex_cap != null:   # the sprite points left: a quarter turn puts its nose up
			draw_set_transform(cap, PI / 2.0)
			draw_texture(tex_cap, -(tex_cap.get_size() / 2.0).floor())
			draw_set_transform(Vector2.ZERO)
		_caption("CREW LIFTS OFF FOR HOME" if crew else "SAMPLES LIFT OFF FOR EARTH", "%d %s DONE. NEXT STOP: EARTH." % [got, noun] if crew else "%d %s ON BOARD." % [got, noun])
	else:
		var dish: Vector2 = top + Vector2(0, 4)
		var to: Vector2 = earth if skin != "venus" else Vector2(560, -10)
		var n: int = int(dish.distance_to(to) / 4.0)
		for i: int in n:   # a faint dotted path, the packets run along it
			if i % 2 == 0:
				draw_rect(Rect2(dish.lerp(to, float(i) / n).floor(), Vector2(1, 1)), Color(0.45, 0.85, 1.0, 0.35))
		Fx.glow(self, dish, 8, Color(0.4, 0.9, 1.0, 0.45), true)
		for i: int in 6:
			var s: float = fmod(t * 0.8 + i / 6.0, 1.0)
			Fx.sparkle(self, dish.lerp(to, s).floor(), fmod(t * 2.5 + i * 0.37, 1.0), UI.CYAN, 0)
		_caption("DATA ON ITS WAY TO EARTH", "%d %s. RADIO DELAY: %s." % [got, noun, String(Game.dest()["light_delay"]).to_upper()])

## Beat 2: mission control, shifted right by `dx` in split screen.
func _draw_room(dx: float) -> void:
	var o: Vector2 = Vector2(dx, 0)
	if tex_room != null:
		draw_texture(tex_room, o)
	_draw_wall_screen(o + SCREEN.position)
	_clocks(o)
	for p: Dictionary in people:
		if bool(p["back"]):
			_person(p, o, Color(0.74, 0.8, 0.95))
	if tex_desk_b != null:
		draw_texture(tex_desk_b, o + Vector2(0, DESK_BACK_Y))
	for p: Dictionary in people:
		if not bool(p["back"]) and not String(p["role"]).begins_with("astro"):
			_person(p, o, Color.WHITE)
	if tex_desk_f != null:
		draw_texture(tex_desk_f, o + Vector2(0, DESK_FRONT_Y))

## The real time in UTC on the left plate, the mission day on the right.
func _clocks(o: Vector2) -> void:
	var now: Dictionary = Time.get_time_dict_from_system(true)
	Pix.text_c(self, o.x + 87, o.y + 28, "%02d:%02d:%02d" % [int(now["hour"]), int(now["minute"]), int(now["second"])], 10, Color("ff9f43"))
	var c: Dictionary = Game.run.get("calc", {})
	var day: int = int(float(c.get("days", 0.0)) + float(Game.run.get("days_extra", 0.0)))
	Pix.text_c(self, o.x + 553, o.y + 28, "DAY %d" % day, 10, Color("6dff8a"))

## The wall screen: live feed header, the find (photo, rock, ice grains or station readings) and the count.
func _draw_wall_screen(p: Vector2) -> void:
	var u: float = t - BEAT1
	draw_rect(Rect2(p, Vector2(SCREEN.size.x, 12)), Color("0a2236"))
	if int(t * 2.0) % 2 == 0:
		draw_rect(Rect2(p + Vector2(5, 4), Vector2(4, 4)), UI.RED)
	Pix.text(self, p + Vector2(13, 10), "LIVE FROM " + Game.place(), 10, UI.TEXT)
	var dl: String = "DELAY " + String(Game.dest()["light_delay"])
	Pix.text(self, p + Vector2(SCREEN.size.x - 4 - Pix.text_w(dl, 10), 10), dl, 10, UI.DIM)
	# the find, in a framed box on the left
	var box: Rect2 = Rect2(p + Vector2(8, 18), Vector2(124, 98))
	draw_rect(box, Color("061626"))
	if job == "photo" and tex_photo != null:
		var ts: Vector2 = tex_photo.get_size()
		var src: Rect2 = Rect2(((ts - box.size) / 2.0).floor() + Vector2(0, 0 if ring else 14), box.size).intersection(Rect2(Vector2.ZERO, ts))
		draw_texture_rect_region(tex_photo, Rect2(box.position + ((box.size - src.size) / 2.0).floor(), src.size), src)
		for c: Vector2 in [Vector2(3, 3), Vector2(box.size.x - 9, 3), Vector2(3, box.size.y - 9), Vector2(box.size.x - 9, box.size.y - 9)]:
			var right: bool = c.x > 50.0
			var low: bool = c.y > 50.0
			draw_rect(Rect2(box.position + c + Vector2(0, 5 if low else 0), Vector2(6, 1)), UI.TEXT)
			draw_rect(Rect2(box.position + c + Vector2(5 if right else 0, 0), Vector2(1, 6)), UI.TEXT)
		Pix.text_o(self, box.position + Vector2(5, box.size.y - 5), "IMG %03d" % maxi(1, counted), 10, UI.YELLOW)
	elif crew:
		for i: int in 3:
			var r: Rect2 = Rect2(box.position + Vector2(4, 4 + i * 31), Vector2(116, 28))
			draw_rect(r, Color("0a1e30"))
			var on: bool = i < counted
			Pix.text(self, r.position + Vector2(3, 10), "STATION %d %s" % [i + 1, "ONLINE" if on else "..."], 10, UI.GREEN if on else UI.DIM)
			if on:
				for x: int in 108:   # live trace
					var y: float = 20.0 + 4.0 * sin(x * 0.5 + t * 8.0 + i) * sin(x * 0.07 + t * 1.3 + i * 2.0)
					draw_rect(Rect2(r.position + Vector2(4 + x, floorf(y)), Vector2(1, 1)), UI.GREEN)
	else:
		for gx: int in range(0, int(box.size.x), 16):
			draw_rect(Rect2(box.position + Vector2(gx, 0), Vector2(1, box.size.y)), Color("0c2438"))
		if tex_find != null:
			Pix.sprite(self, tex_find, box.get_center() + Vector2(0, 4 + roundf(sin(t * 2.0))))
		Pix.text(self, box.position + Vector2(5, 12), "%s %d" % ["GRAIN" if ring else "SAMPLE", maxi(1, counted)], 10, UI.YELLOW)
	draw_rect(Rect2(box.position - Vector2(1, 1), Vector2(box.size.x + 2, 1)), Color("39a0c8"))
	draw_rect(Rect2(box.position + Vector2(-1, box.size.y), Vector2(box.size.x + 2, 1)), Color("1d5a80"))
	# the count
	var cx: float = p.x + 214
	var col: Color = UI.GOOD if full else UI.RISK
	Pix.title_c(self, cx, p.y + 58, "%d/%d" % [counted, goal], col, 3)
	Pix.text_c(self, cx, p.y + 78, noun, 20, UI.TEXT)
	if u >= 0.6 and (full or int(t * 3.0) % 3 != 0):
		var tag: String = "GOAL MET" if full else "PARTIAL RESULT"
		var w: float = Pix.text_w(tag, 10) + 10.0
		draw_rect(Rect2(Vector2(floorf(cx - w / 2.0), p.y + 92), Vector2(w, 14)), Color("04260f") if full else Color("3a1c04"))
		Pix.text_c(self, cx, p.y + 103, tag, 10, col)

## One person: watching, then anticipation (crouch), then their own way of celebrating, out of step with the rest.
func _person(p: Dictionary, o: Vector2, mod: Color) -> void:
	var u: float = t - float(p["off"])
	var f: int = 0
	var lift_px: float = 0.0
	var sway: float = 0.0
	var flip: bool = false
	var role: String = p["role"]
	if u >= 0.0:
		if u < 0.14 and role != "idle":
			f = 1                     # anticipation
		else:
			var w: float = (u - 0.14) * float(p["rate"])
			match role:
				"jump":
					var cyc: float = fmod(w, 1.1)
					if cyc < 0.42:
						f = 2
						var s: float = cyc / 0.42
						lift_px = float(p["h"]) * 4.0 * s * (1.0 - s)
						if not bool(p["threw"]) and int(p["v"]) % 3 == 0:
							p["threw"] = true
							_throw(o + Vector2(float(p["x"]), float(p["feet"]) - 34.0))
					elif cyc < 0.52:
						f = 1
					else:
						f = 3
				"clap":
					f = 4 if int(w / 0.11) % 2 == 0 else 5
					lift_px = 1.0 if full and int(w / 0.22) % 2 == 0 else 0.0
				"pump":
					f = 6 if int(w / 0.22) % 2 == 0 else 3
					lift_px = 1.0 if f == 6 else 0.0
				"hug", "hug2":
					f = 7
					flip = role == "hug2"
					sway = roundf(sin(w * 5.0))
					lift_px = 1.0 if int(w / 0.3) % 2 == 0 else 0.0
				"idle":
					f = 0 if int(w / 0.5) % 2 == 0 else 5
	var pos: Vector2 = (o + Vector2(float(p["x"]) - CW / 2.0 + sway, float(p["feet"]) - CH - lift_px)).floor()
	if lift_px >= 2.0 and not bool(p["back"]):   # the shadow stays on the floor while they are airborne
		draw_rect(Rect2((o + Vector2(float(p["x"]) - 4.0, float(p["feet"]) - 1.0)).floor(), Vector2(9, 1)), Color(0, 0, 0, 0.35))
	_sprite(int(p["v"]), f, pos, flip, mod)

func _sprite(v: int, f: int, pos: Vector2, flip: bool, mod: Color) -> void:
	if tex_people == null:
		return
	var src: Rect2 = Rect2(f * CW, v * CH, CW, CH)
	if flip:
		draw_texture_rect_region(tex_people, Rect2(pos + Vector2(CW, 0), Vector2(-CW, CH)), src, mod)
	else:
		draw_texture_rect_region(tex_people, Rect2(pos, Vector2(CW, CH)), src, mod)

func _throw(at: Vector2) -> void:
	for i: int in 3:
		papers.append({"p": at + Vector2(rng.randf_range(-4, 4), 0), "v": Vector2(rng.randf_range(-40, 40), rng.randf_range(-110, -70)), "ph": rng.randf() * 6.0})

func _paper(p: Dictionary) -> void:
	var q: Vector2 = Vector2(p["p"]).floor()
	var k: int = int(t * 6.0 + float(p["ph"])) % 3   # tumbling: face, edge, side
	var sz: Vector2 = [Vector2(5, 4), Vector2(5, 1), Vector2(3, 5)][k]
	draw_rect(Rect2(q, sz), Color("f4f6fb"))
	if k != 1:
		draw_rect(Rect2(q + Vector2(0, sz.y - 1), Vector2(sz.x, 1)), Color("8a92aa"))
		draw_rect(Rect2(q + Vector2(1, 1), Vector2(sz.x - 2, 1)), Color("a3abc4"))

func _confetti(c: Dictionary) -> void:
	var q: Vector2 = Vector2(c["p"]).floor()
	if q.y > 360.0:
		return
	var k: int = int(t * 8.0 + float(c["ph"])) % 3
	var col: Color = c["c"]
	draw_rect(Rect2(q, [Vector2(2, 1), Vector2(1, 1), Vector2(1, 2)][k]), col if k != 1 else col.darkened(0.35))

## Crew split screen, left: the capsule in cutaway, the two astronauts floating and celebrating inside.
func _draw_cabin() -> void:
	if tex_space != null:
		draw_texture_rect_region(tex_space, Rect2(0, 0, 318, 360), Rect2(0, 0, 318, 360))
	Pix.stars(self, t, Vector2(318, 360), 50, 21)
	if tex_planet != null:   # the world falls away below
		Pix.sprite(self, tex_planet, Vector2(36, 262))
	var cy: float = 60.0
	if tex_capsule != null:
		draw_texture(tex_capsule, Vector2(0, cy))
	Fx.glow(self, Vector2(159, cy + 80), 24, Color(1.0, 0.9, 0.6, 0.25), true)
	for p: Dictionary in people:
		var role: String = p["role"]
		if not role.begins_with("astro"):
			continue
		var u: float = t - float(p["off"])
		var a: bool = role == "astro_a"
		var f: int = 0
		var flip: bool = not a
		if u >= 0.0:
			var w: float = u * float(p["rate"])
			if int(w / 1.2) % 2 == 0:   # hug, then let go and cheer
				f = 7
			else:
				f = 3 if int(w / 0.25) % 2 == 0 else 6
				flip = not a and f == 6
		var hop: float = 0.0   # standing on the surface: one tiny low-gravity hop per cheer (Moon 1/6 g, a little higher than Mars 3/8 g)
		if f == 3:
			hop = absf(sin(u * float(p["rate"]) * 3.0)) * (2.0 if Game.dest_id == "moon" else 1.0)
		var bob: float = -roundf(hop)
		var x: float = float(p["x"]) if f == 7 or f == 0 else float(p["x"]) + (-3.0 if a else 3.0)
		_sprite(int(p["v"]), f, Vector2(floorf(x - CW / 2.0), cy + 128.0 + bob), flip, Color.WHITE)

func _lower_third() -> void:
	var r: Rect2 = Rect2(8, 316, 624, 38)
	Pix.panel(self, r)
	var line1: String = head if full else "PARTIAL RESULT: %d OF %d %s" % [got, goal, noun]
	Pix.text(self, r.position + Vector2(10, 15), line1, 10, UI.YELLOW if full else UI.ORANGE)
	Pix.text(self, r.position + Vector2(10, 30), sub, 10, UI.TEXT)

# ---------------------------------------------------------------- debug hooks (screenshots only)

## Short of the goal: the smaller celebration.
func debug_partial() -> void:
	got = maxi(1, goal - 1)
	full = false
	for p: Dictionary in people:
		if not String(p["role"]).begins_with("astro"):
			p["role"] = "clap" if rng.randf() < 0.75 else "idle"
