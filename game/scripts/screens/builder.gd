extends Control
## Ship builder: 6 resource bars, 4 role tabs, parts shop, ship preview, review board.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

class Bar extends Control:
	var frac: float = 0.0
	var col: Color = Color.WHITE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0f1426"))
		var w: float = clampf(frac, 0.0, 1.0) * (size.x - 2)
		draw_rect(Rect2(1, 1, w, size.y - 2), col)
		# pixel ticks
		for i: int in range(1, 10):
			draw_rect(Rect2(int(size.x * i / 10.0), 1, 1, size.y - 2), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), Color("3a4a7a"), false, 1.0)

class ShipView extends Control:
	var t: float = 0.0
	var tex_dest: Texture2D = null  # kept here: a texture loaded inside _draw is freed before it renders
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	## A hangar like a racing game's garage: lit back wall, a window on the destination,
	## and a glossy floor that reflects the ship.
	func _draw() -> void:
		var w: float = size.x
		var cx: float = floorf(w / 2.0)
		var cy: float = floorf(size.y - 66.0)
		var fy: float = cy + 28.0  # where the ship stands
		var wall_y: float = fy - 14.0
		draw_rect(Rect2(0, 0, w, wall_y), Color("141b2e"))
		var x0: float = fposmod(cx - 11.0, 22.0)
		while x0 < w:
			draw_rect(Rect2(x0, 8, 1, wall_y - 12), Color("1e2740"))
			draw_rect(Rect2(x0 + 1, 8, 1, wall_y - 12), Color("0e1424"))
			x0 += 22.0
		draw_rect(Rect2(0, 44, w, 1), Color("1e2740"))
		# window onto the destination
		draw_rect(Rect2(cx - 31, 15, 62, 34), Color("2a3550"))
		draw_rect(Rect2(cx - 29, 17, 58, 30), Color("04060c"))
		for i: int in 14:
			var sx: float = cx - 28 + float((i * 37) % 56)
			var sy: float = 18 + float((i * 23) % 28)
			draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.35 + 0.4 * absf(sin(t * 1.3 + i))))
		if tex_dest == null:
			tex_dest = Pix.planet(9, Game.dest_id)
		Pix.sprite(self, tex_dest, Vector2(cx + 15, 31))
		draw_rect(Rect2(cx - 1, 17, 2, 30), Color("2a3550"))
		# ceiling lamps and their light
		draw_rect(Rect2(0, 0, w, 8), Color("0b0f1a"))
		for lx: float in [cx - 44.0, cx, cx + 44.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(lx - 5, 9), Vector2(lx + 5, 9), Vector2(lx + 20, wall_y), Vector2(lx - 20, wall_y)]), Color(1, 0.95, 0.8, 0.05))
			draw_rect(Rect2(lx - 6, 7, 12, 2), Color("fff2c0"))
		# hazard stripe at the foot of the wall
		draw_rect(Rect2(0, wall_y - 4, w, 4), Color("1a1a20"))
		for i: int in int(w / 6.0) + 1:
			draw_rect(Rect2(i * 6.0, wall_y - 4, 3, 4), Color("c9a227"))
		# glossy floor in one-point perspective
		draw_rect(Rect2(0, wall_y, w, size.y - wall_y), Color("0e1322"))
		draw_set_transform(Vector2(0, fy * 2.0), 0.0, Vector2(1, -1))
		_ship(cx, cy)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(0, fy, w, size.y - fy), Color(0.055, 0.075, 0.133, 0.72))
		for i: int in range(-4, 5):
			var xb: float = cx + i * 30.0
			draw_line(Vector2(cx + (xb - cx) * (wall_y - 30.0) / (size.y - 30.0), wall_y), Vector2(xb, size.y), Color("1b2440"), 1.0)
		for yy: float in [81.0, 86.0, 94.0, 106.0]:
			draw_rect(Rect2(0, yy, w, 1), Color("1b2440"))
		for lx2: float in [cx - 44.0, cx + 44.0]:
			draw_rect(Rect2(lx2 - 2, wall_y + 2, 4, size.y - wall_y - 4), Color(1, 0.95, 0.8, 0.05))
		for dy: int in range(-2, 3):
			var hw: float = floorf(30.0 * sqrt(1.0 - pow(dy / 2.6, 2.0)))
			draw_rect(Rect2(cx - hw, fy + dy, hw * 2.0, 1), Color(0, 0, 0, 0.45))
		_ship(cx, cy)
		var prop: int = int(Game.build.get("prop", 0))
		var rows: int = ceili(prop / 8.0)
		for i: int in prop:
			draw_rect(Rect2(6 + (i % 8) * 4, size.y - 8 - (i / 8) * 4, 3, 3), Color("ff9f43"))
		if rows > 0:
			Pix.text(self, Vector2(6, size.y - 12 - rows * 4), "FUEL", 8, Color("ff9f43"))

	func _ship(cx: float, cy: float) -> void:
		var b: Dictionary = Game.build
		var solar: int = int(b.get("solar", 0)) + int(b.get("solar_lite", 0))
		for i: int in mini(solar, 8):
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var k: int = i / 2
			var x: float = cx + side * (22 + k * 15) - (12 if side < 0 else 0)
			draw_rect(Rect2(x, cy - 10, 12, 18), Color("2b3f8a"))
			draw_rect(Rect2(x + 1, cy - 9, 4, 7), Color("4fd6ff"))
			draw_rect(Rect2(x + 7, cy - 9, 4, 7), Color("4fd6ff"))
			draw_rect(Rect2(x + 1, cy, 4, 7), Color("4fd6ff"))
			draw_rect(Rect2(x + 7, cy, 4, 7), Color("4fd6ff"))
		if solar > 0:
			draw_rect(Rect2(cx - 22 - (mini(solar, 8) / 2) * 15, cy - 2, 44 + (mini(solar, 8) / 2) * 30, 2), Color("a0a8c0"))
		# bus
		draw_rect(Rect2(cx - 14, cy - 14, 28, 26), Color("ffd75e"))
		draw_rect(Rect2(cx - 12, cy - 12, 24, 22), Color("c9a227"))
		draw_rect(Rect2(cx - 4, cy - 8, 8, 6), Color("4fd6ff"))
		var rtg: int = int(b.get("rtg", 0))
		for i: int in rtg:
			draw_rect(Rect2(cx - 22 + i * 12, cy + 14, 8, 12), Color("606878"))
			draw_rect(Rect2(cx - 21 + i * 12, cy + 16, 6, 2), Color("ff9f43"))
		if b.has("hga") or b.has("ka"):
			draw_rect(Rect2(cx - 16, cy - 32, 32, 4), Color("e8ecff"))
			draw_rect(Rect2(cx - 10, cy - 36, 20, 4), Color("e8ecff"))
			draw_rect(Rect2(cx - 1, cy - 28, 2, 14), Color("a0a8c0"))
		elif b.has("mga"):
			draw_rect(Rect2(cx - 7, cy - 24, 14, 4), Color("e8ecff"))
			draw_rect(Rect2(cx - 1, cy - 20, 2, 6), Color("a0a8c0"))
		elif b.has("lga"):
			draw_rect(Rect2(cx - 1, cy - 22, 2, 8), Color("a0a8c0"))
		if b.has("ascent"):
			draw_rect(Rect2(cx - 8, cy - 26 - (12 if b.has("hga") or b.has("ka") else 0), 16, 10), Color("d8dce8"))
		if b.has("legs"):
			draw_line(Vector2(cx - 12, cy + 12), Vector2(cx - 22, cy + 28), Color("a0a8c0"), 2)
			draw_line(Vector2(cx + 12, cy + 12), Vector2(cx + 22, cy + 28), Color("a0a8c0"), 2)
		if b.has("airbags"):
			for i: int in 3:
				draw_circle(Vector2(cx - 12 + i * 12, cy + 18), 7, Color(0.9, 0.85, 0.7, 0.8))
		if b.has("heatshield"):
			draw_rect(Rect2(cx - 20, cy + 12, 40, 4), Color("7a3a1a"))
		if b.has("chute"):
			draw_rect(Rect2(cx - 6, cy - 18, 12, 4), Color("ff7ad9"))
		if b.has("drone"):
			draw_rect(Rect2(cx + 18, cy + 14, 12, 6), Color("e8ecff"))
			draw_rect(Rect2(cx + 21, cy + 15, 6, 3), Color("4fd6ff"))
		if b.has("rover") or b.has("rover_big"):
			draw_rect(Rect2(cx - 30, cy + 16, 14, 6), Color("e8ecff"))
			draw_rect(Rect2(cx - 29, cy + 22, 3, 3), Color("303850"))
			draw_rect(Rect2(cx - 21, cy + 22, 3, 3), Color("303850"))
		if b.has("shield"):
			draw_rect(Rect2(cx - 15, cy - 15, 30, 28), Color(0.5, 0.9, 1.0, 0.25 + 0.15 * sin(t * 3.0)), false, 1.0)

