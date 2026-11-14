"""Event card art (v6): hazard stripes, the ALERT warning sign, the radio icon and the mission-control
operator portrait for the MESSAGE FROM EARTH card. Pure numpy/PIL, palette from palette.py.

    python tools/art/gen_event_ui.py        (writes art/ui/event_*.png)
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from palette import P  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "ui")
CLEAR = (0, 0, 0, 0)


def save(a, name):
    Image.fromarray(a.astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("wrote", name, a.shape[1], "x", a.shape[0])


def from_ascii(rows, key):
    h, w = len(rows), max(len(r) for r in rows)
    a = np.zeros((h, w, 4), np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            a[y, x] = key.get(ch, CLEAR)
    return a


def stripes():
    """16 x 6 tile, tiles sideways: amber and ink diagonals, a light top edge and a dark bottom edge."""
    w, h = 16, 6
    a = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            amber = ((x + y) // 4) % 2 == 0
            if amber:
                c = P["orange3"] if y == 0 else (P["orange1"] if y == h - 1 else P["orange2"])
            else:
                c = P["jet1"] if y == 0 else P["ol"]
            a[y, x] = c
    save(a, "event_stripes")


def alert():
    """20 x 18 warning triangle with an exclamation mark, lit from the upper left."""
    w, h = 20, 18
    a = np.zeros((h, w, 4), np.uint8)
    cx = (w - 1) / 2.0
    for y in range(h):
        half = (y + 1) * (w / 2.0) / h          # the triangle widens downwards
        for x in range(w):
            d = abs(x - cx)
            if d <= half:
                edge = d > half - 1.2 or y == h - 1 or y == 0
                if edge:
                    a[y, x] = P["ol"]
                elif x < cx and d > half - 2.6:
                    a[y, x] = P["orange3"]       # highlight strip on the lit side
                elif y >= h - 3:
                    a[y, x] = P["orange1"]       # dark lower edge
                else:
                    a[y, x] = P["orange2"]
    # the exclamation mark
    for y in range(5, 12):
        for x in (9, 10):
            a[y, x] = P["ol"]
    for x in (9, 10):
        a[13, x] = P["ol"]
        a[14, x] = P["ol"]
    save(a, "event_alert")


def radio():
    """20 x 18 radio mast sending waves: a cyan-white mast and three arcs on each side."""
    w, h = 20, 18
    a = np.zeros((h, w, 4), np.uint8)
    cx, cy = 9.5, 6.0
    for y in range(h):
        for x in range(w):
            r = np.hypot(x - cx, (y - cy) * 1.1)
            ang = abs(np.degrees(np.arctan2(y - cy, abs(x - cx) + 1e-6)))
            if ang < 38 and abs(x - cx) > 1.5:
                for k, rad in enumerate((3.6, 6.4, 9.2)):
                    if abs(r - rad) < 0.65:
                        a[y, x] = (P["glass3"], P["glass2"], P["glass1"])[k]
    # mast: a tripod under a bright ball
    for y in range(8, 17):
        spread = (y - 8) // 3
        for x in (9 - spread, 10 + spread):
            a[y, x] = P["metal3"] if x <= 9 else P["metal1"]
    for x in range(6, 14):
        a[17, x] = P["metal1"]
    for (x, y, c) in [(9, 5, "glass3"), (10, 5, "glass2"), (9, 6, "glass2"), (10, 6, "glass1"), (9, 7, "metal2"), (10, 7, "metal1")]:
        a[y, x] = P[c]
    a[4, 9] = P["paint4"]
    save(a, "event_radio")


# Left half of the 24 x 24 operator portrait; the right half is its mirror (then shaded and given the mic).
#   o outline  h hair  H hair light  w headset band  m ear cup  s skin  k skin light  e eye  W glint
#   S skin shadow  c collar  t shirt  T shirt shadow  L shirt light
HALF = [
    "            ",
    "        oooo",
    "      oowwww",
    "     owhhHHH",
    "    owhhHHHh",
    "    owhhhhhh",
    "   oowhhhhhh",
    "  ommwhhssss",
    "  ommwhsskkk",
    "  ommwsskkkk",
    "  ommoskWeks",
    "  ommoskeeks",
    "   oooskkkks",
    "     oskkkkk",
    "     oSskkkS",
    "     oSskkSS",
    "      oSsskk",
    "       oSSss",
    "      ccoSSs",
    "    ottcoSSS",
    "  otttttccoo",
    " otTtttttLtt",
    " otTtttttLtt",
    " otTtttttLtt",
]


def operator():
    rows = []
    for r in HALF:
        right = r[::-1]
        # the right half is in shade: light skin -> skin, skin -> shadow, light hair -> hair, light shirt -> shirt
        right = right.translate(str.maketrans({"k": "s", "s": "S", "H": "h", "L": "t"}))
        rows.append(r + right)
    key = {
        "o": P["ol"], "h": P["jet2"], "H": P["jet3"], "w": P["metal3"], "m": P["jet1"],
        "s": (200, 138, 100, 255), "k": (232, 176, 132, 255), "S": (150, 94, 66, 255),
        "e": P["ol"], "W": P["paint4"], "c": P["paint3"],
        "t": P["glass1"], "T": P["glass0"], "L": P["glass2"],
    }
    a = from_ascii(rows, key)
    a[10, 14], a[10, 15] = key["W"], key["e"]   # both glints on the upper left, as the light falls
    # the microphone boom from the left ear cup to the mouth, with a green light on its tip
    for (x, y) in [(5, 12), (6, 13), (7, 14), (8, 15)]:
        a[y, x] = P["jet3"]
    a[15, 9] = (109, 255, 138, 255)
    # background: the blue glow of the control room, darker downwards
    bg = np.zeros_like(a)
    for y in range(24):
        c = np.array(P["cell2"] if y < 8 else (P["cell1"] if y < 16 else P["cell0"]), np.uint8)
        bg[y, :] = c
    # two screen lights behind the operator
    for x in range(2, 7):
        bg[3, x] = P["glass2"]
        bg[4, x] = P["glass1"]
    for x in range(18, 22):
        bg[5, x] = P["glass2"]
    out = np.where(a[..., 3:4] > 0, a, bg)
    save(out, "event_operator")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    stripes()
    alert()
    radio()
    operator()
