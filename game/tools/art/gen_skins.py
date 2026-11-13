"""Surface and landing skins for Mercury and Venus: the same file set the Moon and Mars have
(see research/v5/skins.md for the name map), made with the same helpers.

    python tools/art/gen_skins.py

Mercury: airless, tan-grey, hard shadows from a low Sun, a black sky, and a far polar crater whose
floor never sees the Sun (MESSENGER found water ice there). Venus: dim orange light under the cloud
deck, slabby basalt (Venera 13/14), low domes and a shield volcano lost in thick haze.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bg import dither, fbm, hexc, quant, ramp, save  # noqa: E402
from gen_terrain import facet_rock, floor_tile, mountain_range, peak_field  # noqa: E402
from gen_surface import BAYER, bands, crater, dust_sheet, hill  # noqa: E402

OL = hexc("0c0a14")
PEB = ((6, 4), (9, 6), (14, 9), (20, 13), (30, 19), (44, 28))


# ------------------------------------------------------------------ shared bits

def recolor(img, rgb):
    out = img.copy()
    out[..., :3] = hexc(rgb)[:3]
    return out


def ice_crater(rng_img, x0, base, w=210, rimh=26):
    """Paint a far polar crater into a range image, behind what is already there (only on empty
    pixels), seen from above at a low angle: an elliptical rim, the far inner wall lit only near its
    top on the right (the Sun skims the horizon at the pole), a pitch-black floor that never sees the
    Sun, the near lip, outer flanks lit from the left, and a few blue-white ice glints on the floor."""
    h, W = rng_img.shape[:2]
    out = rng_img.copy()
    R = ramp("100e0b", "241f1a", "3a332b", "564c40", "7a6c5a", "9c8c76")[:, :3]
    a, b = w / 2 - 8, rimh * 0.42
    cx, cy = x0 + w / 2, base - rimh + b + 2
    ys, xs = np.mgrid[0:h, 0:w + 1].astype(np.float64)
    xs += x0
    u, v = (xs - cx) / a, (ys - cy) / b
    r = np.sqrt(u * u + v * v)
    flank = np.abs(xs - cx) <= a + (ys - cy) * 1.6 + 6          # outer slopes widen downward
    shape = ((r <= 1.0) | ((ys >= cy) & flank)) & (ys < base)
    crest = (r > 1.0) & (r <= 1.0 + 1.4 / b) & (v < 0)         # thin raised crest line on the far rim
    img = np.zeros((h, w + 1, 3), dtype=np.uint8)
    img[shape] = R[2]
    img[shape & (ys >= cy) & (r > 1.0) & (u < -0.25)] = R[3]    # sunward outer flank
    img[shape & (ys >= cy) & (r > 1.0) & (u > 0.6)] = R[1]      # flank turned away
    inner = r < 0.92
    img[inner] = R[1]                                           # inner walls in shadow
    sl = u - (v + 1) * 0.9                                      # the left rim's shadow edge runs diagonally
    img[inner & (sl > -0.1) & (v < -0.35)] = R[3]               # far wall catches the Sun at its top
    img[inner & (sl > 0.3) & (v < -0.6)] = R[4]
    flo = np.sqrt((u / 0.8) ** 2 + ((v - 0.35) / 0.55) ** 2) < 1.0
    img[flo & inner] = np.array(hexc("040406")[:3])                       # permanently shadowed floor
    sheen = flo & inner & (np.sqrt(((u + 0.05) / 0.55) ** 2 + ((v - 0.45) / 0.3) ** 2) + dither(h, w + 1) * 0.5 < 1.0)
    img[sheen] = np.array(hexc("0e1824")[:3])                   # a faint blue frost sheen
    lip = (r >= 0.92) & (r <= 1.0) & (v > 0)
    img[lip] = R[4]                                             # near lip catches the low Sun
    img[lip & (u > 0.5)] = R[3]
    img[crest] = R[5]
    shape |= crest
    for gu, gv, big in ((-0.45, 0.25, 0), (-0.2, 0.55, 1), (0.08, 0.3, 0), (0.33, 0.6, 1), (0.5, 0.2, 0), (-0.05, 0.75, 0)):
        gx, gy = int(round(cx + gu * a)) - x0, int(round(cy + gv * b))
        img[gy, gx] = np.array(hexc("e4f6ff")[:3])                       # radar-bright water ice (MESSENGER)
        img[gy, gx + 1] = np.array(hexc("8ab8d8")[:3])
        img[gy, gx - 1] = np.array(hexc("2c4a64")[:3])
        if big:
            img[gy, gx + 2] = np.array(hexc("3a5a74")[:3])
            img[gy, gx - 2] = np.array(hexc("1a2c3e")[:3])
    for y in range(h):
        for x in range(w + 1):
            if shape[y, x] and out[y, (x0 + x) % W, 3] == 0:
                out[y, (x0 + x) % W, :3] = img[y, x]
                out[y, (x0 + x) % W, 3] = 255
    return out


def rays(img, R, seed, n=9):
    """Bright ejecta rays on the plain around a crater sprite (only on empty pixels)."""
    rng = np.random.default_rng(seed)
    H, W = img.shape[:2]
    out = img.copy()
    cx, cy = (W - 1) / 2, (H - 1) / 2
    for _ in range(n):
        a = rng.uniform(0, 2 * np.pi)
        for k in range(int(W * 0.25), int(W * 0.62)):
            x, y = int(round(cx + np.cos(a) * k)), int(round(cy + np.sin(a) * k * 0.34))
            if 0 <= x < W and 0 <= y < H and out[y, x, 3] == 0 and (k + int(a * 10)) % 3 != 0:
                out[y, x] = R[4] if k < W * 0.45 else R[3]
    return out


def sun_glare(r=9, glow=30):
    """Mercury's Sun: 2.5-3x wider than from Earth, a white-hot disc with a fierce dithered glare
    and four short spikes."""
    S = 2 * (r + glow) + 1
    c = (S - 1) / 2
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float64)
    d = np.sqrt((xs - c) ** 2 + (ys - c) ** 2)
    v = np.clip(1 - (d - r) / glow, 0, 1) ** 2.2
    lvl = quant(v, 5, dither(S, S), 0.9)
    cols = np.array([hexc("ffd060", 0), hexc("ffc850", 40), hexc("ffd870", 80), hexc("ffe8a0", 140),
                     hexc("fff4d0", 210)], dtype=np.uint8)
    img = cols[lvl]
    sp = (np.abs(xs - c) < 0.6) | (np.abs(ys - c) < 0.6)
    spike = sp & (d < r + glow * 0.8) & (d > r)
    img[spike] = np.where((d[spike] < r + glow * 0.45)[:, None], hexc("fff8e0", 230), hexc("ffe8a0", 150))
    img[d <= r + 1] = hexc("fff0b0")
    img[d <= r] = hexc("fffef4")
    img[d > r + glow] = 0
    return img


def lightning(frames=4, w=16, h=34, seed=9):
    """Far lightning in the cloud deck (Venus Express saw its radio whistlers): a bolt, its fade, a
    glow in the cloud, then nothing. Same 4x16x34 sheet layout as the Mars dust devil."""
    rng = np.random.default_rng(seed)
    sheet = np.zeros((h, w * frames, 4), dtype=np.uint8)
    path, x = [], w // 2 + int(rng.integers(-2, 3))
    for y in range(h):
        path.append(x)
        if rng.random() < 0.45:
            x = int(np.clip(x + rng.choice([-1, 1]), 2, w - 3))
    branch = [(path[12] + 1 + k // 2, 12 + k) for k in range(7)]
    glow = np.zeros((h, w))
    ys, xs = np.mgrid[0:h, 0:w]
    glow = np.clip(1 - np.sqrt(((xs - w / 2) / (w / 2)) ** 2 + (ys / 7.0) ** 2), 0, 1)
    for f, (core, a_core, a_glow) in enumerate(((hexc("fffbe8"), 255, 120), (hexc("ffe0a0"), 170, 80), (None, 0, 60), (None, 0, 0))):
        sub = sheet[:, f * w:(f + 1) * w]
        if a_glow:
            g = (glow + BAYER[ys % 4, xs % 4] * 0.4) > 0.45
            sub[g] = hexc("ffd890", a_glow)
        if core is not None:
            for y, px in enumerate(path):
                sub[y, px] = list(core[:3]) + [a_core]
            for px, y in branch:
                if 0 <= px < w:
                    sub[y, px] = hexc("ffe8b0", a_core * 2 // 3)
    return sheet


def plates_floor(n, seed, R, crack, dust):
    """Venera-style ground: flat basalt slabs (tileable Voronoi plates, each one flat tone with a lit
    upper-left edge) split by dark cracks with orange dust in them."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64)
    k = 26
    px, py = rng.uniform(0, n, k), rng.uniform(0, n, k) * 0.999
    dx = (xs[..., None] - px + n / 2) % n - n / 2
    dy = ((ys[..., None] - py + n / 2) % n - n / 2) * 1.6     # plates wider than deep
    d = np.sqrt(dx * dx + dy * dy)
    o = np.argsort(d, axis=2)
    d1 = np.take_along_axis(d, o[..., :1], 2)[..., 0]
    d2 = np.take_along_axis(d, o[..., 1:2], 2)[..., 0]
    cell = o[..., 0]
    tone = rng.integers(2, len(R) - 1, k)[cell]
    tex = fbm(n, n, [16, 8], seed + 1, True, True)
    tone = np.clip(tone + (tex > 0.68).astype(int) - (tex < 0.28).astype(int), 1, len(R) - 2)
    img = R[tone].copy()
    edge = (d2 - d1) < 1.6
    lit = (d2 - d1 < 3.0) & ~edge & (np.roll(edge, 2, 0) | np.roll(edge, 2, 1))
    img[lit] = R[len(R) - 1]
    img[edge] = crack
    dusty = edge & (fbm(n, n, [8, 4], seed + 2, True, True) > 0.58)
    img[dusty] = dust
    img[..., 3] = 255
    return img


