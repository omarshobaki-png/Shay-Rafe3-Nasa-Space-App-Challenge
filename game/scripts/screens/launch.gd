extends Control
## Launch: the ascent the player flies (throttle through max-Q, staging, fairing, engine cut, deployment).
## Contract with main.gd and flight.gd (keep it):
##   - this screen calls Game.phase_launch() exactly once (it decides whether the rocket can lift the ship);
##   - on success it sets Game.run["launched"] = true and calls Game.goto("flight"); flight then starts at
##     the cruise and never calls phase_launch itself;
##   - on failure it shows what happened, then Game.finish() and Game.goto("report").
## phase_launch() is called at ignition. A ship it rejects still lifts off, but its upper stage runs dry
## short of orbit speed (the published limits are about reaching the destination, not leaving the pad).
## Art: res://art/launch (tools/art/gen_launch.py) and, read only, res://art/flight (pad, sky, clouds).
##
## ASCENT MODEL.
## Real: gravity falls with the square of the distance from Earth's centre (6,371 km); air density is
## 1.225 kg/m3 at sea level and falls exponentially with a scale height of 8.5 km; the push of the air on
## the rocket is the dynamic pressure q = 1/2 rho v^2; thrust and propellant flow follow each engine's
## specific impulse (Isp), which grows from sea level to vacuum; Falcon 9 and Falcon Heavy stage masses,
## thrusts and Isp are SpaceX's published figures, rounded; circular orbit speed at 200 km is 7.79 km/s.
## Max-Q near 11-13 km at 35-43 kPa at full throttle (lower and earlier when throttled back) and the
## fairing release above 100 km come out of the model; they are not scripted.
## Game rules: flat 2D flight; a fixed pitch program (the flight computer steers, the player sets the
## throttle and calls the staged events); one drag coefficient (0.32); Vulcan and Electron numbers are game
## estimates shaped like the real rockets (Vulcan's upper stage is stronger than the real Centaur V to keep
## the climb short); time runs 1 to 24 times faster than real; the ascent may use what a clean ascent
## needs plus a reserve (8% on NORMAL, 18% EASY, 3.9% HARD) of the upper stage's propellant (the rest is
## kept for the departure burn), and what a sloppy ascent needs beyond that is paid by the spacecraft's
## own tank through the rocket equation (Game.burn); the red line for max-Q (92% of the full-throttle peak
## on NORMAL) and the stress it does are game rules scaled by the difficulty.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")

const G0: float = 9.80665
const RE: float = 6371000.0
const RHO0: float = 1.225
const H_SCALE: float = 8500.0
const CD: float = 0.32
const ORBIT_ALT: float = 200000.0
const ORBIT_V: float = 7790.0
const FAIRING_ALT: float = 100000.0
const LADDER_TOP: float = 210000.0
const THR_BUCKET: float = 0.8   # real rockets throttle down through max-Q (the Space Shuttle to 65-72%)
const Q_ASK: float = 0.7        # game rule: the throttle-back direction shows at 70% of the red line

const RX: float = 336.0       # rocket centre x; these match tools/art/gen_flight.py (the pad art)
const BASE_Y: float = 262.0
const DECK_Y: float = 272.0
const CON_Y: float = 298.0
const SMOKE_WARM: Color = Color(1.0, 0.86, 0.72)
const SMOKE_COOL: Color = Color(0.80, 0.76, 0.90)
## Engine nozzles of each launcher sprite (art/parts/lv_*.png): x from the sprite's left edge, plume width.
## The first is the core; the others are boosters.
const NOZZLES: Dictionary = {"electron": [Vector2(6, 8)], "falcon9": [Vector2(11, 11)],
	"vulcan": [Vector2(17, 14), Vector2(7, 5), Vector2(28, 5)], "heavy": [Vector2(25, 11), Vector2(9, 11), Vector2(40, 11)]}
## Rows where each launcher comes apart: [fairing end, upper stage end]. Same numbers as gen_launch.py.
const CUTS: Dictionary = {"electron": [26, 36], "falcon9": [38, 67], "vulcan": [59, 77], "heavy": [38, 67]}
## Masses kg, thrust N (sea level for stage 1 and boosters), Isp s [sea level, vacuum], area m2 (front),
## hp = height (m) where the pitch program is nearly horizontal (game rule). "center": Falcon Heavy's centre
## core runs at this share of thrust while the side boosters burn (real: it throttles down to save fuel).
const LV: Dictionary = {
	"falcon9": {"s1_dry": 25600.0, "s1_prop": 395700.0, "s1_t": 7607000.0, "s1_isp": [283.0, 312.0],
		"s2_dry": 3900.0, "s2_prop": 92700.0, "s2_t": 981000.0, "s2_isp": 348.0, "fair": 1900.0, "area": 10.8, "hp": 155000.0, "center": 1.0, "boost": {}},
	"heavy": {"s1_dry": 25600.0, "s1_prop": 395700.0, "s1_t": 7607000.0, "s1_isp": [283.0, 312.0],
		"s2_dry": 3900.0, "s2_prop": 92700.0, "s2_t": 981000.0, "s2_isp": 348.0, "fair": 1900.0, "area": 32.0, "hp": 70000.0, "center": 0.55,
		"boost": {"n": 2, "dry": 22200.0, "prop": 395700.0, "t": 7607000.0, "isp": [283.0, 312.0], "solid": false}},
	"vulcan": {"s1_dry": 35000.0, "s1_prop": 380000.0, "s1_t": 4900000.0, "s1_isp": [310.0, 339.0],
		"s2_dry": 6000.0, "s2_prop": 54000.0, "s2_t": 600000.0, "s2_isp": 453.0, "fair": 4000.0, "area": 30.0, "hp": 85000.0, "center": 1.0,
		"boost": {"n": 6, "dry": 6500.0, "prop": 41000.0, "t": 1100000.0, "isp": [250.0, 275.0], "solid": true}},
	"electron": {"s1_dry": 1000.0, "s1_prop": 9250.0, "s1_t": 200000.0, "s1_isp": [311.0, 311.0],
		"s2_dry": 250.0, "s2_prop": 2050.0, "s2_t": 25800.0, "s2_isp": 343.0, "fair": 50.0, "area": 1.13, "hp": 90000.0, "center": 1.0, "boost": {}},
}

## One rocket in flight. Also flown ahead of time to find max-Q and to size the upper stage.
class Ascent extends RefCounted:
	var lv: Dictionary
	var pay: float
	var alt: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var t: float = 0.0
	var p1: float = 0.0
	var pb: float = 0.0
	var p2: float = 0.0
	var p2_min: float = 0.0   # kept for the departure burn after the ascent: the ascent cannot touch it
	var thr: float = 1.0
	var s1_on: bool = true
	var boost_on: bool = false
	var fair_on: bool = true
	var s2_lit: bool = false
	var s2_wait: float = 0.0
	var cut: bool = false
	var held: bool = true
	var q: float = 0.0
	var accel: float = 0.0

	func _init(lv_: Dictionary, pay_kg: float, p2_kg: float) -> void:
		lv = lv_
		pay = pay_kg
		p1 = float(lv["s1_prop"])
		p2 = p2_kg
		var b: Dictionary = lv["boost"]
		if not b.is_empty():
			boost_on = true
			pb = float(b["prop"]) * int(b["n"])

	func mass() -> float:
		var m: float = pay + float(lv["s2_dry"]) + p2
		if fair_on:
			m += float(lv["fair"])
		if s1_on:
			m += float(lv["s1_dry"]) + p1
		if boost_on:
			var b: Dictionary = lv["boost"]
			m += float(b["dry"]) * int(b["n"]) + pb
		return m

	func speed() -> float:
		return Vector2(vx, vy).length()

	func boost_burning() -> bool:
		return boost_on and pb > 0.0

	func s2_burning() -> bool:
		return not s1_on and s2_lit and not cut and p2 > p2_min

	func burning() -> bool:
		return (s1_on and (p1 > 0.0 or boost_burning())) or s2_burning()

	## Thrust (N) at throttle th; with dt > 0 it also burns the propellant.
	func thrust(th: float, dt: float) -> float:
		var pa: float = exp(-alt / H_SCALE)
		var f: float = 0.0
		if s1_on:
			var isp1: Array = lv["s1_isp"]
			if p1 > 0.0:
				var isp: float = lerpf(float(isp1[1]), float(isp1[0]), pa)
				var fi: float = float(lv["s1_t"]) * th * (float(lv["center"]) if boost_burning() else 1.0) * isp / float(isp1[0])
				f += fi
				p1 = maxf(0.0, p1 - fi / (isp * G0) * dt)
			if boost_burning():
				var b: Dictionary = lv["boost"]
				var ispb: Array = b["isp"]
				var isp2: float = lerpf(float(ispb[1]), float(ispb[0]), pa)
				var fb: float = float(b["t"]) * int(b["n"]) * (1.0 if bool(b["solid"]) else th) * isp2 / float(ispb[0])
				f += fb
				pb = maxf(0.0, pb - fb / (isp2 * G0) * dt)
		elif s2_burning():
			var f2: float = float(lv["s2_t"]) * th
			f += f2
			p2 = maxf(p2_min, p2 - f2 / (float(lv["s2_isp"]) * G0) * dt)
		return f

	## The least throttle that still climbs faster than gravity pulls (flight software limit; game rule).
	func floor_thr() -> float:
		if not s1_on:
			return 0.4
		var full: float = thrust(1.0, 0.0)
		if full <= 0.0:
			return 0.4
		return clampf(ceilf(1.08 * mass() * G0 / full * 10.0) / 10.0, 0.4, 1.0)

	func step(dt: float) -> void:
		if not s1_on and not s2_lit:
			s2_wait -= dt
			if s2_wait <= 0.0:
				s2_lit = true
		var pa: float = exp(-alt / H_SCALE)
		var v: float = speed()
		q = 0.5 * RHO0 * pa * v * v
		var f: float = thrust(thr, dt)
		var m: float = mass()
		accel = f / m
		if held:
			return
		var r: float = RE + alt
		var g: float = G0 * pow(RE / r, 2.0)
		var th: float = 0.0
		if s1_on:
			if alt > 800.0:
				th = deg_to_rad(minf(85.0, 90.0 * pow((alt - 800.0) / float(lv["hp"]), 0.55)))
				if vy < 400.0 and accel > 0.0:  # flight computer: never tip over so far that the climb stalls
					th = minf(th, acos(clampf(1.1 * (g - vx * vx / r) / accel, 0.0, 1.0)))
		else:  # closed-loop guidance: level off at the orbit height
			var vy_des: float = clampf((ORBIT_ALT - alt) / 60.0, -150.0, vy + 50.0)
			var ay_des: float = (vy_des - vy) / 15.0
			var c: float = clampf((ay_des + g - vx * vx / r) / maxf(accel, 0.1), -0.5, 0.98)
			th = acos(c)
		var drag: float = q * CD * float(lv["area"]) / m
		var dx: float = vx / v if v > 1.0 else 0.0
		var dy: float = vy / v if v > 1.0 else 1.0
		vx += (accel * sin(th) - drag * dx) * dt
		vy += (accel * cos(th) - g + vx * vx / r - drag * dy) * dt
		alt += vy * dt
		if alt < 0.0:
			alt = 0.0
			vy = maxf(vy, 0.0)
		t += dt

	func drop_boosters() -> void:
		boost_on = false
		pb = 0.0

	func drop_stage() -> void:
		s1_on = false
		thr = 1.0       # game rule: the upper stage always burns at full thrust
		boost_on = false
		s2_wait = 2.0   # real: the second stage lights a few seconds after separation

