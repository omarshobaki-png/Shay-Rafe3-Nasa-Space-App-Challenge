extends Node
## Game state, ship maths, mission simulation, decision events, scoring, money and saving.
## The contract for the screens is V5_DESIGN.md, section 9 ("Core API as built").

const SAVE_PATH: String = "user://save.json"
const Events = preload("res://scripts/events.gd")

var main: Node = null
var funds: int = 0
var tech: Dictionary = {}
var players: int = 1
var missions_flown: int = 0
var best: Dictionary = {}
## 0 EASY, 1 NORMAL, 2 HARD. It never depends on the planet: the player's chosen task sets it (set_task).
var difficulty: int = 1
## Which of the destination's three tasks (Data.TASKS, easiest first) is being flown.
var task_idx: int = 1
## The task last chosen at each destination, {dest id: index}; saved with the game.
var last_task: Dictionary = {}
var _dest_cache: Dictionary = {}

var dest_id: String = "moon"
var build: Dictionary = {}
var rocket_id: String = "falcon9"
var traj_idx: int = 0
var signed: Dictionary = {}

var run: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# multiplayer (decision D7; the network contract is scripts/net.gd)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # the cruise's random events; seeded by the host online
var player_name: String = "PLAYER"
var net_error: String = ""       # why the last room ended, shown on the menu
var team: Dictionary = {}        # team sync stats, see team_reset()

func _ready() -> void:
	randomize()
	rng.randomize()
	load_game()
	team_reset()
	call_deferred("_hook_net")   # Net is the next autoload: connect once everything is in the tree

func goto(screen: String) -> void:
	main.call("goto", screen)

func difficulty_name() -> String:
	return String(Data.DIFFICULTY[clampi(difficulty, 0, 2)]["name"])

## One knob of the chosen difficulty. Keys (Data.DIFFICULTY): "events_per_leg", "burn_band",
## "landing_forgive", "surface_hazards", "drone_rocks", "budget_slack", "over_mult", "storm_strong".
func diff(key: String) -> float:
	return float(Data.DIFFICULTY[clampi(difficulty, 0, 2)][key])

# ---------------------------------------------------------------- build

## "THE MOON", "MARS", "NEPTUNE": for headings.
func place() -> String:
	return "THE MOON" if dest_id == "moon" else String(dest()["name"])

## The destination as the chosen task sees it: Data.DEST[dest_id] with the task's "samples_goal", "goal"
## and "budget", and its "returns" and "objectives" where the task changes them. "task" is the task id.
func dest() -> Dictionary:
	var key: String = dest_id + str(task_idx)
	if not _dest_cache.has(key):
		var d: Dictionary = (Data.DEST[dest_id] as Dictionary).duplicate()
		var t: Dictionary = task()
		d["samples_goal"] = int(t["samples"])
		d["task"] = t["id"]
		for k: String in ["goal", "budget", "returns", "objectives", "time_limit_days", "needs"]:
			if t.has(k):
				d[k] = t[k]
		_dest_cache[key] = d
	return _dest_cache[key]

## The three tasks offered at the current destination, easiest first:
## {"id", "name" (<= 18), "diff" 0..2, "level" "EASY" | "NORMAL" | "HARD", "text" (<= 90), "goal" (<= 60), "samples"}.
func tasks() -> Array:
	return Data.TASKS[dest_id]

func task() -> Dictionary:
	var list: Array = tasks()
	return list[clampi(task_idx, 0, list.size() - 1)]

## Chooses a task: sets the difficulty to the task's, clears the sign-offs, keeps the ship.
func set_task(i: int) -> void:
	task_idx = clampi(i, 0, tasks().size() - 1)
	difficulty = int(task()["diff"])
	last_task[dest_id] = task_idx
	signed = {}

func traj() -> Dictionary:
	var arr: Array = dest()["traj"]
	return arr[traj_idx]

func has_hazard(h: String) -> bool:
	return (dest()["hazards"] as Array).has(h)

## True where sunlight is so strong that a ship without the sunshade overheats (Mercury).
func needs_shade() -> bool:
	return float(dest()["sun_wm2"]) > Data.SHADE_ABOVE_WM2

## Starts a new ship for a destination, on the task whose difficulty is the current Game.difficulty.
func new_mission(id: String) -> void:
	dest_id = id
	task_idx = 1
	for i: int in tasks().size():
		if int(tasks()[i]["diff"]) == difficulty:
			task_idx = i
	build = {"bus": 1}
	traj_idx = 0
	signed = {}
	rocket_id = ""
	for r: String in Data.ROCKETS:
		var cap: Dictionary = Data.ROCKETS[r]["cap"]
		if cap.has(id) and rocket_id == "" and r != "electron":
			rocket_id = r

## A ship that is GO with margin on every lamp and carries what its destination's hazards demand.
## These are the cheapest all-green ships found by tools/dev/balance.gd (Venus, Mars and Saturn on their
## first, best known path, which costs a little more); balance.gd checks every one on every difficulty.
const EXAMPLES: Dictionary = {
	"moon": ["vulcan", 0, {"solar": 1, "battery": 1, "lga": 1, "camera": 1, "drill": 1, "rover": 1, "legs": 1, "ascent": 1, "shield": 1, "prop": 22}],
	"mercury": ["vulcan", 0, {"solar": 1, "battery": 1, "lga": 1, "camera": 1, "drill": 1, "rover": 1, "legs": 1, "sunshade": 1, "shield": 1, "prop": 17}],
	"venus": ["falcon9", 0, {"solar": 1, "battery": 1, "hga": 1, "camera": 1, "drill": 1, "rover": 1, "heatshield": 1, "hull": 1, "shield": 1, "prop": 1}],
	"mars": ["falcon9", 0, {"solar": 1, "battery": 2, "mga": 1, "camera": 1, "drill": 1, "rover": 1, "heatshield": 1, "chute": 1, "legs": 1, "shield": 1, "prop": 1}],
	"jupiter": ["vulcan", 1, {"solar": 7, "mga": 1, "dust": 1, "drone": 1, "shield": 1, "prop": 2}],
	"saturn": ["heavy", 0, {"rtg": 3, "hga": 1, "dust": 1, "drone": 1, "shield": 1, "prop": 2}],
	"uranus": ["heavy", 1, {"rtg": 3, "hga": 1, "dust": 1, "drone": 1, "shield": 1, "prop": 11}],
	"neptune": ["heavy", 0, {"rtg": 3, "hga": 1, "dust": 1, "drone": 1, "shield": 1, "prop": 11}],
}

## The example ship, fitted to the chosen task: no ascent stage where nothing flies home, the cheapest antenna
## that closes the link, no more power parts than the margin needs, a recorder if the science outgrows the
## memory, fuel to the green line, and the cheapest rocket that lifts it with the margin.
func example_build() -> void:
	var ex: Array = EXAMPLES[dest_id]
	build = {"bus": 1}
	signed = {}
	rocket_id = ex[0]
	traj_idx = ex[1]
	build.merge(ex[2])
	if not bool(dest()["returns"]):
		build.erase("ascent")
	for a: String in ["lga", "mga", "hga"]:
		for other: String in ["lga", "mga", "hga"]:
			build.erase(other)
		build[a] = 1
		if calc()["status"]["comms"] == "ok":
			break
	_example_trim("rtg", "power", 0)
	_example_trim("solar", "power", 0)
	_example_trim("battery", "battery", 1 if dest()["kind"] == "land" else 0)
	var c: Dictionary = calc()
	while c["status"]["data"] != "ok" and count("recorder") < int(Data.PARTS["recorder"]["max"]):
		build["recorder"] = count("recorder") + 1
		c = calc()
	build["prop"] = ceili(float(c["prop_ok"]) / float(Data.PARTS["prop"]["mass"]))
	var total: float = float(c["dry"]) + float(build["prop"]) * float(Data.PARTS["prop"]["mass"])
	var best_cost: float = INF
	for r: String in Data.ROCKETS:
		var rk: Dictionary = Data.ROCKETS[r]
		var cap: float = float((rk["cap"] as Dictionary).get(dest_id, 0.0)) * float(traj()["cap_mult"])
		if cap * (1.0 - float(Data.MARGIN["mass"])) >= total and float(rk["cost"]) < best_cost:
			best_cost = float(rk["cost"])
			rocket_id = r

## Takes units of a part off the example while the lamp `key` stays green.
func _example_trim(id: String, key: String, least: int) -> void:
	while count(id) > least:
		var n: int = count(id)
		if n > 1:
			build[id] = n - 1
		else:
			build.erase(id)
		if calc()["status"][key] != "ok":
			build[id] = n
			return

func count(id: String) -> int:
	return int(build.get(id, 0))

func part_available(id: String) -> bool:
	var p: Dictionary = Data.PARTS[id]
	if p.has("tech") and not tech.has(p["tech"]):
		return false
	if p.has("kinds") and not (p["kinds"] as Array).has(dest()["kind"]):
		return false
	if p.has("dests") and not (p["dests"] as Array).has(dest_id):
		return false
	return true

func add_part(id: String, n: int) -> void:
	var p: Dictionary = Data.PARTS[id]
	if p.get("locked_in", false):
		return
	if n > 0 and not part_available(id):
		return
	var c: int = clampi(count(id) + n, 0, int(p["max"]))
	if c == 0:
		build.erase(id)
	else:
		build[id] = c
	signed = {}

func rocket_cap() -> float:
	var r: Dictionary = Data.ROCKETS[rocket_id]
	var cap: Dictionary = r["cap"]
	var t: Dictionary = traj()
	return float(cap.get(dest_id, 0.0)) * float(t["cap_mult"])

func budget() -> float:
	return roundf(float(dest()["budget"]) * diff("budget_slack")) + (100.0 if tech.has("grant") else 0.0)

func ve() -> float:
	return Data.ISP * Data.G0 / 1000.0  # km/s

func rocket_eq_prop(dry: float, dv_kms: float) -> float:
	return dry * (exp(dv_kms / ve()) - 1.0)

