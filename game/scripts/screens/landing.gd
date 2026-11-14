extends Control
## Landing minigame on every "land" world. Real gravity, rocket-equation fuel use, touchdown limits from
## the build and the difficulty (Game.landing_setup()). The kind of air sets the physics:
##   none  (Moon, Mercury) the engine does all the braking;
##   thin  (Mars) the parachute is cut away, then a powered descent;
##   thick (Venus) the lander sinks at the terminal speed the core gives ("vterm"); the engine is hardly
##         needed and the job is to steer onto a flat slab before touchdown.
## Art is looked up by skin (SKIN). The HUD teaches: a BRAKE light from the real stopping distance with
## a countdown bar before it, three readouts (HEIGHT, SPEED with its green band, FUEL), one direction at a time.
## v6, simpler and shorter (game rules, physics unchanged):
##   - the descent starts LATER on the same real trajectory: the free fall (or the sink through thick air)
##     before it is skipped, so each landing lasts about 20-25 s (START_S); gravity, speeds, fuel stay real;
##   - one control, SPACE. Sideways drift is cancelled by the lander's computer except in thick air,
##     where steering onto the flat slab is the job;
##   - LANDING ASSIST on EASY and NORMAL (from Game.diff("landing_forgive")): while you hold SPACE after
##     BRAKE NOW the computer trims the engine to a safe touchdown, as real landers fly the last part.
##     On EASY it also brakes (and steers) by itself if you do nothing, and a hard touchdown only damages
##     the lander. HARD stays fully manual.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const GROUND_Y: float = 312.0
const LX: float = 320.0      # the lander stays in the middle; the ground slides under it
const SIDE_ACC: float = 2.5  # m/s2 from the side thrusters (game rule)
const REACT: float = 0.6     # s of pilot reaction time built into the BRAKE light at NORMAL (game rule)
const ZOOM: float = 0.6      # altitude -> screen exponent: the last metres get more of the screen
const TAPE_TOP: float = 62.0
const TAPE_H: float = 236.0
const X_DRAG: float = 0.35   # 1/s: thick air soaks up sideways speed (game rule)
const SLAB_X: float = -36.0  # m from the entry point to the flat slab, thick air (game rule)
const SLAB_R: float = 8.0    # m: half-width of the slab at NORMAL (game rule)
const OFF_SLAB_MIN: float = 20.0  # surface minutes lost levelling a lander that sits tilted on rough rock (game rule)
const START_S: float = 23.0  # s: target length of a correct landing; the fall before it is skipped (game rule)
const ENTRY_S: float = 3.5   # s the automatic entry stage is announced (heat shield, parachute)
const ASSIST_DEC: float = 0.7  # the assist brakes with 70% of the engine's spare thrust, leaving a margin
const DMG_SCORE: int = 10    # science points lost for a hard but survivable touchdown (game rule)
const PEBBLE_W: Array[int] = [6, 9, 14, 20, 30, 44]
const CRATER_W: Array[int] = [18, 26, 40, 64, 98]
const C_SAFE: Color = Color("1f7a3a")
const C_RISK: Color = Color("4a1a1e")
const C_INK: Color = Color("05070d")

## Art and colours per skin (research/v5/skins.md). "" = this world has no such layer.
const SKIN: Dictionary = {
	"moon": {"haze": "6c7088", "haze_max": 0.8, "fog": "6c7088", "dust": "c4c4d2", "fill": "04050a",
		"sky": "", "sun": "", "fx_sun": false, "body": "", "clouds": "", "sheet": "", "devil": "", "bolt": "",
		"earth": true, "stars": true, "long_shadow": false, "craters": 0.6, "boulders": 0,
		"pan_body": "141a2e", "pan_hi": "4a5c96"},
	"mercury": {"haze": "141210", "haze_max": 0.7, "fog": "4a443c", "dust": "a49684", "fill": "100e0b",
		"sky": "surface/mercury_sky_day", "sun": "surface/mercury_sun", "fx_sun": false, "body": "", "clouds": "",
		"sheet": "", "devil": "", "bolt": "", "earth": false, "stars": true, "long_shadow": true, "craters": 0.7,
		"boulders": 0, "pan_body": "16140f", "pan_hi": "7a6c58"},
	"venus": {"haze": "d8a650", "haze_max": 0.95, "fog": "d8a650", "dust": "c08848", "fill": "d8a650",
		"sky": "surface/venus_sky_day", "sun": "", "fx_sun": false, "body": "", "clouds": "surface/venus_cloud_%d",
		"sheet": "surface/venus_haze", "devil": "", "bolt": "surface/venus_lightning", "earth": false, "stars": false,
		"long_shadow": false, "craters": 0.15, "boulders": 9, "pan_body": "24120a", "pan_hi": "a0703a"},
	"mars": {"haze": "b06a48", "haze_max": 0.8, "fog": "b06a48", "dust": "e0a070", "fill": "e8c49c",
		"sky": "surface/mars_sky_day", "sun": "", "fx_sun": true, "body": "surface/phobos", "clouds": "surface/mars_cloud_%d",
		"sheet": "surface/dust_sheet", "devil": "surface/dust_devil", "bolt": "", "earth": false, "stars": false,
		"long_shadow": false, "craters": 0.3, "boulders": 0, "pan_body": "2a1410", "pan_hi": "8a5a3c"},
}

var state: String = "fly"     # fly | landed | crashed | burned
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
# the world
var skin: String = "moon"
var sk: Dictionary = {}
var air: String = "none"
var vterm: float = 0.0
var hx: float = 0.5           # screen px per metre sideways
var pad_x: float = 0.0        # m: the flat slab (thick air); elsewhere the target ring rides under the lander
var slab_r: float = SLAB_R
var forgive: float = 1.0
var react: float = REACT
var margin: float = REACT     # s of hesitation the BRAKE light allows for; the assist levels allow much more
var need_hull: bool = false
var hull_ok: bool = true
var crushed: bool = false
var on_slab: bool = true
# landing assist (difficulty): trims the engine while SPACE is held; on EASY also flies by itself
var assist: bool = false
var auto_assist: bool = false
var assist_on: bool = false   # latched once the assist has started braking
var assist_self: bool = false # EASY: the assist braked or steered without the player
var dmg_k: float = 1.0        # touchdowns up to touch * dmg_k damage the lander instead of destroying it
var lead: float = 3.0         # s of countdown before BRAKE NOW
var damaged: bool = false
var clock: float = 1.0        # descent clock speed-up (HARD only, on long braking); physics unchanged
# the braking cue
var cue: String = "fall"      # fall | soon | brake | assist | release | safe | empty
var brake: bool = false       # the BRAKE light is latched on until the speed is down
var burn_alt: float = -1.0    # where the next burn has to start if you just keep falling
var burn_in: float = 99.0     # seconds until then
var last_count: int = 9
var burns: int = 0
var vmax: float = 40.0
# directions: each stays until the player has done it
var eng_time: float = 0.0
var did_drift: bool = false
var did_green: bool = false
var did_slab: bool = false
var help_on: bool = false
# debug autopilot: obeys the cues and nothing else
var auto: bool = false
var auto_lag: float = 0.0
var auto_want: bool = false
var auto_since: float = -9.0
var auto_up: bool = false
var log_on: bool = false
# drawing
var tex: Texture2D = null
var tex_earth: Texture2D = null
var tex_halo: Texture2D = null
var tex_dist: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_sky: Texture2D = null
var tex_sun: Texture2D = null
var tex_body: Texture2D = null
var tex_cloud: Array[Texture2D] = []
var tex_devil: Texture2D = null
var tex_bolt: Texture2D = null
var tex_sheet: Texture2D = null
var tex_chute: Texture2D = null
var tex_shield: Texture2D = null
var tex_scorch: Texture2D = null
var tex_marker: Texture2D = null
var tex_arrow: Texture2D = null
var tex_drift: Texture2D = null
var tex_pebble: Array[Texture2D] = []
var tex_crater: Array[Texture2D] = []
var tex_boulder: Array[Texture2D] = []
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
var msg2: String = ""
var msg_bad: bool = false
var haze_tint: Color = Color.WHITE
var dust_col: Color = Color.WHITE
var pan_body: Color = Color("141a2e")
var pan_hi: Color = Color("4a5c96")
# thick air: far lightning and a hull that creaks
var bolt_t: float = 2.5
var bolt_x: float = 420.0
var thunder: bool = false
var creak_t: float = 3.0

