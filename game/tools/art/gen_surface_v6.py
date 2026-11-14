"""v6 surface sprites, written to art/surface_v6/: the astronaut (walk, low-gravity lope, carrying a
science station, kneeling to set it up), the science station packed and deployed, the viewpoint and
station-site flags and the camera icon.

    python tools/art/gen_surface_v6.py

Drawn from a pose skeleton into a part-ID map at 1 art pixel = 1 game pixel, then shaded per part
(light from the upper left: highlight on top/left edges, dark on bottom/right edges, a dark seam where
a nearer part overlaps a farther one) and outlined. numpy/PIL only: no AI images.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "surface_v6")
FW, FH = 28, 40          # astronaut frame; the boots touch the ground on the last row
GROUND = FH - 1

# part -> ramp (dark, mid, light, highlight); later parts in Z are nearer the viewer
RAMPS = {
    "suit_far": [P["paint0"], P["paint1"], P["paint2"], P["paint2"]],
    "glove_far": [P["metal0"], P["metal1"], P["metal1"], P["metal2"]],
    "boot_far": [P["jet0"], P["jet1"], P["jet2"], P["jet2"]],
    "pack": [P["paint0"], P["paint2"], P["paint3"], P["paint4"]],
    "pack_dark": [P["metal0"], P["metal1"], P["metal2"], P["metal3"]],
    "suit": [P["paint1"], P["paint2"], P["paint3"], P["paint4"]],
    "stripe": [P["red0"], P["red1"], P["red2"], P["red3"]],
    "chest": [P["metal0"], P["metal1"], P["metal2"], P["metal3"]],
    "helmet": [P["paint1"], P["paint3"], P["paint4"], P["paint4"]],
    "visor": [P["gold0"], P["gold2"], P["gold3"], P["gold4"]],
    "glove": [P["metal1"], P["metal2"], P["metal3"], P["metal4"]],
    "boot": [P["jet1"], P["jet2"], P["jet3"], P["metal2"]],
    "box": [P["paint1"], P["paint2"], P["paint3"], P["paint4"]],
    "foil": [P["gold0"], P["gold1"], P["gold2"], P["gold3"]],
    "metal": [P["metal0"], P["metal1"], P["metal2"], P["metal3"]],
    "cell": [P["cell0"], P["cell1"], P["cell2"], P["cell3"]],
    "lamp": [P["red1"], P["red2"], P["red3"], P["red3"]],
    "flag_o": [P["orange0"], P["orange1"], P["orange2"], P["orange3"]],
    "flag_c": [P["glass0"], P["glass1"], P["glass2"], P["glass3"]],
    "white": [P["paint2"], P["paint3"], P["paint4"], P["paint4"]],
    "lens": [P["glass0"], P["glass1"], P["glass2"], P["glass3"]],
    "dark": [P["jet0"], P["jet1"], P["jet2"], P["jet3"]],
}
OL = P["ol"]


class Canvas:
    """A part-ID map with a Z order: a stamp only covers pixels of the same or a farther layer."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.part = np.full((h, w), "", dtype=object)
        self.z = np.full((h, w), -1, dtype=int)
        self.flat = np.zeros((h, w), dtype=bool)   # pixels that keep the mid tone (small details)

    def px(self, x, y, part, z, flat=False):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and z >= self.z[y, x]:
            self.part[y, x] = part
            self.z[y, x] = z
            self.flat[y, x] = flat

    def rect(self, x0, y0, x1, y1, part, z, flat=False):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.px(x, y, part, z, flat)

    def disc(self, cx, cy, r, part, z):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.px(x, y, part, z)

    def limb(self, p0, p1, width, part, z):
        """A thick segment: square stamps of `width` px along it."""
        n = max(2, int(math.dist(p0, p1) * 4))
        lo = -(width - 1) // 2
        for i in range(n + 1):
            t = i / n
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t
            for dy in range(lo, lo + width):
                for dx in range(lo, lo + width):
                    self.px(math.floor(x + 0.5) + dx, math.floor(y + 0.5) + dy, part, z)

    def band(self, p0, p1, at, width, part, z):
        """A 1 px stripe across a limb at distance `at` from p0 (a suit band)."""
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        n = math.hypot(dx, dy) or 1.0
        cx, cy = p0[0] + dx / n * at, p0[1] + dy / n * at
        nx, ny = -dy / n, dx / n
        for k in range(width + 1):
            o = k - width / 2.0
            self.px(math.floor(cx + nx * o + 0.5), math.floor(cy + ny * o + 0.5), part, z, flat=True)

    def render(self, outline=True):
        img = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        part, z = self.part, self.z
        for y in range(self.h):
            for x in range(self.w):
                p = part[y, x]
                if p == "":
                    continue
                r = RAMPS[p]

                def other(dx, dy):
                    xx, yy = x + dx, y + dy
                    if not (0 <= xx < self.w and 0 <= yy < self.h):
                        return "", -1
                    return part[yy, xx], z[yy, xx]

                tone = 1
                if not self.flat[y, x]:
                    up, left = other(0, -1), other(-1, 0)
                    down, right = other(0, 1), other(1, 0)
                    if up[0] != p or left[0] != p:
                        tone = 2
                    if down[0] != p or right[0] != p:
                        tone = 0 if tone == 1 else 1
                    if up[0] == "" and left[0] == "":
                        tone = 3
                # a nearer part overlapping this one leaves a dark seam on this side
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    op, oz = other(dx, dy)
                    if op != "" and op != p and oz > z[y, x] + 0 and RAMPS[op] is not r:
                        tone = 0
                        break
                img[y, x] = r[tone]
        if outline:
            a = img[..., 3] > 0
            pad = np.pad(a, 1)
            edge = ~a & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
            img[edge] = OL
        return img


