extends Node
## Game state, ship maths, mission simulation, money and saving.

const SAVE_PATH: String = "user://save.json"

var main: Node = null
var funds: int = 0
var tech: Dictionary = {}
var players: int = 1
var missions_flown: int = 0
var best: Dictionary = {}

var dest_id: String = "moon"
var build: Dictionary = {}
var rocket_id: String = "falcon9"
var traj_idx: int = 0
var signed: Dictionary = {}

var run: Dictionary = {}

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

# ---------------------------------------------------------------- build

func place() -> String:
	return {"moon": "THE MOON", "mars": "MARS", "saturn": "SATURN"}[dest_id]

func dest() -> Dictionary:
	return Data.DEST[dest_id]

func traj() -> Dictionary:
	var arr: Array = dest()["traj"]
	return arr[traj_idx]

func new_mission(id: String) -> void:
	dest_id = id
	build = {"bus": 1}
	traj_idx = 0
	signed = {}
	rocket_id = ""
	for r: String in Data.ROCKETS:
		var cap: Dictionary = Data.ROCKETS[r]["cap"]
		if cap.has(id) and rocket_id == "" and r != "electron":
			rocket_id = r

func example_build() -> void:
	build = {"bus": 1}
	signed = {}
	traj_idx = 0
	match dest_id:
		"moon":
			rocket_id = "falcon9"
			build.merge({"solar": 1, "battery": 2, "mga": 1, "camera": 1, "spectro": 1, "drill": 1, "rover": 1,
				"legs": 1, "ascent": 1, "prop": 24})
		"mars":
			rocket_id = "falcon9"
			build.merge({"solar": 2, "battery": 2, "mga": 1, "camera": 1, "spectro": 1, "drill": 1,
				"rover": 1, "heatshield": 1, "chute": 1, "airbags": 1, "prop": 4})
		"saturn":
			rocket_id = "heavy"
			build.merge({"rtg": 3, "hga": 1, "dust": 1, "mag": 1, "drone": 1,
				"shield": 1, "prop": 4})

func count(id: String) -> int:
	return int(build.get(id, 0))

func part_available(id: String) -> bool:
	var p: Dictionary = Data.PARTS[id]
	if p.has("tech") and not tech.has(p["tech"]):
		return false
	if p.has("dest") and p["dest"] != dest_id:
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
	return float(dest()["budget"]) + (100.0 if tech.has("grant") else 0.0)

func ve() -> float:
	return Data.ISP * Data.G0 / 1000.0  # km/s

func rocket_eq_prop(dry: float, dv_kms: float) -> float:
	return dry * (exp(dv_kms / ve()) - 1.0)

func dv_plan() -> Dictionary:
	var d: Dictionary = dest()
	var t: Dictionary = traj()
	var capture: float = float(d["capture_dv"]) * float(t["dv_mult"])
	var landing: float = float(d["landing_dv"])
	if dest_id == "mars":
		if count("heatshield") > 0:
			capture = 0.0
		landing = 0.3 if count("chute") > 0 else 0.9
	return {"capture": capture, "landing": landing, "total": capture + landing}

