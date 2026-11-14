"""Ship-kit sprites: Blender passes in art/raw3d/parts -> palette pixel art in art/parts.

    python tools/art/gen_parts.py            (everything)
    python tools/art/gen_parts.py bus hga    (only the sprites whose name starts so)

Each sprite is cropped to its pixels; where it sits on the ship (top-left corner, relative to the
centre of the bus) is written into the generated table inside scripts/ship_kit.gd.
The flat parts (solar panels, their yokes, the launcher icons) are drawn here with PIL.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose3d import compose, _outline  # noqa: E402
from palette import P, _rgb  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "art", "raw3d", "parts")
OUT = os.path.join(ROOT, "art", "parts")
KIT = os.path.join(ROOT, "scripts", "ship_kit.gd")
TABLE = os.path.join(RAW, "table.json")

P = dict(P)
for k, v in {
    "green0": "0c3a22", "green1": "1a6e3a", "green2": "34b45a", "green3": "8cf08a",
    "bag0": "4e4034", "bag1": "7e6c54", "bag2": "b09c78", "bag3": "d8caa4", "bag4": "f2ead0",
    "tps0": "2a1814", "tps1": "48281e", "tps2": "6e3e2a", "tps3": "985a3a", "tps4": "c08058",
    "titan0": "222c3c", "titan1": "3c4e68", "titan2": "607a98", "titan3": "92acc6", "titan4": "cfe0ee",
    "lite0": "1a1226", "lite1": "2c1e44", "lite2": "46306a", "lite3": "7a5ab0",
    "cloth0": "4a463c", "cloth1": "7c7664", "cloth2": "b0a890", "cloth3": "dcd5bf", "cloth4": "f6f2e4",
    "hull0": "24211e", "hull1": "433d35", "hull2": "6a6152", "hull3": "93876f", "hull4": "b8ab8c", "hull5": "dccfaa",
}.items():
    P[k] = _rgb(v)

with open(os.path.join(RAW, "parts.json")) as fh:
    _meta = json.load(fh)
MATS = {n: {"id": v["id"], "ramp": [P[c] for c in v["ramp"]], "order": v["order"]} for n, v in _meta.items()}
# the heat shield is seen from its shadow side: lift its ramps so it reads on a dark screen
MATS["tps"]["ramp"] = [P[c] for c in ("tps1", "tps2", "tps3", "tps4", "tps4")]
MATS["hsin"]["ramp"] = [P[c] for c in ("jet1", "jet2", "jet3", "metal1")]
LAST = {}   # part map and names of the last render()
HULL_CUT = 30   # ship y of the bus bottom: hull_front keeps the pressure hull above it
with open(os.path.join(RAW, "sprites.json")) as fh:
    CANVAS = json.load(fh)


def crop(img):
    """-> (cropped image, x offset, y offset)."""
    a = img[..., 3] > 0
    ys, xs = np.where(a)
    if len(xs) == 0:
        return img[:1, :1], 0, 0
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], int(xs.min()), int(ys.min())


def render(name, outline=True):
    img, part, names = compose(os.path.join(RAW, name + "_id.png"), os.path.join(RAW, name + "_n.png"),
                               MATS, factor=4, outline=False)
    img[part == names.index("hold")] = 0        # occluders cut the sprite
    LAST["part"], LAST["names"] = part, names
    if outline:
        img = _outline(img, P["ol"], True)
    return img


# ------------------------------------------------------------------ flat parts (PIL / numpy)

def px(img, x, y, c):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = P[c] if isinstance(c, str) else c


def rect(img, x0, y0, x1, y1, c):
    """Inclusive corners."""
    img[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = P[c]


def solar_panel(lite):
    """One wing panel, 24 x 24: frame, 3 x 4 cells, a diagonal sheen, a dark lower edge."""
    w, h = 24, 24
    img = np.zeros((h, w, 4), dtype=np.uint8)
    frame = ("gold1", "gold2", "gold3", "gold4") if lite else ("metal0", "metal1", "metal3", "metal4")
    cell = ("lite0", "lite1", "lite2", "lite3") if lite else ("cell0", "cell1", "cell2", "cell3")
    rect(img, 1, 1, w - 2, h - 2, frame[1])
    rect(img, 1, 1, w - 2, 1, frame[3])          # highlight strip along the top
    rect(img, 1, 2, 1, h - 3, frame[2])
    rect(img, 1, h - 3, w - 2, h - 2, frame[0])  # dark lower edge
    rect(img, w - 2, 2, w - 2, h - 2, frame[0])
    rect(img, 2, 2, w - 3, h - 4, cell[0])       # grid lines
    for r in range(4):
        for c in range(3):
            x0, y0 = 2 + c * 7, 2 + r * 5
            lit = (c + r) in (1, 2)                # diagonal sheen
            rect(img, x0, y0, x0 + 5, y0 + 3, cell[2] if lit else cell[1])
            rect(img, x0, y0, x0 + 5, y0, cell[3] if lit else cell[2])
            px(img, x0, y0 + 1, cell[3] if lit else cell[2])
            px(img, x0 + 5, y0 + 3, cell[1] if lit else cell[0])
    spine = frame[1] if lite else "metal1"         # wiring spines between the cell columns
    for x in (8, 15):
        for y in (6, 11, 16):
            px(img, x, y, spine if not lite else frame[3])
    if lite:                                       # clipped outer corners: a roll-out blanket
        for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
            img[y, x] = 0
        rect(img, 8, 2, 8, h - 4, frame[1])
        rect(img, 15, 2, 15, h - 4, frame[1])
    return _outline(img, P["ol"], True)


def solar_yoke(left):
    """Hinge motor on the bus wall and a V of two struts out to the first panel. 9 x 24."""
    w, h = 9, 24
    img = np.zeros((h, w, 4), dtype=np.uint8)
    cy = 11
    for x in range(2, w):                          # struts fan out from the motor to the panel corners
        t = (x - 2) / (w - 3)
        yu = int(round(cy - 1 - t * 7))
        yl = int(round(cy + 2 + t * 7))
        px(img, x, yu, "metal3")
        px(img, x, yu + 1, "metal1")
        px(img, x, yl, "metal2")
        px(img, x, yl + 1, "metal0")
    rect(img, 4, cy, w - 1, cy + 1, "metal2")      # spar
    rect(img, 4, cy, w - 1, cy, "metal4")
    rect(img, 1, cy - 3, 4, cy + 4, "jet2")        # motor
    rect(img, 1, cy - 3, 4, cy - 3, "jet3")
    rect(img, 1, cy + 4, 4, cy + 4, "jet0")
    rect(img, 4, cy - 2, 4, cy + 4, "jet1")
    px(img, 2, cy - 1, "orange2")
    px(img, 2, cy + 1, "metal3")
    if left:
        img = img[:, ::-1].copy()
        for y in range(cy - 2, cy + 4):            # the motor's dark edge stays on the right
            img[y, w - 5] = P["jet2"]
            img[y, w - 2] = P["jet1"]
    return _outline(img, P["ol"], True)


def rail():
    """A length of the payload rail (rovers and the drone hang from it). 30 x 4."""
    img = np.zeros((4, 30, 4), dtype=np.uint8)
    rect(img, 0, 1, 29, 1, "metal3")
    rect(img, 0, 2, 29, 2, "metal1")
    for x in (7, 22):
        px(img, x, 1, "metal4")
        px(img, x, 2, "jet2")
    return _outline(img, P["ol"], True)


ROCKET_ICONS = {
    # rows of (x offset from centre, width, colour) spans, top to bottom; drawn 1:1
    "electron": [
        "....k....", "...kkK...", "...kkK...", "...kkK...", "...wwW...", "...kkK...",
        "...mmM...", "...kkK...", "...kkK...", "...rrR...", "...kkK...", "...kkK...",
        "...wwW...", "...kkK...", "...kkK...", "...mmM...", "...n.n...",
    ],
    "falcon9": [
        "....w....", "...wwW...", "..wwwwW..", "..wwwwW..", "..wwwwW..", "..wwwwW..", "...wwW...", "...jjJ...",
        "...wwW...", "...wwW...", "...wwW...", "...dDd...", "...wwW...", "...wwW...", "...wwW...", "...wwW...",
        "...wwW...", "...wwW...", "...wwW...", "...wwW...", "..jwwWj..", "..jjjJj..", "..jnnnj..",
    ],
    "vulcan": [
        ".....w.....", "....wwW....", "...wwwwW...", "...wwwwW...", "...wwwwW...", "...wwwwW...", "...wwwwW...",
        "....rrR....", "....wwW....", "....dDd....", "....ooO....", "....ooO....", "..w.ooO.w..", "..w.ooO.w..",
        ".wW.ooO.wW.", ".wW.ooO.wW.", ".wW.ooO.wW.", ".wW.ooO.wW.", ".wW.ooO.wW.", ".wW.ooO.wW.", ".dD.ooO.dD.",
        ".wW.jjJ.wW.", ".nn.n.n.nn.",
    ],
    "heavy": [
        "......w......", ".....wwW.....", "....wwwwW....", "....wwwwW....", "....wwwwW....", "....wwwwW....",
        ".....wwW.....", ".....jjJ.....", ".....wwW.....", ".w...wwW...w.", ".wW..dDd..wW.", "wwW..wwW..wwW",
        "wwW.jwwWj.wwW", "wwW..wwW..wwW", "wwW..wwW..wwW", "wwW..wwW..wwW", "wwW..wwW..wwW", "wwW..wwW..wwW",
        "wwW.jwwWj.wwW", "wwW..wwW..wwW", "wwW..wwW..wwW", "jjJ..jjJ..jjJ", "nnn..nnn..nnn",
    ],
}
ICON_KEY = {"w": "paint3", "W": "paint1", "j": "jet2", "J": "jet1", "m": "metal3", "M": "metal1", "r": "red2",
            "R": "red1", "d": "jet2", "D": "jet1", "o": "orange2", "O": "orange1", "n": "metal1", "a": "metal3", "k": "jet3", "K": "jet2"}


def rocket_icon(name):
    rows = ROCKET_ICONS[name]
    w = len(rows[0])
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    x0, y0 = (24 - w) // 2, 23 - len(rows)
    for y, row in enumerate(rows):
        assert len(row) == w, (name, y)
        for x, ch in enumerate(row):
            if ch != ".":
                img[y0 + y, x0 + x] = P[ICON_KEY[ch]]
    for y, row in enumerate(rows):                 # a highlight column on the lit side of every body
        for x, ch in enumerate(row):
            if ch == "w" and (x == 0 or row[x - 1] in ".j"):
                img[y0 + y, x0 + x] = P["paint4"]
    return _outline(img, P["ol"], True)


def solar_icon(lite):
    """A short wing: yoke and two panels at icon size (22 x 18)."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    frame = ("gold1", "gold2", "gold4") if lite else ("metal1", "metal3", "metal4")
    cell = ("lite0", "lite1", "lite2", "lite3") if lite else ("cell0", "cell1", "cell2", "cell3")
    rect(img, 1, 10, 4, 13, "jet2")
    rect(img, 1, 10, 4, 10, "jet3")
    px(img, 2, 12, "orange2")
    rect(img, 4, 11, 6, 12, "metal3")
    for k, x0 in enumerate((6, 15)):
        rect(img, x0, 3, x0 + 7, 20, frame[0])
        rect(img, x0, 3, x0 + 7, 3, frame[2])
        rect(img, x0, 4, x0, 19, frame[1])
        rect(img, x0 + 1, 4, x0 + 6, 19, cell[0])
        for r in range(4):
            for c in range(2):
                bx, by = x0 + 1 + c * 3, 4 + r * 4
                lit = (c + r + k) in (1, 2)
                rect(img, bx, by, bx + 2, by + 2, cell[2] if lit else cell[1])
                rect(img, bx, by, bx + 2, by, cell[3] if lit else cell[2])
    rect(img, 14, 11, 14, 12, "metal3")
    return _outline(img, P["ol"], True)


