extends SceneTree
## Headless balance check and core self-test. Run:
##   <Godot console binary> --headless --path <game> --script tools/dev/balance.gd
## For every destination it searches the buildable ships for the cheapest one that is green on every lamp,
## prints it with its slack per resource, and asserts that one exists, that it is "well used" on every
## resource, and that Game.example_build() is all green and survives the destination's forced hazards.
## Then it checks the events (shape, text budgets, coverage) and flies every destination many times.
## Prints "BALANCE OK" and exits 0, or lists every failure and exits 1.

var game: Node = null
var data: Node = null
var pre: GDScript = null
var events: GDScript = null
var fails: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	await process_frame   # autoloads exist after the first frame
	game = root.get_node("Game")
	data = root.get_node("Data")
	pre = load("res://scripts/preflight.gd")
	events = load("res://scripts/events.gd")
	var keep: Array = [game.get("funds"), game.get("tech"), game.get("missions_flown"), game.get("best"), game.get("difficulty")]
	game.set("tech", {})
	game.set("difficulty", 1)
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		only = a
	for id: String in data.get("DEST"):
		if only == "" or only == id:
			for ti: int in 3:
				_balance(id, ti)
	if only == "":
		_events()
		_flights()
		_preflight()
	# the test must not change the player's save
	game.set("funds", keep[0])
	game.set("tech", keep[1])
	game.set("missions_flown", keep[2])
	game.set("best", keep[3])
	game.set("difficulty", keep[4])
	game.call("save_game")
	if fails.is_empty():
		print("BALANCE OK")
	else:
		print("BALANCE FAILED: %d problem(s)" % fails.size())
		for f: String in fails:
			print("  FAIL ", f)
	quit(0 if fails.is_empty() else 1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)

func _all_ok(c: Dictionary) -> bool:
	for k: String in c["status"]:
		if c["status"][k] != "ok":
			return false
	return true

func _stations_ok() -> String:
	for s: Dictionary in pre.call("stations"):
		if s["status"] != "ok":
			return "%s %s: %s" % [s["id"], s["status"], s["headline"]]
	return ""

## Smallest count of `id` (0..max) that makes status `key` "ok", or -1.
func _least(id: String, key: String, from: int = 0) -> int:
	var b: Dictionary = game.get("build")
	var mx: int = int(data.get("PARTS")[id]["max"])
	for n: int in range(from, mx + 1):
		if n > 0:
			b[id] = n
		else:
			b.erase(id)
		if game.call("calc")["status"][key] == "ok":
			return n
	b.erase(id)
	return -1

