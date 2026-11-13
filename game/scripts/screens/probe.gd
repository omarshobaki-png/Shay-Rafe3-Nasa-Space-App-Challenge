extends Control
## Saturn: fly the sampling drone from the orbiter into the rings and back.
## Art: art/probe/ (tools/blender/probe_models.py, tools/art/gen_probe.py). Effects: scripts/fx.gd.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")

const WORLD: float = 1800.0
const GSCALE: float = 2.2       # px per (m/s2): Saturn's 10.44 m/s2 pulls at 23 px/s2
const DOCK: Vector2 = Vector2(150, 118)
const LATCH: Vector2 = Vector2(150, 145)      # where the port holds the drone
const ORB: Vector2 = Vector2(152, 86)         # centre of the orbiter sprite: its port rim ends at y 127
const SHADOW_X: float = 1190.0                # Saturn's shadow lies on the rings from here on
const RING_TOP: float = 160.0
const RING_BOTTOM: float = 246.0
const ROCK_PX: Array[int] = [18, 22, 30, 36, 48, 56, 70]              # frame size of each boulder sheet
const ROCK_R: Array[float] = [6.0, 7.5, 9.5, 12.5, 16.0, 19.5, 24.0]  # hit radius: 0.92 of the drawn one
const ROCK_PICK: Array[int] = [0, 1, 2, 0, 3, 1, 4, 2, 0, 5, 1, 3, 2, 6, 0, 1, 4, 2, 3, 1]
const ROCK_FRAMES: int = 16
const BODY_HALF: float = 13.0   # the drone's hull is a lying capsule: half length and radius
const BODY_R: float = 10.0
const PLANET_Y: float = 262.0
const PLANET_PAR: float = 0.25
const FACTS: Array[String] = [
	"Saturn's rings are mostly water ice.\n(NASA)",
	"In 2017 Cassini dived 22 times through\nthe gap between rings and Saturn (NASA)",
	"Gravity here: 10.44 m/s2,\n1.06x Earth (NASA)",
]
const NEAR: Array[Vector3] = [Vector3(640, 322, 0), Vector3(1230, 128, 1), Vector3(1560, 336, 2),
	Vector3(2080, 312, 0), Vector3(2440, 118, 1), Vector3(2760, 330, 2)]

var t: float = 0.0
var state: String = "fly"
var end_t: float = 0.0
var end_at: float = 0.0
var end_kind: String = ""
var end_title: String = ""
var pos: Vector2 = Vector2(150, 145)
var vel: Vector2 = Vector2.ZERO
var fuel: float = 45.0
var fuel_max: float = 45.0
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
var msg: String = ""
var msg_t: float = 0.0
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
var auto: bool = false          # debug: a simple autopilot flies the whole run
var freeze_at: float = -1.0     # debug: stop the clock here so a screenshot catches a short effect
var puffs: Array = []
var sparks: Array = []
var floaters: Array = []
var gems: Array = []
var debris: Array = []
var wisps: Array = []
var fxr: RandomNumberGenerator = RandomNumberGenerator.new()

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

func _art(n: String) -> Texture2D:
	return Pix.img("probe/" + n)

