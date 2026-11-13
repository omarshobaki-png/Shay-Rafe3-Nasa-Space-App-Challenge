"""Small sprites for the landing and surface screens, written to art/surface/.

    python tools/art/gen_surface.py

Floor craters and low hills (drawn at several depths), the Mars sky bands, thin clouds, Phobos,
a dust devil, drifting dust, the Earth's atmosphere rim, the parachute and heat shield, a scorch
mark, landing-zone beacons and the HUD icons. All numpy or hand-typed pixel maps: no AI images.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import BAYER, dither, fbm, hexc, quant, ramp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "surface")
OL = hexc("0c0a14")


def save(img, name):
    Image.fromarray(img).save(os.path.join(OUT, name))


def outline(img, col=OL):
    a = img[..., 3] > 0
    pad = np.pad(a, 1)
    edge = ~a & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
    out = img.copy()
    out[edge] = col
    return out


def ascii_sprite(rows, pal):
    """Hand-typed pixel map: one character per pixel, '.' is empty."""
    h, w = len(rows), max(len(r) for r in rows)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and ch != " ":
                img[y, x] = hexc(pal[ch])
    return img


def crater(w, R, seed):
    """A crater lying on the floor, already squashed by perspective; sun on the left, so the
    right inner wall is lit and the left inner wall is in shadow. Colours come from the floor ramp."""
    h = max(4, int(round(w * 0.34)))
    W, H = w + 6, h + 4
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    nx = (xs - (W - 1) / 2) / (w / 2)
    ny = (ys - (H - 1) / 2) / (h / 2)
    wob = 1 + 0.06 * np.sin(np.arctan2(ny, nx) * 3 + seed)
    r = np.sqrt(nx * nx + ny * ny) / wob
    hm = np.where(r < 1, (r * r - 1) * 1.0, 0) + np.exp(-((r - 1.05) / 0.16) ** 2) * 0.45
    gx = np.gradient(hm, axis=1) * w * 0.5
    gy = np.gradient(hm, axis=0) * h * 0.5
    lam = 0.5 + gx * 0.42 - gy * 0.2
    # four flat tones: shadowed wall, bowl, lit wall, bright rim; the plain itself stays transparent
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[(r < 0.9)] = R[2]
    img[(lam < 0.38) & (r < 1.25)] = R[1]
    img[(lam < 0.2) & (r < 1.25)] = R[0]
    img[(lam > 0.62) & (r < 1.3)] = R[4]
    img[(lam > 0.8) & (r < 1.3)] = R[5]
    return img


def hill(w, h, R, seed):
    """A low mound on the far plain: lit left flank, dark right flank."""
    rng = np.random.default_rng(seed)
    xs = np.arange(w)
    prof = np.sin(np.pi * (xs + 0.5) / w) ** 0.8
    prof *= 1 + 0.25 * (fbm(w, 1, [max(4, w // 3), max(2, w // 8)], seed, False, False)[0] - 0.5)
    top = (h - np.clip(prof, 0, 1) * (h - 1)).astype(int)
    peak = int(np.argmin(top)) + int(rng.integers(-w // 10, w // 10 + 1))
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for x in range(w):
        for y in range(top[x], h):
            split = peak + (y - top.min()) * 0.9
            tone = 2 if x < split - 3 else (1 if x < split + 2 else 0)
            if y == top[x] and x < split:
                tone = 3
            img[y, x] = R[min(tone, len(R) - 1)]
    return img


def bands(w, h, cols, joins=3, gamma=0.85):
    """Flat sky bands (top to bottom) joined by a few rows of dither: no full-area dither noise."""
    n = len(cols)
    R = ramp(*cols)
    g = (np.linspace(0, 1, h) ** gamma)[:, None] * np.ones((1, w)) * n
    d = dither(h, w)
    frac = g - np.floor(g)
    span = joins * n / h
    step = np.where(frac > 1 - span, ((frac - (1 - span)) / span + d) > 0.53, 0)
    img = R[np.clip(np.floor(g).astype(int) + step.astype(int), 0, n - 1)].copy()
    img[..., 3] = 255
    return img


def chute(w=58, h=46):
    """Supersonic parachute: orange and white gores, a vent, lines meeting at the backshell."""
    img = np.zeros((h, w, 4), dtype=np.uint8)
    cw, ch = w - 4, 20
    cx = (w - 1) / 2
    O = ramp("8c1e22", "d03a30", "f07a50")
    Wt = ramp("a3abc4", "d6dcea", "f4f6fb")
    for y in range(ch):
        for x in range(w):
            nx = (x - cx) / (cw / 2)
            ny = (ch - 1 - y) / (ch - 1)
            if nx * nx + ny * ny <= 1.0 and not (abs(nx) < 0.1 and ny > 0.93):
                gore = int(np.floor((np.arcsin(np.clip(nx / max(1e-6, np.sqrt(max(1e-6, 1 - ny * ny * 0.6))), -1, 1)) / np.pi + 0.5) * 8))
                tone = 2 if nx < -0.3 else (1 if nx < 0.45 else 0)
                if ny < 0.12:
                    tone = max(0, tone - 1)
                img[y, x] = (O if gore % 2 == 0 else Wt)[tone]
    img = outline(img)
    grey = hexc("7d8697")
    for i in range(7):
        x0 = 3 + i * (w - 7) / 6.0
        for k in range(h - ch - 1):
            t = k / (h - ch - 2.0)
            x = int(round(x0 + (cx - x0) * t))
            y = ch + k
            if (k + i) % 4 != 3:
                img[y, x] = grey
    img[h - 2:h, int(cx) - 1:int(cx) + 2] = hexc("4e5566")
    return img


def heatshield(w=46, h=13):
    """Blunt heat shield seen from the side, scorched from the entry."""
    img = np.zeros((h, w, 4), dtype=np.uint8)
    R = ramp("4a2e10", "7c5418", "b3812a", "dcae44")
    cx = (w - 1) / 2
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / (w / 2)
            edge = (y - 2) / (h - 3.0)              # 0 at the rim, 1 at the nose
            if y < 2:
                if abs(nx) <= 1.0:
                    img[y, x] = hexc("4e5566") if y == 1 else hexc("b4bcc8")
            elif abs(nx) <= 1.0 - edge ** 1.6 * 0.72:
                tone = 3 if nx < -0.4 else (2 if nx < 0.2 else 1)
                if edge > 0.55:
                    tone = max(0, tone - 2)         # charred nose
                img[y, x] = R[tone]
    return outline(img)


def scorch(w=72, h=17):
    """Blast mark under a lander: black, densest in the middle, dithered out to the edge."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    r = np.sqrt(((xs - (w - 1) / 2) / (w / 2)) ** 2 + ((ys - (h - 1) / 2) / (h / 2)) ** 2)
    v = np.clip(1.25 - r * 1.25, 0, 1)
    lvl = quant(v, 4, dither(h, w), 0.9)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., 3] = np.array([0, 70, 120, 170])[lvl]
    return img