## The speed changes (km/s) the engine must make: course corrections, braking into orbit, landing.
## With a heat shield a lander needs no braking burn where there is air: it enters straight from its cruise
## path (direct entry, as every Mars lander has), and in thick air (Venus) the air does the whole descent.
func dv_plan() -> Dictionary:
	var d: Dictionary = dest()
	var t: Dictionary = traj()
	var capture: float = float(d["capture_dv"]) * float(t["dv_mult"])
	var landing: float = float(d["landing_dv"])
	var air: String = d["air"]
	if air != "none" and count("heatshield") > 0:
		capture = 0.0
	if air == "thin":
		landing = 0.3 if count("chute") > 0 else 0.9
	return {"cruise": Data.CRUISE_DV, "capture": capture, "landing": landing, "total": Data.CRUISE_DV + capture + landing}

## Everything the builder bars and the review board need.
func calc() -> Dictionary:
	var d: Dictionary = dest()
	var t: Dictionary = traj()
	var mg: Dictionary = Data.MARGIN
	var c: Dictionary = {}
	var dry: float = 0.0
	var prop: float = 0.0
	var cost: float = 0.0
	var draw_ops: float = 0.0
	var draw_cruise: float = 0.0
	var solar_1au: float = 0.0
	var rtg: float = 0.0
	var wh: float = 0.0
	var store: float = 0.0
	var rate: float = 0.0
	var gb_per_sample: float = 0.0
	var pts: int = 0
	var touch: float = 1.0
	var kinds_n: int = 0
	for id: String in build:
		var p: Dictionary = Data.PARTS[id]
		var n: int = int(build[id])
		var m: float = float(p["mass"]) * n
		if id == "prop":
			prop += m
		else:
			dry += m
			if id != "bus":
				kinds_n += 1
		cost += float(p["cost"]) * n
		var dr: float = float(p.get("draw", 0.0)) * n
		draw_ops += dr
		if p["cat"] == "core" or p["cat"] == "comms":
			draw_cruise += dr
		if p.get("kind", "") == "solar":
			solar_1au += float(p["gen"]) * n
		elif p.get("kind", "") == "rtg":
			rtg += float(p["gen"]) * n
		wh += float(p.get("wh", 0.0)) * n
		store += float(p.get("store_gb", 0.0)) * n
		if p.has("rate"):
			var au: float = float(d["earth_au"])
			rate = maxf(rate, minf(float(p["rate"]) / (au * au), float(p["rate_cap"])))
		if p["cat"] == "science":
			gb_per_sample += float(p["gb"])
			pts += int(p["pts"])
		if p.has("touch"):
			touch = maxf(touch, float(p["touch"]))
	if id_has("rover_big"):
		solar_1au += 300.0
	# time = development + cruise + operations
	var cruise_days: float = float(t["days"])
	var ops_days: float = float(d["ops_days"])
	var flight_days: float = cruise_days + ops_days
	var years: float = flight_days / 365.0
	var dev_days: float = Data.DEV_BASE_DAYS + Data.DEV_DAYS_PER_KIND * kinds_n + (Data.DEV_NUCLEAR_DAYS if rtg > 0.0 else 0.0)
	var days: float = dev_days + flight_days
	# power: sunlight by the inverse-square law, arrays age, RTGs fade after their design life
	var sun: float = float(d["sun_au"])
	var solar_space: float = solar_1au / (sun * sun) * pow(1.0 - Data.SOLAR_DECAY_PER_YEAR, years)
	var solar_dest: float = solar_space * float(d["dust"])
	var rtg_dest: float = rtg * (0.5 if years > Data.RTG_LIFE_YEARS else 1.0)
	# where the lander lives on its battery (Venus), the arrays only have to feed the cruise
	var battery_only: bool = d.has("surface_minutes")
	var gen: float = (solar_space if battery_only else solar_dest) + rtg_dest
	var power_need: float = draw_cruise if battery_only else draw_ops
	var dark_hours: float = float(d["surface_minutes"]) / 60.0 if battery_only else float(d["night_hours"])
	var night_need: float = maxf(0.0, draw_ops - rtg_dest) * dark_hours
	var total: float = dry + prop
	var cap: float = rocket_cap()
	var rk: Dictionary = Data.ROCKETS[rocket_id]
	var ops_cost: float = years * Data.OPS_COST_PER_YEAR
	var total_cost: float = cost + float(rk["cost"]) + ops_cost
	var dv: Dictionary = dv_plan()
	var prop_need: float = rocket_eq_prop(dry, float(dv["total"]))
	var prop_ok: float = rocket_eq_prop(dry, float(dv["total"]) * (1.0 + float(mg["fuel"])))
	var data_exp: float = float(d["samples_goal"]) * gb_per_sample
	var window_s: float = float(d["surface_minutes"]) * 60.0 if battery_only else 3600.0 * Data.PASS_HOURS * ops_days
	var downlink: float = rate * window_s / 1000.0
	var bud: float = budget()
	var limit: float = float(d["time_limit_days"])
	c["dry"] = dry
	c["prop"] = prop
	c["mass"] = total
	c["cap"] = cap
	c["mass_margin"] = (cap - total) / cap if cap > 0.0 else -1.0
	c["parts_cost"] = cost
	c["rocket_cost"] = float(rk["cost"])
	c["ops_cost"] = ops_cost
	c["cost"] = total_cost
	c["budget"] = bud
	c["budget_margin"] = (bud - total_cost) / bud
	c["dev_days"] = dev_days
	c["cruise_days"] = cruise_days
	c["ops_days"] = ops_days
	c["flight_days"] = flight_days
	c["days"] = days
	c["limit"] = limit
	c["years"] = years
	c["kinds"] = kinds_n
	c["dev_text"] = "Building takes %s days: %d to design and test, %d for each of the %d kinds of part%s. Game rule." % [
		fmt(dev_days), int(Data.DEV_BASE_DAYS), int(Data.DEV_DAYS_PER_KIND), kinds_n,
		", %d for nuclear launch approval" % int(Data.DEV_NUCLEAR_DAYS) if rtg > 0.0 else ""]
	c["solar_space"] = solar_space
	c["solar_dest"] = solar_dest
	c["rtg"] = rtg_dest
	c["gen"] = gen
	c["gen_space"] = solar_space + rtg_dest
	c["draw_ops"] = draw_ops
	c["draw_cruise"] = draw_cruise
	c["power_need"] = power_need
	c["power_margin"] = (gen - power_need) / power_need if power_need > 0.0 else 1.0
	c["wh"] = wh
	c["dark_hours"] = dark_hours
	c["night_need"] = night_need
	c["dv"] = dv
	c["prop_need"] = prop_need
	c["prop_ok"] = prop_ok
	c["store"] = store
	c["rate"] = rate
	c["window_s"] = window_s
	c["downlink"] = downlink
	c["data_exp"] = data_exp
	c["gb_per_sample"] = gb_per_sample
	c["pts"] = pts
	c["touch"] = touch
	var night_ok: float = night_need * (1.0 + float(mg["battery"]))
	c["status"] = {
		"mass": _st(cap > 0.0 and total <= cap, float(c["mass_margin"]) >= float(mg["mass"])),
		"power": _st(gen >= power_need and wh >= night_need, float(c["power_margin"]) >= float(mg["power"]) and wh >= night_ok),
		"battery": _st(wh >= night_need, wh >= night_ok),
		"budget": _st(total_cost <= bud, float(c["budget_margin"]) >= float(mg["budget"])),
		"time": _st(days <= limit, true),
		"data": _st(store >= data_exp and data_exp > 0.0, store >= data_exp * (1.0 + float(mg["data"]))),
		"comms": _st(rate > 0.0 and downlink >= data_exp, downlink >= data_exp * float(mg["comms"])),
		"fuel": _st(prop >= prop_need - 0.01, prop >= prop_ok - 0.01),
	}
	# how far each resource is above what a green lamp needs (0 = exactly at the margin, below 0 = yellow or red)
	c["slack"] = {
		"mass": float(c["mass_margin"]) - float(mg["mass"]),
		"power": float(c["power_margin"]) - float(mg["power"]),
		"battery": wh / night_ok - 1.0 if night_ok > 0.0 else 1.0,
		"fuel": (prop - prop_ok) / maxf(prop_ok, 1.0),
		"data": store / (data_exp * (1.0 + float(mg["data"]))) - 1.0 if data_exp > 0.0 else -1.0,
		"comms": downlink / (data_exp * float(mg["comms"])) - 1.0 if data_exp > 0.0 else -1.0,
		"budget": float(c["budget_margin"]) - float(mg["budget"]),
		"time": (limit - days) / limit,
	}
	c["use"] = _use(c)
	c["use_rule"] = Data.USE_RULE % int(diff("over_mult"))
	c["issues"] = role_issues(c)
	return c

const USE_TIPS: Dictionary = {
	"power": ["Add a solar array or a nuclear battery (RTG).", "More power than the ship uses: take a power part off."],
	"battery": ["Add a battery for the dark hours.", "More battery than the dark hours need: take one off."],
	"fuel": ["Add propellant until the bar is in the green band.", "Too much fuel: take tanks off and save mass."],
	"data": ["Add a data recorder.", "More storage than the science needs: drop a recorder."],
	"comms": ["Use a bigger antenna, or lighter instruments.", "A smaller antenna would still send everything."],
	"mass": ["This rocket is far bigger than the ship needs: pick a cheaper one.", "Under 35% of the lift spare: lighter ship or bigger rocket."],
	"budget": ["Money to spare: add science, it raises the score.", "Under 25% reserve: a cheaper rocket or fewer extras."],
	"time": ["", "Past the deadline: a faster path or fewer kinds of parts."],
}

## One line of the resource table. band_on = "have": the ship chooses what it carries, under is the risk and
## over the waste. band_on = "need": the limit is fixed (rocket, budget, deadline), over is the risk and
## under the waste. state = "risk" | "well" | "waste" is the same for both, for colours.
func _use_row(key: String, need: float, have: float, lo: float, hi: float, unit: String, band_on: String) -> Dictionary:
	var v: float = have if band_on == "have" else need
	var rating: String = "well"
	if v < lo - 0.01:
		rating = "under"
	elif v > hi + 0.01:
		rating = "over"
	var state: String = "well"
	if rating != "well":
		state = "risk" if (rating == "under") == (band_on == "have") else "waste"
	var tip: String = "Well sized."
	if rating != "well":
		tip = USE_TIPS[key][0 if rating == "under" else 1]
	return {"name": Data.USE_NAMES[key], "need": need, "have": have, "lo": lo, "hi": maxf(hi, lo), "unit": unit,
		"band_on": band_on, "rating": rating, "state": state, "tip": tip}