var tab: String = "planner"
var calc: Dictionary = {}
var bars: Dictionary = {}
var tab_box: VBoxContainer = null
var tab_buttons: Dictionary = {}
var sign_box: VBoxContainer = null
var title: Label = null
var overlay: PanelContainer = null
var facts_box: VBoxContainer = null

const BAR_DEFS: Array = [
	["mass", "MASS", "engineer"],
	["power", "POWER", "engineer"],
	["fuel", "FUEL", "engineer"],
	["budget", "BUDGET", "planner"],
	["time", "TIME", "planner"],
	["data", "DATA", "comms"],
	["comms", "COMMS", "comms"],
]

func _ready() -> void:
	var top: HBoxContainer = UI.hbox(6)
	add_child(top)
	UI.place(top, 6, 4, 628, 22)
	top.add_child(UI.button("< MENU", func() -> void: Game.goto("menu")))
	var d: Dictionary = Game.dest()
	title = UI.label("MISSION: %s  (%s)" % [d["name"], d["diff"]], 13, UI.YELLOW)
	top.add_child(title)
	top.add_child(UI.spacer())
	top.add_child(UI.button("EXAMPLE SHIP", _example))
	var lb: Button = UI.button("REVIEW & LAUNCH >", _review, 11)
	UI.color_button(lb, UI.GREEN)
	top.add_child(lb)

	# left: resource bars
	var left: PanelContainer = UI.panel()
	add_child(left)
	UI.place(left, 6, 30, 172, 324)
	var lv: VBoxContainer = UI.vbox(2)
	left.add_child(lv)
	lv.add_child(UI.label("RESOURCES", 10, UI.CYAN))
	for def: Array in BAR_DEFS:
		var key: String = def[0]
		var row: HBoxContainer = UI.hbox(2)
		lv.add_child(row)
		var nm: Label = UI.label(def[1], 9, UI.TEXT)
		row.add_child(nm)
		row.add_child(UI.spacer())
		var val: Label = UI.label("", 8, UI.DIM)
		row.add_child(val)
		var bar: Bar = Bar.new()
		bar.custom_minimum_size = Vector2(150, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		lv.add_child(bar)
		bars[key] = {"bar": bar, "val": val, "name": nm}
	lv.add_child(UI.label("", 4))
	facts_box = UI.vbox(1)
	lv.add_child(facts_box)

	# middle: role tabs
	var mid: PanelContainer = UI.panel()
	add_child(mid)
	UI.place(mid, 184, 30, 300, 324)
	var mv: VBoxContainer = UI.vbox(4)
	mid.add_child(mv)
	var tabs: HBoxContainer = UI.hbox(2)
	mv.add_child(tabs)
	for r: Dictionary in Data.ROLES:
		var short: String = {"planner": "PLANNER", "engineer": "ENGINEER", "science": "SCIENCE", "comms": "COMMS"}[r["id"]]
		var b: Button = UI.button(short, _set_tab.bind(String(r["id"])), 9)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_buttons[r["id"]] = b
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(scroll)
	tab_box = UI.vbox(3)
	tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tab_box)

	# right: ship and sign-offs
	var right: PanelContainer = UI.panel()
	add_child(right)
	UI.place(right, 490, 30, 144, 324)
	var rv: VBoxContainer = UI.vbox(3)
	right.add_child(rv)
	rv.add_child(UI.label("YOUR SHIP", 10, UI.CYAN))
	var ship: ShipView = ShipView.new()
	ship.custom_minimum_size = Vector2(132, 150)
	ship.clip_contents = true
	rv.add_child(ship)
	rv.add_child(UI.label("SIGN-OFFS", 10, UI.CYAN))
	sign_box = UI.vbox(1)
	rv.add_child(sign_box)
	rv.add_child(UI.spacer())
	rv.add_child(UI.wrap_label("Hover parts and bars to see the real data behind them.", 8, UI.DIM, 130))
	refresh()