def earth_halo(r=22, glow=9):
    """Thin blue atmosphere rim that goes behind the Earth sprite."""
    S = 2 * (r + glow) + 1
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float64)
    d = np.sqrt((xs - (S - 1) / 2) ** 2 + (ys - (S - 1) / 2) ** 2)
    v = np.clip(1 - (d - r) / glow, 0, 1) ** 1.8
    lvl = quant(v, 4, dither(S, S), 0.9)
    img = np.zeros((S, S, 4), dtype=np.uint8)
    cols = np.array([hexc("143e8a", 0), hexc("143e8a", 110), hexc("2264b8", 170), hexc("4a92da", 230)], dtype=np.uint8)
    img[...] = cols[lvl]
    img[d > r + glow] = 0
    return img


def dust_devil(frames=4, w=16, h=34):
    """A far-away dust devil: a swaying funnel, wider at the top."""
    sheet = np.zeros((h, w * frames, 4), dtype=np.uint8)
    C = [hexc("e8c8a0", 150), hexc("d4a67c", 190), hexc("b8805a", 210)]
    for f in range(frames):
        ph = f / frames * 2 * np.pi
        for y in range(h):
            k = 1 - y / (h - 1.0)                   # 1 at the top
            cx = w / 2 + np.sin(ph + y * 0.35) * (1.0 + 2.0 * k)
            half = 1.0 + 3.6 * k ** 1.5
            for x in range(w):
                d = (x - cx) / half
                if abs(d) <= 1 and (BAYER[y % 4, (x + f) % 4] + 0.47) < 0.9 - 0.25 * k:
                    sheet[y, f * w + x] = C[0] if d < -0.3 else (C[1] if d < 0.4 else C[2])
        base = sheet[h - 3:h, f * w:(f + 1) * w]
        base[1:, w // 2 - 3:w // 2 + 4] = np.where(base[1:, w // 2 - 3:w // 2 + 4][..., 3:] > 0, base[1:, w // 2 - 3:w // 2 + 4], C[0])
    return sheet


def dust_sheet(w=256, h=22, seed=5):
    """Tileable drifting dust: thin streaks, dithered, mostly transparent."""
    n = fbm(w, h, [64, 32, 8], seed, True, False)
    n2 = fbm(w, 1, [128, 32], seed + 1, True, False)[0][None, :]
    ys = np.linspace(-1, 1, h)[:, None]
    v = np.clip((n * 0.7 + n2 * 0.5 - 0.5) * 2.2, 0, 1) * (1 - ys * ys)
    lvl = quant(v, 4, dither(h, w), 1.0)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = hexc("f0d2aa")[:3]
    img[..., 3] = np.array([0, 50, 90, 130])[lvl]
    return img


def wisp(w, h, seed):
    """Thin high cloud (water-ice cirrus, as Curiosity photographed): a few broken strokes."""
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for i in range(h):
        x = int(rng.integers(0, w // 3))
        while x < w - 4:
            ln = int(rng.integers(6, max(8, w // 3)))
            a = 150 if i in (h // 2, h // 2 - 1) else 90
            img[i, x:min(w, x + ln)] = hexc("f6e2c8", a)
            x += ln + int(rng.integers(3, 14))
    return img


PAL = {
    "o": "0c0a14", "w": "f4f6fb", "g": "a3abc4", "d": "4e5566", "k": "2a2e3a",
    "y": "ffd75e", "O": "ff9f43", "r": "ff5a5a", "R": "8c1e22", "c": "4fd6ff", "C": "1d5a80",
    "G": "6dff8a", "b": "6e6e80", "B": "9a9aac", "s": "3a3a46", "m": "7d8697",
}

ICONS = {
    # fall-speed chevrons
    "ic_down": ["..ooooo..", ".owwwwwo.", "..owwwo..", "...owo...", "ooooooooo", "owwwwwwwo", ".owwwwwo.", "..owwwo..", "...owo...", "....o...."],
    # fuel drop
    "ic_fuel": ["....o....", "...oOo...", "...oOo...", "..oOOOo..", "..oOyOo..", ".oOOyOOo.", ".oOyyyOo.", ".oOyyyOo.", "..oOOOo..", "...ooo..."],
    # sideways drift
    "ic_drift": ["...o...o...", "..oo...oo..", ".owooooowo.", "owwwwwwwwwo", ".owooooowo.", "..oo...oo..", "...o...o..."],
    # sample slot, empty and full
    "ic_rock0": [".....oooo...", "...oo....oo.", "..o........o", ".o.........o", "o..........o", "o..........o", "o.........o.", ".oo.....oo..", "...ooooo...."],
    "ic_rock1": [".....oooo...", "...ooBBBBoo.", "..oBBBBBbbbo", ".oBBcBBbbbso", "oBBBBcbbbsso", "oBBbbbbcssso", "obbbbbssCso.", ".oobsssssoo.", "...ooooo...."],
    # battery cap is drawn by code; this is the lightning bolt
    "ic_bolt": ["...oooo", "..oyyo.", ".oyyo..", "oyyyooo", "oooyyyo", "..oyyo.", ".oyyo..", ".oyo...", ".oo...."],
    # data chip
    "ic_data": [".o.o.o.o.", "ooooooooo", ".occcccCo", "oocwcccCo", ".occcccCo", "oocccccCo", ".oCCCCCCo", "ooooooooo", ".o.o.o.o."],
    # arrows: screen-edge pointer (points right; mirrored in code) and the marker over a sample
    "arrow_r": ["oo......", "oyoo....", "oyyyoo..", "oyyyyyoo", "oyyyyyoo", "oyyyoo..", "oyoo....", "oo......"],
    "marker": ["ooooooooo", "oyyyyyyyo", ".oyyyyyo.", "..oyyyo..", "...oyo...", "....o...."],
    # landing-zone beacon post, lamp off and on
    "beacon0": ["..ooo..", ".oRRRo.", ".oRRRo.", "..ooo..", "..odo..", "..odo..", "..odo..", "..odo..", ".ooooo.", "odddddo", "ooooooo"],
    "beacon1": ["..ooo..", ".orwro.", ".orrro.", "..ooo..", "..odo..", "..odo..", "..odo..", "..odo..", ".ooooo.", "odddddo", "ooooooo"],
    # Phobos: a lumpy dark moon
    "phobos": ["..oooo...", ".obbBBoo.", "obbsbBBBo", "obbbbBsBo", ".obbbbBBo", "..ooobbo.", ".....oo.."],
    # wind streak
    "streak": ["wwwwww..", "..wwwwww"],
    # rock chips thrown by the drill
    "chip": ["oo.", "oBo", ".oo"],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    moon_floor = ramp("2e2f3c", "3a3c4a", "474a5a", "56596a", "666a7c", "7e8296")
    mars_floor = ramp("4e1e12", "62281a", "74321e", "863c24", "9a4a2c", "b25e38")
    for i, w in enumerate((12, 20, 34, 58, 92)):
        save(crater(w, moon_floor, 3 + i), "crater_moon_%d.png" % i)
        save(crater(w, mars_floor, 13 + i), "crater_mars_%d.png" % i)
    for i, (w, h) in enumerate(((46, 7), (84, 10), (130, 13))):
        save(hill(w, h, ramp("30323f", "4c4f60", "70748a", "989cb2"), 40 + i), "hill_moon_%d.png" % i)
        save(hill(w, h, ramp("642818", "80361e", "9c4628", "b85a34"), 50 + i), "hill_mars_%d.png" % i)
    # Mars sky: pink-tan by day (fine dust scatters red light), near-black by night
    save(bands(640, 300, ["8e5a44", "a26c56", "b88268", "cc9a7a", "dcb08a", "e8c49c"]), "mars_sky_day.png")
    save(bands(640, 300, ["05040a", "0a0812", "110c1a", "1a1220", "261824"]), "mars_sky_night.png")
    save(wisp(96, 5, 1), "mars_cloud_0.png")
    save(wisp(64, 4, 2), "mars_cloud_1.png")
    save(wisp(128, 6, 3), "mars_cloud_2.png")
    save(dust_devil(), "dust_devil.png")
    save(dust_sheet(), "dust_sheet.png")
    save(earth_halo(22), "earth_halo.png")
    save(chute(), "chute.png")
    save(heatshield(), "heatshield.png")
    save(scorch(), "scorch.png")
    for name, rows in ICONS.items():
        save(ascii_sprite(rows, PAL), name + ".png")
    print("SURFACE SPRITES DONE")


if __name__ == "__main__":
    main()