def heatshield_front(img, part, names):
    """The near wall of the bowl (same canvas as the heat shield): drawn again over whatever sits
    in the bowl. `part` is the part map cropped like img. Everything from the widest row down that
    is not the inside of the bowl."""
    a = img[..., 3] > 0
    wide = int(np.argmax(a.sum(axis=1)))
    inside = (part == names.index("hsin")) | (part == names.index("jet"))
    out = img.copy()
    out[:wide] = 0
    out[inside] = 0
    return out


def line(img, x0, y0, x1, y1, c_top, c_bot=None):
    """A line with a second tone under it (2 px thick when c_bot is given)."""
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        x = int(round(x0 + (x1 - x0) * i / max(n, 1)))
        y = int(round(y0 + (y1 - y0) * i / max(n, 1)))
        if c_bot:
            px(img, x, y + 1, c_bot)
        px(img, x, y, c_top)


def icon_mag():
    """Magnetometer: a long boom from its wall mount up to the sensor head."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    line(img, 19, 18, 6, 6, "metal3", "metal1")
    for (x, y) in ((15, 14), (10, 10)):            # boom hinges
        rect(img, x, y, x + 1, y + 2, "jet3")
    rect(img, 17, 16, 21, 21, "jet2")              # wall mount
    rect(img, 17, 16, 21, 16, "jet3")
    px(img, 19, 19, "orange2")
    rect(img, 2, 2, 8, 7, "paint3")                # sensor head
    rect(img, 2, 2, 8, 2, "paint4")
    rect(img, 2, 7, 8, 7, "paint1")
    rect(img, 2, 2, 3, 7, "red2")
    rect(img, 2, 2, 3, 2, "red3")
    return _outline(img, P["ol"], True)


def icon_legs():
    """One landing leg: gold upper strut, bare lower strut, brace and foot pad."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    line(img, 4, 14, 14, 17, "metal2", "metal0")   # brace
    for d in (0, 1):                               # lower strut
        line(img, 11 + d, 11, 17 + d, 20, "metal4" if d == 0 else "metal2")
    for d in (0, 1, 2):                            # gold upper strut
        line(img, 6 + d, 4, 12 + d, 13, ("gold4", "gold3", "gold1")[d])
    rect(img, 3, 2, 8, 6, "jet2")                  # hip block
    rect(img, 3, 2, 8, 2, "jet3")
    rect(img, 2, 12, 5, 16, "jet2")                # knee block
    rect(img, 2, 12, 5, 12, "jet3")
    rect(img, 12, 20, 22, 21, "metal3")            # foot pad
    rect(img, 13, 20, 21, 20, "metal4")
    rect(img, 13, 22, 21, 22, "metal1")
    return _outline(img, P["ol"], True)