func _ready() -> void:
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
	tex_drone = _art("drone")
	tex_flash = _art("drone_flash")
	tex_orbiter = _art("orbiter")
	tex_crystal = _art("crystal")
	tex_arrow = _art("arrow")
	tex_chevron = _art("chevron")
	tex_brackets = _art("brackets")
	tex_lamps = _art("lamps")
	tex_icons = _art("icons")
	tex_gauge = _art("gauge")
	tex_debris = _art("debris")
	for i: int in ROCK_PX.size():
		tex_rocks.append(_art("rock_%d" % i))
	for i: int in 3:
		tex_near.append(_art("near_%d" % i))
	fxr.seed = 99
	goal = int(Game.dest()["samples_goal"])
	if Game.tech.has("armor"):
		hp_max = 4
	hp = hp_max
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(p["gb"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2017
	for i: int in ROCK_PICK.size():
		var m: int = ROCK_PICK[i]
		var r: float = ROCK_R[m]
		var rp: Vector2 = Vector2.ZERO
		for tries: int in 40:
			rp = Vector2(rng.randf_range(380.0 + m * 40.0, WORLD - 60.0), rng.randf_range(172, 234))
			if _free_of_rocks(rp, r + 34.0, r + 6.0):
				break
		var spin: float = rng.randf_range(3.0, 6.5) * (0.55 if m >= 4 else 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		rocks.append({"p": rp, "r": r, "m": m, "ph": rng.randf() * TAU, "spin": spin, "f0": rng.randi_range(0, 15)})
	for i: int in 34:
		var ip: Vector2 = Vector2.ZERO
		for tries: int in 40:
			ip = Vector2(rng.randf_range(320, WORLD - 60), rng.randf_range(176, 230))
			if _free_of_rocks(ip, 28.0, 12.0):
				break
		ice.append({"p": ip, "taken": false, "v": rng.randi_range(0, 2), "ph": rng.randf() * TAU})
	for i: int in 16:
		wisps.append({"x": rng.randf() * 1004.0, "d": rng.randf_range(9.0, 84.0), "k": rng.randi_range(0, 7)})
	if not Game.id_has("drone"):
		state = "nodrone"
		end_t = 4.0
		end_title = "NO DRONE ON BOARD"
		_say("Nothing can go into the rings.")
	var defs: Array = [["<", 8, "l"], [">", 52, "r"], ["THRUST", 548, "u"]]
	for d: Array in defs:
		var b: Button = Button.new()
		b.text = d[0]
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.7)
		b.visible = DisplayServer.is_touchscreen_available()  # the keys do it on a desktop
		add_child(b)
		b.position = Vector2(float(d[1]), 318)
		b.size = Vector2(84 if d[2] == "u" else 40, 34)
		var key: String = d[2]
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold.erase(key))
	jobs = Game.multi()
	driver = Net.is_host()
	if jobs:
		auto = Game.cpu("science")   # offline testing: the computer flies the drone
		dl_job = Game.job("comms")
		Net.received.connect(_on_net)

func _free_of_rocks(p: Vector2, mx: float, my: float) -> bool:
	for q: Dictionary in rocks:
		var qp: Vector2 = q["p"]
		if absf(p.x - qp.x) < float(q["r"]) + mx and absf(p.y - qp.y) < float(q["r"]) + my:
			return false
	return true

func _say(s: String) -> void:
	msg = s
	msg_t = 3.0

func _end(ok_dock: bool, title: String, text: String, kind: String) -> void:
	if state != "fly":
		return
	state = "done"
	docked = ok_dock
	end_kind = kind
	end_title = title
	end_at = t
	end_t = t + 3.0
	_say(text)
	thrusting = false
	steer = 0
	warn.clear()
	Audio.loop("thrust", false)
	if ok_dock:
		Audio.play("dock", -2.0)
	else:
		Audio.play("explosion", -2.0)
		trauma = 1.0
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
	if freeze_at >= 0.0 and t >= freeze_at:
		return
	t += delta
	msg_t -= delta
	invuln -= delta
	_tick_fx(delta)
	if not driver:
		# another player's game: send this player's controls, draw what the host sends
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
		elif state == "done" and end_kind == "burn":
			vel = vel * (1.0 - minf(1.0, 2.0 * delta)) + Vector2(0, 30.0) * delta
			pos += vel * delta
		if t > end_t:
			if docked and dl_job and not dl_done:
				state = "downlink"   # the Comms officer picks what to send home first
				dl_t = 0.0
				_send_state(1.0)
				return
			set_physics_process(false)
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
	var g: float = float(Game.dest()["gravity"]) * GSCALE
	var keys: Dictionary = _fly_keys()
	var up: bool = bool(keys.get("up", false))
	var lft: bool = bool(keys.get("left", false))
	var rgt: bool = bool(keys.get("right", false))
	thrusting = up and fuel > 0.0
	Audio.loop("thrust", thrusting, -9.0)
	var acc: Vector2 = Vector2(0, g)
	steer = 0
	var thr: Dictionary = Data.DRONE_THROTTLE[throttle]
	if thrusting:
		acc.y -= g * 2.2 * float(thr["thrust"])
		fuel -= delta * float(thr["burn"])
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
	# ice samples
	for s: Dictionary in ice:
		var sp: Vector2 = s["p"]
		if not s["taken"] and _drone_dist(sp) < 20.0:
			s["taken"] = true
			got += 1
			got_kinds.append(int(s["v"]))
			Audio.play("pickup", -3.0, 1.0 + got * 0.06)
			data += gb_sample
			_burst(sp, 8, Color("b8f4ff"), 70.0)
			floaters.append({"p": sp, "age": 0.0, "s": "+1 ICE"})
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
			hp -= 1
			Audio.play("hit")
			invuln = 1.0
			vel = (pos - rp).normalized() * 80.0
			trauma = minf(1.0, trauma + 0.7)
			flash_t = 0.12
			hull_flash = 0.5
			var hit: Vector2 = rp + (pos - rp).normalized() * rr
			_burst(hit, 10, Color("ffe9a0"), 110.0)
			for k: int in 3:
				_puff(hit, Vector2(fxr.randf_range(-20, 20), fxr.randf_range(-20, 20)), 0.7, 1, Color(0.6, 0.62, 0.7))
			if hp <= 0:
				_end(false, "DRONE SMASHED", "by a ring boulder.", "smash")
			else:
				floaters.append({"p": pos - Vector2(0, 26), "age": 0.0, "s": "HULL %d/%d" % [hp, hp_max]})
			break
		# collision course: where will the two be at their closest in the next second?
		var d: Vector2 = rp - pos
		if invuln <= 0.0 and d.length() < 170.0:
			var v: Vector2 = Vector2(cos(t * 0.6 + float(r["ph"])) * 8.4, 0) - vel
			var vv: float = v.length_squared()
			if vv > 400.0:
				var tca: float = -d.dot(v) / vv
				if tca > 0.0 and (d + v * minf(tca, 1.1)).length() < rr + 16.0:
					warn.append(i)
	warn_beep -= delta
	if not warn.is_empty() and warn_beep <= 0.0 and state == "fly":
		warn_beep = 0.35
		Audio.play("blip", -10.0, 1.5)
	if pos.y > 330.0:
		_end(false, "DRONE LOST", "in Saturn's atmosphere. Crushed by the pressure.", "burn")
	# docking
	if pos.distance_to(DOCK + Vector2(0, 46)) < 22.0 and vel.length() < 60.0 and t > 3.0:
		_end(true, "DOCKED!", "Samples are safe on the orbiter.", "dock")
	_spawn_trails(delta)

# ---------------------------------------------------------------- multiplayer jobs

## The Scientist's flight keys: this player's own (and the autopilot's) when they hold the role, else
## the last keys that player sent.
func _fly_keys() -> Dictionary:
	if jobs and not Net.owns("science") and not auto:
		return remote.get("science", {})
	return {
		"up": hold.has("u") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE),
		"left": hold.has("l") or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A),
		"right": hold.has("r") or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D),
	}

