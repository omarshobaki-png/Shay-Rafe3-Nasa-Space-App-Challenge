extends RefCounted
## Where things are in the assembly-hall background (art/vab/bg.png, 640x360).
## The builder reads these instead of hard-coding pixel positions.
## WRITTEN BY tools/art/gen_vab.py together with the picture: change the picture there, not the numbers here.
const STAND_TOP: Vector2 = Vector2(310, 318)      # centre of the top face of the assembly stand: the craft stands here
const LAUNCHER_BASE: Vector2 = Vector2(432, 302)  # bottom-centre of the launch vehicle parked on its platform
const WINDOW: Rect2 = Rect2(266, 106, 88, 152)     # the view through the open hall door: dusk sky above y 200, pad and road below
const BEACONS: Array[Vector2] = [Vector2(299, 126), Vector2(261, 100), Vector2(357, 100), Vector2(391, 94), Vector2(465, 94)]  # red warning lights, painted dim: pad tower outside, door posts, service frame
const LAMPS: Array[Vector2] = [Vector2(184, 135), Vector2(436, 135), Vector2(247, 87), Vector2(373, 87), Vector2(241, 76), Vector2(379, 76), Vector2(224, 48), Vector2(396, 48)]  # lit lamp lenses: two wall floodlights, then six ceiling lamps
const SPARKS: Array[Vector2] = [Vector2(381, 201), Vector2(216, 122)]  # welding spots: service-frame arm, the welder on the access tower
# extras
const WINDOW_SKY: Rect2 = Rect2(266, 106, 88, 94)  # only the sky part of WINDOW (stars, weather); the moon is at (337, 122)
const STAND_LIGHTS: Array[Vector2] = [Vector2(221, 320), Vector2(226, 323), Vector2(235, 325), Vector2(249, 327), Vector2(267, 328), Vector2(287, 329), Vector2(309, 329), Vector2(331, 329), Vector2(351, 328), Vector2(369, 327), Vector2(383, 325), Vector2(392, 323), Vector2(397, 320)]  # 2x2 px lights on the stand rim (this is the top-left pixel), left to right; even ones are painted lit
const CRANE_HOOK: Vector2 = Vector2(310, 139)      # tip of the crane hook that hangs over the stand
const WINDOW_HOOK: Rect2 = Rect2(305, 106, 11, 34)  # the hook and its cables hang IN FRONT of the window here: draw no stars or weather inside
const FG: String = "res://art/vab/fg.png"            # 640x360, draw at (0, 0) over the craft
const BEACON_SHEET: String = "res://art/vab/beacon.png"  # 4 frames of 16x16 (off, rising, full, fading)
const BEACON_FRAME: Vector2i = Vector2i(16, 16)
const BEACON_ORIGIN: Vector2 = Vector2(7, 8)         # draw a frame at BEACONS[i] - BEACON_ORIGIN
const FORKLIFT: String = "res://art/vab/forklift.png"   # 40x30, faces right (mirror it to drive left)
const FORKLIFT_POS: Vector2 = Vector2(204, 270)    # top-left corner when parked
const FORKLIFT_RUN: Vector2 = Vector2(204, 336)    # it may drive its left edge between these two x at the same y (behind the stand; draw it before the craft)
