extends Control
## Root: owns the theme and swaps screens.

const UI = preload("res://scripts/ui.gd")
const SCREENS: Dictionary = {
	"menu": preload("res://scripts/screens/menu.gd"),
	"builder": preload("res://scripts/screens/builder.gd"),
	"launch": preload("res://scripts/screens/launch.gd"),
	"flight": preload("res://scripts/screens/flight.gd"),
	"landing": preload("res://scripts/screens/landing.gd"),
	"surface": preload("res://scripts/screens/surface.gd"),
	"probe": preload("res://scripts/screens/probe.gd"),
	"report": preload("res://scripts/screens/report.gd"),
	"kit": preload("res://scripts/screens/kit_test.gd"),  # dev-only contact sheet
	"fx": preload("res://scripts/screens/fx_test.gd"),    # dev-only contact sheet
}

var current: Node = null
var fade: ColorRect = null
const MUSIC: Dictionary = {"menu": "theme", "builder": "theme", "report": "theme"}

func _ready() -> void:
	theme = UI.make_theme()
	Game.main = self
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.02, 0.05, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.size = Vector2(640, 360)
	# debug hook: -- screen=landing dest=mars shot=C:/x.png wait=2
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.has("screen"):
		if args.has("diff"):
			Game.difficulty = int(String(args["diff"]))  # 0 easy, 1 normal, 2 hard
		Game.new_mission(String(args.get("dest", "moon")))
		Game.example_build()
		var sc: String = args["screen"]
		if sc != "menu" and sc != "builder" and sc != "kit" and sc != "fx":
			Game.start_run()
			Game.run["mode"] = String(args.get("mode", "out"))
			# screen=launch starts at the pad; screen=flight starts at the cruise (launch already done);
			# every later screen also gets the cruise and the arrival done for it
			if sc != "launch" and String(Game.run["mode"]) == "out" or (sc != "launch" and sc != "flight"):
				Game.phase_launch()
				Game.run["launched"] = true
			if sc != "launch" and sc != "flight":
				Game.phase_cruise()
				Game.phase_arrive()
			if sc == "report":
				if String(Game.dest().get("kind", "land")) == "ring":
					Game.probe_result(int(Game.dest()["samples_goal"]), true, 2.0)
				else:
					Game.surface_result(int(Game.dest()["samples_goal"]), 2000.0, 2.0)
				Game.phase_home()
				Game.finish()
		goto(sc)
		if args.has("tab"):
			current.set("tab", String(args["tab"]))
			current.call("refresh")
		# call=debug_x[,debug_y] runs methods of the screen, to set up a state for a screenshot
		if args.has("call"):
			for m: String in String(args["call"]).split(","):
				if current.has_method(m):
					current.call(m)
	else:
		goto("menu")
	if args.has("mptest"):
		# dev only: a scripted 2-player online mission (scripts/mp_test.gd)
		var mp: Node = (load("res://scripts/mp_test.gd") as GDScript).new()
		add_child(mp)
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("wait", "1.5"))).timeout
		get_viewport().get_texture().get_image().save_png(String(args["shot"]))
		get_tree().quit()

func goto(screen: String) -> void:
	# the outbound flight begins with the launch screen, which hands over to "flight" for the cruise
	if screen == "flight" and String(Game.run.get("mode", "out")) == "out" and not bool(Game.run.get("launched", false)):
		screen = "launch"
	if current != null:
		current.queue_free()
	var script: GDScript = SCREENS[screen]
	var node: Control = script.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.size = Vector2(640, 360)
	current = node
	add_child(node)
	# fade in from black on every screen change
	if fade.get_parent() == null:
		add_child(fade)
	move_child(fade, -1)
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.35)
	Audio.stop_loops()
	if screen == "launch":
		screen = "flight"  # same music and ambience as the flight
	if Audio.has_method("scene"):
		Audio.call("scene", screen)  # audio.gd picks the music and ambience for this screen
	else:
		Audio.music(String(MUSIC.get(screen, "mission")))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