func _balance(id: String, ti: int) -> void:
	game.call("new_mission", id)
	game.call("set_task", ti)
	var d: Dictionary = game.call("dest")
	var parts: Dictionary = data.get("PARTS")
	var land: bool = d["kind"] == "land"
	var who: String = "%s/%s" % [id, game.call("task")["id"]]
	var base: Dictionary = {"bus": 1, "shield": 1}
	var gear: Array = [[]]
	var jb: String = game.call("job")
	if land:
		if jb == "crew":
			base.merge({"crew": 1, "camera": 1})
		elif jb == "photo":
			base.merge({"rover": 1, "camera": 1})
		else:
			base.merge({"drill": 1, "rover": 1, "camera": 1})   # a lander without a camera is nobody's mission
		if d["air"] != "none":
			base["heatshield"] = 1
		if d["air"] == "thin":
			base["chute"] = 1
		if d["air"] == "thick":
			base["hull"] = 1
		else:
			gear = [["legs"], ["airbags"]]
		if bool(d["returns"]):
			base["ascent"] = 1
	else:
		base.merge({"drone": 1, "camera" if jb == "photo" else "dust": 1})
	if float(d["sun_wm2"]) > float(data.get("SHADE_ABOVE_WM2")):
		base["sunshade"] = 1
	var best: Dictionary = {}
	var tried: int = 0
	var sci: Array = ["spectro", "mag", "dust" if land or jb == "photo" else "camera"]
	for rk: String in data.get("ROCKETS"):
		if not (data.get("ROCKETS")[rk]["cap"] as Dictionary).has(id):
			continue
		for path_i: int in (d["traj"] as Array).size():
			for ant: String in ["lga", "mga", "hga"]:
				for mask: int in range(0, 8):
					for g: Array in gear:
						for rtg: int in range(0, 5):
							var b: Dictionary = base.duplicate()
							b[ant] = 1
							for i: int in 3:
								if mask & (1 << i):
									b[sci[i]] = 1
							for gid: String in g:
								b[gid] = 1
							if rtg > 0:
								b["rtg"] = rtg
							if land:
								b["battery"] = 1
							game.set("build", b)
							game.set("rocket_id", rk)
							game.set("traj_idx", path_i)
							tried += 1
							# cheapest fill-ins: arrays for power, batteries for the dark, a recorder, then fuel last
							var c: Dictionary = game.call("calc")
							if _least("battery", "battery", 1 if land else 0) < 0:
								continue
							if game.call("calc")["status"]["power"] != "ok" and _least("solar", "power") < 0:
								continue
							if _least("recorder", "data") < 0:
								continue
							c = game.call("calc")
							b["prop"] = ceili(float(c["prop_ok"]) / 100.0)
							if int(b["prop"]) > int(parts["prop"]["max"]):
								continue
							c = game.call("calc")
							if int(c["pts"]) < 2 or not _all_ok(c):
								continue
							if best.is_empty() or float(c["cost"]) < float(best["cost"]):
								best = {"cost": float(c["cost"]), "build": b.duplicate(), "rocket": rk, "traj": path_i}
	_check(not best.is_empty(), "%s: no ship is green on every lamp (%d tried)" % [who, tried])
	if best.is_empty():
		print("%-17s NO ALL-GREEN SHIP in %d tried" % [who, tried])
		return
	game.set("build", best["build"])
	game.set("rocket_id", best["rocket"])
	game.set("traj_idx", best["traj"])
	var c: Dictionary = game.call("calc")
	var b2: Dictionary = (best["build"] as Dictionary).duplicate()
	b2.erase("bus")
	print("%-17s %s (%s, %d samples). Cheapest all-green of %d tried: %s, path %d, %s" % [who, game.call("task")["name"], game.call("task")["level"], int(d["samples_goal"]), tried, best["rocket"], best["traj"], str(b2)])
	var line: String = "         cost $%dM of $%dM, mass %d of %d kg, %d of %d days. Slack above the green line:" % [roundi(c["cost"]), roundi(c["budget"]), roundi(c["mass"]), roundi(c["cap"]), roundi(c["days"]), roundi(c["limit"])]
	for k: String in c["slack"]:
		line += " %s %+d%%" % [k, roundi(float(c["slack"][k]) * 100.0)]
	print(line)
	var want: int = ceili(float(c["cost"]) / [0.62, 0.69, 0.725][int(game.get("difficulty"))] / float(game.call("diff", "budget_slack")) / 5.0) * 5
	if absi(want - int(game.call("dest")["budget"])) > 5:
		print("         SUGGEST budget %d for this task (it is %d)" % [want, int(game.call("dest")["budget"])])
	var st_bad: String = _stations_ok()
	_check(st_bad == "", "%s: cheapest ship is not all GO on the board: %s" % [who, st_bad])
	for k: String in c["use"]:
		_check(c["use"][k]["rating"] == "well", "%s: cheapest all-green ship is rated %s on %s" % [who, c["use"][k]["rating"], k])
	# little slack on the tightest of the critical resources (design: about 10%; the easy task gets more money)
	var tight: float = INF
	for k: String in d["critical"]:
		tight = minf(tight, float(c["slack"][k]))
	tight = minf(tight, float(c["slack"]["budget"]))
	_check(tight <= (0.16 if ti == 0 else 0.12), "%s: the cheapest all-green ship has %d%% slack on its tightest critical resource" % [who, roundi(tight * 100.0)])
	# the example ship, fitted to the task, must be green too
	game.call("example_build")
	c = game.call("calc")
	_check(_all_ok(c), "%s: example_build() is not all green: %s" % [who, str(c["status"])])
	st_bad = _stations_ok()
	_check(st_bad == "", "%s: example_build() is not all GO on the board: %s" % [who, st_bad])
	for k: String in c["use"]:
		_check(c["use"][k]["rating"] == "well", "%s: example_build() is rated %s on %s" % [who, c["use"][k]["rating"], k])
	if roundi(c["cost"]) != roundi(best["cost"]):
		print("         example_build() costs $%dM (cheapest is $%dM)" % [roundi(c["cost"]), roundi(best["cost"])])
	# a lazy over-built ship must be rated "over" on mass or budget, or NO-GO
	var fat: Dictionary = game.get("build").duplicate()
	fat.merge({"solar": 8, "battery": 6, "recorder": 4, "spectro": 1, "camera": 1, "mag": 1, "dust": 1, "prop": int(fat.get("prop", 0)) + 12}, true)
	game.set("build", fat)
	c = game.call("calc")
	_check(c["use"]["mass"]["rating"] == "over" or c["use"]["budget"]["rating"] == "over", "%s: an over-built ship is not rated OVER on mass or budget" % who)