# ------------------------------------------------------------------ state

var a: Ascent = null
var lv: Dictionary = {}
var lv_id: String = ""
var mode: String = "pad"    # pad, count, fly, coast, cam, deploy, done, fail
var in_cam: bool = false
var count_t: float = 0.0
var mode_t: float = 0.0
var t: float = 0.0
var speed_mult: float = 1.0
var auto: bool = false
var auto_noq: bool = false
var help_open: bool = false
var hold_ev: String = ""        # debug: the autopilot leaves this staged event to the caller

var seq: Array[String] = []
var ev_i: int = 0
var due_since: float = -1.0      # sim time when the current staged event became due
var q_red: float = 30000.0
var q_peak_alt: float = 12000.0
var meco_alt: float = 80000.0
var q_seen: float = 0.0
var q_seen_alt: float = 0.0
var maxq_task: int = 0           # 0 not yet, 1 asked to throttle down, 2 holding, 3 asked to throttle up, 4 done
var maxq_missed: bool = false
var dmg: float = 0.0
var alarm_t: float = 0.0
var doomed: bool = false
var p1_0: float = 1.0
var pb_0: float = 0.0
var p2_0: float = 1.0
var p2_clean: float = 1.0
var reserve: float = 0.08
var band: float = 1.0
var dmg_mult: float = 1.0
var ship_dv: float = 0.0         # m/s the spacecraft must make up
var notes: Array[Array] = []      # [ok, text] for the log at the end
var flash_msg: String = ""
var flash_t: float = 9.0
var fail_title: String = ""
var fail_why: String = ""
var fail_real: String = ""
var dep_t: float = 0.0
var stowed: Dictionary = {}
var groups: Array = []
var ship_rect: Rect2 = Rect2()
var hv: float = 0.0
var last_h: float = 0.0
var stage_t: float = -1.0        # real seconds since stage 1 separated (the camera recentres)
var cut_v: float = 0.0

# effects
var parts: Array[Dictionary] = []
var falling: Array[Dictionary] = []
var spawn_acc: float = 0.0
var shake: float = 0.0
var flash_age: float = 9.0
var boom_age: float = -1.0
var ign_t: float = -1.0

# log ticker
var shown: int = 0
var lines: Array[Dictionary] = []
var new_t: float = 99.0

# textures (kept in members so they are never freed)
var tex_rocket: Texture2D = null
var tex_space: Texture2D = null
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
var tex_cam: Texture2D = null
var tex_payload: Texture2D = null
var tex_clouds_near: Array[Texture2D] = []
var tex_clouds_far: Array[Texture2D] = []
var pieces: Dictionary = {}       # name -> Texture2D (launcher-sized canvas)
var centers: Dictionary = {}      # name -> Vector2 centre of the piece's pixels
var tumbles: Dictionary = {}      # name -> Texture2D strip of 16 square frames
var nozzles: Array[Vector2] = []

# on-screen buttons (touch and mouse)
const BTN_ACT: Rect2 = Rect2(516, 266, 118, 27)
const BTN_UP: Rect2 = Rect2(12, 158, 62, 17)
const BTN_DN: Rect2 = Rect2(78, 158, 62, 17)
const BTN_HELP: Rect2 = Rect2(614, 6, 20, 17)

func _ready() -> void:
	clip_contents = true
	_setup()

func _f(name: String) -> Texture2D:
	return Pix.img("flight/" + name)

func _setup() -> void:
	lv_id = Game.rocket_id if LV.has(Game.rocket_id) else "falcon9"
	lv = LV[lv_id]
	tex_rocket = ShipKit.launcher(lv_id)
	tex_space = Pix.img("bg_space")
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
	tex_cam = Pix.img("launch/cam_stage_dark" if lv_id == "electron" else "launch/cam_stage")
	tex_payload = Pix.img("launch/payload_" + lv_id)
	tex_clouds_near.clear()
	tex_clouds_far.clear()
	for i: int in 3:
		tex_clouds_near.append(_f("cloud_near_%d" % i))
		tex_clouds_far.append(_f("cloud_far_%d" % i))
	pieces.clear()
	tumbles.clear()
	centers.clear()
	var names: Array[String] = ["fair_l", "fair_r", "upper", "core"]
	var nb: int = 0 if (lv["boost"] as Dictionary).is_empty() else (3 if lv_id == "vulcan" else 2)
	for i: int in nb:
		names.append("boost%d" % i)
	for n: String in names:
		var tx: Texture2D = Pix.img("launch/piece_%s_%s" % [lv_id, n])
		if tx == null:
			continue
		pieces[n] = tx
		centers[n] = Rect2(tx.get_image().get_used_rect()).get_center()
		if n != "upper":
			tumbles[n] = Pix.img("launch/tumble_%s_%s" % [lv_id, n])
	nozzles.clear()
	for v: Vector2 in NOZZLES[lv_id]:
		nozzles.append(v)
	band = Game.diff("burn_band")           # 1.5 EASY, 1.0 NORMAL, 0.7 HARD: how wide every window is
	dmg_mult = Game.diff("surface_hazards") # 0.6 / 1.0 / 1.4: how much a mistake hurts
	reserve = 0.08 * band * band  # 18% EASY, 8% NORMAL, 3.9% HARD
	_presim()
	a = Ascent.new(lv, _pay(), float(lv["s2_prop"]))
	_ascent_fuel(p2_clean * (1.0 + reserve))
	p1_0 = a.p1
	pb_0 = a.pb
	seq.clear()
	seq.append("ignite")
	if a.boost_on:
		seq.append("boosters")
	for e: String in ["stage", "fairing", "cutoff", "deploy"]:
		seq.append(e)
	_setup_ship()
	_update_log(true)

## The upper stage is full; the ascent may use only `usable` kg of it. The rest is the departure burn
## toward the destination after the parking orbit (real: interplanetary upper stages restart in orbit).
func _ascent_fuel(usable: float) -> void:
	a.p2_min = maxf(0.0, a.p2 - usable)
	p2_0 = a.p2 - a.p2_min

## Mass the model carries: the ship, capped at what fits the model (a ship far over the limit is caught
## by phase_launch anyway).
func _pay() -> float:
	var m0: float = float(lv["s1_dry"]) + float(lv["s1_prop"]) + float(lv["s2_dry"]) + float(lv["s2_prop"])
	return clampf(float(Game.run.get("mass", 1000.0)), 10.0, 0.03 * m0)

## Two flights ahead of time: full throttle (where max-Q peaks sets the red line) and a clean ascent
## (sets the upper stage's propellant and where staging shows on the ladder).
func _presim() -> void:
	var f: Ascent = Ascent.new(lv, _pay(), float(lv["s2_prop"]))
	f.held = false
	var peak: float = 0.0
	while f.t < 260.0 and f.alt < 45000.0:
		f.step(0.2)
		if f.q > peak:
			peak = f.q
			q_peak_alt = f.alt
	q_red = peak * (1.0 - 0.08 / band)
	p2_clean = _clean_use(float(lv["s2_prop"]))

## Flies the clean ascent with this much upper-stage propellant; returns what it used to reach orbit speed.
func _clean_use(p2_load: float) -> float:
	var c: Ascent = Ascent.new(lv, _pay(), p2_load)
	c.held = false
	var task: int = 0
	while c.t < 1500.0:
		if c.s1_on:
			if task == 0 and c.q > Q_ASK * q_red:
				task = 1
			if task == 1 and c.alt > q_peak_alt + 3000.0 and c.q < 0.6 * q_red:
				task = 2
			c.thr = THR_BUCKET if task == 1 else 1.0
		else:
			c.thr = 1.0
		if c.boost_on and c.pb <= 0.0:
			c.drop_boosters()
		if c.s1_on and c.p1 <= 0.0:
			meco_alt = c.alt
			c.drop_stage()
		if not c.s1_on and c.fair_on and c.alt >= FAIRING_ALT:
			c.fair_on = false
		if c.speed() >= ORBIT_V or (not c.s1_on and c.s2_lit and c.p2 <= 0.0):
			break
		c.step(0.2)
	return maxf(1.0, p2_load - c.p2)

## What folds out after deployment, in order: power, radio, instruments, robots. The rest is the stowed ship.
func _setup_ship() -> void:
	stowed = Game.build.duplicate()
	groups = []
	for cat: String in ["power", "comms", "science", "robot"]:
		var g: Array = []
		for id: String in Game.build:
			var p: Dictionary = Data.PARTS.get(id, {})
			if p.get("cat", "") != cat:
				continue
			if (cat == "power" and p.has("wh")) or (cat == "comms" and not p.has("rate")):
				continue  # batteries and recorders sit inside the bus
			g.append(id)
			stowed.erase(id)
		if not g.is_empty():
			groups.append(g)
	ship_rect = ShipKit.bounds(Game.build)

