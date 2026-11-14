extends Control
## Cruise map and arrival (mode "out"). The old trip home / downlink stage (mode "home") is kept but v6 never enters it.
## The launch has its own screen (launch.gd), so the outbound flight starts at the cruise.
## Decision events open on the route (EventCard) and the ship reacts to the outcome; the arrival is flown:
## a braking burn the player holds (SPACE or the on-screen button), or an entry corridor behind a heat shield.
## Art: res://art/flight (tools/art/gen_flight.py, gen_arrivals.py, gen_flight2_icons.py). Effects: scripts/fx.gd.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const EventCard = preload("res://scripts/event_card.gd")

const CON_Y: float = 298.0     # top of the console
const T_CRUISE: float = 12.0   # seconds of map time for the whole trip at 1x (game pacing)
const T_HOME: float = 5.0      # seconds of the trip home before the downlink starts
const T_DOWNLINK: float = 6.5
const REACT_S: float = 1.7     # the ship's reaction to an event outcome; the clock waits for it
const FF: float = 4.0          # fast-forward factor while SPACE is held during a coast
## Arrival burn and entry, game rules: seconds of holding for the planned speed change, the green band's
## half-width as a share of the plan (times Game.diff("burn_band")), and the grace after an early release.
const BURN_FULL_S: float = 4.5
const BAND: float = 0.10
const GRACE_S: float = 2.5
const ENTRY_S: float = 6.0
const ENTRY_HW: float = 0.24
const ENTRY_A: Vector2 = Vector2(70, 104)   # the entry corridor on screen: top of the air to the hot part
const ENTRY_B: Vector2 = Vector2(372, 172)
const SMOKE_COOL: Color = Color(0.80, 0.76, 0.90)

