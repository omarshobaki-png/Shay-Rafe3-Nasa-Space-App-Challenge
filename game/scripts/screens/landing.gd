extends Control
## Landing minigame. Real gravity, rocket-equation fuel use, touchdown speed limits.
## The HUD teaches the landing: a BRAKE light computed from the physics, the burn start marked on
## the altitude tape, a speed gauge with a green safe zone and a drift arrow. The player still flies.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const GROUND_Y: float = 312.0
const LX: float = 320.0      # the lander stays in the middle; the ground slides under it
const HX: float = 0.5        # px per metre sideways
const SIDE_ACC: float = 2.5  # m/s2 from the side thrusters (game rule)
const REACT: float = 0.6     # s of pilot reaction time built into the BRAKE light (game rule)
const ZOOM: float = 0.6      # altitude -> screen exponent: the last metres get more of the screen
const TAPE_TOP: float = 62.0
const TAPE_H: float = 236.0
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]
const CRATER_W: Array[int] = [18, 26, 40, 64, 98]

var state: String = "fly"
var t: float = 0.0
var end_t: float = 0.0
var g: float = 1.62
var alt: float = 600.0
var alt0: float = 600.0
var vy: float = 20.0
var vx: float = 0.0
var x: float = 0.0
var prop: float = 0.0
var prop0: float = 1.0
var mass: float = 1000.0
var touch: float = 3.0
var thrust_acc: float = 6.0
var thrusting: bool = false
var side: float = 0.0
var hold_up: bool = false
var hold_l: bool = false
var hold_r: bool = false
var moon: bool = true
# the braking cue
var cue: String = "fall"      # fall | soon | brake | release | safe | empty
var brake: bool = false       # the BRAKE light is latched on until the speed is down
var burn_alt: float = -1.0    # where the next burn has to start if you just keep falling
var burn_in: float = 99.0     # seconds until then
var drift_warn: bool = false
var last_count: int = 9
var burns: int = 0
var vmax: float = 40.0
# debug autopilot: obeys the lights and nothing else
var auto: bool = false
var auto_lag: float = 0.0
var auto_want: bool = false
var auto_since: float = -9.0
var auto_up: bool = false
# drawing
var tex: Texture2D = null
var tex_earth: Texture2D = null
var tex_halo: Texture2D = null
var tex_dist: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_sky: Texture2D = null
var tex_cloud: Array[Texture2D] = []
var tex_phobos: Texture2D = null
var tex_devil: Texture2D = null
var tex_sheet: Texture2D = null
var tex_chute: Texture2D = null
var tex_shield: Texture2D = null
var tex_scorch: Texture2D = null
var tex_beacon: Array[Texture2D] = []
var tex_marker: Texture2D = null
var tex_arrow: Texture2D = null
var tex_icon: Dictionary = {}
var tex_pebble: Array[Texture2D] = []
var tex_crater: Array[Texture2D] = []
var decor: Array = []
var dust: Array = []
var smoke: Array = []
var debris: Array = []
var boom_t: float = -99.0
var land_t: float = -99.0
var has_chute: bool = false
var has_shield: bool = false
var shake: float = 0.0
var shake_off: Vector2 = Vector2.ZERO
var floor_mat: ShaderMaterial = null
var floor_rect: ColorRect = null
var front: Control = null
var msg: String = ""
var msg_col: Color = Color.WHITE
var haze_tint: Color = Color.WHITE
var dust_col: Color = Color.WHITE
var pan_body: Color = Color("141a2e")
var pan_hi: Color = Color("4a5c96")
# multiplayer jobs (decision D7). Solo: no job is split out and the landing plays as before.
# Online the host simulates: the Engineer's engine keys, the Scientist's parachute and legs and the
# Planner's site arrive as "input"; the host sends "state" and everyone else draws it.
var jobs: bool = false          # online, or offline testing with -- roles=...
var driver: bool = true         # this game runs the simulation (offline, or the room host)
var remote: Dictionary = {}     # host: the latest "input" keys from other players, by role
var chute_job: bool = false     # Mars: the Scientist opens the parachute
var chute_open: bool = false
var chute_cut: bool = false
var chute_cut_t: float = -9.0
var chute_req: bool = false
var gear_job: bool = false      # the Scientist lowers the legs (or airbags)
var gear: float = 1.0           # 0 = up, 1 = down
var gear_req: bool = false
var site_job: bool = false      # the Planner picks the landing site first
var site_i: int = -1
var site_t: float = 0.0
var site_req: int = -1
var send_t: float = 0.0

func _ready() -> void:
	jobs = Game.multi()
	driver = Net.is_host()
	chute_job = jobs and Game.job("science") and Game.dest_id == "mars" and Game.id_has("chute") and Game.id_has("heatshield")
	var s: Dictionary = Game.landing_setup(chute_job)
	moon = Game.dest_id == "moon"
	var kind: String = "moon" if moon else "mars"
	tex = Pix.img("lander")
	tex_earth = Pix.planet(22, "earth")
	tex_halo = Pix.img("surface/earth_halo")
	tex_dist = Pix.img("surface/%s_range_dist" % kind)
	tex_far = Pix.img(kind + "_range_far")
	tex_mid = Pix.img(kind + "_range_near")
	tex_scorch = Pix.img("surface/scorch")
	tex_beacon = [Pix.img("surface/beacon0"), Pix.img("surface/beacon1")]
	tex_marker = Pix.img("surface/marker")
	tex_arrow = Pix.img("surface/arrow_r")
	for n: String in ["ic_down", "ic_fuel", "ic_drift"]:
		tex_icon[n] = Pix.img("surface/" + n)
	for i: int in PEBBLE_W.size():
		tex_pebble.append(Pix.img("pebble_%s_%d" % [kind, i]))
	for i: int in CRATER_W.size():
		tex_crater.append(Pix.img("surface/crater_%s_%d" % [kind, i]))
	if not moon:
		tex_sky = Pix.img("surface/mars_sky_day")
		tex_cloud = [Pix.img("surface/mars_cloud_0"), Pix.img("surface/mars_cloud_1"), Pix.img("surface/mars_cloud_2")]
		tex_phobos = Pix.img("surface/phobos")
		tex_devil = Pix.img("surface/dust_devil")
		tex_sheet = Pix.img("surface/dust_sheet")
		tex_chute = Pix.img("surface/chute")
		tex_shield = Pix.img("surface/heatshield")
		pan_body = Color("2a1410")
		pan_hi = Color("8a5a3c")
	haze_tint = Color("6c7088") if moon else Color("b06a48")
	dust_col = Color("c4c4d2") if moon else Color("e0a070")
	has_chute = not moon and Game.id_has("chute")
	has_shield = not moon and Game.id_has("heatshield")
	# layers: this node draws sky and mountains; then the perspective floor; then the rest
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + kind))
	floor_mat.set_shader_parameter("haze", haze_tint)
	floor_mat.set_shader_parameter("haze_max", 0.8)
	floor_rect = ColorRect.new()
	floor_rect.material = floor_mat
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	front = Control.new()
	front.size = Vector2(640, 360)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)
	add_child(front)
	# craters and rocks on the plain, at many depths (s = 1 at the pad, larger = farther)
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = 31 if moon else 32
	for i: int in 90:
		var ds: float = exp(rd.randf_range(log(0.6), log(9.0)))
		var dx: float = rd.randf_range(-420.0, 420.0) * ds
		if ds > 0.75 and ds < 1.5 and absf(dx) < 90.0:
			continue
		var is_crater: bool = rd.randf() < (0.6 if moon else 0.3)
		decor.append({"x": dx, "s": ds, "b": rd.randf_range(30.0, 110.0) if is_crater else rd.randf_range(8.0, 40.0), "c": is_crater})
	decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	if bool(Game.run["dead"]):
		_burn_up()
		return
	g = float(s["g"])
	alt = float(s["alt"])
	alt0 = alt
	vy = float(s["vy"])
	vx = float(s["vx"])
	prop = float(s["prop"])
	prop0 = maxf(1.0, prop)
	mass = float(s["mass"])
	touch = float(s["touch"])
	thrust_acc = maxf(3.0 * g, 7.0)  # game rule: engine sized to 3x local gravity
	vmax = maxf(sqrt(vy * vy + 2.0 * g * alt0) * 0.75, touch * 4.0)
	if jobs:
		gear_job = Game.job("science") and (Game.id_has("legs") or Game.id_has("airbags"))
		gear = 0.0 if gear_job else 1.0
		site_job = Game.job("planner")
		if site_job:
			state = "site"
		auto = Game.cpu("engineer")   # offline testing: the computer flies the engine
		Net.received.connect(_on_net)
	# touch buttons only where there is a touch screen
	if DisplayServer.is_touchscreen_available():
		_hold_button("<", Rect2(8, 322, 44, 30), func(on: bool) -> void: hold_l = on)
		_hold_button(">", Rect2(58, 322, 44, 30), func(on: bool) -> void: hold_r = on)
		_hold_button("ENGINE", Rect2(540, 322, 92, 30), func(on: bool) -> void: hold_up = on)

