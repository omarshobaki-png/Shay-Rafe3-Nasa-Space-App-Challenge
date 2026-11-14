extends Control
## Ring drone: fly the sampling drone from the orbiter through the rings of Jupiter, Saturn, Uranus or Neptune and back.
## The world comes from Game.dest() ("skin" picks the art and the ring layout, "hazards" the radiation, Data the gravity);
## the difficulty comes from Game.diff(). Art: art/probe/ (tools/art/gen_probe.py, gen_giants.py). Effects: scripts/fx.gd.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const EventCard = preload("res://scripts/event_card.gd")

const WORLD: float = 1800.0
const G_REF_PX: float = 24.6    # game rule: px/s2 of pull at Saturn's 11.19 m/s2; other worlds scale as (g / 11.19) ^ 0.6 so Jupiter stays flyable
const G_REF: float = 11.19
const DOCK: Vector2 = Vector2(150, 118)
const LATCH: Vector2 = Vector2(150, 145)      # where the port holds the drone
const ORB: Vector2 = Vector2(152, 86)         # centre of the orbiter sprite: its port rim ends at y 127
const SHADOW_X: float = 1190.0                # the planet's shadow lies on the rings from here on
const RING_TOP: float = 160.0
const RING_BOTTOM: float = 246.0
const ROCK_PX: Array[int] = [18, 22, 30, 36, 48, 56, 70]              # frame size of each boulder sheet
const ROCK_R: Array[float] = [6.0, 7.5, 9.5, 12.5, 16.0, 19.5, 24.0]  # hit radius: 0.92 of the drawn one
const ROCK_FRAMES: int = 16
const BODY_HALF: float = 13.0   # the drone's hull is a lying capsule: half length and radius
const BODY_R: float = 10.0
const PLANET_Y: float = 262.0
const PLANET_PAR: float = 0.25
const FUEL_BASE: float = 45.0   # seconds of thrust at Saturn on NORMAL
const NEAR: Array[Vector3] = [Vector3(640, 322, 0), Vector3(1230, 128, 1), Vector3(1560, 336, 2),
	Vector3(2080, 312, 0), Vector3(2440, 118, 1), Vector3(2760, 330, 2)]
const URANUS_BANDS: Array[float] = [175.0, 200.0, 227.0]   # the narrow rings (art rows): the rocks hide in them, the samples in the lanes
const URANUS_LANES: Array[float] = [187.0, 213.0]
const NEPTUNE_CLUMPS: Array[Vector2] = [Vector2(230, 3), Vector2(620, 5), Vector2(870, 5), Vector2(1260, 5), Vector2(1510, 5)]  # x of the bright Adams arcs (art repeats every 640 px), samples in each

## Per ring world (keyed by the art skin): sky moons, colours, rocks and where the samples lie.
const SKINS: Dictionary = {
	"saturn": {"moon1": "TITAN", "moon2": "ENCELADUS", "glow1": Color(0.95, 0.6, 0.25, 0.25), "spark": "c8dcf0",
		"glint": Color(0.3, 0.85, 1.0), "grain": "ICE", "picks": [0, 1, 2, 0, 3, 1, 4, 2, 0, 5, 1, 3, 2, 6, 0, 1, 4, 2, 3, 1], "ice": 34, "layout": "dense"},
	"jupiter": {"moon1": "IO", "moon2": "EUROPA", "glow1": Color(1.0, 0.85, 0.3, 0.25), "spark": "e0b890",
		"glint": Color(1.0, 0.55, 0.2), "grain": "DUST", "picks": [0, 1, 0, 2, 1, 3, 0], "ice": 20, "layout": "sparse"},
	"uranus": {"moon1": "MIRANDA", "moon2": "ARIEL", "glow1": Color(0.7, 0.75, 0.85, 0.15), "spark": "9aa4b8",
		"glint": Color(0.45, 0.6, 1.0), "grain": "DARK ICE", "picks": [1, 2, 3, 1, 4, 2, 3, 1, 2, 0, 3, 2], "ice": 24, "layout": "lanes"},
	"neptune": {"moon1": "TRITON", "moon2": "PROTEUS", "glow1": Color(0.75, 0.8, 1.0, 0.2), "spark": "e8c8d8",
		"glint": Color(1.0, 0.5, 0.85), "grain": "DUSTY ICE", "picks": [1, 2, 0, 3, 1, 2, 4, 0, 2, 1, 3, 2], "ice": 23, "layout": "clumps"},
}

var skin: String = "saturn"
var sk: Dictionary = {}
var t: float = 0.0
var state: String = "fly"
var end_t: float = 0.0
var end_at: float = 0.0
var end_kind: String = ""
var end_title: String = ""
var pos: Vector2 = Vector2(150, 145)
var vel: Vector2 = Vector2.ZERO
var gpx: float = G_REF_PX       # pull, px/s2
var thr: float = 54.0           # thrust, px/s2
var fuel: float = FUEL_BASE
var fuel_max: float = FUEL_BASE
var hp: int = 2
var hp_max: int = 2
var invuln: float = 0.0
var got: int = 0
var goal: int = 5
var goal_t: float = -1.0
var data: float = 0.0
var gb_sample: float = 0.0
var ice: Array = []
var rocks: Array = []
var rock_w: float = 0.6         # how fast the boulders drift (rad/s)
var msg: String = ""
var thrusting: bool = false
var steer: int = 0
var docked: bool = false
var latched: bool = false
var sent: int = 0
var hold: Dictionary = {}
var cam_x: float = 0.0
var trauma: float = 0.0
var flash_t: float = 0.0
var hull_flash: float = 0.0
var slot_flash: float = 0.0
var warn: Array[int] = []
var warn_beep: float = 0.0
var spawn_acc: float = 0.0
var thrust_time: float = 0.0    # seconds of thrust the player has held: the first direction goes away when this is enough
var rad_on: bool = false       # the world has radiation belts (hazard "radiation")
var rad_shield: bool = false   # the radiation shield is on board
var rad: float = 0.0           # 0..1: how much the electronics have taken
var glitch: float = 0.0        # seconds left of a static burst (the controls drop out)
var glitch_gap: float = 1.0
var ev_shown: int = 0          # site decisions shown this sortie
var help_open: bool = false
var help_btn: Button = null
var auto: bool = false          # debug: a simple autopilot flies the whole run
var freeze_at: float = -1.0     # debug: stop the clock here so a screenshot catches a short effect
var puffs: Array = []
var sparks: Array = []
var floaters: Array = []
var gems: Array = []
var debris: Array = []
var wisps: Array = []
var fxr: RandomNumberGenerator = RandomNumberGenerator.new()
var slot_x0: float = 160.0

var tex_space: Texture2D = null
var tex_planet: Texture2D = null
var tex_wisps: Texture2D = null
var tex_arcs: Texture2D = null
var tex_far: Texture2D = null
var tex_back: Texture2D = null
var tex_mid: Texture2D = null
var tex_grit: Texture2D = null
var tex_shadow: Texture2D = null
var tex_titan: Texture2D = null
var tex_enc: Texture2D = null
var tex_drone: Texture2D = null
var tex_flash: Texture2D = null
var tex_orbiter: Texture2D = null
var tex_crystal: Texture2D = null
var tex_arrow: Texture2D = null
var tex_chevron: Texture2D = null
var tex_brackets: Texture2D = null
var tex_lamps: Texture2D = null
var tex_icons: Texture2D = null
var tex_gauge: Texture2D = null
var tex_debris: Texture2D = null
var tex_rocks: Array[Texture2D] = []
var tex_near: Array[Texture2D] = []

## Art that differs per world (skin prefix; Saturn's files have none).
func _art(n: String) -> Texture2D:
	return Pix.img("probe/" + n if skin == "saturn" else "probe/%s_%s" % [skin, n])

## Art every world shares.
func _gen(n: String) -> Texture2D:
	return Pix.img("probe/" + n)

# multiplayer jobs (decision D7). Solo: no job is split out and the drone flies as before.
# Online the host simulates: the Scientist flies, the Engineer sets the throttle, and after docking the
# Comms officer picks what to send home. Others send "input"; the host sends "state".
var jobs: bool = false
var driver: bool = true
var remote: Dictionary = {}     # host: the latest "input" keys from other players, by role
var send_t: float = 0.0
var throttle: int = 1           # index into Data.DRONE_THROTTLE (1 = NORMAL, the solo value)
var got_kinds: Array = []       # the kind of each ice sample caught (its grain's variant)
var dl_job: bool = false        # the Comms officer picks the downlink after docking
var dl_sel: Array = []          # indices into _dl_items() chosen for the downlink
var dl_t: float = 0.0
var dl_done: bool = false
var dl_send: bool = false       # host: the Comms officer pressed SEND

