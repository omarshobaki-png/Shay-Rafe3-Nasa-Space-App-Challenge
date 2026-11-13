extends Control
## Landing minigame. Real gravity, rocket-equation fuel use, touchdown speed limits.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const GROUND_Y: float = 312.0
const HX: float = 0.5  # px per metre sideways

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
var mass: float = 1000.0
var touch: float = 3.0
var thrust_acc: float = 6.0
var ppm: float = 0.4
var thrusting: bool = false
var side: float = 0.0
var hold_up: bool = false
var hold_l: bool = false
var hold_r: bool = false
var tex: Texture2D = null
var tex_earth: Texture2D = null
var tex_far: Texture2D = null
var tex_mid: Texture2D = null
var tex_sky: Texture2D = null
var parts: Array = []
var shake: float = 0.0
var shake_off: Vector2 = Vector2.ZERO
var floor_mat: ShaderMaterial = null
var floor_rect: ColorRect = null
var front: Control = null
var msg: String = ""
var msg_col: Color = Color.WHITE

func _ready() -> void:
	var s: Dictionary = Game.landing_setup()
	var kind: String = "moon" if Game.dest_id == "moon" else "mars"
	tex = Pix.img("lander")
	tex_earth = Pix.planet(22, "earth")
	tex_far = Pix.img(kind + "_range_far")
	tex_mid = Pix.img(kind + "_range_near")
	if kind == "mars":
		tex_sky = Pix.img("mars_sky_day")
	# layers: this node draws sky and mountains; then the perspective floor; then the rest
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("floor_tex", Pix.img("floor_" + kind))
	floor_mat.set_shader_parameter("haze", Color("1c1d28") if kind == "moon" else Color("b07a56"))
	floor_mat.set_shader_parameter("haze_max", 0.75 if kind == "moon" else 0.9)
	floor_rect = ColorRect.new()
	floor_rect.material = floor_mat
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	front = Control.new()
	front.size = Vector2(640, 360)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)
	add_child(front)
	if bool(Game.run["dead"]):
		state = "burned"
		end_t = 3.5
		msg = "BURNED UP ON ENTRY"
		msg_col = UI.RED
		Audio.play("explosion", -4.0)
		return
	g = float(s["g"])
	alt = float(s["alt"])
	alt0 = alt
	vy = float(s["vy"])
	vx = float(s["vx"])
	prop = float(s["prop"])
	mass = float(s["mass"])
	touch = float(s["touch"])
	thrust_acc = maxf(2.5 * g, 6.0)  # game rule: engine sized to 2.5x local gravity
	ppm = 232.0 / alt0
	# touch buttons for mouse and touch screens
	var l: Button = _hold_button("<", 8, func(on: bool) -> void: hold_l = on)
	var r: Button = _hold_button(">", 52, func(on: bool) -> void: hold_r = on)
	var u: Button = _hold_button("THRUST", 96, func(on: bool) -> void: hold_up = on)
	u.size = Vector2(70, 26)
	l.size = Vector2(40, 26)
	r.size = Vector2(40, 26)

func _hold_button(txt: String, px: float, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.6)
	add_child(b)
	b.position = Vector2(px, 328)
	b.button_down.connect(cb.bind(true))
	b.button_up.connect(cb.bind(false))
	return b