## Everything the builder bars and the review board need.
func calc() -> Dictionary:
	var d: Dictionary = dest()
	var t: Dictionary = traj()
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
	for id: String in build:
		var p: Dictionary = Data.PARTS[id]
		var n: int = int(build[id])
		var m: float = float(p["mass"]) * n
		if id == "prop":
			prop += m
		else:
			dry += m
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
	var days: float = float(t["days"]) + float(d["ops_days"])
	var years: float = days / 365.0
	var sun: float = float(d["sun_au"])
	var solar_dest: float = solar_1au / (sun * sun) * float(d["dust"]) * pow(1.0 - Data.SOLAR_DECAY_PER_YEAR, years)
	var rtg_dest: float = rtg * (0.5 if years > 14.0 else 1.0)
	var gen: float = solar_dest + rtg_dest
	var night_need: float = maxf(0.0, draw_ops - rtg_dest) * float(d["night_hours"])
	var total: float = dry + prop
	var cap: float = rocket_cap()
	var rk: Dictionary = Data.ROCKETS[rocket_id]
	var ops_cost: float = years * Data.OPS_COST_PER_YEAR
	var total_cost: float = cost + float(rk["cost"]) + ops_cost
	var dv: Dictionary = dv_plan()
	var prop_need: float = rocket_eq_prop(dry, float(dv["total"]))
	var data_exp: float = float(d["samples_goal"]) * gb_per_sample
	var downlink: float = rate * 3600.0 * Data.PASS_HOURS * float(d["ops_days"]) / 1000.0
	c["dry"] = dry
	c["prop"] = prop
	c["mass"] = total
	c["cap"] = cap
	c["mass_margin"] = (cap - total) / cap if cap > 0.0 else -1.0
	c["parts_cost"] = cost
	c["rocket_cost"] = float(rk["cost"])
	c["ops_cost"] = ops_cost
	c["cost"] = total_cost
	c["budget"] = budget()
	c["days"] = days
	c["limit"] = float(d["time_limit_days"])
	c["years"] = years
	c["solar_dest"] = solar_dest
	c["rtg"] = rtg_dest
	c["gen"] = gen
	c["draw_ops"] = draw_ops
	c["draw_cruise"] = draw_cruise
	c["power_margin"] = (gen - draw_ops) / draw_ops if draw_ops > 0.0 else 1.0
	c["wh"] = wh
	c["night_need"] = night_need
	c["dv"] = dv
	c["prop_need"] = prop_need
	c["store"] = store
	c["rate"] = rate
	c["downlink"] = downlink
	c["data_exp"] = data_exp
	c["gb_per_sample"] = gb_per_sample
	c["pts"] = pts
	c["touch"] = touch
	var m: float = float(d["margin"])
	c["status"] = {
		"mass": _st(cap > 0.0 and total <= cap, float(c["mass_margin"]) >= m),
		"power": _st(gen >= draw_ops and wh >= night_need, float(c["power_margin"]) >= m),
		"budget": _st(total_cost <= budget(), (budget() - total_cost) / budget() >= m * 0.5),
		"time": _st(days <= float(d["time_limit_days"]), true),
		"data": _st(store >= data_exp and data_exp > 0.0, store >= data_exp * (1.0 + m)),
		"comms": _st(rate > 0.0 and downlink >= data_exp, downlink >= data_exp * (1.0 + m)),
		"fuel": _st(prop >= prop_need, prop >= prop_need * (1.0 + m)),
	}
	c["issues"] = role_issues(c)
	return c

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
	if not caps.has(dest_id):
		r["planner"].append("%s cannot reach the %s." % [rk["name"], String(d["name"]).capitalize()])
	if st["budget"] == "bad":
		r["planner"].append("Over budget: $%dM of $%dM." % [roundi(c["cost"]), roundi(c["budget"])])
	if st["time"] == "bad":
		r["planner"].append("Mission takes too long.")
	if st["mass"] == "bad":
		r["engineer"].append("Too heavy: %s kg, rocket lifts %s kg." % [fmt(c["mass"]), fmt(c["cap"])])
	elif st["mass"] == "warn":
		r["engineer"].append("Mass margin under %d%%." % roundi(float(d["margin"]) * 100))
	if float(c["gen"]) < float(c["draw_ops"]):
		r["engineer"].append("Power: makes %d W, needs %d W." % [roundi(c["gen"]), roundi(c["draw_ops"])])
	if float(c["wh"]) < float(c["night_need"]):
		r["engineer"].append("Battery too small for the night (%s Wh needed)." % fmt(c["night_need"]))
	if st["fuel"] == "bad":
		r["engineer"].append("Fuel: %s kg, rocket equation says %s kg." % [fmt(c["prop"]), fmt(c["prop_need"])])
	if dest_id == "saturn":
		if not id_has("drone"):
			r["science"].append("No drone: nothing can collect ring samples.")
	else:
		if not id_has("drill"):
			r["science"].append("No drill: you cannot pick up samples.")
		if not id_has("rover") and not id_has("rover_big"):
			r["science"].append("No rover: you can only reach rocks next to the lander.")
		if not id_has("legs") and not id_has("airbags"):
			r["science"].append("No legs or airbags: touchdown must be under 1 m/s.")
	if int(c["pts"]) <= 1:
		r["science"].append("Add a science instrument.")
	if dest_id == "moon" and not id_has("ascent"):
		r["science"].append("No ascent stage: samples cannot come home.")
	if dest_id == "mars" and not id_has("heatshield"):
		r["science"].append("No heat shield: the lander will burn up in Mars' air.")
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