func _hold_button(txt: String, r: Rect2, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	b.position = r.position
	b.size = r.size
	b.button_down.connect(cb.bind(true))
	b.button_up.connect(cb.bind(false))

func _burn_up() -> void:
	state = "burned"
	end_t = t + 3.5
	msg = "BURNED UP ON ENTRY"
	msg_col = UI.RED
	Audio.play("explosion", -4.0)

# ---------------------------------------------------------------- the braking cue

## Sideways speed the lander survives at touchdown (game rule).
func side_limit() -> float:
	return maxf(3.0, touch * 0.6)

## Speed the BRAKE light asks you to slow down to: half the limit, or less where gravity is strong,
## so that even REACT seconds of free fall after it stay under the limit.
func target_v() -> float:
	return maxf(touch * 0.25, minf(touch * 0.5, touch * 0.95 - g * REACT))

## Altitude where a full-thrust burn must start at fall speed `v` to reach the target speed at the
## ground: REACT seconds of free fall (a person reacting to the light), then the stopping distance
## (v1*v1 - vt*vt) / (2 * (thrust_acc - g)).
func brake_alt(v: float) -> float:
	var v1: float = v + g * REACT
	var vt: float = target_v()
	return maxf(0.0, v1 * v1 - vt * vt) / (2.0 * (thrust_acc - g)) + maxf(0.0, v) * REACT + 0.5 * g * REACT * REACT

## Speed at the ground if the engine stays off from here.
func impact_v() -> float:
	return sqrt(maxf(0.0, vy * vy + 2.0 * g * alt))

func _must_brake(a: float, v: float) -> bool:
	return v > target_v() and a <= brake_alt(v)

func _update_cue() -> void:
	burn_alt = -1.0
	burn_in = 99.0
	if chute_job and not chute_cut:
		brake = false
		cue = "chute"   # high and fast: the parachute does the braking up here
		return
	if prop <= 0.0:
		brake = false
		cue = "empty"
		return
	var coast_ok: bool = impact_v() <= touch * 0.85
	if brake:
		if vy <= target_v():
			brake = false
	elif not coast_ok and _must_brake(alt, vy):
		brake = true
		burns += 1
		Audio.play("warn_alt", -6.0)
	if brake:
		cue = "brake"
		burn_alt = alt
		burn_in = 0.0
	elif coast_ok:
		cue = "safe"
	else:
		# look ahead along the free fall: when and where will the light come on?
		var a: float = alt
		var v: float = vy
		var tt: float = 0.0
		while tt < 20.0 and a > 0.0:
			if _must_brake(a, v):
				burn_alt = a
				burn_in = tt
				break
			v += g * 0.05
			a -= v * 0.05
			tt += 0.05
		cue = "release" if thrusting else ("soon" if burn_in < 3.0 else "fall")
		var n: int = ceili(burn_in)
		if cue == "soon" and n < last_count:
			Audio.play("blip", -8.0, 1.0 + 0.15 * (3 - n))
		last_count = n if cue == "soon" else 9
	# drift: warn before the limit, stop warning once it is well inside
	if absf(vx) > side_limit() * 0.8:
		drift_warn = true
	elif absf(vx) < side_limit() * 0.3:
		drift_warn = false

# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if state == "site":
		_site_tick(delta)
		return
	t += delta
	_particles(delta)
	shake = maxf(0.0, shake - delta * 1.6)
	if not driver:
		# another player's game: send this player's controls, draw what the host sends
		_send_input(delta)
		if state == "fly":
			_update_cue()
		Audio.loop("thrust", thrusting and state == "fly", -5.0)
		Audio.loop("rcs", side != 0.0 and state == "fly", -10.0)
		return
	_send_state(delta)
	if state != "fly":
		Audio.loop("thrust", false)
		Audio.loop("rcs", false)
		if t > end_t:
			_leave()
		return
	if jobs:
		_jobs_tick(delta)
	_update_cue()
	var k: Dictionary = _engine_keys()
	var up: bool = bool(k.get("up", false))
	var lft: bool = bool(k.get("left", false))
	var rgt: bool = bool(k.get("right", false))
	if auto:
		var want: bool = cue == "brake"
		if want != auto_want:
			auto_want = want
			auto_since = t
		if t - auto_since >= auto_lag:
			auto_up = auto_want
		up = auto_up
		lft = drift_warn and vx > 0.0
		rgt = drift_warn and vx < 0.0
	thrusting = up and prop > 0.0
	Audio.loop("thrust", thrusting, -5.0)
	side = 0.0
	if prop > 0.0:
		if lft:
			side -= SIDE_ACC
		if rgt:
			side += SIDE_ACC
	Audio.loop("rcs", side != 0.0, -10.0)
	var a_up: float = thrust_acc if thrusting else 0.0
	vy += (g - a_up) * delta
	if chute_open and not chute_cut and vy > float(Data.LANDING_JOBS["chute_vy"]):
		vy = maxf(float(Data.LANDING_JOBS["chute_vy"]), vy - float(Data.LANDING_JOBS["chute_decel"]) * delta)
	vx += side * delta
	alt -= vy * delta
	x += vx * delta
	var ve: float = Data.ISP * Data.G0
	var burn: float = 0.0
	if thrusting:
		burn += mass * thrust_acc / ve * delta
	if side != 0.0:
		burn += mass * SIDE_ACC / ve * delta
	burn = minf(burn, prop)
	prop -= burn
	mass -= burn
	if alt <= 0.0:
		alt = 0.0
		var legs_up: bool = gear < 1.0
		var ok: bool = vy <= touch and absf(vx) <= side_limit() and not legs_up
		state = "landed" if ok else "crashed"
		end_t = t + 3.5
		thrusting = false
		side = 0.0
		Game.landing_result(ok, vy, prop, "The landing legs were still up: the Scientist must lower them before touchdown." if legs_up else "")
		if auto:
			print("AUTOPILOT %s on %s: limit %.0f m/s, touched at %.2f m/s down and %.2f m/s sideways (limit %.1f), fuel left %.0f of %.0f kg, %d burns, %.0f s, reaction lag %.2f s" % ["LANDED" if ok else "CRASHED", Game.dest_id, touch, vy, absf(vx), side_limit(), prop, prop0, burns, t, auto_lag])
		if ok:
			msg = "TOUCHDOWN!  %.1f m/s" % vy
			msg_col = UI.GREEN
			land_t = t
			shake = 0.25
			_blow_dust(26, 1.0)
			Audio.play("land")
			Audio.play("success", -4.0)
		else:
			msg = "CRASH  %.1f m/s down, %.1f m/s sideways" % [vy, absf(vx)] if not legs_up else "CRASH: LEGS STILL UP"
			msg_col = UI.RED
			_boom()
		_send_state(1.0)

func _leave() -> void:
	set_physics_process(false)
	if state == "landed":
		Game.flow("surface")
	else:
		Game.finish()
		Game.flow("report")

# ---------------------------------------------------------------- multiplayer jobs

## The Engineer's engine keys: this player's own keys when they hold the role (and solo), else the last
## keys that player sent.
func _engine_keys() -> Dictionary:
	if jobs and not Net.owns("engineer"):
		return remote.get("engineer", {})
	return {
		"up": hold_up or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE),
		"left": hold_l or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A),
		"right": hold_r or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D),
	}