# ---------------------------------------------------------------- events

func _events() -> void:
	var list: Array = events.get("LIST")
	var phases: Dictionary = {}
	var seen: Dictionary = {}
	var from_n: Dictionary = {"ship": 0, "earth": 0}
	var num: RegEx = RegEx.create_from_string("[0-9]+([.][0-9]+)?")
	_check(list.size() >= 16 and list.size() <= 20, "%d events (v6: 16 to 20)" % list.size())
	for ev: Dictionary in list:
		var id: String = ev["id"]
		_check(not seen.has(id), "event id twice: " + id)
		seen[id] = true
		phases[ev["phase"]] = true
		_check(["cruise", "site"].has(ev["phase"]), "%s: phase %s (v6: cruise or site only)" % [id, ev["phase"]])
		_check(from_n.has(ev.get("from", "")), "%s: from must be ship or earth" % id)
		from_n[ev.get("from", "ship")] = int(from_n.get(ev.get("from", "ship"), 0)) + 1
		_check(String(ev["title"]).length() <= 28, "%s: title over 28 characters" % id)
		_check(String(ev["text"]).length() <= 90, "%s: text is %d characters (90)" % [id, String(ev["text"]).length()])
		_check(String(ev["real"]).length() <= (93 if id == "storm" else 140), "%s: real is %d characters" % [id, String(ev["real"]).length()])
		_check(["planner", "engineer", "science", "comms"].has(ev["role"]), "%s: role" % id)
		var n: int = (ev["choices"] as Array).size()
		_check(n == 2, "%s: %d choices (v6: 2)" % [id, n])
		var open: bool = false
		for ch: Dictionary in ev["choices"]:
			_check(String(ch["label"]).length() <= 22, "%s: label '%s' over 22 characters" % [id, ch["label"]])
			_check(String(ch["text"]).length() <= 60, "%s: choice text is %d characters (60): %s" % [id, String(ch["text"]).length(), ch["text"]])
			_check(ch.has("cost") or ch.has("risk"), "%s: choice '%s' has neither a cost nor a risk" % [id, ch["label"]])
			var paid: bool = ch.has("needs_part")
			for k: String in events.get("PAID_KEYS"):
				if (ch.get("cost", {}) as Dictionary).has(k):
					paid = true
			if not paid:
				open = true
			_nums_ok(id, ch)
			for s: String in [String(ev["title"]), String(ev["text"]), String(ev["real"]), String(ch["label"]), String(ch["text"])]:
				for i: int in s.length():
					_check(s.unicode_at(i) < 127, "%s: not ASCII: %s" % [id, s])
		_check(open, "%s: no choice that every ship can take" % id)
	_check(phases.size() == 2, "events do not cover the cruise and the site")
	_check(from_n["ship"] >= list.size() * 0.55 and from_n["earth"] >= list.size() * 0.25, "ship %d / earth %d: v6 wants about two thirds hazards" % [from_n["ship"], from_n["earth"]])
	# every task meets enough different events for the hardest setting, with its example ship
	for did: String in data.get("DEST"):
		for ti: int in 3:
			game.call("new_mission", did)
			game.call("set_task", ti)
			game.call("example_build")
			for ph: String in ["cruise", "site"]:
				var pool: int = 0
				for ev: Dictionary in list:
					if events.call("eligible", ev, ph, did, game.call("dest"), game.get("build")):
						pool += 1
						seen[ev["id"]] = "used"
				_check(pool >= 2, "%s task %d: only %d %s events" % [did, ti, pool, ph])
			game.call("set_task", ti)
			game.set("difficulty", 2)   # the HARD counts on every task
			game.call("start_run", 7)
			var ids: Dictionary = {}
			for ev: Dictionary in game.get("run")["events"]:
				for ch: Dictionary in ev["choices"]:
					_nums_ok(ev["id"] + " (HARD)", ch)
				_check(not ids.has(ev["id"]), "%s: event %s twice in one flight" % [did, ev["id"]])
				ids[ev["id"]] = true
				_check(String(ev["real"]).length() <= 140, "%s: real is %d characters after dressing" % [ev["id"], String(ev["real"]).length()])
			_check(ids.size() == 3, "%s task %d: HARD flight has %d events, not 3" % [did, ti, ids.size()])
	game.set("difficulty", 1)
	game.call("new_mission", "moon")
	game.call("set_task", 0)
	game.call("example_build")
	game.call("start_run", 3)
	_check(not bool(game.call("dest")["returns"]) and not bool(game.call("id_has", "ascent")) and (game.get("run")["events"] as Array).size() == 1, "moon photo task (EASY): returns, capsule or events are wrong (v7: 1 event, none at the site)")
	game.set("difficulty", 1)
	for id: String in seen:
		_check(seen[id] is String, "event %s can never happen on any example ship" % id)
	# every choice of every event resolves, on a destination where it can happen
	var resolved: int = 0
	for ev: Dictionary in list:
		var found: bool = false
		for key: String in _all_tasks():
			if found:
				break
			var did: String = key.get_slice("/", 0)
			game.call("new_mission", did)
			game.call("set_task", int(key.get_slice("/", 1)))
			game.call("example_build")
			if not events.call("eligible", ev, ev["phase"], did, game.call("dest"), game.get("build")):
				continue
			found = true
			for ci: int in (ev["choices"] as Array).size():
				for seed_n: int in 4:
					game.call("start_run", seed_n)
					var run: Dictionary = game.get("run")
					run["data"] = 3.0
					run["samples"] = 3
					var e2: Dictionary = ev.duplicate(true)
					e2["done"] = false
					if e2["id"] == "storm":
						game.call("_dress_storm", e2)
					var info: Dictionary = game.call("event_choice", e2, ci)
					var res: Dictionary = game.call("resolve_event", e2, ci)
					_check(res.has("ok") and res.has("text") and res.has("effects") and res.has("chips"), "%s: result shape" % ev["id"])
					_check(String(res["text"]).length() <= 120, "%s: result text over 120" % ev["id"])
					_check(bool(info["can"]) != res.has("refused"), "%s choice %d: can/refused disagree" % [ev["id"], ci])
					resolved += 1
	game.set("difficulty", 1)
	print("events: %d, every choice resolved (%d runs)" % [list.size(), resolved])