const PLANETS: Array[String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
## Orbital periods in days (NASA planetary fact sheets): how fast each planet moves on the map.
const PERIOD: Dictionary = {"mercury": 87.97, "venus": 224.70, "earth": 365.26, "mars": 686.98, "jupiter": 4332.59,
	"saturn": 10759.22, "uranus": 30685.4, "neptune": 60189.0}
## Map radius (px) of each orbit, in the real order. Distances are squeezed (the map says "not to scale"):
## trips inside Jupiter get room for the inner planets, trips beyond it for the giants.
const R_INNER: Array[float] = [44.0, 80.0, 120.0, 168.0, 212.0, 244.0, 270.0, 292.0]
const R_OUTER: Array[float] = [22.0, 36.0, 50.0, 66.0, 118.0, 180.0, 240.0, 294.0]
## Where a planet that the route does not visit sits at the end of the trip (screen degrees): keeps labels apart.
## Angles in the lower half stay clear of the panels for the slow outer planets.
const PARK: Dictionary = {"mercury": 250.0, "venus": 140.0, "earth": 200.0, "mars": 105.0, "jupiter": 255.0,
	"saturn": 295.0, "uranus": 172.0, "neptune": 218.0}
const END_DEG: float = 335.0   # where the destination is at arrival: lower right, clear of the panels
## The real flybys of each named path, [day after launch, planet]. Key: "<skin>/<path id>". Dates are not shown.
const FLYBYS: Dictionary = {
	# MESSENGER, launched 3 Aug 2004: Earth 2 Aug 2005; Venus 24 Oct 2006, 5 Jun 2007; Mercury 14 Jan 2008, 6 Oct 2008, 29 Sep 2009 (NASA/JHUAPL)
	"mercury/assist": [[364.0, "earth"], [812.0, "venus"], [1036.0, "venus"], [1259.0, "mercury"], [1525.0, "mercury"], [1883.0, "mercury"]],
	# BepiColombo, launched 20 Oct 2018: Earth 10 Apr 2020; Venus 15 Oct 2020, 10 Aug 2021; Mercury 1 Oct 2021, 23 Jun 2022, 19 Jun 2023, 4 Sep 2024, 1 Dec 2024, 8 Jan 2025 (ESA)
	"mercury/slow": [[538.0, "earth"], [726.0, "venus"], [1025.0, "venus"], [1077.0, "mercury"], [1342.0, "mercury"], [1703.0, "mercury"], [2146.0, "mercury"], [2234.0, "mercury"], [2272.0, "mercury"]],
	# Juno, launched 5 Aug 2011: Earth 9 Oct 2013 (NASA)
	"jupiter/assist": [[796.0, "earth"]],
	# Cassini, launched 15 Oct 1997: Venus 26 Apr 1998, 24 Jun 1999; Earth 18 Aug 1999; Jupiter 30 Dec 2000 (NASA)
	"saturn/assist": [[193.0, "venus"], [617.0, "venus"], [672.0, "earth"], [1172.0, "jupiter"]],
	# NASA's Uranus Orbiter and Probe plan flies past Jupiter (no date published: placed about where the path crosses Jupiter's orbit)
	"uranus/slow": [[700.0, "jupiter"]],
	# Voyager 2, launched 20 Aug 1977: Jupiter 9 Jul 1979, Saturn 26 Aug 1981 (NASA)
	"uranus/fast": [[688.0, "jupiter"], [1467.0, "saturn"]],
	# the 12-year Neptune path swings past Jupiter, as Voyager 2 did on 9 Jul 1979 (day 688)
	"neptune/fast": [[688.0, "jupiter"]],
}

# D7: only the host advances the mission; clients render its snapshots.
var driver: bool = true
var send_t: float = 0.0
const MP_FIELDS: Array[String] = ["stage", "st", "t", "did", "hint", "new_t", "shake", "flash_age", "flyby_age", "flyby_name", "react_t", "react_kind", "react_text", "react_bad", "storm_ev", "storm_age", "storm_hit", "storm_speed", "storm_asked", "storm_res", "cruise_t", "lost", "lost_t", "lost_p", "arr", "arr_t", "entry_mode", "cap", "band_w", "dv_done", "dv_max", "m0", "p0", "holding", "armed", "pressed_once", "released_once", "cut_note", "orb_th", "ang", "strain", "entry_t", "orb_rx", "orb_ry", "orb_tilt", "home_t", "dl_t"]

var stage: String = ""
var st: float = 0.0
var t: float = 0.0
var did: Dictionary = {}
var frozen: bool = false
var auto: bool = false        # debug autopilot: flies, decides and continues by itself
var sim_hold: bool = false    # debug: SPACE held
var btn_hold: bool = false    # the on-screen button is held (mouse or touch)
var help_open: bool = false
var did_ff: bool = false
var card: Control = null
var card_age: float = 0.0

# ticker
var shown: int = 0
var lines: Array[Dictionary] = []
var new_t: float = 99.0
var hint: String = ""

# effects
var parts: Array[Dictionary] = []
var shake: float = 0.0
var flash_age: float = 9.0
var flyby_age: float = 9.0
var flyby_name: String = ""

# events and the ship's reaction
var react_t: float = -1.0
var react_kind: String = ""   # "spark" | "burn" | "dim" | "shield" | "ok"
var react_text: String = ""
var react_bad: bool = false
var storm_ev: Dictionary = {}
var storm_age: float = -1.0
var storm_hit: float = -1.0
var storm_speed: float = 200.0
var storm_asked: bool = false
var storm_res: Dictionary = {}

# cruise map
var cruise_t: float = 0.0
var lost: bool = false
var lost_t: float = 0.0
var lost_p: float = 0.0
var moon_map: bool = false
var map_c: Vector2 = Vector2(320, 158)
var map_sq: float = 0.48
var map_rot: float = 0.0
var map_sun: Vector2 = Vector2(320, 158)
var radii: Array[float] = []
var a0: Dictionary = {}       # planet angle (model degrees) at day 0
var legs: Array[Dictionary] = []
var flybys: Array = []
var trip_days: float = 1.0
var moon_a0: float = 0.0
var tex_map: ImageTexture = null

# arrival
var arr: String = ""          # approach | burn | grace | orbit | flyby | entry | entered | burnup | skip
var arr_t: float = 0.0
var entry_mode: bool = false
var cap: float = 0.0          # planned braking speed change, km/s (Game.dv_plan)
var band_w: float = 0.1
var dv_done: float = 0.0
var dv_max: float = 0.0
var m0: float = 0.0
var p0: float = 0.0
var holding: bool = false
var armed: bool = false       # SPACE must be let go once after the coast, so fast-forward never starts the burn
var pressed_once: bool = false
var released_once: bool = false
var cut_note: String = ""
var rescued: bool = false   # a missed burn the level forgave (fail < 2): captured anyway, at a cost
var pop_s: String = ""       # a pop-up line over the arrival scene, in its consequence colour
var pop_c: Color = Color.WHITE
var pop_age: float = 99.0
var orb_th: float = PI / 2.0
var fly_p: Vector2 = Vector2.ZERO   # flying past: position and velocity once off the drawn curve
var fly_v: Vector2 = Vector2.ZERO
var ang: float = 0.0          # entry: 0 = centre of the corridor, + steeper, - shallower
var strain: float = 0.0
var entry_t: float = 0.0
var orb_c: Vector2 = Vector2(400, 150)
var orb_rx: float = 190.0
var orb_ry: float = 52.0
var orb_tilt: float = 0.14

# home
var home_t: float = 0.0
var dl_t: float = 0.0

var tex_space: Texture2D = null
var tex_deep: Texture2D = null
var tex_console: Texture2D = null
var tex_lamp: Texture2D = null
var tex_marker: Texture2D = null
var tex_wave: Texture2D = null
var tex_capsule: Texture2D = null
var tex_orbiter: Texture2D = null
var tex_sample: Texture2D = null
var tex_earth_mid: Texture2D = null
var tex_earth_map: Texture2D = null
var tex_moon_map: Texture2D = null
var tex_big: Texture2D = null
var tex_big_back: Texture2D = null
var tex_big_front: Texture2D = null
var tex_icon: Dictionary = {}
var tex_cam: Array[Texture2D] = []

func _f(name: String) -> Texture2D:
	return Pix.img("flight/" + name)

func _skin() -> String:
	return String(Game.dest()["skin"])

func _ring() -> bool:
	return String(Game.dest()["kind"]) == "ring"

func _ready() -> void:
	driver = Net.is_host()
	if Net.is_online():
		Net.received.connect(_on_net)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin: String = _skin()
	moon_map = float(Game.dest()["earth_au"]) < 0.01   # a world that circles the Earth gets the Earth-Moon map
	tex_space = Pix.img("bg_space")
	tex_deep = _f("space_far")
	tex_console = _f("console")
	tex_lamp = _f("lamp")
	tex_marker = _f("map_ship")
	tex_wave = _f("wave")
	tex_capsule = _f("capsule")
	tex_orbiter = Pix.img("orbiter")
	tex_sample = Pix.img("sample_%s_big" % skin if ResourceLoader.exists("res://art/sample_%s_big.png" % skin) else "sample_moon_big")
	tex_earth_mid = Pix.planet(36, "earth")
	tex_earth_map = Pix.planet(22, "earth")
	tex_moon_map = Pix.planet(9, "moon")
	tex_big = _f("big_" + skin)
	if _ring():
		tex_big_back = _f("big_%s_back" % skin)
		tex_big_front = _f("big_%s_front" % skin)
	for n: String in PLANETS:
		tex_icon[n] = _f("map_" + n)
	for r: int in ([9, 12, 22] if _ring() else [9, 12, 22, 36]):
		tex_cam.append(Pix.planet(r, skin))
	_update_log(true)  # what happened before this screen sits in the ticker already, without the beeps
	_set_stage("cruise" if String(Game.run.get("mode", "out")) == "out" else "home")

func _set_stage(s: String) -> void:
	stage = s   # v6 no longer enters the "home" stage (the ship stays at the destination); its code is kept unreachable
	st = 0.0
	did = {}
	parts.clear()
	shake = 0.0
	react_t = -1.0
	Audio.loop("thrust", false)
	if s == "cruise":
		cruise_t = 0.0
		_setup_map()
		Audio.music("drift")
	elif s == "arrive":
		_setup_arrive()
	elif s == "home":
		home_t = 0.0
		dl_t = 0.0
		var h: float = tex_big.get_height() if tex_big != null else 211.0
		orb_c = Vector2(112, maxf(160.0, 70.0 + floorf(h / 2.0))) if _ring() else Vector2(84, 196)
	_set_hint()

func _dead() -> bool:
	return bool(Game.run["dead"])

func _end() -> void:
	Audio.loop("thrust", false)
	Game.finish()
	Game.flow("report")

# ------------------------------------------------------------- input and clock

func _space_held() -> bool:
	return driver and (Input.is_key_pressed(KEY_SPACE) or btn_hold or sim_hold)

## Coasting stages: SPACE fast-forwards. Never while the player must act.
func _coasting() -> bool:
	return (stage == "cruise" and not lost) or (stage == "home" and not did.has("p"))

func _process(delta: float) -> void:
	if not driver:
		queue_redraw()
		return
	_send_state(delta)
	if auto:
		_auto_card(delta)
	if help_open or EventCard.is_open():
		queue_redraw()
		return
	var mult: float = 1.0
	if _coasting() and (_space_held() or auto) and react_t < 0.0 and storm_age < 0.0:
		mult = FF
		if not auto:
			did_ff = true
	if not frozen:
		_step(delta * mult)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_SLASH or k.keycode == KEY_QUESTION or k.keycode == KEY_H or k.unicode == 63:
		help_open = not help_open
		Audio.play("click", -8.0)
	elif help_open and k.keycode == KEY_ESCAPE:
		help_open = false

const HELP_BTN: Rect2 = Rect2(616, 6, 18, 18)
const BURN_BTN: Rect2 = Rect2(500, 248, 132, 40)

func _burn_btn_on() -> bool:
	return stage == "arrive" and arr in ["burn", "grace", "entry"]

func _gui_input(event: InputEvent) -> void:
	if not driver:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if HELP_BTN.grow(2.0).has_point(mb.position) or help_open:
			help_open = not help_open
			Audio.play("click", -8.0)
		elif _burn_btn_on() and BURN_BTN.has_point(mb.position):
			btn_hold = true
		elif _coasting():
			btn_hold = true   # phones have no SPACE key: holding a finger anywhere fast-forwards the cruise
	else:
		btn_hold = false

func _step(dt: float) -> void:
	t += dt
	st += dt
	new_t += dt
	flash_age += dt
	flyby_age += dt
	shake = maxf(0.0, shake - dt * 3.0)
	match stage:
		"cruise":
			_step_cruise(dt)
		"arrive":
			_step_arrive(dt)
		"home":
			_step_home(dt)
	_step_parts(dt)
	_update_log(false)

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
		var ok: bool = e["ok"]
		for s: String in _wrap(String(e["text"]), 70):
			lines.append({"s": s, "ok": ok, "e": shown})
		shown += 1
		if not silent:
			new_t = 0.0
			Audio.play("radio_blip" if ok else "error", -6.0 if ok else -3.0)

## The console's info line: a fact about what is happening, never an order (those are the directions).
func _set_hint() -> void:
	var d: Dictionary = Game.dest()
	match stage:
		"cruise":
			hint = "%s days of coasting. Sunlight fades with distance from the Sun." % Game.fmt(Game.traj()["days"])
			if lost:
				hint = "The ship is lost. The report says why."
		"arrive":
			if entry_mode:
				var nm: String = Game.place().capitalize()
				hint = "Entry: the heat shield rubs on %s%s air to slow down. No fuel needed." % [nm, "'" if nm.ends_with("s") else "'s"]
			else:
				hint = "Braking burn: %.2f km/s of speed change lets gravity catch the ship." % cap
		"home":
			hint = "Radio delay: %s. Antenna speed and storage decide what reaches Earth." % d["light_delay"]

## The one direction shown now: [key, words]. It stays until the player has done it.
func _direction() -> Array:
	match stage:
		"cruise":
			if lost:
				return ["", "SIGNAL LOST"]
			if not did_ff:
				return ["SPACE", "HOLD TO FAST-FORWARD"]
			return ["", "DECISIONS WAIT AT THE ! MARKS"]
		"arrive":
			var assist: float = Game.diff("assist")
			if assist <= 0.0:
				return ["", ""]   # HARD: readouts and the band only
			var easy: bool = assist >= 2.0 and not entry_mode
			match arr:
				"approach", "burn":
					if entry_mode:
						return ["SPACE", "HOLD TO LIFT THE NOSE"]
					if not pressed_once:
						return ["SPACE", "HOLD TO BRAKE: AUTO CUT-OFF AT PLAN" if easy else "HOLD TO BRAKE INTO ORBIT"]
					if easy:
						return ["SPACE", "KEEP HOLDING: CUT-OFF IN %.1f s" % maxf(0.0, (cap - dv_done) / cap * BURN_FULL_S)]
					return ["SPACE", "LET GO INSIDE THE GREEN BAND"]
				"grace":
					if easy:
						return ["SPACE", "TOO FAST: HOLD AGAIN IN %.1f s" % maxf(0.0, GRACE_S - arr_t)]
					return ["SPACE", "STILL TOO FAST: HOLD AGAIN"]
				"entry":
					if not pressed_once:
						return ["SPACE", "HOLD TO LIFT THE NOSE"]
					if not released_once:
						return ["SPACE", "LET GO TO DIVE STEEPER"]
					return ["SPACE", "KEEP THE MARKER IN THE GREEN"]
		"home":
			if not did_ff and not did.has("p"):
				return ["SPACE", "HOLD TO FAST-FORWARD"]
	return ["", ""]

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

# ------------------------------------------------------------- decision events

func _open_card(ev: Dictionary) -> void:
	if not driver:
		return
	card = EventCard.open(self, ev, _after_event)
	card_age = 0.0

func _after_event(res: Dictionary) -> void:
	card = null
	if storm_age >= 0.0 and not storm_ev.is_empty() and bool(storm_ev.get("done", false)) and storm_res.is_empty():
		storm_res = res      # the wave is still on its way: the ship reacts when it arrives
		if (res.get("chips", []) as Array).any(func(c: Array) -> bool: return c[0] == "fuel"):
			_react(res)      # turning tail is a burn, seen at once
	else:
		_react(res)
	if _dead() and stage == "cruise":
		lost_p = _cruise_p()
		lost = true
	_set_hint()

## The ship shows what the choice did: sparks for damage, a burn for fuel spent, a dim safe mode for power.
func _react(res: Dictionary) -> void:
	react_t = 0.0
	react_kind = "ok"
	react_bad = not bool(res.get("ok", true))
	var icons: Array = []
	for c: Array in res.get("chips", []):
		icons.append(String(c[0]))
	if icons.has("wrench") or icons.has("bad"):
		react_kind = "spark"
	elif icons.has("fuel"):
		react_kind = "burn"
	elif icons.has("power") or icons.has("battery") or icons.has("comms"):
		react_kind = "dim"
	var fx: Array = res.get("effects", [])
	react_text = String(fx[0]) if not fx.is_empty() else ("NO DAMAGE" if bool(res.get("ok", true)) else "")
	if react_kind == "spark":
		Audio.play("hit", -4.0)
		shake = 2.0
		flash_age = 0.0
	elif react_kind == "burn":
		Audio.play("ignition", -12.0, 1.3)

## Autopilot (debug): picks the first choice the ship can pay for, then continues.
func _auto_card(delta: float) -> void:
	if card == null or not is_instance_valid(card) or not EventCard.is_open():
		return
	card_age += delta
	if card_age < 0.6:
		return
	var res: Dictionary = card.get("result")
	if res.is_empty():
		var infos: Array = card.get("infos")
		var pick: int = 0
		for i: int in infos.size():
			if bool((infos[i] as Dictionary)["can"]):
				pick = i
				break
		card.call("_choose", pick)
		card_age = 0.0
	elif card_age > 0.5:
		card.call("_continue")

# ------------------------------------------------------------- cruise map

func _map_pt(ang_deg: float, r: float) -> Vector2:
	var a: float = deg_to_rad(ang_deg + map_rot)
	return map_c + Vector2(cos(a) * r, -sin(a) * r * map_sq)

func _au(name: String) -> float:
	return 1.0 if name == "earth" else float(Data.DEST[name]["sun_au"])

## Distance from the Sun in AU to map radius in px: piecewise between the orbits, so the order is always right.
func _rmap(au: float) -> float:
	var pa: float = 0.0
	var pr: float = 0.0
	for i: int in PLANETS.size():
		var a: float = _au(PLANETS[i])
		if au <= a:
			return lerpf(pr, radii[i], (au - pa) / (a - pa))
		pa = a
		pr = radii[i]
	return pr + (au - pa) * 2.0

func _rate(name: String) -> float:
	return 360.0 / float(PERIOD[name])

func _planet_deg(name: String, day: float) -> float:
	return float(a0[name]) + _rate(name) * day

## Model degrees swept by a craft between two distances from the Sun over `days` (Kepler's third law at
## the mean distance): enough to make each leg look like a real transfer.
func _sweep(r0: float, r1: float, bump: float, days: float) -> float:
	var rm: float = (r0 + r1) / 2.0 + bump * 0.64
	return 360.0 * days / (365.25 * pow(rm, 1.5))

func _setup_map() -> void:
	var d: Dictionary = Game.dest()
	var tr: Dictionary = Game.traj()
	trip_days = maxf(1.0, float(tr["days"]))
	legs.clear()
	a0.clear()
	flybys = []
	storm_age = -1.0
	storm_hit = -1.0
	if moon_map:
		map_c = Vector2(130, 190)
		map_sq = 0.451
		map_sun = Vector2(-520, 60)
		map_rot = 0.0
		radii = [419.0]
		moon_a0 = 14.0 - trip_days * 360.0 / 27.32  # the Moon (27.32-day orbit, NASA) ends at 14 degrees
	else:
		var inner: bool = float(d["sun_au"]) < 2.0
		radii.assign(R_INNER if inner else R_OUTER)
		map_c = Vector2(320, 156)
		map_sq = 0.5 if inner else 0.48
		map_sun = map_c
		var dest_name: String = _skin()
		flybys = FLYBYS.get("%s/%s" % [dest_name, tr["id"]], [])
		var pts: Array = [[0.0, "earth"]]
		pts.append_array(flybys)
		pts.append([trip_days, dest_name])
		a0["earth"] = 0.0
		var th: float = 0.0
		for k: int in range(1, pts.size()):
			var d0: float = float(pts[k - 1][0])
			var d1: float = float(pts[k][0])
			var b0: String = pts[k - 1][1]
			var b1: String = pts[k][1]
			var r0: float = _au(b0)
			var r1: float = _au(b1)
			# a loop from a planet back to the same planet swings out and back (a resonant orbit)
			var bump: float = r0 * 0.6 if b0 == b1 else 0.0
			var s: float = _sweep(r0, r1, bump, d1 - d0)
			var sweep: float = s
			if a0.has(b1):
				var target: float = _planet_deg(b1, d1)
				var base: float = fposmod(target - th, 360.0)
				var n: int = maxi(0, roundi((s - base) / 360.0))
				sweep = base + 360.0 * n
				if sweep < 25.0:
					sweep += 360.0
			else:
				a0[b1] = th + s - _rate(b1) * d1
			legs.append({"d0": d0, "d1": d1, "th0": th, "th1": th + sweep, "r0": r0, "r1": r1, "bump": bump})
			th += sweep
		map_rot = END_DEG - th
		for n: String in PLANETS:
			if not a0.has(n):
				a0[n] = float(PARK[n]) - map_rot - _rate(n) * trip_days
	# orbits and the asteroid belt are baked once into one texture
	var im: Image = Image.create(640, 300, false, Image.FORMAT_RGBA8)
	for r: float in radii:
		var n: int = int(r * 7.0)
		for i: int in n:
			var p: Vector2 = _map_pt(360.0 * i / n, r)
			if p.x >= 0.0 and p.x < 640.0 and p.y >= 0.0 and p.y < 298.0:
				im.set_pixel(int(p.x), int(p.y), Color(0.42, 0.52, 0.86, 0.62 if p.y > map_c.y else 0.36))
	if not moon_map:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		var b0: float = _rmap(2.2)
		var b1: float = _rmap(3.2)  # main asteroid belt, about 2.2 to 3.2 AU
		for i: int in 420:
			var bp: Vector2 = _map_pt(rng.randf() * 360.0, rng.randf_range(b0, b1))
			if bp.x >= 0.0 and bp.x < 640.0 and bp.y >= 0.0 and bp.y < 298.0:
				im.set_pixel(int(bp.x), int(bp.y), Color(0.62, 0.58, 0.52, rng.randf_range(0.25, 0.7)))
	tex_map = ImageTexture.create_from_image(im)

## Where the ship is on the map after the fraction p of the trip.
func _path(p: float) -> Vector2:
	if moon_map:
		var a: Vector2 = map_c + Vector2(20, -12)
		var b: Vector2 = _moon_pos(trip_days) + Vector2(-9, 5)
		if trip_days > 30.0:  # the low-energy path (CAPSTONE) swings far past the Moon and falls back
			return a.bezier_interpolate(Vector2(330, 0), Vector2(680, 30), b, p)
		return a.bezier_interpolate(Vector2(230, 96), Vector2(400, 60), b, p)
	var day: float = p * trip_days
	for i: int in legs.size():
		var lg: Dictionary = legs[i]
		if day <= float(lg["d1"]) or i == legs.size() - 1:
			var u: float = clampf((day - float(lg["d0"])) / maxf(1.0, float(lg["d1"]) - float(lg["d0"])), 0.0, 1.0)
			var r: float = lerpf(float(lg["r0"]), float(lg["r1"]), (1.0 - cos(PI * u)) / 2.0) + float(lg["bump"]) * sin(PI * u)
			return _map_pt(lerpf(float(lg["th0"]), float(lg["th1"]), u), _rmap(r))
	return map_c

func _moon_pos(day: float) -> Vector2:
	return _map_pt(moon_a0 + day * 360.0 / 27.32, 419.0)

func _cruise_p() -> float:
	if lost:
		return lost_p
	return clampf(cruise_t / T_CRUISE, 0.0, 1.0)

## The next stop on the route, in words.
func _next_stop(p: float) -> String:
	for fb: Array in flybys:
		if p * trip_days < float(fb[0]):
			return "NEXT: %s FLYBY" % String(fb[1]).to_upper()
	return "NEXT: ARRIVE AT %s" % Game.place()

func _flyby_words(body: String) -> String:
	# a flyby can add speed (outbound) or take it away (inbound, like MESSENGER's) without fuel
	if float(Game.dest()["sun_au"]) < 1.0:
		return "%s FLYBY: GRAVITY SLOWS THE SHIP" % body.to_upper()
	return "%s FLYBY: FREE SPEED FROM GRAVITY" % body.to_upper()

func _step_cruise(dt: float) -> void:
	if lost:
		lost_t += dt
		if lost_t > 3.6:
			_end()
		return
	if react_t >= 0.0:
		react_t += dt
		if react_t > REACT_S:
			react_t = -1.0
		elif storm_hit < 0.0:
			return
	if storm_age >= 0.0:
		_step_storm(dt)
		return
	var p: float = _cruise_p()
	if not did.has("p") and cruise_t >= 0.4:
		did["p"] = true
		if not _dead():
			Game.phase_cruise(false)
		if _dead():
			Audio.play("alarm", -5.0)
			lost_p = p
			lost = true
			_set_hint()
			return
	var ev: Dictionary = Game.next_event("cruise")
	if not ev.is_empty() and did.has("p") and p >= float(ev["at"]):
		if String(ev["id"]) == "storm":
			storm_ev = ev
			storm_res = {}
			storm_asked = false
			storm_age = 0.0
			storm_hit = -1.0
			storm_speed = maxf(150.0, (_path(p) - map_sun).length() / 1.6)
			Audio.play("alarm", -6.0)
		else:
			Audio.play("alarm", -10.0)
			_open_card(ev)
		return
	cruise_t += dt
	p = _cruise_p()
	for fb: Array in flybys:
		var key: String = "fb%d" % int(fb[0])
		if p * trip_days >= float(fb[0]) and not did.has(key):
			did[key] = true
			flyby_age = 0.0
			flyby_name = _flyby_words(String(fb[1]))
			Audio.play("radio_blip", -4.0, 1.4)
	if p >= 1.0 and ev.is_empty():
		if _dead():
			_end()
		else:
			_set_stage("arrive")

## The storm event: the warning, the front racing out from the Sun, the card while it is on its way, the hit.
func _step_storm(dt: float) -> void:
	storm_age += dt
	var dist: float = (_path(_cruise_p()) - map_sun).length()
	var r: float = storm_age * storm_speed
	if not storm_asked and r >= dist * 0.55:
		storm_asked = true
		_open_card(storm_ev)
		return
	if storm_asked and storm_hit < 0.0 and r >= dist:
		storm_hit = 0.0
		flash_age = 0.0
		if storm_res.is_empty():
			storm_res = storm_ev.get("result", {})
		var pick: int = int(storm_ev.get("choice", -1))
		var risk: Dictionary = (storm_ev["choices"][1] as Dictionary).get("risk", {})
		_react(storm_res)
		if pick == 0:   # turned tail: the front washes past the engine
			react_kind = "ok"
			react_text = "STORM PASSED"
		elif pick == 1 and Game.id_has(String(risk.get("save_part", ""))):
			react_kind = "shield"
			react_text = "SHIELDING HELD"
		shake = 3.0 if react_kind == "spark" else 1.0
	if storm_hit >= 0.0:
		storm_hit += dt
		if storm_hit > 1.4 and react_t < 0.0:
			storm_age = -1.0
			storm_hit = -1.0
			storm_ev = {}

func _storm_big() -> bool:
	var ev: Dictionary = Game.run.get("storm", {})
	return not ev.is_empty() and float(ev["kp"]) >= 7.5

func _draw_cruise() -> void:
	var p: float = _cruise_p()
	var day: float = p * trip_days
	var off: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).floor() if shake > 0.05 else Vector2.ZERO
	draw_texture(tex_deep, Vector2.ZERO)
	Pix.stars(self, t, Vector2(640, 298), 46, 21)
	draw_texture(tex_map, off)
	if moon_map:
		Pix.sprite(self, tex_earth_map, map_c + off)
		_text_c(map_c.x + off.x, map_c.y + 36.0, "EARTH", UI.DIM)
		var mp: Vector2 = _moon_pos(day) + off
		Pix.sprite(self, tex_moon_map, mp)
		_text_c(mp.x, mp.y + 20.0, "MOON", UI.DIM)
	else:
		Fx.glow(self, map_sun + off, 40.0, Color(1.0, 0.75, 0.35, 0.35))
		Fx.sun(self, map_sun + off, 1, Color("ffd75e"), t)
		var pos: Dictionary = {}
		# the Sun, the panels, the ship cam and the bottom note are taken before any label is placed
		var taken: Array[Rect2] = [Rect2(map_sun - Vector2(9, 9), Vector2(18, 18)), Rect2(6, 6, 232, 62), Rect2(484, 30, 152, 96),
			Rect2(0, 284, 360, 14), Rect2(240, 4, 244, 24), Rect2(0, 296, 640, 4)]
		for n: String in PLANETS:
			pos[n] = (_map_pt(_planet_deg(n, day), _rmap(_au(n))) + off).floor()
			var bt: Texture2D = tex_icon[n]
			Pix.sprite(self, bt, pos[n])
			taken.append(Rect2(Vector2(pos[n]) - bt.get_size() / 2.0, bt.get_size()))
		# labels: the destination and Earth first, each in the first free spot around its planet
		var order: Array[String] = [_skin(), "earth"]
		for n: String in PLANETS:
			if not order.has(n):
				order.append(n)
		for n: String in order:
			var bt: Texture2D = tex_icon[n]
			var mine: bool = n == _skin() or n == "earth"
			var lp: Vector2 = _label_spot(pos[n], bt.get_size() / 2.0, n.to_upper(), taken)
			_text_c(lp.x, lp.y, n.to_upper(), UI.TEXT if mine else Color(UI.DIM, 0.85))
	# the road ahead (dotted) and the road travelled (bright near the ship)
	var n_pts: int = 140 + 40 * flybys.size()
	for i: int in n_pts:
		var q: float = float(i) / n_pts
		var pt: Vector2 = (_path(q) + off).floor()
		if q <= p:
			draw_rect(Rect2(pt, Vector2(1, 1)), Color(UI.CYAN, 0.25 + 0.75 * pow(q / maxf(p, 0.001), 6.0)))
		elif i % 3 == 0:
			draw_rect(Rect2(pt, Vector2(1, 1)), Color(1, 1, 1, 0.22))
	# decisions still ahead, at their point on the route
	for ev: Dictionary in Game.run["events"]:
		if String(ev["phase"]) == "cruise" and not bool(ev["done"]):
			var ep: Vector2 = (_path(float(ev["at"])) + off).floor()
			var earth: bool = String(ev.get("from", "ship")) == "earth"   # blue: message from Earth, amber: ship alert
			Fx.glow(self, ep, 8.0, Color(0.35, 0.7, 1.0, 0.35 + 0.2 * sin(t * 5.0)) if earth else Color(1.0, 0.6, 0.2, 0.35 + 0.2 * sin(t * 5.0)), true)
			Pix.text_oc(self, ep.x, ep.y + 4.0, "!", 10, UI.CYAN if earth else UI.ORANGE)
	var ship: Vector2 = (_path(p) + off).floor()
	var dir: Vector2 = _path(minf(1.0, p + 0.004)) - _path(maxf(0.0, p - 0.004))
	_draw_storm(off, ship)
	_draw_marker(ship, dir)
	if lost:
		if int(t * 4.0) % 2 == 0:
			Pix.text_oc(self, ship.x, ship.y - 12.0, "SIGNAL LOST", 10, UI.BAD)
	elif flyby_age < 1.6:
		Fx.sparkle(self, ship, minf(1.0, flyby_age), UI.YELLOW, 1)
		Pix.text_oc(self, 362.0, 42.0, flyby_name, 10, UI.YELLOW)
	_draw_react(ship, true)
	Fx.flash(self, flash_age, 0.3, Color(1.0, 0.6, 0.2, 0.5))
	if moon_map:
		_draw_far_strip()
	Pix.text_o(self, Vector2(8, 293), "MAP NOT TO SCALE: SIZES AND DISTANCES SQUEEZED, ORDER REAL" if not moon_map else "MAP NOT TO SCALE", 10, Color(UI.DIM, 0.85))
	_draw_cam(p)
	# day counter, path name, next stop and a timeline
	var tr: Dictionary = Game.traj()
	Pix.panel(self, Rect2(6, 6, 232, 62))
	_text(Vector2(13, 28), "DAY %s" % (("%.1f" % day) if trip_days < 10.0 else (str(int(day)) if day < 1000.0 else Game.fmt(int(day)))), 20, UI.TEXT)
	var of_s: String = "of %s days" % Game.fmt(trip_days)
	_text(Vector2(232.0 - Pix.text_w(of_s, 10), 20), of_s, 10, UI.DIM)
	_text(Vector2(13, 41), String(tr["name"]), 10, UI.DIM)
	_text(Vector2(13, 53), _next_stop(p), 10, UI.CYAN)
	var bx: float = 13.0
	var bw: float = 218.0
	draw_rect(Rect2(bx, 58, bw, 5), Color("05070d"))
	draw_rect(Rect2(bx + 1.0, 59, floorf((bw - 2.0) * p), 3), UI.CYAN)
	for fb: Array in flybys:
		draw_rect(Rect2(bx + floorf(bw * float(fb[0]) / trip_days), 57, 1, 7), UI.YELLOW)
	for ev: Dictionary in Game.run["events"]:
		if String(ev["phase"]) == "cruise":
			draw_rect(Rect2(bx + floorf(bw * float(ev["at"])) - 1.0, 57, 3, 7), UI.ORANGE if not bool(ev["done"]) else UI.BORDER)
	if storm_age >= 0.0 and storm_hit < 0.0:
		var sev: Dictionary = Game.run.get("storm", {})
		var sy: float = floorf(lerpf(-34.0, 70.0, clampf(storm_age / 0.25, 0.0, 1.0)))
		Pix.panel(self, Rect2(246, sy, 236, 32), UI.ORANGE if int(t * 5.0) % 2 == 0 else UI.BAD)
		_text(Vector2(254, sy + 13.0), "SOLAR STORM WARNING   Kp %s" % str(sev.get("kp", "?")), 10, UI.RISK)
		_text(Vector2(254, sy + 26.0), "Real event %s (NASA DONKI)" % sev.get("time", ""), 10, UI.TEXT)