func _example() -> void:
	Game.example_build()
	refresh()

func _set_tab(id: String) -> void:
	tab = id
	refresh()

func refresh() -> void:
	calc = Game.calc()
	_update_bars()
	_update_tab()
	_update_signs()

func _update_bars() -> void:
	var st: Dictionary = calc["status"]
	var d: Dictionary = Game.dest()
	var rk: Dictionary = Data.ROCKETS[Game.rocket_id]
	var vals: Dictionary = {
		"mass": [float(calc["mass"]), float(calc["cap"]), "%s/%s kg" % [Game.fmt(calc["mass"]), Game.fmt(calc["cap"])],
			"Ship mass (parts + fuel) vs what %s can send to the %s on this path.\n%s\nTarget margin: %d%% (JPL rule: 35%% early in design)." % [rk["name"], String(d["name"]).capitalize(), rk["src"], roundi(float(d["margin"]) * 100)]],
		"power": [float(calc["draw_ops"]), float(calc["gen"]), "%d/%d W" % [roundi(calc["draw_ops"]), roundi(calc["gen"])],
			"Power used vs power made at the %s.\nSolar falls with distance squared: %s AU from the Sun -> %d%% of Earth's sunlight (%s W/m2, NASA).\nSolar arrays also lose 5%% a year (GMAT default). Night: %s h on batteries (needs %s Wh, you have %s Wh)." % [String(d["name"]).capitalize(), str(d["sun_au"]), roundi(100.0 / pow(float(d["sun_au"]), 2)), str(d["sun_wm2"]), str(d["night_hours"]), Game.fmt(calc["night_need"]), Game.fmt(calc["wh"])]],
		"fuel": [float(calc["prop_need"]), float(calc["prop"]), "%s/%s kg" % [Game.fmt(calc["prop_need"]), Game.fmt(calc["prop"])],
			"Fuel needed vs fuel carried.\nRocket equation: fuel = dry mass x (exp(dv / ve) - 1), ve = Isp x g0 = %.2f km/s (Isp 300 s, NASA GMAT default).\nBraking into orbit %.2f km/s + landing %.2f km/s (delta-v table, NASA / Wikipedia)." % [Game.ve(), float(calc["dv"]["capture"]), float(calc["dv"]["landing"])]],
		"budget": [float(calc["cost"]), float(calc["budget"]), "$%dM/$%dM" % [roundi(calc["cost"]), roundi(calc["budget"])],
			"Parts $%dM + rocket $%dM + mission control $%dM (game rule: $10M per year).\nReal costs: CAPSTONE $13.7M, MRO about $720M, Cassini about $3.3B." % [roundi(calc["parts_cost"]), roundi(calc["rocket_cost"]), roundi(calc["ops_cost"])]],
		"time": [float(calc["days"]), float(calc["limit"]), "%s/%s days" % [Game.fmt(calc["days"]), Game.fmt(calc["limit"])],
			"Travel %d days + %d days of work at the destination.\nLonger trips cost more to operate, and solar arrays wear out. MMRTG design life: 14 years (NASA)." % [int(Game.traj()["days"]), int(d["ops_days"])]],
		"data": [float(calc["data_exp"]), float(calc["store"]), "%s/%s Gb" % [Game.fmt(calc["data_exp"]), Game.fmt(calc["store"])],
			"Science data from %d samples vs on-board storage.\nEach sample makes %s Gb with your instruments (CRISM: 2-2.5 Gb per look, NASA)." % [int(d["samples_goal"]), Game.fmt(calc["gb_per_sample"])]],
		"comms": [float(calc["data_exp"]), float(calc["downlink"]), "%s/%s Gb" % [Game.fmt(calc["data_exp"]), Game.fmt(calc["downlink"])],
			"Data to send vs what your antenna can send in %d days (%d h of Deep Space Network time a day, game rule).\nRadio speed falls with distance squared: %s AU from Earth -> %s Mbps.\nRadio delay: %s." % [int(d["ops_days"]), int(Data.PASS_HOURS), str(d["earth_au"]), Game.fmt(calc["rate"]), d["light_delay"]]],
	}
	for key: String in bars:
		var v: Array = vals[key]
		var used: float = v[0]
		var limit: float = v[1]
		var s: String = st[key]
		var bar: Bar = bars[key]["bar"]
		bar.frac = used / limit if limit > 0.0 else 1.0
		bar.col = UI.status_color(s)
		bar.tooltip_text = v[3]
		bar.queue_redraw()
		var val: Label = bars[key]["val"]
		val.text = v[2]
		val.add_theme_color_override("font_color", UI.status_color(s))
		var nm: Label = bars[key]["name"]
		nm.tooltip_text = v[3]
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.clear(facts_box)
	facts_box.add_child(UI.label("AT %s" % Game.place(), 9, UI.CYAN))
	facts_box.add_child(UI.wrap_label("Gravity: %s m/s2 (Earth 9.81)" % str(d["gravity"]), 8, UI.TEXT, 150))
	facts_box.add_child(UI.wrap_label("Sunlight: %s W/m2" % str(d["sun_wm2"]), 8, UI.TEXT, 150))
	facts_box.add_child(UI.wrap_label("Air: %s" % d["atmos"], 8, UI.TEXT, 150))
	facts_box.add_child(UI.wrap_label("Radio delay: %s" % d["light_delay"], 8, UI.TEXT, 150))
	facts_box.add_child(UI.wrap_label("Source: NASA planetary fact sheets", 7, UI.DIM, 150))