func _ready() -> void:
	jobs = Game.multi()
	driver = Net.is_host()
	if jobs:
		auto = Game.cpu("science")
		dl_job = Game.job("comms")
		Net.received.connect(_on_net)
	var d: Dictionary = Game.dest()
	skin = String(d["skin"])
	sk = SKINS.get(skin, SKINS["saturn"])
	if not SKINS.has(skin):
		skin = "saturn"
	tex_space = Pix.img("bg_space")
	tex_planet = _art("planet")
	tex_wisps = _art("wisps")
	tex_arcs = _art("ring_arcs")
	tex_far = _art("ring_far")
	tex_back = _art("ring_back")
	tex_mid = _art("ring_mid")
	tex_grit = _art("ring_near")
	tex_shadow = _art("shadow")
	tex_titan = _art("titan")
	tex_enc = _art("enceladus")
	tex_crystal = _art("crystal")
	tex_drone = _gen("drone")
	tex_flash = _gen("drone_flash")
	tex_orbiter = _gen("orbiter")
	tex_arrow = _gen("arrow")
	tex_chevron = _gen("chevron")
	tex_brackets = _gen("brackets")
	tex_lamps = _gen("lamps")
	tex_icons = _gen("icons")
	tex_gauge = _gen("gauge")
	tex_debris = _gen("debris")
	for i: int in ROCK_PX.size():
		tex_rocks.append(_art("rock_%d" % i))
	for i: int in 3:
		tex_near.append(_art("near_%d" % i))
	fxr.seed = 99
	goal = int(d["samples_goal"])
	# gravity is the real one from Data; the thrust is tuned so the drone flies well on every world (game rule)
	var g: float = float(d["gravity"])
	gpx = G_REF_PX * pow(g / G_REF, 0.6)
	thr = gpx * (1.0 + 1.2 * sqrt(G_REF / g))
	fuel_max = FUEL_BASE * pow(g / G_REF, 0.3) * Game.diff("landing_forgive")
	fuel = fuel_max
	rock_w = 0.6 * (0.6 + 0.4 * Game.diff("drone_rocks"))
	hp_max = 4 if Game.tech.has("armor") else 2
	if Game.diff("drone_rocks") < 0.8:
		hp_max += 1    # EASY: one more hit
	hp = clampi(hp_max + int(Game.run.get("hull_delta", 0)), 1, hp_max)
	rad_on = Game.has_hazard("radiation")
	rad_shield = Game.id_has("shield")
	_reload_instruments()
	_make_field()
	for i: int in 16:
		wisps.append({"x": fxr.randf() * 1004.0, "d": fxr.randf_range(9.0, 84.0), "k": fxr.randi_range(0, 7)})
	slot_x0 = 148.0 + hp_max * 11.0 + 14.0
	if not Game.id_has("drone"):
		state = "nodrone"
		end_t = 4.0
		end_title = "NO DRONE ON BOARD"
		msg = "Nothing can go into the rings."
	var defs: Array = [["<", 8, "l"], [">", 52, "r"], ["THRUST", 548, "u"]]
	for dd: Array in defs:
		var b: Button = Button.new()
		b.text = dd[0]
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.7)
		b.visible = DisplayServer.is_touchscreen_available()  # the keys do it on a desktop
		add_child(b)
		b.position = Vector2(float(dd[1]), 292)
		b.size = Vector2(84 if dd[2] == "u" else 40, 34)
		var key: String = dd[2]
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold.erase(key))
	help_btn = Button.new()
	help_btn.text = "?"
	help_btn.focus_mode = Control.FOCUS_NONE
	add_child(help_btn)
	help_btn.position = Vector2(614, 8)
	help_btn.size = Vector2(20, 18)
	help_btn.pressed.connect(func() -> void: help_open = not help_open)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## What the instruments make per sample: only the ones that still work.
func _reload_instruments() -> void:
	gb_sample = 0.0
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(p["gb"])

## Boulders and samples for this world. Saturn: dense and bright. Jupiter: few rocks, sparse dust. Uranus: rocks in
## the narrow rings, samples in the lanes between. Neptune: samples in the bright arcs, nothing between.
func _make_field() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2017
	var picks: Array = sk["picks"]
	var n_rocks: int = maxi(3, roundi(float(picks.size()) * Game.diff("drone_rocks")))
	var layout: String = sk["layout"]
	for i: int in n_rocks:
		var m: int = int(picks[i % picks.size()])
		var r: float = ROCK_R[m]
		var rp: Vector2 = Vector2.ZERO
		for tries: int in 40:
			var x: float = rng.randf_range(380.0 + m * 40.0, WORLD - 60.0)
			var y: float = rng.randf_range(172, 234)
			if layout == "lanes":
				y = URANUS_BANDS[i % 3] + rng.randf_range(-4.0, 4.0)
			elif layout == "clumps" and i % 2 == 0:
				var c: Vector2 = NEPTUNE_CLUMPS[1 + (i / 2) % (NEPTUNE_CLUMPS.size() - 1)]
				x = c.x + rng.randf_range(-70.0, 70.0)
				y = rng.randf_range(182.0, 222.0)
			rp = Vector2(x, y)
			if _free_of_rocks(rp, r + 34.0, r + 6.0):
				break
		var spin: float = rng.randf_range(3.0, 6.5) * (0.55 if m >= 4 else 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		rocks.append({"p": rp, "r": r, "m": m, "ph": rng.randf() * TAU, "spin": spin, "f0": rng.randi_range(0, 15)})
	var n_ice: int = int(sk["ice"])
	var lane: int = 0
	for i: int in n_ice:
		var ip: Vector2 = Vector2.ZERO
		for tries: int in 40:
			ip = Vector2(rng.randf_range(320, WORLD - 60), rng.randf_range(176, 230))
			if layout == "sparse":
				ip.x = 330.0 + (float(i) + rng.randf_range(-0.2, 0.2)) * (WORLD - 400.0) / float(n_ice)
			elif layout == "lanes":
				ip.x = 330.0 + (float(i) + rng.randf_range(-0.2, 0.2)) * (WORLD - 400.0) / float(n_ice)
				ip.y = URANUS_LANES[rng.randi_range(0, 1)] + rng.randf_range(-4.0, 4.0)
			elif layout == "clumps":
				var k: int = 0
				var left: int = i
				while left >= int(NEPTUNE_CLUMPS[k].y):
					left -= int(NEPTUNE_CLUMPS[k].y)
					k += 1
				ip = Vector2(NEPTUNE_CLUMPS[k].x + rng.randf_range(-40.0, 40.0), 201.0 + rng.randf_range(-15.0, 15.0))
			if _free_of_rocks(ip, 28.0, 12.0):
				break
		ice.append({"p": ip, "taken": false, "v": rng.randi_range(0, 2), "ph": rng.randf() * TAU})
		lane += 1

func _free_of_rocks(p: Vector2, mx: float, my: float) -> bool:
	for q: Dictionary in rocks:
		var qp: Vector2 = q["p"]
		if absf(p.x - qp.x) < float(q["r"]) + mx and absf(p.y - qp.y) < float(q["r"]) + my:
			return false
	return true

func _say(s: String) -> void:
	msg = s

func _end(ok_dock: bool, title: String, text: String, kind: String) -> void:
	if state != "fly":
		return
	state = "done"
	if auto:
		print("DRONE_AUTO %s %s: got %d of %d, hull %d of %d, fuel %.1f of %.1f s, radiation %.2f, cards %d, t %.1f s" % [skin, title, got, goal, hp, hp_max, fuel, fuel_max, rad, ev_shown, t])
	docked = ok_dock
	end_kind = kind
	end_title = title
	end_at = t
	end_t = t + (3.6 if kind == "fry" else 3.0)
	_say(text)
	thrusting = false
	steer = 0
	warn.clear()
	help_open = false
	Audio.loop("thrust", false)
	if ok_dock:
		Audio.play("dock", -2.0)
	else:
		Audio.play("hit" if kind == "fry" else "explosion", -2.0)
		trauma = 1.0 if kind != "fry" else 0.4
		if kind == "smash":
			for i: int in 4:
				var a: float = fxr.randf() * TAU
				debris.append({"p": pos, "v": Vector2(cos(a), sin(a)) * fxr.randf_range(50, 120) + vel * 0.4, "age": 0.0, "c": i})
			_burst(pos, 14, Color("ffd75e"), 130.0)

## Distance from a point to the drone's hull axis (a lying capsule, so the thruster pods count too).
func _drone_dist(p: Vector2) -> float:
	var c: Vector2 = pos + Vector2(0, 1)
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, c - Vector2(BODY_HALF, 0), c + Vector2(BODY_HALF, 0)))