func _ready() -> void:
	var s: Dictionary = Game.landing_setup()
	var d: Dictionary = Game.dest()
	skin = String(d["skin"])
	sk = SKIN.get(skin, SKIN["moon"])
	air = String(s["air"])
	vterm = float(s["vterm"])
	forgive = Game.diff("landing_forgive")
	react = REACT * forgive * forgive        # EASY gives a slower pilot more warning, HARD less
	slab_r = SLAB_R * forgive * forgive * (1.5 if forgive >= 1.0 else 1.0)
	assist = forgive >= 1.0                  # EASY and NORMAL
	auto_assist = forgive >= 1.2             # EASY
	dmg_k = 1.0 + clampf((forgive - 0.85) * 2.2, 0.0, 1.0)   # EASY 2x the limit, NORMAL 1.33x, HARD 1x
	margin = 2.2 * forgive if assist else react   # EASY 2.9 s, NORMAL 2.2 s of late press still lands; HARD 0.43 s
	lead = 5.0 * forgive                     # countdown before BRAKE NOW: EASY 6.5 s, NORMAL 5 s, HARD 4.3 s
	hx = 3.0 if air == "thick" else 0.5
	pad_x = SLAB_X if air == "thick" else 0.0
	need_hull = Game.has_hazard("pressure")
	hull_ok = not need_hull or Game.id_has("hull")
	tex = Pix.img("lander")
	if bool(sk["earth"]):
		tex_earth = Pix.planet(22, "earth")
		tex_halo = Pix.img("surface/earth_halo")
	tex_dist = Pix.img("surface/%s_range_dist" % skin)
	tex_far = Pix.img(skin + "_range_far")
	tex_mid = Pix.img(skin + "_range_near")
	tex_sky = _opt(sk["sky"])
	tex_sun = _opt(sk["sun"])
	tex_body = _opt(sk["body"])
	tex_devil = _opt(sk["devil"])
	tex_bolt = _opt(sk["bolt"])
	tex_sheet = _opt(sk["sheet"])
	if String(sk["clouds"]) != "":
		for i: int in 3:
			tex_cloud.append(Pix.img(String(sk["clouds"]) % i))
	tex_scorch = Pix.img("surface/scorch")
	tex_marker = Pix.img("surface/marker")
	tex_arrow = Pix.img("surface/arrow_r")
	tex_drift = Pix.img("surface/ic_drift")
	tex_chute = Pix.img("surface/chute")
	tex_shield = Pix.img("surface/heatshield")
	for i: int in PEBBLE_W.size():
		tex_pebble.append(Pix.img("pebble_%s_%d" % [skin, i]))
	for i: int in CRATER_W.size():
		tex_crater.append(Pix.img("surface/crater_%s_%d" % [skin, i]))
	tex_boulder = [Pix.img("boulder_%s_23" % skin), Pix.img("boulder_%s_50" % skin)]
	haze_tint = Color(String(sk["fog"]))
	dust_col = Color(String(sk["dust"]))
	pan_body = Color(String(sk["pan_body"]))
	pan_hi = Color(String(sk["pan_hi"]))
	has_chute = air == "thin" and Game.id_has("chute")
	has_shield = air != "none" and Game.id_has("heatshield")
	# layers: this node draws sky and mountains; then the perspective floor; then the rest
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + skin))
	floor_mat.set_shader_parameter("haze", Color(String(sk["haze"])))
	floor_mat.set_shader_parameter("haze_max", float(sk["haze_max"]))
	floor_rect = ColorRect.new()
	floor_rect.material = floor_mat
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	front = Control.new()
	front.size = Vector2(640, 360)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)
	add_child(front)
	_make_decor()
	var help: Button = UI.button("?", func() -> void: help_on = not help_on)
	help.focus_mode = Control.FOCUS_NONE
	help.tooltip_text = "Controls"
	add_child(help)
	help.position = Vector2(606, 322)
	help.size = Vector2(28, 32)
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
	_start_later()
	alt0 = alt
	if air == "thick":
		vmax = maxf(vterm, touch) * 1.6
	else:
		vmax = maxf(sqrt(vy * vy + 2.0 * g * alt0) * 0.75, touch * 4.0)
	# touch buttons only where there is a touch screen
	if DisplayServer.is_touchscreen_available():
		if air == "thick":
			_hold_button("<", Rect2(8, 280, 44, 30), func(on: bool) -> void: hold_l = on)
			_hold_button(">", Rect2(58, 280, 44, 30), func(on: bool) -> void: hold_r = on)
		else:
			_hold_button("BRAKE", Rect2(476, 270, 92, 40), func(on: bool) -> void: hold_up = on)

## v6: skip the start of the real descent so that a correct landing takes about START_S seconds.
## No air or thin air: fall freely (true gravity) until the BRAKE NOW light is `lead` + 2 s away, or
## less if the braking itself is long. Thick air: start lower on the same steady sink.
func _start_later() -> void:
	if air == "thick":
		alt = minf(alt, vterm * (START_S - 2.0))
		return
	var brake_s: float = impact_v() / ((thrust_acc - g) * ASSIST_DEC)   # rough length of the braking
	var want: float = clampf(START_S - brake_s, lead + 2.0, 14.0)      # seconds of fall to keep before BRAKE NOW
	var skip: float = _fall_to_brake(alt, vy) - want
	while skip > 0.0:
		vy += g * 0.05
		alt -= vy * 0.05
		skip -= 0.05
	# HARD flies by hand in several short burns, which takes longer: where the braking is long (Mars)
	# the descent clock runs up to 1.35x faster. Same physics, shown in real m/s and m.
	if not assist:
		clock = clampf(impact_v() / (thrust_acc - g) / 12.0, 1.0, 1.35)