func _particles(delta: float) -> void:
	var drag: float = 0.0 if Game.dest_id == "moon" else 1.8
	var lx: float = 320.0
	if thrusting and alt < 60.0:
		for i: int in 3:
			var dirx: float = -1.0 if randf() < 0.5 else 1.0
			parts.append({"p": Vector2(lx + randf_range(-4, 4), GROUND_Y - 1.0), "v": Vector2(dirx * randf_range(60, 160) * (1.0 - alt / 70.0), -randf_range(4, 30)), "life": 1.6, "c": 0})
	if thrusting:
		var ly: float = GROUND_Y - alt * ppm
		parts.append({"p": Vector2(lx + 2.0 + randf_range(-2, 2), ly - 6.0), "v": Vector2(randf_range(-6, 6), 60.0 + randf_range(0, 30)), "life": 0.35, "c": 1})
	for d: Dictionary in parts:
		var v: Vector2 = d["v"]
		if int(d["c"]) != 1:
			v.y += g * 12.0 * delta
		v *= 1.0 - drag * delta
		d["v"] = v
		d["p"] = Vector2(d["p"]) + v * delta
		d["life"] = float(d["life"]) - delta
	parts = parts.filter(func(d: Dictionary) -> bool: return float(d["life"]) > 0.0 and Vector2(d["p"]).y < GROUND_Y + 2.0)
	shake = maxf(0.0, shake - delta * 2.0)

func _boom() -> void:
	shake = 1.0
	Audio.play("explosion")
	var cols: Array = [UI.YELLOW, UI.ORANGE, UI.RED, Color("dcae44"), Color("b4bcc8"), Color("4e5566")]
	for i: int in 70:
		var a: float = randf_range(PI * 1.05, PI * 1.95)
		var sp: float = randf_range(30, 150)
		parts.append({"p": Vector2(320, GROUND_Y - 8.0), "v": Vector2(cos(a), sin(a)) * sp, "life": randf_range(1.0, 3.0), "c": 2 + (i % cols.size()), "col": cols[i % cols.size()]})

func _physics_process(delta: float) -> void:
	t += delta
	_particles(delta)
	if state != "fly":
		Audio.loop("thrust", false)
		if t > end_t:
			_leave()
		return
	var up: bool = hold_up or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
	var lft: bool = hold_l or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var rgt: bool = hold_r or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	thrusting = up and prop > 0.0
	Audio.loop("thrust", thrusting, -5.0)
	side = 0.0
	if prop > 0.0:
		if lft:
			side -= 1.5
		if rgt:
			side += 1.5
	var a_up: float = thrust_acc if thrusting else 0.0
	vy += (g - a_up) * delta
	vx += side * delta
	alt -= vy * delta
	x += vx * delta
	var ve: float = Data.ISP * Data.G0
	var burn: float = 0.0
	if thrusting:
		burn += mass * thrust_acc / ve * delta
	if side != 0.0:
		burn += mass * 1.5 / ve * delta
	burn = minf(burn, prop)
	prop -= burn
	mass -= burn
	if alt <= 0.0:
		alt = 0.0
		var ok: bool = vy <= touch and absf(vx) <= maxf(2.0, touch * 0.5)
		state = "landed" if ok else "crashed"
		end_t = t + 3.5
		Game.landing_result(ok, vy, prop)
		if ok:
			msg = "TOUCHDOWN!  %.1f m/s" % vy
			msg_col = UI.GREEN
			Audio.play("land")
			Audio.play("success", -4.0)
		else:
			msg = "CRASH  %.1f m/s down, %.1f m/s sideways" % [vy, absf(vx)]
			msg_col = UI.RED
			_boom()

func _leave() -> void:
	set_physics_process(false)
	if state == "landed":
		Game.goto("surface")
	else:
		Game.finish()
		Game.goto("report")

func _process(_delta: float) -> void:
	shake_off = (Vector2(randf_range(-2, 2), randf_range(-2, 2)) * shake * shake * 3.0).floor()
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

## The ground sits lower on screen while you are high up, and rises to meet you.
func _horizon() -> float:
	return floorf(236.0 + clampf(alt / maxf(1.0, alt0), 0.0, 1.0) * 100.0)

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(front, p, s, size, c)