func _physics_process(delta: float) -> void:
	if EventCard.is_open():
		if auto:
			_auto_card()
		return
	if freeze_at >= 0.0 and t >= freeze_at:
		return
	t += delta
	invuln -= delta
	_tick_fx(delta)
	if not driver:
		_send_input(delta)
		Audio.loop("thrust", thrusting and state == "fly", -9.0)
		return
	_send_state(delta)
	if state == "downlink":
		_dl_tick(delta)
		return
	if state != "fly":
		if state == "done" and docked:
			_tick_docking(delta)
		elif state == "done" and (end_kind == "burn" or end_kind == "fry"):
			vel = vel * (1.0 - minf(1.0, 2.0 * delta)) + Vector2(0, 30.0 if end_kind == "burn" else gpx) * delta
			pos += vel * delta
		if t > end_t:
			if docked and dl_job and not dl_done:
				state = "downlink"
				dl_t = 0.0
				_send_state(1.0)
				return
			set_physics_process(false)
			Engine.time_scale = 1.0
			Game.probe_result(got, docked, data)
			if dl_done:
				var pts: int = _dl_pts()
				Game.run["downlink_pts"] = pts
				Game.note(pts > 0, "The Comms officer sent %d of %d items home: %d science points (+%d credits)." % [dl_sel.size(), _dl_items().size(), pts, pts * int(Data.DRONE_DOWNLINK["credits_per_pt"])])
			Game.run["mode"] = "home"
			Game.flow("flight")
		return
	if auto:
		_autopilot()
	_tick_radiation(delta)
	var keys: Dictionary = _fly_keys()
	var up: bool = bool(keys.get("up", false))
	var lft: bool = bool(keys.get("left", false))
	var rgt: bool = bool(keys.get("right", false))
	if glitch > 0.0:
		up = false    # the electronics drop the commands
		lft = false
		rgt = false
	thrusting = up and fuel > 0.0
	Audio.loop("thrust", thrusting, -9.0)
	var acc: Vector2 = Vector2(0, gpx)
	steer = 0
	if thrusting:
		acc.y -= thr * (float(Data.DRONE_THROTTLE[throttle]["thrust"]) if jobs else 1.0)
		fuel -= delta * (float(Data.DRONE_THROTTLE[throttle]["burn"]) if jobs else 1.0)
		thrust_time += delta
	if fuel > 0.0:
		if lft:
			acc.x -= 55.0
			fuel -= delta * 0.3
			steer -= 1
		if rgt:
			acc.x += 55.0
			fuel -= delta * 0.3
			steer += 1
	fuel = maxf(fuel, 0.0)
	if pos.y > 285.0:
		vel *= 1.0 - minf(1.0, 2.0 * delta)  # thick air drags
	vel += acc * delta
	vel.x = clampf(vel.x, -140.0, 140.0)
	pos += vel * delta
	pos.x = clampf(pos.x, 10.0, WORLD - 10.0)
	if pos.y < 10.0:
		pos.y = 10.0
		vel.y = 0.0
	# samples
	for s: Dictionary in ice:
		var sp: Vector2 = s["p"]
		if not s["taken"] and _drone_dist(sp) < 20.0:
			s["taken"] = true
			got += 1
			got_kinds.append(int(s["v"]))
			Audio.play("pickup", -3.0, 1.0 + got * 0.06)
			data += gb_sample
			_burst(sp, 8, Color(sk["glint"]).lerp(Color.WHITE, 0.6), 70.0)
			floaters.append({"p": sp, "age": 0.0, "s": "+1 %s" % sk["grain"], "bad": false})
			gems.append({"a": sp - Vector2(_cam(), 0), "b": _slot_pos(mini(got, goal) - 1), "age": 0.0, "life": 0.55, "hud": true})
			if got == goal:
				goal_t = t
	# ring rocks
	warn.clear()
	for i: int in rocks.size():
		var r: Dictionary = rocks[i]
		var rp: Vector2 = _rock_pos(r)
		var rr: float = float(r["r"])
		if invuln <= 0.0 and _drone_dist(rp) < rr + BODY_R:
			_hurt(1, rp, rr)
			break
		# collision course: where will the two be at their closest in the next second?
		var dd: Vector2 = rp - pos
		if invuln <= 0.0 and dd.length() < 170.0:
			var v: Vector2 = Vector2(cos(t * rock_w + float(r["ph"])) * 14.0 * rock_w, 0) - vel
			var vv: float = v.length_squared()
			if vv > 400.0:
				var tca: float = -dd.dot(v) / vv
				if tca > 0.0 and (dd + v * minf(tca, 1.1)).length() < rr + 16.0:
					warn.append(i)
	warn_beep -= delta
	if not warn.is_empty() and warn_beep <= 0.0 and state == "fly":
		warn_beep = 0.35
		Audio.play("blip", -10.0, 1.5)
	if pos.y > 330.0:
		_end(false, "DRONE LOST", "It burned up in the air, as Cassini did in 2017.", "burn")
	# docking
	if pos.distance_to(DOCK + Vector2(0, 46)) < 22.0 and vel.length() < 60.0 and t > 3.0:
		_end(true, "DOCKED!", "Samples are safe on the orbiter.", "dock")
	_spawn_trails(delta)
	_check_events()

## A boulder hit: `n` hull points lost.
func _hurt(n: int, from: Vector2, radius: float) -> void:
	hp -= n
	Audio.play("hit")
	invuln = 1.0
	vel = (pos - from).normalized() * 80.0
	trauma = minf(1.0, trauma + 0.7)
	flash_t = 0.12
	hull_flash = 0.5
	var hit: Vector2 = from + (pos - from).normalized() * radius
	_burst(hit, 10, Color("ffe9a0"), 110.0)
	for k: int in 3:
		_puff(hit, Vector2(fxr.randf_range(-20, 20), fxr.randf_range(-20, 20)), 0.7, 1, Color(0.6, 0.62, 0.7))
	if hp <= 0:
		_end(false, "DRONE SMASHED", "by a ring boulder.", "smash")
	else:
		floaters.append({"p": pos - Vector2(0, 26), "age": 0.0, "s": "HULL %d OF %d" % [hp, hp_max], "bad": true})

## The belts fill the meter while the drone is out: slowly with the shield, fast without it (then the controls drop out, then it fails).
func _tick_radiation(delta: float) -> void:
	if not rad_on:
		return
	var depth: float = lerpf(0.4, 1.3, clampf((pos.x - 150.0) / 700.0, 0.0, 1.0))   # the orbiter's side is calmer
	var per_s: float = (1.0 / 260.0 if rad_shield else 1.0 / 40.0) * Game.diff("surface_hazards") * depth
	rad = minf(1.0, rad + per_s * delta)
	if not rad_shield and rad > 0.5:
		glitch_gap -= delta * (1.0 + (rad - 0.5) * 6.0)
		if glitch <= 0.0 and glitch_gap <= 0.0:
			glitch = 0.12 + fxr.randf() * 0.18
			glitch_gap = 1.2 + fxr.randf()
			Audio.play("blip", -9.0, 0.6)
	glitch = maxf(0.0, glitch - delta)
	if rad >= 1.0 and not rad_shield:
		_end(false, "ELECTRONICS FRIED", "The belts broke the drone. A shield would have saved it.", "fry")

## Decision cards at the site: one after the first samples, one before the flight back.
func _check_events() -> void:
	if state != "fly" or Game.run.is_empty() or ev_shown >= 2 or bool(Game.run.get("dead", false)):
		return
	var ev: Dictionary = Game.next_event("site")
	if ev.is_empty():
		return
	var due: bool = got >= goal if ev_shown == 1 else float(got) >= clampf(float(ev["at"]), 0.2, 0.6) * float(goal)
	if due and got > 0 and pos.y < 270.0:
		_open_event(ev)

func _open_event(ev: Dictionary) -> void:
	ev_shown += 1
	Game.run["samples"] = got
	Game.run["data"] = data
	Game.run["hull_delta"] = hp - hp_max
	hold.clear()
	thrusting = false
	steer = 0
	Audio.loop("thrust", false)
	EventCard.open(self, ev, _after_event)

## The host supplied the run already; watchers only open the shared card.
func mp_open_event(ev: Dictionary) -> void:
	EventCard.open(self, ev, _after_event)

## Mirror what the decision did into the drone, and show it in the world.
func _after_event(res: Dictionary) -> void:
	var ap: Dictionary = res.get("applied", {})
	got = int(Game.run["samples"])
	data = float(Game.run["data"])
	hp = clampi(hp_max + int(Game.run["hull_delta"]), 0, hp_max)
	_reload_instruments()
	if got < goal:
		goal_t = -1.0
	var k: int = 0
	for chip: Array in res.get("chips", []):
		floaters.append({"p": pos + Vector2(0, -14 - 12 * k), "age": 0.0, "s": String(chip[1]).left(22), "bad": bool(chip[2])})
		k += 1
	if int(ap.get("hull", 0)) < 0:
		trauma = 0.6
		flash_t = 0.12
		hull_flash = 0.5
		_burst(pos, 8, Color("ffe9a0"), 90.0)
	if not (ap.get("broken", []) as Array).is_empty():
		_burst(pos, 10, Color("ff9a5a"), 80.0)
		trauma = maxf(trauma, 0.4)
	if bool(Game.run.get("dead", false)):
		_end(false, "MISSION LOST", "See the report.", "fry")
	elif hp <= 0:
		_end(false, "DRONE SMASHED", "The damage was too much.", "smash")

## The port reels the drone in, the latch arms close, then the samples go up one by one.
func _tick_docking(delta: float) -> void:
	vel = Vector2.ZERO
	pos = pos.lerp(LATCH, 1.0 - exp(-5.0 * delta))
	if not latched and t - end_at > 0.9:
		latched = true
		pos = LATCH
		Audio.play("success", -2.0)
		_burst(LATCH - Vector2(0, 18), 8, Color("6dff8a"), 60.0)
	if latched and sent < mini(got, 8) and t - end_at > 1.1 + sent * 0.2:
		sent += 1
		Audio.play("ice_ping", -8.0, 1.0 + sent * 0.05)
		gems.append({"a": LATCH - Vector2(_cam(), 14), "b": ORB + Vector2(-_cam() - 12, 2), "age": 0.0, "life": 0.5, "hud": false})

func _puff(p: Vector2, v: Vector2, life: float, size: int, tint: Color) -> void:
	if puffs.size() < 140:
		puffs.append({"p": p, "v": v, "age": 0.0, "life": life, "size": size, "tint": tint})

