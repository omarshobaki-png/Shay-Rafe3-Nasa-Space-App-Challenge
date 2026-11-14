"""Assembly hall (the ship-builder background), painted in code as palette pixel art.
    python tools/art/gen_vab.py
Writes art/vab/bg.png (opaque), art/vab/fg.png (drawn over the craft), the small extras
(beacon.png, forklift.png) and scripts/vab_meta.gd, so the constants always match the picture.
The hall is a one-point perspective box: every shape is projected with P() and filled with
flat palette tones (no anti-aliasing). Soft light is an integer tone shift along a ramp with a
narrow ordered dither at the band edges only.
"""
import math
import os
import sys
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_bg import BAYER  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "vab")
META = os.path.join(ROOT, "scripts", "vab_meta.gd")
W, H = 640, 360
# ------------------------------------------------------------------ palette
_STEEL = ["0c0a14", "0f1220", "141a2e", "1a2138", "212a44", "2a3552", "344263", "3f5077",
          "4f628c", "6478a2", "8292b8", "a9b6d4"]
_GOLD = ["4a2e10", "7c5418", "b3812a", "dcae44"]
_RED = ["4a1016", "8c1e22", "d03a30", "f07a50"]
_ORANGE = ["b4501a", "f08a2a"]
_GLASS = ["1d5a80", "39a0c8", "8fe3f5"]
_WHITE = ["d6dcea", "f4f6fb"]
_WARM = ["f6dc84"]
_SKY = ["13122c", "1b1840", "2a1e54", "44265f", "6b3366", "9c4a66", "cc6a58", "eca060"]
_ALL = _STEEL + _GOLD + _RED + _ORANGE + _GLASS + _WHITE + _WARM + _SKY

def _ids(start, n):
    return list(range(start, start + n))

S = _ids(0, 12)
G = _ids(12, 4)
R = _ids(16, 4)
O = _ids(20, 2)
C = _ids(22, 3)
WH = _ids(25, 2)
WM = 27
K = _ids(28, 8)
TR = 255  # transparent (fg and sprites)
PAL = np.zeros((256, 4), np.uint8)
for _i, _h in enumerate(_ALL):
    PAL[_i] = (int(_h[0:2], 16), int(_h[2:4], 16), int(_h[4:6], 16), 255)
# tone shift table: SHIFT[index, delta + 4] moves an index along its own ramp
SHIFT = np.tile(np.arange(256)[:, None], (1, 9))
for _lad in (S[1:11], G, R, O):
    for _p, _i in enumerate(_lad):
        for _dl in range(-4, 5):
            SHIFT[_i, _dl + 4] = _lad[min(max(_p + _dl, 0), len(_lad) - 1)]
BAYT = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
YY, XX = np.mgrid[0:H, 0:W].astype(np.float64)
# ------------------------------------------------------------------ camera and hall
CX, CY, F, CAM = 310, 200, 1000.0, 6.5   # vanishing point, focal length (px), eye height (m)
ZB = 112.0                               # back wall depth
HW = 11.76                               # half width of the hall
HH = 20.164                              # roof height
BX0, BX1, BY0, BY1 = 205, 415, 78, 258   # back wall on screen
DOOR = (264, 106, 355, 257)              # outside view, inclusive pixels
STAND_Z, STAND_Y, STAND_R = 50.85, 0.5, 4.5
PAD_X, PAD_Z, PAD_Y = 7.2, 58.8, 0.5
img = None
d = None
Lt = None

def canvas(fill, w=W, h=H):
    global img, d, Lt
    img = Image.new("L", (w, h), fill)
    d = ImageDraw.Draw(img)
    Lt = np.zeros((h, w))
    return img

def P(X, Y, Z):
    return (int(round(CX + F * X / Z)), int(round(CY - F * (Y - CAM) / Z)))

def rect(x0, y0, x1, y1, c):
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=c)

def line(x0, y0, x1, y1, c):
    d.line([(x0, y0), (x1, y1)], fill=c)

def px(x, y, c):
    d.point((x, y), fill=c)

def poly(pts, c):
    d.polygon(pts, fill=c)

def poly3(pts, c):
    d.polygon([P(*p) for p in pts], fill=c)

def line3(a, b, c):
    d.line([P(*a), P(*b)], fill=c)

def lad(ladder, i):
    return ladder[min(max(i, 0), len(ladder) - 1)]

def box(x0, x1, y0, y1, z0, z1, t, ladder=None):
    """Axis-aligned box; t is the tone of the face that looks at the camera."""
    ladder = ladder or S
    if y1 < CAM:
        poly3([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], lad(ladder, t + 2))
    if y0 > CAM:
        poly3([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], lad(ladder, t - 2))
    if x0 > 0:
        poly3([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], lad(ladder, t + 1))
    if x1 < 0:
        poly3([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], lad(ladder, t - 1))
    a, b = P(x0, y1, z0), P(x1, y0, z0)
    rect(a[0], a[1], b[0], b[1], lad(ladder, t))
    return a[0], a[1], b[0], b[1]

def vtruss(x0, x1, ya, yb, step, cc, cw):
    """Vertical lattice column between two screen x."""
    y, flip = ya, False
    while y < yb:
        y2 = min(y + step, yb)
        if flip:
            line(x0 + 1, y, x1 - 1, y2, cw)
        else:
            line(x1 - 1, y, x0 + 1, y2, cw)
        y, flip = y2, not flip
    line(x0, ya, x0, yb, cc)
    line(x1, ya, x1, yb, cc)

def htruss(xa, xb, y0, y1, step, cc, cw):
    """Horizontal lattice girder between two screen y."""
    x, flip = xa, False
    while x < xb:
        x2 = min(x + step, xb)
        if flip:
            line(x, y0 + 1, x2, y1 - 1, cw)
        else:
            line(x, y1 - 1, x2, y0 + 1, cw)
        line(x2, y0, x2, y1, cw)
        x, flip = x2, not flip
    line(xa, y0, xb, y0, cc)
    line(xa, y1, xb, y1, cc)

def curve(pts, c, n=48):
    """Cubic bezier through 4 screen points, 1 px."""
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u ** 3 * pts[0][0] + 3 * u * u * t * pts[1][0] + 3 * u * t * t * pts[2][0] + t ** 3 * pts[3][0]
        y = u ** 3 * pts[0][1] + 3 * u * u * t * pts[1][1] + 3 * u * t * t * pts[2][1] + t ** 3 * pts[3][1]
        out.append((int(round(x)), int(round(y))))
    d.line(out, fill=c)
    return out