## Centre-x and baseline for a label next to a body: below, above, right or left, whichever is free.
func _label_spot(c: Vector2, half: Vector2, s: String, taken: Array[Rect2]) -> Vector2:
	var w: float = Pix.text_w(s, 10)
	var spots: Array[Vector2] = [Vector2(c.x, c.y + half.y + 10.0), Vector2(c.x, c.y - half.y - 3.0),
		Vector2(c.x + half.x + 3.0 + w / 2.0, c.y + 4.0), Vector2(c.x - half.x - 3.0 - w / 2.0, c.y + 4.0),
		Vector2(c.x + half.x + w / 2.0, c.y + half.y + 10.0), Vector2(c.x - half.x - w / 2.0, c.y - half.y - 3.0)]
	for sp: Vector2 in spots:
		var r: Rect2 = Rect2(floorf(sp.x - w / 2.0) - 1.0, sp.y - 9.0, w + 2.0, 10.0)
		if not taken.any(func(q: Rect2) -> bool: return q.intersects(r)):
			taken.append(r)
			return sp
	return spots[0]

## The ship on the map: a small arrow (a symbol, so it is never drawn bigger than a planet).
func _draw_marker(ship: Vector2, dir: Vector2) -> void:
	var fr: int = posmod(roundi(atan2(-dir.y, dir.x) / (PI / 4.0)), 8)
	if lost:
		fr = int(t * 3.0) % 8  # a dead ship tumbles
	var dim: bool = react_t >= 0.0 and react_kind == "dim"
	var mod: Color = Color(0.45, 0.45, 0.55) if lost else (Color(0.55, 0.55, 0.65) if dim else Color.WHITE)
	if not lost:
		Fx.glow(self, ship, 7.0, Color(0.3, 0.8, 1.0, 0.35), true)
	draw_texture_rect_region(tex_marker, Rect2(ship - Vector2(4, 4), Vector2(9, 9)), Rect2(fr * 9, 0, 9, 9), mod)