func _burst(p: Vector2, n: int, tint: Color, speed: float) -> void:
	for i: int in n:
		var a: float = TAU * i / n + fxr.randf() * 0.5
		sparks.append({"p": p, "v": Vector2(cos(a), sin(a)) * speed * fxr.randf_range(0.5, 1.0), "age": 0.0, "life": fxr.randf_range(0.3, 0.6), "tint": tint})

## Thruster gas, the wake of ring dust, smoke from a hurt hull, haze in the atmosphere, radiation sparks on the hull.
func _spawn_trails(delta: float) -> void:
	spawn_acc += delta
	if spawn_acc < 0.05:
		return
	spawn_acc = 0.0
	var jit: Vector2 = Vector2(fxr.randf_range(-4, 4), fxr.randf_range(-4, 4))
	if thrusting:
		_puff(pos + Vector2(0, 30) + jit, Vector2(fxr.randf_range(-12, 12), 50) + vel * 0.3, 0.45, 0, Color(1.0, 0.8, 0.55))
	if steer != 0:
		_puff(pos + Vector2(-28.0 * steer, 6) + jit * 0.5, Vector2(-70.0 * steer, fxr.randf_range(-8, 8)) + vel * 0.5, 0.35, 0, Color(0.85, 0.92, 1.0))
	if pos.y > RING_TOP and pos.y < RING_BOTTOM and vel.length() > 25.0:
		_puff(pos - vel.normalized() * 20.0 + jit * 2.0, -vel * 0.15, 0.8, 0, Color(0.8, 0.92, 1.0))
		if fxr.randf() < 0.3:
			sparks.append({"p": pos - vel.normalized() * 16.0 + jit * 3.0, "v": -vel * 0.3, "age": 0.0, "life": 0.5, "tint": Color("f0f6ff"), "size": 0})
	if hp < hp_max and fxr.randf() < (0.8 if hp <= 1 else 0.4):
		_puff(pos + Vector2(-8, -8) + jit, Vector2(fxr.randf_range(-10, 10), -22) - vel * 0.2, 1.1, 1, Color(0.3, 0.3, 0.36))
	if rad_on and fxr.randf() < rad * (0.25 if rad_shield else 0.9):
		sparks.append({"p": pos + jit * 4.0, "v": Vector2(fxr.randf_range(-30, 30), fxr.randf_range(-30, 30)), "age": 0.0, "life": 0.35,
			"tint": Color("8fa8ff") if rad_shield else Color("c9a0ff"), "size": 0})
	if pos.y > 285.0:
		_puff(pos + Vector2(fxr.randf_range(-30, 30), fxr.randf_range(0, 24)), Vector2(-vel.x * 0.6, -30), 0.8, 1, Color(0.96, 0.86, 0.6))

func _tick_fx(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.8)
	flash_t -= delta
	hull_flash -= delta
	slot_flash -= delta
	for list: Array in [puffs, sparks, floaters, gems, debris]:
		for i: int in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[i]
			e["age"] = float(e["age"]) + delta
			if e.has("v"):
				var v: Vector2 = e["v"]
				var p: Vector2 = e["p"]
				e["p"] = p + v * delta
			if float(e["age"]) >= float(e.get("life", 0.9 if list != debris else 2.5)):
				if list == gems and e["hud"]:
					slot_flash = 0.25
					Audio.play("ice_ping", -8.0, 1.0 + got * 0.05)
				list.remove_at(i)
	if state == "done" and end_kind == "burn" and t - end_at < 0.7:
		_puff(pos + Vector2(fxr.randf_range(-12, 12), -6), Vector2(fxr.randf_range(-20, 20), -60), 0.7, 1, Color(0.3, 0.26, 0.24))

func _rock_pos(r: Dictionary) -> Vector2:
	var p: Vector2 = r["p"]
	return p + Vector2(sin(t * rock_w + float(r["ph"])) * 14.0, 0)

func _process(delta: float) -> void:
	var want: float = clampf(pos.x - 320.0 + clampf(vel.x * 0.45, -70.0, 70.0), 0.0, WORLD - 640.0)
	cam_x = lerpf(cam_x, want, 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if EventCard.is_open():
		return
	_job_input(event)
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_H or k.keycode == KEY_SLASH or k.keycode == KEY_QUESTION) and not EventCard.is_open():
		help_open = not help_open

func _cam() -> float:
	return floorf(clampf(cam_x, 0.0, WORLD - 640.0))

func _slot_pos(i: int) -> Vector2:
	return Vector2(slot_x0 + i * 10, 16)

## One cell of a sprite sheet, centred on `center`.
func _cell(tex: Texture2D, center: Vector2, cx: int, cy: int, size: Vector2, mod: Color = Color.WHITE) -> void:
	draw_texture_rect_region(tex, Rect2((center - size / 2.0).floor(), size), Rect2(Vector2(cx, cy) * size, size), mod)

## Height of the planet's limb on screen at planet-image column px (same arc as tools/art/gen_probe.py and gen_giants.py).
func _limb(px: float) -> float:
	return PLANET_Y + 14.0 + 4614.0 - sqrt(4614.0 * 4614.0 - (px - 470.0) * (px - 470.0))

## How deep in the planet's shadow a world x is: 0 lit .. 1 dark.
func _shade(wx: float) -> float:
	return clampf((wx - SHADOW_X - 20.0) / 90.0, 0.0, 1.0)

func _draw() -> void:
	var cam: float = _cam()
	var sh: Vector2 = Vector2.ZERO
	if trauma > 0.0:
		sh = Vector2(sin(t * 61.0), sin(t * 47.0 + 1.3)) * trauma * trauma * 5.0
	draw_set_transform(sh.floor())
	_draw_sky(cam)
	_draw_planet(cam)
	_draw_rings(cam)
	_draw_ice(cam)
	_draw_rocks(cam)
	_draw_orbiter(cam)
	_draw_drone(cam)
	_draw_front(cam)
	draw_set_transform(Vector2.ZERO)
	Fx.flash(self, 0.12 - flash_t, 0.12, Color(1, 1, 1, 0.4))
	_draw_glitch()
	_draw_hud(cam)
	if jobs:
		_draw_jobs()
	if state == "downlink":
		_draw_downlink()

func _draw_sky(cam: float) -> void:
	Pix.tiled(self, tex_space, -4, cam * 0.05 + t * 1.0)
	Pix.stars(self, t, Vector2(640, 250), 46, 12, Vector2(-cam * 0.06, 0))
	var sun: Vector2 = Vector2(50.0 - cam * 0.02, 62.0).floor()
	Fx.glow(self, sun, 24.0, Color(1.0, 0.95, 0.8, 0.18), true)
	Fx.sun(self, sun, 0, Color("fff6e0"), t)
	var ti: Vector2 = Vector2(486.0 - cam * 0.03, 88.0).floor()
	Fx.glow(self, ti, 12.0, sk["glow1"], true)
	Pix.sprite(self, tex_titan, ti)
	Pix.text(self, ti + Vector2(12, 4), String(sk["moon1"]), 10, Color(UI.DIM, 0.6))
	var en: Vector2 = Vector2(574.0 - cam * 0.04, 112.0).floor()
	_cell(tex_enc, en, int(t * 3.0) % 2, 0, Vector2(11, 14))
	Pix.text(self, en + Vector2(8, 1), String(sk["moon2"]), 10, Color(UI.DIM, 0.6))
	draw_texture(tex_arcs, Vector2(-floorf(cam * 0.12) - 20.0, 38.0))

func _draw_planet(cam: float) -> void:
	var off: float = floorf(cam * PLANET_PAR)
	draw_texture(tex_planet, Vector2(-off, PLANET_Y))
	for w: Dictionary in wisps:
		var d: float = float(w["d"])
		var px: float = fposmod(float(w["x"]) + t * (2.0 + d * 0.22), 1004.0) - 64.0
		var night: float = clampf((px + 32.0 - 583.0) / 188.0, 0.0, 1.0)
		var y: float = _limb(px + 32.0) + d
		draw_texture_rect_region(tex_wisps, Rect2(floorf(px - off), floorf(y), 64, 5), Rect2(0, int(w["k"]) * 5, 64, 5),
			Color(1.0 - 0.7 * night, 1.0 - 0.72 * night, 1.0 - 0.55 * night, 0.8))

func _draw_rings(cam: float) -> void:
	Pix.tiled(self, tex_far, 136, cam * 0.3)
	# far glints: each one lives a moment at a spot picked by its cycle number
	for i: int in 12:
		var cyc: float = (t + i * 0.37) / (1.4 + i * 0.13)
		var n: int = int(cyc) * 12 + i
		var gp: Vector2 = Vector2(fposmod(float((n * 7919) % 640) - cam * 0.3, 640.0), 150.0 + float((n * 104729) % 86))
		var age: float = fposmod(cyc, 1.0) * 2.2
		if age < 1.0:
			Fx.sparkle(self, gp, age, Color(String(sk["spark"])))
	Pix.tiled(self, tex_back, 150, cam * 0.6)
	Pix.tiled(self, tex_mid, 158, cam)
	draw_texture(tex_shadow, Vector2(SHADOW_X - cam, 136))

