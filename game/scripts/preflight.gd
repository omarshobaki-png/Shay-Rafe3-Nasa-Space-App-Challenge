extends RefCounted
## Pre-flight check: turns the current Game state into Mission Control's GO / NO-GO board.
## Pure data, no drawing; nothing here changes the simulation. The builder screen shows it.
## Works for all eight destinations from the fields of Data.DEST (kind, air, returns, hazards), never from ids.
##
##   Preflight.stations() -> Array of station Dictionaries, in flight order:
##       booster, power, fuel, landing | drone, [heat], [pressure], [radiation], science, data, comms, [return],
##       budget, time, risk   (bracketed ones only where the destination has that hazard or returns samples)
##     "id"       String  one of the names above
##     "name"     String  label on the board
##     "role"     String  id from Data.ROLES: the player who watches this lamp
##     "status"   String  "ok" (GO) | "warn" (GO, but under the NASA margin: an unlucky event could end it) | "bad" (NO-GO)
##     "value"    String  need against have in one short line; "short" says the same without words
##     "frac"     float   gauge: need / have (1.0 = at the limit); -1.0 = this station has no gauge
##     "lo", "hi" float   where the WELL USED zone of that gauge starts and ends (0..1); -1.0 = no band
##     "critical" bool    this resource is one of the destination's critical ones (Data.DEST[..]["critical"])
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
##   Preflight.part_need(id) -> {"level", "label", "why"}: how much this mission needs a part (design 8b)
##   Preflight.checklist() -> the short ordered build steps for this destination (design 8b)

const RANK: Dictionary = {"ok": 0, "warn": 1, "bad": 2}
const WORD: Dictionary = {"ok": "GO", "warn": "GO, LOW MARGIN", "bad": "NO-GO"}
## What a yellow lamp means, in the builder's words.
const YELLOW: String = "GO, but an unlucky event could end it."
const NEED_LABEL: Dictionary = {"required": "REQUIRED", "recommended": "RECOMMENDED", "optional": "OPTIONAL", "not_needed": "NOT NEEDED HERE"}

## Parts that can be put on the ship but do nothing at a destination and only add weight.
const DEAD: Dictionary = {
	"moon": ["heatshield", "chute"],
	"mercury": ["heatshield", "chute"],
	"venus": ["chute", "legs", "airbags"],
	"mars": [],
	"jupiter": ["battery", "battery_hi"],
	"saturn": ["battery", "battery_hi"],
	"uranus": ["battery", "battery_hi"],
	"neptune": ["battery", "battery_hi"],
}
## Samples that exist to be collected: goal + 2 rocks on the ground (surface.gd), 34 ice grains (probe.gd).
# shortcut: copies two numbers from the play screens; read them from Data if they ever move there.
const RING_GRAINS: int = 34
const SATURN_GRAINS: int = RING_GRAINS
## Power of a typical working ship (bus, antenna, instruments, robot), used to say whether sunlight can run one here. Game estimate.
const TYPICAL_DRAW_W: float = 150.0
const SCIENCE_FACT: Dictionary = {
	"moon": "Apollo 11 brought home 21.5 kg of Moon rock.",
	"mercury": "No lander has ever been sent to Mercury: MESSENGER studied it from orbit.",
	"venus": "Venera 13 drilled the soil of Venus in 1982 and sent the first colour pictures from its surface.",
	"mars": "The first Mars rover, Sojourner (1997), weighed just 11.5 kg.",
	"jupiter": "Jupiter has faint dust rings: a halo, a main ring and two gossamer rings (NASA).",
	"saturn": "Cassini's dust analyzer studied the grains of Saturn's rings.",
	"uranus": "Uranus has 13 dark, narrow rings (NASA).",
	"neptune": "Neptune has five named rings; the outer one, Adams, carries bright arcs (NASA).",
}

static func stations() -> Array:
	var c: Dictionary = Game.calc()
	var d: Dictionary = Game.dest()
	var out: Array = [_booster(c), _power(c), _fuel(c)]
	out.append(_landing(c) if d["kind"] == "land" else _drone())
	if Game.has_hazard("heat"):
		out.append(_heat())
	if Game.has_hazard("pressure"):
		out.append(_pressure())
	if Game.has_hazard("radiation"):
		out.append(_radiation())
	out.append(_science(c))
	out.append(_data(c))
	out.append(_comms(c))
	if bool(d["returns"]):
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

## "the Moon", "Mars", "Neptune": for use inside a sentence.
static func place() -> String:
	return "the Moon" if Game.dest_id == "moon" else String(Game.dest()["name"]).capitalize()

static func money(v: float) -> String:
	return "$%sM" % (str(roundi(v)) if absf(v) >= 10.0 or is_equal_approx(v, roundf(v)) else "%.1f" % v)

# ---------------------------------------------------------------- helpers

static func _new(id: String, name: String, role: String, prio: int) -> Dictionary:
	return {"id": id, "name": name, "role": role, "prio": prio, "status": "ok", "value": "", "short": "",
		"frac": -1.0, "lo": -1.0, "hi": -1.0, "critical": false, "headline": "", "explain": "", "fact": "", "fix": [], "need": []}

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

## Puts the WELL USED zone of a resource (Game.calc()["use"][key]) on the station's gauge, whose fill is need / have.
static func _band(s: Dictionary, c: Dictionary, key: String) -> void:
	var u: Dictionary = c["use"][key]
	s["critical"] = (Game.dest()["critical"] as Array).has(key)
	if u["band_on"] == "need":   # fixed limit: the zone is a share of the limit
		s["lo"] = clampf(float(u["lo"]) / maxf(1.0, float(u["have"])), 0.0, 1.0)
		s["hi"] = clampf(float(u["hi"]) / maxf(1.0, float(u["have"])), 0.0, 1.0)
	elif float(u["need"]) > 0.0:   # carried: more on board = a shorter bar, so the zone's ends swap
		s["lo"] = clampf(float(u["need"]) / maxf(1.0, float(u["hi"])), 0.0, 1.0)
		s["hi"] = clampf(float(u["need"]) / maxf(1.0, float(u["lo"])), 0.0, 1.0)

static func _name(id: String) -> String:
	return String(Data.PARTS[id]["name"])