# ------------------------------------------------------------------ time

func _process(delta: float) -> void:
	_tick(delta * speed_mult)
	queue_redraw()

func _tick(dt: float) -> void:
	t += dt
	new_t += dt
	flash_t += dt
	flash_age += dt
	shake = maxf(0.0, shake - dt * 3.0)
	if boom_age >= 0.0:
		boom_age += dt
	if help_open:
		return
	mode_t += dt
	match mode:
		"count":
			_step_count(dt)
		"fly", "coast":
			_step_fly(dt)
		"deploy":
			_step_deploy(dt)
		"done":
			if mode_t > 0.6 and not bool(Game.run.get("launched", false)):
				Game.run["launched"] = true
				Audio.loop("thrust", false)
				Game.goto("flight")
				return
	if auto:
		_autopilot()
	_step_parts(dt)
	_step_falling(dt)
	_update_log(false)

func _set_mode(m: String) -> void:
	mode = m
	mode_t = 0.0

func _step_count(dt: float) -> void:
	var c0: float = count_t
	count_t += dt
	for i: int in 3:
		if c0 < float(i) and count_t >= float(i):
			Audio.play("countdown_beep", -5.0)
	var rw: float = tex_rocket.get_width()
	var rh: float = tex_rocket.get_height()
	if count_t < 2.4 and randf() < dt * 7.0:  # oxygen vapour drifting off the tanks
		_puff(Vector2(RX + rw * 0.5, BASE_Y - rh * randf_range(0.45, 0.6)), Vector2(randf_range(8, 20), randf_range(2, 10)), 1.4, 0, Color(0.95, 0.9, 1.0, 0.8), -6.0)
	if c0 < 2.4 and count_t >= 2.4:
		_ignite()
	if count_t >= 2.4:
		a.step(dt)  # the engines run up on the hold-down clamps
		_smoke(dt)
	if c0 < 3.0 and count_t >= 3.0:
		a.held = false
		Audio.play("launch", -2.0)
		Audio.play("countdown_beep", -4.0, 2.0)
		shake = 4.0
		_set_mode("fly")

func _ignite() -> void:
	ign_t = t
	Game.phase_launch()
	doomed = bool(Game.run.get("dead", false))
	if doomed:  # the stage can't reach orbit speed with this ship: it runs dry short of it
		_ascent_fuel(p2_clean * 0.8)
	Audio.play("ignition", -2.0)
	shake = 5.0
	flash_age = 0.0
	for i: int in 18:
		var sd: float = -1.0 if i % 2 == 0 else 1.0
		_spark(Vector2(RX + sd * 4.0, DECK_Y - 4.0), Vector2(sd * randf_range(50, 190), -randf_range(10, 110)), randf_range(0.35, 0.8), Color("ffb84d"))

## Time runs faster than real, slower around the moments the player must act.
func _warp() -> float:
	if mode == "coast":
		return 4.0
	var nx: String = _next()
	if _due(nx) and nx != "fairing":
		return 1.0
	if a.t < 6.0:
		return 1.5
	if maxq_task == 1:
		return 2.0
	if nx == "cutoff" and a.s2_burning():  # the last 3 real seconds before orbit speed run near real time
		var tgo: float = (ORBIT_V - a.speed()) / maxf(a.accel, 1.0)
		return clampf(tgo / 3.0, 1.0, 24.0)
	var km: float = a.alt / 1000.0
	if km < 22.0:
		return 3.0
	return clampf(3.0 + (km - 22.0) / 40.0 * 9.0, 3.0, 24.0 if not a.s1_on else 12.0)

func _step_fly(dt: float) -> void:
	var sim: float = dt * _warp()
	var n: int = maxi(1, ceili(sim / 0.1))
	var was_lit: bool = a.s2_lit
	for i: int in n:
		a.step(sim / n)
		_after_step(sim / n)
		if mode == "fail":
			return
	if not was_lit and a.s2_lit:
		Audio.play("ignition", -8.0, 1.5)
		flash_age = 0.0
	var h: float = _h_px()
	hv = (h - last_h) / maxf(dt, 0.001)
	last_h = h
	if stage_t >= 0.0:
		stage_t += dt
	var lit: bool = a.burning()
	Audio.loop("thrust", lit, -14.0 + 6.0 * a.thr)
	if lit:
		shake = maxf(shake, 1.6 * clampf(1.0 - a.alt / 30000.0, 0.0, 1.0))
	_smoke(dt)
	if mode == "fly" and a.q > q_red:
		alarm_t -= dt
		if alarm_t <= 0.0:
			alarm_t = 0.9
			Audio.play("alarm", -8.0)
	if mode == "coast" and mode_t > 1.6:
		_set_mode("cam")
		in_cam = true
		Audio.loop("thrust", false)
		Audio.play("radio_blip", -6.0)

## After each physics step: pressure damage, the max-Q directions, running out of fuel.
func _after_step(dt: float) -> void:
	if a.q > q_seen:
		q_seen = a.q
		q_seen_alt = a.alt
	if a.q > q_red and a.s1_on:
		dmg += (a.q / q_red - 1.0) * 40.0 * dmg_mult * dt
		if Game.difficulty == 0:
			dmg = minf(dmg, 95.0)  # EASY: the rocket complains but never breaks up
		if dmg >= 100.0:
			_breakup()
			return
	if a.s1_on:
		if maxq_task == 0 and a.q > Q_ASK * q_red:
			maxq_task = 2 if a.thr <= THR_BUCKET + 0.01 else 1
		if maxq_task == 1 and a.thr <= THR_BUCKET + 0.01:
			maxq_task = 2
		if (maxq_task == 1 or maxq_task == 2) and a.alt > q_peak_alt + 3000.0 and a.q < 0.6 * q_red:
			maxq_missed = maxq_task == 1
			maxq_task = 3
	if maxq_task == 3 and a.thr >= 0.99:
		maxq_task = 4
	if _due(_next()):
		if due_since < 0.0:
			due_since = a.t
	else:
		due_since = -1.0
	if mode == "fly" and not a.s1_on and a.s2_lit and a.p2 <= a.p2_min and not a.cut:
		_stage2_dry()

func _h_px() -> float:
	return 260.0 * log(1.0 + a.alt / 400.0)

# ------------------------------------------------------------------ staged events

func _next() -> String:
	return seq[ev_i] if ev_i < seq.size() else ""

func _due(ev: String) -> bool:
	match ev:
		"boosters":
			return a.pb <= 0.0
		"stage":
			return a.p1 <= 0.0 and not a.boost_on
		"fairing":
			return a.alt >= FAIRING_ALT and not a.s1_on
		"cutoff":
			return a.speed() >= ORBIT_V - _tol()
	return false

func _tol() -> float:
	return 40.0 * band

func _flash(s: String) -> void:
	flash_msg = s
	flash_t = 0.0
	Audio.play("error", -8.0)

## SPACE, ENTER or the big button: the next staged event.
func _act() -> void:
	if help_open:
		help_open = false
		return
	match mode:
		"pad":
			ev_i = 1
			_set_mode("count")
			Audio.play("radio_blip", -6.0)
			return
		"cam":
			_deploy()
			return
		"fail":
			if mode_t < 1.2:
				return
			Audio.loop("thrust", false)
			Game.finish()
			Game.goto("report")
			return
	if mode != "fly":
		return
	var nx: String = _next()
	var lat: float = a.t - due_since if due_since >= 0.0 else 0.0
	match nx:
		"boosters":
			var left: float = a.pb / maxf(1.0, pb_0)
			if left > 0.08 * band:
				_flash("NOT YET: THE BOOSTERS STILL HAVE %d%% FUEL" % ceili(left * 100.0))
				return
			if a.pb > 0.0:
				notes.append([false, "Boosters dropped early: %s kg of their fuel thrown away." % _n(a.pb)])
			elif lat > 3.0:
				notes.append([false, "Boosters dropped %d s late: carrying empty tanks cost speed." % roundi(lat)])
			_drop_boosters()
		"stage":
			var left1: float = a.p1 / maxf(1.0, p1_0)
			if a.boost_on:
				_flash("FIRST DROP THE BOOSTERS")
				return
			if left1 > 0.06 * band:
				_flash("NOT YET: STAGE 1 STILL HAS %d%% FUEL" % ceili(left1 * 100.0))
				return
			if a.p1 > 0.0:
				notes.append([false, "Stage 1 dropped early: %s kg of its fuel thrown away; the second stage burned longer." % _n(a.p1)])
			elif lat > 3.0:
				notes.append([false, "Stage 1 dropped %d s late: coasting let gravity take about %d m/s." % [roundi(lat), roundi(lat * G0)]])
			_drop_stage()
		"fairing":
			if a.s1_on:
				_flash("FIRST SEPARATE STAGE 1")
				return
			var early_km: float = (FAIRING_ALT - a.alt) / 1000.0
			if early_km > 30.0 * band:
				_flash("NOT YET: THE AIR IS STILL TOO THICK AT %d km" % floori(a.alt / 1000.0))
				return
			if early_km > 0.0:
				var hurt: float = early_km / (30.0 * band) * 45.0 * dmg_mult
				dmg += hurt
				notes.append([false, "Fairing opened at %d km, below 100 km: air friction heated the spacecraft (%d%% stress)." % [floori(a.alt / 1000.0), roundi(hurt)]])
			elif lat > 20.0:
				notes.append([true, "Fairing dropped late (%d km): its %s kg rode along a little longer." % [floori(a.alt / 1000.0), Game.fmt(lv["fair"])]])
			_drop_fairing()
		"cutoff":
			var v: float = a.speed()
			if v < ORBIT_V - 500.0 * band:
				_flash("NOT YET: %s OF %s m/s" % [_n(v), _n(ORBIT_V)])
				return
			_cutoff()

func _advance() -> void:
	ev_i += 1
	due_since = -1.0
	Audio.play("radio_blip", -10.0, 1.3)

func _top_screen() -> Vector2:
	return Vector2(floorf(RX - tex_rocket.get_width() / 2.0), floorf(BASE_Y - _h_px() + _cam() - tex_rocket.get_height()))

