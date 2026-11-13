extends Control
## Dev-only contact sheet for the ship kit (not reachable from the game's menus).
##   bash tools/dev/shot.sh kit mars out.png 1.0 [call=debug_x]
## No call: the example ship of the destination. Calls (one at a time):
##   debug_bare, debug_max, debug_three (the three example ships), debug_parts (every part alone with
##   its id), debug_icons (bin icons and launchers), debug_fuel, debug_fuel2 (the tank at
##   growing unit counts), debug_power (wings, RTGs, racks filling up), debug_slots (next_slot ghosts),
##   debug_hit (hit boxes), debug_hl (highlight), debug_check (prints layout checks to the log).

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const ShipKit = preload("res://scripts/ship_kit.gd")

var mode: String = "ship"
var show_hit: bool = false
var hl: String = ""

func debug_bare() -> void:
	Game.build = {"bus": 1}
	queue_redraw()

func debug_max() -> void:
	Game.build = _max_build()
	queue_redraw()

func debug_three() -> void:
	mode = "three"
	queue_redraw()

func debug_parts() -> void:
	mode = "parts"
	queue_redraw()

func debug_icons() -> void:
	mode = "icons"
	queue_redraw()

func debug_fuel() -> void:
	mode = "fuel"
	queue_redraw()

func debug_fuel2() -> void:
	mode = "fuel2"
	queue_redraw()

func debug_power() -> void:
	mode = "power"
	queue_redraw()

func debug_slots() -> void:
	mode = "slots"
	queue_redraw()

func debug_hit() -> void:
	show_hit = true
	queue_redraw()

func debug_hl() -> void:
	hl = "prop"
	queue_redraw()

func _max_build() -> Dictionary:
	var b: Dictionary = {}
	for id: String in Data.PARTS:
		b[id] = int(Data.PARTS[id]["max"])
	return b

func _example(dest: String) -> Dictionary:
	var keep_dest: String = Game.dest_id
	var keep_build: Dictionary = Game.build
	var keep_rocket: String = Game.rocket_id
	Game.dest_id = dest
	Game.example_build()
	var b: Dictionary = Game.build
	Game.dest_id = keep_dest
	Game.build = keep_build
	Game.rocket_id = keep_rocket
	return b

## Layout checks: every unit of every part changes the picture, next_slot agrees with layout,
## nothing is fully covered by one sprite in front of it. Prints "KIT CHECK ..." lines.
func debug_check() -> void:
	var bad: int = 0
	var full: Dictionary = _max_build()
	for id: String in Data.PARTS:
		if id == "bus":
			continue
		for start: Dictionary in [{"bus": 1}, full]:
			var b: Dictionary = start.duplicate()
			b.erase(id)
			for n: int in int(Data.PARTS[id]["max"]):
				var slot: Dictionary = ShipKit.next_slot(b, id)
				var before: String = _sig(b)
				b[id] = n + 1
				if _sig(b) == before:
					print("KIT CHECK no change: ", id, " ", n + 1)
					bad += 1
				var found: bool = false
				for it: Dictionary in ShipKit.layout(b):
					if it["id"] == id and not it.has("deco") and it["pos"] == slot.get("pos") and it["tex"] == slot.get("tex"):
						found = true
				if not found:
					print("KIT CHECK next_slot disagrees: ", id, " ", n + 1)
					bad += 1
			if not ShipKit.next_slot(b, id).is_empty():
				print("KIT CHECK next_slot not empty at max: ", id)
				bad += 1
	var items: Array = ShipKit.layout(full)
	for i: int in items.size():
		var a: Rect2 = items[i]["box"]
		for j: int in range(i + 1, items.size()):
			var f: Rect2 = items[j]["box"]
			if f.encloses(a) and not items[i].has("deco") and items[j]["id"] != "heatshield_front" and items[j]["id"] != "shield":
				print("KIT CHECK ", items[i]["id"], " ", items[i]["n"], " is inside the box of ", items[j]["id"])
	for dest: String in ["moon", "mars", "saturn"]:
		print("KIT CHECK size ", dest, " ", ShipKit.bounds(_example(dest)).size)
	print("KIT CHECK size bare ", ShipKit.bounds({"bus": 1}).size, " max ", ShipKit.bounds(full).size, " ", ShipKit.bounds(full))
	print("KIT CHECK done, problems: ", bad)

func _sig(b: Dictionary) -> String:
	var s: String = ""
	for it: Dictionary in ShipKit.layout(b):
		var t: Texture2D = it["tex"]
		s += "%s@%s;" % [t.resource_path if t != null else "-", it["pos"]]
	return s

func _ship(b: Dictionary, centre: Vector2, label: String) -> void:
	var r: Rect2 = ShipKit.bounds(b)
	var o: Vector2 = (centre - r.get_center()).floor()
	ShipKit.draw(self, o, b, Color.WHITE, hl)
	if show_hit:
		for it: Dictionary in ShipKit.layout(b):
			var h: Rect2 = it["rect"]
			if h.size.x > 0.0:
				draw_rect(Rect2(o + h.position + Vector2(0.5, 0.5), h.size - Vector2.ONE), Color(0.3, 1.0, 0.5, 0.7), false, 1.0)
		draw_rect(Rect2(o + r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), Color(1, 0.8, 0.2, 0.6), false, 1.0)
	Pix.text_c(self, centre.x, 352, "%s %dx%d" % [label, int(r.size.x), int(r.size.y)], 10, UI.YELLOW)