def stamp(x, y, rows, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in cmap:
                px(x + i, y + j, cmap[ch])

def ell(cx, cy, rx, ry):
    return np.sqrt(((XX - cx) / rx) ** 2 + ((YY - cy) / ry) ** 2)

def glow(cx, cy, rx, ry, amt, soft=0.3, mask=None):
    g = amt * np.clip((1.0 - ell(cx, cy, rx, ry)) / soft, 0, 1)
    Lt[...] += g if mask is None else g * mask

def bake(k=0.3):
    """Turn the light buffer into whole tone steps (dither only at band edges)."""
    a = np.asarray(img)
    lev = np.clip(np.floor(Lt + 0.5 + BAYT[:a.shape[0], :a.shape[1]] * k), -4, 4).astype(int)
    out = SHIFT[a, lev + 4].astype(np.uint8)
    img.paste(Image.fromarray(out))
    Lt[...] = 0

def mask_poly(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=1)
    return np.asarray(m).astype(np.float64)

def to_rgba(im):
    return PAL[np.asarray(im)].copy()

def ring(cz, y, r, n=96):
    return [P(r * math.cos(2 * math.pi * i / n), y, cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]

# ------------------------------------------------------------------ outside, seen through the door
BEACONS = []
LAMPS = []
SPARKS = []
STAND_LIGHTS = []

def outside():
    x0, y0, x1, y1 = DOOR
    starts = [106, 128, 148, 163, 175, 184, 191, 196]
    for y in range(y0, 200):
        b = max(i for i in range(8) if starts[i] <= y)
        nxt = starts[b + 1] if b < 7 else 999
        for x in range(x0, x1 + 1):
            c = K[b]
            if y == nxt - 2 and (x + y) % 4 == 0:
                c = K[b + 1]
            elif y == nxt - 1 and (x + y) % 2 == 0:
                c = K[b + 1]
            px(x, y, c)
    # stars and the moon
    for sx, sy, c in ((270, 111, S[9]), (283, 118, S[11]), (295, 109, S[8]), (309, 121, S[10]), (322, 112, S[9]),
                      (350, 110, S[8]), (347, 139, S[9]), (275, 134, S[8]), (289, 143, S[9]), (318, 137, S[8]),
                      (332, 151, S[9]), (269, 156, S[8]), (303, 152, S[8]), (352, 160, S[9]), (281, 167, S[8])):
        px(sx, sy, c)
    px(283, 117, S[8]), px(283, 119, S[8]), px(282, 118, S[8]), px(284, 118, S[8])
    d.ellipse([329, 114, 345, 130], fill=K[1])
    d.ellipse([332, 117, 342, 127], fill=WH[0])
    for mx, my in ((335, 120), (336, 120), (339, 123), (338, 124), (339, 124), (335, 124), (337, 126)):
        px(mx, my, S[10])
    line(333, 120, 333, 124, WH[1]), line(334, 118, 334, 119, WH[1]), px(335, 117, WH[1]), px(336, 117, WH[1])
    # ground and the crawler road to the pad
    rect(x0, 200, x1, y1, K[0])
    for ya, yb, t in ((200, 211, 3), (212, 229, 4), (230, 246, 5), (247, 257, 6)):
        poly([(310 - (ya - 199) * 0.62, ya), (310 + (ya - 199) * 0.62, ya),
              (310 + (yb - 199) * 0.62, yb), (310 - (yb - 199) * 0.62, yb)], S[t])
    for y in range(204, 258):
        if (y * y // 37) % 3 != 0:
            px(310, y, S[2])
    for y in (203, 207, 213, 222, 236):
        o = int(round((y - 199) * 0.62)) + 2
        px(310 - o, y, WM), px(310 + o, y, WM)
        px(310 - o, y + 1, K[3]), px(310 + o, y + 1, K[3])
    # far shore, buildings, the pad and its tower
    for x in range(x0, x1 + 1):
        h = 1 + int(2.2 * abs(math.sin(x * 0.37) * math.sin(x * 0.11 + 1.0)))
        rect(x, 200 - h, x, 199, K[2])
    rect(326, 194, 340, 199, S[1]), rect(331, 191, 336, 194, S[1])
    px(328, 196, WM), px(333, 196, WM), px(338, 197, WM), px(334, 192, C[1])
    rect(266, 195, 272, 199, S[1]), px(268, 197, WM)
    poly([(288, 199), (292, 195), (314, 195), (318, 199)], S[1])
    vtruss(296, 302, 140, 195, 6, S[1], S[1])
    for y in range(146, 195, 6):
        line(296, y, 302, y, S[1])
    line(292, 139, 308, 139, S[1]), line(292, 140, 308, 140, S[1])
    line(299, 127, 299, 139, S[1]), line(293, 141, 293, 144, S[1])
    line(303, 158, 309, 158, S[1]), line(303, 171, 308, 171, S[1]), line(303, 183, 310, 183, S[1])
    px(299, 126, R[1]), px(299, 150, WM), px(299, 164, WM), px(299, 178, WM), px(304, 190, WM)
    BEACONS.append((299, 126))
    line(321, 152, 321, 199, S[1]), px(321, 151, R[1])
    rect(277, 178, 284, 184, S[1]), line(278, 177, 283, 177, S[1])
    line(277, 185, 275, 199, S[1]), line(284, 185, 286, 199, S[1]), line(277, 191, 284, 191, S[1])
    # a little warm haze around the pad lights
    for hx, hy in ((294, 194), (306, 193), (312, 196)):
        px(hx, hy, K[7])

# ------------------------------------------------------------------ back wall
def back_wall():
    rect(BX0, BY0, BX1, BY1 - 1, S[4])
    wall = np.zeros((H, W))
    wall[BY0:BY1, BX0:BX1 + 1] = 1
    wall[DOOR[1]:DOOR[3] + 1, DOOR[0]:DOOR[2] + 1] = 0
    # cladding seams, girts, columns (drawn first so the light gradient shifts them too)
    for x in range(BX0 + 7, BX1, 14):
        line(x, BY0, x, BY1 - 1, S[3])
    for y in (108, 138, 169, 198, 228):
        line(BX0, y, BX1, y, S[5])
        line(BX0, y + 1, BX1, y + 1, S[3])
    for xa, xb in ((208, 232), (236, 259), (360, 384), (388, 412)):
        line(xa, 80, xb, 106, S[5]), line(xb, 80, xa, 106, S[5])
    for x in (205, 233, 385, 413):
        rect(x, BY0, x + 2, BY1 - 1, S[5])
        line(x, BY0, x, BY1 - 1, S[6])
        line(x + 3, BY0, x + 3, BY1 - 1, S[3])
    Lt[...] += wall * (np.clip((YY - 190) / 6, 0, 1) - np.clip((122 - YY) / 6, 0, 1))
    # wall floodlights wash the wall below them
    for lx in (234, 386):
        cone = np.clip(1 - np.abs(XX - lx) / (6 + (YY - 112) * 0.42), 0, 1) * np.clip(1 - (YY - 112) / 70, 0, 1)
        Lt[...] += wall * (YY > 112) * cone * 1.5
    bake()
    outside()
    # door: posts, header, the raised leaf, hazard edges
    x0, y0, x1, y1 = DOOR
    rect(x0 - 4, 82, x0 - 1, y1, S[6]), line(x0 - 4, 82, x0 - 4, y1, S[7]), line(x0 - 1, 82, x0 - 1, y1, S[3])
    rect(x1 + 1, 82, x1 + 4, y1, S[6]), line(x1 + 1, 82, x1 + 1, y1, S[7]), line(x1 + 4, 82, x1 + 4, y1, S[3])
    for y in range(y0, y1 + 1):
        c = G[1] if (y // 4) % 2 == 0 else S[1]
        px(x0, y, c), px(x0 + 1, y, c), px(x1, y, c), px(x1 - 1, y, c)
    rect(x0, 82, x1, y0 - 1, S[5])
    for y in range(86, y0 - 4, 5):
        line(x0, y, x1, y, S[6]), line(x0, y + 1, x1, y + 1, S[3])
    for x in range(x0 + 2, x1, 15):
        line(x, 82, x, y0 - 4, S[4])
    for x in range(x0, x1 + 1):
        c = G[2] if ((x + 0) // 4) % 2 == 0 else S[1]
        px(x, y0 - 3, c), px(x, y0 - 2, c)
    line(x0, y0 - 1, x1, y0 - 1, S[2])
    line(x0 - 4, 81, x1 + 4, 81, S[7])
    stamp(291, 88, ["###..#..#.#...#", "#.#.#.#.#.#..##", "##..###..#....#", "#.#.#.#..#....#", "###.#.#..#...###"],
          {"#": S[7]})
    # warning lights on the door posts (painted dim: the builder lights them)
    for bx in (x0 - 3, x1 + 2):
        rect(bx, 100, bx + 1, 101, R[1]), line(bx, 102, bx + 1, 102, S[2])
        BEACONS.append((bx, 100))

def wall_props():
    # floodlights
    for lx in (234, 386):
        rect(lx - 2, 109, lx + 2, 110, S[7]), rect(lx - 1, 111, lx + 1, 111, WH[1]), px(lx, 112, WH[0])
    # pipes down the left wall section and along the wall
    for x, a, b in ((241, S[7], S[5]), (245, C[0], S[3])):
        line(x, BY0 + 4, x, 168, a), line(x + 1, BY0 + 4, x + 1, 168, b)
        for y in range(92, 168, 19):
            line(x - 1, y, x + 2, y, S[3])
    for y, a, b in ((131, C[0], S[3]), (134, S[6], S[3])):
        line(BX0 + 4, y, DOOR[0] - 6, y, a), line(DOOR[2] + 6, y, BX1 - 3, y, a)
        if b != a:
            line(BX0 + 4, y + 1, DOOR[0] - 6, y + 1, b), line(DOOR[2] + 6, y + 1, BX1 - 3, y + 1, b)
    rect(222, 129, 224, 136, R[1]), px(223, 130, R[2])
    rect(399, 129, 401, 136, S[7])
    # banner
    line(212, 142, 230, 142, S[8])
    rect(213, 143, 229, 164, S[8]), rect(213, 143, 229, 144, S[9])
    rect(213, 151, 229, 156, C[0]), line(213, 150, 229, 150, S[10]), line(213, 157, 229, 157, S[10])
    rect(219, 151, 223, 156, G[2]), px(219, 151, C[0]), px(223, 151, C[0]), px(219, 156, C[0]), px(223, 156, C[0])
    line(216, 155, 226, 152, S[10])
    poly([(213, 165), (229, 165), (229, 167), (221, 165), (213, 167)], S[8])
    line(229, 143, 229, 166, S[6])
    # catwalk across the wall at the level of the side catwalks
    cy = P(0, 10, ZB)[1]
    for xa, xb in ((BX0, DOOR[0] - 5), (DOOR[2] + 5, BX1)):
        rect(xa, cy, xb, cy + 1, S[6]), line(xa, cy + 2, xb, cy + 2, S[2]), line(xa, cy, xb, cy, S[7])
        line(xa, cy - 9, xb, cy - 9, S[6]), line(xa, cy - 5, xb, cy - 5, S[5])
        for x in range(xa + 3, xb, 8):
            line(x, cy - 9, x, cy, S[5])
        for x in range(xa + 6, xb - 4, 16):
            line(x, cy + 2, x - 4, cy + 6, S[3])
    # control booth on the right catwalk
    rect(366, cy - 27, 408, cy - 1, S[6]), line(366, cy - 27, 408, cy - 27, S[8]), line(366, cy - 26, 408, cy - 26, S[7])
    line(366, cy - 27, 366, cy - 1, S[7]), line(408, cy - 26, 408, cy - 1, S[4])
    rect(369, cy - 22, 397, cy - 11, C[0]), line(369, cy - 22, 397, cy - 22, WM)
    for x in (378, 388):
        line(x, cy - 22, x, cy - 11, S[4])
    rect(371, cy - 14, 376, cy - 12, S[2]), px(372, cy - 15, C[2]), px(374, cy - 15, C[1])
    rect(381, cy - 14, 385, cy - 12, S[2]), px(383, cy - 15, R[2])
    rect(391, cy - 18, 392, cy - 12, S[1]), rect(390, cy - 20, 393, cy - 19, S[1])
    rect(400, cy - 20, 405, cy - 1, S[5]), px(401, cy - 10, WM), rect(401, cy - 18, 404, cy - 14, C[0])
    px(367, cy - 29, R[1])
    # railing in front of the booth again
    line(DOOR[2] + 5, cy - 9, BX1, cy - 9, S[7])
    # stairs from the left catwalk to the floor, two flights
    ly = P(0, 5, ZB)[1]
    def flight(xa, ya, xb, yb):
        for o in (0, 1):
            line(xa, ya + o, xb, yb + o, S[6 - 3 * o])
        line(xa, ya - 8, xb, yb - 8, S[5])
        n = abs(xb - xa) // 4
        for i in range(n + 1):
            x = xa + (xb - xa) * i // max(n, 1)
            y = ya + (yb - ya) * i // max(n, 1)
            px(x, y - 1, S[7])
            if i % 2 == 0:
                line(x, y - 8, x, y, S[4])
    flight(255, cy, 215, ly)
    rect(208, ly, 218, ly + 1, S[6]), line(208, ly + 2, 218, ly + 2, S[2]), line(208, ly - 8, 218, ly - 8, S[5])
    line(209, ly + 2, 209, BY1 - 1, S[4]), line(218, ly + 2, 218, BY1 - 1, S[4])
    flight(215, ly, 255, BY1 - 1)
    # cabinets under the stairs
    rect(221, 240, 231, 257, S[6]), line(221, 240, 231, 240, S[8]), line(226, 241, 226, 257, S[4])
    px(223, 243, C[2]), px(228, 243, R[2]), px(223, 246, C[1]), rect(233, 246, 240, 257, S[5]), line(233, 246, 240, 246, S[7])
    rect(243, 250, 245, 257, R[1]), px(243, 250, R[2]), px(244, 249, S[7])
    # propellant tank, pipes and drums on the right
    rect(383, 252, 405, 257, S[3])
    rect(385, 198, 403, 253, S[8])
    rect(385, 198, 386, 253, S[10]), rect(387, 198, 389, 253, S[9]), rect(399, 198, 403, 253, S[7]), line(403, 198, 403, 253, S[6])
    d.pieslice([385, 191, 403, 205], 180, 360, fill=S[9])
    line(387, 195, 389, 193, S[10]), line(399, 194, 402, 197, S[7])
    rect(385, 214, 403, 219, C[0]), rect(385, 214, 386, 219, C[1]), rect(399, 214, 403, 219, S[3])
    for y in (207, 228, 241):
        line(385, y, 403, y, S[7])
    stamp(390, 231, [".#.", "###", ".#."], {"#": G[2]})
    line(394, 191, 394, cy + 3, S[6]), line(395, 191, 395, cy + 3, S[4])
    line(408, 205, 408, 257, S[6]), line(404, 205, 408, 205, S[6]), rect(407, 224, 409, 226, R[1])
    for bx, c in ((363, C[0]), (370, C[0]), (377, R[1])):
        rect(bx, 247, bx + 5, 257, c), line(bx, 247, bx + 5, 247, S[8]), line(bx, 251, bx + 5, 251, S[3])
        line(bx, 248, bx, 257, R[2] if c in R else C[1])
        line(bx + 5, 248, bx + 5, 257, S[3])

# ------------------------------------------------------------------ side walls
def side_walls():
    for sg in (-1, 1):
        X = sg * HW
        for Yg in (3, 6, 9, 12, 18):
            a, b = P(X, Yg, ZB), P(X, Yg, 34)
            line(a[0], a[1], b[0], b[1], S[4]), line(a[0], a[1] + 1, b[0], b[1] + 1, S[2])
        # cross bracing in every second bay
        for z0, z1 in ((100, 88), (76, 64)):
            for ya, yb in ((0, 5), (5, 10), (10, 15)):
                line3((X, ya, z0), (X, yb, z1), S[4]), line3((X, yb, z0), (X, ya, z1), S[4])
        # pipes
        for Yp, c in ((14.2, C[0]), (13.85, S[5])):
            line3((X, Yp, ZB), (X, Yp, 34), c)
        # catwalks (drawn before the columns: the columns stand in front of the wall)
        Xi = sg * (HW - 1.4)
        for Yc in (5.0, 10.0):
            under = Yc > CAM
            poly3([(X, Yc, ZB), (Xi, Yc, ZB), (Xi, Yc, 34), (X, Yc, 34)], S[2] if under else S[5])
            poly3([(Xi, Yc, ZB), (Xi, Yc + 0.3, ZB), (Xi, Yc + 0.3, 34), (Xi, Yc, 34)], S[6])
            line3((Xi, Yc + 0.3, ZB), (Xi, Yc + 0.3, 34), S[7])
            for z in range(108, 36, -4):
                line3((Xi, Yc + 0.3, z), (Xi, Yc + 1.4, z), S[4])
            line3((Xi, Yc + 1.4, ZB), (Xi, Yc + 1.4, 34), S[6])
            line3((Xi, Yc + 0.85, ZB), (Xi, Yc + 0.85, 34), S[4])
        # columns, far to near
        for Z in (100, 88, 76, 64, 52, 42):
            w = max(3, int(round(0.55 * F / Z)))
            xa, yf = P(X, 0, Z)
            yc = P(X, HH, Z)[1]
            x0 = xa if sg < 0 else xa - w + 1
            rect(x0, yc, x0 + w - 1, yf, S[5])
            if w >= 5:
                rect(x0 + 1, yc, x0 + w - 2, yf, S[3])
                vtruss(x0, x0 + w - 1, yc, yf, w + 2, S[5], S[4])
            line(x0, yc, x0, yf, S[6])
            line(x0 + w - 1, yc, x0 + w - 1, yf, S[4] if w >= 5 else S[3])
            # bracket under the crane rail and a base plate
            b = P(X, 14.9, Z)
            rect(x0, b[1], x0 + w - 1 + (2 if sg < 0 else 0) - (0 if sg < 0 else 0), b[1] + 1, S[6])
            rect(x0 - 1, yf - 2, x0 + w, yf, S[4])
        # crane rail
        Xr = sg * (HW - 0.45)
        poly3([(Xr, 15.0, ZB), (Xr, 15.6, ZB), (Xr, 15.6, 34), (Xr, 15.0, 34)], S[5])
        line3((Xr, 15.6, ZB), (Xr, 15.6, 34), S[7])
        line3((Xr, 15.0, ZB), (Xr, 15.0, 34), S[2])
        # a floodlight on the third column
        fx, fy = P(sg * (HW - 0.7), 12.2, 88)
        rect(fx - 2, fy - 2, fx + 2, fy + 1, S[7]), rect(fx - 1, fy - 1, fx + 1, fy, WH[1]), px(fx, fy + 2, S[4])
        LAMPS.append((fx, fy))

# ------------------------------------------------------------------ roof, lamps, crane
def ceiling():
    poly3([(-HW, HH, ZB), (HW, HH, ZB), (HW, HH, 40), (-HW, HH, 40)], S[1])
    for Z in (103, 94, 85, 76, 67, 58, 49):
        yt, yb = P(0, HH, Z)[1], P(0, HH - 1.5, Z)[1]
        xl, xr = P(-HW, 0, Z)[0], P(HW, 0, Z)[0]
        rect(xl, yt, xr, yb, S[2])
        htruss(xl, xr, yt, yb - 1, max(8, int(round(1.6 * F / Z))), S[4], S[3])
        rect(xl, yb - 1, xr, yb, S[5]), line(xl, yb - 1, xr, yb - 1, S[6])
        line(xl, yt, xr, yt, S[3])
    # conduits along the lamp rows
    for X in (-6.5, 6.5):
        line3((X, HH - 1.55, ZB), (X, HH - 1.55, 60), S[4])

def lamps():
    for Z, hang in ((103, 0.55), (94, 0.55), (76, 0.6)):
        for X in (-6.5, 6.5):
            x, y = P(X, HH - 1.5 - hang, Z)
            ytop = P(X, HH - 1.5, Z)[1]
            line(x, ytop, x, y - 2, S[3])
            hw = 2 if Z > 90 else 3
            rect(x - hw + 1, y - 2, x + hw - 1, y - 2, S[6])
            rect(x - hw, y - 1, x + hw, y - 1, S[7])
            rect(x - hw, y, x + hw, y, WH[1])
            rect(x - hw + 1, y + 1, x + hw - 1, y + 1, WH[0])
            LAMPS.append((x, y))

def lamp_light(mask):
    for x, y in LAMPS[2:]:
        glow(x, y + 1, 9, 6, 1.6, 0.9, mask)
        cone = np.clip(1 - np.abs(XX - x) / (3 + (YY - y) * 0.36), 0, 1) * np.clip(1 - (YY - y) / 56, 0, 1)
        Lt[...] += mask * (YY > y) * cone * 1.3

def crane():
    Z, y0, y1 = 80.0, 17.2, 18.4
    xl, yt = P(-(HW - 0.45), y1, Z)
    xr, yb = P(HW - 0.45, y0, Z)
    rect(xl, yt, xr, yb, G[1])
    line(xl, yt, xr, yt, G[2]), line(xl, yt + 1, xr, yt + 1, G[2])
    line(xl, yb, xr, yb, G[0]), line(xl, yb + 1, xr, yb + 1, S[1])
    line(xl, yt + 6, xr, yt + 6, G[0])
    for x in range(xl + 14, xr - 8, 22):
        line(x, yt + 2, x, yb - 1, G[0])
    for x in list(range(xl, xl + 16)) + list(range(xr - 15, xr + 1)):
        for y in range(yt + 7, yb):
            px(x, y, G[3] if ((x + y) // 3) % 2 == 0 else S[1])
    stamp(CX - 44, yt + 8, ["##.###.#####", ".#.#.#...#..", "##.#.#...#..", "#..#.#...#..", "##.###...#.."], {"#": S[1]})
    # end trucks on the rails
    for ex in (xl - 3, xr - 5):
        rect(ex, yb - 3, ex + 8, yb + 4, S[5]), line(ex, yb - 3, ex + 8, yb - 3, S[7]), line(ex, yb + 4, ex + 8, yb + 4, S[2])
        px(ex + 2, yb + 5, S[1]), px(ex + 6, yb + 5, S[1])
    # trolley, cables, hook block
    tx = CX
    rect(tx - 9, yb + 1, tx + 9, yb + 6, S[5]), line(tx - 9, yb + 1, tx + 9, yb + 1, S[7]), line(tx - 9, yb + 6, tx + 9, yb + 6, S[2])
    rect(tx - 6, yb + 7, tx + 6, yb + 9, S[4]), px(tx - 8, yb + 3, WM), px(tx + 8, yb + 3, R[2])
    hy = P(0, 12.6, Z)[1]
    for cxx in (tx - 3, tx + 2):
        line(cxx, yb + 10, cxx, hy, S[6])
    line(tx - 2, yb + 10, tx - 2, hy, S[2])
    rect(tx - 5, hy, tx + 4, hy + 8, G[2]), line(tx - 5, hy, tx + 4, hy, G[3]), line(tx - 5, hy + 8, tx + 4, hy + 8, G[0])
    for x in range(tx - 5, tx + 5):
        for y in range(hy + 3, hy + 7):
            if ((x - y) // 2) % 2 == 0:
                px(x, y, S[1])
    line(tx - 5, hy, tx - 5, hy + 8, G[3])
    stamp(tx - 3, hy + 9, ["..##..", "..##..", "...##.", "#...##", "##..##", ".####.", "..##.."], {"#": S[8]})
    px(tx, hy + 10, S[10]), px(tx + 1, hy + 11, S[10])
    return tx, hy + 15

# ------------------------------------------------------------------ floor
def floor_mask():
    return mask_poly([P(-HW, 0, ZB), P(HW, 0, ZB), P(HW, 0, 30), P(-HW, 0, 30)])

def floor():
    fm = floor_mask()
    poly3([(-HW, 0, ZB), (HW, 0, ZB), (HW, 0, 30), (-HW, 0, 30)], S[5])
    # slab joints: toward the vanishing point and across
    j = Image.new("L", (W, H), 0)
    jd = ImageDraw.Draw(j)
    for i in range(-3, 4):
        X = i * 3.92
        jd.line([P(X, 0, ZB), P(X, 0, 30)], fill=1)
    for Z in range(104, 36, -8):
        y = P(0, 0, Z)[1]
        jd.line([(0, y), (W, y)], fill=1)
    Lt[...] -= np.asarray(j) * fm
    # far floor catches the door light, near floor falls off
    Lt[...] += fm * (np.clip((272 - YY) / 8, 0, 1) - np.clip((YY - 346) / 8, 0, 1))
    bake()
    # glossy sheen: the back wall mirrored about the floor line and squeezed to half height
    # (not physical: it keeps the mirror image short, behind the stand), as broken streaks
    a = np.asarray(img).copy()
    out = a.copy()
    for y in range(BY1, H):
        dist = y - BY1
        sy = BY1 - 1 - 2 * dist
        if sy < BY0 or (dist > 8 and y % 3 == 0):
            continue
        for x in range(BX0, BX1 + 1):
            if not fm[y, x]:
                continue
            s = a[sy, x]
            if s in (WM, WH[0], WH[1]):
                out[y, x] = SHIFT[a[y, x], 5]
            elif (s <= S[3] or s == K[0]) and dist < 30:
                out[y, x] = SHIFT[a[y, x], 3]
    img.paste(Image.fromarray(out))
    # the dusk glow on the polish: dashes that get shorter and cooler toward the camera
    for dy, c, inset, on, off in ((0, K[5], 3, 92, 0), (1, K[5], 5, 30, 2), (3, K[4], 9, 17, 3), (4, K[4], 12, 13, 4),
                                  (6, K[4], 17, 9, 6), (8, K[3], 22, 7, 8), (10, K[3], 27, 5, 11), (13, K[3], 33, 3, 9)):
        x = DOOR[0] + inset
        while x <= DOOR[2] - inset:
            line(x, 288 + dy, min(x + on - 1, DOOR[2] - inset), 288 + dy, c)
            x += on + off
    # hot spot of each ceiling lamp in its pool on the polished floor
    for X in (-6.5, 6.5):
        for Z, n in ((103, 3), (94, 4), (76, 6)):
            x, y = P(X, 0, Z)
            line(x - n, y, x + n, y, S[7]), line(x - n + 2, y, x + n - 2, y, S[8])
            line(x - n + 2, y - 1, x + n - 2, y - 1, S[7])
    return fm

def floor_paint(fm):
    # lane from the door to the stand, ring round the stand, threshold, pad box
    for sg in (-1, 1):
        for Xa, c in ((5.25, G[1]), (5.45, G[2])):
            a, b = P(sg * Xa, 0, ZB), P(sg * Xa, 0, 61)
            line(a[0], a[1], b[0], b[1], c)
    for x in range(DOOR[0] - 4, DOOR[2] + 5):
        c = G[2] if (x // 4) % 2 == 0 else S[1]
        px(x, BY1, c), px(x, BY1 + 1, c)
    pts = ring(STAND_Z, 0, 6.4)
    d.line(pts + pts[:1], fill=G[2])
    pts = ring(STAND_Z, 0, 6.55)
    d.line(pts + pts[:1], fill=G[1])
    x0, y0 = P(PAD_X - 3.1, 0, PAD_Z + 2.6)
    x1, y1 = P(PAD_X + 3.1, 0, PAD_Z - 2.6)
    for xa, ya, xb, yb in ((x0, y0, x1, y0), (P(PAD_X - 3.1, 0, PAD_Z - 2.6)[0], y1, P(PAD_X + 3.1, 0, PAD_Z - 2.6)[0], y1)):
        for x in range(xa, xb + 1):
            px(x, ya, G[2] if (x // 5) % 2 == 0 else S[2])
    line3((PAD_X - 3.1, 0, PAD_Z + 2.6), (PAD_X - 3.1, 0, PAD_Z - 2.6), G[2])
    line3((PAD_X + 3.1, 0, PAD_Z + 2.6), (PAD_X + 3.1, 0, PAD_Z - 2.6), G[2])
    # stencil on the near floor
    stamp(238, 349, ["####...####..##..##.....####....##.",
                     "##..##.##..##.##..##...##..##..###.",
                     "#####..######..####....##..##...##.",
                     "##..##.##..##...##.....##..##...##.",
                     "####...##..##...##......####...####"], {"#": S[7]})

def floor_light(fm):
    cx, cy = P(0, 0, STAND_Z)
    glow(cx, cy + 2, 215, 30, 1.0, 0.22, fm)
    glow(cx, cy + 2, 150, 19, 1.0, 0.22, fm)
    # pools under the far lamps
    for X in (-6.5, 6.5):
        for Z, rx in ((103, 26), (94, 30), (76, 38)):
            x, y = P(X, 0, Z)
            glow(x, y, rx, rx / 6.5, 1.0, 0.4, fm)
    # contact shadows
    glow(cx + 4, cy + 9, 100, 15, -2.2, 0.16, fm)
    px_, py_ = P(PAD_X, 0, PAD_Z - 1.6)
    glow(px_ + 4, py_ + 2, 50, 7, -2.0, 0.25, fm)
    sx, sy = P(-8.55, 0, 64)
    glow(sx + 3, sy + 1, 30, 5, -2.0, 0.3, fm)
    for x, y, rx in ((232, 259, 22), (388, 259, 30), (255, 276, 14), (364, 271, 10)):
        glow(x, y, rx, 3, -1.6, 0.5, fm)

# ------------------------------------------------------------------ things on the floor
def crate(x, y, w, h, t=1, far=True):
    """Wooden crate, screen coords of the bottom-left corner."""
    a, b, c = (G[0], G[1], S[2]) if far else (G[1], G[2], G[0])
    rect(x, y - h + 1, x + w - 1, y, a)
    rect(x, y - h + 1, x + w - 1, y - h + 1, b)
    line(x, y - h + 1, x, y, b)
    line(x + w - 1, y - h + 2, x + w - 1, y, c)
    line(x, y, x + w - 1, y, c)
    if w >= 9:
        line(x + 2, y - h + 3, x + w - 3, y - 2, c)
        line(x + 1, y - h // 2, x + w - 2, y - h // 2, c)

def props_far():
    crate(247, 267, 11, 9), crate(259, 267, 9, 7), crate(250, 258, 9, 8)
    # red tool cart
    rect(359, 262, 372, 270, R[1]), line(359, 262, 372, 262, R[2]), line(359, 265, 372, 265, R[0]), line(359, 268, 372, 268, R[0])
    line(358, 261, 373, 261, S[8]), px(361, 271, S[1]), px(370, 271, S[1]), line(373, 258, 373, 261, S[7])
    px(365, 263, S[9]), px(365, 266, S[9]), px(365, 269, S[9])
    # cones
    for x, y in ((343, 277), (277, 277), (379, 290)):
        px(x + 1, y - 4, O[1]), rect(x + 1, y - 3, x + 1, y - 3, O[1]), rect(x, y - 2, x + 2, y - 2, WH[0])
        rect(x, y - 1, x + 2, y - 1, O[0]), rect(x - 1, y, x + 3, y, O[0])
    # hoses from the tank to the pad
    for pts, c in (([(396, 258), (386, 268), (424, 276), (418, 292)], S[2]), ([(402, 258), (412, 270), (446, 270), (440, 290)], S[2])):
        o = curve(pts, c)
        for i in range(2, len(o), 5):
            px(o[i][0], o[i][1] - 1, S[7])

def pad(shadow=False):
    """Mobile platform for the launch vehicle and the service frame behind it."""
    lx, ly = P(PAD_X, PAD_Y, PAD_Z)
    # service frame: two lattice posts, work platforms, top beam
    zf = PAD_Z + 2.0
    top = P(0, 12.6, zf)[1]
    base = P(0, 0, zf)[1]
    xs = [P(PAD_X - 2.25, 0, zf)[0], P(PAD_X + 2.25, 0, zf)[0]]
    for i, xc in enumerate(xs):
        rect(xc - 3, top, xc + 3, base, S[3])
        vtruss(xc - 3, xc + 3, top, base, 9, S[7], S[5])
        line(xc - 3, top, xc - 3, base, S[8])
        line(xc + 3, top, xc + 3, base, S[5])
        rect(xc - 5, base - 2, xc + 5, base, S[6]), line(xc - 5, base - 2, xc + 5, base - 2, S[8])
    rect(xs[0] - 5, top - 4, xs[1] + 5, top - 1, S[6]), line(xs[0] - 5, top - 4, xs[1] + 5, top - 4, S[8])
    line(xs[0] - 5, top - 1, xs[1] + 5, top - 1, S[3])
    for x in range(xs[0] - 5, xs[1] + 6):
        if ((x // 3) % 2) == 0:
            px(x, top - 2, G[2]), px(x, top - 3, G[2])
    px(xs[0], top - 6, R[1]), px(xs[0], top - 5, S[7]), px(xs[1], top - 6, R[1]), px(xs[1], top - 5, S[7])
    BEACONS.append((xs[0], top - 6)), BEACONS.append((xs[1], top - 6))
    for Yl in (3.4, 6.4, 9.4):
        y = P(0, Yl, zf)[1]
        under = Yl > CAM
        rect(xs[0] + 4, y, xs[1] - 4, y + 1, S[6]), line(xs[0] + 4, y + (2 if under else -1), xs[1] - 4, y + (2 if under else -1), S[3] if under else S[8])
        line(xs[0] + 4, y - 8, xs[1] - 4, y - 8, S[6])
        for x in range(xs[0] + 7, xs[1] - 4, 7):
            line(x, y - 8, x, y - 1, S[5])
        rect(xs[1] - 9, y + 2, xs[1] - 7, y + 2, S[8]), rect(xs[1] - 9, y + 3, xs[1] - 7, y + 3, WM)
        # short arm toward the craft side with a hazard tip
        rect(xs[0] - 11, y, xs[0] - 4, y + 1, S[6]), rect(xs[0] - 11, y, xs[0] - 10, y + 1, G[2])
        line(xs[0] - 4, y + 2, xs[0] - 9, y + 5, S[4])
    # umbilical hoses hanging from the frame
    curve([(xs[1] - 3, top + 12), (xs[1] - 10, top + 40), (xs[1] - 4, top + 70), (xs[1] - 12, top + 96)], S[2])
    # platform
    x0, yt, x1, yb = box(PAD_X - 2.2, PAD_X + 2.2, 0.0, PAD_Y, PAD_Z - 1.6, PAD_Z + 1.6, 6)
    tb = P(0, PAD_Y, PAD_Z + 1.6)[1]
    xb0, xb1 = P(PAD_X - 2.2, PAD_Y, PAD_Z + 1.6)[0], P(PAD_X + 2.2, PAD_Y, PAD_Z + 1.6)[0]
    line(xb0, tb, xb1, tb, S[9])
    line(x0, yt, x1, yt, S[9])
    for x in range(x0, x1 + 1):
        for y in range(yt + 2, yb - 1):
            px(x, y, G[3] if ((x + y) // 4) % 2 == 0 else S[1])
    line(x0, yb, x1, yb, S[1]), line(x0, yb - 1, x1, yb - 1, S[2])
    rect(x0, yt + 1, x1, yt + 1, S[7])
    # flame hole and hold-down posts
    d.ellipse([lx - 9, ly - 1, lx + 9, ly + 2], fill=S[3])
    for o in (-15, 15):
        rect(lx + o - 1, ly - 3, lx + o + 1, ly + 1, S[8]), line(lx + o - 1, ly - 3, lx + o + 1, ly - 3, S[10])
    # crawler trucks
    for xa in (x0 + 4, x1 - 16):
        rect(xa, yb + 1, xa + 12, yb + 3, S[1]), line(xa + 1, yb + 1, xa + 11, yb + 1, S[3])
    SPARKS.append((xs[0] - 10, P(0, 6.4, zf)[1] - 1))
    return lx, ly

def stair_tower():
    """Mobile access tower with zigzag stairs, left of the stand."""
    Z = 64.0
    xa, xb = P(-9.8, 0, Z)[0], P(-7.3, 0, Z)[0]
    base = P(0, 0, Z)[1]
    levels = [P(0, yv, Z)[1] for yv in (0.35, 3.0, 5.7, 8.4, 11.1)]
    top = levels[-1]
    # back bracing
    for i in range(4):
        line(xa + 1, levels[i], xb - 1, levels[i + 1], S[4])
    # stairs
    for i in range(4):
        ya, yb = levels[i], levels[i + 1]
        x0, x1 = (xa + 3, xb - 3) if i % 2 == 0 else (xb - 3, xa + 3)
        line(x0, ya, x1, yb, S[8]), line(x0, ya + 1, x1, yb + 1, S[6]), line(x0, ya + 2, x1, yb + 2, S[3])
        line(x0, ya - 9, x1, yb - 9, S[6])
        n = 7
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k // n
            y = ya + (yb - ya) * k // n
            px(x, y - 1, S[9])
    # landings
    for i, y in enumerate(levels[1:]):
        rect(xa, y, xb, y + 1, S[7]), line(xa, y, xb, y, S[9]), line(xa, y + 2, xb, y + 2, S[3])
    # posts
    for x in (xa, xb):
        rect(x - 1, top - 10, x, base, S[6]), line(x - 1, top - 10, x - 1, base, S[8])
    # top deck railing and the swing arm toward the craft
    line(xa, top - 10, xb + 22, top - 10, S[7]), line(xa, top - 5, xb + 22, top - 5, S[5])
    rect(xb, top, xb + 24, top + 1, S[7]), line(xb, top, xb + 24, top, S[9]), line(xb, top + 2, xb + 24, top + 2, S[3])
    for x in range(xb + 6, xb + 24, 8):
        line(x, top - 10, x, top, S[5])
    rect(xb + 23, top - 10, xb + 24, top + 1, G[2]), px(xb + 23, top - 6, S[1]), px(xb + 24, top - 2, S[1])
    line(xb + 1, top + 3, xb + 12, top + 14, S[5]), line(xb + 1, top + 14, xb + 1, top + 3, S[5])
    # base beam with hazard stripes, wheels
    rect(xa - 3, base - 4, xb + 3, base - 1, S[6]), line(xa - 3, base - 4, xb + 3, base - 4, S[8])
    for x in range(xa - 3, xb + 4):
        if ((x // 3) % 2) == 0:
            px(x, base - 2, G[3]), px(x, base - 3, G[3])
    for x in (xa - 2, xb - 2):
        rect(x, base, x + 3, base + 2, S[1]), px(x + 1, base + 1, S[5])
    # a welder kneeling on the swing arm
    wx, wy = xb + 11, top - 13
    stamp(wx, wy, ["...ww....",
                   "..wWWg...",
                   "..wWgg...",
                   ".oOOo....",
                   ".oOOOoo..",
                   ".oOOo.oo.",
                   ".bBBb..t.",
                   ".bB.bb...",
                   ".bb..bb..",
                   "kkk..kkk.",
                   ], {"w": S[9], "W": WH[0], "g": S[1], "o": O[0], "O": O[1], "b": S[5], "B": S[7], "k": S[1], "t": S[10]})
    # hand lamp on the deck
    px(xa + 6, top - 2, WM), px(xa + 6, top - 1, S[2])
    SPARKS.append((wx + 9, wy + 7))
    px(wx + 9, wy + 7, WH[1])

def workers():
    # two figures far away, for scale (a person is about 9 px per metre tall at the back wall)
    cy = P(0, 10, ZB)[1]
    stamp(246, cy - 15, [".yy.", ".ww.", "oOOo", "oOOo", "oOOo", "wOOw", ".bb.", ".bb.", ".bb.", ".bb.", ".bb.", ".b.b",
                         ".b.b", ".b.b", "kk.k"],
          {"y": G[3], "w": S[9], "o": O[0], "O": O[1], "b": S[3], "k": S[1]})
    # he stands behind the catwalk railing
    line(244, cy - 9, 251, cy - 9, S[6]), line(244, cy - 5, 251, cy - 5, S[5])
    stamp(331, 259, [".yy..", ".yy..", ".ww..", ".ww..", "bBBb.", "bBBb.", "bBBb.", "bBBbp", "wBBwp", ".BB.p", ".dd..", ".dd..",
                     ".dd..", ".d.d.", ".d.d.", ".d.d.", "kk.kk"],
          {"y": G[3], "w": S[10], "b": S[8], "B": S[9], "d": S[3], "k": S[1], "p": WH[0]})

def stand(fm):
    """The assembly stand: its top-centre is STAND_TOP."""
    cx, cy = P(0, STAND_Y, STAND_Z)
    top = ring(STAND_Z, STAND_Y, STAND_R)
    bot = ring(STAND_Z, 0, STAND_R)
    xs = [p[0] for p in top]
    xl, xr = min(xs), max(xs)
    yb = P(0, 0, STAND_Z)[1]
    # side band
    band = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(band)
    bd.rectangle([xl, cy, xr, yb], fill=1)
    bd.polygon(bot, fill=1)
    bd.polygon(top, fill=0)
    bm = np.asarray(band).astype(bool)
    a = np.asarray(img).copy()
    ys, xs_ = np.nonzero(bm)
    for y, x in zip(ys, xs_):
        u = (x - cx) / (xr - cx)
        yel = ((x + y) // 5) % 2 == 0
        if u > 0.55:
            a[y, x] = G[1] if yel else S[0]
        elif u < -0.75:
            a[y, x] = G[3] if yel else S[2]
        else:
            a[y, x] = G[2] if yel else S[1]
    # bottom edge darker, top edge of the band a steel lip
    low = bm & ~np.roll(bm, -1, axis=0)
    a[low] = S[0]
    img.paste(Image.fromarray(a))
    # top surface
    poly(top, S[7])
    for r, c in ((4.05, S[8]), (3.9, G[2]), (2.2, S[6])):
        p = ring(STAND_Z, STAND_Y, r)
        d.line(p + p[:1], fill=c)
    for ang in range(0, 360, 45):
        ca, sa = math.cos(math.radians(ang + 22.5)), math.sin(math.radians(ang + 22.5))
        line3((2.2 * ca, STAND_Y, STAND_Z + 2.2 * sa), (3.9 * ca, STAND_Y, STAND_Z + 3.9 * sa), S[6])
    d.line(top + top[:1], fill=S[9])
    back = [p for p in top if p[1] < cy]
    for p in back:
        px(p[0], p[1], S[6])
    # lip under the front edge
    front = sorted(set(p for p in top if p[1] >= cy))
    for p in front:
        px(p[0], p[1] + 1, S[5])
    # centre mark
    line(cx - 4, cy, cx + 4, cy, S[9]), line(cx, cy - 1, cx, cy + 1, S[9])
    # ring of lights on the rim
    for i, ang in enumerate(range(12, 180, 13)):
        x, y = P(STAND_R * math.cos(math.radians(ang)), STAND_Y, STAND_Z - STAND_R * math.sin(math.radians(ang)))
        on = i % 2 == 0
        rect(x - 2, y + 1, x + 1, y + 2, S[1])
        rect(x - 1, y, x, y, C[2] if on else C[0])
        rect(x - 1, y + 1, x, y + 1, C[1] if on else S[3])
        if on:
            px(x - 1, y, WH[1]), px(x - 2, y, C[0]), px(x + 1, y, C[0]), rect(x - 1, y - 1, x, y - 1, C[0])
        STAND_LIGHTS.append((x - 1, y))
    # steps on the left
    sx, sy = P(-STAND_R - 0.1, 0, STAND_Z - 0.4)
    for i in range(3):
        rect(sx - 4 - i * 4, sy - 8 + i * 3, sx - 1 - i * 4 + 3, sy, S[6 - i])
        line(sx - 4 - i * 4, sy - 8 + i * 3, sx - 1 - i * 4 + 3, sy - 8 + i * 3, S[9 - i])
    return cx, cy

# ------------------------------------------------------------------ the two pictures
def build_bg():
    canvas(S[3])
    side_walls()
    ceiling()
    back_wall()
    wall_props()
    wall = np.zeros((H, W))
    wall[BY0:BY1, BX0:BX1 + 1] = 1
    lamps()
    hook = crane()
    fm = floor()
    floor_paint(fm)
    floor_light(fm)
    bake()
    props_far()
    workers()
    launcher = pad()
    stair_tower()
    st = stand(fm)
    # calm, darker sides under the parts bin and the mission board; darker top corners
    Lt[...] -= np.clip((150 - XX) / 34, 0, 2) + np.clip((XX - 470) / 34, 0, 2)
    bake(0.25)
    return to_rgba(img), st, launcher, hook

def shaft(rgba, pts, col):
    """Dithered light shaft: density falls with the distance from the lamp."""
    m = mask_poly(pts).astype(bool)
    y0 = min(p[1] for p in pts)
    y1 = max(p[1] for p in pts)
    t = (YY - y0) / max(1, (y1 - y0))
    xi, yi = XX.astype(int), YY.astype(int)
    dense = ((xi + yi) % 2 == 0) & (t < 0.3)
    mid = ((xi % 2 == 0) & (yi % 2 == 0)) & (t >= 0.3) & (t < 0.65)
    thin = ((xi % 4 == 0) & (yi % 4 == 0) | (xi % 4 == 2) & (yi % 4 == 2)) & (t >= 0.65)
    sel = m & (dense | mid | thin)
    rgba[sel] = col

def build_fg():
    canvas(TR)
    rgba = np.zeros((H, W, 4), np.uint8)
    shaft(rgba, [(162, 24), (196, 24), (248, 172), (198, 172)], (169, 182, 212, 24))
    shaft(rgba, [(424, 24), (458, 24), (422, 172), (372, 172)], (169, 182, 212, 24))
    # cables and a chain hoist hanging in front, top corners
    for pts in ([(150, 30), (166, 52), (196, 52), (214, 24)], [(150, 40), (170, 70), (206, 60), (232, 24)],
                [(470, 34), (452, 58), (426, 50), (410, 24)], [(470, 46), (446, 76), (414, 62), (392, 24)]):
        o = curve(pts, S[1])
        for i in range(3, len(o), 6):
            px(o[i][0], o[i][1] - 1, S[4])
    for x, yb_ in ((178, 78), (447, 92)):
        for y in range(24, yb_):
            px(x, y, S[1] if y % 3 else S[4])
        rect(x - 3, yb_, x + 3, yb_ + 5, S[1]), line(x - 3, yb_, x + 3, yb_, S[5]), rect(x - 2, yb_ + 2, x + 2, yb_ + 3, G[1])
        stamp(x - 3, yb_ + 6, ["..##..", "...##.", "#...##", "##..##", ".####."], {"#": S[1]})
        px(x + 2, yb_ + 8, S[5])
    # tool cart, lower left
    x0, y0 = 152, 324
    rect(x0, y0 + 6, x0 + 46, y0 + 32, R[0]), rect(x0, y0 + 6, x0 + 46, y0 + 7, R[1]), line(x0, y0 + 6, x0 + 30, y0 + 6, R[2]), line(x0, y0 + 5, x0 + 47, y0 + 5, S[6])
    rect(x0 - 1, y0 + 3, x0 + 48, y0 + 4, S[2]), line(x0 - 1, y0 + 3, x0 + 48, y0 + 3, S[7])
    for i, y in enumerate((y0 + 11, y0 + 17, y0 + 23, y0 + 29)):
        line(x0 + 2, y, x0 + 44, y, S[1]), line(x0 + 2, y + 1, x0 + 44, y + 1, R[1]), line(x0 + 14, y + 2, x0 + 32, y + 2, S[6]), line(x0 + 14, y + 3, x0 + 32, y + 3, S[1])
    line(x0 + 46, y0 + 6, x0 + 46, y0 + 32, S[1]), line(x0, y0 + 8, x0, y0 + 32, R[1])
    rect(x0 + 4, y0 + 33, x0 + 10, y0 + 35, S[1]), rect(x0 + 36, y0 + 33, x0 + 42, y0 + 35, S[1])
    # tools on top: a gas bottle, a box, a wrench
    rect(x0 + 5, y0 - 12, x0 + 10, y0 + 2, S[2]), line(x0 + 5, y0 - 12, x0 + 5, y0 + 2, S[5]), rect(x0 + 6, y0 - 15, x0 + 9, y0 - 13, S[1])
    rect(x0 + 5, y0 - 7, x0 + 10, y0 - 5, C[0])
    rect(x0 + 16, y0 - 4, x0 + 29, y0 + 2, S[2]), line(x0 + 16, y0 - 4, x0 + 29, y0 - 4, S[6]), px(x0 + 22, y0 - 1, G[2])
    line(x0 + 33, y0 + 1, x0 + 43, y0 - 5, S[5]), line(x0 + 33, y0 + 2, x0 + 43, y0 - 4, S[1]), rect(x0 + 43, y0 - 7, x0 + 45, y0 - 4, S[5])
    # railing and bottles, lower right
    rx = 412
    for x in (rx, rx + 28, rx + 56):
        rect(x, 330, x + 1, 359, S[1]), line(x, 330, x, 359, S[4])
    rect(rx, 329, rx + 57, 331, S[1]), line(rx, 329, rx + 57, 329, S[6])
    rect(rx, 344, rx + 57, 345, S[1]), line(rx, 344, rx + 57, 344, S[4])
    for x in range(rx, rx + 58):
        for y in range(354, 360):
            px(x, y, G[1] if ((x + y) // 4) % 2 == 0 else S[1])
    line(rx, 353, rx + 57, 353, S[5])
    for bx, c in ((rx + 34, C[0]), (rx + 43, R[1])):
        rect(bx, 314, bx + 6, 353, S[2]), line(bx, 314, bx, 353, S[5]), rect(bx + 2, 310, bx + 4, 313, S[1]), px(bx + 3, 309, S[6])
        rect(bx, 320, bx + 6, 323, c)
    out = to_rgba(img)
    out[np.asarray(img) == TR] = (0, 0, 0, 0)
    sel = (out[..., 3] == 0) & (rgba[..., 3] > 0)
    out[sel] = rgba[sel]
    return out

def build_beacon():
    """4 frames, 16x16 each: off, rising, full, fading. The lamp pixel is at (7, 8) of a frame."""
    canvas(TR, 64, 16)
    for f in range(4):
        ox = f * 16
        core = (R[1], R[2], R[3], R[2])[f]
        if f in (1, 3):
            for dx, dy in ((0, -2), (0, 2), (-2, 0), (3, 0)):
                px(ox + 7 + dx, 8 + dy, R[1])
        if f == 2:
            for dx, dy in ((0, -2), (1, -2), (0, 3), (1, 3), (-2, 0), (-2, 1), (3, 0), (3, 1)):
                px(ox + 7 + dx, 8 + dy, R[2])
            for dx, dy in ((0, -4), (1, 5), (-4, 0), (5, 1), (-2, -2), (3, -2), (-2, 3), (3, 3)):
                px(ox + 7 + dx, 8 + dy, R[1])
        rect(ox + 6, 7, ox + 9, 10, R[1] if f == 0 else R[2] if f != 2 else R[3])
        rect(ox + 7, 8, ox + 8, 9, core if f != 2 else WM)
        if f == 0:
            rect(ox + 6, 7, ox + 9, 10, TR), rect(ox + 7, 8, ox + 8, 9, R[1])
    out = to_rgba(img)
    out[np.asarray(img) == TR] = (0, 0, 0, 0)
    return out

def build_forklift():
    """Small forklift facing right, 40x30; it stands on the bottom row."""
    canvas(TR, 40, 30)
    rows = [
        "..............................kk........",
        "...........kOOk...............kh........",
        "......kkkkkkkkkkkkk...........kh........",
        "......kHHHHHHHHHHHk...........kh........",
        "......kh.........hk...........kh........",
        "......kh.........hk...........kh........",
        "......kh.........hk...........kh........",
        "......kh..wwk....hk...........kh........",
        "......kh..wWk....hk...........kh........",
        "......kh.kooOk...hk...........kh........",
        "......kh.koOOk...hk...........kh........",
        "......kh.koOOOk..hk...........kh........",
        "..kkkkkh.kbbbbk..hkkkkkkk.....kh........",
        ".kYYYYYYYYYYYYYYYYYYYYYYYk....kh........",
        ".kyyyyyyyyyyyyyyyyyyyyyyyyk...kh........",
        ".kyyyyyyyyyyyyyyyyyyyyyyyyk...kh........",
        ".kyyyyyyyyyyyyyyyyyyyyyyyyk...kh........",
        ".kyyyyykkkkkyyyyyyyyyyyyyyykkkkh........",
        ".kzzzzzkgggkzzzzzzzzzzzzzzzk..kh........",
        ".kzzzzzkkkkkzzzzzzzzzzzzzzzk..kh........",
        ".kzzkkkkkkzzzzzzzzzkkkkkkzzk..kh........",
        ".kzkttttttkzzzzzzzkttttttkzk..kh........",
        ".kkttkkkkttkkkkkkkttkkkkttkk..kh........",
        "..kttkhhkttk.....kttkhhkttk...kh........",
        "..kttkhhkttk.....kttkhhkttk...khkkkkkkkk",
        "..kttkkkkttk.....kttkkkkttk...kHHHHHHHHk",
        "...kttttttk.......kttttttk....kkkkkkkkkk",
        "....kkkkkk.........kkkkkk...............",
    ]
    stamp(0, 2, rows, {"k": S[0], "h": S[6], "H": S[8], "Y": G[3], "y": G[2], "z": G[1], "g": S[3], "t": S[2],
                        "w": S[9], "W": WH[0], "o": O[0], "O": O[1], "b": S[5]})
    out = to_rgba(img)
    out[np.asarray(img) == TR] = (0, 0, 0, 0)
    for y, xa, xb in ((29, 1, 30), (28, 2, 29)):  # contact shadow on the floor between and around the wheels
        seg = out[y, xa:xb]
        seg[seg[:, 3] == 0] = (8, 10, 20, 120)
    return out

def v2(p):
    return "Vector2(%d, %d)" % (p[0], p[1])

def arr(ps):
    return "[" + ", ".join(v2(p) for p in ps) + "]"

def write_meta(st, launcher, hook):
    x0, y0, x1, y1 = DOOR[0] + 2, DOOR[1], DOOR[2] - 2, DOOR[3]
    txt = """extends RefCounted
## Where things are in the assembly-hall background (art/vab/bg.png, 640x360).
## The builder reads these instead of hard-coding pixel positions.
## WRITTEN BY tools/art/gen_vab.py together with the picture: change the picture there, not the numbers here.
const STAND_TOP: Vector2 = %s      # centre of the top face of the assembly stand: the craft stands here
const LAUNCHER_BASE: Vector2 = %s  # bottom-centre of the launch vehicle parked on its platform
const WINDOW: Rect2 = Rect2(%d, %d, %d, %d)     # the view through the open hall door: dusk sky above y 200, pad and road below
const BEACONS: Array[Vector2] = %s  # red warning lights, painted dim: pad tower outside, door posts, service frame
const LAMPS: Array[Vector2] = %s  # lit lamp lenses: two wall floodlights, then six ceiling lamps
const SPARKS: Array[Vector2] = %s  # welding spots: service-frame arm, the welder on the access tower
# extras
const WINDOW_SKY: Rect2 = Rect2(%d, %d, %d, %d)  # only the sky part of WINDOW (stars, weather); the moon is at (337, 122)
const STAND_LIGHTS: Array[Vector2] = %s  # 2x2 px lights on the stand rim (this is the top-left pixel), left to right; even ones are painted lit
const CRANE_HOOK: Vector2 = %s      # tip of the crane hook that hangs over the stand
const WINDOW_HOOK: Rect2 = Rect2(%d, %d, 11, %d)  # the hook and its cables hang IN FRONT of the window here: draw no stars or weather inside
const FG: String = "res://art/vab/fg.png"            # 640x360, draw at (0, 0) over the craft
const BEACON_SHEET: String = "res://art/vab/beacon.png"  # 4 frames of 16x16 (off, rising, full, fading)
const BEACON_FRAME: Vector2i = Vector2i(16, 16)
const BEACON_ORIGIN: Vector2 = Vector2(7, 8)         # draw a frame at BEACONS[i] - BEACON_ORIGIN
const FORKLIFT: String = "res://art/vab/forklift.png"   # 40x30, faces right (mirror it to drive left)
const FORKLIFT_POS: Vector2 = %s    # top-left corner when parked
const FORKLIFT_RUN: Vector2 = %s    # it may drive its left edge between these two x at the same y (behind the stand; draw it before the craft)
""" % (v2(st), v2(launcher), x0, y0, x1 - x0 + 1, y1 - y0 + 1, arr(BEACONS), arr(LAMPS), arr(SPARKS),
       x0, y0, x1 - x0 + 1, 200 - y0, arr(STAND_LIGHTS), v2(hook), hook[0] - 5, y0, hook[1] - y0 + 1,
       v2(FORKLIFT_POS), v2(FORKLIFT_RUN))
    with open(META, "w", newline="\n") as fh:
        fh.write(txt)

# ------------------------------------------------------------------ bin category tabs: one 26 x 26 icon each
# Flat 3-tone pieces, each with its own 1 px ink outline; one accent colour per category (TAB_ACCENT in builder.gd).
TAB_ORDER = ["launcher", "power", "comms", "science", "landing", "robot", "return", "fuel", "protect"]
TS = 26

def _c(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

INK = _c("0c0a14")
W1, W2, W3 = _c("f4f6fb"), _c("c8d0e2"), _c("8292b8")
D1, D2, D3 = _c("4f628c"), _c("2a3552"), _c("1a2138")
RAMP = {k: [_c(x) for x in v] for k, v in {
    "red": ["ff9a8a", "f0503c", "a8282a"], "orange": ["ffd08a", "ff9f43", "c0601c"],
    "yellow": ["fff2a8", "ffd75e", "c8901c"], "cyan": ["c8f6ff", "4fd6ff", "1f8cc0"],
    "green": ["c8ffd2", "6dff8a", "24a850"], "cell": ["6aa8ff", "2b6fd6", "173c8c"],
    "violet": ["e2d0ff", "b48cff", "6c48c0"], "pink": ["ffc8ee", "ff7ad9", "b83c98"],
    "shield": ["a8c8ff", "5a8cff", "2c4cb0"], "flame": ["fff2a8", "ffb347", "f0602a"]}.items()}

class TabIcon:
    def __init__(self):
        self.a = np.zeros((TS, TS, 4), np.uint8)

    def piece(self, paint):
        """paint(d) draws one solid piece on a fresh layer; it gets an ink outline and goes on top."""
        lay = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
        paint(ImageDraw.Draw(lay))
        a = np.array(lay)
        m = a[..., 3] > 0
        ring = np.zeros_like(m)
        ring[1:] |= m[:-1]
        ring[:-1] |= m[1:]
        ring[:, 1:] |= m[:, :-1]
        ring[:, :-1] |= m[:, 1:]
        self.a[ring & ~m] = INK
        self.a[m] = a[m]

    def flat(self, paint):
        """Thin details (lines, ropes) drawn on top without an outline."""
        lay = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
        paint(ImageDraw.Draw(lay))
        a = np.array(lay)
        m = a[..., 3] > 0
        self.a[m] = a[m]

def _tab_launcher(ic):
    r = RAMP["red"]
    def fins(d):
        d.polygon([(9, 12), (5, 17), (5, 21), (9, 19)], fill=r[1])
        d.polygon([(16, 12), (20, 17), (20, 21), (16, 19)], fill=r[2])
    def body(d):
        d.rectangle((9, 7, 16, 19), fill=W2)
        d.rectangle((9, 7, 10, 19), fill=W1)
        d.rectangle((15, 7, 16, 19), fill=W3)
        d.polygon([(9, 7), (12, 1), (13, 1), (16, 7)], fill=r[1])
        d.polygon([(13, 1), (16, 7), (13, 7)], fill=r[2])
        d.line((11, 3, 10, 6), fill=r[0])
        d.rectangle((9, 16, 16, 17), fill=r[1])
        d.rectangle((15, 16, 16, 17), fill=r[2])
        d.ellipse((10, 9, 15, 14), fill=D2)
        d.ellipse((11, 10, 14, 13), fill=RAMP["cyan"][2])
        d.point((12, 11), fill=W1)
    def flame(d):
        f = RAMP["flame"]
        d.rectangle((10, 20, 15, 20), fill=D1)
        d.polygon([(10, 21), (15, 21), (13, 24), (12, 24)], fill=f[2])
        d.polygon([(11, 21), (14, 21), (13, 23), (12, 23)], fill=f[1])
        d.line((12, 21, 13, 21), fill=f[0])
    ic.piece(fins)
    ic.piece(flame)
    ic.piece(body)

def _tab_power(ic):
    b, y = RAMP["cell"], RAMP["yellow"]
    def mast(d):
        d.rectangle((8, 19, 10, 22), fill=D1)
        d.rectangle((4, 22, 14, 23), fill=D2)
        d.line((4, 22, 14, 22), fill=D1)
    def panel(d):
        d.rectangle((1, 3, 17, 19), fill=W3)
        d.rectangle((2, 4, 16, 18), fill=b[1])
        for yy in range(4, 19):     # a diagonal sheen across the cells
            for x in range(2, 17):
                if (x + yy) % 7 == 0:
                    d.point((x, yy), fill=b[0])
        d.rectangle((1, 3, 17, 3), fill=W1)
        d.rectangle((1, 3, 1, 19), fill=W1)
        d.rectangle((17, 3, 17, 19), fill=W3)
        d.rectangle((1, 19, 17, 19), fill=W3)
        for x in (6, 11):
            d.line((x, 4, x, 18), fill=b[2])
        for yy in (8, 13):
            d.line((2, yy, 16, yy), fill=b[2])
    def bolt(d):
        d.polygon([(19, 2), (12, 14), (16, 14), (13, 24), (23, 10), (18, 10), (22, 2)], fill=y[1])
        d.polygon([(18, 10), (23, 10), (14, 22), (16, 14)], fill=y[2])
        d.line((19, 3, 14, 12), fill=y[0])
        d.line((20, 2, 21, 2), fill=y[0])
    ic.piece(mast)
    ic.piece(panel)
    ic.piece(bolt)

def _tab_comms(ic):
    cy = RAMP["cyan"]
    c = np.array([10.0, 14.0])
    u = np.array([0.7071, 0.7071])     # along the rim (upper left to lower right)
    n = np.array([0.7071, -0.7071])    # the way the dish looks (up and right)
    def ell(a, b, t0, t1, k=32):
        return [tuple(int(v) for v in np.round(c + a * math.cos(t) * u + b * math.sin(t) * n)) for t in np.linspace(t0, t1, k)]
    def stand(d):
        d.polygon([(9, 17), (11, 17), (12, 22), (8, 22)], fill=D1)
        d.rectangle((4, 22, 15, 23), fill=D2)
        d.line((4, 22, 15, 22), fill=D1)
    def dish(d):
        d.polygon(ell(9, 6, math.pi, 2 * math.pi), fill=W3)          # the back of the bowl
        d.polygon(ell(9, 3.2, 0, 2 * math.pi), fill=W2)              # the face
        d.polygon(ell(6.5, 2, 0, 2 * math.pi), fill=W1)
        d.line([(10, 14), (15, 9)], fill=D2)
    def feed(d):
        d.rectangle((15, 7, 17, 9), fill=W3)
        d.point((15, 7), fill=W1)
    def waves(d):
        d.arc((12, 2, 22, 12), 280, 350, fill=cy[1], width=2)
        d.arc((10, -2, 26, 14), 278, 352, fill=cy[1], width=2)
    ic.piece(stand)
    ic.piece(dish)
    ic.piece(feed)
    ic.piece(waves)

def _tab_science(ic):
    g = RAMP["green"]
    def body(d):
        d.rectangle((5, 5, 10, 8), fill=D1)
        d.rectangle((17, 6, 20, 8), fill=W3)
        d.rounded_rectangle((1, 8, 24, 21), radius=2, fill=D1)
        d.rectangle((2, 9, 23, 10), fill=_c("6478a2"))
        d.rectangle((2, 19, 23, 20), fill=D2)
        d.rectangle((19, 11, 22, 13), fill=g[0])
    def lens(d):
        d.ellipse((6, 8, 19, 21), fill=W2)
        d.arc((6, 8, 19, 21), 135, 315, fill=W1)
        d.ellipse((8, 10, 17, 19), fill=D3)
        d.ellipse((9, 11, 16, 18), fill=g[2])
        d.ellipse((10, 12, 15, 17), fill=g[1])
        d.rectangle((10, 12, 11, 13), fill=g[0])
        d.point((11, 12), fill=W1)
    ic.piece(body)
    ic.piece(lens)

def _tab_landing(ic):
    o = RAMP["orange"]
    def canopy(d):
        box = (1, 2, 24, 22)
        for i in range(6):
            d.pieslice(box, 180 + 30 * i, 210 + 30 * i, fill=o[1] if i % 2 == 0 else W2)
        d.line((2, 12, 23, 12), fill=o[2])
        d.arc((3, 4, 22, 20), 200, 250, fill=W1)
    def ropes(d):
        for a, b in (((3, 13), (10, 18)), ((8, 13), (11, 17)), ((17, 13), (14, 17)), ((22, 13), (15, 18))):
            d.line((a, b), fill=W3)
    def capsule(d):
        d.polygon([(10, 17), (15, 17), (17, 22), (8, 22)], fill=W2)
        d.polygon([(13, 17), (15, 17), (17, 22), (14, 22)], fill=W3)
        d.line((10, 17, 9, 21), fill=W1)
        d.rectangle((8, 22, 17, 23), fill=D2)
        d.point((11, 19), fill=RAMP["cyan"][1])
    ic.piece(canopy)
    ic.flat(ropes)
    ic.piece(capsule)

def _tab_robot(ic):
    v = RAMP["violet"]
    def mast(d):
        d.rectangle((17, 3, 18, 9), fill=W3)
        d.rectangle((15, 1, 21, 4), fill=W2)
        d.rectangle((15, 1, 21, 1), fill=W1)
        d.rectangle((19, 2, 20, 3), fill=RAMP["cyan"][1])
    def body(d):
        d.rectangle((1, 8, 23, 9), fill=RAMP["cell"][1])
        d.line((1, 8, 23, 8), fill=RAMP["cell"][0])
        d.rectangle((4, 10, 21, 15), fill=v[1])
        d.rectangle((4, 10, 21, 10), fill=v[0])
        d.rectangle((4, 15, 21, 15), fill=v[2])
        d.rectangle((7, 12, 10, 13), fill=v[2])
    def legs(d):
        d.line((5, 19, 8, 15), fill=D1)
        d.line((13, 19, 12, 15), fill=D1)
        d.line((21, 19, 17, 15), fill=D1)
        d.line((5, 16, 21, 16), fill=D1)
    def wheels(d):
        for x in (2, 10, 18):
            d.ellipse((x, 17, x + 6, 23), fill=D3)
            d.ellipse((x + 2, 19, x + 4, 21), fill=W3)
            d.point((x + 2, 18), fill=D1)
    ic.piece(mast)
    ic.piece(body)
    ic.flat(legs)
    ic.piece(wheels)

def _tab_return(ic):
    def earth(d):
        d.ellipse((13, 1, 24, 12), fill=RAMP["cell"][1])
        d.polygon([(15, 4), (18, 3), (19, 6), (16, 8)], fill=RAMP["green"][2])
        d.polygon([(20, 7), (23, 6), (22, 10), (20, 10)], fill=RAMP["green"][2])
        d.arc((13, 1, 24, 12), 160, 260, fill=RAMP["cell"][0])
        d.point((16, 4), fill=W1)
    def arrow(d):
        d.arc((5, 6, 21, 26), 190, 262, fill=W1, width=2)
        d.polygon([(11, 4), (15, 6), (11, 9)], fill=W1)
    def capsule(d):
        d.polygon([(4, 14), (8, 14), (12, 22), (0, 22)], fill=W2)
        d.polygon([(6, 14), (8, 14), (12, 22), (7, 22)], fill=W3)
        d.line((4, 14, 1, 21), fill=W1)
        d.rectangle((0, 22, 12, 23), fill=RAMP["orange"][2])
        d.point((5, 17), fill=RAMP["cyan"][1])
    ic.piece(earth)
    ic.piece(arrow)
    ic.piece(capsule)

def _tab_fuel(ic):
    p = RAMP["pink"]
    def tank(d):
        d.rectangle((10, 0, 15, 2), fill=D1)
        d.ellipse((5, 2, 20, 9), fill=W2)
        d.ellipse((5, 17, 20, 24), fill=W3)
        d.rectangle((5, 5, 20, 20), fill=W2)
        d.rectangle((5, 5, 7, 20), fill=W1)
        d.rectangle((17, 5, 20, 21), fill=W3)
        d.line((5, 19, 20, 19), fill=D1)
    def drop(d):
        d.polygon([(12, 7), (13, 7), (17, 14), (8, 14)], fill=p[1])
        d.ellipse((8, 11, 17, 20), fill=p[1])
        d.pieslice((8, 11, 17, 20), 300, 90, fill=p[2])
        d.rectangle((10, 13, 11, 15), fill=p[0])
    ic.piece(tank)
    ic.piece(drop)

def _tab_protect(ic):
    s = RAMP["shield"]
    pts = [(3, 2), (12, 4), (13, 4), (22, 2), (22, 13), (19, 18), (13, 23), (12, 23), (6, 18), (3, 13)]
    def shield(d):
        d.polygon(pts, fill=s[1])
        d.polygon([(13, 4), (22, 2), (22, 13), (19, 18), (13, 23)], fill=s[2])
        d.line([(5, 4), (11, 6)], fill=s[0])
        d.line([(5, 4), (5, 12), (7, 16)], fill=s[0])
        star = [(12.5 + (5.5 if k % 2 == 0 else 2.3) * math.sin(k * math.pi / 5),
                 12.5 - (5.5 if k % 2 == 0 else 2.3) * math.cos(k * math.pi / 5)) for k in range(10)]
        d.polygon(star, fill=W1)
        d.polygon([(12.5, 12.5), star[4], star[5], star[6]], fill=W2)
    ic.piece(shield)

def build_tabs():
    """art/vab/tabs.png: the nine bin tab icons, 26 x 26 each, left to right in TAB_ORDER."""
    strip = np.zeros((TS, TS * len(TAB_ORDER), 4), np.uint8)
    for i, cat in enumerate(TAB_ORDER):
        ic = TabIcon()
        globals()["_tab_" + cat](ic)
        strip[:, i * TS:(i + 1) * TS] = ic.a
    return strip

FORKLIFT_POS = (204, 270)   # on the empty floor between the access tower and the lane, behind the stand
FORKLIFT_RUN = (204, 336)   # stops before the service frame, which stands in front of this line

def main():
    os.makedirs(OUT, exist_ok=True)
    bg, st, launcher, hook = build_bg()
    assert bg.shape == (H, W, 4) and bg[..., 3].min() == 255
    Image.fromarray(bg).save(os.path.join(OUT, "bg.png"))
    fg = build_fg()
    assert fg[60:300, 250:371, 3].max() == 0, "fg must leave the middle clear"
    Image.fromarray(fg).save(os.path.join(OUT, "fg.png"))
    Image.fromarray(build_beacon()).save(os.path.join(OUT, "beacon.png"))
    Image.fromarray(build_forklift()).save(os.path.join(OUT, "forklift.png"))
    Image.fromarray(build_tabs()).save(os.path.join(OUT, "tabs.png"))
    STAND_LIGHTS.sort()
    for p in BEACONS + LAMPS + SPARKS + STAND_LIGHTS + [st, launcher]:
        assert 150 <= p[0] < 470 and 24 <= p[1] < H, p
    assert abs(st[0] - 310) <= 2 and 310 <= st[1] <= 330 and 425 <= launcher[0] <= 440 and 290 <= launcher[1] <= 320
    col = lambda p: tuple(bg[p[1], p[0]])
    assert all(col(p) == tuple(PAL[R[1]]) for p in BEACONS), "a beacon is not on its dim red pixel"
    assert all(col(p) == tuple(PAL[WH[1]]) for p in LAMPS), "a lamp is not on its lens"
    assert all(col(p) == tuple(PAL[WH[1] if i % 2 == 0 else C[0]]) for i, p in enumerate(STAND_LIGHTS)), "stand lights moved"
    assert col(st) in (tuple(PAL[S[9]]), tuple(PAL[S[7]])) and col((st[0], st[1] + 1)) == tuple(PAL[S[9]]), "STAND_TOP is not the centre mark"
    x0, y0, x1, y1 = DOOR
    assert not set(map(col, [(x, y) for x in (x0 + 2, x1 - 2) for y in range(y0, 190)])) & {tuple(PAL[G[1]])}, "WINDOW includes the door edge"
    write_meta(st, launcher, hook)
    n = len(set(map(tuple, bg.reshape(-1, 4))))
    print("bg colours", n, "STAND_TOP", st, "LAUNCHER_BASE", launcher, "hook", hook)
    print("BEACONS", BEACONS, "\nLAMPS", LAMPS, "\nSPARKS", SPARKS)

if __name__ == "__main__":
    if sys.argv[1:] == ["tabs"]:   # only the bin tab icons, without repainting the hall
        Image.fromarray(build_tabs()).save(os.path.join(OUT, "tabs.png"))
    else:
        main()