## Every number in a choice text is one of its effects (or its odds); no effect ends the mission.
func _nums_ok(id: String, ch: Dictionary) -> void:
	var num: RegEx = RegEx.create_from_string("[0-9]+([.][0-9]+)?")
	var ok_nums: Array = []
	var risk: Dictionary = ch.get("risk", {})
	for e: Dictionary in [ch.get("cost", {}), risk.get("bad", {}), ch.get("gain", {})]:
		_check(not e.has("fail"), "%s: an effect ends the mission (v6: no fail)" % id)
		for k: String in e:
			if e[k] is float or e[k] is int:
				var v: float = absf(float(e[k]))
				ok_nums.append_array([v, roundf((1.0 - v) * 100.0)])
	if risk.has("chance"):
		ok_nums.append_array([roundf(float(risk["chance"]) * 100.0), roundf((1.0 - float(risk["chance"])) * 100.0)])
	for m: RegExMatch in num.search_all(String(ch["text"]).replace("{pct}", "")):
		_check(ok_nums.has(float(m.get_string())), "%s: '%s' says %s, which is not one of its effects" % [id, ch["text"], m.get_string()])

func _all_tasks() -> Array:
	var out: Array = []
	for did: String in data.get("DEST"):
		for ti: int in 3:
			out.append("%s/%d" % [did, ti])
	return out

