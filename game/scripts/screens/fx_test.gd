extends Control
## Dev-only contact sheet for the effects kit (not reachable from the game's menus).
##   bash tools/dev/shot.sh fx moon out.png 1.0                      overview, everything animated
##   ... call=debug_flames | debug_flames_big | debug_smoke | debug_boom | debug_small | debug_scene
##   add ,debug_light for the pale sky / Mars backgrounds, ,debug_freeze to stop the clock at 0
## Keys when run by hand: 1..7 pages, L light background.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/pix.gd")
const Fx = preload("res://scripts/fx.gd")

const DARK: Color = Color("10141f")
const SKY: Color = Color("96beec")
const MARS: Color = Color("d6966a")
const MOON_DUST: Color = Color("b9b9c6")
const MARS_DUST: Color = Color("d98a55")

var t: float = 0.0
var page: int = 0
var light: bool = false
var frozen: bool = false

func debug_flames() -> void:
	page = 1

func debug_flames_big() -> void:
	page = 2

func debug_smoke() -> void:
	page = 3

func debug_boom() -> void:
	page = 4

func debug_small() -> void:
	page = 5

func debug_scene() -> void:
	page = 6

func debug_light() -> void:
	light = true

func debug_freeze() -> void:
	frozen = true

func _process(delta: float) -> void:
	if not frozen:
		t += delta
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_7:
		page = k.keycode - KEY_1
	elif k.keycode == KEY_L:
		light = not light

func _label(p: Vector2, s: String) -> void:
	Pix.text(self, p, s, 10, Color("20263a") if light else Color("8fa0c8"))

func _bg() -> void:
	if light:
		draw_rect(Rect2(0, 0, 640, 180), SKY)
		draw_rect(Rect2(0, 180, 640, 180), MARS)
	else:
		draw_rect(Rect2(0, 0, 640, 360), DARK)

func _draw() -> void:
	match page:
		0:
			_overview()
		1:
			_bg()
			_flames([3, 5, 8, 11, 14], "FLAMES 3 5 8 11 14: 8 FRAMES AT 1.5 AND 4 WIDTHS")
		2:
			_bg()
			_flames([20, 30], "FLAMES 20 30: 8 FRAMES AT 1.5 AND 3.5 WIDTHS")
		3:
			_bg()
			_smoke()
		4:
			_bg()
			_boom()
		5:
			_bg()
			_small()
		_:
			_scene()

# ---------------------------------------------------------------- pages

