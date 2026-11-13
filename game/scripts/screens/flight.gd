extends Control
## Launch, cruise map, orbit arrival (mode "out") and the trip home / data downlink (mode "home").

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

const W: float = 430.0

var stage: String = ""
var st: float = 0.0
var t: float = 0.0
var did: Dictionary = {}
var log_box: VBoxContainer = null
var scroll: ScrollContainer = null
var shown: int = 0
var pending_scroll: int = 0
var info: Label = null
var tex_earth: Texture2D = null
var tex_earth_big: Texture2D = null
var tex_dest: Texture2D = null
var tex_dest_mid: Texture2D = null
var tex_dest_big: Texture2D = null
var tex_dest_home: Texture2D = null
var tex_orbiter: Texture2D = null
var tex_space: Texture2D = null
var tex_rocket: Texture2D = null
var tex_sky: Texture2D = null
var tex_ground: Texture2D = null
var tex_tower: Texture2D = null
var tex_clouds: Array = []

func _ready() -> void:
	clip_contents = true
	var right: PanelContainer = UI.panel()
	add_child(right)
	UI.place(right, 436, 6, 198, 348)
	var rv: VBoxContainer = UI.vbox(3)
	right.add_child(rv)
	rv.add_child(UI.label("MISSION LOG", 11, UI.CYAN))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	log_box = UI.vbox(4)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_box)
	rv.add_child(UI.label("Hold SPACE to speed up", 8, UI.DIM))
	info = UI.label("", 9, UI.TEXT)
	add_child(info)
	UI.place(info, 8, 340, 420, 14)
	tex_earth = Pix.planet(9, "earth")
	tex_earth_big = Pix.planet(22, "earth")
	tex_dest = Pix.planet(9 if Game.dest_id != "saturn" else 12, Game.dest_id)
	tex_dest_mid = Pix.planet(12, Game.dest_id)
	tex_dest_big = Pix.planet(60, Game.dest_id)
	tex_dest_home = Pix.planet(36, Game.dest_id)
	tex_orbiter = Pix.img("orbiter")
	tex_space = Pix.img("bg_space")
	tex_rocket = Pix.img("rocket")
	tex_sky = Pix.img("launch_sky")
	tex_ground = Pix.img("launch_ground")
	tex_tower = Pix.img("tower")
	for i: int in 3:
		tex_clouds.append(Pix.img("cloud_%d" % i))
	_set_stage("launch" if Game.run.get("mode", "out") == "out" else "home")

func _set_stage(s: String) -> void:
	stage = s
	st = 0.0
	did = {}

func _dead() -> bool:
	return bool(Game.run["dead"])

func _process(delta: float) -> void:
	var dt: float = delta * (4.0 if Input.is_key_pressed(KEY_SPACE) else 1.0)
	t += dt
	st += dt
	match stage:
		"launch":
			if st > 0.6 and not did.has("snd"):
				did["snd"] = true
				Audio.play("launch", -2.0)
			if st > 2.6 and _dead() and not did.has("boom"):
				did["boom"] = true
				Audio.play("explosion")
			if st > 1.2 and not did.has("p"):
				did["p"] = true
				Game.phase_launch()
			if st > 5.0:
				_next("cruise")
		"cruise":
			if st > 2.0 and not did.has("p"):
				did["p"] = true
				Game.phase_cruise()
				if not Game.run["storm"].is_empty():
					Audio.play("alarm", -6.0)
			if st > 6.5:
				_next("arrive")
		"arrive":
			Audio.loop("thrust", st < 0.9 and not _dead(), -8.0)
			if st > 0.6 and not did.has("p"):
				did["p"] = true
				Game.phase_arrive()
			if st > 3.5:
				if _dead():
					_end()
				else:
					Game.goto("probe" if Game.dest_id == "saturn" else "landing")
		"home":
			if st > 0.5 and not did.has("p"):
				did["p"] = true
				Game.phase_home()
			if st > 7.0:
				_end()
	_update_log()
	var r: Dictionary = Game.run
	info.text = "FUEL %s kg    MASS %s kg    BATTERY %d%%" % [Game.fmt(r["prop"]), Game.fmt(r["mass"]), roundi(100.0 * float(r["battery"]) / maxf(1.0, float(r["wh"])))]
	queue_redraw()

func _next(s: String) -> void:
	if _dead():
		_end()
	else:
		_set_stage(s)

func _end() -> void:
	Game.finish()
	Game.goto("report")

func _update_log() -> void:
	var lg: Array = Game.run["log"]
	while shown < lg.size():
		var e: Dictionary = lg[shown]
		var ok: bool = e["ok"]
		log_box.add_child(UI.wrap_label(("OK  " if ok else "!!  ") + String(e["text"]), 9, UI.GREEN if ok else UI.RED, 180))
		Audio.play("blip" if ok else "error", -8.0 if ok else -4.0)
		shown += 1
		pending_scroll = 3
	if pending_scroll > 0:
		pending_scroll -= 1
		scroll.scroll_vertical = 100000