## Turns a piece that was attached into a tumbling one, in world coordinates.
func _release(name: String, push: Vector2, spin: float) -> void:
	if not tumbles.has(name) or tumbles[name] == null:
		return
	var c: Vector2 = _top_screen() + Vector2(centers[name]) - Vector2(0, _cam())
	falling.append({"tex": tumbles[name], "p": c, "v": Vector2(push.x, -hv + push.y), "a": 0.0, "spin": spin, "age": 0.0})

func _sep_puffs(y_sprite: float, n: int) -> void:
	var top: Vector2 = _top_screen() - Vector2(0, _cam())
	var rw: float = tex_rocket.get_width()
	for i: int in n:
		var sd: float = -1.0 if i % 2 == 0 else 1.0
		_puff(Vector2(RX + sd * rw * 0.4, top.y + y_sprite), Vector2(sd * randf_range(30, 90), -hv + randf_range(-20, 20)), randf_range(0.6, 1.1), 1 if i < 6 else 0, Color(1, 1, 1, 0.9), 0.0)
		_spark(Vector2(RX, top.y + y_sprite), Vector2(randf_range(-120, 120), -hv + randf_range(-60, 60)), 0.6, Color("fff3b0"), 0.0)

func _drop_boosters() -> void:
	a.drop_boosters()
	Audio.play("stage_sep", -2.0)
	shake = 2.5
	if lv_id == "vulcan":
		_release("boost0", Vector2(-22, 10), -2.2)
		_release("boost1", Vector2(4, 22), 1.6)
		_release("boost2", Vector2(22, 10), 2.2)
	else:
		_release("boost0", Vector2(-24, 8), -2.5)
		_release("boost1", Vector2(24, 8), 2.5)
	_sep_puffs(tex_rocket.get_height() * 0.45, 10)
	_advance()

func _drop_stage() -> void:
	a.drop_stage()
	stage_t = 0.0
	Audio.play("stage_sep", -2.0)
	shake = 2.5
	_release("core", Vector2(-6, 14), -2.0)
	_sep_puffs(float(CUTS[lv_id][1]), 10)
	_advance()

func _drop_fairing() -> void:
	a.fair_on = false
	Audio.play("stage_sep", -6.0, 1.4)
	_release("fair_l", Vector2(-26, -4), -3.0)
	_release("fair_r", Vector2(26, -4), 3.0)
	_sep_puffs(float(CUTS[lv_id][0]) * 0.6, 6)
	_advance()

func _cutoff() -> void:
	a.cut = true
	cut_v = a.speed()
	var err: float = absf(cut_v - ORBIT_V) - _tol()
	if err > 0.0:
		ship_dv += err
		if cut_v < ORBIT_V:
			notes.append([false, "Engine cut early at %s m/s: %d m/s short of orbit speed." % [_n(cut_v), roundi(ORBIT_V - cut_v)]])
		else:
			notes.append([false, "Engine cut late at %s m/s: the orbit came out %d m/s too fast." % [_n(cut_v), roundi(cut_v - ORBIT_V)]])
	Audio.loop("thrust", false)
	Audio.play("radio_blip", -4.0)
	_advance()
	_set_mode("coast")

## The upper stage ran out before the engine was cut.
func _stage2_dry() -> void:
	a.cut = true
	cut_v = a.speed()
	if doomed:
		var why: String = ""
		for e: Dictionary in Game.run["log"]:
			if not bool(e["ok"]):
				why = String(e["text"])
		_fail("OUT OF FUEL - SHORT OF ORBIT", why if why != "" else "The rocket could not lift this ship to the speed it needed.",
			"Real launchers publish how much they can send to each place. A heavier ship needs a bigger rocket.", false)
		return
	if cut_v < ORBIT_V - _tol():
		ship_dv += ORBIT_V - cut_v
		notes.append([false, "Stage 2 ran dry %d m/s short of orbit speed (a slow climb loses speed to gravity)." % roundi(ORBIT_V - cut_v)])
	elif cut_v > ORBIT_V + _tol():
		ship_dv += cut_v - ORBIT_V - _tol()
		notes.append([false, "The engine was never cut: the orbit came out %d m/s too fast." % roundi(cut_v - ORBIT_V)])
	_flash("STAGE 2 RAN DRY")
	if _next() == "cutoff":
		_advance()
	_set_mode("coast")

func _breakup() -> void:
	Audio.play("explosion")
	boom_age = 0.0
	shake = 7.0
	flash_age = 0.0
	var top: Vector2 = _top_screen() - Vector2(0, _cam())
	var rh: float = tex_rocket.get_height()
	for i: int in 26:
		var ang: float = randf() * TAU
		_spark(Vector2(RX, top.y + rh * randf()), Vector2(cos(ang), sin(ang)) * randf_range(40, 200), randf_range(0.5, 1.3), Color("ff9f43"), 160.0)
	for i: int in 22:
		_puff(Vector2(RX + randf_range(-20, 20), top.y + rh * randf()), Vector2(randf_range(-50, 50), randf_range(-40, 10)), randf_range(1.6, 3.0), 2, Color(0.45, 0.4, 0.5), 14.0)
	_fail("BROKE UP AT MAX-Q", "The air pushed on the rocket past its %d kPa red line for too long, at %d km up." % [roundi(q_red / 1000.0), roundi(a.alt / 1000.0)],
		"Max-Q is the moment of greatest air pressure on a rocket. Real rockets throttle down through it so the structure is never pushed past its limit.", true)

func _fail(title: String, why: String, real: String, log_it: bool) -> void:
	Audio.loop("thrust", false)
	Audio.play("alarm", -4.0)
	fail_title = title
	fail_why = why
	fail_real = real
	Game.run["obj"]["launch"] = false
	if log_it or not bool(Game.run.get("dead", false)):
		Game.fail("%s. %s %s" % [title, why, real])
	_set_mode("fail")

func _deploy() -> void:
	_set_mode("deploy")
	dep_t = 0.0
	Audio.play("stage_sep", -6.0, 1.6)
	for i: int in 12:
		_spark(Vector2(320 + randf_range(-30, 30), 214), Vector2(randf_range(-80, 80), randf_range(-60, 10)), 0.6, Color("fff3b0"), 0.0)
	_advance()

func _deploy_end() -> float:
	return 1.4 + 0.7 * groups.size() + 0.4

func _step_deploy(dt: float) -> void:
	var d0: float = dep_t
	dep_t += dt
	for i: int in groups.size():
		var at: float = 1.4 + 0.7 * i
		if d0 < at and dep_t >= at:
			Audio.play("radio_blip", -8.0, 1.0 + 0.15 * i)
	var end: float = _deploy_end()
	if d0 < end and dep_t >= end:
		_finish_notes()
		if bool(Game.run.get("dead", false)):
			fail_title = "SHORT OF ORBIT"
			fail_why = "The spacecraft had to finish the climb itself (%d m/s) and its tank ran dry." % roundi(ship_dv)
			fail_real = "Every wasted second near the ground costs fuel to gravity. Real rockets climb as hard as the air allows."
			Audio.play("alarm", -4.0)
			_set_mode("fail")
			return
		Audio.play("success", -4.0)
	if dep_t > end + 2.8 and mode == "deploy":
		_set_mode("done")

## The log lines for the report, and the price of a sloppy ascent.
func _finish_notes() -> void:
	var rk: String = String(Data.ROCKETS[lv_id]["name"]) if Data.ROCKETS.has(lv_id) else lv_id
	notes.push_front([dmg < 20.0, "Ascent on %s: max-Q %d kPa at %d km (red line %d kPa)." % [rk, roundi(q_seen / 1000.0), roundi(q_seen_alt / 1000.0), roundi(q_red / 1000.0)]])
	if maxq_missed:
		notes.append([false, "No throttle-back through max-Q. Real rockets throttle down there to protect the structure."])
	if dmg >= 50.0:
		var hit: String = _break_part()
		if hit != "":
			notes.append([false, "The shaking at max-Q cracked the %s (%d%% of the breakup limit)." % [hit, roundi(dmg)]])
	elif dmg >= 20.0:
		notes.append([true, "The rocket shook hard (%d%% of the breakup limit) but nothing broke." % roundi(dmg)])
	for n: Array in notes:
		Game.note(bool(n[0]), String(n[1]))
	notes.clear()
	if ship_dv > 0.0 and band > 1.2:  # EASY: the ship never spends more than half its tank; the rest is forgiven
		var m0: float = float(Game.run["mass"])
		var cap: float = Game.ve() * 1000.0 * log(m0 / maxf(m0 - 0.5 * float(Game.run["prop"]), 1.0))
		if ship_dv > cap:
			Game.note(true, "EASY: the upper stage dipped into its departure reserve for %d m/s." % roundi(ship_dv - cap))
			ship_dv = cap
	if ship_dv > 0.0:
		var used: float = Game.burn(ship_dv / 1000.0)
		if used < 0.0:
			Game.run["obj"]["launch"] = false
			Game.fail("SHORT OF ORBIT. The spacecraft needed %d m/s to finish the climb and its tank ran dry. A cleaner climb or more fuel would have saved it." % roundi(ship_dv))
			return
		Game.note(false, "The spacecraft's own engine made up %d m/s with %s kg of its fuel." % [roundi(ship_dv), _n(used)])
	Game.note(true, "Spacecraft deployed in orbit: 200 km up at 7.8 km/s.")

func _break_part() -> String:
	var pick: String = ""
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS.get(id, {})
		if Game.run["broken"].has(id):
			continue
		if p.get("cat", "") == "science" and id != "drill":
			pick = id
			break
		if p.get("cat", "") == "comms" and p.has("rate") and pick == "":
			pick = id
	if pick == "":
		return ""
	Game.run["broken"][pick] = true
	return String(Data.PARTS[pick]["name"]).to_lower()

# ------------------------------------------------------------------ input

