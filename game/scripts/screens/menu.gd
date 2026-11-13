extends Control
## Title scene, three mission posters, players, Tech Lab, how to play, sources.
## Everything is drawn by hand on the 640x360 pixel grid; buttons are hit rectangles registered while drawing.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")
const BG_TEX: Texture2D = preload("res://art/bg_space.png")

## Set by the report screen: open the Tech Lab as soon as the menu appears.
static var open_tech_next: bool = false

const CARD_W: int = 200
const CARD_H: int = 238
const CARD_Y: int = 56
const WIN_H: int = 100
const IDS: Array[String] = ["moon", "mars", "saturn"]

const FRAME_M: Array = [6, 6, 6, 8]
const BTN_M: Array = [4, 5, 4, 6]
const TILE_M: Array = [5, 5, 5, 6]

const INK: Color = Color("05070d")
const PICKS: Dictionary = {
	"moon": {
		"col": Color("c9c9d6"), "pips": 1, "ground": Color(1, 1, 1), "sky": Color("0b1022"),
		"goal": "Land, grab 3 samples, fly home.",
		"fact": "Gravity is 1.62 m/s2: you jump 6x higher",
		"icon": "ic_gravity", "veh": ["veh_lander", "veh_rover"],
		"facts": ["Gravity 1.62 m/s2 (Earth 9.81)", "No air: no parachute, no heat shield", "384,400 km away, radio delay 1.3 s", "One lunar day lasts about 14 Earth days"],
	},
	"mars": {
		"col": Color("e0784a"), "pips": 2, "ground": Color(1.0, 0.55, 0.38), "sky": Color("1a0f18"),
		"goal": "Land a rover, drill 4 samples, send the data home.",
		"fact": "Radio delay 4 to 24 min: landers land themselves",
		"icon": "ic_radio", "veh": ["veh_lander", "veh_rover"],
		"facts": ["Gravity 3.71 m/s2", "Sunlight 586 W/m2, 43% of Earth's", "Radio delay 4 to 24 min: land by itself", "One sol is 24 h 40 min, nights are cold"],
	},
	"saturn": {
		"col": Color("e3c27a"), "pips": 3, "ground": Color(1, 1, 1), "sky": Color("120f20"),
		"goal": "Reach orbit, fly a drone through the rings for 5 samples.",
		"fact": "Sunlight is 1% of Earth's: solar panels barely work",
		"icon": "ic_sun", "veh": ["veh_orbiter", "veh_drone"],
		"facts": ["Gravity 10.44 m/s2 at the cloud tops", "Sunlight 14.8 W/m2, about 1% of Earth's", "No surface: send a drone into the rings", "Radio delay about 80 min each way"],
	},
}
const DIFF_PIP: Array[String] = ["pip_g", "pip_y", "pip_r"]
const DIFF_COL: Array[Color] = [Color("6dff8a"), Color("ffd75e"), Color("ff5a5a")]
const DIFF_BTN: Array[String] = ["btn_green", "btn_yellow", "btn_red"]

var t: float = 0.0
var tex_cache: Dictionary = {}
var hits: Array = []
var blocked: bool = false
var hot: String = ""
var down: String = ""
var force_hot: String = ""
var hv: Dictionary = {"moon": 0.0, "mars": 0.0, "saturn": 0.0}
var dm: Dictionary = {"moon": 0.0, "mars": 0.0, "saturn": 0.0}
var hover_t: float = 0.0
var stars_win: Array = []
var launching: String = ""
var launch_t: float = 0.0

var overlay: String = ""
var ov_t: float = 0.0
var shown_funds: float = 0.0
var reset_armed: float = -10.0
var sparks: Array = []   # {pos, age, dur, tint}
var shake: Dictionary = {}  # tile id -> time of a denied click
var bought: Dictionary = {}  # tile id -> time of the purchase
# multiplayer lobby (decision D7; the network is scripts/net.gd)
var name_text: String = ""
var code_text: String = ""
var field: String = "code"      # the text field that takes the keys
var connecting: bool = false
var lobby_dest: String = "moon" # host: where the mission goes

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	name_text = Game.player_name
	Net.connected.connect(_on_connected)
	Net.started.connect(_on_started)
	if Game.net_error != "" or Net.is_online():
		call_deferred("_open", "multi")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for i: int in 3:
		var arr: Array = []
		for j: int in 22:
			arr.append([Vector2(rng.randi_range(2, 185), rng.randi_range(2, WIN_H - 4)), rng.randf() * 6.28, rng.randf() < 0.15])
		stars_win.append(arr)
	for n: String in ["logo", "logo_rocket", "satellite", "card", "card_hot", "plate", "tile", "tile_owned", "medal_gold", "medal_silver", "medal_bronze",
			"ic_play", "ic_coin", "ic_helmet", "ic_helmet_off", "ic_flask", "ic_help", "ic_fact", "ic_close", "ic_tick", "ic_cross", "ic_dash", "ic_gravity", "ic_radio", "ic_sun",
			"pip_g", "pip_y", "pip_r", "pip_off", "ground_moon", "lamp_go", "lamp_nogo", "lamp_warn", "lamp_off",
			"veh_lander", "veh_rover", "veh_orbiter", "veh_drone", "veh_rocket", "mini_moon", "mini_mars", "mini_saturn",
			"tech_solar2", "tech_batt2", "tech_ka", "tech_rover2", "tech_armor", "tech_grant"]:
		_tx(n)
	for n: String in ["btn_green", "btn_yellow", "btn_red", "btn_blue", "btn_grey"]:
		for s: String in ["n", "h", "p"]:
			_tx(n + "_" + s)
	for n: String in ["planet_earth_60", "planet_moon_60", "planet_mars_60", "planet_saturn_60"]:
		_planet(n)
	shown_funds = float(Game.funds)
	if open_tech_next:
		open_tech_next = false
		_open("tech")

