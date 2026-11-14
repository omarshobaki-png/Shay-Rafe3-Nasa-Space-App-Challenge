extends SceneTree
## Prints the battery of the example ship on every land task (dev check for the per-target battery cost).
func _initialize() -> void:
	var game: Node = root.get_node("Game")
	for d: String in ["moon", "mercury", "venus", "mars"]:
		for t: int in 3:
			game.set("difficulty", t)
			game.call("new_mission", d)
			game.call("set_task", t)
			game.call("example_build")
			game.call("start_run", 1)
			var run: Dictionary = game.get("run")
			var c: Dictionary = run["calc"]
			print("%s %d job=%s goal=%d wh=%d batt=%s" % [d, t, game.call("job"), int(game.call("dest")["samples_goal"]), int(run["wh"]), str(run["use"].get("battery", {}))])
	quit()