## Seconds of free fall from (a, v) until BRAKE NOW comes on.
func _fall_to_brake(a: float, v: float) -> float:
	var tt: float = 0.0
	while tt < 90.0 and a > 0.0 and not _must_brake(a, v):
		v += g * 0.05
		a -= v * 0.05
		tt += 0.05
	return tt

## A texture by name, or null when the skin has none.
func _opt(name: String) -> Texture2D:
	if name == "" or not ResourceLoader.exists("res://art/%s.png" % name):
		return null
	return Pix.img(name)

## Craters, pebbles and (thick air) boulders on the plain, at many depths (s = 1 at the lane, larger = farther).
## The landing spot stays clear: under the lander, or the slab in thick air.
func _make_decor() -> void:
	var rd: RandomNumberGenerator = RandomNumberGenerator.new()
	rd.seed = hash(skin)
	var pad_px: float = pad_x * hx
	var clear_w: float = slab_r * hx + 50.0 if air == "thick" else 90.0
	for i: int in 90:
		var ds: float = exp(rd.randf_range(log(0.6), log(9.0)))
		var dx: float = rd.randf_range(-420.0, 420.0) * ds
		if ds > 0.75 and ds < 1.5 and absf(dx / ds - pad_px) < clear_w:
			continue
		var is_crater: bool = rd.randf() < float(sk["craters"])
		decor.append({"x": dx, "s": ds, "b": rd.randf_range(30.0, 110.0) if is_crater else rd.randf_range(8.0, 40.0), "c": is_crater, "k": -1})
	for i: int in int(sk["boulders"]):
		var ds: float = rd.randf_range(1.03, 1.7)
		var dx: float = rd.randf_range(-360.0, 300.0) * ds
		if absf(dx / ds - pad_px) < clear_w + 30.0:
			continue
		decor.append({"x": dx, "s": ds, "b": 0.0, "c": false, "k": rd.randi() % 2})
	decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))

func _hold_button(txt: String, r: Rect2, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	b.position = r.position
	b.size = r.size
	b.button_down.connect(cb.bind(true))
	b.button_up.connect(cb.bind(false))

func _unhandled_key_input(e: InputEvent) -> void:
	var k: InputEventKey = e as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode in [KEY_H, KEY_F1, KEY_SLASH]:
		help_on = not help_on
		Audio.play("ui_open" if help_on else "ui_close")

func _burn_up() -> void:
	state = "burned"
	end_t = t + 3.5
	msg = "BURNED UP ON ENTRY"
	msg2 = "No heat shield"
	msg_bad = true
	Audio.play("explosion", -4.0)

# ---------------------------------------------------------------- the braking cue

## Sideways speed the lander survives at touchdown (game rule; the difficulty widens or narrows it).
func side_limit() -> float:
	return maxf(3.0 * forgive, touch * 0.6)

## Speed the BRAKE light asks you to slow down to: half the limit, or less where gravity is strong,
## so that even `react` seconds of free fall after it stay under the limit.
func target_v() -> float:
	return maxf(touch * 0.25, minf(touch * 0.5, touch * 0.95 - g * react))

## Altitude where a full-thrust burn must start at fall speed `v` to reach the target speed at the
## ground: `margin` seconds of free fall (a person reacting to the light), then the stopping distance
## (v1*v1 - vt*vt) / (2 * (thrust_acc - g)).
func brake_alt(v: float) -> float:
	var v1: float = v + g * margin
	var vt: float = target_v()
	return maxf(0.0, v1 * v1 - vt * vt) / (2.0 * (thrust_acc - g)) + maxf(0.0, v) * margin + 0.5 * g * margin * margin

## Speed at the ground if the engine stays off from here. Thick air holds it at the terminal speed.
func impact_v() -> float:
	if air == "thick":
		return vterm
	return sqrt(maxf(0.0, vy * vy + 2.0 * g * alt))

func _must_brake(a: float, v: float) -> bool:
	return v > target_v() and a <= brake_alt(v)

func _update_cue() -> void:
	burn_alt = -1.0
	burn_in = 99.0
	if prop <= 0.0:
		brake = false
		cue = "empty"
		return
	var coast_ok: bool = impact_v() <= touch * (1.0 if air == "thick" else 0.85)
	if assist_on:
		cue = "assist"
		return
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
		burn_in = _fall_to_brake(alt, vy)
		cue = "release" if thrusting else ("soon" if burn_in < lead else "fall")
		var n: int = ceili(burn_in)
		if cue == "soon" and n < last_count and n <= 3:
			Audio.play("blip", -8.0, 1.0 + 0.15 * (3 - n))
		last_count = n if cue == "soon" else 9

## Engine acceleration the landing assist asks for: brake evenly to the BRAKE light's target speed at
## the ground, then hold that speed. Real landers fly this last part by computer.
func _assist_acc() -> float:
	var vt: float = target_v()
	if vy > vt:
		return clampf(g + (vy * vy - vt * vt) / (2.0 * maxf(alt, 0.5)), 0.0, thrust_acc)
	return clampf(g - (vt - vy) * 2.0, 0.0, thrust_acc)

## Which side jet the cue asks for: -1 left, 1 right, 0 none. Only thick air needs steering: onto the
## slab and stop there. Elsewhere the lander's computer cancels the drift by itself.
func steer_dir() -> int:
	if air != "thick":
		return 0
	var want: float = clampf((pad_x - x) * 0.25, -side_limit() * 0.7, side_limit() * 0.7)
	if absf(want - vx) > 0.6:
		return 1 if want > vx else -1
	return 0

# ---------------------------------------------------------------- directions (one at a time, design 8d.3)

## Latches the steps the player has done. A step is done by doing it, never by a timer.
func _update_steps() -> void:
	if eng_time >= 0.3 and vy <= touch:
		did_green = true
	if absf(x - pad_x) <= slab_r * 0.8:
		did_slab = true

## The one direction on screen: [line with [KEY] caps, a short reason]. Empty when there is none.
func _direction() -> PackedStringArray:
	if state != "fly":
		return PackedStringArray()
	if t < ENTRY_S and air == "thin":
		return PackedStringArray(["HEAT SHIELD AND PARACHUTE DONE THEIR JOB", "They took off most of your speed. Now the engine lands you."])
	if t < ENTRY_S and air == "thick":
		return PackedStringArray(["HEAT SHIELD OFF: THE THICK AIR SLOWS YOU", "No parachute or engine needed on Venus"])
	if air == "thick":
		var key: String = "<" if pad_x < x else ">"
		if assist_self:
			return PackedStringArray(["LANDING ASSIST IS STEERING YOU TO THE SLAB", "Press A or D to steer yourself"])
		if not on_slab_now():
			return PackedStringArray(["HOLD [%s] TO STEER OVER THE FLAT SLAB" % key, "Rough rock anywhere else tilts the lander"])
		return PackedStringArray(["STAY OVER THE SLAB: THE AIR LANDS YOU", "It holds you at a gentle %s m/s" % _f1(vterm)])
	if prop <= 0.0:
		return PackedStringArray(["OUT OF FUEL: NOTHING LEFT TO BRAKE WITH", "Next time, carry more propellant"])
	if assist_on:
		if assist_self:
			return PackedStringArray(["LANDING ASSIST IS BRAKING FOR YOU", "Hold SPACE next time to do it yourself"])
		return PackedStringArray(["KEEP HOLDING [SPACE] DOWN TO THE GROUND", "The computer sets the engine for a soft touchdown"])
	if cue == "brake":
		return PackedStringArray(["HOLD [SPACE] TO BRAKE", "Keep it on while it says BRAKE NOW"])
	if eng_time < 0.3 or assist:
		return PackedStringArray(["WAIT FOR BRAKE NOW, THEN HOLD [SPACE]", "You are falling: the engine will slow you down"])
	if not did_green or cue == "release":
		return PackedStringArray(["LET GO OF [SPACE] WHEN THE SPEED IS GREEN", "Safe touchdown speed: under %s m/s" % _f1(touch)])
	return PackedStringArray(["TOUCH DOWN WITH THE SPEED IN THE GREEN", "Hold SPACE again whenever it says BRAKE NOW"])

func _f1(v: float) -> String:
	return ("%.0f" % v) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v)

# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	t += delta
	_particles(delta)
	shake = maxf(0.0, shake - delta * 1.6)
	if state != "fly":
		Audio.loop("thrust", false)
		Audio.loop("rcs", false)
		if t > end_t:
			_leave()
		return
	if help_on:
		# the controls list pauses the descent
		Audio.loop("thrust", false)
		Audio.loop("rcs", false)
		return
	delta *= clock
	_update_cue()
	var up: bool = hold_up or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
	var lft: bool = hold_l or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var rgt: bool = hold_r or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	if auto:
		var want: bool = cue == "brake" or cue == "assist"
		if want != auto_want:
			auto_want = want
			auto_since = t
		if t - auto_since >= auto_lag:
			auto_up = auto_want
		up = auto_up
		var sd: int = steer_dir()
		lft = sd < 0
		rgt = sd > 0
	var a_up: float = 0.0
	if assist and prop > 0.0 and (cue == "brake" or assist_on) and (up or auto_assist):
		# landing assist: the computer sets the thrust; on EASY it does so even with no key held
		assist_self = not up
		assist_on = true
		a_up = _assist_acc()
	elif assist:
		assist_on = false
	elif up and prop > 0.0:
		a_up = thrust_acc
	thrusting = a_up > 0.0
	if thrusting:
		eng_time += delta
	Audio.loop("thrust", thrusting, -5.0)
	side = 0.0
	if prop > 0.0:
		if air != "thick":
			# the computer cancels any sideways drift with the side jets (a few seconds at most)
			side = -signf(vx) * minf(SIDE_ACC, absf(vx) / delta)
		elif lft or rgt:
			side = (SIDE_ACC if rgt else 0.0) - (SIDE_ACC if lft else 0.0)
			assist_self = false
		elif auto_assist and steer_dir() != 0:
			side = SIDE_ACC * steer_dir()
			assist_self = true
	Audio.loop("rcs", absf(side) > 0.5, -10.0)
	# thick air: drag grows with the square of the speed and balances gravity at the terminal speed
	var drag: float = g * vy * absf(vy) / (vterm * vterm) if air == "thick" else 0.0
	vy += (g - a_up - drag) * delta
	if air == "thick":
		vx += (side - vx * X_DRAG) * delta
	else:
		vx += side * delta
	alt -= vy * delta
	x += vx * delta
	var ve: float = Data.ISP * Data.G0
	var burn: float = 0.0
	burn += mass * (a_up + absf(side)) / ve * delta
	burn = minf(burn, prop)
	prop -= burn
	mass -= burn
	_update_steps()
	if air == "thick":
		_thick_air()
	if alt <= 0.0:
		_touchdown()

func _touchdown() -> void:
	alt = 0.0
	var ok: bool = vy <= touch and absf(vx) <= side_limit()
	# EASY and NORMAL: a touchdown a little too hard bends the lander instead of wrecking it (game rule)
	damaged = not ok and prop > 0.0 and vy <= touch * dmg_k and absf(vx) <= side_limit() * dmg_k
	ok = ok or damaged
	on_slab = air != "thick" or absf(x - pad_x) <= slab_r
	state = "landed" if ok else "crashed"
	end_t = t + 3.5
	thrusting = false
	side = 0.0
	Game.landing_result(ok, vy, prop)
	crushed = ok and bool(Game.run["dead"])
	if crushed:
		state = "crashed"
	elif damaged:
		Game.run["score_bonus"] = int(Game.run.get("score_bonus", 0)) - DMG_SCORE
		Game.note(false, "HARD LANDING at %.1f m/s (limit %s m/s): the lander is bent but works. -%d science (game rule)." % [vy, _f1(touch), DMG_SCORE])
	elif ok and not on_slab:
		# game rule: a tilted lander costs surface time (Venus: out of the minutes the heat allows)
		Game.run["minutes_lost"] = float(Game.run.get("minutes_lost", 0.0)) + OFF_SLAB_MIN
		Game.note(false, "Touched down on rough rock, tilted: %d minutes lost levelling the drill (game rule)." % int(OFF_SLAB_MIN))
	if auto or log_on:
		print("AUTOPILOT %s on %s (%s): limit %s m/s, touched at %.2f m/s down and %.2f m/s sideways (limit %.1f), %s, fuel left %.0f of %.0f kg, %d burns, %.0f s, lag %.2f s" % [
			"CRUSHED" if crushed else ("DAMAGED" if damaged else ("LANDED" if ok else "CRASHED")), Game.dest_id, Game.difficulty_name(), _f1(touch), vy, absf(vx),
			side_limit(), "on the slab" if on_slab else "OFF THE SLAB", prop, prop0, burns, t, auto_lag])
	if crushed:
		msg = "CRUSHED"
		msg2 = "No pressure hull: the air folded the lander"
		msg_bad = true
		shake = 0.6
		boom_t = t
		Audio.play("hit", -2.0, 0.5)
		_blow_dust(20, 0.8)
		_break_up()
	elif ok:
		msg = "HARD LANDING" if damaged else "TOUCHDOWN"
		msg2 = "%.1f m/s, limit %s m/s" % [vy, _f1(touch)] if on_slab else "On rough rock: %d minutes lost" % int(OFF_SLAB_MIN)
		if damaged:
			msg2 = "%.1f m/s: lander bent, still working" % vy
			msg_bad = true
		land_t = t
		shake = 0.25
		_blow_dust(26, 1.0)
		Audio.play("land")
		Audio.play("success", -4.0)
	else:
		msg = "CRASH"
		msg2 = "%.1f m/s down, %.1f m/s sideways" % [vy, absf(vx)]
		msg_bad = true
		_boom()