static func _pct(key: String) -> int:
	return roundi(float(Data.MARGIN[key]) * 100.0)

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

## Watts one unit of a power part makes while working at this destination (after the cruise).
static func _unit_w(id: String, c: Dictionary) -> float:
	var d: Dictionary = Game.dest()
	var p: Dictionary = Data.PARTS[id]
	if p["kind"] == "rtg":
		return float(p["gen"]) * (0.5 if float(c["years"]) > Data.RTG_LIFE_YEARS else 1.0)
	var sun: float = float(d["sun_au"])
	return float(p["gen"]) / (sun * sun) * pow(1.0 - Data.SOLAR_DECAY_PER_YEAR, float(c["years"])) * (1.0 if d.has("surface_minutes") else float(d["dust"]))

## The cheapest power part that can run a typical ship here with the margin: "solar", "solar_lite" or "rtg".
static func _power_part(c: Dictionary) -> String:
	var want: float = TYPICAL_DRAW_W * (1.0 + float(Data.MARGIN["power"]))
	var best: String = "rtg"
	var best_cost: float = INF
	for id: String in ["solar", "solar_lite", "rtg"]:
		var p: Dictionary = Data.PARTS[id]
		var unit: float = _unit_w(id, c)
		if not Game.part_available(id) or unit <= 0.0 or ceilf(want / unit) > float(p["max"]):
			continue
		var cost: float = ceilf(want / unit) * float(p["cost"])
		if cost < best_cost:
			best_cost = cost
			best = id
	return best

## Gb an antenna sends home in the contact time this destination gives.
static func _down(id: String, c: Dictionary) -> float:
	var p: Dictionary = Data.PARTS[id]
	var au: float = float(Game.dest()["earth_au"])
	return minf(float(p["rate"]) / (au * au), float(p["rate_cap"])) * float(c["window_s"]) / 1000.0

## Gb of science to plan the radio for: what this ship makes, and at least what the basic kit makes
## (drill + camera on the ground, dust analyzer at the rings).
static func _data_ref(c: Dictionary) -> float:
	return maxf(float(c["data_exp"]), float(Game.dest()["samples_goal"]) * (0.6 if Game.dest()["kind"] == "land" else 0.3))

## The cheapest antenna the player can use that sends twice the science (the 3 dB margin); the fastest one if none can.
static func _antenna(c: Dictionary) -> String:
	var want: float = _data_ref(c) * float(Data.MARGIN["comms"])
	var best: String = ""
	var fastest: String = "lga"
	for id: String in ["lga", "mga", "hga", "ka"]:
		if not Game.part_available(id):
			continue
		if _down(id, c) > _down(fastest, c):
			fastest = id
		if _down(id, c) >= want and (best == "" or float(Data.PARTS[id]["cost"]) < float(Data.PARTS[best]["cost"])):
			best = id
	return best if best != "" else fastest

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
	var want: int = ceili(float(c["prop_ok"]) / float(Data.PARTS["prop"]["mass"]))
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
	s["fact"] = "A rocket lifts less the farther it throws: Falcon Heavy sends %s kg to Mars, %s kg to Neptune (game estimate)." % [_f(heavy["mars"]), _f(heavy["neptune"])]
	s["value"] = "%s of %s kg" % [_f(mass), _f(cap)]
	s["short"] = "%s/%s kg" % [_f(mass), _f(cap)]
	s["frac"] = mass / cap if cap > 0.0 else 1.0
	_band(s, c, "mass")
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
		_flag(s, "warn", "The rocket has only %d%% of its lift to spare." % roundi(float(c["mass_margin"]) * 100.0),
			"%s JPL asks for a %d%% margin on dry mass this early; the game keeps that share of the rocket's lift spare. Trim fuel, drop parts, or pick a bigger rocket." % [YELLOW, _pct("mass")],
			_rockets_for(mass / (1.0 - float(Data.MARGIN["mass"]))))
	elif c["use"]["mass"]["rating"] == "under":
		s["explain"] = "A cheaper rocket would still lift this ship with the %d%% margin." % _pct("mass")
	return s