# ------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	match stage:
		"launch":
			_draw_launch()
		"cruise":
			_draw_cruise()
		"arrive":
			_draw_arrive()
		"home":
			_draw_home()

func _text(p: Vector2, s: String, size: int, c: Color) -> void:
	Pix.text(self, p, s, size, c)

func _planet(tex: Texture2D, center: Vector2) -> void:
	Pix.sprite(self, tex, center)

func _space(seed_n: int) -> void:
	Pix.tiled(self, tex_space, 0, t * 2.0, W)
	Pix.stars(self, t, Vector2(W, 360), 40, seed_n)

## p = nozzle centre (x) and the bottom of the rocket (y).
func _draw_rocket(p: Vector2, flame: bool, max_fl: float = 999.0) -> void:
	var x: float = floorf(p.x)
	var b: float = floorf(p.y)
	if flame:
		var fl: float = minf(22.0 + 12.0 * absf(sin(t * 40.0)) + randf() * 5.0, max_fl)
		draw_rect(Rect2(x - 7, b - 1, 14, floorf(fl)), UI.ORANGE)
		draw_rect(Rect2(x - 5, b - 1, 10, floorf(fl * 0.75)), UI.YELLOW)
		draw_rect(Rect2(x - 2, b - 1, 4, floorf(fl * 0.45)), Color.WHITE)
		for k: int in 2:
			draw_rect(Rect2(x - 3, b + 6 + k * 8, 6, 2), Color(1, 1, 0.9, 0.7))
	draw_texture(tex_rocket, Vector2(x - 14, b - 193))

func _draw_launch() -> void:
	var failed: bool = did.has("p") and _dead()
	var rt: float = maxf(0.0, st - 1.0)
	var h: float = 18.0 * rt * rt
	if failed:
		h = minf(12.0 * rt, 30.0)
	var sky_k: float = clampf(h / 500.0, 0.0, 1.0)
	draw_texture(tex_sky, Vector2.ZERO)
	if sky_k > 0.0:
		Pix.tiled(self, tex_space, 0, 0, W, Color(1, 1, 1, sky_k))
	if sky_k > 0.3:
		Pix.stars(self, t, Vector2(W, 360), 50, 9)
	var cam: float = maxf(0.0, h - 120.0)
	var gy: float = floorf(300.0 + cam)
	for i: int in 6:
		var cy: float = fposmod(70.0 * i + cam * 0.8, 600.0) - 120.0
		var cx: float = float((30 + i * 131) % 400) - 20.0
		draw_texture(tex_clouds[i % 3], Vector2(floorf(cx), floorf(cy)), Color(1, 1, 1, 0.9 * (1.0 - sky_k)))
	if gy < 400:
		draw_texture(tex_ground, Vector2(0, gy - 26))
		draw_texture(tex_tower, Vector2(166, gy - tex_tower.get_height()))
	var rx: float = 200.0
	var rb: float = 300.0 - minf(h, 120.0)
	if failed and st > 2.6:
		var e: float = (st - 2.6) * 50.0
		for i: int in 5:
			var col: Color = [UI.YELLOW, UI.ORANGE, UI.RED, Color("606878"), Color("303850")][i]
			draw_circle(Vector2(rx + sin(i * 2.1) * e * 0.4, rb - 30 + cos(i * 1.7) * e * 0.3), maxf(2.0, e * (0.5 - i * 0.07)), col)
		Pix.text_c(self, W / 2.0, 120, "LAUNCH FAILED", 20, UI.RED)
	else:
		if st > 0.6:
			# exhaust billowing out sideways from the pad, then a trail behind the climbing rocket
			for i: int in 16:
				var a: float = fposmod(t * 0.7 + i / 16.0, 1.0)
				var sdir: float = -1.0 if i % 2 == 0 else 1.0
				var pc: Vector2 = Vector2(rx + sdir * (8.0 + 90.0 * a) + sin(i * 3.0) * 6.0, gy - 5.0 - a * 18.0)
				draw_circle(pc.floor(), 4.0 + 13.0 * a, Color(0.92, 0.92, 0.95, 0.55 * (1.0 - a)))
				draw_circle((pc + Vector2(-2, -2)).floor(), 2.0 + 9.0 * a, Color(1, 1, 1, 0.4 * (1.0 - a)))
			for i: int in 24:
				var q: float = i / 24.0
				var ty: float = rb + 14.0 + q * (gy - rb - 14.0)
				if ty < rb + 12.0:
					continue
				draw_circle(Vector2(rx + sin(i * 1.7 + t) * 2.0 * q, ty).floor(), 3.0 + q * 7.0, Color(0.9, 0.9, 0.95, 0.45 * (1.0 - q)))
		_draw_rocket(Vector2(rx, rb), st > 0.6, maxf(3.0, gy - rb + 1.0))
	var rk: Dictionary = Data.ROCKETS[Game.rocket_id]
	Pix.panel(self, Rect2(6, 6, 240, 40))
	_text(Vector2(13, 20), "T+%02d s   %s" % [int(maxf(0.0, st - 1.0) * 12), rk["name"]], 12, UI.TEXT)
	if st < 1.0:
		_text(Vector2(13, 36), "IGNITION", 12, UI.YELLOW)
	elif not failed:
		_text(Vector2(13, 36), "LIFTOFF!  ALT %s km" % Game.fmt(h * 0.2), 12, UI.GREEN)