## Venus: far lightning in the clouds and a hull that groans under the pressure.
func _thick_air() -> void:
	if tex_bolt != null and t - bolt_t > 0.5:
		bolt_t = t + randf_range(2.5, 6.0)
		bolt_x = randf_range(170.0, 560.0)
		thunder = false
	if not thunder and t > bolt_t + 1.6:
		thunder = true
		Audio.play("land", -24.0, 0.45)   # far thunder: a low rumble
	if need_hull and t > creak_t:
		creak_t = t + (randf_range(2.5, 5.0) if hull_ok else randf_range(1.0, 2.0))
		Audio.play("hit", -18.0 if hull_ok else -10.0, randf_range(0.38, 0.5))
		shake = maxf(shake, 0.12 if hull_ok else 0.3)

func _leave() -> void:
	set_physics_process(false)
	if state == "landed":
		Game.goto("surface")
	else:
		Game.finish()
		Game.goto("report")

# ---------------------------------------------------------------- particles (drawn by the Fx kit)

## Dust blown outward along the ground. No air: it flies flat and fast on ballistic arcs. Thin air:
## it slows down and billows. Thick air: it barely gets going and hangs.
func _blow_dust(n: int, power: float) -> void:
	for i: int in n:
		var a: float = randf_range(0.0, TAU)
		var sp: float = randf_range(50.0, 170.0) * power * (0.5 if air == "thick" else 1.0)
		dust.append({"x": randf_range(-5.0, 5.0), "z": randf_range(-2.0, 2.0), "h": 0.0,
			"vx": cos(a) * sp, "vz": sin(a) * sp * 0.3, "vh": randf_range(6.0, 34.0) * power * (0.5 if air == "none" else 1.0),
			"age": 0.0, "life": randf_range(0.5, 1.3) * (1.6 if air == "thick" else 1.0), "size": 1 if i % 3 == 0 else 0})

func _particles(delta: float) -> void:
	var gap: float = _lane() - (_feet() - 8.0)   # nozzle to ground, in screen px
	if thrusting and gap < 80.0:
		_blow_dust(2, 1.0 - gap / 100.0)
	var damp: float = 0.0 if air == "none" else (2.2 if air == "thin" else 5.0)
	for d: Dictionary in dust:
		var vh: float = float(d["vh"]) - g * 14.0 * delta
		if damp > 0.0:
			d["vx"] = float(d["vx"]) * (1.0 - damp * delta)
			d["vz"] = float(d["vz"]) * (1.0 - damp * delta)
			vh += (26.0 if air == "thin" else 120.0) * delta
		d["vh"] = vh
		d["h"] = maxf(0.0, float(d["h"]) + vh * delta)
		d["x"] = float(d["x"]) + float(d["vx"]) * delta
		d["z"] = float(d["z"]) + float(d["vz"]) * delta
		d["age"] = float(d["age"]) + delta
	dust = dust.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["life"]))
	# wreck smoke needs air to rise in
	if state == "crashed" and not crushed and air != "none" and t - boom_t > 0.3 and randf() < 0.3:
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
	_break_up()

## The lander breaks into pieces of its own sprite.
func _break_up() -> void:
	var power: float = 0.35 if crushed else 1.0
	for i: int in 9:
		var src: Rect2 = Rect2(8 + (i % 3) * 22, 6 + (i / 3) * 22, 22, 22)
		var a: float = randf_range(PI * 1.1, PI * 1.9)
		debris.append({"src": src, "p": Vector2(LX - 30.0 + (i % 3) * 22.0, GROUND_Y - 60.0 + (i / 3) * 18.0),
			"v": Vector2(cos(a), sin(a)) * randf_range(40.0, 150.0) * power, "rest": GROUND_Y - 20.0 + randf_range(-3.0, 5.0)})

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
	floor_mat.set_shader_parameter("cam", floorf(x * hx))
	queue_redraw()
	front.queue_redraw()

# ---------------------------------------------------------------- back layer: sky and ranges

func _draw() -> void:
	var k: float = _k()
	var hz: float = _horizon()
	var cam_x: float = x * hx
	var sky_y: float = -20.0 + k * 20.0
	draw_set_transform(shake_off)
	draw_rect(Rect2(-4, -4, 648, 368), Color(String(sk["fill"])))
	if tex_sky != null:
		draw_texture(tex_sky, Vector2(0, sky_y))
	if bool(sk["stars"]):
		Pix.stars(self, t, Vector2(640, 300), 110 if tex_sky == null else 60, 5)
	if tex_earth != null:
		var ep: Vector2 = Vector2(476, 96.0 + k * 20.0)
		Pix.sprite(self, tex_halo, ep)
		Pix.sprite(self, tex_earth, ep)
	if tex_sun != null:
		# low over the pole, 2.5-3 times wider than from Earth, with a glare around it
		var sp: Vector2 = Vector2(200, 110.0 + k * 20.0)
		Fx.glow(self, sp, 64.0, Color(1.0, 0.92, 0.75, 0.22), true)
		Fx.glow(self, sp, 32.0, Color(1.0, 0.95, 0.85, 0.35), true)
		Pix.sprite(self, tex_sun, sp)
	if bool(sk["fx_sun"]):
		Fx.sun(self, Vector2(206, 70.0 + k * 20.0), 1, Color("fff0d8"))
	if tex_body != null:
		draw_texture(tex_body, Vector2(430, 52.0 + k * 20.0))
	for i: int in (5 if not tex_cloud.is_empty() else 0):
		var ct: Texture2D = tex_cloud[i % 3]
		var cx: float = fposmod(i * 173.0 + t * (2.0 + i % 2), 780.0) - 130.0
		draw_texture(ct, Vector2(floorf(cx), floorf(60.0 + i * 31.0 + k * 20.0)), Color(1, 1, 1, 0.7))
	Pix.tiled(self, tex_dist, hz - tex_dist.get_height() + 4, cam_x * 0.02)
	if tex_bolt != null:
		var age: float = t - bolt_t
		if age >= 0.0 and age < 0.4:
			# far lightning: bolt, fade, glow, then the empty frame
			var f: int = 0 if age < 0.07 else (1 if age < 0.17 else 2)
			if f == 0:
				draw_rect(Rect2(-4, -4, 648, hz), Color(1.0, 0.92, 0.75, 0.10))
			draw_texture_rect_region(tex_bolt, Rect2(floorf(bolt_x - cam_x * 0.04), hz - 92.0, 16, 34), Rect2(16 * f, 0, 16, 34))
	Pix.tiled(self, tex_far, hz - tex_far.get_height() + 3, cam_x * 0.06)
	if tex_devil != null:
		# a dust devil wandering across the far plain
		var dvx: float = fposmod(t * 6.0 + 380.0 - cam_x * 0.1, 760.0) - 60.0
		draw_texture_rect_region(tex_devil, Rect2(floorf(dvx), hz - 40.0, 16, 34), Rect2(16 * (int(t * 6.0) % 4), 0, 16, 34), Color(1, 1, 1, 0.8))
	Pix.tiled(self, tex_mid, hz - tex_mid.get_height() + 8, cam_x * 0.16)
	if tex_sheet != null:
		Pix.tiled(self, tex_sheet, hz - 16.0, cam_x * 0.2 - t * (9.0 if air == "thin" else 4.0), 640.0, Color(1, 1, 1, 0.8))
	if air == "thick":
		# the haze glows where the hot ground meets the sky
		Fx.glow(self, Vector2(320, hz - 4.0), 96.0, Color(1.0, 0.78, 0.42, 0.30))
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- front layer