func _row(builds: Array, labels: Array) -> void:
	var w: float = 640.0 / builds.size()
	for i: int in builds.size():
		_ship(builds[i], Vector2(w * (i + 0.5), 172), String(labels[i]))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("10141f"))
	match mode:
		"ship":
			_ship(Game.build, Vector2(320, 172), Game.dest_id)
		"three":
			_row([_example("moon"), _example("mars"), _example("saturn")], ["moon", "mars", "saturn"])
		"fuel", "fuel2":
			var bs: Array = []
			var ls: Array = []
			for u: int in ([0, 1, 2, 5, 8, 9, 16] if mode == "fuel" else [24, 25, 26, 40, 80]):
				bs.append({"bus": 1, "prop": u, "legs": 1} if u > 0 else {"bus": 1, "legs": 1})
				ls.append("fuel %d" % u)
			_row(bs, ls)
		"power":
			_row([{"bus": 1, "solar": 1, "battery": 1, "recorder": 1, "rtg": 1},
				{"bus": 1, "solar": 5, "battery": 4, "battery_hi": 3, "recorder": 3, "rtg": 2},
				{"bus": 1, "solar": 8, "solar_lite": 8, "battery": 6, "battery_hi": 6, "recorder": 4, "rtg": 4}],
				["1", "some", "all"])
		"slots":
			_slots()
		"parts":
			_parts()
		"icons":
			_icons()

func _slots() -> void:
	var b: Dictionary = Game.build
	var o: Vector2 = (Vector2(320, 172) - ShipKit.bounds(b).get_center()).floor()
	ShipKit.draw(self, o, b)
	for id: String in Data.PARTS:
		var s: Dictionary = ShipKit.next_slot(b, id)
		if s.is_empty():
			continue
		var tex: Texture2D = s["tex"]
		var p: Vector2 = s["pos"]
		if tex != null and id != "prop" and id != "shield":
			draw_texture(tex, o + p, Color(0.4, 1.0, 0.6, 0.45))
		var node: Vector2 = s["node"]
		draw_rect(Rect2(o + node - Vector2(1, 1), Vector2(3, 3)), Color(0.2, 1.0, 0.4))

func _parts() -> void:
	var ids: Array = Data.PARTS.keys()
	var x: float = 8.0
	var y: float = 8.0
	var row_h: float = 0.0
	for id: String in ids:
		var b: Dictionary = {"bus": 1, id: 1}
		if id == "prop":
			b[id] = 5
		var items: Array = []
		var box: Rect2 = Rect2()
		for it: Dictionary in ShipKit.layout(b):
			if it["id"] == id or it.get("owner", "") == id:
				items.append(it)
				var ib: Rect2 = it["box"]
				box = ib if box.size == Vector2.ZERO else box.merge(ib)
		var w: float = maxf(box.size.x, id.length() * 6.0) + 10.0
		if x + w > 636.0:
			x = 8.0
			y += row_h + 18.0
			row_h = 0.0
		for it: Dictionary in items:
			var tex: Texture2D = it["tex"]
			var p: Vector2 = it["pos"]
			if tex != null:
				draw_texture(tex, Vector2(x, y) + p - box.position)
		Pix.text(self, Vector2(x, y + box.size.y + 11), id, 10, UI.CYAN)
		x += w
		row_h = maxf(row_h, box.size.y)

func _icons() -> void:
	var x: float = 12.0
	var y: float = 10.0
	for id: String in Data.PARTS:
		draw_rect(Rect2(x - 2, y - 2, 28, 28), Color("1b2233"))
		var t: Texture2D = ShipKit.icon(id)
		if t != null:
			draw_texture(t, Vector2(x, y) + ((Vector2(24, 24) - t.get_size()) / 2.0).floor())
		Pix.text(self, Vector2(x - 2, y + 37), id.substr(0, 7), 10, UI.CYAN)
		x += 48.0
		if x > 600.0:
			x = 12.0
			y += 46.0
	x = 12.0
	y += 50.0
	for rid: String in Data.ROCKETS:
		draw_rect(Rect2(x - 2, y - 2, 28, 28), Color("1b2233"))
		var t2: Texture2D = ShipKit.launcher_icon(rid)
		if t2 != null:
			draw_texture(t2, Vector2(x, y) + ((Vector2(24, 24) - t2.get_size()) / 2.0).floor())
		x += 34.0
	x = 220.0
	for rid: String in Data.ROCKETS:
		var lv: Texture2D = ShipKit.launcher(rid)
		if lv != null:
			draw_texture(lv, Vector2(x - lv.get_width() / 2, 350 - lv.get_height()))
			Pix.text_c(self, x, 358, "%s %dx%d" % [rid, lv.get_width(), lv.get_height()], 10, UI.CYAN)
		x += 100.0
