"""Ring-drone art for Jupiter, Uranus and Neptune (scripts/screens/probe.gd) -> art/probe/<skin>_<name>.png.

    python tools/art/gen_giants.py                 all three skins
    python tools/art/gen_giants.py uranus          one skin

Same file set, sizes and anchors as Saturn's unprefixed files made by tools/art/gen_probe.py, so the
screen swaps worlds by putting "<skin>_" in front of each name. Mapping: research/v5/giants.md.
The planet keeps Saturn's limb arc (940 x 100, limb radius 4614 px, top at y 14), so probe.gd's _limb()
and the wisp maths stay valid. Rocks and the foreground boulders are recoloured from Saturn's sheets.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_probe as gp  # noqa: E402
from gen_bg import fbm, hexc, ramp  # noqa: E402
from gen_probe import (CRYSTALS, PLANET_H, PLANET_W, ascii_sprite, bayer, band_rows, centre,  # noqa: E402
                       limb_top, ring_layer)

OUT = gp.OUT
SKINS = ("jupiter", "uranus", "neptune")


def save(img, name):
    Image.fromarray(img).save(os.path.join(OUT, name))
    print(name, img.shape[1], "x", img.shape[0])


def H(*hs):
    return [hexc(h) for h in hs]


# ------------------------------------------------------------------ per-world looks

LOOK = {
    "jupiter": {
        "night": [4, 2, 12], "haze": ("fff0d0", "f0dcb0", "d8b888"), "glow": "b48cff",
        "chunk": H("d8b898", "8a6450", "402a24"),
        "far": H("5a4038", "6e5044", "4a3a3a"), "back": H("8a6450", "a07a5a", "6a5048"),
        "mid": H("b08870", "c8a080", "7a5a4a"),
        "near": H("2a1a14", "1a100c", "0c0806"),
        "rock": ("1e1412", "40281e", "6a4632", "9a6e50", "d0a888"), "ice": ("6a4424", "a06a34", "d09a58", "f4d098"),
        "boulder": ("0c0706", "140c0a", "1e1410", "2c1e18", "060403"),
        "cry": {"o": hexc("4a1a08"), "d": hexc("b0501c"), "c": hexc("f49040"), "l": hexc("ffd49a"), "w": hexc("ffffff")},
        "shadow": "0a0608",
    },
    "uranus": {
        "night": [4, 8, 14], "haze": ("e4fbfb", "b8eeee", "8cd6d8"), "glow": None,
        "chunk": H("7a7e8a", "3e404a", "1c1e26"),
        "near": H("3a3e48", "1e2028", "0c0d12"),
        "rock": ("121216", "22222a", "363640", "525260", "7a7a88"), "ice": ("1e2634", "2e3c52", "4a5e7a", "7a90b0"),
        "boulder": ("060709", "0c0d11", "14161c", "202430", "040507"),
        "cry": {"o": hexc("10162a"), "d": hexc("34466e"), "c": hexc("6e8cc4"), "l": hexc("bcd4f4"), "w": hexc("ffffff")},
        "shadow": "05070c",
    },
    "neptune": {
        "night": [2, 4, 18], "haze": ("cfe4ff", "8cbcf4", "4c88de"), "glow": None,
        "chunk": H("c0a8a8", "6a5458", "2e2428"),
        "far": H("4a3c44", "54444c", "3c343e"), "back": H("6a5460", "7a6068", "5a4a54"),
        "mid": H("8a7078", "9a7c80", "6a585e"),
        "near": H("2a2030", "18121e", "0a080e"),
        "rock": ("1a1216", "30242a", "4a383e", "6a5258", "94787a"), "ice": ("3e2a3a", "6a4a64", "a07898", "d0b0c8"),
        "boulder": ("06071a", "0c0e26", "141a3a", "1e2650", "050612"),
        "cry": {"o": hexc("3a1238"), "d": hexc("a04a90"), "c": hexc("e88ad0"), "l": hexc("ffd4f2"), "w": hexc("ffffff")},
        "shadow": "04061a",
    },
}


# ------------------------------------------------------------------ the planet below the rings

def _deck_base(skin, xs, ys, top, B):
    """Day-side colour of the cloud deck (h x w x 3, float) before the night steps."""
    h, w = ys.shape
    dep = ys - top
    dd = np.clip(dep + B * 2.4, 0, None)
    u = np.log1p(dd / 5.0)                                    # depth below the limb, squeezed toward it
    di = np.clip(dep, 0, h - 1).astype(int)
    if skin == "jupiter":
        wob = fbm(w, h, [140, 70, 35, 16], 171, False, False) - 0.5
        turb = fbm(w // 4 + 1, h, [10, 5, 3], 172, False, False)
        turb = np.repeat(turb, 4, axis=1)[:, :w][di, xs.astype(int)] - 0.5
        uu = u + wob * (0.06 + 0.05 * np.log1p(dd / 5.0)) + turb * 0.09 * (dep > 6)
        edges = [0.22, 0.5, 0.78, 1.05, 1.32, 1.56, 1.8, 2.02, 2.24, 2.46, 2.66, 2.86]
        # 0 = zone (cream), 1 = belt (rust); a level on each ramp
        kind = np.array([0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1])[np.searchsorted(edges, uu)]
        lvl = np.array([4, 3, 5, 2, 4, 3, 2, 4, 3, 4, 2, 3, 2])[np.searchsorted(edges, uu)]
        st = np.repeat(fbm(w // 6 + 1, h, [8, 4], 173, False, False), 6, axis=1)[:, :w][di, xs.astype(int)]
        lvl = np.where((dep > 5) & (st > 0.64), lvl + 1, lvl)
        lvl = np.where((dep > 5) & (st < 0.32), lvl - 1, lvl)
        Z = ramp("4a3a2c", "7a6448", "a88e6a", "ccb48c", "e6d4ae", "f8eed6", "fffaf0")
        Bl = ramp("3a1a10", "5e2c18", "864222", "a85c30", "c47e4c", "dca476", "ecc49c")
        lvl = np.clip(lvl, 0, 6)
        rgb = np.where((kind == 1)[..., None], Bl[lvl][..., :3], Z[lvl][..., :3]).astype(np.float64)
        # white ovals in a southern belt
        for ox, od in ((180, 52), (560, 50), (760, 54), (860, 60)):
            ex, ey = (xs - ox) / 7.0, (dep - od) / 2.2
            e = ex * ex + ey * ey
            rgb[e < 1.0] = hexc("e6d4ae")[:3]
            rgb[e < 0.45] = hexc("fffaf0")[:3]
        # the Great Red Spot with its pale collar
        ex, ey = (xs - 392.0) / 34.0, (dep - 46.0) / 7.5
        e = ex * ex + ey * ey + 0.1 * np.sin(np.arctan2(ey, ex) * 3)
        rgb[e < 1.35] = hexc("f6e8cc")[:3]
        rgb[e < 1.0] = hexc("b8482a")[:3]
        rgb[e < 0.72] = hexc("d06438")[:3]
        rgb[e < 0.4] = hexc("e48450")[:3]
        rgb[(e < 0.4) & (ey < -0.15) & (ex < 0.2)] = hexc("f0a070")[:3]
        rgb[(e < 0.16)] = hexc("c45632")[:3]
        rgb[(e >= 1.0) & (e < 1.12) & (ey > 0)] = hexc("a86a48")[:3]
        return rgb
    if skin == "uranus":
        R = ramp("1a5058", "2e7c84", "56a8ac", "7cc4c4", "a2dcda", "c8eeec", "e4fbfa")
        wob = fbm(w, h, [200, 100], 271, False, False) - 0.5
        uu = u + wob * 0.04
        edges = [0.25, 0.7, 1.6, 2.3, 2.75]
        lvl = np.array([6, 5, 4, 3, 4, 3])[np.searchsorted(edges, uu)]
        st = np.repeat(fbm(w // 10 + 1, h, [8, 4], 273, False, False), 10, axis=1)[:, :w][di, xs.astype(int)]
        lvl = np.where((dep > 10) & (st > 0.8), lvl + 1, lvl)
        lvl = np.clip(lvl, 0, 5)                               # only the limb haze reaches the top tone
        rgb = R[lvl][..., :3].astype(np.float64)
        # two small bright methane clouds, the only weather Voyager 2 saw
        for ox, od, a, b in ((300, 34, 9, 1.6), (700, 58, 6, 1.3)):
            ex, ey = (xs - ox) / a, (dep - od) / b
            rgb[ex * ex + ey * ey < 1.0] = hexc("f4ffff")[:3]
        return rgb
    # neptune
    R = ramp("0e1e58", "183888", "2a5cba", "3c74cc", "4c88de", "70a8ec", "a6ccf8")
    wob = fbm(w, h, [160, 80, 40], 371, False, False) - 0.5
    uu = u + wob * (0.05 + 0.04 * np.log1p(dd / 5.0))
    edges = [0.2, 0.55, 1.0, 1.5, 1.9, 2.3, 2.7]
    lvl = np.array([6, 5, 4, 3, 4, 2, 3, 2])[np.searchsorted(edges, uu)]
    st = np.repeat(fbm(w // 8 + 1, h, [8, 4], 373, False, False), 8, axis=1)[:, :w][di, xs.astype(int)]
    lvl = np.where((dep > 8) & (st > 0.68), lvl + 1, lvl)
    lvl = np.where((dep > 8) & (st < 0.3), lvl - 1, lvl)
    lvl = np.clip(lvl, 0, 6)
    rgb = R[lvl][..., :3].astype(np.float64)
    # the Great Dark Spot with the bright companion cloud on its rim (Voyager 2, 1989)
    ex, ey = (xs - 360.0) / 30.0, (dep - 44.0) / 6.5
    e = ex * ex + ey * ey
    rgb[e < 1.0] = hexc("12285e")[:3]
    rgb[e < 0.55] = hexc("0a1a48")[:3]
    rgb[(e >= 1.0) & (e < 1.25) & (ey < 0)] = hexc("2a5cba")[:3]
    cx, cy = (xs - 380.0) / 14.0, (dep - 36.0) / 1.6
    rgb[cx * cx + cy * cy < 1.0] = hexc("ffffff")[:3]
    # long white methane streaks high in the air
    for ox, od, ln in ((150, 22, 70), (540, 30, 90), (640, 60, 60), (820, 26, 80)):
        ex, ey = (xs - ox) / ln, (dep - od - 2.0 * np.sin((xs - ox) * 0.04))
        m = (np.abs(ex) < 1.0) & (np.abs(ey) < (1.0 - ex * ex) * 1.6)
        rgb[m] = hexc("e6f2ff")[:3]
        rgb[m & (ey < -0.6)] = hexc("ffffff")[:3]
    return rgb


def planet(skin):
    """Cloud tops below the rings: same limb arc and night side as Saturn's, the world's own colours."""
    L = LOOK[skin]
    w, h = PLANET_W, PLANET_H
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    top = limb_top(xs)
    B = bayer(h, w)
    rgb = _deck_base(skin, xs, ys, top, B)
    sh = (xs - 0.62 * w) / (0.20 * w) + (ys - top) / 500.0 + B * 0.035
    lvl = np.searchsorted([0.0, 0.33, 0.66, 1.0], sh)
    mult = np.array([[1, 1, 1], [0.7, 0.62, 0.66], [0.46, 0.4, 0.52], [0.28, 0.25, 0.42], [0.15, 0.14, 0.3]])[lvl]
    add = np.array(L["night"])[None, None, :] * (mult[..., :1] < 1)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = np.clip(rgb * mult + add, 0, 255).astype(np.uint8)
    img[..., 3] = 255
    dr = ys - top
    glow_a = np.array([1.0, 0.8, 0.55, 0.3, 0.15])[lvl]
    c0, c1, c2 = L["haze"]
    for lo, hi, col, a in ((-1.0, 0.0, c0, 170), (-3.0, -1.0, c1, 80), (-6.0, -3.0, c2, 36)):
        m = (dr >= lo) & (dr < hi)
        img[m, :3] = hexc(col)[:3]
        img[..., 3] = np.where(m, (a * glow_a).astype(np.uint8), img[..., 3])
    img[dr < -6.0] = 0
    if L["glow"]:
        # Jupiter's radiation belts: a faint violet sheen hanging over the limb, in flat steps
        g = np.floor(np.clip(1.0 - (-dr - 6.0) / 16.0, 0, 1) * 3 + B * 0.7) / 3.0
        m = (dr < -6.0) & (g > 0)
        img[m, :3] = hexc(L["glow"])[:3]
        img[m, 3] = (g[m] * 34 * glow_a[m]).astype(np.uint8)
    return img


def wisps(skin):
    """8 drifting cloud streaks, 64 x 5 each: rows 0-3 light, 4-7 dark (Saturn's layout)."""
    cols = {"jupiter": (("fffaf0", "e6d4ae"), ("864222", "a85c30")),
            "uranus": (("f4ffff", "c8eeec"), ("56a8ac", "7cc4c4")),
            "neptune": (("ffffff", "e6f2ff"), ("0e1e58", "183888"))}[skin]
    rng = np.random.default_rng(73)
    sheet = np.zeros((40, 64, 4), dtype=np.uint8)
    for k in range(8):
        c0, c1 = (hexc(cols[0][0]), hexc(cols[0][1])) if k < 4 else (hexc(cols[1][0]), hexc(cols[1][1]))
        ln = int(rng.integers(26, 62))
        if skin == "uranus":
            ln = max(16, ln // 2)                              # Uranus barely has weather
        x0 = (64 - ln) // 2
        fat = int(rng.choice([1, 2, 2]))
        for x in range(ln):
            th = 1 + int(round(np.sin(np.pi * x / (ln - 1)) * fat))
            y = 2 + int(round(np.sin(x * 0.11 + k) * 0.8))
            for j in range(th):
                yy = k * 5 + min(4, max(0, y - th // 2 + j))
                sheet[yy, x0 + x] = c0 if j == 0 else c1
    return sheet


# ------------------------------------------------------------------ ring layers

def _layer(skin, w, h, seed, tones, alphas, lo, hi, n_chunks, sizes, chunk_alpha, edge, speck):
    gp.ICE3 = LOOK[skin]["chunk"]       # gen_probe.chunk() reads this module global for its 3 tones
    try:
        return ring_layer(w, h, seed, tones, alphas, lo, hi, n_chunks, sizes, chunk_alpha, edge, speck)
    finally:
        gp.ICE3 = SATURN_ICE3


SATURN_ICE3 = gp.ICE3


def _thin_rings(w, h, seed, rows_spec, chunks, sizes, chunk_alpha, skin):
    """Uranus: a few narrow, sharp rings with empty space between, then a sprinkle of coal-dark chunks."""
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    for y, th, col, a in rows_spec:
        for k in range(th):
            img[y + k, :, :3] = hexc(col)[:3]
            img[y + k, :, 3] = a if k in (0, th - 1) or th < 3 else min(255, a + 30)
    brk = fbm(w, h, [200, 100, 50], seed + 1, True, False)
    img[..., 3] = np.where(brk > 0.32, img[..., 3], (img[..., 3] * 0.55).astype(np.uint8))
    gp.ICE3 = LOOK[skin]["chunk"]
    try:
        for _ in range(chunks):
            s = int(rng.choice(sizes))
            c = gp.chunk(rng, s)
            y0, th = rows_spec[int(rng.integers(0, len(rows_spec)))][:2]
            x, y = int(rng.integers(0, w)), int(np.clip(y0 + th // 2 - s // 2 + rng.integers(-2, 3), 0, h - s))
            for yy in range(s):
                for xx in range(s):
                    if c[yy, xx, 3]:
                        img[y + yy, (x + xx) % w] = (*c[yy, xx, :3], chunk_alpha)
    finally:
        gp.ICE3 = SATURN_ICE3
    return img


def _arcs_clumps(img, y, th, seed, col_hi, col_mid, n=4):
    """Neptune's Adams ring arcs: bright clumped stretches along an otherwise faint thin ring."""
    rng = np.random.default_rng(seed)
    h, w = img.shape[:2]
    for i in range(n):
        x0 = int(rng.integers(0, w))
        ln = int(rng.integers(50, 130))
        for x in range(ln):
            k = np.sin(np.pi * x / ln)
            if k < 0.25 or rng.random() > 0.55 + 0.45 * k:
                continue
            xx = (x0 + x) % w
            for yy in range(y - (1 if k > 0.7 else 0), y + th + (1 if k > 0.7 else 0)):
                img[yy, xx, :3] = hexc(col_hi if k > 0.6 and rng.random() < 0.6 else col_mid)[:3]
                img[yy, xx, 3] = int(150 + 90 * k)
    return img


def ring_set(skin):
    """ring_far (640x112), ring_back (640x98), ring_mid (640x88), ring_near (800x132)."""
    L = LOOK[skin]
    if skin == "jupiter":
        # a faint dusty sheet: very few solid bands, lots of fine specks
        far = _layer(skin, 640, 112, 191, L["far"], [0, 0, 14, 20, 26], 1, 3, 0, [1], 90, 14, 900)
        back = _layer(skin, 640, 98, 192, L["back"], [0, 0, 0, 16, 24], 1, 3, 90, [1, 1, 2], 120, 12, 500)
        mid = _layer(skin, 640, 88, 193, L["mid"], [0, 0, 0, 20, 30, 38], 2, 6, 60, [2, 2, 3, 3, 4], 220, 9, 380)
    elif skin == "uranus":
        g = ("3a3e48", "4a4e5a", "5e6270", "7a7e8c")
        far = _thin_rings(640, 112, 291, [(18, 1, g[0], 70), (44, 1, g[0], 60), (60, 2, g[1], 80), (88, 1, g[0], 70)],
                          40, [1, 1, 2], 110, skin)
        back = _thin_rings(640, 98, 292, [(14, 1, g[1], 90), (30, 2, g[1], 100), (62, 1, g[1], 80), (80, 1, g[1], 90)],
                           70, [1, 2, 2, 3], 170, skin)
        # the epsilon ring, widest and brightest, runs through the play layer
        mid = _thin_rings(640, 88, 293, [(16, 2, g[2], 120), (40, 1, g[2], 90), (41, 2, g[3], 130), (43, 1, g[2], 90), (68, 2, g[2], 120)],
                          90, [2, 2, 3, 3, 4, 5], 235, skin)
    else:
        far = _layer(skin, 640, 112, 391, L["far"], [0, 0, 16, 22, 28, 34], 2, 5, 0, [1], 100, 14, 420)   # Galle: broad, faint
        back = _layer(skin, 640, 98, 392, L["back"], [0, 0, 0, 20, 28], 1, 3, 160, [1, 1, 2, 2], 150, 12, 220)
        back[46:48, :, :3] = hexc("8a7078")[:3]                                             # Le Verrier: narrow
        back[46:48, :, 3] = np.maximum(back[46:48, :, 3], 70)
        mid = _layer(skin, 640, 88, 393, L["mid"], [0, 0, 0, 0, 24, 32], 1, 3, 130, [2, 2, 3, 3, 4, 5], 230, 9, 160)
        mid[43:45, :, :3] = hexc("7a6068")[:3]                                              # Adams: thin ring...
        mid[43:45, :, 3] = np.maximum(mid[43:45, :, 3], 60)
        mid = _arcs_clumps(mid, 43, 2, 394, "f0e0d8", "c8a8a0")                           # ...with bright arcs
    return far, back, mid, ring_near(skin)


def ring_near(skin, w=800, h=132):
    """Foreground grit, recoloured: Saturn's own generator, then its 3 tones mapped to the world's darks."""
    img = _layer(skin, w, h, 94, LOOK[skin]["chunk"], [0], 2, 7, 34, [3, 4, 4, 5, 6, 7], 255, 9, 0)
    for src, dst in zip(LOOK[skin]["chunk"], LOOK[skin]["near"]):
        m = (img[..., :3] == src[:3]).all(axis=2) & (img[..., 3] > 0)
        img[m, :3] = dst[:3]
    return img


def ring_arcs(skin, w=820, h=120):
    """The far side of the ring system arcing across the sky (Saturn: tools/art/gen_probe.ring_arcs)."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    R = {"jupiter": 2600.0, "uranus": 1300.0, "neptune": 2200.0}[skin]   # Uranus curves hardest: it lies on its side
    top = 8 + R - np.sqrt(R * R - (xs - w * 0.42) ** 2)
    d = ys - top
    prof = np.zeros(64)
    cols = np.zeros((64, 3), dtype=np.uint8)
    if skin == "jupiter":
        for y in range(0, 44):                     # halo: a wide faint sheet, brightening outward
            prof[y] = 6 + y * 0.35
            cols[y] = hexc("6a4a50")[:3]
        prof[44:47] = [40, 52, 40]                  # main ring
        cols[44:47] = hexc("a07860")[:3]
        prof[47:52] = 10
        cols[47:52] = hexc("5a4a58")[:3]            # gossamer
        prof = np.floor(prof / 6.0) * 6.0
    elif skin == "uranus":
        for y, a, c in ((6, 26, "4a4e5a"), (12, 26, "4a4e5a"), (16, 30, "4a4e5a"), (24, 34, "5e6270"),
                        (28, 30, "5e6270"), (33, 30, "5e6270"), (38, 36, "5e6270"), (44, 36, "6a6e7a"),
                        (50, 40, "6a6e7a"), (61, 64, "8a8e9a"), (62, 64, "8a8e9a"), (63, 50, "8a8e9a")):
            prof[y] = a
            cols[y] = hexc(c)[:3]
    else:
        prof[10:22] = 10
        cols[10:22] = hexc("54444c")[:3]            # Galle, faint and broad
        prof[30] = 30
        cols[30] = hexc("8a7078")[:3]               # Le Verrier
        prof[31:38] = 8
        cols[31:38] = hexc("54444c")[:3]            # Lassell sheet
        prof[39] = 22
        cols[39] = hexc("8a7078")[:3]               # Arago
        prof[54] = 26
        cols[54] = hexc("8a7078")[:3]               # Adams
    di = np.clip(d, 0, 63).astype(int)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = cols[di]
    fade = np.clip((w * 0.86 - xs - ys * 0.6) / 60.0, 0, 1)
    fade = np.clip(np.floor(fade * 4 + bayer(h, w) * 0.6) / 4.0, 0, 1)
    a = np.where((d >= 0) & (d < 64), prof[di] * fade, 0)
    if skin == "neptune":                           # the arcs: bright clumps on the Adams ring
        clump = (di == 54) & (d >= 0) & (d < 64) & (((xs > 250) & (xs < 270)) | ((xs > 282) & (xs < 296)) |
                                                       ((xs > 306) & (xs < 330)) | ((xs > 340) & (xs < 348)))
        img[clump, :3] = hexc("e8d0c8")[:3]
        a = np.where(clump, 120 * fade, a)
    img[..., 3] = a.astype(np.uint8)
    return img


def shadow(skin, w=700, h=128):
    img = gp.shadow(w, h)
    img[..., :3] = hexc(LOOK[skin]["shadow"])[:3]
    return img


# ------------------------------------------------------------------ recoloured sheets

def _lum(c):
    return 0.3 * c[0] + 0.55 * c[1] + 0.15 * c[2]


def recolour_rock(img, skin):
    """Map Saturn's grey rock and blue-white ice tones onto the world's own two ramps, by brightness."""
    L = LOOK[skin]
    src_rock = [hexc(h)[:3] for h in ("2a2634", "484252", "6c6470", "968c90", "c6bcb6")]
    src_ice = [hexc(h)[:3] for h in ("46668c", "82aace", "c0e0f4", "f4fbff")]
    dst_rock = np.array([hexc(h)[:3] for h in L["rock"]], dtype=np.float64)
    dst_ice = np.array([hexc(h)[:3] for h in L["ice"]], dtype=np.float64)
    out = img.copy()
    a = img[..., 3] > 0
    cols = np.unique(img[a][:, :3], axis=0)
    for c in cols:
        icy = int(c[2]) - int(c[0]) > 30
        srcs, dsts = (src_ice, dst_ice) if icy else (src_rock, dst_rock)
        xs = [_lum(s) for s in srcs]
        new = [np.interp(_lum(c), xs, dsts[:, k]) for k in range(3)]
        m = a & (img[..., :3] == c).all(axis=2)
        out[m, :3] = np.clip(new, 0, 255).astype(np.uint8)
    return out


def recolour_near(img, skin):
    src = ("070914", "0c1020", "131a30", "1c2644", "060812")
    out = img.copy()
    for s, d in zip(src, LOOK[skin]["boulder"]):
        m = (img[..., :3] == hexc(s)[:3]).all(axis=2) & (img[..., 3] > 0)
        out[m, :3] = hexc(d)[:3]
    return out


def crystals(skin):
    """Saturn's 3 crystal shapes x 4 glint frames, in the world's sample colours."""
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
            sheet[v * 15:(v + 1) * 15, f * 15:(f + 1) * 15] = centre(ascii_sprite(rr, LOOK[skin]["cry"]), 15, 15)
    return sheet


# ------------------------------------------------------------------ moons

def _disc(size, rad, paint):
    """A lit ball: paint(dx, dy, lit, r) -> colour tuple or None. Light from the upper left."""
    img = np.zeros((size, size, 4), dtype=np.uint8)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            r = np.hypot(dx, dy)
            if r <= rad:
                col = paint(dx, dy, -(dx + dy) / rad, r)
                if col is not None:
                    img[y, x] = col
    return img


def big_moon(skin):
    """The 17 x 17 sky moon (Saturn: Titan). Jupiter: Io, Uranus: Miranda, Neptune: Triton."""
    if skin == "jupiter":
        spots = {(-2, -1): "3a1a0a", (1, 2): "7a2a10", (2, -2): "e8e8d0", (-1, 3): "3a1a0a", (3, 1): "a04018"}

        def paint(dx, dy, lit, r):
            if (round(dx), round(dy)) in spots and lit > -0.5:
                return hexc(spots[(round(dx), round(dy))])
            return hexc("fff08a") if lit > 0.55 else (hexc("e8c440") if lit > -0.1 else (hexc("b08420") if lit > -0.6 else hexc("5a3c10")))
    elif skin == "uranus":
        def paint(dx, dy, lit, r):
            tone = 2 if lit > 0.45 else (1 if lit > -0.25 else 0)
            # the chevron and the racetrack coronae: bands of dark and light grooves
            if abs(dx - dy * 0.3 - 0.5) < 0.7 and dy > -2 and tone > 0:
                tone = 3 if tone == 2 else 2
            if abs(np.hypot(dx + 2.5, dy - 1.5) - 2.2) < 0.6 and tone > 0:
                tone -= 1
            return hexc(("3a3c44", "7a7c86", "b4b6c0", "e4e6ee")[tone])
    else:
        def paint(dx, dy, lit, r):
            tone = 2 if lit > 0.45 else (1 if lit > -0.25 else 0)
            cap = dy > 1.5                                   # the pink south polar cap
            pal = ("6a4a52", "c09098", "f0c8c8", "fff0ee") if cap else ("4e4a52", "a08e8e", "d8c0b4", "f4e4dc")
            if not cap and (round(dx) + round(dy) * 2) % 3 == 0 and tone == 1:
                tone = 0                                     # "cantaloupe" terrain
            return hexc(pal[tone])
    t = _disc(17, 5.6, paint)
    halo = {"jupiter": ("fff08a", "e8c440"), "uranus": None, "neptune": ("c8d8ff", "8aa0d0")}[skin]
    if halo:
        ys, xs = np.mgrid[0:17, 0:17]
        r = np.hypot(xs - 8, ys - 8)
        lit = -((xs - 8) + (ys - 8)) / 8.0
        m = (r > 5.6) & (r <= 6.7) & (lit > -0.2)
        t[m] = hexc(halo[0], 110)
        m = (r > 5.6) & (r <= 6.7) & (lit <= -0.2) & (lit > -0.6)
        t[m] = hexc(halo[1], 60)
    return t


def small_moon(skin):
    """22 x 14, two 11 x 14 frames (Saturn: Enceladus with its plume). 7 x 7 disc at the top left of each cell."""
    e = np.zeros((14, 22, 4), dtype=np.uint8)
    if skin == "jupiter":                 # Europa: white ice, brown lineae, the plume Hubble may have seen
        disc = ["..www..", ".wwbwl.", "wbwwlbs", "wwbllls", "wwlblss", ".lllbs.", "..sss.."]
        col = {"w": hexc("fffaf0"), "l": hexc("dcd0bc"), "s": hexc("8a7a6a"), "b": hexc("9a6040")}
        plume = [[(3, 7), (3, 8), (3, 9), (2, 10)], [(3, 7), (3, 8), (4, 9), (3, 10), (3, 11)]]
        pc = "e4e0ff"
    elif skin == "uranus":                # Ariel: grey ice, bright young scarps
        disc = ["..lll..", ".lwlll.", "lwwlwls", "llwllss", "lllslss", ".lssss.", "..sss.."]
        col = {"w": hexc("e8eaf0"), "l": hexc("a4a8b4"), "s": hexc("4e525e")}
        plume, pc = [[], []], None
    else:                                 # Proteus: dark and lumpy
        disc = ["..ll...", ".lllls.", "llwllss", "lllssss", ".lsssss", "..sss..", "......."]
        col = {"w": hexc("a09898"), "l": hexc("6e6466"), "s": hexc("38302e")}
        plume, pc = [[], []], None
    for f in range(2):
        e[0:7, f * 11:f * 11 + 7] = ascii_sprite(disc, col)
        for i, (x, y) in enumerate(plume[f]):
            e[y, f * 11 + x] = hexc(pc, 200 - i * 40)
    if skin != "jupiter":                 # a glint that comes and goes so the 2 frames still differ
        e[1, 11 + 2] = hexc("ffffff")
    return e


# ------------------------------------------------------------------ main

def gen(skin):
    def put(img, name):
        save(img, "%s_%s.png" % (skin, name))

    put(planet(skin), "planet")
    put(wisps(skin), "wisps")
    far, back, mid, near = ring_set(skin)
    put(far, "ring_far")
    put(back, "ring_back")
    put(mid, "ring_mid")
    put(near, "ring_near")
    put(ring_arcs(skin), "ring_arcs")
    put(shadow(skin), "shadow")
    put(crystals(skin), "crystal")
    put(big_moon(skin), "titan")
    put(small_moon(skin), "enceladus")
    for i in range(7):
        put(recolour_rock(np.array(Image.open(os.path.join(OUT, "rock_%d.png" % i)).convert("RGBA")), skin), "rock_%d" % i)
    for i in range(3):
        put(recolour_near(np.array(Image.open(os.path.join(OUT, "near_%d.png" % i)).convert("RGBA")), skin), "near_%d" % i)


if __name__ == "__main__":
    for s in (sys.argv[1:] or SKINS):
        gen(s)