# ---------------------------------------------------------------- whole flights

## Flies the current build through every phase the way the screens do. policy: -1 no event shown (old
## screens), 0 always the first open choice, 1 the last open choice, 2 random.
func _fly(seed_n: int, policy: int) -> Dictionary:
	var d: Dictionary = game.call("dest")
	game.call("start_run", seed_n)
	var run: Dictionary = game.get("run")
	game.call("phase_launch")
	if not bool(run["dead"]):
		game.call("phase_cruise", policy < 0)
		_decide("cruise", policy, seed_n)
	if not bool(run["dead"]):
		game.call("phase_arrive")
	if not bool(run["dead"]):
		var goal: int = int(d["samples_goal"])
		var gb: float = float(run["calc"]["gb_per_sample"])
		if d["kind"] == "land":
			var s: Dictionary = game.call("landing_setup")
			if not bool(run["dead"]):
				if d["air"] != "thick":
					game.call("burn", 0.14 if d["air"] == "none" else float(game.call("dv_plan")["landing"]))
				game.call("landing_result", true, minf(2.0, float(s["touch"])) if d["air"] != "thick" else float(s["vterm"]), float(run["prop"]))
			if not bool(run["dead"]):
				run["samples"] = goal
				run["data"] = goal * gb
				run["battery"] = float(run["wh"]) * 0.8
				_decide("site", policy, seed_n)
				if not bool(run["dead"]):
					game.call("surface_result", int(run["samples"]), float(run["battery"]), float(run["data"]))
		else:
			run["samples"] = goal
			run["data"] = goal * gb
			_decide("site", policy, seed_n)
			if not bool(run["dead"]):
				game.call("probe_result", int(run["samples"]), true, float(run["data"]))
		if not bool(run["dead"]):
			_decide("home", policy, seed_n)
		if not bool(run["dead"]):
			game.call("phase_home")
	game.call("finish")
	return game.get("run")

func _decide(phase: String, policy: int, seed_n: int) -> void:
	if policy < 0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_n * 31 + phase.length()
	for guard: int in 9:
		var ev: Dictionary = game.call("next_event", phase)
		if ev.is_empty():
			return
		var open: Array = []
		for i: int in (ev["choices"] as Array).size():
			if bool(game.call("event_choice", ev, i)["can"]):
				open.append(i)
		_check(not open.is_empty(), "%s: no open choice" % ev["id"])
		if open.is_empty():
			return
		var pick: int = open[0] if policy == 0 else (open[-1] if policy == 1 else open[rng.randi_range(0, open.size() - 1)])
		game.call("resolve_event", ev, pick)