def icon_heatshield():
    """Aeroshell from the side: bright rim, the dark inside of the bowl, the tiled cone."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    rows = [(4, 7, 16), (5, 3, 20), (6, 1, 22), (7, 1, 22), (8, 1, 22), (9, 2, 21), (10, 3, 20), (11, 4, 19), (12, 5, 18),
            (13, 6, 17), (14, 7, 16), (15, 8, 15), (16, 9, 14), (17, 9, 14)]
    for y, x0, x1 in rows:
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            if y <= 6:
                c = "jet1" if y == 4 else ("jet2" if t < 0.6 else "jet1")       # inside of the bowl
            else:
                c = "tps4" if t < 0.2 else "tps3" if t < 0.5 else "tps2" if t < 0.8 else "tps1"
            px(img, x, y, c)
    for x in range(7, 17):                          # far rim
        px(img, x, 4, "metal2")
    for x in range(3, 21):
        if x < 7 or x > 16:
            px(img, x, 5, "metal2")
    rect(img, 1, 7, 22, 7, "metal4")               # near rim
    rect(img, 12, 7, 22, 7, "metal3")
    px(img, 1, 6, "metal3")
    px(img, 22, 6, "metal2")
    for y, x0, x1 in rows:                          # tile rows
        if y in (10, 14):
            for x in range(x0, x1 + 1):
                px(img, x, y, "tps1" if x > (x0 + x1) // 2 else "tps2")
    rect(img, 9, 17, 14, 17, "tps1")
    for x in (5, 9, 14, 18):                        # ribs inside
        px(img, x, 6, "metal1")
    return _outline(img, P["ol"], True)


def icon_bus_block(img, x0, y0, x1, y1):
    """A small gold bus: metal deck on top, foil body with a lit strip, a dark skirt."""
    rect(img, x0 + 1, y0, x1 - 1, y0, "metal3")
    rect(img, x0, y0 + 1, x1, y0 + 1, "metal2")
    rect(img, x0, y0 + 2, x1, y1, "gold2")
    rect(img, x0, y0 + 2, x1, y0 + 2, "gold4")
    rect(img, x0, y0 + 3, x0 + 1, y1, "gold3")
    rect(img, x1 - 1, y0 + 3, x1, y1, "gold1")
    rect(img, x0, y1, x1, y1, "gold0")


def icon_sunshade():
    """The quilted cloth shade bent round the Sun side of a small bus, on two standoffs."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    icon_bus_block(img, 14, 7, 21, 17)
    for y in (9, 15):                                  # standoffs
        rect(img, 9, y, 13, y, "metal3")
        px(img, 13, y + 1, "metal1")
    cx, cy, r0, r1 = 17.5, 12.0, 8.6, 15.4
    for y in range(24):
        for x in range(24):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = (dx * dx + dy * dy) ** 0.5
            a = np.degrees(np.arctan2(dy, dx)) % 360    # 180 = straight left
            if not (r0 <= r < r1 and 124 <= a <= 236):
                continue
            ring = (r - r0) / (r1 - r0)
            if ring > 0.86:
                c = "metal4" if a < 185 else "metal3"   # frame, outer (sunny) side
            elif a <= 130 or a >= 230:
                c = "metal2"                          # frame at the two ends
            elif a < 190:
                c = "cloth4" if ring > 0.55 else "cloth3" if ring > 0.2 else "cloth2"
            else:
                c = "cloth3" if ring > 0.55 else "cloth2" if ring > 0.2 else "cloth1"
            px(img, x, y, c)
    for a in (153, 180, 207):                         # quilt seams across the band
        for k in range(10):
            r = r0 + 0.6 + k * 0.5
            x = int(cx + r * np.cos(np.radians(a)))
            y = int(cy + r * np.sin(np.radians(a)))
            px(img, x, y, "cloth1" if a < 190 else "cloth0")
    for (x, y) in ((8, 2), (8, 21)):                  # tie-down lugs at the ends
        px(img, x, y, "orange2")
    return _outline(img, P["ol"], True)