func _role(id: String) -> Dictionary:
	for r: Dictionary in Data.ROLES:
		if r["id"] == id:
			return r
	return {}

func _update_tab() -> void:
	UI.clear(tab_box)
	for id: String in tab_buttons:
		var b: Button = tab_buttons[id]
		var r: Dictionary = _role(id)
		var issues: Array = calc["issues"][id]
		var mark: String = " !" if not issues.is_empty() else (" *" if Game.signed.has(id) else "")
		b.text = {"planner": "PLANNER", "engineer": "ENGINEER", "science": "SCIENCE", "comms": "COMMS"}[id] + mark
		var c: Color = r["color"]
		if id == tab:
			UI.color_button(b, c)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.add_theme_color_override("font_color", c if issues.is_empty() else UI.RED)
	var role: Dictionary = _role(tab)
	var idx: int = Data.ROLES.find(role)
	var who: String = ""
	if Game.players > 1:
		who = "PLAYER %d: " % (idx % Game.players + 1)
	tab_box.add_child(UI.label(who + String(role["name"]), 12, role["color"]))
	tab_box.add_child(UI.wrap_label(String(role["job"]), 9, UI.DIM, 280))
	match tab:
		"planner":
			_planner()
		"engineer":
			_parts(["power", "landing", "fuel", "protect"])
			var dv: Dictionary = calc["dv"]
			tab_box.add_child(UI.wrap_label("Rocket equation: fuel = %s kg dry x (exp(%.2f / %.2f) - 1) = %s kg." % [Game.fmt(calc["dry"]), float(dv["total"]), Game.ve(), Game.fmt(calc["prop_need"])], 8, UI.ORANGE, 280))
		"science":
			_parts(["science", "robot", "return"])
		"comms":
			_parts(["comms"])
			tab_box.add_child(UI.wrap_label("Downlink speed here: %s Mbps. Real: MRO sends up to 6 Mbps from Mars; New Horizons sent 1-4 kbps from Pluto and took a year to empty its memory." % Game.fmt(calc["rate"]), 8, UI.ORANGE, 280))
	var issues2: Array = calc["issues"][tab]
	if issues2.is_empty():
		tab_box.add_child(UI.label("No problems found.", 9, UI.GREEN))
	else:
		for s: String in issues2:
			tab_box.add_child(UI.wrap_label("! " + s, 9, UI.RED, 280))
	var signed: bool = Game.signed.has(tab)
	var sb: Button = UI.button("SIGNED OFF" if signed else "SIGN OFF " + String(role["name"]), _sign.bind(tab), 10)
	UI.color_button(sb, UI.GREEN if signed else role["color"])
	tab_box.add_child(sb)

