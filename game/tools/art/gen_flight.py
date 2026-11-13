"""Flight screen art: dawn launch site, mission-control console, cruise map and arrival planets.

    python tools/art/gen_flight.py            (writes art/flight/*.png)

All numpy / PIL, 1 art pixel = 1 game pixel, lit from the upper left (the low sun sits on the
left of the launch scene). Layout numbers shared with scripts/screens/flight.gd:
horizon y 228, pad deck top y 272, rocket centre x 336, console from y 298.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import LIGHT, _sphere, _tex_lookup, dither, fbm, fbm1, hexc, planet, quant, ramp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "flight")

RX = 336          # rocket centre x
HORIZON = 228     # ocean horizon on screen with the camera on the ground
DECK = 272        # top of the pad deck front face
FAR_TOP = 208     # screen y of the far layer's first row


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    if isinstance(img, np.ndarray):
        img = Image.fromarray(img)
    img.save(os.path.join(OUT, name))


def new(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def c(h, a=255):
    return hexc(h, a)


# ------------------------------------------------------------------ sky

SKY = ["ffd9a0", "ffb884", "f58f86", "cf6c94", "9a569c", "6a469a", "46398c", "2e2f78", "1f2462", "151a4a",
       "0d1034", "080a20"]
SKY_H = [12, 18, 22, 26, 32, 40, 50, 68, 90, 110, 130, 130]


def sky(w=640, h=1080):
    """Tall dawn sky strip: the screen shows 360 rows of it, sliding up as the rocket climbs.
    Flat bands, three dither rows at each join, fading to nothing (stars behind) at the top."""
    img = np.zeros((h, w, 4), dtype=np.uint8)
    hz = h - 360 + HORIZON
    img[hz:, :] = c(SKY[0])
    xs = np.arange(w)
    y = hz
    cols = [c(s) for s in SKY] + [c(SKY[-1], 190), c(SKY[-1], 120), c(SKY[-1], 60), c(SKY[-1], 0)]
    hs = SKY_H + [60, 60, 60, 2000]
    for i, col in enumerate(cols):
        y0 = max(0, y - hs[i])
        img[y0:y, :] = col
        if i > 0 and y < h:  # join with the band below: 25 / 50 / 75 % rows
            below = np.array(cols[i - 1], dtype=np.uint8)
            for k, row in enumerate((y - 1, y - 2, y - 3)):
                if row < 0:
                    continue
                if k == 0:
                    m = (xs + row * 2) % 4 != 0
                elif k == 1:
                    m = (xs + row) % 2 == 0
                else:
                    m = (xs + row * 2) % 4 == 0
                img[row, m] = below
        y = y0
        if y <= 0:
            break
    return img


# ------------------------------------------------------------------ clouds

def cloud(w, h, seed, tones, n=9):
    """Flat-bottomed pixel cloud lit by the low sun on the left: tones = (glow, body, shade, rim)."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    base = h - 2
    m = np.zeros((h, w), bool)
    tone = np.full((h, w), 1)
    blobs = []
    for i in range(n):
        cx = rng.uniform(w * 0.14, w * 0.86)
        edge = 1.0 - abs(cx / w - 0.5) * 1.7
        rr = rng.uniform(h * 0.25, h * 0.52) * (0.45 + 0.55 * edge)
        blobs.append((base - rr * rng.uniform(0.55, 0.95), cx, rr))
    for cy, cx, rr in sorted(blobs):          # painter's order: lower puffs overlap higher ones
        dd = (xs - cx) ** 2 + (ys - cy) ** 2
        inb = dd < rr * rr
        m |= inb
        tone[inb] = 1
        tone[inb & ((xs - cx) * 0.6 + (ys - cy) > rr * 0.35)] = 2          # shaded lower right
        tone[inb & (dd > (rr - 1.3) ** 2) & ((xs - cx) + (ys - cy) * 0.4 < -rr * 0.35)] = 3   # rim toward the sun
    m &= ys < base
    core = m.copy()                           # keep the sun rim on the outer silhouette only
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        core &= np.roll(m, (dy, dx), axis=(0, 1))
    tone[(tone == 3) & core] = 1
    cols = np.where(m.any(axis=0))[0]
    slab = (ys >= base - 3) & (ys < base) & (xs > cols.min() + 2) & (xs < cols.max() - 2)
    tone[slab & ~m] = 2
    m |= slab
    height = base - ys
    tone[m & (height < 1.5) & (xs < w * 0.6 + (ys % 2) * 3)] = 0            # glowing flat base on the sun side
    img = np.zeros((h, w, 4), dtype=np.uint8)
    T = np.array([c(t) for t in tones], dtype=np.uint8)
    img[m] = T[tone[m]]
    return img


def clouds():
    near = ("ffd2a0", "b684a8", "8a68a0", "f2a8a8")
    far = ("ffc49a", "d78c9c", "b6789e", "f6b0a0")
    for i, (w, h) in enumerate(((118, 34), (86, 26), (150, 40))):
        save(cloud(w, h, 40 + i, near, 11), "cloud_near_%d.png" % i)
    for i, (w, h) in enumerate(((54, 12), (38, 9), (72, 14))):
        save(cloud(w, h, 60 + i, far, 7), "cloud_far_%d.png" % i)


# ------------------------------------------------------------------ launch site

def lattice(d, x, y0, y1, w, dark, mid, lit, step=8):
    """Vertical truss from y0 (top) to y1 (bottom): two legs, cross braces, a lit left edge."""
    d.line([(x, y0), (x, y1)], fill=lit)
    d.line([(x + w - 1, y0), (x + w - 1, y1)], fill=dark)
    k = 0
    for y in range(y1, y0, -step):
        a, b = (x, x + w - 1) if k % 2 == 0 else (x + w - 1, x)
        d.line([(a, y), (b, max(y0, y - step))], fill=mid)
        d.line([(x, y), (x + w - 1, y)], fill=mid)
        k += 1