func _input(ev: InputEvent) -> void:
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
	for v: Variant in got_kinds.slice(0, 8):
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
		Net.send("input", {"role": "science", "keys": _fly_keys()})
	if Net.owns("engineer") and remote.has("throttle"):
		Net.send("input", {"role": "engineer", "keys": {"throttle": int(remote["throttle"])}})
	if Net.owns("comms") and state == "downlink" and (remote.has("dl") or remote.has("send")):
		Net.send("input", {"role": "comms", "keys": {"pick": remote.get("dl", dl_sel), "send": bool(remote.get("send", false))}})

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
	Net.send("state", {"s": state, "t": t, "px": pos.x, "py": pos.y, "vx": vel.x, "vy": vel.y, "fuel": fuel, "hp": hp,
		"got": got, "gk": got_kinds, "ice": taken, "inv": invuln, "thr": thrusting, "steer": steer, "th": throttle,
		"dk": docked, "lt": latched, "sent": sent, "ek": end_kind, "et": end_title, "msg": msg, "dl": dl_sel, "dlt": dl_t})

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
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
	elif kind == "state" and not driver:
		_apply_state(d)

## Not the host: take the host's simulation, with the sounds of a pickup, a hit or the end.
func _apply_state(d: Dictionary) -> void:
	var ns: String = String(d.get("s", state))
	if state == "fly" and ns != "fly":
		_end(bool(d.get("dk", false)), String(d.get("et", "")), String(d.get("msg", "")), String(d.get("ek", "")))
	state = ns
	t = float(d.get("t", t))
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
		floaters.append({"p": pos, "age": 0.0, "s": "+1 ICE"})
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

