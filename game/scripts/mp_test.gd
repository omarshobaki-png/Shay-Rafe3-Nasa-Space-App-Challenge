extends Node
const EventCard = preload("res://scripts/event_card.gd")
## Dev only: plays a 2-player online Mars mission by itself against a relay and prints what each side sees.
## Not used by the game. main.gd adds it when the command line has mptest=...
##   godot --path game -- server=ws://127.0.0.1:8080 mptest=host          (prints "MPTEST host code=ABCD")
##   godot --path game -- server=ws://127.0.0.1:8080 mptest=join:ABCD
## Host: planner + engineer + comms (the free roles), flies the landing with the debug autopilot.
## Joiner: scientist. Adds a magnetometer through the host, is refused a power part, sends a REQUEST,
## signs, opens the parachute and lowers the legs.

var me: String = ""
var code: String = ""
var step: String = "lobby"
var t: float = 0.0
var on_screen: float = 0.0
var screen: String = ""
var did: Dictionary = {}
var dest: String = "mars"     # mpdest=saturn: the joiner is the Comms officer and picks the downlink
var expected_part: int = 0
var host_report: Dictionary = {}
var report_ack: bool = false
var remote_choices: int = 0
var failed: bool = false

func _ring() -> bool:
	return String(Data.DEST[dest]["kind"]) == "ring"

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		_say("FAIL " + message)
		get_tree().quit(1)
	return ok

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("mptest="):
			var v: String = a.trim_prefix("mptest=")
			me = "host" if v == "host" else "join"
			code = v.trim_prefix("join:")
		elif a.begins_with("mpdest="):
			dest = a.trim_prefix("mpdest=")
	Engine.time_scale = 2.0
	Net.lobby_changed.connect(_on_lobby)
	Net.disconnected.connect(func(r: String) -> void: _say("DISCONNECTED " + r))
	Net.received.connect(_on_msg)
	if me == "host":
		Net.host("HOST P")
	else:
		Net.join(code, "JOIN P")

func _say(s: String) -> void:
	print("MPTEST %s %s" % [me, s])

func _once(key: String) -> bool:
	if did.has(key):
		return false
	did[key] = true
	return true

func _on_lobby(l: Dictionary) -> void:
	if me == "host" and _once("code"):
		_say("code=" + String(l.get("code", "")))
	if me == "join" and _once("pick"):
		Net.pick_role("comms" if _ring() else "science")
		Net.set_ready(true)
	var players: Array = l.get("players", [])
	if me == "host" and players.size() >= 2 and _once("ready"):
		Net.set_ready(true)

func _on_msg(kind: String, d: Dictionary, from_id: int) -> void:
	if kind == "mptest_report" and me == "join" and Game.sender_is_host(from_id):
		host_report = d["run"]
	elif kind == "mptest_ack" and me == "host":
		report_ack = bool(d.get("ok", false))
	if kind in ["input", "state", "build", "run"]:
		return
	_say("got %s from %d: %s" % [kind, from_id, JSON.stringify(d).left(120)])

func _all_ready() -> bool:
	var players: Array = Net.lobby().get("players", [])
	for p: Variant in players:
		if not bool((p as Dictionary).get("ready", false)):
			return false
	return players.size() >= 2