def far_layer(w=640, h=156):
    """Ocean horizon, far hills, the assembly building and the coastal plain seen as the camera rises."""
    im, d = new(w, h)
    hz = HORIZON - FAR_TOP
    # far hills, two ranges, hazy and tinted to the sky
    for seed, amp, col, x0, x1 in ((3, 13, "c98a96", 170, 440), (5, 8, "a66c90", 230, 400), (8, 8, "b87a94", 520, 640),
                                   (6, 9, "b87a94", -30, 44)):
        prof = fbm1(w, [90, 40, 18], seed)
        for x in range(max(0, x0), x1):
            fade = min(1.0, (x1 - x) / 60.0, (x - x0) / 60.0)
            t = int(prof[x] * amp * fade)
            if t > 0:
                d.line([(x, hz - t), (x, hz)], fill=c(col))
    # ocean rows, brightest at the horizon
    rows = ["ffe6b4", "ffc692", "f3a08c", "f3a08c", "cd7f98", "cd7f98", "cd7f98", "9a659e", "9a659e", "9a659e",
            "9a659e", "6d5298", "6d5298", "6d5298", "6d5298", "4d4688", "4d4688", "4d4688"]
    rng = np.random.default_rng(11)
    for i, col in enumerate(rows):
        d.line([(0, hz + i), (w, hz + i)], fill=c(col))
    for i in range(1, len(rows)):
        if rows[i] == rows[i - 1]:
            for _ in range(int(26 - i)):
                x = int(rng.integers(0, w))
                ln = int(rng.integers(3, 9 + i))
                d.line([(x, hz + i), (x + ln, hz + i)], fill=c(rows[max(0, i - 3)]))
    # sun glitter path under the low sun (sun x = 104)
    for i in range(1, len(rows)):
        for _ in range(3):
            x = 104 + int(rng.normal(0, 2 + i * 1.3))
            ln = int(rng.integers(2, 5 + i // 3))
            d.line([(x, hz + i), (x + ln, hz + i)], fill=c("fff2c8" if i < 9 else "ffcf9a"))
    # land spit on the right with the assembly building, control centre and tank farm
    d.polygon([(470, hz + 18), (500, hz + 3), (540, hz - 1), (640, hz - 2), (640, hz + 18)], fill=c("5e5484"))
    d.rectangle([548, hz - 19, 569, hz - 2], fill=c("7a5f90"))
    d.rectangle([548, hz - 19, 553, hz - 2], fill=c("e2a79a"))
    d.line([(548, hz - 19), (569, hz - 19)], fill=c("f0c0a4"))
    d.rectangle([560, hz - 14, 562, hz - 3], fill=c("4c4276"))      # the tall door
    d.rectangle([570, hz - 8, 584, hz - 2], fill=c("6a5488"))
    d.line([(570, hz - 8), (584, hz - 8)], fill=c("d79a98"))
    for x in (596, 606, 616):
        d.ellipse([x, hz - 9, x + 6, hz - 3], fill=c("7a5f90"))
        d.point([(x + 1, hz - 8), (x + 2, hz - 8), (x + 1, hz - 7)], fill=c("f0c0a4"))
    d.line([(626, hz - 16), (626, hz - 2)], fill=c("6a5488"))        # far mast
    # shore: surf line and sand
    y = hz + len(rows)
    shore = [(0, y), (470, y)]
    d.line(shore, fill=c("f6dcd8"))
    for x in range(0, 470, 7):
        d.point((x + int(rng.integers(0, 5)), y - 1), fill=c("f6dcd8"))
    d.line([(0, y + 1), (476, y + 1)], fill=c("c79d86"))
    d.line([(0, y + 2), (640, y + 2)], fill=c("a4807a"))
    # coastal plain in flat bands, darker and greener toward the viewer
    y += 3
    bands = [("56587a", 6), ("48566e", 9), ("3c5464", 14), ("32525a", 22), ("2a4c50", 34), ("244444", 60)]
    for col, bh in bands:
        d.rectangle([0, y, w, y + bh], fill=c(col))
        y += bh
    # dither-free band joins: a few tufts of the lower band's colour poking up
    y = hz + len(rows) + 3
    for i, (col, bh) in enumerate(bands[:-1]):
        y += bh
        nxt = c(bands[i + 1][0])
        for _ in range(60):
            x = int(rng.integers(0, w))
            d.line([(x, y - 1), (x + int(rng.integers(2, 9)), y - 1)], fill=nxt)
    # lagoons that mirror the sky
    for cx, cy, rw, rh in ((150, 50, 46, 3), (60, 66, 36, 4), (250, 76, 60, 5), (560, 60, 40, 3), (420, 104, 80, 7),
                           (90, 118, 70, 8)):
        d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=c("8d629c"))
        d.line([(cx - rw + 4, cy - rh), (cx + rw - 4, cy - rh)], fill=c("e9a093"))
        d.line([(cx - rw + 6, cy + rh), (cx + rw - 6, cy + rh)], fill=c("3c3a6c"))
    # crawler-way: twin gravel tracks from the assembly building toward the pad
    for off, col in ((0, "b79a92"), (1, "8f7c84")):
        pts = [(556 + off * 2, hz - 1), (540, hz + 22), (500, hz + 30), (474 - off * 5, 54 + off)]
        d.line(pts, fill=c(col))
    # tree clumps, bigger toward the viewer, rim-lit on the sun side
    for _ in range(90):
        ty = int(rng.integers(hz + 24, h))
        k = (ty - hz - 24) / float(h - hz - 24)
        tw, th = int(3 + k * 13), int(2 + k * 6)
        tx = int(rng.integers(-6, w))
        d.ellipse([tx, ty - th, tx + tw, ty], fill=c("1c343c" if k > 0.3 else "2c4250"))
        d.line([(tx + 1, ty - th + 1), (tx + max(1, tw // 3), ty - th)], fill=c("c98f6c" if k > 0.3 else "9c7a80"))
    return im


def near_layer(w=640, h=360):
    """Ground the pad stands on and everything behind the rocket: apron, deck top, back masts,
    water tower, floodlight towers, tanks. Screen-aligned (drawn at y = camera offset)."""
    im, d = new(w, h)
    rng = np.random.default_rng(21)
    top = 258 + (fbm1(w, [60, 24, 9], 4) * 5).astype(int)
    px = im.load()
    bands = [(0, "2a4a48"), (9, "234240"), (20, "1c3838"), (34, "162e30")]
    for x in range(w):
        for y in range(int(top[x]), h):
            dy = y - 258
            col = bands[0][1]
            for b0, bc in bands:
                if dy >= b0 + ((x * 7 + y * 3) % 3):
                    col = bc
            px[x, y] = c(col)
        px[x, int(top[x])] = c("c58e6c") if (x * 13) % 7 < 2 else c("3a5c54")
    for _ in range(260):  # grass blades and warm specks
        x, y = int(rng.integers(0, w)), int(rng.integers(264, 300))
        d.line([(x, y), (x, y - 1 - int(rng.integers(0, 2)))], fill=c("3a5c54" if rng.random() < 0.7 else "0f2226"))
    # concrete apron (hardstand) around the pad
    d.polygon([(RX - 150, 268), (RX + 150, 268), (RX + 205, 300), (RX - 205, 300)], fill=c("5a5878"))
    d.polygon([(RX - 150, 268), (RX + 150, 268), (RX + 154, 270), (RX - 154, 270)], fill=c("9388a0"))
    for i in range(-5, 6):  # slab joints, fanned for perspective
        d.line([(RX + i * 28, 270), (RX + i * 38, 300)], fill=c("4a4868"))
    d.line([(RX - 180, 285), (RX + 180, 285)], fill=c("4a4868"))
    # crawler-way running off toward the assembly building
    d.polygon([(RX + 150, 268), (474, 260), (482, 260), (RX + 172, 272)], fill=c("a48c88"))
    d.line([(RX + 152, 269), (478, 261)], fill=c("6e6078"))
    # low back buildings, tanks and pipes
    d.rectangle([70, 255, 100, 263], fill=c("5f5680"))
    d.line([(70, 255), (100, 255)], fill=c("dba294"))
    d.rectangle([70, 255, 72, 263], fill=c("b88a94"))
    for x in (78, 86, 94):
        d.point((x, 259), fill=c("ffe2a0"))
    d.ellipse([196, 248, 214, 266], fill=c("8f86a8"))                 # LOX sphere
    d.pieslice([196, 248, 214, 266], 140, 260, fill=c("e8c4b4"))
    d.ellipse([200, 252, 206, 257], fill=c("fff0dc"))
    d.line([(199, 266), (197, 270)], fill=c("3c3858"))
    d.line([(211, 266), (213, 270)], fill=c("3c3858"))
    d.line([(214, 262), (RX - 100, 262), (RX - 100, 268)], fill=c("8f86a8"))
    d.rounded_rectangle([430, 252, 466, 262], 5, fill=c("9a90ae"))    # fuel tank lying down
    d.line([(434, 253), (462, 253)], fill=c("f0d0c0"))
    d.line([(434, 261), (462, 261)], fill=c("5a5278"))
    d.line([(438, 262), (438, 266)], fill=c("3c3858"))
    d.line([(458, 262), (458, 266)], fill=c("3c3858"))
    d.line([(430, 258), (RX + 100, 258), (RX + 100, 268)], fill=c("7c7498"))
    # water tower (sound suppression), far right, hazy
    for lx in (498, 510, 522):
        d.line([(lx, 176), (lx, 262)], fill=c("6f6690"))
    for y in range(184, 262, 16):
        d.line([(498, y), (522, y + 8)], fill=c("7f759c"))
        d.line([(522, y), (498, y + 8)], fill=c("5f587f"))
    d.ellipse([490, 146, 530, 180], fill=c("8c80a6"))
    d.pieslice([490, 146, 530, 180], 120, 250, fill=c("e3b6ac"))
    d.chord([490, 146, 530, 180], 20, 110, fill=c("655c88"))
    d.ellipse([498, 152, 508, 160], fill=c("ffe6cc"))
    d.rectangle([507, 141, 513, 147], fill=c("8c80a6"))
    d.line([(510, 132), (510, 141)], fill=c("b8a8c0"))
    # floodlight towers
    for x, ty, flip in ((150, 172, 1), (236, 200, 1), (588, 184, -1)):
        lattice(d, x, ty, 266, 5, c("3a3658"), c("5a5480"), c("d9a590"), 9)
        bx = x + 3 if flip > 0 else x - 10
        d.rectangle([bx, ty - 8, bx + 12, ty], fill=c("2c2a48"))
        for i in range(3):
            for j in range(2):
                d.rectangle([bx + 1 + i * 4, ty - 7 + j * 4, bx + 3 + i * 4, ty - 5 + j * 4], fill=c("fff4c8"))
    # back pair of lightning masts and the catenary wire between all four
    for x in (RX - 86, RX + 62):
        lattice(d, x, 62, 266, 3, c("5a5482"), c("7a709c"), c("c9a2a6"), 7)
        d.line([(x + 1, 44), (x + 1, 62)], fill=c("d8cfe0"))
    for (x0, y0), (x1, y1) in (((RX - 85, 45), (RX + 63, 45)), ((RX - 116, 31), (RX - 85, 45)), ((RX + 116, 31), (RX + 63, 45))):
        n = int(abs(x1 - x0))
        for i in range(n + 1):
            t = i / float(n)
            d.point((round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t + n * 0.22 * t * (1 - t))), fill=c("6a629a"))
    # deck top face with the flame hole
    d.polygon([(RX - 96, 265), (RX + 96, 265), (RX + 104, 272), (RX - 104, 272)], fill=c("b6a7b2"))
    d.line([(RX - 96, 265), (RX + 96, 265)], fill=c("e9cdb8"))
    d.ellipse([RX - 30, 266, RX + 30, 271], fill=c("1a1626"))
    d.ellipse([RX - 24, 267, RX + 24, 270], fill=c("0c0a14"))
    for x in range(RX - 92, RX + 96, 12):  # deck rail
        if abs(x - RX) > 36:
            d.line([(x, 260), (x, 265)], fill=c("4a4668"))
    d.line([(RX - 92, 260), (RX - 38, 260)], fill=c("7c749c"))
    d.line([(RX + 38, 260), (RX + 92, 260)], fill=c("7c749c"))
    return im


def front_layer(w=640, h=360):
    """In front of the rocket: deck face with hazard edge and trench mouth, front lightning masts,
    foreground fence, a tanker and bushes."""
    im, d = new(w, h)
    rng = np.random.default_rng(33)
    # deck front face with ramps
    d.polygon([(RX - 104, DECK), (RX + 104, DECK), (RX + 122, 287), (RX - 122, 287)], fill=c("6c6688"))
    d.polygon([(RX - 104, 280), (RX + 104, 280), (RX + 122, 287), (RX - 122, 287)], fill=c("544f74"))
    d.line([(RX - 104, DECK), (RX - 122, 287)], fill=c("b89a9c"))
    for x in range(RX - 104, RX + 104):  # hazard edge
        k = ((x - RX) // 4) % 2
        d.line([(x, DECK), (x, DECK + 2)], fill=c("f2c230") if k == 0 else c("1a1626"))
    d.line([(RX - 104, DECK + 3), (RX + 104, DECK + 3)], fill=c("3e3a5c"))
    for x in range(RX - 96, RX + 100, 24):  # panel seams
        if abs(x - RX) > 34:
            d.line([(x, DECK + 4), (x - (1 if x < RX else -1), 286)], fill=c("544f74"))
    # flame trench mouth
    d.rounded_rectangle([RX - 30, DECK + 4, RX + 30, 290], 5, fill=c("38345a"))
    d.rounded_rectangle([RX - 27, DECK + 6, RX + 27, 292], 4, fill=c("120e1c"))
    d.rectangle([RX - 30, 287, RX + 30, 292], fill=c("120e1c"))
    d.line([(RX - 26, DECK + 6), (RX - 20, DECK + 6)], fill=c("8a7c98"))
    # front lightning masts
    for x in (RX - 118, RX + 114):
        d.rectangle([x - 2, 283, x + 6, 287], fill=c("3e3a5c"))
        lattice(d, x, 52, 284, 5, c("26243e"), c("4a4670"), c("dba58c"), 9)
        d.line([(x + 2, 30), (x + 2, 52)], fill=c("efe6ee"))
        d.line([(x + 1, 46), (x + 3, 46)], fill=c("d03a30"))
    # ground in front: darker, more saturated (near = high contrast)
    prof = 286 + (fbm1(w, [50, 20, 8], 9) * 4).astype(int)
    for x in range(w):
        if abs(x - RX) < 122 + 4:
            continue
        d.line([(x, int(prof[x])), (x, h)], fill=c("0f2226"))
    d.rectangle([0, 292, w, h], fill=c("0f2226"))
    d.rectangle([RX - 30, 287, RX + 30, 292], fill=c("120e1c"))
    for _ in range(220):
        x, y = int(rng.integers(0, w)), int(rng.integers(288, 300))
        d.line([(x, y), (x + int(rng.integers(-1, 2)), y - 2 - int(rng.integers(0, 3)))],
               fill=c("1f3c3a" if rng.random() < 0.75 else "c58e6c"))
    # perimeter fence
    for x in range(4, w, 26):
        if abs(x - RX) < 44:
            continue
        d.line([(x, 284), (x, 296)], fill=c("0a1218"))
        d.point((x, 284), fill=c("c58e6c"))
    for y in (287, 291):
        d.line([(0, y), (RX - 126, y)], fill=c("0a1218"))
        d.line([(RX + 126, y), (w, y)], fill=c("0a1218"))
    # tanker truck parked on the apron
    d.rounded_rectangle([174, 277, 198, 285], 3, fill=c("c9c2d6"))
    d.line([(177, 278), (195, 278)], fill=c("ffffff"))
    d.line([(176, 285), (196, 285)], fill=c("6e688c"))
    d.rectangle([199, 279, 206, 286], fill=c("d03a30"))
    d.rectangle([202, 280, 205, 282], fill=c("8fe3f5"))
    for x in (178, 192, 203):
        d.rectangle([x, 286, x + 2, 288], fill=c("0c0a14"))
    # palmetto bushes in the corners
    for bx, by, r in ((18, 298, 15), (52, 300, 10), (600, 298, 16), (632, 300, 11), (470, 300, 8)):
        for a in range(-80, 81, 16):
            ex = bx + math.sin(math.radians(a)) * r
            ey = by - math.cos(math.radians(a)) * r
            d.line([(bx, by), (ex, ey)], fill=c("0a1a1c"), width=2)
            d.line([(bx, by - 2), (ex - 1, ey)], fill=c("1f3c3a") if a > -20 else c("b8825e"))
    return im


def tower(w=26, h=240):
    """Fixed service structure, cropped from the bottom to the rocket's height by the game."""
    im, d = new(w, h)
    d.rectangle([8, 0, 17, h], fill=c("2c2a44"))             # lift shaft
    d.line([(8, 0), (8, h)], fill=c("57527a"))
    for y in range(6, h, 12):
        d.rectangle([11, y, 14, y + 3], fill=c("ffe2a0") if (y // 12) % 3 == 0 else c("3e3a5c"))
    lattice(d, 1, 0, h - 1, 5, c("2e2c48"), c("575278"), c("e0aa90"), 12)
    lattice(d, 20, 0, h - 1, 5, c("24223a"), c("48446a"), c("8f86a8"), 12)
    for y in range(h - 1, 0, -24):                            # work platforms
        d.line([(0, y), (w - 1, y)], fill=c("8f86a8"))
        d.line([(0, y + 1), (w - 1, y + 1)], fill=c("24223a"))
        d.line([(0, y - 4), (w - 1, y - 4)], fill=c("57527a"))
        for x in (0, 6, 19, w - 1):
            d.line([(x, y - 4), (x, y)], fill=c("57527a"))
    for y in range(h - 60, 0, -96):                           # red / white bands
        d.rectangle([1, y, 5, y + 11], fill=c("d03a30"))
        d.rectangle([20, y, 24, y + 11], fill=c("8c1e22"))
    return im


def tower_cap():
    im, d = new(34, 22)
    d.rectangle([4, 16, 29, 21], fill=c("48446a"))
    d.line([(4, 16), (29, 16)], fill=c("e0aa90"))
    d.line([(4, 21), (29, 21)], fill=c("24223a"))
    d.line([(12, 15), (33, 9)], fill=c("8f86a8"))             # hammerhead crane jib
    d.line([(12, 16), (33, 10)], fill=c("48446a"))
    d.line([(33, 10), (33, 15)], fill=c("57527a"))
    d.line([(16, 0), (16, 15)], fill=c("d8cfe0"))             # lightning rod
    d.rectangle([14, 10, 18, 15], fill=c("57527a"))
    return im


def arms():
    """Umbilical arm, tower end on the left: three frames (out, swinging, stowed), 24x7 each."""
    im, d = new(24, 21)
    for f, ln in enumerate((24, 14, 6)):
        y = f * 7
        d.line([(0, y + 1), (ln - 1, y + 1)], fill=c("e0aa90"))
        d.line([(0, y + 5), (ln - 1, y + 5)], fill=c("3e3a5c"))
        for x in range(0, ln - 2, 4):
            d.line([(x, y + 5), (x + 3, y + 1)], fill=c("6e688c"))
        d.rectangle([ln - 4, y, ln - 1, y + 6], fill=c("c9c2d6"))
        d.line([(ln - 4, y), (ln - 1, y)], fill=c("ffffff"))
        d.line([(ln - 4, y + 6), (ln - 1, y + 6)], fill=c("6e688c"))
    return im


def clamps():
    """Hold-down post, rocket on its right: closed and released frames, 9x13 each."""
    im, d = new(18, 13)
    for f in (0, 1):
        x = f * 9
        d.rectangle([x + 2, 4, x + 5, 12], fill=c("6e688c"))
        d.line([(x + 2, 4), (x + 2, 12)], fill=c("e0aa90"))
        d.line([(x + 5, 4), (x + 5, 12)], fill=c("3e3a5c"))
        d.rectangle([x + 1, 11, x + 7, 12], fill=c("3e3a5c"))
        if f == 0:
            d.rectangle([x + 4, 1, x + 8, 4], fill=c("f2c230"))
            d.line([(x + 4, 4), (x + 8, 4)], fill=c("8a6a18"))
        else:
            d.rectangle([x + 0, 0, x + 3, 4], fill=c("f2c230"))
            d.line([(x + 0, 4), (x + 3, 4)], fill=c("8a6a18"))
    return im


def birds():
    im, d = new(14, 5)
    col = c("241c38")
    d.line([(0, 0), (2, 2), (3, 3), (4, 2), (6, 0)], fill=col)     # wings up
    d.line([(7, 3), (9, 2), (10, 2), (11, 2), (13, 3)], fill=col)  # wings down
    d.point((10, 1), fill=col)
    return im


def limb(w=640, h=120):
    """Curved Earth horizon seen from the edge of space: night ocean, dawn clouds, air glow."""
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    R = 2700.0
    dist = np.sqrt((xs - 320) ** 2 + (ys - (16 + R)) ** 2)
    depth = R - dist                      # > 0 inside the planet
    surf = depth >= 0
    sun = np.clip(1.0 - xs / 520.0, 0, 1)             # dawn light comes from the left
    n = fbm(w, h, [80, 30, 12, 5], 51, False, False)
    cl = fbm(w, h, [120, 40, 14, 6], 52, False, False)
    persp = np.clip(depth / 130.0, 0.05, 1)
    cl = fbm(w, int(h * 3), [120, 40, 14, 6], 52, False, False)[np.clip((persp * h * 2.5).astype(int), 0, h * 3 - 1), xs.astype(int)]
    O = ramp("070a22", "0b1238", "10204e", "183468", "24508c")
    v = np.clip(0.15 + sun * 0.75 - depth / 400.0 + (n - 0.5) * 0.25, 0, 0.99)
    img[surf] = O[(v[surf] * len(O)).astype(int)]
    C = ramp("3a3a6a", "7a5e94", "d48a98", "ffd0a8")
    cm = surf & (cl > 0.56)
    cv = np.clip((cl - 0.56) * 5 + sun * 0.7 - 0.2, 0, 0.99)
    img[cm] = C[(cv[cm] * len(C)).astype(int)]
    # air glow bands above the surface
    for d0, d1, col, a in ((0, 1.5, "bfe9ff", 255), (1.5, 4, "6fb6f2", 255), (4, 7, "3f7fd6", 230), (7, 11, "2a55a8", 170),
                           (11, 15, "1c3478", 100)):
        m = (depth < -d0) & (depth >= -d1)
        img[m] = c(col, a)
    warm = (depth < 0) & (depth >= -4) & (xs < 230)
    img[warm, 0] = 255
    img[warm, 1] = np.clip(img[warm, 1].astype(int) + 10, 0, 255)
    img[warm & (depth >= -1.5)] = c("fff0c8")
    return img


# ------------------------------------------------------------------ console and HUD pieces

def console(w=640, h=62):
    """Mission-control console: bevelled body, lamp sockets, gauge slots, inset ticker screen."""
    im, d = new(w, h)
    d.rectangle([0, 0, w, h], fill=c("141a2e"))
    d.line([(0, 0), (w, 0)], fill=c("05070d"))
    d.line([(0, 1), (w, 1)], fill=c("5a6ea8"))
    d.line([(0, 2), (w, 2)], fill=c("2a3560"))
    d.rectangle([0, h - 3, w, h], fill=c("0b0e1a"))
    for x in range(0, w, 2):                                   # brushed rows
        d.point((x, 3), fill=c("1d2540"))
    # left plate
    d.rectangle([4, 5, 180, 57], fill=c("1d2540"))
    d.line([(4, 5), (180, 5)], fill=c("3a4a7a"))
    d.line([(4, 5), (4, 57)], fill=c("3a4a7a"))
    d.line([(4, 57), (180, 57)], fill=c("0b0e1a"))
    d.line([(180, 5), (180, 57)], fill=c("0b0e1a"))
    for sx, sy in ((6, 7), (178, 7), (6, 55), (178, 55)):      # screws
        d.point((sx, sy), fill=c("8a94b8"))
        d.point((sx, sy + 1), fill=c("05070d"))
    for i in range(5):                                         # lamp sockets
        cx = 24 + i * 35
        d.ellipse([cx - 6, 8, cx + 6, 20], fill=c("05070d"))
        d.arc([cx - 6, 8, cx + 6, 20], 200, 340, fill=c("3a4a7a"))
    for gy in (36, 47):                                        # gauge slots
        d.rectangle([33, gy, 113, gy + 8], fill=c("05070d"))
        d.line([(33, gy + 8), (113, gy + 8)], fill=c("3a4a7a"))
        d.line([(113, gy), (113, gy + 8)], fill=c("3a4a7a"))
    # ticker screen
    d.rectangle([186, 5, 635, 57], fill=c("05070d"))
    d.rectangle([188, 7, 633, 55], fill=c("070c18"))
    for y in range(8, 55, 2):
        d.line([(188, y), (633, y)], fill=c("0a1122"))
    d.line([(186, 57), (635, 57)], fill=c("3a4a7a"))
    d.line([(635, 5), (635, 57)], fill=c("3a4a7a"))
    d.point([(188, 7), (633, 7), (188, 55), (633, 55)], fill=c("05070d"))
    return im


def lamps():
    """Status lamps 11x11: off, green, yellow, red, cyan."""
    im, d = new(55, 11)
    sets = [("1a2036", "2a3252", "3a4a7a"), ("1f7a3a", "6dff8a", "e4ffe8"), ("8a6a18", "ffd75e", "fff6d0"),
            ("7a1e22", "ff5a5a", "ffd6d0"), ("1d5a80", "4fd6ff", "e0f8ff")]
    for i, (dark, mid, hi) in enumerate(sets):
        x = i * 11
        d.ellipse([x + 1, 1, x + 9, 9], fill=c(dark))
        d.ellipse([x + 2, 2, x + 8, 8], fill=c(mid))
        d.rectangle([x + 3, 3, x + 4, 4], fill=c(hi))
        d.arc([x + 1, 1, x + 9, 9], 20, 120, fill=c(dark))
    return im


def keycap():
    im, d = new(40, 13)
    d.rounded_rectangle([0, 0, 39, 12], 2, fill=c("05070d"))
    d.rounded_rectangle([1, 1, 38, 9], 2, fill=c("e8ecff"))
    d.line([(2, 10), (37, 10)], fill=c("8a94b8"))
    d.line([(2, 11), (37, 11)], fill=c("3a4a7a"))
    d.line([(3, 1), (36, 1)], fill=c("ffffff"))
    return im


# ------------------------------------------------------------------ cruise map

def space_far(w=640, h=360, seed=5):
    """Deep-space backdrop for the cruise map: a faint Milky Way band, dust lanes, two constellations."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    u = (xs * 0.42 + (ys - 150) * 1.0) / 110.0 - 1.15      # distance across a diagonal band
    band = np.exp(-(u * u) * 2.2)
    n = fbm(w, h, [140, 60, 26, 11, 5], seed, False, False)
    lane = fbm(w, h, [90, 30, 12], seed + 2, False, False)
    v = band * (0.35 + 0.9 * n) - np.clip(lane - 0.55, 0, 1) * 1.6 * band
    v = np.clip(v, 0, 1)
    V = ramp("05060e", "080a18", "0c0f24", "121430", "1a183a", "241d44", "30244a")
    img = V[quant(v * 0.9, len(V), dither(h, w), 0.8)]
    rng = np.random.default_rng(seed + 9)
    for _ in range(1500):
        sx, sy = int(rng.integers(0, w)), int(rng.integers(0, h))
        if rng.random() > 0.12 + band[sy, sx] * 0.9:
            continue
        b = rng.random() ** 2.5
        cc = int(60 + 150 * b)
        tint = [(1, 1, 1), (0.8, 0.9, 1.0), (1.0, 0.88, 0.75)][int(rng.integers(0, 3))]
        img[sy, sx, :3] = [int(cc * t) for t in tint]
    def star(x, y, big):
        img[y, x, :3] = (255, 255, 255)
        if big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx, :3] = (140, 160, 215)
    def line(a, b):
        n_ = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])))
        for i in range(3, n_ - 2):
            if i % 3 == 0:
                x = round(a[0] + (b[0] - a[0]) * i / n_)
                y = round(a[1] + (b[1] - a[1]) * i / n_)
                img[y, x, :3] = (40, 52, 96)
    orion = [(52, 196), (84, 190), (62, 224), (69, 228), (76, 232), (48, 262), (88, 268)]
    for a, b in ((0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6), (0, 1), (5, 6)):
        line(orion[a], orion[b])
    for i, p in enumerate(orion):
        star(p[0], p[1], i in (0, 1, 5, 6))
    dipper = [(470, 250), (494, 256), (514, 266), (536, 270), (544, 290), (574, 292), (578, 270)]
    for a in range(6):
        line(dipper[a], dipper[a + 1])
    line(dipper[6], dipper[3])
    for i, p in enumerate(dipper):
        star(p[0], p[1], i in (0, 3, 6))
    for _ in range(10):
        star(int(rng.integers(4, w - 4)), int(rng.integers(4, h - 4)), True)
    img[..., 3] = 255
    return img


SHIP_PARTS = [  # (polygon in ship space, x forward; ramp dark, mid, lit)
    ([(-2, -10), (2, -10), (2, -3), (-2, -3)], ("101a3c", "2b4796", "4f74c8")),
    ([(-2, 3), (2, 3), (2, 10), (-2, 10)], ("101a3c", "2b4796", "4f74c8")),
    ([(-8, -2), (-4, -1.5), (-4, 1.5), (-8, 2)], ("2a2e3a", "4e5566", "7d8697")),
    ([(-4, -3), (3, -3), (3, 3), (-4, 3)], ("7c5418", "dcae44", "f6dc84")),
    ([(3, -2), (5, -2), (7, -5), (8, -5), (8, 5), (7, 5), (5, 2), (3, 2)], ("6a7290", "d6dcea", "ffffff")),
]


def ship8(cell=23):
    """The player's ship on the map, turned to 8 headings (frame 0 = flying right, then counter-clockwise)."""
    S = 6
    out = np.zeros((cell, cell * 8, 4), dtype=np.uint8)
    for k in range(8):
        a = -k * math.pi / 4
        ids = np.zeros((cell, cell), dtype=int)
        for pi, (poly, _) in enumerate(SHIP_PARTS):
            im = Image.new("L", (cell * S, cell * S), 0)
            pts = []
            for x, y in poly:
                rx = x * math.cos(a) - y * math.sin(a)
                ry = x * math.sin(a) + y * math.cos(a)
                pts.append(((rx + cell / 2) * S, (ry + cell / 2) * S))
            ImageDraw.Draw(im).polygon(pts, fill=255)
            cov = np.asarray(im).reshape(cell, S, cell, S).mean(axis=(1, 3)) / 255.0
            ids[cov > 0.45] = pi + 1
        fr = np.zeros((cell, cell, 4), dtype=np.uint8)
        for y in range(cell):
            for x in range(cell):
                p = ids[y, x]
                if p == 0:
                    continue
                dark, mid, lit = SHIP_PARTS[p - 1][1]
                up = ids[y - 1, x] != p or ids[y, x - 1] != p
                dn = ids[min(cell - 1, y + 1), x] != p or ids[y, min(cell - 1, x + 1)] != p
                fr[y, x] = c(lit if up and not dn else (dark if dn and not up else mid))
        solid = ids > 0
        edge = np.zeros_like(solid)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            edge |= np.roll(solid, (dy, dx), axis=(0, 1))
        fr[edge & ~solid] = c("0c0a14")
        out[:, k * cell:(k + 1) * cell] = fr
    return out


def small_planets():
    for kind, r in (("earth", 5), ("mars", 4), ("moon", 4)):
        save(planet(kind, r), "p_%s.png" % kind)
    for name, r, cols, bands in (("venus", 4, ("5a4020", "a8823c", "e2c878", "fbf0c0"), 0.0),
                                 ("jupiter", 9, ("4a2c1c", "8a5a34", "c89a64", "ecd4a4", "fbf0d8"), 1.0)):
        W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, pad=1)
        R = ramp(*cols)
        v = lam ** 0.8 * (0.8 + 0.28 * bands * np.sin(lat * 9.0))
        img = np.zeros((H, W, 4), dtype=np.uint8)
        img[...] = R[np.clip((v * len(R)).astype(int), 0, len(R) - 1)]
        if name == "jupiter":
            img[H // 2 + 3, W // 2 + 2:W // 2 + 5] = c("c2522c")
        img[~inside] = 0
        save(img, "p_%s.png" % name)


def waves():
    """Radio wave arcs travelling right: three sizes, 12x44 cells."""
    out = np.zeros((44, 36, 4), dtype=np.uint8)
    for i, R in enumerate((9, 15, 21)):
        ys, xs = np.mgrid[0:44, 0:12].astype(np.float64)
        dd = np.sqrt((xs - (10 - R)) ** 2 + (ys - 21.5) ** 2)
        ang = np.abs(np.arctan2(ys - 21.5, xs - (10 - R)))
        m = (np.abs(dd - R) < 1.0) & (ang < 0.95)
        cell = np.zeros((44, 12, 4), dtype=np.uint8)
        cell[m] = c("4fd6ff")
        cell[m & (ang < 0.5)] = c("e0f8ff")
        out[:, i * 12:(i + 1) * 12] = cell
    return out


def capsule():
    """Sample-return capsule, heat shield leading (flying right)."""
    im, d = new(17, 13)
    d.polygon([(1, 5), (1, 7), (11, 12), (11, 0)], fill=c("d6dcea"))
    d.line([(2, 5), (10, 1)], fill=c("ffffff"))
    d.line([(2, 8), (10, 11)], fill=c("6a7290"))
    d.rectangle([11, 0, 13, 12], fill=c("4a2e10"))
    d.line([(14, 2), (14, 10)], fill=c("7c5418"))
    d.rectangle([5, 5, 7, 7], fill=c("39a0c8"))
    d.point((5, 5), fill=c("8fe3f5"))
    d.line([(0, 5), (0, 7)], fill=c("0c0a14"))
    return im


# ------------------------------------------------------------------ arrival planets

def big_planet(kind, r=100, seed=4):
    """Hero planet with a clear terminator, higher-resolution surface and (Earth, Mars) an air rim."""
    pad = 5
    W, H, x, y, d2, inside, lam, lon, lat = _sphere(r, pad=pad)
    d = dither(H, W)
    tw, th = 640, 320
    img = np.zeros((H, W, 4), dtype=np.uint8)
    lit = np.clip((lam - 0.06) * 1.25, 0, 1) ** 0.8
    lon = lon + math.pi          # look at the middle of each texture: no wrap seam on the disc
    if kind == "moon":
        base = fbm(tw, th, [80, 40, 20, 10, 5], seed)
        maria = fbm(tw, th, [160, 80, 40, 20], seed + 1)
        crat = np.zeros((th, tw))
        rng = np.random.default_rng(seed + 2)
        yy, xx = np.mgrid[0:th, 0:tw]
        for i in range(150):
            cx, cy = rng.integers(0, tw), rng.integers(20, th - 20)
            cr = rng.integers(8, 20) if i < 14 else rng.integers(2, 8)
            dx = np.minimum(np.abs(xx - cx), tw - np.abs(xx - cx))
            dd = np.sqrt(dx ** 2 + (yy - cy) ** 2) / cr
            lightside = ((xx - cx) + (yy - cy)) < 0
            crat = np.where(dd < 0.8, np.where(lightside, -0.26, -0.1), crat)
            crat = np.where((dd >= 0.8) & (dd < 1.12), np.where(lightside, -0.05, 0.22), crat)
        alb = 0.66 + 0.3 * (_tex_lookup(base, lon, lat) - 0.5) + _tex_lookup(crat, lon, lat)
        alb -= 0.2 * (_tex_lookup(maria, lon, lat) > 0.55)
        R = ramp("0e0e18", "1e1e2a", "34344a", "55556a", "7c7c92", "a6a6b8", "d2d2de")
        img[...] = R[quant(lit * np.clip(alb, 0, 1.25), len(R), d, 0.55)]
    elif kind == "mars":
        base = fbm(tw, th, [80, 40, 20, 10, 5], seed)
        dark = fbm(tw, th, [160, 80, 40, 20, 10], seed + 5)
        canyon = np.abs(fbm(tw, th, [160, 40, 20], seed + 7) - 0.5) < 0.014
        crat = np.zeros((th, tw))
        rng = np.random.default_rng(seed + 3)
        yy, xx = np.mgrid[0:th, 0:tw]
        for i in range(60):
            cx, cy = rng.integers(0, tw), rng.integers(20, th - 20)
            cr = rng.integers(6, 13) if i < 8 else rng.integers(2, 6)
            dd = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / cr
            lightside = ((xx - cx) + (yy - cy)) < 0
            crat = np.where(dd < 0.8, np.where(lightside, -0.2, -0.06), crat)
            crat = np.where((dd >= 0.8) & (dd < 1.15), np.where(lightside, -0.03, 0.14), crat)
        dk = _tex_lookup(dark, lon, lat)
        alb = 0.72 + 0.5 * (_tex_lookup(base, lon, lat) - 0.5) - 0.2 * (dk > 0.54) - 0.14 * (dk > 0.6)
        alb += _tex_lookup(crat, lon, lat)
        alb -= 0.22 * _tex_lookup(canyon.astype(float), lon, lat) * (np.abs(lat) < 0.45)
        R = ramp("140606", "30100c", "561c12", "7e2e18", "a84a24", "cc6e3a", "e69a62", "f6c692")
        img[...] = R[quant(lit * np.clip(alb, 0, 1.1), len(R), d, 0.55)]
        cap = np.abs(lat) > 1.2 + 0.07 * np.sin(lon * 5) + 0.05 * np.sin(lon * 11)
        C = ramp("3a3646", "8a8698", "d0d0dc", "fafafc")
        img[cap] = C[quant(lit[cap], len(C), d[cap], 0.55)]
    elif kind == "earth":
        land = fbm(tw, th, [160, 80, 40, 20, 10, 5], seed + 21)
        hills = fbm(tw, th, [40, 20, 10, 5], seed + 14)
        cloud = fbm(tw, th, [80, 40, 20, 10, 5], seed + 12)
        L = _tex_lookup(land, lon, lat)
        Hl = _tex_lookup(hills, lon, lat)
        Cl = _tex_lookup(cloud, lon + 0.5 * np.sin(lat * 4.0), lat)
        O = ramp("040a22", "08183e", "0e2c68", "184a98", "2c6cc0", "4e94dc", "86c0f0")
        G = ramp("0a1408", "16300e", "265016", "3e7422", "5e9432", "8aa84a", "c2b878")
        img[...] = O[quant(lit * 0.92, len(O), d, 0.55)]
        lm = L > 0.55
        dry = np.clip((Hl - 0.45) * 1.4 + 0.25 * np.cos(lat * 2.0), 0, 0.45)
        img[lm] = G[quant((lit * (0.55 + dry))[lm], len(G), d[lm], 0.55)]
        shallow = (L > 0.525) & ~lm
        img[shallow] = O[np.clip(quant(lit * 0.92, len(O), d, 0.55) + 1, 0, len(O) - 1)][shallow]
        ice = np.abs(lat) > 1.26 + 0.05 * np.sin(lon * 7)
        CW = ramp("1a2238", "4a5a80", "9aaace", "dce6f4", "ffffff")
        cm = (Cl > 0.585) | ice
        img[cm] = CW[quant(lit[cm] * (0.72 + 1.6 * np.clip(Cl[cm] - 0.585, 0, 0.2)), len(CW), d[cm], 0.55)]
    img[~inside] = 0
    if kind in ("earth", "mars"):
        side = np.clip((x * LIGHT[0] - y * LIGHT[1]) + 0.35, 0, 1)
        rim_cols = (("d6f0ff", "7ab8ff", "3f7fd6") if kind == "earth" else ("f6cfa8", "e8a07a", "a85a3c"))
        dist = np.sqrt(d2) * r - r
        for i, (d0, d1, a) in enumerate(((0, 1.5, 230), (1.5, 3.0, 150), (3.0, 4.5, 70))):
            m = (dist > d0) & (dist <= d1) & (side > 0.12 + i * 0.1)
            img[m] = c(rim_cols[i], a)
        edge = inside & (dist > -2.5) & (side > 0.3)
        img[edge, :3] = np.clip(img[edge, :3].astype(int) + (46 if kind == "earth" else 26), 0, 255)
    return img


def big_saturn(r=64):
    """Saturn in three layers so a craft can pass between them: far rings, globe, near rings."""
    tilt = math.radians(-14)
    ring_out, rb = 2.3, 0.34
    S = int(2 * ring_out * r) + 8
    Hh = int(2 * r * 1.25) + 10
    ys, xs = np.mgrid[0:Hh, 0:S].astype(np.float64)
    X0 = (xs - (S - 1) / 2) / r
    Y0 = (ys - (Hh - 1) / 2) / r
    ct, st_ = math.cos(tilt), math.sin(tilt)
    x = X0 * ct - Y0 * st_
    y = X0 * st_ + Y0 * ct
    yp = y / 0.9
    d2 = x * x + yp * yp
    inside = d2 <= 1.0
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    lam = np.clip(x * LIGHT[0] + (-yp) * LIGHT[1] + z * LIGHT[2], 0, 1)
    lit = np.clip((lam - 0.05) * 1.2, 0, 1) ** 0.8
    lat = np.arcsin(np.clip(-yp, -1, 1))
    d = dither(Hh, S)
    band = 0.5 + 0.2 * np.sin(lat * 11.0) + 0.12 * np.sin(lat * 27.0 + 1.0) + 0.07 * np.sin(lat * 47.0)
    band += 0.04 * np.sin(x * 12 + lat * 34)
    P = ramp("1c1408", "3e2e14", "6a5028", "98783e", "c09c5c", "dcbc7c", "f0dca8", "fbf2d4")
    body = np.zeros((Hh, S, 4), dtype=np.uint8)
    body[inside] = P[quant(lit * (0.55 + 0.5 * band), len(P), d, 0.5)][inside]
    hexa = inside & (lat > 1.25)
    body[hexa, :3] = (body[hexa, :3] * 0.8).astype(np.uint8)
    rr = np.sqrt(x * x + (y / rb) ** 2)
    dens = np.zeros_like(rr)
    dens += np.where((rr > 1.24) & (rr < 1.52), 0.26, 0)
    dens += np.where((rr >= 1.52) & (rr < 1.95), 0.92 - 0.3 * ((rr - 1.52) / 0.43), 0)
    dens += np.where((rr >= 2.03) & (rr < 2.27), 0.55, 0)
    dens *= np.where((rr > 2.19) & (rr < 2.21), 0.0, 1.0)
    dens *= 0.82 + 0.18 * np.sign(np.sin(rr * 90))
    ring = dens > 0.05
    RR = ramp("2e2618", "5a4c34", "8c7a5a", "b8a682", "dccba4", "f4e8c8")
    ring_px = RR[np.clip((np.clip(dens * np.where(x < 0, 1.0, 0.86), 0, 0.99) * len(RR)).astype(int), 0, len(RR) - 1)]
    ring_px[..., 3] = np.clip(110 + dens * 170, 0, 255).astype(np.uint8)
    back = np.zeros_like(body)
    front = np.zeros_like(body)
    bm = ring & (y < 0)
    fm = ring & (y >= 0) & ~(inside & (rr < 1.0))
    back[bm] = ring_px[bm]
    shadow = bm & (np.abs(x - 0.35) < 0.75) & (x > 0.0)       # the globe's shadow across the far rings
    back[shadow, :3] = (back[shadow, :3] * 0.3).astype(np.uint8)
    front[fm] = ring_px[fm]
    rs = inside & (np.abs(np.sqrt(x * x + ((y - 0.2) / rb) ** 2) - 1.75) < 0.2) & (y > 0)
    body[rs, :3] = (body[rs, :3] * 0.55).astype(np.uint8)       # ring shadow on the globe
    a = (back[..., 3] > 0) | (body[..., 3] > 0) | (front[..., 3] > 0)
    yy, xx = np.where(a)
    sl = (slice(yy.min(), yy.max() + 1), slice(xx.min(), xx.max() + 1))
    return back[sl], body[sl], front[sl]


def main():
    save(sky(), "sky.png")
    clouds()
    save(far_layer(), "launch_far.png")
    save(near_layer(), "launch_near.png")
    save(front_layer(), "launch_front.png")
    save(tower(), "tower.png")
    save(tower_cap(), "tower_cap.png")
    save(arms(), "arm.png")
    save(clamps(), "clamp.png")
    save(birds(), "bird.png")
    save(limb(), "limb.png")
    save(console(), "console.png")
    save(lamps(), "lamp.png")
    save(keycap(), "keycap.png")
    save(space_far(), "space_far.png")
    save(ship8(), "ship8.png")
    small_planets()
    save(waves(), "wave.png")
    save(capsule(), "capsule.png")
    for kind in ("moon", "mars", "earth"):
        save(big_planet(kind), "big_%s.png" % kind)
    b, g, f = big_saturn()
    save(b, "big_saturn_back.png")
    save(g, "big_saturn.png")
    save(f, "big_saturn_front.png")
    print("flight art written to", OUT)


if __name__ == "__main__":
    main()