## Thruster gas, the wake of ice dust inside the ring, smoke from a hurt hull, haze in the atmosphere.
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
	return p + Vector2(sin(t * 0.6 + float(r["ph"])) * 14.0, 0)

func _process(delta: float) -> void:
	var want: float = clampf(pos.x - 320.0 + clampf(vel.x * 0.45, -70.0, 70.0), 0.0, WORLD - 640.0)
	cam_x = lerpf(cam_x, want, 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _cam() -> float:
	return floorf(clampf(cam_x, 0.0, WORLD - 640.0))

func _slot_pos(i: int) -> Vector2:
	return Vector2(130 + hp_max * 11 + i * 10, 16)

## One cell of a sprite sheet, centred on `center`.
func _cell(tex: Texture2D, center: Vector2, cx: int, cy: int, size: Vector2, mod: Color = Color.WHITE) -> void:
	draw_texture_rect_region(tex, Rect2((center - size / 2.0).floor(), size), Rect2(Vector2(cx, cy) * size, size), mod)

## Height of Saturn's limb on screen at planet-image column px (same arc as tools/art/gen_probe.py).
func _limb(px: float) -> float:
	return PLANET_Y + 14.0 + 4614.0 - sqrt(4614.0 * 4614.0 - (px - 470.0) * (px - 470.0))

## How deep in Saturn's shadow a world x is: 0 lit .. 1 dark.
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
	_draw_hud(cam)

func _draw_sky(cam: float) -> void:
	Pix.tiled(self, tex_space, -4, cam * 0.05 + t * 1.0)
	Pix.stars(self, t, Vector2(640, 250), 46, 12, Vector2(-cam * 0.06, 0))
	var sun: Vector2 = Vector2(50.0 - cam * 0.02, 62.0).floor()
	Fx.glow(self, sun, 24.0, Color(1.0, 0.95, 0.8, 0.18), true)
	Fx.sun(self, sun, 0, Color("fff6e0"), t)
	var ti: Vector2 = Vector2(486.0 - cam * 0.03, 88.0).floor()
	Fx.glow(self, ti, 12.0, Color(0.95, 0.6, 0.25, 0.25), true)
	Pix.sprite(self, tex_titan, ti)
	Pix.text(self, ti + Vector2(12, 4), "TITAN", 10, Color(UI.DIM, 0.6))
	var en: Vector2 = Vector2(574.0 - cam * 0.04, 112.0).floor()
	_cell(tex_enc, en, int(t * 3.0) % 2, 0, Vector2(11, 14))
	Pix.text(self, en + Vector2(8, 1), "ENCELADUS", 10, Color(UI.DIM, 0.6))
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
			Fx.sparkle(self, gp, age, Color("c8dcf0"))
	Pix.tiled(self, tex_back, 150, cam * 0.6)
	Pix.tiled(self, tex_mid, 158, cam)
	draw_texture(tex_shadow, Vector2(SHADOW_X - cam, 136))

func _draw_ice(cam: float) -> void:
	for sd: Dictionary in ice:
		if sd["taken"]:
			continue
		var p: Vector2 = sd["p"]
		var ph: float = float(sd["ph"])
		var sp: Vector2 = Vector2(p.x - cam, p.y + sin(t * 2.2 + ph) * 2.0).floor()
		if sp.x < -20 or sp.x > 660:
			continue
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + ph)
		Fx.glow(self, sp, 10.0 + 3.0 * pulse, Color(0.3, 0.85, 1.0, 0.3 + 0.25 * pulse + 0.2 * _shade(p.x)), true)
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
	var gone: bool = state == "nodrone" or (end_kind == "smash" and t - end_at > 0.08) or (end_kind == "burn" and t - end_at > 0.7)
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
			_cell(tex_drone, dp, dmg, row, Vector2(66, 48), Color(1.0 - k, 1.0 - k, 1.0 - k * 0.4))
			if int(t * 1.5) % 2 == 0 and dmg < 2:
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
		var txt: String = e["s"]
		Pix.text_c(self, fp.x - cam, fp.y - 14.0 - age * 22.0, txt, 10, Color(UI.CYAN if txt.begins_with("+") else UI.RED, clampf(2.0 - age * 2.2, 0.0, 1.0)))
	if state == "fly" and pos.y > 285.0 and int(t * 5.0) % 2 == 0:
		Pix.text_c(self, dp.x, dp.y - 32.0, "PULL UP", 10, UI.RED)
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