## The visible answer to an event: sparks, a burn, a dimmed safe mode, a shield, and the price in words.
func _draw_react(ship: Vector2, small: bool) -> void:
	if react_t < 0.0:
		return
	var k: float = react_t / REACT_S
	var s: float = 1.0 if small else 2.4
	match react_kind:
		"spark":
			for j: int in 7:
				var a: float = j * 0.9 + t * 7.0
				Fx.sparkle(self, ship + Vector2(cos(a), sin(a * 1.3)) * (4.0 + 9.0 * k) * s, fposmod(k * 3.0 + j * 0.2, 1.0), UI.BAD if j % 2 == 0 else UI.ORANGE, 0 if small else 1)
		"burn":
			if k < 0.7:
				Fx.flame(self, ship + Vector2(-3, 0) * s, Vector2.LEFT, 8.0 * s, 3.0 * s, t)
		"dim":
			if int(t * 3.0) % 2 == 0:
				Fx.glow(self, ship, 6.0 * s, Color(1.0, 0.75, 0.2, 0.5), true)
		"shield":
			Fx.glow(self, ship, 9.0 * s, Color(0.3, 0.85, 1.0, 0.7 * (1.0 - k)), true)
			Fx.shockwave(self, ship, k, 0, UI.CYAN)
		"ok":
			Fx.sparkle(self, ship, k, UI.GOOD, 0 if small else 1)
	if react_text != "" and small:
		var y: float = ship.y - 12.0 - floorf(6.0 * k)
		Pix.text_oc(self, ship.x, y, react_text.to_upper(), 10, UI.BAD if react_bad or react_kind == "spark" else (UI.RISK if react_kind != "ok" and react_kind != "shield" else UI.GOOD))

## Moon map only: the planets, far beyond the Moon, framed apart with how much farther they are (NASA fact
## sheets: closest distance from Earth divided by the Moon's 384,400 km).
func _draw_far_strip() -> void:
	var r: Rect2 = Rect2(188, 246, 446, 46)
	Pix.panel(self, r, UI.BORDER, Color(0.02, 0.03, 0.06, 0.92))
	_text(r.position + Vector2(7, 12), "FAR BEYOND THE MOON (not to scale)", 10, UI.YELLOW)
	var note: String = "x = times farther, at closest"
	_text(Vector2(r.end.x - 7.0 - Pix.text_w(note, 10), r.position.y + 12.0), note, 10, UI.DIM)
	var moon_mkm: float = float(Game.dest()["earth_min_mkm"])
	var order: Array = []
	for n: String in PLANETS:
		if n != "earth":
			order.append(n)
	order.sort_custom(func(a: String, b: String) -> bool: return float(Data.DEST[a]["earth_min_mkm"]) < float(Data.DEST[b]["earth_min_mkm"]))
	var x: float = r.position.x + 8.0
	for n: String in order:
		var ratio: float = float(Data.DEST[n]["earth_min_mkm"]) / moon_mkm
		var rs: String = Game.fmt(snappedf(ratio, 5.0) if ratio < 1000.0 else snappedf(ratio, 100.0)) + "x"
		var tex: Texture2D = tex_icon[n]
		var cw: float = maxf(float(tex.get_width()), 1.0)
		Pix.sprite(self, tex, Vector2(x + floorf(cw / 2.0), r.position.y + 31.0), Color(1, 1, 1, 0.9))
		var tx: float = x + cw + 3.0
		_text(Vector2(tx, r.position.y + 28.0), n.to_upper(), 10, UI.DIM)
		_text(Vector2(tx, r.position.y + 40.0), rs, 10, UI.TEXT)
		x = tx + maxf(Pix.text_w(rs, 10), Pix.text_w(n, 10)) + 8.0

## The storm front: a ring of charged particles racing out from the Sun.
func _draw_storm(off: Vector2, _ship: Vector2) -> void:
	if storm_age < 0.0:
		return
	var big: bool = _storm_big()
	var r: float = storm_age * storm_speed
	var fade: float = clampf(1.0 - (r - 520.0) / 300.0, 0.0, 1.0)
	if fade <= 0.0:
		return
	var c: Vector2 = map_sun + off
	var wide: bool = not moon_map
	var span: float = PI if wide else 0.42
	var n: int = 110 if wide else 46
	for i: int in n:
		var a: float = -span + 2.0 * span * (i + 0.5 * sin(i * 12.9)) / n
		var layer: int = i % 3
		var rr: float = r - layer * 9.0 - 6.0 * sin(i * 7.3)
		var pp: Vector2 = c + Vector2(cos(a) * rr, sin(a) * rr * (map_sq if wide else 1.0))
		if rr > 4.0 and pp.x > -8.0 and pp.x < 648.0 and pp.y > -8.0 and pp.y < CON_Y:
			Fx.sparkle(self, pp, fposmod(t * 1.7 + i * 0.37, 1.0) * (1.0 - 0.5 * fade), Color("ffd75e") if layer == 0 else Color("ff9f43"), (1 if big else 0) if layer == 0 else 0)

func _blit(tex: Texture2D, pos: Vector2, clip: Rect2, mod: Color = Color.WHITE) -> void:
	var r: Rect2 = Rect2(pos.floor(), tex.get_size()).intersection(clip)
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_texture_rect_region(tex, r, Rect2(r.position - pos.floor(), r.size), mod)

## Close-up window: the ship with the destination growing ahead of it, and its reaction to events.
func _draw_cam(p: float) -> void:
	var win: Rect2 = Rect2(486, 32, 148, 92)
	draw_rect(win.grow(2.0), Color("05070d"))
	draw_rect(win.grow(1.0), UI.BORDER, false, 1.0)
	if lost:
		draw_rect(win, Color("0b0e1a"))
		for i: int in 160:  # snow
			draw_rect(Rect2(win.position + Vector2(randi() % 146, randi() % 91), Vector2(2, 1)), Color(1, 1, 1, randf_range(0.15, 0.5)))
		Pix.text_oc(self, win.get_center().x, win.get_center().y + 4.0, "NO SIGNAL", 10, UI.BAD if int(t * 4.0) % 2 == 0 else Color("ff9f9f"))
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
	var dim: bool = react_t >= 0.0 and react_kind == "dim"
	if react_t >= 0.0 and react_kind == "burn" and react_t < REACT_S * 0.7:
		Fx.flame(self, sp + Vector2(-24, 5), Vector2.LEFT, 26.0, 9.0, t)
	_blit(tex_orbiter, sp - tex_orbiter.get_size() / 2.0, win, Color(0.5, 0.5, 0.6) if dim else Color.WHITE)
	if react_t >= 0.0 and react_kind != "burn":
		_draw_react(sp, false)
	_text(win.position + Vector2(4, 11), "SAFE MODE" if dim else "SHIP CAM", 10, UI.RISK if dim else UI.DIM)
	if int(t * 1.5) % 2 == 0:
		draw_rect(Rect2(win.end.x - 9.0, win.position.y + 4.0, 5, 5), UI.BAD)

# ------------------------------------------------------------- arrival

func _setup_arrive() -> void:
	var dv: Dictionary = Game.dv_plan()
	cap = float(dv["capture"])
	entry_mode = cap <= 0.0   # the core says: heat shield in air = direct entry, no braking burn
	band_w = BAND * Game.diff("burn_band")
	arr = "approach"
	arr_t = 0.0
	dv_done = 0.0
	pressed_once = false
	released_once = false
	holding = false
	armed = false
	cut_note = ""
	rescued = false
	pop_age = 99.0
	ang = 0.0
	strain = 0.0
	entry_t = 0.0
	orb_th = deg_to_rad(177.0)
	fly_p = Vector2.ZERO
	fly_v = Vector2.ZERO
	m0 = float(Game.run["mass"])
	p0 = float(Game.run["prop"])
	dv_max = Game.ve() * log(m0 / maxf(0.001, m0 - p0)) if m0 > p0 else 99.0
	if _ring():
		orb_c = Vector2(396, 150)
		orb_rx = 188.0
		orb_ry = 64.0
		orb_tilt = 0.244
	else:
		orb_c = Vector2(404, 150)
		orb_rx = 172.0
		orb_ry = 46.0
		orb_tilt = 0.14
	if entry_mode:
		orb_c = Vector2(470, 214)