func _throttle(d: int) -> void:
	if help_open or mode != "fly" or a.cut:
		return
	if a.alt < 500.0:
		_flash("THROTTLE STAYS AT 100% UNTIL THE TOWER IS CLEAR")
		return
	if not a.s1_on:
		_flash("THE UPPER STAGE ALWAYS RUNS AT FULL THRUST")
		return
	var lo: float = a.floor_thr()
	var nt: float = clampf(snappedf(a.thr + 0.1 * d, 0.1), lo, 1.0)
	if is_equal_approx(nt, a.thr):
		if d < 0:
			_flash("LOWEST SAFE THROTTLE: %d%%" % roundi(lo * 100.0))
		return
	a.thr = nt
	Audio.play("click", -10.0, 1.0 + 0.3 * a.thr)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		match ke.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if not ke.echo:
					_act()
			KEY_UP, KEY_W:
				_throttle(1)
			KEY_DOWN, KEY_S:
				_throttle(-1)
			KEY_SLASH, KEY_QUESTION, KEY_H, KEY_F1:
				if not ke.echo:
					help_open = not help_open
			KEY_ESCAPE:
				help_open = false
			_:
				return
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		if BTN_HELP.has_point(p):
			help_open = not help_open
		elif help_open:
			help_open = false
		elif BTN_ACT.has_point(p):
			_act()
		elif BTN_UP.has_point(p) and _hud_on():
			_throttle(1)
		elif BTN_DN.has_point(p) and _hud_on():
			_throttle(-1)
		accept_event()

# ------------------------------------------------------------------ autopilot (debug hooks)

func _autopilot() -> void:
	if help_open:
		return
	match mode:
		"pad":
			_act()
		"cam":
			if mode_t > 0.8:
				_act()
		"fly":
			if not auto_noq:
				if maxq_task == 1:
					_throttle(-1)
				elif maxq_task == 3:
					_throttle(1)
			var nx: String = _next()
			if _due(nx) and nx != hold_ev and (nx != "cutoff" or a.speed() >= ORBIT_V):
				_act()

# ------------------------------------------------------------------ particles

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

func _step_falling(dt: float) -> void:
	var i: int = falling.size() - 1
	while i >= 0:
		var f: Dictionary = falling[i]
		f["age"] = float(f["age"]) + dt
		var v: Vector2 = f["v"]
		v.y += 34.0 * dt          # falls back behind the climbing rocket
		v.x *= exp(-0.3 * dt)
		f["v"] = v
		f["p"] = Vector2(f["p"]) + v * dt
		f["a"] = float(f["a"]) + float(f["spin"]) * dt
		if float(f["age"]) > 14.0:
			falling.remove_at(i)
		i -= 1

## Exhaust: along the ground from the flame trench near the pad, a trail in the sky above it.
func _smoke(dt: float) -> void:
	if not a.burning() or mode == "fail" or not a.s1_on or a.alt > 40000.0:
		return
	var h: float = _h_px()
	var base_y: float = _top_screen().y - _cam() + tex_rocket.get_height()
	spawn_acc += dt * (46.0 if h < 110.0 else 22.0) * (0.4 + 0.6 * a.thr)
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if h < 110.0:
			var side: float = -1.0 if randf() < 0.5 else 1.0
			var from_mouth: bool = randf() < 0.35
			var p0: Vector2 = Vector2(RX + side * randf_range(4, 26), 288.0 - randf() * 5.0) if from_mouth else Vector2(RX + side * randf_range(96, 112), 284.0 - randf() * 6.0)
			_puff(p0, Vector2(side * randf_range(40, 150), -randf_range(2, 26)), randf_range(1.5, 2.9), 2 if randf() < 0.65 else 1, SMOKE_WARM, randf_range(6, 20))
		else:
			_puff(Vector2(RX + randf_range(-5, 5), base_y + randf_range(20, 50)), Vector2(randf_range(-10, 10), randf_range(20, 60)), randf_range(1.2, 2.2), 2 if randf() < 0.5 else 1, SMOKE_WARM, 0.0)

# ------------------------------------------------------------------ drawing: the ascent

## Camera height in px: it starts following once the rocket reaches its spot on screen.
func _cam() -> float:
	var rh: float = tex_rocket.get_height()
	var u_end: float = float(CUTS[lv_id][1])
	var b0: float = clampf(150.0 + rh / 2.0, 150.0, 222.0)
	var b1: float = 150.0 + rh - u_end / 2.0
	var k: float = smoothstep(0.0, 1.4, stage_t) if stage_t >= 0.0 else 0.0
	var lift: float = BASE_Y - lerpf(b0, b1, k)
	return floorf(maxf(0.0, _h_px() - lift))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	if in_cam:
		_draw_cam()
	else:
		_draw_ascent()
	if mode == "cam" and mode_t < 0.4:
		draw_rect(Rect2(0, 0, 640, CON_Y), Color(0, 0, 0, 1.0 - floorf(mode_t / 0.1) * 0.25))
	_draw_console()
	_draw_hud()
	if mode == "fail" and mode_t > 1.2:
		_draw_fail()
	if help_open:
		_draw_help()

func _layer(tex: Texture2D, pos: Vector2) -> void:
	draw_texture(tex, pos)
	if pos.x != 0.0:
		draw_texture(tex, pos - Vector2(signf(pos.x) * 640.0, 0))

func _draw_ascent() -> void:
	var h: float = _h_px()
	var cam: float = _cam()
	var km: float = a.alt / 1000.0
	var k: float = pow(clampf(km / 45.0, 0.0, 1.0), 0.8)
	var rw: float = tex_rocket.get_width()
	var rh: float = tex_rocket.get_height()
	var off: Vector2 = Vector2(0, cam)
	if shake > 0.05:
		off += Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).floor()
	var cloud_c: Color = Color(1, 1, 1, 1.0 - smoothstep(0.35, 0.6, k))
	var ign: float = t - ign_t if ign_t >= 0.0 else -1.0
	# sky: stars behind a tall dawn strip that slides away with altitude
	if k > 0.2:
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
			var bt: float = maxf(0.0, ign - i * 0.05) if ign >= 0.0 else 0.0
			var bp: Vector2 = Vector2(86.0 + i * 13.0 + (i % 2) * 5.0 + t * 5.0, 232.0 - (i % 3) * 6.0 + sin(t * 2.0 + i) * 2.0)
			bp += Vector2(-36.0 - i * 5.0, -30.0 - (i % 3) * 9.0) * bt
			var fr: int = int(t * (5.0 if bt <= 0.0 else 11.0) + i) % 2
			draw_texture_rect_region(tex_bird, Rect2((bp + Vector2(off.x, fy - 208.0)).floor(), Vector2(7, 5)), Rect2(fr * 7, 0, 7, 5))
	var kl: float = pow(clampf((km - 20.0) / 100.0, 0.0, 1.0), 0.7)
	if kl > 0.0:  # the curved edge of the Earth rises into view and turns slowly below
		var ly: float = floorf(330.0 - kl * 140.0)
		var lx: float = floorf(fposmod(-t * 3.0, 640.0))
		draw_texture(tex_limb, Vector2(lx - 640.0, ly))
		draw_texture(tex_limb, Vector2(lx, ly))
	var on_pad: bool = cam < 380.0
	var burning: bool = a.burning() and mode != "fail"
	var base: Vector2 = Vector2(RX, BASE_Y - h) + off
	if on_pad:
		_layer(tex_near, off)
		for lp: Vector2 in [Vector2(159, 168), Vector2(245, 196), Vector2(585, 180)]:  # floodlights
			Fx.glow(self, lp + off, 12.0, Color(1.0, 0.95, 0.75, 0.45 + 0.05 * sin(t * 30.0 + lp.x)), true)
		if int(t * 1.6) % 2 == 0:  # red beacons on the mast tops
			for bx: float in [RX - 116.0, RX + 116.0]:
				Fx.glow(self, Vector2(bx, 46) + off, 6.0, Color(1.0, 0.25, 0.2, 0.7), true)
		var tr_x: float = floorf(RX - rw / 2.0) - 22.0
		var th: float = minf(tex_tower.get_height(), rh + 16.0)
		var tw: float = tex_tower.get_width()
		draw_texture_rect_region(tex_tower, Rect2(Vector2(tr_x - tw, 266.0 - th) + off, Vector2(tw, th)), Rect2(0, tex_tower.get_height() - th, tw, th))
		draw_texture(tex_cap, Vector2(tr_x - tw - 4.0, 266.0 - th - tex_cap.get_height()) + off)
		if int(t * 1.6) % 2 == 1:
			Fx.glow(self, Vector2(tr_x - tw + 12.0, 266.0 - th - 22.0) + off, 6.0, Color(1.0, 0.25, 0.2, 0.7), true)
		var arm_f: int = 0 if count_t < 1.0 else (1 if count_t < 1.5 else 2)  # the arms swing away at T-2
		for frac: float in [0.36, 0.62, 0.86]:
			draw_texture_rect_region(tex_arm, Rect2(Vector2(tr_x, floorf(BASE_Y - rh * frac) - 3.0) + off, Vector2(24, 7)), Rect2(0, arm_f * 7, 24, 7))
		if burning and h < 140.0:  # engine light on the pad and in the trench
			var gl: float = 1.0 - h / 140.0
			Fx.glow(self, Vector2(RX, 270) + off, 96.0 * gl, Color(1.0, 0.72, 0.36, 0.55 * gl))
	for f: Dictionary in falling:
		_draw_falling(f, off)
	if boom_age < 0.15:
		_draw_rocket(base, k, burning, h)
	if on_pad:
		var cf: int = 0 if count_t < 3.0 else 1  # the hold-down clamps open at zero
		draw_texture_rect_region(tex_clamp, Rect2(Vector2(floorf(RX - rw / 2.0) - 7.0, 253) + off, Vector2(9, 13)), Rect2(cf * 9, 0, 9, 13))
		draw_texture_rect_region(tex_clamp, Rect2(Vector2(floorf(RX + rw / 2.0) - 2.0, 253) + off, Vector2(-9, 13)), Rect2(cf * 9, 0, 9, 13))
		_layer(tex_front, off)
		if burning and h < 60.0:
			Fx.glow(self, Vector2(RX, 286) + off, 24.0, Color(1.0, 0.8, 0.4, 0.6))
		if mode == "fly" and a.t < 1.3:
			Fx.shockwave(self, Vector2(RX, 288) + off, a.t / 1.3, 2, Color(1.0, 0.9, 0.8))
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
	Fx.flash(self, flash_age, 0.2, Color(1.0, 0.95, 0.85))