func _draw_ice(cam: float) -> void:
	var gc: Color = sk["glint"]
	for sd: Dictionary in ice:
		if sd["taken"]:
			continue
		var p: Vector2 = sd["p"]
		var ph: float = float(sd["ph"])
		var sp: Vector2 = Vector2(p.x - cam, p.y + sin(t * 2.2 + ph) * 2.0).floor()
		if sp.x < -20 or sp.x > 660:
			continue
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + ph)
		Fx.glow(self, sp, 10.0 + 3.0 * pulse, Color(gc.r, gc.g, gc.b, 0.3 + 0.25 * pulse + 0.2 * _shade(p.x)), true)
		var cyc: float = fposmod(t * 0.8 + ph, 1.0)
		_cell(tex_crystal, sp, 1 + int((cyc - 0.82) / 0.06) if cyc > 0.82 else 0, int(sd["v"]), Vector2(15, 15))

func _draw_rocks(cam: float) -> void:
	for i: int in rocks.size():
		var r: Dictionary = rocks[i]
		var rp: Vector2 = _rock_pos(r)
		var m: int = int(r["m"])
		var s: float = float(ROCK_PX[m])
		if rp.x - cam < -s or rp.x - cam > 640.0 + s:
			continue
		var k: float = _shade(rp.x)
		var f: int = posmod(int(floorf(t * float(r["spin"]))) + int(r["f0"]), ROCK_FRAMES)
		_cell(tex_rocks[m], rp - Vector2(cam, 0), f, 0, Vector2(s, s), Color(1.0 - 0.5 * k, 1.0 - 0.45 * k, 1.0 - 0.22 * k))
		if warn.has(i) and int(t * 8.0) % 2 == 0:
			var c: Vector2 = (rp - Vector2(cam, 0)).floor()
			var h: float = floorf(s / 2.0) + 3.0
			for q: int in 4:
				var qx: int = q % 2
				var qy: int = q / 2
				draw_texture_rect_region(tex_brackets, Rect2(c + Vector2(-h if qx == 0 else h - 7.0, -h if qy == 0 else h - 7.0), Vector2(7, 7)), Rect2(qx * 7, qy * 7, 7, 7))

func _draw_orbiter(cam: float) -> void:
	var o: Vector2 = ORB - Vector2(cam, 0)
	if o.x < -80.0:
		return
	var held: bool = latched or (state == "fly" and t < 0.5) or state == "nodrone"
	_cell(tex_orbiter, o, 1 if held else 0, 0, Vector2(120, 112))
	# beacon on the boom, lamps on the port rim: green when the drone is slow enough to dock
	var blink: bool = int(t * 2.0) % 2 == 0
	if int(t * 1.2) % 2 == 0:
		Fx.glow(self, o + Vector2(-37, -47), 6.0, Color(1.0, 0.3, 0.25, 0.4), true)
		_cell(tex_lamps, o + Vector2(-37, -47), 2, 0, Vector2(5, 5))
	var lamp: int = 1 if (vel.length() < 60.0 or state != "fly") else 2
	for side: int in 2:
		var on: bool = latched or (blink == (side == 0))
		var lp: Vector2 = o + Vector2(-9.0 + side * 14.0, 41.0)
		if on:
			Fx.glow(self, lp, 6.0, Color(0.4, 1.0, 0.55, 0.4) if lamp == 1 else Color(1.0, 0.35, 0.3, 0.4), true)
		_cell(tex_lamps, lp, lamp if on else 0, 0, Vector2(5, 5))
	if state != "fly" or t < 3.0:
		return
	# guide lane under the port: dashes on both sides and chevrons climbing into the cone
	var z: Vector2 = (DOCK + Vector2(-cam, 46)).floor()
	var a: float = 0.85 if got > 0 else 0.45
	var march: float = fposmod(t * 14.0, 8.0)
	for k: int in 7:
		var y: float = z.y + 24.0 - k * 8.0 - march
		if y > z.y - 26.0:
			draw_rect(Rect2(z.x - 25, floorf(y), 2, 4), Color(UI.GREEN, a))
			draw_rect(Rect2(z.x + 23, floorf(y), 2, 4), Color(UI.GREEN, a))
	for k: int in 3:
		var cy: float = z.y + 18.0 - fposmod(t * 14.0 + k * 13.0, 39.0)
		draw_texture(tex_chevron, Vector2(z.x - 5, floorf(cy)), Color(UI.GREEN, a * (1.0 - absf(cy - z.y) / 30.0)))

func _draw_drone(cam: float) -> void:
	var view: Vector2 = Vector2(cam, 0)
	for e: Dictionary in puffs:
		var pp: Vector2 = e["p"]
		Fx.puff(self, pp - view, float(e["age"]) / float(e["life"]), int(e["size"]), e["tint"])
	for e: Dictionary in debris:
		var bp: Vector2 = e["p"]
		_cell(tex_debris, bp - view, int(e["c"]), 0, Vector2(9, 9), Color(1, 1, 1, clampf(2.5 - float(e["age"]), 0.0, 1.0)))
	var dp: Vector2 = (pos - view).floor()
	var gone: bool = state == "nodrone" or (end_kind == "smash" and t - end_at > 0.08) or (end_kind == "burn" and t - end_at > 0.7) or (end_kind == "fry" and pos.y > 330.0)
	var blink_off: bool = state == "fly" and invuln > 0.0 and flash_t <= 0.0 and int(t * 12.0) % 2 == 1
	if not gone and not blink_off:
		if thrusting:
			Fx.glow(self, dp + Vector2(0, 30), 16.0, Color(1.0, 0.7, 0.3, 0.3), true)
			Fx.flame(self, dp + Vector2(0, 17), Vector2.DOWN, 22.0, 8.0, t)
		if steer > 0:
			Fx.flame(self, dp + Vector2(-27, 5), Vector2.LEFT, 9.0, 3.0, t)
		elif steer < 0:
			Fx.flame(self, dp + Vector2(27, 5), Vector2.RIGHT, 9.0, 3.0, t)
		if end_kind == "burn":
			Fx.flame(self, dp + Vector2(0, -14), Vector2.UP, 30.0, 14.0, t)
		var row: int = 1 + steer
		var dmg: int = 0 if hp >= hp_max else (2 if hp <= 1 else 1)
		if flash_t > 0.0:
			_cell(tex_flash, dp, row, 0, Vector2(66, 48))
		else:
			var k: float = _shade(pos.x) * 0.3
			var dim: float = 0.45 if end_kind == "fry" else 1.0
			_cell(tex_drone, dp, dmg, row, Vector2(66, 48), Color((1.0 - k) * dim, (1.0 - k) * dim, (1.0 - k * 0.4) * dim))
			if int(t * 1.5) % 2 == 0 and dmg < 2 and end_kind != "fry":
				Fx.glow(self, dp + Vector2(-10, -21), 4.0, Color(1.0, 0.3, 0.25, 0.45), true)
	if end_kind == "smash":
		Fx.explosion(self, dp, t - end_at, 2)
	elif end_kind == "burn":
		Fx.explosion(self, dp, t - end_at - 0.6, 1)
	for e: Dictionary in sparks:
		var kp: Vector2 = e["p"]
		Fx.sparkle(self, kp - view, float(e["age"]) / float(e["life"]), e["tint"], int(e.get("size", 1)))
	for e: Dictionary in floaters:
		var fp: Vector2 = e["p"]
		var age: float = float(e["age"])
		Pix.text_o(self, Vector2(floorf(fp.x - cam - Pix.text_w(String(e["s"]), 10) / 2.0), floorf(fp.y - 14.0 - age * 22.0)), String(e["s"]), 10,
			Color(UI.YELLOW if bool(e["bad"]) else UI.TEXT, clampf(2.0 - age * 2.2, 0.0, 1.0)))
	if state == "fly" and pos.y > 285.0 and int(t * 5.0) % 2 == 0:
		Pix.text_c(self, dp.x, dp.y - 32.0, "PULL UP", 10, UI.YELLOW)
	if not warn.is_empty() and int(t * 8.0) % 2 == 0:
		_cell(tex_icons, dp + Vector2(0, -34), 5, 0, Vector2(11, 11))

## Dark grit and big boulders close to the camera, sliding past faster than the play layer.
func _draw_front(cam: float) -> void:
	Pix.tiled(self, tex_grit, 138, cam * 1.35 + t * 2.0)
	for n: Vector3 in NEAR:
		var tex: Texture2D = tex_near[int(n.z)]
		var x: float = n.x - cam * 1.7 - t * 3.0
		if x > -100.0 and x < 740.0:
			Pix.sprite(self, tex, Vector2(x, n.y + sin(t * 0.3 + n.x) * 3.0))

## Static from the radiation: thin bars and specks while the electronics glitch.
func _draw_glitch() -> void:
	var k: float = 0.0
	if glitch > 0.0:
		k = 1.0
	elif rad_on and not rad_shield and rad > 0.5:
		k = (rad - 0.5) * 0.5 * (1.0 if int(t * 20.0) % 7 == 0 else 0.0)
	if k <= 0.0:
		return
	var seed_n: int = int(t * 30.0)
	for i: int in 9:
		var y: float = float((seed_n * 7919 + i * 104729) % 360)
		draw_rect(Rect2(0, y, 640, 1 + (i % 3)), Color(0.7, 0.55, 1.0, 0.18 * k + 0.1))
	for i: int in 40:
		draw_rect(Rect2(float((seed_n * 31 + i * 7717) % 640), float((seed_n * 17 + i * 2399) % 360), 3, 1), Color(0.9, 0.85, 1.0, 0.5 * k))

