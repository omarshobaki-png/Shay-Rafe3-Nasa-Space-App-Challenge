extends Control
## Saturn: fly the sampling drone from the orbiter into the rings and back.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

const WORLD: float = 1800.0
const GSCALE: float = 2.2       # px per (m/s2): Saturn's 10.44 m/s2 pulls at 23 px/s2
const DOCK: Vector2 = Vector2(150, 118)

var t: float = 0.0
var state: String = "fly"
var end_t: float = 0.0
var pos: Vector2 = Vector2(150, 145)
var vel: Vector2 = Vector2.ZERO
var fuel: float = 45.0
var fuel_max: float = 45.0
var hp: int = 2
var hp_max: int = 2
var invuln: float = 0.0
var got: int = 0
var data: float = 0.0
var gb_sample: float = 0.0
var ice: Array = []
var rocks: Array = []
var msg: String = ""
var msg_t: float = 0.0
var thrusting: bool = false
var docked: bool = false
var tex_drone: Texture2D = null
var tex_orbiter: Texture2D = null
var tex_space: Texture2D = null
var tex_clouds: Texture2D = null
var tex_ring: Texture2D = null
var tex_rocks: Dictionary = {}
var hold: Dictionary = {}

func _ready() -> void:
	tex_drone = Pix.img("drone")
	tex_orbiter = Pix.img("orbiter")
	tex_space = Pix.img("bg_space")
	tex_clouds = Pix.img("saturn_clouds")
	tex_ring = Pix.img("ring_band")
	for dia: int in [12, 16, 20, 22]:
		tex_rocks[dia] = Pix.img("rock_ring_%d" % dia)
	if Game.tech.has("armor"):
		hp_max = 4
	hp = hp_max
	for id: String in Game.build:
		var p: Dictionary = Data.PARTS[id]
		if p["cat"] == "science" and not Game.run["broken"].has(id):
			gb_sample += float(p["gb"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2017
	for i: int in 34:
		ice.append({"p": Vector2(rng.randf_range(320, WORLD - 60), rng.randf_range(176, 230)), "taken": false})
	for i: int in 20:
		rocks.append({"p": Vector2(rng.randf_range(380, WORLD - 60), rng.randf_range(172, 234)), "r": rng.randf_range(6, 11), "ph": rng.randf() * TAU})
	if not Game.id_has("drone"):
		state = "nodrone"
		end_t = 4.0
		_say("No drone on board! Nothing can go into the rings.")
	var defs: Array = [["<", 8, "l"], [">", 52, "r"], ["THRUST", 96, "u"]]
	for d: Array in defs:
		var b: Button = Button.new()
		b.text = d[0]
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.6)
		add_child(b)
		b.position = Vector2(float(d[1]), 330)
		var key: String = d[2]
		b.button_down.connect(func() -> void: hold[key] = true)
		b.button_up.connect(func() -> void: hold.erase(key))

func _say(s: String) -> void:
	msg = s
	msg_t = 3.0

func _end(ok_dock: bool, text: String) -> void:
	if state != "fly":
		return
	state = "done"
	docked = ok_dock
	end_t = t + 3.0
	_say(text)
	Audio.loop("thrust", false)
	Audio.play("success" if ok_dock else "explosion", -2.0)

func _physics_process(delta: float) -> void:
	t += delta
	msg_t -= delta
	invuln -= delta
	if state != "fly":
		if t > end_t:
			set_physics_process(false)
			Game.probe_result(got, docked, data)
			Game.run["mode"] = "home"
			Game.goto("flight")
		return
	var g: float = float(Game.dest()["gravity"]) * GSCALE
	var up: bool = hold.has("u") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
	var lft: bool = hold.has("l") or Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var rgt: bool = hold.has("r") or Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	thrusting = up and fuel > 0.0
	Audio.loop("thrust", thrusting, -9.0)
	var acc: Vector2 = Vector2(0, g)
	if thrusting:
		acc.y -= g * 2.2
		fuel -= delta
	if fuel > 0.0:
		if lft:
			acc.x -= 55.0
			fuel -= delta * 0.3
		if rgt:
			acc.x += 55.0
			fuel -= delta * 0.3
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
		if not s["taken"] and pos.distance_to(s["p"]) < 16.0:
			s["taken"] = true
			got += 1
			Audio.play("pickup", -3.0, 1.0 + got * 0.06)
			data += gb_sample
			_say("Ice grain sample %d!" % got)
	# ring rocks
	if invuln <= 0.0:
		for r: Dictionary in rocks:
			var rp: Vector2 = _rock_pos(r)
			if pos.distance_to(rp) < float(r["r"]) + 5.0:
				hp -= 1
				Audio.play("hit")
				invuln = 1.0
				vel = (pos - rp).normalized() * 80.0
				if hp <= 0:
					_end(false, "DRONE SMASHED by a ring boulder.")
				else:
					_say("HIT! Hull %d/%d" % [hp, hp_max])
				break
	if pos.y > 330.0:
		_end(false, "LOST in Saturn's atmosphere. Crushed by the pressure.")
	# docking
	if pos.distance_to(DOCK + Vector2(0, 46)) < 22.0 and vel.length() < 60.0 and t > 3.0:
		_end(true, "DOCKED! Samples are safe on the orbiter.")

func _rock_pos(r: Dictionary) -> Vector2:
	var p: Vector2 = r["p"]
	return p + Vector2(sin(t * 0.6 + float(r["ph"])) * 14.0, 0)

func _process(_delta: float) -> void:
	queue_redraw()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(self, p, s, size, c)

func _rock_tex(r: float) -> Texture2D:
	var best: int = 12
	for dia: int in [12, 16, 20, 22]:
		if absf(dia - r * 2.0) < absf(best - r * 2.0):
			best = dia
	return tex_rocks[best]

func _draw() -> void:
	var cam: float = clampf(pos.x - 320.0, 0.0, WORLD - 640.0)
	Pix.tiled(self, tex_space, 0, cam * 0.1 + t * 1.5)
	Pix.stars(self, t, Vector2(640, 200), 40, 12, Vector2(-cam * 0.2, 0))
	# Saturn's cloud tops, curving away at the edges
	for i: int in 160:
		var sx: float = i * 4.0
		var wx: float = sx + cam
		var top: float = floorf(276.0 + pow((wx - WORLD * 0.5) / WORLD, 2) * 60.0)
		draw_texture_rect_region(tex_clouds, Rect2(sx, top, 4, 110), Rect2(fposmod(floorf(wx * 0.5 + t * 4.0), 640.0 - 4.0), 0, 4, 110))
		draw_rect(Rect2(sx, top - 3, 4, 3), Color(0.98, 0.9, 0.7, 0.18))
		draw_rect(Rect2(sx, top - 7, 4, 4), Color(0.98, 0.9, 0.7, 0.07))
	# the ring plane (A and B ring), with the gap Cassini dove through below it
	Pix.tiled(self, tex_ring, 166, cam)
	_text(Vector2(440, 254), "Ring gap (Cassini Grand Finale route)", 8, Color(1, 1, 1, 0.4))
	for sd: Dictionary in ice:
		if sd["taken"]:
			continue
		var p: Vector2 = sd["p"]
		var sp: Vector2 = (p - Vector2(cam, 0)).floor()
		if sp.x < -10 or sp.x > 650:
			continue
		var tw: float = 0.5 + 0.5 * sin(t * 6.0 + p.x)
		draw_rect(Rect2(sp - Vector2(1, 1), Vector2(3, 3)), Color(0.8, 0.95, 1.0))
		draw_rect(Rect2(sp, Vector2(1, 1)), Color.WHITE)
		draw_rect(Rect2(sp - Vector2(3, 0), Vector2(7, 1)), Color(0.8, 0.95, 1.0, tw * 0.7))
		draw_rect(Rect2(sp - Vector2(0, 3), Vector2(1, 7)), Color(0.8, 0.95, 1.0, tw * 0.7))
	for r: Dictionary in rocks:
		var rp: Vector2 = _rock_pos(r) - Vector2(cam, 0)
		if rp.x < -20 or rp.x > 660:
			continue
		Pix.sprite(self, _rock_tex(float(r["r"])), rp)
	# orbiter and its docking zone
	var dk: Vector2 = DOCK - Vector2(cam, 0)
	Pix.sprite(self, tex_orbiter, dk)
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_arc((dk + Vector2(0, 46)).floor(), 22.0, 0.0, TAU, 32, Color(UI.GREEN, 0.25 + 0.35 * pulse), 1.0)
	draw_rect(Rect2(dk.x - 6, dk.y + 22, 12, 1), Color(UI.GREEN, 0.5 + 0.5 * pulse))
	# drone
	if state != "nodrone":
		var dp: Vector2 = (pos - Vector2(cam, 0)).floor()
		if thrusting:
			var fl: float = floorf(4.0 + 4.0 * absf(sin(t * 50.0)) + randf() * 2.0)
			draw_rect(Rect2(dp.x - 2, dp.y + 6, 4, fl), UI.ORANGE)
			draw_rect(Rect2(dp.x - 1, dp.y + 6, 2, floorf(fl * 0.6)), UI.YELLOW)
		if invuln <= 0.0 or int(t * 12.0) % 2 == 0:
			Pix.sprite(self, tex_drone, dp)
	# HUD
	Pix.panel(self, Rect2(8, 8, 252, 82))
	_text(Vector2(15, 22), "SATURN SAMPLING DRONE", 11, UI.YELLOW)
	_text(Vector2(15, 37), "FUEL", 10, UI.TEXT)
	draw_rect(Rect2(48, 31, 204, 6), Color("0f1426"))
	draw_rect(Rect2(48, 31, floorf(204 * fuel / fuel_max), 6), UI.ORANGE)
	draw_rect(Rect2(48, 31, floorf(204 * fuel / fuel_max), 1), Color(1, 1, 1, 0.35))
	_text(Vector2(15, 51), "HULL %d/%d    SAMPLES %d / %d" % [hp, hp_max, got, int(Game.dest()["samples_goal"])], 10, UI.CYAN)
	_text(Vector2(15, 65), "GRAVITY 10.44 m/s2 (NASA): 1.06x Earth", 9, UI.TEXT)
	_text(Vector2(15, 79), "Grab ice, dodge rocks, fly back to the dock.", 9, UI.DIM)
	Pix.panel(self, Rect2(388, 8, 244, 58))
	Pix.para(self, Vector2(395, 21), "Saturn's rings are mostly water ice. In 2017 Cassini dived 22 times through the gap between the rings and Saturn. (NASA)", 232, UI.TEXT)
	Pix.text_c(self, 400, 322, "UP / W / SPACE = THRUST     LEFT / RIGHT = STEER", 8, UI.DIM)
	if msg_t > 0.0:
		Pix.text_c(self, 320, 130, msg, 12, UI.YELLOW)