func _process(delta: float) -> void:
	if failed or step == "done":
		return
	t += delta
	if t > 240.0:
		_say("FAIL timeout on %s" % screen)
		get_tree().quit(1)
		return
	var cur: Node = Game.main.current if Game.main != null else null
	if cur == null:
		return
	var sname: String = String(cur.get_script().resource_path.get_file().get_basename())
	if sname != screen:
		screen = sname
		on_screen = 0.0
		_say("screen %s  roles=%s  host=%s  dest=%s" % [screen, str(Net.my_roles()), str(Net.is_host()), Game.dest_id])
	on_screen += delta
	_event_step()
	match screen:
		"menu":
			if me == "host" and _all_ready() and _once("start"):
				cur.call("_pick", dest)
				cur.call("_pick_task", 0)
				Net.start()
		"builder":
			_builder(cur)
		"launch":
			if me == "host" and _once("launch_auto"):
				cur.call("debug_autopilot")
		"flight":
			if me == "host":
				cur.set("auto", true)
				if _ring() and _once("remote_event"):
					cur.call("_open_card", Game.event_by_id("receiver"))
		"landing":
			if me == "host" and _once("auto"):
				cur.call("debug_autopilot")
			if me == "join" and on_screen > 1.5 and _once("chute"):
				cur.set("chute_req", true)
				cur.set("gear_req", true)
				_say("pressed C and G (chute_job=%s gear_job=%s)" % [str(cur.get("chute_job")), str(cur.get("gear_job"))])
			if on_screen > 0.5 and int(on_screen * 2.0) % 6 == 0 and _once("l%d" % int(on_screen)):
				_say("landing state=%s alt=%.0f vy=%.1f chute=%s gear=%.1f" % [cur.get("state"), cur.get("alt"), cur.get("vy"), str(cur.get("chute_open")), cur.get("gear")])
		"probe":
			if me == "host" and _once("pauto"):
				cur.call("debug_auto")
			if on_screen > 0.5 and int(on_screen) % 4 == 0 and _once("p%d" % int(on_screen)):
				_say("probe state=%s got=%d hp=%d fuel=%.1f throttle=%d pos=(%.0f,%.0f)" % [cur.get("state"), cur.get("got"), cur.get("hp"), cur.get("fuel"), cur.get("throttle"), (cur.get("pos") as Vector2).x, (cur.get("pos") as Vector2).y])
			if me == "join" and cur.get("state") == "downlink" and _once("dl"):
				cur.call("_dl_toggle", 0)
				cur.call("_dl_toggle", 1)
				_say("joiner picked items 0 and 1 of %d" % (cur.call("_dl_items") as Array).size())
			if me == "join" and did.has("dl") and (cur.get("dl_sel") as Array).size() >= 2 and _once("dlsend"):
				_say("host confirmed the pick %s, pressing SEND" % str(cur.get("dl_sel")))
				cur.call("_dl_press_send")
		"surface":
			if me == "host" and _once("surf"):
				cur.call("debug_auto")
				cur.call("_open_event", Game.event_by_id("odd_rock"))   # v6: a Scientist site event for land worlds
			if me == "join" and on_screen > 1.0 and _once("watch"):
				_say("surface watching: driver=%s rx=%.0f" % [str(cur.get("driver")), cur.get("rx")])
		"report":
			_report_step()

func _builder(cur: Node) -> void:
	if me == "host":
		if _once("example"):
			Game.example_build()   # the host's game is the truth: this goes out as a "build" snapshot
			expected_part = maxi(1, Game.count(_part()))
			Game.build[_part()] = expected_part - 1
			if expected_part == 1:
				Game.build.erase(_part())
			_say("host loaded the example ship")
		var team: Node = cur.get("team")
		var q: Array = team.get("queue")
		if not q.is_empty():
			team.call("_answer", q[0], true)
			_say("host accepted a request")
		if Game.count(_part()) == expected_part and _once("sawmag"):
			_say("host build has mag=%d (the joiner's edit applied)" % Game.count(_part()))
			cur.call("_toggle_sign")
		if Game.all_signed() and _once("poll"):
			_say("all 4 signed, starting the poll")
			cur.call("_start_poll")
		var poll: Dictionary = cur.get("poll")
		if String(poll.get("phase", "")) == "nogo" and _once("anyway"):
			_say("poll said NO-GO, launching anyway")
			cur.call("_launch")
	else:
		if on_screen > 2.0 and _once("edit"):
			expected_part = Game.count(_part()) + 1
			_say("joiner build before: mag=%d solar=%d" % [Game.count(_part()), Game.count("solar")])
			cur.call("_take", "solar")      # engineer's part: must be refused
			if not _check(String(cur.get("hand")) == "", "role lock allowed solar"):
				return
			_say("joiner tried solar: hand='%s' (empty = refused)" % String(cur.get("hand")))
			cur.call("_attach", _part(), 1)   # own part: goes to the host as an "edit"
			var team: Node = cur.get("team")
			team.set("req_to", "engineer")
			team.call("_send_request", 0)
		if did.has("edit") and Game.count(_part()) == expected_part and _once("sawmag"):
			_say("joiner build now has mag=%d (from the host's snapshot)" % Game.count(_part()))
			cur.call("_toggle_sign")
		if not (cur.get("poll") as Dictionary).is_empty() and _once("pollseen"):
			_say("joiner sees the launch poll")