func _draw_hud(cam: float) -> void:
	# cockpit strip: fuel, hull, sample slots, gravity
	var gx: float = slot_x0 + goal * 10.0 + 14.0    # groove after the sample slots (room for "+12")
	var w: float = gx + 74.0
	Pix.panel(self, Rect2(6, 6, w, 20))
	_cell(tex_icons, Vector2(17, 16), 0, 0, Vector2(11, 11))
	var cells: int = ceili(20.0 * fuel / fuel_max)
	var low: bool = fuel < fuel_max * 0.25
	for i: int in 20:
		var col: int = 2 if i >= cells or (low and int(t * 4.0) % 2 == 0) else (1 if low else 0)
		draw_texture_rect_region(tex_gauge, Rect2(26 + i * 4, 13, 4, 6), Rect2(col * 4, 0, 4, 6))
	Pix.text(self, Vector2(109, 20), "%d s" % ceili(fuel), 10, UI.TEXT)
	_groove(136)
	for i: int in hp_max:
		var lost_now: bool = i == hp and hull_flash > 0.0 and int(t * 12.0) % 2 == 0
		_cell(tex_icons, Vector2(154 - 6 + i * 11, 16), 1 if i < hp else 2, 0, Vector2(11, 11), Color(1.0, 0.4, 0.4) if lost_now else Color.WHITE)
	_groove(slot_x0 - 12.0)
	for i: int in goal:
		var just: bool = slot_flash > 0.0 and i == mini(got, goal) - 1
		var filled: bool = i < got - (1 if _gem_flying() else 0)
		_cell(tex_icons, _slot_pos(i), 3 if filled else 4, 0, Vector2(11, 11))
		if just:
			Fx.sparkle(self, _slot_pos(i), 1.0 - slot_flash / 0.25, Color.WHITE)
	if got > goal:
		Pix.text(self, _slot_pos(goal) + Vector2(-4, 4), "+%d" % (got - goal), 10, UI.TEXT)
	_groove(gx)
	_cell(tex_icons, Vector2(gx + 11.0, 16), 6, 0, Vector2(11, 11))
	Pix.text(self, Vector2(gx + 19.0, 20), "%.2f m/s2" % float(Game.dest()["gravity"]), 10, UI.TEXT)
	if rad_on:
		_draw_rad_meter()
	# samples on their way to a slot or up into the orbiter
	var gc: Color = sk["glint"]
	for e: Dictionary in gems:
		var k: float = float(e["age"]) / float(e["life"])
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var gp: Vector2 = a.lerp(b, k * k) + Vector2(0, -24.0 * sin(k * PI))
		Fx.glow(self, gp, 8.0, Color(gc.r, gc.g, gc.b, 0.4), true)
		_cell(tex_icons, gp, 3, 0, Vector2(11, 11))
	_draw_fact()
	# the dock, when it is off screen
	var dk: float = DOCK.x - cam
	if state == "fly" and dk < -12.0:
		var bob: float = floorf(absf(sin(t * (6.0 if got >= goal else 3.0))) * 4.0)
		draw_texture_rect_region(tex_arrow, Rect2(8.0 - bob, 150, 19, 15), Rect2(19, 0, 19, 15), UI.GREEN)
		Pix.text(self, Vector2(8, 176), "DOCK", 10, UI.TEXT)
	# what to do: one direction, until it is done
	if state == "fly" and not EventCard.is_open():
		var dir: Array = _direction(dk)
		if not dir.is_empty():
			_hint(320.0, String(dir[0]), int(dir[1]), UI.YELLOW)
	if help_open:
		_draw_help()
	else:
		pass
	# end banner
	if state != "fly":
		var tw: float = maxf(Pix.text_w(end_title, 20), Pix.text_w(msg, 10)) + 28.0
		Pix.panel(self, Rect2(floorf(320.0 - tw / 2.0), 58, tw, 46), UI.GREEN if docked else UI.RED)
		Pix.text_c(self, 320, 82, end_title, 20, UI.TEXT)
		Pix.text_c(self, 320, 96, msg, 10, UI.DIM)

func _draw_rad_meter() -> void:
	Pix.panel(self, Rect2(6, 29, 238, 16))
	_cell(tex_icons, Vector2(17, 37), 5, 0, Vector2(11, 11))
	Pix.text(self, Vector2(26, 40), "RADIATION", 10, UI.DIM)
	var cells: int = ceili(14.0 * rad)
	for i: int in 14:
		var col: int = 2 if i >= cells else (1 if rad > 0.5 and not rad_shield else 0)
		draw_texture_rect_region(tex_gauge, Rect2(88 + i * 4, 34, 4, 6), Rect2(col * 4, 0, 4, 6))
	Pix.text(self, Vector2(148, 40), "%d %%" % roundi(rad * 100.0), 10, UI.TEXT)
	Pix.text(self, Vector2(180, 40), "SHIELD ON" if rad_shield else "NO SHIELD", 10, UI.DIM if rad_shield else UI.YELLOW)

## A verified fact about this world (Data), bottom left. The keys sit on the "?" panel.
func _draw_fact() -> void:
	var facts: Array = Game.dest()["facts"]
	var fact: String = facts[int(t / 9.0) % facts.size()]
	var lines: PackedStringArray = _wrap(fact, 72)
	var fw: float = 0.0
	for line: String in lines:
		fw = maxf(fw, Pix.text_w(line, 10))
	var ph: float = 8.0 + lines.size() * 10.0
	Pix.panel(self, Rect2(6, 354.0 - ph, fw + 12.0, ph))
	var fy: float = 354.0 - ph + 11.0
	for line: String in lines:
		Pix.text(self, Vector2(12, fy), line, 10, UI.TEXT if fy < 340.0 else UI.DIM)
		fy += 10.0

