extends RefCounted
## Sprite effects shared by every screen: engine flames, smoke and dust puffs, explosions, sparkles, glows,
## suns, shockwave rings, debris, engine trails, scanner beams and a screen flash.
## Stateless: the screen keeps its own particle list and timers and calls these from its draw code.
##   const Fx = preload("res://scripts/fx.gd")
## The sheets are in res://art/fx/ and come from tools/art/gen_fx.py (layout numbers below match that file).
## Everything is drawn 1:1 on whole pixels; directions are 90-degree turns, nothing is ever scaled.
##
## PUBLIC API (the first six keep the signatures every screen depends on; new parameters are optional)
##   `ci` is the CanvasItem to draw on, positions are screen pixels, `t` is a running time in seconds,
##   age01 runs 0 = just born .. 1 = gone, size is 0 small, 1 medium, 2 large.
##
##   Fx.flame(ci, nozzle, dir, length, width, t, tint = WHITE)
##       Engine plume from `nozzle` (centre of the nozzle exit) along `dir` (Vector2.DOWN, UP, LEFT or RIGHT;
##       anything else snaps to the nearest). White-hot core, yellow, orange, red-brown ragged tip, 8 frames
##       at 14 fps. `width` picks the nearest of 3, 5, 8, 11, 14, 20, 30 px; `length` snaps to the nearest
##       drawn plume (0.75 to 6 widths) and beyond that the body repeats, so any length works. Plumes of
##       3 widths or more and 11 px or wider carry shock diamonds. Drive `length` with the throttle.
##       Give each engine of a cluster its own `t` offset (t + 0.13 * i) so they do not flicker in step.
##       `tint` multiplies the colours (Color(0.6, 0.8, 1.0) gives a blue ion or methane flame).
##   Fx.puff(ci, pos, age01, size = 1, tint = WHITE, variant = 0)
##       One smoke or dust puff centred on `pos`: a tight bright ball that billows, breaks into pieces and
##       dithers away (8 frames). About 8, 14 and 26 px across when full. Grey sheet multiplied by `tint`:
##       WHITE launch smoke, Color("b9b9c6") Moon dust, Color("d98a55") Mars dust; tint alpha fades it.
##       `variant` 0..3 picks one of two shapes and a mirror: pass the particle's index for variety.
##   Fx.explosion(ci, pos, age, size = 1, debris_gravity = 60.0) -> bool
##       A whole explosion `age` seconds after it began, 1.0 s long: white flash, fireball, ring shockwave
##       and sparks, dark smoke that rises and breaks up, plus tumbling debris (Fx.debris). Fireball about
##       20, 40 and 72 px across. Returns false once it is over (or for a negative age).
##       debris_gravity is px/s^2: about 20 Moon, 45 Mars, 110 Earth, 0 in space.
##   Fx.sparkle(ci, pos, age01, tint = WHITE, size = 1)
##       A twinkle for pickups, sparks and glints: cross and diamond shapes, 6 frames, white-hot centre
##       inside a tinted star. 7, 11 and 17 px across.
##   Fx.glow(ci, pos, radius, color, circle = false)
##       A pool of light made of ordered-dither rings, tinted by `color`; its alpha sets the strength
##       (0.3 to 0.6 reads well). By default a 2:1 ellipse `radius` wide each side and radius / 2 high each
##       side: light lying on the ground under an engine or a lamp. circle = true gives a round glow for
##       lamps, hot nozzles and halos. Radius snaps to 3, 4, 6, 8, 12, 16, 24, 32, 48, 64 or 96; from 6 up a paler
##       hot spot half the size sits in the middle.
##   Fx.sun(ci, pos, size = 1, tint = Color("fff6e0"), t = 0.0)
##       Sun disc with a bright core, dithered halo and thin rays; 23, 41 and 67 px across with rays
##       (disc 7, 13, 23 px). The core is drawn lighter than `tint`, so Color("ffd75e") gives a yellow sun
##       with a pale centre and Color("bcd8ff") the pale blue Mars sunset sun. Pass `t` to make the rays
##       twinkle slowly; leave it out for a still sun.
##
## ADDED
##   Fx.shockwave(ci, pos, age01, size = 1, tint = WHITE)
##       A ring spreading over the ground, seen in perspective (flat ellipse, thicker near edge, breaks
##       into dither as it fades). 28x12, 52x20 and 92x34 px at full size. Touchdown, crash, launch.
##   Fx.debris(ci, pos, age, size = 1, gravity = 60.0, tint = WHITE, seed = 0) -> bool
##       Tumbling chunks thrown out from `pos` on arcs, `age` seconds after the burst, 1.0 s long.
##       5, 8 and 12 chunks. Fx.explosion already draws one set; call it yourself for a hard landing or
##       a rock breaking. Returns false once over.
##   Fx.trail(ci, from, dir, length, width, t, tint = Color("9fe8ff"))
##       Thin engine trail for ships in space: bright at `from`, thinning into dither along `dir`.
##       Width snaps to 1, 3 or 5 px, length to 8 .. 128 px.
##   Fx.beam(ci, from, dir, length, width, t, tint = Color("7dffd8"))
##       Scanner cone opening from a point at `from` to `width` px at `length` px away: dithered fill,
##       solid edges, a bright scan line running outward. Width snaps to 9, 17 or 33, length to 12 .. 96.
##   Fx.flash(ci, age, duration = 0.25, tint = WHITE) -> bool
##       Full-screen flash that steps down over `duration` seconds; false once over. Draw it last.