## Each resource: what the mission needs, what the ship has, the green band and the rating (design 8d).
## Parts come in whole units, so the ceiling is never below the smallest set of parts that reaches the band.
func _use(c: Dictionary) -> Dictionary:
	var d: Dictionary = dest()
	var mg: Dictionary = Data.MARGIN
	var k: float = diff("over_mult")
	var u: Dictionary = {}
	# power: the smallest number of arrays, or of RTGs, that reaches the band is always "well"
	var p_need: float = c["power_need"]
	var p_lo: float = p_need * (1.0 + float(mg["power"]))
	var p_hi: float = p_need * (1.0 + k * float(mg["power"]))
	var sun: float = float(d["sun_au"])
	var sun_k: float = pow(1.0 - Data.SOLAR_DECAY_PER_YEAR, float(c["years"])) / (sun * sun) * (1.0 if d.has("surface_minutes") else float(d["dust"]))
	for id: String in ["solar", "solar_lite", "rtg"]:
		var p: Dictionary = Data.PARTS[id]
		var unit: float = float(p["gen"]) * (sun_k if p["kind"] == "solar" else (0.5 if float(c["years"]) > Data.RTG_LIFE_YEARS else 1.0))
		if part_available(id) and unit > 0.0 and ceilf(p_lo / unit) <= float(p["max"]):
			p_hi = maxf(p_hi, ceilf(p_lo / unit) * unit)
	u["power"] = _use_row("power", p_need, c["gen"], p_lo, p_hi, "W", "have")
	# battery: one spare unit is a fair reserve (events draw on it)
	var b_unit: float = float(Data.PARTS["battery_hi" if part_available("battery_hi") else "battery"]["wh"])
	var b_lo: float = float(c["night_need"]) * (1.0 + float(mg["battery"]))
	u["battery"] = _use_row("battery", c["night_need"], c["wh"], b_lo,
		maxf(float(c["night_need"]) * (1.0 + k * float(mg["battery"])), (ceilf(b_lo / b_unit) + 1.0) * b_unit), "Wh", "have")
	# fuel: tanks hold 100 kg
	var f_unit: float = float(Data.PARTS["prop"]["mass"])
	u["fuel"] = _use_row("fuel", c["prop_need"], c["prop"], c["prop_ok"],
		maxf(rocket_eq_prop(float(c["dry"]), float(c["dv"]["total"]) * (1.0 + k * float(mg["fuel"]))), ceilf(float(c["prop_ok"]) / f_unit) * f_unit), "kg", "have")
	# data: the bus stores some, a recorder adds a lot; one spare recorder is a fair reserve
	var s_bus: float = float(Data.PARTS["bus"]["store_gb"])
	var s_unit: float = float(Data.PARTS["recorder"]["store_gb"])
	var s_lo: float = float(c["data_exp"]) * (1.0 + float(mg["data"]))
	u["data"] = _use_row("data", c["data_exp"], c["store"], s_lo,
		maxf(float(c["data_exp"]) * (1.0 + k * float(mg["data"])), s_bus + (ceilf(maxf(0.0, s_lo - s_bus) / s_unit) + 1.0) * s_unit), "Gb", "have")
	# comms: the cheapest antenna that closes the link with margin is always "well"
	var l_lo: float = float(c["data_exp"]) * float(mg["comms"])
	var l_hi: float = float(c["data_exp"]) * (1.0 + k * (float(mg["comms"]) - 1.0))
	var best_cost: float = INF
	var au: float = float(d["earth_au"])
	for id: String in ["lga", "mga", "hga", "ka"]:
		var p: Dictionary = Data.PARTS[id]
		var down: float = minf(float(p["rate"]) / (au * au), float(p["rate_cap"])) * float(c["window_s"]) / 1000.0
		if part_available(id) and down >= l_lo and float(p["cost"]) < best_cost:
			best_cost = float(p["cost"])
			l_hi = maxf(float(c["data_exp"]) * (1.0 + k * (float(mg["comms"]) - 1.0)), down)
	if best_cost == INF:
		l_hi = maxf(l_hi, float(c["downlink"]))  # nothing closes the link with margin: the best there is cannot be "over"
	u["comms"] = _use_row("comms", c["data_exp"], c["downlink"], l_lo, l_hi, "Gb", "have")
	# rocket lift: over = less than the 35% spare; under = a cheaper rocket would lift this ship with the margin
	var cap: float = c["cap"]
	var m_lo: float = 0.0
	for id: String in Data.ROCKETS:
		var r: Dictionary = Data.ROCKETS[id]
		if (r["cap"] as Dictionary).has(dest_id) and float(r["cost"]) < float(c["rocket_cost"]):
			m_lo = maxf(m_lo, float(r["cap"][dest_id]) * float(traj()["cap_mult"]) * (1.0 - float(mg["mass"])))
	u["mass"] = _use_row("mass", c["mass"], cap, m_lo, cap * (1.0 - float(mg["mass"])), "kg", "need")
	var bud: float = c["budget"]
	u["budget"] = _use_row("budget", c["cost"], bud, bud * (1.0 - float(mg["budget"]) - 0.1 * k), bud * (1.0 - float(mg["budget"])), "$M", "need")
	u["time"] = _use_row("time", c["days"], c["limit"], 0.0, c["limit"], "days", "need")
	return u

func id_has(id: String) -> bool:
	return count(id) > 0

func _st(ok: bool, good: bool) -> String:
	if not ok:
		return "bad"
	return "ok" if good else "warn"

func role_issues(c: Dictionary) -> Dictionary:
	var d: Dictionary = dest()
	var st: Dictionary = c["status"]
	var r: Dictionary = {"planner": [], "engineer": [], "science": [], "comms": []}
	var rk: Dictionary = Data.ROCKETS[rocket_id]
	var caps: Dictionary = rk["cap"]
	var land: bool = d["kind"] == "land"
	if not caps.has(dest_id):
		r["planner"].append("%s cannot reach %s." % [rk["name"], place().capitalize()])
	if st["budget"] == "bad":
		r["planner"].append("Over budget: $%dM of $%dM." % [roundi(c["cost"]), roundi(c["budget"])])
	if st["time"] == "bad":
		r["planner"].append("Mission takes too long.")
	if st["mass"] == "bad":
		r["engineer"].append("Too heavy: %s kg, rocket lifts %s kg." % [fmt(c["mass"]), fmt(c["cap"])])
	elif st["mass"] == "warn":
		r["engineer"].append("Mass margin under %d%%." % roundi(float(Data.MARGIN["mass"]) * 100))
	if float(c["gen"]) < float(c["power_need"]):
		r["engineer"].append("Power: makes %d W, needs %d W." % [roundi(c["gen"]), roundi(c["power_need"])])
	if float(c["wh"]) < float(c["night_need"]):
		r["engineer"].append("Battery too small (%s Wh needed)." % fmt(c["night_need"]))
	if st["fuel"] == "bad":
		r["engineer"].append("Fuel: %s kg, rocket equation says %s kg." % [fmt(c["prop"]), fmt(c["prop_need"])])
	if needs_shade() and not id_has("sunshade"):
		r["engineer"].append("No sunshade: the ship overheats near the Sun.")
	if has_hazard("radiation") and not id_has("shield"):
		r["engineer"].append("No radiation shield: the belts break electronics.")
	if not land:
		if not id_has("drone"):
			r["science"].append("No drone: nothing can collect ring samples.")
	else:
		if not id_has("drill"):
			r["science"].append("No drill: you cannot pick up samples.")
		if not id_has("rover") and not id_has("rover_big"):
			r["science"].append("No rover: you can only reach rocks next to the lander.")
		if d["air"] == "thick":
			if not id_has("hull"):
				r["science"].append("No pressure hull: the air crushes the lander.")
		elif not id_has("legs") and not id_has("airbags"):
			r["science"].append("No legs or airbags: touchdown must be under 1 m/s.")
		if d["air"] != "none" and not id_has("heatshield"):
			r["science"].append("No heat shield: the lander will burn up in the air.")
	if int(c["pts"]) <= 1:
		r["science"].append("Add a science instrument.")
	if bool(d["returns"]) and not id_has("ascent"):
		r["science"].append("No ascent stage: samples cannot come home.")
	if float(c["rate"]) <= 0.0:
		r["comms"].append("No antenna: you cannot talk to Earth.")
	elif st["comms"] == "bad":
		r["comms"].append("Downlink %s Gb < science %s Gb." % [fmt(c["downlink"]), fmt(c["data_exp"])])
	if st["data"] == "bad":
		r["comms"].append("Storage %s Gb < science %s Gb." % [fmt(c["store"]), fmt(c["data_exp"])])
	return r

static func fmt(v: Variant) -> String:
	var f: float = float(v)
	if absf(f) >= 100.0:
		var s: String = str(roundi(f))
		var out: String = ""
		var cnt: int = 0
		for i: int in range(s.length() - 1, -1, -1):
			out = s[i] + out
			cnt += 1
			if cnt % 3 == 0 and i > 0 and s[i - 1] != "-":
				out = "," + out
		return out
	if absf(f) >= 10.0:
		return str(roundi(f))
	return "%.2f" % f if absf(f) < 1.0 else "%.1f" % f

# ---------------------------------------------------------------- simulation

## seed_n >= 0 makes the flight's events and dice repeatable (tests); the game passes nothing.
func start_run(seed_n: int = -1) -> void:
	var c: Dictionary = calc()
	run = {
		"calc": c,
		"mass": float(c["mass"]),
		"dry": float(c["dry"]),
		"prop": float(c["prop"]),
		"battery": float(c["wh"]),
		"wh": float(c["wh"]),
		"data": 0.0,
		"sent": 0.0,
		"samples": 0,
		"pts": 0,
		"broken": {},
		"log": [],
		"obj": {},
		"dead": false,
		"landing_speed": 0.0,
		"storm": {},
		"reward": 0,
		# v5: what the decision events change
		"seed": seed_n if seed_n >= 0 else int(randi()),
		"events": [],
		"decisions": [],
		"days_extra": 0.0,
		"money": 0.0,
		"rate_mult": 1.0,
		"gen_mult": 1.0,
		"score_bonus": 0,
		"minutes_lost": 0.0,
		"hull_delta": 0,
		"cruised": false,
		"phase_now": "launch",
		"use": (c["use"] as Dictionary).duplicate(true),  # the resource ratings at launch, for the build report
		"difficulty": difficulty,
	}
	for o: String in dest()["objectives"]:
		run["obj"][o] = false
	event_plan()