func _draw_hud(cam: float) -> void:
	# cockpit strip: fuel cells, hull shields, sample slots, gravity
	var gx: float = 147.0 + hp_max * 11.0 + goal * 10.0    # groove after the sample slots (room for "+12")
	var w: float = gx + 81.0
	Pix.panel(self, Rect2(6, 6, w, 20))
	_cell(tex_icons, Vector2(17, 16), 0, 0, Vector2(11, 11))
	var cells: int = ceili(20.0 * fuel / fuel_max)
	var low: bool = fuel < fuel_max * 0.25
	for i: int in 20:
		var col: int = 2 if i >= cells or (low and int(t * 4.0) % 2 == 0) else (1 if low else 0)
		draw_texture_rect_region(tex_gauge, Rect2(26 + i * 4, 13, 4, 6), Rect2(col * 4, 0, 4, 6))
	_groove(111)
	for i: int in hp_max:
		var lost_now: bool = i == hp and hull_flash > 0.0 and int(t * 12.0) % 2 == 0
		_cell(tex_icons, Vector2(122 + i * 11, 16), 1 if i < hp else 2, 0, Vector2(11, 11), Color(1.0, 0.4, 0.4) if lost_now else Color.WHITE)
	_groove(119 + hp_max * 11)
	for i: int in goal:
		var just: bool = slot_flash > 0.0 and i == mini(got, goal) - 1
		var filled: bool = i < got - (1 if _gem_flying() else 0)
		_cell(tex_icons, _slot_pos(i), 3 if filled else 4, 0, Vector2(11, 11))
		if just:
			Fx.sparkle(self, _slot_pos(i), 1.0 - slot_flash / 0.25, Color.WHITE)
	if got > goal:
		Pix.text(self, _slot_pos(goal) + Vector2(-4, 4), "+%d" % (got - goal), 10, UI.CYAN)
	_groove(gx)
	_cell(tex_icons, Vector2(gx + 11.0, 16), 6, 0, Vector2(11, 11))
	Pix.text(self, Vector2(gx + 19.0, 20), "%.2f m/s2" % float(Game.dest()["gravity"]), 10, UI.TEXT)
	# samples on their way to a slot or up into the orbiter
	for e: Dictionary in gems:
		var k: float = float(e["age"]) / float(e["life"])
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var gp: Vector2 = a.lerp(b, k * k) + Vector2(0, -24.0 * sin(k * PI))
		Fx.glow(self, gp, 8.0, Color(0.3, 0.85, 1.0, 0.4), true)
		_cell(tex_icons, gp, 3, 0, Vector2(11, 11))
	# a NASA fact, bottom left (the keys sit bottom right, as on the landing and surface screens)
	var fact: String = FACTS[int(t / 9.0) % FACTS.size()]
	var fw: float = 0.0
	for line: String in fact.split("\n"):
		fw = maxf(fw, Pix.text_w(line, 10))
	Pix.panel(self, Rect2(6, 326, fw + 12.0, 28))
	var fy: float = 337.0
	for line: String in fact.split("\n"):
		Pix.text(self, Vector2(12, fy), line, 10, UI.TEXT if fy < 340.0 else UI.DIM)
		fy += 10.0
	# the dock, when it is off screen
	var dk: float = DOCK.x - cam
	if state == "fly" and dk < -12.0:
		var bob: float = floorf(absf(sin(t * (6.0 if got >= goal else 3.0))) * 4.0)
		draw_texture_rect_region(tex_arrow, Rect2(8.0 - bob, 150, 19, 15), Rect2(19, 0, 19, 15), UI.GREEN)
		Pix.text(self, Vector2(8, 176), "DOCK", 10, UI.GREEN)
	# what to do
	if state == "fly":
		var low_fuel: bool = fuel < fuel_max * 0.3 and dk < -12.0
		if got == 0 and t < 9.0:
			_hint(400.0 if cam < 80.0 else 320.0, "FLY RIGHT: GRAB THE GLOWING ICE", 1, UI.YELLOW)
		elif low_fuel and int(t * 3.0) % 3 != 0:
			_hint(320.0, "LOW FUEL: FLY BACK AND DOCK", -1, UI.RED)
		elif goal_t >= 0.0 and t - goal_t < 7.0 and not low_fuel:
			_hint(320.0, "FLY BACK AND DOCK", -1, UI.GREEN)
		if t < 9.0 and get_child(0) is Button and not (get_child(0) as Button).visible and (not jobs or Net.owns("science")):
			var kw: float = 19.0 + 4.0 + Pix.text_w("THRUST", 10) + 10.0 + 15.0 + 17.0 + Pix.text_w("STEER", 10) + 12.0
			Pix.panel(self, Rect2(634.0 - kw, 334, kw, 20))
			var kx: float = 640.0 - kw
			kx += Pix.key_hint(self, Vector2(kx, 337), "UP", "THRUST") + 10.0
			kx += Pix.keycap(self, Vector2(kx, 337), "<") + 2.0
			Pix.key_hint(self, Vector2(kx, 337), ">", "STEER")
	if jobs:
		_draw_jobs()
	if state == "downlink":
		_draw_downlink()
	# end banner
	if state != "fly":
		var tw: float = maxf(Pix.text_w(end_title, 20), Pix.text_w(msg, 10)) + 28.0
		Pix.panel(self, Rect2(floorf(320.0 - tw / 2.0), 58, tw, 46), UI.GREEN if docked else UI.RED)
		Pix.text_c(self, 320, 82, end_title, 20, UI.GREEN if docked else UI.RED)
		Pix.text_c(self, 320, 96, msg, 10, UI.TEXT)

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
	var ax: float = cx + tw / 2.0 + 8.0 if dir > 0 else cx - tw / 2.0 - 27.0
	draw_texture_rect_region(tex_arrow, Rect2(floorf(ax + nudge), 47, 19, 15), Rect2(0 if dir > 0 else 19, 0, 19, 15), c)

