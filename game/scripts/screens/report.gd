extends Control
## Mission report: goals, the chain of causes, role scores, real mission, credits.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")

const TIPS: Array = [
	["TOO HEAVY", "ENGINEER + PLANNER: remove mass or pick a bigger rocket. A slower path can also save fuel mass."],
	["OUT OF POWER", "ENGINEER: far from the Sun, solar panels fail. Use an MMRTG nuclear generator, like Cassini and Perseverance."],
	["NOT ENOUGH FUEL", "ENGINEER: add propellant until the FUEL bar is green. Fuel grows fast with mass (rocket equation)."],
	["BURNED UP", "SCIENTIST: Mars has air. A heat shield is a must."],
	["NO PARACHUTE", "SCIENTIST: a parachute slows you from 420 to 90 m/s for free."],
	["CRASH", "Pilot: fire the engine earlier and touch down slowly. Landing legs or airbags raise the speed limit."],
	["STRANDED", "ENGINEER: bring more solar power or batteries, and keep 30% battery for the trip home."],
	["BATTERY EMPTY", "ENGINEER: Mars nights last 12 hours. Add batteries or an MMRTG."],
	["SOLAR STORM", "ENGINEER: radiation shielding protects electronics from solar storms."],
	["Storage full", "COMMS: add a data recorder."],
	["Sent", "COMMS: a bigger antenna sends data faster. Radio speed falls with distance squared."],
	["No ascent stage", "SCIENTIST: add the ascent stage to bring samples home."],
	["drone was lost", "Pilot: save fuel to fly the drone back up to the orbiter."],
	["No drone", "SCIENTIST: Saturn has no ground. Add the sampling drone."],
	["Samples collected", "SCIENTIST: a rover and a drill reach more rocks. Watch the battery."],
	["Ring samples", "Pilot: fly through the ring band and grab the ice grains."],
]

func _ready() -> void:
	var r: Dictionary = Game.run
	var d: Dictionary = Game.dest()
	var score: int = int(r.get("score", 0))
	var head: String = "MISSION SUCCESS" if score >= 100 else ("PARTIAL SUCCESS" if score >= 50 else "MISSION FAILED")
	Audio.play("success" if score >= 50 else "error", -3.0)
	if score > 0:
		Audio.play("coin", -6.0)
	var hc: Color = UI.GREEN if score >= 100 else (UI.YELLOW if score >= 50 else UI.RED)
	var top: HBoxContainer = UI.hbox(8)
	add_child(top)
	UI.place(top, 8, 4, 624, 28)
	top.add_child(UI.label(head, 18, hc))
	top.add_child(UI.label("%s  -  %d%% of goals" % [d["name"], score], 11, UI.DIM))
	top.add_child(UI.spacer())
	top.add_child(UI.label("+%d CREDITS  (total %d)" % [int(r.get("reward", 0)), Game.funds], 11, UI.YELLOW))

	var left: PanelContainer = UI.panel()
	add_child(left)
	UI.place(left, 8, 36, 168, 284)
	var lv: VBoxContainer = UI.vbox(3)
	left.add_child(lv)
	lv.add_child(UI.label("GOALS", 10, UI.CYAN))
	var obj: Dictionary = r["obj"]
	for o: String in obj:
		var ok: bool = obj[o]
		var name: String = String(Data.OBJ_NAMES[o])
		if o == "samples":
			name += " (%d/%d)" % [int(r["samples"]), int(d["samples_goal"])]
		lv.add_child(UI.wrap_label(("[OK] " if ok else "[--] ") + name, 9, UI.GREEN if ok else UI.RED, 150))
	lv.add_child(UI.label("", 4))
	lv.add_child(UI.label("TEAM SCORES", 10, UI.CYAN))
	var roles: Dictionary = r.get("roles", {})
	for role: Dictionary in Data.ROLES:
		var v: int = int(roles.get(role["id"], 0))
		var h: HBoxContainer = UI.hbox(2)
		lv.add_child(h)
		h.add_child(UI.label({"planner": "Planner", "engineer": "Engineer", "science": "Scientist", "comms": "Comms"}[role["id"]], 9, role["color"]))
		h.add_child(UI.spacer())
		h.add_child(UI.label("%d" % v, 9, UI.TEXT))
		var bar: ColorRect = ColorRect.new()
		bar.color = role["color"]
		bar.custom_minimum_size = Vector2(maxf(2.0, 150.0 * v / 100.0), 3)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lv.add_child(bar)

	var mid: PanelContainer = UI.panel()
	add_child(mid)
	UI.place(mid, 182, 36, 270, 284)
	var mv: VBoxContainer = UI.vbox(3)
	mid.add_child(mv)
	mv.add_child(UI.label("WHAT HAPPENED, AND WHY", 10, UI.CYAN))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(scroll)
	var logv: VBoxContainer = UI.vbox(4)
	logv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(logv)
	var tip: String = ""
	for e: Dictionary in r["log"]:
		var ok2: bool = e["ok"]
		var txt: String = String(e["text"])
		logv.add_child(UI.wrap_label(("OK  " if ok2 else "!!  ") + txt, 9, UI.GREEN if ok2 else UI.RED, 250))
		if not ok2 and tip == "":
			for tp: Array in TIPS:
				if txt.contains(String(tp[0])):
					tip = tp[1]
					break

	var right: PanelContainer = UI.panel()
	add_child(right)
	UI.place(right, 458, 36, 174, 284)
	var rv: VBoxContainer = UI.vbox(3)
	right.add_child(rv)
	if tip != "":
		rv.add_child(UI.label("TRY THIS", 10, UI.YELLOW))
		rv.add_child(UI.wrap_label(tip, 9, UI.TEXT, 160))
		rv.add_child(UI.label("", 4))
	rv.add_child(UI.label("THE REAL THING", 10, UI.CYAN))
	rv.add_child(UI.wrap_label(String(d["real"]), 9, UI.TEXT, 160))
	var c: Dictionary = r["calc"]
	rv.add_child(UI.label("", 4))
	rv.add_child(UI.label("YOUR SHIP", 10, UI.CYAN))
	rv.add_child(UI.wrap_label("%s kg, $%dM, %d W at %s, %s Mbps radio." % [Game.fmt(c["mass"]), roundi(c["cost"]), roundi(c["gen"]), Game.place().capitalize(), Game.fmt(c["rate"])], 9, UI.DIM, 160))

	var bottom: HBoxContainer = UI.hbox(8)
	add_child(bottom)
	UI.place(bottom, 8, 326, 624, 26)
	bottom.add_child(UI.button("MISSION SELECT", func() -> void: Game.goto("menu"), 11))
	bottom.add_child(UI.spacer())
	var again: Button = UI.button("REDESIGN & FLY AGAIN", _again, 12)
	UI.color_button(again, UI.GREEN)
	bottom.add_child(again)

func _again() -> void:
	Game.signed = {}
	Game.goto("builder")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), UI.BG)