func _draw() -> void:
	var moon: bool = Game.dest_id == "moon"
	var k: float = clampf(alt / maxf(1.0, alt0), 0.0, 1.0)
	draw_set_transform(shake_off)
	if moon:
		draw_rect(Rect2(-4, -4, 648, 368), Color("04050a"))
		Pix.stars(self, t, Vector2(640, 330), 110, 5)
		Pix.sprite(self, tex_earth, Vector2(540, 64))
	else:
		draw_texture(tex_sky, Vector2(0, -20.0 + k * 20.0))
		draw_rect(Rect2(-4, 278, 648, 90), Color("e8c090"))
	var hz: float = _horizon()
	var cam_x: float = x * HX
	Pix.tiled(self, tex_far, hz - tex_far.get_height() + 3, cam_x * 0.06)
	Pix.tiled(self, tex_mid, hz - tex_mid.get_height() + 2, cam_x * 0.16)
	draw_set_transform(Vector2.ZERO)

## Front layer: landing pad, lander, plume, debris, HUD.
func _draw_front() -> void:
	var moon: bool = Game.dest_id == "moon"
	var k: float = clampf(alt / maxf(1.0, alt0), 0.0, 1.0)
	var lane: float = _horizon() + 76.0
	front.draw_set_transform(shake_off)
	var gcol: Color = Color("8a8a99") if moon else Color("9e4a2a")
	# landing zone: a dashed ring lying on the floor
	for i: int in 56:
		if i % 2 == 0:
			var a: float = i * TAU / 56.0
			var pp: Vector2 = Vector2(322.0 + cos(a) * 52.0, lane + sin(a) * 5.0).floor()
			front.draw_rect(Rect2(pp, Vector2(2, 1)), Color(UI.YELLOW, 0.75))
	if state == "burned":
		var fy: float = t * 60.0
		for i: int in 6:
			var tail: float = i * 7.0
			front.draw_circle(Vector2(305 + sin(t * 30.0 + i) * 2.0, fy - tail), 6.0 - i * 0.8, [Color.WHITE, UI.YELLOW, UI.ORANGE, UI.ORANGE, UI.RED, Color("5a2414")][i])
		Pix.text_c(front, 320, 150, msg, 18, msg_col)
		front.draw_set_transform(Vector2.ZERO)
		return
	var feet: float = floorf(GROUND_Y - alt * ppm)
	var lx: float = 320.0
	if state != "crashed":
		# contact shadow: grows and darkens as the ground comes up
		var near: float = 1.0 - k
		for dy: int in range(-2, 3):
			var hw: float = floorf((20.0 + 26.0 * near) * sqrt(1.0 - pow(dy / 2.6, 2.0)))
			front.draw_rect(Rect2(lx + 6.0 - hw, lane + dy, hw * 2.0, 1), Color(0, 0, 0, 0.12 + 0.3 * near))
	# engine plume, dust, debris
	for d: Dictionary in parts:
		var dp: Vector2 = Vector2(d["p"]).floor()
		var life: float = float(d["life"])
		match int(d["c"]):
			0:
				front.draw_rect(Rect2(dp, Vector2(2, 1)), Color(gcol.lightened(0.2), clampf(life, 0.0, 1.0)))
			1:
				front.draw_rect(Rect2(dp, Vector2(2, 2)), Color(UI.ORANGE, life * 2.5))
			_:
				front.draw_rect(Rect2(dp, Vector2(2, 2)), Color(d["col"], clampf(life, 0.0, 1.0)))
	if state == "crashed":
		var e: float = clampf((t - (end_t - 3.5)) * 3.0, 0.0, 1.0)
		if e < 1.0:
			front.draw_circle(Vector2(320, GROUND_Y - 8), 10.0 + e * 40.0, Color(1, 0.9, 0.6, 1.0 - e))
		for i: int in 4:
			var sm: float = t * 6.0 + i * 9.0
			front.draw_circle(Vector2(312 + i * 6.0, GROUND_Y - 10 - fposmod(sm, 40.0)), 4.0 + fposmod(sm, 40.0) * 0.15, Color(0.2, 0.2, 0.24, 0.5))
	else:
		if thrusting:
			var fl: float = 12.0 + 7.0 * absf(sin(t * 47.0)) + randf() * 4.0
			var nz: Vector2 = Vector2(lx + 2, feet - 8)
			front.draw_rect(Rect2(nz.x - 4, nz.y, 8, floorf(fl)), UI.ORANGE)
			front.draw_rect(Rect2(nz.x - 3, nz.y, 6, floorf(fl * 0.7)), UI.YELLOW)
			front.draw_rect(Rect2(nz.x - 1, nz.y, 2, floorf(fl * 0.4)), Color.WHITE)
			if alt * ppm < 60.0:
				var pool: float = 1.0 - alt * ppm / 60.0
				front.draw_rect(Rect2(lx + 2 - 40 * pool, lane - 1, 80 * pool, 1), Color(UI.YELLOW, 0.5 * pool))
		if side < 0.0:
			front.draw_rect(Rect2(lx + 16, feet - 51, 4, 1), Color.WHITE)
			front.draw_rect(Rect2(lx + 20, feet - 51, 3, 1), Color(1, 1, 1, 0.5))
		elif side > 0.0:
			front.draw_rect(Rect2(lx - 19, feet - 51, 4, 1), Color.WHITE)
			front.draw_rect(Rect2(lx - 22, feet - 51, 3, 1), Color(1, 1, 1, 0.5))
		front.draw_texture(tex, Vector2(lx - 38, feet - 71))
	front.draw_set_transform(Vector2.ZERO)
	# HUD
	var safe: bool = vy <= touch
	Pix.panel(front, Rect2(8, 8, 214, 116))
	_text(Vector2(15, 22), "LANDING ON %s" % Game.place(), 11, UI.YELLOW)
	_text(Vector2(15, 37), "ALTITUDE   %s m" % Game.fmt(alt), 10, UI.TEXT)
	_text(Vector2(15, 51), "FALL SPEED %.1f m/s" % vy, 10, UI.GREEN if safe else UI.RED)
	_text(Vector2(15, 65), "SIDE SPEED %.1f m/s" % absf(vx), 10, UI.GREEN if absf(vx) <= maxf(2.0, touch * 0.5) else UI.RED)
	_text(Vector2(15, 79), "FUEL       %s kg" % Game.fmt(prop), 10, UI.ORANGE if prop > 0.0 else UI.RED)
	_text(Vector2(15, 93), "GRAVITY    %s m/s2 (NASA)" % str(g), 10, UI.CYAN)
	_text(Vector2(15, 107), "SAFE: under %.0f m/s" % touch, 9, UI.DIM)
	var fuel_frac: float = clampf(prop / maxf(1.0, prop + 200.0), 0.0, 1.0)
	front.draw_rect(Rect2(15, 112, 200, 4), Color("0f1426"))
	front.draw_rect(Rect2(15, 112, floorf(200 * fuel_frac), 4), UI.ORANGE)
	# altitude tape
	front.draw_rect(Rect2(616, 60, 6, 220), Color("0f1426"))
	front.draw_rect(Rect2(616, 60 + floorf(220 * (1.0 - k)), 6, 2), UI.YELLOW if safe else UI.RED)
	Pix.panel(front, Rect2(410, 8, 222, 46))
	var tip: String = "No air here: only your engine can slow you down." if moon else "Radio delay 4-24 min: real Mars landers fly themselves. Today YOU are the flight computer."
	Pix.para(front, Vector2(417, 21), tip, 210, UI.TEXT)
	Pix.text_c(front, 400, 322, "HOLD UP / W / SPACE = ENGINE     LEFT / RIGHT = STEER", 9, UI.DIM)
	if msg != "":
		Pix.text_c(front, 320, 170, msg, 16, msg_col)
	elif prop <= 0.0:
		Pix.text_c(front, 320, 170, "OUT OF FUEL!", 16, UI.RED)