def ang(p, a_deg, length):
    a = math.radians(a_deg)
    return (p[0] + math.sin(a) * length, p[1] + math.cos(a) * length)


THIGH, SHIN, UPPER, FORE = 8.0, 8.0, 6.0, 6.0


def leg_drop(thigh, shin):
    return math.cos(math.radians(thigh)) * THIGH + math.cos(math.radians(shin)) * SHIN


def astronaut(legs, arms, carry=False, lean=0.0, hip_dy=0.0, kneel=False):
    """legs: ((thigh, shin) near, (thigh, shin) far) in degrees from straight down, + = forward.
    arms: ((upper, fore) near, (upper, fore) far). The hip height keeps the lowest boot on the ground."""
    c = Canvas(FW, FH)
    drop = max(leg_drop(*legs[0]), leg_drop(*legs[1]))
    hip = (12.0, GROUND - 2.0 - drop + hip_dy)
    neck = (hip[0] + 1.0 + lean, hip[1] - 10.0)
    shoulder = (hip[0] + 1.0 + lean * 0.8, hip[1] - 8.0)

    def leg(spec, near):
        thigh, shin = spec
        knee = ang(hip, thigh, THIGH)
        ankle = ang(knee, shin, SHIN)
        part = "suit" if near else "suit_far"
        boot = "boot" if near else "boot_far"
        zz = 60 if near else 10
        c.limb(hip, knee, 4, part, zz)
        c.limb(knee, ankle, 3, part, zz)
        if near:
            c.band(hip, knee, 6.0, 3, "stripe", zz + 1)
        ax, ay = round(ankle[0]), round(ankle[1])
        if kneel and not near:
            c.rect(ax - 3, ay - 1, ax, ay + 1, boot, zz + 1)       # toes on the ground behind
        else:
            c.rect(ax - 1, ay, ax + 3, ay + 1, boot, zz + 1)
            c.rect(ax - 1, ay - 1, ax + 1, ay - 1, boot, zz + 1)

    def arm(spec, near):
        upper, fore = spec
        elbow = ang(shoulder, upper, UPPER)
        hand = ang(elbow, fore, FORE)
        part = "suit" if near else "suit_far"
        zz = 80 if near else 5
        c.limb(shoulder, elbow, 3, part, zz)
        c.limb(elbow, hand, 3, part, zz)
        if near:
            c.band(shoulder, elbow, 4.0, 2, "stripe", zz + 1)
        c.disc(hand[0], hand[1], 1.2, "glove" if near else "glove_far", zz + 1)
        return hand

    leg(legs[1], False)
    arm(arms[1], False)
    # life-support backpack on the back
    bx = neck[0] - 9
    c.rect(bx, neck[1] - 1, bx + 4, neck[1] + 10, "pack", 20)
    c.rect(bx + 1, neck[1] + 3, bx + 3, neck[1] + 3, "pack_dark", 21, flat=True)
    c.rect(bx + 1, neck[1] + 6, bx + 3, neck[1] + 6, "pack_dark", 21, flat=True)
    # torso
    for i in range(11):
        k = i / 10.0
        cx = hip[0] + (neck[0] - hip[0]) * (1 - k) + 0.0
        y = neck[1] + i
        c.rect(cx - 4, y, cx + 3, y, "suit", 30)
    c.rect(neck[0] + 2, neck[1] + 3, neck[0] + 4, neck[1] + 5, "chest", 31)   # display and control module
    c.px(neck[0] + 3, neck[1] + 4, "lamp", 32, flat=True)
    # helmet with a gold sun visor facing forward
    hc = (neck[0] + 1.0, neck[1] - 4.0)
    c.disc(hc[0], hc[1], 4.6, "helmet", 40)
    for y in range(int(hc[1]) - 2, int(hc[1]) + 3):
        for x in range(int(hc[0]), int(hc[0]) + 6):
            if (x - hc[0]) ** 2 + (y - hc[1]) ** 2 <= 4.6 * 4.6 - 1.5:
                c.px(x, y, "visor", 41)
    c.px(hc[0] + 2, hc[1] - 1, "white", 42, flat=True)
    if carry:
        # the packed station held at the waist with both hands
        bx0, by0 = int(shoulder[0] + 5), int(shoulder[1] + 3)
        c.rect(bx0, by0, bx0 + 8, by0 + 6, "box", 70)
        c.rect(bx0, by0 + 2, bx0 + 8, by0 + 2, "foil", 71, flat=True)
        c.rect(bx0 + 3, by0 - 1, bx0 + 5, by0 - 1, "metal", 71, flat=True)
    leg(legs[0], True)
    arm(arms[0], True)
    return c.render()