## Word wrap to `n` characters a line (the font is fixed-width).
func _wrap(s: String, n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: String = ""
	for word: String in s.split(" "):
		if cur != "" and cur.length() + 1 + word.length() > n:
			out.append(cur)
			cur = word
		else:
			cur = word if cur == "" else cur + " " + word
	out.append(cur)
	return out

## The one thing to do now. Each stays until the player has done it.
func _direction(dk: float) -> Array:
	var touch: bool = DisplayServer.is_touchscreen_available()
	var low_fuel: bool = fuel < fuel_max * 0.3 and dk < -12.0 and got > 0
	if thrust_time < 0.6:
		return ["HOLD THRUST" if touch else "HOLD UP TO THRUST", 0]
	if low_fuel and int(t * 3.0) % 3 != 0:
		return ["LOW FUEL: FLY BACK AND DOCK", -1]
	if got == 0:
		return ["FLY RIGHT: GRAB THE GLOWING %s" % sk["grain"], 1]
	if got < goal:
		return ["GRAB THE GLOWING %s: %d OF %d" % [sk["grain"], got, goal], 1]
	return ["FLY BACK AND DOCK", -1]

func _draw_help() -> void:
	var x: float = 296.0
	var y: float = 262.0
	Pix.panel(self, Rect2(x, y, 242, 80))
	Pix.text(self, Vector2(x + 8, y + 14), "CONTROLS", 10, UI.TEXT)
	var kx: float = x + 8.0
	Pix.key_hint(self, Vector2(kx, y + 20), "UP", "OR W OR SPACE: THRUST")
	var kw: float = Pix.keycap(self, Vector2(kx, y + 38), "<") + 2.0
	Pix.key_hint(self, Vector2(kx + kw, y + 38), ">", "OR A D: STEER")
	Pix.text(self, Vector2(x + 8, y + 62), "DOCK: GO SLOWLY UNDER THE PORT", 10, UI.DIM)
	Pix.text(self, Vector2(x + 8, y + 72), "CLOSE: ? OR H", 10, UI.DIM)

func _gem_flying() -> bool:
	for e: Dictionary in gems:
		if e["hud"]:
			return true
	return false

func _groove(x: float) -> void:
	draw_rect(Rect2(x, 10, 1, 12), Color("05070e"))
	draw_rect(Rect2(x + 1, 10, 1, 12), Color("2a3352"))

## A big instruction with an arrow that nudges the way to go.
func _hint(cx: float, s: String, dir: int, c: Color) -> void:
	var tw: float = Pix.text_w(s, 20)
	var nudge: float = floorf(absf(sin(t * 5.0)) * 5.0) * dir
	Pix.text_c(self, cx, 62, s, 20, c)
	if dir == 0:
		return
	var ax: float = cx + tw / 2.0 + 8.0 if dir > 0 else cx - tw / 2.0 - 27.0
	draw_texture_rect_region(tex_arrow, Rect2(floorf(ax + nudge), 47, 19, 15), Rect2(0 if dir > 0 else 19, 0, 19, 15), c)

# ---------------------------------------------------------------- screenshot set-ups (harmless in the game)

func _debug_at(p: Vector2, v: Vector2, samples: int) -> void:
	pos = p
	vel = v
	got = samples
	t = 12.0
	thrust_time = 1.0
	ev_shown = 2    # no decision card in the screenshot, unless debug_event opens one
	if got >= goal:
		goal_t = t - 1.0
	for i: int in mini(samples, ice.size()):
		ice[i * 3 % ice.size()]["taken"] = true
	cam_x = clampf(pos.x - 320.0 + clampf(vel.x * 0.45, -70.0, 70.0), 0.0, WORLD - 640.0)

## A boulder of sheet `m` or bigger with nothing else near the point `off` away from it.
func _debug_rock(m: int, off: Vector2) -> int:
	var best: int = 0
	for i: int in rocks.size():
		var p: Vector2 = _rock_pos(rocks[i]) + off
		var clear: bool = int(rocks[i]["m"]) >= m
		for k: int in rocks.size():
			if k != i and p.distance_to(_rock_pos(rocks[k])) < float(rocks[k]["r"]) + 70.0:
				clear = false
		if clear:
			return i
		if int(rocks[i]["m"]) > int(rocks[best]["m"]):
			best = i
	return best

## The start: still at the port, the first direction on screen.
func debug_start() -> void:
	t = 1.0
	freeze_at = 1.2

## Mid ring in the middle of the samples (Neptune: inside a bright clump).
func debug_samples() -> void:
	var s: Vector2 = ice[ice.size() / 3]["p"]
	_debug_at(s + Vector2(-70, 6), Vector2(70, -8), 1)
	freeze_at = t + 0.2

## Mid ring, a boulder on a collision course.
func debug_mid() -> void:
	var off: Vector2 = Vector2(-96, -30)
	_debug_at(_rock_pos(rocks[_debug_rock(3, off)]) + off, Vector2(95, 26), 2)
	hold["u"] = true
	hold["r"] = true
	freeze_at = t + 0.3

## The moment a boulder hits the hull.
func debug_hit() -> void:
	var r: Dictionary = rocks[_debug_rock(3, Vector2(-40, -6))]
	_debug_at(_rock_pos(r) + Vector2(-float(r["r"]) - 20.0, -6), Vector2(90, 10), 3)
	freeze_at = t + 0.1

## Carrying the samples home, hull hurt.
func debug_carry() -> void:
	var p: Vector2 = Vector2(700, 168)
	while p.x > 420.0 and not _free_of_rocks(p, 60.0, 34.0):
		p.x -= 20.0
	_debug_at(p, Vector2(-110, -6), goal)
	hp = 1
	hold["l"] = true
	hold["u"] = true
	freeze_at = t + 0.6

## Docked: latched, samples going up.
func debug_dock() -> void:
	_debug_at(DOCK + Vector2(6, 52), Vector2(0, -20), goal)
	freeze_at = t + 1.6

## Smashed by a boulder.
func debug_fail() -> void:
	var r: Dictionary = rocks[_debug_rock(2, Vector2(-40, 4))]
	_debug_at(_rock_pos(r) + Vector2(-float(r["r"]) - 18.0, 4), Vector2(100, 0), 4)
	hp = 1
	freeze_at = t + 0.3

## Lost in the atmosphere.
func debug_burn() -> void:
	_debug_at(Vector2(900, 328), Vector2(30, 40), 1)
	freeze_at = t + 0.5

## Deep in the planet's shadow at the far end of the ring.
func debug_shadow() -> void:
	_debug_at(Vector2(1480, 150), Vector2(60, 10), 3)
	hold["u"] = true
	freeze_at = t + 0.4

## Radiation high: the meter, the static, the sparks (without the shield the controls drop out).
func debug_rad() -> void:
	rad_on = true
	_debug_at(Vector2(760, 196), Vector2(70, -6), 2)
	rad = 0.78
	glitch = 0.5
	hold["r"] = true
	freeze_at = t + 0.2

## Fly without the radiation shield (a smoke test of the failure).
func debug_noshield() -> void:
	rad_shield = false
	rad = 0.6

## The radiation killed the electronics.
func debug_fry() -> void:
	rad_on = true
	rad_shield = false
	_debug_at(Vector2(900, 200), Vector2(60, 0), 2)
	rad = 0.999
	freeze_at = t + 0.9

## A decision card open over the drone (a site event of this world; `id` picks another).
func debug_event() -> void:
	_debug_at(Vector2(640, 196), Vector2(60, -6), 2)
	ev_shown = 0
	var ev: Dictionary = Game.next_event("site")
	if ev.is_empty():
		ev = Game.event_by_id("ring_cross")
	_open_event(ev)

## The card, its outcome shown.
func debug_event_result() -> void:
	debug_event()
	var cards: Array = get_children().filter(func(c: Node) -> bool: return c.has_method("_choose"))
	if not cards.is_empty():
		cards[0].call("_choose", 0)

## The "?" list of controls.
func debug_help() -> void:
	_debug_at(Vector2(520, 196), Vector2(60, -6), 1)
	help_open = true
	freeze_at = t + 0.2

## Fly the whole run by itself (out along the ring, back when the slots are full, dock): a smoke test. 3x speed.
func debug_auto() -> void:
	auto = true
	Engine.time_scale = 3.0

func _auto_card() -> void:
	for c: Node in get_children():
		if not c.has_method("_choose") or float(c.get("age")) < 0.6:
			continue
		if (c.get("result") as Dictionary).is_empty():
			var ev: Dictionary = c.get("ev")
			for i: int in (ev["choices"] as Array).size():
				if bool(Game.event_choice(ev, i)["can"]):
					c.call("_choose", i)
					return
		else:
			c.call("_continue")

func _autopilot() -> void:
	var home: bool = got >= goal
	var want_y: float = 164.0 if home else 196.0
	if not home and skin == "uranus":
		want_y = URANUS_LANES[int(pos.x / 400.0) % 2]
	# steer round a boulder that is about to be in the way
	for r: Dictionary in rocks:
		var rp: Vector2 = _rock_pos(r)
		var rr: float = float(r["r"]) + BODY_R + 12.0
		var dx: float = rp.x - pos.x
		if absf(dx) < 100.0 + rr and absf(rp.y - want_y) < rr + 6.0:
			want_y = rp.y - rr if rp.y - rr > 172.0 or home else rp.y + rr
			if want_y < 150.0:
				want_y = rp.y + rr
	var want_vx: float = clampf((DOCK.x - pos.x) * 0.8, -110.0, 110.0) if home else 90.0
	hold.clear()
	if pos.y + vel.y * 0.45 > want_y:
		hold["u"] = true
	if vel.x < want_vx - 6.0:
		hold["r"] = true
	elif vel.x > want_vx + 6.0:
		hold["l"] = true

func _fly_keys() -> Dictionary:
	if jobs and not Net.owns("science") and not auto:
		return remote.get("science", {})
	return {
		"up": hold.has("u") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE),
		"left": hold.has("l") or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A),
		"right": hold.has("r") or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D),
	}

func _job_input(ev: InputEvent) -> void:
	if not jobs:
		return
	var k: InputEventKey = ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var n: int = k.keycode - KEY_1   # keys 1-9, then 0 for the tenth
	if k.keycode == KEY_0:
		n = 9
	if state == "downlink":
		if Net.owns("comms"):
			if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
				_dl_press_send()
			elif n >= 0 and n < _dl_items().size():
				_dl_toggle(n)
	elif Net.owns("engineer") and n >= 0 and n < Data.DRONE_THROTTLE.size():
		if driver:
			throttle = n
		else:
			remote["throttle"] = n
		Audio.play("ui_tab")

## What the Comms officer can send: one item per ice sample caught (its kind from the grain), then the photos.

func _dl_items() -> Array:
	var dd: Dictionary = Data.DRONE_DOWNLINK
	var kinds: Array = dd["samples"]
	var out: Array = []
	for v: Variant in got_kinds.slice(0, mini(got, int(dd["max_samples"]))):
		out.append(kinds[clampi(int(v), 0, kinds.size() - 1)])
	out.append_array(dd["photos"])
	return out

func _dl_used() -> int:
	var items: Array = _dl_items()
	var n: int = 0
	for i: Variant in dl_sel:
		if int(i) < items.size():
			n += int(items[int(i)]["size"])
	return n

func _dl_pts() -> int:
	var items: Array = _dl_items()
	var n: int = 0
	for i: Variant in dl_sel:
		if int(i) < items.size():
			n += int(items[int(i)]["pts"])
	return n

## Comms: picks or drops an item, within the downlink limit. Online the host applies it.

func _dl_toggle(i: int) -> void:
	if state != "downlink" or not Net.owns("comms") or i < 0 or i >= _dl_items().size():
		return
	if not driver:
		var want: Array = (remote.get("dl", dl_sel) as Array).duplicate()
		if want.has(i):
			want.erase(i)
		else:
			want.append(i)
		remote["dl"] = want
		Audio.play("ui_tab")
		return
	if dl_sel.has(i):
		dl_sel.erase(i)
		Audio.play("ui_close", -4.0)
	elif _dl_used() + int(_dl_items()[i]["size"]) <= int(Data.DRONE_DOWNLINK["limit"]):
		dl_sel.append(i)
		Audio.play("ui_tab")
	else:
		Audio.play("ui_deny", -4.0)

func _dl_press_send() -> void:
	if state != "downlink" or not Net.owns("comms"):
		return
	if driver:
		dl_send = true
	else:
		remote["send"] = true
	Audio.play("confirm", -4.0)

## Host: waits for the Comms officer's SEND, or sends the current choice when time is up.