def cloud_roll(w, h, seed):
    """Underside of the cloud deck: a long darker roll, ragged top and bottom, soft dithered ends."""
    n = fbm(w, 2, [max(4, w // 6), max(2, w // 16)], seed, False, False)
    xs = np.arange(w)
    end = np.clip(np.minimum(xs, w - 1 - xs) / (w * 0.25), 0, 1)
    top = (h / 2 - (h / 2) * end * (0.6 + 0.6 * n[0])).astype(int)
    bot = (h / 2 + (h / 2) * end * (0.6 + 0.6 * n[1])).astype(int)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for x in range(w):
        for y in range(max(0, top[x]), min(h, bot[x] + 1)):
            edge = y == top[x] or y == bot[x]
            if edge and BAYER[y % 4, x % 4] > 0:
                continue
            img[y, x] = hexc("a8762e", 140) if y == bot[x] else hexc("74481a", 120)
    return img


def glow_sky(w, h, cols, cx, cy, rx, ry, amp, gamma=0.7):
    """bands() with a soft bright patch added before the bands are cut (Sun behind the cloud deck),
    so the patch follows the same flat steps and dithered joins as the rest of the sky."""
    n = len(cols)
    R = ramp(*cols)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    g = (ys / (h - 1)) ** gamma * n + amp * np.exp(-((xs - cx) / rx) ** 2 - ((ys - cy) / ry) ** 2)
    frac = g - np.floor(g)
    span = 3 * n / h
    step = np.where(frac > 1 - span, ((frac - (1 - span)) / span + dither(h, w)) > 0.53, 0)
    img = R[np.clip(np.floor(g).astype(int) + step.astype(int), 0, n - 1)].copy()
    img[..., 3] = 255
    return img


# ------------------------------------------------------------------ the two skins

def mercury():
    ol = OL
    sky = hexc("0a0908")
    # far: a long lobate scarp (a thrust-fault cliff hundreds of km long, like Discovery Rupes)
    hd = peak_field(640, 120, 611, [(0.75, 6, 26, 56)], slope=0.35, rough=0, round_r=12, ridges=(2, 4))
    zs = np.arange(120)[:, None]
    z0 = 55 + (fbm(640, 1, [160, 80], 612, True, False)[0] - 0.5) * 50
    hd = np.maximum(hd, 20 * np.clip((zs - z0[None, :]) / 2.5, 0, 1) + (fbm(640, 1, [40, 20], 613, True, False)[0] - 0.5) * 6)
    save(mountain_range(640, 60, hd, ramp("2a2520", "3a332b", "4a4238"), sky, (0.0, 0.0), 5, sun=(-0.85, 0.3, 0.35), rim=False),
         "surface/mercury_range_dist.png")
    # mid: rough crater-rim mountains; low around x 180..410 so the polar crater shows behind them
    X0, CW = 180, 230
    hf = peak_field(640, 260, 601, [(0.8, 24, 96, 66), (0.55, 14, 56, 50), (0.35, 8, 30, 40)], slope=0.8, mesa=0.3, round_r=10, sharp=2.4)
    xs = np.arange(640)
    hf *= 1 - 0.8 * np.clip(1 - np.abs(xs - (X0 + CW / 2)) / (CW / 2 + 30), 0, 1) ** 0.6
    far = mountain_range(640, 140, hf, ramp("1c1916", "302a24", "4a4138", "675b4e"), sky, (0.0, 0.15), 16, sun=(-0.85, 0.3, 0.35))
    solid = far[..., 3] > 0
    sky_h = np.where(solid.any(0), 140 - solid.argmax(0), 0)
    far = ice_crater(far, X0, 140 - int(sky_h[X0 + 30:X0 + CW - 30].max()) + 8, w=CW, rimh=40)
    save(far, "mercury_range_far.png")
    save(mountain_range(640, 90, peak_field(640, 170, 602, [(0.8, 8, 30, 40), (0.45, 4, 16, 30)], slope=0.6, ridge_amp=0.5, round_r=8),
                        ramp("15120f", "2c2620", "463d33", "655848", "8a7a66", "b3a088"), sky, (0.0, 0.05), 24, sun=(-0.85, 0.3, 0.35)),
         "mercury_range_near.png")
    fl = ramp("2a2621", "36312a", "433c34", "524a3f", "635a4d", "7c7262")
    save(floor_tile(128, 611, fl, "moon"), "floor_mercury.png")
    rk = ramp("221e1a", "3c352e", "5a5046", "7e7262", "a49684")
    for i, (w, h) in enumerate(PEB):
        save(facet_rock(w, h, 1100 + i, rk, ol), "pebble_mercury_%d.png" % i)
    for h in (23, 50):
        save(facet_rock(67, h + 12, 1120 + h, rk, ol, table=True), "boulder_mercury_%d.png" % h)
    # ice-bearing dark rock with a pale blue glint
    save(facet_rock(20, 13, 1177, ramp("1a1a20", "2c2c36", "42424e", "5e5e6c"), ol, veins=(hexc("4a7a9a"), hexc("d8f2ff"))),
         "sample_mercury_big.png")
    for i, w in enumerate((12, 20, 34, 58, 92)):
        c = crater(w, fl, 61 + i)
        if i >= 2:                                  # young craters wear bright rays (Hokusai, Kuiper)
            c = rays(c, ramp("2a2621", "36312a", "433c34", "6e6656", "8a8070", "a49a86"), 70 + i)
        save(c, "surface/crater_mercury_%d.png" % i)
    for i, (w, h) in enumerate(((46, 7), (84, 10), (130, 13))):
        save(hill(w, h, ramp("2c2620", "463d33", "655848", "8a7a66"), 160 + i), "surface/hill_mercury_%d.png" % i)
    # no air: the sky stays black by day; a faint warm glow over the sunward horizon
    save(bands(640, 300, ["040405", "050506", "070707", "0a0908", "100e0b"], joins=2, gamma=1.6), "surface/mercury_sky_day.png")
    save(bands(640, 300, ["020203", "030304", "040405", "050506"], joins=2), "surface/mercury_sky_night.png")
    save(sun_glare(), "surface/mercury_sun.png")


def venus():
    ol = OL
    haze = hexc("d8a650")                           # horizon colour every layer fades into
    # far shield volcano (like Maat Mons): one broad gentle cone, almost lost in the haze
    hp = peak_field(640, 120, 711, [(0.6, 6, 16, 44)], slope=0.3, rough=0, round_r=10, ridges=(2, 3))
    ys, xs = np.mgrid[0:120, 0:640].astype(np.float64)
    dd = np.sqrt(((xs - 420 + 320) % 640 - 320) ** 2 + ((ys - 70) * 2) ** 2)
    hp = np.maximum(hp, 46 - dd * 0.2 + np.where(dd < 14, (14 - dd) * 0.25 - 3.0, 0))   # summit caldera
    save(mountain_range(640, 60, hp, ramp("b07a3c", "bc8846", "c89450"), haze, (0.25, 0.35), 5, sun=(-0.3, 0.3, 0.9), rim=False),
         "surface/venus_range_dist.png")
    # low pancake domes: flat tops, steep sides
    save(mountain_range(640, 140, peak_field(640, 260, 701, [(0.8, 22, 64, 70), (0.55, 14, 40, 52), (0.35, 6, 22, 40)],
                                              slope=0.9, mesa=0.75, round_r=24, ridges=(5, 7), ridge_amp=0.15, sharp=1.6),
                        ramp("6a3e1c", "7e4c22", "94602c", "aa7436"), haze, (0.35, 0.75), 18, sun=(-0.3, 0.3, 0.9)),
         "venus_range_far.png")
    # near: slabby basalt ridges, broken and flat-topped
    save(mountain_range(640, 90, peak_field(640, 170, 702, [(0.8, 8, 44, 30), (0.45, 4, 22, 24)], slope=0.75, mesa=0.6,
                                             ridge_amp=0.3, round_r=3, ridges=(4, 6)),
                        ramp("2e1a0c", "432612", "5c3618", "784820", "94602a", "b07a38"), haze, (0.18, 0.5), 24, sun=(-0.3, 0.3, 0.9)),
         "venus_range_near.png")
    fl = ramp("3a2410", "4c3016", "5e3c1c", "704a22", "86592a", "a06e36")
    save(plates_floor(128, 711, fl, hexc("1e1208"), hexc("8a5424")), "floor_venus.png")
    rk = ramp("24160c", "3e2814", "5c3c1e", "7e5428", "a07038")
    for i, (w, h) in enumerate(PEB):
        save(facet_rock(w, h, 1200 + i, rk, ol, table=True), "pebble_venus_%d.png" % i)
    for h in (23, 50):
        save(facet_rock(67, h + 12, 1220 + h, rk, ol, table=True), "boulder_venus_%d.png" % h)
    save(facet_rock(20, 13, 1277, ramp("1e1410", "34241a", "4e3626", "6c4c34"), ol, table=True, veins=(hexc("5a0c0c"), hexc("c8302a"))),
         "sample_venus_big.png")
    for i, w in enumerate((12, 20, 34, 58, 92)):
        save(crater(w, fl, 71 + i), "surface/crater_venus_%d.png" % i)
    for i, (w, h) in enumerate(((46, 7), (84, 10), (130, 13))):
        save(hill(w, h, ramp("5c3618", "784820", "94602a", "b07a38"), 170 + i), "surface/hill_venus_%d.png" % i)
    # featureless glowing sulphur-yellow sky, darker toward the top, a brighter patch for the Sun
    save(glow_sky(640, 300, ["3c220e", "5a3414", "7a4a1c", "9a6226", "b87c34", "cc9442", "d8a650"], 170, 150, 240, 90, 1.3),
         "surface/venus_sky_day.png")
    # the cloud deck never clears; at night only the hot ground glows a dull red
    save(bands(640, 300, ["0a0504", "120806", "1a0c08", "26120a", "34180c"]), "surface/venus_sky_night.png")
    for i, (w, h) in enumerate(((96, 5), (64, 4), (128, 6))):
        save(cloud_roll(w, h, 11 + i), "surface/venus_cloud_%d.png" % i)
    save(lightning(), "surface/venus_lightning.png")
    save(recolor(dust_sheet(seed=9), "e8b860"), "surface/venus_haze.png")


if __name__ == "__main__":
    mercury()
    venus()
    print("SKINS DONE")