func _lo() -> float:
	return cap * (1.0 - band_w)

func _hi() -> float:
	return cap * (1.0 + band_w)

func _cutoff() -> float:
	return cap * (1.0 + 3.0 * band_w)

## Fuel on board while the burn runs: the rocket equation on the speed change made so far.
func _fuel_now() -> float:
	if stage == "arrive" and not entry_mode and arr in ["burn", "grace"]:
		return maxf(0.0, p0 - m0 * (1.0 - exp(-dv_done / Game.ve())))
	return float(Game.run["prop"])

## Shape of the orbit for the speed change made so far: open (e > 1) until the band, then an ellipse that
## closes to the planned circle; burning past the plan pulls the far side down (apoapsis at the ship).
func _ecc() -> float:
	if dv_done <= _lo():
		return 1.0 + 0.6 * (_lo() - dv_done) / maxf(0.001, _lo())
	if dv_done <= cap:
		return 0.85 * (cap - dv_done) / maxf(0.001, cap - _lo())
	return minf(0.35, (dv_done - cap) / cap * 1.2)

func _conic_pt(th: float, e: float) -> Vector2:
	var dd: float = th - PI / 2.0
	var r: float = (1.0 - e) / (1.0 - e * cos(dd)) if dv_done > cap else (1.0 + e) / (1.0 + e * cos(dd))
	return orb_c + Vector2(cos(th) * r * orb_rx, sin(th) * r * orb_ry).rotated(orb_tilt)

func _conic_ok(th: float, e: float) -> bool:
	if dv_done > cap:
		return true
	var den: float = 1.0 + e * cos(th - PI / 2.0)
	return den > 0.05 and (1.0 + e) / den < 2.6

func _step_arrive(dt: float) -> void:
	arr_t += dt
	pop_age += dt
	var held: bool = _space_held()
	if not armed:
		armed = not held
		held = false
	if auto:
		held = _auto_hold()
	match arr:
		"approach":
			var u: float = clampf(arr_t / 2.0, 0.0, 1.0)
			if entry_mode:
				if arr_t >= 1.6:
					arr = "entry"
					arr_t = 0.0
			else:
				orb_th = lerpf(deg_to_rad(177.0), PI / 2.0, 1.0 - (1.0 - u) * (1.0 - u))
				if u >= 1.0:
					arr = "burn"
					arr_t = 0.0
		"burn", "grace":
			_step_burn(dt, held)
		"orbit":
			orb_th -= dt * 1.1
			if arr_t > 2.8:
				Game.flow("probe" if _ring() else "landing")
		"flyby":
			var e: float = _ecc()
			var nth: float = orb_th - dt * 0.8
			if fly_p == Vector2.ZERO:
				fly_p = _conic_pt(orb_th, e)
			if _conic_ok(nth, e) and fly_v.length() < 400.0:
				var np: Vector2 = _conic_pt(nth, e)
				fly_v = (np - fly_p) / maxf(dt, 0.001)
				fly_p = np
				orb_th = nth
			else:
				fly_p += fly_v * dt
			if arr_t > 3.4:
				_end()
		"entry":
			_step_entry(dt, held)
		"entered":
			if arr_t > 1.8:
				Game.flow("probe" if _ring() else "landing")
		"burnup", "skip":
			if arr_t > 3.0:
				_end()
	if holding and not entry_mode and randf() < dt * 30.0:
		var sh: Vector2 = _conic_pt(orb_th, _ecc())
		_puff(sh + Vector2(26, 6), Vector2(randf_range(40, 90), randf_range(-12, 12)), 0.6, 0, Color(1.0, 0.85, 0.7, 0.7), 0.0)

func _auto_hold() -> bool:
	if entry_mode:
		return ang > -0.02
	return arr in ["burn", "grace"] and dv_done < cap

func _step_burn(dt: float, held: bool) -> void:
	var fuel_out: bool = dv_done >= dv_max - 0.0001
	if held and not fuel_out:
		if not holding:
			Audio.play("ignition", -8.0)
		holding = true
		pressed_once = true
		arr = "burn"
		dv_done = minf(dv_done + cap / BURN_FULL_S * dt, dv_max)
		shake = maxf(shake, 0.8)
		Audio.loop("thrust", true, -8.0)
		if dv_done >= _cutoff():
			cut_note = "SAFETY CUT-OFF"
			_burn_done()
		elif Game.diff("assist") >= 2.0 and dv_done >= cap:
			_burn_done()   # EASY: the computer cuts the engine at the plan
		return
	Audio.loop("thrust", false)
	var was: bool = holding
	holding = false
	if fuel_out and dv_done < cap:
		_burn_done()   # the tank is dry before the plan: the core decides what that means
		return
	if was:
		released_once = true
		if dv_done >= _lo():
			_burn_done()
		else:
			arr = "grace"
			arr_t = 0.0
	elif arr == "grace":
		orb_th -= dt * 0.12
		if arr_t > GRACE_S:
			if Game.diff("fail") >= 2.0:
				_flew_past()
			else:
				# EASY / NORMAL: the computer fires again into the band (NORMAL late, wasting fuel); days are lost below
				rescued = true
				dv_done = minf(dv_max, _lo() + (cap * 0.15 * Game.diff("bite") if Game.diff("fail") >= 1.0 else 0.0))
				_burn_done()

## The burn is over: the core books the planned capture (and radiation, objectives), then the fuel is set
## to what this burn really used, by the same rocket equation, and its log line says the real numbers.
func _burn_done() -> void:
	Audio.loop("thrust", false)
	holding = false
	var short: bool = dv_max < cap
	if short and Game.diff("fail") >= 2.0:
		Game.phase_arrive()   # not enough fuel for the plan: the core fails the arrival and says why
		if _dead():
			arr = "flyby"
			arr_t = 0.0
			Audio.play("alarm", -5.0)
			_set_hint()
			return
	else:
		if short:
			Game.run["prop"] = m0   # shortcut: lets the core book the capture below HARD; the real fuel use is redone next
		Game.phase_arrive()
	# undo the planned burn the core booked and make the one flown, with the core's own rocket equation
	Game.run["mass"] = m0
	Game.run["prop"] = p0
	var used: float = absf(Game.burn(dv_done))
	var ve: float = Game.ve()
	var mf: float = float(Game.run["mass"])
	var lg: Array = Game.run["log"]
	for i: int in range(lg.size() - 1, -1, -1):
		if String(lg[i]["text"]).begins_with("Orbit reached"):
			lg[i]["text"] = "Orbit reached: braking burn of %.2f km/s (plan %.2f km/s) used %s kg of fuel (rocket equation, Isp %d s)." % [
				dv_done, cap, Game.fmt(used), int(Data.ISP)]
			break
	if dv_done > _hi():
		var waste: float = m0 * exp(-_hi() / ve) - mf
		Game.note(false, "BURNED TOO LONG%s: %s km/s past the green band wasted %s kg of fuel." % [
			" (" + cut_note + ")" if cut_note != "" else "", str(snappedf(dv_done - _hi(), 0.01)), Game.fmt(waste)])
	if rescued or short:
		var days: int = roundi((20.0 if Game.diff("fail") < 1.0 else 45.0) * Game.diff("bite"))
		Game.run["days_extra"] = float(Game.run["days_extra"]) + days
		var extra: float = used - m0 * (1.0 - exp(-cap / ve))
		Game.note(false, "%s Captured anyway into a long, loose orbit: +%d days%s." % [
			"TANK DRY %s km/s short of the plan." % str(snappedf(cap - dv_done, 0.01)) if short and not rescued else "MISSED THE GREEN BAND: the computer fired the engine again.",
			days, ", %s kg more fuel than the plan" % Game.fmt(extra) if extra > 0.5 else ""])
		_pop("CAPTURED ANYWAY: +%d DAYS" % days, UI.BAD)
	elif dv_done < cap:
		Game.note(true, "Stopped %s km/s short of the plan: captured into a longer orbit." % str(snappedf(cap - dv_done, 0.01)))
	arr = "orbit"
	arr_t = 0.0
	flyby_age = 0.0
	Audio.play("arrive", -3.0)
	_set_hint()

func _flew_past() -> void:
	var used: float = Game.burn(dv_done)
	Game.fail("FLEW PAST %s. The braking burn stopped at %s km/s, short of the green band (%s km/s): gravity could not catch the ship. It used %s kg of fuel. Fix: hold until the bar is inside the green band, and carry fuel to spare." % [
		Game.place(), str(snappedf(dv_done, 0.01)), str(snappedf(_lo(), 0.01)), Game.fmt(absf(used))])
	arr = "flyby"
	arr_t = 0.0
	Audio.play("alarm", -5.0)
	_set_hint()

## Entry: hold to lift the nose (shallower), let go to dive (steeper). Gusts push it about. Out of the green
## for about a second: too steep burns up, too shallow skips off the air. Game rules.
func _step_entry(dt: float, held: bool) -> void:
	var hw: float = ENTRY_HW * Game.diff("burn_band")
	if held:
		pressed_once = true
	elif pressed_once:
		released_once = true
	if not pressed_once:
		return   # the lander waits at the top of the air until the player starts
	entry_t += dt
	var gust: float = 0.28 * sin(t * 2.3) + 0.18 * sin(t * 5.1 + 1.0)
	ang += ((-0.55 if held else 0.38) + gust) * dt
	ang = clampf(ang, -1.0, 1.0)
	Audio.loop("thrust", true, -14.0, 0.6)
	if absf(ang) > hw:
		strain += dt / 1.1
	else:
		strain = maxf(0.0, strain - dt * 0.6)
	if randf() < dt * (20.0 + 30.0 * maxf(0.0, ang)):
		var sh: Vector2 = _entry_ship()
		_spark(sh + Vector2(randf_range(-4, 4), randf_range(-3, 3)), Vector2(-randf_range(60, 140), -randf_range(10, 50)), 0.5, Color("ff9f43"), 0.0)
	if (strain >= 1.0 or absf(ang) >= 1.0) and Game.diff("fail") < 2.0:
		_entry_saved(ang > 0.0)
		return
	if strain >= 1.0 or absf(ang) >= 1.0:
		Audio.loop("thrust", false)
		if ang > 0.0:
			Game.fail("BURNED UP. The entry was too steep: the air heated the shield past what it could take and the lander broke apart. Fix: hold SPACE sooner to lift the nose back into the green.")
			arr = "burnup"
			Audio.play("explosion", -2.0)
			flash_age = 0.0
		else:
			Game.fail("SKIPPED OFF. The entry was too shallow: the lander bounced off the top of the air and flew back out into space. Fix: let go of SPACE sooner so the nose drops back into the green.")
			arr = "skip"
			Audio.play("alarm", -5.0)
		arr_t = 0.0
		_set_hint()
		return
	if entry_t >= ENTRY_S:
		Audio.loop("thrust", false)
		Game.phase_arrive()
		arr = "entered"
		arr_t = 0.0
		Audio.play("arrive", -3.0)
		_set_hint()