func start_run() -> void:
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
	}
	for o: String in dest()["objectives"]:
		run["obj"][o] = false

func note(ok: bool, text: String) -> void:
	run["log"].append({"ok": ok, "text": text})

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
	var c: Dictionary = run["calc"]
	var rk: Dictionary = Data.ROCKETS[rocket_id]
	var caps: Dictionary = rk["cap"]
	if not caps.has(dest_id):
		fail("%s cannot send anything to the %s." % [rk["name"], String(dest()["name"]).capitalize()])
		return
	if float(c["mass"]) > float(c["cap"]):
		fail("TOO HEAVY. The ship weighs %s kg but %s can send only %s kg on this path. The rocket could not reach the right speed." % [fmt(c["mass"]), rk["name"], fmt(c["cap"])])
		return
	run["obj"]["launch"] = true
	note(true, "Launch on %s: %s kg of %s kg capacity used." % [rk["name"], fmt(c["mass"]), fmt(c["cap"])])

func phase_cruise() -> void:
	var c: Dictionary = run["calc"]
	var d: Dictionary = dest()
	var sun: float = float(d["sun_au"])
	var solar_far: float = float(c["solar_dest"])
	var gen: float = solar_far + float(c["rtg"])
	var need: float = float(c["draw_cruise"])
	if gen < need:
		fail("OUT OF POWER in deep space. At %s AU from the Sun your solar arrays give only %d W, but the ship needs %d W to stay warm and talk. Sunlight falls with distance squared." % [str(sun), roundi(gen), roundi(need)])
		return
	note(true, "Cruise: %d days. Power OK (%d W made, %d W used)." % [int(traj()["days"]), roundi(gen), roundi(need)])
	# Real space weather from NASA DONKI
	var evs: Array = Data.donki
	if evs.is_empty():
		return
	var ev: Dictionary = evs[rng.randi() % evs.size()]
	if dest_id == "saturn" or rng.randf() < 0.35:
		ev = _strongest(evs)
	run["storm"] = ev
	var kp: float = float(ev["kp"])
	var when: String = String(ev["time"])
	if kp >= 7.5:
		if id_has("shield"):
			note(true, "SOLAR STORM (real event %s, Kp %s from NASA DONKI). Your radiation shielding protected the electronics." % [when, str(kp)])
		else:
			var victims: Array = []
			for id: String in build:
				var cat: String = Data.PARTS[id]["cat"]
				if cat == "science" or cat == "comms":
					victims.append(id)
			if victims.is_empty():
				note(false, "SOLAR STORM (real event %s, Kp %s). No shielding, but nothing important broke." % [when, str(kp)])
			else:
				var v: String = victims[rng.randi() % victims.size()]
				run["broken"][v] = true
				note(false, "SOLAR STORM (real event %s, Kp %s from NASA DONKI). No shielding: the %s was damaged by radiation." % [when, str(kp), Data.PARTS[v]["name"]])
	else:
		note(true, "Small solar storm on the way (real event %s, Kp %s from NASA DONKI). No damage." % [when, str(kp)])

func _strongest(evs: Array) -> Dictionary:
	var best_ev: Dictionary = evs[0]
	for e: Dictionary in evs:
		if float(e["kp"]) > float(best_ev["kp"]):
			best_ev = e
	return best_ev

func phase_arrive() -> void:
	var dv: Dictionary = dv_plan()
	var cap_dv: float = float(dv["capture"])
	var name: String = String(dest()["name"]).capitalize()
	if dest_id == "mars" and id_has("heatshield"):
		note(true, "Mars arrival: the heat shield used Mars' air to brake. No fuel needed.")
		run["obj"]["arrive"] = true
		return
	var used: float = burn(cap_dv)
	if used < 0.0:
		fail("NOT ENOUGH FUEL to brake into orbit. Braking by %s km/s needed %s kg of fuel; you had %s kg. The ship flew past the %s." % [str(cap_dv), fmt(-used), fmt(run["calc"]["prop"]), name])
		return
	run["obj"]["arrive"] = true
	note(true, "Orbit reached: braking burn of %s km/s used %s kg of fuel (rocket equation, Isp %d s)." % [str(cap_dv), fmt(used), int(Data.ISP)])