func _decor(lane: float, near: bool) -> void:
	var hz: float = lane - 76.0
	var cam_x: float = x * hx
	var long: bool = bool(sk["long_shadow"])
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
		var fog: Color = Color.WHITE.lerp(haze_tint, clampf((s - 1.0) / 9.0, 0.0, 1.0) * 0.8)
		var want: float = float(d["b"]) / s
		if int(d["k"]) >= 0:
			var bt: Texture2D = tex_boulder[int(d["k"])]
			_shadow(sx + 4.0, sy, bt.get_width() * 1.1, 0.35, long)
			front.draw_texture(bt, Vector2(floorf(sx - bt.get_width() * 0.5), floorf(sy - bt.get_height() + 3)), fog)
		elif bool(d["c"]):
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
			if pi >= 2 or long:
				_shadow(sx + 3.0, sy, pt.get_width() * 0.9, 0.25, long)
			front.draw_texture(pt, Vector2(floorf(sx - pt.get_width() * 0.5), floorf(sy - pt.get_height() + 2)), fog)

## A contact shadow on the ground: a soft pixel ellipse, or with the Sun low on the horizon (long = true)
## a hard dark streak thrown away from it.
func _shadow(cx: float, y: float, w: float, a: float, long: bool = false) -> void:
	if long:
		var x0: float = floorf(cx - w * 0.45)
		front.draw_rect(Rect2(x0, floorf(y) - 1.0, floorf(w * 2.6), 2), Color(0, 0, 0, minf(0.75, a * 2.2)))
		front.draw_rect(Rect2(x0 + 2.0, floorf(y) + 1.0, floorf(w * 1.8), 1), Color(0, 0, 0, minf(0.6, a * 1.6)))
		return
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

## The landing target on the floor: a flat slab in thick air, a ring under the lander elsewhere.
func _draw_target(lane: float) -> void:
	if air == "thick":
		var cx: float = floorf(LX + 2.0 + (pad_x - x) * hx)
		var hw: float = floorf(slab_r * hx + 30.0)
		if cx + hw < -10.0 or cx - hw > 650.0:
			return
		for dy: int in range(-5, 6):
			var w: float = floorf(hw * sqrt(1.0 - pow(dy / 6.0, 2.0)))
			front.draw_rect(Rect2(cx - w, lane + dy, w * 2.0, 1), Color(1.0, 0.86, 0.6, 0.18 if dy < 0 else 0.10))
		var lit: bool = on_slab_now()
		if lane > 318.0 and state == "fly":
			# the ground is still below the screen: a pointer shows where the slab lies
			var px: float = clampf(cx, 24.0, 560.0)
			var bob: float = floorf(absf(sin(t * 4.0)) * 3.0)
			front.draw_texture(tex_marker, Vector2(px - 4.0, 296.0 + bob), UI.GREEN if lit else UI.YELLOW)
			Pix.text_oc(front, px, 292.0 + bob, "SLAB %s m" % Game.fmt(absf(pad_x - x)) if not lit else "SLAB", 10, UI.TEXT)
		for i: int in 64:
			if i % 2 == 0:
				var a: float = i * TAU / 64.0
				front.draw_rect(Rect2(Vector2(cx + cos(a) * hw, lane + sin(a) * 6.0).floor(), Vector2(2, 1)), Color(UI.GREEN if lit else UI.YELLOW, 0.85))
		return
	for i: int in 56:
		if i % 2 == 0:
			var a: float = i * TAU / 56.0
			front.draw_rect(Rect2(Vector2(LX + 2.0 + cos(a) * 56.0, lane + sin(a) * 6.0).floor(), Vector2(2, 1)), Color(UI.YELLOW, 0.6))

func on_slab_now() -> bool:
	return absf(x - pad_x) <= slab_r

func _draw_front() -> void:
	var lane: float = _lane()
	var feet: float = _feet()
	var gap: float = lane - feet
	front.draw_set_transform(shake_off)
	_decor(lane, false)
	if state == "burned":
		_draw_burned()
		front.draw_set_transform(Vector2.ZERO)
		_draw_msg()
		return
	_draw_target(lane)
	if state == "crashed" or state == "landed":
		front.draw_texture(tex_scorch, Vector2(LX - 34.0, lane - 8.0), Color(1, 1, 1, 0.0 if crushed else (1.0 if state == "crashed" else 0.45)))
	if state != "crashed":
		# contact shadow: grows and darkens as the ground comes up
		var near: float = clampf(1.0 - gap / 240.0, 0.0, 1.0)
		_shadow(LX + 6.0, lane, 40.0 + 52.0 * near, 0.1 + 0.32 * near, bool(sk["long_shadow"]))
		# where you will touch down if you do nothing about the drift
		var fall_t: float = alt / maxf(1.0, vterm) if air == "thick" else (-vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * alt))) / g
		var drift_m: float = vx / X_DRAG * (1.0 - exp(-X_DRAG * fall_t)) if air == "thick" else vx * fall_t
		var px: float = clampf(LX + drift_m * hx, 20.0, 620.0)
		if state == "fly" and air == "thick" and absf(px - LX) > 10.0:
			front.draw_texture(tex_marker, Vector2(floorf(px - 4.0), lane - 9.0 - floorf(absf(sin(t * 5.0)) * 3.0)))
	_draw_dust(lane, true)
	if state == "crashed":
		for d: Dictionary in debris:
			front.draw_texture_rect_region(tex, Rect2(Vector2(d["p"]).floor(), Vector2(22, 22)), d["src"], Color(0.7, 0.62, 0.55) if crushed else Color.WHITE)
		for d: Dictionary in smoke:
			Fx.puff(front, d["p"], float(d["age"]) / float(d["life"]), 2, Color("3a3440"))
		if not crushed:
			Fx.explosion(front, Vector2(LX, lane - 16.0), t - boom_t, 2, g * 12.0)
	else:
		_draw_lander(feet, lane)
	_draw_dust(lane, false)
	_decor(lane, true)
	front.draw_set_transform(Vector2.ZERO)
	if state == "crashed" and not crushed:
		Fx.flash(front, t - boom_t, 0.2, Color(1.0, 0.95, 0.85))
	_draw_hud()