const FLAME_W: Array[int] = [3, 5, 8, 11, 14, 20, 30]
const FLAME_PAD: Array[int] = [2, 2, 2, 3, 4, 5, 8]
const FLAME_PERIOD: Array[int] = [3, 4, 7, 9, 12, 17, 26]
const FLAME_SPLIT: Array[int] = [5, 8, 12, 17, 21, 30, 45]
const FLAME_M4: Array[int] = [3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 22, 24]
const FLAME_TEX: Array[String] = ["flame_3", "flame_5", "flame_8", "flame_11", "flame_14", "flame_20", "flame_30"]
const FLAME_FPS: float = 14.0
const PUFF_CELL: Array[int] = [10, 16, 30]
const PUFF_TEX: Array[String] = ["puff_0", "puff_1", "puff_2"]
const BOOM_CELL: Array[int] = [32, 64, 112]
const BOOM_TEX: Array[String] = ["boom_0", "boom_1", "boom_2"]
const BOOM_T: Array[float] = [0.05, 0.10, 0.17, 0.25, 0.34, 0.45, 0.58, 0.72, 0.86, 1.0]
const BOOM_TIME: float = 1.0
const DEBRIS_N: Array[int] = [5, 8, 12]
const DEBRIS_SPEED: Array[float] = [30.0, 48.0, 74.0]
const SPARK_R: Array[int] = [3, 5, 8]
const SPARK_TEX: Array[String] = ["sparkle_0", "sparkle_1", "sparkle_2"]
const GLOW_R: Array[int] = [3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96]
const SUN_CELL: Array[int] = [23, 41, 67]
const SUN_TEX: Array[String] = ["sun_0", "sun_1", "sun_2"]
const RING_W: Array[int] = [28, 52, 92]
const RING_H: Array[int] = [12, 20, 34]
const RING_TEX: Array[String] = ["ring_0", "ring_1", "ring_2"]
const TRAIL_W: Array[int] = [1, 3, 5]
const TRAIL_LEN: Array[int] = [8, 12, 16, 24, 32, 48, 64, 96, 128]
const TRAIL_TEX: Array[String] = ["trail_1", "trail_3", "trail_5"]
const BEAM_W: Array[int] = [9, 17, 33]
const BEAM_LEN: Array[int] = [12, 16, 24, 32, 48, 64, 96]
const BEAM_TEX: Array[String] = ["beam_9", "beam_17", "beam_33"]
const FLASH_A: Array[float] = [0.85, 0.6, 0.35, 0.15]