func _planner() -> void:
	tab_box.add_child(UI.label("ROCKET", 10, UI.CYAN))
	for id: String in Data.ROCKETS:
		var r: Dictionary = Data.ROCKETS[id]
		var caps: Dictionary = r["cap"]
		var can: bool = caps.has(Game.dest_id)
		var txt: String = "%s  $%sM  %s" % [r["name"], Game.fmt(r["cost"]), ("%s kg here" % Game.fmt(caps[Game.dest_id])) if can else "can't reach"]
		var b: Button = UI.button(txt, _set_rocket.bind(id), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(r["src"])
		b.disabled = not can
		if id == Game.rocket_id:
			UI.color_button(b, UI.YELLOW)
		tab_box.add_child(b)
	tab_box.add_child(UI.label("FLIGHT PATH", 10, UI.CYAN))
	var arr: Array = Game.dest()["traj"]
	for i: int in arr.size():
		var tr: Dictionary = arr[i]
		var extra: String = ""
		if float(tr["cap_mult"]) < 1.0:
			extra = "  capacity x%s" % str(tr["cap_mult"])
		if float(tr["dv_mult"]) != 1.0:
			extra += "  braking fuel x%s" % str(tr["dv_mult"])
		var b2: Button = UI.button("%s: %s days%s" % [tr["name"], Game.fmt(tr["days"]), extra], _set_traj.bind(i), 9)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.tooltip_text = String(tr["src"])
		if i == Game.traj_idx:
			UI.color_button(b2, UI.YELLOW)
		tab_box.add_child(b2)
	tab_box.add_child(UI.label("COST", 10, UI.CYAN))
	tab_box.add_child(UI.label("Parts $%dM + rocket $%dM + operations $%dM" % [roundi(calc["parts_cost"]), roundi(calc["rocket_cost"]), roundi(calc["ops_cost"])], 9, UI.TEXT))
	tab_box.add_child(UI.label("= $%dM of $%dM budget" % [roundi(calc["cost"]), roundi(calc["budget"])], 9, UI.status_color(calc["status"]["budget"])))

func _parts(cats: Array) -> void:
	for cat: String in cats:
		var ids: Array = []
		for id: String in Data.PARTS:
			var p: Dictionary = Data.PARTS[id]
			if p["cat"] == cat and (not p.has("dest") or p["dest"] == Game.dest_id):
				ids.append(id)
		if ids.is_empty():
			continue
		tab_box.add_child(UI.label(String(Data.CAT_NAMES[cat]), 10, UI.CYAN))
		for id: String in ids:
			tab_box.add_child(_part_row(id))

func _part_row(id: String) -> Control:
	var p: Dictionary = Data.PARTS[id]
	var h: HBoxContainer = UI.hbox(3)
	var n: int = Game.count(id)
	var avail: bool = Game.part_available(id)
	var nm: Label = UI.label(String(p["name"]), 9, UI.TEXT if avail else Color("4a5270"))
	nm.custom_minimum_size = Vector2(118, 0)
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_PASS
	nm.tooltip_text = "%s\n\nSource: %s" % [p["desc"], p["src"]]
	h.add_child(nm)
	var stats: String = "%skg $%sM" % [Game.fmt(p["mass"]), Game.fmt(p["cost"])]
	if p.has("gen"):
		stats += " +%dW" % int(p["gen"])
	elif p.has("draw"):
		stats += " -%dW" % int(p["draw"])
	elif p.has("wh"):
		stats += " %dWh" % int(p["wh"])
	var st: Label = UI.label(stats, 8, UI.DIM)
	st.custom_minimum_size = Vector2(86, 0)
	st.tooltip_text = nm.tooltip_text
	st.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(st)
	if not avail:
		h.add_child(UI.label("TECH LAB", 8, UI.YELLOW))
		return h
	if p.get("locked_in", false):
		h.add_child(UI.label("x1 built in", 8, UI.DIM))
		return h
	var minus: Button = UI.button("-", _add.bind(id, -1), 9, 16)
	minus.disabled = n == 0
	h.add_child(minus)
	var cnt: Label = UI.label("x%d" % n, 9, UI.YELLOW if n > 0 else UI.DIM)
	cnt.custom_minimum_size = Vector2(22, 0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(cnt)
	var plus: Button = UI.button("+", _add.bind(id, 1), 9, 16)
	plus.disabled = n >= int(p["max"])
	h.add_child(plus)
	return h

func _add(id: String, n: int) -> void:
	var step: int = n
	if id == "prop" and Input.is_key_pressed(KEY_SHIFT):
		step = n * 10
	Game.add_part(id, step)
	refresh()

func _set_rocket(id: String) -> void:
	Game.rocket_id = id
	Game.signed = {}
	refresh()

func _set_traj(i: int) -> void:
	Game.traj_idx = i
	Game.signed = {}
	refresh()

func _sign(id: String) -> void:
	if Game.signed.has(id):
		Game.signed.erase(id)
	else:
		Game.signed[id] = true
	refresh()

func _update_signs() -> void:
	UI.clear(sign_box)
	for r: Dictionary in Data.ROLES:
		var id: String = r["id"]
		var issues: Array = calc["issues"][id]
		var s: String = "SIGNED" if Game.signed.has(id) else ("problems" if not issues.is_empty() else "waiting")
		var c: Color = UI.GREEN if Game.signed.has(id) else (UI.RED if not issues.is_empty() else UI.DIM)
		var h: HBoxContainer = UI.hbox(2)
		sign_box.add_child(h)
		h.add_child(UI.label({"planner": "Planner", "engineer": "Engineer", "science": "Scientist", "comms": "Comms"}[id], 9, r["color"]))
		h.add_child(UI.spacer())
		h.add_child(UI.label(s, 8, c))

func _review() -> void:
	if overlay != null:
		overlay.queue_free()
	overlay = UI.panel(Color("0b0f1e"), UI.YELLOW)
	add_child(overlay)
	UI.place(overlay, 110, 40, 420, 280)
	var v: VBoxContainer = UI.vbox(3)
	overlay.add_child(v)
	v.add_child(UI.label("MISSION REVIEW BOARD", 14, UI.YELLOW))
	var bad: int = 0
	var st: Dictionary = calc["status"]
	for def: Array in BAR_DEFS:
		var key: String = def[0]
		var s: String = st[key]
		if s == "bad":
			bad += 1
		var h: HBoxContainer = UI.hbox(4)
		v.add_child(h)
		var l1: Label = UI.label(String(def[1]), 9, UI.TEXT)
		l1.custom_minimum_size = Vector2(70, 0)
		h.add_child(l1)
		h.add_child(UI.label({"ok": "GO", "warn": "GO, but low margin", "bad": "NO-GO"}[s], 9, UI.status_color(s)))
	var unsigned: int = 0
	for r: Dictionary in Data.ROLES:
		if not Game.signed.has(r["id"]):
			unsigned += 1
	var all_issues: int = 0
	for k: String in calc["issues"]:
		all_issues += (calc["issues"][k] as Array).size()
	var verdict: String
	if bad == 0 and all_issues == 0:
		verdict = "ALL SYSTEMS GO."
	else:
		verdict = "NO-GO: %d problems found. You can still launch and see what happens." % all_issues
	if unsigned > 0:
		verdict += "  (%d roles have not signed off.)" % unsigned
	v.add_child(UI.wrap_label(verdict, 10, UI.GREEN if all_issues == 0 else UI.RED, 400))
	v.add_child(UI.spacer())
	var h2: HBoxContainer = UI.hbox(8)
	v.add_child(h2)
	h2.add_child(UI.button("BACK TO DESIGN", _close_review))
	h2.add_child(UI.spacer())
	var go: Button = UI.button("LAUNCH!", _launch, 12, 120)
	UI.color_button(go, UI.GREEN if all_issues == 0 else UI.ORANGE)
	h2.add_child(go)

func _close_review() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

func _launch() -> void:
	Game.start_run()
	Game.run["mode"] = "out"
	Game.goto("flight")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), UI.BG)