func _dl_tick(delta: float) -> void:
	dl_t += delta
	if dl_send or dl_t >= float(Data.DRONE_DOWNLINK["secs"]):
		dl_done = true
		state = "done"
		end_t = t   # leaves on the next frame, with the downlink choice
		Audio.play("radio_blip", -4.0)

## Host: applies another player's downlink choice, checked against the limit.

func _dl_apply(want: Array) -> void:
	var items: Array = _dl_items()
	var sel: Array = []
	var used: int = 0
	for v: Variant in want:
		var i: int = int(v)
		if i >= 0 and i < items.size() and not sel.has(i) and used + int(items[i]["size"]) <= int(Data.DRONE_DOWNLINK["limit"]):
			sel.append(i)
			used += int(items[i]["size"])
	dl_sel = sel

## Not the host: this player's controls, about 20 times a second, one message per role they hold.

func _send_input(delta: float) -> void:
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 1.0 / float(Data.NET_RATES["input_hz"])
	if Net.owns("science") and state == "fly":
		Net.send("input", {"screen": "probe", "role": "science", "keys": _fly_keys()})
	if Net.owns("engineer") and remote.has("throttle"):
		Net.send("input", {"screen": "probe", "role": "engineer", "keys": {"throttle": int(remote["throttle"])}})
	if Net.owns("comms") and state == "downlink" and (remote.has("dl") or remote.has("send")):
		Net.send("input", {"screen": "probe", "role": "comms", "keys": {"pick": remote.get("dl", dl_sel), "send": bool(remote.get("send", false))}})

## Host: the simulation for everyone else to draw, about 15 times a second (force with delta >= 1).

func _send_state(delta: float) -> void:
	if not Net.is_online():
		return
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 1.0 / float(Data.NET_RATES["state_hz"])
	var taken: Array = []
	for i: int in ice.size():
		if ice[i]["taken"]:
			taken.append(i)
	Net.send("state", {"screen": "probe", "s": state, "t": t, "px": pos.x, "py": pos.y, "vx": vel.x, "vy": vel.y, "fuel": fuel, "hp": hp,
		"got": got, "gk": got_kinds, "ice": taken, "inv": invuln, "thr": thrusting, "steer": steer, "th": throttle,
		"dk": docked, "lt": latched, "sent": sent, "ek": end_kind, "et": end_title, "msg": msg, "dl": dl_sel, "dlt": dl_t, "rad": rad, "glitch": glitch, "data": data, "events": ev_shown})

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
	if String(d.get("screen", "")) != "probe":
		return
	if kind == "input" and driver:
		var role: String = String(d.get("role", ""))
		if not Game.sender_owns(from_id, role) or not (d.get("keys") is Dictionary):
			return
		var keys: Dictionary = d["keys"]
		match role:
			"science":
				remote["science"] = keys
			"engineer":
				throttle = clampi(int(keys.get("throttle", throttle)), 0, Data.DRONE_THROTTLE.size() - 1)
			"comms":
				if state == "downlink":
					if keys.get("pick") is Array:
						_dl_apply(keys["pick"])
					if bool(keys.get("send", false)):
						dl_send = true
	elif kind == "state" and not driver and Game.sender_is_host(from_id):
		_apply_state(d)

## Not the host: take the host's simulation, with the sounds of a pickup, a hit or the end.

func _apply_state(d: Dictionary) -> void:
	var ns: String = String(d.get("s", state))
	if state == "fly" and ns != "fly":
		_end(bool(d.get("dk", false)), String(d.get("et", "")), String(d.get("msg", "")), String(d.get("ek", "")))
	state = ns
	t = float(d.get("t", t))
	rad = float(d.get("rad", rad))
	glitch = float(d.get("glitch", glitch))
	data = float(d.get("data", data))
	ev_shown = int(d.get("events", ev_shown))
	pos = Vector2(float(d.get("px", pos.x)), float(d.get("py", pos.y)))
	vel = Vector2(float(d.get("vx", vel.x)), float(d.get("vy", vel.y)))
	fuel = float(d.get("fuel", fuel))
	var nhp: int = int(d.get("hp", hp))
	if nhp < hp:
		Audio.play("hit")
		trauma = minf(1.0, trauma + 0.7)
		flash_t = 0.12
		hull_flash = 0.5
	hp = nhp
	var ngot: int = int(d.get("got", got))
	if ngot > got:
		Audio.play("pickup", -3.0, 1.0 + ngot * 0.06)
		floaters.append({"p": pos, "age": 0.0, "s": "+1 %s" % sk["grain"], "bad": false})
	got = ngot
	if d.get("gk") is Array:
		got_kinds = (d["gk"] as Array).map(func(v: Variant) -> int: return int(v))
	if d.get("ice") is Array:
		for i: Variant in d["ice"]:
			if int(i) >= 0 and int(i) < ice.size():
				ice[int(i)]["taken"] = true
	invuln = float(d.get("inv", invuln))
	thrusting = bool(d.get("thr", false))
	steer = int(d.get("steer", 0))
	throttle = int(d.get("th", throttle))
	docked = bool(d.get("dk", docked))
	latched = bool(d.get("lt", latched))
	sent = int(d.get("sent", sent))
	if d.get("dl") is Array:
		dl_sel = (d["dl"] as Array).map(func(v: Variant) -> int: return int(v))   # JSON numbers come back as floats
	dl_t = float(d.get("dlt", dl_t))

## The port reels the drone in, the latch arms close, then the samples go up one by one.

func _who(role: String) -> String:
	if Net.owns(role):
		return "YOU"
	if Game.cpu(role):
		return "COMPUTER"
	var h: String = Game.holder(role)
	return h.substr(0, 12) if h != "" else Game.role_name(role)

## Multiplayer: who flies, and the Engineer's throttle.

func _draw_jobs() -> void:
	var r: Rect2 = Rect2(6, 30, 214, 32)
	Pix.panel(self, r)
	var thr: Dictionary = Data.DRONE_THROTTLE[throttle]
	var rows: Array = [["science", "PILOT", _who("science"), ""],
		["engineer", "THROTTLE", _who("engineer"), String(thr["name"]) + ("  KEYS 1-3" if Net.owns("engineer") else "")]]
	for i: int in rows.size():
		var row: Array = rows[i]
		var y: float = r.position.y + 4.0 + i * 12.0
		var rc: Color = Game.role_color(row[0])
		draw_rect(Rect2(r.position.x + 6, y + 3, 7, 7), rc)
		Pix.text(self, Vector2(r.position.x + 17, y + 10), row[1], 10, UI.TEXT)
		Pix.text(self, Vector2(r.position.x + 70, y + 10), row[2], 10, rc)
		var st: String = row[3]
		Pix.text(self, Vector2(r.end.x - 6.0 - Pix.text_w(st, 10), y + 10), st, 10, UI.YELLOW if throttle != 1 else UI.DIM)

func _dl_row(i: int) -> Rect2:
	return Rect2(178, 140 + i * 12, 284, 12)

## Multiplayer: the Comms officer's downlink choice after docking.

func _draw_downlink() -> void:
	var items: Array = _dl_items()
	var dd: Dictionary = Data.DRONE_DOWNLINK
	var r: Rect2 = Rect2(170, 112, 300, 46 + items.size() * 12)
	Pix.panel(self, r, Game.role_color("comms"), Color(0.03, 0.04, 0.08, 0.95))
	var left: int = ceili(maxf(0.0, float(dd["secs"]) - dl_t))
	Pix.text(self, r.position + Vector2(8, 13), "DOWNLINK TO EARTH: %d / %d UNITS" % [_dl_used(), int(dd["limit"])], 10, Game.role_color("comms"))
	Pix.text(self, Vector2(r.end.x - 8.0 - Pix.text_w("%d s" % left, 10), r.position.y + 13), "%d s" % left, 10, UI.DIM)
	Pix.text(self, r.position + Vector2(8, 25), "Comms officer: %s" % _who("comms"), 10, UI.DIM)
	for i: int in items.size():
		var it: Dictionary = items[i]
		var rr: Rect2 = _dl_row(i)
		var on: bool = dl_sel.has(i)
		if on:
			draw_rect(rr, Color(Game.role_color("comms"), 0.18))
		Pix.text(self, rr.position + Vector2(2, 10), "%d" % ((i + 1) % 10), 10, UI.YELLOW)
		Pix.text(self, rr.position + Vector2(16, 10), String(it["name"]), 10, UI.TEXT if on else UI.DIM)
		Pix.text(self, rr.position + Vector2(150, 10), "size %d" % int(it["size"]), 10, UI.DIM)
		Pix.text(self, rr.position + Vector2(206, 10), "%d pts" % int(it["pts"]), 10, UI.GREEN if on else UI.DIM)
		if on:
			Pix.text(self, rr.position + Vector2(262, 10), "SEND", 10, UI.GREEN)
	var foot: String = "KEYS 1-0 OR CLICK TO PICK.  ENTER SENDS." if Net.owns("comms") else "THE COMMS OFFICER IS PICKING."
	Pix.text_c(self, 320, r.end.y - 6.0, foot, 10, UI.TEXT)

func _gui_input(ev: InputEvent) -> void:
	var mb: InputEventMouseButton = ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if state == "downlink" and Net.owns("comms") and jobs:
		for i: int in _dl_items().size():
			if _dl_row(i).has_point(mb.position):
				_dl_toggle(i)

