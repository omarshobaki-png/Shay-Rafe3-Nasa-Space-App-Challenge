extends RefCounted
## Pre-flight check: turns the current Game state into Mission Control's GO / NO-GO board.
## Pure data, no drawing; nothing here changes the simulation. The builder screen shows it.
## Rules and plain messages come from research/audit/rules.json (every blocker, risk and tip).
##
##   Preflight.stations() -> Array of station Dictionaries, in flight order
##       (launch, cruise, arrival, landing, surface, downlink, return, then money, time and risks):
##     "id"       String  booster | power | fuel | landing | drone | science | data | comms | return | budget | time | risk
##     "name"     String  label on the board
##     "role"     String  id from Data.ROLES: the player who watches this lamp
##     "status"   String  "ok" (GO) | "warn" (GO, low margin) | "bad" (NO-GO)
##     "value"    String  need against have in one short line; "short" says the same without words
##     "frac"     float   gauge: need / have (1.0 = at the limit); -1.0 = this station has no gauge
##     "headline" String  the problem, or the all-clear, in one plain sentence
##     "explain"  String  the numbers and what to do about it
##     "fact"     String  the real-world reason, one sentence
##     "fix"      Array   bin tiles that fix it, best first: part ids to add, "rocket:<id>", "path:<index>",
##                        or "-<part id>" for a part to take OFF the ship (too heavy, too expensive)
##     "need"     Array   part ids missing from the ship (the builder outlines their slots)
##     "prio"     int     which NO-GO to fix first: lowest wins (fuel and mass come last,
##                        because every part added changes them)
##   Preflight.top(stations) -> the NO-GO station to fix first, {} when every station is GO
##   Preflight.effect(id, n, base = Game.build) -> what n more (or fewer) of a part change, as Game.calc() deltas
##   Preflight.what_if(rocket_id, traj_idx) -> Game.calc() for another rocket or flight path

const RANK: Dictionary = {"ok": 0, "warn": 1, "bad": 2}
const WORD: Dictionary = {"ok": "GO", "warn": "GO, LOW MARGIN", "bad": "NO-GO"}

## Parts that do nothing at a destination and only add weight (rules.json: dead_weight_parts).
const DEAD: Dictionary = {
	"moon": ["heatshield", "chute"],
	"mars": ["ascent"],
	"saturn": ["legs", "airbags", "heatshield", "chute", "rover", "rover_big", "ascent", "battery", "battery_hi", "drill"],
}
## Samples that exist to be collected: goal + 2 rocks on the ground (surface.gd), 34 ice grains (probe.gd).
# shortcut: copies two numbers from the play screens; read them from Data if they ever move there.
const SATURN_GRAINS: int = 34

static func stations() -> Array:
	var c: Dictionary = Game.calc()
	var out: Array = [_booster(c), _power(c), _fuel(c)]
	out.append(_drone() if Game.dest_id == "saturn" else _landing(c))
	out.append(_science(c))
	out.append(_data(c))
	out.append(_comms(c))
	if Game.dest_id == "moon":
		out.append(_return(c))
	out.append(_budget(c))
	out.append(_time(c))
	out.append(_risk(c, out))
	return out

static func top(list: Array) -> Dictionary:
	var best: Dictionary = {}
	for s: Dictionary in list:
		if s["status"] == "bad" and (best.is_empty() or int(s["prio"]) < int(best["prio"])):
			best = s
	return best

static func count(list: Array, status: String) -> int:
	var n: int = 0
	for s: Dictionary in list:
		if s["status"] == status:
			n += 1
	return n

static func effect(id: String, n: int, base: Dictionary = {}) -> Dictionary:
	var keep: Dictionary = Game.build
	Game.build = (keep if base.is_empty() else base).duplicate()
	var a: Dictionary = Game.calc()
	var left: int = Game.count(id) + n
	if left > 0:
		Game.build[id] = left
	else:
		Game.build.erase(id)
	var b: Dictionary = Game.calc()
	Game.build = keep
	var out: Dictionary = {}
	for k: String in ["mass", "cost", "gen", "draw_ops", "wh", "store", "prop_need", "rate"]:
		out[k] = float(b[k]) - float(a[k])
	return out