## Host: the Scientist's parachute and legs.
func _jobs_tick(delta: float) -> void:
	var j: Dictionary = Data.LANDING_JOBS
	if chute_job and not chute_cut:
		if chute_req and not chute_open:
			chute_open = true
			Audio.play("confirm", -2.0)
			Game.note(true, "The Scientist opened the parachute at %s m, falling at %d m/s." % [Game.fmt(alt), roundi(vy)])
		if alt <= float(j["chute_cut_alt"]):
			chute_cut = true
			chute_cut_t = t
			if not chute_open:
				Game.note(false, "The parachute was never opened: the lander is still falling at %d m/s." % roundi(vy))
	if gear_job and gear_req and gear < 1.0:
		if gear == 0.0:
			Audio.play("part_snap", -4.0)
		gear = minf(1.0, gear + delta / float(j["gear_secs"]))

func _site_tick(delta: float) -> void:
	if not driver:
		_send_input(delta)
		return
	site_t += delta
	if site_req < 0 and site_t >= float(Data.LANDING_JOBS["site_secs"]):
		site_req = 0
	if site_req >= 0:
		_pick_site(site_req)
	_send_state(delta)

## Host: the Planner's landing site changes the drift to cancel and the safe touchdown speed.
func _pick_site(i: int) -> void:
	site_i = clampi(i, 0, Data.LANDING_SITES.size() - 1)
	var sd: Dictionary = Data.LANDING_SITES[site_i]
	vx += (signf(vx) if vx != 0.0 else 1.0) * float(sd["drift"])
	touch *= float(sd["touch_mult"])
	Game.run["site"] = site_i
	Game.run["calc"]["touch"] = touch
	var extra: String = "" if float(sd["credit_mult"]) == 1.0 else " Credits x%s." % str(sd["credit_mult"])
	Game.note(true, "The Planner picked the %s. Safe touchdown there: %.1f m/s.%s" % [String(sd["name"]).to_lower(), touch, extra])
	state = "fly"
	Audio.play("confirm", -3.0)

func _input(ev: InputEvent) -> void:
	if not jobs:
		return
	var k: InputEventKey = ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if Net.owns("science"):
		if k.physical_keycode == KEY_C and chute_job:
			chute_req = true
		elif k.physical_keycode == KEY_G and gear_job:
			gear_req = true
	if Net.owns("planner") and state == "site" and site_req < 0:
		var i: int = k.keycode - KEY_1
		if i >= 0 and i < Data.LANDING_SITES.size():
			site_req = i

func _gui_input(ev: InputEvent) -> void:
	var mb: InputEventMouseButton = ev as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if state == "site" and Net.owns("planner") and site_req < 0:
		for i: int in Data.LANDING_SITES.size():
			if _site_rect(i).has_point(mb.position):
				site_req = i

## Not the host: this player's controls, about 20 times a second, one message per role they hold.
func _send_input(delta: float) -> void:
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 1.0 / float(Data.NET_RATES["input_hz"])
	if Net.owns("engineer") and state == "fly":
		Net.send("input", {"role": "engineer", "keys": _engine_keys()})
	if Net.owns("science") and (chute_req or gear_req):
		Net.send("input", {"role": "science", "keys": {"chute": chute_req, "legs": gear_req}})
	if Net.owns("planner") and site_req >= 0 and state == "site":
		Net.send("input", {"role": "planner", "keys": {"site": site_req}})

## Host: the simulation for everyone else to draw, about 15 times a second (force with delta >= 1).
func _send_state(delta: float) -> void:
	if not Net.is_online():
		return
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 1.0 / float(Data.NET_RATES["state_hz"])
	Net.send("state", {"s": state, "t": t, "alt": alt, "vy": vy, "vx": vx, "x": x, "prop": prop, "thr": thrusting,
		"side": side, "touch": touch, "chute": chute_open, "cut": chute_cut, "gear": gear, "site": site_i, "st": site_t})

func _on_net(kind: String, d: Dictionary, from_id: int) -> void:
	if kind == "input" and driver:
		var role: String = String(d.get("role", ""))
		if not Game.sender_owns(from_id, role) or not (d.get("keys") is Dictionary):
			return
		var keys: Dictionary = d["keys"]
		match role:
			"engineer":
				remote["engineer"] = keys
			"science":
				chute_req = chute_req or bool(keys.get("chute", false))
				gear_req = gear_req or bool(keys.get("legs", false))
			"planner":
				if state == "site" and site_req < 0:
					site_req = int(keys.get("site", -1))
	elif kind == "state" and not driver:
		_apply_state(d)