## Everything animated, once on the dark half and once on the sky / Mars half.
func _overview() -> void:
	draw_rect(Rect2(0, 0, 320, 360), DARK)
	draw_rect(Rect2(320, 0, 320, 180), SKY)
	draw_rect(Rect2(320, 180, 320, 180), MARS)
	for half: int in 2:
		var ox: float = half * 320.0
		var x: float = ox + 10.0
		for w: int in [3, 5, 8, 11, 14, 20, 30]:
			Fx.flame(self, Vector2(x + w, 12), Vector2.DOWN, w * 3.5, w, t + w * 0.13)
			x += w * 1.5 + 12.0
		Fx.flame(self, Vector2(ox + 250, 30), Vector2.RIGHT, 40.0, 11.0, t)
		Fx.flame(self, Vector2(ox + 240, 60), Vector2.LEFT, 40.0, 11.0, t + 0.3)
		Fx.flame(self, Vector2(ox + 270, 110), Vector2.UP, 36.0, 8.0, t + 0.6)
		Fx.flame(self, Vector2(ox + 300, 20), Vector2.DOWN, 30.0, 8.0, t, Color(0.6, 0.8, 1.0))
		Fx.trail(self, Vector2(ox + 240, 84), Vector2.LEFT, 64.0, 3.0, t)
		for s: int in 3:
			var tints: Array[Color] = [Color.WHITE, MOON_DUST, MARS_DUST]
			for k: int in 3:
				var px: float = ox + 20.0 + s * 30.0 + k * 100.0
				Fx.puff(self, Vector2(px, 150), fposmod(t * 0.9 + s * 0.21 + k * 0.4, 1.0), s, tints[k], s + k)
		Fx.explosion(self, Vector2(ox + 30, 215), fposmod(t, 1.3), 0)
		Fx.explosion(self, Vector2(ox + 95, 215), fposmod(t + 0.4, 1.3), 1)
		Fx.explosion(self, Vector2(ox + 200, 225), fposmod(t + 0.8, 1.3), 2)
		Fx.shockwave(self, Vector2(ox + 285, 200), fposmod(t * 1.4, 1.0), 1)
		Fx.shockwave(self, Vector2(ox + 285, 240), fposmod(t * 1.4 + 0.5, 1.0), 0, MARS_DUST)
		for s: int in 3:
			Fx.sparkle(self, Vector2(ox + 16 + s * 22, 300), fposmod(t * 1.6 + s * 0.3, 1.0), [UI.CYAN, UI.YELLOW, Color.WHITE][s], s)
		Fx.glow(self, Vector2(ox + 110, 300), 32.0, Color(1.0, 0.75, 0.35, 0.5))
		Fx.glow(self, Vector2(ox + 110, 335), 12.0, Color(0.5, 0.9, 1.0, 0.6), true)
		Fx.sun(self, Vector2(ox + 170, 290), 0, Color("fff6e0"), t)
		Fx.sun(self, Vector2(ox + 205, 300), 1, Color("ffd75e"), t)
		Fx.sun(self, Vector2(ox + 270, 310), 2, Color("bcd8ff") if half == 1 else Color("fff6e0"), t)
		Fx.beam(self, Vector2(ox + 150, 320), Vector2.DOWN, 32.0, 17.0, t)
	Pix.text(self, Vector2(4, 356), "FX KIT   T %.2f" % t, 10, UI.YELLOW)

## Eight frames of each width at two lengths, then directions, snapping and the repeating body.
func _flames(widths: Array, title: String) -> void:
	_label(Vector2(4, 10), title)
	var x: float = 8.0
	var tall: float = 0.0
	for w: int in widths:
		var cw: float = w * 1.5 + 6.0
		for f: int in 8:
			var ft: float = (f + 0.5) / Fx.FLAME_FPS
			Fx.flame(self, Vector2(x + f * cw + cw * 0.5, 16), Vector2.DOWN, w * 1.5, w, ft)
			Fx.flame(self, Vector2(x + f * cw + cw * 0.5, 22 + w * 1.5 + 4), Vector2.DOWN, w * (4.0 if w < 20 else 3.5), w, ft)
		x += cw * 8.0 + 8.0
		tall = maxf(tall, 30.0 + w * 1.5 + w * 4.0)
	if widths.size() < 3:
		# big page: directions and the repeating body
		Fx.flame(self, Vector2(40, 250), Vector2.RIGHT, 150.0, 20.0, t)
		Fx.flame(self, Vector2(260, 300), Vector2.LEFT, 180.0, 30.0, t)
		Fx.flame(self, Vector2(600, 200), Vector2.DOWN, 150.0, 14.0, t)
		Fx.flame(self, Vector2(560, 350), Vector2.UP, 130.0, 14.0, t)
		Fx.flame(self, Vector2(300, 230), Vector2.RIGHT, 250.0, 20.0, t)
		Fx.flame(self, Vector2(300, 330), Vector2.RIGHT, 330.0, 30.0, t)
		_label(Vector2(300, 205), "LONGER THAN 6 WIDTHS: THE BODY REPEATS")
		return
	var y: float = tall + 16.0
	_label(Vector2(4, y), "LENGTH 2 TO 96 STEP 4, WIDTH 14 / 8 / 5 (ANIMATED)")
	for i: int in 24:
		Fx.flame(self, Vector2(16 + i * 26, y + 6), Vector2.DOWN, 2.0 + i * 4.0, 14.0, t + i * 0.1)
	for i: int in 16:
		Fx.flame(self, Vector2(16 + i * 16, y + 108), Vector2.DOWN, 2.0 + i * 4.0, 8.0, t + i * 0.1)
		Fx.flame(self, Vector2(290 + i * 12, y + 108), Vector2.DOWN, 2.0 + i * 3.0, 5.0, t + i * 0.1)
		Fx.flame(self, Vector2(500 + i * 8, y + 108), Vector2.DOWN, 2.0 + i * 2.0, 3.0, t + i * 0.1)
	_label(Vector2(4, 300), "FOUR DIRECTIONS")
	var c: Vector2 = Vector2(110, 325)
	for d: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		Fx.flame(self, c + d * 8.0, d, 28.0, 11.0, t)
	draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), Color("3a4058"))
	for i: int in 4:
		Fx.flame(self, Vector2(260 + i * 40, 320), Vector2.RIGHT, 24.0, [3.0, 5.0, 8.0, 11.0][i], t)
		Fx.flame(self, Vector2(430 + i * 30, 350), Vector2.UP, 30.0, [3.0, 5.0, 8.0, 14.0][i], t)
	Fx.flame(self, Vector2(600, 300), Vector2.DOWN, 40.0, 11.0, t, Color(0.6, 0.8, 1.0))