func note(ok: bool, text: String) -> void:
	run["log"].append({"ok": ok, "text": text, "phase": run.get("phase_now", "")})

func fail(text: String) -> void:
	note(false, text)
	run["dead"] = true

func burn(dv_kms: float) -> float:
	## Returns propellant used (kg). If not enough, uses it all and returns -need.
	var m0: float = float(run["mass"])
	var need: float = m0 * (1.0 - exp(-dv_kms / ve()))
	var have: float = float(run["prop"])
	if need > have + 0.01:
		run["mass"] = m0 - have
		run["prop"] = 0.0
		return -need
	run["prop"] = have - need
	run["mass"] = m0 - need
	return need

func phase_launch() -> void:
	run["phase_now"] = "launch"
	var c: Dictionary = run["calc"]
	var rk: Dictionary = Data.ROCKETS[rocket_id]
	var caps: Dictionary = rk["cap"]
	if not caps.has(dest_id):
		fail("%s cannot send anything to %s." % [rk["name"], place().capitalize()])
		return
	if float(c["mass"]) > float(c["cap"]):
		fail("TOO HEAVY. The ship weighs %s kg but %s can send only %s kg on this path. The rocket could not reach the right speed." % [fmt(c["mass"]), rk["name"], fmt(c["cap"])])
		return
	run["obj"]["launch"] = true
	note(true, "Launch on %s: %s kg of %s kg capacity used." % [rk["name"], fmt(c["mass"]), fmt(c["cap"])])

## Checks that the ship survives the trip: power, heat near the Sun, fuel for course corrections.
## auto_events = true (old screens): a planned solar storm that nobody decided on is flown through as before.
## Screens that show the event cards call phase_cruise(false) and resolve the events themselves.
func phase_cruise(auto_events: bool = true) -> void:
	run["phase_now"] = "cruise"
	var c: Dictionary = run["calc"]
	var d: Dictionary = dest()
	var sun: float = float(d["sun_au"])
	var gen: float = float(c["gen_space"]) * float(run["gen_mult"])
	var need: float = float(c["draw_cruise"])
	if gen < need:
		fail("OUT OF POWER in deep space. At %s AU from the Sun your solar arrays give only %d W, but the ship needs %d W to stay warm and talk. Sunlight falls with distance squared." % [str(sun), roundi(gen), roundi(need)])
		return
	if needs_shade() and not id_has("sunshade"):
		fail("OVERHEATED. At %s sunlight is %s W/m2, %s times stronger than at Earth. Without a sunshade the electronics cooked on the way in." % [place().capitalize(), fmt(d["sun_wm2"]), fmt(float(d["sun_wm2"]) / 1361.0)])
		return
	var used: float = burn(Data.CRUISE_DV)
	run["cruised"] = true
	if used < 0.0:
		fail("NOT ENOUGH FUEL for course corrections. Small steering burns on the way needed %s kg; the ship drifted off its path and missed %s." % [fmt(-used), place().capitalize()])
		return
	note(true, "Cruise: %d days. Power OK (%d W made, %d W used). Course corrections used %s kg of fuel." % [int(traj()["days"]), roundi(gen), roundi(need), fmt(used)])
	if auto_events:
		for ev: Dictionary in run["events"]:
			if ev["id"] == "storm" and not bool(ev["done"]):
				resolve_event(ev, 1)

func _strongest(evs: Array) -> Dictionary:
	var best_ev: Dictionary = evs[0]
	for e: Dictionary in evs:
		if float(e["kp"]) > float(best_ev["kp"]):
			best_ev = e
	return best_ev

func phase_arrive() -> void:
	run["phase_now"] = "arrive"
	var d: Dictionary = dest()
	var dv: Dictionary = dv_plan()
	var cap_dv: float = float(dv["capture"])
	var name: String = place().capitalize()
	if d["air"] != "none" and id_has("heatshield"):
		if d["air"] == "thin":
			note(true, "%s arrival: direct entry. The lander dives from its cruise path straight into the thin air behind its heat shield. No braking burn." % name)
		else:
			note(true, "%s arrival: direct entry. The lander dives straight into the thick air behind its heat shield. No braking burn." % name)
		run["obj"]["arrive"] = true
	else:
		var used: float = burn(cap_dv)
		if used < 0.0:
			fail("NOT ENOUGH FUEL to brake into orbit. Braking by %s km/s needed %s kg of fuel; you had %s kg. The ship flew past %s." % [str(snappedf(cap_dv, 0.01)), fmt(-used), fmt(run["calc"]["prop"]), name])
			return
		run["obj"]["arrive"] = true
		note(true, "Orbit reached: braking burn of %s km/s used %s kg of fuel (rocket equation, Isp %d s)." % [str(snappedf(cap_dv, 0.01)), fmt(used), int(Data.ISP)])
	if has_hazard("radiation"):
		if id_has("shield"):
			note(true, "RADIATION BELTS: the shielding kept the electronics alive, as Juno's titanium vault does.")
		else:
			var hit: PackedStringArray = PackedStringArray()
			for target: String in ["comms", "science"]:
				var nm: String = _break(target)
				if nm != "":
					hit.append(nm)
			note(false, "RADIATION. %s's belts hit the unshielded electronics%s. Juno hides its computer in a titanium vault." % [name, ": the %s failed" % " and the ".join(hit) if not hit.is_empty() else ""])

## Called before the landing minigame. Returns the start state for it:
## g, alt, vy, vx, drag, prop, mass, touch, air ("none" | "thin" | "thick") and vterm
## (m/s: in thick air the lander cannot fall faster than this and needs no engine; 0 elsewhere).
func landing_setup() -> Dictionary:
	run["phase_now"] = "landing"
	var d: Dictionary = dest()
	var air: String = d["air"]
	var s: Dictionary = {"g": float(d["gravity"]), "alt": 600.0, "vy": 20.0, "vx": 3.0, "drag": 0.0}
	if air == "none":
		# coming down from low orbit: all but the last 0.14 km/s is spent before the final approach
		var used: float = burn(maxf(0.0, float(d["landing_dv"]) - 0.14))
		if used < 0.0:
			note(false, "Fuel ran out during the descent from orbit.")
		else:
			note(true, "Descent from orbit used %s kg of fuel." % fmt(used))
	elif not id_has("heatshield"):
		fail("BURNED UP at %s. Even behind a shield, entry heats a lander to about 1,300 C. Without one it burns." % place().capitalize())
	elif air == "thin":
		if id_has("chute"):
			note(true, "Entry: heat shield OK, parachute opened (420 m/s to 85 m/s). Powered descent begins.")
			s = {"g": float(d["gravity"]), "alt": 1500.0, "vy": 85.0, "vx": 6.0, "drag": 0.0}
		else:
			note(false, "Entry: heat shield OK but NO PARACHUTE. Still falling at 420 m/s.")
			s = {"g": float(d["gravity"]), "alt": 3000.0, "vy": 420.0, "vx": 8.0, "drag": 0.0}
		var dropped: float = float(Data.PARTS["heatshield"]["mass"]) + float(Data.PARTS["chute"]["mass"]) * count("chute")
		run["mass"] = float(run["mass"]) - dropped
		note(true, "Heat shield and parachute dropped away (%s kg lighter)." % fmt(dropped))
	else:
		note(true, "Entry: heat shield OK. The air is so thick that the lander sinks through it at %s m/s with no engine and no parachute." % fmt(Data.VENUS_TOUCHDOWN))
		s = {"g": float(d["gravity"]), "alt": 300.0, "vy": Data.VENUS_TOUCHDOWN, "vx": 4.0, "drag": 0.0}
		run["mass"] = float(run["mass"]) - float(Data.PARTS["heatshield"]["mass"])
	s["prop"] = float(run["prop"])
	s["mass"] = float(run["mass"])
	if not run.has("touch_scaled"):
		run["calc"]["touch"] = float(run["calc"]["touch"]) * diff("landing_forgive")  # the difficulty's touchdown limit
		run["touch_scaled"] = true
	s["touch"] = float(run["calc"]["touch"])
	s["air"] = air
	s["vterm"] = Data.VENUS_TOUCHDOWN if air == "thick" else 0.0
	return s

## reason: a crash cause the speeds don't explain (online: the legs were still up).
func landing_result(ok: bool, vy: float, prop_left: float, reason: String = "") -> void:
	run["landing_speed"] = vy
	var used: float = float(run["prop"]) - prop_left
	run["prop"] = prop_left
	run["mass"] = float(run["mass"]) - used
	var touch: float = float(run["calc"]["touch"])
	if not ok:
		if prop_left <= 0.5 and dest()["air"] != "thick":
			fail("CRASH at %.1f m/s. Out of fuel before touchdown: bring more propellant." % vy)
		else:
			fail("CRASH at %.1f m/s. The %s can survive only %.0f m/s." % [vy, "landing gear" if touch > 1.0 else "bare frame", touch])
	elif has_hazard("pressure") and not id_has("hull"):
		fail("CRUSHED. The air at the surface of %s presses 92 times harder than Earth's. Without a pressure hull the lander folded like a can." % place().capitalize())
	else:
		run["obj"]["land"] = true
		note(true, "TOUCHDOWN at %.1f m/s (limit %.0f m/s). %s kg of fuel left." % [vy, touch, fmt(prop_left)])

func surface_result(samples: int, battery: float, data: float) -> void:
	run["phase_now"] = "site"
	run["samples"] = samples
	run["battery"] = battery
	run["data"] = data
	var goal: int = int(dest()["samples_goal"])
	run["obj"]["samples"] = samples >= goal
	note(samples >= goal, "Samples collected: %d of %d. Battery left: %d%%." % [samples, goal, roundi(100.0 * battery / maxf(1.0, float(run["wh"])))])

func probe_result(samples: int, docked: bool, data: float) -> void:
	run["phase_now"] = "site"
	run["obj"]["deploy"] = true
	run["samples"] = samples
	run["data"] = data
	var goal: int = int(dest()["samples_goal"])
	run["obj"]["samples"] = samples >= goal
	run["obj"]["dock"] = docked
	note(samples >= goal, "Ring samples collected: %d of %d." % [samples, goal])
	if docked:
		note(true, "The drone docked with the orbiter and handed over its samples.")
	else:
		note(false, "The drone was lost: its samples never reached the orbiter.")
		run["data"] = 0.0