## The launcher from its pieces: flames, first stage and boosters, upper stage, fairing or payload.
func _draw_rocket(base: Vector2, k: float, burning: bool, h: float) -> void:
	var rw: float = tex_rocket.get_width()
	var rh: float = tex_rocket.get_height()
	var top: Vector2 = Vector2(floorf(base.x - rw / 2.0), floorf(base.y - rh))
	var cuts: Array = CUTS[lv_id]
	var u_end: float = float(cuts[1])
	var grow: float = clampf((t - ign_t) / 0.5, 0.2, 1.0) if ign_t >= 0.0 else 0.0
	var thr_len: float = 0.55 + 0.45 * a.thr
	if a.s1_on:
		if burning:
			var fl: float = (34.0 + rh * 0.42) * thr_len
			if h < 90.0:
				fl = minf(fl * grow, h + 14.0 + (20.0 if a.held else 0.0))
			for i: int in nozzles.size():
				var nz: Vector2 = nozzles[i]
				var lit: bool = (a.p1 > 0.0) if i == 0 else a.boost_burning()
				if lit:
					Fx.flame(self, Vector2(top.x + nz.x, base.y - 1.0), Vector2.DOWN, fl * (1.0 if i == 0 else 0.85), nz.y * (1.0 + 0.9 * k), t + i * 0.37)
		if a.boost_on or pb_0 <= 0.0:
			draw_texture(tex_rocket, top)
		else:
			_piece("core", top)
			_piece("upper", top)
			_piece("fair_l", top)
			_piece("fair_r", top)
		if burning and h < 300.0:  # warm light on the lowest part of the hull
			draw_texture_rect_region(tex_rocket, Rect2(top + Vector2(0, rh - 26.0), Vector2(rw, 26)), Rect2(0, rh - 26.0, rw, 26), Color(1.0, 0.8, 0.55))
		return
	if a.s2_burning():
		var fw: float = clampf(rw * 0.55, 8.0, 30.0)
		Fx.flame(self, top + Vector2(floorf(rw / 2.0), u_end - 1.0), Vector2.DOWN, 40.0 * thr_len, maxf(6.0, fw * 0.9), t, Color(0.8, 0.9, 1.0))
	_piece("upper", top)
	if a.fair_on:
		_piece("fair_l", top)
		_piece("fair_r", top)
	elif tex_payload != null:
		var f_end: float = float(cuts[0])
		draw_texture(tex_payload, top + Vector2(floorf((rw - tex_payload.get_width()) / 2.0), f_end - tex_payload.get_height()))

func _piece(name: String, top: Vector2) -> void:
	if pieces.has(name):
		draw_texture(pieces[name], top)

func _draw_falling(f: Dictionary, off: Vector2) -> void:
	var tx: Texture2D = f["tex"]
	if tx == null:
		return
	var side: float = tx.get_height()
	var fr: int = posmod(int(floorf(float(f["a"]))), 16)
	var p: Vector2 = (Vector2(f["p"]) + off - Vector2(side, side) / 2.0).floor()
	if p.y > CON_Y or p.y < -side:
		return
	var fade: float = clampf(1.0 - (float(f["age"]) - 8.0) / 6.0, 0.0, 1.0)
	draw_texture_rect_region(tx, Rect2(p, Vector2(side, side)), Rect2(fr * side, 0, side, side), Color(0.82, 0.84, 0.95, fade))

func _draw_parts(off: Vector2) -> void:
	for q: Dictionary in parts:
		var p: Vector2 = Vector2(q["p"]) + off
		if p.y < -30.0 or p.y > 380.0:
			continue
		var age: float = float(q["age"]) / float(q["life"])
		if int(q["k"]) == 0:
			Fx.puff(self, p, age, int(q["size"]), Color(q["tint"]).lerp(SMOKE_COOL, age), int(q["n"]))
		else:
			Fx.sparkle(self, p, age, Color(q["tint"]), int(q["size"]))

# ------------------------------------------------------------------ drawing: the deployment camera

func _ship_build() -> Dictionary:
	var b: Dictionary = stowed.duplicate()
	if mode == "deploy" or mode == "done":
		for i: int in groups.size():
			if dep_t >= 1.4 + 0.7 * i:
				for id: String in groups[i]:
					b[id] = Game.build[id]
	return b

func _draw_cam() -> void:
	draw_texture(tex_space, Vector2.ZERO)
	Pix.stars(self, t, Vector2(640, 300), 80, 4, Vector2(-t * 2.0, 0))
	var lx: float = floorf(fposmod(-t * 6.0, 640.0))
	draw_texture(tex_limb, Vector2(lx - 640.0, 160))
	draw_texture(tex_limb, Vector2(lx, 160))
	Fx.sun(self, Vector2(560, 44), 2, Color("ffd75e"), t)
	var d: float = dep_t if mode == "deploy" or mode == "done" else 0.0
	var sep: float = 1.0 - exp(-d * 1.4)
	var ring_top: float = 214.0
	var stage_pos: Vector2 = Vector2(320.0 - floorf(tex_cam.get_width() / 2.0), ring_top + floorf(sep * 22.0 + d * 1.5))
	var origin: Vector2 = Vector2(320.0 - ship_rect.get_center().x, ring_top - ship_rect.end.y + 1.0)
	origin += Vector2(floorf(sep * 10.0 + d * 1.0), -floorf(sep * 12.0 + d * 1.0))
	ShipKit.draw(self, origin, _ship_build())
	draw_texture(tex_cam, stage_pos)
	if (mode == "deploy" or mode == "done") and dep_t < 0.5:
		Fx.glow(self, Vector2(320, ring_top + 2.0), 30.0 * (1.0 - dep_t * 2.0), Color(1, 1, 0.9, 0.6), true)
	for i: int in groups.size():
		var at: float = 1.4 + 0.7 * i
		if d >= at and d < at + 0.6:
			for j: int in 4:
				Fx.sparkle(self, origin + Vector2(-50 + j * 33, -10 + (j % 2) * 18), (d - at) / 0.6, UI.YELLOW, 1)
	_draw_parts(Vector2.ZERO)
	Pix.text_o(self, Vector2(12, 286), "STAGE 2 CAMERA", 10, UI.DIM)
	if int(t * 1.5) % 2 == 0:
		draw_rect(Rect2(102, 279, 5, 5), UI.RED)
	if d >= _deploy_end() and mode != "fail":
		Pix.title_c(self, 130.0, 70.0, "SPACECRAFT", UI.GREEN, 2)
		Pix.title_c(self, 130.0, 98.0, "DEPLOYED", UI.GREEN, 2)
		Pix.text_oc(self, 130.0, 118.0, "ON ITS WAY TO %s" % Game.place(), 10, UI.TEXT)

# ------------------------------------------------------------------ drawing: HUD

func _hud_on() -> bool:
	return not in_cam