func _draw_lander(feet: float, lane: float) -> void:
	# legs take the touchdown: a short squash, then back up
	var settle: float = 2.0 if t - land_t < 0.12 else 0.0
	var top: float = feet - 71.0 + settle
	if air != "none" and t < 4.0:
		# the build's entry hardware has done its job and drops away (already in the simulation)
		if has_shield:
			var sy: float = feet - 2.0 + maxf(0.0, t - 0.5) * 130.0
			front.draw_texture(tex_shield, Vector2(LX - 21.0 + maxf(0.0, t - 0.5) * 14.0, floorf(sy)))
		if has_chute:
			# rides above the lander for the first seconds, then is cut away
			var cut: float = maxf(0.0, t - 2.6)
			var cy: float = top - 44.0 - cut * cut * 160.0
			front.draw_texture(tex_chute, Vector2(floorf(LX - 27.0 - cut * 40.0 + sin(t * 3.0) * 2.0), floorf(cy)))
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
	if air == "thick":
		# hot air: the lander glows faintly on its lower edge
		Fx.glow(front, Vector2(LX + 2.0, top + 60.0), 24.0, Color(1.0, 0.55, 0.2, 0.25))
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

# ---------------------------------------------------------------- HUD (text colours: TEXT, DIM, RED)

func _text(p: Vector2, s: String, c: Color = UI.TEXT) -> void:
	Pix.text(front, p, s, 10, c)

## The shared HUD frame from the UI kit, tinted for the place.
func _panel(r: Rect2, accent: Color = Color(0, 0, 0, 0)) -> void:
	Pix.panel(front, r, pan_hi if accent.a == 0.0 else accent, Color(pan_body, 0.9))

## Sunken gauge well.
func _well(r: Rect2) -> void:
	front.draw_rect(r.grow(1.0), C_INK)
	front.draw_rect(r, Color("0d1120"))

## Three readouts, big and in plain words: HEIGHT, SPEED (with the green safe band), FUEL.
func _draw_hud() -> void:
	var safe: bool = vy <= touch
	_panel(Rect2(6, 6, 158, 124))
	# height
	_text(Vector2(14, 19), "HEIGHT", UI.DIM)
	var at: String = ("%d m" % roundi(alt)) if alt >= 10.0 else ("%.1f m" % alt)
	Pix.title(front, Vector2(14, 44), at, UI.TEXT, 2)
	# speed: the number, then a bar with the green band up to the safe limit (square-root scale)
	_text(Vector2(14, 60), "SPEED", UI.DIM)
	var lim: String = "SAFE UNDER %s" % _f1(touch)
	_text(Vector2(156.0 - Pix.text_w(lim, 10), 60), lim, UI.GREEN)
	var num: String = "%.1f" % maxf(0.0, vy)
	Pix.title(front, Vector2(14, 85), num, UI.GREEN if safe else UI.RED, 2)
	_text(Vector2(18.0 + Pix.title_w(num, 2), 85), "m/s", UI.DIM)
	var gr: Rect2 = Rect2(14, 89, 142, 12)
	Pix.frame(front, gr, "gauge_frame")
	var inner: Rect2 = gr.grow(-2)
	var safe_w: float = floorf(inner.size.x * sqrt(clampf(touch / vmax, 0.0, 1.0)))
	front.draw_rect(Rect2(inner.position, Vector2(safe_w, inner.size.y)), C_SAFE)
	front.draw_rect(Rect2(inner.position, Vector2(safe_w, 2)), UI.GREEN)
	front.draw_rect(Rect2(inner.position + Vector2(safe_w, 0), Vector2(inner.size.x - safe_w, inner.size.y)), C_RISK)
	var nx: float = inner.position.x + floorf((inner.size.x - 2.0) * sqrt(clampf(vy / vmax, 0.0, 1.0)))
	front.draw_rect(Rect2(nx - 1.0, gr.position.y - 2.0, 4, gr.size.y + 4.0), C_INK)
	front.draw_rect(Rect2(nx, gr.position.y - 1.0, 2, gr.size.y + 2.0), Color.WHITE)
	# fuel
	var frac: float = clampf(prop / prop0, 0.0, 1.0)
	_text(Vector2(14, 120), "FUEL", UI.DIM)
	Pix.gauge(front, Rect2(44, 112, 62, 8), frac, UI.ORANGE if frac > 0.2 else UI.RED)
	var fk: String = "%s kg" % Game.fmt(prop)
	_text(Vector2(156.0 - Pix.text_w(fk, 10), 120), fk, UI.TEXT if frac > 0.2 else UI.RED)
	if state == "fly":
		_draw_cue()
	_draw_direction()
	if help_on:
		_draw_help()
	_draw_msg()

func _draw_msg() -> void:
	if msg == "":
		return
	var mw: float = maxf(Pix.title_w(msg, 2), Pix.text_w(msg2, 10)) + 28.0
	var mh: float = 48.0 if msg2 != "" else 36.0
	_panel(Rect2(floorf(320.0 - mw / 2.0), 136, mw, mh), UI.RED if msg_bad else UI.GREEN)
	Pix.title_c(front, 320, 165, msg, UI.RED if msg_bad else UI.TEXT, 2)
	if msg2 != "":
		Pix.text_c(front, 320, 177, msg2, 10, UI.DIM)

## The one direction: a line with key caps for [KEY], and a short reason under it.
func _draw_direction() -> void:
	var dir: PackedStringArray = _direction()
	if dir.is_empty():
		return
	var parts: PackedStringArray = dir[0].replace("]", "[").split("[")
	var w: float = 0.0
	for i: int in parts.size():
		w += (maxf(13.0, Pix.text_w(parts[i], 10) + 7.0) + 2.0) if i % 2 == 1 else Pix.text_w(parts[i], 10)
	var r: Rect2 = Rect2(150, 318, 340, 36)
	_panel(r, UI.YELLOW)
	var px: float = floorf(r.position.x + (r.size.x - w) / 2.0)
	for i: int in parts.size():
		if i % 2 == 1:
			px += Pix.keycap(front, Vector2(px + 1.0, 322), parts[i]) + 2.0
		else:
			_text(Vector2(px, 332), parts[i])
			px += Pix.text_w(parts[i], 10)
	Pix.text_c(front, r.position.x + r.size.x / 2.0, 348, dir[1], 10, UI.DIM)

## The controls list behind the "?" button (H or F1). The descent waits while it is open.
func _draw_help() -> void:
	var r: Rect2 = Rect2(180, 104, 280, 86)
	_panel(r, UI.YELLOW)
	Pix.title(front, Vector2(192, 122), "CONTROLS", UI.TEXT)
	_text(Vector2(372, 121), "(paused)", UI.DIM)
	var rows: Array = [[["A", "D"], "steer onto the flat slab"]] if air == "thick" else [[["SPACE"], "BRAKE: slows your fall"]]
	rows.append([["H"], "show or hide this list"])
	var y: float = 132.0
	for row: Array in rows:
		var kx: float = 192.0
		for key: String in row[0]:
			kx += Pix.keycap(front, Vector2(kx, y), key) + 3.0
		_text(Vector2(262, y + 10.0), String(row[1]))
		y += 18.0
	_text(Vector2(192, y + 10.0), "Arrow keys work too.", UI.DIM)