def walk(ph, carry):
    """One frame of a walk cycle at phase ph (0..1): a steady Mars walk."""
    out = []
    for leg_ph in (ph, ph + 0.5):
        s = math.sin(2 * math.pi * leg_ph)
        cs = math.cos(2 * math.pi * leg_ph)
        thigh = 26.0 * s
        shin = thigh - 38.0 * max(0.0, cs) * 0.9 - 4.0
        out.append((thigh, shin))
    s = math.sin(2 * math.pi * ph)
    arms = ((-22 * s, -22 * s + 25), (22 * s, 22 * s + 25))
    if carry:
        arms = ((35, 95), (40, 100))
    return astronaut((out[0], out[1]), arms, carry, lean=1.0)


# the Apollo "bunny hop" lope: crouch, push off, float, reach for the ground
LOPE = [
    (((40, -12), (34, -18)), 0.0),
    (((-6, -14), (-18, -26)), 1.5),
    (((26, -8), (8, -30)), 1.0),
    (((32, 14), (2, -16)), 0.5),
]


def lope(i, carry):
    legs, lean = LOPE[i]
    arms = ((-30, 10), (20, 50)) if i in (1, 2) else ((10, 40), (-10, 30))
    if carry:
        arms = ((35, 95), (40, 100))
    return astronaut(legs, arms, carry, lean=lean)


def kneel(i):
    # near leg forward with the knee up, far knee on the ground; both hands down at the station
    legs = ((70, 0), (8, -88))
    arms = ((60 + 8 * i, 120 - 10 * i), (50 - 6 * i, 110 + 8 * i))
    return astronaut(legs, arms, lean=2.0, kneel=True)


def idle(carry):
    arms = ((35, 95), (40, 100)) if carry else ((6, 14), (-4, 10))
    return astronaut(((4, 0), (-3, -3)), arms, carry)


def sheet():
    rows = [
        [walk(i / 8.0, False) for i in range(8)],
        [walk(i / 8.0, True) for i in range(8)],
        [lope(i, False) for i in range(4)] + [lope(i, True) for i in range(4)],
        [kneel(0), kneel(1), idle(False), idle(True)],
    ]
    img = np.zeros((FH * len(rows), FW * 8, 4), dtype=np.uint8)
    for r, row in enumerate(rows):
        for i, fr in enumerate(row):
            img[r * FH:(r + 1) * FH, i * FW:(i + 1) * FW] = fr
    return img


def station():
    """A deployed science station: an insulated box on three legs, a tilted solar panel, a radio whip."""
    c = Canvas(24, 22)
    for lx in (7, 12, 17):
        c.rect(lx, 16, lx, 21, "metal", 1, flat=True)
    c.rect(6, 10, 18, 16, "foil", 10)
    c.rect(6, 13, 18, 13, "box", 11, flat=True)
    c.rect(11, 6, 12, 9, "metal", 9)
    for i in range(16):
        c.rect(3 + i, 3 + (i // 4), 3 + i, 4 + (i // 4), "cell", 12)
    c.limb((19, 9), (20, 0), 1, "metal", 13)
    c.px(20, 0, "lamp", 14, flat=True)
    c.rect(14, 11, 15, 11, "lamp", 15, flat=True)
    return c.render()


def station_box():
    c = Canvas(11, 9)
    c.rect(1, 2, 9, 8, "box", 10)
    c.rect(1, 4, 9, 4, "foil", 11, flat=True)
    c.rect(4, 1, 6, 1, "metal", 11, flat=True)
    return c.render()


def flag(part):
    c = Canvas(10, 23)
    c.limb((2, 2), (2, 22), 1, "metal", 5)
    c.rect(3, 2, 8, 6, part, 10)
    c.rect(3, 4, 8, 4, "white", 11, flat=True)
    return c.render()


def camera_icon():
    c = Canvas(12, 12)
    c.rect(1, 3, 10, 9, "dark", 5)
    c.rect(3, 2, 5, 2, "dark", 5)
    c.disc(6, 6, 2.2, "lens", 10)
    c.px(5, 5, "white", 11, flat=True)
    c.px(9, 4, "lamp", 11, flat=True)
    return c.render()


def save(img, name):
    Image.fromarray(img).save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    save(sheet(), "astronaut.png")
    save(station(), "station.png")
    save(station_box(), "station_box.png")
    save(flag("flag_o"), "flag_photo.png")
    save(flag("flag_c"), "flag_site.png")
    save(camera_icon(), "ic_camera.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