## EASY / NORMAL: a bad entry is pulled back into the corridor at a cost (NORMAL also burns landing fuel).
func _entry_saved(steep: bool) -> void:
	var mins: int = roundi(10.0 * Game.diff("bite"))
	Game.run["minutes_lost"] = float(Game.run.get("minutes_lost", 0.0)) + mins
	var kg: float = 0.0
	if Game.diff("fail") >= 1.0:
		kg = float(Game.run["prop"]) * 0.15 * Game.diff("bite")
		Game.run["prop"] = float(Game.run["prop"]) - kg
		Game.run["mass"] = float(Game.run["mass"]) - kg
	Game.note(false, "%s The lander pulled back into the corridor: %d minutes of surface time lost%s." % [
		"TOO STEEP: the shield overheated." if steep else "TOO SHALLOW: it nearly skipped off.", mins,
		", %s kg of landing fuel burned" % Game.fmt(kg) if kg > 0.5 else ""])
	_pop("SAVED: -%d MIN%s" % [mins, "  -%s KG FUEL" % Game.fmt(kg) if kg > 0.5 else ""], UI.BAD)
	strain = 0.0
	ang = 0.0
	shake = 1.5
	Audio.play("alarm", -6.0)

func _pop(s: String, c: Color) -> void:
	pop_s = s
	pop_c = c
	pop_age = 0.0

## Entry: the lander slides down a corridor from the upper left toward the glowing edge of the air.
func _entry_ship() -> Vector2:
	var u: float = clampf(entry_t / ENTRY_S, 0.0, 1.0)
	if arr == "approach":
		u = -0.25 * (1.0 - arr_t / 1.6)
	var a: Vector2 = ENTRY_A
	var b: Vector2 = ENTRY_B
	var nrm: Vector2 = (b - a).normalized().orthogonal()   # points up and right: "shallower"
	var pos: Vector2 = a.lerp(b, u) - nrm * ang * 34.0
	if arr == "skip":
		pos += Vector2(150, -90) * arr_t
	return pos

func _orbit_half(front: bool, e: float, solid: bool) -> void:
	var n: int = 420
	var c: Color = UI.CYAN
	if arr in ["burn", "grace", "approach"]:
		c = UI.GOOD if dv_done >= _lo() and dv_done <= _hi() else (UI.ORANGE if dv_done < _lo() else UI.BAD)
	var open_curve: bool = dv_done < _lo()
	for j: int in n:
		var th: float = TAU * j / n
		if (sin(th) >= 0.0) != front or (open_curve and j % 4 == 3) or not _conic_ok(th, e):
			continue
		draw_rect(Rect2(_conic_pt(th, e).floor(), Vector2(1, 1)), Color(c, 1.0 if front else 0.55))

func _draw_big_planet(layer: int) -> void:
	var tex: Texture2D = [tex_big_back, tex_big, tex_big_front][layer]
	if tex != null:
		Pix.sprite(self, tex, orb_c)

func _draw_orbiter(pos: Vector2, flip: bool, mod: Color = Color.WHITE) -> void:
	var s: Vector2 = tex_orbiter.get_size()
	var tl: Vector2 = (pos - s / 2.0).floor()
	if flip:
		draw_texture_rect(tex_orbiter, Rect2(tl, Vector2(-s.x, s.y)), false, mod)  # a negative width mirrors in place
	else:
		draw_texture(tex_orbiter, tl, mod)

func _draw_arrive() -> void:
	var slow: float = 0.25 if arr in ["burn", "grace", "entry"] else 1.0
	Pix.tiled(self, tex_space, 0, t * 6.0 * slow)
	Pix.stars(self, t, Vector2(640, 298), 60, 33, Vector2(-t * 12.0 * slow, 0))
	if entry_mode:
		_draw_entry()
		return
	var e: float = _ecc()
	var solid: bool = arr == "orbit"
	var ship: Vector2 = _conic_pt(orb_th, e).floor()
	if arr == "flyby" and fly_p != Vector2.ZERO:
		ship = fly_p.floor()
	var behind: bool = sin(orb_th) < 0.0 and arr == "orbit"
	var off: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).floor() if shake > 0.3 else Vector2.ZERO
	_draw_big_planet(0)
	_orbit_half(false, e, solid)
	if behind:
		_draw_orbiter(ship + off, true)
	_draw_big_planet(1)
	_draw_big_planet(2)
	_orbit_half(true, e, solid)
	if not behind:
		if holding:
			Fx.flame(self, ship + off + Vector2(25, 6), Vector2.RIGHT, 30.0 + 6.0 * sin(t * 30.0), 10.0, t)
			Fx.glow(self, ship + off + Vector2(38, 6), 22.0, Color(1.0, 0.7, 0.35, 0.45), true)
		_draw_orbiter(ship + off, true)
	_draw_parts(Vector2.ZERO)
	if arr == "orbit" and flyby_age < 1.0:
		Fx.sparkle(self, ship, flyby_age, UI.GOOD, 2)
	# the speed-change gauge: green band from Game.diff, the plan, and where the fuel runs out
	Pix.panel(self, Rect2(6, 6, 300, 64))
	_text(Vector2(13, 28), Game.place(), 20, UI.TEXT)
	var status: String = "BRAKING BURN"
	var sc: Color = UI.ORANGE
	match arr:
		"approach":
			status = "APPROACHING"
			sc = UI.DIM
		"grace":
			status = "STILL TOO FAST"
			sc = UI.BAD if int(t * 4.0) % 2 == 0 else UI.RISK
		"orbit":
			status = "CAPTURED LATE" if rescued else ("IN ORBIT" if dv_done <= _hi() else "FUEL WASTED")
			sc = UI.GOOD if dv_done <= _hi() and not rescued else UI.BAD
		"flyby":
			status = "FLEW PAST"
			sc = UI.BAD
	_text(Vector2(118, 28), status, 10, sc)
	var dv_s: String = "%.2f of %.2f km/s" % [dv_done, cap]
	_text(Vector2(13, 42), "SPEED CHANGE", 10, UI.DIM)
	_text(Vector2(13 + Pix.text_w("SPEED CHANGE ", 10), 42), dv_s, 10, UI.TEXT)
	var g: Rect2 = Rect2(13, 46, 286, 10)
	var gmax: float = _cutoff()
	draw_rect(g.grow(1.0), UI.BORDER, false, 1.0)
	draw_rect(g, Color("05070d"))
	var bx0: float = g.position.x + floorf(g.size.x * _lo() / gmax)
	var bx1: float = g.position.x + floorf(g.size.x * _hi() / gmax)
	draw_rect(Rect2(bx0, g.position.y, bx1 - bx0, g.size.y), Color(UI.GOOD, 0.35))
	draw_rect(Rect2(g.position.x + 1.0, g.position.y + 2.0, floorf((g.size.x - 2.0) * clampf(dv_done / gmax, 0.0, 1.0)), g.size.y - 4.0),
		UI.GOOD if dv_done >= _lo() and dv_done <= _hi() else (UI.ORANGE if dv_done < _lo() else UI.BAD))
	var px: float = g.position.x + floorf(g.size.x * cap / gmax)
	draw_rect(Rect2(px, g.position.y - 2.0, 1, g.size.y + 4.0), Color.WHITE)
	_text(Vector2(px - 9.0, 66), "PLAN", 10, UI.DIM)
	if dv_max < gmax:
		var fx_: float = g.position.x + floorf(g.size.x * dv_max / gmax)
		draw_rect(Rect2(fx_, g.position.y - 2.0, 1, g.size.y + 4.0), UI.BAD)
		var fw: float = Pix.text_w("FUEL OUT", 10)
		_text(Vector2(299.0 - fw, 42), "FUEL OUT", 10, UI.BAD)
	_text(Vector2(13, 66), "OPEN", 10, UI.DIM)
	if arr == "grace":
		var gw: float = floorf(120.0 * (1.0 - arr_t / GRACE_S))
		draw_rect(Rect2(320.0 - gw / 2.0, 92, gw, 3), UI.BAD)
	_draw_fuel_line()
	_draw_pop()
	if _burn_btn_on():
		_draw_burn_btn("HOLD: BURN")

## Fuel the plan needs against what is on board, coloured by margin (V7: resources must be felt).
func _draw_fuel_line() -> void:
	var need: float = m0 * (1.0 - exp(-cap / Game.ve()))
	var r: Rect2 = Rect2(6, 72, 300, 20)
	Pix.panel(self, r)
	var x: float = r.position.x + 7.0
	var y: float = r.position.y + 13.0
	if arr in ["approach", "burn", "grace"]:
		var margin: float = p0 / maxf(1.0, need) - 1.0
		var c: Color = UI.BAD if margin < 0.0 else (UI.RISK if margin < 0.25 else UI.GOOD)
		var s: String = "BURN NEEDS %s kg  ON BOARD %s kg" % [Game.fmt(need), Game.fmt(p0)]
		_text(Vector2(x, y), s, 10, UI.TEXT)
		var tag: String = "SHORT" if margin < 0.0 else ("TIGHT" if margin < 0.25 else "+%d%%" % roundi(margin * 100.0))
		_text(Vector2(r.end.x - 7.0 - Pix.text_w(tag, 10), y), tag, 10, c)
	else:
		var left: float = float(Game.run["prop"])
		_text(Vector2(x, y), "FUEL LEFT %s kg" % Game.fmt(left), 10, UI.TEXT)
		var waste: bool = dv_done > _hi() or rescued or arr == "flyby"
		var tag2: String = "WASTED" if waste else ("EMPTY" if left < 1.0 else "KEPT")
		_text(Vector2(r.end.x - 7.0 - Pix.text_w(tag2, 10), y), tag2, 10, UI.BAD if waste or left < 1.0 else UI.GOOD)

func _draw_pop() -> void:
	if pop_age < 3.0:
		Pix.text_oc(self, 320.0, 116.0 - floorf(4.0 * minf(pop_age, 1.0)), pop_s, 10, pop_c)

func _draw_burn_btn(label: String) -> void:
	var down: bool = _space_held()
	Pix.button(self, BURN_BTN, label, "btn_go" if not down else "btn_go", "pressed" if down else "normal")