func _flights() -> void:
	for diff: int in 3:
		for id: String in data.get("DEST"):
			game.call("new_mission", id)
			game.call("set_task", diff)
			game.call("example_build")
			# the example ship meets no decision (old screens): the forced hazards alone must not stop it.
			# The dice only decide an unshown solar storm, which the example's shielding stops.
			for seed_n: int in 10:
				var r0: Dictionary = _fly(seed_n, -1)
				_check(int(r0["score"]) == 100, "%s %s seed %d: example ship missed a goal with no decisions: %s" % [id, game.call("difficulty_name"), seed_n, str(r0["log"][-1]["text"])])
				_check(r0.has("report") and (r0["report"]["phases"] as Array).size() >= 4 and (r0["report"]["build"] as Dictionary).size() == 8, "%s: report is incomplete" % id)
				_check(r0["scores"]["efficiency"]["value"] == 100, "%s: example ship scores %d on efficiency" % [id, r0["scores"]["efficiency"]["value"]])
				_check(["A", "B", "C"].has(r0["report"]["grade"]) and String(r0["report"]["grade_text"]).length() <= 50 and r0["report"]["grade_rule"] != "", "%s: grade '%s' / '%s'" % [id, r0["report"]["grade"], r0["report"]["grade_text"]])
			var dead: int = 0
			var full: int = 0
			var total: float = 0.0
			var n: int = 0
			for policy: int in 3:
				for seed_n: int in 40:
					var r: Dictionary = _fly(seed_n, policy)
					n += 1
					total += float(r["total"])
					if bool(r["dead"]):
						dead += 1
					if int(r["score"]) == 100:
						full += 1
					_check((r["report"]["grade"] == "") == (int(r["score"]) < 100) and String(r["report"]["grade_text"]).length() <= 50, "%s: grade '%s' with %d%% of the goals" % [id, r["report"]["grade"], int(r["score"])])
					_check((r["decisions"] as Array).size() <= 9, "%s: too many decisions" % id)
					for k: String in ["success", "science", "efficiency", "decisions"]:
						var v: int = r["scores"][k]["value"]
						_check(v >= 0 and v <= 100 and String(r["scores"][k]["tip"]) != "", "%s: score %s = %d" % [id, k, v])
			print("flights %-6s %-8s %3d flown with decisions: %3d all goals, %2d lost, average total %d" % [game.call("difficulty_name"), id, n, full, dead, roundi(total / n)])
			_check(diff == 2 or dead == 0, "%s %s: the example ship was lost %d times (v7: only HARD may end a mission)" % [id, game.call("difficulty_name"), dead])
	game.set("difficulty", 1)
	# every task: shape and text budgets, and Game.dest() follows the chosen one
	for id: String in data.get("DEST"):
		game.call("new_mission", id)
		var list: Array = game.call("tasks")
		_check(list.size() == 3, "%s: %d tasks" % [id, list.size()])
		for i: int in list.size():
			var t: Dictionary = list[i]
			_check(int(t["diff"]) == i and t["level"] == ["EASY", "NORMAL", "HARD"][i], "%s task %d: diff or level" % [id, i])
			_check(String(t["name"]).length() <= 18 and String(t["name"]) == String(t["name"]).to_upper(), "%s task %s: name" % [id, t["name"]])
			_check(String(t["text"]).length() <= 90 and String(t["goal"]).length() <= 60, "%s task %s: text %d, goal %d characters" % [id, t["id"], String(t["text"]).length(), String(t["goal"]).length()])
			game.call("set_task", i)
			_check(int(game.call("dest")["samples_goal"]) == int(t["samples"]) and game.call("dest")["goal"] == t["goal"] and int(game.get("difficulty")) == i, "%s task %s: Game.dest() does not follow the task" % [id, t["id"]])
			game.set("difficulty", i)
			game.call("new_mission", id)
			_check(int(game.get("task_idx")) == i, "%s: new_mission() does not pick the task of difficulty %d" % [id, i])
		game.set("difficulty", 1)
	# the hazards do stop a ship that ignores them
	var traps: Array = [["mercury", "sunshade", "OVERHEATED"], ["venus", "hull", "CRUSHED"], ["venus", "heatshield", "NOT ENOUGH FUEL"],
		["mars", "heatshield", "NOT ENOUGH FUEL"], ["jupiter", "shield", "RADIATION"]]
	for t: Array in traps:
		game.call("new_mission", t[0])
		game.call("example_build")
		(game.get("build") as Dictionary).erase(t[1])
		var r: Dictionary = _fly(3, -1)
		var hit: bool = false
		for e: Dictionary in r["log"]:
			if String(e["text"]).begins_with(t[2]):
				hit = true
		_check(hit and int(r["score"]) < 100, "%s without %s: expected %s" % [t[0], t[1], t[2]])
	_under()
	# a ship with no fuel reserve cannot afford a correction burn
	game.call("new_mission", "saturn")
	game.call("example_build")
	game.get("build")["prop"] = 1
	game.call("start_run", 1)
	var ev: Dictionary = (events.call("by_id", "wheel") as Dictionary).duplicate(true)
	ev["done"] = false
	_check(not bool(game.call("event_choice", ev, 0)["can"]) or String(game.call("event_choice", ev, 0)["warn"]) != "", "a ship short of fuel can take the thruster burn without a warning")

