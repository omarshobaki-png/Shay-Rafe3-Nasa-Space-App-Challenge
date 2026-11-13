extends Control
## Title, mission select, players, Tech Lab, how to play, sources.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const BG_TEX: Texture2D = preload("res://art/bg_space.png")

var t: float = 0.0
var overlay: PanelContainer = null
var funds_label: Label = null
var player_buttons: Array = []

func _ready() -> void:
	var root: VBoxContainer = UI.vbox(6)
	add_child(root)
	UI.place(root, 16, 10, 608, 340)
	var title: Label = UI.label("SPACE MISSION DESIGNER", 24, UI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub: Label = UI.label("Build a spacecraft with real NASA numbers. Fly it. Find out why it worked or failed.", 10, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var cards: HBoxContainer = UI.hbox(8)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cards)
	for id: String in ["moon", "mars", "saturn"]:
		cards.add_child(_card(id))
	var bottom: HBoxContainer = UI.hbox(6)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	bottom.add_child(UI.label("PLAYERS:", 10, UI.DIM))
	for n: int in [1, 2, 3, 4]:
		var b: Button = UI.button(str(n), _set_players.bind(n), 10, 22)
		player_buttons.append(b)
		bottom.add_child(b)
	_set_players(Game.players)
	bottom.add_child(UI.label("   ", 10))
	funds_label = UI.label("", 10, UI.YELLOW)
	bottom.add_child(funds_label)
	bottom.add_child(UI.button("TECH LAB", _show_tech))
	bottom.add_child(UI.button("HOW TO PLAY", _show_help))
	bottom.add_child(UI.button("NASA DATA & CREDITS", _show_sources))
	var team: Label = UI.label("Team Shay Rafe3  -  NASA Space Apps Challenge 2026  -  Space Mission Design Game", 8, Color("4a5270"))
	team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(team)
	_update_funds()

func _card(id: String) -> PanelContainer:
	var d: Dictionary = Data.DEST[id]
	var col: Color = {"moon": UI.GREEN, "mars": UI.YELLOW, "saturn": UI.RED}[id]
	var p: PanelContainer = UI.panel(UI.PANEL, col.darkened(0.3))
	p.custom_minimum_size = Vector2(196, 238)
	var v: VBoxContainer = UI.vbox(3)
	p.add_child(v)
	var head: HBoxContainer = UI.hbox(4)
	v.add_child(head)
	var trx: TextureRect = TextureRect.new()
	trx.texture = Pix.planet(12 if id == "saturn" else 22, id)
	trx.custom_minimum_size = Vector2(62, 49)
	trx.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(trx)
	var hv: VBoxContainer = UI.vbox(0)
	head.add_child(hv)
	hv.add_child(UI.label(String(d["name"]), 16, UI.TEXT))
	hv.add_child(UI.label(String(d["diff"]), 10, col))
	if Game.best.has(id):
		hv.add_child(UI.label("Best: %d%%" % int(Game.best[id]), 9, UI.DIM))
	var goal: String = {
		"moon": "Land, collect 3 rocks, fly them home.",
		"mars": "Land a rover, study 4 rocks, send the data home.",
		"saturn": "Reach orbit, send a drone through the rings for 5 samples.",
	}[id]
	v.add_child(UI.wrap_label("GOAL: " + goal, 9, UI.CYAN, 180))
	for f: String in d["facts"]:
		v.add_child(UI.wrap_label("- " + f, 8, UI.DIM, 180))
	v.add_child(UI.spacer())
	var b: Button = UI.button("PLAY  " + String(d["name"]), _play.bind(id), 11)
	UI.color_button(b, col)
	v.add_child(b)
	return p

func _set_players(n: int) -> void:
	Game.players = n
	for i: int in player_buttons.size():
		var b: Button = player_buttons[i]
		b.modulate = Color(1, 1, 1) if i + 1 == n else Color(0.5, 0.5, 0.6)

func _play(id: String) -> void:
	Game.new_mission(id)
	Game.goto("builder")

func _update_funds() -> void:
	funds_label.text = "CREDITS: %d" % Game.funds

func _open(title: String) -> VBoxContainer:
	if overlay != null:
		overlay.queue_free()
	overlay = UI.panel(Color("0b0f1e"), UI.YELLOW)
	add_child(overlay)
	UI.place(overlay, 60, 30, 520, 300)
	var v: VBoxContainer = UI.vbox(4)
	overlay.add_child(v)
	var h: HBoxContainer = UI.hbox()
	v.add_child(h)
	h.add_child(UI.label(title, 14, UI.YELLOW))
	h.add_child(UI.spacer())
	h.add_child(UI.button("CLOSE", _close))
	return v

func _close() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

func _show_tech() -> void:
	var v: VBoxContainer = _open("TECH LAB  -  credits: %d" % Game.funds)
	v.add_child(UI.wrap_label("Earn credits by finishing mission goals. Spend them on new technology, then build better ships.", 9, UI.DIM, 500))
	for id: String in Data.TECH:
		var tdat: Dictionary = Data.TECH[id]
		var h: HBoxContainer = UI.hbox(6)
		v.add_child(h)
		var nm: Label = UI.label(String(tdat["name"]), 10, UI.TEXT)
		nm.custom_minimum_size = Vector2(150, 0)
		h.add_child(nm)
		h.add_child(UI.wrap_label(String(tdat["desc"]), 9, UI.DIM, 230))
		if Game.tech.has(id):
			h.add_child(UI.label("OWNED", 10, UI.GREEN))
		else:
			var b: Button = UI.button("BUY %d" % int(tdat["cost"]), _buy.bind(id), 10, 70)
			b.disabled = Game.funds < int(tdat["cost"])
			h.add_child(b)
	v.add_child(UI.spacer())
	v.add_child(UI.button("RESET SAVE (start over)", _reset))

func _buy(id: String) -> void:
	Game.buy_tech(id)
	_update_funds()
	_show_tech()

func _reset() -> void:
	Game.reset_save()
	_update_funds()
	_show_tech()

func _show_help() -> void:
	var v: VBoxContainer = _open("HOW TO PLAY")
	var lines: Array = [
		"1. Pick a mission. Moon is easy, Mars is medium, Saturn is hard.",
		"2. Up to 4 players share the keyboard. Each takes a role tab: PLANNER (rocket, path, budget, time), ENGINEER (mass, power, fuel), SCIENTIST (instruments, robots), COMMS (data, antennas). Fix your red bars, then press SIGN OFF.",
		"3. Every bar uses real physics and NASA numbers. Hover any part or bar to see where the number comes from.",
		"4. Press LAUNCH. The flight is simulated: power falls with distance from the Sun, fuel follows the rocket equation, and real solar storms from NASA's DONKI database can hit you.",
		"5. LAND: hold UP / W / SPACE to fire the engine, LEFT / RIGHT to steer. Touch down slower than your landing gear allows.",
		"6. EXPLORE: LEFT / RIGHT to drive, UP to jump (gravity is real: you jump 6x higher on the Moon), E to drill a rock, E at the lander to finish.",
		"7. SATURN: fly the drone into the rings, grab ice samples, avoid rocks, dock back with the orbiter.",
		"8. Read the report: it tells you WHY things worked or failed. Redesign and fly again. Credits buy new tech.",
	]
	for l: String in lines:
		v.add_child(UI.wrap_label(l, 9, UI.TEXT, 500))

func _show_sources() -> void:
	var v: VBoxContainer = _open("NASA DATA & CREDITS")
	v.add_child(UI.label("Data sources", 10, UI.CYAN))
	for s: String in Data.SOURCES:
		v.add_child(UI.wrap_label("- " + s, 8, UI.TEXT, 500))
	v.add_child(UI.label("AI use (Space Apps rules)", 10, UI.CYAN))
	v.add_child(UI.wrap_label("Game idea and design: Team Shay Rafe3. Code and the code-drawn pixel art were written with help from Claude (AI) and checked by the team. No NASA logos are used.", 8, UI.TEXT, 500))

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	Pix.tiled(self, BG_TEX, 0, t * 4.0)
	Pix.stars(self, t, Vector2(640, 360), 60, 11, Vector2(-t * 6.0, 0))