func _tx(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/menu/%s.png" % name) as Texture2D
	return tex_cache[name]

func _planet(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load("res://art/%s.png" % name) as Texture2D
	return tex_cache[name]

# ---------------------------------------------------------------- input

func _process(delta: float) -> void:
	t += delta
	hover_t += delta
	var h: String = _hit_at(get_local_mouse_position())
	if force_hot != "":
		h = force_hot
	if launching != "":
		h = ""
	if h != hot:
		hot = h
		hover_t = 0.0
		if h != "" and h != "o:panel" and h != "o:dim":
			Audio.play("ui_hover", -9.0)
	var any: bool = false
	for id: String in IDS:
		any = any or (hot == "play:" + id and overlay == "")
	for id: String in IDS:
		var on: bool = hot == "play:" + id and overlay == ""
		hv[id] = move_toward(float(hv[id]), 1.0 if on else 0.0, delta * 7.0)
		dm[id] = move_toward(float(dm[id]), 1.0 if (any and not on) else 0.0, delta * 5.0)
	if overlay != "":
		ov_t += delta
	var gap: float = absf(shown_funds - float(Game.funds))
	shown_funds = move_toward(shown_funds, float(Game.funds), maxf(60.0 * delta, gap * 6.0 * delta))
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["dur"]):
			sparks.remove_at(i)
	if launching != "":
		launch_t += delta
		if launch_t >= 0.75:
			var id2: String = launching
			launching = ""
			_play(id2)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if launching != "":
		return
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		down = _hit_at(e.position)
		hot = down
	else:
		var up: String = _hit_at(e.position)
		if up != "" and up == down:
			_activate(up)
		down = ""

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and overlay == "multi" and not Net.is_online() and not connecting and k.keycode != KEY_ESCAPE:
		_type(k)
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and overlay != "":
		_close()

## Typing in the lobby's name and room-code fields.
func _type(k: InputEventKey) -> void:
	if k.keycode == KEY_BACKSPACE:
		if field == "code":
			code_text = code_text.left(-1)
		else:
			name_text = name_text.left(-1)
	elif k.keycode == KEY_TAB:
		field = "name" if field == "code" else "code"
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		if field == "code":
			_activate("o:join")
		else:
			field = "code"
	elif k.unicode > 0 and not k.echo:
		var ch: String = String.chr(k.unicode).to_upper()
		if field == "code":
			if ch >= "A" and ch <= "Z" and code_text.length() < 4:
				code_text += ch
		elif ((ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " ") and name_text.length() < 12:
			name_text += ch

func _hit_at(p: Vector2) -> String:
	for i: int in range(hits.size() - 1, -1, -1):
		var r: Rect2 = hits[i][0]
		if r.has_point(p):
			return hits[i][1]
	return ""

func _hit(r: Rect2, id: String) -> void:
	if blocked and not id.begins_with("o:"):
		return
	hits.append([r, id])

func _activate(id: String) -> void:
	if id == "o:panel":
		return
	if id == "o:dim":
		_close()
	elif id.begins_with("play:"):
		Audio.play("confirm")
		Audio.play("ignition", -4.0)
		launching = id.substr(5)
		launch_t = 0.0
	elif id.begins_with("pl:"):
		Audio.play("ui_tab")
		Game.players = int(id.substr(3))
	elif id == "tech" or id == "help" or id == "src" or id == "multi":
		_open(id)
	elif id == "o:close":
		_close()
	elif id.begins_with("o:buy:"):
		_buy(id.substr(6))
	elif id == "o:reset":
		_reset()
	elif id.begins_with("o:"):
		_lobby_action(id.substr(2))

# ---------------------------------------------------------------- multiplayer lobby

func _me() -> Dictionary:
	for p: Variant in Net.lobby().get("players", []):
		var pd: Dictionary = p
		if int(pd.get("id", -1)) == Net.my_id():
			return pd
	return {}

func _all_ready() -> bool:
	var players: Array = Net.lobby().get("players", [])
	for p: Variant in players:
		if not bool((p as Dictionary).get("ready", false)):
			return false
	return not players.is_empty()

func _lobby_action(a: String) -> void:
	if a == "field:name" or a == "field:code":
		field = a.substr(6)
		Audio.play("ui_tab")
	elif a == "host" and not connecting:
		_connect("")
	elif a == "join" and not connecting:
		if code_text.length() != 4:
			Audio.play("ui_deny")
			Game.net_error = "TYPE 4 LETTERS"
			return
		_connect(code_text)
	elif a.begins_with("role:"):
		var role: String = a.substr(5)
		var holder: String = Game.holder(role)
		if Net.owns(role):
			Net.drop_role(role)
			Audio.play("ui_close")
		elif holder == "":
			Net.pick_role(role)   # only a free role: the server drops a player who picks a taken one
			Audio.play("confirm", -3.0)
		else:
			Audio.play("ui_deny")
	elif a == "ready":
		Net.set_ready(not bool(_me().get("ready", false)))
		Audio.play("ui_tab")
	elif a.begins_with("dest:"):
		lobby_dest = a.substr(5)
		Audio.play("ui_tab")
	elif a == "start":
		if Net.is_host() and _all_ready():
			Audio.play("confirm")
			Net.start()
		else:
			Audio.play("ui_deny")
	elif a == "leave":
		Net.leave()
		connecting = false
		Audio.play("ui_close")

func _connect(code: String) -> void:
	Game.player_name = name_text.strip_edges() if name_text.strip_edges() != "" else "PLAYER"
	Game.net_error = ""
	connecting = true
	Audio.play("confirm", -3.0)
	if code == "":
		Net.host(Game.player_name)
	else:
		Net.join(code, Game.player_name)

func _on_connected() -> void:
	connecting = false

## Every player hears this; the host takes everyone to the builder for the chosen destination.
func _on_started() -> void:
	if Net.is_host():
		Game.new_mission(lobby_dest)
		Game.host_goto("builder")

## The server's reasons, in plain words.
static func _plain(reason: String) -> String:
	match reason:
		"ROOM NOT FOUND":
			return "No room has that code. Check the 4 letters with your host."
		"ROOM FULL":
			return "That room already has 4 players."
		"ROOM STARTED":
			return "That mission has already started. Ask the host for a new room."
		"HOST LEFT":
			return "The host left, so the room closed."
		"TIMEOUT", "CONNECTION FAILED":
			return "Could not reach the game server. Check your internet and try again."
		"CONNECTION CLOSED", "connection lost":
			return "The connection to the server was lost."
		"ROLE TAKEN":
			return "Someone else took that role first."
		"SERVER FULL":
			return "The server is full. Try again later."
		"TYPE 4 LETTERS":
			return "Type the 4-letter room code first."
	return "Connection problem: %s." % reason.to_lower()

func _play(id: String) -> void:
	Game.new_mission(id)
	Game.goto("builder")

func _open(which: String) -> void:
	overlay = which
	ov_t = 0.0
	Audio.play("ui_open")

func _close() -> void:
	if overlay == "multi" and (Net.is_online() or connecting):
		return   # in a room: only LEAVE closes it
	if overlay != "":
		Audio.play("ui_close")
	overlay = ""

func _buy(id: String) -> void:
	var cost: int = int(Data.TECH[id]["cost"])
	if Game.tech.has(id):
		return
	if Game.funds < cost:
		Audio.play("ui_deny")
		shake[id] = t
		return
	if Game.buy_tech(id):
		Audio.play("coin")
		Audio.play("confirm", -3.0)
		bought[id] = t
		var c: Vector2 = _tile_rect(id).get_center()
		for k: int in 5:
			sparks.append({"pos": c + Vector2((k - 2) * 26, ((k * 7) % 5) * 7 - 14), "age": -0.07 * k, "dur": 0.55, "tint": Color("ffd75e")})

func _reset() -> void:
	if t - reset_armed < 3.0:
		reset_armed = -10.0
		Game.reset_save()
		Audio.play("ui_close")
		shown_funds = float(Game.funds)
	else:
		reset_armed = t
		Audio.play("ui_deny", -6.0)

# ---------------------------------------------------------------- drawing helpers

func _nine(r: Rect2, name: String, m: Array, mod: Color = Color.WHITE) -> void:
	var tx: Texture2D = _tx(name)
	RenderingServer.canvas_item_add_nine_patch(get_canvas_item(), Rect2(r.position.floor(), r.size.floor()), Rect2(Vector2.ZERO, tx.get_size()),
		tx.get_rid(), Vector2(m[0], m[1]), Vector2(m[2], m[3]), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, mod)

func _blit(tx: Texture2D, pos: Vector2, clip: Rect2, mod: Color = Color.WHITE) -> void:
	var dst: Rect2 = Rect2(pos, tx.get_size()).intersection(clip)
	if dst.size.x <= 0.0 or dst.size.y <= 0.0:
		return
	draw_texture_rect_region(tx, dst, Rect2(dst.position - pos, dst.size), mod)

func _img(name: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	draw_texture(_tx(name), pos.floor(), mod)

func _para(p: Vector2, s: String, w: float, c: Color, lines_max: int = 9) -> int:
	## Word-wrapped 10 px text, baseline-left at p, 12 px per line. Returns the number of lines used.
	var f: Font = Pix.font()
	var line: String = ""
	var n: int = 0
	for wd: String in s.split(" "):
		var test: String = wd if line == "" else line + " " + wd
		if line != "" and f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > w:
			Pix.text(self, p + Vector2(0, n * 12), line, 10, c)
			n += 1
			line = wd
			if n >= lines_max:
				return n
		else:
			line = test
	if line != "":
		Pix.text(self, p + Vector2(0, n * 12), line, 10, c)
		n += 1
	return n

## A face from art/menu with a label and an optional 14 px icon. owns_hit false: the caller registered the hit.
func _button(r: Rect2, id: String, label: String, kind: String, icon: String = "", enabled: bool = true, mod: Color = Color.WHITE, owns_hit: bool = true) -> void:
	if owns_hit:
		_hit(r, id)
	var state: String = "n"
	if enabled and hot == id:
		state = "p" if down == id else "h"
	if not enabled:
		kind = "btn_grey"
	var drop: int = 2 if state == "p" else 0
	_nine(Rect2(r.position, Vector2(r.size.x, 24)), "%s_%s" % [kind, state], BTN_M, mod)
	var ink: Color = Color("f4f8ff")
	if kind == "btn_yellow":
		ink = Color("2a1c04")
	if not enabled:
		ink = Color("6a7490")
	var w: float = Pix.text_w(label, 10) + (16.0 if icon != "" else 0.0)
	var x: float = r.position.x + floorf((r.size.x - w) / 2.0)
	var by: float = r.position.y + 15.0 + drop
	if icon != "":
		_img(icon, Vector2(x, by - 11), mod * Color(1, 1, 1, 1.0 if enabled else 0.5))
		x += 16.0
	Pix.text(self, Vector2(x, by), label, 10, ink * mod)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	hits.clear()
	blocked = overlay != ""
	_draw_background()
	_draw_title()
	for i: int in 3:
		_draw_card(i, IDS[i])
	_draw_bar()
	Pix.text_c(self, 320.0, 356.0, "Team Shay Rafe3  -  NASA Space Apps Challenge 2026  -  Space Mission Design Game", 10, Color("56608a"))
	if launching != "":
		_draw_launch()
	for s: Dictionary in sparks:
		if float(s["age"]) >= 0.0:
			Fx.sparkle(self, s["pos"], float(s["age"]) / float(s["dur"]), s["tint"], 1)
	if overlay != "":
		_draw_overlay()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
	Pix.tiled(self, BG_TEX, 0, t * 2.0, 640.0, Color(0.85, 0.85, 1.0))
	Pix.stars(self, t, Vector2(640, 360), 50, 11, Vector2(-t * 3.0, 0))
	Pix.stars(self, t * 1.3, Vector2(640, 360), 26, 5, Vector2(-t * 9.0, 0))
	# home planet in the corner, the sun on the other side
	draw_texture(_planet("planet_earth_60"), Vector2(-42, -58), Color(0.95, 0.97, 1.0))
	Fx.sun(self, Vector2(598, 24), 1, Color("ffd75e"), t)
	# a satellite crossing slowly
	var sp: float = fposmod(t, 30.0) / 30.0
	_img("satellite", Vector2(-40.0 + sp * 720.0, 36.0 + floorf(sin(sp * 9.0) * 3.0)), Color(0.9, 0.95, 1.0, 0.9))
	# a small rocket crossing with a trail
	var rp: float = fposmod(t + 7.0, 21.0) / 6.0
	if rp < 1.0:
		var rx: float = floorf(-30.0 + rp * 700.0)
		var ry: float = 20.0 + floorf(sin(rp * 5.0) * 5.0)
		Fx.trail(self, Vector2(rx + 1, ry + 4), Vector2.LEFT, 48.0, 3.0, t)
		_img("logo_rocket", Vector2(rx, ry))
	# a shooting star
	var cycle: int = int((t + 3.0) / 11.0)
	var sp2: float = fposmod(t + 3.0, 11.0) / 0.7
	if sp2 < 1.0:
		var sx: float = 120.0 + fposmod(float(cycle) * 197.0, 400.0)
		var sy: float = 6.0 + fposmod(float(cycle) * 37.0, 30.0)
		for j: int in 10:
			var a: float = 1.0 - j / 10.0
			var px: float = sx - sp2 * 120.0 + j * 2.0
			var py: float = sy + sp2 * 60.0 - j
			draw_rect(Rect2(floorf(px), floorf(py), 1 if j > 2 else 2, 1), Color(0.85, 0.92, 1.0, a * (1.0 - sp2 * 0.5)))

func _draw_title() -> void:
	var lg: Texture2D = _tx("logo")
	var by: float = floorf(sin(t * 1.1) * 1.4)
	draw_texture(lg, Vector2(floorf((640.0 - lg.get_width()) / 2.0), 2.0 + by))
	# a glint that sweeps the lettering every few seconds
	var gp: float = fposmod(t, 4.5) / 0.7
	if gp < 1.0:
		Fx.sparkle(self, Vector2(190.0 + gp * 260.0, 14.0 + by), gp, Color("fff4b8"), 1)

func _draw_card(i: int, id: String) -> void:
	var pk: Dictionary = PICKS[id]
	var d: Dictionary = Data.DEST[id]
	var h: float = float(hv[id])
	var dim: float = float(dm[id])
	var x: int = 10 + i * (CARD_W + 10)
	var y: int = CARD_Y - roundi(h * 3.0)
	var lum: float = 1.0 - 0.3 * dim
	var mod: Color = Color(lum, lum, lum, 1.0)
	var col: Color = pk["col"]
	var cr: Rect2 = Rect2(x, y, CARD_W, CARD_H)
	_hit(cr, "play:" + id)
	if h > 0.05:
		Fx.glow(self, Vector2(x + CARD_W / 2.0, CARD_Y + CARD_H - 6), 96.0, Color(0.5, 0.8, 1.0, 0.5 * h))
	_nine(cr, "card", FRAME_M, mod)
	if h > 0.02:
		_nine(cr, "card_hot", FRAME_M, Color(1, 1, 1, h))
	# --- the window: a planet rising out of the bottom edge
	var wr: Rect2 = Rect2(x + 6, y + 6, 188, WIN_H)
	var sky: Color = pk["sky"]
	draw_rect(wr, sky * mod)
	for s: Array in stars_win[i]:
		var sp: Vector2 = s[0]
		var tw: float = 0.45 + 0.55 * sin(t * 1.7 + float(s[1]))
		draw_rect(Rect2((wr.position + sp).floor(), Vector2(2, 2) if bool(s[2]) else Vector2(1, 1)), Color(0.8 * lum, 0.88 * lum, lum, 0.3 + 0.7 * tw))
	var bob: float = floorf(sin(t * 0.9 + i) * 1.6)
	var cx: float = wr.position.x + 94.0 + floorf(sin(t * 0.37 + i * 2.0) * 3.0)
	if id == "saturn":
		_blit(_planet("planet_saturn_60"), Vector2(cx - 133.0, wr.position.y + 6.0 + bob), wr, mod)
	else:
		_blit(_planet("planet_%s_60" % id), Vector2(cx - 62.0, wr.position.y + 12.0 + bob), wr, mod)
	# foreground ground and the vehicles you will fly
	var veh: Array = pk["veh"]
	var v1: Texture2D = _tx(String(veh[0]))
	var v2: Texture2D = _tx(String(veh[1]))
	if id != "saturn":
		var gt: Texture2D = _tx("ground_moon")
		var gx: float = wr.position.x - fposmod(floorf(t * 3.0), float(gt.get_width()))
		var gmod: Color = (pk["ground"] as Color) * mod
		while gx < wr.end.x:
			_blit(gt, Vector2(gx, wr.end.y - 13.0), wr, gmod)
			gx += gt.get_width()
		_blit(v1, Vector2(wr.position.x + 4.0, wr.end.y - 8.0 - v1.get_height()), wr, mod)
		_blit(v2, Vector2(wr.end.x - 4.0 - v2.get_width(), wr.end.y - 7.0 - v2.get_height()), wr, mod)
	else:
		_blit(v1, Vector2(wr.position.x + 4.0, wr.end.y - 4.0 - v1.get_height() + bob), wr, mod)
		_blit(v2, Vector2(wr.end.x - 8.0 - v2.get_width(), wr.end.y - 6.0 - v2.get_height() - bob), wr, mod)
	draw_rect(Rect2(wr.position.x, wr.end.y - 1, wr.size.x, 1), Color("2a3558") * mod)
	# difficulty pips and tag
	var pips: int = int(pk["pips"])
	draw_rect(Rect2(wr.position.x + 2, wr.position.y + 2, 34 + Pix.text_w(String(d["diff"]), 10) + 10, 13), Color(0.02, 0.03, 0.07, 0.6))
	for p: int in 3:
		_img(DIFF_PIP[pips - 1] if p < pips else "pip_off", Vector2(wr.position.x + 4 + p * 10, wr.position.y + 4), mod)
	Pix.text(self, Vector2(wr.position.x + 38, wr.position.y + 12), String(d["diff"]), 10, DIFF_COL[pips - 1] * mod)
	# best score as a medal
	if Game.best.has(id):
		var b: int = int(Game.best[id])
		var medal: String = "medal_gold" if b >= 100 else ("medal_silver" if b >= 75 else "medal_bronze")
		_img(medal, Vector2(wr.end.x - 24, wr.position.y + 2), mod)
		Pix.text_c(self, wr.end.x - 15.0, wr.position.y + 40.0, "%d%%" % b, 10, Color("e8ecff") * mod)
	# --- body
	var bx: float = x + 10.0
	Pix.title(self, Vector2(bx, y + 132), String(d["name"]), col * mod, 2)
	_para(Vector2(bx, y + 148), String(pk["goal"]), 180.0, Color("bfeaff") * mod, 2)
	var fy: float = y + 148.0 + 2 * 12.0 + 4.0
	var fact: String = String(pk["fact"])
	if h > 0.5:
		var facts: Array = pk["facts"]
		fact = String(facts[int(hover_t / 2.2) % facts.size()])
	_img(String(pk["icon"]), Vector2(bx - 2, fy - 2), mod)
	_para(Vector2(bx + 16, fy + 7), fact, 164.0, Color("8a94b8").lerp(Color("e8ecff"), h) * mod, 2)
	_button(Rect2(x + 8, y + CARD_H - 32, CARD_W - 16, 24), "play:" + id, "PLAY " + String(d["name"]), DIFF_BTN[pips - 1], "ic_play", true, mod, false)

func _draw_bar() -> void:
	_nine(Rect2(10, 298, 620, 46), "plate", FRAME_M)
	Pix.text(self, Vector2(22, 324), "PLAYERS", 10, Color("8a94b8"))
	for n: int in 4:
		var r: Rect2 = Rect2(70 + n * 22, 305, 22, 26)
		_hit(r, "pl:%d" % (n + 1))
		var lift: int = 1 if hot == "pl:%d" % (n + 1) else 0
		_img("ic_helmet" if n + 1 <= Game.players else "ic_helmet_off", Vector2(r.position.x + 4, r.position.y + 6 - lift))
		if n + 1 == Game.players:
			draw_rect(Rect2(r.position.x + 4, r.position.y + 22, 14, 2), UI.CYAN)
	_button(Rect2(164, 308, 98, 24), "multi", "MULTIPLAYER", "btn_yellow", "ic_helmet")
	var shown: int = roundi(shown_funds)
	var cw: float = 20.0 + Pix.title_w(str(shown), 2)
	var cx0: float = floorf(318.0 - cw / 2.0)
	_img("ic_coin", Vector2(cx0, 312))
	Pix.title(self, Vector2(cx0 + 20.0, 332.0), str(shown), UI.YELLOW, 2)
	_button(Rect2(372, 308, 88, 24), "tech", "TECH LAB", "btn_blue", "ic_flask")
	_button(Rect2(464, 308, 88, 24), "help", "HOW TO PLAY", "btn_grey", "ic_help")
	_button(Rect2(556, 308, 66, 24), "src", "NASA", "btn_grey", "ic_fact")

func _draw_launch() -> void:
	var i: int = IDS.find(launching)
	var x: float = 10.0 + i * (CARD_W + 10) + CARD_W / 2.0
	var y: float = 196.0 - 520.0 * launch_t * launch_t
	var rk: Texture2D = _tx("veh_rocket")
	Fx.glow(self, Vector2(x, 292.0), 64.0, Color(1.0, 0.7, 0.35, 0.5))
	Fx.flame(self, Vector2(x, y + rk.get_height() - 4), Vector2.DOWN, 30.0 + launch_t * 40.0, 11.0, t)
	draw_texture(rk, Vector2(floorf(x - rk.get_width() / 2.0), floorf(y)))
	for j: int in 3:
		Fx.puff(self, Vector2(x + (j - 1) * 22, 290.0 - j % 2 * 4), clampf(launch_t / 0.75 + j * 0.1 - 0.2, 0.0, 0.99), 1, Color(1, 1, 1, 0.7), j)

# ---------------------------------------------------------------- overlays

func _panel_rect() -> Rect2:
	var e: float = clampf(ov_t / 0.18, 0.0, 1.0)
	e = 1.0 - pow(1.0 - e, 3.0)
	return Rect2(40, 14 + roundi((1.0 - e) * 14.0), 560, 326)

func _draw_overlay() -> void:
	var e: float = clampf(ov_t / 0.18, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.07, 0.8 * e))
	_hit(Rect2(0, 0, 640, 360), "o:dim")
	var pr: Rect2 = _panel_rect()
	_hit(pr, "o:panel")
	_nine(pr, "card", FRAME_M)
	var title: String = {"tech": "TECH LAB", "help": "HOW TO PLAY", "src": "NASA DATA & CREDITS", "multi": "MULTIPLAYER"}[overlay]
	Pix.title(self, pr.position + Vector2(16, 28), title, UI.YELLOW, 2)
	if overlay != "multi" or not (Net.is_online() or connecting):
		_button(Rect2(pr.end.x - 38, pr.position.y + 8, 28, 24), "o:close", "", "btn_red", "ic_close")
	draw_rect(Rect2(pr.position.x + 10, pr.position.y + 38, pr.size.x - 20, 1), Color("2a3558"))
	match overlay:
		"tech":
			_draw_tech(pr)
		"help":
			_draw_help(pr)
		"src":
			_draw_sources(pr)
		"multi":
			if Net.is_online():
				_draw_lobby(pr)
			else:
				_draw_join(pr)

func _field(r: Rect2, id: String, label: String, text: String, hint: String) -> void:
	_hit(r, "o:field:" + id)
	var on: bool = field == id and not connecting
	Pix.text(self, r.position + Vector2(0, -4), label, 10, UI.CYAN)
	draw_rect(r, Color("05070d"))
	draw_rect(r, UI.YELLOW if on else Color("3a4a7a"), false, 1.0)
	var shown: String = text if text != "" else hint
	Pix.text(self, r.position + Vector2(7, 15), shown, 10, UI.TEXT if text != "" else Color("56608a"))
	if on and fposmod(t, 1.0) < 0.55:
		draw_rect(Rect2(r.position.x + 8 + (Pix.text_w(text, 10) if text != "" else 0.0), r.position.y + 5, 1, 12), UI.YELLOW)

## Not in a room yet: a name, HOST, or a code and JOIN.
func _draw_join(pr: Rect2) -> void:
	var x: float = pr.position.x + 16.0
	_para(Vector2(x, pr.position.y + 56), "1 to 4 players, each on their own computer. Each player takes a role: Planner, Engineer, Scientist or Comms. One player hosts and gets a 4-letter code; the others join with it.", 528.0, UI.DIM, 3)
	_field(Rect2(x, pr.position.y + 108, 200, 22), "name", "YOUR NAME", name_text, "TYPE YOUR NAME")
	if connecting:
		Pix.text(self, Vector2(x, pr.position.y + 170), "CONNECTING" + ".".repeat(int(t * 3.0) % 4), 10, UI.YELLOW)
		_button(Rect2(x, pr.position.y + 186, 120, 24), "o:leave", "CANCEL", "btn_grey")
	else:
		Pix.text(self, Vector2(x, pr.position.y + 158), "START A NEW ROOM", 10, UI.CYAN)
		_button(Rect2(x, pr.position.y + 164, 200, 24), "o:host", "HOST A ROOM", "btn_green", "ic_play")
		var jx: float = pr.position.x + 300.0
		_field(Rect2(jx, pr.position.y + 108, 90, 22), "code", "ROOM CODE", code_text, "ABCD")
		Pix.text(self, Vector2(jx, pr.position.y + 158), "JOIN A FRIEND'S ROOM", 10, UI.CYAN)
		_button(Rect2(jx, pr.position.y + 164, 200, 24), "o:join", "JOIN ROOM", "btn_blue", "ic_helmet", code_text.length() == 4)
	if Game.net_error != "":
		_img("ic_cross", Vector2(x, pr.position.y + 214))
		_para(Vector2(x + 18, pr.position.y + 225), _plain(Game.net_error), 500.0, UI.RED, 2)
	Pix.text(self, pr.position + Vector2(16, 300), "Type with the keyboard. TAB switches fields, ENTER joins. Solo play needs no network.", 10, Color("56608a"))

func _role_rect(i: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 10 + i * 136, pr.position.y + 66, 130, 96)

## In a room: the 4 role slots, the players and READY, the host's destination and START, LEAVE.
func _draw_lobby(pr: Rect2) -> void:
	var lob: Dictionary = Net.lobby()
	var code: String = String(lob.get("code", "----"))
	Pix.text(self, Vector2(pr.end.x - 190, pr.position.y + 20), "ROOM CODE", 10, UI.DIM)
	Pix.title(self, Vector2(pr.end.x - 120, pr.position.y + 30), code, UI.YELLOW, 2)
	Pix.text(self, pr.position + Vector2(16, 56), "Click a role to take it, click it again to drop it. Free roles go to the host.", 10, UI.DIM)
	for i: int in Data.ROLES.size():
		var role: Dictionary = Data.ROLES[i]
		var id: String = role["id"]
		var r: Rect2 = _role_rect(i, pr)
		var col: Color = role["color"]
		var mine: bool = Net.owns(id)
		var who: String = Game.holder(id)
		_hit(r, "o:role:" + id)
		_nine(r, "tile_owned" if mine else "tile", TILE_M, Color(1.15, 1.15, 1.15) if hot == "o:role:" + id else Color.WHITE)
		draw_rect(Rect2(r.position.x + 5, r.position.y + 5, r.size.x - 10, 3), col)
		Pix.text(self, r.position + Vector2(8, 22), String(role["name"]), 10, col)
		_para(r.position + Vector2(8, 36), String(role["job"]), r.size.x - 16.0, UI.DIM, 3)
		var tag: String = "YOU" if mine else (who.substr(0, 14) if who != "" else "FREE")
		Pix.text(self, Vector2(r.position.x + 8, r.end.y - 18), tag, 10, UI.GREEN if mine else (UI.TEXT if who != "" else Color("56608a")))
		Pix.text(self, Vector2(r.position.x + 8, r.end.y - 7), "CLICK TO DROP" if mine else ("CLICK TO TAKE" if who == "" else "TAKEN"), 10, Color("56608a"))
	# players and READY
	var y: float = pr.position.y + 176.0
	Pix.text(self, Vector2(pr.position.x + 16, y), "PLAYERS", 10, UI.CYAN)
	var players: Array = lob.get("players", [])
	for k: int in players.size():
		var p: Dictionary = players[k]
		var py: float = y + 14.0 + k * 13.0
		var rdy: bool = bool(p.get("ready", false))
		_img("ic_tick" if rdy else "ic_dash", Vector2(pr.position.x + 14, py - 10))
		var nm: String = String(p.get("name", "PLAYER")).substr(0, 14) + (" (HOST)" if bool(p.get("host", false)) else "") + (" - YOU" if int(p.get("id", -1)) == Net.my_id() else "")
		Pix.text(self, Vector2(pr.position.x + 32, py), nm, 10, UI.TEXT)
		var rx: float = pr.position.x + 200.0
		for rid: Variant in p.get("roles", []):
			draw_rect(Rect2(rx, py - 8, 9, 9), Game.role_color(String(rid)))
			rx += 12.0
		Pix.text(self, Vector2(pr.position.x + 256, py), "READY" if rdy else "NOT READY", 10, UI.GREEN if rdy else UI.DIM)
	var me_ready: bool = bool(_me().get("ready", false))
	_button(Rect2(pr.position.x + 16, pr.end.y - 64, 130, 24), "o:ready", "I'M READY" if not me_ready else "NOT READY", "btn_green" if not me_ready else "btn_grey", "ic_tick" if not me_ready else "")
	_button(Rect2(pr.position.x + 16, pr.end.y - 34, 130, 24), "o:leave", "LEAVE ROOM", "btn_red")
	# destination and START
	var dx: float = pr.position.x + 360.0
	if Net.is_host():
		Pix.text(self, Vector2(dx, y), "DESTINATION", 10, UI.CYAN)
		for j: int in IDS.size():
			var did: String = IDS[j]
			var br: Rect2 = Rect2(dx + j * 62, y + 6, 58, 24)
			_button(br, "o:dest:" + did, String(Data.DEST[did]["name"]), DIFF_BTN[j] if lobby_dest == did else "btn_grey")
		var ok: bool = _all_ready()
		_button(Rect2(dx, pr.end.y - 64, 182, 24), "o:start", "START MISSION", "btn_green", "ic_play", ok)
		Pix.text(self, Vector2(dx, pr.end.y - 20), "Everyone must be READY." if not ok else "All ready: press START.", 10, UI.DIM if not ok else UI.GREEN)
	else:
		_para(Vector2(dx, y), "The host picks the destination and presses START when everyone is READY.", 200.0, UI.DIM, 3)
	if Game.net_error != "":
		_para(Vector2(pr.position.x + 160, pr.end.y - 46), _plain(Game.net_error), 190.0, UI.RED, 3)

func _tile_rect(id: String) -> Rect2:
	var pr: Rect2 = _panel_rect()
	var idx: int = Data.TECH.keys().find(id)
	return Rect2(pr.position.x + 8 + (idx % 3) * 184, pr.position.y + 62 + floori(idx / 3.0) * 114, 176, 110)

func _draw_tech(pr: Rect2) -> void:
	_img("ic_coin", Vector2(pr.end.x - 150, pr.position.y + 12))
	Pix.title(self, Vector2(pr.end.x - 130, pr.position.y + 28), str(roundi(shown_funds)), UI.YELLOW, 2)
	Pix.text(self, pr.position + Vector2(16, 54), "Earn credits by finishing mission goals. Spend them on new parts for your ships.", 10, UI.DIM)
	for id: String in Data.TECH:
		var td: Dictionary = Data.TECH[id]
		var r: Rect2 = _tile_rect(id)
		var owned: bool = Game.tech.has(id)
		var cost: int = int(td["cost"])
		var can: bool = Game.funds >= cost
		if shake.has(id) and t - float(shake[id]) < 0.3:
			r.position.x += floorf(sin((t - float(shake[id])) * 60.0) * 2.0)
		var flash: float = clampf(1.0 - (t - float(bought.get(id, -9.0))) / 0.5, 0.0, 1.0)
		_nine(r, "tile_owned" if owned else "tile", TILE_M, Color(1, 1, 1).lerp(Color(1.6, 1.5, 1.0), flash))
		_img("tech_" + id, r.position + Vector2(8, 8), Color.WHITE if (owned or can) else Color(0.72, 0.72, 0.84))
		Pix.text(self, r.position + Vector2(40, 18), String(td["name"]), 10, UI.TEXT)
		_para(r.position + Vector2(40, 32), String(td["desc"]), 128.0, UI.DIM, 4)
		if owned:
			_img("ic_tick", Vector2(r.position.x + 56, r.end.y - 28))
			Pix.text(self, Vector2(r.position.x + 76, r.end.y - 17), "OWNED", 10, UI.GREEN)
		else:
			_button(Rect2(r.position.x + 8, r.end.y - 31, r.size.x - 16, 24), "o:buy:" + id, "BUY  %d" % cost, "btn_green" if can else "btn_grey", "ic_coin", can)
	var armed: bool = t - reset_armed < 3.0
	_button(Rect2(pr.position.x + 8, pr.end.y - 34, 150, 24), "o:reset", "SURE? CLICK AGAIN" if armed else "RESET SAVE", "btn_red" if armed else "btn_grey", "")
	Pix.text(self, Vector2(pr.position.x + 172, pr.end.y - 17), "New parts appear in the builder after you buy them.", 10, Color("56608a"))

func _draw_help(pr: Rect2) -> void:
	var titles: Array = ["PICK A DESTINATION", "BUILD THE SHIP UNTIL MISSION CONTROL SAYS GO", "FLY AND LAND IT YOURSELF", "READ THE REPORT, EARN CREDITS, UPGRADE"]
	var bodies: Array = [
		"Moon is easy, Mars medium, Saturn hard. Each has its own goal.",
		"Pick parts from the bin and snap them on. One lamp per station: red means something is missing.",
		"UP fires the engine, LEFT and RIGHT steer. Touch down slowly.",
		"The report tells you what went wrong and why. Credits buy new tech.",
	]
	for n: int in 4:
		var r: Rect2 = Rect2(pr.position.x + 8 + n * 137, pr.position.y + 50, 130, 216)
		_nine(r, "tile", TILE_M)
		var pw: Rect2 = Rect2(r.position.x + 6, r.position.y + 6, 118, 84)
		draw_rect(pw, Color("090c18"))
		draw_rect(Rect2(pw.position.x, pw.end.y - 1, pw.size.x, 1), Color("2a3558"))
		_help_picture(n, pw)
		var ny: float = r.position.y + 100.0
		var lines: int = _para(Vector2(r.position.x + 8, ny + 8), String(titles[n]), 116.0, UI.YELLOW, 4)
		_para(Vector2(r.position.x + 8, ny + 14 + lines * 12), String(bodies[n]), 116.0, Color("bfc8e8"), 7)
		if n == 2:
			var kx: float = r.position.x + 8.0
			for kk: String in ["UP", "LEFT", "RIGHT"]:
				kx += Pix.keycap(self, Vector2(kx, r.end.y - 20.0), kk) + 4.0
		# big step number in the picture corner
		draw_rect(Rect2(pw.position.x + 3, pw.position.y + 3, 18, 20), Color(0.02, 0.03, 0.07, 0.7))
		Pix.title(self, pw.position + Vector2(6, 21), str(n + 1), UI.YELLOW, 1)
	Pix.text(self, pr.position + Vector2(16, 294), "Up to 4 players share the roles: planner, engineer, scientist, comms.", 10, Color("8a94b8"))
	Pix.text(self, pr.position + Vector2(16, 308), "Drive: LEFT / RIGHT, UP to jump, E to drill. Every number is real NASA data or marked game rule.", 10, Color("56608a"))

func _help_picture(n: int, pw: Rect2) -> void:
	var c: Vector2 = pw.get_center()
	match n:
		0:
			var names: Array[String] = ["mini_moon", "mini_mars", "mini_saturn"]
			var sel: int = int(t / 1.2) % 3
			for j: int in 3:
				var tx: Texture2D = _tx(names[j])
				var xx: float = pw.position.x + 8 + j * 34 - (6 if j == 2 else 0)
				draw_texture(tx, Vector2(xx, c.y - tx.get_height() / 2.0 - 6.0 - (4.0 if j == sel else 0.0)).floor())
			for j: int in 3:
				_img(DIFF_PIP[j] if j <= sel else "pip_off", Vector2(c.x - 15 + j * 10, pw.end.y - 18))
		1:
			var phase: int = int(t / 0.7) % 7
			for j: int in 5:
				var lamp: String = "lamp_go" if j < phase else ("lamp_warn" if j == phase else "lamp_nogo")
				_img(lamp, Vector2(pw.position.x + 10 + j * 20, pw.position.y + 8))
			_img("veh_lander", Vector2(c.x - 20, pw.position.y + 24))
			var go: bool = phase >= 5
			Pix.text_c(self, c.x, pw.end.y - 6.0, "GO" if go else "NO-GO", 10, UI.GREEN if go else UI.RED)
		2:
			var ph: float = fposmod(t, 2.4) / 2.4
			var ly: float = pw.position.y + 6.0 + ph * 26.0
			var gt: Texture2D = _tx("ground_moon")
			_blit(gt, Vector2(pw.position.x, pw.end.y - 13), pw)
			Fx.flame(self, Vector2(c.x - 1, ly + 34), Vector2.DOWN, 12.0, 5.0, t)
			_img("veh_lander", Vector2(c.x - 20, ly))
		3:
			var m: int = int(t / 1.1) % 3
			_img(["medal_bronze", "medal_silver", "medal_gold"][m], Vector2(c.x - 9, pw.position.y + 8))
			_img("ic_coin", Vector2(c.x - 26, pw.end.y - 24))
			Pix.text(self, Vector2(c.x - 8, pw.end.y - 12), "+%d" % (60 + 20 * m), 10, UI.YELLOW)
			Fx.sparkle(self, Vector2(c.x + 18, pw.position.y + 14), fposmod(t, 1.1) / 1.1, Color("fff4b8"), 0)

func _draw_sources(pr: Rect2) -> void:
	var y: float = pr.position.y + 54.0
	Pix.text(self, Vector2(pr.position.x + 16, y), "DATA SOURCES", 10, UI.CYAN)
	y += 8.0
	for s: String in Data.SOURCES:
		_img("ic_dash", Vector2(pr.position.x + 14, y - 1))
		var n: int = _para(Vector2(pr.position.x + 30, y + 9), s, 510.0, UI.TEXT, 3)
		y += 4.0 + n * 12.0
	y += 8.0
	Pix.text(self, Vector2(pr.position.x + 16, y + 6), "AI USE (SPACE APPS RULES)", 10, UI.CYAN)
	_para(Vector2(pr.position.x + 16, y + 20), "Game idea and design: Team Shay Rafe3. Code, code-drawn pixel art and code-made sound were written with help from Claude (AI) and checked by the team. No NASA logos are used.", 526.0, UI.TEXT, 4)

# ---------------------------------------------------------------- debug (screenshots)

func debug_tech() -> void:
	overlay = "tech"
	ov_t = 1.0

func debug_multi() -> void:
	overlay = "multi"
	ov_t = 1.0
	code_text = "AB"
	Game.net_error = "ROOM NOT FOUND"

func debug_help() -> void:
	overlay = "help"
	ov_t = 1.0

func debug_sources() -> void:
	overlay = "src"
	ov_t = 1.0

func debug_hover_moon() -> void:
	force_hot = "play:moon"
	hv["moon"] = 1.0
	dm["mars"] = 1.0
	dm["saturn"] = 1.0

func debug_hover_mars() -> void:
	force_hot = "play:mars"
	hv["mars"] = 1.0
	dm["moon"] = 1.0
	dm["saturn"] = 1.0

func debug_hover_saturn() -> void:
	force_hot = "play:saturn"
	hv["saturn"] = 1.0
	dm["moon"] = 1.0
	dm["mars"] = 1.0

func debug_medals() -> void:
	Game.best = {"moon": 100, "mars": 60, "saturn": 20}

func debug_launch() -> void:
	launching = "mars"
	launch_t = 0.3

func debug_owned() -> void:
	Game.tech["solar2"] = true
	Game.tech["ka"] = true