static func what_if(rocket_id: String, traj_idx: int) -> Dictionary:
	var keep_r: String = Game.rocket_id
	var keep_t: int = Game.traj_idx
	Game.rocket_id = rocket_id
	Game.traj_idx = traj_idx
	var c: Dictionary = Game.calc()
	Game.rocket_id = keep_r
	Game.traj_idx = keep_t
	return c

## "the Moon", "Mars", "Saturn": for use inside a sentence.
static func place() -> String:
	return {"moon": "the Moon", "mars": "Mars", "saturn": "Saturn"}[Game.dest_id]

static func money(v: float) -> String:
	return "$%sM" % (str(roundi(v)) if absf(v) >= 10.0 or is_equal_approx(v, roundf(v)) else "%.1f" % v)

# ---------------------------------------------------------------- helpers

static func _new(id: String, name: String, role: String, prio: int) -> Dictionary:
	return {"id": id, "name": name, "role": role, "prio": prio, "status": "ok", "value": "", "short": "",
		"frac": -1.0, "headline": "", "explain": "", "fact": "", "fix": [], "need": []}

## Records one finding. The first finding of the worst level gives the station its words;
## every further NO-GO adds the parts it misses, so the ship can show all of them.
static func _flag(s: Dictionary, level: String, headline: String, explain: String, fix: Array = [], need: Array = []) -> void:
	if s["headline"] == "" or int(RANK[level]) > int(RANK[s["status"]]):
		s["status"] = level
		s["headline"] = headline
		s["explain"] = explain
		s["fix"] = fix.duplicate()
		s["need"] = need.duplicate()
	elif level == "bad":
		(s["need"] as Array).append_array(need)

static func _f(v: Variant) -> String:
	return "0" if is_zero_approx(float(v)) else Game.fmt(v)

static func _nh(s: Dictionary, need: float, have: float, unit: String) -> void:
	s["value"] = "need %s have %s %s" % [_f(need), _f(have), unit]
	s["short"] = "%s/%s %s" % [_f(need), _f(have), unit]
	s["frac"] = need / have if have > 0.0 else (1.0 if need > 0.0 else 0.0)

static func _name(id: String) -> String:
	return String(Data.PARTS[id]["name"])

## Rockets that reach this destination and lift `mass` on the current path, as bin tile ids.
static func _rockets_for(mass: float, cheaper_than: float = INF) -> Array:
	var out: Array = []
	var mult: float = float(Game.traj()["cap_mult"])
	for id: String in Data.ROCKETS:
		var r: Dictionary = Data.ROCKETS[id]
		var caps: Dictionary = r["cap"]
		if caps.has(Game.dest_id) and float(caps[Game.dest_id]) * mult >= mass and float(r["cost"]) < cheaper_than and id != Game.rocket_id:
			out.append("rocket:" + id)
	return out

## Rockets that fly to this destination at all, biggest last.
static func _rockets_reaching() -> Array:
	var out: Array = []
	for id: String in Data.ROCKETS:
		if (Data.ROCKETS[id]["cap"] as Dictionary).has(Game.dest_id) and id != Game.rocket_id:
			out.append("rocket:" + id)
	return out

static var _probing: bool = false

## What can come off the ship without breaking another station, biggest saving first (by "mass", "cost" or "draw").
## Returns [{"id", "n", "save", "why"}]: spare fuel, parts that do nothing here, extras.
static func _trim(c: Dictionary, by: String) -> Array:
	var out: Array = []
	if _probing:
		return out
	_probing = true
	var keep: Dictionary = Game.build
	var bad0: Dictionary = {}
	for st: Dictionary in stations():
		if st["status"] == "bad":
			bad0[st["id"]] = true
	var want: int = ceili(float(c["prop_need"]) * (1.0 + float(Game.dest()["margin"])) / 100.0)
	for id: String in keep:
		var p: Dictionary = Data.PARTS[id]
		if p.get("locked_in", false):
			continue
		var n: int = 1
		var why: String = "you can fly without it"
		if id == "prop":
			n = int(keep[id]) - want
			why = "spare fuel"
			if n <= 0:
				continue
		elif (DEAD[Game.dest_id] as Array).has(id):
			n = int(keep[id])
			why = "it does nothing at %s" % place()
		Game.build = keep.duplicate()
		if int(keep[id]) - n > 0:
			Game.build[id] = int(keep[id]) - n
		else:
			Game.build.erase(id)
		var breaks: bool = false
		for st: Dictionary in stations():
			if st["status"] == "bad" and not bad0.has(st["id"]):
				breaks = true
		if not breaks and float(p.get(by, 0.0)) > 0.0:
			out.append({"id": id, "n": n, "save": float(p[by]) * n, "why": why})
	Game.build = keep
	_probing = false
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["save"]) > float(b["save"]))
	return out