func _draw_entry() -> void:
	var hw: float = ENTRY_HW * Game.diff("burn_band")
	var u: float = clampf(entry_t / ENTRY_S, 0.0, 1.0)
	_draw_big_planet(1)
	# the glowing top of the air along the limb
	var rr: float = tex_big.get_width() / 2.0 - 5.0 if tex_big != null else 100.0
	for i: int in 48:
		var a: float = PI + 0.12 + 1.4 * i / 47.0
		var lp: Vector2 = orb_c + Vector2(cos(a), sin(a)) * (rr + 3.0)
		draw_rect(Rect2(lp.floor(), Vector2(1, 1)), Color(1.0, 0.85, 0.6, 0.35))
	# the corridor: centre line and the green edges on the scene itself
	var a0p: Vector2 = ENTRY_A
	var b0p: Vector2 = ENTRY_B
	var nrm: Vector2 = (b0p - a0p).normalized().orthogonal()
	for i: int in 160:
		var q: float = i / 159.0
		var c: Vector2 = a0p.lerp(b0p, q)
		draw_rect(Rect2((c - nrm * hw * 34.0).floor(), Vector2(1, 1)), Color(UI.GOOD, 0.85 if q > u else 0.25))
		draw_rect(Rect2((c + nrm * hw * 34.0).floor(), Vector2(1, 1)), Color(UI.GOOD, 0.85 if q > u else 0.25))
		if i % 2 == 0:
			draw_rect(Rect2((c - nrm * 34.0).floor(), Vector2(1, 1)), Color(UI.BAD, 0.5))
			draw_rect(Rect2((c + nrm * 34.0).floor(), Vector2(1, 1)), Color(UI.ORANGE, 0.5))
	var mid_c: Vector2 = a0p.lerp(b0p, 0.42)
	if Game.diff("assist") > 0.0:   # HARD: no cue text, only the corridor
		Pix.text_oc(self, mid_c.x + nrm.x * 46.0, mid_c.y + nrm.y * 46.0, "TOO SHALLOW: SKIPS OFF", 10, UI.RISK)
		Pix.text_oc(self, mid_c.x - nrm.x * 44.0, mid_c.y - nrm.y * 44.0 + 8.0, "TOO STEEP: BURNS UP", 10, UI.BAD)
	var ship: Vector2 = _entry_ship().floor()
	var heat: float = clampf(0.25 + 0.6 * u + 0.6 * maxf(0.0, ang), 0.0, 1.0) if arr == "entry" and pressed_once else 0.15
	if arr == "burnup":
		Fx.explosion(self, ship, arr_t, 2, 60.0)
	else:
		Fx.glow(self, ship + Vector2(6, 4), 10.0 + 14.0 * heat, Color(1.0, 0.55, 0.2, 0.25 + 0.5 * heat), true)
		_draw_orbiter(ship, false, Color(1.0, 0.9 - 0.3 * heat, 0.8 - 0.4 * heat))
	_draw_parts(Vector2.ZERO)
	Fx.flash(self, flash_age, 0.3, Color(1.0, 0.7, 0.3, 0.6))
	# the corridor gauge
	Pix.panel(self, Rect2(6, 6, 300, 64))
	_text(Vector2(13, 28), Game.place(), 20, UI.TEXT)
	var status: String = "ENTRY: HOLD THE CORRIDOR"
	var sc: Color = UI.ORANGE
	match arr:
		"approach":
			status = "AT THE TOP OF THE AIR"
			sc = UI.DIM
		"entered":
			status = "THROUGH THE HOT PART"
			sc = UI.GOOD
		"burnup":
			status = "BURNED UP"
			sc = UI.BAD
		"skip":
			status = "SKIPPED OFF THE AIR"
			sc = UI.BAD
	_text(Vector2(118, 28), status, 10, sc)
	var g: Rect2 = Rect2(13, 46, 286, 10)
	draw_rect(g.grow(1.0), UI.BORDER, false, 1.0)
	draw_rect(g, Color("05070d"))
	var mid: float = g.position.x + floorf(g.size.x / 2.0)
	var bw: float = floorf(g.size.x / 2.0 * hw)
	draw_rect(Rect2(mid - bw, g.position.y, bw * 2.0 + 1.0, g.size.y), Color(UI.GOOD, 0.4))
	var mx: float = mid + floorf(g.size.x / 2.0 * clampf(ang, -1.0, 1.0))
	draw_rect(Rect2(mx - 1.0, g.position.y - 2.0, 3, g.size.y + 4.0), UI.GOOD if absf(ang) <= hw else UI.BAD)
	_text(Vector2(13, 42), "SHALLOW", 10, UI.DIM)
	_text(Vector2(299.0 - Pix.text_w("STEEP", 10), 42), "STEEP", 10, UI.DIM)
	_text(Vector2(13, 66), "AIR BRAKING", 10, UI.DIM)
	Pix.gauge(self, Rect2(84, 59, 100, 8), u, UI.CYAN)
	if strain > 0.05:
		_text(Vector2(192, 66), "DANGER", 10, UI.BAD)
		Pix.gauge(self, Rect2(234, 59, 64, 8), strain, UI.BAD)
	_draw_pop()
	if _burn_btn_on():
		_draw_burn_btn("HOLD: LIFT")

# ------------------------------------------------------------- home

func _step_home(dt: float) -> void:
	if react_t >= 0.0:
		react_t += dt
		if react_t > REACT_S:
			react_t = -1.0
		return
	if not did.has("p"):
		var ev: Dictionary = Game.next_event("home")
		if not ev.is_empty() and home_t / T_HOME >= float(ev["at"]):
			Audio.play("alarm", -10.0)
			_open_card(ev)
			return
		home_t += dt
		if home_t >= T_HOME and Game.next_event("home").is_empty():
			did["p"] = true
			Game.phase_home()
			_set_hint()
		return
	dl_t += dt
	if float(Game.run["sent"]) > 0.0 and dl_t < 5.8 and not did.has("rb%d" % int(dl_t / 0.7)) and dl_t > 0.8:
		did["rb%d" % int(dl_t / 0.7)] = true
		Audio.play("radio_blip", -14.0, 1.0 + 0.12 * (int(dl_t / 0.7) % 3))  # data packets leaving
	if dl_t > T_DOWNLINK:
		_end()

func _draw_home() -> void:
	Pix.tiled(self, tex_space, 0, t * 2.0)
	Pix.stars(self, t, Vector2(640, 298), 60, 44)
	var obj: Dictionary = Game.run["obj"]
	var sent: float = float(Game.run["sent"])
	var made: float = maxf(float(Game.run["data"]), 0.001)
	var e_pos: Vector2 = Vector2(540, 104) if moon_map else Vector2(586, 74)
	_draw_big_planet(0)
	_draw_big_planet(1)
	_draw_big_planet(2)
	if moon_map:
		Pix.sprite(self, tex_earth_mid, e_pos)
	else:
		Fx.glow(self, e_pos, 12.0, Color(0.4, 0.7, 1.0, 0.4), true)
		Pix.sprite(self, tex_icon["earth"], e_pos)
	_text_c(e_pos.x, e_pos.y + (52.0 if moon_map else 18.0), "EARTH", UI.DIM)
	var ship: Vector2 = Vector2(300, 178) if moon_map else Vector2(318, 170)
	ship += Vector2(0, roundf(sin(t * 1.2) * 2.0))
	var dish: Vector2 = ship + Vector2(42, 2)
	var dim: bool = react_t >= 0.0 and react_kind == "dim"
	if sent > 0.0 and did.has("p"):  # radio waves crawl to Earth
		for i: int in 6:
			var k: float = fposmod(dl_t * 0.3 + i / 6.0, 1.0)
			var wp: Vector2 = dish.lerp(e_pos + Vector2(-14, 4), k).floor()
			var wf: int = mini(2, int(k * 3.0))
			draw_texture_rect_region(tex_wave, Rect2(wp - Vector2(6, 22), Vector2(12, 44)), Rect2(wf * 12, 0, 12, 44), Color(1, 1, 1, minf(1.0, 3.0 * (1.0 - k))))
	if react_t >= 0.0 and react_kind == "burn" and react_t < REACT_S * 0.7:
		Fx.flame(self, ship + Vector2(-26, 4), Vector2.LEFT, 18.0, 7.0, t)
	_draw_orbiter(ship, false, Color(0.5, 0.5, 0.6) if dim else Color.WHITE)
	_draw_react(ship, false)
	if react_t >= 0.0 and react_text != "":
		Pix.text_oc(self, ship.x, ship.y - 30.0 - floorf(6.0 * react_t / REACT_S), react_text.to_upper(), 10, UI.BAD if react_bad or react_kind == "spark" else UI.RISK)
	_draw_parts(Vector2.ZERO)
	var title: String = "SENDING SCIENCE HOME" if did.has("p") else "AFTER THE SITE"
	var sub: String = "" if did.has("p") else "Getting ready to send it all home"
	var sub_c: Color = UI.DIM
	if bool(Game.dest()["returns"]) and did.has("p"):
		if obj.get("return", false):
			var p: float = clampf((dl_t - 1.2) / 5.6, 0.0, 1.0)
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
				Fx.sparkle(self, e_pos + Vector2(-30, 6), fposmod(t, 1.0), UI.GOOD, 2)
			title = "SAMPLES COMING HOME"
			sub = "%d samples on board" % int(Game.run["samples"])
			sub_c = UI.GOOD
		else:
			title = "NO RIDE HOME"
			sub = "The samples stay on %s" % Game.place().capitalize()
			sub_c = UI.BAD
	Pix.panel(self, Rect2(6, 6, 262, 62))
	_text(Vector2(13, 28), title, 20, UI.TEXT)
	if sub != "":
		_text(Vector2(13, 42), sub, 10, sub_c)
	if not did.has("p"):
		var bx: float = 13.0
		draw_rect(Rect2(bx, 54, 248, 5), Color("05070d"))
		draw_rect(Rect2(bx + 1.0, 55, floorf(246.0 * clampf(home_t / T_HOME, 0.0, 1.0)), 3), UI.CYAN)
		for ev: Dictionary in Game.run["events"]:
			if String(ev["phase"]) == "home":
				draw_rect(Rect2(bx + floorf(248.0 * float(ev["at"])) - 1.0, 53, 3, 7), UI.ORANGE if not bool(ev["done"]) else UI.BORDER)
		return
	var shown_gb: float = sent * clampf((dl_t - 0.8) / 5.0, 0.0, 1.0)
	_text(Vector2(13, 55), "DATA", 10, UI.DIM)
	Pix.gauge(self, Rect2(42, 48, 120, 8), clampf(shown_gb / made, 0.0, 1.0), UI.CYAN if sent / made >= 0.9 else UI.YELLOW)
	if sent > 0.0:
		_text(Vector2(168, 55), "%s of %s Gb" % [Game.fmt(shown_gb), Game.fmt(made)], 10, UI.TEXT)
	else:
		_text(Vector2(168, 55), "NOTHING SENT", 10, UI.BAD)
	if bool(Game.dest()["returns"]) and obj.get("return", false):
		for i: int in mini(8, int(Game.run["samples"])):
			draw_texture(tex_sample, Vector2(180 + i * 11, 30))

# ------------------------------------------------------------- shared drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	match stage:
		"cruise":
			_draw_cruise()
		"arrive":
			_draw_arrive()
		"home":
			_draw_home()
	if st < 0.32 and t > st + 0.01:  # not on the first phase: main.gd fades the screen in itself
		draw_rect(Rect2(0, 0, 640, CON_Y), Color(0, 0, 0, 1.0 - floorf(st / 0.08) * 0.25))
	_draw_direction()
	_draw_console()
	if help_open:
		_draw_help()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(self, p, s, size, c)

func _text_c(cx: float, y: float, s: String, c: Color) -> void:
	Pix.text_c(self, cx, y, s, 10, c)

## The one direction, centred at the top, with its key; and the "?" button for the list of controls.
func _draw_direction() -> void:
	var dr: Array = _direction() if driver else ["", "THE HOST IS FLYING. YOU ARE WATCHING."]
	var key: String = dr[0]
	var words: String = dr[1]
	if key == "SPACE" and DisplayServer.is_touchscreen_available():
		key = "BUTTON" if _burn_btn_on() else "SCREEN"   # on a phone: hold the HOLD: BURN button, or anywhere
	if words != "":
		var kw: float = (Pix.text_w(key, 10) + 7.0 + 4.0) if key != "" else 0.0
		var w: float = kw + Pix.text_w(words, 10) + 14.0
		var x: float = floorf(362.0 - w / 2.0) if stage == "cruise" else floorf(460.0 - w / 2.0)
		var y: float = 6.0
		var hot: bool = key != ""
		Pix.panel(self, Rect2(x, y, w, 20), UI.YELLOW if hot and int(t * 2.0) % 2 == 0 else UI.BORDER)
		if key != "":
			Pix.key_hint(self, Vector2(x + 7.0, y + 3.0), key, words, UI.YELLOW)
		else:
			_text(Vector2(x + 7.0, y + 13.0), words, 10, UI.DIM)
	Pix.panel(self, HELP_BTN, UI.CYAN if help_open else UI.BORDER)
	Pix.text_c(self, HELP_BTN.get_center().x + 1.0, HELP_BTN.position.y + 13.0, "?", 10, UI.TEXT)

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55))
	var r: Rect2 = Rect2(150, 70, 340, 150)
	Pix.panel(self, r, UI.CYAN)
	_text(r.position + Vector2(12, 18), "CONTROLS", 20, UI.TEXT)
	var rows: Array = [["SPACE", "hold: fast-forward the cruise"], ["SPACE", "hold: braking burn, let go in green"],
		["SPACE", "hold: lift the nose during entry"], ["1 2 3", "pick a choice on a decision card"],
		["ENTER", "continue after a decision"], ["?", "show or hide this list"]]
	for i: int in rows.size():
		var y: float = r.position.y + 30.0 + i * 18.0
		Pix.key_hint(self, Vector2(r.position.x + 12.0, y), String(rows[i][0]), String(rows[i][1]), UI.TEXT)
	_text(r.position + Vector2(12, 144), "Click, tap or press ? to close", 10, UI.DIM)