## Not the host: take the host's simulation, and play the touchdown or the crash when it happens.
func _apply_state(d: Dictionary) -> void:
	t = float(d.get("t", t))
	alt = float(d.get("alt", alt))
	vy = float(d.get("vy", vy))
	vx = float(d.get("vx", vx))
	x = float(d.get("x", x))
	prop = float(d.get("prop", prop))
	thrusting = bool(d.get("thr", false))
	side = float(d.get("side", 0.0))
	touch = float(d.get("touch", touch))
	chute_open = bool(d.get("chute", chute_open))
	gear = float(d.get("gear", gear))
	site_i = int(d.get("site", site_i))
	site_t = float(d.get("st", site_t))
	var cut: bool = bool(d.get("cut", chute_cut))
	if cut and not chute_cut:
		chute_cut_t = t
	chute_cut = cut
	var ns: String = String(d.get("s", state))
	if ns == state or state == "burned":
		return
	state = ns
	if ns == "landed":
		msg = "TOUCHDOWN!  %.1f m/s" % vy
		msg_col = UI.GREEN
		land_t = t
		shake = 0.25
		_blow_dust(26, 1.0)
		Audio.play("land")
		Audio.play("success", -4.0)
	elif ns == "crashed":
		msg = "CRASH: LEGS STILL UP" if gear < 1.0 else "CRASH  %.1f m/s down, %.1f m/s sideways" % [vy, absf(vx)]
		msg_col = UI.RED
		_boom()

func _site_rect(i: int) -> Rect2:
	return Rect2(146 + i * 118, 132, 112, 74)

# ---------------------------------------------------------------- particles (drawn by the Fx kit)

## Dust blown outward along the ground. No air on the Moon: it flies flat and fast on ballistic
## arcs. Thin air on Mars: it slows down and billows.
func _blow_dust(n: int, power: float) -> void:
	for i: int in n:
		var a: float = randf_range(0.0, TAU)
		var sp: float = randf_range(50.0, 170.0) * power
		dust.append({"x": randf_range(-5.0, 5.0), "z": randf_range(-2.0, 2.0), "h": 0.0,
			"vx": cos(a) * sp, "vz": sin(a) * sp * 0.3, "vh": randf_range(6.0, 34.0) * power * (0.5 if moon else 1.0),
			"age": 0.0, "life": randf_range(0.5, 1.3), "size": 1 if i % 3 == 0 else 0})

func _particles(delta: float) -> void:
	var gap: float = _lane() - (_feet() - 8.0)   # nozzle to ground, in screen px
	if thrusting and gap < 80.0:
		_blow_dust(2, 1.0 - gap / 100.0)
	for d: Dictionary in dust:
		var vh: float = float(d["vh"]) - g * 14.0 * delta
		if not moon:
			d["vx"] = float(d["vx"]) * (1.0 - 2.2 * delta)
			d["vz"] = float(d["vz"]) * (1.0 - 2.2 * delta)
			vh += 26.0 * delta
		d["vh"] = vh
		d["h"] = maxf(0.0, float(d["h"]) + vh * delta)
		d["x"] = float(d["x"]) + float(d["vx"]) * delta
		d["z"] = float(d["z"]) + float(d["vz"]) * delta
		d["age"] = float(d["age"]) + delta
	dust = dust.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["life"]))
	# wreck smoke needs air to rise in: Mars only
	if state == "crashed" and not moon and t - boom_t > 0.3 and randf() < 0.3:
		smoke.append({"p": Vector2(LX + randf_range(-14.0, 14.0), GROUND_Y - 6.0), "age": 0.0, "life": randf_range(1.2, 2.2)})
	for d: Dictionary in smoke:
		d["p"] = Vector2(d["p"]) + Vector2(14.0, -26.0) * delta
		d["age"] = float(d["age"]) + delta
	smoke = smoke.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["life"]))
	for d: Dictionary in debris:
		var p: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		if p.y < float(d["rest"]):
			v.y += g * 60.0 * delta
			p += v * delta
			if p.y >= float(d["rest"]):
				p.y = float(d["rest"])
		d["p"] = p
		d["v"] = v

func _boom() -> void:
	shake = 1.0
	boom_t = t
	Audio.play("explosion")
	_blow_dust(40, 1.3)
	# the lander breaks into pieces of its own sprite
	for i: int in 9:
		var src: Rect2 = Rect2(8 + (i % 3) * 22, 6 + (i / 3) * 22, 22, 22)
		var a: float = randf_range(PI * 1.1, PI * 1.9)
		debris.append({"src": src, "p": Vector2(LX - 30.0 + (i % 3) * 22.0, GROUND_Y - 60.0 + (i / 3) * 18.0),
			"v": Vector2(cos(a), sin(a)) * randf_range(40.0, 150.0), "rest": GROUND_Y - 20.0 + randf_range(-3.0, 5.0)})

# ---------------------------------------------------------------- camera

func _k() -> float:
	return pow(clampf(alt / maxf(1.0, alt0), 0.0, 1.0), ZOOM)

## The ground sits lower on screen while you are high up, and rises to meet you.
func _horizon() -> float:
	return floorf(236.0 + _k() * 100.0)

func _lane() -> float:
	return _horizon() + 76.0

func _feet() -> float:
	# while the parachute is out the lander hangs lower, so the canopy fits on screen
	var hang: float = 36.0 * clampf(3.6 - t, 0.0, 1.0) if has_chute else 0.0
	if chute_job:
		hang = 0.0 if not chute_open else (36.0 if not chute_cut else 36.0 * clampf(1.0 - (t - chute_cut_t), 0.0, 1.0))
	return floorf(GROUND_Y - 232.0 * _k() + hang)

func _process(_delta: float) -> void:
	# decaying trauma on smooth sines, not per-frame noise
	var tr: float = shake * shake * 5.0
	shake_off = Vector2(sin(t * 61.0) * tr, sin(t * 47.0 + 1.3) * tr).floor()
	var hz: float = _horizon()
	floor_rect.position = Vector2(0, hz) + shake_off
	floor_rect.size = Vector2(640, 364.0 - hz)
	floor_mat.set_shader_parameter("horizon", hz)
	floor_mat.set_shader_parameter("top", hz)
	floor_mat.set_shader_parameter("lane", hz + 76.0)
	floor_mat.set_shader_parameter("size", floor_rect.size)
	floor_mat.set_shader_parameter("cam", floorf(x * HX))
	queue_redraw()
	front.queue_redraw()

# ---------------------------------------------------------------- back layer: sky and ranges