# ---------------------------------------------------------------- screenshot set-ups (harmless in the game)

func _debug_at(p: Vector2, v: Vector2, samples: int) -> void:
	pos = p
	vel = v
	got = samples
	t = 12.0
	if got >= goal:
		goal_t = t - 1.0
	for i: int in mini(samples, ice.size()):
		ice[i * 3 % ice.size()]["taken"] = true
	cam_x = clampf(pos.x - 320.0 + clampf(vel.x * 0.45, -70.0, 70.0), 0.0, WORLD - 640.0)

## A boulder of sheet `m` or bigger with nothing else near the point `off` away from it.
func _debug_rock(m: int, off: Vector2) -> int:
	for i: int in rocks.size():
		var p: Vector2 = _rock_pos(rocks[i]) + off
		var clear: bool = int(rocks[i]["m"]) >= m
		for k: int in rocks.size():
			if k != i and p.distance_to(_rock_pos(rocks[k])) < float(rocks[k]["r"]) + 70.0:
				clear = false
		if clear:
			return i
	return 0

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

## Multiplayer: the Comms officer's downlink choice after docking (run with -- roles=comms).
func debug_downlink() -> void:
	_debug_at(LATCH, Vector2.ZERO, goal)
	got_kinds = [0, 1, 2, 1, 0]
	docked = true
	latched = true
	end_title = "DOCKED!"
	msg = "Samples are safe on the orbiter."
	state = "downlink"
	dl_sel = [1, 3]

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

## Deep in Saturn's shadow at the far end of the ring.
func debug_shadow() -> void:
	_debug_at(Vector2(1480, 150), Vector2(60, 10), 3)
	hold["u"] = true
	freeze_at = t + 0.4

## Fly the whole run by itself (out along the ring, back when the slots are full, dock): a smoke test.
func debug_auto() -> void:
	auto = true

func _autopilot() -> void:
	var home: bool = got >= goal
	var want_y: float = 164.0 if home else 196.0
	var want_vx: float = clampf((DOCK.x - pos.x) * 0.8, -110.0, 110.0) if home else 90.0
	hold.clear()
	if pos.y + vel.y * 0.45 > want_y:
		hold["u"] = true
	if vel.x < want_vx - 6.0:
		hold["r"] = true
	elif vel.x > want_vx + 6.0:
		hold["l"] = true