func _smoke() -> void:
	_label(Vector2(4, 10), "PUFFS: 8 FRAMES, 3 SIZES x 2 SHAPES. WHITE / MOON DUST / MARS DUST")
	var tints: Array[Color] = [Color.WHITE, MOON_DUST, MARS_DUST]
	var y: float = 24.0
	for s: int in 3:
		var c: float = Fx.PUFF_CELL[s] + 2.0
		for v: int in 2:
			for k: int in 3:
				for f: int in 8:
					Fx.puff(self, Vector2(12 + k * 212 + f * c + c * 0.5, y + c * 0.5), (f + 0.5) / 8.0, s, tints[k], v)
			y += c
		y += 4.0
	_label(Vector2(4, y + 8), "SHOCKWAVE RINGS: 8 FRAMES")
	y += 14.0
	for s: int in 2:
		for f: int in 8:
			Fx.shockwave(self, Vector2(20 + f * (Fx.RING_W[s] + 2) + s * 250, y + 12), (f + 0.5) / 8.0, s, tints[s])
	y += 28.0
	for f: int in 6:
		Fx.shockwave(self, Vector2(52 + f * 96, y + 18), (f + 2.5) / 8.0, 2)
	y += 40.0
	_label(Vector2(4, y + 6), "IN USE: LAUNCH COLUMN, GROUND DUST")
	# a rising smoke column and dust blown sideways along the ground, driven only by t
	for i: int in 22:
		var a: float = fposmod(t * 0.55 + i / 22.0, 1.0)
		var sway: float = sin(i * 2.4) * (4.0 + 14.0 * a)
		Fx.puff(self, Vector2(60 + sway, 340 - a * 70.0), a, 2 if i % 3 == 0 else 1, Color.WHITE, i)
	for i: int in 26:
		var a: float = fposmod(t * 0.9 + i / 26.0, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		for k: int in 2:
			Fx.puff(self, Vector2(220 + k * 200 + side * (6.0 + a * 60.0), 346 - a * 10.0 - (i % 3) * 2.0), a, 1 + (i % 2), tints[k + 1], i)
	Fx.puff(self, Vector2(560, 320), fposmod(t * 0.5, 1.0), 2, Color(1, 1, 1, 0.6))
	Fx.puff(self, Vector2(600, 320), fposmod(t * 0.5, 1.0), 2, Color(0.25, 0.24, 0.3))

func _boom() -> void:
	_label(Vector2(4, 10), "EXPLOSION: 10 FRAMES, LARGE / MEDIUM / SMALL, THEN LIVE")
	for f: int in 10:
		var age: float = (Fx.BOOM_T[f] + (Fx.BOOM_T[f - 1] if f > 0 else 0.0)) * 0.5
		Fx.explosion(self, Vector2(60 + (f % 5) * 114, 68 + (f / 5) * 108), age, 2)
		Fx.explosion(self, Vector2(32 + f * 62, 262), age, 1)
		Fx.explosion(self, Vector2(20 + f * 34, 320), age, 0)
	Fx.explosion(self, Vector2(420, 325), fposmod(t, 1.2), 1, 20.0)
	Fx.explosion(self, Vector2(500, 330), fposmod(t + 0.5, 1.2), 0, 110.0)
	Fx.explosion(self, Vector2(585, 70), fposmod(t + 0.3, 1.2), 1, 0.0)
	Fx.explosion(self, Vector2(590, 300), fposmod(t + 0.7, 1.2), 2)

func _small() -> void:
	_label(Vector2(4, 10), "SPARKLE 6 FRAMES x 3 SIZES")
	for s: int in 3:
		for f: int in 6:
			Fx.sparkle(self, Vector2(12 + f * 20, 24 + s * 20), (f + 0.5) / 6.0, [Color.WHITE, UI.CYAN, UI.YELLOW][s], s)
			Fx.sparkle(self, Vector2(150 + f * 20, 24 + s * 20), (f + 0.5) / 6.0, [Color("ff6a5a"), Color("7dff9a"), Color("c9a0ff")][s], s)
		Fx.sparkle(self, Vector2(290, 24 + s * 20), fposmod(t * 1.5, 1.0), UI.CYAN, s)
	_label(Vector2(330, 10), "SUN x 3 SIZES, 4 FRAMES, WARM / YELLOW / BLUE")
	var suns: Array[Color] = [Color("fff6e0"), Color("ffd75e"), Color("bcd8ff")]
	for f: int in 4:
		Fx.sun(self, Vector2(344 + f * 26, 30), 0, suns[f % 3], f / 3.0 + 0.01)
		Fx.sun(self, Vector2(470 + f * 42, 34), 1, suns[f % 3], f / 3.0 + 0.01)
		Fx.sun(self, Vector2(360 + f * 72, 96), 2, suns[f % 3], f / 3.0 + 0.01)
	_label(Vector2(4, 88), "GLOW: POOL (GROUND) AND ROUND, EVERY RADIUS")
	var x: float = 8.0
	for r: int in Fx.GLOW_R:
		if r <= 48:
			Fx.glow(self, Vector2(x + r, 110), r, Color(1.0, 0.75, 0.35, 0.55))
			Fx.glow(self, Vector2(x + r, 190), r, Color(0.5, 0.85, 1.0, 0.55), true)
			x += 2 * r + 4
	Fx.glow(self, Vector2(430, 200), 96.0, Color(1.0, 0.75, 0.35, 0.45))
	Fx.glow(self, Vector2(560, 210), 64.0, Color(1.0, 0.4, 0.3, 0.5), true)
	_label(Vector2(4, 256), "TRAIL 1 3 5")
	for i: int in 3:
		Fx.trail(self, Vector2(140, 266 + i * 10), Vector2.LEFT, [48.0, 96.0, 128.0][i], [1.0, 3.0, 5.0][i], t)
		Fx.trail(self, Vector2(150 + i * 12, 262), Vector2.DOWN, [24.0, 32.0, 64.0][i], [1.0, 3.0, 5.0][i], t, Color("ffc060"))
	_label(Vector2(200, 256), "BEAM 9 17 33")
	for i: int in 3:
		Fx.beam(self, Vector2(220 + i * 50, 262), Vector2.DOWN, [24.0, 48.0, 64.0][i], [9.0, 17.0, 33.0][i], t)
	Fx.beam(self, Vector2(380, 300), Vector2.RIGHT, 64.0, 17.0, t, Color("ffd75e"))
	_label(Vector2(470, 256), "DEBRIS")
	Fx.debris(self, Vector2(500, 300), fposmod(t, 1.2), 1)
	Fx.debris(self, Vector2(580, 300), fposmod(t + 0.5, 1.2), 2, 20.0, Color("f6dc84"), 5)
	for i: int in 4:
		Fx.debris(self, Vector2(480 + i * 40, 345), 0.15 + i * 0.2, 0, 60.0, Color.WHITE, 2)
	Fx.flash(self, fposmod(t, 3.0) - 2.0)

## A small landing scene: how the effects sit together at game scale.
func _scene() -> void:
	var mars: bool = light
	draw_rect(Rect2(0, 0, 640, 360), Color("e2b088") if mars else Color("0a0c16"))
	draw_rect(Rect2(0, 280, 640, 80), Color("a85a34") if mars else Color("5a5c6c"))
	draw_rect(Rect2(0, 280, 640, 2), Color("c8784a") if mars else Color("8c8ea0"))
	Fx.sun(self, Vector2(520, 70), 2, Color("bcd8ff") if mars else Color("fff6e0"), t)
	var dust: Color = MARS_DUST if mars else MOON_DUST
	# lander stand-in with its engine light on the ground
	var hover: float = 30.0 + 10.0 * sin(t * 1.3)
	var nozzle: Vector2 = Vector2(160, 280 - hover - 6)
	Fx.glow(self, Vector2(160, 284), 32.0, Color(1.0, 0.7, 0.3, 0.5))
	Fx.shockwave(self, Vector2(160, 286), fposmod(t * 1.2, 1.0), 2, dust)
	for i: int in 18:
		var a: float = fposmod(t * 1.1 + i / 18.0, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		Fx.puff(self, Vector2(160 + side * (8.0 + a * 70.0), 282 - a * 14.0 - (i % 3) * 3.0), a, 1 + (i % 2), dust, i)
	draw_rect(Rect2(nozzle.x - 12, nozzle.y - 22, 24, 18), Color("b3812a"))
	draw_rect(Rect2(nozzle.x - 5, nozzle.y - 4, 10, 4), Color("4e5566"))
	Fx.flame(self, nozzle, Vector2.DOWN, hover * 0.8, 8.0, t)
	Fx.glow(self, nozzle + Vector2(0, 1), 6.0, Color(1.0, 0.8, 0.5, 0.6), true)
	# rocket stand-in at lift-off
	Fx.glow(self, Vector2(360, 284), 48.0, Color(1.0, 0.7, 0.3, 0.5))
	for i: int in 24:
		var a: float = fposmod(t * 0.7 + i / 24.0, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		Fx.puff(self, Vector2(360 + side * (4.0 + a * 90.0), 280 - a * 26.0 - (i % 4) * 4.0), a, 2 if i % 3 != 0 else 1, Color.WHITE, i)
	draw_rect(Rect2(346, 110, 28, 110), Color("d6dcea"))
	draw_rect(Rect2(366, 110, 8, 110), Color("a3abc4"))
	Fx.flame(self, Vector2(360, 220), Vector2.DOWN, 62.0, 20.0, t)
	# crash, pickup sparkle, scanner
	Fx.explosion(self, Vector2(520, 262), fposmod(t, 1.5), 2, 45.0 if mars else 20.0)
	Fx.shockwave(self, Vector2(520, 284), fposmod(t, 1.5) * 1.6, 2, dust)
	Fx.sparkle(self, Vector2(250, 270), fposmod(t * 1.5, 1.0), UI.CYAN, 1)
	Fx.beam(self, Vector2(60, 230), Vector2.DOWN, 48.0, 33.0, t)
	Fx.trail(self, Vector2(600, 30), Vector2.LEFT, 96.0, 3.0, t)
	Fx.flash(self, fposmod(t, 1.5), 0.2, Color(1, 1, 1, 0.5))