## The big light that says what to do now, beside the lander where the eyes are. Before BRAKE NOW a
## bar counts down, so nobody is surprised.
func _draw_cue() -> void:
	var feet: float = _feet()
	var p: Vector2 = Vector2(374, clampf(feet - 70.0, 8.0, 230.0))
	var head: String = ""
	var sub: String = ""
	var lamp: Color = UI.DIM
	var hot: bool = false
	var blink: bool = true
	var bar: float = -1.0
	match cue:
		"brake":
			head = "BRAKE NOW"
			sub = "hold SPACE"
			lamp = UI.RED
			hot = true
			blink = fposmod(t, 0.3) < 0.18
		"assist":
			head = "LANDING ASSIST"
			sub = "braking for you" if assist_self else "keep holding SPACE"
			lamp = UI.GREEN
		"release":
			head = "LET GO"
			sub = "slow enough: save fuel"
			lamp = UI.YELLOW
		"safe":
			head = "SAFE SPEED"
			sub = "under the limit"
			lamp = UI.GREEN
		"soon":
			head = "BRAKE IN %d" % maxi(1, ceili(burn_in))
			sub = "get ready to hold SPACE"
			lamp = UI.YELLOW
			blink = fposmod(burn_in, 1.0) > 0.5
			bar = clampf(burn_in / lead, 0.0, 1.0)
		"empty":
			head = "NO FUEL"
			sub = "nothing left to brake with"
			lamp = UI.RED
			hot = true
		_:
			head = "FALLING"
			sub = "BRAKE NOW comes in %d s" % ceili(burn_in) if burn_in < 60.0 else "wait for BRAKE NOW"
	if air == "thick":
		var over: bool = on_slab_now()
		head = "OVER THE SLAB" if over else "OVER ROUGH ROCK"
		sub = "sinking at %s m/s" % ("%.1f" % vy)
		lamp = UI.GREEN if over else UI.YELLOW
		hot = false
		blink = true
	if not hull_ok:
		head = "NO HULL"
		sub = "the air will crush it"
		lamp = UI.RED
		hot = true
		blink = fposmod(t, 0.5) < 0.3
	var sc: int = 2 if Pix.title_w(head, 2) <= 214.0 else 1   # big, unless it would reach over the lander
	var w: float = maxf(Pix.title_w(head, sc), Pix.text_w(sub, 10)) + 40.0
	var h: float = 48.0 if bar < 0.0 else 58.0
	p.x = minf(p.x, 634.0 - w)
	_panel(Rect2(p, Vector2(w, h)), UI.RED if hot else (UI.GREEN if cue == "assist" else Color(0, 0, 0, 0)))
	front.draw_rect(Rect2(p + Vector2(8, 10), Vector2(18, 18)), C_INK)
	front.draw_rect(Rect2(p + Vector2(9, 11), Vector2(16, 16)), lamp if blink else lamp.darkened(0.7))
	if blink:
		front.draw_rect(Rect2(p + Vector2(10, 12), Vector2(5, 4)), lamp.lightened(0.6))
	Pix.title(front, p + Vector2(32, 26 if sc == 2 else 23), head, UI.RED if hot else UI.TEXT, sc)
	_text(p + Vector2(32, 41), sub, UI.DIM)
	if bar >= 0.0:
		# the countdown: the bar empties as BRAKE NOW comes closer
		var br: Rect2 = Rect2(p + Vector2(8, 46), Vector2(w - 16.0, 6))
		_well(br)
		front.draw_rect(Rect2(br.position, Vector2(floorf(br.size.x * bar), br.size.y)), UI.YELLOW)

# ---------------------------------------------------------------- debug hooks (screenshots and the landing proof)

## Flies by obeying the cues only: engine while BRAKE NOW is lit, the side jet the cue asks for.
func debug_autopilot() -> void:
	auto = true

## The same, but reacting 0.4 s late to every light, like a person.
func debug_human() -> void:
	auto = true
	auto_lag = 0.4

## A first-timer who holds SPACE from the very start and never lets go.
func debug_hold() -> void:
	hold_up = true
	log_on = true

## A first-timer who presses nothing at all.
func debug_idle() -> void:
	log_on = true

## A slow first-timer: presses SPACE 1.5 s after every light.
func debug_late() -> void:
	auto = true
	auto_lag = 1.5

func debug_fast() -> void:
	Engine.time_scale = 4.0

func debug_help() -> void:
	help_on = true

## Mars with landing legs (4 m/s) in place of the example ship's airbags (12 m/s).
func debug_legs() -> void:
	touch = float(Data.PARTS["legs"]["touch"]) * forgive
	Game.run["calc"]["touch"] = touch

## Falling fast, just above where BRAKE NOW comes on.
func debug_brake() -> void:
	if air == "thick":
		return
	t = 4.0
	vy = sqrt(vy * vy + 2.0 * g * alt0 * 0.6)
	alt = brake_alt(vy) - 2.0
	did_drift = true

## Near the ground with the engine on.
func debug_near() -> void:
	t = 6.0
	alt = 13.0
	vy = touch * 0.5 + 3.0 if air != "thick" else vterm
	vx = 0.4
	x = pad_x + 2.0 if air == "thick" else 0.0
	hold_up = air != "thick"
	did_drift = true
	eng_time = 1.0

func debug_drift() -> void:
	vx = side_limit() * 1.6

## A touchdown a little too hard: damaged on EASY and NORMAL, a crash on HARD.
func debug_hard() -> void:
	debug_touchdown()
	vy = touch * 1.25

func debug_crash() -> void:
	t = 6.0
	alt = 2.0
	vy = maxf(30.0, touch * 3.0)
	if air == "thick":
		vterm = vy   # pretend the drag plate failed, so the fall is fast enough to crash

func debug_touchdown() -> void:
	t = 6.0
	alt = 0.4
	vy = touch * 0.5 if air != "thick" else vterm
	vx = 0.0
	x = pad_x

## Thick air: halfway down, drifting off the slab.
func debug_descent() -> void:
	t = 8.0
	alt = alt0 * 0.55
	x = pad_x + 18.0
	vx = 1.5

## Thin air with the parachute still out (the first second of the descent).
func debug_chute() -> void:
	t = 1.2

## Thick air with no pressure hull on board.
func debug_nohull() -> void:
	Game.build.erase("hull")
	hull_ok = not need_hull

## Thick air: about to touch down on rough rock beside the slab.
func debug_offslab() -> void:
	debug_touchdown()
	x = pad_x + slab_r + 14.0

## The descent tuned for a moment in the far lightning.
func debug_bolt() -> void:
	bolt_t = t + 0.45

func debug_burned() -> void:
	_burn_up()