## Storage and radio speed as they are now, after broken parts and events.
func live_store() -> float:
	var store: float = float(run["calc"]["store"])
	if run["broken"].has("recorder"):
		store -= float(Data.PARTS["recorder"]["store_gb"]) * count("recorder")
	return store

func live_rate() -> float:
	var rate: float = float(run["calc"]["rate"]) * float(run["rate_mult"])
	for id: String in run["broken"]:
		if Data.PARTS[id].has("rate"):
			return rate * 0.1
	return rate

## Sends the science home and, where samples return, flies them back. Resolve the "home" events first.
func phase_home() -> void:
	run["phase_now"] = "home"
	var c: Dictionary = run["calc"]
	var d: Dictionary = dest()
	# Data to Earth
	var data: float = float(run["data"])
	var store: float = live_store()
	if data > store:
		note(false, "Storage full: %s Gb of science made but only %s Gb fit. The rest was lost." % [fmt(data), fmt(store)])
		data = store
	var rate: float = live_rate()
	var cap_gb: float = rate * float(c["window_s"]) / 1000.0
	var sent: float = minf(data, cap_gb)
	run["sent"] = sent
	if data > 0.0:
		var pct: float = 100.0 * sent / data
		var ok: bool = pct >= 90.0
		if run["obj"].has("downlink"):
			run["obj"]["downlink"] = ok
		var span: String = "over %d days, %d h a day" % [int(d["ops_days"]), int(Data.PASS_HOURS)]
		if d.has("surface_minutes"):
			span = "in the %d minutes the lander lived" % int(d["surface_minutes"])
		var rate_txt: String = ("%s Mbps" % fmt(rate)) if rate >= 0.1 else ("%s kbps" % fmt(rate * 1000.0))
		note(ok, "Sent %s of %s Gb to Earth (%d%%) at %s %s. Radio delay: %s." % [fmt(sent), fmt(data), roundi(pct), rate_txt, span, d["light_delay"]])
	elif run["obj"].has("downlink"):
		note(false, "No science data to send home.")
	# Sample return
	if bool(d["returns"]) and bool(run["obj"].get("land", false)):
		var pct_b: float = 100.0 * float(run["battery"]) / maxf(1.0, float(run["wh"]))
		if not id_has("ascent"):
			note(false, "No ascent stage: the samples stay on %s forever." % place().capitalize())
		elif pct_b < 30.0:
			note(false, "STRANDED. Battery at %d%%: game rule says the ascent needs 30%%. No way home." % roundi(pct_b))
		elif int(run["samples"]) == 0:
			note(false, "The ascent stage launched, but with no samples on board.")
		else:
			run["obj"]["return"] = true
			note(true, "The ascent stage lifted off and brought %d samples back to Earth." % int(run["samples"]))

# ---------------------------------------------------------------- decision events

## Rolls which events this flight meets. Called by start_run(). Each planned event is a copy of an
## Events.LIST entry plus "at" (0..1: how far through its phase it happens) and "done" (false).
func event_plan() -> void:
	_rng.seed = int(run["seed"])
	var d: Dictionary = dest()
	var per_leg: int = int(diff("events_per_leg"))
	var phases: Array = ["cruise", "site", "home"]
	var plan: Array = []
	for pi: int in phases.size():
		var pool: Array = []
		for ev: Dictionary in Events.LIST:
			if Events.eligible(ev, phases[pi], dest_id, d, build):
				pool.append(ev)
		for i: int in range(pool.size() - 1, 0, -1):  # shuffle with the run's own dice
			var j: int = _rng.randi_range(0, i)
			var tmp: Dictionary = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		var n: int = mini(per_leg, pool.size())
		for k: int in n:
			var ev: Dictionary = (pool[k] as Dictionary).duplicate(true)
			ev["at"] = clampf((k + 0.5 + _rng.randf_range(-0.2, 0.2)) / n, 0.12, 0.88)
			ev["done"] = false
			if ev["id"] == "storm":
				_dress_storm(ev)
			plan.append(ev)
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return phases.find(a["phase"]) * 10.0 + float(a["at"]) < phases.find(b["phase"]) * 10.0 + float(b["at"]))
	run["events"] = plan

## The storm is a real one from NASA DONKI: its strength sets the odds on the card.
func _dress_storm(ev: Dictionary) -> void:
	var evs: Array = Data.donki
	if evs.is_empty():
		return
	var st: Dictionary = evs[_rng.randi_range(0, evs.size() - 1)]
	if _rng.randf() < diff("storm_strong"):
		st = _strongest(evs)
	run["storm"] = st
	var strong: bool = float(st["kp"]) >= 7.5
	var chance: float = 0.7 if strong else 0.15
	ev["real"] = "Real storm of %s, Kp %s (NASA DONKI). %s" % [st["time"], str(st["kp"]), ev["real"]]
	ev["title"] = "SOLAR STORM INCOMING" if strong else "SMALL SOLAR STORM"
	var ch: Dictionary = ev["choices"][1]
	ch["risk"]["chance"] = chance
	ch["text"] = String(ch["text"]).replace("{pct}", str(roundi(chance * 100.0)))

## The next event of a phase that nobody has decided yet, or {}. Show it when the phase's progress
## (0..1) passes ev["at"].
func next_event(phase: String) -> Dictionary:
	if run.is_empty() or bool(run.get("dead", false)):
		return {}
	for ev: Dictionary in run["events"]:
		if ev["phase"] == phase and not bool(ev["done"]):
			return ev
	return {}

## A fresh, playable copy of any event by its id, whether or not this flight planned it (debug hooks, tests).
func event_by_id(id: String) -> Dictionary:
	var ev: Dictionary = Events.by_id(id).duplicate(true)
	if ev.is_empty():
		return ev
	ev["at"] = 0.5
	ev["done"] = false
	if id == "storm":
		_dress_storm(ev)
	return ev

## kg of fuel a burn of dv_ms would use right now.
func _dv_kg(dv_ms: float) -> float:
	return float(run["mass"]) * (1.0 - exp(-dv_ms / 1000.0 / ve()))

## kg of fuel the planned burns still ahead will use (after `spent` kg more are gone).
func _fuel_ahead(spent: float = 0.0) -> float:
	var dv: Dictionary = dv_plan()
	var left: float = 0.0
	if not bool(run["cruised"]):
		left += float(dv["cruise"])
	if not bool(run["obj"].get("arrive", false)):
		left += float(dv["capture"])
	if run["obj"].has("land") and not bool(run["obj"]["land"]):
		left += float(dv["landing"])
	return (float(run["mass"]) - spent) * (1.0 - exp(-left / ve()))

func money_left() -> float:
	return float(run["calc"]["budget"]) - float(run["calc"]["cost"]) - float(run["money"])

## Days over the limit when > 0 (development + cruise + operations + delays from events).
func days_over() -> float:
	return float(run["calc"]["days"]) + float(run["days_extra"]) - float(run["calc"]["limit"])

func _fuel_cost(e: Dictionary) -> float:
	return _dv_kg(float(e.get("dv_ms", 0.0))) + float(e.get("fuel_kg", 0.0))

func _battery_cost(e: Dictionary) -> float:
	return float(e.get("battery_pct", 0.0)) / 100.0 * float(run["wh"]) + float(e.get("battery_wh", 0.0))

## What is short right now: any of "fuel", "power", "comms", "time", "battery", "money".
func _shortfalls() -> Array:
	var c: Dictionary = run["calc"]
	var out: Array = []
	if float(run["prop"]) + 0.01 < _fuel_ahead():
		out.append("fuel")
	if float(c["gen"]) * float(run["gen_mult"]) < _draw_now():
		out.append("power")
	if live_rate() * float(c["window_s"]) / 1000.0 < float(c["data_exp"]):
		out.append("comms")
	if days_over() > 0.0:
		out.append("time")
	if float(run["wh"]) > 0.0 and float(run["battery"]) <= 0.0:
		out.append("battery")
	if money_left() < 0.0:
		out.append("money")
	return out

const SHORT_WORDS: Dictionary = {
	"fuel": "Not enough fuel is left for the burns ahead.",
	"power": "The ship now makes less power than it uses.",
	"comms": "The radio is now too slow to send all the science.",
	"time": "The mission will now end after its deadline.",
	"battery": "The battery is empty.",
	"money": "The budget is overspent.",
}

func _draw_now() -> float:
	var c: Dictionary = run["calc"]
	var draw: float = float(c["power_need"])
	if is_equal_approx(draw, float(c["draw_ops"])):
		for id: String in run["broken"]:
			if Data.PARTS[id]["cat"] == "science":
				draw -= float(Data.PARTS[id].get("draw", 0.0))
	return draw