## v7: a resource rated UNDER at launch shows in the log at every level, costs more on harder ones, and only
## HARD may end the mission. And one part more or less moves its number clearly.
func _under() -> void:
	var cases: Array = [["moon", 1, "fuel", "LOW FUEL"], ["mars", 1, "battery", "SMALL BATTERY"], ["mars", 1, "comms", "WEAK RADIO"]]
	for cs: Array in cases:
		var pts: Array = []
		for lv: int in 3:
			game.call("new_mission", cs[0])
			game.call("set_task", cs[1])
			game.call("example_build")
			game.set("difficulty", lv)
			var b: Dictionary = game.get("build")
			if cs[2] == "fuel":
				var c0: Dictionary = game.call("calc")
				b["prop"] = ceili(float(c0["prop_need"]) / 100.0)
			elif cs[2] == "battery":
				b["battery"] = 1
			elif cs[2] == "comms":
				b.erase("mga")
				b["lga"] = 1
			var c: Dictionary = game.call("calc")
			if c["use"][cs[2]]["state"] != "risk":
				print("under %s %s: could not make it UNDER (%s)" % [cs[0], cs[2], c["status"][cs[2]]])
				break
			var r: Dictionary = _fly(4, -1)
			var seen: bool = false
			for e: Dictionary in r["log"]:
				if String(e["text"]).begins_with(cs[3]) and String(e["text"]).contains("Fix: "):
					seen = true
			_check(seen, "%s %s UNDER at level %d: no log line naming it" % [cs[0], cs[2], lv])
			_check(lv == 2 or not bool(r["dead"]), "%s %s UNDER ended the mission at level %d" % [cs[0], cs[2], lv])
			pts.append(int(r["short_pts"]))
			print("under %-5s %-8s %-6s efficiency %3d, dead %s" % [cs[0], cs[2], game.call("difficulty_name"), int(r["scores"]["efficiency"]["value"]), str(r["dead"])])
		if pts.size() == 3:
			_check(pts[0] < pts[1] and pts[1] < pts[2], "%s %s UNDER: penalties %s do not grow with the level" % [cs[0], cs[2], str(pts)])
	game.set("difficulty", 1)
	# one part more: the numbers it drives move clearly (printed for the team; checked where it is the rule)
	for did: String in ["moon", "mars", "saturn"]:
		game.call("new_mission", did)
		game.call("set_task", 1)
		game.call("example_build")
		var c: Dictionary = game.call("calc")
		var line: String = "one part more %-7s" % did
		for pk: Array in [["solar", "gen"], ["rtg", "gen"], ["battery", "wh"], ["prop", "prop"], ["spectro", "pts"], ["recorder", "store"]]:
			if not bool(game.call("part_available", pk[0])):
				continue
			var e: Dictionary = pre.call("effect", pk[0], 1)
			var base: float = maxf(0.001, float(c[pk[1]]))
			var d: float = float(e.get(pk[1], 0.0))
			line += "  %s %+d%%" % [pk[0], roundi(100.0 * d / base)]
		print(line)

# ---------------------------------------------------------------- the board, the part labels, the checklist

func _preflight() -> void:
	for id: String in data.get("DEST"):
		for ti: int in 3:
			_preflight_one(id, ti)
	game.set("difficulty", 1)