## Called before the landing minigame. Returns the start state for it.
## manual_chute (online landing job): the parachute stays packed and the Scientist opens it.
func landing_setup(manual_chute: bool = false) -> Dictionary:
	var s: Dictionary = {"g": float(dest()["gravity"]), "alt": 600.0, "vy": 20.0, "vx": 3.0, "drag": 0.0}
	if dest_id == "moon":
		# deorbit from 50 km orbit: most of the 1.89 km/s is spent before the final approach
		var used: float = burn(1.75)
		if used < 0.0:
			note(false, "Fuel ran out during the descent from orbit.")
		else:
			note(true, "Descent from orbit used %s kg of fuel." % fmt(used))
	elif dest_id == "mars":
		if not id_has("heatshield"):
			fail("BURNED UP. Without a heat shield, Mars' air heated the lander to thousands of degrees on entry.")
			return s
		if id_has("chute") and manual_chute:
			var j: Dictionary = Data.LANDING_JOBS
			note(true, "Entry: heat shield OK. The parachute is packed: the Scientist must open it.")
			s = {"g": 3.71, "alt": float(j["mars_alt"]), "vy": float(j["mars_vy"]), "vx": float(j["mars_vx"]), "drag": 0.0}
		elif id_has("chute"):
			note(true, "Entry: heat shield OK, parachute opened (420 m/s to 90 m/s). Powered descent begins.")
			s = {"g": 3.71, "alt": 1500.0, "vy": 90.0, "vx": 6.0, "drag": 0.0}
		else:
			note(false, "Entry: heat shield OK but NO PARACHUTE. Still falling at 420 m/s.")
			s = {"g": 3.71, "alt": 3000.0, "vy": 420.0, "vx": 8.0, "drag": 0.0}
		var dropped: float = float(Data.PARTS["heatshield"]["mass"]) + float(Data.PARTS["chute"]["mass"]) * count("chute")
		run["mass"] = float(run["mass"]) - dropped
		note(true, "Heat shield and parachute dropped away (%s kg lighter)." % fmt(dropped))
	s["prop"] = float(run["prop"])
	s["mass"] = float(run["mass"])
	s["touch"] = float(run["calc"]["touch"])
	return s

## reason: a crash cause the speeds don't explain (online: the legs were still up).
func landing_result(ok: bool, vy: float, prop_left: float, reason: String = "") -> void:
	run["landing_speed"] = vy
	var used: float = float(run["prop"]) - prop_left
	run["prop"] = prop_left
	run["mass"] = float(run["mass"]) - used
	if ok:
		run["obj"]["land"] = true
		note(true, "TOUCHDOWN at %.1f m/s (limit %.0f m/s). %s kg of fuel left." % [vy, float(run["calc"]["touch"]), fmt(prop_left)])
	else:
		if reason != "":
			fail("CRASH at %.1f m/s. %s" % [vy, reason])
		elif prop_left <= 0.5:
			fail("CRASH at %.1f m/s. Out of fuel before touchdown: bring more propellant." % vy)
		else:
			fail("CRASH at %.1f m/s. The %s can survive only %.0f m/s." % [vy, "landing gear" if float(run["calc"]["touch"]) > 1.0 else "bare frame", float(run["calc"]["touch"])])

func surface_result(samples: int, battery: float, data: float) -> void:
	run["samples"] = samples
	run["battery"] = battery
	run["data"] = data
	var goal: int = int(dest()["samples_goal"])
	run["obj"]["samples"] = samples >= goal
	note(samples >= goal, "Samples collected: %d of %d. Battery left: %d%%." % [samples, goal, roundi(100.0 * battery / maxf(1.0, float(run["wh"])))])

func probe_result(samples: int, docked: bool, data: float) -> void:
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