## What a choice needs and whether the ship can pay for it, before the player picks:
##   can   bool    false = show the button greyed out
##   why   String  the reason it is closed ("NOT ENOUGH FUEL: 31 kg needed, 12 kg on board")
##   line  String  the price in the ship's own numbers ("31 kg of fuel, 85 kg on board"), "" when there is none
##   warn  String  open, but it leaves the ship short of something ("" = fine)
##   safe  bool    a part on board removes the risk of this choice
func event_choice(ev: Dictionary, i: int) -> Dictionary:
	var ch: Dictionary = ev["choices"][i]
	var c: Dictionary = run["calc"]
	var out: Dictionary = {"can": true, "why": "", "line": "", "warn": "", "safe": false}
	var cost: Dictionary = ch.get("cost", {})
	var lines: PackedStringArray = PackedStringArray()
	if ch.has("needs_part") and not Events.has_part(build, ch["needs_part"]):
		out["can"] = false
		out["why"] = "NOT ON YOUR SHIP: %s" % String(Data.PARTS[String(ch["needs_part"])]["name"]).to_upper()
		return out
	var kg: float = _fuel_cost(cost)
	if kg > 0.0:
		lines.append("%s kg of fuel, %s kg on board" % [fmt(kg), fmt(run["prop"])])
		if kg > float(run["prop"]) + 0.01:
			out["can"] = false
			out["why"] = "NOT ENOUGH FUEL: %s kg needed, %s kg on board" % [fmt(kg), fmt(run["prop"])]
		elif float(run["prop"]) - kg + 0.01 < _fuel_ahead(kg):
			out["warn"] = "LEAVES TOO LITTLE FUEL FOR THE BURNS AHEAD"
	var money: float = float(cost.get("money", 0.0))
	if money > 0.0:
		lines.append("reserve left $%sM" % fmt(maxf(0.0, money_left())))
		if money > money_left() + 0.001 and bool(out["can"]):
			out["can"] = false
			out["why"] = "NO MONEY: $%sM needed, $%sM of reserve left" % [fmt(money), fmt(maxf(0.0, money_left()))]
	var wh: float = _battery_cost(cost)
	if wh > 0.0:
		lines.append("battery at %d%%" % roundi(100.0 * float(run["battery"]) / maxf(1.0, float(run["wh"]))))
		if (float(run["wh"]) <= 0.0 or wh > float(run["battery"]) + 0.01) and bool(out["can"]):
			out["can"] = false
			out["why"] = "NO BATTERY ON BOARD" if float(run["wh"]) <= 0.0 else "BATTERY TOO LOW: it is at %d%%" % roundi(100.0 * float(run["battery"]) / float(run["wh"]))
	if cost.has("power"):
		var margin: float = float(c["gen"]) * float(run["gen_mult"]) / maxf(1.0, _draw_now()) - 1.0
		lines.append("power margin now %d%%" % roundi(margin * 100.0))
		if float(c["gen"]) * float(run["gen_mult"]) * float(cost["power"]) < _draw_now():
			out["warn"] = "NOT ENOUGH POWER MARGIN: SOMETHING WILL SWITCH OFF"
	if cost.has("rate"):
		var have: float = live_rate() * float(c["window_s"]) / 1000.0
		lines.append("radio can send %sx the data" % fmt(have / maxf(0.001, float(c["data_exp"]))))
		if have * float(cost["rate"]) < float(c["data_exp"]):
			out["warn"] = "THE RADIO WILL BE TOO SLOW FOR ALL THE DATA"
	if cost.has("days"):
		lines.append("%s days spare" % fmt(maxf(0.0, -days_over())))
		if days_over() + float(cost["days"]) > 0.0 and out["warn"] == "":
			out["warn"] = "MISSES THE DEADLINE"
	if ch.has("risk") and (ch["risk"] as Dictionary).has("save_part") and Events.has_part(build, ch["risk"]["save_part"]):
		out["safe"] = true
		lines.append("%s ON BOARD: NO RISK" % String(Data.PARTS[String(ch["risk"]["save_part"])]["name"]).to_upper())
	out["line"] = ". ".join(lines)
	return out

## Applies the player's choice. Returns
##   ok       bool    it went well
##   text     String  what happened, <= 120 characters
##   effects  Array[String]  each change in words ("-31 kg fuel", "+2 days")
##   chips    Array   the same as [icon name, text, bad: bool] for the card
##   applied  Dictionary  raw changes a screen must mirror in its own state: battery_wh, data_gb, samples,
##                        minutes, hull, power, broken [part ids]
##   grade    "good" | "risky" | "bad"   and   points 0..100: how the call counts in the report
## and logs it in run["decisions"] and run["log"]. An event can be resolved once.
func resolve_event(ev: Dictionary, choice: int) -> Dictionary:
	if bool(ev.get("done", false)):
		return ev["result"]
	var info: Dictionary = event_choice(ev, choice)
	if not bool(info["can"]):
		return {"ok": false, "text": String(info["why"]), "effects": [], "chips": [], "applied": {}, "grade": "bad", "points": 0, "refused": true}
	var ch: Dictionary = ev["choices"][choice]
	run["phase_now"] = ev["phase"]   # the report files the decision under its own leg of the trip
	var res: Dictionary = {"ok": true, "text": "", "effects": [], "chips": [], "applied": {}, "grade": "good", "points": 100}
	var short_before: Array = _shortfalls()
	var gambled: bool = false
	var chance: float = 0.0
	var lead: String = "Done."
	_apply(ch.get("cost", {}), res, false)
	if ch.has("risk"):
		var risk: Dictionary = ch["risk"]
		chance = float(risk["chance"])
		if bool(info["safe"]):
			lead = "The %s did its job: no damage." % String(Data.PARTS[String(risk["save_part"])]["name"]).to_lower()
		else:
			gambled = true
			if _rng.randf() < chance:
				res["ok"] = false
				lead = "It went wrong."
				_apply(risk["bad"], res, true)
			else:
				lead = "It worked."
	if bool(res["ok"]) and ch.has("gain"):
		_apply(ch["gain"], res, false)
	_power_check(res)
	var new_short: Array = []
	for s: String in _shortfalls():
		if not short_before.has(s):
			new_short.append(s)
	# how good was the call: by the odds taken and what it left the ship short of, not by luck alone
	if bool(run["dead"]):
		res["grade"] = "bad"
		res["points"] = 0
	elif not bool(res["ok"]):
		res["grade"] = "risky" if chance <= 0.35 else "bad"
		res["points"] = 40 if chance <= 0.35 else 15
	elif not new_short.is_empty():
		res["grade"] = "risky"
		res["points"] = 40
	elif gambled and chance > 0.35:
		res["grade"] = "risky"
		res["points"] = 70
	var text: String = lead
	if not (res["effects"] as Array).is_empty():
		text += " " + ", ".join(PackedStringArray(res["effects"])) + "."
	if not new_short.is_empty() and not bool(run["dead"]):
		text += " " + String(SHORT_WORDS[new_short[0]])
	if text.length() > 120:
		text = text.substr(0, 117) + "..."
	res["text"] = text
	res["short"] = new_short
	ev["done"] = true
	ev["choice"] = choice
	ev["result"] = res
	var fine: bool = bool(res["ok"]) and new_short.is_empty()
	run["decisions"].append({"id": ev["id"], "title": ev["title"], "phase": ev["phase"], "role": ev["role"],
		"choice": ch["label"], "ok": bool(res["ok"]), "good": res["grade"] == "good", "grade": res["grade"], "points": res["points"],
		"cost": ", ".join(PackedStringArray(res["effects"])) if not (res["effects"] as Array).is_empty() else "nothing", "text": text,
		"real": ev["real"]})
	if not bool(run["dead"]):
		note(fine, "DECISION, %s: %s. %s" % [ev["title"], ch["label"], text])
	return res

func _chip(res: Dictionary, icon: String, text: String, bad: bool) -> void:
	(res["effects"] as Array).append(text)
	(res["chips"] as Array).append([icon, text, bad])

func _apply(e: Dictionary, res: Dictionary, bad: bool) -> void:
	var ap: Dictionary = res["applied"]
	var kg: float = _fuel_cost(e)
	if kg > 0.0:
		kg = minf(kg, float(run["prop"]))
		run["prop"] = float(run["prop"]) - kg
		run["mass"] = float(run["mass"]) - kg
		_chip(res, "fuel", "-%s kg fuel" % fmt(kg), true)
	var wh: float = minf(_battery_cost(e), float(run["battery"]))
	if wh > 0.0:
		run["battery"] = float(run["battery"]) - wh
		ap["battery_wh"] = float(ap.get("battery_wh", 0.0)) - wh
		_chip(res, "battery", "-%d%% battery" % roundi(100.0 * wh / maxf(1.0, float(run["wh"]))), true)
	if e.has("power"):
		run["gen_mult"] = float(run["gen_mult"]) * float(e["power"])
		ap["power"] = float(e["power"])
		_chip(res, "power", "-%d%% power" % roundi((1.0 - float(e["power"])) * 100.0), true)
	if e.has("rate"):
		run["rate_mult"] = float(run["rate_mult"]) * float(e["rate"])
		_chip(res, "comms", "radio x%s" % str(e["rate"]), true)
	if e.has("money"):
		run["money"] = float(run["money"]) + float(e["money"])
		_chip(res, "money", "-$%sM" % fmt(e["money"]), true)
	if e.has("days"):
		run["days_extra"] = float(run["days_extra"]) + float(e["days"])
		_chip(res, "time", "+%d days" % int(e["days"]), true)
	var lost: float = float(run["data"]) * float(e.get("data_pct", 0.0)) / 100.0 + float(e.get("data_gb", 0.0))
	if e.has("data_pct") or e.has("data_gb"):
		lost = minf(lost, float(run["data"]))
		run["data"] = float(run["data"]) - lost
		ap["data_gb"] = float(ap.get("data_gb", 0.0)) - lost
		_chip(res, "data", "-%s Gb science" % fmt(lost) if lost > 0.0 else "no data on board to lose", lost > 0.0)
	if e.has("break"):
		var nm: String = _break(String(e["break"]), ap)
		_chip(res, "wrench", "%s lost" % nm if nm != "" else "nothing left to break", nm != "")
	if e.has("samples"):
		var before: int = int(run["samples"])
		run["samples"] = maxi(0, before + int(e["samples"]))
		ap["samples"] = int(ap.get("samples", 0)) + int(run["samples"]) - before
		_chip(res, "sample", "%+d samples" % (int(run["samples"]) - before), int(e["samples"]) < 0)
	if e.has("score"):
		run["score_bonus"] = int(run["score_bonus"]) + int(e["score"])
		_chip(res, "science", "%+d science" % int(e["score"]), int(e["score"]) < 0)
	if e.has("minutes"):
		run["minutes_lost"] = float(run["minutes_lost"]) + float(e["minutes"])
		ap["minutes"] = float(ap.get("minutes", 0.0)) - float(e["minutes"])
		_chip(res, "time", "-%d minutes" % int(e["minutes"]), true)
	if e.has("hull"):
		run["hull_delta"] = int(run["hull_delta"]) + int(e["hull"])
		ap["hull"] = int(ap.get("hull", 0)) + int(e["hull"])
		_chip(res, "shield", "drone %+d hull" % int(e["hull"]), int(e["hull"]) < 0)
	if e.has("fail"):
		fail(String(e["fail"]))
		_chip(res, "bad", "mission lost", true)
	if bad:
		res["ok"] = false