static func _power(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("power", "POWER", "engineer", 2)
	var d: Dictionary = Game.dest()
	var gen: float = c["gen"]
	var draw: float = c["power_need"]
	var land: bool = d["kind"] == "land"
	var battery_only: bool = d.has("surface_minutes")
	var main: String = _power_part(c)
	var far: bool = main == "rtg"
	var makers: Array = ["rtg"] if far else [main, "rtg"]
	var add: String = "nuclear batteries (RTGs): sunlight is too weak here" if far else "a solar array"
	s["fact"] = "Sunlight falls with the square of distance from the Sun: at %s it is %s%% of Earth's." % [place(), _f(100.0 / pow(float(d["sun_au"]), 2.0))]
	s["value"] = "need %s have %s W" % [_f(roundf(draw)), _f(roundf(gen))]
	s["short"] = "%s/%s W" % [_f(roundf(draw)), _f(roundf(gen))]
	s["frac"] = draw / gen if gen > 0.0 else 1.0
	_band(s, c, "power")
	var dark: String = "the %s-hour night (half a sol: game estimate)" % str(d["night_hours"])
	if battery_only:
		dark = "the %d minutes on the ground, with no sunlight to recharge" % int(d["surface_minutes"])
	var night: String = ""
	if float(c["night_need"]) > 0.0:
		night = "The battery must cover %s: %s Wh needed, %s Wh on board." % [dark, _f(c["night_need"]), _f(c["wh"])]
	_flag(s, "ok", "Makes %s W and uses %s W%s." % [_f(roundf(gen)), _f(roundf(draw)), " on the way" if battery_only else " at %s" % place()], night)
	if float(c["gen_space"]) < float(c["draw_cruise"]):
		_flag(s, "bad", "The ship runs out of electricity on the way there.",
			"It needs %s W just to stay warm and talk, but makes %s W at %s. Add %s." % [_f(roundf(float(c["draw_cruise"]))), _f(roundf(float(c["gen_space"]))), place(), add], makers, [makers[0]])
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
	if float(c["wh"]) < float(c["night_need"]) or (land and float(c["wh"]) <= 0.0):
		if gen >= draw:
			_nh(s, float(c["night_need"]), float(c["wh"]), "Wh")
			_band(s, c, "battery")
		var head: String = "Without enough batteries the rover dies in the night."
		if battery_only:
			head = "On %s the lander lives on its battery alone." % place()
		elif float(c["night_need"]) <= 0.0:
			head = "The lander runs on a battery at the site: the ship has none."
		_flag(s, "bad", head,
			"%s Add batteries%s." % [night if night != "" else "One battery is enough to start.", "" if battery_only else ", or an RTG that works in the dark"],
			["battery", "battery_hi"] if battery_only else ["battery", "battery_hi", "rtg"], ["battery"])
	elif c["status"]["power"] == "warn":
		if c["status"]["battery"] == "warn":
			_nh(s, float(c["night_need"]), float(c["wh"]), "Wh")
			_band(s, c, "battery")
			_flag(s, "warn", "The battery only just covers the dark hours.",
				"%s JPL asks for a %d%% energy margin this early. %s" % [YELLOW, _pct("battery"), night], ["battery", "battery_hi"])
		else:
			_flag(s, "warn", "Power is enough, but with little to spare.",
				"%s JPL asks for a %d%% power margin this early: %s W made, %s W used. Add %s." % [YELLOW, _pct("power"), _f(roundf(gen)), _f(roundf(draw)), add], makers)
	return s

static func _fuel(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("fuel", "FUEL", "engineer", 8)
	var need: float = c["prop_need"]
	var prop: float = c["prop"]
	var capture: float = float(c["dv"]["capture"])
	var lands: bool = float(c["dv"]["landing"]) > 0.0
	_nh(s, need, prop, "kg")
	_band(s, c, "fuel")
	s["fact"] = "The rocket equation: every kg you carry needs fuel to stop it, and that fuel needs fuel too."
	var job: String = "course corrections and braking into orbit"
	if lands:
		job = "braking into orbit and landing" if capture > 0.0 else "course corrections and the landing engine"
	elif capture <= 0.0:
		job = "course corrections: the air does the braking"
	_flag(s, "ok", "%s kg on board, %s kg needed for %s." % [_f(prop), _f(need), job], "")
	if c["status"]["fuel"] == "bad":
		var head: String = "Not enough fuel for the landing engine."
		if float(c["mass"]) * (1.0 - exp(-(capture + float(c["dv"]["cruise"])) / Game.ve())) > prop:
			head = "Not enough fuel to slow down and enter orbit: the ship flies past." if capture > 0.0 else "Not enough fuel to steer on the way there."
		elif Game.dest()["air"] == "none":
			head = "Not enough fuel to come down from orbit: there is no air to help."
		_flag(s, "bad", head, "Need %s kg, have %s kg. Add PROPELLANT or press FILL TO NEED. Do it last: every new part needs more fuel." % [_f(need), _f(prop)],
			["prop"], ["prop"])
	elif c["status"]["fuel"] == "warn":
		_flag(s, "warn", "You have almost no spare fuel%s." % (" for the landing" if lands else ""),
			"%s Carry fuel for %d%% of the planned speed change: %s kg. You have %s kg." % [YELLOW, 100 + _pct("fuel"), _f(c["prop_ok"]), _f(prop)], ["prop"])
	return s

static func _landing(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("landing", "LANDING", "engineer", 3)
	var air: String = Game.dest()["air"]
	var touch: float = c["touch"]
	s["value"] = "safe up to %s m/s" % str(roundi(touch))
	s["short"] = "max %s m/s" % str(roundi(touch))
	if air == "thin":
		s["fact"] = "Mars' air is under 1% of Earth's: thick enough to burn a lander, too thin to stop it."
		_flag(s, "ok", "Safe touchdown up to %s m/s." % str(roundi(touch)), "The heat shield and parachute do the fast part; the engine does the rest.")
	elif air == "thick":
		s["fact"] = "The air of Venus is 92 times denser at the ground than Earth's: landers sink through it slowly, with no rocket."
		_flag(s, "ok", "The thick air lands you at %s m/s with no engine." % _f(Data.VENUS_TOUCHDOWN), "Steer to flat ground. The pressure hull lands on its own crush ring.")
	else:
		s["fact"] = "%s has no air, so only the engine can slow the lander down." % place().capitalize()
		_flag(s, "ok", "Safe touchdown up to %s m/s." % str(roundi(touch)), "Fly the engine down gently and keep it level.")
	if air != "none" and not Game.id_has("heatshield"):
		s["value"] = "no heat shield"
		s["short"] = "no heat shield"
		_flag(s, "bad", "Without a heat shield the lander burns up in the air of %s." % place(),
			"Add the HEAT SHIELD. Landers dive straight in: no braking burn needed.", ["heatshield"], ["heatshield"])
	if air == "thin" and not Game.id_has("chute"):
		if Game.id_has("heatshield"):
			s["value"] = "no parachute"
			s["short"] = "no parachute"
		_flag(s, "bad", "Without a parachute you hit Mars far too fast for any engine to stop.",
			"Add the SUPERSONIC PARACHUTE: it slows you from 420 m/s to 85 m/s.", ["chute"], ["chute"])
	if air == "thick":
		if touch < Data.VENUS_TOUCHDOWN:
			_flag(s, "bad", "The lander sinks at %s m/s and nothing on it can take that." % _f(Data.VENUS_TOUCHDOWN),
				"Add the PRESSURE HULL: it lands on a crush ring, safe up to %s m/s." % _f(Data.PARTS["hull"]["touch"]), ["hull"], ["hull"])
	elif not Game.id_has("legs") and not Game.id_has("airbags"):
		_flag(s, "bad", "With no legs or airbags you must touch down slower than 1 m/s.",
			"Add LANDING LEGS (safe up to %s m/s, light) or AIRBAGS (%s m/s, the easy way)." % [str(int(Data.PARTS["legs"]["touch"])), str(int(Data.PARTS["airbags"]["touch"]))],
			["legs", "airbags"], ["legs"])
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
		_flag(s, "bad", "%s has no ground: without the drone nothing can collect samples." % place().capitalize(),
			"Add the SAMPLING DRONE from the ROBOTS tab.", ["drone"], ["drone"])
	return s

static func _heat() -> Dictionary:
	var s: Dictionary = _new("heat", "HEAT", "engineer", 3)
	var d: Dictionary = Game.dest()
	var times: String = _f(float(d["sun_wm2"]) / 1361.0)
	if Game.needs_shade():
		s["fact"] = "MESSENGER stayed near room temperature behind a ceramic-cloth sunshade whose front went above 300 C."
		s["value"] = "sunshade on"
		s["short"] = "shaded"
		_flag(s, "ok", "The sunshade keeps the ship cool in sunlight %s times Earth's." % times, "It must always face the Sun.")
		if not Game.id_has("sunshade"):
			s["value"] = "no sunshade"
			s["short"] = "no shade"
			_flag(s, "bad", "Without a sunshade the ship overheats before it arrives.",
				"Sunlight at %s is %s W/m2, %s times Earth's. Add the SUNSHADE from the SHIELD tab." % [place(), _f(d["sun_wm2"]), times], ["sunshade"], ["sunshade"])
	else:
		var mins: int = int(d.get("surface_minutes", 0.0))
		s["fact"] = "Venera 13 lived 127 minutes on the 464 C surface of Venus (1982). Nothing has lasted much longer."
		s["value"] = "%d min on the ground" % mins
		s["short"] = "%d min" % mins
		_flag(s, "ok", "The ground is hot enough to melt lead: you get %d minutes." % mins,
			"Drill fast and send the data at once." if Game.id_has("sunshade") else "Drill fast. A SUNSHADE also keeps the ship cool on the way in.")
	return s

static func _pressure() -> Dictionary:
	var s: Dictionary = _new("pressure", "PRESSURE", "engineer", 3)
	s["fact"] = "The air of Venus presses 92 times harder than Earth's, like the sea 900 m down (NASA)."
	s["value"] = "hull holds 92 bar"
	s["short"] = "hull OK"
	_flag(s, "ok", "The pressure hull holds against air 92 times Earth's.", "Everything that must survive sits inside the sealed ball.")
	if not Game.id_has("hull"):
		s["value"] = "no pressure hull"
		s["short"] = "no hull"
		_flag(s, "bad", "Without a pressure hull the lander is crushed like a can.",
			"Add the PRESSURE HULL from the LANDING tab.", ["hull"], ["hull"])
	return s

static func _radiation() -> Dictionary:
	var s: Dictionary = _new("radiation", "RADIATION", "engineer", 3)
	s["fact"] = "Juno keeps its computer inside a 172 kg titanium vault that cuts Jupiter's radiation 800 times."
	s["value"] = "shielded"
	s["short"] = "shielded"
	_flag(s, "ok", "The shielding protects the electronics in the radiation belts.", "It also stops solar storms on the way.")
	if not Game.id_has("shield"):
		s["value"] = "no shielding"
		s["short"] = "no shield"
		_flag(s, "bad", "Without shielding the radiation belts break the antenna and an instrument.",
			"Add RADIATION SHIELDING from the SHIELD tab (%s kg, %s)." % [_f(Data.PARTS["shield"]["mass"]), money(float(Data.PARTS["shield"]["cost"]))], ["shield"], ["shield"])
	return s

static func _science(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("science", "SCIENCE", "science", 4)
	var d: Dictionary = Game.dest()
	var ring: bool = d["kind"] == "ring"
	var goal: int = int(d["samples_goal"])
	var pts: int = int(c["pts"])
	var jb: String = Game.job()
	var what: String = "ice grains" if ring else "rocks"
	if jb != "drill":
		what = String(Data.JOBS[jb]["noun"])
	s["value"] = "%d %s x %d pt%s" % [goal, what, pts, "" if pts == 1 else "s"]
	s["short"] = "%d x %d pt%s" % [goal, pts, "" if pts == 1 else "s"]
	s["fact"] = SCIENCE_FACT[Game.dest_id]
	_flag(s, "ok", "The task needs all of them: %d %s." % [goal, what],
		"Each one makes %s Gb of data and earns %d science points." % [_f(c["gb_per_sample"]), pts])
	if ring:
		if jb == "drill" and float(c["gb_per_sample"]) <= 0.0:
			s["value"] = "no instrument"
			s["short"] = "no instrument"
			_flag(s, "bad", "Bring at least one science instrument or there is nothing to send home.",
				"Add the DUST ANALYZER, or the lighter MAGNETOMETER.", ["dust", "mag", "camera", "spectro"], ["dust"])
	elif jb == "crew":
		if not Game.id_has("crew"):
			s["value"] = "no crew"
			s["short"] = "no crew"
			_flag(s, "bad", "No crew cabin: nobody can set up the science stations.", "Add the CREW CABIN from the ROBOTS tab.", ["crew"], ["crew"])
	else:
		if jb == "drill" and not Game.id_has("drill"):
			s["value"] = "no drill"
			s["short"] = "no drill"
			_flag(s, "bad", "No drill: you cannot pick up any rock.", "Add the SAMPLE DRILL AND ARM.", ["drill"], ["drill"])
		if not Game.id_has("rover") and not Game.id_has("rover_big"):
			if Game.id_has("drill") or jb == "photo":
				s["value"] = "no rover"
				s["short"] = "no rover"
			_flag(s, "bad", "Without a rover you can reach only what is next to the lander.",
				"Add the SMALL ROVER from the ROBOTS tab.", ["rover", "rover_big"], ["rover"])
	if jb == "photo" and not Game.id_has("camera"):
		s["value"] = "no camera"
		s["short"] = "no camera"
		_flag(s, "bad", "No camera: you cannot take a single photo.", "Add the CONTEXT CAMERA from the SCIENCE tab.", ["camera"], ["camera"])
	if pts <= 1:
		_flag(s, "warn", "Add a science instrument.",
			"Each sample earns only %d point now. One more instrument raises the science score and the credits." % pts,
			["dust", "mag"] if ring else ["camera", "mag", "spectro"])
	return s

static func _data(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("data", "DATA", "comms", 6)
	var d: Dictionary = Game.dest()
	var ring: bool = d["kind"] == "ring"
	var goal: int = int(d["samples_goal"])
	var gb: float = c["gb_per_sample"]
	var store: float = c["store"]
	var all: float = gb * (RING_GRAINS if ring else goal + 2)
	_nh(s, float(c["data_exp"]), store, "Gb")
	_band(s, c, "data")
	s["fact"] = "One look by the CRISM spectrometer on Mars Reconnaissance Orbiter makes 2 to 2.5 Gb."
	_flag(s, "ok", "%d samples make %s Gb; the ship stores %s Gb." % [goal, _f(c["data_exp"]), _f(store)], "")
	if gb <= 0.0:
		s["value"] = "no science data"
		s["short"] = "no data"
		s["frac"] = 1.0
		var inst: Array = ["camera"] if Game.job() == "photo" else (["dust", "mag"] if ring else ["drill", "camera", "spectro"])
		_flag(s, "bad", "Bring at least one science instrument or there is nothing to send home.",
			"Samples only turn into data when an instrument looks at them. Add one from the SCIENCE tab.", inst)
	elif store < float(c["data_exp"]):
		_flag(s, "bad", "Storage is too small for the science data.",
			"%d samples make %s Gb but only %s Gb fit. Add a DATA RECORDER." % [goal, _f(c["data_exp"]), _f(store)], ["recorder"], ["recorder"])
	elif c["status"]["data"] == "warn":
		_flag(s, "warn", "Storage only just fits the science data.",
			"%s Keep %d%% of the storage spare (game rule): add a DATA RECORDER." % [YELLOW, _pct("data")], ["recorder"])
	elif store < all:
		_flag(s, "warn", "Storage is full: extra science is thrown away.",
			"Collecting every sample would make %s Gb; only %s Gb fit. Add a DATA RECORDER." % [_f(all), _f(store)], ["recorder"])
	return s

static func _comms(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("comms", "COMMS", "comms", 7)
	var d: Dictionary = Game.dest()
	var goal: int = int(d["samples_goal"])
	var exp_gb: float = c["data_exp"]
	var down: float = c["downlink"]
	var best: String = _antenna(c)
	var span: String = "%d minutes" % int(d["surface_minutes"]) if d.has("surface_minutes") else "%d days" % int(d["ops_days"])
	# antennas faster than the one on board
	var faster: Array = []
	for id: String in ["mga", "hga", "ka"]:
		if not Game.id_has(id) and _down(id, c) > down:
			faster.append(id)
	_nh(s, exp_gb, down, "Gb")
	_band(s, c, "comms")
	s["fact"] = "Radio speed falls with the square of distance. A signal from %s takes %s." % [place(), d["light_delay"]]
	_flag(s, "ok", "The antenna can send %s Gb in %s; the science is %s Gb." % [_f(down), span, _f(exp_gb)], "")
	if float(c["rate"]) <= 0.0:
		s["value"] = "no antenna"
		s["short"] = "no antenna"
		s["frac"] = 1.0
		_flag(s, "bad", "No antenna: your science never reaches Earth.",
			"Add an antenna from the COMMS tab. The %s is enough for %s." % [_name(best).to_upper(), place()],
			[best] + ["lga", "mga", "hga", "ka"].filter(func(id: String) -> bool: return id != best), [best])
	elif down < exp_gb:
		_flag(s, "bad", "Your antenna is too slow to send all the science home in time.",
			"It sends %s Gb in %s, but %d samples make %s Gb. Use a bigger dish or lighter instruments." % [_f(down), span, goal, _f(exp_gb)], faster)
	elif c["status"]["comms"] == "warn":
		_flag(s, "warn", "The antenna only just keeps up with the science.",
			"%s JPL asks for a 3 dB link margin; the game translates it as room for twice the data (%s Gb). You can send %s Gb." % [YELLOW, _f(exp_gb * float(Data.MARGIN["comms"])), _f(down)], faster)
	return s

static func _return(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("return", "RETURN", "science", 5)
	var crew: bool = Game.job() == "crew"
	var cargo: String = "the crew" if crew else "the rocks"
	s["value"] = "capsule ready"
	s["short"] = "ready"
	s["fact"] = "Apollo and Chang'e 5 left their landers behind: only a small stage flew up and home."
	_flag(s, "ok", "The return capsule will fly %s to Earth. The lander stays." % cargo, "Game rule: keep 30% battery or the capsule won't launch.")
	if not Game.id_has("ascent"):
		s["value"] = "no capsule"
		s["short"] = "no capsule"
		_flag(s, "bad", "No return capsule: %s can never leave %s." % [cargo, place()],
			"Add the RETURN CAPSULE from the RETURN tab. It weighs %s kg, so it needs a lot more fuel." % _f(Data.PARTS["ascent"]["mass"]), ["ascent"], ["ascent"])
	elif float(c["wh"]) <= 0.0:
		s["value"] = "no battery"
		s["short"] = "no battery"
		_flag(s, "bad", "The capsule needs a charged battery to launch.", "Add a BATTERY and keep it above 30%.", ["battery"], ["battery"])
	elif float(c["gen"]) < float(c["draw_ops"]):
		_flag(s, "warn", "Game rule: keep 30% battery or the capsule won't launch.",
			"The ship uses more power than it makes, so the battery will run down. Fix POWER, and carry a battery as reserve.", ["solar", "battery"])
	elif not crew and not Game.id_has("drill"):
		_flag(s, "warn", "The capsule needs at least one rock on board to count.", "Bring a drill and a rover.", ["drill"])
	return s

static func _budget(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("budget", "BUDGET", "planner", 10)
	var cost: float = c["cost"]
	var budget: float = c["budget"]
	s["value"] = "%s of %s" % [money(cost), money(budget)]
	s["short"] = "$%d/%dM" % [roundi(cost), roundi(budget)]
	s["frac"] = cost / budget
	_band(s, c, "budget")
	s["fact"] = "NASA's CAPSTONE Moon probe cost $13.7M, plus $9.95M for its launch on Electron."
	var split: String = "Parts %s + rocket %s + mission control %s." % [money(float(c["parts_cost"])), money(float(c["rocket_cost"])), money(float(c["ops_cost"]))]
	_flag(s, "ok", "The mission costs %s of your %s." % [money(cost), money(budget)], split)
	if c["status"]["budget"] != "ok":
		var over: bool = c["status"]["budget"] == "bad"
		var cheaper: Array = _rockets_for(float(c["mass"]), float(c["rocket_cost"]))
		var trim: Array = _trim(c, "cost").filter(func(t: Dictionary) -> bool: return float(t["save"]) >= 1.0)
		var how: String = _trim_words(trim, "$")
		if not cheaper.is_empty():
			how = "A cheaper rocket still lifts this ship: pick %s." % String(Data.ROCKETS[String(cheaper[0]).trim_prefix("rocket:")]["name"])
		elif how == "" and Game.id_has("rtg") and _power_part(c) != "rtg" and not Game.id_has("solar"):
			how = "Swap the nuclear RTGs for solar arrays: add a SOLAR ARRAY (%s), then take off an RTG (%s)." % [money(float(Data.PARTS["solar"]["cost"])), money(float(Data.PARTS["rtg"]["cost"]))]
			cheaper = ["solar"]
		elif how == "" and over:
			how = "Nothing more can come off. The ship still flies, but the planner loses points."
		if over:
			_flag(s, "bad", "The mission costs more than your budget.", "%s %s" % [split, how], cheaper + _trim_tiles(trim))
		else:
			_flag(s, "warn", "Only %d%% of the budget is left in reserve." % roundi(float(c["budget_margin"]) * 100.0),
				"%s NASA's Discovery 2019 call asked for a %d%% reserve to pay for surprises. %s" % [YELLOW, _pct("budget"), how], cheaper + _trim_tiles(trim))
	return s

static func _time(c: Dictionary) -> Dictionary:
	var s: Dictionary = _new("time", "TIME", "planner", 11)
	var d: Dictionary = Game.dest()
	var t: Dictionary = Game.traj()
	s["value"] = "%s of %s days" % [_f(c["days"]), _f(c["limit"])]
	s["short"] = "%s/%s d" % [_f(c["days"]), _f(c["limit"])]
	s["frac"] = float(c["days"]) / float(c["limit"])
	_band(s, c, "time")
	s["fact"] = String(t["src"])
	var split: String = "%s days to build + %s days of travel + %d of work at %s." % [_f(c["dev_days"]), _f(t["days"]), int(d["ops_days"]), place()]
	_flag(s, "ok", "The mission fits its deadline with %s days to spare." % _f(float(c["limit"]) - float(c["days"])),
		"%s Game rules: every kind of part adds %d days of building; each year of flight costs %s." % [split, int(Data.DEV_DAYS_PER_KIND), money(Data.OPS_COST_PER_YEAR)])
	if c["status"]["time"] == "bad":
		var over: float = float(c["days"]) - float(c["limit"])
		var fix: Array = []
		var how: String = "Take off a kind of part you can fly without (%d days each)." % int(Data.DEV_DAYS_PER_KIND)
		for i: int in (d["traj"] as Array).size():
			if i != Game.traj_idx and float(d["traj"][i]["days"]) < float(t["days"]):
				fix.append("path:%d" % i)
				how = "Pick the faster flight path in the LAUNCHER tab, or take off a kind of part (%d days each)." % int(Data.DEV_DAYS_PER_KIND)
		if Game.id_has("rtg") and _power_part(c) != "rtg":
			fix.append("-rtg")
			how += " Nuclear power adds %d days of launch approval." % int(Data.DEV_NUCLEAR_DAYS)
		_flag(s, "bad", "The mission takes %s days too long." % _f(over), "%s %s" % [split, how], fix)
	return s

## Things that do not stop the launch: storms, low margins, wasted parts.
static func _risk(c: Dictionary, list: Array) -> Dictionary:
	var s: Dictionary = _new("risk", "RISK", "engineer", 12)
	s["fact"] = "The storms in this game are real 2024 events from NASA's DONKI space weather database."
	var risks: Array = []
	_flag(s, "ok", "No open risks.", "Margins on every lamp: the ship can pay for surprises.")
	if not Game.id_has("shield") and not Game.has_hazard("radiation"):
		risks.append("storm")
		_flag(s, "warn", "A solar storm can break your antenna or an instrument on the way.",
			"Without shielding you must dodge it with fuel or gamble. Add RADIATION SHIELDING (%s kg, %s)." % [_f(Data.PARTS["shield"]["mass"]), money(float(Data.PARTS["shield"]["cost"]))], ["shield"])
	var low: PackedStringArray = []
	for st: Dictionary in list:
		if st["status"] == "warn":
			low.append(String(st["name"]))
	if not low.is_empty():
		var words: String = "Low margin: %s." % ", ".join(low)
		if risks.is_empty():
			_flag(s, "warn", words, "%s Margins are what surprises eat. Tap a yellow lamp to see why." % YELLOW)
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
	var over: PackedStringArray = []
	for key: String in c["use"]:
		if c["use"][key]["state"] == "waste":
			over.append(String(c["use"][key]["name"]))
	if antennas > 1:
		tip = "Only your best antenna is used; extra ones just waste power."
	elif not dead.is_empty():
		tip = "%s does nothing at %s and only adds weight." % [dead[0], place()]
	elif not over.is_empty():
		tip = "More than this mission needs: %s. It costs mass and money." % ", ".join(over)
	if tip != "":
		if risks.is_empty():
			s["headline"] = "No open risks. One tip:"
			s["explain"] = tip
		else:
			s["explain"] = "%s Tip: %s" % [s["explain"], tip]
	s["value"] = "none" if risks.is_empty() else ("storm: no shield" if risks[0] == "storm" else "low margin")
	s["short"] = s["value"]
	return s

# ---------------------------------------------------------------- how much a part is needed (design 8b)

static func _pn(level: String, why: String) -> Dictionary:
	return {"level": level, "label": NEED_LABEL[level], "why": why}

## How much the current mission (destination, rocket, path) needs a part:
##   {"level": "required" | "recommended" | "optional" | "not_needed", "label": the words for the badge, "why": <= 60 characters}
static func part_need(id: String) -> Dictionary:
	var d: Dictionary = Game.dest()
	var c: Dictionary = Game.calc()
	var land: bool = d["kind"] == "land"
	var air: String = d["air"]
	var here: String = place()
	var p: Dictionary = Data.PARTS[id]
	var jb: String = Game.job()
	if p.has("kinds") and not (p["kinds"] as Array).has(d["kind"]):
		return _pn("not_needed", "No ground at %s: nothing to land on" % here if not land else "%s has ground: no rings to fly through" % here.capitalize())
	if p.has("jobs") and not (p["jobs"] as Array).has(jb):
		return _pn("not_needed", "Only for a task with astronauts")
	match id:
		"bus":
			return _pn("required", "The ship itself: frame, computer and engine")
		"prop":
			return _pn("required", "Fuel to steer, brake and land: fill to the green band")
		"solar", "solar_lite", "rtg":
			var main: String = _power_part(c)
			var sun_pct: String = _f(100.0 / pow(float(d["sun_au"]), 2.0))
			if id == main:
				if id == "rtg":
					return _pn("required", "Sunlight here is %s%% of Earth's: too weak for solar" % sun_pct)
				return _pn("required", "Cheapest power here: sunlight is %s%% of Earth's" % sun_pct)
			if id == "rtg":
				return _pn("optional", "Works in the dark, but costs $%dM and %d build days" % [int(p["cost"]), int(Data.DEV_NUCLEAR_DAYS)])
			if _unit_w(id, c) * float(p["max"]) < float(Data.PARTS["bus"]["draw"]) * (1.0 + float(Data.MARGIN["power"])):
				return _pn("not_needed", "Sunlight here is %s%% of Earth's: too weak" % sun_pct)
			return _pn("optional", "Also works here: %s W from each array" % _f(_unit_w(id, c)))
		"battery", "battery_hi":
			if not land:
				return _pn("not_needed", "No night in orbit: the power runs all the time")
			if id == "battery_hi":
				return _pn("optional", "Twice the energy of the small battery")
			if d.has("surface_minutes"):
				return _pn("required", "No sunlight on the ground: battery power only")
			if float(d["night_hours"]) > 0.0:
				return _pn("required", "%s nights last %s hours" % [here.capitalize(), _f(roundf(float(d["night_hours"])))])
			return _pn("required", "The lander runs on it at the site")
		"lga", "mga", "hga", "ka":
			var best: String = _antenna(c)
			var want: float = _data_ref(c) * float(Data.MARGIN["comms"])
			if id == best:
				return _pn("required", "The cheapest antenna that is fast enough from here")
			if _down(id, c) < want:
				return _pn("not_needed", "Too slow from %s: %s" % [here, d["light_delay"] + " away by radio"])
			return _pn("optional", "Faster than this mission needs")
		"recorder":
			if float(c["data_exp"]) * (1.0 + float(Data.MARGIN["data"])) > float(Data.PARTS["bus"]["store_gb"]):
				return _pn("required", "The science is bigger than the ship's own memory")
			return _pn("recommended", "Spare memory: a way out when a computer fails")
		"drill":
			if jb == "photo":
				return _pn("not_needed", "A photo task takes pictures, not rocks")
			if jb == "crew":
				return _pn("not_needed", "The astronauts set up stations by hand")
			return _pn("required", "Nothing else can pick up a rock sample")
		"camera":
			if jb == "photo":
				return _pn("required", "Takes the photos: %s Gb each (game rule)" % _f(Data.PHOTO_GB[d["kind"]]))
			return _pn("recommended" if land else "optional", "Adds 1 science point to every sample")
		"mag":
			return _pn("optional", "Light and cheap: 1 science point per sample")
		"spectro":
			return _pn("optional", "Best science, but 2.5 Gb per sample to send home")
		"dust":
			return _pn("required" if not land and jb == "drill" else "optional", "Reads what dust and ring grains are made of")
		"legs":
			if air == "thick":
				return _pn("not_needed", "The pressure hull lands on its own crush ring")
			return _pn("required", "The lander must stand: safe up to %d m/s" % int(p["touch"]))
		"airbags":
			if air == "thick":
				return _pn("not_needed", "The pressure hull lands on its own crush ring")
			return _pn("optional", "Easier than legs: safe up to %d m/s, but heavier" % int(p["touch"]))
		"heatshield":
			if air == "none":
				return _pn("not_needed", "No air at %s: nothing to brake against" % here)
			return _pn("required", "The air of %s burns up a bare lander" % here)
		"chute":
			if air == "none":
				return _pn("not_needed", "No air at %s: a parachute catches nothing" % here)
			if air == "thick":
				return _pn("not_needed", "The air is so thick the lander sinks slowly")
			return _pn("required", "Thin air: slows you from 420 m/s to 85 m/s")
		"hull":
			if Game.has_hazard("pressure"):
				return _pn("required", "The air here crushes like 900 m of sea")
			return _pn("not_needed", "No crushing air at %s" % here)
		"rover":
			if jb == "crew":
				return _pn("not_needed", "The astronauts walk to the stations")
			return _pn("required", "Drives to the %s: the lander cannot move" % ("viewpoints" if jb == "photo" else "rocks"))
		"rover_big":
			if jb == "crew":
				return _pn("not_needed", "The astronauts walk to the stations")
			return _pn("optional", "Faster than the small rover, but 300 kg")
		"crew":
			return _pn("required", "Two astronauts set up the stations by hand")
		"drone":
			return _pn("required", "No ground here: only the drone reaches the rings")
		"ascent":
			if bool(d["returns"]):
				return _pn("required", "Flies the %s to Earth; the lander stays" % ("crew" if jb == "crew" else "rocks"))
			return _pn("not_needed", "Only the data goes home from %s" % here)
		"sunshade":
			if Game.needs_shade():
				return _pn("required", "Sunlight here is %s times Earth's" % _f(float(d["sun_wm2"]) / 1361.0))
			if Game.has_hazard("heat"):
				return _pn("recommended", "Keeps the electronics cool on the way in")
			return _pn("not_needed", "Sunlight at %s is no stronger than at Earth" % here)
		"shield":
			if Game.has_hazard("radiation"):
				return _pn("required", "Radiation belts here break bare electronics")
			return _pn("recommended", "Solar storms can break the antenna or an instrument")
	return _pn("optional", "")

# ---------------------------------------------------------------- the build steps (design 8b)

static func _step(id: String, title: String, parts: Array, done: bool, hint: String, tab: String = "") -> Dictionary:
	var next: String = ""
	for pid: String in parts:
		if Data.PARTS.has(pid) and not Game.id_has(pid) and next == "":
			next = pid
	var t: String = tab
	if t == "":
		t = String(Data.PARTS[next if next != "" else String(parts[0])]["cat"])
	return {"id": id, "title": title, "done": done, "hint": hint, "parts": parts, "next": next, "tab": t}

## The short ordered list of build steps for this destination. The builder lights the first one that is not done.
##   {"id", "title" (<= 16), "done": bool, "hint" (<= 60: the one thing to do now), "parts": [part ids or "rocket:<id>"
##    that complete it], "next": the first of them still missing ("" if none), "tab": the bin category to open}
static func checklist() -> Array:
	var c: Dictionary = Game.calc()
	var d: Dictionary = Game.dest()
	var st: Dictionary = c["status"]
	var land: bool = d["kind"] == "land"
	var air: String = d["air"]
	var out: Array = []
	# 1 power: first enough watts, then the battery a lander needs
	var pw: Array = [_power_part(c)]
	if land:
		pw.append("battery")
	var pw_next: String = ""
	var pw_hint: String = "Power is enough."
	if float(c["gen"]) <= 0.0 or float(c["gen"]) < float(c["power_need"]) or float(c["gen_space"]) < float(c["draw_cruise"]):
		pw_next = pw[0] if Game.count(pw[0]) < int(Data.PARTS[pw[0]]["max"]) else "rtg"
		pw_hint = "Add %s: the ship needs more power." % ("a NUCLEAR BATTERY (RTG)" if pw_next == "rtg" else "a SOLAR ARRAY")
	elif land and (float(c["wh"]) <= 0.0 or float(c["wh"]) < float(c["night_need"])):
		pw_next = "battery"
		pw_hint = "Add a BATTERY: the lander runs on it."
		if float(c["night_need"]) > 0.0:
			pw_hint = "Add a BATTERY: %s Wh needed for the dark hours." % _f(c["night_need"])
	var pw_step: Dictionary = _step("power", "POWER", pw, pw_next == "", pw_hint, "power")
	pw_step["next"] = pw_next
	out.append(pw_step)
	# 2 radio
	var ant: String = _antenna(c)
	var rd_done: bool = float(c["rate"]) > 0.0 and (float(c["data_exp"]) <= 0.0 or (st["comms"] != "bad" and st["data"] != "bad"))
	var rd_hint: String = "Add the %s to talk to Earth." % _name(ant).to_upper()
	var rd: Array = [ant]
	if float(c["rate"]) > 0.0 and st["data"] == "bad" and float(c["data_exp"]) > 0.0:
		rd_hint = "Add a DATA RECORDER: the science does not fit."
		rd.append("recorder")
	out.append(_step("radio", "RADIO", rd, rd_done, rd_hint if not rd_done else "The radio link works."))
	# 3 science
	var jb: String = Game.job()
	var mover: bool = Game.id_has("rover") or Game.id_has("rover_big")
	var sc: Array = ["drill", "rover", "camera"] if land else ["drone", "dust"]
	var sc_done: bool = int(c["pts"]) >= 2 and ((Game.id_has("drill") and mover) if land else Game.id_has("drone"))
	if jb == "photo":
		sc = ["camera", "rover"] if land else ["drone", "camera"]
		sc_done = Game.id_has("camera") and (mover if land else Game.id_has("drone"))
	elif jb == "crew":
		sc = ["crew"]
		sc_done = Game.id_has("crew")
	var sc_step: Dictionary = _step("science", "SCIENCE", sc, sc_done, "")
	if sc_step["next"] == "" and not sc_done:
		sc_step["next"] = "mag"
		sc_step["tab"] = "science"
	sc_step["hint"] = "Science is ready." if sc_done else "Add the %s." % _name(sc_step["next"]).to_upper()
	out.append(sc_step)
	# 4 getting down, and whatever the destination's hazards demand
	var gd: Array = []
	if land:
		if air != "none":
			gd.append("heatshield")
		if air == "thin":
			gd.append("chute")
		gd.append("hull" if air == "thick" else "legs")
		if bool(d["returns"]):
			gd.append("ascent")
	if Game.needs_shade():
		gd.append("sunshade")
	if Game.has_hazard("radiation"):
		gd.append("shield")
	if not gd.is_empty():
		# the first part still missing; airbags stand in for legs
		var missing: String = ""
		for pid: String in gd:
			if missing == "" and not Game.id_has(pid) and not (pid == "legs" and Game.id_has("airbags")):
				missing = pid
		var gd_step: Dictionary = _step("down", "GETTING DOWN" if land else "PROTECTION", gd, missing == "", "")
		gd_step["next"] = missing
		gd_step["tab"] = String(Data.PARTS[missing if missing != "" else String(gd[0])]["cat"])
		gd_step["hint"] = "Ready for %s." % place() if missing == "" else "Add the %s." % _name(missing).to_upper()
		out.append(gd_step)
	# 5 fuel, 6 rocket
	var tanks: int = ceili(maxf(0.0, float(c["prop_ok"]) - float(c["prop"])) / float(Data.PARTS["prop"]["mass"]))
	out.append(_step("fuel", "FUEL", ["prop"], st["fuel"] == "ok",
		"Fuel is in the green band." if st["fuel"] == "ok" else "Add %d PROPELLANT tank%s: fill to the green band." % [tanks, "" if tanks == 1 else "s"], "fuel"))
	var fits: Array = _rockets_for(float(c["mass"]) / (1.0 - float(Data.MARGIN["mass"])))
	var rk_done: bool = st["mass"] == "ok"
	var rk_hint: String = "The rocket lifts the ship with margin."
	if not rk_done:
		rk_hint = "Pick %s: it lifts this ship." % String(Data.ROCKETS[String(fits[0]).trim_prefix("rocket:")]["name"]) if not fits.is_empty() else "Too heavy for any rocket here: take parts off."
	out.append(_step("rocket", "ROCKET", fits if not rk_done and not fits.is_empty() else ["rocket:" + Game.rocket_id], rk_done, rk_hint, "launcher"))
	return out