func phase_home() -> void:
	var c: Dictionary = run["calc"]
	var d: Dictionary = dest()
	# Data to Earth
	var data: float = float(run["data"])
	var store: float = float(c["store"])
	if data > store:
		note(false, "Storage full: %s Gb of science made but only %s Gb fit. The rest was lost." % [fmt(data), fmt(store)])
		data = store
	var rate: float = float(c["rate"])
	var bad_antenna: bool = false
	for id: String in run["broken"]:
		if Data.PARTS[id]["cat"] == "comms" and Data.PARTS[id].has("rate"):
			bad_antenna = true
	if bad_antenna:
		rate *= 0.1
	var cap_gb: float = rate * 3600.0 * Data.PASS_HOURS * float(d["ops_days"]) / 1000.0
	var sent: float = minf(data, cap_gb)
	run["sent"] = sent
	if data > 0.0:
		var pct: float = 100.0 * sent / data
		var ok: bool = pct >= 90.0
		if run["obj"].has("downlink"):
			run["obj"]["downlink"] = ok
		note(ok, "Sent %s of %s Gb to Earth (%d%%) at %s Mbps over %d days, %d h a day. Radio delay: %s." % [fmt(sent), fmt(data), roundi(pct), fmt(rate), int(d["ops_days"]), int(Data.PASS_HOURS), d["light_delay"]])
	elif run["obj"].has("downlink"):
		note(false, "No science data to send home.")
	# Moon sample return
	if dest_id == "moon" and bool(run["obj"].get("land", false)):
		var pct_b: float = 100.0 * float(run["battery"]) / maxf(1.0, float(run["wh"]))
		if not id_has("ascent"):
			note(false, "No ascent stage: the samples stay on the Moon forever.")
		elif pct_b < 30.0:
			note(false, "STRANDED. Battery at %d%%: the ascent engine needs 30%% to start. You can't go home." % roundi(pct_b))
		elif int(run["samples"]) == 0:
			note(false, "The ascent stage launched, but with no samples on board.")
		else:
			run["obj"]["return"] = true
			note(true, "The ascent stage lifted off and brought %d samples back to Earth." % int(run["samples"]))

func finish() -> void:
	if Net.is_online() and not Net.is_host():
		return   # the host's game is the truth: its finished run arrives with the "goto report"
	var d: Dictionary = dest()
	var obj: Dictionary = run["obj"]
	var c: Dictionary = run["calc"]
	var per: int = {"moon": 20, "mars": 30, "saturn": 50}[dest_id]
	var reward: int = 0
	for o: String in obj:
		if obj[o]:
			reward += per
	reward += int(run["samples"]) * int(c["pts"]) * 2
	# online jobs: the Planner's landing site and the Comms officer's downlink choice
	if run.has("site"):
		reward = roundi(reward * float(Data.LANDING_SITES[int(run["site"])]["credit_mult"]))
	reward += int(run.get("downlink_pts", 0)) * int(Data.DRONE_DOWNLINK["credits_per_pt"])
	run["reward"] = reward
	funds += reward
	missions_flown += 1
	var done: int = 0
	for o: String in obj:
		if obj[o]:
			done += 1
	var score: int = roundi(100.0 * done / maxf(1.0, obj.size()))
	run["score"] = score
	if score > int(best.get(dest_id, 0)):
		best[dest_id] = score
	# role scores
	var st: Dictionary = c["status"]
	var roles: Dictionary = {}
	roles["planner"] = (40 if st["budget"] != "bad" else 0) + (30 if st["time"] != "bad" else 0) + (30 if obj["launch"] else 0)
	roles["engineer"] = (35 if st["mass"] == "ok" else (20 if st["mass"] == "warn" else 0)) + (35 if st["power"] == "ok" else (20 if st["power"] == "warn" else 0)) + (30 if obj.get("arrive", false) else 0)
	roles["science"] = roundi(100.0 * minf(1.0, float(run["samples"]) / float(d["samples_goal"])))
	roles["comms"] = roundi(100.0 * float(run["sent"]) / float(run["data"])) if float(run["data"]) > 0.0 else 0
	run["roles"] = roles
	if Net.is_online():
		run["team_sync"] = team_sync()
		run["team"] = team.duplicate(true)
	save_game()

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
	f.store_string(JSON.stringify({"funds": funds, "tech": tech, "flown": missions_flown, "best": best}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		funds = int(d.get("funds", 0))
		tech = d.get("tech", {})
		missions_flown = int(d.get("flown", 0))
		best = d.get("best", {})

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