static var _tex: Dictionary = {}  # sheet name -> Texture2D, kept for the whole run


static func flame(ci: CanvasItem, nozzle: Vector2, dir: Vector2, length: float, width: float, t: float, tint: Color = Color.WHITE) -> void:
	if length < 1.0 or width < 1.0:
		return
	var wi: int = _nearest(FLAME_W, width)
	var w: int = FLAME_W[wi]
	var cw: int = w + 2 * FLAME_PAD[wi]
	var sx: int = posmod(floori(t * FLAME_FPS), 8) * cw
	var want: int = int(length)
	var tex: Texture2D = _t(FLAME_TEX[wi])
	var d: int = _dir4(dir)
	var y: int = 0
	var row_y: int = 0
	var row_len: int = 0
	var last_y: int = 0
	var last_len: int = 0
	for m: int in FLAME_M4:
		last_len = maxi(2, (m * w + 2) >> 2)
		last_y = y
		if row_len == 0 or absi(last_len - want) < absi(row_len - want):
			row_len = last_len
			row_y = y
		y += last_len
	var period: int = FLAME_PERIOD[wi]
	if want <= last_len + (period >> 1):
		_strip(ci, tex, Rect2(sx, row_y, cw, row_len), nozzle, d, 0, tint)
		return
	# longer than the longest drawn plume: its head, then body tiles (sheet row `y`), then the rest of it
	var n: int = roundi(float(want - last_len) / float(period))
	var split: int = FLAME_SPLIT[wi]
	_strip(ci, tex, Rect2(sx, last_y, cw, split), nozzle, d, 0, tint)
	for k: int in n:
		_strip(ci, tex, Rect2(sx, y, cw, period), nozzle, d, split + k * period, tint)
	_strip(ci, tex, Rect2(sx, last_y + split, cw, last_len - split), nozzle, d, split + n * period, tint)


static func puff(ci: CanvasItem, pos: Vector2, age01: float, size: int = 1, tint: Color = Color.WHITE, variant: int = 0) -> void:
	if age01 < 0.0 or age01 >= 1.0:
		return
	var s: int = clampi(size, 0, 2)
	var c: int = PUFF_CELL[s]
	var dst: Rect2 = Rect2((pos - Vector2(c, c) * 0.5).floor(), Vector2(c, c))
	if variant & 2:
		dst.size.x = -c  # mirrored
	ci.draw_texture_rect_region(_t(PUFF_TEX[s]), dst, Rect2(mini(7, int(age01 * 8.0)) * c, (variant & 1) * c, c, c), tint)


static func explosion(ci: CanvasItem, pos: Vector2, age: float, size: int = 1, debris_gravity: float = 60.0) -> bool:
	if age < 0.0 or age >= BOOM_TIME:
		return false
	var s: int = clampi(size, 0, 2)
	var c: int = BOOM_CELL[s]
	var f: int = 0
	while age >= BOOM_T[f]:
		f += 1
	debris(ci, pos, age, s, debris_gravity, Color.WHITE, s)  # under the fireball: chunks show once they fly clear
	ci.draw_texture_rect_region(_t(BOOM_TEX[s]), Rect2((pos - Vector2(c, c) * 0.5).floor(), Vector2(c, c)), Rect2(f * c, 0, c, c))
	return true