## The joiner's own part to add: the Scientist's magnetometer, or the Comms officer's recorder at Saturn.
func _part() -> String:
	return "recorder" if _ring() else "mag"

## Exercise the real EventCard network path: the owner chooses, then only the host closes.
func _event_step() -> void:
	if not EventCard.is_open():
		return
	var card: Control = EventCard._current
	var ev: Dictionary = card.get("ev")
	if float(card.get("age")) < EventCard.INPUT_DELAY:
		return
	if (card.get("result") as Dictionary).is_empty():
		if not Net.owns(String(ev["role"])):
			return
		var key: String = "choice:" + str(card.get_instance_id())
		if not _once(key):
			return
		var infos: Array = card.get("infos")
		for i: int in infos.size():
			if bool((infos[i] as Dictionary)["can"]):
				card.call("_choose", i)
				if me == "join":
					remote_choices += 1
				_say("event choice owner=%s id=%s choice=%d" % [me, ev["id"], i])
				break
	elif me == "host":
		card.call("_continue")

func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _canonical(value[key])
		return out
	if value is Array:
		var out: Array = []
		for entry: Variant in value:
			out.append(_canonical(entry))
		return out
	if value is int or value is float:
		return float(value)
	return value

func _report_step() -> void:
	if on_screen <= 2.0:
		return
	if _once("report_check"):
		var obj: Dictionary = Game.run.get("obj", {})
		if not _check(bool(obj.get("launch", false)) and bool(obj.get("arrive", false)), "mission failed before arrival"):
			return
		if not _check(bool(obj.get("dock" if _ring() else "land", false)), "landing or docking failed"):
			return
		if not _check(Game.run.has("team_sync") and (Game.run.get("decisions", []) as Array).size() > 0, "missing team score or events"):
			return
		if me == "host":
			Net.send("mptest_report", {"run": Game.run})
	if me == "join" and not host_report.is_empty():
		if not _check(remote_choices > 0, "no remote event choice exercised"):
			return
		var mine: Dictionary = _canonical(Game.run)
		var theirs: Dictionary = _canonical(host_report)
		if JSON.stringify(mine) != JSON.stringify(theirs):
			var keys: Array = []
			for k: Variant in mine.keys() + theirs.keys():
				if not keys.has(k) and JSON.stringify(mine.get(k)) != JSON.stringify(theirs.get(k)):
					keys.append(k)
			for k: Variant in keys:
				_say("run[%s] join=%s host=%s" % [k, JSON.stringify(mine.get(k)).left(160), JSON.stringify(theirs.get(k)).left(160)])
		if not _check(JSON.stringify(mine) == JSON.stringify(theirs), "host/client Game.run differs"):
			return
		Net.send("mptest_ack", {"ok": true})
		_complete()
	elif me == "host" and report_ack:
		_complete()

func _complete() -> void:
	step = "done"
	_say("DONE score=%s reward=%s team_sync=%s land=%s dock=%s decisions=%d; identical Game.run, role lock, request, signatures and remote events passed" % [Game.run.get("score"), Game.run.get("reward"), Game.run.get("team_sync"), Game.run["obj"].get("land"), Game.run["obj"].get("dock"), (Game.run["decisions"] as Array).size()])
	get_tree().create_timer(0.5).timeout.connect(func() -> void: get_tree().quit(0))