func _txt(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(self, p, s, size, c)

func _txt_r(xr: float, y: float, s: String, size: int, c: Color) -> void:
	Pix.text(self, Vector2(xr - Pix.text_w(s, size), y), s, size, c)

func _draw_hud() -> void:
	if _hud_on():
		_draw_gauges()
		_draw_ladder()
		_draw_clock()
	_draw_direction()
	Pix.button(self, BTN_HELP, "?", "btn", "pressed" if help_open else "normal")

func _clock_s() -> String:
	if mode == "pad" or mode == "count":
		return "T-%d" % maxi(0, ceili(3.0 - count_t))
	var s: int = int(a.t)
	return "T+%d:%02d" % [s / 60, s % 60]

func _event_name() -> String:
	if mode == "pad":
		return "READY ON THE PAD"
	if mode == "count":
		return "IGNITION" if count_t >= 2.4 else ("ARMS CLEAR" if count_t >= 1.0 else "COUNTDOWN")
	if mode == "fail":
		return "LAUNCH FAILED"
	if mode == "coast":
		return "ENGINE CUT: IN ORBIT"
	if maxq_task == 1 or maxq_task == 2:
		return "MAX-Q"
	if a.s1_on:
		if a.boost_on and a.pb <= 0.0:
			return "BOOSTERS EMPTY"
		if a.p1 <= 0.0:
			return "STAGE 1 EMPTY"
		return "LIFTOFF" if a.t < 12.0 else "STAGE 1 BURN"
	if not a.s2_lit:
		return "STAGE SEPARATION"
	return "STAGE 2 BURN"

func _draw_clock() -> void:
	var r: Rect2 = Rect2(226, 6, 188, 34)
	Pix.panel(self, r)
	_txt(Vector2(r.position.x + 8.0, 29), _clock_s(), 20, UI.YELLOW if mode == "pad" or mode == "count" else UI.TEXT)
	var rk: String = String(Data.ROCKETS[lv_id]["name"]) if Data.ROCKETS.has(lv_id) else lv_id
	_txt_r(r.end.x - 7.0, 19, rk, 10, UI.DIM)
	var ec: Color = UI.RED if mode == "fail" or (maxq_task <= 2 and a.q > q_red) else (UI.YELLOW if maxq_task == 1 or maxq_task == 2 else UI.GREEN)
	_txt_r(r.end.x - 7.0, 32, _event_name(), 10, ec)
	if mode == "count" and count_t < 2.4:
		Pix.title_c(self, 386.0, 120.0, str(ceili(3.0 - count_t)), Color.WHITE if fposmod(count_t, 1.0) < 0.12 else UI.YELLOW, 3)

func _draw_gauges() -> void:
	Pix.panel(self, Rect2(6, 6, 140, 230))
	var km: float = a.alt / 1000.0
	_txt(Vector2(12, 18), "ALTITUDE", 10, UI.DIM)
	_txt(Vector2(12, 38), ("%.1f km" % km) if km < 100.0 else ("%d km" % roundi(km)), 20, UI.YELLOW)
	_txt(Vector2(12, 52), "VERTICAL SPEED", 10, UI.DIM)
	var vy: int = roundi(a.vy)
	_txt(Vector2(12, 72), "%s%s m/s" % ["+" if vy > 0 else "", _n(vy)], 20, UI.TEXT if vy >= 0 else UI.ORANGE)
	var v: float = a.speed()
	_txt(Vector2(12, 88), "SPEED", 10, UI.DIM)
	_txt_r(140, 88, "%s m/s" % _n(v), 10, UI.TEXT)
	Pix.gauge(self, Rect2(12, 91, 128, 8), v / (ORBIT_V * 1.06), UI.CYAN, 1.0 / 1.06)
	var qc: Color = UI.RED if a.q > q_red else (UI.YELLOW if a.q > 0.75 * q_red else UI.GREEN)
	if dmg > 1.0:
		_txt(Vector2(12, 112), "STRESS %d%%" % roundi(dmg), 10, UI.RED if dmg > 50.0 else UI.ORANGE)
	else:
		_txt(Vector2(12, 112), "PRESSURE", 10, UI.DIM)
	_txt_r(140, 112, "%d kPa" % roundi(a.q / 1000.0), 10, qc if a.q > 0.75 * q_red else UI.TEXT)
	var red_x: float = 14.0 + floorf(123.0 / 1.35)
	Pix.gauge(self, Rect2(12, 115, 128, 8), a.q / (q_red * 1.35), qc, 1.0 / 1.35)
	draw_rect(Rect2(red_x + 1.0, 117, 137.0 - red_x, 4), Color(0.85, 0.15, 0.15, 0.55))  # the red zone
	_txt(Vector2(12, 134), "THROTTLE", 10, UI.DIM)
	_txt_r(140, 134, "%d%%" % roundi(a.thr * 100.0), 10, UI.YELLOW if a.thr < 0.99 else UI.TEXT)
	var lo: float = a.floor_thr() if mode == "fly" else 0.4
	for i: int in 10:
		var on: bool = a.thr >= (i + 1) * 0.1 - 0.001
		var c: Color = UI.GREEN if on else Color("1a2038")
		if not on and (i + 1) * 0.1 <= lo - 0.05:
			c = Color("3a1a26")
		draw_rect(Rect2(12 + i * 13, 139, 11, 12), Color("05070d"))
		draw_rect(Rect2(13 + i * 13, 140, 9, 10), c)
		if on:
			draw_rect(Rect2(13 + i * 13, 140, 9, 2), UI.GREEN.lightened(0.5))
	var st: String = "normal" if mode == "fly" else "disabled"
	Pix.button(self, BTN_UP, "UP / W", "btn", st)
	Pix.button(self, BTN_DN, "DOWN / S", "btn", st)
	_txt(Vector2(12, 190), "FUEL", 10, UI.DIM)
	var y: float = 192.0
	if pb_0 > 0.0:
		_fuel_row(y, "BOOST", a.pb / pb_0, a.boost_on)
		y += 13.0
	_fuel_row(y, "STAGE 1", a.p1 / p1_0, a.s1_on)
	y += 13.0
	_fuel_row(y, "STAGE 2", (a.p2 - a.p2_min) / maxf(1.0, p2_0), true)

func _fuel_row(y: float, label: String, frac: float, attached: bool) -> void:
	_txt(Vector2(12, y + 9.0), label, 10, UI.TEXT if attached else UI.DIM)
	if not attached:
		_txt_r(140, y + 9.0, "DROPPED", 10, UI.DIM)
		return
	var c: Color = UI.GREEN if frac > 0.25 else (UI.YELLOW if frac > 0.08 else UI.RED)
	Pix.gauge(self, Rect2(62, y + 2.0, 78, 8), frac, c)

## Altitude ladder on the right edge, square-root scale so the low milestones get room.
func _draw_ladder() -> void:
	var x: float = 618.0
	var y0: float = 254.0
	var hgt: float = 222.0
	Pix.panel(self, Rect2(x, y0 - hgt - 4.0, 16, hgt + 8.0))
	var marks: Array = [[q_peak_alt, "MAX-Q"], [meco_alt, "STAGING"], [FAIRING_ALT, "FAIRING 100 km"], [ORBIT_ALT, "ORBIT 200 km"]]
	var nx: String = _next()
	var nxt_i: int = 0
	match nx:
		"boosters", "stage":
			nxt_i = 1
		"fairing":
			nxt_i = 2
		"cutoff":
			nxt_i = 3
		"deploy", "":
			nxt_i = 4
	if maxq_task <= 2 and nxt_i <= 1:
		nxt_i = 0
	for i: int in marks.size():
		var m: Array = marks[i]
		var my: float = floorf(y0 - hgt * sqrt(clampf(float(m[0]) / LADDER_TOP, 0.0, 1.0)))
		var col: Color = UI.CYAN if i < nxt_i else (UI.YELLOW if i == nxt_i else UI.DIM)
		draw_rect(Rect2(x + 2.0, my, 12, 1), col)
		if i == 1 and absf(meco_alt - FAIRING_ALT) < 9000.0:
			continue  # staging and the fairing nearly coincide: one label is enough
		Pix.text_o(self, Vector2(x - 4.0 - Pix.text_w(String(m[1]), 10), my + 4.0), String(m[1]), 10, col)
	var ay: float = floorf(y0 - hgt * sqrt(clampf(a.alt / LADDER_TOP, 0.0, 1.0)))
	draw_rect(Rect2(x + 3.0, ay - 2.0, 8, 5), UI.YELLOW)
	draw_rect(Rect2(x + 1.0, ay, 12, 1), Color.WHITE)

## [key, text, urgent]: the one thing to do now. It stays until the player has done it.
func _direction() -> Array:
	match mode:
		"pad":
			return ["SPACE", "START THE COUNTDOWN", true]
		"count":
			return ["", "COUNTDOWN: THE ENGINES START AT ZERO", false]
		"coast":
			return ["", "ENGINE OFF. SWITCHING TO THE STAGE 2 CAMERA", false]
		"cam":
			return ["SPACE", "DEPLOY YOUR SPACECRAFT", true]
		"deploy", "done":
			return ["", "THE SPACECRAFT UNFOLDS ITS PANELS AND ANTENNAS", false]
		"fail":
			return ["SPACE", "SEE THE MISSION REPORT", mode_t > 1.2]
	if maxq_task == 1:
		return ["DOWN", "THROTTLE BACK TO 80%: AIR PRESSURE IS RISING", true]
	if maxq_task == 3:
		return ["UP", "PAST MAX-Q: FULL THROTTLE AGAIN", true]
	var nx: String = _next()
	var now: bool = _due(nx)
	match nx:
		"boosters":
			return ["SPACE", "BOOSTERS EMPTY: DROP THEM NOW" if now else "DROP THE BOOSTERS WHEN THEIR FUEL HITS 0", now]
		"stage":
			return ["SPACE", "STAGE 1 EMPTY: SEPARATE IT NOW" if now else "SEPARATE STAGE 1 WHEN ITS FUEL HITS 0", now]
		"fairing":
			return ["SPACE", "ABOVE 100 km: DROP THE FAIRING NOW" if now else "DROP THE FAIRING ABOVE 100 km", now]
		"cutoff":
			return ["SPACE", "ORBIT SPEED: CUT THE ENGINE NOW" if now else "CUT THE ENGINE AT ORBIT SPEED, 7,790 m/s", now]
	return ["", "", false]

func _act_label() -> String:
	match mode:
		"pad":
			return "START"
		"cam":
			return "DEPLOY"
		"fail":
			return "REPORT"
		"fly":
			match _next():
				"boosters":
					return "DROP BOOSTERS"
				"stage":
					return "SEPARATE"
				"fairing":
					return "DROP FAIRING"
				"cutoff":
					return "CUT ENGINE"
	return "WAIT"

func _draw_direction() -> void:
	var d: Array = _direction()
	var key: String = d[0]
	var txt: String = d[1]
	var urgent: bool = d[2]
	if txt != "":
		var col: Color = UI.YELLOW if urgent and int(t * 3.0) % 3 != 0 else (UI.TEXT if key != "" else UI.DIM)
		var w: float = Pix.text_w(txt, 10) + 16.0 + (maxf(13.0, Pix.text_w(key, 10) + 7.0) + 4.0 if key != "" else 0.0)
		var x: float = floorf(clampf(330.0 - w / 2.0, 152.0, 510.0 - w))
		Pix.panel(self, Rect2(x, 268, w, 24), UI.YELLOW if urgent else UI.BORDER)
		if key != "":
			Pix.key_hint(self, Vector2(x + 8.0, 273), key, txt, col)
		else:
			Pix.text_o(self, Vector2(x + 8.0, 283), txt, 10, col)
	if flash_t < 2.2 and flash_msg != "":
		Pix.text_oc(self, 330.0, 258.0, flash_msg, 10, UI.ORANGE)
	if mode == "deploy" or mode == "done" or mode == "coast":
		return
	var lab: String = _act_label()
	var ready: bool = lab != "WAIT" and not (mode == "fail" and mode_t < 1.2)
	var go: bool = ready and (mode != "fly" or _due(_next()))
	Pix.button(self, BTN_ACT, lab, "btn_go" if go else "btn", "normal" if ready else "disabled")

func _draw_fail() -> void:
	var r: Rect2 = Rect2(160, 56, 320, 160)
	Pix.panel(self, r, UI.RED, Color(0.08, 0.02, 0.03, 0.94))
	Pix.title_c(self, 320.0, r.position.y + 22.0, fail_title, UI.RED)
	Pix.para(self, Vector2(r.position.x + 12.0, r.position.y + 42.0), fail_why, r.size.x - 24.0, UI.TEXT)
	_txt(Vector2(r.position.x + 12.0, r.position.y + 106.0), "WHY IT MATTERS", 10, UI.YELLOW)
	Pix.para(self, Vector2(r.position.x + 12.0, r.position.y + 118.0), fail_real, r.size.x - 24.0, UI.DIM)

func _draw_help() -> void:
	var r: Rect2 = Rect2(160, 46, 320, 206)
	Pix.panel(self, r, UI.CYAN, Color(0.02, 0.03, 0.07, 0.95))
	Pix.title_c(self, 320.0, r.position.y + 20.0, "CONTROLS", UI.CYAN)
	var y: float = r.position.y + 32.0
	var rows: Array = [["UP", "MORE THROTTLE (also W)"], ["DOWN", "LESS THROTTLE (also S)"], ["SPACE", "NEXT STAGED EVENT (or the big button)"], ["?", "SHOW OR HIDE THIS LIST"]]
	for row: Array in rows:
		Pix.key_hint(self, Vector2(r.position.x + 14.0, y), String(row[0]), String(row[1]))
		y += 17.0
	_txt(Vector2(r.position.x + 14.0, y + 12.0), "STAGED EVENTS, IN ORDER", 10, UI.YELLOW)
	y += 16.0
	var names: Dictionary = {"ignite": "IGNITION AND LIFTOFF", "boosters": "DROP THE BOOSTERS", "stage": "STAGE SEPARATION",
		"fairing": "FAIRING RELEASE (ABOVE 100 km)", "cutoff": "ENGINE CUT AT ORBIT SPEED", "deploy": "DEPLOY THE SPACECRAFT"}
	for i: int in seq.size():
		var done: bool = i < ev_i
		var mark: String = "DONE" if done else ("NEXT" if i == ev_i else "")
		_txt(Vector2(r.position.x + 18.0, y + 10.0), mark, 10, UI.GREEN if done else UI.YELLOW)
		_txt(Vector2(r.position.x + 52.0, y + 10.0), String(names[seq[i]]), 10, UI.GREEN if done else (UI.TEXT if i == ev_i else UI.DIM))
		y += 12.0

# ------------------------------------------------------------------ console (as on the flight screen)

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
	var lg: Array = Game.run.get("log", [])
	while shown < lg.size():
		var e: Dictionary = lg[shown]
		var ok: bool = e["ok"]
		for s: String in _wrap(String(e["text"]), 70):
			lines.append({"s": s, "ok": ok, "e": shown})
		shown += 1
		if not silent:
			new_t = 0.0

## One plain-words line about what is happening (the gloss for each launch word).
func _teach() -> String:
	var c: Dictionary = Game.run.get("calc", {})
	match mode:
		"pad", "count":
			return "Rocket limit on this path: %s kg. Your ship: %s kg." % [Game.fmt(c.get("cap", 0)), Game.fmt(c.get("mass", 0))]
		"cam", "deploy", "done":
			return "Springs push the ship free of the stage, then it unfolds."
		"fail":
			return "The report shows what to change next time."
	if maxq_task == 1 or maxq_task == 2:
		return "Max-Q: the moment the air pushes hardest on the rocket."
	match _next():
		"boosters":
			return "Boosters burn out first; empty tanks are dead weight."
		"stage":
			return "Staging: drop the empty stage so the light one speeds up."
		"fairing":
			return "The fairing (nose shell) shields the ship from the air."
		"cutoff":
			return "Orbit: 7.8 km/s sideways, so you fall around the Earth."
	return ""

func _lamp(center: Vector2, state: int) -> void:
	draw_texture_rect_region(tex_lamp, Rect2(center - Vector2(5, 5), Vector2(11, 11)), Rect2(state * 11, 0, 11, 11))

func _draw_console() -> void:
	draw_texture(tex_console, Vector2(0, CON_Y))
	var r: Dictionary = Game.run
	var ring: bool = String(Game.dest().get("kind", "land")) == "ring"
	var names: Array[String] = ["LIFT", "CRUISE", "ORBIT", "RINGS" if ring else "LAND", "HOME"]
	for i: int in 5:
		var state: int = 0
		if i == 0:
			state = 3 if mode == "fail" else (1 if mode == "done" else (2 if int(t * 3.0) % 2 == 0 else 0))
		var cx: float = 24.0 + i * 35.0
		_lamp(Vector2(cx, CON_Y + 14.0), state)
		Pix.text_c(self, cx, CON_Y + 31.0, names[i], 10, UI.TEXT if i == 0 else UI.DIM)
	var prop0: float = maxf(1.0, float(r["calc"]["prop"]))
	_cgauge(CON_Y + 36.0, "FUEL", float(r["prop"]) / prop0, "%s kg" % _n(float(r["prop"])))
	var bat: float = float(r["battery"]) / maxf(1.0, float(r["wh"]))
	_cgauge(CON_Y + 47.0, "BATT", bat, "%d%%" % roundi(bat * 100.0) if float(r["wh"]) > 0.0 else "none")
	_txt(Vector2(192, CON_Y + 17.0), _teach(), 10, UI.CYAN)
	var first: int = maxi(0, lines.size() - 3)
	while first > 0 and int(lines[first - 1]["e"]) == shown - 1:  # a long newest entry shows from its start
		first -= 1
	var typed: int = int(new_t * 140.0)
	for i: int in range(first, mini(first + 3, lines.size())):
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
		_txt(Vector2(200, y), s, 10, (UI.TEXT if ok else UI.RED) if newest else UI.DIM)

func _n(v: float) -> String:
	return Game.fmt(roundi(v)) if absf(v) >= 100.0 else str(roundi(v))

func _cgauge(y: float, label: String, frac: float, value: String) -> void:
	_txt(Vector2(8, y + 8.0), label, 10, UI.DIM)
	var col: Color = UI.GREEN if frac > 0.35 else (UI.YELLOW if frac > 0.15 else UI.RED)
	Pix.gauge(self, Rect2(34, y, 80, 8), frac, col)
	_txt(Vector2(118, y + 8.0), value, 10, UI.TEXT)

# ------------------------------------------------------------------ debug hooks (tools/dev/shot.sh call=...)

## Runs the screen ahead with the autopilot until cond is true, then hands control back.
func _skip(cond: Callable, noq: bool = false) -> void:
	var was: bool = auto
	auto = true
	auto_noq = noq
	var guard: int = 0
	while not bool(cond.call()) and guard < 30000 and is_inside_tree() and mode != "fail" and mode != "done":
		_tick(1.0 / 30.0)
		guard += 1
	auto = was
	hold_ev = ""

func debug_countdown() -> void:
	_act()
	_skip(func() -> bool: return count_t >= 1.3)

func debug_liftoff() -> void:
	_skip(func() -> bool: return mode == "fly" and a.t > 5.0)

func debug_maxq() -> void:  # full throttle into max-Q: the red gauge and the throttle-back direction
	_skip(func() -> bool: return mode == "fly" and a.q > q_red * 1.02, true)

func debug_bucket() -> void:  # flying the max-Q throttle-back correctly
	_skip(func() -> bool: return mode == "fly" and a.alt > q_peak_alt)

func debug_boosters() -> void:
	hold_ev = "boosters"
	_skip(func() -> bool: return mode == "fly" and (_next() != "boosters" or _due("boosters")))
	if _next() == "boosters":
		_act()

func debug_staging() -> void:
	hold_ev = "stage"
	_skip(func() -> bool: return mode == "fly" and _next() == "stage" and _due("stage"))
	_act()

func debug_fairing() -> void:
	hold_ev = "fairing"
	_skip(func() -> bool: return mode == "fly" and _next() == "fairing" and _due("fairing"))
	_act()

func debug_cutoff() -> void:
	hold_ev = "cutoff"
	_skip(func() -> bool: return mode == "fly" and _next() == "cutoff" and ORBIT_V - a.speed() < 300.0)

func debug_deploy() -> void:
	_skip(func() -> bool: return mode == "cam")
	_act()

func debug_fail() -> void:  # a ship the rocket cannot carry: its stage runs dry short of orbit
	_act()
	_skip(func() -> bool: return count_t >= 2.5)
	doomed = true
	_ascent_fuel(p2_clean * 0.8)
	Game.fail("TOO HEAVY (debug). The ship weighs more than this rocket can send on this path.")
	_skip(func() -> bool: return false)
	mode_t = 2.0

func debug_breakup() -> void:  # never throttles back on HARD: the rocket breaks up at max-Q
	Game.difficulty = 2
	_setup()
	_skip(func() -> bool: return false, true)
	mode_t = 0.4

func debug_autopilot() -> void:  # flies a clean ascent, three times faster, and ends on the flight screen
	auto = true
	speed_mult = 3.0

func debug_noq() -> void:  # calls every event on time but never throttles back
	auto = true
	auto_noq = true
	speed_mult = 3.0

func debug_help() -> void:
	help_open = true

func debug_electron() -> void:
	Game.rocket_id = "electron"
	Game.start_run()
	Game.run["mode"] = "out"
	_setup()

## Prints how a whole ascent goes (real seconds, max-Q, stress, what the ship paid). tools/dev only.
func debug_report(noq: bool = false, slow: bool = false) -> void:
	var frames: int = 0
	var fuel0: float = float(Game.run["prop"])
	auto = true
	auto_noq = noq
	hold_ev = ""
	var marks: Dictionary = {}
	while frames < 30000 and mode != "fail" and mode != "done":
		_tick(1.0 / 30.0)
		frames += 1
		if slow and mode == "fly" and a.alt > 500.0 and a.s1_on:
			a.thr = a.floor_thr()  # the lowest throttle allowed all the way up
		var key: String = "%s:%d" % [mode, ev_i]
		if not marks.has(key):
			marks[key] = true
			print("  %5.1f s real  T+%4d s  %-6s next=%-8s alt %6.1f km  v %5d  q %4.1f kPa  thr %.1f  p1 %d%%  p2 %d%%" % [frames / 30.0, int(a.t), mode, _next(), a.alt / 1000.0, int(a.speed()), a.q / 1000.0, a.thr, int(100 * a.p1 / p1_0), int(100 * (a.p2 - a.p2_min) / p2_0)])
	print("LAUNCH %s diff %d noq %s: %s after %.1f s real (T+%d s). max-Q %.1f kPa at %.1f km, red %.1f; stress %d%%; ship paid %d m/s, fuel %.0f -> %.0f kg; stage 2 left %d%%; meco %.0f km" % [lv_id, Game.difficulty, str(noq), mode, frames / 30.0, int(a.t), q_seen / 1000.0, q_seen_alt / 1000.0, q_red / 1000.0, roundi(dmg), roundi(ship_dv), fuel0, float(Game.run["prop"]), int(100 * (a.p2 - a.p2_min) / p2_0), meco_alt / 1000.0])
	get_tree().quit()

func debug_report_noq() -> void:
	debug_report(true)

func debug_report_slow() -> void:
	debug_report(true, true)