static func sparkle(ci: CanvasItem, pos: Vector2, age01: float, tint: Color = Color.WHITE, size: int = 1) -> void:
	if age01 < 0.0 or age01 >= 1.0:
		return
	var s: int = clampi(size, 0, 2)
	var r: int = SPARK_R[s]
	var c: int = 2 * r + 1
	var x: int = mini(5, int(age01 * 6.0)) * c
	var dst: Rect2 = Rect2(pos.floor() - Vector2(r, r), Vector2(c, c))
	var tex: Texture2D = _t(SPARK_TEX[s])
	ci.draw_texture_rect_region(tex, dst, Rect2(x, 0, c, c), tint)
	ci.draw_texture_rect_region(tex, dst, Rect2(x, c, c, c), Color(1.0, 1.0, 1.0, tint.a))


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color, circle: bool = false) -> void:
	var i: int = _nearest(GLOW_R, radius)
	var x: int = 0
	for k: int in i:
		x += 2 * GLOW_R[k]
	var r: int = GLOW_R[i]
	var h: int = 2 * r if circle else r
	var tex: Texture2D = _t("glow_round" if circle else "glow_pool")
	ci.draw_texture_rect_region(tex, Rect2((pos - Vector2(r, h * 0.5)).floor(), Vector2(2 * r, h)), Rect2(x, 0, 2 * r, h), color)
	if i < 2:
		return
	# a paler hot spot half the size on top, so the pool reads as light and not as a stain
	var ri: int = GLOW_R[i - 2]
	var hi: int = 2 * ri if circle else ri
	var xi: int = 0
	for k: int in i - 2:
		xi += 2 * GLOW_R[k]
	ci.draw_texture_rect_region(tex, Rect2((pos - Vector2(ri, hi * 0.5)).floor(), Vector2(2 * ri, hi)), Rect2(xi, 0, 2 * ri, hi),
			Color(lerpf(color.r, 1.0, 0.55), lerpf(color.g, 1.0, 0.55), lerpf(color.b, 1.0, 0.55), color.a * 0.7))


static func sun(ci: CanvasItem, pos: Vector2, size: int = 1, tint: Color = Color("fff6e0"), t: float = 0.0) -> void:
	var s: int = clampi(size, 0, 2)
	var c: int = SUN_CELL[s]
	var x: int = posmod(floori(t * 3.0), 4) * c
	var dst: Rect2 = Rect2(pos.floor() - Vector2(c >> 1, c >> 1), Vector2(c, c))
	var tex: Texture2D = _t(SUN_TEX[s])
	ci.draw_texture_rect_region(tex, dst, Rect2(x, 0, c, c), tint)
	ci.draw_texture_rect_region(tex, dst, Rect2(x, c, c, c), Color(lerpf(tint.r, 1.0, 0.7), lerpf(tint.g, 1.0, 0.7), lerpf(tint.b, 1.0, 0.7), tint.a))


static func shockwave(ci: CanvasItem, pos: Vector2, age01: float, size: int = 1, tint: Color = Color.WHITE) -> void:
	if age01 < 0.0 or age01 >= 1.0:
		return
	var s: int = clampi(size, 0, 2)
	var w: int = RING_W[s]
	var h: int = RING_H[s]
	ci.draw_texture_rect_region(_t(RING_TEX[s]), Rect2((pos - Vector2(w, h) * 0.5).floor(), Vector2(w, h)),
			Rect2(mini(7, int(age01 * 8.0)) * w, 0, w, h), tint)


static func debris(ci: CanvasItem, pos: Vector2, age: float, size: int = 1, gravity: float = 60.0, tint: Color = Color.WHITE, seed: int = 0) -> bool:
	if age < 0.0 or age >= BOOM_TIME:
		return false
	var s: int = clampi(size, 0, 2)
	var n: int = DEBRIS_N[s]
	var tex: Texture2D = _t("debris")
	for j: int in n:
		var life: float = 0.55 + 0.45 * _hash(j * 7 + seed * 131 + 3)
		if age > life or (age > life - 0.18 and (int(age * 30.0) & 1) == 0):
			continue  # the last moments of a chunk blink out
		var ang: float = TAU * (float(j) + _hash(j * 13 + seed * 57)) / float(n)
		var v: float = DEBRIS_SPEED[s] * (0.5 + _hash(j * 29 + seed * 11 + 1))
		var p: Vector2 = pos + Vector2(cos(ang), sin(ang) - 0.35) * v * age * (1.0 - 0.3 * age) + Vector2(0.0, 0.5 * gravity * age * age)
		ci.draw_texture_rect_region(tex, Rect2(p.floor() - Vector2(2, 2), Vector2(5, 5)),
				Rect2((j & 3) * 5, ((int(age * 10.0) + j) & 3) * 5, 5, 5), tint)
	return true