func _lamp(center: Vector2, state: int) -> void:
	draw_texture_rect_region(tex_lamp, Rect2(center - Vector2(5, 5), Vector2(11, 11)), Rect2(state * 11, 0, 11, 11))

func _gauge(y: float, label: String, frac: float, value: String) -> void:
	_text(Vector2(8, y + 8.0), label, 10, UI.DIM)
	var col: Color = UI.GOOD if frac > 0.35 else (UI.RISK if frac > 0.15 else UI.BAD)
	Pix.gauge(self, Rect2(34, y, 80, 8), frac, col)
	_text(Vector2(118, y + 8.0), value, 10, UI.TEXT)

## Mission-control console: phase lamps, fuel and battery gauges, the info line and the log ticker.
func _draw_console() -> void:
	draw_texture(tex_console, Vector2(0, CON_Y))
	var r: Dictionary = Game.run
	var cur: int = {"cruise": 1, "arrive": 2, "home": 4}[stage]
	var names: Array[String] = ["LIFT", "CRUISE", "ARRIVE", "RINGS" if _ring() else "LAND", "EARTH"]
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
	var fuel: float = _fuel_now()
	_gauge(CON_Y + 36.0, "FUEL", fuel / prop0, "%s kg" % Game.fmt(fuel))
	var bat: float = float(r["battery"]) / maxf(1.0, float(r["wh"]))
	_gauge(CON_Y + 47.0, "BATT", bat, "%d%%" % roundi(bat * 100.0) if float(r["wh"]) > 0.0 else "none")
	# ticker: the info line, then the last three log lines with the newest entry typed out and lit
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
			draw_rect(Rect2(192, y - 6.0, 4, 4), (UI.GOOD if ok else UI.BAD) if newest else UI.BORDER)
		_text(Vector2(200, y), s, 10, (UI.TEXT if ok else UI.BAD) if newest else UI.DIM)

# ------------------------------------------------------------- debug hooks (tools/dev/shot.sh call=...)

## Steps the screen as the game would, 30 times a second, until `done` says stop (or 60 s of game time).
func _warp(done: Callable) -> void:
	var guard: int = 0
	while not bool(done.call()) and guard < 1800 and is_inside_tree():
		if EventCard.is_open():
			break
		_step(1.0 / 30.0)
		guard += 1

func debug_freeze() -> void:
	frozen = true

## Cruise start, half-way, and the first flyby on paths that have one.
func debug_cruise() -> void:
	did_ff = false
	_warp(func() -> bool: return cruise_t >= 1.2)

func debug_cruise_mid() -> void:
	_warp_cruise(0.6)

func _warp_cruise(p: float) -> void:
	for ev: Dictionary in Game.run["events"]:   # the cards are shown by the event hooks below
		if String(ev["phase"]) == "cruise" and float(ev["at"]) < p:
			ev["done"] = true
	_warp(func() -> bool: return _cruise_p() >= p)

func debug_flyby() -> void:
	if flybys.is_empty():
		_warp_cruise(0.5)
		return
	_warp_cruise(float(flybys[0][0]) / trip_days + 0.004)

## The next planned cruise event, opened at its point on the route.
func debug_event() -> void:
	_warp(func() -> bool: return EventCard.is_open() or stage != "cruise")

## The second planned event: the first one is decided with its first choice.
func debug_event2() -> void:
	debug_event()
	if card != null:
		card.call("_choose", 0)
		card.call("_continue")
	react_t = -1.0
	debug_event()

func _force_event(id: String, at: float) -> void:
	var ev: Dictionary = Game.event_by_id(id)
	ev["at"] = at
	ev["phase"] = "cruise"
	for e: Dictionary in Game.run["events"]:
		if String(e["phase"]) == "cruise":
			e["done"] = true
	(Game.run["events"] as Array).push_front(ev)

## The storm: the front on its way, then the card.
func debug_storm() -> void:
	_force_event("storm", 0.3)
	_warp(func() -> bool: return storm_age >= 0.35)

func debug_storm_card() -> void:
	_force_event("storm", 0.3)
	_warp(func() -> bool: return EventCard.is_open())

## The storm hits after "keep working": damage sparks, or the shielding glows.
func debug_storm_hit() -> void:
	_force_event("storm", 0.3)
	_warp(func() -> bool: return EventCard.is_open())
	if card != null:
		card.call("_choose", 1)
		card.call("_continue")
	_warp(func() -> bool: return storm_hit >= 0.25)

## An event whose choice burns fuel: the ship fires its engine.
func debug_react_burn() -> void:
	_force_event("units", 0.3)
	_warp(func() -> bool: return EventCard.is_open())
	if card != null:
		card.call("_choose", 1)
		card.call("_continue")
	_warp(func() -> bool: return react_t >= 0.3)

func debug_react_dim() -> void:
	_force_event("micro", 0.3)
	_warp(func() -> bool: return EventCard.is_open())
	if card != null:
		card.call("_choose", 1)
		card.call("_continue")
	_warp(func() -> bool: return react_t >= 0.3)

func debug_cruise_lost() -> void:
	Game.run["calc"]["draw_cruise"] = 99999.0
	_warp(func() -> bool: return lost_t >= 0.6)

func _to_arrive() -> void:
	if stage == "cruise":
		if not did.has("p"):
			Game.phase_cruise(false)
		for ev: Dictionary in Game.run["events"]:
			if String(ev["phase"]) == "cruise":
				ev["done"] = true
		_set_stage("arrive")

## Arrival: approach, the burn waiting for SPACE, holding inside the band, burning too long, released too early.
func debug_arrive() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr_t >= 1.0)

func debug_burn() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr in ["burn", "entry"] and arr_t >= 0.5)

func debug_burn_band() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or dv_done >= cap * (1.0 + band_w * 0.4) or arr != "burn")
	frozen = true

func debug_burn_long() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or dv_done >= cap * (1.0 + band_w * 2.2) or arr != "burn")
	frozen = true

func debug_burn_open() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or dv_done >= cap * 0.45 or arr != "burn")
	frozen = true

func debug_burn_early() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or dv_done >= cap * 0.5)
	sim_hold = false
	_warp(func() -> bool: return arr in ["flyby", "orbit"] and arr_t > 0.8 or entry_mode)
	frozen = true

## In orbit after a burn in the band; after one too long.
func debug_orbit() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or dv_done >= cap)
	sim_hold = false
	_warp(func() -> bool: return arr in ["orbit", "entered"] and arr_t > 0.9 or entry_mode)

## Arrived: in orbit after a burn in the band, or through the hot part of an entry.
func debug_arrived() -> void:
	if not entry_mode and stage == "arrive" or stage == "cruise":
		_to_arrive()
	if entry_mode:
		auto = true
		_warp(func() -> bool: return arr != "entry" and arr != "approach")
		auto = false
		frozen = true
	else:
		debug_orbit()
		frozen = true

func debug_orbit_wasted() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "burn" or entry_mode)
	sim_hold = true
	_warp(func() -> bool: return entry_mode or arr == "orbit")
	sim_hold = false
	_warp(func() -> bool: return arr_t > 0.9 or entry_mode)

## Direct entry (heat shield in air): the start, the middle, burning up, skipping off.
func debug_entry() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "entry" and arr_t > 0.4 or not entry_mode)

func debug_entry_mid() -> void:
	_to_arrive()
	auto = true
	_warp(func() -> bool: return entry_t >= ENTRY_S * 0.55 or not entry_mode)
	auto = false
	frozen = true

func debug_entry_steep() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "entry" or not entry_mode)
	pressed_once = true
	_warp(func() -> bool: return arr == "burnup" and arr_t > 0.4 or pop_age < 0.4 or not entry_mode)
	frozen = pop_age < 1.0   # EASY / NORMAL: hold on the rescue line

func debug_entry_skip() -> void:
	_to_arrive()
	_warp(func() -> bool: return arr == "entry" or not entry_mode)
	sim_hold = true
	_warp(func() -> bool: return arr == "skip" and arr_t > 0.5 or not entry_mode)

## The trip home: coasting with an event ahead, an event open, and the downlink.
func debug_home() -> void:
	if stage != "home":
		_set_stage("home")
	_warp(func() -> bool: return home_t >= 0.5)

func debug_home_event() -> void:
	if stage != "home":
		_set_stage("home")
	if Game.next_event("home").is_empty():
		var ev: Dictionary = Game.event_by_id("gyro")
		ev["at"] = 0.3
		ev["phase"] = "home"
		(Game.run["events"] as Array).append(ev)
	_warp(func() -> bool: return EventCard.is_open())

func debug_downlink() -> void:
	if stage != "home":
		_set_stage("home")
	if bool(Game.dest()["returns"]):
		Game.run["samples"] = 3
		Game.run["obj"]["land"] = true
	Game.run["data"] = maxf(float(Game.run["data"]), 12.0)
	for ev: Dictionary in Game.run["events"]:
		if String(ev["phase"]) == "home":
			ev["done"] = true
	_warp(func() -> bool: return dl_t >= 3.6)

func debug_help() -> void:
	help_open = true

## Flies the whole screen by itself (at fast-forward): decides every event, burns into the band or holds the
## corridor, then hands over to the next screen (or the report on the way home). For error checks.
func debug_autopilot() -> void:
	auto = true
	if stage == "home":
		Game.run["data"] = maxf(float(Game.run["data"]), 2.0)

# ---------------------------------------------------------------- multiplayer (D7)
func _send_state(delta: float) -> void:
	if not Net.is_online() or not driver:
		return
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 1.0 / float(Data.NET_RATES["state_hz"])
	var snapshot: Dictionary = {"screen": "flight", "run": Game.run}
	for key: String in MP_FIELDS:
		snapshot[key] = get(key)
	for key: String in ["fly_p", "fly_v", "orb_c"]:
		var point: Vector2 = get(key)
		snapshot[key] = [point.x, point.y]
	Net.send("state", snapshot)

func _on_net(kind: String, snapshot: Dictionary, from_id: int) -> void:
	if driver or kind != "state" or String(snapshot.get("screen", "")) != "flight":
		return
	var host_sender: bool = false
	for player: Dictionary in Net.lobby().get("players", []):
		if int(player.get("id", -1)) == from_id and bool(player.get("host", false)):
			host_sender = true
	if not host_sender:
		return
	if snapshot.get("run") is Dictionary:
		Game.run = snapshot["run"]
	var next_stage: String = String(snapshot.get("stage", stage))
	if next_stage != stage:
		_set_stage(next_stage)
	for key: String in MP_FIELDS:
		if snapshot.has(key):
			set(key, snapshot[key])
	for key: String in ["fly_p", "fly_v", "orb_c"]:
		if snapshot.get(key) is Array and (snapshot[key] as Array).size() == 2:
			set(key, Vector2(float(snapshot[key][0]), float(snapshot[key][1])))
	_update_log(false)
	queue_redraw()

## EventCard's network dispatcher opens the same card on spectators.
func mp_open_event(ev: Dictionary) -> void:
	card = EventCard.open(self, ev, _after_event)
	card_age = 0.0