func _draw() -> void:
	var k: float = _k()
	var hz: float = _horizon()
	var cam_x: float = x * HX
	draw_set_transform(shake_off)
	if moon:
		draw_rect(Rect2(-4, -4, 648, 368), Color("04050a"))
		Pix.stars(self, t, Vector2(640, 330), 110, 5)
		var ep: Vector2 = Vector2(476, 96.0 + k * 20.0)
		Pix.sprite(self, tex_halo, ep)
		Pix.sprite(self, tex_earth, ep)
	else:
		draw_rect(Rect2(-4, 260, 648, 108), Color("e8c49c"))
		draw_texture(tex_sky, Vector2(0, -20.0 + k * 20.0))
		Fx.sun(self, Vector2(150, 70.0 + k * 20.0), 1, Color("fff0d8"))
		draw_texture(tex_phobos, Vector2(430, 52.0 + k * 20.0))
		for i: int in 5:
			var ct: Texture2D = tex_cloud[i % 3]
			var cx: float = fposmod(i * 173.0 + t * (2.0 + i % 2), 780.0) - 130.0
			draw_texture(ct, Vector2(floorf(cx), floorf(60.0 + i * 31.0 + k * 20.0)), Color(1, 1, 1, 0.7))
	Pix.tiled(self, tex_dist, hz - tex_dist.get_height() + 4, cam_x * 0.02)
	Pix.tiled(self, tex_far, hz - tex_far.get_height() + 3, cam_x * 0.06)
	if not moon:
		# a dust devil wandering across the far plain
		var dvx: float = fposmod(t * 6.0 + 380.0 - cam_x * 0.1, 760.0) - 60.0
		draw_texture_rect_region(tex_devil, Rect2(floorf(dvx), hz - 40.0, 16, 34), Rect2(16 * (int(t * 6.0) % 4), 0, 16, 34), Color(1, 1, 1, 0.8))
	Pix.tiled(self, tex_mid, hz - tex_mid.get_height() + 8, cam_x * 0.16)
	if not moon:
		Pix.tiled(self, tex_sheet, hz - 16.0, cam_x * 0.2 - t * 9.0, 640.0, Color(1, 1, 1, 0.8))
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- front layer

func _decor(lane: float, near: bool) -> void:
	var hz: float = lane - 76.0
	var cam_x: float = x * HX
	for d: Dictionary in decor:
		var s: float = d["s"]
		if (s < 1.0) != near:
			continue
		var sx: float = LX + (float(d["x"]) - cam_x) / s
		if sx < -70.0 or sx > 710.0:
			continue
		var sy: float = hz + 76.0 / s
		if sy > 380.0:
			continue
		var want: float = float(d["b"]) / s
		var fog: Color = Color.WHITE.lerp(haze_tint, clampf((s - 1.0) / 9.0, 0.0, 1.0) * 0.8)
		if bool(d["c"]):
			var ci: int = 0
			while ci < CRATER_W.size() - 1 and CRATER_W[ci + 1] <= want:
				ci += 1
			var ct: Texture2D = tex_crater[ci]
			front.draw_texture(ct, Vector2(floorf(sx - ct.get_width() * 0.5), floorf(sy - ct.get_height() * 0.5)), fog)
		else:
			var pi: int = 0
			while pi < PEBBLE_W.size() - 1 and PEBBLE_W[pi + 1] <= want:
				pi += 1
			var pt: Texture2D = tex_pebble[pi]
			if pi >= 2:
				_shadow(sx + 3.0, sy, pt.get_width() * 0.9, 0.25)
			front.draw_texture(pt, Vector2(floorf(sx - pt.get_width() * 0.5), floorf(sy - pt.get_height() + 2)), fog)

## A soft pixel ellipse on the ground (contact shadow).
func _shadow(cx: float, y: float, w: float, a: float) -> void:
	for dy: int in range(-2, 3):
		var hw: float = floorf(w * 0.5 * sqrt(1.0 - pow(dy / 2.6, 2.0)))
		front.draw_rect(Rect2(floorf(cx - hw), floorf(y) + dy, hw * 2.0, 1), Color(0, 0, 0, a))

func _draw_dust(lane: float, behind: bool) -> void:
	for d: Dictionary in dust:
		var z: float = d["z"]
		if (z < 0.0) != behind:
			continue
		var p: Vector2 = Vector2(LX + 2.0 + float(d["x"]), lane + z - float(d["h"]))
		Fx.puff(front, p, float(d["age"]) / float(d["life"]), int(d["size"]), dust_col)

func _draw_front() -> void:
	var lane: float = _lane()
	var feet: float = _feet()
	var gap: float = lane - feet
	front.draw_set_transform(shake_off)
	_decor(lane, false)
	if state == "burned":
		_draw_burned()
		front.draw_set_transform(Vector2.ZERO)
		Pix.text_c(front, 320, 150, msg, 18, msg_col)
		return
	# landing zone: a dashed ring on the floor and two blinking beacons
	for i: int in 56:
		if i % 2 == 0:
			var a: float = i * TAU / 56.0
			front.draw_rect(Rect2(Vector2(LX + 2.0 + cos(a) * 56.0, lane + sin(a) * 6.0).floor(), Vector2(2, 1)), Color(UI.YELLOW, 0.8))
	var lit: int = 1 if fposmod(t, 1.0) < 0.25 else 0
	for bx: float in [LX - 62.0, LX + 58.0]:
		if lit == 1:
			Fx.glow(front, Vector2(bx + 3.0, lane - 8.0), 7.0, Color(1.0, 0.3, 0.25, 0.7))
		front.draw_texture(tex_beacon[lit], Vector2(bx, lane - 10.0))
	if state == "crashed" or state == "landed":
		front.draw_texture(tex_scorch, Vector2(LX - 34.0, lane - 8.0), Color(1, 1, 1, 1.0 if state == "crashed" else 0.45))
	if state != "crashed":
		# contact shadow: grows and darkens as the ground comes up
		var near: float = clampf(1.0 - gap / 240.0, 0.0, 1.0)
		_shadow(LX + 6.0, lane, 40.0 + 52.0 * near, 0.1 + 0.32 * near)
		# where you will touch down if you do nothing about the drift
		var fall_t: float = (-vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * alt))) / g
		var px: float = clampf(LX + vx * fall_t * HX, 20.0, 620.0)
		if state == "fly" and absf(px - LX) > 10.0:
			front.draw_texture(tex_marker, Vector2(floorf(px - 4.0), lane - 9.0 - floorf(absf(sin(t * 5.0)) * 3.0)))
	_draw_dust(lane, true)
	if state == "crashed":
		for d: Dictionary in debris:
			front.draw_texture_rect_region(tex, Rect2(Vector2(d["p"]).floor(), Vector2(22, 22)), d["src"])
		for d: Dictionary in smoke:
			Fx.puff(front, d["p"], float(d["age"]) / float(d["life"]), 2, Color("3a3440"))
		Fx.explosion(front, Vector2(LX, lane - 16.0), t - boom_t, 2)
	else:
		_draw_lander(feet, lane)
	_draw_dust(lane, false)
	_decor(lane, true)
	front.draw_set_transform(Vector2.ZERO)
	if state == "crashed":
		Fx.flash(front, t - boom_t, 0.2, Color(1.0, 0.95, 0.85))
	_draw_hud()

