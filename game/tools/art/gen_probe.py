"""Sprites for the Saturn ring drone screen (scripts/screens/probe.gd) -> art/probe/.

    python tools/art/gen_probe.py            everything
    python tools/art/gen_probe.py 3d         only the Blender composites
    python tools/art/gen_probe.py 2d         only the numpy art

3D (passes from tools/blender/probe_models.py in art/raw3d/probe): tumbling ring boulders,
the drone (3 tilts x 3 damage states), the orbiter with its docking port, foreground boulders.
2D (numpy): Saturn's limb and cloud bands, ring layers, ice crystals, moons, HUD pieces.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose3d import compose, save_sheet  # noqa: E402
from gen_bg import fbm, hexc, ramp  # noqa: E402
from palette import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "art", "raw3d", "probe")
OUT = os.path.join(ROOT, "art", "probe")

PAL = dict(P)
PAL.update({
    "rock0": hexc("2a2634"), "rock1": hexc("484252"), "rock2": hexc("6c6470"), "rock3": hexc("968c90"),
    "rock4": hexc("c6bcb6"),
    "ice0": hexc("46668c"), "ice1": hexc("82aace"), "ice2": hexc("c0e0f4"), "ice3": hexc("f4fbff"),
    "lamp0": hexc("1c6a34"), "lamp1": hexc("48d06a"), "lamp2": hexc("c8ffd0"),
})
ROCKS = ["rock_%d" % i for i in range(7)]
ROCK_FRAMES = 16
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47
OL = hexc("0c0a14")


def save(img, name):
    Image.fromarray(img).save(os.path.join(OUT, name))
    print(name, img.shape[1], "x", img.shape[0])


# ------------------------------------------------------------------ 3D composites

def parts():
    with open(os.path.join(RAW, "parts.json")) as fh:
        meta = json.load(fh)
    return {n: {"id": v["id"], "ramp": [PAL[c] for c in v["ramp"]], "order": v["order"]} for n, v in meta.items()}


def one(name, pt):
    return compose(os.path.join(RAW, name + "_id.png"), os.path.join(RAW, name + "_n.png"),
                   pt, factor=4, outline=True, selective=True)


def flash(img):
    """White silhouette of a sprite, for the hit flash."""
    out = np.zeros_like(img)
    out[img[..., 3] > 0] = (255, 255, 255, 255)
    return out


def gen_3d():
    pt = parts()
    for r in ROCKS:
        frames = [one("%s_%02d" % (r, f), pt)[0] for f in range(ROCK_FRAMES)]
        save_sheet(frames, os.path.join(OUT, r + ".png"))
        a = np.mean([f[..., 3] > 0 for f in frames], axis=0)
        print(r, frames[0].shape[1], "px, mean radius %.1f" % np.sqrt((a > 0.5).sum() / np.pi))
    frames = [one("drone_%d%d" % (ti, dmg), pt)[0] for ti in range(3) for dmg in range(3)]
    save_sheet(frames, os.path.join(OUT, "drone.png"), cols=3)
    save_sheet([flash(f) for f in frames[0::3]], os.path.join(OUT, "drone_flash.png"))
    print("drone", frames[0].shape[1], "x", frames[0].shape[0])
    frames = []
    for c in range(2):
        img, part, names = one("orbiter_%d" % c, pt)
        frames.append(img)
        ys, xs = np.nonzero(part == names.index("lamp"))
        print("orbiter", c, "lamps x %d..%d y %d..%d" % (xs.min(), xs.max(), ys.min(), ys.max()))
    save_sheet(frames, os.path.join(OUT, "orbiter.png"))
    print("orbiter", frames[0].shape[1], "x", frames[0].shape[0])
    for k in range(3):
        save(near_rock("near_%d" % k, pt), "near_%d.png" % k)


def near_rock(name, pt):
    """A foreground boulder: dark, low contrast, with a soft fringe so it reads as out of focus."""
    img = one(name, pt)[0]
    a = img[..., 3] > 0
    lum = img[..., :3].astype(np.float64).mean(axis=2)
    out = np.zeros_like(img)
    out[a] = hexc("070914")
    out[a & (lum > 100)] = hexc("0c1020")
    out[a & (lum > 150)] = hexc("131a30")
    out[a & (lum > 185)] = hexc("1c2644")
    out = pad(out, 3)
    g = out[..., 3] > 0
    for ring_a in (150, 80):
        n = g.copy()
        n[1:, :] |= g[:-1, :]
        n[:-1, :] |= g[1:, :]
        n[:, 1:] |= g[:, :-1]
        n[:, :-1] |= g[:, 1:]
        out[n & ~g] = (*hexc("060812")[:3], ring_a)
        g = n
    return out


# ------------------------------------------------------------------ 2D helpers

def bayer(h, w):
    return np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]


def ascii_sprite(rows, colours):
    h, w = len(rows), len(rows[0])
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for y, row in enumerate(rows):
        assert len(row) == w, (row, w)
        for x, ch in enumerate(row):
            if ch != ".":
                img[y, x] = colours[ch]
    return img


def outline(img, colour=OL):
    a = img[..., 3] > 0
    grow = np.zeros_like(a)
    grow[1:, :] |= a[:-1, :]
    grow[:-1, :] |= a[1:, :]
    grow[:, 1:] |= a[:, :-1]
    grow[:, :-1] |= a[:, 1:]
    out = img.copy()
    out[grow & ~a] = colour
    return out


def pad(img, n=1):
    return np.pad(img, ((n, n), (n, n), (0, 0)))


def centre(img, w, h):
    out = np.zeros((h, w, 4), dtype=np.uint8)
    y0, x0 = (h - img.shape[0]) // 2, (w - img.shape[1]) // 2
    out[y0:y0 + img.shape[0], x0:x0 + img.shape[1]] = img
    return out


def poly_mask(w, h, pts):
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon(pts, fill=255)
    return np.array(im) > 0


def shaded(mask, light, mid, dark):
    """Flat fill with a highlight strip on top and a dark lower edge, then an outline."""
    h, w = mask.shape
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[mask] = mid
    up = np.zeros_like(mask)
    up[1:, :] = mask[:-1, :]
    dn = np.zeros_like(mask)
    dn[:-1, :] = mask[1:, :]
    img[mask & ~up] = light
    img[mask & ~dn] = dark
    return outline(pad(img))


# ------------------------------------------------------------------ Saturn below the ring gap

PLANET_W, PLANET_H, LIMB_Y0, LIMB_R = 940, 100, 14, 4614.0
TAN = ["5a4420", "8a6428", "b8863c", "d4a85a", "e8c98a", "f6e6b8"]


def limb_top(xs):
    return LIMB_Y0 + LIMB_R - np.sqrt(LIMB_R ** 2 - (xs - PLANET_W / 2.0) ** 2)


def planet():
    """Saturn's cloud tops: a curved limb, flat bands that thin toward it, a storm, night on the right."""
    w, h = PLANET_W, PLANET_H
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    top = limb_top(xs)
    B = bayer(h, w)
    wob = fbm(w, h, [120, 60, 30], 71, False, False) - 0.5
    d = ys - top + B * 2.4                                    # 2 px dither at every join
    dd = np.clip(d, 0, None)
    u = np.log1p(dd / 5.0) + wob * (0.05 + 0.03 * np.log1p(dd / 5.0))
    edges = [0.16, 0.42, 0.66, 0.9, 1.12, 1.36, 1.56, 1.8, 2.0, 2.22, 2.42, 2.62, 2.8, 2.95]
    tones = [5, 4, 3, 4, 2, 3, 4, 3, 2, 3, 1, 2, 3, 2, 1]
    tone = np.array(tones)[np.searchsorted(edges, u)]
    # long streaks inside the bands, following the curve
    di = np.clip(ys - top, 0, h - 1).astype(int)
    st = np.repeat(fbm(w // 8 + 1, h, [6, 3], 72, False, False), 8, axis=1)[:, :w]
    st = st[di, xs.astype(int)]
    deep = (ys - top) > 9
    tone = np.where(deep & (st > 0.66), tone + 1, tone)
    tone = np.where(deep & (st < 0.3), tone - 1, tone)
    # a storm oval
    ex, ey = (xs - 318.0) / 24.0, (ys - top - 40.0) / 5.5
    e = ex * ex + ey * ey
    tone = np.where(e < 1.0, 1, tone)
    tone = np.where(e < 0.62, 4, tone)
    tone = np.where((e < 0.3) & (ey < 0.1), 5, tone)
    tone = np.where((np.abs(ey + 0.1) < 0.14) & (e < 0.5) & (ex > -0.4), 3, tone)
    tone = np.clip(tone, 0, 5)
    # night side toward the right, in flat steps
    sh = (xs - 0.62 * w) / (0.20 * w) + (ys - top) / 500.0 + B * 0.035
    lvl = np.searchsorted([0.0, 0.33, 0.66, 1.0], sh)
    mult = np.array([[1, 1, 1], [0.7, 0.62, 0.66], [0.46, 0.4, 0.52], [0.28, 0.25, 0.42], [0.15, 0.14, 0.3]])
    base = ramp(*TAN)[..., :3].astype(np.float64)
    table = np.clip(base[None, :, :] * mult[:, None, :] + np.array([4, 5, 14])[None, None, :] * (mult[:, None, :1] < 1), 0, 255)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = table[lvl, tone].astype(np.uint8)
    img[..., 3] = 255
    # haze glowing above the limb
    dr = ys - top
    glow_a = np.array([1.0, 0.8, 0.55, 0.3, 0.15])[lvl]
    for lo, hi, col, a in ((-1.0, 0.0, "f6e6b8", 170), (-3.0, -1.0, "e8c98a", 80), (-6.0, -3.0, "d4a85a", 36)):
        m = (dr >= lo) & (dr < hi)
        img[m, :3] = hexc(col)[:3]
        img[..., 3] = np.where(m, (a * glow_a).astype(np.uint8), img[..., 3])
    img[dr < -6.0] = 0
    return img


def wisps():
    """Cloud streaks that drift along the bands: 4 light and 4 dark shapes, 64 x 5 each."""
    rng = np.random.default_rng(73)
    sheet = np.zeros((40, 64, 4), dtype=np.uint8)
    for k in range(8):
        c0, c1 = (hexc("f6e6b8"), hexc("e8c98a")) if k < 4 else (hexc("8a6428"), hexc("b8863c"))
        ln = int(rng.integers(26, 62))
        x0 = (64 - ln) // 2
        fat = int(rng.choice([1, 2, 2]))
        for x in range(ln):
            th = 1 + int(round(np.sin(np.pi * x / (ln - 1)) * fat))
            y = 2 + int(round(np.sin(x * 0.11 + k) * 0.8))
            for j in range(th):
                yy = k * 5 + min(4, max(0, y - th // 2 + j))
                sheet[yy, x0 + x] = c0 if j == 0 else c1
    return sheet


# ------------------------------------------------------------------ rings

ICE3 = [hexc("f0f6ff"), hexc("a8c0d8"), hexc("5a6a80")]


def chunk(rng, s):
    """One ice chunk, s px across, lit from the upper left, no outline (background detail)."""
    img = np.zeros((s, s, 4), dtype=np.uint8)
    if s <= 2:
        img[0, 0] = ICE3[int(rng.integers(0, 2))]
        if s == 2:
            img[0, 1] = ICE3[1]
            img[1, 0] = ICE3[1]
            img[1, 1] = ICE3[2]
        return img
    c = (s - 1) / 2.0
    p = rng.uniform(1.1, 1.9)
    sq = rng.uniform(0.7, 1.0)
    rot = rng.uniform(0, np.pi)
    for y in range(s):
        for x in range(s):
            dx, dy = (x - c) / (s / 2.0), (y - c) / (s / 2.0)
            rx, ry = dx * np.cos(rot) + dy * np.sin(rot), (-dx * np.sin(rot) + dy * np.cos(rot)) / sq
            if abs(rx) ** p + abs(ry) ** p <= 1.0:
                lit = -(dx + dy)
                img[y, x] = ICE3[0] if lit > 0.35 else (ICE3[1] if lit > -0.45 else ICE3[2])
    return img


def band_rows(h, rng, tones, alphas, lo, hi, edge):
    """Thin flat ring bands: per row a colour and an alpha, fading in steps at the top and bottom."""
    rows = np.zeros((h, 4), dtype=np.uint8)
    y = 0
    while y < h:
        th = int(rng.integers(lo, hi + 1))
        a = int(rng.choice(alphas))
        col = tones[int(rng.integers(0, len(tones)))]
        for yy in range(y, min(h, y + th)):
            k = min(yy, h - 1 - yy) / float(edge)
            fade = 0.0 if k < 0.34 else (0.4 if k < 0.67 else (0.7 if k < 1.0 else 1.0))
            rows[yy, :3] = col[:3]
            rows[yy, 3] = int(a * fade)
        y += th + int(rng.integers(0, 3))
    return rows


def ring_layer(w, h, seed, tones, alphas, lo, hi, n_chunks, sizes, chunk_alpha, edge=10, speck=0):
    rng = np.random.default_rng(seed)
    rows = band_rows(h, rng, tones, alphas, lo, hi, edge)
    img = np.repeat(rows[:, None, :], w, axis=1)
    # break the bands into long dashes so they do not look ruled
    brk = fbm(w, h, [160, 80, 40], seed + 1, True, False)
    brk = np.repeat(brk[::3, :], 3, axis=0)[:h]
    img[..., 3] = np.where(brk > 0.36, img[..., 3], (img[..., 3] * 0.45).astype(np.uint8))
    img[..., 3] = np.where(brk > 0.26, img[..., 3], 0)
    for _ in range(speck):
        x, y = int(rng.integers(0, w)), int(np.clip(rng.normal(h / 2, h / 4.5), 2, h - 3))
        img[y, x] = (*tones[int(rng.integers(0, len(tones)))][:3], chunk_alpha)
    for _ in range(n_chunks):
        s = int(rng.choice(sizes))
        c = chunk(rng, s)
        x, y = int(rng.integers(0, w)), int(np.clip(rng.normal(h / 2, h / 5.0), 1, h - s - 1))
        for yy in range(s):
            for xx in range(s):
                if c[yy, xx, 3]:
                    img[y + yy, (x + xx) % w] = (*c[yy, xx, :3], chunk_alpha)
    return img


def ring_near(w=800, h=132):
    """Grit between the camera and the play layer: sparse dark chunks, out of the light, no bands."""
    img = ring_layer(w, h, 94, ICE3, [0], 2, 7, 34, [3, 4, 4, 5, 6, 7], 255, 9, 0)
    for src, dst in zip(ICE3, ("3a4a70", "1c2644", "0c1020")):
        m = (img[..., :3] == src[:3]).all(axis=2) & (img[..., 3] > 0)
        img[m, :3] = hexc(dst)[:3]
    return img


def ring_arcs(w=820, h=120):
    """The far rings sweeping across the sky behind: fine concentric arcs with the Cassini gap."""
    rng = np.random.default_rng(81)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    R = 2600.0
    top = 8 + R - np.sqrt(R * R - (xs - w * 0.42) ** 2)
    d = ys - top
    prof = np.zeros(64)
    cols = np.zeros((64, 3), dtype=np.uint8)
    y = 0
    while y < 64:
        th = int(rng.integers(1, 4))
        a = int(rng.choice([0, 18, 26, 34, 44]))
        if 20 <= y < 26 or y > 56:
            a = 0                                              # Cassini division, outer edge
        prof[y:y + th] = a
        cols[y:y + th] = hexc(str(rng.choice(["a8c0d8", "c8c0ac", "7c8ca4"])))[:3]
        y += th
    di = np.clip(d, 0, 63).astype(int)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = cols[di]
    fade = np.clip((w * 0.86 - xs - ys * 0.6) / 60.0, 0, 1)   # Saturn's shadow swallows the right end
    fade = np.clip(np.floor(fade * 4 + bayer(h, w) * 0.6) / 4.0, 0, 1)
    img[..., 3] = np.where((d >= 0) & (d < 64), prof[di] * fade, 0).astype(np.uint8)
    return img


def shadow(w=700, h=128):
    """Saturn's shadow lying across the ring plane: a slanted, stepped edge, then full shade."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    B = bayer(h, w)
    lvl = np.clip(np.floor((xs - (h - ys) * 0.35 + B * 5.0) / 26.0), 0, 3)
    edge = np.minimum(ys, h - 1 - ys) / 5.0
    lvl = np.minimum(lvl, np.clip(np.floor(edge + B * 0.8), 0, 3))
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = hexc("060816")[:3]
    img[..., 3] = (lvl * 52).astype(np.uint8)
    return img


# ------------------------------------------------------------------ small sprites

CRY = {"o": hexc("0f3a6a"), "d": hexc("1d8fc8"), "c": hexc("4fd6ff"), "l": hexc("b8f4ff"), "w": hexc("ffffff")}
CRYSTALS = [
    ["....o....", "...owo...", "...olco..", "..owlcdo.", "..owlcdo.", ".owllcdo.", ".owlccdo.", ".owlccddo",
     ".olccdddo", "..occddo.", "..ocddo..", "...odo...", "....o...."],
    [".....o.......", "....owo......", "....olco..o..", "...owlcdoowo.", "...owlcdoolco", ".o.owlccdolco",
     "owoowlccdoldo", "olcoolccddodo", "olcdolcdddoo.", ".oddooccddo..", "..ooo.oddo...", ".......oo...."],
    ["...ooooo...", "..owwlllo..", ".owlllccdo.", "owllccccddo", "olcccccdddo", ".occccdddo.", "..occdddo..",
     "...ocddo...", "....odo....", ".....o....."],
]
GEM = ["...ooo...", "..owllo..", ".owlccdo.", "owlcccddo", "olccccddo", ".occcddo.", "..ocddo..", "...odo...", "....o...."]


def crystals():
    """3 crystal shapes x 4 frames (frame 0 plain, 1-3 a glint sweeping across), 15 x 15 cells."""
    up = {"d": "c", "c": "l", "l": "w", "w": "w", "o": "o"}
    sheet = np.zeros((45, 60, 4), dtype=np.uint8)
    for v, rows in enumerate(CRYSTALS):
        h, w = len(rows), len(rows[0])
        for f in range(4):
            rr = []
            for y, row in enumerate(rows):
                line = ""
                for x, ch in enumerate(row):
                    hit = f > 0 and ch != "." and abs((x + y) - (f * (w + h) / 4.0 - 1)) < 1.5
                    line += up[ch] if hit else ch
                rr.append(line)
            sheet[v * 15:(v + 1) * 15, f * 15:(f + 1) * 15] = centre(ascii_sprite(rr, CRY), 15, 15)
    return sheet


def moons():
    """Titan (orange, hazy) and Enceladus (white, with its south-pole plume; 2 frames)."""
    t = np.zeros((17, 17, 4), dtype=np.uint8)
    for y in range(17):
        for x in range(17):
            dx, dy = x - 8, y - 8
            r = np.hypot(dx, dy)
            lit = -(dx + dy) / 8.0
            if r <= 5.6:
                t[y, x] = hexc("f0a850") if lit > 0.5 else (hexc("d07a2a") if lit > -0.3 else hexc("7a3c14"))
            elif r <= 6.7:
                t[y, x] = hexc("f6c070", 150) if lit > -0.2 else hexc("9a5a2a", 110)
            elif r <= 7.8 and lit > 0.2:
                t[y, x] = hexc("f6c070", 50)
    e = np.zeros((14, 22, 4), dtype=np.uint8)
    disc = ["..www..", ".wwwwl.", "wwwwlls", "wwwllls", "wwlllss", ".lllss.", "..sss.."]
    col = {"w": hexc("ffffff"), "l": hexc("c4dcf0"), "s": hexc("6a86a8")}
    plume = [[(3, 7), (3, 8), (2, 9), (4, 9), (3, 10), (1, 11), (5, 11), (3, 12)],
             [(3, 7), (2, 8), (4, 8), (3, 9), (1, 10), (5, 10), (2, 12), (4, 12), (3, 13)]]
    for f in range(2):
        e[0:7, f * 11:f * 11 + 7] = ascii_sprite(disc, col)
        for i, (x, y) in enumerate(plume[f]):
            e[y, f * 11 + x] = hexc("b8e4ff", 230 - i * 22)
    return t, e


def arrow():
    """A chunky arrow pointing right and one pointing left, white so the game tints them."""
    m = poly_mask(17, 13, [(0, 4), (8, 4), (8, 0), (16, 6), (8, 12), (8, 8), (0, 8)])
    a = shaded(m, hexc("ffffff"), hexc("e4e8f4"), hexc("9aa4c0"))
    return np.concatenate([a, a[:, ::-1]], axis=1)


def chevron():
    m = poly_mask(11, 6, [(5, 0), (10, 5), (8, 5), (5, 2), (2, 5), (0, 5)])
    img = np.zeros((6, 11, 4), dtype=np.uint8)
    img[m] = hexc("ffffff")
    return img


def brackets():
    """Four red warning corners in a 2 x 2 sheet of 7 x 7 cells."""
    c = np.zeros((7, 7, 4), dtype=np.uint8)
    c[1:3, 1:6] = hexc("ff5a5a")
    c[1:6, 1:3] = hexc("ff5a5a")
    c[1, 1:6] = hexc("ffb0a0")
    c = outline(c)
    sheet = np.zeros((14, 14, 4), dtype=np.uint8)
    sheet[0:7, 0:7] = c
    sheet[0:7, 7:14] = c[:, ::-1]
    sheet[7:14, 0:7] = c[::-1, :]
    sheet[7:14, 7:14] = c[::-1, ::-1]
    return sheet


def lamps():
    """5 x 5 lamps: off, green, red."""
    sheet = np.zeros((5, 15, 4), dtype=np.uint8)
    for i, (hi, mid, lo) in enumerate((("3a4460", "262e48", "181e32"), ("e4ffe8", "6dff8a", "1c8a44"),
                                       ("ffe0d0", "ff5a5a", "8c1e22"))):
        b = np.zeros((3, 3, 4), dtype=np.uint8)
        b[...] = hexc(mid)
        b[0, 0] = hexc(hi)
        b[2, 2] = hexc(lo)
        if i:
            b[1, 1] = hexc(hi)
        sheet[:, i * 5:(i + 1) * 5] = outline(pad(b))
    return sheet


def icons():
    """HUD icons, 11 x 11 cells: nitrogen bottle, shield full, shield empty, gem full, gem empty, warning, gravity."""
    # the drone's cold-gas thrusters blow compressed nitrogen (like NASA's MMU), so its tank is a pale gas bottle, not a fuel drop
    fuel = ascii_sprite(["...ooo...", "..owwwo..", "...owo...", "..ooooo..", ".obllldo.", ".obllldo.", ".obllldo.",
                         ".obllldo.", ".obllldo.", "..ooooo.."],
                        {"o": OL, "w": hexc("c8ccd8"), "b": hexc("eef6ff"), "l": hexc("a8d0f0"), "d": hexc("5a86b0")})
    sh = [".ooooooo.", "owwlllllo", "owlccccdo", "owlccccdo", "olccccddo", "olcccdddo", ".occcddo.", ".occdddo.",
          "..ocddo..", "...ooo..."]
    full = ascii_sprite(sh, {"o": OL, "w": hexc("e4ffe8"), "l": hexc("a8ffb8"), "c": hexc("48d06a"), "d": hexc("1c8a44")})
    dk = {"o": hexc("2c3658"), "w": hexc("1a2036"), "l": hexc("1a2036"), "c": hexc("141a2e"), "d": hexc("10152a")}
    warn = ascii_sprite([".....o.....", "....oyo....", "...oyyyo...", "...oyoyo...", "..oyyoyyo..", "..oyyoyyo..",
                         ".oyyyyyyyo.", ".oyyyoyyyo.", "oyyyyyyyyyo", ".ooooooooo."],
                        {"o": OL, "y": hexc("ff5a5a")})
    grav = ascii_sprite(["...ooo...", "...oco...", "...oco...", "...oco...", "oooocoooo", "occcccccd", ".occccdo.",
                         "..occdo..", "...odo...", "....o...."],
                        {"o": OL, "c": hexc("ffd75e"), "d": hexc("b3812a")})
    cells = [fuel, full, ascii_sprite(sh, dk), ascii_sprite(GEM, CRY), ascii_sprite(GEM, dk), warn, grav]
    sheet = np.zeros((11, 11 * len(cells), 4), dtype=np.uint8)
    for i, c in enumerate(cells):
        sheet[:, i * 11:(i + 1) * 11] = centre(c, 11, 11)
    return sheet


def keys():
    """Key caps 13 x 13: left, up, right arrows and a blank cap."""
    sheet = np.zeros((13, 52, 4), dtype=np.uint8)
    glyph = {"l": ["..#..", ".##..", "#####", ".##..", "..#.."], "u": ["..#..", ".###.", "#####", "..#..", "..#.."],
             "r": ["..#..", "..##.", "#####", "..##.", "..#.."], "b": []}
    for i, k in enumerate("lurb"):
        c = np.zeros((13, 13, 4), dtype=np.uint8)
        c[...] = OL
        c[1:12, 1:12] = hexc("6a7290")
        c[1:9, 2:11] = hexc("d6dcea")
        c[1, 2:11] = hexc("f4f6fb")
        c[9, 2:11] = hexc("a3abc4")
        for a, b in ((0, 0), (0, 12), (12, 0), (12, 12)):
            c[a, b] = 0
        for y, row in enumerate(glyph[k]):
            for x, ch in enumerate(row):
                if ch == "#":
                    c[2 + y, 4 + x] = hexc("1e2232")
        sheet[:, i * 13:(i + 1) * 13] = c
    return sheet


def plate():
    """9-slice cockpit plate, 16 x 16 with 4 px borders: metal bezel around dark glass."""
    c = np.zeros((16, 16, 4), dtype=np.uint8)
    c[...] = OL
    c[1:15, 1:15] = hexc("4e5566")
    c[1, 1:15] = hexc("7d8697")
    c[1:15, 1] = hexc("7d8697")
    c[14, 1:15] = hexc("2a2e3a")
    c[2:15, 14] = hexc("2a2e3a")
    c[3:13, 3:13] = hexc("0a0e1c", 235)
    c[3, 3:13] = hexc("05070e", 245)
    c[12, 3:13] = hexc("161c34", 235)
    for a, b in ((0, 0), (0, 15), (15, 0), (15, 15)):
        c[a, b] = 0
    return c


def gauge():
    """Fuel cell segment 4 x 6 (3 px lit, 1 px gap) in three colours: orange, red, empty."""
    sheet = np.zeros((6, 12, 4), dtype=np.uint8)
    for i, (hi, mid, lo) in enumerate((("ffd75e", "ff9f43", "b4501a"), ("ffb0a0", "ff5a5a", "8c1e22"),
                                       ("1c2440", "141a2e", "0e1222"))):
        sheet[0, i * 4:i * 4 + 3] = hexc(hi)
        sheet[1:5, i * 4:i * 4 + 3] = hexc(mid)
        sheet[5, i * 4:i * 4 + 3] = hexc(lo)
    return sheet


def debris():
    """Pieces of the drone for the crash: 4 cells of 9 x 9."""
    cols = {"o": OL, "w": hexc("f4f6fb"), "p": hexc("a3abc4"), "g": hexc("dcae44"), "h": hexc("7c5418"),
            "j": hexc("2e3448"), "k": hexc("121420"), "r": hexc("d03a30"), "m": hexc("b4bcc8")}
    cells = [[".ooo...", "owwpo..", "owppo..", ".oppoo.", "..oppo.", "...oo.."],
             ["..ooo.", ".oggho", "ogghho", "oghho.", ".ooo.."],
             [".oooo.", "ojjjko", "ojrkko", "ojkkko", ".oooo."],
             ["oo.....", "ommo...", ".ommo..", "..ommo.", "...ommo", "....oo."]]
    sheet = np.zeros((9, 36, 4), dtype=np.uint8)
    for i, c in enumerate(cells):
        sheet[:, i * 9:(i + 1) * 9] = centre(ascii_sprite(c, cols), 9, 9)
    return sheet


def gen_2d():
    save(planet(), "planet.png")
    save(wisps(), "wisps.png")
    cool = [hexc("a8c0d8"), hexc("d8d0c0"), hexc("7c8ca4")]
    far = [hexc("7c8ca4"), hexc("5a6a80"), hexc("8c8c98")]
    save(ring_layer(640, 112, 91, far, [0, 22, 30, 40, 50], 1, 3, 0, [1], 120, 14, 520), "ring_far.png")
    save(ring_layer(640, 98, 92, cool, [0, 0, 26, 36, 46], 1, 4, 300, [1, 1, 2, 2, 3], 150, 12, 200), "ring_back.png")
    save(ring_layer(640, 88, 93, cool, [0, 0, 34, 48, 62, 76], 2, 7, 170, [2, 2, 3, 3, 4, 5, 6], 235, 9, 120), "ring_mid.png")
    save(ring_near(), "ring_near.png")
    save(ring_arcs(), "ring_arcs.png")
    save(shadow(), "shadow.png")
    save(crystals(), "crystal.png")
    t, e = moons()
    save(t, "titan.png")
    save(e, "enceladus.png")
    save(arrow(), "arrow.png")
    save(chevron(), "chevron.png")
    save(brackets(), "brackets.png")
    save(lamps(), "lamps.png")
    save(icons(), "icons.png")
    save(keys(), "keys.png")
    save(plate(), "plate.png")
    save(gauge(), "gauge.png")
    save(debris(), "debris.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "3d"):
        gen_3d()
    if what in ("all", "2d"):
        gen_2d()
    if what == "icons":
        save(icons(), "icons.png")