def icon_hull():
    """The bronze-grey pressure bowl round the lower bus: bolted rim, a rivet row, a thick porthole."""
    img = np.zeros((24, 24, 4), dtype=np.uint8)
    icon_bus_block(img, 5, 3, 18, 11)
    cx, cy, rx, ry = 11.5, 9.5, 10.6, 12.0
    for y in range(10, 23):
        for x in range(24):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v > 1.0:
                continue
            lit = -u * 0.8 - v * 0.6                  # light from the upper left
            c = "hull4" if lit > 0.4 else "hull3" if lit > -0.05 else "hull2" if lit > -0.5 else "hull1"
            px(img, x, y, c)
    rect(img, 1, 10, 22, 11, "hull3")                  # rim flange with its ring of bolts
    rect(img, 1, 10, 22, 10, "hull4")
    rect(img, 1, 12, 22, 12, "hull1")
    for x in range(2, 22, 3):
        px(img, x, 11, "hull5")
    for x in range(4, 20):                             # weld seam and rivets lower down
        if 4 < x < 19:
            px(img, x, 19, "hull1")
    for x in range(6, 18, 3):
        px(img, x, 18, "hull4")
    for x, y in ((9, 14), (10, 14), (11, 14), (8, 15), (12, 15), (8, 16), (12, 16), (9, 17), (10, 17), (11, 17)):
        px(img, x, y, "hull1")                         # thick porthole frame and glass
    for x, y in ((9, 13), (10, 13), (11, 13), (8, 14), (12, 14), (7, 15), (7, 16)):
        px(img, x, y, "hull5")
    rect(img, 9, 15, 11, 16, "glass1")
    px(img, 9, 15, "glass3")
    px(img, 10, 15, "glass2")
    return _outline(img, P["ol"], True)