func _draw_lander(feet: float, lane: float) -> void:
	# legs take the touchdown: a short squash, then back up
	var settle: float = 2.0 if t - land_t < 0.12 else 0.0
	var top: float = feet - 71.0 + settle
	if not moon and t < 4.0:
		# the build's entry hardware has done its job and drops away (already in the simulation)
		if has_shield:
			var sy: float = feet - 2.0 + maxf(0.0, t - 0.5) * 130.0
			front.draw_texture(tex_shield, Vector2(LX - 21.0 + maxf(0.0, t - 0.5) * 14.0, floorf(sy)))
		if has_chute and not chute_job:
			# rides above the lander for the first seconds, then is cut away
			var cut: float = maxf(0.0, t - 2.6)
			var cy: float = top - 44.0 - cut * cut * 160.0
			front.draw_texture(tex_chute, Vector2(floorf(LX - 27.0 - cut * 40.0 + sin(t * 3.0) * 2.0), floorf(cy)))
	if chute_job and chute_open and (not chute_cut or t - chute_cut_t < 2.0):
		# the Scientist's parachute: open until it is cut away at the cut altitude
		var cut2: float = maxf(0.0, t - chute_cut_t) if chute_cut else 0.0
		front.draw_texture(tex_chute, Vector2(floorf(LX - 27.0 - cut2 * 40.0 + sin(t * 3.0) * 2.0), floorf(top - 44.0 - cut2 * cut2 * 160.0)))
	var nz: Vector2 = Vector2(LX + 2.0, feet - 8.0 + settle)
	if thrusting:
		var room: float = maxf(4.0, lane - nz.y)
		Fx.flame(front, nz, Vector2.DOWN, minf(24.0, room), 9.0, t)
		if room < 70.0:
			# engine light pooled on the ground
			Fx.glow(front, Vector2(LX + 2.0, lane), 46.0 * (1.0 - room / 90.0), Color(1.0, 0.75, 0.35, 0.8 * (1.0 - room / 90.0)))
	if side < 0.0:
		Fx.flame(front, Vector2(LX + 17.0, top + 20.0), Vector2.RIGHT, 9.0, 3.0, t)
	elif side > 0.0:
		Fx.flame(front, Vector2(LX - 16.0, top + 20.0), Vector2.LEFT, 9.0, 3.0, t)
	front.draw_texture(tex, Vector2(LX - 38.0, top))
	if fposmod(t, 1.2) < 0.15:
		front.draw_rect(Rect2(LX + 15.0, top + 18.0, 2, 2), Color("ffb0a0"))  # nav light

func _draw_burned() -> void:
	var age: float = t - (end_t - 3.5)
	var p: Vector2 = Vector2(250.0 + age * 40.0, 20.0 + age * 70.0).floor()
	if age < 2.2:
		for i: int in 6:
			Fx.puff(front, p - Vector2(8.0 + i * 9.0, 14.0 + i * 16.0), 0.25 + i * 0.12, 1, Color("5a4840"))
		Fx.glow(front, p, 26.0, Color(1.0, 0.6, 0.2, 0.8))
		Fx.flame(front, p, Vector2.UP, 46.0, 14.0, t)
	Fx.explosion(front, p.min(Vector2(640.0, 174.0)), age - 2.2, 2)

# ---------------------------------------------------------------- HUD

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(front, p, s, size, c)

## The shared HUD frame from the UI kit, tinted for the place (warm on Mars).
func _panel(r: Rect2) -> void:
	Pix.panel(front, r, pan_hi, Color(pan_body, 0.88))

## Sunken gauge well.
func _well(r: Rect2) -> void:
	front.draw_rect(r.grow(1.0), Color("05070d"))
	front.draw_rect(r, Color("0d1120"))

## A key cap from the UI kit; returns its width.
func _key(p: Vector2, label: String) -> float:
	return Pix.keycap(front, p, label)

func _tape_y(a: float) -> float:
	return floorf(TAPE_TOP + TAPE_H * (1.0 - pow(clampf(a / maxf(1.0, alt0), 0.0, 1.0), ZOOM)))

func _draw_hud() -> void:
	var safe: bool = vy <= touch
	var scol: Color = UI.GREEN if safe else UI.RED
	# left cluster: fall speed (big), its gauge, fuel, drift
	_panel(Rect2(6, 6, 140, 96))
	_text(Vector2(13, 18), "%s LANDING" % String(Game.dest()["name"]).to_upper(), 10, UI.YELLOW)
	front.draw_texture(tex_icon["ic_down"], Vector2(13, 25), scol)
	_text(Vector2(27, 42), "%.1f" % maxf(0.0, vy), 20, scol)
	_text(Vector2(100, 33), "m/s", 10, UI.DIM)
	_text(Vector2(100, 43), "MAX %.0f" % touch, 10, UI.TEXT)
	# speed gauge on a square-root scale, so the small safe zone stays readable
	var gx: float = 13.0
	var gw: float = 126.0
	_well(Rect2(gx, 49, gw, 7))
	var safe_w: float = floorf(gw * sqrt(touch / vmax))
	front.draw_rect(Rect2(gx, 49, safe_w, 7), Color("1f7a3a"))
	front.draw_rect(Rect2(gx, 49, safe_w, 2), UI.GREEN)
	front.draw_rect(Rect2(gx + safe_w, 49, gw - safe_w, 7), Color("5a1c20"))
	var nx: float = gx + floorf((gw - 2.0) * sqrt(clampf(vy / vmax, 0.0, 1.0)))
	front.draw_rect(Rect2(nx - 1.0, 47, 4, 11), Color("05070d"))
	front.draw_rect(Rect2(nx, 48, 2, 9), Color.WHITE)
	# fuel tank
	front.draw_texture(tex_icon["ic_fuel"], Vector2(13, 62))
	var frac: float = clampf(prop / prop0, 0.0, 1.0)
	Pix.gauge(front, Rect2(26, 63, 64, 9), frac, UI.ORANGE if frac > 0.2 else UI.RED)
	_text(Vector2(94, 71), "%s kg" % Game.fmt(prop), 10, UI.TEXT)
	# drift: zero in the middle, green inside the limit
	front.draw_texture(tex_icon["ic_drift"], Vector2(13, 82))
	var lim: float = side_limit()
	var span: float = lim * 2.5
	_well(Rect2(27, 82, 62, 7))
	var half: float = floorf(31.0 * lim / span)
	front.draw_rect(Rect2(58.0 - half, 82, half * 2.0, 7), Color("1f7a3a"))
	var dcol: Color = UI.GREEN if absf(vx) <= lim else UI.RED
	var dn: float = 58.0 + floorf(clampf(vx / span, -1.0, 1.0) * 30.0)
	front.draw_rect(Rect2(dn - 2.0, 80, 4, 11), Color("05070d"))
	front.draw_rect(Rect2(dn - 1.0, 81, 2, 9), Color.WHITE)
	_text(Vector2(94, 89), "%.1f" % absf(vx), 10, dcol)
	_text(Vector2(118, 89), "m/s", 10, UI.DIM)
	_draw_tape(safe)
	if state == "fly":
		_draw_cue()
	# bottom line: what to do for the first seconds, then the keys and a real-world fact
	if jobs:
		_draw_crew()
	if state == "site":
		_draw_sites()
	var engineer: bool = not jobs or Net.owns("engineer")   # the engine keys belong to the Engineer
	if state == "fly" and t < 5.0 and not auto and engineer:
		_panel(Rect2(128, 334, 384, 20))
		var hx: float = 136.0
		_text(Vector2(hx, 348), "Fall freely. When the light says BRAKE, hold", 10, UI.TEXT)
		hx += Pix.text_w("Fall freely. When the light says BRAKE, hold", 10) + 5.0
		hx += _key(Vector2(hx, 337), "SPACE") + 5.0
		_text(Vector2(hx, 348), "to slow down.", 10, UI.TEXT)
	else:
		var kx: float = 444.0 if not DisplayServer.is_touchscreen_available() else 700.0
		if engineer:
			_panel(Rect2(kx - 6.0, 334, 196, 20))
			kx += _key(Vector2(kx, 337), "SPACE") + 4.0
			_text(Vector2(kx, 348), "ENGINE", 10, UI.TEXT)
			kx += 44.0
			kx += _key(Vector2(kx, 337), "<") + 2.0
			kx += _key(Vector2(kx, 337), ">") + 4.0
			_text(Vector2(kx, 348), "STEER", 10, UI.TEXT)
		var fact: String = "No air here: only the engine can slow you down." if moon else "Radio delay 4-24 min: real Mars landers fly themselves."
		# a real-world fact, bottom left, framed like the drone screen's
		var gl: String = "Gravity %s m/s2 (NASA)" % str(g)
		_panel(Rect2(6, 326, maxf(Pix.text_w(fact, 10), Pix.text_w(gl, 10)) + 12.0, 28))
		_text(Vector2(12, 337), fact, 10, UI.TEXT)
		_text(Vector2(12, 347), gl, 10, UI.DIM)
	if msg != "":
		var mw: float = Pix.text_w(msg, 20) + 24.0
		_panel(Rect2(floorf(320.0 - mw / 2.0), 150, mw, 30))
		Pix.text_c(front, 320, 172, msg, 20, msg_col)