func _preflight_one(id: String, ti: int) -> void:
	if true:
		game.call("new_mission", id)
		game.call("set_task", ti)
		var d: Dictionary = game.call("dest")
		# an empty ship: the checklist starts at power and names a part to add
		var steps: Array = pre.call("checklist")
		_check(steps.size() >= 5 and steps.size() <= 7 and steps[0]["id"] == "power" and not bool(steps[0]["done"]), "%s: checklist of an empty ship" % id)
		for s: Dictionary in steps:
			_check(String(s["title"]).length() <= 16 and String(s["hint"]).length() <= 60 and String(s["hint"]) != "", "%s: checklist step %s: '%s' (%d)" % [id, s["id"], s["hint"], String(s["hint"]).length()])
		var ml: String = pre.call("missing_line")
		_check(ml.begins_with("Missing: ") and ml.length() <= 50 and String(pre.call("hint_line", 0)) == "" and String(pre.call("hint_line", 2)) == String(steps[0]["hint"]), "%s: hint lines by level: '%s'" % [id, ml])
		# following the checklist's next part builds a ship that is GO
		for guard: int in 60:
			var todo: Dictionary = {}
			for s: Dictionary in pre.call("checklist"):
				if not bool(s["done"]) and todo.is_empty():
					todo = s
			if todo.is_empty():
				break
			if todo["id"] == "rocket":
				game.set("rocket_id", String(todo["parts"][0]).trim_prefix("rocket:"))
			else:
				game.call("add_part", todo["next"] if todo["next"] != "" else todo["parts"][0], 1)
		var left: String = ""
		for s: Dictionary in pre.call("checklist"):
			if not bool(s["done"]):
				left += " " + String(s["id"])
		_check(left == "", "%s: following the checklist leaves steps open:%s. Ship: %s" % [id, left, str(game.get("build"))])
		_check(String(pre.call("missing_line")) == "" or left != "", "%s: a GO ship still says '%s'" % [id, pre.call("missing_line")])
		var bad: String = ""
		for s: Dictionary in pre.call("stations"):
			if s["status"] == "bad":
				bad += " " + String(s["id"])
		_check(bad == "", "%s: the checklist ship is NO-GO at:%s. Ship: %s on %s" % [id, bad, str(game.get("build")), game.get("rocket_id")])
		# labels: required parts are exactly what the example needs; whys are short
		game.call("example_build")
		var req: PackedStringArray = PackedStringArray()
		for pid: String in data.get("PARTS"):
			var pn: Dictionary = pre.call("part_need", pid)
			_check(String(pn["why"]).length() <= 60 and String(pn["why"]) != "", "%s: part_need(%s) why is %d characters: %s" % [id, pid, String(pn["why"]).length(), pn["why"]])
			if pn["level"] == "required":
				req.append(pid)
				_check(bool(game.call("part_available", pid)), "%s: %s is REQUIRED but cannot be used here" % [id, pid])
			if pn["level"] == "not_needed":
				_check(not bool(game.call("id_has", pid)), "%s: the example ship carries %s, labelled NOT NEEDED" % [id, pid])
		print("required %-8s %-6s %s" % [id, game.call("job"), ", ".join(req)])
		# the job decides the science parts
		var want: Dictionary = {"photo": {"camera": "required", "drill": "not_needed"},
			"crew": {"crew": "required", "ascent": "required", "rover": "not_needed", "drill": "not_needed"},
			"drill": {"crew": "not_needed"}}[game.call("job")]
		for pid: String in want:
			_check(pre.call("part_need", pid)["level"] == want[pid], "%s task %d: part_need(%s) is %s, not %s" % [id, ti, pid, pre.call("part_need", pid)["level"], want[pid]])
		_check(String(game.call("task").get("job", "")) != "", "%s task %d has no job" % [id, ti])
		for s: Dictionary in pre.call("stations"):
			if float(s["frac"]) >= 0.0 and float(s["lo"]) >= 0.0:
				_check(float(s["frac"]) >= float(s["lo"]) - 0.001 and float(s["frac"]) <= float(s["hi"]) + 0.001, "%s: station %s gauge %.2f is outside its band %.2f..%.2f on the example ship" % [id, s["id"], s["frac"], s["lo"], s["hi"]])
		_check(d["kind"] == "land" or bool(game.call("part_available", "drone")), "%s: the drone must work at every ring destination" % id)