## Breaks a part: an id, "science" (an instrument, never the drill), "comms" (the antenna in use)
## or "electronics" (either). Returns the part's name, "" when nothing could break.
func _break(target: String, ap: Dictionary = {}) -> String:
	var pool: Array = []
	var best_rate: float = 0.0
	var antenna: String = ""
	for id: String in build:
		var p: Dictionary = Data.PARTS[id]
		if run["broken"].has(id):
			continue
		if id == target:
			pool = [id]
			break
		if (target == "science" or target == "electronics") and p["cat"] == "science" and id != "drill":
			pool.append(id)
		if p.has("rate") and float(p["rate"]) > best_rate:
			best_rate = float(p["rate"])
			antenna = id
	if (target == "comms" or target == "electronics") and antenna != "" and not pool.has(antenna):
		pool.append(antenna)
	if pool.is_empty():
		return ""
	var hit: String = pool[_rng.randi_range(0, pool.size() - 1)]
	run["broken"][hit] = true
	if not ap.has("broken"):
		ap["broken"] = []
	(ap["broken"] as Array).append(hit)
	return String(Data.PARTS[hit]["name"])

## After a power loss: instruments are switched off, hungriest first, until the ship makes what it uses.
func _power_check(res: Dictionary) -> void:
	var c: Dictionary = run["calc"]
	var gen: float = float(c["gen"]) * float(run["gen_mult"])
	while gen < _draw_now():
		var worst: String = ""
		for id: String in build:
			var p: Dictionary = Data.PARTS[id]
			if p["cat"] == "science" and id != "drill" and not run["broken"].has(id) and is_equal_approx(float(c["power_need"]), float(c["draw_ops"])):
				if worst == "" or float(p.get("draw", 0.0)) > float(Data.PARTS[worst].get("draw", 0.0)):
					worst = id
		if worst == "":
			break
		run["broken"][worst] = true
		if not (res["applied"] as Dictionary).has("broken"):
			res["applied"]["broken"] = []
		(res["applied"]["broken"] as Array).append(worst)
		_chip(res, "wrench", "%s switched off" % String(Data.PARTS[worst]["name"]), true)
	if gen < float(c["draw_cruise"]) and not bool(run["dead"]):
		fail("OUT OF POWER. After the damage the ship makes %d W and needs %d W just to stay alive. A power margin would have absorbed it." % [roundi(gen), roundi(c["draw_cruise"])])
		_chip(res, "bad", "mission lost", true)
		res["ok"] = false

# ---------------------------------------------------------------- the end

## Scores the flight. Keeps run["score"] (objectives, 0-100), run["reward"], run["roles"] as before and adds
## run["scores"]: {"success" | "science" | "efficiency" | "decisions": {"name", "value" 0-100, "tip"}},
## run["total"] (0-100: success 40%, the other three 20% each) and run["late_days"].
func finish() -> void:
	if Net.is_online() and not Net.is_host():
		return   # the host's game is the truth: its finished run arrives with the "goto report"
	var d: Dictionary = dest()
	var obj: Dictionary = run["obj"]
	var c: Dictionary = run["calc"]
	var st: Dictionary = c["status"]
	var done: int = 0
	for o: String in obj:
		if obj[o]:
			done += 1
	var score: int = roundi(100.0 * done / maxf(1.0, obj.size()))
	run["score"] = score
	if score > int(best.get(dest_id, 0)):
		best[dest_id] = score
	run["late_days"] = maxf(0.0, days_over())
	if days_over() > 0.0:
		note(false, "LATE. The mission ended %s days after its deadline of %s days." % [fmt(days_over()), fmt(c["limit"])])
	if float(run["money"]) > 0.0:
		note(money_left() >= 0.0, "Decisions on the way cost $%sM. Budget reserve left: $%sM of $%sM." % [fmt(run["money"]), fmt(money_left()), fmt(c["budget"])])
	var scores: Dictionary = {}
	# 1. mission success: the objectives
	var missed: String = ""
	for o: String in obj:
		if not obj[o] and missed == "":
			missed = String(Data.OBJ_NAMES[o])
	scores["success"] = {"name": "MISSION SUCCESS", "value": score,
		"tip": "Every goal was met." if missed == "" else "Missed goal: %s. The flight log says why." % missed}
	# 2. science value: samples, how much of it reached Earth, how rich the instruments are
	var goal: float = float(d["samples_goal"])
	var s_frac: float = minf(1.0, float(run["samples"]) / goal)
	var pts: int = 0
	for id: String in build:
		if Data.PARTS[id]["cat"] == "science" and not run["broken"].has(id):
			pts += int(Data.PARTS[id]["pts"])
	var home_frac: float = float(run["sent"]) / float(run["data"]) if float(run["data"]) > 0.0 else 0.0
	if bool(d["returns"]):
		home_frac = 1.0 if bool(obj.get("return", false)) else 0.0
	var rich: float = minf(1.0, pts / 6.0)
	var sci: int = clampi(roundi(40.0 * s_frac + 35.0 * home_frac * s_frac + 25.0 * rich * s_frac) + int(run["score_bonus"]), 0, 100)
	var sci_tip: String = "Full science: every sample, all of it home, rich instruments."
	if s_frac < 1.0:
		sci_tip = "Collect all %d samples: you got %d." % [int(goal), int(run["samples"])]
	elif home_frac < 0.999:
		sci_tip = "Bring the samples home." if bool(d["returns"]) else "Only %d%% of the data reached Earth: faster dish, more margin." % roundi(home_frac * 100.0)
	elif rich < 1.0:
		sci_tip = "Carry richer instruments: 6 points a sample is full marks, you had %d." % pts
	scores["science"] = {"name": "SCIENCE VALUE", "value": sci, "tip": sci_tip}
	# 3. resource efficiency: the resource ratings of the ship as launched (design 8d), then what the flight did to them
	var use: Dictionary = run["use"]
	var eff: float = 0.0
	var eff_tip: String = "Every resource was well sized: margin kept, nothing wasted."
	var eff_low: float = 100.0
	for key: String in use:
		var row: Dictionary = use[key]
		var v: float = 100.0
		if row["state"] == "waste":
			v = 55.0
		elif row["state"] == "risk":
			v = 35.0 if st[key] != "bad" else 0.0
		eff += v / use.size()
		if v < eff_low:
			eff_low = v
			eff_tip = "%s %s: %s" % [row["name"], "OVER" if row["rating"] == "over" else "UNDER", row["tip"]]
	if days_over() > 0.0:
		eff -= 10.0
		if eff_low >= 100.0:
			eff_tip = "The mission ran %s days late: keep spare days for surprises." % fmt(days_over())
	if money_left() < 0.0:
		eff -= 10.0
		if eff_low >= 100.0:
			eff_tip = "Decisions overspent the budget: the 25% reserve is there for them."
	scores["efficiency"] = {"name": "RESOURCE EFFICIENCY", "value": clampi(roundi(eff), 0, 100), "tip": eff_tip}
	# 4. good decisions: the event calls
	var decs: Array = run["decisions"]
	var dec: int = 70
	var dec_tip: String = "No decisions came up on this flight."
	if not decs.is_empty():
		var sum: float = 0.0
		var low: Dictionary = decs[0]
		for e: Dictionary in decs:
			sum += float(e["points"])
			if int(e["points"]) < int(low["points"]):
				low = e
		dec = roundi(sum / decs.size())
		dec_tip = "Every call was sound."
		if int(low["points"]) < 100:
			dec_tip = "%s: %s" % [String(low["title"]).capitalize(), "the gamble failed. Margin pays for the safe choice." if not bool(low["ok"]) else "it worked, but it was a gamble or left the ship short."]
	scores["decisions"] = {"name": "GOOD DECISIONS", "value": dec, "tip": dec_tip}
	run["scores"] = scores
	run["total"] = roundi(0.4 * score + 0.2 * sci + 0.2 * float(scores["efficiency"]["value"]) + 0.2 * dec)
	# credits for the Tech Lab
	var per: int = 10 + 10 * int(d["tier"])
	var reward: int = done * per + int(run["samples"]) * int(c["pts"]) * 2
	for e: Dictionary in decs:
		if bool(e["good"]):
			reward += 5
	run["reward"] = reward
	funds += reward
	missions_flown += 1
	# role scores
	var roles: Dictionary = {}
	roles["planner"] = (40 if st["budget"] != "bad" else 0) + (30 if st["time"] != "bad" else 0) + (30 if obj["launch"] else 0)
	roles["engineer"] = (35 if st["mass"] == "ok" else (20 if st["mass"] == "warn" else 0)) + (35 if st["power"] == "ok" else (20 if st["power"] == "warn" else 0)) + (30 if obj.get("arrive", false) else 0)
	roles["science"] = roundi(100.0 * s_frac)
	roles["comms"] = roundi(100.0 * float(run["sent"]) / float(run["data"])) if float(run["data"]) > 0.0 else 0
	run["roles"] = roles
	# letter grade: only a mission that met every goal of its task gets one
	var grade: String = ""
	var grade_text: String = "No letter: a mission goal was missed."
	if score >= 100:
		var total: int = run["total"]
		grade = "A" if total >= Data.GRADE_A else ("B" if total >= Data.GRADE_B else "C")
		grade_text = "Top grade: a total of %d or more." % Data.GRADE_A
		if grade != "A":
			grade_text = "%s needs a total of %d: you scored %d." % ["A" if grade == "B" else "B", Data.GRADE_A if grade == "B" else Data.GRADE_B, total]
	run["grade"] = grade
	run["report"] = _report(scores)
	run["report"]["grade"] = grade
	run["report"]["grade_text"] = grade_text
	run["report"]["grade_rule"] = Data.GRADE_RULE
	run["report"]["task"] = task()
	save_game()

const PHASE_NAMES: Dictionary = {"launch": "LAUNCH", "cruise": "CRUISE", "arrive": "ARRIVAL", "landing": "LANDING", "site": "AT THE SITE", "home": "SENDING IT HOME"}