## Multiplayer: who does which landing job, and how each one stands. "PRESS ..." when it is this player's turn.
func _draw_crew() -> void:
	var rows: Array = [["engineer", "ENGINE", "FIRING" if thrusting else "-", UI.ORANGE if thrusting else UI.DIM]]
	if site_job:
		var sname: String = String(Data.LANDING_SITES[site_i]["name"]) if site_i >= 0 else ("PRESS 1-3" if Net.owns("planner") else "PICKING")
		rows.append(["planner", "SITE", sname, UI.TEXT if site_i >= 0 else UI.YELLOW])
	if chute_job:
		var cs: String = "PRESS C" if Net.owns("science") else "PACKED"
		var cc: Color = UI.YELLOW
		if chute_open:
			cs = "CUT AWAY" if chute_cut else "OPEN"
			cc = UI.GREEN
		elif chute_cut:
			cs = "NOT OPENED"
			cc = UI.RED
		rows.append(["science", "CHUTE", cs, cc])
	if gear_job:
		var gs: String = "DOWN" if gear >= 1.0 else ("LOWERING" if gear > 0.0 else ("PRESS G" if Net.owns("science") else "UP"))
		rows.append(["science", "LEGS", gs, UI.GREEN if gear >= 1.0 else UI.YELLOW])
	var r: Rect2 = Rect2(152, 6, 218, 8 + rows.size() * 12)
	_panel(r)
	for i: int in rows.size():
		var row: Array = rows[i]
		var role: String = row[0]
		var y: float = r.position.y + 4.0 + i * 12.0
		var rc: Color = Game.role_color(role)
		front.draw_rect(Rect2(r.position.x + 6, y + 3, 7, 7), rc)
		_text(Vector2(r.position.x + 17, y + 10), String(row[1]), 10, UI.TEXT)
		var who: String = "YOU" if Net.owns(role) else ("COMPUTER" if Game.cpu(role) else Game.holder(role))
		if who == "":
			who = Game.role_name(role)
		_text(Vector2(r.position.x + 54, y + 10), who.substr(0, 12), 10, rc)
		var st: String = row[2]
		_text(Vector2(r.end.x - 6.0 - Pix.text_w(st, 10), y + 10), st, 10, row[3])

## Multiplayer: the Planner's landing site choice, before the descent starts.
func _draw_sites() -> void:
	var box: Rect2 = Rect2(138, 104, 364, 112)
	_panel(box)
	var mine: bool = Net.owns("planner")
	var left: int = ceili(maxf(0.0, float(Data.LANDING_JOBS["site_secs"]) - site_t))
	Pix.text_c(front, 320, 117, "PICK THE LANDING SITE", 10, UI.YELLOW)
	Pix.text_c(front, 320, 128, ("PLANNER: CLICK A SITE OR PRESS 1, 2, 3  (%d s)" if mine else "THE PLANNER IS PICKING A SITE  (%d s)") % left, 10, UI.TEXT)
	var m: Vector2 = get_local_mouse_position()
	for i: int in Data.LANDING_SITES.size():
		var sd: Dictionary = Data.LANDING_SITES[i]
		var rc: Rect2 = _site_rect(i)
		var hot: bool = mine and rc.has_point(m)
		Pix.panel(front, rc, Game.role_color("planner") if hot else pan_hi, Color(pan_body, 0.95))
		_text(rc.position + Vector2(6, 13), "%d  %s" % [i + 1, sd["name"]], 10, UI.YELLOW)
		Pix.para(front, rc.position + Vector2(6, 25), String(sd["desc"]), rc.size.x - 12.0, UI.TEXT)
		_text(rc.position + Vector2(6, 56), "drift +%d m/s" % int(sd["drift"]), 10, UI.DIM)
		_text(rc.position + Vector2(6, 68), "safe speed x%s" % str(sd["touch_mult"]), 10, UI.DIM)