# ------------------------------------------------------------------ main

def save(name, img):
    Image.fromarray(img).save(os.path.join(OUT, name + ".png"))


def write_table(table):
    """Rewrite the generated block of scripts/ship_kit.gd (between the two marker lines)."""
    lines = ["# >>> GENERATED by tools/art/gen_parts.py: sprite name -> [x, y, w, h] on the ship. Do not edit.",
             "const SPR: Dictionary = {"]
    row = "\t"
    for n in sorted(table):
        item = '"%s": [%d, %d, %d, %d], ' % (n, *table[n])
        if len(row) + len(item) > 118:
            lines.append(row.rstrip())
            row = "\t"
        row += item
    lines.append(row.rstrip())
    lines.append("}")
    lines.append("# <<< GENERATED")
    with open(KIT, encoding="utf-8") as fh:
        src = fh.read()
    new, n = re.subn(r"# >>> GENERATED.*?# <<< GENERATED", lambda m: "\n".join(lines), src, flags=re.S)
    if n != 1:
        print("WARNING: no generated block in ship_kit.gd; table left in", TABLE)
        return
    with open(KIT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(new)


def main():
    os.makedirs(OUT, exist_ok=True)
    want = sys.argv[1:]
    table = {}
    if os.path.exists(TABLE):
        with open(TABLE) as fh:
            table = json.load(fh)

    def wanted(n):
        return not want or any(n.startswith(w) for w in want)

    for name, (x0, y0, w, h) in CANVAS.items():
        if not wanted(name):
            continue
        img = render(name)
        full = img
        if name in ("icon_mag", "icon_legs", "icon_heatshield", "icon_sunshade", "icon_hull"):
            continue
        if name.startswith("icon_") or name.startswith("lv_"):
            if name.startswith("lv_"):
                img, ox, oy = crop(img)
                # bottom-centre anchored: pad so the nozzles are the last row and x = 0 is the middle
                half = max(-(x0 + ox), x0 + ox + img.shape[1])
                pad = np.zeros((img.shape[0], half * 2, 4), dtype=np.uint8)
                px0 = half + x0 + ox
                pad[:, px0:px0 + img.shape[1]] = img
                img = pad
            save(name, img)
            print(name, img.shape[1], "x", img.shape[0])
            continue
        img, ox, oy = crop(img)
        save(name, img)
        table[name] = [x0 + ox, y0 + oy, img.shape[1], img.shape[0]]
        print(name, table[name])
        if name == "heatshield":
            ys, xs = np.where(full[..., 3] > 0)
            pm = LAST["part"][ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            save("heatshield_front", heatshield_front(img, pm, LAST["names"]))
        if name == "hull":   # the part in front of the bus (drawn over it); the rest stays behind the tanks
            front = img.copy()
            front[max(0, HULL_CUT - (y0 + oy)):] = 0
            front, fx, fy = crop(front)
            save("hull_front", front)
            table["hull_front"] = [x0 + ox + fx, y0 + oy + fy, front.shape[1], front.shape[0]]
    if wanted("solar") or wanted("icon_solar") or wanted("lv_icon"):
        for lite in (False, True):
            n = "solar_lite" if lite else "solar"
            save(n, solar_panel(lite))
            save("icon_" + n, solar_icon(lite))
        save("yoke", solar_yoke(False))
        save("yoke_l", solar_yoke(True))
        save("rail", rail())
        save("icon_mag", icon_mag())
        save("icon_legs", icon_legs())
        save("icon_heatshield", icon_heatshield())
        for r in ROCKET_ICONS:
            save("lv_icon_" + r, rocket_icon(r))
    for n, fn in (("icon_sunshade", icon_sunshade), ("icon_hull", icon_hull)):
        if wanted(n):
            save(n, fn())
    with open(TABLE, "w") as fh:
        json.dump(table, fh)
    write_table(table)
    print("sprites:", len(table))


if __name__ == "__main__":
    main()