func _hohmann_pos(center: Vector2, re: float, rd: float, th: float) -> Vector2:
	var a: float = (re + rd) / 2.0
	var e: float = (rd - re) / (rd + re)
	var r: float = a * (1.0 - e * e) / (1.0 + e * cos(th))
	return center + Vector2(cos(th), -sin(th)) * r

func _dotted_circle(c: Vector2, r: float, col: Color) -> void:
	var n: int = int(r * 0.9)
	for i: int in n:
		var a: float = TAU * i / n
		draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * r).floor(), Vector2(1, 1)), col)

func _draw_cruise() -> void:
	_space(21)
	var tr: Dictionary = Game.traj()
	var days: float = float(tr["days"])
	var p: float = clampf(st / 6.0, 0.0, 1.0)
	var lost: bool = did.has("p") and _dead()
	if lost:
		p = clampf(2.0 / 6.0, 0.0, 1.0)
	var ship: Vector2
	if Game.dest_id == "moon":
		var e: Vector2 = Vector2(90, 190)
		var m: Vector2 = Vector2(340, 170)
		_planet(tex_earth_big, e)
		_planet(tex_dest_mid, m)
		_dotted_circle(e, 250.0, Color(1, 1, 1, 0.15))
		var c: Vector2 = Vector2(215, 60) if tr["id"] == "direct" else Vector2(215, -40)
		for i: int in 40:
			var q: float = i / 40.0
			if q > p:
				break
			var pt: Vector2 = e.lerp(c, q).lerp(c.lerp(m, q), q)
			draw_rect(Rect2(pt.floor(), Vector2(1, 1)), UI.CYAN)
		ship = e.lerp(c, p).lerp(c.lerp(m, p), p)
	else:
		var sun: Vector2 = Vector2(215, 185)
		var re: float = 45.0
		var rd: float = 90.0 if Game.dest_id == "mars" else 150.0
		var period: float = 687.0 if Game.dest_id == "mars" else 10759.0
		draw_circle(sun, 22.0, Color(1, 0.7, 0.3, 0.08))
		draw_circle(sun, 15.0, Color(1, 0.75, 0.35, 0.16))
		for i: int in 4:
			draw_circle(sun, 10.0 - i * 2.0, [Color("ff9f43"), Color("ffb84d"), Color("ffd75e"), Color("fff3b0")][i])
		_dotted_circle(sun, re, Color(0.3, 0.6, 1.0, 0.5))
		_dotted_circle(sun, rd, Color(1, 0.8, 0.5, 0.4))
		var day: float = p * days
		var ea: float = day * TAU / 365.0
		_planet(tex_earth, sun + Vector2(cos(ea), -sin(ea)) * re)
		var da: float = PI - (days - day) * TAU / period
		_planet(tex_dest, sun + Vector2(cos(da), -sin(da)) * rd)
		for i: int in 60:
			var th: float = PI * i / 60.0
			if th > PI * p:
				break
			draw_rect(Rect2(_hohmann_pos(sun, re, rd, th).floor(), Vector2(1, 1)), UI.CYAN)
		ship = _hohmann_pos(sun, re, rd, PI * p)
		if tr["id"] == "assist":
			_text(Vector2(10, 330), "Flybys: Venus, Venus, Earth, Jupiter (like Cassini)", 9, UI.DIM)
		if did.has("p") and not Game.run["storm"].is_empty() and st < 4.5:
			var k: float = (st - 2.0) * 90.0
			draw_arc(sun, k, 0.0, TAU, 48, Color(1, 0.85, 0.3, clampf(1.0 - k / 220.0, 0.0, 1.0)), 2.0)
	if lost and int(t * 4.0) % 2 == 0:
		_text(ship + Vector2(-30, -10), "SIGNAL LOST", 10, UI.RED)
	else:
		draw_rect(Rect2(ship.floor() - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
		draw_rect(Rect2(ship.floor() - Vector2(1, 1), Vector2(3, 3)), UI.CYAN)
	_text(Vector2(10, 22), "CRUISE  DAY %s of %s" % [Game.fmt(int(p * days)), Game.fmt(days)], 12, UI.TEXT)
	_text(Vector2(10, 38), String(tr["name"]), 9, UI.DIM)
	if did.has("p") and not Game.run["storm"].is_empty() and st < 5.0:
		var ev: Dictionary = Game.run["storm"]
		_text(Vector2(10, 54), "SOLAR STORM %s (Kp %s)  -  NASA DONKI" % [ev["time"], str(ev["kp"])], 9, UI.YELLOW)

func _draw_arrive() -> void:
	_space(33)
	var c: Vector2 = Vector2(215, 180)
	var failed: bool = did.has("p") and _dead()
	var ship: Vector2
	var behind: bool = false
	if failed:
		ship = Vector2(-20 + st * 140.0, 60 + st * 10.0)
	else:
		var a2: float = st * 1.6
		ship = c + Vector2(cos(a2) * 150.0, sin(a2) * 46.0 - 20.0)
		behind = sin(a2) < 0.0
		for j: int in 90:
			var aa: float = TAU * j / 90.0
			if (sin(aa) < 0.0) == true:
				draw_rect(Rect2((c + Vector2(cos(aa) * 150.0, sin(aa) * 46.0 - 20.0)).floor(), Vector2(1, 1)), Color(UI.CYAN, 0.35))
	if behind:
		Pix.sprite(self, tex_orbiter, ship)
	_planet(tex_dest_big, c)
	if not failed:
		for j: int in 90:
			var ab: float = TAU * j / 90.0
			if sin(ab) >= 0.0:
				draw_rect(Rect2((c + Vector2(cos(ab) * 150.0, sin(ab) * 46.0 - 20.0)).floor(), Vector2(1, 1)), Color(UI.CYAN, 0.5))
	if not behind:
		if not failed and not did.has("p"):
			draw_rect(Rect2(ship.x + 18, ship.y - 1, 8, 3), UI.ORANGE)
			draw_rect(Rect2(ship.x + 18, ship.y, 5, 1), UI.YELLOW)
		Pix.sprite(self, tex_orbiter, ship)
	Pix.panel(self, Rect2(6, 6, 300, 42))
	_text(Vector2(13, 20), "ARRIVING AT %s" % Game.place(), 12, UI.TEXT)
	if failed:
		_text(Vector2(13, 36), "NO FUEL TO BRAKE: FLYING PAST", 11, UI.RED)
	elif did.has("p"):
		_text(Vector2(13, 36), "ORBIT INSERTION COMPLETE", 11, UI.GREEN)
	else:
		_text(Vector2(13, 36), "BRAKING BURN...", 11, UI.ORANGE)

func _draw_home() -> void:
	_space(44)
	var d_pos: Vector2 = Vector2(80, 200)
	var e_pos: Vector2 = Vector2(360, 150)
	_planet(tex_dest_home, d_pos)
	_planet(tex_earth_big, e_pos)
	var obj: Dictionary = Game.run["obj"]
	if Game.dest_id == "moon":
		if obj.get("return", false):
			var p: float = clampf((st - 1.0) / 5.0, 0.0, 1.0)
			var c: Vector2 = Vector2(220, 60)
			var pos: Vector2 = d_pos.lerp(c, p).lerp(c.lerp(e_pos, p), p)
			draw_rect(Rect2(pos.floor() - Vector2(3, 3), Vector2(6, 6)), Color("d8dce8"))
			draw_rect(Rect2(pos.floor() - Vector2(5, 0) - Vector2(4, 0), Vector2(4, 2)), UI.ORANGE)
			_text(Vector2(10, 22), "RETURNING %d SAMPLES TO EARTH" % int(Game.run["samples"]), 12, UI.GREEN)
		else:
			_text(Vector2(10, 22), "THE SAMPLES STAY ON THE MOON", 12, UI.RED)
	else:
		var sent: float = float(Game.run["sent"])
		for i: int in 5:
			var k: float = fposmod(st * 0.4 + i * 0.2, 1.0)
			var pos2: Vector2 = d_pos.lerp(e_pos, k)
			if sent > 0.0:
				draw_arc(pos2, 6.0, -0.8, 0.8, 8, UI.CYAN, 1.0)
				draw_arc(pos2, 10.0, -0.8, 0.8, 8, Color(UI.CYAN, 0.5), 1.0)
		_text(Vector2(10, 22), "SENDING SCIENCE TO EARTH", 12, UI.CYAN)
		_text(Vector2(10, 40), "Each signal takes %s to arrive." % Game.dest()["light_delay"], 9, UI.DIM)
		_text(Vector2(10, 54), "Sent: %s Gb" % Game.fmt(sent), 9, UI.TEXT)