## Altitude tape: ticks, the lander as the marker, and where the next burn has to start.
func _draw_tape(safe: bool) -> void:
	_panel(Rect2(576, 6, 58, 304))
	_text(Vector2(582, 18), "ALTITUDE", 10, UI.DIM)
	Pix.text(front, Vector2(628.0 - Pix.text_w("%s m" % Game.fmt(alt), 10), 30), "%s m" % Game.fmt(alt), 10, UI.TEXT)
	var tx: float = 616.0
	_well(Rect2(tx, TAPE_TOP, 10, TAPE_H))
	var step: float = 100.0 if alt0 <= 800.0 else (250.0 if alt0 <= 2000.0 else 500.0)
	var a: float = 0.0
	while a <= alt0 + 1.0:
		var ty: float = _tape_y(a)
		front.draw_rect(Rect2(tx, ty, 10, 1), Color("4a5c96"))
		Pix.text(front, Vector2(tx - 5.0 - Pix.text_w(Game.fmt(a), 10), ty + 4.0), Game.fmt(a), 10, UI.DIM)
		a += step
	front.draw_rect(Rect2(tx, TAPE_TOP + TAPE_H - 2.0, 10, 2), UI.DIM)   # the ground
	if burn_alt > 0.0 and state == "fly":
		# from here down the engine has to be on: red hatch, with the start line on top
		var by: float = _tape_y(burn_alt)
		var yy: float = by
		while yy < TAPE_TOP + TAPE_H - 2.0:
			front.draw_rect(Rect2(tx + (2.0 if int(yy) % 4 < 2 else 0.0), yy, 8, 1), Color(UI.RED, 0.55))
			yy += 1.0
		var flash: bool = cue == "brake" and fposmod(t, 0.3) < 0.15
		front.draw_rect(Rect2(tx - 3.0, by - 1.0, 16, 2), Color.WHITE if flash else UI.RED)
		if cue != "brake" and by > TAPE_TOP + 12.0:
			var lw: float = Pix.text_w("BRAKE", 10) + 5.0
			front.draw_rect(Rect2(tx - lw - 5.0, by - 6.0, lw, 11), Color("5a1c20"))
			_text(Vector2(tx - lw - 2.0, by + 3.0), "BRAKE", 10, UI.RED)
	# the lander marker
	var my: float = _tape_y(alt)
	var mcol: Color = UI.GREEN if safe else UI.YELLOW
	for i: int in 5:
		front.draw_rect(Rect2(tx - 2.0 + i, my - 4.0 + i, 1, 9 - i * 2), Color("05070d"))
	for i: int in 4:
		front.draw_rect(Rect2(tx - 2.0 + i, my - 3.0 + i, 1, 7 - i * 2), mcol)
	front.draw_rect(Rect2(tx + 2.0, my, 8, 1), mcol)

## The light that says what to do now. It rides next to the lander, where the eyes are.
func _draw_cue() -> void:
	var feet: float = _feet()
	var p: Vector2 = Vector2(372, clampf(feet - 64.0, 44.0, 250.0))
	var head: String = ""
	var sub: String = ""
	var col: Color = UI.TEXT
	var lamp: bool = true
	match cue:
		"brake":
			head = "BRAKE NOW"
			sub = "hold the engine on"
			col = UI.RED
			lamp = fposmod(t, 0.3) < 0.18
		"release":
			head = "RELEASE"
			sub = "slow enough, save fuel"
			col = UI.YELLOW
		"safe":
			head = "SAFE SPEED"
			sub = "hands off, let it land"
			col = UI.GREEN
		"soon":
			head = "BRAKE IN %d" % maxi(1, ceili(burn_in))
			sub = "get ready"
			col = UI.YELLOW
			lamp = fposmod(burn_in, 1.0) > 0.5
		"empty":
			head = "NO FUEL"
			sub = "nothing left to brake with"
			col = UI.RED
		"chute":
			head = "PARACHUTE"
			sub = "opening: wait, engine off" if chute_open else "Scientist: press C"
			col = UI.GREEN if chute_open else UI.YELLOW
			lamp = chute_open or fposmod(t, 0.5) < 0.3
		_:
			head = "FALLING" if vy > touch else "SAFE SPEED"
			sub = "brake in %d s" % ceili(burn_in) if burn_in < 60.0 else "wait for the light"
			col = UI.DIM if vy > touch else UI.GREEN
	var w: float = maxf(Pix.text_w(head, 20) + 34.0, Pix.text_w(sub, 10) + 34.0)
	_panel(Rect2(p, Vector2(w, 40)))
	# lamp
	front.draw_rect(Rect2(p + Vector2(7, 9), Vector2(14, 14)), Color("05070d"))
	front.draw_rect(Rect2(p + Vector2(8, 10), Vector2(12, 12)), col if lamp else col.darkened(0.7))
	if lamp:
		front.draw_rect(Rect2(p + Vector2(9, 11), Vector2(4, 3)), col.lightened(0.6))
	_text(p + Vector2(27, 24), head, 20, col if lamp or cue != "brake" else Color.WHITE)
	_text(p + Vector2(27, 35), sub, 10, UI.TEXT)
	# drift: an arrow that shows which way you slide, and which key stops it
	if absf(vx) > side_limit() * 0.3:
		var dir: float = signf(vx)
		var ap: Vector2 = Vector2(LX + 2.0 + dir * 50.0 - 4.0 + dir * floorf(fposmod(t * 2.0, 1.0) * 4.0), feet - 40.0)
		var acol: Color = Color.WHITE if absf(vx) <= side_limit() * 0.8 else (UI.RED if fposmod(t, 0.4) < 0.2 else Color.WHITE)
		if dir > 0.0:
			front.draw_texture(tex_arrow, ap, acol)
		else:
			front.draw_set_transform(ap + Vector2(8, 0), 0.0, Vector2(-1, 1))
			front.draw_texture(tex_arrow, Vector2.ZERO, acol)
			front.draw_set_transform(Vector2.ZERO)
	if drift_warn:
		var q: Vector2 = p + Vector2(0, 44)
		var s2: String = "TO STOP THE DRIFT"
		_panel(Rect2(q, Vector2(Pix.text_w("PRESS", 10) + Pix.text_w(s2, 10) + 38.0, 20)))
		_text(q + Vector2(7, 14), "PRESS", 10, UI.TEXT)
		var kx: float = q.x + 11.0 + Pix.text_w("PRESS", 10)
		kx += _key(Vector2(kx, q.y + 3.0), "<" if vx > 0.0 else ">") + 4.0
		_text(Vector2(kx, q.y + 14.0), s2, 10, UI.TEXT)

# ---------------------------------------------------------------- debug hooks (screenshots and the landing proof)

## Flies by obeying the cue lights only: engine while BRAKE is lit, steer while the drift warning is up.
func debug_autopilot() -> void:
	auto = true

## The same, but reacting 0.4 s late to every light, like a person.
func debug_human() -> void:
	auto = true
	auto_lag = 0.4

func debug_fast() -> void:
	Engine.time_scale = 4.0

## Mars with landing legs (4 m/s) in place of the example ship's airbags (12 m/s).
func debug_legs() -> void:
	touch = float(Data.PARTS["legs"]["touch"])
	mass -= float(Data.PARTS["airbags"]["mass"]) - float(Data.PARTS["legs"]["mass"])
	Game.run["calc"]["touch"] = touch

func debug_brake() -> void:
	vy = sqrt(vy * vy + 2.0 * g * alt0 * 0.6)
	alt = brake_alt(vy) - 2.0

func debug_near() -> void:
	t = 6.0
	alt = 13.0
	vy = touch * 0.5 + 3.0
	vx = 0.4
	hold_up = true

func debug_drift() -> void:
	vx = side_limit() * 1.6

func debug_crash() -> void:
	t = 6.0
	alt = 2.0
	vy = 30.0

func debug_touchdown() -> void:
	t = 6.0
	alt = 0.4
	vy = touch * 0.5
	vx = 0.0

func debug_burned() -> void:
	_burn_up()