## Everything the end report shows, in one place (design 8d, points 4 and 5):
##   phases      [{"id", "name", "ok": bool, "lines": [{"ok", "text"}]}] in flight order, only the phases reached
##   decisions   run["decisions"]: [{"id", "title", "phase", "role", "choice", "ok", "good", "grade", "points", "cost", "text"}]
##   objectives  [{"id", "name", "done": bool}]
##   scores      {"success" | "science" | "efficiency" | "decisions": {"name", "value", "tip"}},  total,  credits
##   build       the resource table at launch: {resource: {"name", "need", "have", "lo", "hi", "unit", "band_on", "rating", "state", "tip"}}
##   build_rule  the rating rule in words;  difficulty  its name;  late_days, money_spent, money_left
##   grade "A" | "B" | "C" | "" (no letter when a goal was missed), grade_text (<= 50), grade_rule;  task  the task flown
func _report(scores: Dictionary) -> Dictionary:
	var phases: Array = []
	for e: Dictionary in run["log"]:
		var id: String = e.get("phase", "")
		if phases.is_empty() or phases[-1]["id"] != id:
			phases.append({"id": id, "name": String(PHASE_NAMES.get(id, id.to_upper())), "ok": true, "lines": []})
		(phases[-1]["lines"] as Array).append({"ok": e["ok"], "text": e["text"]})
		if not bool(e["ok"]):
			phases[-1]["ok"] = false
	var objectives: Array = []
	for o: String in run["obj"]:
		objectives.append({"id": o, "name": String(Data.OBJ_NAMES[o]), "done": bool(run["obj"][o])})
	return {"phases": phases, "decisions": run["decisions"], "objectives": objectives, "scores": scores,
		"total": run["total"], "credits": run["reward"], "build": run["use"],
		"build_rule": Data.USE_RULE % int(float(Data.DIFFICULTY[int(run["difficulty"])]["over_mult"])),
		"difficulty": String(Data.DIFFICULTY[int(run["difficulty"])]["name"]),
		"late_days": run["late_days"], "money_spent": run["money"], "money_left": money_left()}

# ---------------------------------------------------------------- money

func buy_tech(id: String) -> bool:
	var t: Dictionary = Data.TECH[id]
	if tech.has(id) or funds < int(t["cost"]):
		return false
	funds -= int(t["cost"])
	tech[id] = true
	save_game()
	return true

func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"funds": funds, "tech": tech, "flown": missions_flown, "best": best, "difficulty": difficulty, "tasks": last_task}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var js: JSON = JSON.new()  # a half-written or damaged save must not log an error: just start fresh
	var parsed: Variant = js.data if js.parse(f.get_as_text()) == OK else null
	if parsed is Dictionary:
		var d: Dictionary = parsed
		funds = int(d.get("funds", 0))
		tech = d.get("tech", {})
		missions_flown = int(d.get("flown", 0))
		best = d.get("best", {})
		difficulty = clampi(int(d.get("difficulty", 1)), 0, 2)
		last_task = d.get("tasks", {})

func reset_save() -> void:
	funds = 0
	tech = {}
	missions_flown = 0
	best = {}
	save_game()

# ---------------------------------------------------------------- multiplayer (decision D7)
## Net (scripts/net.gd) moves the messages; this part keeps the shared state in step:
## the host's build, the signatures, the run, the screen changes and the team sync stats.

func _hook_net() -> void:
	Net.received.connect(_on_net)
	Net.disconnected.connect(_on_net_lost)

## True when the screens show the multiplayer parts: online, or offline testing with `-- roles=...`.
func multi() -> bool:
	return Net.is_online() or Net.my_roles().size() < Net.ALL_ROLES.size()

## Offline, a role this player doesn't own (`-- roles=...`) is done by the computer, the solo way.
func cpu(role: String) -> bool:
	return not Net.is_online() and not Net.owns(role)

## Is this role's flight job split out to a person? Solo: never, so solo plays as before.
func job(role: String) -> bool:
	return multi() and not cpu(role)

## Does the player with this id own the role? The host checks this before applying their action.
func sender_owns(from_id: int, role: String) -> bool:
	for p: Variant in Net.lobby().get("players", []):
		var pd: Dictionary = p
		if int(pd.get("id", -1)) == from_id:
			return (pd.get("roles", []) as Array).has(role)
	return false

## Name of whoever holds a role ("" offline or when nobody does).
func holder(role: String) -> String:
	for p: Variant in Net.lobby().get("players", []):
		var pd: Dictionary = p
		if (pd.get("roles", []) as Array).has(role):
			return String(pd.get("name", ""))
	return ""

static func role_name(role: String) -> String:
	for r: Dictionary in Data.ROLES:
		if r["id"] == role:
			return String(r["name"])
	return role.to_upper()

static func role_color(role: String) -> Color:
	for r: Dictionary in Data.ROLES:
		if r["id"] == role:
			return r["color"]
	return Color.WHITE

## The first role this player owns: the "from" of their requests and the colour of their chat.
func my_role() -> String:
	var mine: Array[String] = Net.my_roles()
	return mine[0] if not mine.is_empty() else "planner"

## All 4 roles signed. Offline, roles played by the computer count as signed.
func all_signed() -> bool:
	for r: String in Net.ALL_ROLES:
		if not bool(signed.get(r, false)) and not cpu(r):
			return false
	return true

func signed_count() -> int:
	var n: int = 0
	for r: String in Net.ALL_ROLES:
		if bool(signed.get(r, false)) or cpu(r):
			n += 1
	return n

func snap() -> Dictionary:
	return {"build": build.duplicate(), "rocket": rocket_id, "traj": traj_idx}

## Applies a host build snapshot. JSON turns counts into floats: they come back as ints here.
## Any change clears every signature. Returns true when something changed.
func apply_snap(d: Dictionary) -> bool:
	if not (d.get("build") is Dictionary):
		return false
	var b: Dictionary = {}
	var src: Dictionary = d["build"]
	for k: Variant in src:
		if Data.PARTS.has(String(k)) and int(src[k]) > 0:
			b[String(k)] = int(src[k])
	var rk: String = String(d.get("rocket", rocket_id))
	if not Data.ROCKETS.has(rk):
		rk = rocket_id
	var tr: int = clampi(int(d.get("traj", traj_idx)), 0, (dest()["traj"] as Array).size() - 1)
	if b == build and rk == rocket_id and tr == traj_idx:
		return false
	build = b
	rocket_id = rk
	traj_idx = tr
	signed = {}
	return true

## A screen change in the mission flow. Online only the host moves everyone; the others wait for its
## "goto". Offline it is a plain goto.
func flow(screen: String) -> void:
	if not Net.is_online():
		goto(screen)
	elif Net.is_host():
		host_goto(screen)

## Host: sends the run, then the screen change (destination, build, cruise seed), then goes there itself.
func host_goto(screen: String, seed_n: int = 0) -> void:
	Net.send("run", {"run": run})
	Net.send("goto", {"screen": screen, "dest": dest_id, "build": snap(), "seed": seed_n})
	goto(screen)

## Host and offline: starts the flight. Online every player flies the same cruise from the same seed.
func launch() -> void:
	var seed_n: int = randi() % 2000000000 + 1
	rng.seed = seed_n
	start_run()
	run["mode"] = "out"
	if Net.is_online():
		host_goto("flight", seed_n)
	else:
		goto("flight")

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
	match kind:
		"goto":
			if not Net.is_host():
				_remote_goto(d)
		"run":
			if not Net.is_host() and d.get("run") is Dictionary:
				run = d["run"]
		"build":
			if not Net.is_host():
				apply_snap(d)
		"sign":
			var role: String = String(d.get("role", ""))
			if sender_owns(from_id, role):
				signed[role] = bool(d.get("on", false))
		"request":
			team_request(String(d.get("id", "")))
		"reply":
			team_reply(String(d.get("id", "")))

func _remote_goto(d: Dictionary) -> void:
	var screen: String = String(d.get("screen", ""))
	if main == null or not ["builder", "flight", "landing", "surface", "probe", "report"].has(screen):
		return
	var id: String = String(d.get("dest", dest_id))
	if Data.DEST.has(id) and id != dest_id:
		new_mission(id)
	if d.get("build") is Dictionary:
		apply_snap(d["build"])
	match screen:
		"builder":
			signed = {}
		"flight":
			if int(d.get("seed", 0)) != 0:
				rng.seed = int(d["seed"])
				start_run()
				run["mode"] = "out"
		"report":
			# the host finished the run: this player earns the same credits
			funds += int(run.get("reward", 0))
			missions_flown += 1
			if int(run.get("score", 0)) > int(best.get(dest_id, 0)):
				best[dest_id] = int(run.get("score", 0))
			save_game()
	goto(screen)

func _on_net_lost(reason: String) -> void:
	net_error = reason if reason != "" else "connection lost"
	signed = {}
	if main != null:
		goto("menu")

## Leaves the room and goes back to solo play on the menu.
func leave_room() -> void:
	Net.leave()
	signed = {}
	goto("menu")

# ---------------------------------------------------------------- team sync score

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func team_reset() -> void:
	team = {"asked": 0, "answered": 0, "reply_s": 0.0, "open": {}, "green_t": -1.0, "sign_s": -1.0}

func team_request(id: String) -> void:
	if id == "" or (team["open"] as Dictionary).has(id):
		return
	team["asked"] = int(team["asked"]) + 1
	team["open"][id] = now()

func team_reply(id: String) -> void:
	var open: Dictionary = team["open"]
	if not open.has(id):
		return
	team["answered"] = int(team["answered"]) + 1
	team["reply_s"] = float(team["reply_s"]) + now() - float(open[id])
	open.erase(id)

## The builder calls this every frame: are all lamps green, and are all roles signed?
func team_tick(all_go: bool, all_sign: bool) -> void:
	if not all_go:
		team["green_t"] = -1.0
		return
	if float(team["green_t"]) < 0.0:
		team["green_t"] = now()
	if all_sign and float(team["sign_s"]) < 0.0:
		team["sign_s"] = now() - float(team["green_t"])

## 0..100 from requests answered, the average reply time and the time from all-green to all-signed.
func team_sync() -> int:
	var w: Dictionary = Data.TEAM_SYNC
	var asked: int = int(team["asked"])
	var answered: int = int(team["answered"])
	var a: float = 1.0 if asked == 0 else float(answered) / asked
	var r: float = 1.0
	if answered > 0:
		var avg: float = float(team["reply_s"]) / answered
		r = 1.0 - clampf((avg - float(w["reply_good_s"])) / (float(w["reply_bad_s"]) - float(w["reply_good_s"])), 0.0, 1.0)
	var s: float = 0.0
	if float(team["sign_s"]) >= 0.0:
		s = 1.0 - clampf((float(team["sign_s"]) - float(w["sign_good_s"])) / (float(w["sign_bad_s"]) - float(w["sign_good_s"])), 0.0, 1.0)
	var total: float = float(w["w_answered"]) + float(w["w_reply"]) + float(w["w_sign"])
	return roundi(100.0 * (float(w["w_answered"]) * a + float(w["w_reply"]) * r + float(w["w_sign"]) * s) / total)