static func trail(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, width: float, t: float, tint: Color = Color("9fe8ff")) -> void:
	if length < 1.0:
		return
	var wi: int = _nearest(TRAIL_W, width)
	var w: int = TRAIL_W[wi]
	var li: int = _nearest(TRAIL_LEN, length)
	var y: int = 0
	for k: int in li:
		y += TRAIL_LEN[k]
	_strip(ci, _t(TRAIL_TEX[wi]), Rect2(posmod(floori(t * 12.0), 4) * w, y, w, TRAIL_LEN[li]), from, _dir4(dir), 0, tint)


static func beam(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, width: float, t: float, tint: Color = Color("7dffd8")) -> void:
	if length < 1.0:
		return
	var wi: int = _nearest(BEAM_W, width)
	var w: int = BEAM_W[wi]
	var li: int = _nearest(BEAM_LEN, length)
	var y: int = 0
	for k: int in li:
		y += BEAM_LEN[k]
	_strip(ci, _t(BEAM_TEX[wi]), Rect2(posmod(floori(t * 10.0), 8) * w, y, w, BEAM_LEN[li]), from, _dir4(dir), 0, tint)


static func flash(ci: CanvasItem, age: float, duration: float = 0.25, tint: Color = Color.WHITE) -> bool:
	if age < 0.0 or age >= duration:
		return false
	var a: float = FLASH_A[mini(3, int(age / duration * 4.0))]
	ci.draw_rect(Rect2(-64, -64, 768, 488), Color(tint.r, tint.g, tint.b, tint.a * a))  # wider than the screen: survives camera shake
	return true


# ---------------------------------------------------------------- internals

static func _t(name: String) -> Texture2D:
	var tex: Texture2D = _tex.get(name) as Texture2D
	if tex == null:
		tex = load("res://art/fx/%s.png" % name) as Texture2D
		_tex[name] = tex
	return tex


## Index of the entry of `list` closest to `v` (the smaller one on a tie).
static func _nearest(list: Array[int], v: float) -> int:
	var best: int = 0
	for i: int in list.size():
		if absf(list[i] - v) < absf(list[best] - v):
			best = i
	return best


## 0 down, 1 up, 2 right, 3 left.
static func _dir4(dir: Vector2) -> int:
	if absf(dir.y) >= absf(dir.x):
		return 0 if dir.y >= 0.0 else 1
	return 2 if dir.x > 0.0 else 3


## Draw `src` (a slice of a sheet cell drawn pointing down, origin at the top centre) turned to direction
## `d`, starting `at` px away from `origin` along that direction. Turns are a mirror and a transpose:
## exact pixels, no rotation matrix.
static func _strip(ci: CanvasItem, tex: Texture2D, src: Rect2, origin: Vector2, d: int, at: int, mod: Color) -> void:
	var o: Vector2 = origin.floor()
	var w: float = src.size.x
	var l: float = src.size.y
	var half: float = float(int(w) >> 1)
	match d:
		0:
			ci.draw_texture_rect_region(tex, Rect2(o.x - half, o.y + at, w, l), src, mod)
		1:
			ci.draw_texture_rect_region(tex, Rect2(o.x - half, o.y - at - l, w, -l), src, mod)
		2:  # transposed draws take the size before the swap; a negative width mirrors left-right on screen
			ci.draw_texture_rect_region(tex, Rect2(o.x + at, o.y - half, w, l), src, mod, true)
		_:
			ci.draw_texture_rect_region(tex, Rect2(o.x - at - l, o.y - half, -w, l), src, mod, true)


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