## The best saving of a _trim list in words: "Take off the HEAT SHIELD (saves 150 kg: it does nothing at the Moon)."
static func _trim_words(list: Array, unit: String) -> String:
	if list.is_empty():
		return ""
	var t: Dictionary = list[0]
	if t["id"] == "prop":
		return "You carry %s kg more fuel than you need: open FUEL and press FILL TO NEED." % _f(float(t["n"]) * 100.0)
	return "Take off the %s (saves %s: %s)." % [_name(t["id"]).to_upper(), money(float(t["save"])) if unit == "$" else "%s %s" % [_f(t["save"]), unit], t["why"]]

static func _trim_tiles(list: Array) -> Array:
	var out: Array = []
	for t: Dictionary in list:
		out.append("-" + String(t["id"]))
	return out

# ---------------------------------------------------------------- stations

static func _booster(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("booster", "BOOSTER", "planner", 9)
	var rk: Dictionary = Data.ROCKETS[Game.rocket_id]
	var caps: Dictionary = rk["cap"]
	var mass: float = c["mass"]
	var cap: float = c["cap"]
	var heavy: Dictionary = Data.ROCKETS["heavy"]["cap"]
	s["fact"] = "A rocket can carry less the farther it must throw it: Falcon Heavy sends %s kg to Mars but %s kg toward Saturn." % [_f(heavy["mars"]), _f(heavy["saturn"])]
	s["value"] = "%s of %s kg" % [_f(mass), _f(cap)]
	s["short"] = "%s/%s kg" % [_f(mass), _f(cap)]
	s["frac"] = mass / cap if cap > 0.0 else 1.0
	var fits: Array = _rockets_for(mass)
	if fits.is_empty() and (not caps.has(Game.dest_id) or cap < float(Data.PARTS["bus"]["mass"])):
		fits = _rockets_reaching()   # none lifts this ship yet: first a rocket that gets there at all
		fits.reverse()
	var pick: String = String(Data.ROCKETS[String(fits[0]).trim_prefix("rocket:")]["name"]) if not fits.is_empty() else ""
	_flag(s, "ok", "%s lifts this ship with %d%% to spare." % [rk["name"], roundi(float(c["mass_margin"]) * 100.0)],
		"A lighter ship leaves room for more fuel and science.")
	if not caps.has(Game.dest_id):
		s["prio"] = 0
		s["value"] = "cannot reach"
		s["short"] = "cannot reach"
		_flag(s, "bad", "This rocket cannot fly to your destination.",
			"%s does not reach %s. Pick %s in the LAUNCHER tab." % [rk["name"], place(), pick], fits)
	elif cap < float(Data.PARTS["bus"]["mass"]):
		_flag(s, "bad", "%s is too small for any ship you can build here." % rk["name"],
			"It lifts %s kg and the bare spacecraft weighs %s kg. Choose %s." % [_f(cap), _f(Data.PARTS["bus"]["mass"]), pick], fits)
	elif mass > cap:
		# cheapest cure first: spare fuel and dead weight off, then a bigger rocket or the easier path, then extras off
		var trim: Array = _trim(c, "mass")
		var free: Array = trim.filter(func(t: Dictionary) -> bool: return t["why"] != "you can fly without it")
		var how: String = _trim_words(free, "kg")
		var tiles: Array = _trim_tiles(free)
		if float(Game.traj()["cap_mult"]) < 1.0:
			fits.append("path:0")
		if how == "":
			if not fits.is_empty() and String(fits[0]).begins_with("rocket:"):
				how = "Pick %s in the LAUNCHER tab." % pick
			elif not fits.is_empty():
				how = "Fly the other path in the LAUNCHER tab: on this one the rocket lifts far less."
			else:
				how = _trim_words(trim, "kg")
		tiles.append_array(fits)
		tiles.append_array(_trim_tiles(trim.filter(func(t: Dictionary) -> bool: return t["why"] == "you can fly without it")))
		_flag(s, "bad", "Your ship is heavier than this rocket can lift.",
			"It weighs %s kg; %s lifts %s kg on this path. %s" % [_f(mass), rk["name"], _f(cap), how], tiles)
	elif c["status"]["mass"] == "warn":
		_flag(s, "warn", "You are close to the rocket's weight limit.",
			"Only %d%% to spare; aim for %d%%. Trim fuel to just above the green FUEL level, or drop unused parts." % [roundi(float(c["mass_margin"]) * 100.0), roundi(float(Game.dest()["margin"]) * 100.0)])
	return s

static func _power(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("power", "POWER", "engineer", 2)
	var d: Dictionary = Game.dest()
	var gen: float = c["gen"]
	var draw: float = c["draw_ops"]
	var far: bool = Game.dest_id == "saturn"
	var makers: Array = ["rtg"] if far else ["solar", "solar_lite", "rtg"]
	var add: String = "RTGs: solar panels barely work this far from the Sun" if far else "a solar array"
	s["fact"] = "Sunlight falls with the square of distance from the Sun: at %s it is %s%% of Earth's." % [place(), _f(100.0 / pow(float(d["sun_au"]), 2.0))]
	s["value"] = "need %s have %s W" % [_f(roundf(draw)), _f(roundf(gen))]
	s["short"] = "%s/%s W" % [_f(roundf(draw)), _f(roundf(gen))]
	s["frac"] = draw / gen if gen > 0.0 else 1.0
	var night: String = ""
	if float(c["night_need"]) > 0.0:
		night = " The night needs %s Wh; you carry %s Wh." % [_f(c["night_need"]), _f(c["wh"])]
	_flag(s, "ok", "Makes %s W and uses %s W at %s." % [_f(roundf(gen)), _f(roundf(draw)), place()], night.strip_edges())
	if gen < float(c["draw_cruise"]):
		_flag(s, "bad", "The ship runs out of electricity on the way there.",
			"It needs %s W just to stay warm and talk, but makes %s W at %s. Add %s." % [_f(roundf(float(c["draw_cruise"]))), _f(roundf(gen)), place(), add], makers, [makers[0]])
	elif gen < draw:
		var can_add: bool = makers.any(func(id: String) -> bool: return Game.part_available(id) and Game.count(id) < int(Data.PARTS[id]["max"]))
		var trim: Array = _trim(c, "draw")
		var how: String = "Add %s." % add
		if not can_add:
			how = "No more power parts fit. %s" % _trim_words(trim, "W")
		elif not trim.is_empty():
			how = "Add %s, or take off the %s (%s W)." % [add, _name(trim[0]["id"]).to_upper(), _f(trim[0]["save"])]
		_flag(s, "bad", "Your ship uses more power than it makes.",
			"It uses %s W but makes %s W at %s. %s" % [_f(roundf(draw)), _f(roundf(gen)), place(), how], makers + _trim_tiles(trim), [makers[0]])
	if float(c["wh"]) < float(c["night_need"]):
		if gen >= draw:
			_nh(s, float(c["night_need"]), float(c["wh"]), "Wh")
		_flag(s, "bad", "Without enough batteries the rover dies in the Mars night.",
			"The %s-hour night needs %s Wh; you carry %s Wh. Add batteries, or an RTG that works in the dark." % [str(d["night_hours"]), _f(c["night_need"]), _f(c["wh"])],
			["battery", "battery_hi", "rtg"], ["battery"])
	elif c["status"]["power"] == "warn":
		_flag(s, "warn", "Power is enough, but with little to spare.",
			"%s W made, %s W used. Aim for %d%% extra: add %s." % [_f(roundf(gen)), _f(roundf(draw)), roundi(float(d["margin"]) * 100.0), add], makers)
	return s

static func _fuel(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("fuel", "FUEL", "engineer", 8)
	var need: float = c["prop_need"]
	var prop: float = c["prop"]
	var capture: float = float(c["dv"]["capture"])
	var lands: bool = float(c["dv"]["landing"]) > 0.0
	_nh(s, need, prop, "kg")
	s["fact"] = "The rocket equation: every kg you carry needs fuel to stop it, and that fuel needs fuel too."
	var job: String = "braking into orbit"
	if lands:
		job = "braking into orbit and landing" if capture > 0.0 else "the landing engine"
	_flag(s, "ok", "%s kg on board, %s kg needed for %s." % [_f(prop), _f(need), job], "")
	if c["status"]["fuel"] == "bad":
		var head: String = "Not enough fuel for the landing engine."
		if float(c["mass"]) * (1.0 - exp(-capture / Game.ve())) > prop:
			head = "Not enough fuel to slow down and enter orbit: the ship flies past."
		elif Game.dest_id == "moon":
			head = "Not enough fuel to come down from Moon orbit."
		_flag(s, "bad", head, "Need %s kg, have %s kg. Add PROPELLANT or press FILL TO NEED. Do it last: every new part needs more fuel." % [_f(need), _f(prop)],
			["prop"], ["prop"])
	elif c["status"]["fuel"] == "warn":
		_flag(s, "warn", "You have almost no spare fuel%s." % (" for the landing" if lands else ""),
			"%s kg needed, %s kg on board. Add one or two more PROPELLANT units." % [_f(need), _f(prop)], ["prop"])
	return s

static func _landing(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("landing", "LANDING", "engineer", 3)
	var mars: bool = Game.dest_id == "mars"
	var touch: float = c["touch"]
	s["value"] = "safe up to %s m/s" % str(roundi(touch))
	s["short"] = "max %s m/s" % str(roundi(touch))
	s["fact"] = "Mars' air is under 1% of Earth's: thick enough to burn a lander, too thin to stop it." if mars else "The Moon has no air, so only the engine can slow the lander down."
	_flag(s, "ok", "Safe touchdown up to %s m/s." % str(roundi(touch)),
		"The heat shield and parachute do the fast part; the engine does the rest." if mars else "Fly the engine down gently and keep it level.")
	if mars and not Game.id_has("heatshield"):
		s["value"] = "no heat shield"
		s["short"] = "no heat shield"
		_flag(s, "bad", "Without a heat shield the lander burns up in Mars' air.",
			"Add the HEAT SHIELD. It also brakes into orbit, so you need far less fuel.", ["heatshield"], ["heatshield"])
	if mars and not Game.id_has("chute"):
		if Game.id_has("heatshield"):
			s["value"] = "no parachute"
			s["short"] = "no parachute"
		_flag(s, "bad", "Without a parachute you hit Mars far too fast for any engine to stop.",
			"Add the SUPERSONIC PARACHUTE: it slows you from 420 m/s to 90 m/s.", ["chute"], ["chute"])
	if not Game.id_has("legs") and not Game.id_has("airbags"):
		_flag(s, "bad", "With no legs or airbags you must touch down slower than 1 m/s.",
			"Add AIRBAGS (safe up to %s m/s, the easy way) or LANDING LEGS (%s m/s, lighter)." % [str(int(Data.PARTS["airbags"]["touch"])), str(int(Data.PARTS["legs"]["touch"]))],
			["airbags", "legs"], ["airbags"])
	return s

static func _drone() -> Dictionary:
	var s: Dictionary = _new("drone", "DRONE", "science", 3)
	s["value"] = "drone ready"
	s["short"] = "ready"
	s["fact"] = "In 2017 Cassini dived 22 times between Saturn and its rings."
	var hits: String = "The armored drone survives 3 hits" if Game.tech.has("armor") else "The drone survives only one hit"
	_flag(s, "ok", "%s and has limited fuel: fly back to the orbiter in time." % hits,
		"Leave the dock right away, grab the ice grains, then come back." if Game.tech.has("armor") else "ARMOR from the Tech Lab lets it take more hits.")
	if not Game.id_has("drone"):
		s["value"] = "no drone"
		s["short"] = "no drone"
		_flag(s, "bad", "Saturn has no ground: without the drone nothing can collect samples.",
			"Add the SAMPLING DRONE from the ROBOTS tab.", ["drone"], ["drone"])
	return s

static func _science(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("science", "SCIENCE", "science", 4)
	var d: Dictionary = Game.dest()
	var goal: int = int(d["samples_goal"])
	var pts: int = int(c["pts"])
	var what: String = "ice grains" if Game.dest_id == "saturn" else "rocks"
	s["value"] = "%d %s x %d pt%s" % [goal, what, pts, "" if pts == 1 else "s"]
	s["short"] = "%d x %d pt%s" % [goal, pts, "" if pts == 1 else "s"]
	s["fact"] = {"moon": "Apollo 11 brought home 21.5 kg of Moon rock.",
		"mars": "The first Mars rover, Sojourner (1997), weighed just 11.5 kg.",
		"saturn": "Cassini's dust analyzer studied the grains of Saturn's rings."}[Game.dest_id]
	_flag(s, "ok", "You must collect the full number of samples for this mission: %d %s." % [goal, what],
		"Each sample makes %s Gb of data and earns %d science points." % [_f(c["gb_per_sample"]), pts])
	if Game.dest_id == "saturn":
		if float(c["gb_per_sample"]) <= 0.0:
			s["value"] = "no instrument"
			s["short"] = "no instrument"
			_flag(s, "bad", "Bring at least one science instrument or there is nothing to send home.",
				"Add the DUST ANALYZER, or the lighter MAGNETOMETER.", ["dust", "mag", "camera", "spectro"], ["dust"])
	else:
		if not Game.id_has("drill"):
			s["value"] = "no drill"
			s["short"] = "no drill"
			_flag(s, "bad", "No drill: you cannot pick up any rock.", "Add the SAMPLE DRILL AND ARM.", ["drill"], ["drill"])
		if not Game.id_has("rover") and not Game.id_has("rover_big"):
			if Game.id_has("drill"):
				s["value"] = "no rover"
				s["short"] = "no rover"
			_flag(s, "bad", "Without a rover you can reach only one rock, and you get stuck on the surface.",
				"Add the SMALL ROVER from the ROBOTS tab.", ["rover", "rover_big"], ["rover"])
	if pts <= 1:
		_flag(s, "warn", "Add a science instrument.",
			"Each sample earns only %d point now. A camera or a spectrometer earns more credits for the Tech Lab." % pts,
			["dust", "mag"] if Game.dest_id == "saturn" else ["camera", "spectro"])
	return s

static func _data(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("data", "DATA", "comms", 6)
	var d: Dictionary = Game.dest()
	var goal: int = int(d["samples_goal"])
	var gb: float = c["gb_per_sample"]
	var store: float = c["store"]
	var all: float = gb * (SATURN_GRAINS if Game.dest_id == "saturn" else goal + 2)
	_nh(s, float(c["data_exp"]), store, "Gb")
	s["fact"] = "One look by the CRISM spectrometer on Mars Reconnaissance Orbiter makes 2 to 2.5 Gb."
	_flag(s, "ok", "%d samples make %s Gb; the ship stores %s Gb." % [goal, _f(c["data_exp"]), _f(store)], "")
	if gb <= 0.0:
		s["value"] = "no science data"
		s["short"] = "no data"
		s["frac"] = 1.0
		var inst: Array = ["dust", "mag"] if Game.dest_id == "saturn" else ["drill", "camera", "spectro"]
		_flag(s, "bad", "Bring at least one science instrument or there is nothing to send home.",
			"Samples only turn into data when an instrument looks at them. Add one from the SCIENCE tab.", inst)
	elif store < float(c["data_exp"]):
		_flag(s, "bad", "Storage is too small for the science data.",
			"%d samples make %s Gb but only %s Gb fit. Add a DATA RECORDER." % [goal, _f(c["data_exp"]), _f(store)], ["recorder"], ["recorder"])
	elif store < all:
		_flag(s, "warn", "Storage is full: extra science is thrown away.",
			"Collecting every sample would make %s Gb; only %s Gb fit. Add a DATA RECORDER." % [_f(all), _f(store)], ["recorder"])
	elif c["status"]["data"] == "warn":
		_flag(s, "warn", "Storage only just fits the science data.", "Add a DATA RECORDER for spare room.", ["recorder"])
	return s

static func _comms(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("comms", "COMMS", "comms", 7)
	var d: Dictionary = Game.dest()
	var goal: int = int(d["samples_goal"])
	var exp_gb: float = c["data_exp"]
	var down: float = c["downlink"]
	var all: float = float(c["gb_per_sample"]) * (SATURN_GRAINS if Game.dest_id == "saturn" else goal + 2)
	var best: String = {"moon": "lga", "mars": "mga", "saturn": "hga"}[Game.dest_id]
	# antennas faster than the one on board
	var faster: Array = []
	for id: String in ["mga", "hga", "ka"]:
		if not Game.id_has(id) and minf(float(Data.PARTS[id]["rate"]) / pow(float(d["earth_au"]), 2.0), float(Data.PARTS[id]["rate_cap"])) > float(c["rate"]):
			faster.append(id)
	_nh(s, exp_gb, down, "Gb")
	s["fact"] = "Radio speed falls with the square of distance. A signal from %s takes %s." % [place(), d["light_delay"]]
	_flag(s, "ok", "The antenna can send %s Gb in %d days; the science is %s Gb." % [_f(down), int(d["ops_days"]), _f(exp_gb)], "")
	if float(c["rate"]) <= 0.0:
		s["value"] = "no antenna"
		s["short"] = "no antenna"
		s["frac"] = 1.0
		_flag(s, "bad", "No antenna: your science never reaches Earth.",
			"Add an antenna from the COMMS tab. The %s is enough for %s." % [_name(best).to_upper(), place()],
			[best] + ["lga", "mga", "hga", "ka"].filter(func(id: String) -> bool: return id != best), [best])
	elif down < exp_gb:
		_flag(s, "bad", "Your antenna is too slow to send all the science home in time.",
			"It sends %s Gb in %d days, but %d samples make %s Gb. Use a bigger dish or lighter instruments." % [_f(down), int(d["ops_days"]), goal, _f(exp_gb)], faster)
	elif down < all:
		_flag(s, "warn", "Your antenna is too slow to send all the science home in time.",
			"Fine for %d samples (%s Gb), but collect many more and not all of it gets home: it sends %s Gb at most." % [goal, _f(exp_gb), _f(down)], faster)
	elif c["status"]["comms"] == "warn":
		_flag(s, "warn", "The antenna only just keeps up with the science.", "A bigger dish gives spare time.", faster)
	return s

static func _return(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("return", "RETURN", "science", 5)
	s["value"] = "ascent stage ready"
	s["short"] = "ready"
	s["fact"] = "Apollo left its landing stage on the Moon and flew home in a separate ascent stage."
	_flag(s, "ok", "The ascent stage will carry the rocks home.", "Keep at least 30% battery or its engine will not start.")
	if not Game.id_has("ascent"):
		s["value"] = "no ascent stage"
		s["short"] = "no stage"
		_flag(s, "bad", "No ascent stage: your rocks can never leave the Moon.",
			"Add the ASCENT STAGE from the RETURN tab. It weighs %s kg, so it needs a lot more fuel." % _f(Data.PARTS["ascent"]["mass"]), ["ascent"], ["ascent"])
	elif float(c["gen"]) < float(c["draw_ops"]):
		_flag(s, "warn", "Keep at least 30% battery or the ascent engine will not start.",
			"The ship uses more power than it makes, so the battery will run down. Fix POWER, and carry a battery as reserve.", ["solar", "battery"])
	elif not Game.id_has("drill"):
		_flag(s, "warn", "The ascent stage needs at least one rock on board to count.", "Bring a drill and a rover.", ["drill"])
	return s

static func _budget(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("budget", "BUDGET", "planner", 10)
	var cost: float = c["cost"]
	var budget: float = c["budget"]
	s["value"] = "%s of %s" % [money(cost), money(budget)]
	s["short"] = "$%d/%dM" % [roundi(cost), roundi(budget)]
	s["frac"] = cost / budget
	s["fact"] = "NASA's CAPSTONE Moon probe cost $13.7M, plus $9.95M for its launch on Electron."
	var split: String = "Parts %s + rocket %s + mission control %s." % [money(float(c["parts_cost"])), money(float(c["rocket_cost"])), money(float(c["ops_cost"]))]
	_flag(s, "ok", "The mission costs %s of your %s." % [money(cost), money(budget)], split)
	if c["status"]["budget"] == "bad":
		var cheaper: Array = _rockets_for(float(c["mass"]), float(c["rocket_cost"]))
		var trim: Array = _trim(c, "cost").filter(func(t: Dictionary) -> bool: return float(t["save"]) >= 1.0)
		var how: String = _trim_words(trim, "$")
		if not cheaper.is_empty():
			how = "A cheaper rocket still lifts this ship: pick %s." % String(Data.ROCKETS[String(cheaper[0]).trim_prefix("rocket:")]["name"])
		elif how == "" and Game.id_has("rtg") and Game.dest_id != "saturn" and not Game.id_has("solar"):
			how = "Swap the nuclear RTGs for solar arrays: add a SOLAR ARRAY (%s), then take off an RTG (%s)." % [money(float(Data.PARTS["solar"]["cost"])), money(float(Data.PARTS["rtg"]["cost"]))]
			cheaper = ["solar"]
		elif how == "":
			how = "Nothing more can come off. The ship still flies, but the planner loses points."
		_flag(s, "bad", "The mission costs more than your budget.", "%s %s" % [split, how], cheaper + _trim_tiles(trim))
	elif c["status"]["budget"] == "warn":
		_flag(s, "warn", "The budget is almost used up.", split)
	return s

static func _time(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("time", "TIME", "planner", 11)
	var d: Dictionary = Game.dest()
	var t: Dictionary = Game.traj()
	s["value"] = "%s of %s days" % [_f(c["days"]), _f(c["limit"])]
	s["short"] = "%s/%s d" % [_f(c["days"]), _f(c["limit"])]
	s["frac"] = float(c["days"]) / float(c["limit"])
	s["fact"] = String(t["src"])
	_flag(s, "ok", "Mission time is always within the limit.",
		"%s days of travel + %d days of work at %s. A longer trip costs %s a year in mission control." % [_f(t["days"]), int(d["ops_days"]), place(), money(Data.OPS_COST_PER_YEAR)])
	if c["status"]["time"] == "bad":
		_flag(s, "bad", "The mission takes too long.", "Pick the faster flight path in the LAUNCHER tab.", ["path:0", "path:1"])
	return s

## Things that do not stop the launch: storms, low margins, wasted parts.
static func _risk(c: Dictionary, list: Array) -> Dictionary:
	var s: Dictionary = _new("risk", "RISK", "engineer", 12)
	s["fact"] = "The storms in this game are real 2024 events from NASA's DONKI space weather database."
	var risks: Array = []
	_flag(s, "ok", "No open risks.", "Radiation shielding protects the electronics from solar storms.")
	if not Game.id_has("shield"):
		# same odds as Game.phase_cruise: Saturn always meets the strongest storm, others 35% + a random real event
		var strong: int = 0
		for ev: Dictionary in Data.donki:
			if float(ev["kp"]) >= 7.5:
				strong += 1
		var odds: String = "every flight" if Game.dest_id == "saturn" else "about %d of 10 flights" % roundi(10.0 * (0.35 + 0.65 * strong / maxf(1.0, Data.donki.size())))
		risks.append("storm")
		_flag(s, "warn", "A solar storm can break your antenna or an instrument on the way.",
			"A strong storm hits %s to %s. Add RADIATION SHIELDING (%s kg, %s)." % [odds, place(), _f(Data.PARTS["shield"]["mass"]), money(float(Data.PARTS["shield"]["cost"]))], ["shield"])
	var low: PackedStringArray = []
	for st: Dictionary in list:
		if st["status"] == "warn":
			low.append(String(st["name"]))
	if not low.is_empty():
		var words: String = "Low margin: %s." % ", ".join(low)
		if risks.is_empty():
			_flag(s, "warn", words, "A yellow lamp is GO, but with little room for surprises. Tap it to see why.")
		else:
			s["explain"] = "%s %s" % [s["explain"], words]
		risks.append("margin")
	# tips: true, but they do not change the lamp
	var tip: String = ""
	var antennas: int = 0
	for id: String in ["lga", "mga", "hga", "ka"]:
		antennas += Game.count(id)
	var dead: Array = []
	for id: String in DEAD[Game.dest_id]:
		if Game.id_has(id):
			dead.append(_name(id))
	if antennas > 1:
		tip = "Only your best antenna is used; extra ones just waste power."
	elif not dead.is_empty():
		tip = "%s does nothing at %s and only adds weight." % [dead[0], place()]
	elif Game.id_has("rover_big") and Game.dest_id == "moon":
		tip = "The big rover is fast but heavy and expensive."
	if tip != "":
		if risks.is_empty():
			s["headline"] = "No open risks. One tip:"
			s["explain"] = tip
		else:
			s["explain"] = "%s Tip: %s" % [s["explain"], tip]
	s["value"] = "none" if risks.is_empty() else ("storm: no shield" if risks[0] == "storm" else "low margin")
	s["short"] = s["value"]
	return s
